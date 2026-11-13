#!/usr/bin/env node
// Nutrition N12 (D86): builds src/data/korean-foods.json — the representative items (품목대표: dishes, raw foods,
// generic processed foods) of 식품의약품안전처's 식품영양성분DB (data.go.kr 15127578, licence: 이용허락범위 제한 없음).
// The server searches this copy for a Korean query, so the dishes and plain foods rank well and answer at once; brand
// products come from the live API. Re-run before a release to refresh (≈ 93 calls of the 10,000 a day).
//
//   MFDS_API_KEY=… node scripts/build-korean-foods.mjs
//
// The key travels in the URL (the API takes no header); it is never printed — errors name the page and status only.

import { writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const URL_BASE = "https://apis.data.go.kr/1471000/FoodNtrCpntDbInfo03/getFoodNtrCpntDbInq03";
const PAGE = 100;
const OUT = join(dirname(fileURLToPath(import.meta.url)), "..", "src", "data", "korean-foods.json");

const key = process.env.MFDS_API_KEY?.trim();
if (!key) {
  console.error("Set MFDS_API_KEY (the data.go.kr key) in the environment.");
  process.exit(1);
}

async function page(number) {
  const query = new URLSearchParams({
    serviceKey: key, type: "json", pageNo: String(number), numOfRows: String(PAGE), DB_CLASS_NM: "품목대표",
  });
  for (let attempt = 1; attempt <= 4; attempt++) {
    try {
      const response = await fetch(`${URL_BASE}?${query}`, { signal: AbortSignal.timeout(30_000) });
      if (response.ok) {
        const body = await response.json();
        if (body?.header?.resultCode === "00" && Array.isArray(body?.body?.items)) return body.body;
      }
      console.error(`page ${number}: status ${response.status}, attempt ${attempt}`);
    } catch (error) {
      console.error(`page ${number}: ${error?.name ?? "error"}, attempt ${attempt}`);
    }
    await new Promise((resolve) => setTimeout(resolve, 1_000 * attempt));
  }
  throw new Error(`page ${number} failed`);
}

/** "2,117.000" → 2117; "" or missing → null; anything else that is not a non-negative number → NaN (row skipped). */
function number(value) {
  if (value === undefined || value === null) return null;
  const text = String(value).replace(/,/g, "").trim();
  if (text === "") return null;
  const n = Number(text.replace(/(mg|g|ml|kcal)$/i, ""));
  return Number.isFinite(n) && n >= 0 ? n : NaN;
}

/** "400.000g" → [400, "g"]; "575.000mL" → [575, "ml"]; anything else → [null, null]. */
function weight(value) {
  const match = /^\s*([\d,.]+)\s*(g|ml)\s*$/i.exec(String(value ?? ""));
  if (!match) return [null, null];
  const n = Number(match[1].replace(/,/g, ""));
  return Number.isFinite(n) && n > 0 ? [Math.round(n * 100) / 100, match[2].toLowerCase()] : [null, null];
}

const first = await page(1);
const total = Number(first.totalCount);
const pages = Math.ceil(total / PAGE);
const items = [...first.items];
for (let n = 2; n <= pages; n++) items.push(...(await page(n)).items);
if (items.length !== total) throw new Error(`expected ${total} rows, got ${items.length}`);

const rows = [];
let skipped = 0;
for (const item of items) {
  const basis = String(item.SERVING_SIZE ?? "").trim().toLowerCase();
  const unit = basis === "100g" ? "g" : basis === "100ml" ? "ml" : null;
  const group = item.DB_GRP_CM === "D" ? "D" : item.DB_GRP_CM === "P" ? "P" : String(item.DB_GRP_CM ?? "").startsWith("R") ? "R" : null;
  const name = String(item.FOOD_NM_KR ?? "").replace(/\s+/g, " ").trim();
  const values = ["AMT_NUM1", "AMT_NUM3", "AMT_NUM4", "AMT_NUM6", "AMT_NUM7", "AMT_NUM8", "AMT_NUM13", "AMT_NUM24"]
    .map((field) => number(item[field]));
  if (!unit || !group || !name || !item.FOOD_CD || values.some(Number.isNaN) || values[0] === null) { skipped++; continue; }
  const [portion, portionUnit] = weight(item.Z10500);
  const maker = String(item.MAKER_NM ?? "").trim();
  rows.push({
    code: String(item.FOOD_CD), name, group, maker: maker && maker !== "-" ? maker : null, unit, values,
    portion: portionUnit === unit ? portion : null,
    complete: values.slice(1, 4).every((v) => v !== null),
    date: String(item.UPDATE_DATE ?? item.RESEARCH_YMD ?? ""),
  });
}

// One row per name: the same dish or food appears once per survey year. Keep the one with protein, fat and carbs all
// given, then per 100 g (a solid dish per 100 mL is the survey's volume, not what people weigh), then the newest.
const best = new Map();
const better = (a, b) => (a.complete !== b.complete ? a.complete : a.unit !== b.unit ? a.unit === "g" : a.date > b.date);
for (const row of rows) {
  const kept = best.get(row.name);
  if (!kept || better(row, kept)) best.set(row.name, row);
}

// Compact rows: [code, name, group, maker, unit, kcal, protein, fat, carbs, sugar, fiber, sodiumMg, saturatedFat, portion]
const out = [...best.values()]
  .sort((a, b) => a.name.localeCompare(b.name, "ko"))
  .map((r) => [r.code, r.name, r.group, r.maker, r.unit, ...r.values, r.portion]);
writeFileSync(OUT, JSON.stringify({
  source: "식품의약품안전처 식품영양성분DB (data.go.kr 15127578), 품목대표",
  built: new Date().toISOString().slice(0, 10),
  fields: ["code", "name", "group", "maker", "unit", "kcal", "protein", "fat", "carbs", "sugar", "fiber", "sodiumMg", "saturatedFat", "portion"],
  rows: out,
}) + "\n");
console.log(`${total} rows read, ${skipped} skipped, ${out.length} written to src/data/korean-foods.json`);

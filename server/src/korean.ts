import type { Deps, Env } from "./env";
import {
  type DatabaseFood, type Field, type Nutrients, type Per100Unit, INVALID, PER_100_KCAL, PER_SERVING_KCAL, Upstream,
  fetchJSON, field, isObject, nutrients, round, scale, text,
} from "./food";
import data from "./data/korean-foods.json";

// Nutrition N12 (D86): Korean food data. A search typed in Korean goes to 식품의약품안전처's 식품영양성분DB instead of
// USDA: its representative items (dishes, raw foods, generic processed foods — about 6,500 after one row per name) are
// built into the server (scripts/build-korean-foods.mjs) and ranked here; brand products come from the live API. A
// Korean barcode (GS1 Korea, 880…) that Open Food Facts cannot fill is asked of Food QR and of 식품안전나라's C005 list,
// which give the product's report number (품목제조보고번호) — the key 식품영양성분DB has instead of a barcode — and
// Food QR the label's own numbers. Both data.go.kr services share one key (MFDS_API_KEY); C005 has its own
// (FOODSAFETY_API_KEY). Every key travels in a URL (the APIs take no header): a URL is never logged.

export const MFDS_URL = "https://apis.data.go.kr/1471000/FoodNtrCpntDbInfo03/getFoodNtrCpntDbInq03";
export const FOOD_QR_URL = "https://apis.data.go.kr/1471000/FoodQrInfoService02/";
export const C005_URL = "https://openapi.foodsafetykorea.go.kr/api/";
/** A search shows at most this many foods (as N8's). */
export const KOREAN_RESULTS = 10;
/** Brand products asked of the live API per search (each row is ~3.5 KB of 157 nutrient fields). */
const LIVE_ROWS = 30;
/** Report numbers tried for one barcode (a product made in several factories has one each). */
const MAX_REPORT_NUMBERS = 3;
/** A package larger than this is not offered as "1 package" (a 2 kg bulk pack is not a portion). */
const MAX_PACKAGE = 1_000;
const MAX_NAME = 200;
const MAX_BRAND = 100;

/** Hangul syllables or jamo anywhere in a query: it goes to the Korean database. */
export const hasHangul = (query: string) => /[ᄀ-ᇿ㄰-㆏가-힯]/.test(query);

/** A food or dish as the database gives it, before it is checked: nutrients per 100 of `unit`. */
export interface KoreanRow {
  code: string;
  name: string;
  /** D 음식 (dish), P 가공식품 (processed), R 원재료성 (raw). */
  group: "D" | "P" | "R";
  maker: string | null;
  unit: Per100Unit;
  values: { calories: Field; protein: Field; fat: Field; carbs: Field; sugar: Field; fiber: Field; sodiumMg: Field; saturatedFat: Field };
  /** A dish's usual portion, or a product's package, in `unit`; null when not given or in the other unit. */
  portion: number | null;
}

/** "김치찌개_돼지고기" → "김치찌개, 돼지고기": the database joins a dish and its kind with "_"; raw foods already use ", ". */
export function koreanName(raw: string): string | null {
  return text(raw.replace(/\s*_\s*/g, ", "), MAX_NAME);
}

/** The maker, or null for the database's placeholders. */
function maker(raw: unknown): string | null {
  const name = text(raw, MAX_BRAND);
  return name && !/^(-|해당없음|없음)$/.test(name) ? name : null;
}

/** "2,117.000" → 2117 (the database's numbers are text with thousands commas); otherwise as N8's `field`. */
function koreanField(value: unknown): Field {
  return field(typeof value === "string" ? value.replace(/,/g, "") : value);
}

/** "400.000g" / "575.000mL" → its amount when it is in `unit`; null otherwise. */
function portionIn(value: unknown, unit: Per100Unit): number | null {
  const match = typeof value === "string" ? /^\s*([\d,.]+)\s*(g|ml)\s*$/i.exec(value) : null;
  if (!match || match[2]!.toLowerCase() !== unit) return null;
  const n = Number(match[1]!.replace(/,/g, ""));
  return Number.isFinite(n) && n > 0 && n <= 100_000 ? round(n) : null;
}

/** A live API item (식품영양성분DB) as a row, or null when its basis is not 100 g or 100 mL or it lacks a code or name. */
export function fromMFDSItem(item: Record<string, unknown>): KoreanRow | null {
  const basis = typeof item.SERVING_SIZE === "string" ? item.SERVING_SIZE.trim().toLowerCase() : "";
  const unit: Per100Unit | null = basis === "100g" ? "g" : basis === "100ml" ? "ml" : null;
  const code = typeof item.FOOD_CD === "string" && /^[\w-]{1,40}$/.test(item.FOOD_CD) ? item.FOOD_CD : null;
  const name = typeof item.FOOD_NM_KR === "string" ? item.FOOD_NM_KR : null;
  const groupCode = String(item.DB_GRP_CM ?? "");
  const group = groupCode === "D" ? "D" : groupCode === "P" ? "P" : groupCode.startsWith("R") ? "R" : null;
  if (!unit || !code || !name || !group) return null;
  return {
    code, name, group, maker: maker(item.MAKER_NM), unit, portion: portionIn(item.Z10500, unit),
    values: {
      calories: koreanField(item.AMT_NUM1), protein: koreanField(item.AMT_NUM3), fat: koreanField(item.AMT_NUM4),
      carbs: koreanField(item.AMT_NUM6), sugar: koreanField(item.AMT_NUM7), fiber: koreanField(item.AMT_NUM8),
      sodiumMg: koreanField(item.AMT_NUM13), saturatedFat: koreanField(item.AMT_NUM24),
    },
  };
}

/** The built-in representative items (scripts/build-korean-foods.mjs), read once per isolate. Each compact row is
 *  [code, name, group, maker, unit, kcal, protein, fat, carbs, sugar, fiber, sodiumMg, saturatedFat, portion]; a row
 *  of any other shape is skipped. */
let builtIn: KoreanRow[] | null = null;
export function representativeRows(): KoreanRow[] {
  if (builtIn) return builtIn;
  const rows: KoreanRow[] = [];
  for (const raw of (data as unknown as { rows: unknown[][] }).rows) {
    const [code, name, group, rowMaker, unit, ...numbers] = raw;
    if (typeof code !== "string" || typeof name !== "string" || (group !== "D" && group !== "P" && group !== "R")
      || (rowMaker !== null && typeof rowMaker !== "string") || (unit !== "g" && unit !== "ml") || numbers.length !== 9) continue;
    const [kcal, protein, fat, carbs, sugar, fiber, sodiumMg, saturatedFat, portion] = numbers.map((v) => field(v));
    rows.push({
      code, name, group, maker: rowMaker, unit, portion: typeof portion === "number" && portion > 0 ? portion : null,
      values: { calories: kcal!, protein: protein!, fat: fat!, carbs: carbs!, sugar: sugar!, fiber: fiber!, sodiumMg: sodiumMg!, saturatedFat: saturatedFat! },
    });
  }
  builtIn = rows;
  return rows;
}

/** The macros a row leaves blank (restaurant chains often give only calories, protein and sodium) — shown with a note,
 *  kept as 0 as N8 reads a blank (D86). */
export type NotListed = "protein" | "carbs" | "fat";

/**
 * A row as the one food shape: per 100 g (or ml), and a serving when the row gives a portion — a dish's usual portion
 * ("1 serving (400 g)") or a processed food's package ("1 package (77 g)", not for a pack over 1 kg). Raw foods are per
 * 100 g only. Bounded as N8's (codex-review-n8 S5): any invalid value makes the row unusable.
 */
export function fromKoreanRow(row: KoreanRow, barcode: string | null = null): DatabaseFood | null {
  const name = koreanName(row.name);
  if (!name || row.values.calories === null) return null;
  const v = row.values;
  const per100g = nutrients({
    calories: v.calories, protein: v.protein, carbs: v.carbs, fat: v.fat, saturatedFat: v.saturatedFat, fiber: v.fiber,
    sugar: v.sugar, sodiumMg: v.sodiumMg,
  }, { amount: 100, unit: row.unit }, PER_100_KCAL);
  if (!per100g) return null;
  let serving: DatabaseFood["serving"] = null;
  const portion = row.portion;
  if (portion && row.group !== "R" && (row.group === "D" || portion <= MAX_PACKAGE)) {
    const scaled = scale(per100g, portion, row.unit);
    const words = `${row.group === "D" ? "1 serving" : "1 package"} (${round(portion)} ${row.unit})`;
    if (scaled) serving = { text: words, grams: row.unit === "g" ? round(portion) : null, nutrients: scaled };
  }
  const notListed = (["protein", "carbs", "fat"] as const).filter((m) => v[m] === null);
  return {
    id: `mfds:${row.code}`, source: "mfds", name, brand: row.maker, barcode, per100g, per100Unit: row.unit, serving,
    measures: [], ...(notListed.length > 0 ? { notListed } : {}),
  };
}

// MARK: - Search

/** Letters and digits only, lower case: "신라면 건면" and "신라면건면" match alike (Korean is often typed unspaced). */
const compact = (s: string) => s.toLowerCase().replace(/[^\p{L}\p{N}]+/gu, "");
/** Words people type for what the database names otherwise (compact forms): egg, chicken breast ("닭고기, 가슴, 생것"),
 *  protein powder ("단백질 보충제, 가루"). */
const SYNONYMS: [string, string][] = [["계란", "달걀"], ["닭가슴살", "닭고기가슴"], ["프로틴", "단백질"]];

/** The query, and its forms with a synonym swapped in. */
export function queryForms(query: string): string[] {
  const forms = new Set([compact(query)]);
  for (const [a, b] of SYNONYMS) {
    for (const form of [...forms]) {
      if (form.includes(a)) forms.add(form.replaceAll(a, b));
      if (form.includes(b)) forms.add(form.replaceAll(b, a));
    }
  }
  return [...forms].filter(Boolean);
}

/**
 * How well a name matches (lower is better), or null when it does not hold the query: 0 the name itself, 1 its first
 * part ("바나나, 생것" or "김밥, 참치" for 바나나 / 김밥), 2 a name starting with it, 3 a later part starting with it
 * ("김치찌개, 돼지고기" for 돼지고기), 4 anywhere. The database's own order is by id, not relevance ("바나나, 생것" came
 * last of 1,871 matches).
 */
export function matchTier(name: string, forms: string[]): number | null {
  const whole = compact(name);
  const parts = name.split(/[,_/()]+/).map(compact).filter(Boolean);
  let best: number | null = null;
  for (const q of forms) {
    const tier = whole === q ? 0 : parts[0] === q ? 1 : whole.startsWith(q) ? 2 : parts.slice(1).some((p) => p.startsWith(q)) ? 3
      : whole.includes(q) ? 4 : null;
    if (tier !== null && (best === null || tier < best)) best = tier;
  }
  return best;
}

const GROUP_ORDER = { R: 0, D: 1, P: 2 } as const;

/** Rows that hold the query, best first: by tier, then raw food, dish, product; then those giving every macro; then
 *  the shorter (plainer) name; then the given order. Rows with the same name and maker are kept once. */
export function rankKorean(query: string, rows: KoreanRow[]): KoreanRow[] {
  const forms = queryForms(query);
  const scored: { row: KoreanRow; key: number[]; index: number }[] = [];
  rows.forEach((row, index) => {
    const tier = matchTier(row.name, forms);
    if (tier === null) return;
    const incomplete = row.values.protein === null || row.values.fat === null || row.values.carbs === null ? 1 : 0;
    scored.push({ row, index, key: [tier, GROUP_ORDER[row.group], incomplete, [...row.name].length] });
  });
  scored.sort((a, b) => {
    for (let i = 0; i < a.key.length; i++) if (a.key[i] !== b.key[i]) return a.key[i]! - b.key[i]!;
    return a.index - b.index;
  });
  const seen = new Set<string>();
  return scored.map((s) => s.row).filter((row) => {
    const key = `${compact(row.name)}|${row.maker ?? ""}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

/** The live 식품영양성분DB API: its items for `params`, or [] when nothing matches. Anything but the documented reply
 *  is a failure (never an empty result to cache). */
async function mfds(env: Env, deps: Deps, params: Record<string, string>): Promise<Record<string, unknown>[]> {
  const query = new URLSearchParams({ serviceKey: env.MFDS_API_KEY!, type: "json", pageNo: "1", ...params });
  const body = await fetchJSON(deps, "mfds", `${MFDS_URL}?${query}`, { headers: { accept: "application/json" } });
  if (!isObject(body) || !isObject(body.header) || body.header.resultCode !== "00" || !isObject(body.body)) {
    throw new Upstream("mfds", "malformed");
  }
  const items = body.body.items;
  if (items === undefined && Number(body.body.totalCount) === 0) return [];
  if (!Array.isArray(items)) throw new Upstream("mfds", "malformed");
  return items.filter(isObject);
}

/**
 * A Korean search: the built-in representative items and, with the key, the live API's brand products (상용제품) —
 * ranked together, the representative row first on a tie. `live` says whether brand products are in (false: no key,
 * or the live API failed; the caller does not cache such an answer as if complete).
 */
export async function searchKorean(env: Env, deps: Deps, query: string): Promise<{ foods: DatabaseFood[]; live: boolean; failed: boolean }> {
  const local = rankKorean(query, representativeRows());
  let products: KoreanRow[] = [];
  let failed = false;
  if (env.MFDS_API_KEY) {
    // The API matches a literal substring of the name, spaces included: "양파링 오리지널" finds the product named so,
    // "양파링오리지널" nothing — and "신라면건면" is found only unspaced (codex-review-n12 R1). A query with spaces is
    // asked both ways, at once; one form failing marks the answer incomplete (not cached) without hiding the other's.
    const forms = [...new Set([query, query.replace(/\s+/g, "")])];
    const answers = await Promise.all(forms.map(async (form) => {
      try {
        return await mfds(env, deps, { numOfRows: String(LIVE_ROWS), FOOD_NM_KR: form, DB_CLASS_NM: "상용제품" });
      } catch (error) {
        if (!(error instanceof Upstream)) throw error;
        console.error("food upstream", error.source, error.status);
        failed = true;
        return [];
      }
    }));
    products = answers.flat().map(fromMFDSItem).filter((r): r is KoreanRow => r !== null);
  }
  const foods: DatabaseFood[] = [];
  for (const row of rankKorean(query, [...local, ...products])) {
    const food = fromKoreanRow(row);
    if (!food || foods.some((f) => f.id === food.id)) continue;
    foods.push(food);
    if (foods.length === KOREAN_RESULTS) break;
  }
  return { foods, live: Boolean(env.MFDS_API_KEY) && !failed, failed };
}

// MARK: - Barcodes

/** What the Korean sources know of a barcode: its product's report numbers, a Korean name for the "Is this it?"
 *  search, and Food QR's label numbers when it has them. `failed`: a source that was asked did not answer. */
export interface KoreanBarcode {
  reportNumbers: string[];
  name: string | null;
  label: DatabaseFood | null;
  failed: boolean;
}

/** A report number as given: 8–20 digits (the database sometimes joins several with "/"). */
const reportNumber = (value: unknown) => {
  const s = typeof value === "string" ? value.trim() : typeof value === "number" ? String(value) : "";
  return /^\d{8,20}$/.test(s) ? s : null;
};

/** A source that was asked and did not answer (kept apart from every value it could answer). */
const FAILED = Symbol("failed");

/** A barcode as a source gives it — digits, as text — is this GTIN, whatever its zero padding (8–14 digits). */
export function sameCode(value: unknown, code: string): boolean {
  if (typeof value !== "string") return false;
  const digits = value.trim();
  return /^\d{8,14}$/.test(digits) && digits.padStart(14, "0") === code.padStart(14, "0");
}

/** Food QR stores a GTIN as 14 digits with a leading 0. */
const qrBarcode = (code: string) => code.padStart(14, "0");

async function foodQR(env: Env, deps: Deps, operation: string, code: string): Promise<Record<string, unknown>[]> {
  const query = new URLSearchParams({ serviceKey: env.MFDS_API_KEY!, type: "json", pageNo: "1", numOfRows: "50", brcd_no: qrBarcode(code) });
  const body = await fetchJSON(deps, "foodqr", `${FOOD_QR_URL}${operation}?${query}`, { headers: { accept: "application/json" } });
  if (!isObject(body) || !isObject(body.header) || body.header.resultCode !== "00" || !isObject(body.body)) {
    throw new Upstream("foodqr", "malformed");
  }
  const items = body.body.items;
  if (items === undefined && Number(body.body.totalCount) === 0) return [];
  const list = Array.isArray(items) ? items : isObject(items) && Array.isArray(items.item) ? items.item : null;
  if (!list) throw new Upstream("foodqr", "malformed");
  // Only rows that name this barcode (the filter is the service's; a reply is not trusted to have applied it — a row
  // without one, or with another, is never taken for this product: codex-review-n12 R3). Rows, none of them ours: a
  // malformed reply, a failure (never a miss to cache).
  const rows = list.filter(isObject);
  const ours = rows.filter((r) => sameCode(r.BRCD_NO, code));
  if (rows.length > 0 && ours.length === 0) throw new Upstream("foodqr", "malformed");
  return ours;
}

/** Food QR's nutrient names → the food shape, with the unit each must be in. */
const QR_NUTRIENTS: Record<string, [keyof Nutrients, string]> = {
  열량: ["calories", "kcal"], 탄수화물: ["carbs", "g"], 단백질: ["protein", "g"], 지방: ["fat", "g"], 당류: ["sugar", "g"],
  포화지방: ["saturatedFat", "g"], 식이섬유: ["fiber", "g"], 나트륨: ["sodiumMg", "mg"],
};

/** An amount and unit as Food QR gives them ("1.000" "kg") in g or ml; null otherwise. */
function qrAmount(value: unknown, unit: unknown): { amount: number; unit: Per100Unit } | null {
  const n = Number(typeof value === "string" ? value.replace(/,/g, "") : value);
  const u = String(unit ?? "").trim().toLowerCase();
  if (!Number.isFinite(n) || n <= 0) return null;
  const [factor, base]: [number, Per100Unit] | [null, null] = u === "g" ? [1, "g"] : u === "kg" ? [1000, "g"]
    : u === "ml" ? [1, "ml"] : u === "l" ? [1000, "ml"] : [null, null];
  if (factor === null) return null;
  const amount = n * factor;
  return amount <= 100_000 ? { amount: round(amount), unit: base } : null;
}

/**
 * Food QR's label numbers as a food, or null. Its rows give one nutrient each, for a stated basis — per 100 g, per
 * unit, or per package. Labels are not all consistent (one gave the same numbers for 200 g and for 1 kg), so a label
 * is used only when every row states one and the same basis; per package it becomes the serving ("1 package (247 g)")
 * and is scaled to 100.
 */
export function fromFoodQRLabel(code: string, rows: Record<string, unknown>[], name: string | null): DatabaseFood | null {
  const label = rows.filter((r) => typeof r.NIRWMT_NM === "string" && r.NIRWMT_NM.trim() in QR_NUTRIENTS);
  if (label.length === 0) return null;
  const basisOf = (r: Record<string, unknown>) => {
    const kind = String(r.UCVI_CTA_CD ?? "");
    if (/100\s*(g|ml)/i.test(kind)) return { amount: 100, unit: (/ml/i.test(kind) ? "ml" : "g") as Per100Unit, perPackage: false };
    const unitAmount = qrAmount(r.NTRTN_ICUT_CTV, r.NTRTN_ICUT_CVUCD);
    if (unitAmount && !/총/.test(kind)) return { ...unitAmount, perPackage: false };
    const total = qrAmount(r.NTRTN_INDCT_TCT, r.NTRTN_INDCT_TCD);
    return total ? { ...total, perPackage: true } : null;
  };
  const bases = label.map(basisOf);
  const first = bases[0];
  if (!first || bases.some((b) => !b || b.amount !== first.amount || b.unit !== first.unit)) return null;
  const raw: Record<keyof Nutrients, Field> = {
    calories: null, protein: null, carbs: null, fat: null, saturatedFat: null, fiber: null, sugar: null, sodiumMg: null,
  };
  for (const r of label) {
    const [key, unit] = QR_NUTRIENTS[String(r.NIRWMT_NM).trim()]!;
    const value = String(r.IGRD_UCD ?? "").trim().toLowerCase() === unit ? field(typeof r.CTA === "string" ? r.CTA.replace(/,/g, "") : r.CTA) : INVALID;
    // The same nutrient given twice must agree.
    if (raw[key] !== null && raw[key] !== value) raw[key] = INVALID; else raw[key] = value;
  }
  const atBasis = nutrients(raw, { amount: first.amount, unit: first.unit }, first.amount === 100 ? PER_100_KCAL : PER_SERVING_KCAL);
  if (!atBasis) return null;
  const per100g = first.amount === 100 ? atBasis : rescale(atBasis, 100 / first.amount, first.unit);
  if (!per100g) return null;
  const productName = name ?? text(label[0]!.PRDCT_NM, MAX_NAME);
  if (!productName) return null;
  const serving = first.amount === 100 ? null : {
    text: `${first.perPackage ? "1 package" : "1 serving"} (${round(first.amount)} ${first.unit})`,
    grams: first.unit === "g" ? round(first.amount) : null, nutrients: atBasis,
  };
  return {
    id: `foodqr:${code}`, source: "foodQR", name: productName, brand: null, barcode: code, per100g, per100Unit: first.unit,
    serving, measures: [],
  };
}

/** Nutrients for one basis scaled by `factor` and bounded per 100 of `unit`. */
function rescale(n: Nutrients, factor: number, unit: Per100Unit): Nutrients | null {
  const s = (v: number | null) => (v === null ? null : v * factor);
  return nutrients({
    calories: n.calories * factor, protein: n.protein * factor, carbs: n.carbs * factor, fat: n.fat * factor,
    saturatedFat: s(n.saturatedFat), fiber: s(n.fiber), sugar: s(n.sugar), sodiumMg: s(n.sodiumMg),
  }, { amount: 100, unit }, PER_100_KCAL);
}

/** C005 (식품안전나라 바코드연계제품정보): the products registered under a barcode. Its replies wrap a RESULT code:
 *  INFO-000 found, INFO-200 none; anything else (a bad key, the call limit, a server error) is a failure. */
async function c005(env: Env, deps: Deps, code: string): Promise<Record<string, unknown>[]> {
  const url = `${C005_URL}${encodeURIComponent(env.FOODSAFETY_API_KEY!)}/C005/json/1/20/BAR_CD=${code}`;
  const body = await fetchJSON(deps, "c005", url, { headers: { accept: "application/json" } });
  const service = isObject(body) ? body.C005 : null;
  if (!isObject(service) || !isObject(service.RESULT)) throw new Upstream("c005", "malformed");
  const result = service.RESULT.CODE;
  if (result === "INFO-200") return [];
  // Its code reaches the log only in its documented shape ("INFO-300", "ERROR-500"); anything else is "malformed" —
  // a reply's text never reaches the log (codex-review-n12 R4).
  if (result !== "INFO-000" || !Array.isArray(service.row)) {
    throw new Upstream("c005", typeof result === "string" && /^(INFO|ERROR)-\d{3}$/.test(result) ? result : "malformed");
  }
  // As Food QR's: only rows that name this barcode (R3).
  const rows = service.row.filter(isObject);
  const ours = rows.filter((r) => sameCode(r.BAR_CD, code));
  if (rows.length > 0 && ours.length === 0) throw new Upstream("c005", "malformed");
  return ours;
}

/** Asks Food QR (two operations) and C005 at once — whichever keys are set — and gathers what they know. */
export async function koreanBarcode(env: Env, deps: Deps, code: string): Promise<KoreanBarcode> {
  const ask = async <T>(enabled: boolean, work: () => Promise<T>): Promise<T | null | typeof FAILED> => {
    if (!enabled) return null;
    try { return await work(); } catch (error) {
      if (!(error instanceof Upstream)) throw error;
      console.error("food upstream", error.source, error.status);
      return FAILED;
    }
  };
  const [maker, label, registered] = await Promise.all([
    ask(Boolean(env.MFDS_API_KEY), () => foodQR(env, deps, "getFoodQrProdMnfInfo02", code)),
    ask(Boolean(env.MFDS_API_KEY), () => foodQR(env, deps, "getFoodQrProdNsd02", code)),
    ask(Boolean(env.FOODSAFETY_API_KEY), () => c005(env, deps, code)),
  ]);
  const failed = maker === FAILED || label === FAILED || registered === FAILED;
  const qrRows = Array.isArray(maker) ? maker : [];
  const c005Rows = Array.isArray(registered) ? registered : [];
  const numbers = [...qrRows.map((r) => reportNumber(r.IMRPT_NO)), ...c005Rows.map((r) => reportNumber(r.PRDLST_REPORT_NO))]
    .filter((n): n is string => n !== null);
  const name = text(qrRows[0]?.PRDCT_NM, MAX_NAME) ?? text(c005Rows[0]?.PRDLST_NM, MAX_NAME);
  const qrName = text(qrRows[0]?.PRDCT_NM, MAX_NAME);
  return {
    reportNumbers: [...new Set(numbers)].slice(0, MAX_REPORT_NUMBERS), name,
    label: Array.isArray(label) ? fromFoodQRLabel(code, label, qrName) : null, failed,
  };
}
/** The product a report number names in 식품영양성분DB, or null. The API's filter matches a prefix and one row can list
 *  several numbers ("a/b/c"), so a row counts only when one of its numbers is exactly this one. */
export async function byReportNumber(env: Env, deps: Deps, number: string, code: string): Promise<DatabaseFood | null> {
  const items = await mfds(env, deps, { numOfRows: "20", ITEM_REPORT_NO: number });
  for (const item of items) {
    const numbers = String(item.ITEM_REPORT_NO ?? "").split("/").map((n) => n.trim());
    if (!numbers.includes(number)) continue;
    const row = fromMFDSItem(item);
    const food = row ? fromKoreanRow(row, code) : null;
    if (food) return food;
  }
  return null;
}

/** The first of `numbers` (in order) that 식품영양성분DB has, asked at once; `failed` when a lookup did not answer. */
export async function bridge(env: Env, deps: Deps, numbers: string[], code: string): Promise<{ food: DatabaseFood | null; failed: boolean }> {
  if (!env.MFDS_API_KEY || numbers.length === 0) return { food: null, failed: false };
  const results = await Promise.all(numbers.map(async (n) => {
    try { return await byReportNumber(env, deps, n, code); } catch (error) {
      if (!(error instanceof Upstream)) throw error;
      console.error("food upstream", error.source, error.status);
      return FAILED;
    }
  }));
  const food = results.find((r): r is DatabaseFood => r !== null && r !== FAILED) ?? null;
  return { food, failed: !food && results.includes(FAILED) };
}

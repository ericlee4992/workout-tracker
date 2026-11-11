import { AuthError } from "./apple";
import { sha256Hex } from "./crypto";
import type { Deps, Env } from "./env";
import { characterCount } from "./text";
import { newYorkDay } from "./time";

// Nutrition N8 (D72): food databases through the server. A barcode is looked up at Open Food Facts first, then at USDA
// FoodData Central's branded foods; a search by name goes to USDA's generic foods (Foundation, SR Legacy, FNDDS). Every
// answer is normalised to one food shape (per 100 g and per serving) and cached in D1 — hits and misses, each with an
// expiry. Signed in only, with a modest per-account daily limit (no AI cost). Nothing about the account is sent to
// either database; the cache is linked to no account and keeps a typed search only as a one-way hash.

export const OFF_PRODUCT_URL = "https://world.openfoodfacts.org/api/v2/product/";
export const USDA_SEARCH_URL = "https://api.nal.usda.gov/fdc/v1/foods/search";
/** Open Food Facts asks every client for a descriptive User-Agent with a way to reach it: the app's support page (no
 *  personal address in a request). */
export const FOOD_USER_AGENT = "Stacked/1.0 (iOS workout and food log; +https://stacked-server.stacked-server.workers.dev/support)";
/** Each upstream call; the app waits longer (FoodDatabaseClient.timeout). */
export const FOOD_TIMEOUT_MS = 8_000;
/** Lookups per account per New York day; every request counts, cache hits too. */
export const FOOD_DAILY_LIMITS = { barcode: 200, search: 500 } as const;
export type FoodKind = keyof typeof FOOD_DAILY_LIMITS;

const DAY_MS = 24 * 60 * 60 * 1000;
/** A found product rarely changes; a miss is retried after a day (a product added to either database since). */
export const BARCODE_HIT_TTL_MS = 30 * DAY_MS;
export const BARCODE_MISS_TTL_MS = DAY_MS;
export const SEARCH_TTL_MS = 7 * DAY_MS;
export const EMPTY_SEARCH_TTL_MS = DAY_MS;
export const SEARCH_RESULTS = 10;
const USDA_PAGE_SIZE = 25;
/** A search asks for more than it shows, so the plain food ("Bananas, raw") is among what is ranked. */
const USDA_SEARCH_PAGE_SIZE = 50;
/** USDA's generic (not branded) foods, for search by name. */
export const USDA_GENERIC_TYPES = ["Foundation", "SR Legacy", "Survey (FNDDS)"];
const MAX_NAME = 200;
const MAX_BRAND = 100;
const MAX_SERVING_TEXT = 120;
const MAX_MEASURES = 6;

/** One serving's or 100 g's nutrition; macros 0 when the source omits them (as the app's forms read a blank). */
export interface Nutrients {
  calories: number; protein: number; carbs: number; fat: number;
  saturatedFat: number | null; fiber: number | null; sugar: number | null; sodiumMg: number | null;
}

/** A portion the food can be logged by, in the source's words, with its weight. */
export interface Measure { text: string; grams: number }

/** What `per100g` is per: 100 g, or 100 ml for a drink (codex-review-n8 S2) — never converted without a density. */
export type Per100Unit = "g" | "ml";

/** The one food shape both databases are normalised to. */
export interface DatabaseFood {
  /** `off:<code>` or `usda:<fdcId>`: the app's `SavedFood.databaseID`. */
  id: string;
  source: "openFoodFacts" | "usda";
  name: string;
  brand: string | null;
  barcode: string | null;
  /** Per 100 of `per100Unit` (g, or ml for a drink); null when the source gives only a serving. */
  per100g: Nutrients | null;
  per100Unit: Per100Unit;
  /** The package's (or the first household) serving: its words, weight when known, and its nutrition. */
  serving: { text: string; grams: number | null; nutrients: Nutrients } | null;
  /** Other portions (USDA generic foods), heaviest-ranked first; scale `per100g` by `grams / 100`. */
  measures: Measure[];
}

// MARK: - Input

/**
 * A scanned code as a GTIN, or null: 8 (EAN-8), 12 (UPC-A), 13 (EAN-13) or 14 digits with a valid check digit. UPC-A
 * and a 14-digit code with a leading 0 become their 13-digit EAN form, so one product has one cache key whichever way
 * it was read. (The app expands UPC-E to UPC-A before sending.)
 */
export function normalizeBarcode(raw: string): string | null {
  if (!/^(\d{8}|\d{12,14})$/.test(raw) || /^0+$/.test(raw) || !validCheckDigit(raw)) return null;
  if (raw.length === 12) return `0${raw}`;
  if (raw.length === 14 && raw.startsWith("0")) return raw.slice(1);
  return raw;
}

/** The GTIN check digit: weights 3, 1, 3, … from the digit left of the check digit. */
export function validCheckDigit(code: string): boolean {
  const digits = [...code].map(Number);
  const check = digits.pop()!;
  let sum = 0;
  digits.reverse().forEach((d, i) => { sum += d * (i % 2 === 0 ? 3 : 1); });
  return (10 - (sum % 10)) % 10 === check;
}

/** A search as typed: whitespace collapsed, 2–100 characters, no control characters; null otherwise. */
export function cleanQuery(raw: string | null): string | null {
  if (raw === null) return null;
  const query = raw.replace(/\s+/g, " ").trim();
  const length = characterCount(query);
  if (length < 2 || length > 100 || /[\u0000-\u001f\u007f]/.test(query)) return null;
  return query;
}

// MARK: - Normalisation

const round = (value: number, places = 2) => Math.round(value * 10 ** places) / 10 ** places;

/** A finite, non-negative number at most `max` (a number given as text, as Open Food Facts sometimes does, counts);
 *  null otherwise. For a serving's size or a portion's weight, where an unusable one is simply left out. */
function amount(value: unknown, max: number): number | null {
  const n = typeof value === "string" && value.trim() !== "" ? Number(value) : value;
  return typeof n === "number" && Number.isFinite(n) && n >= 0 && n <= max ? n : null;
}

/** A supplied nutrient (codex-review-n8 S5): `null` when the source does not give it, `INVALID` when it gives one that
 *  is not a finite, non-negative number — which makes the whole set unusable rather than read as missing or zero. */
const INVALID = Symbol("invalid");
type Field = number | null | typeof INVALID;

function field(value: unknown): Field {
  if (value === undefined || value === null || (typeof value === "string" && value.trim() === "")) return null;
  const n = typeof value === "string" ? Number(value) : value;
  return typeof n === "number" && Number.isFinite(n) && n >= 0 ? n : INVALID;
}

function text(value: unknown, max: number): string | null {
  if (typeof value !== "string") return null;
  const cleaned = value.replace(/[\u0000-\u001f\u007f]/g, " ").replace(/\s+/g, " ").trim();
  if (cleaned.length === 0) return null;
  return [...cleaned].slice(0, max).join("");
}

/** "NUTELLA HAZELNUT SPREAD" (USDA's branded names are often capitals) → "Nutella Hazelnut Spread"; other names as is. */
export function tidyName(name: string): string {
  if (name !== name.toUpperCase() || name === name.toLowerCase()) return name;
  return name.toLowerCase().replace(/(^|[\s\-/(&])(\p{L})/gu, (_, gap: string, letter: string) => gap + letter.toUpperCase());
}

/** What a set of nutrients is for, to bound it: an amount in grams or millilitres, or a serving of unknown weight. */
export interface Basis { amount: number | null; unit: Per100Unit }

/** A serving of unknown weight is bounded loosely: no serving holds more than this of one nutrient. */
const UNKNOWN_SERVING_GRAMS = 2_000;
/** A gram holds at most a gram of a nutrient; a millilitre may weigh more (syrups, honey ~1.4 g/ml). Rounding slack. */
const tolerance = (unit: Per100Unit) => (unit === "ml" ? 1.5 : 1.05);

/**
 * Bounds a nutrition answer (codex-review-n8 S5): 100 g (or ml) up to 900 kcal (pure fat), a serving up to 10,000;
 * no nutrient, and not protein + carbs + fat together, weighs more than its basis; sodium likewise in mg. Any supplied
 * value out of bounds, negative or not a number makes the set unusable — the source's numbers are wrong, so the food is
 * not logged with them. Macros the source omits are 0 (as the app's forms read a blank); the others stay unknown.
 */
function nutrients(raw: Record<keyof Nutrients, Field>, basis: Basis, kcalMax: number): Nutrients | null {
  const values = Object.values(raw);
  if (values.includes(INVALID)) return null;
  const v = raw as Record<keyof Nutrients, number | null>;
  if (v.calories === null || v.calories > kcalMax) return null;
  const limit = (basis.amount ?? UNKNOWN_SERVING_GRAMS) * tolerance(basis.unit);
  // Nothing has more than 9 kcal a gram (fat).
  if (basis.amount !== null && v.calories > limit * 9) return null;
  const grams = [v.protein, v.carbs, v.fat, v.saturatedFat, v.fiber, v.sugar];
  if (grams.some((g) => g !== null && g > limit)) return null;
  if ((v.protein ?? 0) + (v.carbs ?? 0) + (v.fat ?? 0) > limit) return null;
  if (v.sodiumMg !== null && v.sodiumMg > limit * 1000) return null;
  const g = (x: number | null) => (x === null ? null : round(x));
  return {
    calories: round(v.calories, 1),
    protein: g(v.protein) ?? 0, carbs: g(v.carbs) ?? 0, fat: g(v.fat) ?? 0,
    saturatedFat: g(v.saturatedFat), fiber: g(v.fiber), sugar: g(v.sugar),
    sodiumMg: v.sodiumMg === null ? null : round(v.sodiumMg, 1),
  };
}

/** `per100` scaled to `amount` of the same unit (a serving or a portion). */
function scale(per100: Nutrients, amount: number, unit: Per100Unit): Nutrients | null {
  const f = amount / 100;
  const s = (v: number | null) => (v === null ? null : v * f);
  return nutrients({
    calories: per100.calories * f, protein: per100.protein * f, carbs: per100.carbs * f, fat: per100.fat * f,
    saturatedFat: s(per100.saturatedFat), fiber: s(per100.fiber), sugar: s(per100.sugar), sodiumMg: s(per100.sodiumMg),
  }, { amount, unit }, PER_SERVING_KCAL);
}

const PER_100_KCAL = 900;
const PER_SERVING_KCAL = 10_000;
const MAX_GRAMS = 100_000;
const kj = (value: Field): Field => (typeof value === "number" ? value / 4.184 : value);
/** The first value a source gives (energy in kcal, else kJ…); an invalid one is not passed over for the next. */
const first = (...fields: Field[]): Field => fields.find((f) => f !== null) ?? null;

/** Amounts by volume ("330 ml", "1.5 L", "33 cl", "12 fl oz") and by weight ("400 g", "1 kg", "8 oz"). */
const VOLUME = /\b\d+(?:[.,]\d+)?\s*(?:ml|cl|dl|l|fl\.?\s?oz)\b/i;
const WEIGHT = /\b\d+(?:[.,]\d+)?\s*(?:g|kg|mg|oz|lb)\b/i;

/** "g" or "ml" when a text gives amounts in only one of the two; null when it gives neither or both. */
export function unitIn(words: string | null): Per100Unit | null {
  if (!words) return null;
  const volume = VOLUME.test(words), weight = WEIGHT.test(words);
  return volume === weight ? null : volume ? "ml" : "g";
}

/**
 * Open Food Facts' units, resolved together from every piece of evidence before any number is read (codex-review-n8-c
 * R3-S1). Its `_100g` numbers are per 100 ml for a product sold by volume and per 100 g otherwise; `serving_quantity`
 * is in the serving's unit. Neither the unit field nor the package's quantity is required, so:
 * - the basis: the package's quantity ("500 ml"), else the serving's unit (field, else its text), else grams — the
 *   database's own default;
 * - the serving's unit: its field, else its text ("1 spoon (10 g)"), else the basis — unless the field names some other
 *   unit, when its quantity is not used at all.
 * The two stay distinct: a 10 g spoon of a product sold by the litre is grams, and is never scaled from per 100 ml.
 */
export function offUnits(product: Record<string, unknown>): { per100: Per100Unit; serving: Per100Unit | null } {
  const raw = typeof product.serving_quantity_unit === "string" ? product.serving_quantity_unit.trim().toLowerCase() : "";
  const field: Per100Unit | null = raw === "g" || raw === "ml" ? raw : null;
  const servingText = typeof product.serving_size === "string" ? product.serving_size : null;
  const inServing = field ?? unitIn(servingText);
  const per100 = unitIn(typeof product.quantity === "string" ? product.quantity : null) ?? inServing ?? "g";
  // A field naming another unit ("oz") decides first: `serving_quantity` is in that unit, so no text ("2 oz (56 g)")
  // or basis may lend it grams or millilitres (codex-review-n8-d T1).
  if (raw !== "" && field === null) return { per100, serving: null };
  return { per100, serving: inServing ?? per100 };
}

/** An Open Food Facts product (API v2) as a food, or null when it has no name or no usable nutrition. */
export function fromOpenFoodFacts(code: string, product: Record<string, unknown>): DatabaseFood | null {
  const name = text(product.product_name, MAX_NAME) ?? text(product.product_name_en, MAX_NAME)
    ?? text(product.generic_name, MAX_NAME);
  if (!name) return null;
  const n = (typeof product.nutriments === "object" && product.nutriments !== null ? product.nutriments : {}) as Record<string, unknown>;
  const units = offUnits(product);
  const per100Unit = units.per100;
  const read = (suffix: "100g" | "serving", basis: Basis, max: number) => {
    const per = (key: string) => field(n[`${key}_${suffix}`]);
    const sodium = per("sodium");
    return nutrients({
      calories: first(per("energy-kcal"), kj(per("energy-kj")), kj(per("energy"))),
      protein: per("proteins"), carbs: per("carbohydrates"), fat: per("fat"),
      saturatedFat: per("saturated-fat"), fiber: per("fiber"), sugar: per("sugars"),
      // Open Food Facts gives sodium in grams.
      sodiumMg: typeof sodium === "number" ? sodium * 1000 : sodium,
    }, basis, max);
  };
  const per100g = read("100g", { amount: 100, unit: per100Unit }, PER_100_KCAL);
  const servingText = text(product.serving_size, MAX_SERVING_TEXT);
  const quantity = units.serving ? amount(product.serving_quantity, MAX_GRAMS) : null;
  const size = quantity && quantity > 0 ? quantity : null;
  const basis: Basis = { amount: size, unit: units.serving ?? "g" };
  // Scaled from 100 only within one unit: grams and millilitres are not interchangeable without a density.
  const servingNutrients = read("serving", basis, PER_SERVING_KCAL)
    ?? (per100g && size && units.serving === per100Unit ? scale(per100g, size, per100Unit) : null);
  const grams = units.serving === "g" && size ? round(size) : null;
  const serving = servingText && servingNutrients ? { text: servingText, grams, nutrients: servingNutrients } : null;
  if (!per100g && !serving) return null;
  const brand = typeof product.brands === "string" ? text(product.brands.split(",")[0], MAX_BRAND) : null;
  return {
    id: `off:${code}`, source: "openFoodFacts", name, brand, barcode: code, per100g: per100g, per100Unit, serving,
    measures: [],
  };
}

/** USDA nutrient numbers (FoodData Central): energy in kcal, then the Atwater energies some foods carry instead. */
const USDA = {
  calories: [1008, 2047, 2048], protein: [1003], carbs: [1005], fat: [1004], saturatedFat: [1258], fiber: [1079],
  sugar: [2000, 1063], sodiumMg: [1093],
} as const;

function usdaNutrients(food: Record<string, unknown>, unit: Per100Unit): Nutrients | null {
  const list = Array.isArray(food.foodNutrients) ? food.foodNutrients as Record<string, unknown>[] : [];
  const find = (ids: readonly number[], energy = false): Field => {
    for (const id of ids) {
      const row = list.find((r) => r.nutrientId === id && (!energy || String(r.unitName).toUpperCase() === "KCAL"));
      if (row) return field(row.value);
    }
    return null;
  };
  return nutrients({
    calories: find(USDA.calories, true), protein: find(USDA.protein), carbs: find(USDA.carbs), fat: find(USDA.fat),
    saturatedFat: find(USDA.saturatedFat), fiber: find(USDA.fiber), sugar: find(USDA.sugar), sodiumMg: find(USDA.sodiumMg),
  }, { amount: 100, unit }, PER_100_KCAL);
}

/** A USDA branded food (a search result: nutrients per 100 g, or per 100 ml for one served in ml) as a food, or null
 *  when unusable. */
export function fromUSDABranded(code: string, food: Record<string, unknown>): DatabaseFood | null {
  const name = text(food.description, MAX_NAME);
  const size = amount(food.servingSize, MAX_GRAMS);
  const unit = String(food.servingSizeUnit ?? "").toLowerCase();
  const metric = ["g", "grm", "gram", "grams"].includes(unit) ? "g" : ["ml", "mlt"].includes(unit) ? "ml" : null;
  const per100Unit: Per100Unit = metric === "ml" ? "ml" : "g";
  const per100g = usdaNutrients(food, per100Unit);
  if (!name || !per100g || typeof food.fdcId !== "number") return null;
  let serving: DatabaseFood["serving"] = null;
  if (size && size > 0 && metric) {
    const household = text(food.householdServingFullText, MAX_SERVING_TEXT);
    const weight = `${round(size)} ${metric}`;
    const scaled = scale(per100g, size, per100Unit);
    // "1 Can" → "1 Can (355 ml)"; a household text that already says its weight ("3/4 cup (20g)") is kept as is.
    const words = household && !household.includes(String(round(size))) ? `${household} (${weight})` : household ?? weight;
    if (scaled) serving = { text: words, grams: metric === "g" ? round(size) : null, nutrients: scaled };
  }
  const brand = text(food.brandName, MAX_BRAND) ?? text(food.brandOwner, MAX_BRAND);
  return {
    id: `usda:${food.fdcId}`, source: "usda", name: tidyName(name), brand: brand ? tidyName(brand) : null, barcode: code,
    per100g, per100Unit, serving, measures: [],
  };
}

/** A USDA generic food (Foundation, SR Legacy, FNDDS) as a food: per 100 g, its household portions as measures, the
 *  first of them as the serving. */
export function fromUSDAGeneric(food: Record<string, unknown>): DatabaseFood | null {
  const name = text(food.description, MAX_NAME);
  const per100g = usdaNutrients(food, "g");
  if (!name || !per100g || typeof food.fdcId !== "number") return null;
  const raw = Array.isArray(food.foodMeasures) ? food.foodMeasures as Record<string, unknown>[] : [];
  const measures: Measure[] = [];
  for (const m of [...raw].sort((a, b) => (Number(a.rank) || 0) - (Number(b.rank) || 0))) {
    const words = text(m.disseminationText, MAX_SERVING_TEXT);
    const grams = amount(m.gramWeight, MAX_GRAMS);
    if (!words || !grams || grams <= 0 || /quantity not specified/i.test(words)) continue;
    if (measures.some((x) => x.text === words)) continue;
    measures.push({ text: words, grams: round(grams) });
    if (measures.length === MAX_MEASURES) break;
  }
  const head = measures[0];
  const scaled = head ? scale(per100g, head.grams, "g") : null;
  return {
    id: `usda:${food.fdcId}`, source: "usda", name: tidyName(name), brand: null, barcode: null, per100g, per100Unit: "g",
    serving: head && scaled ? { text: head.text, grams: head.grams, nutrients: scaled } : null,
    measures: measures.slice(1),
  };
}

// MARK: - Upstream

class Upstream extends Error {
  constructor(readonly source: string, readonly status: string) { super(`${source} ${status}`); this.name = "Upstream"; }
}

/** An HTTP not-found, kept apart from every JSON value a reply can decode to (codex-review-n8-b R2-S2: a 200 `null`
 *  read as a miss). */
const NOT_FOUND = Symbol("not found");

async function fetchJSON(deps: Deps, source: string, url: string, init: RequestInit, missStatus?: number): Promise<unknown> {
  let response: Response;
  try {
    response = await deps.fetch(url, { ...init, signal: AbortSignal.timeout(FOOD_TIMEOUT_MS) });
  } catch (error) {
    throw new Upstream(source, error instanceof Error && error.name === "TimeoutError" ? "timeout" : "network");
  }
  if (response.status === missStatus) return NOT_FOUND;
  if (!response.ok) throw new Upstream(source, String(response.status));
  try { return await response.json(); } catch { throw new Upstream(source, "malformed"); }
}

/** Open Food Facts: a product, or null when it has none usable. Its v2 API answers 404 `{status: 0}` for an unknown code. */
async function openFoodFacts(code: string, deps: Deps): Promise<DatabaseFood | null> {
  const fields = "code,product_name,product_name_en,generic_name,brands,quantity,serving_size,serving_quantity," +
    "serving_quantity_unit,nutriments";
  const body = await fetchJSON(deps, "off", `${OFF_PRODUCT_URL}${code}.json?fields=${fields}`,
    { headers: { "user-agent": FOOD_USER_AGENT, accept: "application/json" } }, 404);
  if (body === NOT_FOUND) return null;  // 404: not in Open Food Facts
  // Only `{status: 0}` is a miss and only `{status: 1, product: {…}}` a product; any other reply is a failure, never a
  // miss to cache (codex-review-n8 S4).
  if (!isObject(body)) throw new Upstream("off", "malformed");
  if (body.status === 0) return null;
  if (body.status !== 1 || !isObject(body.product)) throw new Upstream("off", "malformed");
  return fromOpenFoodFacts(code, body.product);
}

/** USDA's food search; the key travels in a header, never in a URL. */
async function usdaSearch(key: string, deps: Deps, query: string, dataType: string[], pageSize = USDA_PAGE_SIZE): Promise<Record<string, unknown>[]> {
  const body = await fetchJSON(deps, "usda", USDA_SEARCH_URL, {
    method: "POST",
    headers: { "x-api-key": key, "content-type": "application/json", accept: "application/json", "user-agent": FOOD_USER_AGENT },
    body: JSON.stringify({ query, dataType, pageSize }),
  });
  // A reply without its `foods` list (an error envelope, another shape) is a failure, not an empty result to cache.
  if (!isObject(body) || !Array.isArray(body.foods)) throw new Upstream("usda", "malformed");
  return body.foods.filter(isObject);
}

const isObject = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null && !Array.isArray(value);

/** The same GTIN whatever its length in USDA's `gtinUpc` (12-digit UPCs, sometimes 13 or 14 digits; an EAN-8 padded
 *  with zeros): both valid, compared as 14 digits (codex-review-n8 S1). */
export function sameGTIN(value: unknown, code: string): boolean {
  if (typeof value !== "string") return false;
  const other = value.trim();
  if (!/^\d{8,14}$/.test(other) || !validCheckDigit(other)) return false;
  return other.padStart(14, "0") === code.padStart(14, "0");
}

/** The forms a GTIN is stored in at USDA (`gtinUpc` holds 12, 13 or 14 digits, matched only exactly): every form,
 *  as one any-word query. */
export function gtinForms(code: string): string[] {
  const forms = new Set([code, code.padStart(14, "0")]);
  if (code.length === 13 && code.startsWith("0")) forms.add(code.slice(1));
  if (code.length === 8) forms.add(code.padStart(13, "0"));
  return [...forms];
}

async function usdaBarcode(code: string, key: string, deps: Deps): Promise<DatabaseFood | null> {
  const foods = await usdaSearch(key, deps, gtinForms(code).join(" "), ["Branded"]);
  for (const food of foods.filter((f) => sameGTIN(f.gtinUpc, code))) {
    const found = fromUSDABranded(code, food);
    if (found) return found;
  }
  return null;
}

// MARK: - Cache and limit

async function readCache<T>(env: Env, deps: Deps, key: string): Promise<{ value: T } | null> {
  const row = await env.DB.prepare("SELECT body FROM food_cache WHERE key = ? AND expires_at > ?")
    .bind(key, deps.now()).first<{ body: string }>();
  if (!row) return null;
  try { return { value: JSON.parse(row.body) as T }; } catch { return null; }
}

async function writeCache(env: Env, deps: Deps, key: string, value: unknown, ttl: number) {
  const now = deps.now();
  await env.DB.prepare("INSERT OR REPLACE INTO food_cache (key, body, created_at, expires_at) VALUES (?, ?, ?, ?)")
    .bind(key, JSON.stringify(value), now, now + ttl).run();
}

/** Counts one lookup, or refuses it past today's limit (`429 food_limit`). A deleted account counts nothing (401). */
async function countLookup(env: Env, deps: Deps, accountID: string, kind: FoodKind) {
  const row = await env.DB.prepare(
    "INSERT INTO food_limits (account_id, day, kind, count) SELECT ?1, ?2, ?3, 1 " +
    "WHERE EXISTS (SELECT 1 FROM accounts WHERE id = ?1) " +
    "ON CONFLICT(account_id, day, kind) DO UPDATE SET count = count + 1 WHERE count < ?4 RETURNING count")
    .bind(accountID, newYorkDay(deps.now()), kind, FOOD_DAILY_LIMITS[kind]).first<{ count: number }>();
  if (row) return;
  const exists = await env.DB.prepare("SELECT 1 AS one FROM accounts WHERE id = ?").bind(accountID).first();
  throw exists ? new AuthError("food_limit", 429) : new AuthError("unauthorized", 401);
}

// MARK: - Routes

/**
 * `GET /v1/food/barcode/:code` → `{ found: true, food }` or `{ found: false }`. Open Food Facts first, then USDA
 * branded foods (when the key is set). Hits are cached 30 days, misses a day. A miss is not cached when USDA was not
 * asked (no key yet) or when either source failed — the next try may find it — and a failure with nothing found is
 * `502 food_unavailable`.
 */
export async function lookupBarcode(env: Env, deps: Deps, accountID: string, raw: string) {
  const code = normalizeBarcode(raw);
  if (!code) throw new AuthError("invalid_barcode", 400);
  await countLookup(env, deps, accountID, "barcode");
  const key = `barcode:${code}`;
  const cached = await readCache<DatabaseFood | null>(env, deps, key);
  if (cached) return cached.value ? { found: true, food: cached.value } : { found: false };
  let failed = false;
  let food: DatabaseFood | null = null;
  try { food = await openFoodFacts(code, deps); } catch (error) { failed = true; logUpstream(error); }
  if (!food && env.USDA_API_KEY) {
    try { food = await usdaBarcode(code, env.USDA_API_KEY, deps); } catch (error) { failed = true; logUpstream(error); }
  }
  if (food) {
    await writeCache(env, deps, key, food, BARCODE_HIT_TTL_MS);
    return { found: true, food };
  }
  if (failed) throw new AuthError("food_unavailable", 502);
  if (env.USDA_API_KEY) await writeCache(env, deps, key, null, BARCODE_MISS_TTL_MS);
  return { found: false };
}

/**
 * `GET /v1/food/search?q=` → `{ foods: [...] }`, at most ten USDA generic foods (e.g. "banana", "chicken breast").
 * Cached under the query's hash: a week, a day when nothing matched. Without the USDA key: `503 server_not_configured`.
 */
export async function searchFoods(env: Env, deps: Deps, accountID: string, raw: string | null) {
  const query = cleanQuery(raw);
  if (!query) throw new AuthError("invalid_query", 400);
  if (!env.USDA_API_KEY) throw new AuthError("server_not_configured", 503);
  await countLookup(env, deps, accountID, "search");
  const key = `search:${await sha256Hex(query.toLowerCase())}`;
  const cached = await readCache<DatabaseFood[]>(env, deps, key);
  if (cached) return { foods: cached.value };
  let results: Record<string, unknown>[];
  try {
    results = await usdaSearch(env.USDA_API_KEY, deps, query, USDA_GENERIC_TYPES, USDA_SEARCH_PAGE_SIZE);
  } catch (error) {
    logUpstream(error);
    throw new AuthError("food_unavailable", 502);
  }
  const foods: DatabaseFood[] = [];
  for (const result of results) {
    const food = fromUSDAGeneric(result);
    if (!food || foods.some((f) => f.id === food.id || f.name.toLowerCase() === food.name.toLowerCase())) continue;
    foods.push(food);
  }
  foods.splice(0, foods.length, ...rankFoods(query, foods).slice(0, SEARCH_RESULTS));
  await writeCache(env, deps, key, foods, foods.length > 0 ? SEARCH_TTL_MS : EMPTY_SEARCH_TTL_MS);
  return { foods };
}

/** Words for matching: lower case, letters and digits only, a plural "s" dropped ("Bananas, raw" → banana raw). */
function words(text: string): string[] {
  return text.toLowerCase().split(/[^\p{L}\p{N}]+/u).filter(Boolean).map((w) => (w.length > 3 && w.endsWith("s") ? w.slice(0, -1) : w));
}

/**
 * USDA's own order puts "Bananas, dehydrated, or banana powder" before "Bananas, raw" (live check, 2026-11-11), so the
 * results are re-ranked: names that START with the query's words first (the food itself, not a dish with it), then
 * names holding every word; within each, raw before prepared, then the shorter (plainer) name; then USDA's order.
 */
export function rankFoods(query: string, foods: DatabaseFood[]): DatabaseFood[] {
  const q = words(query);
  const score = (food: DatabaseFood) => {
    const name = words(food.name);
    const starts = q.every((w, i) => name[i] === w);
    const all = q.every((w) => name.includes(w));
    // "…, raw" is the food as bought; "…, from raw" is a cooked dish.
    const raw = name.includes("raw") && !/\bfrom raw\b/i.test(food.name);
    return [starts ? 0 : all ? 1 : 2, raw ? 0 : 1, name.length];
  };
  return foods.map((food, index) => ({ food, index, key: score(food) }))
    .sort((a, b) => a.key[0]! - b.key[0]! || a.key[1]! - b.key[1]! || a.key[2]! - b.key[2]! || a.index - b.index)
    .map((x) => x.food);
}

/** The source and its status only — never the code, the query or the key. */
function logUpstream(error: unknown) {
  if (error instanceof Upstream) console.error("food upstream", error.source, error.status);
  else throw error;
}

/** Hourly: expired cache rows and earlier days' counts (two statements). */
export async function pruneFood(env: Env, deps: Deps) {
  const now = deps.now();
  try {
    await env.DB.batch([
      env.DB.prepare("DELETE FROM food_cache WHERE expires_at <= ?").bind(now),
      env.DB.prepare("DELETE FROM food_limits WHERE day < ?").bind(newYorkDay(now - 2 * DAY_MS)),
    ]);
  } catch (error) {
    console.error("food prune failed", error instanceof Error ? error.name : "unknown");
  }
}

import { env } from "cloudflare:test";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import {
  BARCODE_HIT_TTL_MS, BARCODE_MISS_TTL_MS, EMPTY_SEARCH_TTL_MS, FOOD_DAILY_LIMITS, FOOD_USER_AGENT, SEARCH_TTL_MS,
  USDA_GENERIC_TYPES, cleanQuery, fromOpenFoodFacts, normalizeBarcode, pruneFood, tidyName,
} from "../src/food";
import { count, harness, USDA_KEY, type Harness } from "./helpers";

// Nutrition N8: barcode lookups (Open Food Facts, then USDA branded) and search by name (USDA generic foods). Fake
// databases stand in; nothing reaches the network.
let h: Harness;
let session: string;
beforeEach(async () => {
  h = await harness();
  session = (await h.signIn()).session;
});
afterEach(() => vi.restoreAllMocks());

const NUTELLA = "3017620422003";
const COKE_UPC = "049000028911";
const COKE = `0${COKE_UPC}`;
const SHIN = "8801043014809";

/** An Open Food Facts v2 product as the API answers (trimmed to the fields asked for). */
const offProduct = (overrides: Record<string, unknown> = {}) => ({
  code: NUTELLA, product_name: "Nutella", brands: "Ferrero,Nutella", serving_size: "15 g", serving_quantity: "15",
  nutriments: {
    "energy-kcal_100g": 539, "energy-kcal_serving": 80.8, proteins_100g: 6.3, carbohydrates_100g: 57.5, fat_100g: 30.9,
    "saturated-fat_100g": 10.6, fiber_100g: 0, sugars_100g: 56.3, sodium_100g: 0.0428,
    proteins_serving: 0.945, carbohydrates_serving: 8.62, fat_serving: 4.63,
  },
  ...overrides,
});
const offFound = (product = offProduct()) => Response.json({ status: 1, product });
const offMissing = () => Response.json({ status: 0, status_verbose: "product not found" }, { status: 404 });

const nutrient = (nutrientId: number, value: number, unitName = "G") => ({ nutrientId, value, unitName });
/** A USDA branded search result (per 100 g). */
const usdaBranded = (overrides: Record<string, unknown> = {}) => ({
  fdcId: 2_345_678, dataType: "Branded", description: "COCA-COLA CLASSIC", brandOwner: "The Coca-Cola Company",
  brandName: "COCA-COLA", gtinUpc: COKE_UPC, servingSize: 355, servingSizeUnit: "ml", householdServingFullText: "1 can",
  foodNutrients: [nutrient(1008, 39, "KCAL"), nutrient(1003, 0), nutrient(1005, 10.6), nutrient(1004, 0),
    nutrient(2000, 10.6), nutrient(1093, 12.7, "MG")],
  ...overrides,
});
const banana = {
  fdcId: 173_944, dataType: "SR Legacy", description: "Bananas, raw",
  foodNutrients: [nutrient(1008, 89, "KCAL"), nutrient(1003, 1.09), nutrient(1005, 22.84), nutrient(1004, 0.33),
    nutrient(1079, 2.6), nutrient(2000, 12.23), nutrient(1093, 1, "MG")],
  foodMeasures: [
    { disseminationText: "1 medium (7\" to 7-7/8\" long)", gramWeight: 118, rank: 2 },
    { disseminationText: "1 cup, sliced", gramWeight: 150, rank: 1 },
    { disseminationText: "Quantity not specified", gramWeight: 118, rank: 3 },
  ],
};
const usdaAnswer = (foods: unknown[]) => Response.json({ totalHits: foods.length, foods });

const barcode = (code: string, token = session) => h.call("GET", `/v1/food/barcode/${code}`, { token });
const search = (q: string, token = session) => h.call("GET", `/v1/food/search?q=${encodeURIComponent(q)}`, { token });
const body = async (r: Response) => (await r.json()) as any;

describe("barcodes", () => {
  it("Open Food Facts first: normalised per 100 g and per serving, with its User-Agent; USDA not asked", async () => {
    h.food.off = () => offFound();
    const response = await barcode(NUTELLA);
    expect(response.status).toBe(200);
    expect(await body(response)).toEqual({
      found: true,
      food: {
        id: `off:${NUTELLA}`, source: "openFoodFacts", name: "Nutella", brand: "Ferrero", barcode: NUTELLA,
        per100g: { calories: 539, protein: 6.3, carbs: 57.5, fat: 30.9, saturatedFat: 10.6, fiber: 0, sugar: 56.3, sodiumMg: 42.8 },
        // The serving's own numbers as the product gives them; what it does not give per serving stays unknown.
        serving: {
          text: "15 g", grams: 15,
          nutrients: { calories: 80.8, protein: 0.95, carbs: 8.62, fat: 4.63, saturatedFat: null, fiber: null, sugar: null, sodiumMg: null },
        },
        measures: [],
      },
    });
    expect(h.food.offCalls).toHaveLength(1);
    expect(h.food.offCalls[0]!.url).toContain(`/api/v2/product/${NUTELLA}.json?fields=`);
    expect(h.food.offCalls[0]!.userAgent).toBe(FOOD_USER_AGENT);
    expect(FOOD_USER_AGENT).not.toMatch(/@/);  // no personal address in a request
    expect(h.food.usdaCalls).toHaveLength(0);
  });

  it("a serving without its own numbers is scaled from 100 g; kJ-only energy becomes kcal", async () => {
    h.food.off = () => offFound(offProduct({
      serving_size: "1 bar (40 g)", serving_quantity: 40,
      nutriments: { "energy-kj_100g": 2092, proteins_100g: 10, carbohydrates_100g: 60, fat_100g: 20 },
    }));
    const food = (await body(await barcode(NUTELLA))).food;
    expect(food.per100g).toMatchObject({ calories: 500, protein: 10, carbs: 60, fat: 20, sodiumMg: null });
    expect(food.serving).toEqual({
      text: "1 bar (40 g)", grams: 40,
      nutrients: { calories: 200, protein: 4, carbs: 24, fat: 8, saturatedFat: null, fiber: null, sugar: null, sodiumMg: null },
    });
  });

  it("a Korean product: its own name, per 100 g only when it gives no serving", async () => {
    h.food.off = () => offFound(offProduct({
      code: SHIN, product_name: "신라면", brands: "농심", serving_size: undefined, serving_quantity: undefined,
      nutriments: { "energy-kcal_100g": 416, proteins_100g: 8.3, carbohydrates_100g: 63.3, fat_100g: 13.3, sodium_100g: 1.43 },
    }));
    const food = (await body(await barcode(SHIN))).food;
    expect(food).toMatchObject({ id: `off:${SHIN}`, name: "신라면", brand: "농심", serving: null });
    expect(food.per100g.sodiumMg).toBe(1430);
  });

  it("falls back to USDA branded foods: matched by GTIN, the key in a header, the 12-digit UPC as the query", async () => {
    h.food.off = offMissing;
    h.food.usda = () => usdaAnswer([usdaBranded({ fdcId: 1, gtinUpc: "000000000000" }), usdaBranded()]);
    const response = await barcode(COKE_UPC);
    expect(await body(response)).toEqual({
      found: true,
      food: {
        id: "usda:2345678", source: "usda", name: "Coca-Cola Classic", brand: "Coca-Cola", barcode: COKE,
        per100g: { calories: 39, protein: 0, carbs: 10.6, fat: 0, saturatedFat: null, fiber: null, sugar: 10.6, sodiumMg: 12.7 },
        // A drink given per 100 ml: the serving keeps its millilitres, with no grams claimed.
        serving: {
          text: "1 can (355 ml)", grams: null,
          nutrients: { calories: 138.5, protein: 0, carbs: 37.63, fat: 0, saturatedFat: null, fiber: null, sugar: 37.63, sodiumMg: 45.1 },
        },
        measures: [],
      },
    });
    expect(h.food.offCalls[0]!.url).toContain(`/product/${COKE}.json`);
    const call = h.food.usdaCalls[0]!;
    expect(call.apiKey).toBe(USDA_KEY);
    expect(call.url).not.toContain(USDA_KEY);
    expect(call.body).toEqual({ query: COKE_UPC, dataType: ["Branded"], pageSize: 25 });
  });

  it("an Open Food Facts product without calories is not a find: USDA is asked", async () => {
    h.food.off = () => offFound(offProduct({ nutriments: { proteins_100g: 3 } }));
    h.food.usda = () => usdaAnswer([usdaBranded({ gtinUpc: NUTELLA, servingSize: 37, servingSizeUnit: "g",
      householdServingFullText: "2 Tbsp" })]);
    const food = (await body(await barcode(NUTELLA))).food;
    expect(food).toMatchObject({ source: "usda", serving: { text: "2 Tbsp (37 g)", grams: 37 } });
  });

  it("found nowhere: { found: false }, cached a day; then looked up again", async () => {
    const first = await barcode(NUTELLA);
    expect(first.status).toBe(200);
    expect(await body(first)).toEqual({ found: false });
    expect([h.food.offCalls.length, h.food.usdaCalls.length]).toEqual([1, 1]);
    // Cached: neither source is asked again within the day.
    expect(await body(await barcode(NUTELLA))).toEqual({ found: false });
    expect([h.food.offCalls.length, h.food.usdaCalls.length]).toEqual([1, 1]);
    // Expired: the product may have been added since.
    h.clock.now += BARCODE_MISS_TTL_MS;
    h.food.off = () => offFound();
    expect(await body(await barcode(NUTELLA))).toMatchObject({ found: true, food: { name: "Nutella" } });
    expect(h.food.offCalls).toHaveLength(2);
  });

  it("a hit is cached 30 days for everyone, under one key whichever form the code was read in", async () => {
    h.food.off = () => offFound(offProduct({ code: COKE, product_name: "Coca-Cola" }));
    expect(await body(await barcode(COKE_UPC))).toMatchObject({ found: true });
    const other = (await h.signIn("002345.other-user")).session;
    expect(await body(await barcode(COKE, other))).toMatchObject({ found: true, food: { name: "Coca-Cola" } });
    expect(await body(await barcode(`0${COKE}`, other))).toMatchObject({ found: true });
    expect(h.food.offCalls).toHaveLength(1);
    const row = await env.DB.prepare("SELECT key, expires_at - created_at AS ttl FROM food_cache").first<{ key: string; ttl: number }>();
    expect(row).toEqual({ key: `barcode:${COKE}`, ttl: BARCODE_HIT_TTL_MS });
    h.clock.now += BARCODE_HIT_TTL_MS;
    await barcode(COKE_UPC);
    expect(h.food.offCalls).toHaveLength(2);
  });

  it("a source failing with nothing found: 502 food_unavailable, nothing cached", async () => {
    h.food.off = () => new Response("busy", { status: 503 });
    const response = await barcode(NUTELLA);
    expect(response.status).toBe(502);
    expect(await body(response)).toEqual({ error: "food_unavailable" });
    expect(await count("food_cache")).toBe(0);
    // Open Food Facts down, USDA has it: found.
    h.food.usda = () => usdaAnswer([usdaBranded({ gtinUpc: NUTELLA })]);
    expect(await body(await barcode(NUTELLA))).toMatchObject({ found: true, food: { source: "usda" } });
    // USDA failing after an Open Food Facts miss: not a miss to cache.
    h.food.off = offMissing;
    h.food.usda = () => { throw new TypeError("network down"); };
    expect((await barcode(SHIN)).status).toBe(502);
    expect(await count("food_cache")).toBe(1);
  });

  it("without the USDA key: Open Food Facts only, and a miss is not cached (USDA was not asked)", async () => {
    delete h.env.USDA_API_KEY;
    expect(await body(await barcode(NUTELLA))).toEqual({ found: false });
    expect(h.food.usdaCalls).toHaveLength(0);
    expect(await count("food_cache")).toBe(0);
    h.food.off = () => offFound();
    expect(await body(await barcode(NUTELLA))).toMatchObject({ found: true });
  });

  it("refuses codes that are not a GTIN, before counting or asking anyone", async () => {
    for (const code of ["12345", "3017620422004", "abcdefghijklm", "00000000", "30176204220031", "%20" + NUTELLA]) {
      const response = await barcode(code);
      expect(response.status, code).toBe(400);
      expect(await body(response)).toEqual({ error: "invalid_barcode" });
    }
    expect(h.food.offCalls).toHaveLength(0);
    expect(await count("food_limits")).toBe(0);
  });

  it("signed in only", async () => {
    expect((await h.call("GET", `/v1/food/barcode/${NUTELLA}`)).status).toBe(401);
    expect((await barcode(NUTELLA, "not-a-session")).status).toBe(401);
    expect((await h.call("GET", "/v1/food/search?q=banana")).status).toBe(401);
    expect(h.food.offCalls).toHaveLength(0);
  });
});

describe("search by name", () => {
  it("USDA generic foods: per 100 g, household portions by rank, the first as the serving", async () => {
    h.food.usda = () => usdaAnswer([banana, { ...banana, fdcId: 9 }, { fdcId: 10, description: "No energy", foodNutrients: [] }]);
    const response = await search("  Banana ");
    expect(response.status).toBe(200);
    expect(await body(response)).toEqual({
      foods: [{
        id: "usda:173944", source: "usda", name: "Bananas, raw", brand: null, barcode: null,
        per100g: { calories: 89, protein: 1.09, carbs: 22.84, fat: 0.33, saturatedFat: null, fiber: 2.6, sugar: 12.23, sodiumMg: 1 },
        serving: {
          text: "1 cup, sliced", grams: 150,
          nutrients: { calories: 133.5, protein: 1.64, carbs: 34.26, fat: 0.5, saturatedFat: null, fiber: 3.9, sugar: 18.35, sodiumMg: 1.5 },
        },
        measures: [{ text: "1 medium (7\" to 7-7/8\" long)", grams: 118 }],
      }],
    });
    expect(h.food.usdaCalls[0]!.body).toEqual({ query: "Banana", dataType: USDA_GENERIC_TYPES, pageSize: 25 });
  });

  it("caches under the query's hash, any case: a week; nothing found, a day", async () => {
    h.food.usda = () => usdaAnswer([banana]);
    await search("banana");
    await search("BANANA");
    expect(h.food.usdaCalls).toHaveLength(1);
    const row = await env.DB.prepare("SELECT key, body, expires_at - created_at AS ttl FROM food_cache").first<{ key: string; body: string; ttl: number }>();
    expect(row!.key).toMatch(/^search:[0-9a-f]{64}$/);
    expect(row!.key).not.toContain("banana");
    expect(row!.ttl).toBe(SEARCH_TTL_MS);
    h.food.usda = () => usdaAnswer([]);
    expect(await body(await search("zzzz"))).toEqual({ foods: [] });
    const empty = await env.DB.prepare("SELECT expires_at - created_at AS ttl FROM food_cache WHERE body = '[]'").first<{ ttl: number }>();
    expect(empty!.ttl).toBe(EMPTY_SEARCH_TTL_MS);
    h.clock.now += SEARCH_TTL_MS;
    await search("banana");
    expect(h.food.usdaCalls).toHaveLength(3);
  });

  it("without the USDA key: 503 server_not_configured, nothing counted", async () => {
    delete h.env.USDA_API_KEY;
    const response = await search("banana");
    expect(response.status).toBe(503);
    expect(await body(response)).toEqual({ error: "server_not_configured" });
    expect(await count("food_limits")).toBe(0);
  });

  it("USDA failing: 502 food_unavailable, nothing cached", async () => {
    h.food.usda = () => new Response("{}", { status: 429 });
    expect((await search("banana")).status).toBe(502);
    h.food.usda = () => new Response("not json");
    expect((await search("apple")).status).toBe(502);
    expect(await count("food_cache")).toBe(0);
  });

  it("refuses a query that is too short, too long or not text", async () => {
    for (const q of ["", "a", " b ", "x".repeat(101), "ban\u0007ana"]) {
      expect((await search(q)).status, JSON.stringify(q)).toBe(400);
    }
    expect((await h.call("GET", "/v1/food/search", { token: session })).status).toBe(400);
    expect(h.food.usdaCalls).toHaveLength(0);
  });
});

describe("the daily limit", () => {
  it("counts every lookup (cache hits too) per account and kind; resets with the New York day", async () => {
    h.food.off = () => offFound();
    await env.DB.prepare("INSERT INTO food_limits (account_id, day, kind, count) SELECT id, '2026-10-02', 'barcode', ? FROM accounts")
      .bind(FOOD_DAILY_LIMITS.barcode - 1).run();
    expect((await barcode(NUTELLA)).status).toBe(200);
    const refused = await barcode(NUTELLA);
    expect(refused.status).toBe(429);
    expect(await body(refused)).toEqual({ error: "food_limit" });
    // Search has its own count.
    h.food.usda = () => usdaAnswer([banana]);
    expect((await search("banana")).status).toBe(200);
    // Another account is not affected.
    const other = (await h.signIn("002345.other-user")).session;
    expect((await barcode(NUTELLA, other)).status).toBe(200);
    // Midnight in New York (the clock is 08:00 there).
    h.clock.now += 16 * 60 * 60 * 1000;
    expect((await barcode(NUTELLA)).status).toBe(200);
  });

  it("deleted with the account; the shared cache stays; the cron prunes old days and expired rows", async () => {
    h.food.off = () => offFound();
    await barcode(NUTELLA);
    expect(await count("food_limits")).toBe(1);
    expect((await h.call("DELETE", "/v1/account", { token: session })).status).toBe(200);
    expect(await count("food_limits")).toBe(0);
    expect(await count("food_cache")).toBe(1);
    await h.signIn("002345.other-user");
    await env.DB.prepare("INSERT INTO food_limits (account_id, day, kind, count) SELECT id, ?, 'search', 3 FROM accounts")
      .bind("2026-10-02").run();
    // Two days on: today's count (the day before yesterday's) is pruned with the expired cache row; a fresh row stays.
    h.clock.now += 2 * 24 * 60 * 60 * 1000 + 1;
    await env.DB.prepare("INSERT INTO food_cache (key, body, created_at, expires_at) VALUES ('barcode:96385074', 'null', ?, ?)")
      .bind(h.clock.now, h.clock.now + 2 * BARCODE_HIT_TTL_MS).run();
    h.clock.now += BARCODE_HIT_TTL_MS - 2 * 24 * 60 * 60 * 1000;
    await pruneFood(h.env, h.deps);
    expect(await count("food_cache")).toBe(1);
    expect(await count("food_limits")).toBe(0);
  });
});

describe("normalisation helpers", () => {
  it("GTINs: check digit, UPC-A and 14-digit forms to EAN-13, EAN-8 kept", () => {
    expect(normalizeBarcode(COKE_UPC)).toBe(COKE);
    expect(normalizeBarcode(`0${COKE}`)).toBe(COKE);
    expect(normalizeBarcode("96385074")).toBe("96385074");
    expect(normalizeBarcode(NUTELLA)).toBe(NUTELLA);
    expect(normalizeBarcode("3017620422004")).toBeNull();
    expect(normalizeBarcode("1234567")).toBeNull();
  });

  it("queries and names", () => {
    expect(cleanQuery("  chicken \n breast ")).toBe("chicken breast");
    expect(cleanQuery("닭")).toBeNull();
    expect(cleanQuery("닭가슴살")).toBe("닭가슴살");
    expect(tidyName("COCA-COLA CLASSIC")).toBe("Coca-Cola Classic");
    expect(tidyName("Bananas, raw")).toBe("Bananas, raw");
    expect(tidyName("123")).toBe("123");
  });

  it("refuses impossible numbers rather than logging them", () => {
    expect(fromOpenFoodFacts(NUTELLA, offProduct({ nutriments: { "energy-kcal_100g": 4000 } }))).toBeNull();
    expect(fromOpenFoodFacts(NUTELLA, offProduct({ nutriments: { "energy-kcal_100g": -5 } }))).toBeNull();
    expect(fromOpenFoodFacts(NUTELLA, offProduct({ product_name: "  " }))).toBeNull();
    const food = fromOpenFoodFacts(NUTELLA, offProduct({ nutriments: { "energy-kcal_100g": "250", fat_100g: "NaN" } }));
    expect(food?.per100g).toMatchObject({ calories: 250, fat: 0 });
  });
});

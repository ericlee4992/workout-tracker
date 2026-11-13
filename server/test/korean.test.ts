import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { BARCODE_HIT_TTL_MS, BARCODE_MISS_TTL_MS, FOOD_DAILY_LIMITS } from "../src/food";
import {
  type KoreanRow, fromFoodQRLabel, fromKoreanRow, hasHangul, koreanName, matchTier, queryForms, rankKorean,
  representativeRows,
} from "../src/korean";
import { FOODSAFETY_KEY, MFDS_KEY, count, harness, type Harness } from "./helpers";

// Nutrition N12 (D86): a search in Korean (식품영양성분DB: built-in representative items + live brand products) and a
// Korean barcode (Open Food Facts, USDA, Food QR, C005 → report number → 식품영양성분DB). Fakes stand in for every
// service; nothing reaches the network.
let h: Harness;
let session: string;
beforeEach(async () => {
  h = await harness();
  session = (await h.signIn()).session;
});
afterEach(() => vi.restoreAllMocks());

const ONION_RING = "8801043036597";  // 양파링 오리지널 (농심)
const NUTELLA = "3017620422003";

/** A 식품영양성분DB item as the API answers (every value text; numbers with thousands commas; blanks ""). */
const mfdsItem = (overrides: Record<string, unknown> = {}) => ({
  NUM: "140811", FOOD_CD: "P108-001000300-0738", FOOD_NM_KR: "신라면건면사발", DB_GRP_CM: "P", DB_GRP_NM: "가공식품",
  DB_CLASS_NM: "상용제품", SERVING_SIZE: "100g", AMT_NUM1: "370.000", AMT_NUM2: "", AMT_NUM3: "9.09", AMT_NUM4: "5.71",
  AMT_NUM6: "70.13", AMT_NUM7: "6.49", AMT_NUM8: "", AMT_NUM13: "2,117.000", AMT_NUM24: "1.82", Z10500: "77.00g",
  MAKER_NM: "(주)농심", ITEM_REPORT_NO: "2007014900270", SUB_REF_NAME: "식품의약품안전처", ...overrides,
});
const mfdsAnswer = (items: unknown[]) =>
  Response.json({ header: { resultCode: "00", resultMsg: "NORMAL SERVICE." }, body: { pageNo: 1, totalCount: items.length, numOfRows: 30, items } });
const qrAnswer = (items: unknown[]) =>
  Response.json({ header: { resultCode: "00", resultMsg: "NORMAL SERVICE." }, body: { pageNo: 1, totalCount: items.length, numOfRows: 50, items } });
const c005Answer = (rows: unknown[]) =>
  Response.json({ C005: { total_count: String(rows.length), row: rows, RESULT: { MSG: "정상처리되었습니다.", CODE: "INFO-000" } } });
/** One Food QR nutrient row for a basis of `total` g "총 내용량당". */
const qrNutrient = (name: string, amount: string, unit: string, total = "247.000", kind = "총 내용량당") => ({
  BRCD_NO: `0${ONION_RING}`, PRDCT_NM: "양파링 오리지널", NTRTN_INDCT_TCT: total, NTRTN_INDCT_TCD: "g", NTRTN_ICUT_CTV: "0.000",
  NTRTN_ICUT_CVUCD: "g", UCVI_CTA_CD: kind, NIRWMT_NM: name, CTA: amount, IGRD_UCD: unit,
});
const qrLabel = (total = "247.000", kind = "총 내용량당") => [
  qrNutrient("열량", "525.000", "kcal", total, kind), qrNutrient("나트륨", "1,110.000", "mg", total, kind),
  qrNutrient("탄수화물", "57.000", "g", total, kind), qrNutrient("당류", "11.000", "g", total, kind),
  qrNutrient("지방", "27.000", "g", total, kind), qrNutrient("포화지방", "9.000", "g", total, kind),
  qrNutrient("단백질", "14.000", "g", total, kind),
];

const search = (q: string) => h.call("GET", `/v1/food/search?q=${encodeURIComponent(q)}`, { token: session });
const barcode = (code: string) => h.call("GET", `/v1/food/barcode/${code}`, { token: session });
const body = async (r: Response) => (await r.json()) as any;

describe("Korean search", () => {
  it("a Korean query searches 식품영양성분DB, not USDA: the plain food first, brand products after", async () => {
    h.food.mfds = () => mfdsAnswer([mfdsItem({ FOOD_CD: "P1", FOOD_NM_KR: "바나나맛우유", MAKER_NM: "(주)빙그레", SERVING_SIZE: "100mL", Z10500: "240.000mL", AMT_NUM1: "80.00" })]);
    const response = await search("바나나");
    expect(response.status).toBe(200);
    const foods = (await body(response)).foods;
    // "바나나, 생것" is the last of 1,871 matches in the API's own order; ranked here it comes first.
    expect(foods[0]).toMatchObject({ source: "mfds", name: "바나나, 생것", brand: null, per100Unit: "g", serving: null });
    expect(foods.map((f: any) => f.name)).toContain("바나나맛우유");
    expect(foods.length).toBeLessThanOrEqual(10);
    expect(h.food.usdaCalls).toHaveLength(0);
    // Brand products only, by the name as typed without spaces; the key as the API asks for it.
    expect(h.food.mfdsCalls).toEqual([expect.objectContaining({
      serviceKey: MFDS_KEY, type: "json", FOOD_NM_KR: "바나나", DB_CLASS_NM: "상용제품", numOfRows: "30",
    })]);
  });

  it("a live product: per 100 g from the text numbers, its package as the serving, the maker as brand", async () => {
    h.food.mfds = () => mfdsAnswer([mfdsItem()]);
    const foods = (await body(await search("신라면건면"))).foods;
    expect(foods).toContainEqual({
      id: "mfds:P108-001000300-0738", source: "mfds", name: "신라면건면사발", brand: "(주)농심", barcode: null, per100Unit: "g",
      per100g: { calories: 370, protein: 9.09, carbs: 70.13, fat: 5.71, saturatedFat: 1.82, fiber: null, sugar: 6.49, sodiumMg: 2117 },
      serving: {
        text: "1 package (77 g)", grams: 77,
        nutrients: { calories: 284.9, protein: 7, carbs: 54, fat: 4.4, saturatedFat: 1.4, fiber: null, sugar: 5, sodiumMg: 1630.1 },
      },
      measures: [],
    });
  });

  it("a query with spaces is asked as typed and unspaced, merged (codex-review-n12 R1); one syllable is a search (밥)", async () => {
    // The API matches a literal substring: "양파링 오리지널" is found only spaced, "신라면건면" only unspaced.
    h.food.mfds = (params) => mfdsAnswer(params.FOOD_NM_KR === "양파링 오리지널"
      ? [mfdsItem({ FOOD_CD: "P-SPACED", FOOD_NM_KR: "양파링 오리지널" })]
      : params.FOOD_NM_KR === "양파링오리지널" ? [mfdsItem({ FOOD_CD: "P-UNSPACED", FOOD_NM_KR: "양파링오리지널", MAKER_NM: "다른식품(주)" })] : []);
    const ids = (await body(await search("양파링 오리지널"))).foods.map((f: any) => f.id);
    expect(h.food.mfdsCalls.map((c) => c.FOOD_NM_KR).sort()).toEqual(["양파링 오리지널", "양파링오리지널"]);
    expect(ids).toEqual(expect.arrayContaining(["mfds:P-SPACED", "mfds:P-UNSPACED"]));
    // Typed without spaces: one form, one call, its own cache entry (not the spaced query's).
    await search("양파링오리지널");
    expect(h.food.mfdsCalls).toHaveLength(3);
    expect(await count("food_cache")).toBe(2);
    const rice = await search("밥");
    expect(rice.status).toBe(200);
    expect((await body(rice)).foods.length).toBeGreaterThan(0);
  });

  it("a restaurant row without fat or carbs is shown: those macros 0 and marked as not listed (D86)", async () => {
    h.food.mfds = () => mfdsAnswer([mfdsItem({
      FOOD_CD: "D2", FOOD_NM_KR: "떡볶이_로제떡볶이", DB_GRP_CM: "D", MAKER_NM: "치킨플러스", AMT_NUM1: "187.000", AMT_NUM3: "5.03",
      AMT_NUM4: "", AMT_NUM6: "", AMT_NUM13: "436.000", Z10500: "100.000g",
    })]);
    const foods = (await body(await search("로제떡볶이"))).foods;
    expect(foods).toContainEqual(expect.objectContaining({
      id: "mfds:D2", name: "떡볶이, 로제떡볶이", brand: "치킨플러스", notListed: ["carbs", "fat"],
      per100g: expect.objectContaining({ calories: 187, protein: 5.03, carbs: 0, fat: 0 }),
      serving: expect.objectContaining({ text: "1 serving (100 g)" }),
    }));
  });

  it("a row with an invalid number, another basis or no calories is left out", async () => {
    h.food.mfds = () => mfdsAnswer([
      mfdsItem({ FOOD_CD: "X1", FOOD_NM_KR: "가나다라과자1", AMT_NUM3: "-2" }),
      mfdsItem({ FOOD_CD: "X2", FOOD_NM_KR: "가나다라과자2", SERVING_SIZE: "1회" }),
      mfdsItem({ FOOD_CD: "X3", FOOD_NM_KR: "가나다라과자3", AMT_NUM1: "" }),
      mfdsItem({ FOOD_CD: "X4", FOOD_NM_KR: "가나다라과자4", AMT_NUM3: "120" }),  // more protein than 100 g holds
      mfdsItem({ FOOD_CD: "X5", FOOD_NM_KR: "가나다라과자5" }),
    ]);
    expect((await body(await search("가나다라과자"))).foods.map((f: any) => f.id)).toEqual(["mfds:X5"]);
  });

  it("a drink or dish given per 100 mL stays per 100 mL; its portion in mL has no gram weight", async () => {
    h.food.mfds = () => mfdsAnswer([mfdsItem({
      FOOD_CD: "P9", FOOD_NM_KR: "가나다바나나우유", SERVING_SIZE: "100mL", Z10500: "240.000mL", AMT_NUM1: "80.00",
      AMT_NUM3: "2.00", AMT_NUM4: "2.50", AMT_NUM6: "12.50", AMT_NUM13: "30.00",
    })]);
    const milk = (await body(await search("가나다바나나우유"))).foods[0];
    expect(milk).toMatchObject({ per100Unit: "ml", serving: { text: "1 package (240 ml)", grams: null } });
  });

  it("cached a week under its own key; counted as a search; a repeat asks nothing", async () => {
    await search("김치찌개");
    expect(h.food.mfdsCalls).toHaveLength(1);
    const again = await body(await search("김치찌개"));
    expect(again.foods[0]).toMatchObject({ name: "김치찌개", source: "mfds" });
    expect(h.food.mfdsCalls).toHaveLength(1);
    expect(await count("food_cache")).toBe(1);
    const row = await h.env.DB.prepare("SELECT key FROM food_cache").first<{ key: string }>();
    expect(row!.key).toMatch(/^search:ko:live:[0-9a-f]{64}$/);
    const used = await h.env.DB.prepare("SELECT count FROM food_limits WHERE kind = 'search'").first<{ count: number }>();
    expect(used!.count).toBe(2);
  });

  it("one form failing: the other's products still shown, the answer not cached", async () => {
    h.food.mfds = (params) => params.FOOD_NM_KR === "양파링 오리지널"
      ? mfdsAnswer([mfdsItem({ FOOD_CD: "P-SPACED", FOOD_NM_KR: "양파링 오리지널" })])
      : new Response("busy", { status: 503 });
    const ids = (await body(await search("양파링 오리지널"))).foods.map((f: any) => f.id);
    expect(ids).toContain("mfds:P-SPACED");
    expect(await count("food_cache")).toBe(0);
  });

  it("the live API down: the built-in foods alone, not cached; nothing built in either: 502", async () => {
    h.food.mfds = () => new Response("busy", { status: 503 });
    const response = await search("김치찌개");
    expect(response.status).toBe(200);
    expect((await body(response)).foods[0]).toMatchObject({ name: "김치찌개" });
    expect(await count("food_cache")).toBe(0);
    const nothing = await search("쀍쀍없는제품");
    expect(nothing.status).toBe(502);
    expect(await body(nothing)).toEqual({ error: "food_unavailable" });
  });

  it("an error envelope from data.go.kr is a failure, never an empty result to cache", async () => {
    h.food.mfds = () => Response.json({ header: { resultCode: "22", resultMsg: "LIMITED_NUMBER_OF_SERVICE_REQUESTS_EXCEEDS_ERROR" } });
    expect((await search("쀍쀍없는제품")).status).toBe(502);
    h.food.mfds = () => Response.json({ header: { resultCode: "00" }, body: { totalCount: 3 } });
    expect((await search("쀍쀍없는제품")).status).toBe(502);
    expect(await count("food_cache")).toBe(0);
  });

  it("without MFDS_API_KEY: the built-in foods only, no live call, cached apart", async () => {
    delete h.env.MFDS_API_KEY;
    const foods = (await body(await search("김치찌개"))).foods;
    expect(foods[0]).toMatchObject({ name: "김치찌개" });
    expect(h.food.mfdsCalls).toHaveLength(0);
    const row = await h.env.DB.prepare("SELECT key FROM food_cache").first<{ key: string }>();
    expect(row!.key).toMatch(/^search:ko:local:/);
  });

  it("works without the USDA key; a non-Korean search still needs it", async () => {
    delete h.env.USDA_API_KEY;
    expect((await search("김치찌개")).status).toBe(200);
    expect((await search("banana")).status).toBe(503);
  });

  it("synonyms: 계란 finds 달걀, 닭가슴살 the raw chicken breast, 프로틴 protein powder", async () => {
    const names = async (q: string) => (await body(await search(q))).foods.map((f: any) => f.name);
    expect(await names("계란")).toContain("달걀, 생것");
    expect(await names("닭가슴살")).toContain("닭고기, 가슴, 생것");
    expect(await names("프로틴")).toContain("단백질 보충제, 가루");
  });
});

describe("Korean barcodes", () => {
  const qr = (handlers: Record<string, () => Response>) => (operation: string) =>
    handlers[operation]?.() ?? qrAnswer([]);

  it("Open Food Facts has it: its food, whatever the Korean sources say", async () => {
    h.food.off = () => Response.json({ status: 1, product: { product_name: "Original Onion Ring", nutriments: { "energy-kcal_100g": 469, proteins_100g: 6, carbohydrates_100g: 63, fat_100g: 22 } } });
    expect(await body(await barcode(ONION_RING))).toMatchObject({ found: true, food: { source: "openFoodFacts" } });
  });

  it("Food QR's report number → 식품영양성분DB's product, with the barcode; cached 30 days", async () => {
    h.food.foodQR = qr({ getFoodQrProdMnfInfo02: () => qrAnswer([{ BRCD_NO: `0${ONION_RING}`, PRDCT_NM: "양파링 오리지널", IMRPT_NO: "1991046110125" }]) });
    h.food.mfds = (params) => params.ITEM_REPORT_NO === "1991046110125" ? mfdsAnswer([
      // The API's filter matches a prefix: a row for another number is not this product.
      mfdsItem({ FOOD_CD: "P-OTHER", FOOD_NM_KR: "다른과자", ITEM_REPORT_NO: "19910461101259" }),
      mfdsItem({ FOOD_CD: "P-ONION", FOOD_NM_KR: "양파링 오리지널", ITEM_REPORT_NO: "2001054954152/1991046110125", AMT_NUM1: "469.000", Z10500: "84.00g" }),
    ]) : mfdsAnswer([]);
    const found = await body(await barcode(ONION_RING));
    expect(found).toMatchObject({ found: true, food: { id: "mfds:P-ONION", source: "mfds", name: "양파링 오리지널", barcode: ONION_RING, serving: { text: "1 package (84 g)" } } });
    // Food QR is asked by the barcode as 14 digits, with the data.go.kr key.
    expect(h.food.foodQRCalls).toContainEqual({ operation: "getFoodQrProdMnfInfo02", params: expect.objectContaining({ brcd_no: `0${ONION_RING}`, serviceKey: MFDS_KEY }) });
    const cached = await h.env.DB.prepare("SELECT expires_at - created_at AS ttl FROM food_cache WHERE key = ?").bind(`barcode:${ONION_RING}`).first<{ ttl: number }>();
    expect(cached!.ttl).toBe(BARCODE_HIT_TTL_MS);
  });

  it("C005's report number → 식품영양성분DB, its key in the URL path", async () => {
    h.food.c005 = () => c005Answer([{ BAR_CD: ONION_RING, PRDLST_NM: "양파링 오리지널", BSSH_NM: "(주)농심", PRDLST_REPORT_NO: "1991046110125" }]);
    h.food.mfds = (params) => mfdsAnswer(params.ITEM_REPORT_NO === "1991046110125" ? [mfdsItem({ FOOD_CD: "P-ONION", FOOD_NM_KR: "양파링 오리지널", ITEM_REPORT_NO: "1991046110125" })] : []);
    expect(await body(await barcode(ONION_RING))).toMatchObject({ found: true, food: { id: "mfds:P-ONION" } });
    expect(h.food.c005Calls).toEqual([{ key: FOODSAFETY_KEY, code: ONION_RING }]);
  });

  it("Food QR's label when 식품영양성분DB lacks the product: per package as the serving, scaled to 100 g", async () => {
    h.food.foodQR = qr({
      getFoodQrProdMnfInfo02: () => qrAnswer([{ BRCD_NO: `0${ONION_RING}`, PRDCT_NM: "통소시지김밥", IMRPT_NO: "200202215922406" }]),
      getFoodQrProdNsd02: () => qrAnswer(qrLabel()),
    });
    const food = (await body(await barcode(ONION_RING))).food;
    expect(food).toEqual({
      id: `foodqr:${ONION_RING}`, source: "foodQR", name: "통소시지김밥", brand: null, barcode: ONION_RING, per100Unit: "g",
      per100g: { calories: 212.6, protein: 5.67, carbs: 23.08, fat: 10.93, saturatedFat: 3.64, fiber: null, sugar: 4.45, sodiumMg: 449.4 },
      serving: {
        text: "1 package (247 g)", grams: 247,
        nutrients: { calories: 525, protein: 14, carbs: 57, fat: 27, saturatedFat: 9, fiber: null, sugar: 11, sodiumMg: 1110 },
      },
      measures: [],
    });
  });

  it("nothing has numbers: not found, with a Korean name for the app's search; the miss (and name) cached a day", async () => {
    h.food.off = () => Response.json({ status: 1, product: { product_name: "Original Onion Ring" } });
    h.food.c005 = () => c005Answer([{ BAR_CD: ONION_RING, PRDLST_NM: "양파링 오리지널", BSSH_NM: "(주)농심", PRDLST_REPORT_NO: "1991046110125" }]);
    expect(await body(await barcode(ONION_RING))).toEqual({ found: false, name: "양파링 오리지널" });
    const cached = await h.env.DB.prepare("SELECT expires_at - created_at AS ttl FROM food_cache WHERE key = ?").bind(`barcode:${ONION_RING}`).first<{ ttl: number }>();
    expect(cached!.ttl).toBe(BARCODE_MISS_TTL_MS);
    const calls = h.food.c005Calls.length;
    expect(await body(await barcode(ONION_RING))).toEqual({ found: false, name: "양파링 오리지널" });
    expect(h.food.c005Calls).toHaveLength(calls);
  });

  it("only Open Food Facts' name: that name; none at all: no name", async () => {
    h.food.off = () => Response.json({ status: 1, product: { product_name: "Original Onion Ring" } });
    expect(await body(await barcode(ONION_RING))).toEqual({ found: false, name: "Original Onion Ring" });
    await h.env.DB.prepare("DELETE FROM food_cache").run();
    h.food.off = () => Response.json({ status: 0 }, { status: 404 });
    expect(await body(await barcode(ONION_RING))).toEqual({ found: false });
  });

  it("a Korean source failing: still an answer (not 502), but the miss is not cached", async () => {
    h.food.c005 = () => Response.json({ C005: { RESULT: { CODE: "INFO-500", MSG: "서버 오류" } } });
    const response = await barcode(ONION_RING);
    expect(response.status).toBe(200);
    expect(await body(response)).toEqual({ found: false });
    expect(await count("food_cache")).toBe(0);
    h.food.c005 = () => c005Answer([]);
    h.food.foodQR = () => new Response("down", { status: 500 });
    expect((await barcode(ONION_RING)).status).toBe(200);
    expect(await count("food_cache")).toBe(0);
  });

  it("Open Food Facts failing with nothing found anywhere: 502, as N8", async () => {
    h.food.off = () => new Response("busy", { status: 503 });
    expect((await barcode(ONION_RING)).status).toBe(502);
    // …but a Korean source that finds it answers.
    h.food.foodQR = qr({ getFoodQrProdNsd02: () => qrAnswer(qrLabel()) });
    expect(await body(await barcode(ONION_RING))).toMatchObject({ found: true, food: { source: "foodQR" } });
  });

  it("Food QR and C005 rows must name this barcode: missing, other or wrong-typed codes are never used, nor cached (R3)", async () => {
    const label = qrLabel().map((r) => ({ ...r, PRDCT_NM: "다른 제품" }));
    for (const BRCD_NO of [undefined, 12345678, "08801234567893", ""]) {
      await h.env.DB.prepare("DELETE FROM food_cache").run();
      h.food.foodQR = qr({
        getFoodQrProdMnfInfo02: () => qrAnswer([{ BRCD_NO, PRDCT_NM: "다른 제품", IMRPT_NO: "1991046110125" }]),
        getFoodQrProdNsd02: () => qrAnswer(label.map((r) => ({ ...r, BRCD_NO }))),
      });
      h.food.mfds = () => mfdsAnswer([mfdsItem({ FOOD_CD: "P-OTHER", FOOD_NM_KR: "다른 제품", ITEM_REPORT_NO: "1991046110125" })]);
      const response = await barcode(ONION_RING);
      expect(response.status).toBe(200);
      expect(await body(response)).toEqual({ found: false });
      // A reply naming only other products is a failure, not a miss to remember.
      expect(await count("food_cache")).toBe(0);
    }
    h.food.foodQR = () => qrAnswer([]);
    h.food.c005 = () => c005Answer([{ BAR_CD: "8801234567893", PRDLST_NM: "다른 제품", PRDLST_REPORT_NO: "1991046110125" }]);
    expect(await body(await barcode(ONION_RING))).toEqual({ found: false });
    expect(await count("food_cache")).toBe(0);
    // The same code zero-padded is this product.
    h.food.c005 = () => c005Answer([{ BAR_CD: `0${ONION_RING}`, PRDLST_NM: "양파링 오리지널", PRDLST_REPORT_NO: "1991046110125" }]);
    h.food.mfds = () => mfdsAnswer([mfdsItem({ FOOD_CD: "P-ONION", FOOD_NM_KR: "양파링 오리지널", ITEM_REPORT_NO: "1991046110125" })]);
    expect(await body(await barcode(ONION_RING))).toMatchObject({ found: true, food: { id: "mfds:P-ONION" } });
  });

  it("C005's result code reaches the log only in its documented shape (R4)", async () => {
    const logs: string[] = [];
    vi.spyOn(console, "error").mockImplementation((...args: unknown[]) => { logs.push(args.map(String).join(" ")); });
    const sentinel = `${FOODSAFETY_KEY} https://x.test/${ONION_RING}?q=양파링`;
    h.food.c005 = () => Response.json({ C005: { RESULT: { CODE: sentinel, MSG: sentinel } } });
    await barcode(ONION_RING);
    expect(logs).toContain("food upstream c005 malformed");
    await h.env.DB.prepare("DELETE FROM food_cache").run();
    h.food.c005 = () => Response.json({ C005: { RESULT: { CODE: "INFO-300", MSG: "유효 호출건수를 이미 초과하셨습니다." } } });
    await barcode(ONION_RING);
    expect(logs).toContain("food upstream c005 INFO-300");
    for (const line of logs) for (const secret of [FOODSAFETY_KEY, ONION_RING, "https", "양파링"]) expect(line).not.toContain(secret);
  });

  it("a non-Korean code never asks the Korean sources; without their keys a Korean code skips them", async () => {
    await barcode(NUTELLA);
    expect(h.food.foodQRCalls).toHaveLength(0);
    expect(h.food.c005Calls).toHaveLength(0);
    delete h.env.MFDS_API_KEY;
    delete h.env.FOODSAFETY_API_KEY;
    expect(await body(await barcode(ONION_RING))).toEqual({ found: false });
    expect(h.food.foodQRCalls).toHaveLength(0);
    expect(h.food.c005Calls).toHaveLength(0);
    expect(h.food.mfdsCalls).toHaveLength(0);
  });

  it("logs name the source and status only — never a key, the code or a URL", async () => {
    const logs: string[] = [];
    vi.spyOn(console, "error").mockImplementation((...args: unknown[]) => { logs.push(args.map(String).join(" ")); });
    h.food.c005 = () => new Response("down", { status: 500 });
    h.food.foodQR = () => new Response("down", { status: 500 });
    h.food.mfds = () => new Response("down", { status: 500 });
    await barcode(ONION_RING);
    await search("쀍쀍없는제품");
    expect(logs.length).toBeGreaterThan(0);
    for (const line of logs) {
      for (const secret of [MFDS_KEY, FOODSAFETY_KEY, ONION_RING, "쀍쀍", "http"]) expect(line).not.toContain(secret);
    }
  });

  it("each barcode lookup counts once against the daily limit, however many sources are asked", async () => {
    await barcode(ONION_RING);
    const used = await h.env.DB.prepare("SELECT count FROM food_limits WHERE kind = 'barcode'").first<{ count: number }>();
    expect(used!.count).toBe(1);
    expect(FOOD_DAILY_LIMITS.barcode).toBe(200);
  });
});

describe("Korean helpers", () => {
  const row = (overrides: Partial<KoreanRow> = {}): KoreanRow => ({
    code: "R1", name: "바나나, 생것", group: "R", maker: null, unit: "g", portion: null,
    values: { calories: 77, protein: 1.11, fat: 0.2, carbs: 20, sugar: 14.18, fiber: 2.2, sodiumMg: 0, saturatedFat: 0.05 },
    ...overrides,
  });

  it("Hangul detection and names", () => {
    expect(hasHangul("바나나")).toBe(true);
    expect(hasHangul("ramen 라면")).toBe(true);
    expect(hasHangul("ramen")).toBe(false);
    expect(koreanName("김치찌개_돼지고기")).toBe("김치찌개, 돼지고기");
    expect(koreanName("비빔밥_간편조리세트_꼬막비빔밥")).toBe("비빔밥, 간편조리세트, 꼬막비빔밥");
  });

  it("match tiers: the name itself, its first part, a name starting with it, a later part, anywhere", () => {
    const forms = queryForms("바나나");
    expect(matchTier("바나나", forms)).toBe(0);
    expect(matchTier("바나나, 생것", forms)).toBe(1);
    expect(matchTier("바나나칩, 튀긴것", forms)).toBe(2);
    expect(matchTier("과ㆍ채주스_딸기_바나나", forms)).toBe(3);
    expect(matchTier("딸기바나나 스무디", forms)).toBe(4);
    expect(matchTier("사과, 생것", forms)).toBeNull();
    expect(queryForms("계란 후라이")).toEqual(["계란후라이", "달걀후라이"]);
  });

  it("ranking: tier, then raw before dish before product, complete before incomplete, shorter first; one per name and maker", () => {
    const ranked = rankKorean("김밥", [
      row({ code: "P1", name: "김밥", group: "P", maker: "(주)씨제이" }),
      row({ code: "D2", name: "김밥_김치", group: "D", values: { ...row().values, fat: null } }),
      row({ code: "D1", name: "김밥_참치", group: "D" }),
      row({ code: "D3", name: "김밥", group: "D" }),
      row({ code: "D4", name: "김밥", group: "D" }),  // the same name and maker again: kept once
    ]);
    expect(ranked.map((r) => r.code)).toEqual(["D3", "P1", "D1", "D2"]);
  });

  it("a dish's portion is its serving; a raw food has none; a package over 1 kg is not a serving", () => {
    expect(fromKoreanRow(row({ group: "D", name: "김치찌개", portion: 400 }))!.serving).toMatchObject({ text: "1 serving (400 g)", grams: 400 });
    expect(fromKoreanRow(row({ portion: 150 }))!.serving).toBeNull();
    expect(fromKoreanRow(row({ group: "P", name: "바나나모찌", portion: 2000 }))!.serving).toBeNull();
    expect(fromKoreanRow(row({ values: { ...row().values, calories: null } }))).toBeNull();
  });

  it("Food QR labels: one consistent basis only; units must be the expected ones", () => {
    expect(fromFoodQRLabel(ONION_RING, qrLabel(), null)).toMatchObject({ name: "양파링 오리지널", serving: { text: "1 package (247 g)" } });
    // Per 100 g: no serving.
    expect(fromFoodQRLabel(ONION_RING, qrLabel("247.000", "100g당"), null)).toMatchObject({ per100g: { calories: 525 }, serving: null });
    // Two bases (the sesame label gave the same numbers for 200 g and for 1 kg): not used.
    expect(fromFoodQRLabel(ONION_RING, [...qrLabel("200.000"), ...qrLabel("1000.000")], null)).toBeNull();
    // Sodium in grams where mg is expected: the label is not used.
    const label = qrLabel();
    label[1] = qrNutrient("나트륨", "1.11", "g");
    expect(fromFoodQRLabel(ONION_RING, label, null)).toBeNull();
    expect(fromFoodQRLabel(ONION_RING, [], "x")).toBeNull();
  });

  it("the built-in list: one row per name, every row a usable food", () => {
    const rows = representativeRows();
    expect(rows.length).toBeGreaterThan(5_000);
    expect(new Set(rows.map((r) => r.name)).size).toBe(rows.length);
    const unusable = rows.filter((r) => !fromKoreanRow(r));
    // A few survey rows break N8's bounds (e.g. more nutrients than weight); they are left out at search time.
    expect(unusable.length).toBeLessThan(rows.length / 100);
  });
});

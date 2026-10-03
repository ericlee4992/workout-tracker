import { env } from "cloudflare:test";
import { beforeEach, describe, expect, it } from "vitest";
import { count, harness, type Harness } from "./helpers";

// Public beta ticket 05: the training profile on GET/PUT /v1/profile.
let h: Harness;
let session: string;
beforeEach(async () => {
  h = await harness();
  session = (await h.signIn()).session;
});

const training = {
  goals: "Build strength. Get back to a bodyweight pull-up by spring.", experience: "Intermediate", days: 4, minutes: 45,
  height: { value: 70, unit: "in" }, weight: { value: 180.5, unit: "lb" },
};
const put = (body: unknown) => h.call("PUT", "/v1/profile", { token: session, body });
const get = async () => (await (await h.call("GET", "/v1/profile", { token: session })).json()) as Record<string, any>;
const errorOf = async (r: Response) => ((await r.json()) as { error: string }).error;

describe("the training profile", () => {
  it("starts empty, saves, reads back, and keeps height and weight in the units entered (D52)", async () => {
    expect((await get()).training).toBeNull();
    const response = await put({ training });
    expect(response.status).toBe(200);
    expect(((await response.json()) as any).training).toEqual(training);
    expect((await get()).training).toEqual(training);
    // Metric entries stay metric; nothing is converted.
    const metric = { ...training, height: { value: 178, unit: "cm" }, weight: { value: 82, unit: "kg" } };
    await put({ training: metric });
    expect((await get()).training).toEqual(metric);
  });

  it("height and weight are optional; null removes the whole profile", async () => {
    const { height: _h, weight: _w, ...bare } = training;
    await put({ training: bare });
    expect((await get()).training).toEqual({ ...bare, height: null, weight: null });
    await put({ training: null });
    expect((await get()).training).toBeNull();
    expect(await count("training_profiles")).toBe(0);
  });

  it("trims the goal; renaming leaves the training profile alone, and both can change at once", async () => {
    await put({ training: { ...training, goals: "  Get strong  " } });
    expect((await get()).training.goals).toBe("Get strong");
    await put({ displayName: "Alex Kim" });
    expect((await get()).training.goals).toBe("Get strong");
    const both = await put({ displayName: "A. Kim", training });
    expect(await both.json()).toMatchObject({ displayName: "A. Kim", training });
  });

  const invalid: [string, Record<string, unknown>][] = [
    ["a blank goal", { goals: "   " }],
    ["a goal over 1,000 characters", { goals: "a".repeat(1001) }],
    ["a control character", { goals: "hi\u0000" }],
    ["an unknown experience", { experience: "Expert" }],
    ["0 days", { days: 0 }], ["8 days", { days: 8 }], ["2.5 days", { days: 2.5 }],
    ["10 minutes", { minutes: 10 }], ["121 minutes", { minutes: 121 }],
    ["a height in metres", { height: { value: 1.8, unit: "m" } }],
    ["a height under 50 cm", { height: { value: 49, unit: "cm" } }],
    ["a height over 250 cm (99 in = 251 cm)", { height: { value: 99, unit: "in" } }],
    ["a weight over 400 kg (900 lb)", { weight: { value: 900, unit: "lb" } }],
    ["a weight of NaN", { weight: { value: "NaN", unit: "kg" } }],
    ["a height without a unit", { height: { value: 180 } }],
    // Inherited property names are not units (codex-review-05 #1).
    ["a height in 'toString'", { height: { value: 70, unit: "toString" } }],
    ["a weight in 'constructor'", { weight: { value: 80, unit: "constructor" } }],
    ["a height in '__proto__'", { height: { value: 70, unit: "__proto__" } }],
    ["a weight in 'hasOwnProperty'", { weight: { value: 80, unit: "hasOwnProperty" } }],
  ];
  for (const [name, change] of invalid) {
    it(`refuses ${name}, changing nothing`, async () => {
      await put({ training });
      const response = await put({ displayName: "Changed", training: { ...training, ...change } });
      expect([response.status, await errorOf(response)]).toEqual([400, "invalid_training_profile"]);
      const now = await get();
      expect(now.training).toEqual(training);
      expect(now.displayName).not.toBe("Changed");
    });
  }

  it("accepts the bounds exactly: 50 cm, 250 cm, 20 kg, 400 kg, 1 and 7 days, 15 and 120 minutes", async () => {
    for (const change of [
      { height: { value: 50, unit: "cm" }, weight: { value: 20, unit: "kg" }, days: 1, minutes: 15 },
      { height: { value: 250, unit: "cm" }, weight: { value: 400, unit: "kg" }, days: 7, minutes: 120 },
    ]) {
      expect((await put({ training: { ...training, ...change } })).status).toBe(200);
    }
  });

  it("a rename and a training save commit together: a failing write leaves both unchanged", async () => {
    await put({ displayName: "Before", training });
    const { createHandler } = await import("../src/index");
    // The training write fails at the database (a constraint), after the rename statement in the same batch.
    const failing = { ...h.env, DB: new Proxy(h.env.DB, {
      get(target, prop) {
        if (prop === "batch") return async (statements: D1PreparedStatement[]) =>
          target.batch([...statements, target.prepare("INSERT INTO training_profiles (account_id) VALUES (NULL)")]);
        const value = Reflect.get(target, prop);
        return typeof value === "function" ? value.bind(target) : value;
      },
    }) };
    const response = await createHandler(h.deps)(new Request("https://stacked.test/v1/profile", {
      method: "PUT", headers: { authorization: `Bearer ${session}`, "content-type": "application/json" },
      body: JSON.stringify({ displayName: "After", training: { ...training, days: 2 } }),
    }), failing);
    expect(response.status).toBe(500);
    const now = await get();
    expect([now.displayName, now.training.days]).toEqual(["Before", training.days]);
  });

  it("an empty request or a bad name is refused as before", async () => {
    expect((await put({})).status).toBe(400);
    expect((await put({ displayName: "" })).status).toBe(400);
  });

  it("needs a session", async () => {
    expect((await h.call("PUT", "/v1/profile", { body: { training } })).status).toBe(401);
  });

  it("account deletion deletes it", async () => {
    await put({ training });
    expect((await h.call("DELETE", "/v1/account", { token: session })).status).toBe(200);
    expect(await count("training_profiles")).toBe(0);
  });

  it("a save racing the account's deletion writes nothing", async () => {
    const { writeTraining } = await import("../src/training");
    const account = await env.DB.prepare("SELECT id FROM accounts").first<{ id: string }>();
    await h.call("DELETE", "/v1/account", { token: session });
    await expect(writeTraining(h.env, h.deps, account!.id, { ...training, experience: "Intermediate" } as any))
      .rejects.toMatchObject({ code: "unauthorized" });
    expect(await count("training_profiles")).toBe(0);
  });
});

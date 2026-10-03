import { AuthError } from "./apple";
import type { Deps, Env } from "./env";
import { characterCount } from "./text";

// Public beta ticket 05: the training profile, validated against the bounds Ask AI for Templates uses
// (AIRoutineFlowModel.next, AIMinutesControl, the day picker): a goal of 1–1,000 characters, one of three
// experiences, 1–7 days, 15–120 minutes, height 50–250 cm and weight 20–400 kg — checked after converting only for
// the check; what is stored is the value and unit entered (D52).

export const EXPERIENCES = ["Beginner", "Intermediate", "Experienced"] as const;
const INCH_CM = 2.54;
const POUND_KG = 0.45359237;

export interface Measure { value: number; unit: string }
export interface TrainingProfile {
  goals: string;
  experience: (typeof EXPERIENCES)[number];
  days: number;
  minutes: number;
  height: Measure | null;
  weight: Measure | null;
}

function invalid(): never {
  throw new AuthError("invalid_training_profile", 400);
}

function measure(value: unknown, units: Record<string, number>, min: number, max: number): Measure | null {
  if (value === undefined || value === null) return null;
  if (typeof value !== "object" || Array.isArray(value)) invalid();
  const { value: amount, unit } = value as Record<string, unknown>;
  if (typeof unit !== "string" || !(unit in units)) invalid();
  if (typeof amount !== "number" || !Number.isFinite(amount)) invalid();
  const base = amount * units[unit]!;
  if (base < min || base > max) invalid();
  return { value: amount, unit };
}

/** A training profile from a request body, or the reason it is refused. */
export function cleanTraining(raw: unknown): TrainingProfile {
  if (typeof raw !== "object" || raw === null || Array.isArray(raw)) invalid();
  const body = raw as Record<string, unknown>;
  const goals = typeof body.goals === "string" ? body.goals.trim() : "";
  if (goals.length === 0 || characterCount(goals) > 1000 || /[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/.test(goals)) invalid();
  if (typeof body.experience !== "string" || !(EXPERIENCES as readonly string[]).includes(body.experience)) invalid();
  const isInt = (v: unknown, lo: number, hi: number) => typeof v === "number" && Number.isInteger(v) && v >= lo && v <= hi;
  if (!isInt(body.days, 1, 7) || !isInt(body.minutes, 15, 120)) invalid();
  return {
    goals, experience: body.experience as TrainingProfile["experience"], days: body.days as number, minutes: body.minutes as number,
    height: measure(body.height, { cm: 1, in: INCH_CM }, 50, 250),
    weight: measure(body.weight, { kg: 1, lb: POUND_KG }, 20, 400),
  };
}

interface Row {
  goals: string; experience: string; days: number; minutes: number;
  height_value: number | null; height_unit: string | null; weight_value: number | null; weight_unit: string | null;
}

export async function readTraining(env: Env, accountID: string): Promise<TrainingProfile | null> {
  const row = await env.DB.prepare("SELECT * FROM training_profiles WHERE account_id = ?").bind(accountID).first<Row>();
  if (!row) return null;
  return {
    goals: row.goals, experience: row.experience as TrainingProfile["experience"], days: row.days, minutes: row.minutes,
    height: row.height_value === null ? null : { value: row.height_value, unit: row.height_unit! },
    weight: row.weight_value === null ? null : { value: row.weight_value, unit: row.weight_unit! },
  };
}

/** Saves (or, with null, removes) the account's training profile — only while the account exists. */
export async function writeTraining(env: Env, deps: Deps, accountID: string, training: TrainingProfile | null) {
  if (training === null) {
    await env.DB.prepare("DELETE FROM training_profiles WHERE account_id = ?").bind(accountID).run();
    return;
  }
  const result = await env.DB.prepare(
    "INSERT INTO training_profiles (account_id, goals, experience, days, minutes, height_value, height_unit, " +
    "weight_value, weight_unit, updated_at) SELECT ?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10 " +
    "WHERE EXISTS (SELECT 1 FROM accounts WHERE id = ?1) " +
    "ON CONFLICT(account_id) DO UPDATE SET goals = excluded.goals, experience = excluded.experience, " +
    "days = excluded.days, minutes = excluded.minutes, height_value = excluded.height_value, " +
    "height_unit = excluded.height_unit, weight_value = excluded.weight_value, weight_unit = excluded.weight_unit, " +
    "updated_at = excluded.updated_at")
    .bind(accountID, training.goals, training.experience, training.days, training.minutes,
      training.height?.value ?? null, training.height?.unit ?? null, training.weight?.value ?? null,
      training.weight?.unit ?? null, deps.now()).run();
  if ((result.meta.changes ?? 0) === 0) throw new AuthError("unauthorized", 401);
}

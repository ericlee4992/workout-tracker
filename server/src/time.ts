// The app's day for every daily limit is the calendar day in America/New_York (D60; tickets 06 and 07).

const DAY = new Intl.DateTimeFormat("en-CA", { timeZone: "America/New_York", year: "numeric", month: "2-digit", day: "2-digit" });
const CLOCK = new Intl.DateTimeFormat("en-US", {
  timeZone: "America/New_York", hourCycle: "h23", hour: "2-digit", minute: "2-digit", second: "2-digit",
});

/** YYYY-MM-DD in New York. */
export function newYorkDay(ms: number): string {
  return DAY.format(new Date(ms));
}

/** The instant the next New York day starts (when daily limits reset), in ms. DST-safe: probes the hour around it. */
export function nextNewYorkMidnight(ms: number): number {
  const parts = Object.fromEntries(CLOCK.formatToParts(new Date(ms)).map((p) => [p.type, p.value]));
  const sinceMidnight = ((Number(parts.hour) * 60 + Number(parts.minute)) * 60 + Number(parts.second)) * 1000 + (ms % 1000);
  // A first guess 24 h after today's midnight is off by an hour on a DST change day; step to the exact boundary.
  let guess = ms - sinceMidnight + 24 * 60 * 60 * 1000;
  const today = newYorkDay(ms);
  for (const shift of [-60 * 60 * 1000, 0, 60 * 60 * 1000]) {
    const candidate = guess + shift;
    if (newYorkDay(candidate) !== today && newYorkDay(candidate - 1000) === today) return candidate;
  }
  return guess;
}

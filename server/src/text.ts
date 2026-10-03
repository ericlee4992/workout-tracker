/** User-perceived characters, as the app counts them (Swift `String.count`), for limits that mirror the app's. */
export function characterCount(text: string): number {
  let n = 0;
  for (const _ of new Intl.Segmenter("en", { granularity: "grapheme" }).segment(text)) n++;
  return n;
}

/** The first `max` user-perceived characters. */
export function firstCharacters(text: string, max: number): string {
  let out = "";
  let n = 0;
  for (const { segment } of new Intl.Segmenter("en", { granularity: "grapheme" }).segment(text)) {
    if (n++ === max) break;
    out += segment;
  }
  return out;
}

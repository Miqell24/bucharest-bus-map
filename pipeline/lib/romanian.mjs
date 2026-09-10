// Romanian stop names without their diacritics → with them.
//
// TPBI's feed writes the stops the way Romanian keyboards did for twenty
// years: "Piata Gorjului", "Rasaritului", "Soseaua Giurgiului" — 4 242 of the
// 4 264 poles without a single ș, ț, ă, â or î (user report, 10.09.2026: "old
// habits — a pity it is the capital"). The street names on the map come from
// OSM written properly (Piața, Răsăritului, Șoseaua), and the two sit next to
// each other. The feed contains no information about where the marks go, but
// OSM contains the same words: so a dictionary of properly written word forms
// is harvested from the OSM extracts the build already reads (the road names
// and the named places, shops, churches, schools), and every stop name is
// rewritten word by word through it — the Athens rule (lib/greek.mjs there),
// applied to a Latin alphabet.
//
// Only a word the dictionary knows UNAMBIGUOUSLY is touched: the folded form
// must map to one dominant spelling (≥ 60 % of its occurrences) that differs
// from the feed's word by diacritics alone. "Piata" → "Piața" is safe; a fold
// that OSM writes two ways stays as the feed wrote it. Words that already
// carry a mark are left exactly as they are. The comma-below letters are the
// standard (ș ț); the cedilla forms older data carries (ş ţ) are folded to them.

const COMMA = { 'ş': 'ș', 'ţ': 'ț', 'Ş': 'Ș', 'Ţ': 'Ț' };
export const commaBelow = (s) => s.replace(/[şţŞŢ]/g, (c) => COMMA[c]);
const MARKS = /[ăâîșțĂÂÎȘȚşţŞŢ]/;
const fold = (w) => commaBelow(w).normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/[șț]/g, (c) => (c === 'ș' ? 's' : 't')).replace(/[ȘȚ]/g, (c) => (c === 'Ș' ? 'S' : 'T')).toLowerCase();
const WORD = /[A-Za-zĂÂÎȘȚăâîșțŞŢşţ]+/g;
const MIN_SHARE = 0.6;

// A dictionary of properly written word forms, harvested from every name in
// the OSM extracts: folded word → the commonest spelling, if it dominates.
export function buildNameDict(osmDocs) {
  const seen = new Map(); // fold → Map(spelling → count)
  for (const doc of osmDocs) {
    for (const e of doc.elements || []) {
      const name = e.tags && e.tags.name;
      if (!name) continue;
      for (const raw of name.match(WORD) || []) {
        if (raw.length < 3) continue;
        const w = commaBelow(raw).toLowerCase();
        const k = fold(w);
        let m = seen.get(k);
        if (!m) seen.set(k, (m = new Map()));
        m.set(w, (m.get(w) || 0) + 1);
      }
    }
  }
  const dict = new Map();
  let ambiguous = 0;
  for (const [k, m] of seen) {
    let best = null, bestN = -1, total = 0;
    for (const [w, n] of m) { total += n; if (n > bestN) { best = w; bestN = n; } }
    if (!MARKS.test(best)) continue;                 // the dominant form carries no mark: nothing to add
    if (bestN / total < MIN_SHARE) { ambiguous++; continue; }
    dict.set(k, best);
  }
  dict.ambiguous = ambiguous;
  return dict;
}

// Put the feed word's capitalisation on the dictionary form: Title, UPPER or lower.
const recase = (feedWord, form) => {
  if (feedWord === feedWord.toUpperCase()) return form.toUpperCase();
  if (feedWord[0] === feedWord[0].toUpperCase()) return form[0].toUpperCase() + form.slice(1);
  return form;
};

// Rewrite one name word by word. Returns the name unchanged when nothing is known.
export function restoreDiacritics(name, dict) {
  if (!name || !dict) return name;
  return name.replace(WORD, (w) => {
    if (w.length < 3 || MARKS.test(w)) return w;   // already written properly, or too short to judge
    const form = dict.get(fold(w));
    if (!form || fold(form) !== fold(w)) return w;
    return recase(w, form);
  });
}

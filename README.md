# Bucharest & Ilfov Public Transport — interactive map

Interactive, poster-grade map of the public transport network of **Bucharest
and Ilfov county**: STB buses, trolleybuses and trams, the Metrorex metro
(M1–M5, drawn in the official line colors) and the regional bus lines of the
Ilfov operators — ~200 lines drawn along the real street and track geometry.

## Live

**https://miqell24.github.io/bucharest-bus-map/** — GitHub Pages from `main:/docs`.

Everything comes from ONE feed — the TPBI regional GTFS bundle
(https://gtfs.tpbi.ro/regional/) — split by `route_type` at build time:

| mode | route_type | lines | graph |
|---|---|---|---|
| buses | 3 | STB city network + STV / STCM / Regio Serv (Ilfov) | OSM roadways |
| trolleybuses | 11 | STB 61–97, drawn green on the bus network | OSM roadways |
| trams | 0 | STB 1–55 | `railway=tram` tracks |
| metro | 1 | Metrorex M1–M5, official colors from `routes.txt` | `railway=subway` tunnels |

Build quirks worth knowing: TPBI shapes overshoot the termini into depot
access tracks (trimmed to the passenger stretch between the first and last
stop); OSM maps the metro as per-direction tunnel islands that share no
junction nodes (dangling endpoints are welded to the nearest track within
60 m); trams and metro get separate matching graphs — the tunnels run under
streets that carry tram tracks, and a shared graph lured the matcher onto
the wrong rails.

## Stop names: the diacritics put back

TPBI's feed writes its stops the way Romanian keyboards did for twenty years —
"Piata Gorjului", "Rasaritului", "Soseaua Giurgiului": 4 242 of the 4 264 poles
without a single ș, ț, ă, â or î (user report, 10.09.2026). The street names on
the map come from OSM written properly, and the two sit next to each other. The
feed holds no information about where the marks go, but OSM holds the same
words: `pipeline/lib/romanian.mjs` harvests a dictionary of properly written
word forms from the OSM extracts the build reads anyway (the road names) plus
the named objects cut for that purpose (`data/osm/bucharest-names.json` —
places, shops, churches, schools), and rewrites every stop name word by word
through it: 4 362 word forms, 1 880 of the feed's 4 532 stop rows changed, 431
distinct words (Piața ×60, Șoseaua ×43, Școala ×36, Primăria ×27, Grădinița,
București, Ștefan, Țepeș, Brâncuși…). Only a word the dictionary knows
unambiguously is touched — the folded form must map to one dominant spelling
(≥ 60 % of its occurrences, 72 folds OSM writes two ways are left alone) that
differs from the feed's word by diacritics alone; words already carrying a mark
stay as they are, and the cedilla forms older data carries (ş ţ) are folded to
the standard comma-below letters. The Athens rule (`lib/greek.mjs` there),
applied to a Latin alphabet. What stays unaccented is what OSM never writes:
dates ("1 Decembrie 1918"), and names OSM itself spells without marks.

## Pipeline

`npm run download` fetches the TPBI feed, OSM roadways and rails (Overpass,
bbox 44.20–44.80 N / 25.80–26.45 E) and MapLibre GL. `npm run build`
map-matches every line (HMM/Viterbi on the OSM graphs) and writes GeoJSON to
`data/out/`. `npm run serve` hosts the map at http://localhost:8135.

Data: TPBI (STB, Metrorex, STV, STCM, Regio Serv Transport) ·
base map © OpenFreeMap / OpenMapTiles / OpenStreetMap contributors.

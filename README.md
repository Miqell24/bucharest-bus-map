# Bucharest & Ilfov Public Transport — interactive map

Interactive, poster-grade map of the public transport network of **Bucharest
and Ilfov county**: STB buses, trolleybuses and trams, the Metrorex metro
(M1–M5, drawn in the official line colors) and the regional bus lines of the
Ilfov operators — ~200 lines drawn along the real street and track geometry.

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

## Pipeline

`npm run download` fetches the TPBI feed, OSM roadways and rails (Overpass,
bbox 44.20–44.80 N / 25.80–26.45 E) and MapLibre GL. `npm run build`
map-matches every line (HMM/Viterbi on the OSM graphs) and writes GeoJSON to
`data/out/`. `npm run serve` hosts the map at http://localhost:8135.

Data: TPBI (STB, Metrorex, STV, STCM, Regio Serv Transport) ·
base map © OpenFreeMap / OpenMapTiles / OpenStreetMap contributors.

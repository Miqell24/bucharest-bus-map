#!/usr/bin/env bash
# Downloads input data: TPBI GTFS feed, OSM networks (Overpass), MapLibre GL.
# Everything is cached — re-running only fetches what is missing.
#
# ONE feed covers the whole Bucharest–Ilfov region (gtfs.tpbi.ro/regional/):
# STB (buses, trolleybuses, trams), Metrorex (metro M1–M5, with shapes and
# official line colors) and the Ilfov regional operators (STV, STCM, Regio Serv).
# Modes are separated by route_type at build time.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p data/gtfs data/osm web/vendor

# 1) GTFS — the regional bundle (stable URL, refreshed in place by TPBI)
if [ ! -f data/gtfs/routes.txt ]; then
  echo "== TPBI GTFS (Bucharest region) =="
  curl -fL --retry 3 --max-time 600 -o data/bucharest-region.zip \
    "https://gtfs.tpbi.ro/regional/BUCHAREST-REGION.zip"
  unzip -o data/bucharest-region.zip -d data/gtfs
fi

# 2) OSM — roadways over the whole region (GTFS stops extent 44.26–44.75 N,
#    25.87–26.39 E plus margin: Ilfov ring communes on every side)
if [ ! -f data/osm/bucharest.json ]; then
  echo "== Overpass (roads) =="
  Q='[out:json][timeout:900];way(44.20,25.80,44.80,26.45)["highway"~"^(motorway|trunk|primary|secondary|tertiary|unclassified|residential|living_street|service|busway|construction|motorway_link|trunk_link|primary_link|secondary_link|tertiary_link)$"];out geom;'
  ok=0
  for EP in "https://overpass-api.de/api/interpreter" \
            "https://maps.mail.ru/osm/tools/overpass/api/interpreter" \
            "https://overpass.kumi.systems/api/interpreter"; do
    echo "-- $EP"
    if curl -fsS --max-time 900 -o data/osm/bucharest.json --data-urlencode "data=$Q" "$EP" \
       && grep -q '"elements"' data/osm/bucharest.json; then
      ok=1; break
    fi
  done
  [ "$ok" = 1 ] || { echo "Overpass: all mirrors failed" >&2; exit 1; }
fi

# 2b) OSM — rails for the tram+metro mode: tram tracks, metro tunnels
#     (railway=subway; M2/M4/M5 fully underground, M1/M3 partly surface) and
#     light_rail/rail for the shared corridors. Same bbox as the roads.
if [ ! -f data/osm/bucharest-rail.json ]; then
  echo "== Overpass (rails) =="
  QT='[out:json][timeout:300];way(44.20,25.80,44.80,26.45)["railway"~"^(subway|tram|light_rail|rail)$"];out geom;'
  ok=0
  for EP in "https://overpass-api.de/api/interpreter" \
            "https://maps.mail.ru/osm/tools/overpass/api/interpreter" \
            "https://overpass.kumi.systems/api/interpreter"; do
    echo "-- $EP"
    if curl -fsS --max-time 300 -o data/osm/bucharest-rail.json --data-urlencode "data=$QT" "$EP" \
       && grep -q '"elements"' data/osm/bucharest-rail.json; then
      ok=1; break
    fi
  done
  [ "$ok" = 1 ] || { echo "Overpass (rails): all mirrors failed" >&2; exit 1; }
fi

# 3) MapLibre GL (vendored, no CDN at runtime)
if [ ! -f web/vendor/maplibre-gl.js ]; then
  echo "== MapLibre GL =="
  curl -fL --retry 3 -o web/vendor/maplibre-gl.js  https://unpkg.com/maplibre-gl@5.6.1/dist/maplibre-gl.js
  curl -fL --retry 3 -o web/vendor/maplibre-gl.css https://unpkg.com/maplibre-gl@5.6.1/dist/maplibre-gl.css
fi

echo "OK — data ready:"
du -sh data/bucharest-region.zip data/osm/bucharest.json data/osm/bucharest-rail.json 2>/dev/null || true

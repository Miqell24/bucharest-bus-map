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

# A downloaded extract is only accepted if it PARSES and carries a plausible
# number of elements. `grep -q '"elements"'` — the guard this family used
# everywhere — passes on a truncated response too: Brașov's roads arrived as a
# 65 kB fragment that still contained the string, was taken for complete, and
# silently skipped the city (16.08.2026).
# The minimum differs by extract: a road network runs to tens of thousands of
# ways, a city rail network to a few hundred, so the caller passes its own floor
# rather than sharing one.
# A rejected file is deleted rather than left behind — the `[ ! -f … ]` gates
# below only ask whether the file exists, so a fragment on disk would be taken
# for a finished download on the next run.
ok_json () { # $1=file  $2=minimum element count
  python3 - "$1" "$2" <<'PYEOF' 2>/dev/null
import json, sys
try:
    sys.exit(0 if len(json.load(open(sys.argv[1])).get("elements", [])) >= int(sys.argv[2]) else 1)
except Exception:
    sys.exit(1)
PYEOF
}

# 1) GTFS — the regional bundle (stable URL, refreshed in place by TPBI)
#    Checked 2026-09-01: gtfs.tpbi.ro resolves and answers on port 443, but its
#    TLS certificate has EXPIRED, so curl refuses the connection and the whole
#    download step dies. That is the operator's problem to fix, not something to
#    paper over with --insecure: an expired certificate means the transfer is no
#    longer authenticated. The MobilityDatabase keeps an open mirror of exactly
#    this feed (mdb-2098), so the download falls through to it and says so.
if [ ! -f data/gtfs/routes.txt ]; then
  echo "== TPBI GTFS (Bucharest region) =="
  if ! curl -fL --retry 3 --max-time 600 -o data/bucharest-region.zip \
    "https://gtfs.tpbi.ro/regional/BUCHAREST-REGION.zip"; then
    echo "-- gtfs.tpbi.ro unreachable (expired TLS certificate?) — falling back to the MobilityDatabase mirror"
    curl -fL --retry 3 --max-time 600 -o data/bucharest-region.zip \
      "https://files.mobilitydatabase.org/mdb-2098/latest.zip"
  fi
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
       && ok_json "data/osm/bucharest.json" 2000; then
      ok=1; break
    fi
  done
  [ "$ok" = 1 ] || { rm -f data/osm/bucharest.json; echo "Overpass: all mirrors failed" >&2; exit 1; }
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
       && ok_json "data/osm/bucharest-rail.json" 40; then
      ok=1; break
    fi
  done
  [ "$ok" = 1 ] || { rm -f data/osm/bucharest-rail.json; echo "Overpass (rails): all mirrors failed" >&2; exit 1; }
fi

# 3) MapLibre GL (vendored, no CDN at runtime)
if [ ! -f web/vendor/maplibre-gl.js ]; then
  echo "== MapLibre GL =="
  curl -fL --retry 3 -o web/vendor/maplibre-gl.js  https://unpkg.com/maplibre-gl@5.6.1/dist/maplibre-gl.js
  curl -fL --retry 3 -o web/vendor/maplibre-gl.css https://unpkg.com/maplibre-gl@5.6.1/dist/maplibre-gl.css
fi

echo "OK — data ready:"
du -sh data/bucharest-region.zip data/osm/bucharest.json data/osm/bucharest-rail.json 2>/dev/null || true

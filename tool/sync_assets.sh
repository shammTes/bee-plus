#!/usr/bin/env bash
# Copies the web app's content UNCHANGED into Flutter assets. Source of truth stays /workspace/junior/app/content.
set -euo pipefail
SRC=${1:-/workspace/junior/app/content}
DST=$(cd "$(dirname "$0")/.." && pwd)/assets/junior/content
rm -rf "$DST"; mkdir -p "$DST/exams" "$DST/notes" "$DST/media"
for f in "$SRC"/*_g8.json; do case "$(basename "$f")" in topics_index_*) ;; *) cp "$f" "$DST/exams/";; esac; done
cp "$SRC"/notes/*.json "$DST/notes/"
cp -r "$SRC"/notes/svg "$DST/notes/svg"
cp "$SRC"/notes_schema.json "$DST/"
cp "$SRC"/media/* "$DST/media/" 2>/dev/null || true
# index of files (Flutter cannot list asset folders at runtime without the manifest API; this keeps loading explicit)
python3 - "$DST" <<'PY'
import json, os, sys
d = sys.argv[1]
idx = {"exams": sorted(os.listdir(os.path.join(d, "exams"))),
       "notes": sorted(f for f in os.listdir(os.path.join(d, "notes")) if f.endswith(".json") and f != "manifest.json")}
json.dump(idx, open(os.path.join(d, "index.json"), "w"), indent=1)
print(len(idx["exams"]), "papers,", len(idx["notes"]), "notes books")
PY

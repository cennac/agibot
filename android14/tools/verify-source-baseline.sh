#!/usr/bin/env bash
set -euo pipefail

if [[ $# -gt 1 ]]; then
    echo "Usage: ${0##*/} [SOURCE_DIR]" >&2
    exit 2
fi

SOURCE_DIR=${1:-${HOME}/src/agibot-android14}
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
BASELINE_FILE=$SCRIPT_DIR/../baseline/radxa-android14-rkr6.json
failures=0

for tool in git python3; do
    command -v "$tool" >/dev/null 2>&1 || {
        echo "Missing required tool: $tool" >&2
        exit 1
    }
done

[[ -r "$BASELINE_FILE" ]] || {
    echo "Missing baseline file: $BASELINE_FILE" >&2
    exit 1
}
[[ -d "$SOURCE_DIR/.repo/manifests" ]] || {
    echo "Not a repo checkout: $SOURCE_DIR" >&2
    exit 1
}

expected_manifest=$(python3 - "$BASELINE_FILE" <<'PY'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as handle:
    print(json.load(handle)["baseline"]["manifest_revision"])
PY
)
actual_manifest=$(git -C "$SOURCE_DIR/.repo/manifests" rev-parse HEAD)
if [[ "$actual_manifest" != "$expected_manifest" ]]; then
    echo "manifest expected=$expected_manifest actual=$actual_manifest"
    failures=$((failures + 1))
else
    echo "manifest=$actual_manifest"
fi

while IFS=$'\t' read -r logical_path expected_revision; do
    project_dir=$SOURCE_DIR/$logical_path
    if [[ ! -d "$project_dir/.git" && ! -f "$project_dir/.git" ]]; then
        echo "$logical_path missing"
        failures=$((failures + 1))
        continue
    fi
    actual_revision=$(git -C "$project_dir" rev-parse HEAD)
    if [[ "$actual_revision" != "$expected_revision" ]]; then
        echo "$logical_path expected=$expected_revision actual=$actual_revision"
        failures=$((failures + 1))
    else
        echo "$logical_path=$actual_revision"
    fi
done < <(python3 - "$BASELINE_FILE" <<'PY'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as handle:
    baseline = json.load(handle)
for project in baseline["pinned_projects"]:
    print(project["logical_path"], project["revision"], sep="\t")
PY
)

echo "failures=$failures"
exit "$failures"

#!/bin/bash
# apply device/board/opc/common/patches/* to their target repos; skip if unappliable
P=/data/oh/device/board/opc/common/patches
declare -A MAP=(
  [001-build.diff]=build
  [002-base-startup-appspawn.diff]=base/startup/appspawn
  [003-foundation-arkui-gce_engine_lite.diff]=foundation/arkui/ace_engine_lite
  [004-foundation-ability-ability_runtime.diff]=foundation/ability/ability_runtime
  [005-drivers-peripheral-audio.diff]=drivers/peripheral
)
for f in "${!MAP[@]}"; do
  d=/data/oh/${MAP[$f]}
  if [ ! -d "$d" ]; then echo "SKIP $f: no dir $d"; continue; fi
  if git -C "$d" apply --check "$P/$f" 2>/dev/null; then
    git -C "$d" apply "$P/$f" && echo "APPLIED $f -> ${MAP[$f]}"
  else
    echo "SKIP $f (unappliable: already applied or mismatch)"
  fi
done

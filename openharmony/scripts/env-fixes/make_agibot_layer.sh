#!/bin/bash
set -e
B=/data/oh/device/board/opc
V=/data/oh/vendor/opc
if [ -d $B/agibot ]; then echo "board/agibot exists"; else
  cp -a $B/opi5plus $B/agibot
fi
if [ -d $V/agibot ]; then echo "vendor/agibot exists"; else
  cp -a $V/opi5plus $V/agibot
fi
# --- board layer renames ---
cd $B/agibot
grep -rl opi5plus . --include="*.sh" --include="*.gn" --include="*.gni" --include="*.json" --include="*.cfg" 2>/dev/null | while read f; do
  sed -i 's/opi5plus/agibot/g' "$f"
done
mv kernel/configs/orangepi5plus_oh_defconfig kernel/configs/agibot_oh_defconfig 2>/dev/null || true
rm -f kernel/dts/rk3588-orangepi-5-plus*.dts* kernel/dts/rk3588-orangepi*.dtsi kernel/dts/rk3588s-orangepi*.dts* 2>/dev/null || true
# place AGIBOT dts (uploaded separately)
if [ -f /data/agibot.dts.oh ]; then cp /data/agibot.dts.oh kernel/dts/rk3588-agibot-mb0002-v2.dts; fi
echo "board layer done"
# --- vendor layer ---
cd $V/agibot
grep -rl opi5plus . 2>/dev/null | while read f; do
  sed -i 's/opi5plus/agibot/g' "$f"
done
echo "vendor layer done"
ls $B/agibot/ | head -6; ls $V/agibot/ | head -6

#!/bin/bash
set -e
LOG=/data/oh_p0.log
echo "=== fill ohos-sdk sysroot $(date) ===" >> $LOG
cd /data/openharmony_prebuilts
if [ ! -f ohos-sdk-windows_linux-public.tar.gz ]; then
  curl -fSL --retry 3 -o ohos-sdk-windows_linux-public.tar.gz \
    https://repo.huaweicloud.com/openharmony/os/6.0.0.1-Release/ohos-sdk-windows_linux-public.tar.gz >> $LOG 2>&1
fi
mkdir -p /data/openharmony/sdk_x
tar -xzf ohos-sdk-windows_linux-public.tar.gz -C /data/openharmony/sdk_x
NATIVE=$(find /data/openharmony/sdk_x -maxdepth 4 -type d -name native | head -1)
echo "native dir: $NATIVE" >> $LOG
mkdir -p /data/oh/prebuilts/ohos-sdk/linux/20
rm -rf /data/oh/prebuilts/ohos-sdk/linux/20/native
cp -a "$NATIVE" /data/oh/prebuilts/ohos-sdk/linux/20/native
ls /data/oh/prebuilts/ohos-sdk/linux/20/native/sysroot/usr/lib/aarch64-linux-ohos/ | grep -E 'libbundle_ndk|libasset_ndk|libnative_drawing' >> $LOG
echo "=== sdk filled, build again $(date) ===" >> $LOG
cd /data/oh && ./build.sh --product-name opi5plus --ccache >> $LOG 2>&1
echo "BUILD5 rc=$? $(date)" >> $LOG

#!/bin/bash
LOG=/data/oh_p0.log
echo "=== prebuilts_download $(date) ===" >> $LOG
cd /data/oh
bash build/prebuilts_download.sh >> $LOG 2>&1
RC=$?
echo "prebuilts_download rc=$RC $(date)" >> $LOG
if [ $RC -ne 0 ]; then exit 1; fi
echo "=== build retry $(date) ===" >> $LOG
./build.sh --product-name opi5plus --ccache >> $LOG 2>&1
echo "BUILD3 rc=$? $(date)" >> $LOG

#!/bin/bash
# P0 chain: wait repo sync -> lfs pull -> common patches -> build opi5plus
LOG=/data/oh_p0.log
echo "=== chain start $(date) ===" >> $LOG
echo "=== waiting for repo sync ===" >> $LOG
for i in $(seq 1 300); do grep -q 'rc=' /data/oh_sync.log && break; sleep 30; done
RC=$(grep -o 'rc=[0-9]*' /data/oh_sync.log | tail -1)
echo "sync finished: $RC" >> $LOG
if [ "$RC" != "rc=0" ]; then echo "SYNC FAILED - stop" >> $LOG; exit 1; fi

cd /data/oh
echo "=== git lfs pull (device/board/opc) ===" >> $LOG
git lfs install >> $LOG 2>&1
cd device/board/opc
git lfs pull >> $LOG 2>&1
ls -la opi5plus/kernel/kernel_patch/0001-add-rk.patch >> $LOG 2>&1
cd /data/oh

echo "=== apply common patches ===" >> $LOG
bash /data/apply_common_patches.sh >> $LOG 2>&1
echo "patch chain rc=$?" >> $LOG

echo "=== build opi5plus $(date) ===" >> $LOG
./build.sh --product-name opi5plus --ccache >> $LOG 2>&1
echo "BUILD rc=$? $(date)" >> $LOG

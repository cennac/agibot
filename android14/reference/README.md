# External board references

Large source files and all firmware remain outside this directory. Their
provenance and SHA-256 values are recorded in
`baseline/radxa-android14-rkr6.json`.

| Role | Workspace path |
|---|---|
| Original 5.10 vendor DTS, decompiled | `../../agibot.dts` |
| Mainline-oriented minimal DTS | `../openwrt/files/arch/arm64/boot/dts/rockchip/rk3588-agibot-mb0002-v2.dts` |
| Hardware discovery matrix and on-board USB validation | `../docs/HARDWARE-DISCOVERY-20260818.md` |
| Verified 6.1 USB hub reset pulse implementation | `../overlay/usr/local/sbin/agibot-usb-hub-reset` |
| Linux bring-up observations used as board evidence | `../docs/ARMBIAN-LINUX-BRINGUP.md` |
| Original DTB | `../../RK3588-backup/dev-resources/boot/fdt.dtb` |
| Original kernel config | `../../RK3588-backup/dev-resources/kernel/config` |
| Extracted firmware directory | `../../RK3588-backup/dev-resources/firmware/` |

The extraction contains `mali_csffw.bin`, RTL8821CU files, RTL Bluetooth files,
Rockchip DP firmware, and regulatory database files. They are not copied into
Git because of size and licensing. Their presence does not resolve the populated
wireless-module question; runtime identification is still required.

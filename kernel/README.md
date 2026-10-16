# AGIBOT vendor-kernel patches

`setup.sh` copies this directory to `armbian-build/userpatches/kernel/`.
The directory name below it must match Armbian's `KERNELPATCHDIR`.

`rk35xx-vendor-6.1/0001-ASoC-add-ACM8625P-amplifier.patch` vendors the
GPL-2.0 ACM8625P codec driver from:

- https://github.com/Rainm1st/acm86xx-drivers
- source commit: `640bb3ee26b009b0e1c0dcafd274fc84be64e4c7`
- original author: Wenhao Yang `<wenhaoy@acme-semi.com>`

The driver is built in because the original AGIBOT 5.10 kernel also carried it
built in, and the board's `acm8625p-sound` card depends on it during boot.

The matching rootfs firmware is installed as
`overlay/lib/firmware/acm8625p_dsp_stereo_btl_48khz.bin`. ACME's proprietary
tuning output was not present in the original AGIBOT rootfs or the public
driver repository, so this file is an exact export of the GPL driver's
90-byte `dsp_cfg_default` register sequence. It preserves the driver's
previous fallback behavior while satisfying the device-tree firmware request.
Its SHA-256 is
`9a8d3d5542e2a32cada1716ad99efbba661ca31037e6590c2c32419f61ba4ac4`.

`rk35xx-vendor-6.1/0002-net-dwmac-rk-rk3588-optional-legacy-clocks.patch`
uses the kernel optional-clock API for RK3588's legacy `mac_clk_rx`,
`mac_clk_tx`, and `clk_mac_speed` names. These names are absent from the
vendor board DT while the required GMAC clocks are present and both RTL8211F
links operate at 1 Gbps. Other Rockchip SoCs retain the original required-clock
behavior.

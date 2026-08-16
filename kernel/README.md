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

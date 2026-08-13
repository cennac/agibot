# agibot

Reproducible **Armbian** build + flash toolchain for the **AGIBOT MB0002 V2** (RK3588) board.

`git clone --recursive` → `setup.sh` → `start-build.sh` → flash. The 5 WSL2 framework hacks and board config are all committed, so a clean clone compiles without manual patching.

> Full step-by-step (WSL2 pitfalls, 5 framework hacks, verification, flashing): see **[BUILD-GUIDE.md](BUILD-GUIDE.md)** (中文).

## Board Specs
- **SoC**: Rockchip RK3588
- **Board**: AGIBOT MB0002 V2 (IP: 192.168.88.101)
- **Kernel**: Vendor 6.1 BSP (rk-6.1-rkr5.1)
- **Base**: armbian/build, based on rock-5b configuration
- **Release**: Ubuntu 22.04 (jammy) minimal / Ubuntu 24.04 (noble) desktop

## Directory Structure
```
├── armbian-build/              # armbian/build framework (git submodule @ 70a242f)
├── patches/
│   └── wsl2-build-hacks.patch  # 5 WSL2 framework hacks (sync/git/mmdebstrap/fchmod/9p)
├── setup.sh                    # Assemble: init submodule + apply patch + install userpatches
├── start-build.sh              # Build entry: proxy / NO_HOST_RELEASE_CHECK / git resilience / bg log
├── config-agibot.conf          # Main build config (jammy minimal)
├── config-agibot-desktop.conf  # Desktop build config (noble + xfce)
├── config-example.conf         # Example config
├── config/
│   └── boards/
│       └── agibot.conf         # Board definition (u-boot defconfig / fdtfile / boot)
├── customize-image.sh          # ★ overlay injection logic (runs in chroot)
├── overlay/                    # Files injected into rootfs
│   ├── etc/{hostname, systemd/system/resize-rootfs.service}
│   ├── boot/dtb/rockchip/rk3588-agibot-mb0002-v2.dtb   # DT, adapted 5.10 → 6.1
│   └── lib/firmware/           # Mali / DP / RTL8821CU / BT / regulatory
├── flash/                      # eMMC flashing tools
│   ├── rk3588_spl_loader_v1.16.113.bin   # ★ correct RK3588 loader (not RKDevTool's MiniLoaderAll)
│   ├── gen-armbian-cfg.py      # Split img → head/rootfs + generate config.cfg
│   ├── dump-cfg-any.py         # config.cfg inspector
│   └── README.md               # Full flashing guide (中文)
├── wsl-binfmt-setup.sh         # WSL2 qemu binfmt registration
├── ADAPT-NOTES.md              # DT 5.10 → 6.1 adaptation notes
├── BUILD-GUIDE.md              # ★ Complete build tutorial (中文)
└── README.md
```

## Build
Requires WSL2 Ubuntu 22.04+ (see BUILD-GUIDE §1 for setup).
```bash
# 1. Clone with submodule
git clone --recursive https://github.com/cennac/agibot.git
cd agibot

# 2. Assemble (in WSL): init submodule + apply 5 framework hacks + install userpatches
bash setup.sh                   # add --reuse-cache to reuse a sibling armbian-build/cache

# 3. Build (proxy / NO_HOST_RELEASE_CHECK / background log are built-in)
bash start-build.sh
tail -f armbian-build/output/build.log
```
Output: `armbian-build/output/images/Armbian_..._Agibot_jammy_vendor_6.1.115_minimal.img` (~1.7G)

Desktop variant: `./compile.sh agibot-desktop` (see BUILD-GUIDE §10).

## Flash to eMMC
See **[flash/README.md](flash/README.md)**. In short, on the RKDevTool「下载镜像」page add two items and run:
- **Loader** `@0xCCCCCCCC` → `flash/rk3588_spl_loader_v1.16.113.bin`
- **image** `@0x00000000` → the whole-disk `.img` (equivalent to `dd`, no splitting needed)

⚠️ Do **not** use RKDevTool's bundled `MiniLoaderAll.bin` — it is usually an RK356x loader and fails with「下载 boot 失败」. Use the committed RK3588 loader above.

## WSL2 Notes
First-time setup: register qemu binfmt (otherwise chroot fails with `Exec format error`):
```bash
sudo bash wsl-binfmt-setup.sh      # re-run after each WSL restart
```
The other three WSL2 pitfalls (fsync hang, proxy, overlay injection) + 5 framework hacks are handled by `setup.sh` / `start-build.sh` — see BUILD-GUIDE §2.

## Backup
Board backup available as RKFW `update.img` (8.73G) for RKDevTool one-click flash.

## Related Repos
- armbian/build: https://github.com/armbian/build
- RK3588 BSP kernel: https://github.com/armbian/linux-rockchip (branch: rk-6.1-rkr5.1)

# agibot

Armbian build configuration for **AGIBOT MB0002 V2** (RK3588) development board.

## Board Specs
- **SoC**: Rockchip RK3588
- **Board**: AGIBOT MB0002 V2 (IP: 192.168.88.101)
- **Kernel**: Vendor 6.1 BSP (rk-6.1-rkr5.1)
- **Base**: armbian/build, based on rock-5b configuration
- **Release**: Ubuntu 22.04 (jammy)

## Directory Structure
```
├── config-agibot.conf          # Main build configuration
├── config/
│   └── boards/
│       └── agibot.conf         # Board definition
├── overlay/
│   ├── etc/
│   │   ├── hostname            # agibot
│   │   └── systemd/system/
│   │       └── resize-rootfs.service  # Auto-resize on first boot
│   ├── boot/dtb/rockchip/
│   │   └── rk3588-agibot-mb0002-v2.dtb  # Device tree (from 5.10 BSP, for 6.1)
│   └── lib/firmware/
│       ├── mali_csffw.bin      # Mali GPU firmware
│       ├── rockchip/dptx.bin   # DisplayPort firmware
│       ├── rtl8821cu_*         # RTL8821CU WiFi firmware
│       ├── rtlbt/              # Bluetooth firmware
│       └── regulatory.db       # Wireless regulatory database
├── wsl-binfmt-setup.sh         # WSL2 qemu binfmt registration
└── README.md
```

## Build
```bash
# Clone armbian/build
git clone --depth=1 https://github.com/armbian/build armbian-build
cd armbian-build

# Copy userpatches
cp -r agibot-armbian/config agibot-armbian/overlay ./userpatches/
cp agibot-armbian/config-agibot.conf ./

# Build
./compile.sh agibot EXPERT=yes
```

Output: `output/Armbian_agibot.img`

## WSL2 Notes
If building on WSL2, run `wsl-binfmt-setup.sh` first to register qemu binfmt handlers:
```bash
sudo bash wsl-binfmt-setup.sh
```

## Backup
Board backup available as RKFW `update.img` (8.73G) for RKDevTool one-click flash.

## Related Repos
- armbian/build: https://github.com/armbian/build
- RK3588 BSP kernel: https://github.com/armbian/linux-rockchip (branch: rk-6.1-rkr5.1)

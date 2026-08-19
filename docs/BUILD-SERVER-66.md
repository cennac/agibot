# Armbian on the 66 build server

This is the reproducible procedure used to build the AGIBOT Armbian image on the Ubuntu 26.04 server at `192.168.88.66`. The examples assume the SSH user is `cennac`; use your normal SSH authentication method and do not store the password in the repository.

## Tested environment

- Host: Ubuntu 26.04 LTS, 20 CPU cores, 30 GiB RAM
- Build root: `/home/cennac/agibot-armbian`
- Armbian framework: submodule commit `70a242faa308c57be5ed636897dfee77de350773`
- Repository baseline: `cennac/agibot@78e2875d329ec8156e0e3180fed9ded47b29a758`
- Proxy: `http://192.168.88.128:7897`
- GHCR mirror: `nju`

The successful build on 2026-08-20 took 49 minutes 43 seconds from a cold cache and produced:

```text
Agibot-Armbian_26.08.0-trunk_Agibot_jammy_vendor_6.1.115_minimal.img
SHA256: 00b4a79e520803a188d79045a937272881328d141ca512e5d2e77bf6cfc53569
```

## 1. Clone with the proxy

```bash
cd ~
export http_proxy=http://192.168.88.128:7897
export https_proxy=http://192.168.88.128:7897
export ftp_proxy=http://192.168.88.128:7897
export all_proxy=http://192.168.88.128:7897
export no_proxy='localhost,127.0.0.1,::1,192.168.0.0/16,10.0.0.0/8,.tuna.tsinghua.edu.cn,.bfsu.edu.cn,.aliyun.com,.ustc.edu.cn,github.armbian.com'
export NO_PROXY="$no_proxy"

git clone https://github.com/cennac/agibot.git agibot-armbian
cd agibot-armbian
```

GitHub direct connections timed out from this server, while the proxy above worked. Keep local LAN addresses and Chinese package mirrors in `no_proxy`.

## 2. Install host dependencies

On Ubuntu 26.04, `qemu-user-static` is effectively replaced by the binfmt package. If the generic dependency script fails on that package name, install `qemu-user-binfmt` directly:

```bash
sudo apt update
sudo apt install -y \
  git curl ca-certificates build-essential \
  qemu-user-binfmt binfmt-support device-tree-compiler \
  e2fsprogs cpio
sudo systemctl restart systemd-binfmt
test -f /proc/sys/fs/binfmt_misc/qemu-aarch64
```

The final `test` command must succeed; otherwise the arm64 rootfs chroot will later fail with `Exec format error`.

## 3. Assemble and build

```bash
cd ~/agibot-armbian
bash setup.sh
```

On this native Linux ext4 path, `setup.sh` initializes the pinned Armbian submodule, skips the WSL2-only filesystem patch, and installs the board userpatches.

Start the build in a root environment so later loop-device, mount, and chroot operations do not stop to ask for `sudo` after the script has already detached into the background:

```bash
sudo env \
  http_proxy=http://192.168.88.128:7897 \
  https_proxy=http://192.168.88.128:7897 \
  ftp_proxy=http://192.168.88.128:7897 \
  all_proxy=http://192.168.88.128:7897 \
  no_proxy='localhost,127.0.0.1,::1,192.168.0.0/16,10.0.0.0/8,.tuna.tsinghua.edu.cn,.bfsu.edu.cn,.aliyun.com,.ustc.edu.cn,github.armbian.com' \
  NO_PROXY='localhost,127.0.0.1,::1,192.168.0.0/16,10.0.0.0/8,.tuna.tsinghua.edu.cn,.bfsu.edu.cn,.aliyun.com,.ustc.edu.cn,github.armbian.com' \
  bash start-build.sh
```

`start-build.sh` runs this Armbian command in the background and writes the complete log:

```bash
./compile.sh agibot EXPERT=yes DOWNLOAD_MIRROR=china
```

## 4. Monitor progress

```bash
cd ~/agibot-armbian/armbian-build
tail -f output/build.log
```

Useful completion checks:

```bash
grep -a FINISHED_EXIT output/build.log
find output/images -maxdepth 1 -type f -printf '%s %f\n' | sort -nr
```

`FINISHED_EXIT=0` means success. If it is nonzero, inspect the tail of `output/build.log` and the matching UUID log under `output/logs/`; do not delete `cache/`, because the kernel and rootfs caches make a retry much faster.

## 5. Validate and retrieve

On the server:

```bash
cd ~/agibot-armbian/armbian-build/output/images
sha256sum -c Agibot-Armbian_26.08.0-trunk_Agibot_jammy_vendor_6.1.115_minimal.img.sha

cd ~/agibot-armbian
bash scripts/verify-image.sh \
  armbian-build/output/images/Agibot-Armbian_26.08.0-trunk_Agibot_jammy_vendor_6.1.115_minimal.img
```

The 2026-08-20 build passed checksum verification and all 12 image-content checks, including the Agibot DTB, 6.1 DT adaptations, ACM8625P firmware in rootfs and initramfs, resize service, hostname, and branding.

From another Linux machine, retrieve the image with visible transfer progress:

```bash
rsync -av --partial --info=progress2 \
  cennac@192.168.88.66:/home/cennac/agibot-armbian/armbian-build/output/images/Agibot-Armbian_26.08.0-trunk_Agibot_jammy_vendor_6.1.115_minimal.img \
  cennac@192.168.88.66:/home/cennac/agibot-armbian/armbian-build/output/images/Agibot-Armbian_26.08.0-trunk_Agibot_jammy_vendor_6.1.115_minimal.img.sha \
  cennac@192.168.88.66:/home/cennac/agibot-armbian/armbian-build/output/images/Agibot-Armbian_26.08.0-trunk_Agibot_jammy_vendor_6.1.115_minimal.img.txt \
  ./
```

Then verify the downloaded copy against its `.sha` file before writing it to media.

## Repository-state note

The successful server build used the repository baseline above plus two locally synchronized changes: `start-build.sh` exports `core.filemode=false`, and `overlay/etc/issue` starts with `Agibot-Armbian`. Push those changes before doing a completely fresh clone-and-build if you want the branding check to pass without manually copying files again. The filemode setting is mainly useful for a Windows/DrvFs checkout; it is harmless on the server's ext4 filesystem.

# scripts/ — 辅助脚本

让「clone → 编译 → 刷机 → 验证」全流程不依赖仓库外的任何东西。所有脚本跨平台(WSL2 / Linux / macOS),路径全部脚本相对,**无 `/mnt/e` 硬编码**。

## 速查表

| 脚本 | 何时跑 | 作用 |
|---|---|---|
| `install-deps.sh` | **首次,每台机器一次** | 装 git / curl / build-essential / qemu-user-static / binfmt-support / device-tree-compiler;WSL2 另注册 binfmt + systemd override;macOS 检 Docker |
| `preflight.sh` | 编译**前** / 卡住时 | 确认 WSL2 patch 是否 apply、上次 build.log 失败阶段、缓存命中、shellcheck 直连 |
| `build-status.sh` | 编译**进行中**(另开终端) | build.log 尾、编译进程、images/ 产物、kernel clone 进度 |
| `verify-image.sh` | 编译**完成后** | 无需启动板子,debugfs 读 ext4 验证 dtb / firmware / service / hostname 是否进了镜像 + dtb 适配是否生效 |

## 典型流程

```bash
git clone --recursive https://github.com/cennac/agibot.git && cd agibot

bash scripts/install-deps.sh   # ① 首次装依赖(每台机器一次)
bash setup.sh                  # ② 装配 submodule + patch + userpatches
bash preflight.sh 2>/dev/null; bash scripts/preflight.sh   # ③(可选)编译前体检
bash start-build.sh            # ④ 编译(后台)
bash scripts/build-status.sh   # ⑤(另开终端)盯进度
bash scripts/verify-image.sh   # ⑥ 编完验证产物
```

## 逐个说明

### install-deps.sh
```bash
bash scripts/install-deps.sh
```
- **WSL2 / Linux**:`apt install` 编译依赖 + 注册 qemu-aarch64 binfmt(交叉编译 arm64 rootfs 必需,否则 chroot 报 `Exec format error`)。WSL2 额外做 systemd-binfmt 的 `ConditionVirtualization=` override(BUILD-GUIDE 坑①)。
- **macOS**:armbian 走 Docker,只检 Docker Desktop 是否运行(binfmt/qemu 在 macOS 原生跑不了,必须 Docker)。
- 幂等,可重复跑。

### preflight.sh
```bash
bash scripts/preflight.sh
```
查五件事,帮你定位「为什么编译卡住」:
1. **fsync patch** —— `host-utils.sh` 的 `wait_for_disk_sync` 函数体(WSL2 坑②是否生效)
2. **失败阶段** —— build.log 里 `shellcheck / SSL_ERROR / uboot / FAILED` 的具体行
3. **内核缓存** —— `cache/sources/linux-*` 是否已下载(决定是否要重新 clone 内核源码)
4. **rootfs / memoize 缓存** —— 命中可省大段时间
5. **shellcheck 直连** —— curl github releases,验证代理是否生效(HTTP 200 才算通)

### build-status.sh
```bash
bash scripts/build-status.sh
```
编译跑起来后**另开一个终端**跑,看:`build.log` 最后 22 行(去 ANSI 色)、`FINISHED_EXIT` 出现次数、相关进程、`images/` 产物、kernel 源码 du 大小(clone 进度)。

### verify-image.sh
```bash
bash scripts/verify-image.sh                       # 自动找最新 Armbian-*.img
bash scripts/verify-image.sh path/to/Armbian_*.img # 指定镜像
```
**不刷板子**直接验证产物(对应 BUILD-GUIDE §7):
- (1) agibot dtb 是否进了 `boot/dtb-*/rockchip/`
- (2) dtb 5.10→6.1 适配是否生效(`iommu-av1d` compatible)
- (3) Mali/ACM8625P firmware（ACM 同时校验 rootfs 与 initramfs）、Armbian 官方扩容服务、hostname、armbianEnv 的 fdtfile

依赖 `debugfs`(e2fsprogs)和 `fdtget`(device-tree-compiler),install-deps.sh 已装。

---

板子刷完后的回归测试见 **`flash/`**:`postflash-test.sh`(CAN/UART/GPIO/watchdog/NPU/温度)和 `npu_test.py`(RKNN smoke test),详见 [flash/README.md](../flash/README.md)。

# flash — AgiBot MB0002 (RK3588) Armbian 刷机

把 `armbian-build` 编译出的 Armbian 镜像刷进板载 **eMMC**。

> **硬性前提**:镜像头部必须包含 AGIBOT 专用 U-Boot 标识
> `rk3588-agibot-mb0002-v2`。2026-08-14 之前使用
> `rock-5b-rk3588_defconfig` 构建的镜像会停在 BL31 跳转 BL33 后，禁止刷入。
>
> `gen-armbian-cfg.py` 会检查这个标识；检查失败时不会生成刷机配置。

## 需要的文件

| 文件 | 位置 | 说明 |
|---|---|---|
| 整盘镜像 `Armbian-...minimal.img` | `../armbian-build/output/images/` | 自建产物,~1.67 GiB,kernel 6.1.115 / jammy / vendor |
| `rk3588_spl_loader_v1.16.113.bin` | **本目录(已入库)** | MASKROM 转 LOADER 的临时下载器，不定义 GPT 或板级 U-Boot |

loader SHA256 = `4cc43c2ff29e08b5491b4d52528346aa7da6948128c17e670ff8a000029c9408`(487 872 字节)
⚠️ **别用 RKDevTool 安装目录自带的 `MiniLoaderAll.bin`** —— 多半是 RK356x 的,会报「下载 boot 失败 / Sent(0)」。这是刷不动的头号原因,不是 USB 线。

---

## 方法一:整盘写,不拆分

先运行方法二中的生成脚本完成 U-Boot 板型校验。只有脚本输出下面一行时，
整盘写入才允许继续：

```text
U-Boot DTB: rk3588-agibot-mb0002-v2 [OK]
```

### 1. 板子进 MASKROM
断电 → **按住板载 MASKROM 按键** → 上电 → 松开 → USB-C 连电脑。
RKDevTool 底部状态栏显示 `Found One MASKROM Device`。

### 2. RKDevTool「下载镜像」页配置
顶部切到 **「下载镜像」** 页 → 右键列表**清空默认项** → 右键 **「添加项目」** 两项:

| 项 | 名称 | 地址 | 文件 |
|---|---|---|---|
| 1 | `Loader` | `0xCCCCCCCC` | 本目录 `rk3588_spl_loader_v1.16.113.bin` |
| 2 | `image`  | `0x00000000` | `../armbian-build/output/images/Armbian-...minimal.img`(整盘) |

两项都勾选 → 点 **「执行」**。

**地址含义**:
- `0xCCCCCCCC` 不是真地址,是 Rockchip 的标记值 —— RKDevTool 看到它就执行"下 loader → MASKROM 转 LOADER",不写 flash、不算扇区。
- `0x00000000` = 从 LBA0 开始写,**写入长度 = 文件本身大小**(按扇区自动取整,无需手填)。整盘 img 多大就写多大,精确到字节。

执行顺序(自动):先下 Loader 项(进 LOADER)→ 再从 LBA0 把整个 img 顺序写满。

### 3. 重启
显示 `下载完成` → 右键设备 → **重启设备**。首次启动 Armbian 会自动扩容 rootfs,等 1–2 分钟。

### 如果板子已经在 LOADER 模式
(按 RECOVERY 键上电,或状态栏已显示 LOADER)→ loader 已在跑,**Loader 项别勾**,只留 `image@0x00000000` 一项直接执行。

---

## 方法二(备选):拆分写

本目录的 `gen-armbian-cfg.py` 会先检查 AGIBOT U-Boot，再从整盘 img 拆出
head/rootfs 并生成 config.cfg：

```bash
# 在仓库根(flash/ 的上一层),Windows 或 WSL Python 均可
python flash/gen-armbian-cfg.py
#   自动找 ../armbian-build/output/images/ 下最新的 Armbian-*.img
#   拆成 flash/armbian-head.img (16MiB) + flash/armbian-rootfs.img
#   生成 flash/config.cfg(路径已转 Windows 格式)
# 指定 img:
python flash/gen-armbian-cfg.py --img /path/to/Armbian-xxx.img
```

拆分依据(head 与 rootfs 在 flash 上首尾相接,拼起来 = 整盘 dd):

| 文件 | 写入地址 | 内容 |
|---|---|---|
| `armbian-head.img` (16 MiB) | `0x00000000` (0) | LBA 0–32767:保护 MBR + GPT + RKNS idbloader + u-boot |
| `armbian-rootfs.img` (1.65 GiB) | `0x00008000` (32768) | LBA 32768–末尾:rootfs 分区 + 备份 GPT |

**操作**:「下载镜像」页 → **「选择配置文件」** → 选 `flash/config.cfg`(已配好 Loader + head@0 + rootfs@32768 三项)→ 勾选 → 执行。

拆分不会改变启动链，也不会修复不兼容的 U-Boot。它只用于绕过 RKDevTool
单个大文件写入问题。

校验/排查 config.cfg 内容:
```bash
python flash/dump-cfg-any.py flash/config.cfg
```

---

## config.cfg 二进制格式(逆向记录)

config.cfg 是定长二进制,布局(逆向自能用的 oneshot 配置,RKDevTool v2.86/2.92/v3.37 同格式):

```
29B header:  "CFG" + 19B 零 + [22]=item 槽位数 + [23..28]=固定尾缀 1d 00 00 00 62 02
8 x 610B item: label UTF16-LE@[2:82], path UTF16-LE@[82:602](520B), addr LE@602, sel LE@606
```

⚠️ **头部尾缀 `1d 00 00 00 62 02`(offset 23–28)+ item 计数(offset 22)缺一不可**。
全填零会让 RKDevTool 读到 itemcount=0、**导入 config.cfg 即崩溃**。
`gen-armbian-cfg.py` 已正确写出(`CFG` + 19 零 + `08` + `1d 00 00 00 62 02`)。

config.cfg 内存的是 **Windows 绝对路径**。bundle 搬位置或换盘符后,重跑 `gen-armbian-cfg.py` 即可(脚本自动写当前正确路径)。

---

## 其他备选

### rkdeveloptool 整盘写(Linux / WSL)
```bash
rkdeveloptool db  rk3588_spl_loader_v1.16.113.bin   # 下 loader 进 LOADER
rkdeveloptool wl 0 <整盘.img>                       # 整盘写到 LBA0
rkdeveloptool rd                                    # 重启
```
> 二进制在 `../armbian-build/cache/sources/rkbin-tools/tools/rkdeveloptool`(Linux x86-64,WSL 可跑)。
> Windows 下需 usbipd-win 把 USB 设备直通进 WSL。

### SD 卡 dd(不碰 eMMC,最稳的验证方式)
```bash
sudo dd if=../armbian-build/output/images/Armbian-...minimal.img of=/dev/sdX bs=4M status=progress conv=fsync
```
插卡,板子置 SD 启动。镜像本身能跑后再刷 eMMC。

---

## 文件清单

```
flash/
├── README.md                          本文档
├── rk3588_spl_loader_v1.16.113.bin    RK3588 loader(入库,固定不变)
├── gen-armbian-cfg.py                 方法二:自动拆分 img + 生成 config.cfg
└── dump-cfg-any.py                    config.cfg 校验/排查工具
```
> 整盘 img、head.img、rootfs.img、config.cfg **都不入库**——由 `gen-armbian-cfg.py` 从你编译出的 img 现场生成;方法一直接用整盘 img,连生成都不需要。

---

## 重新构建镜像

镜像由上层 `armbian-build` submodule 产出(仓库根脚本):

```bash
# WSL Ubuntu 内, 在仓库根
bash setup.sh         # 装配 submodule + patch + userpatches(首次)
bash start-build.sh   # 编译(含代理 / NO_HOST_RELEASE_CHECK / 后台日志)
# 产物: armbian-build/output/images/Armbian-...minimal.img
```

重建后方法一直接用新整盘 img;方法二重跑 `gen-armbian-cfg.py` 即自动重新拆分。

---

## 内容已校验(构建批次 2026-08-13)

- 整盘 img / head.img 偏移 `0x8000`(LBA64) = `RKNS` magic ✓
- rootfs.img 偏移 `0x438` = ext4 superblock magic `EF 53` ✓
- loader SHA256 已核对 ✓

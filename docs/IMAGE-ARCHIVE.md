# 本地镜像归档规范

AGIBOT MB0002 的大镜像不提交 Git。唯一归档根目录为：

```text
E:\AIPorject\101\agibot-releases\
```

源码仓库、`flash/`、工作区根目录和构建输出目录都不是长期归档位置。
`flash/` 只保留 loader、刷机脚本和测试脚本；刷机时直接从发布归档选择整盘镜像。

## 目录规则

```text
agibot-releases/
├── armbian/
│   ├── validated/    已完成实机验收，可作为回滚基线
│   ├── candidates/   构建及离线检查完成，尚未完成实机验收
│   ├── archive/      历史构建或阶段性试验，不建议日常刷入
│   ├── quarantine/   文件内容、名称或历史元数据不一致，禁止刷入
│   └── derived/      head/rootfs 等可再生拆分产物
├── android/          Android 发布镜像（当前仍由 android14-flash 管理）
├── openwrt/          OpenWrt/LEDE 发布镜像
└── fnos/             飞牛系统发布镜像
```

版本目录统一使用：

```text
YYYY-MM-DD-<variant>-<sha256前8位>
```

每个可刷版本至少保存整盘 `.img` 和实际重新计算的 `SHA256SUMS.txt`。有构建说明时一并
保留，但历史 `.sha` 与实际镜像不一致时必须移入 `quarantine/`，不能继续作为校验依据。

## 当前 Armbian 基线

- 实机验证回滚基线：`armbian/validated/2026-08-14-stable-v3-2dc05ed4/`
- 品牌候选版：`armbian/candidates/2026-08-18-branded-df777c1e/`
- 当前板上用于蓝牙交叉验证的镜像 SHA-256：
  `2dc05ed4e388cb8187d2c4a92f8cc1de45926c70cd0a4b3a11c6b8cac411da91`

`quarantine/2026-08-14-rebuild-label-mismatch-c28f0b70/` 原目录名含
`f850f7e8`，但 2026-08-27 重新计算实体镜像得到 `c28f0b70...`，且尺寸也与原
`RELEASE.md` 不一致。推测归档镜像曾通过 NTFS hard link 被后续构建原地改写；因此
旧 `f850f7e8` 实体已不能从该目录恢复。后续归档禁止用可被构建器覆盖的 hard link。

## 刷机选择原则

1. 正常回滚只使用 `validated/`。
2. `candidates/` 必须先核对 SHA-256，再进行明确的上板验收。
3. `archive/` 仅用于问题复现。
4. `quarantine/` 禁止刷入，除非重新完成镜像身份检查并迁出。
5. `derived/` 不作为发布镜像；需要时优先由整盘镜像重新生成。

## 2026-08-27 迁移说明

本次只迁移和分类，不改写镜像内容。迁移前散落位置包括工作区根目录、
`agibot-armbian/flash/` 和 `agibot-releases/` 根目录。迁移后 Armbian 镜像全部集中到
`agibot-releases/armbian/`，原路径不再使用。详细文件哈希见归档根目录的
`README.md` 与各版本的 `SHA256SUMS.txt`。

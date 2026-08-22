# WSL Ubuntu source workspace

## Audit result

Audited on 2026-08-22 with `tools/audit-wsl-ubuntu.sh`:

| Item | Result |
|---|---|
| Distribution | Ubuntu 24.04 Noble |
| WSL version | WSL 2 |
| Architecture | x86_64 |
| Kernel | `5.15.153.1-microsoft-standard-WSL2` |
| Root filesystem | About 955 GiB available |
| Required tools | `git`, `python3`, and `curl` available |
| Optional tools | `repo`, `jq`, `xmllint`, and `dtc` missing at audit time |
| Network | Radxa manifest Git endpoint reachable directly; raw GitHub was intermittent on recheck |
| Proxy | `http_proxy` and `https_proxy` unset |

The Ubuntu Store launcher existed, but no WSL distribution had been initialized
for the current Windows user. It was registered non-interactively as WSL2 before
the audit. No Android packages were installed during the audit.

## Source location

Use an ext4 path inside WSL, not `/mnt/e`, for a future full Android checkout:

```text
~/src/agibot-android14
```

Reasons:

- avoids DrvFS metadata and symlink performance penalties;
- avoids Windows antivirus scanning a multi-hundred-gigabyte source tree;
- keeps Linux executable and case-sensitivity behavior predictable;
- keeps this adaptation directory separate from the large source checkout.

The adaptation directory remains at:

```text
/mnt/e/AIPorject/101/agibot-armbian/android14
```

## Ubuntu 24.04 caveat

Ubuntu 24.04 is adequate for Phase 1 source preparation and static inspection.
Android 14 BSP build scripts are more commonly validated on Ubuntu 20.04 or
22.04. Before any future build, use the BSP's documented package set or a
compatible 22.04 container. This phase intentionally performs no compilation.

## Windows PATH warning

WSL currently appends the Windows `PATH`. That is convenient for interop but
can expose Windows executables to source scripts. For a dedicated build distro,
consider setting the following in `/etc/wsl.conf` and restarting that distro:

```ini
[interop]
appendWindowsPath=false
```

No WSL configuration was changed during Phase 0.

Before running `repo init`, configure Git identity and disable repo's
interactive color prompt:

```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
git config --global color.ui never
```

## Preparing the source tree

Do not copy ROCK 5C images or clone unrelated repositories into this adaptation
repository. The preparation script keeps the full Android tree separate:

If Gerrit's repo-tool URL is unreachable, clone the official repository once and
point the script at the local mirror:

```bash
cd /mnt/e/AIPorject/101/agibot-armbian/android14
tools/prepare-source-sync.sh --source-dir ~/src/agibot-android14
```

```bash
git clone https://github.com/GerritCodeReview/git-repo.git \
  ~/.local/share/git-repo
ln -s ~/.local/share/git-repo/repo ~/.local/bin/repo
export REPO_URL=~/.local/share/git-repo
export REPO_REV=v2.66.1
```

That command performs environment checks and `repo init` only. To explicitly
download the source later, add `--sync`:

```bash
tools/prepare-source-sync.sh \
  --source-dir ~/src/agibot-android14 \
  --sync \
  --repo-jobs 8
```

If the WSL image does not provide the `repo` launcher, add
`--install-repo` only when you want the script to download it to
`~/.local/bin/repo`. After syncing, verify every locked revision:

```bash
tools/verify-source-baseline.sh ~/src/agibot-android14
```

## Current initialization state

- WSL source directory: `/root/src/agibot-android14`
- Manifest commit: `ac6785b31865b06223ae262c8ed42b14b11f5aaa`
- Manifest entry: `rockchip-u1-release.xml`
- Repo tool: `v2.66.1`, commit `b85886fa9f5b4e2189cc5b2f40bd0a80459d4c77`
- `repo sync` has **not** been executed.
- Full project revision verification is pending until the source is synced.

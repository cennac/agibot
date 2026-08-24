# Remote Android build host

## Decision

The full Android 14 source checkout and all future build output are hosted on
the remote Ubuntu machine at `192.168.88.66`, under `/data`. The remote root
filesystem has limited free space, but `/data` is a large independent volume;
keeping source, caches, and output there avoids repeating the WSL dynamic-VHDX
space problem.

The workspace layout is:

```text
/data/agibot-android14-build/
  android14/       Copied adaptation metadata and tooling
  aosp/            Full repo checkout
  tools/git-repo/  Pinned git-repo source
  tools/repo       Symlink to the pinned launcher
  out/             Reserved build output location
```

The unrelated project `/data/fnos-3588` is not part of this adaptation and must
not be modified.

## Locked source initialization

The checkout uses the same locked baseline as the local metadata:

| Item | Value |
|---|---|
| Manifest URL | `https://github.com/radxa/manifests.git` |
| Manifest branch | `Android14-rkr6-rock5c` |
| Manifest file | `rockchip-u1-release.xml` |
| Manifest commit | `ac6785b31865b06223ae262c8ed42b14b11f5aaa` |
| Repo tool | `v2.66.1` |
| Repo revision | `b85886fa9f5b4e2189cc5b2f40bd0a80459d4c77` |

The recommended bounded sync command is:

```bash
cd /data/agibot-android14-build/aosp
PATH=/data/agibot-android14-build/tools:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
  /data/agibot-android14-build/tools/repo sync -c -j4
```

Sync and repair logs are kept beside the checkout as `repo-sync.log`,
`repo-repair.log`, `repo-trace.log`, and `repo-sync-sdk-repair.log`. The active
sync PID is written to `repo-sync.pid`.

## Checkout repair, 2026-08-23

The first resumed sync reported worktree initialization failures for:

- `platform/external/armnn`
- `external/camera_engine_rkaiq`

Both backing Git object stores and manifest revisions were present. Manual
`read-tree` reproduction showed that checkout failed because the remote host did
not have `git-lfs`, while the projects' Git filters invoke
`git-lfs filter-process --skip`.

`git-lfs` was installed from Ubuntu packages. The incomplete worktrees were
moved to `/data/agibot-android14-build/partial-checkouts-20260823-1029/` for
traceability, after which both projects checked out successfully with:

```bash
repo sync -c -j1 --fail-fast \
  external/armnn external/camera_engine_rkaiq
```

The original sync process had remained active after logging those checkout
errors, so starting a second full sync created duplicate fetches. The older
process was terminated with SIGTERM and the post-repair process was retained.

## Environment caveat

The host currently runs a future Ubuntu release. Android 14 Rockchip BSPs are
more commonly validated on Ubuntu 20.04 or 22.04. Before compilation, inspect
the BSP's documented package set and prefer a compatible container if host
package versions are incompatible. Keep any container storage and build output
under `/data`.

Compilation was authorized on 2026-08-24. The environment caveat above remains,
but the product, kernel, and full-build attempts are now recorded in
`docs/10-build-validation.md`.

## Source download completion, 2026-08-24

The full TUNA-backed sync completed after the single `prebuilts/sdk` checkout
repair described in `docs/08-source-download.md`. The final checkout contains
1236 repo projects and occupies about `674G`; `/data` retained roughly `2.0T`
free space. The locked-baseline verifier reported `failures=0`.

The `.repo/manifests` checkout intentionally carries the one-line
`prebuilts/sdk` repair as an uncommitted diff. Its `HEAD` remains the locked
manifest revision, so the baseline verifier can still detect an accidental
manifest update. Reapply `tools/fix-radxa-sdk-manifest.sh` after any deliberate
manifest re-initialization.

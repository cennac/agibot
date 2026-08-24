# Android 14 source download log

This document records the remote source download process, including failed
routes and the reasons for the current strategy. It is intentionally kept in
this repository because those details affect reproducibility and future sync
performance.

## Timeline

### 2026-08-23 morning: checkout repair

- The remote checkout had complete object data and manifest revisions for
  `external/armnn` and `external/camera_engine_rkaiq`, but their worktrees
  could not be checked out.
- Reproduction with `git read-tree` showed that their Git filters called
  `git-lfs`; the build host did not yet have `git-lfs`.
- Ubuntu `git-lfs` was installed, the two incomplete worktrees were moved to
  `/data/agibot-android14-build/partial-checkouts-20260823-1029/`, and the two
  projects were successfully checked out with a bounded `repo sync`.
- The older overlapping sync process was terminated to avoid duplicate fetches.

### 2026-08-23 afternoon: official AOSP route and proxy failure

- The Rockchip/GitLab portion of the manifest had already been fetched.
  Remaining failures were concentrated on AOSP `android.googlesource.com`
  repositories.
- The Windows Clash listener was verified to be on port `7897`; stale Git proxy
  configuration referred to `7890`.
- The remote Git proxy was corrected to `http://192.168.88.128:7897` for the
  AOSP and GitHub hosts, with HTTP/1.1 forced.
- The proxy route remained unstable for multi-gigabyte packfiles. In particular,
  `external/chromium-webview` transferred roughly 9.6 GiB and then failed with a
  GnuTLS stream error. Small repositories worked, but this route was unsuitable
  for the remaining AOSP prebuilt repositories.

### 2026-08-23 afternoon: TUNA mirror route

- The AOSP commit served by the TUNA mirror was checked against the official
  `android-14.0.0_r27` expectation for `external/chromium-webview`; the commit
  matched `9aa46b97ac83b3e1e85cd7a58fe0787f4068307a`.
- The remote global Git rewrite was configured as:

  ```bash
  git config --global \
    url.https://mirrors.tuna.tsinghua.edu.cn/git/AOSP/.insteadOf \
    https://android.googlesource.com/
  ```

- A single bounded sync was then started under the locked repo configuration:

  ```bash
  cd /data/agibot-android14-build/aosp
  PATH=/data/agibot-android14-build/tools:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    /data/agibot-android14-build/tools/repo sync -c -j4
  ```

- It is logged in `/data/agibot-android14-build/repo-sync-mirror.log`, with the
  process identifier in `/data/agibot-android14-build/repo-sync.pid`.
- Do not start another full sync while that PID is active.

## Final sync observations

At the 21:25 CST checkpoint on 2026-08-23:

- Current sync PID: `3024042`.
- Continuous runtime: about five hours.
- Checkout size: about `416G`.
- `/data` remained comfortably below capacity, with roughly `2.3T` free.
- No `Failing repos` list or GnuTLS failure had appeared in the mirror-sync log.
- Large repositories that had completed or remained active included
  `external/chromium-webview`, `kernel/prebuilts/5.10/arm64`,
  `prebuilts/android-emulator`, `prebuilts/clang/host/linux-x86`,
  `prebuilts/clang/host/darwin-x86`, `prebuilts/rust`, `prebuilts/sdk`, and
  `prebuilts/tools`.
- Reused repositories did not retain shallow markers, so `repo` fetched broader
  ref/object data than a fresh `clone-depth=1` checkout would. This explains the
  very large checkout size and should be considered before any future
  re-initialization.
- Failed earlier attempts left `tmp_pack_*` files in project object stores.
  They may be useful evidence for diagnosing the network route and can also
  consume substantial space. They must not be deleted while a fetch is active.
  Cleanup should happen only after the final sync and baseline verification.

The full mirror sync eventually transferred the remaining large repositories
and exited after approximately 11.4 hours. Its only failure was the
`prebuilts/sdk` checkout.

## 2026-08-24: prebuilts/sdk manifest repair

The full sync reported:

```text
error.GitError: Cannot checkout platform/prebuilts/sdk
fatal: cannot update ref 'HEAD': trying to write non-commit object
cd99dbe8b79005f8fcda159e996211e3f019dd57
```

`cd99dbe8b79005f8fcda159e996211e3f019dd57` is an annotated tag object for
`android-14.0.0_r27`, not a commit. The Radxa manifest uses it directly as the
project revision. Git can set `HEAD` only to the commit peeled from that tag:
`92e2a80095695a40fa854fff44268e0bc333c154`.

The reproducible repair is:

```bash
bash tools/fix-radxa-sdk-manifest.sh /data/agibot-android14-build/aosp

cd /data/agibot-android14-build/aosp
PATH=/data/agibot-android14-build/tools:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
  /data/agibot-android14-build/tools/repo sync -c -j1 --fail-fast prebuilts/sdk
```

The single-project repair completed in 45.113 seconds and printed:

```text
repo sync has finished successfully.
```

The result is recorded on the build host in
`/data/agibot-android14-build/repo-sync-sdk-repair.log`.

## Final verification

The repaired source tree was checked with:

```bash
cd /data/agibot-android14-build/android14
bash tools/verify-source-baseline.sh /data/agibot-android14-build/aosp
```

It reported `failures=0` and matched:

- Manifest: `ac6785b31865b06223ae262c8ed42b14b11f5aaa`
- `device/rockchip/rk3588`: `4e9794df017bd56f50d8835f95dfdb8b39abf90f`
- `device/rockchip/common`: `7e6116f5fe4f29797d242115f8fd1ddf4a3363da`
- `vendor/rockchip/common`: `13bbb25125ce0aea9e988aaa2b31c3f8e159af30`
- `vendor/rockchip/hardware`: `90dfdbc85a4a2e787f1541ce1f3fc1bbb8b6b49d`
- `u-boot`: `fba0c8f28039e0f253ada4a71613ae1dd401c864`
- `kernel-6.1`: `aaf1830c6647a51523704d5e21c39a7705d3e79d`

Final checkout facts:

- 1236 repo projects.
- About `674G` occupied by the source and reused object stores.
- About `2.0T` still free on `/data`.
- The `.repo/manifests` checkout intentionally has the one-line
  `prebuilts/sdk` repair as an uncommitted local diff; its `HEAD` remains the
  locked manifest revision.

Cleanup of obsolete `tmp_pack_*` files is now safe only after confirming no Git
or repo process is active, but it has not been performed because those files are
still useful evidence for the failed network routes and space is not constrained.

This document covers source synchronization only. Compilation was later
authorized and is recorded separately in `docs/10-build-validation.md`; image
flashing remains outside the current phase.

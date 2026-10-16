# Versioning and change control

The outer `agibot-armbian` repository owns this directory. Android 14 work is
versioned alongside Armbian and LEDE, but changes must remain separable by path
and commit scope.

## Branches

- The outer repository's `main` branch contains reviewed board work.
- An Android change must leave `tools/validate-no-build.ps1` passing and must
  not mix unrelated Armbian or LEDE modifications into the same commit.
- A focused Android branch may be created later for experimental kernel or
  product integration.

Do not mix exploratory Android, Armbian, and LEDE edits in one commit. Merge
only after the relevant static checks and documentation are updated together.

## Tags

- The former standalone repository retains `phase/0-baseline` as audit
  provenance for the imported contents.
- Later tags are created only after a named milestone is complete, not merely
  because files changed.

## Commit convention

Use imperative subjects with a scope:

```text
baseline: lock Radxa Android 14 RKR6 source revisions
device: add AGIBOT MB0002 product skeleton
dts: document initial HDMI0 bring-up policy
```

Keep baseline changes, board DTS changes, and Android product-policy changes in
separate commits so they can be reviewed independently.

## Baseline immutability

The revisions in `baseline/radxa-android14-rkr6.json` are locked. A baseline
update must add the new revision IDs and retrieval date, explain the reason in
`docs/00-baseline.md`, list expected migration effects in the same commit, and
advance the phase or add an explicit revision suffix when incompatible.

## Binary policy

This directory tracks source, configuration, provenance, and hashes. It does
not track full Android repositories, firmware binaries, vendor blobs, bootloader
images, recovery images, or build products. A firmware item may be referenced by
workspace-relative path and hash, but not copied here.

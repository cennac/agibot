# Android 14 default locale policy

## Requirement

AGIBOT MB0002 V2 should complete first-boot setup in Simplified Chinese. The
device remains a normal tablet/desktop Android product and continues to expose
the locale picker so other languages can be selected manually.

## Implementation

The AGIBOT product definition reorders the inherited AOSP `PRODUCT_LOCALES`
list after all common product inheritance:

```make
PRODUCT_LOCALES := zh_CN $(filter-out zh_CN,$(PRODUCT_LOCALES))
```

Android's build system derives `ro.product.locale` from the first entry and
converts the underscore form to `zh-CN`. The remaining inherited locales are
retained, so this changes only the default rather than removing other language
resources.

Repeating `ro.product.locale` through `PRODUCT_PROPERTY_OVERRIDES` is avoided
because `build/make/core/sysprop.mk` already generates that read-only property
from `PRODUCT_LOCALES`; a duplicate assignment could produce conflicting
build.prop entries.

## Runtime behavior

- Fresh userdata or a factory reset starts with `zh-CN`.
- Existing userdata keeps the user-selected locale after an OTA-style system
  update; this is expected Android behavior.
- The first supported locale is the default, but language selection remains
  available in Android Settings.

## Source control and build record

Remote device project:

```text
project: device/rockchip/rk3588
branch:  agibot/android14-rkr6
commit:  a512f711f28f3b2c514527c9d26ac279cf7b432f
subject: agibot: default to Simplified Chinese
```

Local replay patch:

```text
android14/patches/0006-device-agibot-default-simplified-chinese.patch
```

The incremental `systemimage` regeneration is recorded at:

```text
/data/agibot-android14-build/logs/2026-08-25-default-locale-systemimage.log
```

The regeneration was started with `BUILD_BROKEN_DISABLE_BAZEL=true` to avoid
the previously observed Bazel mixed-build graph expansion. Static validation
passed before the build was launched.

The currently flashed board was also switched immediately with:

```text
settings put system system_locales zh-CN
```

This is a user preference change and does not by itself prove the new first-boot
default; the regenerated `system.img` must still expose
`ro.product.locale=zh-CN`.

# Android 14 r17 AP6275P inbound Bluetooth wake fix

Date: 2026-08-26

## Reason for r17

r16 proved that the Android Bluetooth framework is issuing the standard
Classic discoverability command (`HCI Write Scan Enable`, opcode `0x0C1A`,
parameter `0x03`) and that the controller can receive Windows inquiry results.
The remaining failure was the reverse direction: Windows could not discover
`MB0002 V2`, and Android pairing attempts timed out during `GET_REM_NAME` with
`HCI_ERR_PAGE_TIMEOUT` before Windows showed a PIN prompt.

The Windows adapter is independently known to work with this computer's
headset and mouse, and Android can discover the computer.  The evidence points
to the AP6275P inbound page/inquiry response path rather than a Windows scan
problem.

## Source finding

The r14 change disabled the AP6275P controller sleep mode by sending
`sleep_mode=0` for `ro.product.device=agibot_mb0002`.  However, the vendor
configuration still had:

```text
BT_WAKE_VIA_PROC = TRUE
PROC_BTWRITE_TIMER_TIMEOUT_MS = 0
BT_WAKE_VIA_PROC_NOTIFY_DEASSERT = TRUE
```

With this configuration `upio_set(UPIO_BT_WAKE, UPIO_DEASSERT, ...)` writes
`0` to `/proc/bluetooth/sleep/btwrite` after an idle HCI transaction.  That
proc node controls the AP6275P BT_WAKE GPIO on the board.  Controller LPM is
disabled, so deasserting this host-wake line provides no power-saving benefit
and can prevent the controller from answering an inbound inquiry or page.

## r17 change

Patch `0032-broadcom-keep-bt-wake-agibot.patch` changes the generated Broadcom
vendor configuration to:

```text
BT_WAKE_VIA_PROC_NOTIFY_DEASSERT = FALSE
```

The vendor HAL will continue asserting `btwrite` when HCI traffic starts but
will no longer send the deassert notification.  Existing r14 LPM disabling,
r15 OTP address preservation, and the r16 91,900-byte HCD rollback remain
unchanged.

## Validation plan

1. Apply the patch to the remote AOSP checkout and rebuild the targeted
   `libbt-vendor` (32-bit and 64-bit).
2. Verify the generated `vnd_buildcfg.h` contains
   `BT_WAKE_VIA_PROC_NOTIFY_DEASSERT 0` and the build log records the r17
   source commit.
3. Build the complete `vendorimage`, `superimage`, and normalized `update.img`
   as a new r17 release; keep r16 available for rollback.
4. After a later flash, verify `bt_default_wake` remains asserted while
   Bluetooth is discoverable and repeat exactly one Windows reverse-discovery
   and pairing attempt.  Success requires Windows to list `MB0002 V2` and the
   attempt to reach `BOND_BONDED` instead of `HCI_ERR_PAGE_TIMEOUT`.

No device flash is performed in this r17 source stage.

## Build record

The change was applied to the remote AOSP Broadcom repository and committed as:

```text
a59f43d broadcom: keep AP6275P BT_WAKE asserted on AGIBOT
```

The targeted vendor build completed successfully for both 32-bit and 64-bit
`libbt-vendor` targets.  The build emitted only the existing deprecated-header
warnings and no compiler or linker errors.

Targeted log:

```text
/data/agibot-android14-build/logs/2026-08-26-r17-bt-wake-targeted-build.log
```

The complete image build was then started in the background with a separate
log.  Its output and final `update.img` hash will be added here when the build
finishes:

```text
/data/agibot-android14-build/logs/2026-08-26-r17-bt-wake-full-build.log
```

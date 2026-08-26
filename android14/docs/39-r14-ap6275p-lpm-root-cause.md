# Android 14 r14 AP6275P low-power root cause

Date: 2026-08-26

## Root cause

r13 proved that switching from extended scan command `0x2041` to legacy scan
command `0x200b` did not by itself fix discovery. Both commands timed out only
after Bluetooth had initialized and remained idle.

The Broadcom vendor HAL enables controller UART low-power mode with vendor
command `0xfc27`. On this Rockchip kernel, writes to
`/proc/bluetooth/sleep/lpm` are accepted but the handler is an empty stub. The
separate `/proc/bluetooth/sleep/btwrite` handler controls the AP6275P BT_WAKE
GPIO. At failure time `bt_default_wake` was low and the controller did not
respond to the first scan command.

## Discriminating runtime test

With the unchanged r13 payload, ADB root manually wrote `1` to the kernel
`btwrite` node. The debug GPIO state changed from low to high. Settings pairing
was then launched inside the wake window.

```text
PID before: 2706
PID after:  2706
bt_default_wake: out hi
```

The pairing page remained active with its scan progress indicator. There was no
`0x200b` timeout, HCI timeout, fatal signal, or Bluetooth process restart. This
isolates the failure to the low-power wake path rather than the LE scan opcode.

An earlier non-root write was denied and did not alter GPIO state. Its following
scan repeated the known timeout and is not evidence for or against the wake
hypothesis.

## r14 source change

Patch `0026-broadcom-disable-lpm-ap6275p.patch` changes the Broadcom vendor HAL
only for `ro.product.device=agibot_mb0002`. When Android requests controller LPM,
the HAL sends `sleep_mode=0` in `Write Sleep Mode (0xfc27)` and emits:

```text
AGIBOT AP6275P: controller low-power mode disabled
```

The change keeps the controller awake and avoids dependence on the incomplete
host-wake integration. Existing UART, legacy scan, and unsupported vendor
offload fixes remain unchanged.

## Acceptance

After building and flashing r14:

1. Confirm the r14 vendor library hash and the LPM-disable log.
2. Leave Bluetooth idle for at least 30 seconds before discovery.
3. Run one Settings pairing scan for at least 30 seconds.
4. Require one stable Bluetooth PID with no `0x200b`, `0x2041`, `0xfd57`, or
   `0xfd59` timeout and no fatal signal.
5. Confirm at least one actual remote device appears before testing pairing.

## Build artifact

The Broadcom patch passed `git apply --check` and was committed in the remote
project as:

```text
8322435 broadcom: disable controller LPM on AGIBOT AP6275P
```

Both 32-bit and 64-bit `libbt-vendor` targets were recompiled and linked. The
vendor and super images were then rebuilt, followed by the BSP's official
`./build.sh -u -J8` Rockchip packaging flow. The log contains `Make firmware
OK!`, `Make update image ok!`, and `Make gpt image ok!`.

```text
Build log:
/data/agibot-android14-build/logs/2026-08-26-r14-bluetooth-lpm-disable-build.log

Local image:
E:\AIPorject\101\android14-flash\releases\2026-08-26-r14-bluetooth-lpm-disable-official\agibot-mb0002-android14-r14-bluetooth-lpm-disable-official-update.img
```

- Image size: `2134964810` bytes
- Image SHA-256: `55FAE401B7EF82E50E5F0E75266DEDA36DFF00A80AF46C12644E75D6283FBED3`
- Vendor library SHA-256: `53035DDB5EE327268F416B2BCD5E71F51FB5148CC3B5E8B213C929F9202BD724`
- APEX SHA-256: `7A917B280C8E31D69F2A9ACA0BB243FFB70A2FFC86EECB07BF2C1A4763F95715`
- JNI SHA-256: `0200DDC044213132B7AF525366AB16681B3730DBA83D021E3FED8EC1EFB330F1`

The image hash was independently calculated on the build server and after the
copy to Windows; both values matched. The built vendor library also contains
the expected `AGIBOT AP6275P: controller low-power mode disabled` string.

## Flash and runtime verification

RKDevTool v3.37 flashed the normalized r14 image through Loader mode. The tool
reported 100% followed by `下载固件成功`, and Android completed boot normally.
The installed vendor library, APEX, and JNI hashes all matched the build hashes
above. Enabling Bluetooth emitted the expected LPM-disable message.

Bluetooth was left idle for 30 seconds without manually touching `btwrite`.
During that idle period `bt_default_wake` returned low, the Bluetooth process
remained PID `2319`, and no HCI timeout occurred. One Settings pairing session
was then run for 30 seconds from that idle state.

```text
Bluetooth PID before scan: 2319
Bluetooth PID after scan:  2319
0x200b timeout:             none
0x2041 timeout:             none
0xfd57 timeout:             none
0xfd59 timeout:             none
HCI timeout/fatal signal:   none
```

The Settings UI remained on the pairing page with its scan progress indicator.
The Bluetooth manager's internal history confirms that the controller received
real LE advertisements: completed 10-second LE scan cycles reported 4, 5, 7,
and 5 results. Each parallel classic inquiry ended with `HCI_SUCCESS` and zero
classic results. Settings did not render a named device, which is consistent
with nearby anonymous/non-pairable BLE advertisements and does not indicate a
transport failure.

After leaving the pairing page, discovery stopped cleanly, the search state
returned to `BTA_DM_SEARCH_IDLE`, and PID `2319` remained active. r14 therefore
passes Bluetooth initialization, idle recovery, scan command completion,
process stability, and actual BLE receive validation. Pairing and profile use
still require a known external device placed in discoverable mode.

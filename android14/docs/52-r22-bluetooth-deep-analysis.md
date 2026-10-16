# r22 Bluetooth deep analysis

Date: 2026-08-27

## Scope

This round separates four previously conflated cases:

1. Android can enable Classic discoverability.
2. A remote peer can discover Android by address.
3. Android can receive Classic Inquiry results from an independently verified peer.
4. A remote peer receives Android's name and Class of Device through EIR/FHS data.

No image or source payload was changed during this runtime investigation.

## Test state

The board remained on the r22 kernel and vendor payload:

~~~text
Linux 6.1.99 #13 SMP PREEMPT Thu Aug 27 00:47:53 CST 2026
HCD SHA-256: f7adf14413063f14b0204684fb67ddcd2ae6bca3120343cb9a5cab86a1a545c3
Bluetooth address: B0:02:47:43:EA:3B
Adapter name after restoration: MB0002 V2
Scan mode: SCAN_MODE_CONNECTABLE_DISCOVERABLE
Bluetooth crashed 0 times
~~~

The r22 proc-read fix continued to return "unsupported to read" as root. No new
pstore dmesg-ramoops record was generated, and sys.boot.reason remained
"reboot,factory_reset".

## HCI evidence

The UI-triggered pairing scan was captured with Bluetooth snoop logging. The
controller accepted all relevant host commands:

~~~text
Write Class of Device (0x0C24): successful
Write Local Name (0x0C13): successful, contains MB0002 V2
Write Extended Inquiry Response (0x0C52): successful
Write Scan Enable (0x0C1A): 0x03, successful
Inquiry (0x0401): two 12.8-second cycles, status HCI_SUCCESS
~~~

The final observed Class of Device write was 0x181f00. The EIR payload contained
the local name and the expected service UUID list.

During repeated scans, Android received BLE reports but zero Classic Inquiry
Result events:

~~~text
Classic result events: 0
LE results per scan:   3
~~~

## Windows as the opposite peer

Windows used the Intel Bluetooth radio with driver 23.60.0.1. A real Win32
Classic Inquiry, not merely cached PnP enumeration, was run while Android was
discoverable. Windows returned:

~~~text
Address=B0:02:47:43:EA:3B
Name=<empty>
Class=0x000000
Remembered=False
Authenticated=False
~~~

This corrects the earlier conclusion in 51-r22-classic-bluetooth-diagnosis.md:
the MB0002 controller is discoverable at the Classic level. Windows does see
the board's address. It does not receive or expose the expected friendly name
and Class of Device through the Win32 API result.

A controlled A/B test renamed the adapter to MB0002_V2_EIR while scan mode was
already discoverable. This forced new Local Name and EIR writes after scan
enable. Windows still returned the same address with an empty name and zero
Class of Device. The friendly name was restored to MB0002 V2.

Therefore, simply rewriting EIR after entering discoverability is not a valid
r23 fix.

## Windows peer limitation

Windows reports repeated BTHUSB event 18:

~~~text
Windows cannot store Bluetooth authentication codes (link keys) on the local adapter.
~~~

The current shell is not elevated, so the Intel Bluetooth device stack cannot
be safely restarted or reinstalled from this session. The Windows radio also
claims Discoverable=True and Connectable=True through Win32, but Android does
not receive a Classic result from it. It is therefore not a reliable negative
control for MB0002 incoming Classic Inquiry.

## Current verdict

- Classic discoverability from Android: PASS at the address level.
- BLE reception and service stability: PASS.
- Local EIR/CoD host commands: PASS, all accepted by the controller.
- Remote presentation of name/CoD: UNRESOLVED; needs one independent scanner.
- Android incoming Classic Inquiry: UNRESOLVED; needs one independently verified discoverable Classic peer.
- r22 kernel/HCI stability: PASS.

No r23 source change is justified from this evidence alone. Flashing another
uncontrolled firmware or framework variant would discard the only stable
post-proc-fix baseline.

## Required independent test

Use a phone, headset, speaker, or second computer that is independently proven
discoverable in Classic pairing mode:

1. Keep the peer in pairing/discoverable mode and verify that another device can see its name.
2. Scan from MB0002 for at least 30 seconds.
3. If the peer appears, pair once and record the HCI result.
4. In the reverse direction, scan for MB0002 V2.
5. Record whether the independent scanner shows a name and device type.

Only if an independent scanner sees the address but no name/CoD should the next
revision investigate AP6275P HCD EIR/FHS behavior. Only if MB0002 cannot see an
independently verified Classic peer should the next revision investigate Classic
receive/coexistence.

## Evidence

~~~text
E:\AIPorject\101\android14-flash\validation\r22-classic-deep\
~~~

Key files:

~~~text
windows-inquiry-btsnoop.log
eir-rewrite-btsnoop.log
bluetooth-after-ui.txt
bluetooth-final.txt
dmesg-bluetooth.txt
discovery-ui.png
~~~

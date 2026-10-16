# Risk register

| ID | Risk | Impact | Likelihood | Mitigation |
|---|---|---:|---:|---|
| R01 | Treating ROCK 5C image or DTS as directly compatible | Brick or non-boot | High if ignored | Source-only baseline; separate AGIBOT product and DTS; no image flashing |
| R02 | Wrong wireless module assumption | Wi-Fi/BT failure or rail mismatch | Medium | Keep disabled until physical and runtime identification |
| R03 | PMIC/power-tree mismatch | Boot instability | Medium | Start from original 5.10 properties and compare RKR6 bindings before changes |
| R04 | Android partition mismatch with 233 GiB eMMC | Recovery failure | Medium | Design GPT separately; keep known rescue image untouched |
| R05 | HDMI route/HPD differences | No display while system is running | Medium | Enable only HDMI0; collect serial and DRM logs |
| R06 | USB hub reset ordering | USB HID/ADB intermittent | Medium | Replicate the original GPIO4_D2/D3 reset pulse after confirming the RKR6 mechanism |
| R07 | Mixing mainline DTS syntax into vendor 6.1 tree | Compile or probe failure | High if copied blindly | Treat the 6.12 DTS as evidence, not a drop-in patch |
| R08 | Losing board recovery data | Permanent data/availability loss | Low | Do not commit images; never overwrite rescue package |
| R09 | Android property deprecations in RKR6 | Build failure later | Medium | Prefer vendor-product examples after source checkout |
| R10 | NPU/camera scope creep | Delays core boot | High | Explicitly deferred until milestone 4 |
| R11 | USB VBUS expander sequencing or over-enable | HID/ADB failure or unintended auxiliary power | Medium | Initialize only PCA9555 `0x20` offsets 0..11 after the hub reset review |

## Stop conditions

Stop and reassess before proceeding if any of these become true:

- the original recovery image cannot be verified;
- a power rail or PMIC binding cannot be mapped between 5.10 and RKR6;
- the populated wireless module remains unidentified;
- generated Android partition offsets would overwrite the rescue loader area
  without a tested rollback;
- HDMI0 and serial console cannot both be preserved during first boot tests.

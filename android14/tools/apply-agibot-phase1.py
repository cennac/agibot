#!/usr/bin/env python3
"""Apply small Phase 1 source-tree edits idempotently."""

from pathlib import Path


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text()
    if new in text:
        return
    if old not in text:
        raise RuntimeError(f"expected context not found in {path}")
    path.write_text(text.replace(old, new, 1))


def ignore_missing_latest_api(path: Path, library: str) -> None:
    replace_once(
        path,
        f'java_sdk_library {{\n    name: "{library}",\n',
        f'java_sdk_library {{\n'
        f'    name: "{library}",\n'
        f'    unsafe_ignore_missing_latest_api: true,\n',
    )


def disable_soong_module(path: Path, module: str) -> None:
    """Insert an immediately-scoped enabled:false property idempotently."""
    text = path.read_text()
    name_line = f'name: "{module}",'
    lines = text.splitlines(keepends=True)

    for index, line in enumerate(lines):
        if line.strip() != name_line:
            continue
        next_index = index + 1
        if next_index < len(lines) and lines[next_index].strip() == "enabled: false,":
            return
        indent = line[: len(line) - len(line.lstrip())]
        lines.insert(next_index, f"{indent}enabled: false,\n")
        path.write_text("".join(lines))
        return

    raise RuntimeError(f"module {module!r} not found in {path}")


def main() -> None:
    products = Path("device/rockchip/rk3588/AndroidProducts.mk")
    replace_once(
        products,
        "    $(LOCAL_DIR)/rk3588s_u_radxa_rock5c/rk3588s_u_radxa_rock5c.mk \n\nCOMMON_LUNCH_CHOICES",
        "    $(LOCAL_DIR)/rk3588s_u_radxa_rock5c/rk3588s_u_radxa_rock5c.mk \\\n"
        "    $(LOCAL_DIR)/agibot_mb0002/agibot_mb0002.mk\n\nCOMMON_LUNCH_CHOICES",
    )
    replace_once(
        products,
        "    rk3588s_u_radxa_rock5c-userdebug \\\n    rk3588s_u_radxa_rock5c-user \n",
        "    rk3588s_u_radxa_rock5c-userdebug \\\n"
        "    rk3588s_u_radxa_rock5c-user \\\n"
        "    agibot_mb0002-userdebug\n",
    )

    dts_makefile = Path("kernel-6.1/arch/arm64/boot/dts/rockchip/Makefile")
    replace_once(
        dts_makefile,
        'dtb-$(CONFIG_ARCH_ROCKCHIP) += rk3588-evb1-lp4-v10.dtb\n',
        'dtb-$(CONFIG_ARCH_ROCKCHIP) += rk3588-agibot-mb0002-v2.dtb\n'
        'dtb-$(CONFIG_ARCH_ROCKCHIP) += rk3588-evb1-lp4-v10.dtb\n',
    )

    usb_kconfig = Path("kernel-6.1/drivers/usb/misc/Kconfig")
    replace_once(
        usb_kconfig,
        'comment "USB Miscellaneous drivers"\n\n',
        'comment "USB Miscellaneous drivers"\n\n'
        'config USB_AGIBOT_HUB_RESET\n'
        '\ttristate "AGIBOT MB0002 V2 USB hub reset GPIO support"\n'
        "\tdepends on GPIOLIB && OF\n"
        "\thelp\n"
        "\t  Say Y here to pulse and release the two onboard USB hub reset\n"
        "\t  lines used by AGIBOT MB0002 V2 before USB enumeration starts.\n\n",
    )

    usb_makefile = Path("kernel-6.1/drivers/usb/misc/Makefile")
    replace_once(
        usb_makefile,
        "obj-$(CONFIG_USB_ADUTUX)\t\t+= adutux.o\n",
        "obj-$(CONFIG_USB_ADUTUX)\t\t+= adutux.o\n"
        "obj-$(CONFIG_USB_AGIBOT_HUB_RESET)\t+= agibot-hub-reset.o\n",
    )

    # Radxa's public RKR6 manifest combines android-14.0-mid-rkr6 sources with
    # the older public android-14.0.0_r27 prebuilt SDK.  That SDK predates both
    # APEX libraries and therefore lacks their latest API tracking filegroups.
    # Disable compat tracking for only these two modules until a matching SDK
    # snapshot is available.
    ignore_missing_latest_api(
        Path("packages/providers/MediaProvider/apex/pdf/framework/Android.bp"),
        "framework-pdf",
    )
    ignore_missing_latest_api(
        Path("packages/providers/MediaProvider/photopicker/framework/Android.bp"),
        "framework-photopicker",
    )

    # The public RKR6 Car repository added RKAVM render dependencies but omitted
    # libassimp.so. AGIBOT Phase 1 disables camera/EVS, so do not synthesize a
    # placeholder binary. Disable the complete EVS sample chain until upstream
    # publishes the missing prebuilt or a source-based replacement.
    evs_bp = Path("packages/services/Car/cpp/evs/apps/default/Android.bp")
    for module in (
        "evs_app",
        "libopencv_core",
        "libopencv_imgcodecs",
        "libopencv_imgproc",
        "libassimp",
        "lib_render_3d",
    ):
        disable_soong_module(evs_bp, module)

    # Android's Ethernet stack manages interface state. The Rockchip common RC
    # additionally starts BusyBox directly from init, which has no SELinux
    # domain transition and is rejected even in permissive mode.
    replace_once(
        Path("device/rockchip/common/rootdir/init.rk30board.rc"),
        "service up_eth0 /system/bin/busybox ifconfig eth0 up\n"
        "    class main\n"
        "    oneshot\n\n",
        "# Ethernet interface state is managed by Android EthernetService.\n\n",
    )


if __name__ == "__main__":
    main()

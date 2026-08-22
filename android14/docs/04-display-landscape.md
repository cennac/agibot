# Display and landscape policy

## Product behavior

AGIBOT MB0002 V2 will initially be connected to desktop monitors or TVs. The
product is therefore a landscape Android tablet/desktop device rather than an
Android TV device.

The initial policy is:

- one HDMI0 connector;
- rotation zero at display-server level;
- EDID-selected standard landscape resolution;
- pointer and keyboard navigation supported;
- no forced portrait rotation;
- no Android TV `Leanback` requirement in the base product.

## Initial properties

The product skeleton sets:

```properties
ro.sf.hwrotation=0
ro.surface_flinger.primary_display_orientation=ORIENTATION_0
```

These are intentionally conservative. After the source checkout, the exact
Rockchip RKR6 property names and the SurfaceFlinger integration must be checked
against the selected framework revision. A property that is ignored by the
vendor composer must be replaced by the board display route and launcher policy
rather than duplicated.

## Portrait applications

Portrait phone applications may still choose portrait-only orientation. They
should be presented by Android's normal compatibility behavior on the landscape
display. Forcing every application to rotate can break camera/video layouts.

If desktop-style windows are added later, use a supported Android windowing mode
and test pointer capture, IME, and fullscreen video separately.

## TV variant

A TV launcher can be created as a separate product variant only after the normal
Android product is stable. It should not change the board DTS or display HAL.

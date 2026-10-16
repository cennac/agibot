# DTS working notes

Files here are candidate fragments for the Rockchip Android 14 Linux 6.1 source
tree. They are not compiled in Phase 0 and are not copied into the kernel tree
automatically.

The original decompiled 5.10 DTS and the newer 6.12-oriented DTS use different
binding generations. A property that is valid in one tree may be invalid or
renamed in the other. Every migrated node needs a side-by-side comparison.

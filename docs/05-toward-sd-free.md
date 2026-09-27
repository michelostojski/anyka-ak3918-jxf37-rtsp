# 05 — Toward SD-free (open problem / help wanted)

Right now everything runs from the **SD card** (`/mnt`, plenty of space) via
the `wifitest` boot hook. Making it **flash-only (SD-free)** is blocked on
**space**:

```
/dev/root       1.3M 1.3M   0 100% /            (rootfs, full)
/dev/mtdblock6  3.3M 3.3M   0 100% /usr         (squashfs, read-only, full)
/dev/mtdblock5  500K 288K 212K 58% /etc/jffs2   (writable — only 212K free)
/dev/mmcblk0p1   30G       …       /mnt         (the SD card)
```

The demo binary is tiny (26 KB). The problem is its **libraries**:
- 16 of the 20 needed libs are already in the read-only, full `/usr/lib`.
- 4 are "extra": `libakae` **462 KB**, `libplat_common_one` 27 KB,
  `libplat_mem` 25 KB, `libplat_osal` 38 KB (~551 KB total).
- Only ~212 KB is free in the writable jffs2, and `/usr` is a full read-only
  squashfs. **`libakae` (audio) alone doesn't fit.**

Ideas (untested / help welcome):

1. **Video-only:** drop `libakae` (it's the audio encoder). The remaining 3
   libs (~90 KB) fit in jffs2. Put them in `/etc/jffs2/lib/` and boot with
   `LD_LIBRARY_PATH=/etc/jffs2/lib:/usr/lib`. Needs testing that the demo runs
   without libakae.
2. **Reflash `/usr`:** extract the `mtd6` squashfs, delete unused stock
   binaries to free ~551 KB, add the 4 libs, rebuild the squashfs (must fit
   3.3 MB), reflash mtd6. Recoverable via U-Boot + `sf update`/TFTP over
   serial (`ttySAK0,115200`) — so serial console is strongly recommended
   before trying.
3. **Custom firmware (buildroot):** the bigger path — a buildroot external
   tree for AK3918/AK39ev already exists as a WIP; bake the app + libs into a
   rebuilt rootfs/APP. See the sibling buildroot repo.

Boot hook, for reference: stock `rc.local` → `service.sh start` →
`anyka_ipc.sh start`. There's no writable user-rc that runs at boot other
than the SD `wifitest` hook, which is why SD-free needs one of the above.

If you've done Anyka `/usr` reflashing or have the flash headroom, a PR that
lands the video-only SD-free path (idea 1) or a safe mtd6 reflash (idea 2)
would complete this.

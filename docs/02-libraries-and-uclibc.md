# 02 — Libraries + the uClibc trap

## uClibc 0.9.33 (.so.0), not uClibc-ng (.so.1)

The camera runs uClibc **0.9.33**; its loader is `/lib/ld-uClibc.so.0`. Build
the demo with a toolchain that targets that (arm-anykav200 / v500 here both
produce `.so.0`). A uClibc-ng toolchain produces `.so.1` binaries/libraries
that die with:

```
can't load library 'ld-uClibc.so.1'
```

Note the loader can't be run standalone here ("Standalone execution is not
enabled"), so you can't work around a `.so.1` binary by invoking the loader.

**Keep the whole `LD_LIBRARY_PATH` set `.so.0`-consistent.** A single `.so.1`
library dropped into the path triggers the `.so.1` loader error even though
the demo binary itself is fine. Scan a lib dir for contaminants:

```sh
for f in *.so; do strings "$f" | grep -q "ld-uClibc.so.1" && echo "SO.1: $f"; done
```

## The 20 libraries the demo needs

From `strings ak_rtsp_demo | grep '\.so'` (readelf may not be on the camera):

```
libakae libakaudiofilter libakispsdk libakmedialib libakuio libakv_encode
libapp_net libapp_rtsp libmpi_venc libplat_ai libplat_common
libplat_common_one libplat_drv libplat_ipcsrv libplat_mem libplat_osal
libplat_venc_cb libplat_vi libplat_vpss libplat_thread
```
(+ system libc/dl/pthread/rt, loader ld-uClibc.so.0)

On this unit **16 of these are already in the read-only `/usr/lib`**; only 4
are "extra" and must be supplied from the working set (LibAK):
`libakae` (462 KB), `libplat_common_one` (27 KB), `libplat_mem` (25 KB),
`libplat_osal` (38 KB).

Gotchas found the hard way:
- **`libakuio`** must match the kernel's ION driver or `ION_IOC_ALLOC` fails.
- **`libplat_vi` / config version** interact: the config-version check
  (`ak_vi_match_sensor`) is done in `libplat_vi`; make sure the lib and the
  `isp_f37_mipi1lane.conf` version agree (see docs/04).
- A **crashed run leaks the 28 MB ION reservation** → next run fails
  `ION_IOC_ALLOC errno=22`; reboot to clear.

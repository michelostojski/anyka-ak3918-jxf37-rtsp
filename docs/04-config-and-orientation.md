# 04 — Sensor config version + orientation

## Sensor config version

`ak_vi_match_sensor()` version-checks the ISP config. An old one is rejected:

```
[check_data] config file ... is old version, main_version_int=0x4
[check_file] read sensor fail
match sensor failed  ->  vi init fail
```

The config that works on this unit is `/etc/jffs2/isp_f37_mipi1lane.conf`
**version 4.005** (`[isp.conf]version: 4.005, sensor id: 0xf37`). There are
several f37 configs scattered on these devices (`isp_f37_mipi1.conf`,
`isp_f37_mipi_1lane.conf`, `.orig` …) — pick the one whose version the
`libplat_vi` you're using accepts.

## Orientation (VI flip) — and *where* to call it

Image upside-down for this mounting. The VI API has:

```c
int ak_vi_set_flip_mirror(void *handle, int flip_enable, int mirror_enable);
```

- `(1,1)` = flip + mirror = 180° (fixes plain upside-down here)
- `(1,0)` = vertical flip only, `(0,1)` = horizontal mirror only

**Placement matters.** The function itself is NULL-safe, but calling it
mid-VI-init (before the ISP pipeline is fully up) crashed. Calling it on the
**fully-initialised handle returned by the demo's `ak_rtsp_vi_init`**, after
`vi init ok`, works cleanly:

```c
if (vi_handle == NULL) { ...; return -1; }
ak_print_notice("vi init ok\n");
ak_vi_set_flip_mirror(vi_handle, 1, 1);   /* <-- here, on the ready handle */
```

This flips at the VI/ISP source, so the RTSP stream itself is upright (no
consumer-side rotation needed).

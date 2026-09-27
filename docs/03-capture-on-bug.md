# 03 — The capture-on segfault (found by reading ak_vi.c)

The single most important fix. The vendor `ak_rtsp_demo` sets up VI, opens the
encoder, starts the RTSP server (port 554 opens, clients can connect) — but
**no video frames flow**. The capture loop just prints:

```
[isp_vi_get_frame] must call after capture on (capture_on=0)
```

## Why

The demo's VI init calls `ak_vi_open()`, prints `"start capture ..."` and
returns — it **never calls `ak_vi_capture_on()`**. So capture is never
enabled and `ak_vi_get_frame` returns nothing.

## First attempt → segfault

Add `ak_vi_capture_on(handle)` after `ak_vi_open`. Now it **segfaults** at
`start capture`. The reason is only visible in the `libplat_vi.so` source
(`ak_vi.c`):

```c
static int vi_set_capture_on(void *handle, enum isp_vi_status status)
{
    struct vi_device *pdev = ((struct user_t *)handle)->pdev;
    ...
    int main_size = CH_MAIN_SIZE(pdev->chn_main->max_width,   /* <-- NULL deref */
                                 pdev->chn_main->max_height);
    int sub_size  = CH_SUB_SIZE(pdev->chn_sub->max_width,
                                pdev->chn_sub->max_height);
    ...
}
```

`pdev->chn_main` / `pdev->chn_sub` are **NULL** until they are `calloc`'d —
and that only happens inside **`ak_vi_set_channel_attr()`**:

```c
static int vi_set_channel_attr(struct vi_device *pdev, const ... *attr)
{
    ...
    if (!pdev->chn_main) {
        pdev->chn_main = calloc(1, sizeof(struct video_resolution));
        pdev->chn_sub  = calloc(1, sizeof(struct video_resolution));
        pdev->crop_info = calloc(1, sizeof(struct crop_info));
    }
    pdev->chn_main->max_width  = attr->res[VIDEO_CHN_MAIN].max_width;   /* set here */
    pdev->chn_main->max_height = attr->res[VIDEO_CHN_MAIN].max_height;
    pdev->chn_sub->max_width   = attr->res[VIDEO_CHN_SUB].max_width;
    pdev->chn_sub->max_height  = attr->res[VIDEO_CHN_SUB].max_height;
    ...
}
```

So the required order is:

```
ak_vi_open()
ak_vi_get_sensor_resolution()      (optional but handy for max_width/height)
ak_vi_set_channel_attr()   <-- allocates chn_main/chn_sub, sets max_width/height
ak_vi_capture_on()         <-- now safe; enables capture
ak_vi_get_frame()          <-- frames flow
```

The demo skipped `ak_vi_set_channel_attr()` entirely.

## The fix

In the demo's VI init, before `ak_vi_capture_on()`:

```c
struct video_channel_attr attr;
memset(&attr, 0, sizeof(attr));
attr.crop.left = 0; attr.crop.top = 0;
attr.crop.width  = resolution.width;    /* full sensor, e.g. 1920 */
attr.crop.height = resolution.height;   /* 1080 */
attr.res[VIDEO_CHN_MAIN].width  = 1280; attr.res[VIDEO_CHN_MAIN].height = 720;
attr.res[VIDEO_CHN_MAIN].max_width  = resolution.width;
attr.res[VIDEO_CHN_MAIN].max_height = resolution.height;
attr.res[VIDEO_CHN_SUB].width   = 640;  attr.res[VIDEO_CHN_SUB].height  = 480;
attr.res[VIDEO_CHN_SUB].max_width   = 640;
attr.res[VIDEO_CHN_SUB].max_height  = 480;
ak_vi_set_channel_attr(handle, &attr);   /* <-- the missing call */

if (ak_vi_capture_on(handle))
    ak_print_error_ex("ak_vi_capture_on failed\n");
```

Rebuild, run (clean ION state — reboot if a prior run crashed), and the log
turns into:

```
[isp_vi_get_frame] capture on --> real get frame
## max nalu size = ...., type: I, stream ...
## max nalu size = ...., type: P, stream ...
```

Frames flow; RTSP streams real video on both channels.

## Moral

When a vendor SDK call segfaults, get the library's source (or decompile) and
read what it dereferences. Here `vi_set_capture_on` assumed channel attrs were
already set — a one-call ordering bug that cost a lot of blind guessing before
the source made it obvious.

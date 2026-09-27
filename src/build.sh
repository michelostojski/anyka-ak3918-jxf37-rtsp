#!/bin/sh
# Cross-compile ak_rtsp_demo for AK3918 (uClibc 0.9.33 -> ld-uClibc.so.0).
# Adjust toolchain + include/lib paths.
CC=/path/to/arm-anykav200-crosstool/usr/bin/arm-anykav200-linux-uclibcgnueabi-gcc
INC=/path/to/sdk/include
LIBD=/path/to/working/libset       # .so.0-consistent (LibAK)

$CC -I$INC/libplat/include -I$INC/libmpi/include -I$INC/libre_anyka_app/include \
    -I$INC/include_vi \
    -Wall -g -O0 -std=gnu99 -pthread ak_rtsp_demo.c -o ak_rtsp_demo_v104 \
    -L$LIBD -Wl,-rpath-link,$LIBD \
    -Wl,--start-group \
      -lplat_vi -lplat_vpss -lakispsdk -lakuio -lmpi_venc -lakv_encode \
      -lakmedialib -lplat_common -lplat_common_one -lplat_thread -lplat_drv -lplat_ai \
      -lplat_ipcsrv -lplat_venc_cb -lakae -lapp_rtsp -lapp_net \
      -lplat_mem -lplat_osal -lakaudiofilter \
    -Wl,--end-group -ldl -lrt -lpthread
echo "exit $?"; ls -la ak_rtsp_demo_v104

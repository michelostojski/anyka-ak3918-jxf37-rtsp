#!/bin/sh
# Start the from-source RTSP demo (binary + libs on SD, /mnt/RTSP). See docs/05.
DEMO=/mnt/ak_rtsp_demo_v104
LIBS=/usr/lib:/mnt/RTSP/LibAK        # .so.0-consistent set that accepts config v4.005
ps | grep -q "[c]md_serverd" || /usr/bin/cmd_serverd &
sleep 2
killall ak_rtsp_demo_v104 2>/dev/null   # avoid leaked-ION from a prior crash
sleep 1
export LD_LIBRARY_PATH=$LIBS
cd /mnt
"$DEMO" &
echo "RTSP -> rtsp://<camera-ip>:554/vs0 (main), /vs1 (sub)"

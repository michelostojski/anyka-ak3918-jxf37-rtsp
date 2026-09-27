#!/bin/sh
# wifi_test.sh - WiFi+Telnet startup for Anyka cameras (no anyka_ipc/Osaio)
# SD: /wifitest/wifi_test.sh, chmod +x if on Linux/ext4

LOG=/mnt/wifitest/wifi_test_log.txt
RAN=/mnt/wifitest/wifi_test_ran.txt
TELNET_LOG=/mnt/wifitest/telnet_launch.log
UDHCPC_LOG=/mnt/wifitest/udhcpc.log

# ---- EDIT YOUR WIFI CREDENTIALS HERE ----
WIFI_SSID="yourSSID"
WIFI_PASS="your password"
# -----------------------------------------
# ---- LOAD WIFI DRIVER STACK (correct order from stock wifi_driver.sh) ----
echo "loading wifi driver stack" >> "$LOG"
insmod /usr/modules/sdio_wifi.ko 2>> "$LOG"
sleep 2
insmod /usr/modules/otg-hs.ko 2>> "$LOG"
sleep 2
insmod /usr/modules/8188fu.ko 2>> "$LOG"
sleep 3
STATIC_IP="192.168.1.200/24"
GATEWAY="192.168.1.1"

echo "wifi_test.sh START $(date)" > "$LOG"
echo "mounts:" >> "$LOG"
mount >> "$LOG" 2>&1

# Wait for wlan0 to appear
COUNT=0
while [ $COUNT -lt 30 ]; do
  if ip link show wlan0 >/dev/null 2>&1; then
    echo "wlan0 found at $(date)" >> "$LOG"
    break
  fi
  COUNT=$((COUNT+1))
  sleep 1
done

if ! ip link show wlan0 >/dev/null 2>&1; then
  echo "wlan0 not present after wait; aborting" >> "$LOG"
  echo "wifi_test_aborted $(date)" > "$RAN"
  sync
  exit 1
fi

echo "bringing wlan0 up" >> "$LOG"
ip link set wlan0 up 2>> "$LOG" || echo "ip link set failed" >> "$LOG"

# --- WPA Supplicant Wi-Fi connection ---
echo "Configuring Wi-Fi for SSID $WIFI_SSID" >> "$LOG"
cat > /tmp/wpa.conf <<EOF
network={
    ssid="$WIFI_SSID"
    psk="$WIFI_PASS"
    key_mgmt=WPA-PSK
}
EOF

killall wpa_supplicant 2>/dev/null
wpa_supplicant -B -i wlan0 -c /tmp/wpa.conf >> "$LOG" 2>&1
sleep 6

# Confirm Wi-Fi association
if iw wlan0 link | grep -q "Connected"; then
  echo "Wi-Fi connected to $WIFI_SSID" >> "$LOG"
else
  echo "Wi-Fi NOT connected to $WIFI_SSID at $(date)" >> "$LOG"
fi

# DHCP
DHCP_OK=0
if command -v udhcpc >/dev/null 2>&1; then
  echo "starting udhcpc" >> "$LOG"
  udhcpc -i wlan0 -t 5 -n -q >"$UDHCPC_LOG" 2>&1 &
  UDH_PID=$!
  for i in $(seq 1 12); do
    sleep 1
    if ip -4 addr show dev wlan0 | grep -q "inet "; then
      DHCP_OK=1
      break
    fi
  done
  if [ $DHCP_OK -eq 1 ]; then
    echo "DHCP acquired" >> "$LOG"
  else
    echo "DHCP failed or timed out; killing udhcpc" >> "$LOG"
    kill $UDH_PID 2>/dev/null || true
  fi
else
  echo "udhcpc not present" >> "$LOG"
fi

# Fallback static IP
if [ $DHCP_OK -eq 0 ]; then
  echo "Assigning static IP $STATIC_IP" >> "$LOG"
  ip addr flush dev wlan0 2>> "$LOG" || true
  ip addr add $STATIC_IP dev wlan0 2>> "$LOG" || echo "static assign failed" >> "$LOG"
  ip route show | grep -q "default" || ip route add default via $GATEWAY 2>> "$LOG" || true
fi

echo "wlan0 addresses:" >> "$LOG"
ip -4 addr show dev wlan0 >> "$LOG" 2>&1
ip route show >> "$LOG" 2>&1

# Flush iptables if available
if command -v iptables >/dev/null 2>&1; then
  echo "flushing iptables" >> "$LOG"
  iptables -F 2>> "$LOG" || true
  iptables -P INPUT ACCEPT 2>> "$LOG" || true
  iptables -P OUTPUT ACCEPT 2>> "$LOG" || true
  iptables -P FORWARD ACCEPT 2>> "$LOG" || true
else
  echo "iptables not present" >> "$LOG"
fi

# ----------- DO NOT START anyka_ipc HERE -----------

# Start telnetd as before
start_telnetd() {
  killall telnetd 2>/dev/null || true
  for p in /sbin/telnetd /usr/sbin/telnetd /bin/telnetd /usr/bin/telnetd /mnt/factory/custom/telnetd; do
    if [ -x "$p" ]; then
      echo "Trying $p" >> "$LOG"
      "$p" -b 0.0.0.0 -l /bin/sh >"$TELNET_LOG" 2>&1 &
      sleep 1
      if pgrep -f telnetd >/dev/null 2>&1; then
        echo "Started telnetd ($p) pid $(pgrep -f telnetd | head -n1)" >> "$LOG"
        return 0
      fi
      "$p" -l /bin/sh >"$TELNET_LOG" 2>&1 &
      sleep 1
      if pgrep -f telnetd >/dev/null 2>&1; then
        echo "Started telnetd ($p) pid $(pgrep -f telnetd | head -n1)" >> "$LOG"
        return 0
      fi
    fi
  done
  if command -v busybox >/dev/null 2>&1; then
    echo "Trying busybox telnetd" >> "$LOG"
    busybox telnetd -l /bin/sh >"$TELNET_LOG" 2>&1 &
    sleep 1
    if pgrep -f telnetd >/dev/null 2>&1; then
      echo "Started busybox telnetd pid $(pgrep -f telnetd | head -n1)" >> "$LOG"
      return 0
    fi
  fi
  echo "telnetd start failed" >> "$LOG"
  return 1
}

if start_telnetd; then
  echo "telnetd running" >> "$LOG"
else
  echo "telnetd not running" >> "$LOG"
fi

(
  while true; do
    sleep 5
    if ! pgrep -f telnetd >/dev/null 2>&1; then
      echo "telnetd died at $(date), restarting" >> "$LOG"
      start_telnetd || echo "restart failed" >> "$LOG"
    fi
  done
) &

echo "WIFI_TEST_RAN $(date)" > "$RAN"
sync
echo "wifi_test.sh END $(date)" >> "$LOG"

# ================= MOTOR IOCTL CAPTURE =================
echo "starting stock services under ioctl shim $(date)" >> "$LOG"
insmod /usr/modules/ak_motor.ko 2>/dev/null
export LD_PRELOAD=/mnt/ioctl_log.so
/usr/bin/cmd_serverd &
echo "started cmd_serverd (shimmed) pid $!" >> "$LOG"
# /usr/bin/anyka_ipc &
echo "anyka_ipc NOT started (frames+ptz test)" >> "$LOG"
unset LD_PRELOAD
sync
# ======================================================

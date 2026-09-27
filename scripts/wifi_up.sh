#!/bin/sh
# WiFi bring-up for Anyka AK3918 + RTL8188FU (USB).
# The ORDER is the whole trick: USB-host (otg-hs) must load before the
# WiFi driver, or the USB WiFi never enumerates and wlan0 never appears.
# (Order from stock /usr/partC/sbin/wifi_driver.sh.)  EDIT SSID/PSK. LF endings.

SSID="YOUR_SSID"
PSK="YOUR_PSK"
STATIC_IP="192.168.1.200/24"    # fallback if DHCP times out (reserve it!)
GW="192.168.1.1"

# ---- driver stack, in order ----
insmod /usr/modules/sdio_wifi.ko 2>/dev/null   # power/SDIO
sleep 2
insmod /usr/modules/otg-hs.ko 2>/dev/null      # USB OTG host controller  <-- key
sleep 2
insmod /usr/modules/8188fu.ko 2>/dev/null      # WiFi driver
sleep 3

# ---- wait for wlan0 ----
i=0
while [ $i -lt 15 ]; do
    ip link show wlan0 >/dev/null 2>&1 && break
    sleep 1; i=$((i+1))
done
ip link set wlan0 up 2>/dev/null

# ---- associate ----
cat > /tmp/wpa.conf <<WPA
ctrl_interface=/var/run/wpa_supplicant
network={
    ssid="$SSID"
    psk="$PSK"
    key_mgmt=WPA-PSK
    scan_ssid=1
}
WPA
killall wpa_supplicant 2>/dev/null
wpa_supplicant -B -i wlan0 -c /tmp/wpa.conf
sleep 6

# ---- DHCP, else static fallback ----
udhcpc -i wlan0 -t 8 -n 2>/dev/null &
sleep 8
if ! ip -4 addr show dev wlan0 | grep -q "inet "; then
    ip addr add "$STATIC_IP" dev wlan0
    ip route add default via "$GW" 2>/dev/null
fi

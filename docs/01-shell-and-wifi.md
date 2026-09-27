# 01 — Root shell + WiFi bring-up (the USB-host ordering)

## Root shell (no flashing)

Stock `rc.local` → `service.sh` runs `/mnt/wifitest/wifi_test.sh` if
`/mnt/wifitest/` exists on the SD card. Put a `wifitest/wifi_test.sh` on a
FAT32 card that starts telnet; you get a root shell, fully reversible (pull
the card → stock).

## WiFi: the ordering that matters

This unit's WiFi is a **Realtek RTL8188FU on USB**. Loading `8188fu.ko` alone
does nothing — `wlan0` never appears — because the **USB host controller is
not up**, so the WiFi chip never enumerates (`/sys/bus/usb/devices/` empty,
dmesg shows only `usbcore: registered new device driver usb`, no host).

The stock `/usr/partC/sbin/wifi_driver.sh` reveals the correct order:

```sh
insmod /usr/modules/sdio_wifi.ko    # 1. power/SDIO
sleep 2
insmod /usr/modules/otg-hs.ko       # 2. USB OTG *host* controller  <-- the missing step
sleep 2
insmod /usr/modules/8188fu.ko       # 3. WiFi driver
sleep 3
```

After that, `usb1` shows in `/sys/bus/usb/devices/`, the WiFi enumerates, and
`wlan0` (and `wlan1`) appear.

Then associate + get an address:

```sh
ip link set wlan0 up
cat > /tmp/wpa.conf <<WPA
ctrl_interface=/var/run/wpa_supplicant
network={ ssid="SSID" psk="PSK" key_mgmt=WPA-PSK scan_ssid=1 }
WPA
wpa_supplicant -B -i wlan0 -c /tmp/wpa.conf
sleep 6
udhcpc -i wlan0 -t 10            # or a static fallback if DHCP times out
```

DHCP sometimes times out at boot; a static fallback (e.g. 192.168.1.200,
reserved outside the DHCP pool) is arguably better for a camera anyway.

See `scripts/wifi_up.sh` for the whole sequence.

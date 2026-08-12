#!/bin/bash
# Mesh-PI status LEDs (active-high)
#   Green (GPIO18) blinks when WiFi (wlan0) AND meshtasticd are both up
#   Red   (GPIO17) blinks when either one is down
# One LED blinks at a time, the other is held off. Blink = ON on / OFF off.
CHIP=gpiochip0     # Pi Zero/3/4 header. On Pi 5 use the right chip (see: gpiodetect)
GREEN=18
RED=17
ON=200ms
OFF=1800ms         # full cycle = 2 s

PIDS=()
kill_all() {
  for p in "${PIDS[@]}"; do kill "$p" 2>/dev/null; done
  for p in "${PIDS[@]}"; do wait "$p" 2>/dev/null; done
  PIDS=()
}
spawn() { "$@" >/dev/null 2>&1 & PIDS+=($!); }

cleanup() { kill_all; exit 0; }
trap cleanup TERM INT

last=""
while true; do
  if nmcli -t -f DEVICE,STATE device 2>/dev/null | grep -q '^wlan0:connected' \
     && systemctl is-active --quiet meshtasticd; then
    state=ok
  else
    state=ko
  fi

  if [ "$state" != "$last" ]; then
    kill_all
    if [ "$state" = ok ]; then
      # green blinks, red off
      spawn gpioset --toggle "$ON,$OFF" -c "$CHIP" "$GREEN"=1
      spawn gpioset -c "$CHIP" "$RED"=0
    else
      # red blinks, green off
      spawn gpioset --toggle "$ON,$OFF" -c "$CHIP" "$RED"=1
      spawn gpioset -c "$CHIP" "$GREEN"=0
    fi
    last="$state"
  fi
  sleep 3
done

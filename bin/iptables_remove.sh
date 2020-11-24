#!/bin/bash

echo "clear nat.REDSOCKS"
adb shell iptables -t nat -F REDSOCKS

echo "remove REDSOCKS Chain from nat.OUTPUT"
adb shell iptables -t nat -D OUTPUT -p tcp -j REDSOCKS

echo "lookup nat table."
adb shell iptables -t nat -nvxL OUTPUT --line && adb shell iptables -t nat -nvxL REDSOCKS --line
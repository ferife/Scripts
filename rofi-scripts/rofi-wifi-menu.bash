#!/usr/bin/env bash

# Based on github:ericmurphyxyz/rofi-wifi-menu

notify-send "Getting list of available Wi-Fi networks..."

# Get all available wifi networks
# The sed statements are to put them into a nice looking list
wifi_list=$(
  nmcli --fields "SECURITY,SSID" device wifi list |
  sed 1d |
  sed 's/  */ /g' |
  sed -E "s/WPA*.?\S/ /g" |
  sed "s/^--/ /g" |
  sed "s/  //g" |
  sed "/--/d"
)

enable_wifi="󰖩  Enable Wi-Fi"
disable_wifi="󰖪  Disable Wi-Fi"

connected=$(nmcli -fields WIFI g)
if [[ "$connected" =~ "enabled" ]]; then
  toggle="$disable_wifi"
elif [[ "$connected" =~ "disabled" ]]; then
  toggle="$enable_wifi"
else
  notify-send "ERROR: connection detection"
  exit 1
fi

# The awk statement is to remove repeat wifi networks
chosen_network=$(echo -e "$toggle\n$wifi_list" | awk '!seen[$0]++' | rofi -dmenu -i -selected-row 1 -p "Wi-Fi SSID: " )
read -r chosen_id <<< "${chosen_network:3}"

case "$chosen_network" in
  "") # Cancel Choice
    exit 0
    ;;
  "$enable_wifi")
    nmcli radio wifi on
    ;;
  "$disable_wifi")
    nmcli radio wifi off
    ;;
  *)
    success_message="You are now connected to the Wi-Fi network \"$chosen_id\"."
    saved_connections=$(nmcli -g NAME connection)
    if [[ $(echo "$saved_connections" | grep -w "$chosen_id") == "$chosen_id" ]]; then
      nmcli connection up id "$chosen_id" |
      grep "successfully" && notify-send "Connection Established" "$success_message"
    else
      if [[ "$chosen_network" =~ "" ]]; then
        wifi_password=$(rofi -dmenu -p "Password: " )
      fi
      nmcli device wifi connect "$chosen_id" password "$wifi_password" |
      grep "successfully" && notify-send "Connection Established" "$success_message"
    fi
    ;;
esac

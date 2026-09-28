#!/bin/zsh
# Renders one piece of art.html to a PNG with headless Chrome (fonts come from Google Fonts).
# render.sh <piece> <mode> <width> <height> <out.png> [size]
#   piece: icon | logo | word | cardA | cardK | cardQ     mode: light | dark
CH="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
DIR=${0:A:h}
SIZE=${6:-$3}
"$CH" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
  --default-background-color=00000000 --virtual-time-budget=6000 \
  --window-size=$3,$4 --screenshot="$5" "file://$DIR/art.html?piece=$1&mode=$2&size=$SIZE" >/dev/null 2>&1

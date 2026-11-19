#!/bin/bash
# render each diagram html to png at 2x with Edge headless
D="$1"; EDGE="/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe"
node -e "for(const m of require(process.argv[1]))console.log(m.name,m.w,m.h)" "$(cygpath -w "$D/list.json")" | while read n w h; do
  win=$(cygpath -w "$D/$n.png"); url="file:///$(cygpath -m "$D/$n.html")"
  "$EDGE" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=2 --window-size=$w,$h --screenshot="$win" "$url" >/dev/null 2>&1
  echo "$n $(ls -la "$D/$n.png" | awk '{print $5}')"
done

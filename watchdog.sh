#!/bin/sh
while sleep 30; do
  pgrep -f "python3.13.*dash.py" >/dev/null || {
    setsid /opt/bin/python3.13 /mnt/us/dash.py </dev/null >/tmp/dash.log 2>&1 &
  }
done

#!/usr/bin/env bash
# Auto-respawning localhost.run tunnel for the WISMO dashboard host (8090).
# Relaunches the SSH reverse tunnel whenever it drops. Free localhost.run
# rotates the subdomain on each reconnect, so this just keeps connectivity up.
set +m
KEY="/home/scents-iq-ltd7/.ssh/id_ed25519_localhostrun"
USERHOST="scents-wismo-tunnel@localhost.run"
LOCAL_PORT=8090
LOG="/tmp/wismo-tunnel.log"
echo "[tunnel] wrapper started $(date -u +%FT%TZ)" >>"$LOG"
while true; do
  echo "[tunnel] connecting $(date -u +%FT%TZ)" >>"$LOG"
  ssh -i "$KEY" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
      -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -o ExitOnForwardFailure=yes \
      -R 80:localhost:$LOCAL_PORT "$USERHOST" >>"$LOG" 2>&1
  code=$?
  echo "[tunnel] ssh exited code=$code $(date -u +%FT%TZ); restart in 3s" >>"$LOG"
  sleep 3
done

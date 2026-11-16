#!/bin/sh
# supervisord event listener: if Apache, Horizon or the scheduler gives up
# (FATAL), stop supervisord so the container exits and Railway restarts it.
printf 'READY\n'
while read -r header; do
  len=$(printf '%s' "$header" | sed -n 's/.*len:\([0-9]*\).*/\1/p')
  payload=$(dd bs=1 count="${len:-0}" 2>/dev/null)
  case "$header" in
    *PROCESS_STATE_FATAL*)
      echo "fatal-listener: a program entered FATAL ($payload); stopping the container" >&2
      kill -TERM "$(cat /run/supervisord.pid)"
      ;;
  esac
  printf 'RESULT 2\nOK'
  printf 'READY\n'
done

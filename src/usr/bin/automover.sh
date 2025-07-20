#!/bin/bash

CONFIG="/boot/config/plugins/automover/settings.cfg"
PIDFILE="/var/run/automover.pid"

# Trap cleanup on exit
cleanup() {
  echo "🛑 Caught termination signal — cleaning up"
  rm -f "$PIDFILE"
  exit 0
}

trap cleanup SIGINT SIGTERM

# Exit if already running
if [ -f "$PIDFILE" ]; then
  OLD_PID=$(cat "$PIDFILE")
  if kill -0 "$OLD_PID" 2>/dev/null; then
    echo "❌ Already running with PID $OLD_PID"
    exit 1
  else
    echo "⚠️ Stale PID found — continuing"
    rm -f "$PIDFILE"
  fi
fi

echo $$ > "$PIDFILE"

# Load settings
source "$CONFIG"

MOUNT_POINT="/mnt/${POOL_NAME}"

echo "🔁 Automover loop started for $POOL_NAME (Threshold=${THRESHOLD}%, Interval=${INTERVAL_SECS}s, DryRun=$DRY_RUN)"

while true; do
  # Wait if mover is running
  if pgrep -x mover &>/dev/null; then
    echo "⏳ Mover already running — skipping this check"
  else
    USED=$(df -h --output=pcent "$MOUNT_POINT" | awk 'NR==2 {gsub("%",""); print}')
    
    if [ -z "$USED" ]; then
      echo "❌ Could not retrieve usage for $MOUNT_POINT"
    else
      echo "📊 $POOL_NAME usage: ${USED}% (Threshold: $THRESHOLD%)"

      if [ "$USED" -gt "$THRESHOLD" ]; then
        echo "⚠️ Usage exceeds threshold!"

        if [ "$DRY_RUN" == "yes" ]; then
          echo "🔧 Dry Run enabled — not starting mover"
        else
          echo "🛠️ Starting mover..."
          mover start
        fi
      else
        echo "✅ Usage below threshold — nothing to do"
      fi
    fi
  fi

  sleep "$INTERVAL"
done

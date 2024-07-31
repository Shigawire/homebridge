#!/bin/bash

set +e

CREDENTIALS_KEY="vpn_credentials"
TAILSCALE_SOCKET="/var/run/tailscale/tailscaled.sock"
REDIS_URL=$REDIS_URL
SNX_ENDPOINT=$SNX_ENDPOINT

if [ -z "$SNX_ENDPOINT" ]; then
  echo "Error: The environment variable SNX_ENDPOINT is not set."
  exit 1
fi

while true; do
  # Wait for new credentials from Redis
  CREDENTIALS=$(redis-cli -u "$REDIS_URL" getdel "$CREDENTIALS_KEY")

  if [ "$CREDENTIALS" != "" ] && [ "$CREDENTIALS" != "null" ]; then
    # Read credentials
    USERNAME=$(echo "$CREDENTIALS" | jq -r '.username')
    PASSWORD=$(echo "$CREDENTIALS" | jq -r '.password')
    MFA=$(echo "$CREDENTIALS" | jq -r '.mfa')

    # Stop any existing snx-rs instance gracefully
    if [ ! -z "$SNX_PID" ]; then
      if kill -0 $SNX_PID 2>/dev/null; then
        kill $SNX_PID
        wait $SNX_PID
      fi
    fi

    # Start snx-rs command with new credentials
    snx-rs -s "$SNX_ENDPOINT" -o vpn_Two_Factor_Authentication -u "$USERNAME" -p "$PASSWORD$MFA" --no-cert-check true --ignore-server-cert true -e ssl -l trace &

    SNX_PID=$!
    sleep 5  # Wait for snx-rs to establish the connection

    if kill -0 $SNX_PID 2>/dev/null; then
      # Capture routes
      ROUTES=$(ip route show dev snx-tun | awk '{print $1}' | while read route; do case $route in */*) echo $route ;; *) echo ${route}/32 ;; esac; done | tr '\n' ',' | sed 's/,$//')

      # Update Tailscale
      tailscale --socket="$TAILSCALE_SOCKET" set --advertise-routes "$ROUTES"

      # Monitor snx-rs process
      wait $SNX_PID
      EXIT_CODE=$?

      if [ $EXIT_CODE -ne 0 ]; then
        echo "snx-rs terminated with non-zero exit code $EXIT_CODE. Waiting for new credentials to restart."
      fi
    else
      echo "Failed to start snx-rs"
    fi
  fi
done

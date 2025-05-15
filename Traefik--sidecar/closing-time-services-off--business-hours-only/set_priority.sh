#!/bin/bash

YAML_FILE="/app/dynamic_config/work-service.yaml"
LOW_PRIORITY=10
HIGH_PRIORITY=100
START_HOUR=9  # Work hours start (e.g., 9 AM)
END_HOUR=17   # Work hours end (e.g., 5 PM)

# Make sure the dynamic_config directory exists
mkdir -p "$(dirname "$YAML_FILE")"

get_priority() {
  local hour
  hour=$(date +%H)
  if (( hour >= START_HOUR && hour < END_HOUR )); then
    echo "$HIGH_PRIORITY"
  else
    echo "$LOW_PRIORITY"
  fi
}

write_config() {
  local priority=$1
  cat > "$YAML_FILE" <<EOF
http:
  routers:
    work:
      rule: "Host(\`work.example.com\`)"
      service: work-service
      entryPoints:
        - web
      priority: $priority

  services:
    work-service:
      loadBalancer:
        servers:
          - url: "http://work-service:80"
EOF
  echo "[$(date)] Priority set to $priority"
}

echo "[$(date)] Priority updater script started"

# Always write initial config at startup
current_priority=$(get_priority)
write_config "$current_priority"

while true; do
  new_priority=$(get_priority)
  
  # Check if priority needs to change
  if [[ "$new_priority" != "$current_priority" ]]; then
    write_config "$new_priority"
    current_priority="$new_priority"
    echo "[$(date)] Priority changed to $current_priority"
  else
    echo "[$(date)] No change in priority. Current: $current_priority"
  fi

  # Sleep for a shorter time (check every minute) for more reliable operation
  echo "[$(date)] Sleeping for 60 seconds before next check..."
  sleep 60
done

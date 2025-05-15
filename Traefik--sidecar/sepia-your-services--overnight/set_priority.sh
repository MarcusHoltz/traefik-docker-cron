#!/bin/bash

YAML_FILE="/app/dynamic_config/work-service.yaml"
# This rule turns on or off the middlewear, dimscreenrewrite, for portainer-router
AWAKE_RULE=
SLEEP_RULE="- dimscreenrewrite"

## WORKED ##
#START_HOUR=1  # Sleep hours start (e.g., 11 PM)
#END_HOUR=23   # Sleep hours end (e.g., 5 AM)
## WORKED ##

START_HOUR=${START_HOUR:-23}  # Sleep hours start (e.g., 11 PM)
END_HOUR=${END_HOUR:-5}       # Sleep hours end (e.g., 5 AM)


# Make sure the dynamic_config directory exists
mkdir -p "$(dirname "$YAML_FILE")"

# This function sets which rule to use based on the time.
get_priority() {
  local hour
  hour=$(date +%H)
  # Check for overnight hours
  if (( START_HOUR < END_HOUR )); then
    # Case 1: Sleep hours are on the same day (e.g., 4 PM to 11 PM)
    if (( hour >= START_HOUR && hour < END_HOUR )); then
      echo "$SLEEP_RULE"
    else
      echo "$AWAKE_RULE"
    fi
  else
    # Case 2: Sleep hours span midnight (e.g., 11 PM to 5 AM)
    if (( hour >= START_HOUR || hour < END_HOUR )); then
      echo "$SLEEP_RULE"
    else
      echo "$AWAKE_RULE"
    fi
  fi
}

write_config() {
  local middlewear_switch=$1
  cat > "$YAML_FILE" <<EOF
http:
  middlewares:
    dimscreenrewrite:
      plugin:
        rewrite-body:
          lastModified: true
          rewrites:
            - regex: "</head>"
              replacement: "<style>body{transition:filter 2s ease-out;animation:blackout 90s forwards}*:not(body){animation:sepiaTone 70s forwards}@keyframes blackout{0%{background:default}100%{background:black}}@keyframes sepiaTone{0%{filter:none}50%{filter:sepia(.8) brightness(.5)}90%{filter:sepia(1) brightness(.1)}100%{filter:sepia(1) brightness(0)}}</style></head>"

  routers:
    portainer-router:
      rule: "Host(\`portainer.examplesetup.com\`)"
      entryPoints:
        - web
      service: portainer-service
      middlewares:
        $middlewear_switch

  services:
    portainer-service:
      loadBalancer:
        servers:
          - url: "http://portainer:9000"

EOF

}

echo "[$(date)] Middlewear dimscreenrewrite updater script started"

# Always write initial config at startup
current_priority=$(get_priority)
write_config "$current_priority"

while true; do
  new_priority=$(get_priority)
  
  # Check if priority needs to change
  if [[ "$new_priority" != "$current_priority" ]]; then
    write_config "$new_priority"
    current_priority="$new_priority"
    echo "-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_"
    echo "[$(date)] : MODIFING MIDDLEWEAR : MODIFING MIDDLEWEAR : MODIFING MIDDLEWEAR : " 
    echo "[$(date)] Middleware is now $(if [ -z "$new_priority" ]; then echo "NOT ACTIVE"; else echo "ACTIVE"; fi)"
    echo "[$(date)] : MODIFING MIDDLEWEAR : MODIFING MIDDLEWEAR : MODIFING MIDDLEWEAR : " 
    echo "-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_"

  else
    echo "[$(date)] Middleware is presently $(if [ -z "$new_priority" ]; then echo "NOT ACTIVE"; else echo "ACTIVE"; fi)"
#    echo -e "-----------------------------------"
#    echo ""
  fi

  # Sleep for a shorter time (check every minute) for more reliable operation
#  echo "[$(date)] Sleeping for 60 seconds before next check..."
  sleep 60
done

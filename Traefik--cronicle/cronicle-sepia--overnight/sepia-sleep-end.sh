#!/bin/bash

# Load environment variables from .env file
if [ -f .env ]; then
  echo "Loading configuration from .env file..."
  set -a  # automatically export all variables
  source .env
  set +a
else
  echo "Error: .env file not found!"
  echo "Please create a .env file with CRONICLE_URL, API_KEY, and CRONICLE_TARGET variables."
  exit 1
fi

# Verify required environment variables
if [ -z "$CRONICLE_URL" ] || [ -z "$API_KEY" ] || [ -z "$CRONICLE_TARGET" ]; then
  echo "Error: Missing required environment variables!"
  echo "Please ensure CRONICLE_URL, API_KEY, and CRONICLE_TARGET are set in the .env file."
  exit 1
fi

echo "Using Cronicle URL: $CRONICLE_URL"
echo "Using target: $CRONICLE_TARGET"

# Create job event with your shell script
# No double quotes, no backticks
echo "Creating job event..."
JOB_SCRIPT=$(cat <<'EOF' | sed "s/DOMAIN_PLACEHOLDER_VARIABLE/${BASE_DOMAIN}/"
#!/bin/sh

YAML_FILE='/opt/cronicle/traefik/middlewear-portainer.yml'

# Write the YAML content line by line
#echo 'http:' > $YAML_FILE
#echo '  routers:' >> $YAML_FILE
#echo '    work:' >> $YAML_FILE
#echo '      rule: \"Host(`work.DOMAIN_PLACEHOLDER_VARIABLE`)\"' >> $YAML_FILE
#echo '      service: work-service' >> $YAML_FILE
#echo '      entryPoints:' >> $YAML_FILE
#echo '        - web' >> $YAML_FILE
#echo '      priority: 10' >> $YAML_FILE
#echo '' >> $YAML_FILE
#echo '  services:' >> $YAML_FILE
#echo '    work-service:' >> $YAML_FILE
#echo '      loadBalancer:' >> $YAML_FILE
#echo '        servers:' >> $YAML_FILE
#echo '          - url: http://work-service:80' >> $YAML_FILE

# Write the YAML content line by line
echo 'http:' > $YAML_FILE
echo '  middlewares:' >> $YAML_FILE
echo '    dimscreenrewrite:' >> $YAML_FILE
echo '      plugin:' >> $YAML_FILE
echo '        rewrite-body:' >> $YAML_FILE
echo '          lastModified: true' >> $YAML_FILE
echo '          rewrites:' >> $YAML_FILE
echo '            - regex: \"</head>\"' >> $YAML_FILE
echo '              replacement: \"<style>body{transition:filter 2s ease-out;animation:blackout 90s forwards}*:not(body){animation:sepiaTone 70s forwards}@keyframes blackout{0%{background:default}100%{background:black}}@keyframes sepiaTone{0%{filter:none}50%{filter:sepia(.8) brightness(.5)}90%{filter:sepia(1) brightness(.1)}100%{filter:sepia(1) brightness(0)}}</style></head>\"' >> $YAML_FILE
echo '' >> $YAML_FILE
echo '  routers:' >> $YAML_FILE
echo '    portainer-router:' >> $YAML_FILE
echo '      rule: \"Host(`portainer.DOMAIN_PLACEHOLDER_VARIABLE`)\"' >> $YAML_FILE
echo '      entryPoints:' >> $YAML_FILE
echo '        - web' >> $YAML_FILE
echo '      service: portainer-service' >> $YAML_FILE
echo '      middlewares:' >> $YAML_FILE
echo '        - dimscreenrewrite' >> $YAML_FILE
echo '' >> $YAML_FILE
echo '  services:' >> $YAML_FILE
echo '    portainer-service:' >> $YAML_FILE
echo '      loadBalancer:' >> $YAML_FILE
echo '        servers:' >> $YAML_FILE
echo '          - url: \"http://portainer:9000\"' >> $YAML_FILE



echo 'YAML content written to' $YAML_FILE


EOF
)

# Escape newlines for JSON
JOB_SCRIPT_ESCAPED=$(echo "$JOB_SCRIPT" | sed ':a;N;$!ba;s/\n/\\n/g')

# For debugging - print JSON payload
JSON_PAYLOAD="{
  \"title\":\"Sleep Time Begin\",
  \"enabled\":1,
  \"category\":\"general\",
  \"plugin\":\"shellplug\",
  \"target\":\"$CRONICLE_TARGET\",
  \"params\":{
    \"script\":\"$JOB_SCRIPT_ESCAPED\"
  },
  \"timing\":{
    \"minutes\":[0],
    \"hours\":[$END_HOUR],
    \"weekdays\":[0,1,2,3,4,5,6]
  },
  \"max_children\":1,
  \"timeout\":300,
  \"notes\":\"This script creates the directory /opt/cronicle/things if it doesn't exist, creates a file named 'pants', writes 'yay' to it, and then reads the file contents.\"
}"

echo "Sending request with payload:"
echo "$JSON_PAYLOAD"

JOB_RESPONSE=$(curl -s -X POST "$CRONICLE_URL/api/app/create_event?api_key=$API_KEY" \
  -H "Content-Type: application/json" \
  -d "$JSON_PAYLOAD")

# Check response
echo "Job creation response: $JOB_RESPONSE"

# Extract job ID if successful
if echo "$JOB_RESPONSE" | grep -q "\"code\":0"; then
  JOB_ID=$(echo "$JOB_RESPONSE" | grep -o '"id":"[^"]*' | head -1 | cut -d'"' -f4)
  echo "Job created successfully with ID: $JOB_ID"
#  echo "$JOB_ID" > last_job_id.txt
#  echo "Job ID saved to last_job_id.txt"
else
  echo "Failed to create job."
  echo "Error details: $JOB_RESPONSE"
fi

# Traefik cron using a sidecar


## Traefik business hours sidecar


Initially, whoami that runs during work hours has no service or route. That is created by the script that runs. The script then re-runs every 60 seconds to check the time you've set. If it sees that time, it makes the respective priority change.

If you want to change your hours, you'll have to change the script and re-generate the container.

Here’s a detailed, step‑by‑step breakdown of what this `set_priority.sh` script does, including all variables and logic paths.

---

### 1. Variable Definitions

1. **`YAML_FILE`**

   * Path to the generated Traefik dynamic configuration file:

     ```bash
     YAML_FILE="/app/dynamic_config/work-service.yaml"
     ```
   * All subsequent writes go into this file.

2. **`LOW_PRIORITY` and `HIGH_PRIORITY`**

   * Numeric priority values for routing rules:

     ```bash
     LOW_PRIORITY=10
     HIGH_PRIORITY=100
     ```
   * Lower number = lower precedence; higher number = higher precedence in Traefik.

3. **`START_HOUR` and `END_HOUR`**

   * Defines “work hours” during which the script should apply the high priority:

     ```bash
     START_HOUR=9   # 9 AM
     END_HOUR=17    # 5 PM
     ```
   * Hours expressed in 24‑hour format.

---

### 2. Ensuring the Config Directory Exists

```bash
mkdir -p "$(dirname "$YAML_FILE")"
```

* Uses `mkdir -p` to create `/app/dynamic_config` if it doesn’t already exist, preventing errors when writing the YAML file.

---

### 3. `get_priority()` Function

```bash
get_priority() {
  local hour
  hour=$(date +%H)
  if (( hour >= START_HOUR && hour < END_HOUR )); then
    echo "$HIGH_PRIORITY"
  else
    echo "$LOW_PRIORITY"
  fi
}
```

1. **Retrieve current hour**

   * `date +%H` returns the hour (00–23).
2. **Compare against work‑hour window**

   * If `hour` is ≥ `START_HOUR` **and** `< END_HOUR`, output `HIGH_PRIORITY`; otherwise output `LOW_PRIORITY`.
3. **Return value**

   * The function echo’s the numeric priority, which callers can capture.

---

### 4. `write_config()` Function

```bash
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
```

1. **Parameter**

   * Accepts one argument: the desired priority value.
2. **Here‑document**

   * Overwrites (`>`) the YAML file at `$YAML_FILE` with a Traefik dynamic config:

     * **Router** named `work` listening on `work.example.com`
     * **Service** `work-service` pointing to `http://work-service:80`
     * **`priority:`** set to the function’s argument.
3. **Logging**

   * Echoes a timestamped message indicating which priority was written.

---

### 5. Script Entry Point

```bash
echo "[$(date)] Priority updater script started"
```

* Logs startup time.

---

### 6. Initial Configuration Write

```bash
current_priority=$(get_priority)
write_config "$current_priority"
```

1. **Determine initial priority** by calling `get_priority`.
2. **Write the initial YAML** with that priority via `write_config`.

---

### 7. Continuous Monitoring Loop

```bash
while true; do
  new_priority=$(get_priority)
  
  if [[ "$new_priority" != "$current_priority" ]]; then
    write_config "$new_priority"
    current_priority="$new_priority"
    echo "[$(date)] Priority changed to $current_priority"
  else
    echo "[$(date)] No change in priority. Current: $current_priority"
  fi

  echo "[$(date)] Sleeping for 60 seconds before next check..."
  sleep 60
done
```

1. **Infinite loop** (`while true`) to keep the script running as a daemon.
2. **Recompute priority** every iteration (`get_priority`).
3. **Conditional update**

   * **If** new value ≠ current, call `write_config` and update `current_priority`, logging the change.
   * **Else**, log that there was no change.
4. **Sleep** for 60 seconds, then repeat.

   * Ensures the router’s priority is updated in near real‑time as work hours begin/end.

---

### Overall Behavior

* **During 9 AM–5 PM** (`START_HOUR` to `<END_HOUR`), the router rule’s priority is set high (`100`), making traffic to `work.example.com` take precedence.
* **Outside those hours**, priority drops to low (`10`), deprioritizing that service.
* The script automatically adjusts Traefik’s dynamic config and logs every change or check, running indefinitely with a 1‑minute check interval.

This design allows workloads or routing rules to shift priority based on the time of day without manual intervention.









* * *


## A fun way to use the traefik sidecar

We can setup this same concept to setup a "stop using your computer, and go to bed" 


We will inject a header on specific apps that prevents you from using them. This could be a media streaming app, or a productivity app. Whatever.




* * *

### Sepia Sleep Services Demo 

![Example of the middlewear on traefik injecting a header that runs css blacking out the screen](https://raw.githubusercontent.com/MarcusHoltz/marcusholtz.github.io/refs/heads/main/assets/img/posts/turnoffservices--sepia-your-services.gif)



---

### HIGH-LEVEL OVERVIEW

This Bash script dynamically toggles a middleware setting in a YAML configuration file based on the current time.

* It **enables or disables** a middleware (`dimscreenrewrite`) depending on whether the current time falls within a "sleep" or "awake" period.
* The configuration is updated every minute.
* Used in scenarios like **darkening a UI** during night hours for a service (`portainer-router`).

---

### SCRIPT BLOCKS AND LOGIC FLOW

Here's how the script is organized:

1. **Configuration Setup**

   * Define YAML path, awake/sleep rules, and time window.

2. **Directory Preparation**

   * Ensure target config directory exists.

3. **Priority Evaluation Function (`get_priority`)**

   * Decide whether middleware should be active based on current time.

4. **YAML Writer Function (`write_config`)**

   * Generates the YAML file with or without the middleware.

5. **Startup Actions**

   * Log start, write initial config.

6. **Main Loop**

   * Every minute:

     * Re-evaluate time.
     * Update YAML if the middleware state needs changing.
     * Log changes.

---

### DETAILED EXPLANATION

#### 1. **Configuration Setup**

```bash
YAML_FILE="/app/dynamic_config/work-service.yaml"
AWAKE_RULE=
SLEEP_RULE="- dimscreenrewrite"
START_HOUR=${START_HOUR:-23}
END_HOUR=${END_HOUR:-5}
```

* `YAML_FILE`: Output path for the YAML config.
* `AWAKE_RULE` / `SLEEP_RULE`: Strings inserted into YAML.
* `START_HOUR`, `END_HOUR`: Define when middleware should be active. Defaults to 11 PM–5 AM.

---

#### 2. **Directory Preparation**

```bash
mkdir -p "$(dirname "$YAML_FILE")"
```

* Ensures `/app/dynamic_config/` exists before writing to `work-service.yaml`.

---

#### 3. **Determine Priority (`get_priority`)**

```bash
get_priority() {
  ...
}
```

* Gets current hour via `date +%H`.
* **Two scenarios**:

  * **Non-midnight range** (e.g., 16 to 23): `hour >= START_HOUR && hour < END_HOUR`
  * **Cross-midnight** (e.g., 23 to 5): `hour >= START_HOUR || hour < END_HOUR`
* Outputs either `SLEEP_RULE` or `AWAKE_RULE`.

---

#### 4. **Write YAML Config (`write_config`)**

```bash
write_config() {
  local middlewear_switch=$1
  ...
}
```

* Writes full config with or without the middleware line.
* The middleware (`dimscreenrewrite`) injects CSS into HTTP responses to dim the UI.

---

#### 5. **Startup**

```bash
echo "... script started"
current_priority=$(get_priority)
write_config "$current_priority"
```

* Logs start time.
* Writes initial config based on current time.

---

#### 6. **Main Loop**

```bash
while true; do
  new_priority=$(get_priority)
  ...
  sleep 60
done
```

* Every 60 seconds:

  * Checks time again.
  * If middleware status should change, rewrites YAML and logs it.
  * If not, just logs current status.

---

### ASCII FLOW DIAGRAM

Here’s a simplified flow of the script logic using ASCII:

```
+----------------------+
|  Start the Script    |
+----------+-----------+
           |
           v
+------------------------+
| Get Current Hour (H)   |
+------------------------+
           |
           v
+---------------------------------------------+
| Is it within the sleep time window?         |
|  (Handles overnight hours like 23-5)        |
+---------------------+-----------------------+
      Yes             |           No
       |              |            |
       v              v            v
+---------------+   +---------------+
| Use SLEEP_RULE|   | Use AWAKE_RULE|
+---------------+   +---------------+
       \               /
        v             v
     +--------------------+
     | write_config()     |
     +--------------------+
        |
        v
+----------------------------+
| Sleep 60 seconds           |
| Then loop back to recheck |
+----------------------------+
```

---


































































































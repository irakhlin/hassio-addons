#!/command/with-contenv bashio
# ==============================================================================
# Home Assistant Add-on: USBIP Mounter
# Configures USBIP devices
# ==============================================================================

# Configure mount script for all usbip devices
declare server_address
declare bus_id
declare script_directory
declare mount_script

script_directory="/usr/local/bin"
mount_script="/usr/local/bin/mount_devices"

if ! bashio::fs.directory_exists "${script_directory}"; then
  bashio::log.info  "Creating script directory"
  mkdir -p "${script_directory}" || bashio::exit.nok "Could not create bin folder"
fi

if bashio::fs.file_exists "${mount_script}"; then
  rm "${mount_script}"
fi

if ! bashio::fs.file_exists "${mount_script}"; then
  touch ${mount_script}
  chmod +x ${mount_script}
  echo '#!/command/with-contenv bashio' > "${mount_script}"
  echo 'set -x' >> "${mount_script}"
  echo 'mount -o remount -t sysfs sysfs /sys' >> "${mount_script}"
  echo 'declare -a SERVERS' >> "${mount_script}"
  echo 'declare -a BUSIDS' >> "${mount_script}"

  index=0
  for device in $(bashio::config 'devices|keys'); do
    server_address=$(bashio::config "devices[${device}].server_address")
    bus_id=$(bashio::config "devices[${device}].bus_id")
    bashio::log.info "Registering device from server ${server_address} on bus ${bus_id}"
    echo "SERVERS[${index}]=\"${server_address}\"" >> "${mount_script}"
    echo "BUSIDS[${index}]=\"${bus_id}\"" >> "${mount_script}"
    index=$((index + 1))
  done

  # Attach once immediately, then keep checking `usbip port` and re-attach
  # anything that drops off - the original one-shot attach left the add-on
  # unable to recover from a usbip connection timeout without a manual
  # restart, which also unnecessarily detached every OTHER device it manages
  # (e.g. this would have knocked a working Bluetooth adapter offline just to
  # recover an unrelated dropped Z-Wave stick).
  #
  # Per-device exponential backoff on the attach attempt itself (added after
  # observing a real outage in production): during a real outage the
  # server/network side stays down for a while, and hammering `usbip attach`
  # again every single 15s compounds an already unstable connection instead
  # of giving it room to recover. The `usbip port` status check stays on the
  # full 15s cadence regardless (cheap, non-disruptive, and needed to
  # promptly notice a fresh drop on any device) - only the disruptive attach
  # command backs off, and only for the specific device that's failing;
  # other devices keep their own independent cadence. Backoff resets to the
  # base interval the moment a device is seen attached again.
  cat <<'MOUNT_LOOP' >> "${mount_script}"

CHECK_INTERVAL_SECS=15
MAX_BACKOFF_SECS=300

declare -a FAIL_COUNT
declare -a NEXT_ATTEMPT

while true; do
  now=$(date +%s)
  for i in "${!BUSIDS[@]}"; do
    server="${SERVERS[$i]}"
    busid="${BUSIDS[$i]}"

    if usbip port 2>/dev/null | grep -q "usbip://${server}:3240/${busid}"; then
      FAIL_COUNT[$i]=0
      continue
    fi

    if [ "${NEXT_ATTEMPT[$i]:-0}" -gt "${now}" ]; then
      continue
    fi

    fails=${FAIL_COUNT[$i]:-0}
    backoff=$(( CHECK_INTERVAL_SECS * (2 ** fails) ))
    if [ "${backoff}" -gt "${MAX_BACKOFF_SECS}" ]; then
      backoff=${MAX_BACKOFF_SECS}
    fi

    bashio::log.warning "Device ${busid} on ${server} is not attached - (re)attaching (attempt $((fails + 1)); if this fails too, next retry backs off ${backoff}s)"
    /usr/sbin/usbip --debug attach -r "${server}" -b "${busid}"

    FAIL_COUNT[$i]=$((fails + 1))
    NEXT_ATTEMPT[$i]=$((now + backoff))
  done
  sleep "${CHECK_INTERVAL_SECS}"
done
MOUNT_LOOP
fi
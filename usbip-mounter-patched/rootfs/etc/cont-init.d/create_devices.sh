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
  cat <<'MOUNT_LOOP' >> "${mount_script}"

CHECK_INTERVAL_SECS=15

while true; do
  for i in "${!BUSIDS[@]}"; do
    server="${SERVERS[$i]}"
    busid="${BUSIDS[$i]}"
    if ! usbip port 2>/dev/null | grep -q "usbip://${server}:3240/${busid}"; then
      bashio::log.warning "Device ${busid} on ${server} is not attached - (re)attaching"
      /usr/sbin/usbip --debug attach -r "${server}" -b "${busid}"
    fi
  done
  sleep "${CHECK_INTERVAL_SECS}"
done
MOUNT_LOOP
fi
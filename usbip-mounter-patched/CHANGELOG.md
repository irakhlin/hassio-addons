<!-- https://developers.home-assistant.io/docs/add-ons/presentation#keeping-a-changelog -->

## 1.0.0

- Initial release

## 1.0.1

- Fix sysfs remount to mount usbip
- Use local build on HA instead of image pull from docker

## 1.5.3

- Replace the one-shot device attach with a background loop that checks
  `usbip port` every 15s and re-attaches any device that has dropped off
  (e.g. after a `vhci_hcd: connection timed out with pending urbs` disconnect).
  Previously a dropped device required a manual add-on restart to recover,
  which also unnecessarily detached every other device the add-on manages.

## 1.5.4

- Bump build base image from `20.0.1` to `21.0.2` - the old pin had drifted
  out of sync with current Alpine package repos, breaking the build with
  apk dependency conflicts.
- Add field names/descriptions for the `devices` config (Server Address:
  IP.AD.RE.SS syntax, Bus ID: X-X.X syntax) so they show up in the add-on's
  Configuration UI instead of just raw schema.

## 1.5.5

- Add per-device exponential backoff (15s, 30s, 60s, ... capped at 300s) on
  the re-attach attempt itself when a device is found not attached. During a
  real outage the previous 1.5.3 loop retried every single 15s indefinitely,
  compounding an already-unstable connection instead of giving it room to
  recover. The `usbip port` status check still runs every 15s regardless
  (cheap, needed to promptly notice a fresh drop) - only the disruptive
  attach command backs off, per-device, and resets to the base interval the
  moment that device is seen attached again.

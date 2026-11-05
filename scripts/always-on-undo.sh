#!/usr/bin/env bash
# Revert always-on.sh: disables its drop-ins and resets the XFCE keys to defaults.
# Run as your normal user from the XFCE desktop session: bash always-on-undo.sh
set -euo pipefail
ME="$(id -un)"
sudo -v
for f in /etc/systemd/logind.conf.d/10-always-on.conf \
         /etc/systemd/sleep.conf.d/10-always-on.conf \
         /etc/UPower/UPower.conf.d/10-always-on.conf \
         /etc/NetworkManager/conf.d/zz-always-on-wifi-powersave-off.conf \
         /etc/sysctl.d/90-always-on.conf \
         /etc/lightdm/lightdm.conf.d/50-always-on-autologin.conf; do
  if [ -e "$f" ]; then sudo mv "$f" "$f.disabled" && echo "disabled $f"; fi
done
sudo systemctl reload systemd-logind
sudo systemctl restart upower
sudo systemctl reload NetworkManager
sudo sysctl -q -w kernel.panic=0 kernel.softlockup_panic=0 kernel.hardlockup_panic=0 kernel.hung_task_panic=0
sudo loginctl disable-linger "$ME"
for k in lid-action-on-ac lid-action-on-battery inactivity-on-ac inactivity-on-battery \
         critical-power-level critical-power-action; do
  xfconf-query -c xfce4-power-manager -p "/xfce4-power-manager/$k" -r 2>/dev/null || true
done
echo "reverted. *.disabled copies kept; delete them when sure."
echo "If you ran with INTEL_ONLY=1: 'sudo prime-select on-demand' (or your previous profile), then reboot."

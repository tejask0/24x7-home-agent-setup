#!/usr/bin/env bash
# REFERENCE SCRIPT. Read it and adapt it to your machine before running.
# It applies section 3 of the guide (always-on settings) on Xubuntu 26.04 / XFCE.
#
# Run as your normal user from a terminal INSIDE the XFCE desktop session
# (the XFCE settings need the session D-Bus), NOT with sudo:
#     bash always-on.sh
# Laptops with Intel + NVIDIA (Optimus) graphics that should go Intel-only:
#     INTEL_ONLY=1 bash always-on.sh
# Why: a headless box doesn't need the NVIDIA card, older ones never power down in
# on-demand mode (heat, power), and its driver was a suspect in a display-standby freeze.
# Never set INTEL_ONLY on a machine whose only GPU is NVIDIA: it has no display without it.
#
# It calls sudo itself for root parts. Every root file is a NEW drop-in; nothing
# packaged is edited, so package upgrades don't conflict. Undo: always-on-undo.sh
# Not covered here (do by hand, see the guide): blank keyring password, x11vnc, autostart.
set -euo pipefail

ME="$(id -un)"
SESSION="${DESKTOP_SESSION:-xubuntu}"
[ "$ME" != root ] || { echo "run as your normal user, not root"; exit 1; }
xfconf-query -c xfce4-power-manager -l >/dev/null 2>&1 \
  || { echo "no XFCE session D-Bus: run this from a terminal on the desktop (or over VNC)"; exit 1; }
sudo -v

echo "== 1. logind: ignore the lid, never act on idle (covers the login screen / no-session case)"
sudo install -d /etc/systemd/logind.conf.d
sudo tee /etc/systemd/logind.conf.d/10-always-on.conf >/dev/null <<'EOF'
# always-on.sh: 24x7 lid-closed machine.
[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
IdleAction=ignore
EOF
# Reload, don't restart: a restart can end the desktop session.
sudo systemctl reload systemd-logind

echo "== 2. systemd-sleep: refuse every sleep mode, from any source"
sudo install -d /etc/systemd/sleep.conf.d
sudo tee /etc/systemd/sleep.conf.d/10-always-on.conf >/dev/null <<'EOF'
# always-on.sh: never sleep.
[Sleep]
AllowSuspend=no
AllowHibernation=no
AllowSuspendThenHibernate=no
AllowHybridSleep=no
EOF

echo "== 3. UPower: clean power-off if a power cut drains the battery"
sudo install -d /etc/UPower/UPower.conf.d
sudo tee /etc/UPower/UPower.conf.d/10-always-on.conf >/dev/null <<'EOF'
# always-on.sh: power off early and cleanly instead of trying to hibernate/sleep.
[UPower]
PercentageLow=30.0
PercentageCritical=20.0
PercentageAction=15.0
CriticalPowerAction=PowerOff
EOF
sudo systemctl restart upower

echo "== 4. Wi-Fi power saving off"
# zz- so it sorts after the packaged default-wifi-powersave-on.conf. Applies after a reconnect/reboot.
sudo tee /etc/NetworkManager/conf.d/zz-always-on-wifi-powersave-off.conf >/dev/null <<'EOF'
# always-on.sh: 2 = disable Wi-Fi power save (latency, dropped SSH/VNC).
[connection]
wifi.powersave = 2
EOF
sudo systemctl reload NetworkManager

echo "== 5. Reboot 10 s after a kernel panic; turn lockups and hung tasks into panics"
sudo tee /etc/sysctl.d/90-always-on.conf >/dev/null <<'EOF'
# always-on.sh: an unattended box should reboot, not hang.
kernel.panic = 10
kernel.softlockup_panic = 1
kernel.hardlockup_panic = 1
kernel.hung_task_panic = 1
EOF
sudo sysctl -q --system

echo "== 6. Linger: user services start at boot without a login"
sudo loginctl enable-linger "$ME"

echo "== 7. LightDM autologin into $SESSION (x11vnc needs a desktop after reboot)"
sudo install -d /etc/lightdm/lightdm.conf.d
sudo tee /etc/lightdm/lightdm.conf.d/50-always-on-autologin.conf >/dev/null <<EOF
# always-on.sh: boot straight into the desktop.
[Seat:*]
autologin-user=$ME
autologin-user-timeout=0
autologin-session=$SESSION
EOF

echo "== 8. XFCE Power Manager (it owns the lid while you're logged in)"
# Enum values (xfce4-power-manager 4.20, common/xfpm-enum-glib.h):
#   lid-action: 0 display off, 1 suspend, 2 hibernate, 3 lock (default), 4 nothing
#   critical-power-action: 0 nothing (default), 1 suspend, 2 hibernate, 3 ask, 4 shut down
#   inactivity-on-*: minutes, 0 = never
xp() { xfconf-query -c xfce4-power-manager -p "/xfce4-power-manager/$1" -n -t "$2" -s "$3"; }
xp lid-action-on-ac           int  0
xp lid-action-on-battery      int  0
xp inactivity-on-ac           int  0
xp inactivity-on-battery      int  0
xp critical-power-level       int  20
xp critical-power-action      int  4
xp logind-handle-lid-switch   bool false

if [ "${INTEL_ONLY:-0}" = 1 ]; then
  echo "== 9. PRIME: Intel GPU only (needs a reboot)"
  command -v prime-select >/dev/null || { echo "prime-select not found; skipping"; }
  if command -v prime-select >/dev/null && [ "$(prime-select query)" != intel ]; then sudo prime-select intel; fi
else
  echo "== 9. PRIME: skipped (set INTEL_ONLY=1 on Intel+NVIDIA laptops)"
fi

echo "== verify"
bash "$(dirname "$0")/always-on-verify.sh" || true
echo "done. Reboot, then run always-on-verify.sh again."

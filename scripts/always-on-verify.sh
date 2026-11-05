#!/usr/bin/env bash
# Read-only check of every always-on setting. Safe to run any time, no sudo.
ME="$(id -un)"
WIFI="$(iw dev 2>/dev/null | awk '/Interface/{print $2; exit}')"
ok=0; bad=0
chk() { if [ "$2" = "$3" ]; then echo "OK   $1 = $2"; ok=$((ok+1)); else echo "FAIL $1 = '$2' (want '$3')"; bad=$((bad+1)); fi; }
cfg() { systemd-analyze cat-config "$1" 2>/dev/null | grep -E "^$2=" | tail -1 | cut -d= -f2; }

chk logind.HandleLidSwitch              "$(cfg systemd/logind.conf HandleLidSwitch)" ignore
chk logind.HandleLidSwitchExternalPower "$(cfg systemd/logind.conf HandleLidSwitchExternalPower)" ignore
chk logind.IdleAction                   "$(cfg systemd/logind.conf IdleAction)" ignore
chk sleep.AllowSuspend                  "$(cfg systemd/sleep.conf AllowSuspend)" no
chk sleep.AllowHibernation              "$(cfg systemd/sleep.conf AllowHibernation)" no
chk logind.CanSuspend                   "$(busctl call org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager CanSuspend 2>/dev/null)" "s \"no\""
chk upower.CriticalPowerAction          "$(grep -h '^CriticalPowerAction=' /etc/UPower/UPower.conf.d/10-always-on.conf 2>/dev/null | cut -d= -f2)" PowerOff
[ -n "$WIFI" ] && chk "wifi.power_save($WIFI)" "$(iw dev "$WIFI" get power_save 2>/dev/null | awk '{print $3}')" off
chk kernel.panic                        "$(sysctl -n kernel.panic)" 10
chk kernel.softlockup_panic             "$(sysctl -n kernel.softlockup_panic)" 1
chk kernel.hardlockup_panic             "$(sysctl -n kernel.hardlockup_panic)" 1
chk kernel.hung_task_panic              "$(sysctl -n kernel.hung_task_panic)" 1
chk linger                              "$(loginctl show-user "$ME" -p Linger --value)" yes
chk lightdm.autologin-user              "$(grep -h '^autologin-user=' /etc/lightdm/lightdm.conf.d/*.conf 2>/dev/null | tail -1 | cut -d= -f2)" "$ME"
command -v prime-select >/dev/null && echo "INFO prime-select = $(prime-select query 2>/dev/null) (want intel on Optimus laptops)"
x() { xfconf-query -c xfce4-power-manager -p "/xfce4-power-manager/$1" 2>/dev/null || echo unset; }
chk xfpm.lid-action-on-ac        "$(x lid-action-on-ac)" 0
chk xfpm.lid-action-on-battery   "$(x lid-action-on-battery)" 0
chk xfpm.inactivity-on-ac        "$(x inactivity-on-ac)" 0
chk xfpm.inactivity-on-battery   "$(x inactivity-on-battery)" 0
chk xfpm.critical-power-action   "$(x critical-power-action)" 4
chk xfpm.critical-power-level    "$(x critical-power-level)" 20
echo "-- $ok ok, $bad fail"
[ "$bad" = 0 ]

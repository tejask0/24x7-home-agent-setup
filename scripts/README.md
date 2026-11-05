# Reference scripts

These are the scripts from the original build, made generic. They're here so an agent can see what was actually done. They're not a one-click installer: **read them and adapt them to your machine before running anything.**

| File | What it does |
|---|---|
| `always-on.sh` | Applies the always-on settings (section 3 of the guide): lid, sleep, low battery, Wi-Fi power saving, panic and lockup reboot, linger, autologin, XFCE Power Manager. Optional Intel-only graphics with `INTEL_ONLY=1`. Run it from a terminal on the desktop, not with sudo. |
| `always-on-verify.sh` | Read-only OK/FAIL check of every setting. No sudo. |
| `always-on-undo.sh` | Reverts `always-on.sh`. |
| `x11vnc.service` | User systemd unit template for VNC, bound to the Tailscale IPs only. |
| `claude-rc.desktop` | XFCE autostart template that opens Claude Remote Control at login. |

Not scripted, do by hand (see the guide): the blank keyring password, Tailscale login and key expiry, SSH hardening, and the app logins.

Tested on Xubuntu 26.04 LTS, X11, XFCE 4.20, LightDM.

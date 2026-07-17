#!/usr/bin/env bash
choice=$(printf 'Lock\nSuspend\nLogout\nReboot\nShutdown\n' | tofi --prompt-text "Power: ")

case "$choice" in
Lock) noctalia msg session lock ;;
Suspend) noctalia msg session lock-and-suspend ;;
Logout) noctalia msg session logout ;;
Reboot) noctalia msg session reboot ;;
Shutdown) noctalia msg session shutdown ;;
esac

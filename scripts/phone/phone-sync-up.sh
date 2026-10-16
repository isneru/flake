[ "$2" = up ] || exit 0
systemctl --user -M neru@ start --no-block phone-sync.service || true

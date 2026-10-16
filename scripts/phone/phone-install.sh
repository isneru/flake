key="${XDG_DATA_HOME:-$HOME/.local/share}/phone-launcher/key.jks"
signed=$(mktemp --suffix=.apk)
trap 'rm -f "$signed" "$signed.idsig"' EXIT

if [ ! -f "$key" ]; then
  mkdir -p "${key%/*}"
  keytool -genkeypair -keystore "$key" -storepass android -alias bare \
    -keyalg RSA -keysize 2048 -validity 36500 -dname CN=bare
fi
apksigner sign --ks "$key" --ks-pass pass:android --out "$signed" "$apk"

if [ "$(adb get-state 2>/dev/null)" = device ]; then
  adb install -r "$signed"
  adb shell pm grant dev.neru.bare android.permission.POST_NOTIFICATIONS
  adb shell dumpsys deviceidle whitelist +dev.neru.bare
  adb shell appops set com.termux REQUEST_INSTALL_PACKAGES allow
  adb shell appops set com.termux SYSTEM_ALERT_WINDOW allow
elif what=apk file=$signed && online && send phone -o ConnectTimeout=20 -o ProxyCommand="tailscale nc %h %p"; then
  echo "phone-install: sent over the tailnet, tap Update on the phone"
else
  echo "phone-install: no adb device, and the phone is not reachable on the tailnet" >&2
  exit 1
fi

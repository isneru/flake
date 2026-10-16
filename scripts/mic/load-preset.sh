for _ in $(seq 100); do
  [ -S "$XDG_RUNTIME_DIR/EasyEffectsServer" ] && break
  sleep 0.1
done
exec easyeffects --load-preset mic

IFACE=${1:-wlp5s0}
echo "Creating virtual interface 'mon0' from $IFACE..."
if sudo iw dev "$IFACE" interface add mon0 type monitor; then
  sudo ip link set mon0 up
  echo "Done. Interface 'mon0' is up."
else
  echo "Error creating interface. Check if it already exists or if you need sudo privileges."
fi

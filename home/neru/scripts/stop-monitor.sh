echo "Removing virtual interface 'mon0'..."
sudo ip link set mon0 down 2>/dev/null
if sudo iw dev mon0 del; then
  echo "Interface 'mon0' removed successfully."
else
  echo "Error removing interface. Maybe it doesn't exist or you need sudo privileges."
fi

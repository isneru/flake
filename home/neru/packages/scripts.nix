{ pkgs, inputs, ... }:

{
  home.packages = with pkgs; [
    (writeShellScriptBin "start-monitor" ''
      IFACE=''${1:-wlp5s0} 

      echo "Creating virtual interface 'mon0' from $IFACE..."

      if sudo iw dev "$IFACE" interface add mon0 type monitor; then
        sudo ip link set mon0 up
        echo "Done. Interface 'mon0' is up."
      else
        echo "Error creating interface. Check if it already exists or if you need sudo privileges."
      fi
    '')

    (writeShellScriptBin "stop-monitor" ''
      echo "Removing virtual interface 'mon0'..."

      sudo ip link set mon0 down 2>/dev/null

      if sudo iw dev mon0 del; then
        echo "Interface 'mon0' removed successfully."
      else
        echo "Error removing interface. Maybe it doesn't exist or you need sudo privileges."
      fi
    '')

    (pkgs.writeShellApplication {
      name = "ns";
      runtimeInputs = with pkgs; [
        fzf
        (nix-search-tv.overrideAttrs {
          env.GOEXPERIMENT = "jsonv2";
          allowGoReference = true;
        })
      ];
      text = ''exec "${pkgs.nix-search-tv.src}/nixpkgs.sh" "$@"'';
    })

  ];
}

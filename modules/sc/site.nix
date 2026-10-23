{ ... }:
{
  flake.modules.nixos.sc =
    { config, pkgs, ... }:
    let
      port = 8485;
      tunnel = "a15e0de7-30b0-49c6-b701-06d631842ddf";
      page = pkgs.writeTextDir "page.html" (builtins.readFile ./page.html);
    in
    {
      services.caddy.virtualHosts."http://:${toString port}".extraConfig = ''
        bind 127.0.0.1
        header X-Robots-Tag "noindex, nofollow"
        header X-Content-Type-Options nosniff
        root * /srv/sharkcoders

        @blocked path_regexp /\.
        @code path *.java *.py *.lua *.rpy
        @file file

        route {
          respond @blocked 404
          handle @file {
            header @code Content-Type "text/plain; charset=utf-8"
            file_server
          }
          handle {
            root * ${page}
            rewrite * /page.html
            templates {
              root /srv/sharkcoders
            }
            file_server
          }
        }
      '';

      systemd.services.caddy.serviceConfig.BindReadOnlyPaths = [
        "-/home/neru/sharkcoders/partilha:/srv/sharkcoders"
      ];

      # The `isep` tunnel, Caddy and cloudflared are declared here as well as in isep-site, so
      # either site works without the other. With both, the equal definitions merge.
      services.caddy.enable = true;

      sops.secrets.cloudflared-isep = { };

      services.cloudflared = {
        enable = true;
        tunnels.${tunnel} = {
          credentialsFile = config.sops.secrets.cloudflared-isep.path;
          ingress."sc.neru.sh" = "http://127.0.0.1:${toString port}";
          default = "http_status:404";
        };
      };

      systemd.services."cloudflared-tunnel-${tunnel}" = {
        startLimitIntervalSec = 0;
        serviceConfig.RestartSec = 5;
      };
    };
}

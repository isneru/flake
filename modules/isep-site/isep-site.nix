{ ... }:
{
  flake.modules.nixos.isep-site =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      port = 8484;
      tunnel = "a15e0de7-30b0-49c6-b701-06d631842ddf";
      notes = "/home/neru/notes/isep";
      page = pkgs.writeTextDir "page.html" (builtins.readFile ./page.html);
      fonts =
        pkgs.runCommand "isep-site-fonts"
          {
            nativeBuildInputs = [
              (pkgs.python3.withPackages (ps: [
                ps.fonttools
                ps.brotli
              ]))
            ];
          }
          ''
            shopt -s nullglob
            mkdir $out
            for f in ${
              lib.concatMapStringsSep " " (p: "${p}/share/fonts/*/NerdFonts/*/*NerdFontMono-{Regular,Bold}.*") (
                with pkgs.nerd-fonts;
                [
                  departure-mono
                  geist-mono
                  go-mono
                ]
              )
            }; do
              name=$(basename "$f")
              name=''${name%.*}
              pyftsubset "$f" --flavor=woff2 \
                --unicodes=U+0020-024F,U+2000-206F,U+20AC,U+2190-21FF,U+2200-22FF,U+2500-25FF,U+F000-F2E0 \
                --output-file="$out/''${name/NerdFontMono/ Nerd Font Mono}.woff2"
            done
          '';
    in
    {
      services.caddy = {
        enable = true;
        virtualHosts."http://:${toString port}".extraConfig = ''
          bind 127.0.0.1
          header X-Robots-Tag "noindex, nofollow"
          header X-Content-Type-Options nosniff
          root * /srv/isep

          @blocked path_regexp /(\.|node_modules(/|$))
          @climbing vars_regexp {http.request.uri.path} /\.\.(/|$)
          @outside {
            not path /
            not file /{http.request.uri.path.0}/materials/
          }
          @file {
            not path *.md
            file
          }
          @sandboxed not path *.pdf
          @download {
            query download=*
            file
          }

          route {
            respond /robots.txt "User-agent: *
          Disallow: /"
            handle /.site/theme.css {
              root * /var/lib/isep-site
              rewrite * /theme.css
              header Cache-Control no-cache
              file_server
            }
            handle_path /.site/fonts/* {
              root * ${fonts}
              header Content-Type font/woff2
              header Cache-Control "public, max-age=604800"
              file_server
            }
            respond @blocked 404
            respond @climbing 404
            respond @outside 404
            handle @download {
              header Content-Disposition attachment
              file_server
            }
            handle @file {
              header @sandboxed Content-Security-Policy "sandbox allow-scripts"
              file_server
            }
            handle {
              root * ${page}
              rewrite * /page.html
              templates {
                root /srv/isep
              }
              file_server
            }
          }
        '';
      };

      systemd.services.caddy.serviceConfig.BindReadOnlyPaths = [ "${notes}:/srv/isep" ];

      systemd.tmpfiles.rules = [ "d /var/lib/isep-site 0755 neru users -" ];

      sops.secrets.cloudflared-isep = { };

      services.cloudflared = {
        enable = true;
        tunnels.${tunnel} = {
          credentialsFile = config.sops.secrets.cloudflared-isep.path;
          ingress."isep.neru.sh" = "http://127.0.0.1:${toString port}";
          default = "http_status:404";
        };
      };

      systemd.services."cloudflared-tunnel-${tunnel}" = {
        startLimitIntervalSec = 0;
        serviceConfig.RestartSec = 5;
      };
    };

  flake.modules.homeManager.isep-site = {
    theme-engine.apps.isep-site = {
      template = builtins.readFile ./theme.css.tmpl;
      target = "/var/lib/isep-site/theme.css";
    };
  };
}

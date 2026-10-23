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
      editPort = 8486;
      writerPort = 8487;
      access = {
        team = "https://neruzt.cloudflareaccess.com";
        aud = "ab95e63582efbf83b56ee3ff2ab4d397e12de289b48562154fda66c534b3e3cc";
        owner = "isdiogon@gmail.com";
      };
      tunnel = "a15e0de7-30b0-49c6-b701-06d631842ddf";
      notes = "/home/neru/notes/isep";
      page = pkgs.writeTextDir "page.html" (builtins.readFile ./page.html);
      review = pkgs.writeTextDir "review.html" (builtins.readFile ./review.html);
      npm =
        path: hash:
        pkgs.fetchurl {
          url = "https://registry.npmjs.org/${path}.tgz";
          inherit hash;
        };
      libs = pkgs.runCommand "isep-site-libs" { } ''
        get() { mkdir "$2" && tar xzf "$1" -C "$2" --strip-components=1; }
        get ${npm "markdown-it/-/markdown-it-14.1.0" "sha256-fE+rTU05/pggan+77UseNXjytwtradMJQT4z7sFA4Z8="} md
        get ${npm "markdown-it-footnote/-/markdown-it-footnote-4.0.0" "sha256-MZ4ceEt0pztHPnahu3JdN3DFouQJ39jDDFBPOicS4nI="} footnote
        get ${npm "markdown-it-task-lists/-/markdown-it-task-lists-2.1.1" "sha256-jp7VFSlvEdcWpkYMC9Nf+hYwA6Nzptj2XVPqn4rsZn4="} tasks
        get ${npm "markdown-it-texmath/-/markdown-it-texmath-1.0.0" "sha256-r8ofMoBH7NmhIe0xSCMrkRZsN0dmARyPhTcqeg0YwrM="} texmath
        get ${npm "katex/-/katex-0.16.22" "sha256-6eDRZ9sxdUgcutr/OOjZCxMPaj3bRRpH5DxXf9UR82U="} katex
        get ${npm "@highlightjs/cdn-assets/-/cdn-assets-11.11.1" "sha256-KKBr9uvMIhjG6EK9tPHINTUIqMraWehREPkYkvVyYZU="} hljs
        get ${npm "mermaid/-/mermaid-11.4.0" "sha256-JvfV1UmM2ImzL5ETSbN3LVF9mct8Ah9qnK3KDRnyDhI="} mermaid
        mkdir -p $out/katex $out/mermaid/chunks
        cp md/dist/markdown-it.min.js footnote/dist/markdown-it-footnote.min.js \
          tasks/dist/markdown-it-task-lists.min.js texmath/texmath.js hljs/highlight.min.js $out/
        cp -r katex/dist/katex.min.js katex/dist/katex.min.css katex/dist/fonts $out/katex/
        cp mermaid/dist/mermaid.esm.min.mjs $out/mermaid/
        cp -r mermaid/dist/chunks/mermaid.esm.min $out/mermaid/chunks/
      '';
      writer = pkgs.writeShellApplication {
        name = "isep-edit";
        runtimeInputs = [
          # keep-sorted start
          (pkgs.python3.withPackages (ps: [
            ps.cryptography
            ps.pyjwt
          ]))
          pkgs.git
          # keep-sorted end
        ];
        text = ''exec python3 ${./isep_edit.py} "$@"'';
      };
      csp = "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob: https:; object-src 'none'; base-uri 'none'; frame-ancestors 'none'; form-action 'self'";
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
      routes = extra: ''
        bind 127.0.0.1
        header X-Robots-Tag "noindex, nofollow"
        header X-Content-Type-Options nosniff
        root * /srv/isep

        @blocked path_regexp /(\.|node_modules(/|$))
        @climbing vars_regexp {http.request.uri.path} /\.\.(/|$)
        @outside {
          not path /
          not path /lab /lab/*
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
          ${extra}
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
          handle_path /.site/lib/* {
            root * ${libs}
            header Cache-Control "public, max-age=604800"
            file_server
          }
          handle_path /.site/* {
            root * ${./site}
            header Cache-Control no-cache
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
            header Content-Security-Policy "${csp}"
            root * ${page}
            rewrite * /page.html
            templates {
              root /srv/isep
            }
            file_server
          }
        }
      '';
    in
    {
      services.caddy = {
        enable = true;
        virtualHosts."http://:${toString port}".extraConfig = routes "";
        virtualHosts."http://:${toString editPort}".extraConfig = routes ''
          vars edit true
          handle /.edit/api/* {
            request_body {
              max_size 2MiB
            }
            reverse_proxy 127.0.0.1:${toString writerPort}
          }
          handle /.edit/review {
            header Content-Security-Policy "${csp}"
            header Cache-Control no-cache
            root * ${review}
            rewrite * /review.html
            file_server
          }
        '';
      };

      systemd.services.caddy.serviceConfig.BindReadOnlyPaths = [ "-${notes}:/srv/isep" ];

      systemd.tmpfiles.rules = [ "d /var/lib/isep-site 0755 neru users -" ];

      systemd.services.isep-edit = {
        description = "Browser editing for isep.neru.sh";
        wantedBy = [ "multi-user.target" ];
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
        environment = {
          ISEP_EDIT_TEAM = access.team;
          ISEP_EDIT_AUD = access.aud;
          ISEP_EDIT_OWNER = access.owner;
          ISEP_EDIT_ORIGIN = "https://isep-edit.neru.sh";
          ISEP_EDIT_PORT = toString writerPort;
        };
        serviceConfig = {
          ExecStart = lib.getExe writer;
          User = "neru";
          Group = "users";
          StateDirectory = "isep-edit";
          ProtectHome = "tmpfs";
          BindPaths = [ "${notes}:/srv/isep" ];
          ProtectSystem = "strict";
          PrivateTmp = true;
          PrivateDevices = true;
          NoNewPrivileges = true;
          CapabilityBoundingSet = "";
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          ProtectKernelLogs = true;
          ProtectControlGroups = true;
          ProtectClock = true;
          ProtectHostname = true;
          RestrictNamespaces = true;
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          LockPersonality = true;
          SystemCallArchitectures = "native";
          SystemCallFilter = [ "@system-service" ];
          RestrictAddressFamilies = [
            "AF_UNIX"
            "AF_INET"
            "AF_INET6"
          ];
          UMask = "0022";
          Restart = "on-failure";
          RestartSec = 2;
        };
      };

      sops.secrets.cloudflared-isep = { };

      services.cloudflared = {
        enable = true;
        tunnels.${tunnel} = {
          credentialsFile = config.sops.secrets.cloudflared-isep.path;
          ingress."isep.neru.sh" = "http://127.0.0.1:${toString port}";
          ingress."isep-edit.neru.sh" = "http://127.0.0.1:${toString editPort}";
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

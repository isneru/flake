{ ... }:
{
  flake.modules.homeManager.browser =
    { ... }:
    {
      programs.helium = {
        enable = true;
        flags = [
          "--ozone-platform-hint=auto"
          "--start-maximized"
          # Hardware video decode via VA-API is still behind a feature flag on
          # Linux; needs intel-media-driver (modules/desktop.nix).
          "--enable-features=AcceleratedVideoDecodeLinuxGL"
        ];
        # vanilla Chromium's policy loader only looks at system-wide dirs
        # under /etc on Linux, so these per-user managed policies may not
        # actually be read; see the helium module's own caveat in policies'
        # description.
        policies = {
          BrowserSignin = 0;
          SyncDisabled = true;
          PasswordManagerEnabled = true;
        };
      };
    };
}

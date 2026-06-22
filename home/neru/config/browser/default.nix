{
  programs.helium = {
    enable = true;
    flags = [
      "--ozone-platform-hint=auto"
      "--start-maximized"
    ];
    policies = {
      BrowserSignin = 0;
      SyncDisabled = true;
      PasswordManagerEnabled = true;
    };
  };
}

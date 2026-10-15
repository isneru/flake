{ ... }:
{
  flake.modules.homeManager.starship = {
    programs.starship = {
      enable = true;
      enableZshIntegration = true;
      settings = {
        add_newline = true;
        format = "$time$username$hostname$directory$character";

        time = {
          disabled = false;
          time_format = "%H:%M";
          style = "bg:234 fg:245";
          format = "[ $time ]($style)";
        };

        username = {
          show_always = true;
          style_user = "bg:237 fg:250";
          style_root = "bg:237 fg:red";
          format = "[ $user]($style)";
        };

        hostname = {
          ssh_only = false;
          style = "bg:237 fg:245";
          format = "[@$hostname ]($style)";
        };

        directory = {
          truncation_length = 3;
          truncation_symbol = "";
          style = "bg:240 fg:253";
          format = "[ $path ]($style)";
        };

        git_branch = {
          symbol = "";
          style = "bg:240 fg:purple";
          format = "[$symbol $branch ]($style)";
        };

        git_status = {
          disabled = true;
          style = "bg:240 fg:yellow";
          format = "([$all_status$ahead_behind ]($style))";
        };

        character = {
          success_symbol = "[ ❯ ](fg:253)";
          error_symbol = "[ ❯ ](fg:red)";
        };
      };
    };
  };
}

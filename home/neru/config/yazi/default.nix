{ style, ... }:
let
  c = style.colors;
in
{
  programs.yazi = {
    enable = true;
    shellWrapperName = "y";
    settings = {
      mgr = {
        show_hidden = true;
        show_symlink = true;
        ratio = [
          1
          3
          4
        ];
      };
    };
    theme = {
      mgr = {
        cwd = {
          fg = c.fgMuted;
        };

        hovered = {
          fg = c.fg;
          bg = c.bgAlt;
        };
        preview_hovered = {
          underline = true;
        };

        find_keyword = {
          fg = c.orange;
          italic = true;
        };
        find_position = {
          fg = c.error;
          bg = "reset";
          italic = true;
        };

        marker_copied = {
          fg = c.cyan;
          bg = c.cyan;
        };
        marker_cut = {
          fg = c.error;
          bg = c.error;
        };
        marker_marked = {
          fg = c.border;
          bg = c.border;
        };
        marker_selected = {
          fg = c.fgMuted;
          bg = c.fgMuted;
        };

        count_copied = {
          fg = c.bg;
          bg = c.fgMuted;
        };
        count_cut = {
          fg = c.bg;
          bg = c.error;
        };
        count_selected = {
          fg = c.bg;
          bg = c.fgMuted;
        };

        border_symbol = "│";
        border_style = {
          fg = c.border;
        };

        syntect_theme = "";
      };

      tabs = {
        active = {
          fg = c.fg;
          bg = c.bgAlt;
        };
        inactive = {
          fg = c.border;
          bg = c.bgDim;
        };
      };

      mode = {
        normal_main = {
          fg = c.fgMuted;
          bg = c.bgAlt;
          bold = false;
        };
        normal_alt = {
          fg = c.bgAlt;
          bg = c.fgMuted;
        };
        select_main = {
          fg = c.bg;
          bg = c.cyan;
          bold = true;
        };
        select_alt = {
          fg = c.cyan;
          bg = c.bgAlt;
        };
        unset_main = {
          fg = c.bg;
          bg = c.orange;
          bold = true;
        };
        unset_alt = {
          fg = c.orange;
          bg = c.bgAlt;
        };
      };

      status = {
        perm_type = {
          fg = c.border;
        };
        perm_read = {
          fg = c.fgMuted;
        };
        perm_write = {
          fg = c.fgMuted;
        };
        perm_exec = {
          fg = c.cyan;
        };
        perm_sep = {
          fg = c.border;
        };
        progress_label = {
          fg = c.fgMuted;
          bold = false;
        };
        progress_normal = {
          fg = c.border;
          bg = c.bgAlt;
        };
        progress_error = {
          fg = c.error;
          bg = c.bgAlt;
        };
      };

      input = {
        border = {
          fg = c.border;
        };
        title = {
          fg = c.fgMuted;
        };
        value = {
          fg = c.fg;
        };
        selected = {
          reversed = true;
        };
      };

      cmp = {
        border = {
          fg = c.border;
        };
        active = {
          fg = c.fg;
          bg = c.bgAlt;
        };
        inactive = {
          fg = c.fgMuted;
        };
      };

      tasks = {
        border = {
          fg = c.border;
        };
        title = {
          fg = c.fgMuted;
        };
        hovered = {
          underline = true;
        };
      };

      which = {
        mask = {
          bg = c.bgDim;
        };
        cand = {
          fg = c.fgMuted;
        };
        rest = {
          fg = c.border;
        };
        desc = {
          fg = c.fgMuted;
        };
        separator = "  ";
        separator_style = {
          fg = c.border;
        };
      };

      help = {
        on = {
          fg = c.fgMuted;
        };
        run = {
          fg = c.fgMuted;
        };
        desc = {
          fg = c.border;
        };
        hovered = {
          bg = c.bgAlt;
          bold = true;
        };
        footer = {
          fg = c.fgMuted;
          bg = c.bgAlt;
        };
      };

      notify = {
        title_info = {
          fg = c.fgMuted;
        };
        title_warn = {
          fg = c.orange;
        };
        title_error = {
          fg = c.error;
        };
      };

      filetype = {
        rules = [
          {
            mime = "image/*";
            fg = c.cyan;
          }
          {
            mime = "video/*";
            fg = c.purple;
          }
          {
            mime = "audio/*";
            fg = c.orange;
          }
          {
            mime = "application/zip";
            fg = c.fgMuted;
          }
          {
            mime = "application/gzip";
            fg = c.fgMuted;
          }
          {
            mime = "application/x-tar";
            fg = c.fgMuted;
          }
          {
            mime = "application/x-bzip";
            fg = c.fgMuted;
          }
          {
            mime = "application/x-bzip2";
            fg = c.fgMuted;
          }
          {
            mime = "application/x-7z-compressed";
            fg = c.fgMuted;
          }
          {
            mime = "application/x-rar";
            fg = c.fgMuted;
          }
          {
            url = "*/";
            fg = c.fg;
          }
          {
            url = "*";
            fg = c.fgDim;
          }
        ];
      };
    };
  };
}

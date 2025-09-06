-- Pull in the wezterm API
local wezterm = require("wezterm")

-- This will hold the configuration.
local config = wezterm.config_builder()

config.color_scheme = "Sonokai (Gogh)"
-- other color schemes:
-- config.color_scheme = "Gruvbox Material (Gogh)"
-- config.color_scheme = "nightfox"

config.window_background_opacity = 1.0
config.window_decorations = "RESIZE"
config.hide_tab_bar_if_only_one_tab = true

config.font = wezterm.font("JetBrains Mono", { weight = 'DemiLight' }) -- VictorMono Nerd Font Mono
-- other fonts:
-- config.font = wezterm.font("VictorMono Nerd Font Mono", { weight = 'Medium' })

config.font_size = 12.5
config.line_height = 1.05

config.send_composed_key_when_left_alt_is_pressed = true
config.send_composed_key_when_right_alt_is_pressed = true

config.keys = {
  -- Make Option-Left equivalent to Alt-b which many line editors interpret as backward-word
  { key = "LeftArrow",  mods = "OPT", action = wezterm.action({ SendString = "\x1bb" }) },
  -- Make Option-Right equivalent to Alt-f; forward-word
  { key = "RightArrow", mods = "OPT", action = wezterm.action({ SendString = "\x1bf" }) },
}

-- and finally, return the configuration to wezterm
return config

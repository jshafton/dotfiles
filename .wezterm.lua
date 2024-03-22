-- Pull in the wezterm API
local wezterm = require("wezterm")

-- This will hold the configuration.
local config = wezterm.config_builder()

-- This is where you actually apply your config choices

config.color_scheme = "nightfox"
config.window_background_opacity = 0.95
config.window_decorations = "RESIZE"

config.font = wezterm.font("JetBrainsMono Nerd Font Mono")
config.font_size = 12.5

config.send_composed_key_when_left_alt_is_pressed = true
config.send_composed_key_when_right_alt_is_pressed = true

-- and finally, return the configuration to wezterm
return config

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
config.window_padding = {
  bottom = 0,
}
local tomorrow_night = {
  foreground = '#c5c8c6',
  background = '#1d1f21',
  highlight = '#373b41',
  status_line = '#282a2e',
  comment = '#969896',
  red = '#cc6666',
  orange = '#de935f',
  yellow = '#f0c674',
  green = '#b5bd68',
  aqua = '#8abeb7',
  blue = '#81a2be',
  purple = '#b294bb',
  pane = '#4d5057',
}

config.colors = {
  foreground = tomorrow_night.foreground,
  ansi = {
    tomorrow_night.background,
    tomorrow_night.red,
    tomorrow_night.green,
    tomorrow_night.yellow,
    tomorrow_night.blue,
    tomorrow_night.purple,
    tomorrow_night.aqua,
    tomorrow_night.foreground,
  },
  brights = {
    tomorrow_night.status_line,
    tomorrow_night.red,
    tomorrow_night.green,
    tomorrow_night.yellow,
    tomorrow_night.blue,
    tomorrow_night.purple,
    tomorrow_night.aqua,
    tomorrow_night.highlight,
  },
  tab_bar = {
    background = tomorrow_night.status_line,
    active_tab = {
      bg_color = tomorrow_night.purple,
      fg_color = tomorrow_night.background,
      intensity = 'Bold',
    },
    inactive_tab = {
      bg_color = tomorrow_night.status_line,
      fg_color = tomorrow_night.comment,
    },
    inactive_tab_hover = {
      bg_color = tomorrow_night.highlight,
      fg_color = tomorrow_night.foreground,
      italic = true,
    },
    new_tab = {
      bg_color = tomorrow_night.status_line,
      fg_color = tomorrow_night.comment,
    },
    new_tab_hover = {
      bg_color = tomorrow_night.highlight,
      fg_color = tomorrow_night.foreground,
      italic = true,
    },
  },
}

-- config.font = wezterm.font("JetBrains Mono", { weight = 'DemiLight' }) -- VictorMono Nerd Font Mono
-- other fonts:
config.font = wezterm.font("VictorMono Nerd Font Mono", { weight = 'Medium' })

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

config.enable_kitty_keyboard = true

-- Claude notification handling via OSC 1337 user vars
local pending_claude_notifications = {}

wezterm.on('user-var-changed', function(window, pane, name, value)
  wezterm.log_info('user-var-changed: name=' .. name .. ' value=' .. tostring(value):sub(1, 100))

  if name == 'claude_notify' then
    local ok, data = pcall(wezterm.json_parse, value)
    if not ok then
      wezterm.log_error('claude_notify: failed to parse JSON: ' .. tostring(value):sub(1, 200))
      return
    end
    wezterm.log_info('claude_notify: parsed data - project=' ..
      tostring(data.project) .. ' hostname=' .. tostring(data.hostname))

    -- Build notification text
    local subtitle = data.project or 'Claude'
    if data.branch and data.branch ~= '' then
      subtitle = subtitle .. ' (' .. data.branch .. ')'
    end
    if data.hostname and data.hostname ~= '' then
      subtitle = subtitle .. ' @ ' .. data.hostname
    end
    local message = data.message or 'Needs your attention'

    -- Save state for click-to-switch (WezTerm pane + tmux info)
    local pane_id = tostring(pane:pane_id())
    local tmux_session = data.tmux_session or ''
    local tmux_window = data.tmux_window or ''
    local tmux_pane = data.tmux_pane or ''
    local state = string.format('{"wezterm_pane":"%s","tmux_session":"%s","tmux_window":"%s","tmux_pane":"%s"}',
      pane_id, tmux_session, tmux_window, tmux_pane)
    wezterm.log_info('claude_notify: saving state=' .. state)
    wezterm.background_child_process({
      '/bin/sh', '-c',
      "echo '" .. state .. "' > \"$HOME/.claude/last-notification-pane\"",
    })

    -- Use terminal-notifier for macOS notifications (non-blocking)
    wezterm.log_info('claude_notify: sending notification - subtitle=' .. subtitle .. ' message=' .. message)
    wezterm.background_child_process({
      '/opt/homebrew/bin/terminal-notifier',
      '-title', 'Claude Code',
      '-subtitle', subtitle,
      '-message', message,
      '-sound', 'Pop',
      '-execute', os.getenv('HOME') .. '/bin/claude-switch-to-last.sh',
    })

    -- Mark pane for visual tab indicator
    pending_claude_notifications[tostring(pane:pane_id())] = true
    wezterm.log_info('claude_notify: done, marked pane ' .. tostring(pane:pane_id()) .. ' for notification')
  end
end)

local tab_palette = {
  base = tomorrow_night.status_line,
  accent = tomorrow_night.purple,
  text = tomorrow_night.foreground,
  bright = tomorrow_night.foreground,
  separator = tomorrow_night.highlight,
  alert_bg = tomorrow_night.red,
  alert_fg = tomorrow_night.background,
}

local function tab_title(tab_info)
  if tab_info.tab_title and #tab_info.tab_title > 0 then
    return tab_info.tab_title
  end
  return tab_info.active_pane.title
end

local function format_tab(title, is_active)
  local bg = tab_palette.base
  local fg = tab_palette.text
  local intensity = 'Normal'
  if is_active then
    bg = tab_palette.accent
    fg = tab_palette.base
    intensity = 'Bold'
  end

  return {
    { Background = { Color = bg } },
    { Foreground = { Color = fg } },
    { Attribute = { Intensity = intensity } },
    { Text = ' ' .. title .. ' ' },
    { Background = { Color = tab_palette.base } },
    { Foreground = { Color = tab_palette.separator } },
    { Attribute = { Intensity = 'Normal' } },
    { Text = '▏' },
  }
end

wezterm.on('format-tab-title', function(tab, tabs, panes, config, hover, max_width)
  local title = tab_title(tab)

  -- Check if any pane in this tab has a pending notification
  for _, pane_info in ipairs(tab.panes) do
    if pending_claude_notifications[tostring(pane_info.pane_id)] then
      if tab.is_active then
        pending_claude_notifications[tostring(pane_info.pane_id)] = nil
      else
        return {
          { Background = { Color = tab_palette.alert_bg } },
          { Foreground = { Color = tab_palette.alert_fg } },
          { Attribute = { Intensity = 'Bold' } },
          { Text = ' ⚡ ' .. title .. ' ' },
          { Background = { Color = tab_palette.base } },
          { Foreground = { Color = tab_palette.separator } },
          { Attribute = { Intensity = 'Normal' } },
          { Text = '▏' },
        }
      end
    end
  end

  return format_tab(title, tab.is_active)
end)

-- and finally, return the configuration to wezterm
return config

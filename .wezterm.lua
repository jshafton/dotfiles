-- Pull in the wezterm API
local wezterm = require("wezterm")

-- This will hold the configuration.
local config = wezterm.config_builder()

-- Using inline `config.colors` (token-dark) below; leave any scheme commented.
-- config.color_scheme = "Sonokai (Gogh)"
-- config.color_scheme = "Gruvbox Material (Gogh)"
-- config.color_scheme = "nightfox"

config.window_background_opacity = 1.0
config.window_decorations = "RESIZE"
config.hide_tab_bar_if_only_one_tab = true
config.window_padding = {
  bottom = 0,
}
local token_dark = {
  foreground = '#e8e4dc',
  background = '#262624',
  highlight = '#3a3a37',
  status_line = '#1d1d1c',
  comment = '#5a5955',
  red = '#c67777',
  orange = '#d97757',
  yellow = '#c4a855',
  green = '#7da47a',
  aqua = '#6ba8a8',
  blue = '#7b9ebd',
  purple = '#a68bbf',
  pane = '#5a5955',
  bright_red = '#d97757',
  bright_green = '#98bf95',
  bright_yellow = '#c4956a',
  bright_blue = '#96b8d3',
  bright_purple = '#bea5d4',
  bright_aqua = '#88c0c0',
  bright_white = '#e8e4dc',
  selection_bg = '#3a3a37',
  palette_7 = '#d4cfc6',
}

config.colors = {
  foreground = token_dark.foreground,
  background = token_dark.background,
  cursor_bg = token_dark.foreground,
  cursor_fg = token_dark.background,
  cursor_border = token_dark.foreground,
  selection_bg = token_dark.selection_bg,
  selection_fg = token_dark.foreground,
  ansi = {
    token_dark.status_line,
    token_dark.red,
    token_dark.green,
    token_dark.yellow,
    token_dark.blue,
    token_dark.purple,
    token_dark.aqua,
    token_dark.palette_7,
  },
  brights = {
    token_dark.comment,
    token_dark.bright_red,
    token_dark.bright_green,
    token_dark.bright_yellow,
    token_dark.bright_blue,
    token_dark.bright_purple,
    token_dark.bright_aqua,
    token_dark.bright_white,
  },
  tab_bar = {
    background = token_dark.status_line,
    active_tab = {
      bg_color = token_dark.purple,
      fg_color = token_dark.background,
      intensity = 'Bold',
    },
    inactive_tab = {
      bg_color = token_dark.status_line,
      fg_color = token_dark.comment,
    },
    inactive_tab_hover = {
      bg_color = token_dark.highlight,
      fg_color = token_dark.foreground,
      italic = true,
    },
    new_tab = {
      bg_color = token_dark.status_line,
      fg_color = token_dark.comment,
    },
    new_tab_hover = {
      bg_color = token_dark.highlight,
      fg_color = token_dark.foreground,
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
  base = token_dark.status_line,
  accent = token_dark.purple,
  text = token_dark.foreground,
  bright = token_dark.foreground,
  separator = token_dark.highlight,
  alert_bg = token_dark.red,
  alert_fg = token_dark.background,
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

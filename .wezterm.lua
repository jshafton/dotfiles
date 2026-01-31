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
    wezterm.log_info('claude_notify: parsed data - project=' .. tostring(data.project) .. ' hostname=' .. tostring(data.hostname))

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

wezterm.on('format-tab-title', function(tab, tabs, panes, config, hover, max_width)
  local title = tab.active_pane.title

  -- Check if any pane in this tab has a pending notification
  for _, pane_info in ipairs(tab.panes) do
    if pending_claude_notifications[tostring(pane_info.pane_id)] then
      if tab.is_active then
        pending_claude_notifications[tostring(pane_info.pane_id)] = nil
      else
        return {
          { Background = { Color = '#e6a000' } },
          { Foreground = { Color = '#1a1a1a' } },
          { Text = ' ⚡ ' .. title .. ' ' },
        }
      end
    end
  end

  return title
end)

-- and finally, return the configuration to wezterm
return config

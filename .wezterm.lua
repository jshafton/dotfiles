-- Pull in the wezterm API
local wezterm = require("wezterm")

-- This will hold the configuration.
local config = wezterm.config_builder()

-- Custom color schemes live in .config/wezterm/colors/*.toml.
-- Set this to switch themes, then reload config (CMD+R).
local THEME = "nordic" -- one of: "token-dark", "nordfox", "kanagawa-wave", "kanagawa-dragon", "nordic"
config.color_scheme = THEME

config.window_background_opacity = 1.0
config.window_decorations = "RESIZE"
config.hide_tab_bar_if_only_one_tab = true
config.window_padding = {
  bottom = 0,
}

-- config.font = wezterm.font("JetBrains Mono", { weight = 'DemiLight' }) -- VictorMono Nerd Font Mono
-- other fonts:
config.font = wezterm.font("VictorMono Nerd Font Mono", { weight = "Medium" })

config.font_size = 12.5
config.line_height = 1.05

config.send_composed_key_when_left_alt_is_pressed = true
config.send_composed_key_when_right_alt_is_pressed = true

config.keys = {
  -- Make Option-Left equivalent to Alt-b which many line editors interpret as backward-word
  { key = "LeftArrow", mods = "OPT", action = wezterm.action({ SendString = "\x1bb" }) },
  -- Make Option-Right equivalent to Alt-f; forward-word
  { key = "RightArrow", mods = "OPT", action = wezterm.action({ SendString = "\x1bf" }) },
}

config.enable_kitty_keyboard = true

-- Claude notification handling via OSC 1337 user vars
local pending_claude_notifications = {}

wezterm.on("user-var-changed", function(window, pane, name, value)
  wezterm.log_info("user-var-changed: name=" .. name .. " value=" .. tostring(value):sub(1, 100))

  if name == "open_url" then
    if value and value:match("^https?://") then
      wezterm.log_info("open_url: opening " .. value)
      wezterm.open_with(value)
    else
      wezterm.log_error("open_url: rejected non-http URL: " .. tostring(value):sub(1, 200))
    end
    return
  end

  if name == "claude_notify" then
    local ok, data = pcall(wezterm.json_parse, value)
    if not ok then
      wezterm.log_error("claude_notify: failed to parse JSON: " .. tostring(value):sub(1, 200))
      return
    end
    wezterm.log_info(
      "claude_notify: parsed data - project=" .. tostring(data.project) .. " hostname=" .. tostring(data.hostname)
    )

    -- Build notification text
    local subtitle = data.project or "Claude"
    if data.branch and data.branch ~= "" then
      subtitle = subtitle .. " (" .. data.branch .. ")"
    end
    if data.hostname and data.hostname ~= "" then
      subtitle = subtitle .. " @ " .. data.hostname
    end
    local message = data.message or "Needs your attention"

    -- Save state for click-to-switch (WezTerm pane + tmux info)
    local pane_id = tostring(pane:pane_id())
    local tmux_session = data.tmux_session or ""
    local tmux_window = data.tmux_window or ""
    local tmux_pane = data.tmux_pane or ""
    local state = string.format(
      '{"wezterm_pane":"%s","tmux_session":"%s","tmux_window":"%s","tmux_pane":"%s"}',
      pane_id,
      tmux_session,
      tmux_window,
      tmux_pane
    )
    wezterm.log_info("claude_notify: saving state=" .. state)
    wezterm.background_child_process({
      "/bin/sh",
      "-c",
      "echo '" .. state .. '\' > "$HOME/.claude/last-notification-pane"',
    })

    -- Use terminal-notifier for macOS notifications (non-blocking)
    wezterm.log_info("claude_notify: sending notification - subtitle=" .. subtitle .. " message=" .. message)
    wezterm.background_child_process({
      "/opt/homebrew/bin/terminal-notifier",
      "-title",
      "Claude Code",
      "-subtitle",
      subtitle,
      "-message",
      message,
      "-sound",
      "Pop",
      "-execute",
      os.getenv("HOME") .. "/bin/claude-switch-to-last.sh",
    })

    -- Mark pane for visual tab indicator
    pending_claude_notifications[tostring(pane:pane_id())] = true
    wezterm.log_info("claude_notify: done, marked pane " .. tostring(pane:pane_id()) .. " for notification")
  end
end)

local function tab_title(tab_info)
  if tab_info.tab_title and #tab_info.tab_title > 0 then
    return tab_info.tab_title
  end
  return tab_info.active_pane.title
end

local function format_tab(title, is_active, palette)
  local bg = palette.tab_bar.background
  local fg = palette.foreground
  local intensity = "Normal"
  if is_active then
    bg = palette.tab_bar.active_tab.bg_color
    fg = palette.tab_bar.active_tab.fg_color
    intensity = "Bold"
  end

  return {
    { Background = { Color = bg } },
    { Foreground = { Color = fg } },
    { Attribute = { Intensity = intensity } },
    { Text = " " .. title .. " " },
    { Background = { Color = palette.tab_bar.background } },
    { Foreground = { Color = palette.tab_bar.inactive_tab_hover.bg_color } },
    { Attribute = { Intensity = "Normal" } },
    { Text = "▏" },
  }
end

wezterm.on("format-tab-title", function(tab, tabs, panes, config, hover, max_width)
  local palette = config.resolved_palette
  local title = tab_title(tab)

  -- Check if any pane in this tab has a pending notification
  for _, pane_info in ipairs(tab.panes) do
    if pending_claude_notifications[tostring(pane_info.pane_id)] then
      if tab.is_active then
        pending_claude_notifications[tostring(pane_info.pane_id)] = nil
      else
        return {
          { Background = { Color = palette.ansi[2] } }, -- red
          { Foreground = { Color = palette.background } },
          { Attribute = { Intensity = "Bold" } },
          { Text = " ⚡ " .. title .. " " },
          { Background = { Color = palette.tab_bar.background } },
          { Foreground = { Color = palette.tab_bar.inactive_tab_hover.bg_color } },
          { Attribute = { Intensity = "Normal" } },
          { Text = "▏" },
        }
      end
    end
  end

  return format_tab(title, tab.is_active, palette)
end)

-- and finally, return the configuration to wezterm
return config

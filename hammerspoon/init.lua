require("hs.ipc")

local UPLOAD_SCRIPT = os.getenv("HOME") .. "/bin/raycast/share-screenshot.sh"
local REMOTE_HOST = "shafjac-dev"

-- F18 is sent by Karabiner when Hyper+G is pressed (Hyper = right cmd+ctrl+shift+opt)
hs.hotkey.bind({}, "f18", function()
  local baseline = hs.pasteboard.changeCount()
  hs.urlevent.openURL("shottr://grab/area")

  -- Wait for clipboard to stabilize after user explicitly copies from Shottr
  local lastSeen = baseline
  local stableCount = 0
  local attempts = 0
  local t
  t = hs.timer.doEvery(0.3, function()
    attempts = attempts + 1
    local current = hs.pasteboard.changeCount()
    if current ~= lastSeen then
      lastSeen = current
      stableCount = 0
    elseif current ~= baseline and hs.pasteboard.readImage() then
      stableCount = stableCount + 1
      if stableCount >= 2 then -- stable for ~0.6s
        t:stop()
        hs.task.new(UPLOAD_SCRIPT, nil, { REMOTE_HOST }):start()
      end
    elseif attempts > 200 then -- 60s timeout, user cancelled
      t:stop()
    end
  end)
end)

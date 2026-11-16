-- Claude Code gives the subscription limits only to its status line command, so that command
-- (modules/features/claude-statusline.sh) saves them to FILE and this widget reads them back.
local FILE = (noctalia.getenv("XDG_CACHE_HOME") or noctalia.expandPath("~/.cache")) .. "/claude-rate-limits.json"
local WARN = 90

local visible = nil
local shown = nil

local function duration(seconds)
  local minutes = math.max(1, math.ceil(seconds / 60))
  if minutes < 60 then
    return minutes .. " min"
  end
  local hours = minutes // 60
  if hours < 24 then
    return string.format("%d h %d min", hours, minutes % 60)
  end
  return string.format("%d d %d h", hours // 24, hours % 24)
end

-- Claude Code leaves out a window whose reset time has passed, so a missing one is empty too.
local function window(limits, name, now)
  local w = limits[name]
  if type(w) ~= "table" or type(w.used_percentage) ~= "number" or type(w.resets_at) ~= "number" then
    return 0, "0%"
  end
  if w.resets_at <= now then
    return 0, "0%"
  end
  local percent = string.format("%.0f%%", w.used_percentage)
  return w.used_percentage, percent .. ", resets in " .. duration(w.resets_at - now)
end

local function setVisible(on)
  if on ~= visible then
    visible = on
    barWidget.setVisible(on)
  end
end

local function refresh()
  local content = noctalia.readFile(FILE)
  if not content then
    setVisible(false)
    return
  end
  local data = noctalia.json.decode(content)
  if type(data) ~= "table" or type(data.rate_limits) ~= "table" then
    return
  end

  local now = noctalia.nowMs() // 1000
  local session, sessionText = window(data.rate_limits, "five_hour", now)
  local week, weekText = window(data.rate_limits, "seven_day", now)
  local age = now - (tonumber(data.updated_at) or now)
  local updated = age < 60 and "just now" or duration(age) .. " ago"

  local key = sessionText .. "|" .. weekText .. "|" .. updated
  if key ~= shown then
    shown = key
    local color = math.max(session, week) >= WARN and "error" or "on_surface"
    barWidget.setGlyph("asterisk")
    barWidget.setGlyphColor(color)
    barWidget.setColor(color)
    barWidget.setText(string.format("%.0f%%", session))
    barWidget.setTooltip({
      { "Session (5 h)", sessionText },
      { "Week", weekText },
      { "Updated", updated },
    })
  end
  setVisible(true)
end

function update()
  noctalia.setUpdateInterval(5000)
  refresh()
end

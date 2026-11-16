local OFF = "shield-lock"
local ON = "shield-lock-filled"

local connected = nil

local function show(on)
  if on == connected then
    return
  end
  connected = on
  barWidget.setGlyph(on and ON or OFF)
  barWidget.setTooltip(on and "Proton VPN connected: click to disconnect" or "Proton VPN off: click to connect")
end

local function refresh()
  show(noctalia.fileExists("/sys/class/net/wg-proton"))
end

function update()
  noctalia.setUpdateInterval(2000)
  refresh()
end

function onClick()
  local verb = connected and "down" or "up"
  noctalia.runAsync({ "nmcli", "connection", verb, "proton-vpn" }, function(result)
    if result.exitCode ~= 0 then
      noctalia.notifyError("Proton VPN", "nmcli connection " .. verb .. " failed: " .. result.stderr)
    end
    refresh()
  end)
end

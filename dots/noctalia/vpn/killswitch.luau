-- The skull images are generated in modules/features/noctalia.nix so they follow the theme.
local OFF = "skull.svg"
local ON = "skull-filled.svg"
local SIZE = 20

local armed = nil

local function show(on)
  if on == armed then
    return
  end
  armed = on
  barWidget.setImage(on and ON or OFF, false, SIZE)
  barWidget.setTooltip(on and "Kill switch on: click to turn off" or "Kill switch off: click to turn on")
end

local function refresh()
  noctalia.runAsync({ "systemctl", "is-active", "--quiet", "proton-killswitch.service" }, function(result)
    show(result.exitCode == 0)
  end)
end

function update()
  noctalia.setUpdateInterval(2000)
  refresh()
end

-- proton-killswitch-toggle sends its own notification on success.
function onClick()
  noctalia.runAsync({ "proton-killswitch-toggle" }, function(result)
    if result.exitCode ~= 0 then
      noctalia.notifyError("Kill switch", "Toggle failed: " .. result.stderr)
    end
    refresh()
  end)
end

-- lualine theme from the canonical palette; deployed as lua/lualine/themes/oxocarbon.lua.
local c = require('palette').colors

local function mode(color)
  return {
    a = { fg = c.bg, bg = color, gui = 'bold' },
    b = { fg = c.fg, bg = c.overlay },
    c = { fg = c.subtle, bg = c.surface },
  }
end

return {
  normal = mode(c.blue),
  insert = mode(c.green),
  visual = mode(c.purple),
  replace = mode(c.error),
  command = mode(c.yellow),
  terminal = mode(c.teal),
  inactive = {
    a = { fg = c.muted, bg = c.surface },
    b = { fg = c.muted, bg = c.surface },
    c = { fg = c.muted, bg = c.surface },
  },
}

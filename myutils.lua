
local screen = screen
local awful         = require("awful")
local naughty       = require("naughty")

local M = {}



M.reportMonitor = function (s)
   title = string.format("Monitor %s", s.index)
   monitorProps = string.format(
      "x: %s, y: %s\nh: %s, w: %s",
      s.geometry.x, s.geometry.y,
      s.geometry.height, s.geometry.width)
    naughty.notify({title = title,
                    text = monitorProps,
                    screen = s})
end

M.updateFocusWidget = function()
    for s in screen do
        s.focuswidget.checked = (s == awful.screen.focused())
    end
end


local getMyScreenSymbol = function(s)
   local x = s.geometry.x
   local y = s.geometry.y

   -- Translated Letter, i.e. after Colemak mapping
   if x == 0 then return 'a' end
   if x < 3640 then
      if y >= 1080 then
          return 'r' -- Main 32
      else
	      return 'w' -- Top 32 (TV)
      end
   end

   if x == 3640 then
      if y >= 1080 then
         return 's' --Bot 27
      else
         return 'f' -- Top 27
      end  
   end

   return "#" .. tostring(s.index)
end

M.updateScreenList = function () 
   
   -- translate the my index to built-in index
   local myScreenSymbol2Idx = {}
   -- translate built-in index to my index
   local myScreenIdx2Symbol = {}

   for s in screen do
      local screenSymbol = getMyScreenSymbol(s)
      myScreenSymbol2Idx[screenSymbol] = s.index
      myScreenIdx2Symbol[s.index] = screenSymbol
   end

   return myScreenSymbol2Idx, myScreenIdx2Symbol
   
end


return M

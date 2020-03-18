-- Offer functions related to pakcage
local screen = screen
local gears         = require("gears")
local client        = client
local awful         = require("awful")
local beautiful     = require("beautiful")
local naughty       = require("naughty")
local os = os
local next = next
local math = math
local table = table

local M = {}


M.init = function()
   M.filelist = {}
   M.lastFocusedClient = nil
   M.lastFocusedScreen = nil
   M.showDesktopStatus = false
   M.wallpaperMode = "max"
   M.filelistCMD = nil
   M.quiteMode = false
   M.icon = beautiful.refreshed
   -- M.datebaseUpdateLastTime = os.time()
   -- M.UPDATE_DATABASE_INTERVAL = 43200 -- 12h
   M.currentIdx = nil
   math.randomseed(os.time())
   
   local toggleMenu = {}
   if type(beautiful.wallpaper) == "table" then
      for idx, val in ipairs(beautiful.wallpaper) do
         table.insert(toggleMenu,
                      {"[Gallery] " .. val.name, function() M.toggleMode(idx) end})
      end
      M.wallpaperPath = beautiful.wallpaper[1].path
      M.wallpaperMode = beautiful.wallpaper[1].mode
   else
      M.wallpaperPath = beautiful.wallpaper
   end -- if type(beautiful.wallpaper)
   
   M.menu = {
      { "Refresh Wallpaper", function() M.refresh() end},
      { "Show Wallpaper Info", function() M.showWallpaperInfo(awful.screen.focused()) end},
      { "Update Wallpaper Files", function() M.updateFilelist() end},
      { "Change Wallpaper Interval", function() M.changeWallpaperInterval() end},
      { "Toggle Wallpaper Gallery", toggleMenu}}

   M.updateFilelist(true)
   M.timer = gears.timer {
      timeout = 900,
      call_now = false,
      autostart = false,
      callback = function() M.refresh() end}
   M.timer:start()

end -- M.init

M.changeWallpaperInterval = function()
    awful.prompt.run {
        prompt       = '<b>Wallpaper Interval (sec): </b>',
        text         = tostring(M.timer.timeout),
        bg_cursor    = '#ff0000',
        -- To use the default rc.lua prompt:
        textbox      = mouse.screen.mypromptbox.widget,
        exe_callback = function(input)
            if not input or #input == 0 then input = 900 end
            naughty.notify{ text = 'Set Wallpaper Interval: '.. input }
            M.timer.timeout = input
            M.timer:again()
        end
    }
end

M.setWallpaper = function(s)
   
   s.wallpaper = nil
   if type(M.wallpaperPath) == "function" then
      s.wallpaper = M.wallpaperPath(s)
   else
      if (M.wallpaperPath:sub(-1) == "/") then
         if next(M.filelist) ~= nil then
            if M.currentIdx == #M.filelist then
               M.currentIdx = nil -- reset to the beginning
            end
            M.currentIdx, s.wallpaper = next(M.filelist, M.currentIdx)
            s.currentIdx = M.currentIdx
         end
      else
         s.wallpaper = M.wallpaperPath
      end
   end -- if type(beautiful.wallpaper)
   
   if s.wallpaper ~= nil then

      if not M.quiteMode then
         M.showWallpaperInfo(s)
      end
      
      if M.wallpaperMode == "fit" then
         gears.wallpaper.fit(s.wallpaper, s)
      elseif M.wallpaperMode == "max" then
         gears.wallpaper.maximized(s.wallpaper, s)
      elseif M.wallpaperMode == "auto" then
         awful.spawn.easy_async_with_shell(
            "identify " .. s.wallpaper,
            function(out)
               local imgw, imgh = string.match(out, " (%d+)x(%d+) ")
               
               local imgratio = imgw / imgh
               local ratio = s.geometry.width / s.geometry.height
               
               local wallFunc
               
               if math.abs( (imgratio / ratio) - 1) > 0.4 then
                  wallFunc = gears.wallpaper.fit
               else
                  wallFunc = gears.wallpaper.maximized
               end
               wallFunc(s.wallpaper, s)
         end)
      end -- if M.wallpaperMode
      
   end
end

M.updateFilelist = function(doRefresh)
   local height = 100
   local width = 500
   local cmd
   
   M.currentIdx = nil
   M.filelist = {}

   if M.filelistCMD ~= nil then
      cmd = M.filelistCMD
   else
      cmd =  "find -L " .. M.wallpaperPath
         .. ' -iname "*.png" -or -iname "*.jpg" -or -iname "*.jpeg"'
   end
   awful.spawn.easy_async(
      cmd,
      function (out)
         naughty.notify(
            { title = "Updating wallpaper database",
              text  = "Folder: " .. M.wallpaperPath,
              icon  = M.icon, icon_size = 64,})
         
         
         if M.filelistCMD ~= nil then
            for s in out:gmatch("[^\r\n]+") do
               M.filelist[#M.filelist+1] = M.wallpaperPath .. s
            end
         else -- the find return absolute path
            for s in out:gmatch("[^\r\n]+") do
                if not string.match(s, "ignore") then
                   M.filelist[#M.filelist+1] = s
                end
            end
         end

         naughty.notify({ title = "Shuffling Wallpapers...",
                          text  = "Found: " .. #M.filelist .. " items",
                          icon  = M.icon, icon_size = 64})

         -- Fisher-Yates shuffle
         local j
         for i = #M.filelist, 2, -1 do
            j = math.random(i)
            M.filelist[i], M.filelist[j] = M.filelist[j], M.filelist[i]
         end
         
         naughty.notify({ title = "Wallpaper database updated!",
                          text  = "Found: " .. #M.filelist .. " items",
                          icon  = M.icon, icon_size = 64})
         
         if doRefresh then
            for s in screen do
               M.setWallpaper(s)
            end
         end
   end)
end -- end of M.updateFilelist

M.refresh = function(resetTimer, shift)
   -- resetTimer is used when user initiate a refresh
   local resetTimer = resetTimer or false
   local shift = shift or 0

   if M.currentIdx ~= nil then
      -- twice as the currentIdx is now pointing to the next one
      M.currentIdx = M.currentIdx + 2 * shift * screen:count()
      if M.currentIdx < 1 then
         M.currentIdx = nil
      end
   end

   for s in screen do
      M.setWallpaper(s)
   end

   if resetTimer then
      M.timer:again()
   end
end

M.showWallpaperInfo = function(s)

   local curIdx
   if s.currentIdx ~= nil then
      curIdx = s.currentIdx
   else
      curIdx = 'n/a'
   end

    naughty.notify(
        { title  = "Wallpaper Info",
          text   = "Filename:" .. s.wallpaper
             .. '\nPath:' .. M.wallpaperPath
             .. '\nIndex:' .. curIdx .. " (" .. #M.filelist .. ")",
        icon   = M.icon, icon_size = 64, screen = s})
end

M.toggleMode = function(idx)
   M.wallpaperPath = beautiful.wallpaper[idx].path
   M.wallpaperMode = beautiful.wallpaper[idx].mode
   M.quiteMode     = beautiful.wallpaper[idx].quite or false
   M.filelistCMD   = beautiful.wallpaper[idx].cmd or nil
   local interval  = beautiful.wallpaper[idx].interval or nil

   local quiteMode
   if M.quiteMode then
      quiteMode = 'on'
   else
      quiteMode = 'off'
   end

   naughty.notify({ title = "Wallpaper Mode Changed",
                    text  = "Path: " .. M.wallpaperPath
                       .. '\nMode: ' .. M.wallpaperMode
                       .. '\nQuite: ' .. quiteMode,
                    icon  = M.icon, icon_size = 64})
   if (M.wallpaperPath:sub(-1) == "/") then
      M.updateFilelist(true)
   end

   if interval ~= nil then
      naughty.notify{ text = 'Set Wallpaper Interval: ' .. interval }
      M.timer.timeout = interval
      M.timer:again()
   end

end

M.toggleShowDesktop = function()
   local text
   
   M.showDesktopStatus = not M.showDesktopStatus

   if M.showDesktopStatus then
      M.lastFocusedClient = client.focus
      M.lastFocusedScreen = awful.screen.focused()
      for s in screen do
         local wExist = false
         for _, t in ipairs(s.tags) do
            if t.name == "W" then
               t:view_only()
               wExist = true
               break
            end
         end -- tag in s.tags
         if not wExist then
            awful.tag.add("W", {screen = s}):view_only()
         end
      end
   else  -- not showing desktop
      for s in screen do
         for _, t in ipairs(s.tags) do
            if t.name == "W" then
               t:view_only()
               for _, c in ipairs(s.clients) do
                  c:move_to_tag(s.tags[1])
               end
               t:delete()
            end
         end -- tag in s.tags
      end -- s in screen
      -- Refocus the last focused screen
      if M.lastFocusedScreen ~= nil then
         client.focus = M.lastFocusedClient
         M.lastFocusedClient:raise()
      end
      awful.screen.focus(M.lastFocusedScreen)
   end

end -- M.toggleShowDesktop

return M

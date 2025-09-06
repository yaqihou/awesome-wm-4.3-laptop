-- Offer functions related to pakcage
local screen = screen
local gears         = require("gears")
local client        = client
local awful         = require("awful")
local beautiful     = require("beautiful")
local naughty       = require("naughty")
local lain    = require("lain")
local os, next, math, table = os, next, math, table

local modkey         = "Mod4"
local hyperkey       = "Mod3"
local altkey         = "Mod1"

local M = {}
local notiWidth = 600

-- Helper functions for ratio-based wallpaper selection
M.getScreenRatio = function(s)
   local width = s.geometry.width
   local height = s.geometry.height
   if width < height then
      return "portrait"
   else
      return "landscape" -- includes square screens
   end
end

M.getImageRatio = function(imagePath)
   -- TODO: move this to non-blocking async run
   local handle = io.popen("identify -ping -format '%w %h' '" .. imagePath .. "' 2>/dev/null")
   if not handle then return "unknown" end
   
   local result = handle:read("*a")
   handle:close()
   
   local width, height = result:match("(%d+) (%d+)")
   if not width or not height then return "unknown" end
   
   width, height = tonumber(width), tonumber(height)
   if width < height then
      return "portrait"
   else
      return "landscape"
   end
end

-- Lazy loading function to populate ratio-based caches
M.populateRatioCaches = function(batchSize)
   if not M.ratioBasedSelection or M.unprocessedCount == 0 then
      return
   end
   
   batchSize = batchSize or 10  -- Process 10 images at a time by default
   local processed = 0
   
   while processed < batchSize and M.processedIdx <= #M.filelist do
      local wallpaper = M.filelist[M.processedIdx]
      if wallpaper and wallpaper ~= "" then
         local ratio = M.getImageRatio(wallpaper)
         if ratio == "portrait" then
            table.insert(M.portraitList, {path = wallpaper, rawIdx = M.processedIdx})
         elseif ratio == "landscape" then
            table.insert(M.landscapeList, {path = wallpaper, rawIdx = M.processedIdx})
         else
            -- For unknown ratios, add to landscape as fallback
            table.insert(M.landscapeList, {path = wallpaper, rawIdx = M.processedIdx})
         end
         processed = processed + 1
      end
      M.processedIdx = M.processedIdx + 1
      M.unprocessedCount = M.unprocessedCount - 1
   end
end

-- Get next wallpaper for the given ratio
M.getNextWallpaperByRatio = function(desiredRatio)
   if not M.ratioBasedSelection then
      return nil, nil
   end
   
   local targetList, targetIdx
   if desiredRatio == "portrait" then
      targetList = M.portraitList
      targetIdx = M.portraitIdx
   else
      targetList = M.landscapeList  
      targetIdx = M.landscapeIdx
   end
   
   -- If we've reached the end of this list, try to populate more
   if targetIdx > #targetList and M.unprocessedCount > 0 then
      M.populateRatioCaches(10)
   end
   
   -- If still no wallpapers available, fall back to the other ratio
   if targetIdx > #targetList then
      if desiredRatio == "portrait" and #M.landscapeList > 0 then
         targetList = M.landscapeList
         targetIdx = M.landscapeIdx
      elseif desiredRatio == "landscape" and #M.portraitList > 0 then
         targetList = M.portraitList
         targetIdx = M.portraitIdx
      else
         return nil, nil
      end
   end
   
   if targetIdx <= #targetList then
      local wallpaperInfo = targetList[targetIdx]
      return wallpaperInfo.path, wallpaperInfo.rawIdx
   end
   
   return nil, nil
end


local wallpaperFunction = {
   fit=gears.wallpaper.fit,
   centered=gears.wallpaper.centered,
   max=gears.wallpaper.maximized,
   tile=gears.wallpaper.tiled
}

M.init = function()
   M.filelist = {}

   -- Ratio-based wallpaper management
   M.ratioBasedSelection = false
   M.portraitList = {}      -- Cache for portrait wallpapers
   M.landscapeList = {}     -- Cache for landscape wallpapers
   M.portraitIdx = 1        -- Current index for portrait wallpapers
   M.landscapeIdx = 1       -- Current index for landscape wallpapers
   M.processedIdx = 1       -- Index of next unprocessed wallpaper in raw filelist
   M.unprocessedCount = 0   -- Number of unprocessed wallpapers remaining

   M.showDesktopStatus = false
   M.showDesktopBuffer = {}

   M.wallpaperMode = "max"

   M.filelistCMD = nil

   M.quiteMode = false
   M.currentIdx = nil
   -- M.shuffleMode = false

   math.randomseed(os.time())

   M.timer = gears.timer {
      timeout = interval or 900,
      call_now = false,
      autostart = false,
      callback = function() M.refresh() end}
   M.timer:start()

   local modeMenu = {}
   for key, val in pairs(wallpaperFunction) do
      table.insert(modeMenu, {'mode ' .. key, function() M.changeWallpaperMode(key) end})
   end
   
   local inverval = nil
   local toggleMenu = {}

   for idx, val in ipairs(beautiful.wallpaper) do
      table.insert(toggleMenu,
                   {"[Gallery] " .. val.name, function() M.toggleGallery(idx) end})
   end

   local wallpaperActionMenu = {
      { "Show Wallpaper Info", function() M.showWallpaperInfo(awful.screen.focused()) end},
      { "View Wallpaper File", function() M.openWallpaperFile(awful.screen.focused()) end},
      { "Open Wallpaper Directory", function() M.openWallpaperDirectory(awful.screen.focused()) end},
      -- { "Copied Current MD5", function() M.copyMD5(awful.screen.focused()) end},
      { "Ignore Current Wallpaper", function() M.ignoreCurrentWallpaper(awful.screen.focused()) end},
      { "Accept Current Wallpaper", function() M.ignoreCurrentWallpaper(awful.screen.focused(), true) end}
   }
   local galleryActionMenu = {
      { "Toggle Quite Mode", function() M.toggleQuiteMode() end},
      { "Change Wallpaper Mode", modeMenu},
      { "Update Wallpaper Files", function() M.updateFilelist() end},
      { "Change Wallpaper Interval", function() M.changeWallpaperInterval() end},
      -- { "[DB Only] Set Tag", function() M.setTag() end}
   }
   
   M.menu = awful.menu({
         items = {
            { "Refresh Wallpaper", function() M.refresh() end},
            { "Wallpaper Actions", wallpaperActionMenu},
            { "Gallery Actions", galleryActionMenu},
            { "Switch Wallpaper Gallery", toggleMenu},
         }
   })
   M.toggleGallery(1)

end -- M.init

M.toggleQuiteMode = function()

   M.quiteMode = not M.quiteMode
   local quiteMode
   if M.quiteMode then
      quiteMode = 'on'
   else
      quiteMode = 'off'
   end

   naughty.notify({ title = "Wallpaper Quite Mode Changed to " .. quiteMode,
                    position = "bottom_middle",
                    icon  = beautiful.refreshed, icon_size = 64,
                    width = notiWidth})

end -- M.toggleQuiteMode

M.changeWallpaperInterval = function()
    awful.prompt.run {
        prompt       = '<b>Wallpaper Interval (sec): </b>',
        text         = tostring(M.timer.timeout),
        bg_cursor    = '#ff0000',
        -- To use the default rc.lua prompt:
        textbox      = mouse.screen.mypromptbox.widget,
        exe_callback = function(input)
            if not input or #input == 0 then input = 900 end
            naughty.notify{
               text = 'Set Wallpaper Interval: '.. input,
               position = "bottom_middle",
               width = notiWidth}
            M.timer.timeout = tonumber(input)
            M.timer:again()
        end
    }
end
local function split(s, delimiter)
    result = {};
    for match in (s..delimiter):gmatch("(.-)"..delimiter) do
        table.insert(result, match);
    end
    return result;
end

-- local function getMD5(path)
--    local tmp = split(path, '_')
--    if tmp then
--       md5 = tmp[#tmp]:sub(1, 32)
--    else
--       md5 = false
--    end
--    return md5
-- end

M.setWallpaper = function(s)

   s.wallpaper = nil
   s.wallpaperRawIdx = nil
   
   if type(M.wallpaperPath) == "function" then
      s.wallpaper = M.wallpaperPath(s)
   else
      if (M.wallpaperPath:sub(-1) == "/" or M.wallpaperPath == "@combine") then

        if M.ratioBasedSelection then
           -- Use ratio-based selection
           local desiredRatio = M.getScreenRatio(s)
           local wallpaper, rawIdx = M.getNextWallpaperByRatio(desiredRatio)
           
           if wallpaper then
              s.wallpaper = wallpaper
              s.wallpaperRawIdx = rawIdx
              
              -- Advance the appropriate index
              if desiredRatio == "portrait" then
                 M.portraitIdx = M.portraitIdx + 1
              else
                 M.landscapeIdx = M.landscapeIdx + 1
              end
           end
        else
           -- Original non-ratio logic
           if M.currentIdx > #M.filelist then
               M.currentIdx = 1 -- reset to the beginning
           end

           s.wallpaper = M.filelist[M.currentIdx]
           s.wallpaperRawIdx = M.currentIdx
           M.currentIdx = M.currentIdx + 1
        end

      else
         s.wallpaper = M.wallpaperPath
      end
   end -- if type(beautiful.wallpaper)

   if s.wallpaper ~= nil then

      if not M.quiteMode then
         M.showWallpaperInfo(s)
      end
      
      wallpaperFunction[M.wallpaperMode](s.wallpaper, s)

      local displayIdx = s.wallpaperRawIdx or M.currentIdx or 0
      local text = '  [' .. displayIdx .. '/' .. #M.filelist .. ']  '
      s.wallText:set_markup(text)

   end -- if s.wallpaper ~= nil
end

M.changeWallpaperMode = function(mode)

   if mode == "fit" or mode == "max" or mode == "tile" or mode == "centered" then
      M.wallpaperMode = mode
      naughty.notify{
         text = 'Change wallpaper model to ' .. mode,
         position = "bottom_middle",
         width = notiWidth,
      }

      for s in screen do
         wallpaperFunction[mode](s.wallpaper, s) --, f)
      end

   else
      naughty.notify{
         text = 'Only support "fit", "max", "tile", "centered", input is ' .. mode,
         position = "bottom_middle",
         width = notiWidth,
      }
   end

end

-- M.setTag = function()
--    awful.prompt.run {
--       prompt       = '<b>Tag: </b>',
--       -- text         = tostring(M.timer.timeout),
--       bg_cursor    = '#ff0000',
--       -- To use the default rc.lua prompt:
--       textbox      = mouse.screen.mypromptbox.widget,
--       exe_callback = function(input)
--          if input then
--             naughty.notify{
--                text = 'Querying database for tag: '.. input,
--                position = "bottom_middle",
--                width = notiWidth
--             }
--             cmd = "sqlite3 " .. os.getenv("HOME") .. "/Pictures/database.db "
--                .. "'select FilePath from MAIN_TBL where ID in "
--                .. "(select ImgID from IMG_TO_TAG as A inner join TAG_TBL as B on A.TagID=B.ID "
--                .. 'where TagName="' .. input .. '"' .. ") AND WALLPAPER=0' | shuf > /tmp/wall-list"
            
--             awful.spawn.easy_async_with_shell(
--                cmd .. "-new",
--                function(out)
--                   fh = io.open('/tmp/wall-list-new')
--                   if fh:seek("end") ~= 0 then
--                      fh:close()
--                      M.filelistCMD = "mv /tmp/wall-list-new /tmp/wall-list"
--                      if M.galleryName == "HCG-R18" then
--                         M.updateFilelist(true)
--                      else
--                         M.toggleGallery(3, M.filelistCMD)
--                      end
--                      M.currentTag = input
--                      M.filelistCMD = cmd
--                   else
--                      fh:close()
--                      naughty.notify{
--                         text = "Didn't find any wallpapers matching tag.\nCMD:" .. cmd,
--                         position = "bottom_middle",
--                         width = notiWidth}
--                   end
--             end)
            
--          end
--       end
--    }
-- end

M.updateFilelist = function(doRefresh)
   local cmd
   
   M.currentIdx = 1
   M.filelist = {}
   
   -- Reset ratio-based caches
   M.portraitList = {}
   M.landscapeList = {}
   M.portraitIdx = 1
   M.landscapeIdx = 1
   M.processedIdx = 1
   M.unprocessedCount = 0

   if M.filelistCMD ~= nil then
      cmd = M.filelistCMD
   else
      if M.wallpaperPath ~= "@combine" then
         cmd =  "fd -L -i -t f -e png -e jpg -e jpeg . " .. M.wallpaperPath .. ' | shuf > /tmp/wall-list'
      end
   end

   naughty.notify(
      { title = "Updating wallpaper database",
        text  = "Folder: " .. M.wallpaperPath, -- .. '\nCMD: ' .. cmd,
        position = "bottom_middle",
        icon  = beautiful.refreshed, icon_size = 64,
        width = notiWidth})
   
   awful.spawn.easy_async_with_shell(
      cmd,
      function(out)
         fh = io.open('/tmp/wall-list', 'r')
         line = fh:read()
         if line ~= nil then
            M.filelist[#M.filelist+1] = line
            while true do
                line = fh:read()
                if line == nil then break end
                M.filelist[#M.filelist+1] = line
            end
         end
         fh:close()
         
         -- Set unprocessed count for ratio-based selection
         M.unprocessedCount = #M.filelist
         
         naughty.notify({ title = "Wallpaper database updated!",
                          text  = "Found: " .. #M.filelist .. " items",
                          position = "bottom_middle",
                          icon  = beautiful.refreshed, icon_size = 64,
                          width = notiWidth})
         
         if doRefresh then
            M.setAllWallpapers()
         end
   end)
   
end -- end of M.updateFilelist

M.setAllWallpapers = function()
   for s in screen do
      M.setWallpaper(s)
   end
end 

M.refresh = function(resetTimer, shift)
   -- resetTimer is used when user initiate a refresh
   local resetTimer = resetTimer or false
   local shift = shift or 0

   if M.ratioBasedSelection then
      -- For ratio-based selection, advance both portrait and landscape indices
      M.portraitIdx = M.portraitIdx + shift
      M.landscapeIdx = M.landscapeIdx + shift
      
      if M.portraitIdx < 1 then M.portraitIdx = 1 end
      if M.landscapeIdx < 1 then M.landscapeIdx = 1 end
   else
      -- Original logic for non-ratio mode
      -- twice as the currentIdx is now pointing to the next one
      M.currentIdx = M.currentIdx + 2 * shift * screen:count()
      if M.currentIdx < 1 then
          M.currentIdx = 1
      end
   end

   M.setAllWallpapers()

   if resetTimer then
      M.timer:again()
   end

   collectgarbage("collect")    
   collectgarbage("collect")

end

M.shiftWallpaperForCurrentScreen = function(s, shift)

   -- NOTE - below use 2 * shift as input shift is either 0 or 1, and setWallpaper function
   --        will advance shift automatically
   
   if M.ratioBasedSelection then
      -- For ratio-based selection, advance the appropriate index based on screen ratio
      local desiredRatio = M.getScreenRatio(s)
      if desiredRatio == "portrait" then
         M.portraitIdx = M.portraitIdx + 2 * shift
         if M.portraitIdx < 1 then M.portraitIdx = 1 end
      else
         M.landscapeIdx = M.landscapeIdx + 2 * shift
         if M.landscapeIdx < 1 then M.landscapeIdx = 1 end
      end
   else
      -- Original logic for non-ratio mode
      M.currentIdx = M.currentIdx + 2 * shift
      if M.currentIdx < 1 then
         M.currentIdx = 1
      end
   end
   M.setWallpaper(s)
end

local function notiOnIgnore(s, reverse, notiTextExtra)
   local curIdx
   if s.currentIdx ~= nil then
      curIdx = s.currentIdx
   else
      curIdx = 'n/a'
   end

   local notiText = "Filename: " .. s.wallpaper
      .. '\nIndex: ' .. curIdx

   if notiTextExtra then
      notiText = notiText .. notiTextExtra
   end

   local notiTitle
   local icon
   if reverse then
      -- color = "#32CD32"  -- green
      icon = beautiful.greencheck
      notiTitle = "Accepted"
   else
      -- color = "#B22222" -- red
      icon = beautiful.redx
      notiTitle = "Ignored"
      M.setWallpaper(s)
   end

   naughty.notify(
      { title  = "Wallpaper " .. notiTitle,
        text   = notiText,
        position = "bottom_middle",
        timeout = 5,
        -- shape = gears.shape.rectangle,
        -- border_width = 2,
        -- border_color = color,
        icon  = icon, icon_size = 64, screen = s,
        width = 1000})
end -- of function

M.ignoreCurrentWallpaper = function(s, reverse)


   -- if M.galleryName == "HCG-R18" then

   --    local md5 = getMD5(s.wallpaper)
   --    if md5 ~= false then

   --       local wall
   --       if reverse then
   --          wall = '0'
   --       else
   --          wall = '1'
   --       end
         
   --       cmd = "sqlite3 " .. os.getenv("HOME") .. "/Pictures/database.db "
   --          .. "'update MAIN_TBL set WALLPAPER=" .. wall .. ", CHECKED=1 where MD5="
   --          .. '"' .. md5 .. '"' .. ";'"
   --       awful.spawn.easy_async_with_shell(
   --          cmd,
   --          function (out)
   --                local notiTextExtra = '\nMD5: ' .. md5
   --                notiOnIgnore(s, reverse, notiTextExtra)
   --          end
   --       )
   --    end
   -- else -- for other folder w/o database
	if not reverse then
		os.rename(s.wallpaper, s.wallpaper .. ".ignore")
		if s.currentIdx ~= nil then
		M.filelist[s.currentIdx] = s.wallpaper .. ".ignore"
		end
	else
		-- now the wallpaper path is with .ignore suffix
		os.rename(s.wallpaper, s.wallpaper:sub(1, -8))
		if s.currentIdx ~= nil then
		M.filelist[s.currentIdx] = s.wallpaper:sub(1, -8)
		end
	end
	notiOnIgnore(s, reverse)
   -- end -- end of if gallery

end

-- M.copyMD5 = function(s)

--    local md5 = getMD5(s.wallpaper)
--    if md5 == nil then
--       naughty.notify(
--          { text   = "No MD5 Matched",
--            position = "bottom_left",
--            icon   = beautiful.refreshed,
--            icon_size = 64, screen = s,
--            width = notiWidth})
--    else
--       local cmd = "echo " .. '"' .. md5 .. '" ' .. " | xclip -selection c"
--       awful.spawn.easy_async_with_shell(
--          cmd,
--          function (out)
--             naughty.notify(
--                { text   = "MD5 copied to clipboard",
--                  position = "bottom_middle",
--                  icon   = beautiful.refreshed,
--                  icon_size = 64, screen = s,
--                  width = notiWidth})
--          end
--       )
--    end

-- end

M.showWallpaperInfo = function(s)

   local curIdx
   if s.currentIdx ~= nil then
      curIdx = s.currentIdx
   else
      curIdx = 'n/a'
   end

   -- local md5 = getMD5(s.wallpaper)
   -- if md5 == nil then
   --    md5 = "No matched"
   -- end

    naughty.notify(
        { title  = "Wallpaper Info",
          text   = "Filename: " .. s.wallpaper
             .. '\nPath:  ' .. M.wallpaperPath
             .. '\nIndex: ' .. curIdx .. " (" .. #M.filelist .. ")",
             -- .. '\nMD5: ' .. md5
             -- .. '\nTag: ' .. M.currentTag,
          position = "bottom_left",
          icon   = beautiful.refreshed, icon_size = 64, screen = s})
end

M.openWallpaperFile = function(s)
   awful.spawn.easy_async(
      string.format(
         'feh --info "identify %%F" -g 1680x1050 --scale-down --auto-zoom "%s"',
         s.wallpaper
      ),
      function(stdout, stderr, exitreason, exitcode) end
   )
end

M.openWallpaperDirectory = function(s)
   awful.spawn.easy_async(
      string.format(
         'nautilus --new-window "%s"',
         s.wallpaper
      ),
      function(stdout, stderr, exitreason, exitcode) end
   )

end

M.toggleGallery = function(idx, overrideCMD)
   M.wallpaperPath = beautiful.wallpaper[idx].path or "Not Defined"
   M.wallpaperMode = beautiful.wallpaper[idx].mode
   M.quiteMode     = beautiful.wallpaper[idx].quite or false
   M.ratioBasedSelection = beautiful.wallpaper[idx].ratioBasedSelection or false
   -- M.shuffleMode   = beautiful.wallpaper[idx].shuffle or false

   M.filelistCMD   = beautiful.wallpaper[idx].cmd or nil

   M.galleryName   = beautiful.wallpaper[idx].name
   local interval  = beautiful.wallpaper[idx].interval or nil

   if overrideCMD ~= nil then
      M.filelistCMD = overrideCMD
   end

   local quiteMode
   if M.quiteMode then
      quiteMode = 'on'
   else
      quiteMode = 'off'
   end

   local intervalText
   if interval ~= nil then
      M.timer.timeout = interval
      intervalText = tostring(interval)
      M.timer:again()
   else
      intervalText = "n/a"
   end

   naughty.notify({ title = "Wallpaper Mode Changed",
                    text  = "Path: " .. M.wallpaperPath
                       .. '\nMode: ' .. M.wallpaperMode
                       .. '\nQuite: ' .. quiteMode
                       .. '\nInterval: ' .. intervalText,
                    position = "bottom_middle",
                    icon  = beautiful.refreshed, icon_size = 64,
                    width = notiWidth})

   if (M.wallpaperPath:sub(-1) == "/" or M.wallpaperPath == "@combine") then
      M.updateFilelist(true)
   end


end

M.toggleShowDesktop = function()
   local text
   
   M.showDesktopStatus = not M.showDesktopStatus

   if M.showDesktopStatus then  -- now in show desktop mode

      for s in screen do
         M.showDesktopBuffer[s] = s.selected_tags
         awful.tag.viewnone(s)
      end
      
   else  -- not showing desktop
      for s in screen do
         awful.tag.viewmore(M.showDesktopBuffer[s], s)
      end -- s in screen

      M.showDesktopBuffer = {}

    end

end -- M.toggleShowDesktop

M.keybindings = awful.util.table.join(
    awful.key(
        { modkey,  }, "F5",
        function()
           M.refresh(true)
        end,
        {description = "Refresh wallpaper (next)", group = "wallpaper"}),
    awful.key(
        { modkey,  "Shift" }, "F5",
        function()
           M.refresh(true, -1)
        end,
        {description = "Refresh wallpaper (prev)", group = "wallpaper"}),
    awful.key(
        { modkey,  }, "F1",
        function()
           M.showWallpaperInfo(awful.screen.focused())
        end,
        {description = "Show wallpaper info", group = "wallpaper"}),
    awful.key(
        { modkey,  }, "F2",
        function()
           M.openWallpaperFile(awful.screen.focused())
        end,
        {description = "View wallpaper file", group = "wallpaper"}),
    awful.key(
        { modkey,  }, "F3",
        function()
           M.openWallpaperDirectory(awful.screen.focused())
        end,
        {description = "Show wallpaper info", group = "wallpaper"}),
    awful.key(
        { modkey, altkey  }, "i",
        function()
           M.ignoreCurrentWallpaper(awful.screen.focused())
        end,
        {description = "Ignore current focused wallpaper", group = "wallpaper"}),
    awful.key(
        { modkey, altkey, "Shift"  }, "i",
        function()
           M.ignoreCurrentWallpaper(awful.screen.focused(), true)
        end,
        {description = "Accept current focused wallpaper", group = "wallpaper"}),
    awful.key(
        { modkey, altkey,  }, "Right",
        function()
           M.shiftWallpaperForCurrentScreen(awful.screen.focused(), 0)
        end,
        {description = "Next Wallpaper for Current Screen", group = "wallpaper"}),
    awful.key(
        { modkey, altkey,  }, "Left",
        function()
           M.shiftWallpaperForCurrentScreen(awful.screen.focused(), -1)
        end,
        {description = "Prev Wallpaper for Current Screen", group = "wallpaper"}),
      awful.key(
         { modkey,           }, "d",
         function () M.menu:show() end,
         {description = "show wallpaper menu", group = "awesome"}),
      awful.key(
         { modkey, "Control" }, "d", M.toggleShowDesktop,
         {description = "Show Desktop", group = "awesome"})
)

return M

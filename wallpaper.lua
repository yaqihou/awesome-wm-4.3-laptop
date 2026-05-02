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

local function sqlEscape(s)
   return s:gsub("'", "''")
end

-- Async version of getImageRatio with on-demand SQLite lookup
M.getImageRatioAsync = function(imagePath, callback)
   -- Step 1: check in-memory session cache
   local entry = M.ratioCache[imagePath]
   if entry then
      callback(entry.ratio, entry.width, entry.height, true)
      return
   end

   -- Step 2: query SQLite via CLI (single row, fast)
   local sql = string.format(
      "SELECT ratio, width, height FROM wallpaper_cache WHERE path = '%s'",
      sqlEscape(imagePath))
   local cmd = {"sqlite3", M.sqliteCachePath, sql}

   awful.spawn.easy_async(cmd, function(stdout, _, _, exitcode)
      if exitcode == 0 and stdout and stdout ~= "" then
         local ratio, w, h = stdout:match("(%S+)|(%d+)|(%d+)")
         if not ratio then
            ratio, w, h = stdout:match("(%S+)%s+(%d+)%s+(%d+)")
         end
         if ratio and w and h then
            M.ratioCache[imagePath] = { ratio = ratio, width = tonumber(w), height = tonumber(h) }
            callback(ratio, tonumber(w), tonumber(h), true)
            return
         end
      end

      -- Step 3: SQLite miss — use ImageMagick identify
      local identifyCmd = "identify -ping -format '%w %h' '" .. imagePath .. "' 2>/dev/null"

      awful.spawn.easy_async_with_shell(identifyCmd, function(stdout2, _, _, exitcode2)
         if exitcode2 ~= 0 or not stdout2 or stdout2 == "" then
            callback("unknown", nil, nil, nil)
            return
         end

         local width, height = stdout2:match("(%d+) (%d+)")
         if not width or not height then
            callback("unknown", nil, nil, nil)
            return
         end

         width, height = tonumber(width), tonumber(height)
         local ratio = width < height and "portrait" or "landscape"

         M.cacheRatio(imagePath, ratio, width, height)

         callback(ratio, width, height, false)
      end)
   end)
end


-- Async lazy loading function to populate ratio-based caches
M.populateRatioCaches = function(batchSize, callback)
   if not M.ratioBasedSelection or M.unprocessedCount == 0 then
      if callback then callback() end
      return
   end
   
   batchSize = batchSize or 10
   local processed = 0
   local toProcess = {}
   
   -- Collect wallpapers to process in this batch
   while processed < batchSize and M.processedIdx <= #M.filelist do
      local wallpaper = M.filelist[M.processedIdx]
      if wallpaper and wallpaper ~= "" then
         table.insert(toProcess, {path = wallpaper, rawIdx = M.processedIdx})
         processed = processed + 1
      end
      M.processedIdx = M.processedIdx + 1
      M.unprocessedCount = M.unprocessedCount - 1
   end
   
   if #toProcess == 0 then
      if callback then callback() end
      return
   end
   
   -- Process each wallpaper asynchronously and store results for ordered insertion
   local completedCount = 0
   local results = {}
   local hasNewEntries = false  -- Track if we actually added new cache entries
   
   local function onRatioDetected(wallpaperInfo, ratio, width, height, wasFromCache)
      -- Store wallpaper info with dimensions
      local enhancedInfo = {
         path = wallpaperInfo.path,
         rawIdx = wallpaperInfo.rawIdx,
         width = width,
         height = height
      }
      results[wallpaperInfo.rawIdx] = {info = enhancedInfo, ratio = ratio}
      
      -- Track if this was a new cache entry (not from cache)
      -- Only count valid results (wasFromCache = false means new valid entry)
      if wasFromCache == false then
         hasNewEntries = true
      end
      
      completedCount = completedCount + 1
      if completedCount == #toProcess then
         -- All async operations completed, now insert in order
         -- Sort results by raw index to maintain file order
         local sortedIndices = {}
         for rawIdx, _ in pairs(results) do
            table.insert(sortedIndices, rawIdx)
         end
         table.sort(sortedIndices)
         
         -- Insert wallpapers in the correct order
         for _, rawIdx in ipairs(sortedIndices) do
            local result = results[rawIdx]
            if result.ratio == "portrait" then
               table.insert(M.portraitList, result.info)
            elseif result.ratio == "landscape" then
               table.insert(M.landscapeList, result.info)
            else
               -- For unknown ratios, add to landscape as fallback
               table.insert(M.landscapeList, result.info)
            end
         end
         
         -- SQLite entries are auto-saved individually, no batch save needed
         
         if callback then callback() end
      end
   end
   
   -- Start async processing for each wallpaper
   for _, wallpaperInfo in ipairs(toProcess) do
      M.getImageRatioAsync(wallpaperInfo.path, function(ratio, width, height, wasFromCache)
         onRatioDetected(wallpaperInfo, ratio, width, height, wasFromCache)
      end)
   end
end


-- Async version of getNextWallpaperByRatio (recommended for performance)
-- callback(wallpaper, rawIdx, actualRatio) - actualRatio indicates which orientation was actually used
M.getNextWallpaperByRatioAsync = function(desiredRatio, callback)
   if not M.ratioBasedSelection then
      callback(nil, nil, nil)
      return
   end
   
   local targetList, targetIdx
   if desiredRatio == "portrait" then
      targetList = M.portraitList
      targetIdx = M.portraitIdx
   else
      targetList = M.landscapeList  
      targetIdx = M.landscapeIdx
   end
   
   -- Check if we already have a wallpaper available
   if targetIdx <= #targetList then
      local wallpaperInfo = targetList[targetIdx]
      callback(wallpaperInfo.path, wallpaperInfo.rawIdx, desiredRatio)
      return
   end
   
   -- Need to populate more caches with multi-batch search
   local maxSearchAttempts = M.maxSearchAttempts or 5
   local searchAttempts = 0
   
   local function tryNextBatch()
      if targetIdx <= #targetList then
         -- Found a wallpaper
         local wallpaperInfo = targetList[targetIdx]
         callback(wallpaperInfo.path, wallpaperInfo.rawIdx, desiredRatio)
         return
      end
      
	  -- Now targetIdx is out of scope
      if M.unprocessedCount == 0 or searchAttempts >= maxSearchAttempts then
         -- Handle different cases after search attempts  
         if #targetList > 0 then
            -- Case 1: Target list has wallpapers but we've cycled through all - cycle back to start
            if desiredRatio == "portrait" then
			   -- If there are still more to process, we can wait before cycling back to start
			   if M.unprocessedCount == 0 then M.portraitIdx = 1 else M.portraitIdx = #targetList end

               local wallpaperInfo = M.portraitList[M.portraitIdx]
               callback(wallpaperInfo.path, wallpaperInfo.rawIdx, "portrait")
            else
			   if M.unprocessedCount == 0 then M.landscapeIdx = 1 else M.landscapeIdx = #targetList end
               
               local wallpaperInfo = M.landscapeList[M.landscapeIdx]
               callback(wallpaperInfo.path, wallpaperInfo.rawIdx, "landscape")
            end
         else
            -- Case 2: Target list is empty - fall back to other orientation
            if desiredRatio == "portrait" and #M.landscapeList > 0 then
               local wallpaperInfo = M.landscapeList[M.landscapeIdx]
               callback(wallpaperInfo.path, wallpaperInfo.rawIdx, "landscape")  -- FIXED: Return actual orientation used
            elseif desiredRatio == "landscape" and #M.portraitList > 0 then
               local wallpaperInfo = M.portraitList[M.portraitIdx]
               callback(wallpaperInfo.path, wallpaperInfo.rawIdx, "portrait")  -- FIXED: Return actual orientation used
            else
               callback(nil, nil, nil)
            end
         end
         return
      end
      
      -- Try another batch
      searchAttempts = searchAttempts + 1
      M.populateRatioCaches(10, tryNextBatch)
   end
   
   tryNextBatch()
end

-- Simplified sync version (deprecated - use async version)
-- Returns: wallpaper, rawIdx, actualRatio - actualRatio indicates which orientation was actually used
M.getNextWallpaperByRatio = function(desiredRatio)
   if not M.ratioBasedSelection then
      return nil, nil, nil
   end

   local targetList, targetIdx
   local actualRatio = desiredRatio
   if desiredRatio == "portrait" then
      targetList = M.portraitList
      targetIdx = M.portraitIdx
   else
      targetList = M.landscapeList
      targetIdx = M.landscapeIdx
   end

   -- If we have wallpapers available, return one
   if targetIdx <= #targetList then
      local wallpaperInfo = targetList[targetIdx]
      return wallpaperInfo.path, wallpaperInfo.rawIdx, actualRatio
   end

   -- If target list is empty, try fallback orientation
   if desiredRatio == "portrait" and #M.landscapeList > 0 and M.landscapeIdx <= #M.landscapeList then
      local wallpaperInfo = M.landscapeList[M.landscapeIdx]
      return wallpaperInfo.path, wallpaperInfo.rawIdx, "landscape"
   elseif desiredRatio == "landscape" and #M.portraitList > 0 and M.portraitIdx <= #M.portraitList then
      local wallpaperInfo = M.portraitList[M.portraitIdx]
      return wallpaperInfo.path, wallpaperInfo.rawIdx, "portrait"
   end

   return nil, nil, nil
end


local wallpaperFunction = {
   fit=gears.wallpaper.fit,
   centered=gears.wallpaper.centered,
   max=gears.wallpaper.maximized,
   tile=gears.wallpaper.tiled
}

local function updateWallpaperUI(s)
   local displayIdx = s.wallpaperRawIdx or M.currentIdx or 0
   local text

   if M.ratioBasedSelection and s.wallpaperRatioIdx and s.wallpaperRatio then
      local ratioTotal, ratioText

      if s.wallpaperRatio == "portrait" then
         ratioTotal = #M.portraitList
         ratioText = "P"
      else
         ratioTotal = #M.landscapeList
         ratioText = "L"
      end

      text = '  [' .. displayIdx .. '/' .. #M.filelist .. ' - ' .. s.wallpaperRatioIdx .. '/' .. ratioTotal .. ' ' .. ratioText .. ']  '
   else
      text = '  [' .. displayIdx .. '/' .. #M.filelist .. ']  '
   end

   s.wallText:set_markup(text)
end

M.applyWallpaperAsync = function(s, callback)
   if not s.wallpaper then
      if callback then callback() end
      return
   end

   if not M.quiteMode then
      M.showWallpaperInfo(s)
   end

   if M.wallpaperMode == "tile" then
      wallpaperFunction[M.wallpaperMode](s.wallpaper, s)
      if callback then callback() end
      return
   end

   local geo = s.geometry
   local tmpFile = "/tmp/awesome-wallpaper-" .. tostring(s.index) .. ".png"

   local convertCmd
   if M.wallpaperMode == "max" then
      convertCmd = string.format(
         "convert '%s' -resize %dx%d^ -gravity center -crop %dx%d+0+0 +repage '%s'",
         s.wallpaper, geo.width, geo.height, geo.width, geo.height, tmpFile)
   elseif M.wallpaperMode == "fit" then
      convertCmd = string.format(
         "convert '%s' -resize %dx%d -background black -gravity center -extent %dx%d '%s'",
         s.wallpaper, geo.width, geo.height, geo.width, geo.height, tmpFile)
   elseif M.wallpaperMode == "centered" then
      convertCmd = string.format(
         "convert '%s' -resize %dx%d> -gravity center -background black -extent %dx%d '%s'",
         s.wallpaper, geo.width, geo.height, geo.width, geo.height, tmpFile)
   end

   if not convertCmd then
      wallpaperFunction[M.wallpaperMode](s.wallpaper, s)
      if callback then callback() end
      return
   end

   awful.spawn.easy_async_with_shell(convertCmd, function(_, _, _, exitcode)
      local imageToUse = s.wallpaper
      if exitcode == 0 then
         imageToUse = tmpFile
      end

      wallpaperFunction[M.wallpaperMode](imageToUse, s)
      if callback then callback() end
   end)
end

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
   M.maxSearchAttempts = 5  -- Maximum batches to search before falling back to other orientation
   
   -- Dimension cache for wallpapers (path -> {width, height})
   M.dimensionCache = {}
   
   -- Persistent ratio cache settings
    M.ratioCache = {}                -- Runtime cache: path -> {ratio, width, height}
    M.sqliteCachePath = os.getenv("HOME") .. "/.config/awesome/wallpaper-ratio-cache.sqlite3"
    M.journalPath = os.getenv("HOME") .. "/.config/awesome/wallpaper-ratio-cache.journal"
    M.useSQLiteCache = true

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
      { "Ignore Current Wallpaper", function() M.ignoreCurrentWallpaper(awful.screen.focused()) end},
      { "Accept Current Wallpaper", function() M.ignoreCurrentWallpaper(awful.screen.focused(), true) end}
   }
   local galleryActionMenu = {
      { "Toggle Quite Mode", function() M.toggleQuiteMode() end},
      { "Change Wallpaper Mode", modeMenu},
      { "Update Wallpaper Files", function() M.updateFilelist() end},
      { "Change Wallpaper Interval", function() M.changeWallpaperInterval() end},
      { "Clear Wallpaper Cache", function() M.clearRatioCache() end},
      { "Show Cache Status", function() M.showCacheStatus() end},
   }

   
   M.menu = awful.menu({
         items = {
            { "Refresh Wallpaper", function() M.refresh() end},
            { "Wallpaper Actions", wallpaperActionMenu},
            { "Gallery Actions", galleryActionMenu},
            { "Switch Wallpaper Gallery", toggleMenu},
         }
   })
   
    M.initSQLiteCacheAsync(function(ok)
       M.toggleGallery(1)
    end)

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

-- Async version of setWallpaper (recommended for performance)
M.setWallpaperAsync = function(s, callback)
   s.wallpaper = nil
   s.wallpaperRawIdx = nil
   s.wallpaperRatioIdx = nil
   s.wallpaperRatio = nil

   local function applyAsync()
      updateWallpaperUI(s)
      M.applyWallpaperAsync(s, callback)
   end

   if type(M.wallpaperPath) == "function" then
      s.wallpaper = M.wallpaperPath(s)
      applyAsync()
   else
      if (M.wallpaperPath:sub(-1) == "/" or M.wallpaperPath == "@combine") then
         if M.ratioBasedSelection then
            local desiredRatio = M.getScreenRatio(s)
            M.getNextWallpaperByRatioAsync(desiredRatio, function(wallpaper, rawIdx, actualRatio)
               if wallpaper then
                  s.wallpaper = wallpaper
                  s.wallpaperRawIdx = rawIdx

                  if actualRatio == "portrait" then
                     s.wallpaperRatioIdx = M.portraitIdx
                     s.wallpaperRatio = "portrait"
                     M.portraitIdx = M.portraitIdx + 1
                  elseif actualRatio == "landscape" then
                     s.wallpaperRatioIdx = M.landscapeIdx
                     s.wallpaperRatio = "landscape"
                     M.landscapeIdx = M.landscapeIdx + 1
                  end
               end

               applyAsync()
            end)
            return
         else
            if M.currentIdx > #M.filelist then
                M.currentIdx = 1
            end

            s.wallpaper = M.filelist[M.currentIdx]
            s.wallpaperRawIdx = M.currentIdx
            M.currentIdx = M.currentIdx + 1
         end
      else
         s.wallpaper = M.wallpaperPath
      end

      applyAsync()
   end
end

-- Helper function to finalize wallpaper setting (sync version for backward compatibility)
M.finalizeWallpaperSetting = function(s)
   if s.wallpaper ~= nil then
      if not M.quiteMode then
         M.showWallpaperInfo(s)
      end

      wallpaperFunction[M.wallpaperMode](s.wallpaper, s)
      updateWallpaperUI(s)
   end
end

-- [DEPRECATED] Synchronous version - commented out, use setWallpaperAsync instead
--[[
M.setWallpaper = function(s)

   s.wallpaper = nil
   s.wallpaperRawIdx = nil
   s.wallpaperRatioIdx = nil
   s.wallpaperRatio = nil
   
   if type(M.wallpaperPath) == "function" then
      s.wallpaper = M.wallpaperPath(s)
   else
      if (M.wallpaperPath:sub(-1) == "/" or M.wallpaperPath == "@combine") then

        if M.ratioBasedSelection then
           local desiredRatio = M.getScreenRatio(s)
           local wallpaper, rawIdx, actualRatio = M.getNextWallpaperByRatio(desiredRatio)
           
           if wallpaper then
              s.wallpaper = wallpaper
              s.wallpaperRawIdx = rawIdx
              
              if actualRatio == "portrait" then
                 s.wallpaperRatioIdx = M.portraitIdx
                 s.wallpaperRatio = "portrait"
                 M.portraitIdx = M.portraitIdx + 1
              elseif actualRatio == "landscape" then
                 s.wallpaperRatioIdx = M.landscapeIdx
                 s.wallpaperRatio = "landscape"
                 M.landscapeIdx = M.landscapeIdx + 1
              end
           end
        else
           if M.currentIdx > #M.filelist then
               M.currentIdx = 1
           end

           s.wallpaper = M.filelist[M.currentIdx]
           s.wallpaperRawIdx = M.currentIdx
           M.currentIdx = M.currentIdx + 1
        end

      else
         s.wallpaper = M.wallpaperPath
      end
   end

   M.finalizeWallpaperSetting(s)
end
--]]

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
   M.dimensionCache = {}

   if M.filelistCMD ~= nil then
      cmd = M.filelistCMD
   else
      if M.wallpaperPath ~= "@combine" then
          cmd =  "fd -L -i -t f -e png -e jpg -e jpeg . " .. M.wallpaperPath .. ' | shuf > /tmp/wall-list'
      end
   end

    naughty.notify(
       { title = "Updating wallpaper database",
         text  = "Folder: " .. M.wallpaperPath,
         position = "bottom_middle",
         icon  = beautiful.refreshed, icon_size = 64,
         width = notiWidth})

    if not cmd then return end

    awful.spawn.easy_async_with_shell(
       cmd,
       function(out, stderr, exitreason, exitcode)
          local fh = io.open('/tmp/wall-list', 'r')
          if fh then
             for line in fh:lines() do
                if line ~= "" then
                   M.filelist[#M.filelist+1] = line
                end
             end
             fh:close()
          end
          
          -- Set unprocessed count for ratio-based selection
          M.unprocessedCount = #M.filelist
          
          naughty.notify({ title = "Wallpaper database updated!",
                           text  = "Found: " .. #M.filelist .. " items",
                           position = "bottom_middle",
                           icon  = beautiful.refreshed, icon_size = 64,
                           width = notiWidth})
          
          if doRefresh then
             M.setAllWallpapersAsync()
          end
    end)
   
end -- end of M.updateFilelist

-- Helper function to get wallpaper dimensions (from cache or fetch)
M.getWallpaperDimensions = function(wallpaperPath, callback)
   -- First check dimension cache
   if M.dimensionCache[wallpaperPath] then
      callback(M.dimensionCache[wallpaperPath].width, M.dimensionCache[wallpaperPath].height)
      return
   end
   
   -- Check if it exists in ratio caches
   for _, wallpaperInfo in ipairs(M.portraitList) do
      if wallpaperInfo.path == wallpaperPath and wallpaperInfo.width and wallpaperInfo.height then
         M.dimensionCache[wallpaperPath] = {width = wallpaperInfo.width, height = wallpaperInfo.height}
         callback(wallpaperInfo.width, wallpaperInfo.height)
         return
      end
   end
   
   for _, wallpaperInfo in ipairs(M.landscapeList) do
      if wallpaperInfo.path == wallpaperPath and wallpaperInfo.width and wallpaperInfo.height then
         M.dimensionCache[wallpaperPath] = {width = wallpaperInfo.width, height = wallpaperInfo.height}
         callback(wallpaperInfo.width, wallpaperInfo.height)
         return
      end
   end
   
   -- Not in cache, fetch dimensions
   M.getImageRatioAsync(wallpaperPath, function(ratio, width, height, wasFromCache)
      if width and height then
         M.dimensionCache[wallpaperPath] = {width = width, height = height}
         callback(width, height)
      else
         callback(nil, nil)
      end
   end)
end

M.initSQLiteCacheAsync = function(callback)
   if not M.useSQLiteCache then
      if callback then callback(false) end
      return
   end

   local createSQL = [[
      CREATE TABLE IF NOT EXISTS wallpaper_cache (
         path TEXT PRIMARY KEY,
         ratio TEXT NOT NULL,
         width INTEGER NOT NULL,
         height INTEGER NOT NULL
      );
      CREATE INDEX IF NOT EXISTS idx_ratio ON wallpaper_cache(ratio);
      PRAGMA journal_mode=WAL;
      PRAGMA synchronous=NORMAL;
   ]]

   local cmd = string.format("sqlite3 '%s' \"%s\"", M.sqliteCachePath, createSQL)
   awful.spawn.easy_async_with_shell(cmd, function(_, _, _, exitcode)
      if exitcode ~= 0 then
         naughty.notify({
            title = "SQLite Cache Error",
            text = "Failed to initialize SQLite cache via CLI",
            position = "bottom_middle",
            timeout = 5,
            width = notiWidth
         })
         if callback then callback(false) end
         return
      end
      if callback then callback(true) end
   end)
end

M.cacheRatioAsync = function(imagePath, ratio, width, height)
   if not M.useSQLiteCache then return end
   if not imagePath or not ratio or not width or not height then return end

   local escapedPath = sqlEscape(imagePath)
   local sql = string.format(
      "INSERT OR REPLACE INTO wallpaper_cache (path, ratio, width, height) VALUES ('%s', '%s', %d, %d)",
      escapedPath, ratio, width, height)
   local cmd = string.format("sqlite3 '%s' \"%s\"", M.sqliteCachePath, sql)

   awful.spawn.easy_async_with_shell(cmd, function(_, _, _, exitcode)
      if exitcode ~= 0 then
         M.writeToJournal(imagePath, ratio, width, height)
      end
   end)
end

M.showCacheStatusSQLite = function()
   if not M.useSQLiteCache then
      naughty.notify({
         title = "SQLite Cache Status",
         text = "SQLite cache disabled",
         position = "bottom_middle",
         timeout = 5,
         width = notiWidth
      })
      return
   end

   local statsSQL = [[SELECT COUNT(*) as total, SUM(CASE WHEN ratio = 'portrait' THEN 1 ELSE 0 END) as portrait, SUM(CASE WHEN ratio = 'landscape' THEN 1 ELSE 0 END) as landscape FROM wallpaper_cache;]]
   local statsCmd = string.format("sqlite3 -separator '|' '%s' \"%s\"", M.sqliteCachePath, statsSQL)

   awful.spawn.easy_async_with_shell(statsCmd, function(stdout, _, _, exitcode)
      if exitcode ~= 0 or not stdout or stdout == "" then
         naughty.notify({
            title = "SQLite Cache Status",
            text = "Failed to query cache database",
            position = "bottom_middle",
            timeout = 5,
            width = notiWidth
         })
         return
      end

      local total, portrait, landscape = stdout:match("(%d+)|(%d+)|(%d+)")
      total = tonumber(total) or 0
      portrait = tonumber(portrait) or 0
      landscape = tonumber(landscape) or 0

      local statusText = "SQLite Cache entries: " .. total
      if total > 0 then
         statusText = statusText .. "\nPortrait: " .. portrait .. " | Landscape: " .. landscape
         statusText = statusText .. "\nDatabase: " .. M.sqliteCachePath
      else
         statusText = statusText .. "\nNo cached entries"
      end

      local journalCount = 0
      local journalFile = io.open(M.journalPath, "r")
      if journalFile then
         for _ in journalFile:lines() do
            journalCount = journalCount + 1
         end
         journalFile:close()
      end

      if journalCount > 0 then
         statusText = statusText .. "\nJournal: " .. journalCount .. " pending entries"
      end

      naughty.notify({
         title = "SQLite Wallpaper Cache Status",
         text = statusText,
         position = "bottom_middle",
         icon = beautiful.refreshed,
         icon_size = 64,
         width = notiWidth,
         timeout = 8
      })
   end)
end

M.clearRatioCacheSQLite = function()
   if not M.useSQLiteCache then
      naughty.notify({
         title = "SQLite Cache Error",
         text = "SQLite cache disabled",
         position = "bottom_middle",
         timeout = 3,
         width = notiWidth
      })
      return
   end

   local countSQL = "SELECT COUNT(*) FROM wallpaper_cache;"
   local countCmd = string.format("sqlite3 '%s' \"%s\"", M.sqliteCachePath, countSQL)

   awful.spawn.easy_async_with_shell(countCmd, function(stdout, _, _, exitcode)
      local oldSize = 0
      if exitcode == 0 and stdout then
         oldSize = tonumber(stdout:match("(%d+)")) or 0
      end

      local clearSQL = "DELETE FROM wallpaper_cache; VACUUM;"
      local clearCmd = string.format("sqlite3 '%s' \"%s\"", M.sqliteCachePath, clearSQL)
      awful.spawn.easy_async_with_shell(clearCmd)

      M.ratioCache = {}

      naughty.notify({
         title = "SQLite Wallpaper Cache Cleared",
         text = "Cleared " .. oldSize .. " cached entries. Wallpaper ratios will be recalculated as needed.",
         position = "bottom_middle",
         icon = beautiful.refreshed,
         icon_size = 64,
         width = notiWidth
      })
   end)
end

M.writeToJournal = function(imagePath, ratio, width, height)
   local journalEntry = imagePath .. "|" .. ratio .. "|" .. width .. "|" .. height .. "\n"

   local file = io.open(M.journalPath, "a")
   if file then
      file:write(journalEntry)
      file:close()
      return true
   end
   return false
end

M.processJournalAsync = function(callback)
   local file = io.open(M.journalPath, "r")
   if not file then
      if callback then callback(0, 0) end
      return
   end

   local lines = {}
   for line in file:lines() do
      table.insert(lines, line)
   end
   file:close()

   if #lines == 0 then
      os.remove(M.journalPath)
      if callback then callback(0, 0) end
      return
   end

   local sqlParts = {}
   local processed = 0
   local failed = 0

   for _, line in ipairs(lines) do
      local parts = {}
      for part in line:gmatch("([^|]+)") do
         table.insert(parts, part)
      end

      if #parts >= 4 then
         local path, ratio, width, height = parts[1], parts[2], tonumber(parts[3]), tonumber(parts[4])
         if path and ratio and width and height then
            local escapedPath = sqlEscape(path)
            table.insert(sqlParts, string.format(
               "INSERT OR REPLACE INTO wallpaper_cache (path, ratio, width, height) VALUES ('%s', '%s', %d, %d);",
               escapedPath, ratio, width, height))
            processed = processed + 1
         else
            failed = failed + 1
         end
      else
         failed = failed + 1
      end
   end

   if #sqlParts > 0 then
      local sql = "BEGIN TRANSACTION; " .. table.concat(sqlParts, " ") .. " COMMIT;"
      local cmd = string.format("sqlite3 '%s' \"%s\"", M.sqliteCachePath, sql)

      awful.spawn.easy_async_with_shell(cmd, function(_, _, _, exitcode)
         if exitcode == 0 then
            os.remove(M.journalPath)
            if processed > 0 then
               naughty.notify({
                  title = "Journal Processed",
                  text = "Recovered " .. processed .. " entries from journal",
                  position = "bottom_middle",
                  icon = beautiful.refreshed,
                  icon_size = 64,
                  width = notiWidth,
                  timeout = 3
               })
            end
         end

         if callback then callback(processed, failed) end
      end)
   else
      os.remove(M.journalPath)
      if callback then callback(processed, failed) end
   end
end

M.clearJournal = function()
   os.remove(M.journalPath)
end


-- Persistent ratio cache functions


M.cacheRatio = function(imagePath, ratio, width, height)
   M.ratioCache[imagePath] = {
      ratio = ratio,
      width = width,
      height = height,
   }

   if M.useSQLiteCache then
      M.cacheRatioAsync(imagePath, ratio, width, height)
   end
end

M.showCacheStatus = function()
   M.showCacheStatusSQLite()
end

M.clearRatioCache = function()
   M.clearRatioCacheSQLite()
end

M.saveRatioCacheOnExit = function()
end

-- Helper function to check if we need predictive preloading
M.checkPredictivePreloading = function()
   if not M.ratioBasedSelection then return end
   
   local screenCount = screen:count()
   local preloadThreshold = screenCount * 3  -- Preload when we have less than 3x screens worth
   
   -- Check if portrait list is getting low
   local portraitRemaining = #M.portraitList - M.portraitIdx + 1
   if portraitRemaining <= preloadThreshold and M.unprocessedCount > 0 then
      M.populateRatioCaches(15)  -- Non-blocking preload
   end
   
   -- Check if landscape list is getting low  
   local landscapeRemaining = #M.landscapeList - M.landscapeIdx + 1
   if landscapeRemaining <= preloadThreshold and M.unprocessedCount > 0 then
      M.populateRatioCaches(15)  -- Non-blocking preload
   end
end

-- Async version of setAllWallpapers with preloading
M.setAllWallpapersAsync = function(callback)
   local screens = {}
   for s in screen do
      table.insert(screens, s)
   end
   
   if #screens == 0 then
      if callback then callback() end
      return
   end
   
   -- For ratio-based selection, preload if both lists are empty (first run scenario)
   if M.ratioBasedSelection and #M.portraitList == 0 and #M.landscapeList == 0 and M.unprocessedCount > 0 then
      -- Initial preloading to avoid race conditions between multiple screens
      local initialBatchSize = math.min(20, M.unprocessedCount)
      M.populateRatioCaches(initialBatchSize, function()
         -- After preloading, set wallpapers on all screens
         M.setAllWallpapersSequentially(screens, callback)
      end)
   else
      -- No preloading needed or not ratio-based, proceed directly
      M.setAllWallpapersSequentially(screens, callback)
   end
end

-- Set wallpapers sequentially with staggered async to avoid blocking
M.setAllWallpapersSequentially = function(screens, callback)
   local idx = 0

   local function nextOne()
      idx = idx + 1
      if idx > #screens then
         M.checkPredictivePreloading()
         if callback then callback() end
         return
      end

      M.setWallpaperAsync(screens[idx], function()
         gears.timer.start_new(0.05, function()
            nextOne()
            return false
         end)
      end)
   end

   nextOne()
end

-- [DEPRECATED] Synchronous version - commented out, use setAllWallpapersAsync instead
--[[
M.setAllWallpapers = function()
   for s in screen do
      M.setWallpaper(s)
   end
end
--]]

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

   -- M.setAllWallpapers()
   M.setAllWallpapersAsync()

    if resetTimer then
       M.timer:again()
    end

end

M.shiftWallpaperForCurrentScreen = function(s, shift)

   -- NOTE - below use 2 * shift as input shift is either 0 or 1, and setWallpaper function
   --        will advance shift automatically
   
   if M.ratioBasedSelection then
      -- For ratio-based selection, advance the appropriate index based on screen ratio
      local desiredRatio = M.getScreenRatio(s)
      if desiredRatio == "portrait" then
         M.portraitIdx = M.portraitIdx + 2 * shift
         if M.portraitIdx < 1 then M.portraitIdx = math.max(#M.portraitList, 1) end
      else
         M.landscapeIdx = M.landscapeIdx + 2 * shift
         if M.landscapeIdx < 1 then M.landscapeIdx = math.max(#M.landscapeList, 1) end
      end
   else
      -- Original logic for non-ratio mode
      M.currentIdx = M.currentIdx + 2 * shift
      if M.currentIdx < 1 then
         M.currentIdx = math.max(#M.filelist, 1)
      end
   end
   
   -- Set wallpaper and then check if we need predictive preloading
   M.setWallpaperAsync(s, function()
      M.checkPredictivePreloading()
   end)
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
       M.setWallpaperAsync(s)
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

end

M.showWallpaperInfo = function(s)

   local curIdx
   if s.wallpaperRawIdx ~= nil then
      curIdx = s.wallpaperRawIdx
   elseif s.currentIdx ~= nil then
      curIdx = s.currentIdx
   else
      curIdx = 'n/a'
   end

   -- Get wallpaper dimensions asynchronously and show notification
   M.getWallpaperDimensions(s.wallpaper, function(width, height)
      local dimensionText = ""
      if width and height then
         dimensionText = '\nDimensions: ' .. width .. 'x' .. height
      end
      
      naughty.notify(
          { title  = "Wallpaper Info",
            text   = "Filename: " .. s.wallpaper
               .. '\nPath:  ' .. M.wallpaperPath
               .. '\nIndex: ' .. curIdx .. " (" .. #M.filelist .. ")"
               .. dimensionText,
            position = "bottom_left",
            icon   = beautiful.refreshed, icon_size = 64, screen = s})
   end)
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
   M.maxSearchAttempts = beautiful.wallpaper[idx].maxSearchAttempts or 5
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

-- Save cache when AwesomeWM is about to exit (can be called from main rc.lua)
-- awesome.connect_signal("exit", M.saveRatioCacheOnExit)

return M

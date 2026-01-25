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

-- Async version of getImageRatio using awful.spawn with dimension caching
M.getImageRatioAsync = function(imagePath, callback)
   -- First check persistent cache
   local cachedRatio, cachedWidth, cachedHeight = M.getCachedRatio(imagePath)
   if cachedRatio then
      callback(cachedRatio, cachedWidth, cachedHeight, true)  -- true = from cache
      return
   end
   
   -- Cache miss, use ImageMagick identify
   local cmd = "identify -ping -format '%w %h' '" .. imagePath .. "' 2>/dev/null"
   
   awful.spawn.easy_async_with_shell(cmd, function(stdout, stderr, exitreason, exitcode)
      if exitcode ~= 0 or not stdout or stdout == "" then
         callback("unknown", nil, nil, nil)  -- nil = invalid result, not cacheable
         return
      end
      
      local width, height = stdout:match("(%d+) (%d+)")
      if not width or not height then
         callback("unknown", nil, nil, nil)  -- nil = invalid result, not cacheable
         return
      end
      
      width, height = tonumber(width), tonumber(height)
      local ratio
      if width < height then
         ratio = "portrait"
      else
         ratio = "landscape"
      end
      
      -- Cache the result for future use
      M.cacheRatio(imagePath, ratio, width, height)
      
      callback(ratio, width, height, false)  -- false = not from cache (new entry)
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
   M.useSQLiteCache = true          -- Always use SQLite
   M.sqliteConn = nil               -- SQLite connection object

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
   
   -- Load persistent ratio cache async, then toggle gallery
   M.loadRatioCacheSQLite(function()
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
   
   if type(M.wallpaperPath) == "function" then
      s.wallpaper = M.wallpaperPath(s)
      M.finalizeWallpaperSetting(s)
      if callback then callback() end
   else
      if (M.wallpaperPath:sub(-1) == "/" or M.wallpaperPath == "@combine") then
         if M.ratioBasedSelection then
            -- Use async ratio-based selection
            local desiredRatio = M.getScreenRatio(s)
            M.getNextWallpaperByRatioAsync(desiredRatio, function(wallpaper, rawIdx, actualRatio)
               if wallpaper then
                  s.wallpaper = wallpaper
                  s.wallpaperRawIdx = rawIdx
                  
                  -- Store screen-specific ratio index before advancing global index
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
               
               M.finalizeWallpaperSetting(s)
               if callback then callback() end
            end)
            return -- Exit early since we're handling async
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
      
      M.finalizeWallpaperSetting(s)
      if callback then callback() end
   end
end

-- Helper function to finalize wallpaper setting (shared between sync and async)
M.finalizeWallpaperSetting = function(s)
   if s.wallpaper ~= nil then
      if not M.quiteMode then
         M.showWallpaperInfo(s)
      end
      
      wallpaperFunction[M.wallpaperMode](s.wallpaper, s)

      local displayIdx = s.wallpaperRawIdx or M.currentIdx or 0
      local text
      
      if M.ratioBasedSelection and s.wallpaperRatioIdx and s.wallpaperRatio then
         -- Show both raw index and screen-specific ratio index
         local ratioTotal, ratioText
         
         if s.wallpaperRatio == "portrait" then
            ratioTotal = #M.portraitList
			ratioText = "P"
         else
            ratioTotal = #M.landscapeList
			ratioText = "L"
         end
         
         -- Format: [raw_index/total_raw] [screen_ratio_index/ratio_total orientation]
         text = '  [' .. displayIdx .. '/' .. #M.filelist .. ' - ' .. s.wallpaperRatioIdx .. '/' .. ratioTotal .. ' ' .. ratioText .. ']  '
      else
         -- Original format for non-ratio mode or when ratio info not available
         text = '  [' .. displayIdx .. '/' .. #M.filelist .. ']  '
      end
      
      s.wallText:set_markup(text)
   end
end

-- Synchronous version (for backward compatibility)
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
           -- Use ratio-based selection
           local desiredRatio = M.getScreenRatio(s)
           local wallpaper, rawIdx, actualRatio = M.getNextWallpaperByRatio(desiredRatio)
           
           if wallpaper then
              s.wallpaper = wallpaper
              s.wallpaperRawIdx = rawIdx
              
              -- Store screen-specific ratio index before advancing global index
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

   M.finalizeWallpaperSetting(s)
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
            -- M.setAllWallpapers()
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

-- SQLite Cache Functions
M.initSQLiteCache = function()
   if not M.useSQLiteCache then return false end

   -- Load SQLite library
   local success, luasql = pcall(require, "luasql.sqlite3")
   if not success then
      naughty.notify({
         title = "SQLite Cache Error",
         text = "Failed to load luasql.sqlite3. Falling back to text cache.",
         position = "bottom_middle",
         icon = beautiful.refreshed,
         icon_size = 64,
         width = notiWidth,
         timeout = 5
      })
      M.useSQLiteCache = false
      return false
   end

   local env = luasql.sqlite3()
   M.sqliteConn = env:connect(M.sqliteCachePath)

   if not M.sqliteConn then
      M.useSQLiteCache = false
      return false
   end

   -- Create table if it doesn't exist
   local createSQL = [[
      CREATE TABLE IF NOT EXISTS wallpaper_cache (
         path TEXT PRIMARY KEY,
         ratio TEXT NOT NULL,
         width INTEGER NOT NULL,
         height INTEGER NOT NULL
      );

      CREATE INDEX IF NOT EXISTS idx_ratio ON wallpaper_cache(ratio);
   ]]

   local result = M.sqliteConn:execute(createSQL)
   if not result then
	  print("Failed to execute creatSQL statement")
      M.sqliteConn:close()
      M.sqliteConn = nil
      M.useSQLiteCache = false
      return false
   end

   -- Enable WAL mode for better concurrent access
   M.sqliteConn:execute("PRAGMA journal_mode=WAL;")
   M.sqliteConn:execute("PRAGMA synchronous=NORMAL;")
   M.sqliteConn:execute("PRAGMA cache_size=10000;")

   return true
end

M.closeSQLiteCache = function()
   if M.sqliteConn then
      M.sqliteConn:close()
      M.sqliteConn = nil
   end
end

M.getCachedRatioSQLite = function(imagePath)
   if not M.useSQLiteCache or not M.sqliteConn then
      return nil, nil, nil
   end

   local escapedPath = M.sqliteConn:escape(imagePath)
   local sql = "SELECT ratio, width, height FROM wallpaper_cache WHERE path = '" .. escapedPath .. "'"
   local cursor = M.sqliteConn:execute(sql)
   if not cursor then return nil, nil, nil end

   local row = cursor:fetch({}, "a")
   cursor:close()

   if row then
      return row.ratio, tonumber(row.width), tonumber(row.height)
   end

   return nil, nil, nil
end

M.cacheRatioSQLite = function(imagePath, ratio, width, height)
   if not M.useSQLiteCache or not M.sqliteConn then
      return false
   end

   -- Validate inputs
   if not imagePath or not ratio or not width or not height then
      return false
   end

   local success, result = pcall(function()
      local escapedPath = M.sqliteConn:escape(imagePath)
      local sql = string.format(
         "INSERT OR REPLACE INTO wallpaper_cache (path, ratio, width, height) VALUES ('%s', '%s', %d, %d)",
         escapedPath, ratio, width, height)

      return M.sqliteConn:execute(sql)
   end)

   if not success then
      -- Log error details for debugging
      naughty.notify({
         title = "SQLite Error",
         text = "Cache insert failed: " .. (result or "unknown error"),
         position = "bottom_right",
         timeout = 3,
         width = 400
      })
      return false
   end

   return result ~= nil
end

M.loadRatioCacheSQLiteInternal = function(callback)
   -- Load all cached entries into runtime cache for compatibility
   local sql = "SELECT path, ratio, width, height FROM wallpaper_cache"
   local cursor = M.sqliteConn:execute(sql)
   if not cursor then
      if callback then callback() end
      return
   end

   local count = 0
   local row = cursor:fetch({}, "a")
   while row do
      M.ratioCache[row.path] = {
         ratio = row.ratio,
         width = tonumber(row.width),
         height = tonumber(row.height)
      }
      count = count + 1
      row = cursor:fetch({}, "a")
   end
   cursor:close()

   -- Process any pending journal entries
   M.processJournal(function(processed, failed)
      local totalCount = count + processed

      if totalCount > 0 then
         naughty.notify({
            title = "SQLite Wallpaper Cache Loaded",
            text = "Loaded " .. totalCount .. " cached wallpaper ratios" ..
                   (processed > 0 and " (+" .. processed .. " from journal)" or ""),
            position = "bottom_middle",
            icon = beautiful.refreshed,
            icon_size = 64,
            width = notiWidth,
            timeout = 3
         })
      end

      if callback then callback() end
   end)
end

M.loadRatioCacheSQLite = function(callback)
   if not M.useSQLiteCache then
      if callback then callback() end
      return
   end

   if not M.initSQLiteCache() then
      -- SQLite failed to initialize, continue with empty cache
      naughty.notify({
         title = "SQLite Cache Error",
         text = "Failed to initialize SQLite cache. Starting with empty cache.",
         position = "bottom_middle",
         timeout = 5,
         width = notiWidth
      })
      if callback then callback() end
      return
   end

   -- Load cache and process journal
   M.loadRatioCacheSQLiteInternal(callback)
end

M.showCacheStatusSQLite = function()
   if not M.useSQLiteCache or not M.sqliteConn then
      naughty.notify({
         title = "SQLite Cache Status",
         text = "SQLite cache not initialized",
         position = "bottom_middle",
         timeout = 5,
         width = notiWidth
      })
      return
   end

   local cursor = M.sqliteConn:execute([[
      SELECT
         COUNT(*) as total,
         SUM(CASE WHEN ratio = 'portrait' THEN 1 ELSE 0 END) as portrait,
         SUM(CASE WHEN ratio = 'landscape' THEN 1 ELSE 0 END) as landscape
      FROM wallpaper_cache
   ]])

   if not cursor then
      naughty.notify({
         title = "SQLite Cache Status",
         text = "Failed to query cache database",
         position = "bottom_middle",
         timeout = 5,
         width = notiWidth
      })
      return
   end

   local row = cursor:fetch({}, "a")
   cursor:close()

   if not row then
      naughty.notify({
         title = "SQLite Cache Status",
         text = "Failed to read cache statistics",
         position = "bottom_middle",
         timeout = 5,
         width = notiWidth
      })
      return
   end

   local total = tonumber(row.total) or 0
   local portrait = tonumber(row.portrait) or 0
   local landscape = tonumber(row.landscape) or 0

   -- Check journal size
   local journalCount = 0
   local journalFile = io.open(M.journalPath, "r")
   if journalFile then
      for _ in journalFile:lines() do
         journalCount = journalCount + 1
      end
      journalFile:close()
   end

   local statusText = "SQLite Cache entries: " .. total
   if total > 0 then
      statusText = statusText .. "\nPortrait: " .. portrait .. " | Landscape: " .. landscape
      statusText = statusText .. "\nDatabase: " .. M.sqliteCachePath

      -- Get file size
      local fileSize = "Unknown"
      local file = io.popen("ls -lh '" .. M.sqliteCachePath .. "' 2>/dev/null | awk '{print $5}'")
      if file then
         fileSize = file:read("*l") or "Unknown"
         file:close()
      end
      statusText = statusText .. "\nDB size: " .. fileSize
   else
      statusText = statusText .. "\nNo cached entries"
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
end

M.clearRatioCacheSQLite = function()
   if not M.useSQLiteCache or not M.sqliteConn then
      naughty.notify({
         title = "SQLite Cache Error",
         text = "SQLite cache not initialized",
         position = "bottom_middle",
         timeout = 3,
         width = notiWidth
      })
      return
   end

   -- Get count before clearing
   local cursor = M.sqliteConn:execute("SELECT COUNT(*) as count FROM wallpaper_cache")
   local oldSize = 0
   if cursor then
      local row = cursor:fetch({}, "a")
      if row then oldSize = tonumber(row.count) or 0 end
      cursor:close()
   end

   -- Clear database
   M.sqliteConn:execute("DELETE FROM wallpaper_cache")
   M.sqliteConn:execute("VACUUM")

   -- Clear runtime cache
   M.ratioCache = {}

   naughty.notify({
      title = "SQLite Wallpaper Cache Cleared",
      text = "Cleared " .. oldSize .. " cached entries. Wallpaper ratios will be recalculated as needed.",
      position = "bottom_middle",
      icon = beautiful.refreshed,
      icon_size = 64,
      width = notiWidth
   })
end

-- Simple Journal Functions for SQLite fallback
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

M.processJournal = function(callback)
   local file = io.open(M.journalPath, "r")
   if not file then
      if callback then callback(0, 0) end
      return
   end

   local processed = 0
   local failed = 0

   if M.sqliteConn then
      M.sqliteConn:execute("BEGIN TRANSACTION")
   end

   for line in file:lines() do
      local parts = {}
      for part in line:gmatch("([^|]+)") do
         table.insert(parts, part)
      end

      if #parts >= 4 then
         local path, ratio, width, height = parts[1], parts[2], tonumber(parts[3]), tonumber(parts[4])
         if path and ratio and width and height then
            if M.cacheRatioSQLite(path, ratio, width, height) then
               processed = processed + 1
            else
               failed = failed + 1
            end
         else
            failed = failed + 1
         end
      else
         failed = failed + 1
      end
   end

   if M.sqliteConn then
      M.sqliteConn:execute("COMMIT")
   end

   file:close()

   -- If all entries were processed successfully, clear the journal
   if failed == 0 and processed > 0 then
      os.remove(M.journalPath)
      naughty.notify({
         title = "Journal Processed",
         text = "Recovered " .. processed .. " entries from journal",
         position = "bottom_middle",
         icon = beautiful.refreshed,
         icon_size = 64,
         width = notiWidth,
         timeout = 3
      })
   elseif processed > 0 then
      naughty.notify({
         title = "Journal Partially Processed",
         text = "Recovered " .. processed .. " entries, " .. failed .. " failed",
         position = "bottom_middle",
         icon = beautiful.refreshed,
         icon_size = 64,
         width = notiWidth,
         timeout = 5
      })
   end

   if callback then callback(processed, failed) end
end

M.clearJournal = function()
   os.remove(M.journalPath)
end


-- Persistent ratio cache functions


M.getCachedRatio = function(imagePath)
   -- Try SQLite cache first
   if M.useSQLiteCache then
      local ratio, width, height = M.getCachedRatioSQLite(imagePath)
      if ratio then
         return ratio, width, height
      end
   end

   -- Fall back to runtime cache
   local entry = M.ratioCache[imagePath]
   if not entry then
      return nil, nil, nil
   end

   return entry.ratio, entry.width, entry.height
end

M.cacheRatio = function(imagePath, ratio, width, height)
   -- Cache in SQLite if available
   if M.useSQLiteCache then
      if M.sqliteConn then
         local success = M.cacheRatioSQLite(imagePath, ratio, width, height)
         if not success then
            -- SQLite caching failed, write to journal as fallback
            M.writeToJournal(imagePath, ratio, width, height)
            naughty.notify({
               title = "SQLite Cache Warning",
               text = "Failed to cache: " .. (imagePath and imagePath:match("[^/]*$") or "unknown") .. " (saved to journal)",
               position = "bottom_right",
               timeout = 2,
               width = 350
            })
         end
      else
         -- SQLite not connected, write to journal
         M.writeToJournal(imagePath, ratio, width, height)

         -- Try to reconnect for next time
         if not M.initSQLiteCache() then
            naughty.notify({
               title = "SQLite Cache Error",
               text = "SQLite unavailable, using journal fallback",
               position = "bottom_middle",
               timeout = 3,
               width = notiWidth
            })
         else
            -- Retry caching after successful reconnection
            M.cacheRatioSQLite(imagePath, ratio, width, height)
         end
      end
   end

   -- Also cache in runtime cache for compatibility
   M.ratioCache[imagePath] = {
      ratio = ratio,
      width = width,
      height = height,
   }
end

M.showCacheStatus = function()
   M.showCacheStatusSQLite()
end

M.clearRatioCache = function()
   M.clearRatioCacheSQLite()
end

M.saveRatioCacheOnExit = function()
   -- SQLite cache is auto-saved, just close connection
   M.closeSQLiteCache()
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

-- Set wallpapers sequentially to avoid race conditions
M.setAllWallpapersSequentially = function(screens, callback)
   local completedCount = 0
   local function onWallpaperSet()
      completedCount = completedCount + 1
      if completedCount == #screens then
         -- After all wallpapers are set, do predictive preloading
         M.checkPredictivePreloading()
         if callback then callback() end
      end
   end
   
   for _, s in ipairs(screens) do
      M.setWallpaperAsync(s, onWallpaperSet)
   end
end

-- Synchronous version (for backward compatibility)
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

   -- M.setAllWallpapers()
   M.setAllWallpapersAsync()

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

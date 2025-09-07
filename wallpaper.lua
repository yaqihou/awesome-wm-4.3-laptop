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
      callback(cachedRatio, cachedWidth, cachedHeight)
      return
   end
   
   -- Cache miss, use ImageMagick identify
   local cmd = "identify -ping -format '%w %h' '" .. imagePath .. "' 2>/dev/null"
   
   awful.spawn.easy_async_with_shell(cmd, function(stdout, stderr, exitreason, exitcode)
      if exitcode ~= 0 or not stdout or stdout == "" then
         callback("unknown", nil, nil)
         return
      end
      
      local width, height = stdout:match("(%d+) (%d+)")
      if not width or not height then
         callback("unknown", nil, nil)
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
      
      callback(ratio, width, height)
   end)
end

-- Legacy sync function (kept for backward compatibility, but deprecated)
M.getImageRatio = function(imagePath)
   -- DEPRECATED: This function blocks awesome WM. Use getImageRatioAsync instead.
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
   local function onRatioDetected(wallpaperInfo, ratio, width, height)
      -- Store wallpaper info with dimensions
      local enhancedInfo = {
         path = wallpaperInfo.path,
         rawIdx = wallpaperInfo.rawIdx,
         width = width,
         height = height
      }
      results[wallpaperInfo.rawIdx] = {info = enhancedInfo, ratio = ratio}
      
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
         
         -- Save cache after processing batch (non-blocking)
         M.saveRatioCache("auto")
         
         if callback then callback() end
      end
   end
   
   -- Start async processing for each wallpaper
   for _, wallpaperInfo in ipairs(toProcess) do
      M.getImageRatioAsync(wallpaperInfo.path, function(ratio, width, height)
         onRatioDetected(wallpaperInfo, ratio, width, height)
      end)
   end
end

-- Legacy sync version (kept for backward compatibility but deprecated)
M.populateRatioCachesSync = function(batchSize)
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

-- Synchronous version (for backward compatibility, but uses blocking operations)  
-- Returns: wallpaper, rawIdx, actualRatio - actualRatio indicates which orientation was actually used
M.getNextWallpaperByRatio = function(desiredRatio)
   if not M.ratioBasedSelection then
      return nil, nil, nil
   end
   
   local targetList, targetIdx
   local actualRatio = desiredRatio  -- Track which orientation we actually use
   if desiredRatio == "portrait" then
      targetList = M.portraitList
      targetIdx = M.portraitIdx
   else
      targetList = M.landscapeList  
      targetIdx = M.landscapeIdx
   end
   
   -- Multi-batch search using sync version for compatibility
   local maxSearchAttempts = M.maxSearchAttempts or 5
   local searchAttempts = 0
   
   while targetIdx > #targetList and M.unprocessedCount > 0 and searchAttempts < maxSearchAttempts do
      M.populateRatioCachesSync(10)  -- Use sync version to maintain API compatibility
      searchAttempts = searchAttempts + 1
   end
   
   -- Handle different cases after search attempts
   if targetIdx > #targetList then
      if #targetList > 0 then
         -- Case 1: Target list has wallpapers but we've cycled through all - cycle back to start
         if desiredRatio == "portrait" then
            -- If there are still more to process, we can wait before cycling back to start
            if M.unprocessedCount == 0 then M.portraitIdx = 1 else M.portraitIdx = #targetList end
            targetIdx = M.portraitIdx
         else
            if M.unprocessedCount == 0 then M.landscapeIdx = 1 else M.landscapeIdx = #targetList end
            targetIdx = M.landscapeIdx
         end
      else
         -- Case 2: Target list is empty - fall back to other orientation
         if desiredRatio == "portrait" and #M.landscapeList > 0 then
            targetList = M.landscapeList
            targetIdx = M.landscapeIdx
            actualRatio = "landscape"  -- Update actual orientation used
         elseif desiredRatio == "landscape" and #M.portraitList > 0 then
            targetList = M.portraitList
            targetIdx = M.portraitIdx
            actualRatio = "portrait"  -- Update actual orientation used
         else
            return nil, nil, nil
         end
      end
   end
   
   if targetIdx <= #targetList then
      local wallpaperInfo = targetList[targetIdx]
      return wallpaperInfo.path, wallpaperInfo.rawIdx, actualRatio
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
   M.ratioCache = {}                -- Runtime cache: path -> {ratio, width, height, mtime}
   M.cacheFilePath = os.getenv("HOME") .. "/.config/awesome/wallpaper-ratio-cache.json"
   M.cacheVersion = "1.0"
   -- M.maxCacheEntries = 10000        -- Limit cache size

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
      { "Save Cache Now", function() M.saveRatioCache() end},
      { "Show Cache Status", function() M.showCacheStatus() end},
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
   
   -- Load persistent ratio cache async, then toggle gallery
   M.loadRatioCache(function()
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
   M.getImageRatioAsync(wallpaperPath, function(ratio, width, height)
      if width and height then
         M.dimensionCache[wallpaperPath] = {width = width, height = height}
         callback(width, height)
      else
         callback(nil, nil)
      end
   end)
end

-- Persistent ratio cache functions
M.loadRatioCache = function(callback)
   local cmd = "cat '" .. M.cacheFilePath .. "' 2>/dev/null"
   
   awful.spawn.easy_async_with_shell(
	  cmd,
	  function(stdout, stderr, exitreason, exitcode)
		 if exitcode ~= 0 or not stdout or stdout == "" then
			-- Cache file doesn't exist or empty, start with empty cache
			if callback then callback() end
			return
		 end
		 
		 local content = stdout
		 
		 -- Simple JSON parsing for cache structure
		 local success, cache_data = pcall(function()
			   -- Use a simple JSON-like format that's safe for Lua
			   local loadstring_func = loadstring or load
			   local func = loadstring_func("return " .. content)
			   if func then
				  return func()
			   end
			   return nil
		 end)
		 
		 if not success or not cache_data or not cache_data.version or not cache_data.cache then
			-- Invalid cache format, start fresh
			naughty.notify({
			   title = "Wallpaper Cache",
			   text = "Invalid cache format, starting fresh",
			   position = "bottom_middle",
			   icon = beautiful.refreshed,
			   icon_size = 64,
			   width = notiWidth
			})
			if callback then callback() end
			return
		 end
		 
		 -- Version check
		 if cache_data.version ~= M.cacheVersion then
			-- Version mismatch, start fresh
			naughty.notify({
			   title = "Wallpaper Cache",
			   text = "Cache version mismatch, starting fresh",
			   position = "bottom_middle",
			   icon = beautiful.refreshed,
			   icon_size = 64,
			   width = notiWidth
			})
			if callback then callback() end
			return
		 end
		 
		 -- Validate and load cache entries
		 local validEntries = 0
		 for filePath, entry in pairs(cache_data.cache) do
			if type(filePath) == "string" and type(entry) == "table" and 
			   entry.ratio and entry.width and entry.height then
			   
			   M.ratioCache[filePath] = entry
			   validEntries = validEntries + 1
			end
		 end
		 
		 -- Limit cache size by keeping most recently accessed entries
		 -- if validEntries > M.maxCacheEntries then
		 --    -- Simple approach: clear cache and let it rebuild
		 --    M.ratioCache = {}
		 -- end
		 
		 -- Show successful load notification
		 if validEntries > 0 then
			naughty.notify({
			   title = "Wallpaper Cache Loaded",
			   text = "Loaded " .. validEntries .. " cached wallpaper ratios",
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

M.saveRatioCache = function(notificationStyle)
   -- Create cache data structure
   local cache_data = {
      version = M.cacheVersion,
      last_updated = os.date("%Y-%m-%dT%H:%M:%S"),
      cache = M.ratioCache
   }
   
   -- Simple serialization that's safe for Lua
   local function serializeTable(t, indent)
      indent = indent or 0
      local result = "{\n"
      local indentStr = string.rep("  ", indent + 1)
      
      for k, v in pairs(t) do
         result = result .. indentStr .. "[" .. string.format("%q", k) .. "] = "
         
         if type(v) == "table" then
            result = result .. serializeTable(v, indent + 1)
         elseif type(v) == "string" then
            result = result .. string.format("%q", v)
         else
            result = result .. tostring(v)
         end
         result = result .. ",\n"
      end
      
      result = result .. string.rep("  ", indent) .. "}"
      return result
   end
   
   local content = serializeTable(cache_data)
   
   -- Write to temporary file first for atomic operation
   local temp_file_path = M.cacheFilePath .. ".tmp"
   local file = io.open(temp_file_path, "w")
   if not file then
      -- Can't write cache, fail silently
      return false
   end
   
   file:write(content)
   file:close()
   
   -- Atomic move from temp file to actual file
   os.rename(temp_file_path, M.cacheFilePath)
   
   -- Show save notification based on style
   if not M.suppressSaveNotification then
      local cacheSize = 0
      for _ in pairs(M.ratioCache) do
         cacheSize = cacheSize + 1
      end
      
      if notificationStyle == "auto" then
         -- Auto-save: simple, short notification
         naughty.notify({
            title = "Cache Auto-saved",
            text = cacheSize .. " entries",
            position = "bottom_right",
            icon = beautiful.refreshed,
            icon_size = 32,
            width = 200,
            timeout = 1
         })
      elseif notificationStyle ~= "silent" then
         -- Manual save: detailed notification (default)
         naughty.notify({
            title = "Wallpaper Cache Saved",
            text = "Saved " .. cacheSize .. " cached wallpaper ratios",
            position = "bottom_middle",
            icon = beautiful.refreshed,
            icon_size = 64,
            width = notiWidth,
            timeout = 2
         })
      end
   end
   
   return true
end

M.getCachedRatio = function(imagePath)
   local entry = M.ratioCache[imagePath]
   if not entry then
      return nil, nil, nil
   end
   
   return entry.ratio, entry.width, entry.height
end

M.cacheRatio = function(imagePath, ratio, width, height)
   
   M.ratioCache[imagePath] = {
      ratio = ratio,
      width = width,
      height = height,
   }
   
   -- Periodically save cache (every 50 new entries)
   local cache_size = 0
   for _ in pairs(M.ratioCache) do
      cache_size = cache_size + 1
   end
   
   if cache_size % 50 == 0 then
      M.saveRatioCache("auto")
   end
end

M.showCacheStatus = function()
   local cacheSize = 0
   local portraitCount = 0
   local landscapeCount = 0
   
   for _, entry in pairs(M.ratioCache) do
      cacheSize = cacheSize + 1
      if entry.ratio == "portrait" then
         portraitCount = portraitCount + 1
      else
         landscapeCount = landscapeCount + 1
      end
   end
   
   local statusText = "Cache entries: " .. cacheSize
   if cacheSize > 0 then
      statusText = statusText .. "\nPortrait: " .. portraitCount .. " | Landscape: " .. landscapeCount
      statusText = statusText .. "\nCache file: " .. M.cacheFilePath
      
      -- Calculate approximate file size
      local fileSize = "Unknown"
      local file = io.open(M.cacheFilePath, "r")
      if file then
         local size = file:seek("end")
         file:close()
         if size then
            if size < 1024 then
               fileSize = size .. " bytes"
            elseif size < 1024*1024 then
               fileSize = string.format("%.1f KB", size / 1024)
            else
               fileSize = string.format("%.1f MB", size / (1024*1024))
            end
         end
      end
      statusText = statusText .. "\nFile size: " .. fileSize
   else
      statusText = statusText .. "\nNo cached entries"
   end
   
   naughty.notify({
      title = "Wallpaper Ratio Cache Status",
      text = statusText,
      position = "bottom_middle",
      icon = beautiful.refreshed,
      icon_size = 64,
      width = notiWidth,
      timeout = 8
   })
end

M.clearRatioCache = function()
   local oldSize = 0
   for _ in pairs(M.ratioCache) do
      oldSize = oldSize + 1
   end
   
   -- Clear runtime cache
   M.ratioCache = {}
   
   -- Remove cache file
   os.remove(M.cacheFilePath)
   
   -- Show notification
   naughty.notify({ 
      title = "Wallpaper Cache Cleared",
      text = "Cleared " .. oldSize .. " cached entries. Wallpaper ratios will be recalculated as needed.",
      position = "bottom_middle",
      icon = beautiful.refreshed, 
      icon_size = 64,
      width = notiWidth
   })
end

M.saveRatioCacheOnExit = function()
   -- Save cache before AwesomeWM exits (silent)
   M.saveRatioCache("silent")
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
awesome.connect_signal("exit", M.saveRatioCacheOnExit)

return M

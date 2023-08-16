
local awesome, client, mouse, screen, tag = awesome, client, mouse, screen, tag
local ipairs, string, os, table, tostring, tonumber, type = ipairs, string, os, table, tostring, tonumber, type
local wibox         = require("wibox")
local beautiful     = require("beautiful")
local lain          = require("lain")
local awful         = require("awful")

local myutils       = require("myutils")
local hotkeys_popup = require("awful.hotkeys_popup").widget
local wallpaper     = require("wallpaper")
local mymenu        = require("menu")


local M = {}

local modkey         = "Mod4"
local hyperkey       = "Mod3"
local altkey         = "Mod1"
local newemacsclient = "emacsclient -c -n"
local terminal       = "x-terminal-emulator"


local function opacity_adjust(c, delta)
   c.opacity = c.opacity + delta
end

M.getGlobalkeys = function(myScreenIdx)

   local myScreenIdx = myScreenIdx or nil
   if myScreenIdx == nil then
      myScreenIdx, _ = myutils.updateScreenList()
   end
   
   -- {{{ Key bindings
   local globalkeys = awful.util.table.join(
      -- Take a screenshot
      -- https://github.com/lcpz/dots/blob/master/bin/screenshot
      awful.key(
         { modkey,  }, "F5",
         function()    wallpaper.refresh(true) end,
         {description = "Refresh wallpaper (next)", group = "wallpaper"}),
      awful.key(
         { modkey,  "Shift" }, "F5",
         function()    wallpaper.refresh(true, -1) end,
         {description = "Refresh wallpaper (prev)", group = "wallpaper"}),
      awful.key(
         { modkey,  }, "F1",
         function()    wallpaper.showWallpaperInfo(awful.screen.focused()) end,
         {description = "Show wallpaper info", group = "wallpaper"}),
      awful.key(
         { modkey, altkey  }, "i",
         function()    wallpaper.ignoreCurrentWallpaper(awful.screen.focused()) end,
         {description = "Ignore current focused wallpaper", group = "wallpaper"}),
      awful.key(
         { modkey, altkey, "Shift"  }, "i",
         function()    wallpaper.ignoreCurrentWallpaper(awful.screen.focused(), true) end,
         {description = "Accept current focused wallpaper", group = "wallpaper"}),
      awful.key(
         { modkey, altkey,  }, "Right",
         function()    wallpaper.shiftWallpaperForCurrentScreen(awful.screen.focused(), 0) end,
         {description = "Next Wallpaper for Current Screen", group = "wallpaper"}),
      awful.key(
         { modkey, altkey,  }, "Left",
         function()    wallpaper.shiftWallpaperForCurrentScreen(awful.screen.focused(), -1) end,
         {description = "Prev Wallpaper for Current Screen", group = "wallpaper"}),
      
      awful.key(
         { altkey, "Shift", "Control" }, "4",
         function() awful.spawn.with_shell("scrot -s") end,
         {description = "take a screenshot", group = "hotkeys"}),
      
      -- Hotkeys
      awful.key(
         { modkey,           }, "s",
         hotkeys_popup.show_help,
         {description = "show help", group="awesome"}),
      -- Tag browsing
      awful.key(
         { "Control", "Shift" }, "q", awful.tag.viewprev,
         {description = "view previous", group = "tag"}),
      awful.key(
         { "Control", "Shift" }, "w",  awful.tag.viewnext,
         {description = "view next", group = "tag"}),
      -- Backup
      awful.key(
         { modkey, "Control" }, "k", awful.tag.viewprev,
         {description = "view previous", group = "tag"}),
      awful.key(
         { modkey, "Control" }, "j",  awful.tag.viewnext,
         {description = "view next", group = "tag"}),
      -------------
      awful.key(
         { altkey, "Control", "Shift" }, "q", function () lain.util.tag_view_nonempty(-1) end,
         {description = "view previous nonempty", group = "tag"}),
      awful.key(
         { altkey, "Control", "Shift" }, "w",  function () lain.util.tag_view_nonempty(1) end,
         {description = "view next nonempty", group = "tag"}),
      awful.key(
         { modkey,           }, "Escape", awful.tag.history.restore,
         {description = "go back", group = "tag"}),
      
      -- Non-empty tag browsing
      -- awful.key({ "Control", "Shift" }, "q", function () lain.util.tag_view_nonempty(-1) end,
      --           {description = "view  previous nonempty", group = "tag"}),
      -- awful.key({ "Control", "Shift" }, "q",{ altkey }, "Right", function () lain.util.tag_view_nonempty(1) end,
      --           {description = "view  previous nonempty", group = "tag"}),
      
      -- Default client focus
      awful.key(
         { modkey }, "j",
         function () awful.client.focus.byidx(-1) end,
         {description = "focus next by index", group = "client"}
      ),
      awful.key(
         { modkey,           }, "k",
         function () awful.client.focus.byidx( 1) end,
         {description = "focus previous by index", group = "client"}
      ),
      awful.key(
         { modkey,           }, "w",
         function () mymenu.main:show() end,
         {description = "show main menu", group = "awesome"}),
      awful.key(
         { modkey,           }, "d",
         function () wallpaper.menu:show() end,
         {description = "show wallpaper menu", group = "awesome"}),
      -- Layout manipulation
      awful.key(
         { modkey, "Shift"   }, "j",
         function () awful.client.swap.byidx( -1) end,
         {description = "swap with next client by index", group = "client"}),
      awful.key(
         { modkey, "Shift"   }, "k",
         function () awful.client.swap.byidx(  1) end,
         {description = "swap with previous client by index", group = "client"}),
      awful.key(
         { modkey,           }, "o",
         function ()
            awful.screen.focus_relative( 1)
            -- awful.screen.focus_bydirection( 'right')
            myutils.updateFocusWidget()
         end,
         {description = "focus the next screen", group = "screen"}),
      awful.key(
         { modkey, altkey   }, "o",
         function ()
            awful.screen.focus_relative(-1)
            -- awful.screen.focus_bydirection( 'left')
            myutils.updateFocusWidget()
         end,
         {description = "focus the prev screen", group = "screen"}),
      awful.key(
         { modkey,           }, "u",
         awful.client.urgent.jumpto,
         {description = "jump to urgent client", group = "client"}),
      
      awful.key(
         { modkey,           }, "Tab",
         function ()
            awful.client.focus.history.previous()
            if client.focus then
               client.focus:raise()
            end
         end,
         {description = "go back", group = "client"}),
      
      -- -- Show/Hide Wibox
      -- awful.key(
      --    { modkey }, "b",
      --    function ()
      --       for s in screen do
      --          s.mywibox.visible = not s.mywibox.visible
      --          if s.mybottomwibox then
      --             s.mybottomwibox.visible = not s.mybottomwibox.visible
      --          end
      --       end
      --    end,
      --    {description = "toggle wibox", group = "awesome"}),
      
      -- On the fly useless gaps change
      awful.key(
         { altkey, "Control" }, "+",
         function () lain.util.useless_gaps_resize(1) end,
         {description = "increment useless gaps", group = "tag"}),
      awful.key(
         { altkey, "Control" }, "-",
         function () lain.util.useless_gaps_resize(-1) end,
         {description = "decrement useless gaps", group = "tag"}),
      
      -- Dynamic tagging
      awful.key(
         { altkey, "Control", "Shift" }, "n",
         function () lain.util.add_tag() end,
         {description = "add new tag", group = "tag"}),
      awful.key(
         { altkey, "Control", "Shift" }, "r",
         function () lain.util.rename_tag() end,
         {description = "rename tag", group = "tag"}),
      -- awful.key(
      --    { altkey, "Control", "Shift" }, "q",
      --    function () lain.util.move_tag(-1) end,
      --    {description = "move tag to the left", group = "tag"}),
      -- awful.key(
      --    { altkey, "Control", "Shift" }, "w",
      --    function () lain.util.move_tag(1) end,
      --    {description = "move tag to the right", group = "tag"}),
      -- awful.key(
      -- { altkey, "Control", "Shift" }, "d",
      -- function () lain.util.delete_tag() end,
      -- {description = "delete tag", group = "tag"}),
      
      -- Standard program
      awful.key(
         { modkey,           }, "Return",
         function () awful.spawn(terminal) end,
         {description = "open a terminal", group = "launcher"}),
      awful.key(
         { modkey,           }, "e",
         function () awful.spawn(newemacsclient) end,
         {description = "open emacsclient", group = "launcher"}),
      awful.key(
         { modkey, "Control", "Shift" }, "r", awesome.restart,
         {description = "reload awesome", group = "awesome"}),
      awful.key(
         { modkey, "Control" }, "d", wallpaper.toggleShowDesktop,
         {description = "Show Desktop", group = "awesome"}),
      
      -- layout adjustment
      awful.key(
         { modkey, }, "l",
         function () awful.tag.incmwfact( 0.05) end,
         {description = "increase master width factor", group = "layout"}),
      awful.key(
         { modkey, }, "h",
         function () awful.tag.incmwfact(-0.05) end,
         {description = "decrease master width factor", group = "layout"}),
      awful.key(
         { modkey, "Shift"   }, "l",
         function () awful.client.incwfact( 0.05) end,
         {description = "increase slave width factor", group = "layout"}),
      awful.key(
         { modkey, "Shift"   }, "h",
         function () awful.client.incwfact(-0.05) end,
         {description = "decrease slave width factor", group = "layout"}),
      awful.key(
         { modkey, "Shift"   }, "=",
         function () awful.tag.incnmaster( 1, nil, true) end,
         {description = "increase the number of master clients", group = "layout"}),
      awful.key(
         { modkey, "Shift"   }, "-",
         function () awful.tag.incnmaster(-1, nil, true) end,
         {description = "decrease the number of master clients", group = "layout"}),
      awful.key(
         { modkey, "Control" }, "h",
         function () awful.tag.incncol( 1, nil, true) end,
         {description = "increase the number of columns", group = "layout"}),
      awful.key(
         { modkey, "Control" }, "l",
         function () awful.tag.incncol(-1, nil, true) end,
         {description = "decrease the number of columns", group = "layout"}),
      -- layout change
      awful.key(
         { modkey,           }, "space",
         function () awful.layout.inc( 1) end,
         {description = "select next", group = "layout"}),
      awful.key(
         { modkey, "Shift"   }, "space",
         function () awful.layout.inc(-1) end,
         {description = "select previous", group = "layout"}),
      
      awful.key(
         { modkey, "Control" }, "n",
         function ()
            local c = awful.client.restore()
            -- Focus restored client
            if c then
               client.focus = c
               c:raise()
            end
         end,
         {description = "restore minimized", group = "client"}),
      
      -- Dropdown application
      awful.key(
         { modkey, }, "=",
         function () awful.screen.focused().quake:toggle() end,
         {description = "dropdown application", group = "launcher"}),
      
      -- Widgets popups
      -- -- Brightness
      awful.key({ }, "XF86MonBrightnessUp",
         function ()
            awful.util.spawn(beautiful.INC_BRIGHTNESS_CMD)
            beautiful.update_brightness_widget()
         end,
         {description = "+5%", group = "hotkeys"}),
      awful.key({ }, "XF86MonBrightnessDown",
         function ()
            awful.util.spawn(beautiful.DEC_BRIGHTNESS_CMD)
            beautiful.update_brightness_widget()
         end,
         {description = "-5%", group = "hotkeys"}),
      
      -- ALSA volume control
      awful.key(
         { "Shift" }, "XF86AudioRaiseVolume",
         function ()
            awful.spawn.with_shell(
               string.format("%s -q set %s 1%%+",
                             beautiful.volume.cmd,
                             beautiful.volume.channel))
            beautiful.volume.update()
         end,
         {description = "finer volume up", group = "hotkeys"}),
      awful.key(
         { "Shift" }, "XF86AudioLowerVolume",
         function ()
            awful.spawn.with_shell(
               string.format("%s -q set %s 1%%-",
                             beautiful.volume.cmd,
                             beautiful.volume.channel))
            beautiful.volume.update()
         end,
         {description = "finer volume down", group = "hotkeys"}),
      awful.key(
         { }, "XF86AudioRaiseVolume",
         function ()
            awful.spawn.with_shell(
               string.format("%s -q set %s 5%%+",
                             beautiful.volume.cmd,
                             beautiful.volume.channel))
            beautiful.volume.update()
         end,
         {description = "volume up", group = "hotkeys"}),
      awful.key(
         { }, "XF86AudioLowerVolume",
         function ()
            awful.spawn.with_shell(
               string.format("%s -q set %s 5%%-",
                             beautiful.volume.cmd,
                             beautiful.volume.channel))
            beautiful.volume.update()
         end,
         {description = "volume down", group = "hotkeys"}),
    awful.key(
       { }, "XF86AudioMute",
       function ()
          awful.spawn.with_shell(
             string.format(
                "%s -q set %s toggle",
                beautiful.volume.cmd,
                beautiful.volume.togglechannel or beautiful.volume.channel))
          beautiful.volume.update()
       end,
       {description = "toggle mute", group = "hotkeys"}),
    awful.key(
       { altkey }, "XF86AudioMute",
       function ()
          awful.spawn.with_shell(
             string.format("%s -q set %s 100%%",
                           beautiful.volume.cmd,
                           beautiful.volume.channel))
          beautiful.volume.update()
       end,
       {description = "volume 100%", group = "hotkeys"}),

	-- Cmus Control
	awful.key(
       { altkey, "Control" }, "w",
       function () awful.spawn.with_shell("cmus-remote -u") end,
	   {description = "Toggle Play of Cmus", group = "hotkeys"}),
	awful.key(
       { altkey, "Control" }, "f",
       function () awful.spawn.with_shell("cmus-remote -n") end,
	   {description = "Toggle Play of Cmus", group = "hotkeys"}),
	awful.key(
       { altkey, "Control" }, "q",
       function () awful.spawn.with_shell("cmus-remote -r") end,
	   {description = "Toggle Play of Cmus", group = "hotkeys"}),

    -- Copy primary to clipboard (terminals to gtk)
    awful.key(
       { modkey }, "c",
       function () awful.spawn("xsel | xsel -i -b") end,
       {description = "copy terminal to gtk", group = "hotkeys"}),
    -- Copy clipboard to primary (gtk to terminals)
    awful.key(
       { modkey }, "v", function () awful.spawn("xsel -b | xsel") end,
       {description = "copy gtk to terminal", group = "hotkeys"}),

    -- {{{ User programs
    awful.key(
       { modkey, "Shift" }, "c", function () awful.spawn(browser) end,
       {description = "run browser", group = "launcher"}),
	-- Binding for =emacs-anywhere=
    awful.key(
       { modkey }, "a",
       function () awful.spawn("/home/yaqi/.emacs_anywhere/bin/run") end,
       {description = "Call emacs-anywhere", group = "launcher"}),

    awful.key(
       { modkey, "Control"  }, "s", function() awful.spawn("fsearch") end,
       {description = "rofi ssh", group = "rofi"}),
    -- Prompt
    awful.key(
       { modkey, "Control"  }, "r", function() awful.spawn("rofi -show run") end,
       {description = "rofi run", group = "rofi"}),
    awful.key(
       { modkey, "Control"  }, "w", function() awful.spawn("rofi -show window") end,
       {description = "rofi window", group = "rofi"}),
    awful.key(
       { modkey, "Control"  }, "f", function() awful.spawn("rofi -show drun") end,
       {description = "rofi drun", group = "rofi"}),
    -- awful.key(
    --    { modkey, "Control"  }, "s", function() awful.spawn("rofi -show ssh") end,
    --    {description = "rofi ssh", group = "rofi"}),
    awful.key(
       { modkey }, "r",
       function () awful.screen.focused().mypromptbox:run() end,
       {description = "run prompt", group = "launcher"}),
    awful.key(
       { modkey }, "x",
       function ()
          awful.prompt.run {
             prompt       = "Run Lua code: ",
             textbox      = awful.screen.focused().mypromptbox.widget,
             exe_callback = awful.util.eval,
             history_path = awful.util.get_cache_dir() .. "/history_eval"
          }
       end,
       {description = "lua execute prompt", group = "awesome"}),
    ------------------
    -- Custom clients
      awful.key(
         { altkey, "Control", "Shift" }, "c",
         function ()
            awful.spawn.with_shell("google-chrome")
         end,
         {description = "Open a New Chrome Client", group = "Application"}),
      awful.key(
         { altkey, "Control", "Shift" }, "f",
         function ()
            awful.spawn.with_shell("firefox")
         end,
         {description = "Open a New Firefox Client", group = "Application"}),
      awful.key(
         { altkey, "Control", "Shift" }, "s",
         function ()
            awful.spawn.with_shell("slack")
         end,
         {description = "Open or raise the slack client", group = "Application"}),
      
      -- Run or Raise
      awful.key(
         { altkey, "Control", "Shift" }, "j",
         function ()
            local matcher = function (c)
               return awful.rules.match(c, {class = "org.jabref.gui.JabRefMain"})
            end
            awful.client.run_or_raise('jabref', matcher)
         end,
         {description = "Run or Raise Jabref", group = "Application"}),
      
      -- Clients Menu
      awful.key(
         { altkey, "Control" }, "c",
         function ()
            mymenu.app("Google-chrome", "google-chrome")
         end,
         {description = "Open Clients List for Chrome", group = "Application"}),
      awful.key(
         { altkey, "Control" }, "e",
         function ()
            mymenu.app("Emacs", "newem")
         end,
         {description = "Open Clients List for Emacsclient", group = "Application"})
   )
   -- Custom Screen Focus Movement

   for i, v in pairs(myScreenIdx) do
      local descr_view, descr_move
      if i == 1 or i == screen:count() then
         descr_view = {description = "view screen #", group = "screen"}
         descr_move = {description = "move focused client to screen #", group = "screen"}
      end

      globalkeys = awful.util.table.join(
         globalkeys,
         -- View tag only.
         awful.key({ hyperkey }, "#" .. i + 9,
            function ()
               awful.screen.focus(v)
               myutils.updateFocusWidget()
            end,
            descr_view),
         -- Toggle tag display.
         awful.key({ hyperkey, altkey }, "#" .. i + 9,
            function ()
               if client.focus ~= nil then
                  client.focus:move_to_screen(v)
               end
            end,
            descr_move)
      )
   end

   -- Bind all key numbers to tags.
   -- Be careful: we use keycodes to make it works on any keyboard layout.
   -- This should map on the top row of your keyboard, usually 1 to 9.
   for i = 1, 10 do
      -- Hack to only show tags 1 and 9 in the shortcut window (mod+s)
      local descr_view, descr_toggle, descr_move, descr_toggle_focus
      if i == 1 or i == 10 then
         descr_view = {
            description = "view tag #", group = "tag"}
         descr_toggle = {
            description = "toggle tag #", group = "tag"}
         descr_move = {
            description = "move focused client to tag #", group = "tag"}
         descr_toggle_focus = {
            description = "toggle focused client on tag #", group = "tag"}
      end
      globalkeys = awful.util.table.join(
         globalkeys,
         -- View tag only.
         awful.key({ modkey }, "#" .. i + 9,
            function ()
               local screen = awful.screen.focused()
               local tag = screen.tags[i]
               if tag then
                  tag:view_only()
               end
            end,
            descr_view),
         -- Toggle tag display.
         awful.key({ modkey, "Control" }, "#" .. i + 9,
            function ()
               local screen = awful.screen.focused()
               local tag = screen.tags[i]
               if tag then
                  awful.tag.viewtoggle(tag)
               end
            end,
            descr_toggle),
         -- Move client to tag.
         awful.key({ modkey, "Shift" }, "#" .. i + 9,
            function ()
               if client.focus then
                  local tag = client.focus.screen.tags[i]
                  if tag then
                     client.focus:move_to_tag(tag)
                  end
               end
            end,
            descr_move),
         -- another set to move to tag, just for convenience
         awful.key({ modkey, altkey }, "#" .. i + 9,
            function ()
               if client.focus then
                  local tag = client.focus.screen.tags[i]
                  if tag then
                     client.focus:move_to_tag(tag)
                  end
               end
            end,
            descr_move),
         -- Toggle tag on focused client.
         awful.key({ modkey, "Control", "Shift" }, "#" .. i + 9,
            function ()
               if client.focus then
                  local tag = client.focus.screen.tags[i]
                  if tag then
                     client.focus:toggle_tag(tag)
                  end
               end
            end,
            descr_toggle_focus)
      )
   end

   return globalkeys

end

M.getClientkeys = function()

   local clientkeys = awful.util.table.join(
      -- Opacity contrlo
      awful.key(
         { modkey, "Control" }, "=",
         function (c) opacity_adjust(c,  0.01) end,
         {description = "Fine Increase Client Opacity", group = "client"}),
      awful.key(
         { modkey, "Control" }, "-",
         function (c) opacity_adjust(c, -0.01) end,
         {description = "Fine Decrease Client Opacity", group = "client"}),
      awful.key(
         { modkey, "Shift", "Control" }, "=",
         function (c) opacity_adjust(c,  0.05) end,
         {description = "Increase Client Opacity", group = "client"}),
      awful.key(
         { modkey, "Shift", "Control" }, "-",
         function (c) opacity_adjust(c, -0.05) end,
         {description = "Decrease Client Opacity", group = "client"}),
      
      -- Size Control
      awful.key({ altkey, "Shift"   }, "m", lain.util.magnify_client,
         {description = "magnify client", group = "client"}),
      awful.key(
         { modkey,           }, "f",
         function (c)
            c.fullscreen = not c.fullscreen
            c:raise()
         end,
         {description = "toggle fullscreen", group = "client"}),
      -- awful.key({hyperkey}, "t", 
      --    function()
      --       local traywidget =  wibox.widget.systray()
      --       traywidget:set_screen(awful.screen.focused())
      --    end,
      --    {description = "move systray to screen", group = "awesome"}),
      awful.key(
         { modkey,           }, "q", function (c) c:kill() end,
         {description = "close", group = "client"}),
      awful.key(
         { modkey, "Control" }, "space",
         awful.client.floating.toggle,
         {description = "toggle floating", group = "client"}),
      awful.key(
         { modkey, "Control" }, "Return",
         function (c) c:swap(awful.client.getmaster()) end,
         {description = "move to master", group = "client"}),
      awful.key(
         { modkey, "Control"   }, "o",
         function (c) c:move_to_screen() end,
         {description = "move to screen", group = "client"}),
      awful.key(
         { modkey,           }, "t",
         function (c) c.ontop = not c.ontop end,
         {description = "toggle keep on top", group = "client"}),
      awful.key(
         { modkey, "Control"   }, "t", awful.titlebar.toggle,
         {description = "toggle titlebar", group = "client"}),
      awful.key(
         { modkey,           }, "n",
         function (c)
            -- The client currently has the input focus, so it cannot be
            -- minimized, since minimized clients can't have the focus.
            c.minimized = true
         end ,
         {description = "minimize", group = "client"}),
      awful.key({ modkey,           }, "m",
         function (c)
            c.maximized = not c.maximized
            c:raise()
         end ,
         {description = "maximize", group = "client"})
   ) -- End of Client Key
   
   return clientkeys
end -- M.getClientkey


return M
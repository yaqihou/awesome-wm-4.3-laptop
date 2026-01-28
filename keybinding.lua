
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

local basicKeybindings = awful.util.table.join(
   -- Tag browsing
   awful.key(
      { "Control", "Shift" }, "q", awful.tag.viewprev,
      {description = "view previous", group = "tag"}),
   awful.key(
      { "Control", "Shift" }, "w",  awful.tag.viewnext,
      {description = "view next", group = "tag"}),
   awful.key(
      { altkey, "Control", "Shift" }, "q", function () lain.util.tag_view_nonempty(-1) end,
      {description = "view previous nonempty", group = "tag"}),
   awful.key(
      { altkey, "Control", "Shift" }, "w",  function () lain.util.tag_view_nonempty(1) end,
      {description = "view next nonempty", group = "tag"}),
   awful.key(
      { modkey,           }, "Escape", awful.tag.history.restore,
      {description = "go back", group = "tag"}),
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
   -- By Direction
   awful.key(
      { modkey,          }, "Left",
      function () awful.client.focus.bydirection('left') end,
      {description = "focus the left client", group = "client"}),
   awful.key(
      { modkey,          }, "Right",
      function () awful.client.focus.bydirection('right') end,
      {description = "focus the right client", group = "client"}),
   awful.key(
      { modkey,          }, "Up",
      function () awful.client.focus.bydirection('up') end,
      {description = "focus the up client", group = "client"}),
   awful.key(
      { modkey,          }, "Down",
      function () awful.client.focus.bydirection('down') end,
      {description = "focus the down client", group = "client"}),
   -- [END] By Direction
   --
   awful.key(
      { modkey,           }, "w",
      function () mymenu.main:show() end,
      {description = "show main menu", group = "awesome"}),
   awful.key(
      { modkey,           }, "s",
      function () mymenu.script:show() end,
      {description = "show scrcipt menu", group = "awesome"}),
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
   -- By Direction
   awful.key(
      { modkey, altkey   }, "Left",
      function ()
         awful.screen.focus_bydirection('left')
         myutils.updateFocusWidget()
      end,
      {description = "focus the left screen", group = "screen"}),
   awful.key(
      { modkey, altkey   }, "Right",
      function ()
         awful.screen.focus_bydirection('right')
         myutils.updateFocusWidget()
      end,
      {description = "focus the right screen", group = "screen"}),
   awful.key(
      { modkey, altkey   }, "Up",
      function ()
         awful.screen.focus_bydirection('up')
         myutils.updateFocusWidget()
      end,
      {description = "focus the up screen", group = "screen"}),
   awful.key(
      { modkey, altkey   }, "Down",
      function ()
         awful.screen.focus_bydirection('down')
         myutils.updateFocusWidget()
      end,
      {description = "focus the down screen", group = "screen"}),
   -- [END] By Direction
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
   -- Dynamic tagging
   awful.key(
      { altkey, "Control", "Shift" }, "n",
      function () lain.util.add_tag() end,
      {description = "add new tag", group = "tag"}),
   awful.key(
      { altkey, "Control", "Shift" }, "r",
      function () lain.util.rename_tag() end,
      {description = "rename tag", group = "tag"}),
   awful.key(
      { altkey, "Control", "Shift" }, "Left",
      function () lain.util.move_tag(-1) end,
      {description = "move tag to left", group = "tag"}),
   awful.key(
      { altkey, "Control", "Shift" }, "Right",
      function () lain.util.move_tag(1) end,
      {description = "add new tag", group = "tag"}),
   
   -- layout adjustment
   awful.key(
      { modkey, }, "l",
      function ()
         awful.tag.incmwfact( 0.05)
      end,
      {description = "increase master width factor", group = "layout"}),
   awful.key(
      { modkey, }, "h",
      function ()
         awful.tag.incmwfact(-0.05)
      end,
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
      { modkey, "Control"   }, "=",
      function () awful.tag.incnmaster( 1, nil, true) end,
      {description = "increase the number of master clients", group = "layout"}),
   awful.key(
      { modkey, "Control"   }, "-",
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
      function ()
         awful.layout.inc( 1)
         local curTag = awful.screen.focused().selected_tag
         local layoutName = curTag.layout.name
         if layoutName == "termfair" then
            curTag.gap = 5
         else
            curTag.gap = 0
         end
      end,
      {description = "select next", group = "layout"}),
   awful.key(
      { modkey, "Shift"   }, "space",
      function ()
         awful.layout.inc(-1)
         local curTag = awful.screen.focused().selected_tag
         local layoutName = curTag.layout.name
         if layoutName == "termfair" then
            curTag.gap = 5
         else
            curTag.gap = 0
         end
      end,
      {description = "select previous", group = "layout"}),
   -- Show/Hide Wibox
   awful.key(
      { modkey, "Shift" }, "b",
      function ()
         for s in screen do
            s.mywibox.visible = not s.mywibox.visible
            if s.mybottomwibox then
               s.mybottomwibox.visible = not s.mybottomwibox.visible
            end
         end
      end,
      {description = "toggle wibox (all)", group = "awesome"}),
   awful.key(
      { modkey }, "b",
      function ()
         local s = awful.screen.focused()
        s.mywibox.visible = not s.mywibox.visible
        if s.mybottomwibox then
            s.mybottomwibox.visible = not s.mybottomwibox.visible
        end
      end,
      {description = "toggle wibox", group = "awesome"}),
   
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
         {description = "restore minimized", group = "client"})
)

local fnKeybindings  = awful.util.table.join(
   -- Widgets popups
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
         awful.spawn(
            string.format("%s -q set %s 1%%+",
                          beautiful.volume.cmd,
                          beautiful.volume.channel))
         beautiful.volume.update()
      end,
      {description = "finer volume up", group = "hotkeys"}),
   awful.key(
      { "Shift" }, "XF86AudioLowerVolume",
      function ()
         awful.spawn(
            string.format("%s -q set %s 1%%-",
                          beautiful.volume.cmd,
                          beautiful.volume.channel))
         beautiful.volume.update()
      end,
      {description = "finer volume down", group = "hotkeys"}),
   awful.key(
      { }, "XF86AudioRaiseVolume",
      function ()
         awful.spawn(
            string.format("%s -q set %s 5%%+",
                          beautiful.volume.cmd,
                          beautiful.volume.channel))
         beautiful.volume.update()
      end,
      {description = "volume up", group = "hotkeys"}),
   awful.key(
      { }, "XF86AudioLowerVolume",
      function ()
         awful.spawn(
            string.format("%s -q set %s 5%%-",
                          beautiful.volume.cmd,
                          beautiful.volume.channel))
         beautiful.volume.update()
      end,
      {description = "volume down", group = "hotkeys"}),
   awful.key(
      { }, "XF86AudioMute",
      function ()
         awful.spawn(
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
         awful.spawn(
            string.format("%s -q set %s 100%%",
                          beautiful.volume.cmd,
                          beautiful.volume.channel))
         beautiful.volume.update()
      end,
      {description = "volume 100%", group = "hotkeys"})
)
-- Add mapping to function keys
-- for i = 1, 10 do
--    fnKeybindings = awful.util.table.join(
--       fnKeybindings,
--       awful.key({ altkey, "Shift" }, "#" .. i + 9,
--          function() awful.spawn.with_shell('DISPLAY=:1 xdotool key --clearmodifiers F' .. i) end
--       )
--    )
-- end
-- fnKeybindings = awful.util.table.join(
--    fnKeybindings,
--    awful.key({ altkey, "Shift" }, "-",
--       function() awful.spawn.with_shell('DISPLAY=:1 xdotool key --clearmodifiers F11') end
--    ),
--    awful.key({ altkey, "Shift" }, "=",
--       function() awful.spawn.with_shell('DISPLAY=:1 xdotool key --clearmodifiers F12') end
--    )
-- )

local appKeybindings = awful.util.table.join(
   -- Take a screenshot
   -- https://github.com/lcpz/dots/blob/master/bin/screenshot 
   awful.key(
      { modkey, "Shift" }, "s",
      function ()
         awful.spawn.with_shell(
			"scrot -s -F - | xclip -selection clipboard -t image/png"
		 )
      end,
      {description = "Take a screenshot", group = "Apps"}),
   -- Standard program
   awful.key(
      { modkey,           }, "Return",
      function () awful.spawn(terminal) end,
      {description = "open a terminal", group = "Apps"}),
   awful.key(
      { modkey,           }, "e",
      function () awful.spawn(newemacsclient) end,
      {description = "open emacsclient", group = "Apps"}),
    awful.key(
       { altkey, "Control", "Shift" }, "c",
       function ()
          awful.spawn("google-chrome")
       end,
       {description = "Open a New Chrome Client", group ="Apps"}),
    awful.key(
       { altkey, "Control", "Shift" }, "f",
       function ()
          awful.spawn("firefox")
       end,
       {description = "Open a New Firefox Client", group ="Apps"}),
    awful.key(
       { altkey, "Control", "Shift" }, "j",
       function ()
          local matcher = function (c)
             return awful.rules.match(c, {class = "org.jabref.gui.JabRefMain"})
          end
          awful.client.run_or_raise('jabref', matcher)
       end,
       {description = "Run or Raise Jabref", group ="Apps"}),
      
	-- Binding for =emacs-anywhere=
    awful.key(
       { modkey }, "a",
       function () awful.spawn("/home/yaqi/.emacs_anywhere/bin/run") end,
       {description = "Call emacs-anywhere", group="Apps"}),
    awful.key(
       { modkey, "Control"  }, "s", function() awful.spawn("fsearch") end,
       {description = "fsearch", group ="Apps"}),
    -- Prompt
    awful.key(
       { modkey, "Control"  }, "r", function() awful.spawn("rofi -show run") end,
       {description = "rofi run", group ="Apps"}),
    awful.key(
       { modkey, "Control"  }, "a", function() awful.spawn("rofi -show drun") end,
       {description = "rofi run", group ="Apps"}),
    awful.key(
       { modkey, "Control"  }, "w", function() awful.spawn("rofi -show window") end,
       {description = "rofi window", group ="Apps"}),
    awful.key(
       { modkey, "Control"  }, "f", function() awful.spawn("rofi -show filebrowser") end,
       {description = "rofi drun", group ="Apps"})
    -- awful.key(
    --    { modkey, "Control"  }, "s", function() awful.spawn("rofi -show ssh") end,
    --    {description = "rofi ssh", group = "rofi"}),
	-- Cmus Control
	-- awful.key(
    --    { altkey, "Control" }, "w",
    --    function () awful.spawn.with_shell("cmus-remote -u") end,
	--    {description = "Toggle Play of Cmus", group = "hotkeys"}),
	-- awful.key(
    --    { altkey, "Control" }, "f",
    --    function () awful.spawn.with_shell("cmus-remote -n") end,
	--    {description = "Toggle Play of Cmus", group = "hotkeys"}),
	-- awful.key(
    --    { altkey, "Control" }, "q",
    --    function () awful.spawn.with_shell("cmus-remote -r") end,
	--    {description = "Toggle Play of Cmus", group = "hotkeys"}),
)

M.getGlobalkeys = function()

   myScreenSymbol2Idx, _ = myutils.updateScreenList()
   
   -- {{{ Key bindings
   local globalkeys = awful.util.table.join(
      -- Hotkeys
      awful.key(
         { modkey,           }, "/",
         hotkeys_popup.show_help,
         {description = "show help", group="awesome"}),
      -------------
      awful.key(
         { modkey, altkey    }, "Return",
         function () awful.client.getmaster():jump_to() end,
         {description = "jump to master client", group = "Apps"}),
      -------------
      -- awful.key(
      --    { modkey, "Control", "Shift" }, "r", awesome.restart,
      --    {description = "reload awesome", group = "awesome"}),
      -- On the fly useless gaps change
      awful.key(
         { altkey, "Control" }, "[",
         function () lain.util.useless_gaps_resize(5) end,
         {description = "increment useless gaps", group = "tag"}),
      awful.key(
         { altkey, "Control" }, "]",
         function () lain.util.useless_gaps_resize(-5) end,
         {description = "decrement useless gaps", group = "tag"}),
    ------------------
    -- Custom clients
      awful.key(
         { modkey, "Control" }, "c",
         function ()
            mymenu.app("Google-chrome", "google-chrome")
         end,
         {description = "Open Clients List for Chrome", group = "Menu"}),
      awful.key(
         { modkey, "Control" }, "e",
         function ()
            mymenu.app("Emacs", "newem")
         end,
         {description = "Open Clients List for Emacsclient",
          group = "Menu"})
   )

   -- Wallpaper keybindings
   globalkeys = awful.util.table.join(globalkeys, basicKeybindings)
   globalkeys = awful.util.table.join(globalkeys, fnKeybindings)
   globalkeys = awful.util.table.join(globalkeys, wallpaper.keybindings)
   globalkeys = awful.util.table.join(globalkeys, appKeybindings)
   -- Custom Screen Focus Movement

   for symbol, idx in pairs(myScreenSymbol2Idx) do
      -- local descr_view, descr_move
      -- if i == 1 or i == screen:count() then
      --    descr_view = {description = "view screen #", group = "screen"}
      --    descr_move = {description = "move focused client to screen #, focus moved with client", group = "screen"}
      --    descr_move_stay = {description = "move focused client to screen #, focus stayed unchanged", group = "screen"}
      -- end
	  local descr_view = {description = "view screen", group = "screen"}
      local descr_move = {description = "move focused client to screen", group = "screen"}

      globalkeys = awful.util.table.join(
         globalkeys,
         awful.key({ hyperkey, }, symbol,
            function ()
               awful.screen.focus(idx)
               myutils.updateFocusWidget()
            end,
            descr_view),
         awful.key({ hyperkey, altkey }, symbol,
            function ()
               if client.focus ~= nil then
                  client.focus:move_to_screen(idx)
                  myutils.updateFocusWidget()
               end
            end,
            descr_move),
         awful.key({ hyperkey, altkey, "Shift" }, symbol,
            function ()
               if client.focus ~= nil then
                  local srcScreen = awful.screen.focused()
                  client.focus:move_to_screen(idx)
                  awful.screen.focus(srcScreen)
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
         -- Switch to client by number
         awful.key({ modkey, altkey }, "#" .. i + 9,
            function ()
               local cls = client.get(awful.screen.focused())
               local fcls = {}
               for _, c in ipairs(cls) do
                  if not (c.type == "desktop" or c.type == "dock" or c.type == "splash") then
                    if c:isvisible() and c.focusable then
                        table.insert(fcls, c)
                    end
                  end
               end
               if fcls and i <= #fcls then
                  fcls[i]:jump_to()
               end
            end,
            descr_move),
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
         -- Toggle tag for focused client.
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
         { modkey, "Shift" }, "]",
         function (c) opacity_adjust(c,  0.01) end,
         {description = "Fine Increase Client Opacity", group = "client"}),
      awful.key(
         { modkey, "Shift" }, "[",
         function (c) opacity_adjust(c, -0.01) end,
         {description = "Fine Decrease Client Opacity", group = "client"}),
      -- awful.key(
      --    { modkey, "Shift", "Control" }, "=",
      --    function (c) opacity_adjust(c,  0.05) end,
      --    {description = "Increase Client Opacity", group = "client"}),
      -- awful.key(
      --    { modkey, "Shift", "Control" }, "-",
      --    function (c) opacity_adjust(c, -0.05) end,
      --    {description = "Decrease Client Opacity", group = "client"}),
      
      -- Size Control
      awful.key({ modkey, "Shift"   }, "m", lain.util.magnify_client,
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
         function (c) awful.client.setmaster(c) end,
         {description = "move to master", group = "client"}),
      awful.key(
         { modkey, "Control"   }, "o",
         function (c) c:move_to_screen() end,
         {description = "move to screen", group = "client"}),
      awful.key(
         { modkey,           }, "g",
         function (c) c.sticky = not c.sticky end,
         {description = "toggle client sticky", group = "client"}),
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
         end,
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

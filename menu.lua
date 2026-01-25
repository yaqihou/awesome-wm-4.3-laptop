
local awesome, client, mouse, screen, tag = awesome, client, mouse, screen, tag
local awful         = require("awful")
local hotkeys_popup = require("awful.hotkeys_popup").widget
local beautiful     = require("beautiful")

local wallpaper = require("wallpaper")
local myutils = require("myutils")
local vlc_focus_mute = require("vlc_focus_mute")

M = {}

local terminal       = "x-terminal-emulator"
local newemacsclient = "emacsclient -c -n"
local guieditor      = "emacsclient -c -n"
local browser        = "google-chrome"
local editor         = os.getenv("EDITOR") or "vim"

-- {{{ Menu
local awesomemenu = {
   { "Hotkeys",
     function()
        return false, hotkeys_popup.show_help
     end 
   },
   -- { "Manual", terminal .. " -e man awesome" },
   { "Edit config",
     string.format("%s -e %s %s", terminal, guieditor, awesome.conffile) },
   { "Restart", awesome.restart },
   { "Quit", function() awesome.quit() end}
}

local displaymenu = {
   { "Lock",
     "sleep 0.5 && xset dpms force off && command -v xscreensaver-command && xscreensaver-command -lock"},
   { "Turn off Monitor",
     'sleep 0.5 && xset dpms force off'},
   { "Report Monitor Props",
     function()
        for s in screen do
           myutils.reportMonitor(s)
        end
   end },
}

local powermenu = {
   { "Suspend", "sudo systemctl suspend" },
   { "Sus-Hib", "sudo systemctl suspend-then-hibernate" },
   { "Hibernate", "sudo systemctl hibernate" },
}

local servicemenu = {
   { "Restart Dropbox",
     -- if using the command directly, the dropbox will run but
     -- the systray will not show up
     function() awful.spawn.with_shell("dropbox stop && dropbox start") end,},
   { "Restart Emacs",
     "systemctl --user restart emacs.service"},
   { "Update VPN Widget",
     function() beautiful.update_vpn_widget(true) end}, -- true: forec update},
}

local scriptmenu = awful.menu{
   {
	  "Toggle VLC Unmute-on-focus for current tag",
	  function () vlc_focus_mute.toggle() end,
   },
   {
	  "Refresh VLC Unmute-on-focus PID list",
	  function () vlc_focus_mute.refresh() end,
   },
}

local mainmenu = awful.menu{
   items = {
        { "Awesome", awesomemenu},--, beautiful.awesome_icon },
        { "Display", displaymenu},
        { "Power", powermenu},
        { "Services", servicemenu},
        -- { "Sound Setting", terminal .. ' -e alsamixer'},
        -- { "Toggle xcompmgr[s]", "my-toggle-xcompmgr-simple" },
        { "Open terminal", terminal },
   },
   auto_expand = true
}

local myScreenSymbol2Idx, myScreenIdx2Symbol = myutils.updateScreenList()
local app_menu = function(appClass, newCmd)
   local items = {}
   local minimizedStatus = ""
   local header = ""
   
   for i, c in pairs(client.get()) do
      if awful.rules.match(c, {class = appClass}) then
         if c.minimized then
            minimized = "*"
         else
            minimized = " "
         end

        header = string.format(
            "%s[%s-%d] %s",
            minimized, string.upper(myScreenIdx2Symbol[c.screen.index]), c.first_tag.index, c.name)

         items[#items+1] =
            {header, function()
                c.first_tag:view_only()
                client.focus = c
             end, c.icon}
      end
   end
   items[#items+1] = {string.format("Create New %s Client", appClass), newCmd}

   local s = awful.screen.focused()
   local x = math.floor(s.geometry.x + s.geometry.width / 2 - beautiful.menu_width / 2)
   local y = math.floor(s.geometry.y + s.geometry.height / 2)
   
   awful.menu({items = items}):show({coords = {x = x, y = y}})
end


M.wallpaper = wallpaper.menu
M.main = mainmenu
M.script = scriptmenu
M.app = app_menu



return M

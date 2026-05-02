--[[

     Awesome WM configuration template
     github.com/lcpz

--]]

-- {{{ Required libraries
local awesome, client, mouse, screen, tag = awesome, client, mouse, screen, tag
local ipairs, string, os, table, tostring, tonumber, type = ipairs, string, os, table, tostring, tonumber, type

local gears         = require("gears")
local awful         = require("awful")
                      require("awful.autofocus")
local wibox         = require("wibox")
local beautiful     = require("beautiful")
local naughty       = require("naughty")
local lain          = require("lain")
local ruled         = require("ruled")
-- }}}

-- {{{ Error handling
if awesome.startup_errors then
    naughty.notify({ preset = naughty.config.presets.critical,
                     title = "Oops, there were errors during startup!",
                     text = awesome.startup_errors })
end

do
    local in_error = false
    awesome.connect_signal("debug::error", function (err)
        if in_error then return end
        in_error = true

        naughty.notify({ preset = naughty.config.presets.critical,
                         title = "Oops, an error happened!",
                         text = tostring(err) })
        in_error = false
    end)
end
-- }}}

-- {{{ Autostart windowless processes
-- local function run_once(cmd_arr)
--     for _, cmd in ipairs(cmd_arr) do
--         findme = cmd
--         firstspace = cmd:find(" ")
--         if firstspace then
--             findme = cmd:sub(0, firstspace-1)
--         end
--         awful.spawn.with_shell(string.format("pgrep -u $USER -x %s > /dev/null || (%s)", findme, cmd))
--     end
-- end

-- run_once({ "unclutter -root -idle 10" }) -- entries must be comma-separated
-- }}}

-- {{{ Variable definitions

local modkey         = "Mod4"
local hyperkey       = "Mod3"
local altkey         = "Mod1"
local terminal       = "x-terminal-emulator"

awful.util.terminal = terminal
awful.util.tagnames = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0" }
awful.layout.layouts = {
    awful.layout.suit.tile,
    awful.layout.suit.tile.top,
    -- awful.layout.suit.floating,
    lain.layout.termfair,
    -- lain.layout.termfair.center,
    -- lain.layout.cascade.tile,
    awful.layout.suit.max,
    -- lain.layout.centerwork,
    -- lain.layout.cascade,
    -- awful.layout.suit.magnifier,
    -- awful.layout.suit.fair,
    --awful.layout.suit.tile.left,
    --awful.layout.suit.tile.bottom,
    --awful.layout.suit.fair.horizontal,
    --awful.layout.suit.spiral,
    --awful.layout.suit.spiral.dwindle,
    --awful.layout.suit.max.fullscreen,
    --awful.layout.suit.corner.nw,
    --awful.layout.suit.corner.ne,
    --awful.layout.suit.corner.sw,
    --awful.layout.suit.corner.se,
    --lain.layout.centerwork.horizontal,
}

awful.util.taglist_buttons = awful.util.table.join(
   awful.button({ }, 1, function(t) t:view_only() end),
   awful.button({ modkey }, 1, function(t)
         if client.focus then
            client.focus:move_to_tag(t)
         end
   end),
   awful.button({ }, 3, awful.tag.viewtoggle),
   awful.button({ modkey }, 3, function(t)
         if client.focus then
            client.focus:toggle_tag(t)
         end
   end),
   awful.button({ }, 4, function(t) awful.tag.viewnext(t.screen) end),
   awful.button({ }, 5, function(t) awful.tag.viewprev(t.screen) end)
)

awful.util.tasklist_buttons = awful.util.table.join(
   awful.button({ }, 1, function (c)
         if c == client.focus then
            c.minimized = true
         else
            -- Without this, the following
            -- :isvisible() makes no sense
            c.minimized = false
            if not c:isvisible() and c.first_tag then
               c.first_tag:view_only()
            end
            -- This will also un-minimize
            -- the client, if needed
            client.focus = c
            c:raise()
         end
   end),
   awful.button({ }, 3, function()
         local instance = nil
         
         return function ()
            if instance and instance.wibox.visible then
               instance:hide()
               instance = nil
            else
               instance = awful.menu.clients({ theme = { width = 250 } })
            end
         end
   end),
   awful.button({ }, 4, function ()
         awful.client.focus.byidx(1)
   end),
   awful.button({ }, 5, function ()
         awful.client.focus.byidx(-1)
end))

local theme_path = string.format("%s/.config/awesome/themes/theme.lua", os.getenv("HOME"))
beautiful.init(theme_path)

-- }}}
-- This should be loaded after beautiful to correctly reflect the theme
local wallpaper = require("wallpaper")
local keybinding = require("keybinding")
local myutils = require("myutils")
local mymenu = require("menu")

mymenu.main:add(
   { "Re-apply global keybinding",
     function ()
        local globalkeys = keybinding.getGlobalkeys()
        -- Set keys
        root.keys(globalkeys)
     end
   },
   #mymenu.main.items -- secont to last
)

-- Setup Wallpaper Accordingly
-- Re-set wallpaper when a screen's geometry changes (e.g. different resolution)
-- NOTE make sure this after beautiful
wallpaper.init()
screen.connect_signal("property::geometry", function(s)
    if beautiful.wallpaper then
       wallpaper.refresh()
    end
end)

-- {{{ Screen
-- Create a wibox for each screen and add it
awful.screen.connect_for_each_screen(
   function(s) beautiful.at_screen_connect(s) end)


-- Set the Menubar terminal for applications that require it
-- menubar.utils.terminal = terminal 
-- }}}

-- key-bindings
globalkeys = keybinding.getGlobalkeys()

-- Set keys
root.keys(globalkeys)
-- {{{ Mouse bindings
root.buttons(awful.util.table.join(
    awful.button({ }, 3, function () mymenu.main:toggle() end),
    awful.button({ }, 4, awful.tag.viewnext),
    awful.button({ }, 5, awful.tag.viewprev)
))
-- }}}


clientkeys = keybinding.getClientkeys()
clientbuttons = awful.util.table.join(
    awful.button({ }, 1, function (c) client.focus = c; c:raise() end),
    awful.button({ modkey }, 1, awful.mouse.client.move),
    awful.button({ modkey }, 3, awful.mouse.client.resize))

-- {{{
-- Rules to apply to new clients (through the "manage" signal).
awful.rules.rules = {
    -- All clients will match this rule.
    { rule = { },
      properties = {
         border_width = beautiful.border_width,
         border_color = beautiful.border_normal,
         focus = awful.client.focus.filter,
         raise = true,
         keys = clientkeys,
         buttons = clientbuttons,
         screen = awful.screen.preferred,
         placement = awful.placement.no_overlap+awful.placement.no_offscreen,
         size_hints_honor = false -- false to remove gap
     }
    },

    -- Titlebars
    { rule_any = { type = { "dialog", "normal" } },
      properties = { titlebars_enabled = true } },

    -- Set Firefox to always map on the first tag on screen 1.
    -- { rule = { class = "Firefox" },
    --   properties = { screen = 1, tag = awful.util.tagnames[1] } },

    { rule = { class = "Emacs" },
      properties = { opacity = 0.95 }},

    { rule = { class = "Google-chrome", role = "pop-up" },
      properties = { floating=true },
      callback = function(c)
         c:geometry({width=800, height=600})
      end
    },

    { rule = { class = "Google-chrome", above = true },
      properties = { opacity = 0.8 },
    },

    { rule_any = { class = {"Google-chrome", "Nautilus"} },
      properties = { opacity = 0.98 }},

    { rule_any = { class = {"org.jabref.gui.JabRefMain",  "Gnome-terminal"} },
      properties = { opacity = 0.85 }},

    { rule_any = { class = {"Eog", "Nautilus"} },
      properties = {titlebars_enabled = false,
                    requests_no_titlebar = true}},

	-- Set floating clients
    { rule_any = { class = {"feh", "Mathematica", 
                            "libprs500", "Envince",
                            "onscripter", "matplotlib", "steam_proton",
                            "Eog", "Matplotlib", "org.jabref.gui.JabRefMain",
                            "MEGAsync"} },
      properties = { floating = true } },

	-- Set ontop clients
    { rule_any = { class = { "Matplotlib" } },
      properties = { ontop = true } },

	-- Set center clients
	{ rule_any = {class = {"feh", "libprs500",
                           "onscripter", "Steam", "stretchly", "Eog" }},
	  callback = function(c)
		 awful.placement.centered(c)
	  end
	},
    { rule = { name = "TelegramDesktop"},
      callback = function(c)
         local keys = c:keys()
         c:keys(awful.util.table.join(
                   keys,
                   awful.key(
                      { }, "Control_R",
                      function ()
                         awful.spawn("xdotool mousemove 3534 1420 click 1 mousemove restore mousemove 3590 624 click 1 mousemove restore")
                      end,
                      {description = "Press position to download", group="Temporary"}
                   )))
      end
    },

    { rule = { name = "Picture in picture"},
      properties = { floating = true,
                     ontop = true,
                     titlebars_enabled = false}},

    { rule = { class = "Gimp", role = "gimp-image-window" },
      properties = { maximized = true } },
}
-- }}}

-- {{{ Signals
-- Signal function to execute when a new client appears.
client.connect_signal("manage", function (c)
    -- Set the windows at the slave,
    -- i.e. put it at the end of others instead of setting it master.
    if not awesome.startup then awful.client.setslave(c) end

    if awesome.startup and
      not c.size_hints.user_position
      and not c.size_hints.program_position then
        -- Prevent clients from being unreachable after screen count changes.
        awful.placement.no_offscreen(c)
    end
end)

-- Add a titlebar if titlebars_enabled is set to true in the rules.
client.connect_signal("request::titlebars", function(c)
    -- Custom
    if beautiful.titlebar_fun then
        beautiful.titlebar_fun(c)
        return
    end

    -- Default
    -- buttons for the titlebar
    local buttons = awful.util.table.join(
        awful.button({ }, 1, function()
            client.focus = c
            c:raise()
            awful.mouse.client.move(c)
        end),
        awful.button({ }, 3, function()
            client.focus = c
            c:raise()
            awful.mouse.client.resize(c)
        end)
    )

    awful.titlebar(c, {size = 16}) : setup {
        { -- Left
            awful.titlebar.widget.iconwidget(c),
            buttons = buttons,
            layout  = wibox.layout.fixed.horizontal
        },
        { -- Middle
            { -- Title
                align  = "center",
                widget = awful.titlebar.widget.titlewidget(c)
            },
            buttons = buttons,
            layout  = wibox.layout.flex.horizontal
        },
        { -- Right
            awful.titlebar.widget.floatingbutton (c),
            awful.titlebar.widget.maximizedbutton(c),
            awful.titlebar.widget.stickybutton   (c),
            awful.titlebar.widget.ontopbutton    (c),
            awful.titlebar.widget.closebutton    (c),
            layout = wibox.layout.fixed.horizontal()
        },
        layout = wibox.layout.align.horizontal
    }

	-- Hide the titlebar for non-floating only
	-- local l = awful.layout.get(c.screen)
	-- if not c.floating then
	   awful.titlebar.hide(c)
	-- end
end)

-- Enable sloppy focus, so that focus follows mouse.
client.connect_signal(
   "mouse::enter", function(c)
      if awful.layout.get(c.screen) ~= awful.layout.suit.magnifier
      and awful.client.focus.filter(c) then
         client.focus = c
      end
end)

-- Enable Auto Title bar when toggle floating
-- client.connect_signal(
--    "property::floating", function (c)
--       if c.class ~= 'Nautilus' and c.class ~= 'Eog' then
--         if c.floating and not c.maximized then
--             awful.titlebar.show(c)
--         else
--             awful.titlebar.hide(c)
--         end
--       end
-- end)

-- No border for maximized clients
client.connect_signal(
   "focus", function(c)
      if c.maximized then -- no borders if only 1 client visible
         c.border_width = 0
      elseif #awful.screen.focused().clients > 1 then
         c.border_width = beautiful.border_width
         c.border_color = beautiful.border_focus
      end
end)
client.connect_signal(
   "unfocus",
   function(c) c.border_color = beautiful.border_normal end)
-- }}}

-- Update the focus indicator
if screen:count() > 1 then
    client.connect_signal(
    "focus", function(c)
        myutils.updateFocusWidget()
    end)
    client.connect_signal(
    "property::screen", function(c)
        myutils.updateFocusWidget()
    end)
end

-- Run App at Startup
-- local autorun_path = string.format("%s/.config/awesome/autorun.sh", os.getenv("HOME"))
-- awful.spawn.easy_async(autorun_path, function(stdout, stderr, exitreason, exitcode) end)

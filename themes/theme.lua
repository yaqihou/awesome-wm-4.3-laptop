--[[
   
   My Awesome WM Theme 4.3

   based on 
   Holo Awesome WM theme 3.0
   github.com/lcpz
   
--]]

local screen  = screen
local gears   = require("gears")
local gtable  = require("gears.table")
local lain    = require("lain")
local awful   = require("awful")
local wibox   = require("wibox")
local naughty = require("naughty")
local helpers = require("lain.helpers")
local string  = string
local os      = os

local volumeWidget = require('awesome-wm-widgets.volume-widget.volume')
-- local vpnWidget = require('widgets.vpn')

local theme   = {}

theme.default_dir = require("awful.util").get_themes_dir() .. "default"
theme.icon_dir    = os.getenv("HOME") .. "/.config/awesome/themes/icons"
-- theme.wallpaper   = os.getenv("HOME") .. "/Pictures/wallpaper/"
-- theme.wallpaper_alter = os.getenv("HOME") .. "/Pictures/wallpaper-alter/"

theme.wallpaper = {
   {
      name="Normal",
	  galleryType='folder',
      path=os.getenv("HOME") .. "/Pictures/wallpaper/",
      mode="max", quite=true, interval=600
   },
   {
      name="Adult",
	  galleryType='filelist',
      path=os.getenv("HOME") .. "/Pictures/wallpaper-adult/",
      mode="max", quite=true, interval=90,
      cmd="shuf " .. os.getenv("HOME") .. "/Pictures/wallpaper-adult-filelist > /tmp/wall-list"
   },
   {
      name="Custom",
      path='@combine',
	  galleryType='filelist',
      mode="max", quite=true, interval=90,
      cmd="shuf " .. os.getenv("HOME") .. "/Pictures/custom-wallpaper-filelist > /tmp/wall-list",
      cmd_portrait="shuf " .. os.getenv("HOME") .. "/Pictures/custom-wallpaper-portrait-filelist > /tmp/wall-list",
   },
}

theme.font     = "Noto Sans Display SemiBold 10"
theme.monofont = "Noto Sans Mono Bold 10"

local carolinaBlueWeb     = "#4B9CD3"
local transparency = "E6"
local transparency2 = "F6"
-- local widgetBackgroundShape = gears.shape.rectangle
local widgetBackgroundShape = gears.shape.rounded_bar

theme.fg_normal = "#FFFFFF"
theme.bg_normal = "#242424" .. transparency
-- theme.fg_focus  = "#0099CC"
theme.fg_focus  = "#FFFFFF"
theme.bg_focus_bare = "#404040" 
theme.bg_focus  = theme.bg_focus_bare.. transparency2
theme.fg_urgent = "#D87900"
theme.bg_urgent = theme.bg_focus_bare.. transparency2

theme.border_width  = 2
theme.border_normal = "#707C7C"
theme.border_focus  = "#4FAAD6"

theme.taglist_fg_focus = "#4FAAD6"
theme.taglist_bg_focus = theme.bg_focus
theme.taglist_fg_empty = "#505050"
theme.taglist_font     = "Noto Sans Display SemiBold 12"

theme.tasklist_fg_focus     = "#4FAAD6"
theme.tasklist_bg_focus     = "#505050" .. "CC" -- brighter
-- theme.tasklist_border_color = "#505050"
theme.tasklist_border_width = 1
theme.tasklist_border_color = "#777777"
theme.tasklist_fg_minimize  = "#777777"
theme.tasklist_floating     = "[F]"
theme.tasklist_maximized    = "[M]"
theme.tasklist_ontop        = "[T]"
theme.tasklist_font         = "Noto Sans Mono 10"
theme.tasklist_font_focus   = "Noto Sans Mono ExtraBold 10"
theme.tasklist_disable_icon = true

theme.systray_icon_spacing = 4
theme.bg_systray = theme.bg_focus_bare

theme.notification_icon_size = 64
theme.notification_opacity   = 0.9
theme.notification_shape     = gears.shape.rounded_rect
theme.notification_font      = "Noto Sans Mono 14"

theme.prompt_fg_cursor =  "#4FAAD6"

theme.menu_height    = 40
theme.menu_width     = 320
theme.menu_icon_size = 32

theme.awesome_icon          = theme.icon_dir .. "/awesome_icon_white.png"
theme.awesome_icon_launcher = theme.icon_dir .. "/awesome_icon.png"
-- theme.spr_small             = theme.icon_dir .. "/spr_small.png"
-- theme.spr_very_small        = theme.icon_dir .. "/spr_very_small.png"
-- theme.spr_right             = theme.icon_dir .. "/spr_right.png"
-- theme.spr_bottom_right      = theme.icon_dir .. "/spr_bottom_right.png"
-- theme.spr_left              = theme.icon_dir .. "/spr_left.png"
-- theme.bar                   = theme.icon_dir .. "/bar.png"
-- theme.bottom_bar            = theme.icon_dir .. "/bottom_bar.png"
-- theme.mpdl                  = theme.icon_dir .. "/mpd.png"
-- theme.mpd_on                = theme.icon_dir .. "/mpd_on.png"
-- theme.prev                  = theme.icon_dir .. "/prev.png"
-- theme.nex                   = theme.icon_dir .. "/next.png"
-- theme.stop                  = theme.icon_dir .. "/stop.png"
-- theme.pause                 = theme.icon_dir .. "/pause.png"
-- theme.play                  = theme.icon_dir .. "/play.png"
theme.clock                 = theme.icon_dir .. "/myclock.png"
theme.calendar              = theme.icon_dir .. "/mycal.png"
theme.cpu                   = theme.icon_dir .. "/cpu.png"
theme.net_up                = theme.icon_dir .. "/net_up.png"
theme.net_down              = theme.icon_dir .. "/net_down.png"
-- theme.layout_tile           = theme.icon_dir .. "/tile.png"
-- theme.layout_tileleft       = theme.icon_dir .. "/tileleft.png"
-- theme.layout_tilebottom     = theme.icon_dir .. "/tilebottom.png"
-- theme.layout_tiletop        = theme.icon_dir .. "/tiletop.png"
-- theme.layout_fairv          = theme.icon_dir .. "/fairv.png"
-- theme.layout_fairh          = theme.icon_dir .. "/fairh.png"
-- theme.layout_spiral         = theme.icon_dir .. "/spiral.png"
-- theme.layout_dwindle        = theme.icon_dir .. "/dwindle.png"
-- theme.layout_max            = theme.icon_dir .. "/max.png"
-- theme.layout_fullscreen     = theme.icon_dir .. "/fullscreen.png"
-- theme.layout_magnifier      = theme.icon_dir .. "/magnifier.png"
-- theme.layout_floating       = theme.icon_dir .. "/floating.png"
theme.layout_tile           = theme.icon_dir .. "/mytile.png"
theme.layout_tiletop        = theme.icon_dir .. "/mytiletop.png"
theme.layout_floating       = theme.icon_dir .. "/myfloating.png"
theme.layout_max            = theme.icon_dir .. "/mymax.png"

theme.refreshed             = theme.icon_dir .. "/refreshed.png"
theme.warning               = theme.icon_dir .. "/warning.png"
theme.my_redx               = theme.icon_dir .. "/my_redx.png"
theme.my_greencheck               = theme.icon_dir .. "/my_greencheck.png"
theme.brightness            = theme.icon_dir .. "/brightness_icon.png"

theme.useless_gap              = 0

theme.titlebar_close_button_normal              = theme.default_dir.."/titlebar/close_normal.png"
theme.titlebar_close_button_focus               = theme.default_dir.."/titlebar/close_focus.png"
theme.titlebar_minimize_button_normal           = theme.default_dir.."/titlebar/minimize_normal.png"
theme.titlebar_minimize_button_focus            = theme.default_dir.."/titlebar/minimize_focus.png"
theme.titlebar_ontop_button_normal_inactive     = theme.default_dir.."/titlebar/ontop_normal_inactive.png"
theme.titlebar_ontop_button_focus_inactive      = theme.default_dir.."/titlebar/ontop_focus_inactive.png"
theme.titlebar_ontop_button_normal_active       = theme.default_dir.."/titlebar/ontop_normal_active.png"
theme.titlebar_ontop_button_focus_active        = theme.default_dir.."/titlebar/ontop_focus_active.png"
theme.titlebar_sticky_button_normal_inactive    = theme.default_dir.."/titlebar/sticky_normal_inactive.png"
theme.titlebar_sticky_button_focus_inactive     = theme.default_dir.."/titlebar/sticky_focus_inactive.png"
theme.titlebar_sticky_button_normal_active      = theme.default_dir.."/titlebar/sticky_normal_active.png"
theme.titlebar_sticky_button_focus_active       = theme.default_dir.."/titlebar/sticky_focus_active.png"
theme.titlebar_floating_button_normal_inactive  = theme.default_dir.."/titlebar/floating_normal_inactive.png"
theme.titlebar_floating_button_focus_inactive   = theme.default_dir.."/titlebar/floating_focus_inactive.png"
theme.titlebar_floating_button_normal_active    = theme.default_dir.."/titlebar/floating_normal_active.png"
theme.titlebar_floating_button_focus_active     = theme.default_dir.."/titlebar/floating_focus_active.png"
theme.titlebar_maximized_button_normal_inactive = theme.default_dir.."/titlebar/maximized_normal_inactive.png"
theme.titlebar_maximized_button_focus_inactive  = theme.default_dir.."/titlebar/maximized_focus_inactive.png"
theme.titlebar_maximized_button_normal_active   = theme.default_dir.."/titlebar/maximized_normal_active.png"
theme.titlebar_maximized_button_focus_active    = theme.default_dir.."/titlebar/maximized_focus_active.png"

theme.titlebar_bg_normal = theme.bg_normal .. transparency

theme.layout_termfair    = theme.icon_dir .. "/mytermfair.png"
theme.layout_centerfair  = theme.icon_dir .. "/mycenterfair.png"  -- termfair.center
theme.layout_cascade     = theme.icon_dir .. "/mycascade.png"
theme.layout_centerwork  = theme.icon_dir .. "/mycenterwork.png"

local hostname = helpers.first_line('/etc/hostname'):gsub('\n', '')

local markup = lain.util.markup
local blue   = "#80CCE6"
local space2 = markup.font(theme.font, "  ")
local space3 = markup.font(theme.font, "   ")

local bar = wibox.widget{
   widget = wibox.widget.separator,
   shape  = gears.shape.circle,
   -- color  = theme.bg_focus,
   visible = false,
   color  = nil,
   -- forced_width = 7,
}
local space2Widget = wibox.widget.textbox(space2)
local space4Widget = wibox.widget.textbox(space2 .. space2)
local my_green = "#32CD32"

-- local my_red   = "#B22222"
-- local my_yellow = "#FFC300"

local my_red   = "#FF4949"
local my_yellow = "#FFAD22"

local my_lightgray = "#a0a0a0"


local function hex_to_rgb(hex_str)
   local rgb_table = {}
   for i = 2,6,2 do
      rgb_table[i//2] = tonumber('0x' .. hex_str:sub(i, i+1))
   end 
   return rgb_table
end

local function rgb_to_hex(rgb_table)
   local hex_str = "#"
   for _, num in ipairs(rgb_table) do
      hex_str = hex_str .. string.format("%02x", math.floor(num))
   end
   return hex_str
end

local my_green_rgb = hex_to_rgb(my_green)
local my_red_rgb = hex_to_rgb(my_red)
local my_yellow_rgb = hex_to_rgb(my_yellow)
local my_fg_normal_rgb = hex_to_rgb(theme.fg_normal)

local function get_linear_gradient(ratio)
   local ratio = math.max(math.min(ratio, 1), 0)

   -- local start_rgb = my_green_rgb
   local start_rgb = my_fg_normal_rgb
   local end_rgb = my_yellow_rgb
   local prop = ratio * 2
   if ratio > 0.5 then
      start_rgb = my_yellow_rgb
      end_rgb = my_red_rgb
      prop = 2 * ratio - 1
   end
   
   local tmp_rgb = {}
   local invprop = 1 - prop

   for idx, c in ipairs(start_rgb) do
      tmp_rgb[idx] = c * invprop + end_rgb[idx] * prop
   end

   return rgb_to_hex(tmp_rgb)
end

-- local function getPercentageColor(perc)
--    if perc < 30 then
--       return theme.fg_normal
--    elseif perc < 70 then
-- return "#ff8000"
--    else
--       return my_red
--    end
-- end

-----------------------------------------------------------------------------

-- VPN Indicator
local vpnOffMarkup = markup.font(theme.monofont, "VPN " .. markup(my_lightgray, "OFF"))

local vpntext = wibox.widget.textbox(vpnOffMarkup)
local vpntextwidget = wibox.container.margin(
   wibox.container.background(vpntext, theme.bg_focus, widgetBackgroundShape),
   0, 0, 5, 5)

theme.update_vpn_widget = function()
   awful.spawn.easy_async_with_shell(
      "nordvpn status",
      function(out, err, reason, code)
         -- only update when forced or the status changed
         local status = out:match("Status: (%a+)\n") 

         if status == "Connected" then -- connected
            local city = out:match("City: (%a+)\n") 
            local text = markup.font(theme.monofont, "VPN " .. markup(my_green, "ON @ " .. city)) 
            vpntext:set_markup(space2 .. text .. space2)
         else
            vpntext:set_markup(space2 .. vpnOffMarkup .. space2)
         end
   end)
end

local vpnwidget_timer = gears.timer {
   timeout = 10,
   call_now = true,
   autostart = true,
   callback = function() theme.update_vpn_widget() end}


vpntextwidget:connect_signal(
   "mouse::enter",
   function()
      theme.update_vpn_widget()
      -- TODO move it to widgets folder and add notifications
   end
)


-- Clock
local mytextclock = wibox.widget.textclock(
   markup("#FFFFFF", space3 .. "%H:%M" .. space3))
mytextclock.font = theme.font
local clock_icon = wibox.widget.imagebox(theme.clock, true)
local clockbg = wibox.container.background(
   wibox.widget{
      layout=wibox.layout.fixed.horizontal,
      space2Widget,
      clock_icon,
      mytextclock
   },
   theme.bg_focus, widgetBackgroundShape)
local clockwidget = wibox.container.margin(clockbg, 0, 0, 5, 5)


-- Calendar
local mytextcalendar = wibox.widget.textclock(
   markup.fontfg(theme.font, "#FFFFFF", space3 .. "%a %b %d" .. space3))
local calendar_icon = wibox.widget.imagebox(theme.calendar)
local calbg = wibox.container.background(
   wibox.widget{
      layout=wibox.layout.fixed.horizontal,
      space2Widget,
      calendar_icon,
      mytextcalendar,
   },
   theme.bg_focus, widgetBackgroundShape)
local calendarwidget = wibox.container.margin(calbg, 0, 0, 5, 5)


local mycal = lain.widget.cal({
	  -- cal = "/usr/bin/cal -h",
      attach_to = { mytextclock, mytextcalendar },
      notification_preset = {
         fg = "#FFFFFF",
         bg = theme.bg_normal,
         position = "bottom_right",
         font = theme.monofont,
      }
})
-- Disable mouseover popup
mytextclock:disconnect_signal("mouse::enter", mycal.hover_on)
mytextcalendar:disconnect_signal("mouse::enter", mycal.hover_on)

-- MPD
-- local mpd_icon = wibox.widget.imagebox(theme.mpdl)

local batwidget
local mybrightnesswidget 
local brightness_text

if hostname == 'ThinkPad' then

   -- Battery
    local bat = lain.widget.bat({
        timeout = 15,
        ac = "AC",
        settings = function()
            if bat_now.ac_status == 0 then
                bat_header = " Bat "
                header_color = "#F5C400"
            else
                bat_header = " AC "
                header_color = "#4E9D2D"
            end

            if bat_now.status == "Full" then
                bat_foot = "(Full) "
            elseif bat_now.status == "Charging" then
                bat_foot = "(Charging: " .. bat_now.time .. ") " 
            elseif bat_now.status == "Discharging" then
                bat_foot = "(Discharging: " .. bat_now.time .. ") " 
            else
                bat_foot = "(N/A) "
            end

            bat_p      = bat_now.perc .. "% " .. bat_foot
            widget:set_markup(
               space2 ..
                  markup.font(theme.font,
                              markup(header_color, bat_header)
                                 .. bat_p)
                  .. space2)
        end
    })
    local batbg = wibox.container.background(bat.widget, theme.bg_focus, widgetBackgroundShape)
    batwidget = wibox.container.margin(batbg, 0, 0, 5, 5)
    batwidget:connect_signal("mouse::enter", function() end)

    -- Brightness
    local GET_BRIGHTNESS_CMD = "light -G"   -- "xbacklight -get"
    theme.INC_BRIGHTNESS_CMD = "light -A 5" -- "xbacklight -inc 5"
    theme.DEC_BRIGHTNESS_CMD = "light -U 5" -- "xbacklight -dec 5"

    local brightness_icon = wibox.widget.imagebox(theme.brightness)
    local brightness_text = wibox.widget.textbox()
    local brightness_widget = wibox.widget {
       space2Widget,
       brightness_icon,
       brightness_text,
       layout = wibox.layout.fixed.horizontal,
    }

    local brightness_bg = wibox.container.background(
    brightness_widget, theme.bg_focus, widgetBackgroundShape)
    mybrightnesswidget = wibox.container.margin(brightness_bg, 0, 0, 5, 5)

    function theme.update_brightness_widget()
    awful.spawn.easy_async_with_shell(
        GET_BRIGHTNESS_CMD,
        function(stdout)
            local brightness_level = tonumber(string.format("%.0f", stdout))
            brightness_text:set_markup(
                space2 ..
                markup.font(
                    theme.monofont,
                    "BRT " .. brightness_level .. "%") .. space2)
    end)
    end

    theme.update_brightness_widget()

    brightness_text:connect_signal(
    "button::press",
    function(_,_,_,button)
        if button == 4 then
            awful.spawn(theme.INC_BRIGHTNESS_CMD, false)
            theme.update_brightness_widget()
        elseif button == 5 then
            awful.spawn(theme.DEC_BRIGHTNESS_CMD, false)
            theme.update_brightness_widget()
        end
    end)
end

-- ALSA volume bar
local volumeCmd = "amixer"
local volumeChannel = "PCM"
theme.volume = lain.widget.alsabar({
	  notification_preset = { font = theme.monofont, fg = "#FF00FF"},
	  --togglechannel = "IEC958,3",
      cmd = volumeCmd,
	  channel = volumeChannel,
	  width = 80, height = 10, border_width = 0,
	  colors = {
		 background = "#404040",
		 unmute     = carolinaBlueWeb,
		 mute       = "#FF9F9F"
	  },
})
theme.volume.bar.paddings = 0
theme.volume.bar.margins = 5
theme.volume.bar:buttons(
   awful.util.table.join(
    awful.button({}, 3, function() -- right click
          awful.spawn.with_shell(
             string.format(
                "%s set %s toggle",
                theme.volume.cmd,
                theme.volume.togglechannel or theme.volume.channel))
        theme.volume.update()
    end),
    awful.button({}, 4, function() -- scroll up
          awful.spawn.with_shell(
             string.format(
                "%s set %s 1%%+", theme.volume.cmd, theme.volume.channel))
        theme.volume.update()
    end),
    awful.button({}, 5, function() -- scroll down
          awful.spawn.with_shell(
             string.format(
                "%s set %s 1%%-", theme.volume.cmd, theme.volume.channel))
        theme.volume.update()
    end)
))

local volumewidget = wibox.container.background(
   theme.volume.bar, theme.bg_focus, widgetBackgroundShape)
volumewidget = wibox.container.margin(volumewidget, 0, 0, 5, 5)

-- GPU
local gpuwidget
if hostname == "suzuki-trotter" then
    local gputext = wibox.widget.textbox()
    local gpuUpdate = function()
    -- local checkCmd = "gpustat --no-header -P draw | awk -F '|' '{print $2 $3}' ORS=';'"
    local checkCmd = "gpustat --no-header -P draw | awk -F '|' '{print $2 $3}'"
    -- local checkCmd = 'gpustat --no-header'
    awful.spawn.easy_async_with_shell(
        checkCmd,
        function(out)
           local res_text="GPU "
           for line in out:gmatch("[^\n]+") do
              local usage = 0
              for res in line:gmatch('(%d+)%s*%%') do
                 usage = tonumber(res)
              end
              local color = get_linear_gradient(usage / 100)
              res_text = res_text .. "[" .. markup(color, line:gsub("^%s+", ""):gsub("%s+$", "")) .. "] "
           end
           res_text = res_text:gsub('%s+$', '')
           
           gputext:set_markup(
              markup("#FFFFFF", space2 .. markup.font(theme.monofont, res_text)))
    end)
    end

    gpuwidget = wibox.container.margin(
    wibox.container.background(gputext, theme.bg_focus, widgetBackgroundShape),
    0, 0, 5, 5)
    local gpuTimer = gears.timer {
    timeout = 2,
    call_now = true,
    autostart = false,
    callback = gpuUpdate}
    gpuTimer:start()
end

-- CPU
local cpu_icon = wibox.widget.imagebox(theme.cpu)
local cpu = lain.widget.cpu({
      settings = function()
         -- local color = getPercentageColor(cpu_now.usage)
         local color = get_linear_gradient(cpu_now.usage / 100.)
         widget:set_markup(
            space2
               .. markup.font(
                  theme.monofont,
                  "CPU " ..
                     markup(color, string.format("%2d", cpu_now.usage) .. "%")
                             )
               .. space2)
      end
})
local cpubg = wibox.container.background(
   cpu.widget, theme.bg_focus, widgetBackgroundShape)
local cpuwidget = wibox.container.margin(cpubg, 0, 0, 5, 5)

-- Mem
local mem = lain.widget.mem({
      settings = function()
         -- local color = getPercentageColor(mem_now.perc)
         local color = get_linear_gradient(mem_now.perc / 100.)
         widget:set_markup(
            space2
               .. markup.font(
                  theme.monofont, "MEM " .. markup(color, string.format("%2d", mem_now.perc) .. "%")
                             )
               .. space2)
      end
})
local memWidgetBG = wibox.container.background(
   mem.widget, theme.bg_focus, widgetBackgroundShape)

local membg = wibox.container.background(
   mem.widget, theme.bg_focus, widgetBackgroundShape)
local memwidget = wibox.container.margin(membg, 0, 0, 5, 5)

-- Net

-- local function networkSpeedColor(speed)
--    if speed < 20 * 1024 then
--       return theme.fg_normal
--    elseif speed < 40 * 1024 then
--       return "#ff8000"
--    else
--       return "#B22222"
--    end
-- end -- of function


local function formatSpeed(input, max_speed)
   local speedNameList = {'KB', 'MB', 'GB'}
   local base = math.log(input, 1024)
   local numerical_speed = tonumber(input) -- unit is KB
   -- local color = networkSpeedColor(tonumber(input))
   local color = get_linear_gradient(numerical_speed / max_speed) -- 50 MB as maximum
   
   if numerical_speed < 1 then
      return markup(color, string.format("%6.1f KB", numerical_speed))
   else
      local tmp_ = math.floor(base)
      return markup(color,
                    string.format("%6.1f %s",
                                  math.pow(1024, base - tmp_),
                                  speedNameList[tmp_ + 1]))

   end
end -- of function

local net = lain.widget.net({
      settings = function()
         widget:set_markup(
            -- "  ⬇ " .. markup.font(theme.monofont, formatSpeed(net_now.received))
            --    .. " - ⬆ " .. markup.font(theme.monofont, formatSpeed(net_now.sent)) .. "  ")
            -- 122880 KB: 50 MB/s  10240 KB: 10MB/s
            space2 .. markup.font(theme.monofont, formatSpeed(net_now.received, 122880) .. " [D]" ) ..
            space2 .. markup.font(theme.monofont, formatSpeed(net_now.sent, 10240) .. " [U]") .. space2)
      end
})
local netbg = wibox.container.background(
   net.widget, theme.bg_focus, widgetBackgroundShape)
local networkwidget = wibox.container.margin(netbg, 0, 0, 5, 5)

-- Weather
local myweather = lain.widget.weather({
      APPID = 'b4f5e3c877b4def541f826770d8a4128',
      city_id = 4460162, -- Chapel Hill
      units = "metric",
      notification_preset = {
         font = theme.monofont,
         bg = theme.bg_normal,
      },
    settings = function()
       if weather_now["main"]["temp"] then
          units = math.floor(weather_now["main"]["temp"])
       else
          units = "N/A"
       end
       widget:set_markup(
          markup("#FFFFFF",
                 space3
                    .. markup.font(theme.font, units  .. " ℃")))
    end
})

local weatherwidget = wibox.widget{
   layout=wibox.layout.fixed.horizontal,
   space2Widget,
   myweather.icon,
   myweather.widget,
   space2Widget
}

local myWeatherWidget = wibox.container.margin(
   wibox.container.background(
      weatherwidget, theme.bg_focus, widgetBackgroundShape),
   0, 0, 5, 5)
myweather.attach(myWeatherWidget)

local myVolumeWidget = wibox.container.margin(
   wibox.container.background(
      volumeWidget{
         widget_type = 'text'
      }
      , theme.bg_focus, widgetBackgroundShape),
   0, 0, 5, 5)

function theme.at_screen_connect(s)
   
   -- Setup according to Geometry
   local defaultLayout
   
    if s.geometry.width / s.geometry.height > 1 then
        defaultLayout = awful.layout.suit.tile
    else
        defaultLayout = awful.layout.suit.tile.top
    end

   -- Quake application
   -- s.quake = lain.util.quake({ app = "xterm", height = 0.35 })
   
   -- Tags
   awful.tag(awful.util.tagnames, s, defaultLayout)
   
   -- Create a promptbox for each screen
   s.mypromptbox = awful.widget.prompt{
      prompt = " Run: ",
      bg = theme.bg_focus}
   s.mypromptboxcontainer = wibox.container.margin(
      wibox.container.background(
         s.mypromptbox, theme.bg_focus, widgetBackgroundShape),
      0, 0, 5, 5)

   -- Create an imagebox widget which will contains an icon indicating which layout we're using.
   -- We need one layoutbox per screen.
   s.mylayoutbox = awful.widget.layoutbox(s)
   s.mylayoutbox:buttons(
      awful.util.table.join(
         awful.button({ }, 1, function () awful.layout.inc( 1) end),
         awful.button({ }, 3, function () awful.layout.inc(-1) end),
         awful.button({ }, 4, function () awful.layout.inc( 1) end),
         awful.button({ }, 5, function () awful.layout.inc(-1) end)))

   mylayoutcont = wibox.container.background(
      -- s.mylayoutbox,
      wibox.widget{
         layout=wibox.layout.fixed.horizontal,
         space2Widget,
         s.mylayoutbox,
         space2Widget
      },
      theme.bg_focus, widgetBackgroundShape)
   s.mylayout = wibox.container.margin(mylayoutcont, 0, 0, 5, 5)

   -- Create a taglist widget
   local mytaglist = awful.widget.taglist(
      s, awful.widget.taglist.filter.all,
      awful.util.taglist_buttons)
   local mytaglistcont = wibox.container.background(
      wibox.widget{
         layout=wibox.layout.fixed.horizontal,
         space4Widget,
         mytaglist,
         space4Widget
      },
      theme.bg_focus, widgetBackgroundShape)
   s.mytag = wibox.container.margin(mytaglistcont, 0, 0, 5, 5)


   -- create wallpaper indicator
   s.wallText = wibox.widget.textbox(markup.font(theme.monofont, "  [0/0]  "))
   s.wallWidget = wibox.container.margin(
      wibox.container.background(s.wallText, theme.bg_focus, widgetBackgroundShape),
      0, 0, 5, 5)
   
   -- Create the indicator
   s.focuswidget = wibox.widget {
      checked       = (s == awful.screen.focused()),
      color         = my_green, --beautiful.bg_normal,
      paddings      = 2,
      shape         = gears.shape['circle'],
      widget        = wibox.widget.checkbox,
      --    visible       = (s == awful.screen.focused()),
   }
   s.myfocuswidget = wibox.container.margin(s.focuswidget, 0, 0, 5, 5)

   -- Create a tasklist widget
   s.mytasklist = awful.widget.tasklist({
         screen = s,
         filter = awful.widget.tasklist.filter.currenttags,
         buttons = awful.util.tasklist_buttons,
         update_function = function(w, buttons, label, data, objects, args)
            -- Use below function to add a post-hook
            local function new_label(c, tb)
               local text, bg, bg_image, icon, other_args = label(c, tb)
               local fcls = {}
               for _, c in ipairs(objects) do
                  if not (c.type == "desktop" or c.type == "dock" or c.type == "splash") then
                    if c:isvisible() and c.focusable then
                        table.insert(fcls, c)
                    end
                  end
               end
               local cidx = gtable.hasitem(fcls, c) or '#'
               local _, endIdx = string.find(text, '^<[^>]*>') 
               text = text:sub(1, endIdx) .. tostring(cidx) .. '-' .. text:sub(endIdx+1)
               return text, bg, bg_image, icon, other_args
            end
            awful.widget.common.list_update(w, buttons, new_label, data, objects, args)
         end,
         style = {
            bg_focus = theme.tasklist_bg_focus,
            fg_focus = theme.tasklist_fg_focus,
            shape = gears.shape.rounded_bar,
            shape_border_width = theme.tasklist_border_width,
            shape_border_color = theme.tasklist_border_color,
            align = "center"
         },
         layout = {
            spacing = 10,
            spacing_widget = {
               {
                  forced_width = 5,
                  shape        = gears.shape.circle,
                  widget       = wibox.widget.separator
               },
               valign = 'center',
               halign = 'center',
               widget = wibox.container.place,
            },
            layout  = wibox.layout.flex.horizontal
         }
   })

   -- Create the wibox
   s.mywibox = awful.wibar(
      { position = "top",
        screen = s,
        height = 32,
        bg     = theme.bg_normal})
   if s == screen.primary then
      local mysystray = wibox.widget.systray()
      -- TODO: not sure if this is needed
      local mysystraybg = wibox.container.background(
         wibox.widget{
            layout=wibox.layout.fixed.horizontal,
            space4Widget,
            mysystray,
            space4Widget
         },
         theme.bg_focus_bare, widgetBackgroundShape)
      local mysystraycontainer = wibox.container.margin(mysystraybg, 0, 0, 5, 5)
      
      mytoprightwibox = {
         layout = wibox.layout.fixed.horizontal,
         spacing_widget = bar,
         spacing = 10,
         mysystraycontainer,
         myVolumeWidget,
         -- VPN
         vpntextwidget,
         -- Net
         networkwidget,
         -- bat
         batwidget,
         -- cpu
         cpuwidget,
         -- mem
         memwidget,
         -- gpu
         gpuwidget,
         -- Volume
         -- volumewidget,
         -- weather
         myWeatherWidget,
         -- weathericonwidget,
         -- weathertextwidget,
         -- brightness
         mybrightnesswidget,
         -- cal
         calendarwidget,
         -- clock
         clockwidget,
         space2Widget
      }
   else
      mytoprightwibox = {
         layout = wibox.layout.fixed.horizontal,
         spacing_widget = bar,
         spacing = 10,
         clockwidget,
         space2Widget
      }
   end
   
   -- Add widgets to the wibox
   s.mywibox:setup {
      layout = wibox.layout.align.horizontal,
      { -- Left widgets
         layout = wibox.layout.fixed.horizontal,
         spacing_widget = bar,
         spacing = 10,
         s.myfocuswidget,
         -- spr_right,
         s.mytag,
         -- spr_small,
         -- s.mylayoutbox,
         s.mylayout,
         s.wallWidget,
         -- spr_small,
         s.mypromptboxcontainer,
      },
      nil, -- Center widgets
      mytoprightwibox,
   }
   
   -- Create the bottom wibox
   s.mybottomwibox = awful.wibar(
      {position = "bottom",
       screen = s,
       border_width = 0,
       height = 24,
       bg = theme.bg_normal})

   -- Add widgets to the bottom wibox
   s.mybottomwibox:setup {
      layout = wibox.layout.align.horizontal,
      nil,
      s.mytasklist, -- Middle widget
      nil -- Right widgets
   }
end

return theme

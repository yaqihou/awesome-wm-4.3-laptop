-- ===================================================================
-- vlc_focus.lua (Upgraded with Masking & Refresh)
-- ===================================================================

local awful = require("awful")
local naughty = require("naughty")

local vlc_focus = {}

-- State variables
local locked_tag = nil
local valid_pids = {} -- Table to act as a Set: { [pid] = true }

-- Helper: Rebuild the list of PIDs allowed to be controlled
local function rebuild_pid_mask()
    valid_pids = {} -- Clear current list
    
    if not locked_tag then return end

    -- Iterate over all clients specifically on the locked tag
    for _, c in ipairs(locked_tag:clients()) do
        if c.class and string.lower(c.class) == "vlc" then
            valid_pids[tostring(c.pid)] = true
        end
    end
end

-- Worker: Enforce audio exclusivity based on the mask
local function enforce_exclusivity(focused_pid)
    -- Run pactl in async mode
    awful.spawn.easy_async("pactl list sink-inputs", function(stdout)
        
        local current_id = nil
        
        for line in stdout:gmatch("[^\r\n]+") do
            -- 1. Get Sink Input ID
            local id_match = line:match("^Sink Input #(%d+)")
            if id_match then current_id = id_match end

            if current_id then
                -- 2. Get PID
                local pid_match = line:match('application%.process%.id = "(%d+)"')
                
                -- 3. Verify it's VLC and check against our MASK
                if pid_match and stdout:match("Sink Input #"..current_id..".-application%.name = \"[^\"]*[Vv][Ll][Cc][^\"]*\"") then
                    
                    -- CRITICAL CHECK: Is this PID in our allowed mask?
                    -- If no, it belongs to a VLC on another tag/screen -> IGNORE IT.
                    if valid_pids[pid_match] then
                        
                        -- Logic: Unmute if it matches focused PID, Mute otherwise
                        local state = (pid_match == tostring(focused_pid)) and "0" or "1"
                        awful.spawn("pactl set-sink-input-mute " .. current_id .. " " .. state, false)
                    end
                end
            end
        end
    end)
end

-- Public: Refresh the PID mask (Call this after moving/opening windows)
function vlc_focus.refresh()
    if not locked_tag then return end
    
    rebuild_pid_mask()
    
    -- Count the PIDs for user feedback
    local count = 0
    for _ in pairs(valid_pids) do count = count + 1 end
    
    naughty.notify({ 
        title = "VLC Focus", 
        text = "Refreshed: Tracking " .. count .. " instances.",
        timeout = 2
    })
    
    -- Re-apply logic immediately to the currently focused client
    if client.focus and valid_pids[tostring(client.focus.pid)] then
        enforce_exclusivity(client.focus.pid)
    end
end

-- Public: Toggle On/Off
function vlc_focus.toggle()
    local s = awful.screen.focused()
    local t = s.selected_tag

    if locked_tag == t then
        -- DISABLE
        locked_tag = nil
        valid_pids = {}
        naughty.notify({ title = "VLC Focus", text = "Disabled" })
    else
        -- ENABLE
        locked_tag = t
        rebuild_pid_mask() -- Build the initial mask
        
        -- Count valid instances
        local count = 0
        for _ in pairs(valid_pids) do count = count + 1 end

        naughty.notify({ 
            title = "VLC Focus", 
            text = "Enabled on tag '" .. t.name .. "'\nTracking " .. count .. " streams." 
        })
        
        -- Trigger immediately if we are already focused on a valid VLC
        if client.focus and valid_pids[tostring(client.focus.pid)] then
            enforce_exclusivity(client.focus.pid)
        end
    end
end

-- Signal Handler
client.connect_signal("focus", function(c)
    if not locked_tag then return end
    if c.first_tag ~= locked_tag then return end

    -- Only trigger if the focused client is actually one of our tracked VLCs
    if valid_pids and valid_pids[tostring(c.pid)] then
        enforce_exclusivity(c.pid)
    end
end)

return vlc_focus

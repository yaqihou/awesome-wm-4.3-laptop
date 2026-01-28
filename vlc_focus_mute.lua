-- ===================================================================
-- vlc_focus.lua (v5: High Performance Cache)
-- ===================================================================

local awful = require("awful")
local naughty = require("naughty")

local vlc_focus = {}

-- ===================================================================
-- STATE & CACHE
-- ===================================================================
local locked_tag = nil

-- 1. Valid PIDs (The "Allow List")
-- Contains: { ["12345"] = true } (Window PIDs + Child PIDs)
local valid_pids = {}

-- 2. PulseAudio Client Map
-- Contains: { ["Client_ID"] = "PID" }
-- Example: { ["77"] = "3148582" }
local pulse_client_map = {}

-- ===================================================================
-- HELPER FUNCTIONS
-- ===================================================================

-- Synchronously get child PIDs (Fast enough for a manual Refresh action)
local function get_process_family(parent_pid)
    local family = {[tostring(parent_pid)] = true}
    -- 'pgrep' is very lightweight
    local handle = io.popen("pgrep -P " .. parent_pid)
    if handle then
        for line in handle:read("*a"):gmatch("%d+") do
            family[line] = true
        end
        handle:close()
    end
    return family
end

-- ===================================================================
-- CORE LOGIC
-- ===================================================================

-- PHASE 1: Heavy Lifting (Run only on Toggle / Refresh)
local function rebuild_cache()
    if not locked_tag then return end

    -- A. Rebuild Valid PIDs (Window Analysis)
    valid_pids = {}
    for _, c in ipairs(locked_tag:clients()) do
        if c.pid then
            -- Add Parent
            valid_pids[tostring(c.pid)] = true
            -- Add Children (for MPV/Browsers)
            local children = get_process_family(c.pid)
            for child_pid, _ in pairs(children) do
                valid_pids[child_pid] = true
            end
        end
    end

    -- B. Rebuild Client Map (PulseAudio Analysis)
    pulse_client_map = {}
    
    -- We run this async so the UI doesn't stutter during refresh
    awful.spawn.easy_async("pactl list clients", function(stdout)
        local current_client_id = nil
        
        for line in stdout:gmatch("[^\r\n]+") do
            -- Capture Client ID
            local id_match = line:match("^Client #(%d+)")
            if id_match then current_client_id = id_match end
            
            -- Capture PID associated with that Client
            if current_client_id then
                local pid = line:match('application%.process%.id = "(%d+)"')
                if pid then
                    pulse_client_map[current_client_id] = pid
                end
            end
        end
        
        -- Optional: Debug notification to confirm cache is ready
        local count = 0
        for _ in pairs(pulse_client_map) do count = count + 1 end
        naughty.notify({ text = "Cache Ready: " .. count .. " Pulse Clients" })
    end)
end

-- PHASE 2: Fast Path (Run on Focus Change)
local function enforce_exclusivity(focused_c)
    -- 1. Identify the "Focused Family" (Parent + Children of focused window)
    -- We calculate this on the fly because it's cheap and changes instantly
    local focus_family = get_process_family(focused_c.pid)

    -- 2. Fetch ONLY sink-inputs (Lighter query)
    awful.spawn.easy_async("pactl list sink-inputs", function(stdout)
        
        local current_sink_id = nil
        
        for line in stdout:gmatch("[^\r\n]+") do
            -- Capture Sink ID
            local id_match = line:match("^Sink Input #(%d+)")
            if id_match then current_sink_id = id_match end
            
            if current_sink_id then
                local stream_pid = nil
                
                -- Strategy A: Direct PID (Perfect world)
                local raw_pid = line:match('application%.process%.id = "(%d+)"')
                if raw_pid then 
                    stream_pid = raw_pid 
                end

                -- Strategy B: Resolve via Cached Client Map (Your fix)
                if not stream_pid then
                    local client_id = line:match("Client: (%d+)")
                    if client_id and pulse_client_map[client_id] then
                        stream_pid = pulse_client_map[client_id]
                    end
                end

                -- DECISION TIME
                if stream_pid then
                    -- 1. Is this stream allowed to play at all? (On our Tag)
                    if valid_pids[stream_pid] then
                        
                        -- 2. Should it be unmuted? (Is it the focused window?)
                        local should_play = focus_family[stream_pid]
                        local state = should_play and "0" or "1"
                        
                        awful.spawn("pactl set-sink-input-mute " .. current_sink_id .. " " .. state, false)
                    end
                end
            end
        end
    end)
end

function vlc_focus.refresh()
    if not locked_tag then return end
    rebuild_cache()
    
    local count = 0
    for _ in pairs(valid_pids) do count = count + 1 end
    naughty.notify({ title = "Focus Widget", text = "Refreshed: " .. count .. " PIDs tracked." })
    
    if client.focus then enforce_exclusivity(client.focus) end
end

function vlc_focus.toggle()
    local s = awful.screen.focused()
    local t = s.selected_tag

    if locked_tag == t then
        locked_tag = nil
        pulse_client_map = {}
        valid_pids = {}
        naughty.notify({ title = "Focus Widget", text = "Disabled" })
    else
        locked_tag = t
        rebuild_cache() -- Asynchronously builds the map
        naughty.notify({ title = "Focus Widget", text = "Enabled on: " .. t.name })
    end
end

-- Signal Handler
client.connect_signal("focus", function(c)
    if not locked_tag then return end
    if c.first_tag ~= locked_tag then return end
    enforce_exclusivity(c)
end)

return vlc_focus

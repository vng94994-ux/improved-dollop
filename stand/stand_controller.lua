-- stand_controller (REMOTE-ONLY, loadstring-safe)

local env = getgenv()
env.Script = "Moon Stand"
env.Owner = env.Owner or "USERNAME" -- CHANGE THIS
env.Guns = env.Guns or { "rifle", "aug" }
env.FPSCap = env.FPSCap or 60

-- GitHub base
local BASE = "https://raw.githubusercontent.com/vng94994-ux/improved-dollop/main/stand/core/"

local function http(src)
    return game:HttpGet(src, true)
end

-- Load init.lua (it will load everything else)
local INIT_SRC = http(BASE .. "init.lua")

local ok, err = pcall(function()
    loadstring(INIT_SRC)()
end)

if not ok then
    warn("[stand] failed to load core:", err)
else
    print("[stand] core loaded for", env.Owner)
end

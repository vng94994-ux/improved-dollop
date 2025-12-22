local env = getgenv()
env.Script = env.Script or "Moon Stand"
env.Owner = env.Owner or "USERNAME"
env.DisableRendering = env.DisableRendering or false
env.BlackScreen = env.BlackScreen or false
env.FPSCap = env.FPSCap or 60
env.Guns = env.Guns or { "rifle", "aug" }

-- Set this to the base URL that hosts /core/*.lua files.
-- Default points to the same repo layout used previously.
env.ModuleBaseUrl = env.ModuleBaseUrl or "https://raw.githubusercontent.com/vng94994-ux/improved-dollop/main/stand/core/"

local function fetchModule(name)
    local url = tostring(env.ModuleBaseUrl or "") .. tostring(name)
    local ok, content = pcall(game.HttpGet, game, url)
    if not ok then
        error("[stand] Failed to fetch " .. name .. " from " .. url .. ": " .. tostring(content))
    end
    return content
end

local function loadModule(name, cache)
    if cache[name] then return cache[name] end
    local src = fetchModule(name)
    local fn, err = loadstring(src, name)
    if not fn then
        error("[stand] Failed to compile " .. name .. ": " .. tostring(err))
    end
    local mod = fn()
    cache[name] = mod
    return mod
end

local modules = {}
local State = loadModule("state.lua", modules)
local Connections = loadModule("connections.lua", modules)
local Aiming = loadModule("aiming.lua", modules)
local Shopping = loadModule("shopping.lua", modules)
local Combat = loadModule("combat.lua", modules)
local Commands = loadModule("commands.lua", modules)
local init = loadModule("init.lua", modules)

-- Wire dependencies explicitly for executor context
init({
    State = State,
    Connections = Connections,
    Aiming = Aiming,
    Shopping = Shopping,
    Combat = Combat,
    Commands = Commands,
})

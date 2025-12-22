local env = getgenv()
env.Script = env.Script or "Moon Stand"
env.Owner = env.Owner or "USERNAME"
env.DisableRendering = env.DisableRendering or false
env.BlackScreen = env.BlackScreen or false
env.FPSCap = env.FPSCap or 60
env.Guns = env.Guns or { "rifle", "aug" }

-- Optional remote core loading (disabled unless UseRemoteCore=true)
env.UseRemoteCore = env.UseRemoteCore == true
env.RemoteCoreUrl = env.RemoteCoreUrl or nil
env.RemoteCoreSha = env.RemoteCoreSha or nil -- hex SHA-256 of expected content

local function sha256(str)
    if crypt and crypt.sha256 then
        return crypt.sha256(str)
    end
    return nil
end

local function load_local()
    local ok, mod = pcall(loadfile, "core/init.lua")
    if not ok then
        error("[stand] Failed to load local core: " .. tostring(mod))
    end
    return mod
end

local function load_remote(url, expectedSha)
    if not env.UseRemoteCore or not url then
        return nil, "remote disabled"
    end
    local ok, content = pcall(game.HttpGet, game, url)
    if not ok then
        return nil, "http get failed: " .. tostring(content)
    end
    if expectedSha and sha256 then
        local got = sha256(content)
        if not got or string.lower(got) ~= string.lower(expectedSha) then
            return nil, ("hash mismatch expected %s got %s"):format(expectedSha, got or "nil")
        end
    end
    local ok2, mod = pcall(loadstring, content)
    if not ok2 then
        return nil, "compile error: " .. tostring(mod)
    end
    return mod
end

local core = nil
do
    local remote, err = load_remote(env.RemoteCoreUrl, env.RemoteCoreSha)
    if remote then
        core = remote
    else
        warn("[stand] remote load skipped: " .. tostring(err))
        core = load_local()
    end
end
core()

local Players = game:GetService("Players")

local function normalize(s) return string.lower((s or ""):gsub("%W", "")) end

local gunAliases = {
    rifle = { "rifle", "ar" },
    aug = { "aug" },
    flintlock = { "flint", "flintlock", "flint" },
    db = { "db", "doublebarrel", "doublebarrelsg" },
    lmg = { "lmg" },
}

local State = {}
State.__index = State

function State.new(env)
    local owner = tostring(env.Owner or "")
    local allowedCanon, allowedLookup = {}, {}
    for _, g in ipairs(env.Guns or {}) do
        local canon = normalize(g)
        for canonKey, aliases in pairs(gunAliases) do
            for _, a in ipairs(aliases) do
                if normalize(a) == canon then
                    canon = canonKey
                end
            end
        end
        allowedCanon[canon] = true
        for _, a in ipairs(gunAliases[canon] or { canon }) do
            allowedLookup[normalize(a)] = canon
        end
    end

    local self = setmetatable({
        owner = owner,
        whitelist = { [normalize(owner)] = true },
        auraWhitelist = {},
        assistTargets = {},
        allowedCanon = allowedCanon,
        allowedLookup = allowedLookup,
        modes = { movement = "idle", combat = "idle" },
        flags = {
            voided = true,
            maskEnabled = false,
            inCombat = false,
            abortCombat = false,
            loopkillTarget = nil,
            loopknockTarget = nil,
            aura = false,
            akill = false,
            sentry = false,
            bsentry = false,
            lockMovement = false,
        },
        timers = {},
        lastPositions = {},
        playable = false,
        isPlayable = function() return false end, -- replaced in init
    }, State)
    return self
end

function State:getCanonicalGun(name)
    return self.allowedLookup[normalize(name)]
end

function State:isOwner(name)
    return normalize(name) == normalize(self.owner)
end

function State:isWhitelisted(name)
    return self.whitelist[normalize(name or "")] == true
end

function State:setWhitelist(name, val)
    if not name then return end
    if val then
        self.whitelist[normalize(name)] = true
    else
        self.whitelist[normalize(name)] = nil
    end
end

function State:setAuraWhitelist(name, val)
    if not name then return end
    if val then
        self.auraWhitelist[normalize(name)] = true
    else
        self.auraWhitelist[normalize(name)] = nil
    end
end

function State:setAssistTarget(plr, val)
    if not plr then return end
    if val then
        self.assistTargets[normalize(plr.Name)] = plr
    else
        self.assistTargets[normalize(plr.Name)] = nil
    end
end

local movementConflicts = { follow = true, stay = true, void = true, summon = true, idle = true }
local combatConflicts = {
    combat = true, loopkill = true, loopknock = true, akill = true,
    aura = true, sentry = true, bsentry = true, idle = true,
}

function State:setMovementMode(mode)
    if not mode or not movementConflicts[mode] then
        self.modes.movement = "idle"
    else
        self.modes.movement = mode
    end
end

function State:setCombatMode(mode)
    if not mode or not combatConflicts[mode] then
        self.modes.combat = "idle"
    else
        self.modes.combat = mode
    end
end

function State:resetModes()
    self:setMovementMode("idle")
    self:setCombatMode("idle")
end

return State

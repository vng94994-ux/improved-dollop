local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Stats = game:GetService("Stats")

local Combat = {}
Combat.__index = Combat

local function canPatchRapid()
    return getconnections and debug and debug.getupvalues and debug.setupvalue
end

local function applyRapidFire(tool)
    if not canPatchRapid() or not tool then return end
    pcall(function()
        for _, conn in ipairs(getconnections(tool.Activated)) do
            local fn = conn.Function
            if fn then
                for idx, val in ipairs(debug.getupvalues(fn)) do
                    if type(val) == "number" and val > 0.03 and val < 5 then
                        debug.setupvalue(fn, idx, math.max(0.03, val * 0.35))
                    end
                end
            end
        end
    end)
end

local function getPingSeconds()
    local value
    pcall(function()
        local perf = Stats.PerformanceStats:FindFirstChild("Ping")
        if perf and perf.GetValue then value = perf:GetValue() end
        if not value then
            local dataPing = Stats.Network.ServerStatsItem["Data Ping"]
            if dataPing and dataPing.GetValue then value = dataPing:GetValue() end
        end
    end)
    return (value or 50) / 1000
end

local function getChar(plr) return plr and plr.Character end
local function getHum(plr) return getChar(plr) and getChar(plr):FindFirstChildOfClass("Humanoid") end
local function getRoot(plr) return getChar(plr) and getChar(plr):FindFirstChild("HumanoidRootPart") end

local function isKO(plr)
    local h = getHum(plr)
    return h and h.Health <= 0.1
end

local function normalize(s) return string.lower((s or ""):gsub("%W", "")) end

function Combat.new(state, aiming, shopping, connections)
    local self = setmetatable({
        state = state,
        aiming = aiming,
        shopping = shopping,
        connections = connections,
        timers = { aura = 0, void = 0, sentry = 0, assist = 0 },
        loopConns = {},
    }, Combat)
    return self
end

function Combat:toolMatchesAllowed(tool)
    if not tool or not tool:IsA("Tool") then return nil end
    return self.state:getCanonicalGun(tool.Name)
end

function Combat:getAllowedTools()
    local lp = Players.LocalPlayer
    local char = getChar(lp)
    if not char then return {} end
    local tools = {}
    for _, t in ipairs(char:GetChildren()) do
        local canon = self:toolMatchesAllowed(t)
        if canon then table.insert(tools, { tool = t, canon = canon }) end
    end
    return tools
end

function Combat:hasAnyAllowedGun()
    local lp = Players.LocalPlayer
    local char, bp = getChar(lp), lp:FindFirstChild("Backpack")
    for _, parent in ipairs({ char, bp }) do
        if parent then
            for _, t in ipairs(parent:GetChildren()) do
                if self:toolMatchesAllowed(t) then
                    return true
                end
            end
        end
    end
    return false
end

function Combat:equipAnyAllowed(allowPurchase)
    local lp = Players.LocalPlayer
    local char = getChar(lp)
    local bp = lp:FindFirstChild("Backpack")
    if not char then return nil end
    for _, parent in ipairs({ char, bp }) do
        if parent then
            for _, t in ipairs(parent:GetChildren()) do
                local canon = self:toolMatchesAllowed(t)
                if canon then
                    t.Parent = char
                    return t, canon
                end
            end
        end
    end
    if allowPurchase then
        for canon, allowed in pairs(self.state.allowedCanon) do
            if allowed then
                self.shopping:buyGun(canon)
            end
        end
    end
    return nil
end

local function ensureAmmoValue(tool)
    if not tool then return nil end
    for _, name in ipairs({ "Ammo", "AmmoCount", "Clip", "AmmoInGun" }) do
        local v = tool:FindFirstChild(name)
        if v and typeof(v.Value) == "number" then return v end
    end
    return nil
end

function Combat:ensureAmmo(tool, canon, combatStarted, minWindow)
    if not tool then return tool, canon end
    local ammoValue = ensureAmmoValue(tool)
    if not ammoValue then return tool, canon end
    if ammoValue.Value > 2 then return tool, canon end

    -- reload attempt
    pcall(function()
        if tool:FindFirstChild("Reload") and tool.Reload:IsA("RemoteEvent") then
            tool.Reload:FireServer()
        end
    end)
    task.wait(0.08)
    if ammoValue.Value > 2 then return tool, canon end

    local elapsed = combatStarted and (tick() - combatStarted) or math.huge
    local threshold = minWindow or 0.75
    if elapsed < threshold then return tool, canon end

    self.shopping:buyAmmo(canon)
    for _ = 1, 6 do
        local refreshed = self:equipAnyAllowed(false)
        if refreshed then
            tool = refreshed
            break
        end
        task.wait(0.08)
    end
    return tool, canon
end

function Combat:stopAllModes()
    self.state.flags.abortCombat = true
    self.state.flags.inCombat = false
    self.state.flags.loopkillTarget = nil
    self.state.flags.loopknockTarget = nil
    self.state.flags.aura = false
    self.state.flags.akill = false
    self.state.flags.sentry = false
    self.state.flags.bsentry = false
    self.state:setCombatMode("idle")
    self.state:setMovementMode(self.state.modes.movement == "void" and "void" or "idle")
    self.aiming:stop()
end

function Combat:shootTarget(target, opts)
    if not target then return end
    if not self.state.isPlayable() then return end

    local lp = Players.LocalPlayer
    local char = getChar(lp)
    local root = getRoot(lp)
    if not char or not root then return end

    local combatStarted = tick()
    self.state.flags.abortCombat = false
    self.state.flags.inCombat = true
    local tools = self:getAllowedTools()
    if #tools == 0 then
        local gun, canon = self:equipAnyAllowed(true)
        if gun then tools = { { tool = gun, canon = canon } } end
    end
    if #tools == 0 then
        self.state.flags.inCombat = false
        return
    end

    for _, entry in ipairs(tools) do
        applyRapidFire(entry.tool)
    end

    self.aiming:startSilent(target)
    local deadline = combatStarted + (opts and opts.deadline or 18)

    while root and target and target.Character and not isKO(target) and not self.state.flags.abortCombat and
        self.state.isPlayable() and tick() < deadline do

        local troot = getRoot(target)
        if not troot then break end

        root.CFrame = troot.CFrame * CFrame.new(0, 0, -2)
        for idx = #tools, 1, -1 do
            local entry = tools[idx]
            if not entry.tool or entry.tool.Parent ~= char then
                table.remove(tools, idx)
            end
        end

        for _, entry in ipairs(tools) do
            entry.tool, entry.canon = self:ensureAmmo(entry.tool, entry.canon, combatStarted, 0.9)
        end

        if #tools == 0 then
            local gun, canon = self:equipAnyAllowed(false)
            if gun then
                tools = { { tool = gun, canon = canon } }
                applyRapidFire(gun)
            else
                break
            end
        end

        for _, entry in ipairs(tools) do
            if entry.tool.Parent ~= char then
                entry.tool.Parent = char
            end
            applyRapidFire(entry.tool)
            pcall(function() entry.tool:Activate() end)
            task.wait(0.008)
        end

        RunService.Heartbeat:Wait()
        char = getChar(lp)
        root = getRoot(lp)
    end

    self.aiming:stop()
    self.state.flags.inCombat = false
    self.state.flags.abortCombat = false
end

function Combat:knock(target)
    if not target then return end
    self.state:setCombatMode("combat")
    self:shootTarget(target)
end

function Combat:kill(target)
    if not target then return end
    self.state:setCombatMode("combat")
    self:shootTarget(target)
    if isKO(target) then
        for _ = 1, 6 do
            local main = ReplicatedStorage:FindFirstChild("MainEvent")
            if main then main:FireServer("Stomp") end
            task.wait(0.12)
        end
    end
end

function Combat:bring(target)
    if not target then return end
    local root = getRoot(Players.LocalPlayer)
    local troot = getRoot(target)
    if root and troot then
        troot.CFrame = root.CFrame * CFrame.new(0, 0, -2)
    end
end

function Combat:sky(target)
    if not target then return end
    local troot = getRoot(target)
    if troot then
        troot.Velocity = Vector3.new(0, 200, 0)
    end
end

function Combat:fling(target)
    if not target then return end
    local troot = getRoot(target)
    if troot then
        troot.Velocity = Vector3.new(500, 500, 500)
    end
end

function Combat:setLoopKill(target)
    self.state:setCombatMode("loopkill")
    self.state.flags.loopkillTarget = target
end

function Combat:setLoopKnock(target)
    self.state:setCombatMode("loopknock")
    self.state.flags.loopknockTarget = target
end

function Combat:setAkill(on)
    self.state.flags.akill = on
    self.state:setCombatMode(on and "akill" or "idle")
end

function Combat:setAura(on)
    self.state.flags.aura = on
    self.state:setCombatMode(on and "aura" or "idle")
end

function Combat:setSentry(on, brute)
    self.state.flags.sentry = on
    self.state.flags.bsentry = brute or false
    self.state:setCombatMode(on and (brute and "bsentry" or "sentry") or "idle")
end

function Combat:onHeartbeat()
    if not self.state.isPlayable() then return end
    local now = tick()

    -- movement: follow/void/stay
    local lp = Players.LocalPlayer
    local char = getChar(lp)
    local root = getRoot(lp)
    if self.state.modes.movement == "follow" then
        local owner = Players:FindFirstChild(self.state.owner)
        local oroot = getRoot(owner)
        if root and oroot then
            root.CFrame = root.CFrame:Lerp(oroot.CFrame * CFrame.new(0, 1.5, 5), 0.35)
        end
    elseif self.state.modes.movement == "stay" then
        local owner = Players:FindFirstChild(self.state.owner)
        local oroot = getRoot(owner)
        if root and oroot then
            root.CFrame = oroot.CFrame * CFrame.new(0, 1.5, 5)
        end
    elseif self.state.modes.movement == "void" then
        if now - (self.timers.void or 0) > 0.35 then
            self.timers.void = now
            if root then
                root.CFrame = CFrame.new(
                    math.random(-500000, 500000),
                    math.random(10000, 30000),
                    math.random(-500000, 500000)
                )
            end
        end
    end

    -- loopkill/loopknock
    if self.state.modes.combat == "loopkill" and self.state.flags.loopkillTarget then
        local tgt = self.state.flags.loopkillTarget
        if isKO(tgt) then
            self:kill(tgt)
            self.state.flags.loopkillTarget = nil
            self.state:setCombatMode("idle")
        else
            self:kill(tgt)
        end
    elseif self.state.modes.combat == "loopknock" and self.state.flags.loopknockTarget then
        local tgt = self.state.flags.loopknockTarget
        if isKO(tgt) then
            self.state.flags.loopknockTarget = nil
            self.state:setCombatMode("idle")
        else
            self:knock(tgt)
        end
    end

    -- aura
    if self.state.modes.combat == "aura" and self.state.flags.aura then
        if now - (self.timers.aura or 0) > 0.25 then
            self.timers.aura = now
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= lp and not isKO(plr) and not self.state:isWhitelisted(plr.Name) and not self.state.auraWhitelist[normalize(plr.Name)] then
                    self:kill(plr)
                end
            end
        end
    end

    -- akill
    if self.state.modes.combat == "akill" and self.state.flags.akill then
        local target, part = self.aiming:getClosestToCursor()
        if target and part then
            self:kill(target)
        end
    end

    -- sentry / bsentry
    if (self.state.modes.combat == "sentry" or self.state.modes.combat == "bsentry") and now - (self.timers.sentry or 0) > 0.35 then
        self.timers.sentry = now
        local nearest, ndist = nil, math.huge
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= lp and not isKO(plr) and not self.state:isWhitelisted(plr.Name) then
                local troot = getRoot(plr)
                if troot and root then
                    local dist = (troot.Position - root.Position).Magnitude
                    if dist < ndist then
                        ndist = dist
                        nearest = plr
                    end
                end
            end
        end
        if nearest and ndist < 120 then
            if self.state.modes.combat == "bsentry" then
                self:kill(nearest)
            else
                self:knock(nearest)
            end
        end
    end

    -- assist: help targets by killing nearest threat to them
    if now - (self.timers.assist or 0) > 0.6 then
        self.timers.assist = now
        for _, target in pairs(self.state.assistTargets) do
            if target and target.Parent then
                local threat, tdist = nil, 45
                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr ~= lp and plr ~= target and not self.state:isWhitelisted(plr.Name) and not isKO(plr) then
                        local r1, r2 = getRoot(plr), getRoot(target)
                        if r1 and r2 then
                            local dist = (r1.Position - r2.Position).Magnitude
                            if dist < tdist then
                                tdist = dist
                                threat = plr
                            end
                        end
                    end
                end
                if threat then
                    self:kill(threat)
                end
            end
        end
    end
end

function Combat:startup() end

return Combat

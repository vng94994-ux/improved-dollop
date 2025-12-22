local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Commands = {}
Commands.__index = Commands

local function normalize(s) return string.lower((s or ""):gsub("%W", "")) end

local locations = {
    rifle = CFrame.new(-591.824158, 5.46046877, -744.731628),
    armor = CFrame.new(528, 50, -637),
    mil = CFrame.new(-1039.59985, 18.8513641, -256.449951),
}

function Commands.new(state, aiming, combat, shopping, connections)
    local self = setmetatable({
        state = state,
        aiming = aiming,
        combat = combat,
        shopping = shopping,
        connections = connections,
        registry = {},
        cooldowns = {},
        minCooldown = 0.25,
    }, Commands)

    local function isAllowed(name)
        return state:isOwner(name) or state:isWhitelisted(name)
    end

    local function resolve(name)
        if not name then return nil end
        local lower = string.lower(name)
        for _, plr in ipairs(Players:GetPlayers()) do
            if string.lower(plr.Name) == lower or string.lower(plr.DisplayName) == lower then
                return plr
            end
        end
        for _, plr in ipairs(Players:GetPlayers()) do
            if string.find(string.lower(plr.Name), lower, 1, true) or string.find(string.lower(plr.DisplayName), lower, 1, true) then
                return plr
            end
        end
        return nil
    end
    self.resolve = resolve
    self.isAllowed = isAllowed

    local function stopAll(full)
        combat:stopAllModes()
        shopping:stopBuying()
        aiming:stop()
        if full then
            state:setMovementMode("idle")
            state.flags.voided = false
            state:setCombatMode("idle")
            state.flags.inCombat = false
            state.flags.abortCombat = false
            state.flags.loopkillTarget = nil
            state.flags.loopknockTarget = nil
            state.flags.aura = false
            state.flags.akill = false
            state.flags.sentry = false
            state.flags.bsentry = false
            local cam = workspace.CurrentCamera
            local lp = Players.LocalPlayer
            local char = lp and lp.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if cam and hum then
                cam.CameraSubject = hum
                cam.CameraType = Enum.CameraType.Custom
            end
        end
    end

    self:register("panic", function()
        stopAll(true)
    end)

    self:register("status", function()
        local modes = ("movement=%s combat=%s"):format(state.modes.movement, state.modes.combat)
        print("[stand] status: " .. modes)
    end)

    self:register("help", function()
        print("[stand] commands: .summon .stay .v .repair .rejoin .mask on/off .say <msg> .d <plr> .l <plr> .lk <plr> .akill on/off .a on/off .awl <name> .unawl <name> .wl <name> .unwl <name> .b <plr> .sky <plr> .fling <plr> .tp <rifle|armor|mil> .t <plr1> <plr2> .sentry on/off .bsentry on/off .assist <plr> .unassist <plr> .status .panic")
    end)

    self:register("summon", function()
        state:setMovementMode("follow")
        state.flags.voided = false
    end)

    self:register("stay", function()
        state:setMovementMode("stay")
        state.flags.voided = false
    end)

    self:register("s", function(args)
        local target = resolve(args[1])
        if target then
            state:setCombatMode("combat")
            combat:kill(target)
        end
    end)

    self:register("v", function()
        state:setMovementMode("void")
        state.flags.voided = true
        combat:stopAllModes()
    end)

    self:register("repair", function()
        stopAll()
        state.flags.loopkillTarget = nil
        state.flags.loopknockTarget = nil
        state.flags.aura = false
        state.flags.akill = false
    end)

    self:register("rejoin", function()
        TeleportService:Teleport(game.PlaceId)
    end)

    self:register("mask", function(args)
        if args[1] and args[1]:lower() == "on" then
            state.flags.maskEnabled = true
            shopping:buyMask()
        else
            state.flags.maskEnabled = false
        end
    end)

    self:register("say", function(args)
        local message = table.concat(args, " ")
        if #message > 0 then
            local evt = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
            evt = evt and evt:FindFirstChild("SayMessageRequest")
            if evt then
                evt:FireServer(message, "All")
            end
        end
    end)

    self:register("d", function(args)
        local target = resolve(args[1])
        if target then
            combat:knock(target)
        end
    end)

    self:register("l", function(args)
        local target = resolve(args[1])
        if target then
            combat:setLoopKill(target)
        end
    end)

    self:register("lk", function(args)
        local target = resolve(args[1])
        if target then
            combat:setLoopKnock(target)
        end
    end)

    self:register("akill", function(args)
        local on = args[1] and args[1]:lower() == "on"
        combat:setAkill(on)
    end)

    self:register("a", function(args)
        local on = args[1] and args[1]:lower() == "on"
        combat:setAura(on)
    end)

    self:register("awl", function(args)
        if args[1] then state:setAuraWhitelist(args[1], true) end
    end)

    self:register("unawl", function(args)
        if args[1] then state:setAuraWhitelist(args[1], false) end
    end)

    self:register("wl", function(args)
        if args[1] then state:setWhitelist(args[1], true) end
    end)

    self:register("unwl", function(args)
        if args[1] then state:setWhitelist(args[1], false) end
    end)

    self:register("b", function(args)
        local target = resolve(args[1])
        if target then combat:bring(target) end
    end)

    self:register("sky", function(args)
        local target = resolve(args[1])
        if target then combat:sky(target) end
    end)

    self:register("fling", function(args)
        local target = resolve(args[1])
        if target then combat:fling(target) end
    end)

    self:register("tp", function(args)
        local loc = args[1] and locations[string.lower(args[1])]
        local root = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if loc and root then root.CFrame = loc end
    end)

    self:register("t", function(args)
        local p1 = resolve(args[1] or "")
        local p2 = resolve(args[2] or "")
        if p1 and p2 then
            local r1 = p1.Character and p1.Character:FindFirstChild("HumanoidRootPart")
            local r2 = p2.Character and p2.Character:FindFirstChild("HumanoidRootPart")
            if r1 and r2 then
                r1.CFrame = r2.CFrame + Vector3.new(0, 2, 0)
            end
        end
    end)

    self:register("sentry", function(args)
        local on = args[1] and args[1]:lower() == "on"
        combat:setSentry(on, false)
    end)

    self:register("bsentry", function(args)
        local on = args[1] and args[1]:lower() == "on"
        combat:setSentry(on, true)
    end)

    self:register("assist", function(args)
        local target = resolve(args[1] or "")
        if target then state:setAssistTarget(target, true) end
    end)

    self:register("unassist", function(args)
        local target = resolve(args[1] or "")
        if target then state:setAssistTarget(target, false) end
    end)

    return self
end

function Commands:register(name, fn)
    self.registry[string.lower(name)] = fn
end

function Commands:hookChat()
    local function exec(cmd, parts)
        local last = self.cooldowns[cmd] or 0
        if tick() - last < self.minCooldown then return end
        self.cooldowns[cmd] = tick()
        local fn = self.registry[cmd]
        if fn then
            local ok, err = pcall(fn, parts)
            if not ok then warn("[stand] command error: " .. tostring(err)) end
        end
    end

    local function hook(plr)
        if not plr then return end
        if not self.isAllowed(plr.Name) then return end
        local conn = plr.Chatted:Connect(function(msg)
            if type(msg) ~= "string" or msg:sub(1, 1) ~= "." then return end
            if not self.isAllowed(plr.Name) then return end
            local parts = {}
            for word in msg:gmatch("%S+") do table.insert(parts, word) end
            local cmd = parts[1]:sub(1, 1) == "." and parts[1]:sub(2):lower() or ""
            table.remove(parts, 1)
            exec(cmd, parts)
        end)
        table.insert(self.connections.list, conn)
    end

    hook(Players:FindFirstChild(self.state.owner))
    table.insert(self.connections.list, Players.PlayerAdded:Connect(function(plr)
        if self.isAllowed(plr.Name) then hook(plr) end
    end))
end

return Commands

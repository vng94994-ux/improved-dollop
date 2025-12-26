local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- dependencies are injected by the loader: deps.State, deps.Connections, etc.
return function(deps)
    local State = deps.State
    local Connections = deps.Connections
    local Aiming = deps.Aiming
    local Shopping = deps.Shopping
    local Combat = deps.Combat
    local Commands = deps.Commands
    local Desync = deps.Desync

    local env = getgenv()
    local state = State.new(env)
    local connections = Connections.new()
    local aiming = Aiming.new(state, connections)
    local shopping = Shopping.new(state, connections)
    local combat = Combat.new(state, aiming, shopping, connections)
    local commands = Commands.new(state, aiming, combat, shopping, connections)
    local desync = Desync.new(state, connections)

    local function isPlayable()
        local lp = Players.LocalPlayer
        local char = lp and lp.Character
        if not char or char ~= lp.Character then return false end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 or hum:GetState() == Enum.HumanoidStateType.Dead then return false end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then return false end
        return true
    end
    state.isPlayable = isPlayable
    state.playable = isPlayable()

    local function onDeath()
        combat:stopAllModes()
        aiming:stop()
        shopping:stopBuying()
        state.playable = false
        state.flags.inCombat = false
        state.flags.abortCombat = true
    end

    local function bindCharacter(char)
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        connections:connect(hum.Died, onDeath)
        connections:connect(hum:GetPropertyChangedSignal("Health"), function()
            if hum.Health <= 0 then onDeath() end
        end)
    end

    if Players.LocalPlayer.Character then
        bindCharacter(Players.LocalPlayer.Character)
    end
    connections:connect(Players.LocalPlayer.CharacterAdded, function(char)
        bindCharacter(char)
        task.wait(0.2)
        if state.flags.maskEnabled then shopping:buyMask() end
        shopping:buyGun(env.Guns and env.Guns[1] and state:getCanonicalGun(env.Guns[1]) or "rifle")
    end)

    commands:hookChat()
    aiming:startup()
    shopping:startup()
    combat:startup()
    desync:startup()

    connections:connect(RunService.Heartbeat, function()
        local playable = state.isPlayable()
        state.playable = playable
        if not playable then
            combat:stopAllModes()
            aiming:stop()
            return
        end
        aiming:onHeartbeat(playable)
        combat:onHeartbeat(playable)
    end)

    print("[stand] ready for commands from " .. tostring(state.owner))
end

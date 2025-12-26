local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local StandDesync = {}
StandDesync.__index = StandDesync

local function clampVec(vec, maxMag)
    if vec.Magnitude > maxMag then
        return vec.Unit * maxMag
    end
    return vec
end

function StandDesync.new(state, connections)
    local self = setmetatable({
        state = state,
        connections = connections,
        root = nil,
        rand = Random.new(),
        offset = Vector3.new(),
        rotationJitter = Vector3.new(),
        appliedOffset = Vector3.new(),
        appliedRotation = Vector3.new(),
    }, StandDesync)
    return self
end

function StandDesync:trackCharacter(char)
    self.root = nil
    if not char then return end
    local found = char:FindFirstChild("HumanoidRootPart")
    if found then
        self.root = found
        return
    end
    self.connections:addTask(task.spawn(function()
        local root = char:WaitForChild("HumanoidRootPart", 2)
        if root then
            self.root = root
        end
    end))
end

function StandDesync:getRoot()
    local lp = Players.LocalPlayer
    local char = lp and lp.Character
    if not char then
        self.root = nil
        return nil
    end
    if self.root and self.root.Parent == char then
        return self.root
    end
    self:trackCharacter(char)
    return self.root
end

function StandDesync:applyJitter(dt)
    if not self.state.playable then return end
    local root = self:getRoot()
    if not root then return end

    local r = self.rand

    -- drift a small local-only positional offset that remains near the real server position
    local tiny = Vector3.new(
        r:NextNumber(-0.08, 0.08),
        r:NextNumber(-0.05, 0.06),
        r:NextNumber(-0.08, 0.08)
    )
    self.offset = clampVec((self.offset + tiny) * 0.82, 0.45)

    -- slight rotation jitter to keep orientation disagreement alive
    local rotStep = Vector3.new(
        math.rad(r:NextNumber(-1.5, 1.5)),
        math.rad(r:NextNumber(-2.5, 2.5)),
        math.rad(r:NextNumber(-1, 1))
    )
    self.rotationJitter = clampVec((self.rotationJitter + rotStep) * 0.7, math.rad(4))

    local deltaOffset = self.offset - self.appliedOffset
    local deltaRot = self.rotationJitter - self.appliedRotation
    if deltaOffset.Magnitude > 0.001 or deltaRot.Magnitude > 0.001 then
        root.CFrame = root.CFrame * CFrame.new(deltaOffset) * CFrame.Angles(
            deltaRot.X,
            deltaRot.Y,
            deltaRot.Z
        )
        self.appliedOffset = self.offset
        self.appliedRotation = self.rotationJitter
    end

    -- momentary velocity spikes the server will dampen, keeping constant correction pressure
    if r:NextNumber() < 0.45 then
        local spikeBase = Vector3.new(
            r:NextNumber(-1, 1),
            r:NextNumber(-0.25, 0.9),
            r:NextNumber(-1, 1)
        )
        local spike = clampVec(spikeBase * r:NextNumber(3.5, 8.5), 12)
        root.AssemblyLinearVelocity = root.AssemblyLinearVelocity + spike
    end

    -- occasional angular bumps to desync facing without obvious spinning
    if r:NextNumber() < 0.25 then
        local ang = Vector3.new(
            math.rad(r:NextNumber(-3.5, 3.5)),
            math.rad(r:NextNumber(-6, 6)),
            math.rad(r:NextNumber(-2.5, 2.5))
        )
        root.AssemblyAngularVelocity = root.AssemblyAngularVelocity + ang
    end
end

function StandDesync:startup()
    self:trackCharacter(Players.LocalPlayer and Players.LocalPlayer.Character)
    if Players.LocalPlayer then
        self.connections:connect(Players.LocalPlayer.CharacterAdded, function(char)
            self:trackCharacter(char)
        end)
    end
    self.connections:connect(RunService.RenderStepped, function(dt)
        self:applyJitter(dt)
    end)
end

return StandDesync

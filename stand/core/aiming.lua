local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Aiming = {}
Aiming.__index = Aiming

local function isVisible(part, ignore)
    local cam = Workspace.CurrentCamera
    if not cam or not part then return false end
    local origin = cam.CFrame.Position
    local dir = (part.Position - origin)
    local ray = Ray.new(origin, dir.Unit * dir.Magnitude)
    local hit = Workspace:FindPartOnRayWithIgnoreList(ray, ignore or {})
    return not hit or hit:IsDescendantOf(part.Parent)
end

function Aiming.new(state, connections)
    local self = setmetatable({
        state = state,
        connections = connections,
        enabled = false,
        silent = false,
        target = nil,
        targetPart = nil,
        aimRadius = 30,
        timers = { scan = 0 },
        hook = { mt = nil, oldIndex = nil, hooked = false },
        feature = { canHook = getrawmetatable ~= nil and setreadonly ~= nil },
    }, Aiming)
    return self
end

function Aiming:getClosestToCursor()
    local now = tick()
    if now - (self.timers.scan or 0) < 0.18 and self.target then
        return self.target, self.targetPart
    end
    local lp = Players.LocalPlayer
    local mouse = lp:GetMouse()
    local best, bestPart, bestDist = nil, nil, math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= lp and plr.Character then
            for _, partName in ipairs({ "Head", "UpperTorso", "HumanoidRootPart" }) do
                local part = plr.Character:FindFirstChild(partName)
                if part then
                    local pos, onScreen = Workspace.CurrentCamera:WorldToScreenPoint(part.Position)
                    if onScreen then
                        local diff = (Vector2.new(pos.X, pos.Y) - Vector2.new(mouse.X, mouse.Y)).Magnitude
                        if diff < bestDist and isVisible(part, { lp.Character }) then
                            best, bestPart, bestDist = plr, part, diff
                        end
                    end
                end
            end
        end
    end
    self.target = best
    self.targetPart = bestPart
    self.timers.scan = now
    return best, bestPart
end

function Aiming:hookMouse()
    if self.hook.hooked or not self.feature.canHook then return end
    local mt = getrawmetatable(game)
    if not mt then return end
    local old = mt.__index
    setreadonly(mt, false)
    mt.__index = function(t, k)
        if self.silent and self.state.playable and (k == "Hit" or k == "Target") and t == Players.LocalPlayer:GetMouse() then
            local part = self.targetPart
            if part then
                if k == "Hit" then return CFrame.new(part.Position) end
                if k == "Target" then return part end
            end
        end
        return old(t, k)
    end
    setreadonly(mt, true)
    self.hook = { mt = mt, oldIndex = old, hooked = true }
end

function Aiming:unhookMouse()
    if not self.hook.hooked then return end
    local mt, old = self.hook.mt, self.hook.oldIndex
    if mt and old then
        pcall(setreadonly, mt, false)
        mt.__index = old
        pcall(setreadonly, mt, true)
    end
    self.hook = { mt = nil, oldIndex = nil, hooked = false }
end

function Aiming:startSilent(target)
    if not target or not target.Character then return end
    self.enabled = true
    self.silent = true
    self.target = target
    self.targetPart = target.Character:FindFirstChild("HumanoidRootPart") or target.Character:FindFirstChild("Head")
    self:hookMouse()
end

function Aiming:stop()
    self.enabled = false
    self.silent = false
    self.target = nil
    self.targetPart = nil
    self:unhookMouse()
end

function Aiming:onHeartbeat(playable)
    if not self.enabled or not playable then return end
    self:getClosestToCursor()
end

function Aiming:startup() end

return Aiming

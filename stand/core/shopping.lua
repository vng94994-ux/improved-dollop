local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shopping = {}
Shopping.__index = Shopping

local gunShopNames = {
    rifle = "rifle",
    aug = "aug",
    flintlock = "flintlock",
    db = "double-barrel",
    lmg = "lmg",
}

local ammoShopNames = {
    rifle = "rifle ammo",
    aug = "aug ammo",
    flintlock = "flintlock ammo",
    db = "double-barrel sg ammo",
    lmg = "lmg ammo",
}

local function findShopItem(name)
    local shopRoot = Workspace:FindFirstChild("Ignored")
    shopRoot = shopRoot and shopRoot:FindFirstChild("Shop")
    if not shopRoot then return nil end
    name = string.lower(name)
    for _, d in ipairs(shopRoot:GetDescendants()) do
        if d:IsA("Model") or d:IsA("Part") then
            if string.find(string.lower(d.Name), name, 1, true) then
                local head = d:FindFirstChild("Head") or d:FindFirstChildWhichIsA("BasePart")
                local detector = d:FindFirstChildOfClass("ClickDetector") or (head and head:FindFirstChildOfClass("ClickDetector"))
                if detector and head then
                    return detector, head
                end
            end
        end
    end
    return nil
end

function Shopping.new(state, connections)
    local self = setmetatable({
        state = state,
        connections = connections,
        buying = { guns = false, ammo = false, mask = false },
        feature = { click = fireclickdetector ~= nil },
        cache = {},
        cooldown = { guns = 0, ammo = 0, mask = 0 },
    }, Shopping)
    return self
end

function Shopping:resolve(name)
    name = string.lower(name)
    if self.cache[name] then return unpack(self.cache[name]) end
    local detector, head = findShopItem(name)
    if detector and head then
        self.cache[name] = { detector, head }
    end
    return detector, head
end

local function teleportAndClick(head, detector, tries, delay)
    local lp = Players.LocalPlayer
    local char = lp and lp.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    local original = root.CFrame
    root.CFrame = head.CFrame + Vector3.new(0, 3, 0)
    for _ = 1, tries do
        fireclickdetector(detector)
        task.wait(delay)
    end
    root.CFrame = original
    return true
end

local function withMovementLock(state, fn)
    state.flags.lockMovement = true
    local ok, res = pcall(fn)
    state.flags.lockMovement = false
    if not ok then error(res) end
    return res
end

function Shopping:buy(modelName, tries, delay)
    if not self.feature.click then return false end
    local detector, head = self:resolve(modelName)
    if not detector or not head then return false end
    return teleportAndClick(head, detector, tries or 8, delay or 0.12)
end

function Shopping:buyGun(canon)
    if self.buying.guns then return end
    local now = tick()
    if now - (self.cooldown.guns or 0) < 1.0 then return end
    self.buying.guns = true
    withMovementLock(self.state, function()
        self:buy(gunShopNames[canon] or canon, 10, 0.1)
    end)
    self.cooldown.guns = tick()
    self.buying.guns = false
end

function Shopping:buyAmmo(canon)
    if self.buying.ammo then return end
    local now = tick()
    if now - (self.cooldown.ammo or 0) < 1.0 then return end
    self.buying.ammo = true
    withMovementLock(self.state, function()
        self:buy(ammoShopNames[canon] or "ammo", 8, 0.1)
    end)
    self.cooldown.ammo = tick()
    self.buying.ammo = false
end

function Shopping:buyMask()
    if self.buying.mask then return end
    local now = tick()
    if now - (self.cooldown.mask or 0) < 1.0 then return end
    self.buying.mask = true
    withMovementLock(self.state, function()
        self:buy("mask", 10, 0.12)
    end)
    self.cooldown.mask = tick()
    self.buying.mask = false
end

function Shopping:stopBuying()
    self.buying = { guns = false, ammo = false, mask = false }
end

function Shopping:startup() end

return Shopping

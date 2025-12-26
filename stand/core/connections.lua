local Connections = {}
Connections.__index = Connections

function Connections.new()
    return setmetatable({ list = {}, tasks = {} }, Connections)
end

function Connections:connect(signal, fn)
    local c = signal:Connect(fn)
    table.insert(self.list, c)
    return c
end

function Connections:addTask(thread)
    table.insert(self.tasks, thread)
    return thread
end

function Connections:cleanup()
    for _, c in ipairs(self.list) do
        pcall(function() c:Disconnect() end)
    end
    self.list = {}
    for _, t in ipairs(self.tasks) do
        pcall(function() if task.cancel then task.cancel(t) end end)
    end
    self.tasks = {}
end

return Connections

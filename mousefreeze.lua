-- Mouse Freeze / Infinite Camera (Hold Click)
-- Clicou em qualquer lugar: trava no centro
-- Soltou o clique: destrava mantendo no centro

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Camera = workspace.CurrentCamera

local locked = false
local renderConn

local function centerPos()
    local v = Camera.ViewportSize
    return Vector2.new(v.X / 2, v.Y / 2)
end

local function lockMouse()
    if locked then return end
    locked = true

    UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
    UserInputService.MouseIconEnabled = false

    renderConn = RunService.RenderStepped:Connect(function()
        if locked then
            local c = centerPos()
            VirtualInputManager:SendMouseMoveEvent(c.X, c.Y, game)
        end
    end)
end

local function unlockMouse()
    if not locked then return end
    locked = false

    UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    UserInputService.MouseIconEnabled = true

    if renderConn then
        renderConn:Disconnect()
        renderConn = nil
    end

    local c = centerPos()
    VirtualInputManager:SendMouseMoveEvent(c.X, c.Y, game)
end

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        lockMouse()
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        unlockMouse()
    end
end)

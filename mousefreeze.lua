-- Mouse infinito por movimento de câmera (Delta-safe)

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Camera = workspace.CurrentCamera

local locked = false

local function center()
    local v = Camera.ViewportSize
    return Vector2.new(v.X/2, v.Y/2)
end

RunService.RenderStepped:Connect(function()
    local delta = UserInputService:GetMouseDelta()

    if delta.Magnitude > 0 then
        if not locked then
            locked = true
            UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
            UserInputService.MouseIconEnabled = false
        end

        local c = center()
        VirtualInputManager:SendMouseMoveEvent(c.X, c.Y, game)
    else
        if locked then
            locked = false
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
            UserInputService.MouseIconEnabled = true

            local c = center()
            VirtualInputManager:SendMouseMoveEvent(c.X, c.Y, game)
        end
    end
end)

print("Mouse infinito por movimento ativo")

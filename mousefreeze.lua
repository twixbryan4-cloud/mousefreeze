local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local cam = workspace.CurrentCamera

RunService.RenderStepped:Connect(function()
	if cam.CameraType == Enum.CameraType.Custom then
		cam.CameraType = Enum.CameraType.Scriptable
	end
end)

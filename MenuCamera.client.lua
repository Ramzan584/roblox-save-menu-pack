-- Optional menu camera; delete this LocalScript if you use another camera controller.
-- CC0-1.0 | timura032
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local demo = workspace:WaitForChild("SaveMenuDemo", 15)
local point = demo and demo:WaitForChild("MenuCamera", 15)
if not point or not point:IsA("BasePart") then return end
local saved, elapsed
local function restore()
    if not saved then return end
    local camera = saved.camera
    camera.CameraType = saved.kind
    camera.CameraSubject = player.Character and player.Character:FindFirstChildOfClass("Humanoid") or saved.subject
    camera.CFrame = saved.frame
    saved = nil
end
local connection = RunService.RenderStepped:Connect(function(dt)
    local camera = workspace.CurrentCamera
    if not player:GetAttribute("SaveMenuOpen") or not point.Parent or not camera then restore(); return end
    if saved and saved.camera ~= camera then restore() end
    if not saved then
        saved = {camera = camera, kind = camera.CameraType, subject = camera.CameraSubject, frame = camera.CFrame}
        elapsed = 0; camera.CameraType = Enum.CameraType.Scriptable
    end
    elapsed = elapsed + dt
    local offset = player:GetAttribute("SaveMenuReducedMotion") and Vector3.zero or Vector3.new(math.sin(elapsed * 0.2) * 0.4, 0, 0)
    camera.CFrame = point.CFrame + offset
end)
script.Destroying:Connect(function() connection:Disconnect(); restore() end)

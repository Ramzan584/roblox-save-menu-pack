-- LocalScript. Mobile-friendly menu button and live checkpoint/coin counters. CC0-1.0
local player = game:GetService("Players").LocalPlayer
local pg = player:WaitForChild("PlayerGui")
local shared = game:GetService("ReplicatedStorage"):WaitForChild("SaveMenuPack")
local UI = require(shared:WaitForChild("UIFactory"))
local old = pg:FindFirstChild("SaveMenuHUD"); if old then old:Destroy() end
local gui = UI.new("ScreenGui", pg, {Name = "SaveMenuHUD", ResetOnSpawn = false, DisplayOrder = 20})
local bar = UI.new("Frame", gui, {Position = UDim2.new(0, 12, 0, 12), Size = UDim2.new(1, -24, 0, 48), BackgroundColor3 = Color3.fromRGB(22, 25, 33)})
UI.round(bar); UI.new("UISizeConstraint", bar, {MaxSize = Vector2.new(480, 48)})
local button = UI.button(bar, UI.text(UI.language(player), "Меню", "Menu"), function()
    local open = pg:FindFirstChild("SaveMenuOpen")
    if open then open:Fire() end
end)
button.Size = UDim2.fromOffset(92, 48)
local label = UI.label(bar, "", 48); label.Position = UDim2.fromOffset(104, 0); label.Size = UDim2.new(1, -110, 1, 0); label.TextSize = 14
local function update()
    local playing = player:GetAttribute("SaveMenuStarted") == true
    gui.Enabled = playing
    local stage, coins = player:GetAttribute("SaveMenuCheckpoint") or 0, player:GetAttribute("SaveMenuCoins") or 0
    label.Text = string.format(UI.text(UI.language(player), "Этап %d · Монеты %d", "Stage %d · Coins %d"), stage, coins)
end
for _, attribute in ipairs({"SaveMenuStarted", "SaveMenuCheckpoint", "SaveMenuCoins"}) do player:GetAttributeChangedSignal(attribute):Connect(update) end
update()

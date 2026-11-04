-- Shared ModuleScript, used by LocalScripts. CC0-1.0 | timura032
local UI = {}
UI.Accent = Color3.fromRGB(255, 211, 74)
function UI.new(class, parent, properties)
    local object = Instance.new(class)
    for name, value in pairs(properties or {}) do object[name] = value end
    object.Parent = parent
    return object
end
function UI.round(object)
    UI.new("UICorner", object, {CornerRadius = UDim.new(0, 10)})
end
function UI.label(parent, text, height)
    local label = UI.new("TextLabel", parent, {
        Size = UDim2.new(1, 0, 0, height or 40), BackgroundTransparency = 1,
        Text = text, TextColor3 = Color3.fromRGB(231, 235, 243), TextSize = 17,
        Font = Enum.Font.Gotham, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
    })
    return label
end
function UI.button(parent, text, callback)
    local button = UI.new("TextButton", parent, {
        Size = UDim2.new(1, 0, 0, 46), BackgroundColor3 = Color3.fromRGB(44, 49, 62),
        Text = text, TextColor3 = Color3.fromRGB(250, 250, 252), TextSize = 17,
        Font = Enum.Font.GothamMedium, AutoButtonColor = true,
    })
    UI.round(button)
    button.Activated:Connect(callback)
    return button
end
function UI.language(player)
    return string.sub(string.lower(player.LocaleId or "en-us"), 1, 2) == "ru" and "RU" or "EN"
end
function UI.text(language, ru, en) return language == "RU" and ru or en end
return UI

-- LocalScript -> StarterPlayer.StarterPlayerScripts. CC0-1.0 | timura032
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local shared = ReplicatedStorage:WaitForChild("SaveMenuPack")
local Config = require(shared:WaitForChild("Config"))
local UI = require(shared:WaitForChild("UIFactory"))
local request = shared:WaitForChild("Request", 20)
local lang = UI.language(player)
local function t(ru, en) return UI.text(lang, ru, en) end
local old = playerGui:FindFirstChild("SaveMenuUI")
if old then old:Destroy() end
local open = playerGui:FindFirstChild("SaveMenuOpen") or UI.new("BindableEvent", playerGui, {Name = "SaveMenuOpen"})
local changed = playerGui:FindFirstChild("SaveMenuSnapshot") or UI.new("BindableEvent", playerGui, {Name = "SaveMenuSnapshot"})
local gui = UI.new("ScreenGui", playerGui, {Name = "SaveMenuUI", ResetOnSpawn = false, DisplayOrder = 50, ZIndexBehavior = Enum.ZIndexBehavior.Sibling})
local shade = UI.new("TextButton", gui, {Name = "Shade", Size = UDim2.fromScale(1, 1), Text = "", AutoButtonColor = false, Modal = true, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.2})
local window = UI.new("Frame", shade, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.92, 0.9), BackgroundColor3 = Color3.fromRGB(22, 25, 33)})
UI.round(window)
UI.new("UISizeConstraint", window, {MaxSize = Vector2.new(780, 640)})
UI.new("UIPadding", window, {PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 18), PaddingTop = UDim.new(0, 14), PaddingBottom = UDim.new(0, 14)})
local title = UI.label(window, Config.TITLE, 42)
title.TextSize = 25; title.TextColor3 = UI.Accent
local prototype = UI.label(window, t("СЫРОЙ ШАБЛОН · можно менять под свою игру", "RAW TEMPLATE · customize for your own game"), 30)
prototype.Position = UDim2.fromOffset(0, 44); prototype.TextSize = 13
local tabs = UI.new("Frame", window, {Position = UDim2.fromOffset(0, 80), Size = UDim2.new(1, 0, 0, 42), BackgroundTransparency = 1})
local pages, buttons = {}, {}
local function show(name)
    for key, page in pairs(pages) do page.Visible = key == name end
    for key, button in pairs(buttons) do button.BackgroundColor3 = key == name and Color3.fromRGB(89, 75, 30) or Color3.fromRGB(44, 49, 62) end
end
for index, info in ipairs({{"Play", t("Игра", "Play")}, {"Settings", t("Настройки", "Settings")}, {"Help", t("Помощь", "Help")}}) do
    local key = info[1]
    local button = UI.button(tabs, info[2], function() show(key) end)
    button.Size = UDim2.new(1 / 3, -6, 1, 0); button.Position = UDim2.new((index - 1) / 3, 3, 0, 0)
    buttons[key] = button
    local page = UI.new("ScrollingFrame", window, {Name = key, Position = UDim2.fromOffset(0, 134), Size = UDim2.new(1, 0, 1, -138), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y})
    UI.new("UIListLayout", page, {Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder})
    UI.new("UIPadding", page, {PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 12)})
    pages[key] = page
end
local state, busy, render = {Status = "LOADING"}, false, nil
local function setVisible(visible)
    gui.Enabled = visible
    player:SetAttribute("SaveMenuOpen", visible)
end
local function ask(action, name, value)
    if busy then return end
    if not request then state.Message = "NO_SERVER"; if render then render() end; return end
    busy = true
    local ok, result = pcall(function() return request:InvokeServer(action, name, value) end)
    busy = false
    if ok and type(result) == "table" then
        state = result; changed:Fire(result)
    else state.Message = "CONNECTION_ERROR" end
    if render then render() end
end
local progress = UI.label(pages.Play, "", 72); progress.LayoutOrder = 1
local saveState = UI.label(pages.Play, "", 72); saveState.LayoutOrder = 2
local preview = UI.label(pages.Play, "", 58); preview.LayoutOrder = 3; preview.TextColor3 = UI.Accent
local play = UI.button(pages.Play, t("Загрузка…", "Loading…"), function()
    if state.Started then setVisible(false); return end
    ask("Play")
    if state.Started then setVisible(false) end
end); play.LayoutOrder = 4
local save = UI.button(pages.Play, t("Сохранить", "Save now"), function() ask("Save") end); save.LayoutOrder = 5
local retry = UI.button(pages.Play, t("Повторить загрузку", "Retry loading"), function() ask("RetryLoad") end); retry.LayoutOrder = 6
local close = UI.button(pages.Play, t("Вернуться в игру", "Back to game"), function() if state.Started then setVisible(false) end end); close.LayoutOrder = 7
local volume = UI.button(pages.Settings, "", function()
    if state.Data then
        local nextVolume = (math.floor(state.Data.Settings.MusicVolume * 4 + 0.5) + 1) % 5 / 4
        ask("Setting", "MusicVolume", nextVolume)
    end
end); volume.LayoutOrder = 1
local motion = UI.button(pages.Settings, "", function()
    if state.Data then ask("Setting", "ReducedMotion", not state.Data.Settings.ReducedMotion) end
end); motion.LayoutOrder = 2
local settingsHelp = UI.label(pages.Settings, t("Настройки входят в сохранение. Громкость влияет на SoundGroup SaveMenuMusic. Уменьшение движения отключает покачивание камеры меню.", "Settings are saved. Volume affects the SaveMenuMusic SoundGroup. Reduced motion disables menu camera drift."), 96); settingsHelp.LayoutOrder = 3
local helpText = UI.label(pages.Help, t("Это сырой стартовый шаблон. Можно бесплатно менять меню, скрипты и оформление под свою игру.\n\nСохраняются чекпоинт, монеты, игровое время и настройки. Возврат в меню не ставит серверную игру на паузу.", "This is a raw starter template. Customize the menu, scripts and appearance for free.\n\nCheckpoint, coins, playtime and settings are saved. Reopening the menu does not pause the server."), 170); helpText.LayoutOrder = 1
local support = UI.label(pages.Help, t("Помощь по шаблону бесплатная. Оставь комментарий в теме отзывов на GitHub:", "Help with this template is free. Leave a comment in the GitHub feedback thread:"), 64); support.LayoutOrder = 2
local feedback = UI.label(pages.Help, Config.FEEDBACK_URL, 64); feedback.TextSize = 14; feedback.LayoutOrder = 3
local author = UI.label(pages.Help, "timura032 · CC0-1.0 · Telegram " .. Config.TELEGRAM, 40); author.TextSize = 14; author.LayoutOrder = 4
local errors = {
    LOADING = t("Загружаю прогресс…", "Loading progress…"), READY = t("Прогресс загружен", "Progress loaded"),
    PLAYING = t("Игра началась", "Game started"), SAVING = t("Сохраняю…", "Saving…"),
    SAVE_FAILED = t("Не удалось сохранить. Попробуй снова; не выходи сразу.", "Save failed. Try again; avoid leaving immediately."),
    SESSION_LOCKED = t("Сохранение ещё занято другим сервером. Попробуй позже.", "Another server still holds this save. Retry later."),
    DATASTORE_UNAVAILABLE = t("Хранилище недоступно. Прогресс не загружен.", "Storage unavailable. Progress was not loaded."),
    UNSUPPORTED_DATA = t("Формат сохранения не поддерживается. Данные не перезаписаны.", "Unsupported save format. Data was not overwritten."),
    SAVE_COOLDOWN = string.format(t("Между ручными сохранениями нужно подождать %d секунд.", "Wait %d seconds between manual saves."), Config.MANUAL_SAVE_COOLDOWN),
    RATE_LIMIT = t("Подожди немного и попробуй снова.", "Please wait briefly and try again."),
    BUSY = t("Запрос выполняется…", "Request in progress…"),
    CONNECTION_ERROR = t("Ошибка связи. Повторная попытка выполняется автоматически.", "Connection error. Retrying automatically."),
    NO_SERVER = t("Сервер меню не найден. Проверь установку пака.", "Menu server missing. Check pack installation."),
}
render = function()
    local data = state.Data
    progress.Text = data and string.format(t("Чекпоинт: %d   Монеты: %d\nВ игре: %d мин.", "Checkpoint: %d   Coins: %d\nPlaytime: %d min."), data.Checkpoint, data.Coins, math.floor(data.PlaySeconds / 60)) or t("Прогресс пока недоступен", "Progress not yet available")
    local statusText = errors[state.Message] or errors[state.Status] or t("Не удалось загрузить прогресс. Повтори загрузку.", "Progress could not be loaded. Retry loading.")
    if state.LastSavedAt then statusText = statusText .. "\n" .. t("Последнее сохранение: ", "Last save: ") .. os.date("%H:%M:%S", state.LastSavedAt) end
    saveState.Text = statusText
    preview.Text = state.MemoryMode == true and t("ДЕМО В ПАМЯТИ: после остановки Studio прогресс исчезнет.", "MEMORY DEMO: progress disappears after stopping Studio.") or state.MemoryMode == false and t("Постоянное сохранение · автосохранение включено", "Persistent storage · autosave enabled") or t("Определяю режим сохранения…", "Checking storage mode…")
    play.Text = state.Started and t("Вернуться в игру", "Back to game") or data and (state.HasProgress and t("Продолжить", "Continue") or t("Играть", "Play")) or t("Ожидаю загрузку…", "Waiting for save…")
    play.Active = data ~= nil; play.AutoButtonColor = data ~= nil
    save.Visible = data ~= nil; retry.Visible = not data and state.Status ~= "LOADING"; close.Visible = state.Started == true
    volume.Text = t("Громкость музыки: ", "Music volume: ") .. tostring(math.floor(((data and data.Settings.MusicVolume) or 0.5) * 100)) .. "%"
    motion.Text = t("Меньше движения: ", "Reduced motion: ") .. ((data and data.Settings.ReducedMotion) and t("вкл", "on") or t("выкл", "off"))
end
open.Event:Connect(function() setVisible(true); ask("Status") end)
setVisible(true); show("Play"); render()
task.spawn(function()
    while gui.Parent do
        ask("Status")
        task.wait(gui.Enabled and 1 or 4)
    end
end)

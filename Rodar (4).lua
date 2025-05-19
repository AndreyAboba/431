local module = {}

function module.Init(UI, Core, notify)
    -- Получение сервисов через Core
    local Players = Core.Services.Players
    local UserInputService = Core.Services.UserInputService
    local RunService = Core.Services.RunService
    local TweenService = Core.Services.TweenService
    local LocalPlayer = Core.PlayerData.LocalPlayer

    -- Создание секции Radar
    if not UI.Sections.Radar then
        UI.Sections.Radar = UI.Tabs.Visuals:Section({ Name = "Radar", Side = "Right" })
    end

    -- Объект радара
    local Radar = {
        State = {
            Enabled = false, -- Начальное состояние: выключен
            Dragging = false,
            DragStart = nil,
            StartPos = nil,
            Scale = 0.1,
            ShowDebugLabels = true, -- Отображение меток N, S, E, W
            Position = UDim2.new(0, 10, 0, 10), -- Сохранение позиции
        },
        Config = {
            Size = 150,
            BackgroundColor = Color3.fromRGB(20, 30, 50),
            BackgroundTransparency = 0.3,
            DotColor = Color3.fromRGB(255, 0, 0), -- Красный для врагов
            FriendColor = Color3.fromRGB(0, 0, 255), -- Синий для друзей
            DotSize = 5,
            UpdateInterval = 0.02,
            LocalPlayerColor = Color3.fromRGB(0, 255, 0),
            LocalPlayerSize = 8,
            CrosshairColor = Color3.fromRGB(255, 255, 255),
            CrosshairTransparency = 0.5,
            BorderTransparency = 0.5,
            GradientSpeed = 30, -- Скорость вращения градиента
            GradientEnabled = true, -- Включён ли градиент
            RadarColor = Color3.fromRGB(255, 255, 255), -- Статичный цвет бордера
        },
        Elements = {
            Gui = nil,
            Container = nil,
            Dots = {},
            LocalPlayerIndicator = nil,
            CrosshairVertical = nil,
            CrosshairHorizontal = nil,
            Border = nil,
            Gradient = nil, -- Для динамического обновления градиента
            NorthLabel = nil,
            SouthLabel = nil,
            EastLabel = nil,
            WestLabel = nil,
        },
        FriendCache = { -- Кэш для статусов друзей
            IsFriend = {}, -- Ключом будет имя игрока в нижнем регистре
        }
    }

    -- Создание точки для игрока
    local function createPlayerDot(player)
        local dot = Instance.new("Frame")
        dot.Size = UDim2.new(0, Radar.Config.DotSize, 0, Radar.Config.DotSize)
        -- Проверяем, является ли игрок другом
        local playerNameLower = player.Name:lower()
        local isFriend = Core.Services.FriendsList and Core.Services.FriendsList[playerNameLower] or false
        Radar.FriendCache.IsFriend[playerNameLower] = isFriend
        dot.BackgroundColor3 = isFriend and Radar.Config.FriendColor or Radar.Config.DotColor
        dot.BackgroundTransparency = 0
        dot.BorderSizePixel = 0
        dot.Parent = Radar.Elements.Container

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0.5, 0)
        corner.Parent = dot

        Radar.Elements.Dots[player] = dot
    end

    -- Создание GUI радара
    local function createRadarGui()
        if Radar.Elements.Gui then Radar.Elements.Gui:Destroy() end
        Radar.Elements.Dots = {}

        local gui = Instance.new("ScreenGui")
        gui.Name = "SyllinseRadarGui"
        gui.ResetOnSpawn = false
        gui.IgnoreGuiInset = true
        gui.Enabled = Radar.State.Enabled
        gui.Parent = Core.Services.CoreGuiService
        Radar.Elements.Gui = gui

        local container = Instance.new("Frame")
        container.Size = UDim2.new(0, Radar.Config.Size, 0, Radar.Config.Size)
        container.Position = Radar.State.Position -- Восстанавливаем сохранённую позицию
        container.BackgroundColor3 = Radar.Config.BackgroundColor
        container.BackgroundTransparency = Radar.Config.BackgroundTransparency
        container.BorderSizePixel = 0
        container.Parent = gui
        Radar.Elements.Container = container

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 5)
        corner.Parent = container

        -- Градиентный бордер
        local border = Instance.new("Frame")
        border.Size = UDim2.new(1, 4, 1, 4)
        border.Position = UDim2.new(0, -2, 0, -2)
        border.BackgroundTransparency = Radar.Config.BorderTransparency
        border.BackgroundColor3 = Radar.Config.RadarColor
        border.BorderSizePixel = 0
        border.Parent = container
        Radar.Elements.Border = border

        local borderCorner = Instance.new("UICorner")
        borderCorner.CornerRadius = UDim.new(0, 7)
        borderCorner.Parent = border

        local gradient = Instance.new("UIGradient")
        gradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Core.GlobalConfigs.GradientColors["Gradient Color 1"]),
            ColorSequenceKeypoint.new(1, Core.GlobalConfigs.GradientColors["Gradient Color 2"])
        })
        gradient.Rotation = 45
        gradient.Enabled = Radar.Config.GradientEnabled
        gradient.Parent = border
        Radar.Elements.Gradient = gradient

        -- Анимация градиента
        RunService.Heartbeat:Connect(function(deltaTime)
            if Radar.Elements.Border then
                if Radar.Config.GradientEnabled then
                    -- Динамическое обновление цветов градиента
                    gradient.Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0, Core.GlobalConfigs.GradientColors["Gradient Color 1"]),
                        ColorSequenceKeypoint.new(1, Core.GlobalConfigs.GradientColors["Gradient Color 2"])
                    })
                    gradient.Rotation = (gradient.Rotation + deltaTime * Radar.Config.GradientSpeed) % 360
                    gradient.Enabled = true
                    Radar.Elements.Border.BackgroundColor3 = Color3.fromRGB(255, 255, 255) -- Белый фон для градиента
                else
                    gradient.Enabled = false
                    Radar.Elements.Border.BackgroundColor3 = Radar.Config.RadarColor
                end
            end
        end)

        -- Перекрестие: вертикальная линия
        local crosshairVertical = Instance.new("Frame")
        crosshairVertical.Size = UDim2.new(0, 1, 1, 0)
        crosshairVertical.Position = UDim2.new(0.5, 0, 0, 0)
        crosshairVertical.BackgroundColor3 = Radar.Config.CrosshairColor
        crosshairVertical.BackgroundTransparency = Radar.Config.CrosshairTransparency
        crosshairVertical.BorderSizePixel = 0
        crosshairVertical.Parent = container
        Radar.Elements.CrosshairVertical = crosshairVertical

        -- Перекрестие: горизонтальная линия
        local crosshairHorizontal = Instance.new("Frame")
        crosshairHorizontal.Size = UDim2.new(1, 0, 0, 1)
        crosshairHorizontal.Position = UDim2.new(0, 0, 0.5, 0)
        crosshairHorizontal.BackgroundColor3 = Radar.Config.CrosshairColor
        crosshairHorizontal.BackgroundTransparency = Radar.Config.CrosshairTransparency
        crosshairHorizontal.BorderSizePixel = 0
        crosshairHorizontal.Parent = container
        Radar.Elements.CrosshairHorizontal = crosshairHorizontal

        -- Отладочные метки (N, S, E, W)
        local function createDebugLabels()
            if Radar.Elements.NorthLabel then Radar.Elements.NorthLabel:Destroy() end
            if Radar.Elements.SouthLabel then Radar.Elements.SouthLabel:Destroy() end
            if Radar.Elements.EastLabel then Radar.Elements.EastLabel:Destroy() end
            if Radar.Elements.WestLabel then Radar.Elements.WestLabel:Destroy() end

            if not Radar.State.ShowDebugLabels then return end

            local northLabel = Instance.new("TextLabel")
            northLabel.Size = UDim2.new(0, 20, 0, 20)
            northLabel.Position = UDim2.new(0.5, -10, 0, -10)
            northLabel.BackgroundTransparency = 1
            northLabel.Text = "N"
            northLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            northLabel.TextSize = 14
            northLabel.Parent = container
            Radar.Elements.NorthLabel = northLabel

            local southLabel = Instance.new("TextLabel")
            southLabel.Size = UDim2.new(0, 20, 0, 20)
            southLabel.Position = UDim2.new(0.5, -10, 1, -10)
            southLabel.BackgroundTransparency = 1
            southLabel.Text = "S"
            southLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            southLabel.TextSize = 14
            southLabel.Parent = container
            Radar.Elements.SouthLabel = southLabel

            local eastLabel = Instance.new("TextLabel")
            eastLabel.Size = UDim2.new(0, 20, 0, 20)
            eastLabel.Position = UDim2.new(1, -10, 0.5, -10)
            eastLabel.BackgroundTransparency = 1
            eastLabel.Text = "E"
            eastLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            eastLabel.TextSize = 14
            eastLabel.Parent = container
            Radar.Elements.EastLabel = eastLabel

            local westLabel = Instance.new("TextLabel")
            westLabel.Size = UDim2.new(0, 20, 0, 20)
            westLabel.Position = UDim2.new(0, -10, 0.5, -10)
            westLabel.BackgroundTransparency = 1
            westLabel.Text = "W"
            westLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            westLabel.TextSize = 14
            westLabel.Parent = container
            Radar.Elements.WestLabel = westLabel
        end
        createDebugLabels()

        -- Треугольник локального игрока
        local localPlayerIndicator = Instance.new("ImageLabel")
        localPlayerIndicator.Size = UDim2.new(0, Radar.Config.LocalPlayerSize, 0, Radar.Config.LocalPlayerSize)
        localPlayerIndicator.Position = UDim2.new(0.5, -Radar.Config.LocalPlayerSize / 2, 0.5, -Radar.Config.LocalPlayerSize / 2)
        localPlayerIndicator.BackgroundTransparency = 1
        localPlayerIndicator.Image = "rbxassetid://4292970642"
        localPlayerIndicator.ImageColor3 = Radar.Config.LocalPlayerColor
        localPlayerIndicator.Parent = container
        Radar.Elements.LocalPlayerIndicator = localPlayerIndicator

        -- Обновление поворота треугольника
        RunService.Heartbeat:Connect(function()
            if Radar.State.Enabled and Radar.Elements.LocalPlayerIndicator then
                local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if root then
                    local lookDirection = root.CFrame.LookVector
                    local angle = math.deg(math.atan2(lookDirection.Z, lookDirection.X)) + 90
                    Radar.Elements.LocalPlayerIndicator.Rotation = angle
                end
            end
        end)

        -- Создание точек для других игроков
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                createPlayerDot(player)
            end
        end
    end

    -- Удаление точки игрока
    local function removePlayerDot(player)
        if Radar.Elements.Dots[player] then
            Radar.Elements.Dots[player]:Destroy()
            Radar.Elements.Dots[player] = nil
            Radar.FriendCache.IsFriend[player.Name:lower()] = nil -- Очищаем кэш для этого игрока
        end
    end

    -- Обновление позиций точек
    local lastUpdate = 0
    local function updateRadar()
        if not Radar.State.Enabled or not Radar.Elements.Container then return end

        local currentTime = tick()
        if currentTime - lastUpdate < Radar.Config.UpdateInterval then return end
        lastUpdate = currentTime

        local localRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

        for player, dot in pairs(Radar.Elements.Dots) do
            local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            if localRoot and root then
                local relativePos = root.Position - localRoot.Position
                local radarX = relativePos.X * Radar.State.Scale
                local radarZ = relativePos.Z * Radar.State.Scale

                local maxOffset = Radar.Config.Size / 2 - Radar.Config.DotSize / 2
                radarX = math.clamp(radarX, -maxOffset, maxOffset)
                radarZ = math.clamp(radarZ, -maxOffset, maxOffset)

                dot.Position = UDim2.new(0.5, radarX, 0.5, radarZ)
                dot.Visible = true

                -- Обновляем цвет точки, если статус друга изменился
                local playerNameLower = player.Name:lower()
                local isFriend = Core.Services.FriendsList and Core.Services.FriendsList[playerNameLower] or false
                Radar.FriendCache.IsFriend[playerNameLower] = isFriend
                dot.BackgroundColor3 = isFriend and Radar.Config.FriendColor or Radar.Config.DotColor
            else
                dot.Visible = false
            end
        end
    end

    -- Обработка перетаскивания радара
    local function handleInput(input)
        if not Radar.State.Enabled then return end

        local mousePos
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            mousePos = input.UserInputType == Enum.UserInputType.Touch and input.Position or UserInputService:GetMouseLocation()
            if input.UserInputState == Enum.UserInputState.Begin then
                if mousePos and Radar.Elements.Container then
                    local container = Radar.Elements.Container
                    if mousePos.X >= container.Position.X.Offset and mousePos.X <= container.Position.X.Offset + container.Size.X.Offset and
                       mousePos.Y >= container.Position.Y.Offset and mousePos.Y <= container.Position.Y.Offset + container.Size.Y.Offset then
                        Radar.State.Dragging = true
                        Radar.State.DragStart = mousePos
                        Radar.State.StartPos = container.Position
                    end
                end
            elseif input.UserInputState == Enum.UserInputState.End then
                Radar.State.Dragging = false
                -- Сохраняем позицию после перетаскивания
                if Radar.Elements.Container then
                    Radar.State.Position = Radar.Elements.Container.Position
                end
            end
        elseif input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            if Radar.State.Dragging then
                mousePos = input.UserInputType == Enum.UserInputType.Touch and input.Position or UserInputService:GetMouseLocation()
                local delta = mousePos - Radar.State.DragStart
                Radar.Elements.Container.Position = UDim2.new(0, Radar.State.StartPos.X.Offset + delta.X, 0, Radar.State.StartPos.Y.Offset + delta.Y)
            end
        end
    end

    -- Инициализация радара
    createRadarGui()

    -- Подключение событий
    UserInputService.InputBegan:Connect(handleInput)
    UserInputService.InputChanged:Connect(handleInput)
    UserInputService.InputEnded:Connect(handleInput)

    Players.PlayerAdded:Connect(function(player)
        if player ~= LocalPlayer then
            createPlayerDot(player)
        end
    end)

    Players.PlayerRemoving:Connect(removePlayerDot)
    RunService.RenderStepped:Connect(updateRadar)

    LocalPlayer.CharacterAdded:Connect(createRadarGui)

    -- Хранилище UI-элементов для синхронизации
    local uiElements = {}

    -- Добавление UI элементов в секции Radar
    if UI.Sections.Radar then
        -- Заголовок секции
        UI.Sections.Radar:Header({ Name = "Radar" })

        -- Переключатель Enabled
        uiElements.RDEnabled = {
            element = UI.Sections.Radar:Toggle({
                Name = "Enabled",
                Default = false,
                Callback = function(value)
                    Radar.State.Enabled = value
                    if Radar.Elements.Gui then
                        Radar.Elements.Gui.Enabled = value
                        if Radar.Elements.Container then
                            local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
                            local targetScale = value and 1 or 0
                            -- Устанавливаем начальный масштаб для анимации появления
                            if value then
                                Radar.Elements.Container.Size = UDim2.new(0, Radar.Config.Size * 0, 0, Radar.Config.Size * 0)
                            end
                            local tween = TweenService:Create(Radar.Elements.Container, tweenInfo, {Size = UDim2.new(0, Radar.Config.Size * targetScale, 0, Radar.Config.Size * targetScale)})
                            tween:Play()
                        end
                    end
                    notify("Radar", "Radar " .. (value and "Enabled" or "Disabled"), true)
                end
            }, 'RDEnabled'),
            callback = function(value)
                Radar.State.Enabled = value
                if Radar.Elements.Gui then
                    Radar.Elements.Gui.Enabled = value
                    if Radar.Elements.Container then
                        local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
                        local targetScale = value and 1 or 0
                        if value then
                            Radar.Elements.Container.Size = UDim2.new(0, Radar.Config.Size * 0, 0, Radar.Config.Size * 0)
                        end
                        local tween = TweenService:Create(Radar.Elements.Container, tweenInfo, {Size = UDim2.new(0, Radar.Config.Size * targetScale, 0, Radar.Config.Size * targetScale)})
                        tween:Play()
                    end
                end
                notify("Radar", "Radar " .. (value and "Enabled" or "Disabled"), true)
            end
        }

        -- Регулировка масштаба
        uiElements.RDScale = {
            element = UI.Sections.Radar:Slider({
                Name = "Scale",
                Minimum = 0.05,
                Maximum = 0.5,
                Precision = 3,
                Default = 0.1,
                Callback = function(value)
                    Radar.State.Scale = value
                    notify("Radar Scale", "Set to: " .. tostring(value), false)
                end
            }, 'RDScale'),
            callback = function(value)
                Radar.State.Scale = value
                notify("Radar Scale", "Set to: " .. tostring(value), false)
            end
        }

        -- Регулировка размера радара
        uiElements.RDSize = {
            element = UI.Sections.Radar:Slider({
                Name = "Radar Size",
                Minimum = 100,
                Maximum = 300,
                Precision = 0,
                Default = 150,
                Callback = function(value)
                    Radar.Config.Size = value
                    if Radar.Elements.Container then
                        Radar.Elements.Container.Size = UDim2.new(0, value, 0, value)
                        -- Обновляем позицию локального игрока
                        Radar.Elements.LocalPlayerIndicator.Position = UDim2.new(0.5, -Radar.Config.LocalPlayerSize / 2, 0.5, -Radar.Config.LocalPlayerSize / 2)
                        -- Обновляем точки игроков
                        updateRadar()
                    end
                    notify("Radar Size", "Set to: " .. tostring(value), false)
                end
            }, 'RDSize'),
            callback = function(value)
                Radar.Config.Size = value
                if Radar.Elements.Container then
                    Radar.Elements.Container.Size = UDim2.new(0, value, 0, value)
                    Radar.Elements.LocalPlayerIndicator.Position = UDim2.new(0.5, -Radar.Config.LocalPlayerSize / 2, 0.5, -Radar.Config.LocalPlayerSize / 2)
                    updateRadar()
                end
                notify("Radar Size", "Set to: " .. tostring(value), false)
            end
        }

        -- Регулировка размера точек
        uiElements.DTSize = {
            element = UI.Sections.Radar:Slider({
                Name = "Dot Size",
                Minimum = 3,
                Maximum = 10,
                Precision = 0,
                Default = 5,
                Callback = function(value)
                    Radar.Config.DotSize = value
                    for _, dot in pairs(Radar.Elements.Dots) do
                        dot.Size = UDim2.new(0, value, 0, value)
                    end
                    updateRadar()
                    notify("Dot Size", "Set to: " .. tostring(value), false)
                end
            }, 'DTSize'),
            callback = function(value)
                Radar.Config.DotSize = value
                for _, dot in pairs(Radar.Elements.Dots) do
                    dot.Size = UDim2.new(0, value, 0, value)
                end
                updateRadar()
                notify("Dot Size", "Set to: " .. tostring(value), false)
            end
        }

        -- Регулировка прозрачности фона
        uiElements.BackgroundTransperencyRD = {
            element = UI.Sections.Radar:Slider({
                Name = "Background Transparency",
                Minimum = 0,
                Maximum = 1,
                Precision = 2,
                Default = 0.3,
                Callback = function(value)
                    Radar.Config.BackgroundTransparency = value
                    if Radar.Elements.Container then
                        Radar.Elements.Container.BackgroundTransparency = value
                    end
                    notify("Background Transparency", "Set to: " .. tostring(value), false)
                end
            }, 'BackgroundTransperencyRD'),
            callback = function(value)
                Radar.Config.BackgroundTransparency = value
                if Radar.Elements.Container then
                    Radar.Elements.Container.BackgroundTransparency = value
                end
                notify("Background Transparency", "Set to: " .. tostring(value), false)
            end
        }

        -- Переключатель для отладочных меток
        uiElements.ShowDebugLabelsRD = {
            element = UI.Sections.Radar:Toggle({
                Name = "Show Debug Labels",
                Default = true,
                Callback = function(value)
                    Radar.State.ShowDebugLabels = value
                    if Radar.Elements.Container then
                        if value then
                            createRadarGui()
                        else
                            if Radar.Elements.NorthLabel then Radar.Elements.NorthLabel:Destroy() end
                            if Radar.Elements.SouthLabel then Radar.Elements.SouthLabel:Destroy() end
                            if Radar.Elements.EastLabel then Radar.Elements.EastLabel:Destroy() end
                            if Radar.Elements.WestLabel then Radar.Elements.WestLabel:Destroy() end
                        end
                    end
                    notify("Debug Labels", value and "Enabled" or "Disabled", true)
                end
            }, 'ShowDebugLabelsRD'),
            callback = function(value)
                Radar.State.ShowDebugLabels = value
                if Radar.Elements.Container then
                    if value then
                        createRadarGui()
                    else
                        if Radar.Elements.NorthLabel then Radar.Elements.NorthLabel:Destroy() end
                        if Radar.Elements.SouthLabel then Radar.Elements.SouthLabel:Destroy() end
                        if Radar.Elements.EastLabel then Radar.Elements.EastLabel:Destroy() end
                        if Radar.Elements.WestLabel then Radar.Elements.WestLabel:Destroy() end
                    end
                end
                notify("Debug Labels", value and "Enabled" or "Disabled", true)
            end
        }

        -- Переключатель для градиента
        uiElements.GradientEnabledRadar = {
            element = UI.Sections.Radar:Toggle({
                Name = "Gradient Enabled",
                Default = Radar.Config.GradientEnabled,
                Callback = function(value)
                    Radar.Config.GradientEnabled = value
                    if Radar.Elements.Gradient then
                        Radar.Elements.Gradient.Enabled = value
                        if not value then
                            Radar.Elements.Border.BackgroundColor3 = Radar.Config.RadarColor
                        end
                    end
                    notify("Gradient", value and "Enabled" or "Disabled", true)
                end
            }, "GradientEnabledRadar"),
            callback = function(value)
                Radar.Config.GradientEnabled = value
                if Radar.Elements.Gradient then
                    Radar.Elements.Gradient.Enabled = value
                    if not value then
                        Radar.Elements.Border.BackgroundColor3 = Radar.Config.RadarColor
                    end
                end
                notify("Gradient", value and "Enabled" or "Disabled", true)
            end
        }

        -- Регулировка скорости градиента
        uiElements.GradientSpeedRadar = {
            element = UI.Sections.Radar:Slider({
                Name = "Gradient Speed",
                Minimum = 10,
                Maximum = 100,
                Precision = 0,
                Default = Radar.Config.GradientSpeed,
                Callback = function(value)
                    Radar.Config.GradientSpeed = value
                    notify("Gradient Speed", "Set to: " .. tostring(value), false)
                end
            }, "GradientSpeedRadar"),
            callback = function(value)
                Radar.Config.GradientSpeed = value
                notify("Gradient Speed", "Set to: " .. tostring(value), false)
            end
        }

        -- Цвет радара
        uiElements.RadarColor = {
            element = UI.Sections.Radar:Colorpicker({
                Name = "Radar Color",
                Default = Radar.Config.RadarColor,
                Callback = function(value)
                    Radar.Config.RadarColor = value
                    if Radar.Elements.Border and not Radar.Config.GradientEnabled then
                        Radar.Elements.Border.BackgroundColor3 = value
                    end
                    notify("Radar Color", "Updated", true)
                end
            }, "RadarColor"),
            callback = function(value)
                Radar.Config.RadarColor = value
                if Radar.Elements.Border and not Radar.Config.GradientEnabled then
                    Radar.Elements.Border.BackgroundColor3 = value
                end
                notify("Radar Color", "Updated", true)
            end
        }

        -- Цвет врагов
        uiElements.EnemyColor = {
            element = UI.Sections.Radar:Colorpicker({
                Name = "Enemy Color",
                Default = Radar.Config.DotColor,
                Callback = function(value)
                    Radar.Config.DotColor = value
                    for player, dot in pairs(Radar.Elements.Dots) do
                        local playerNameLower = player.Name:lower()
                        local isFriend = Core.Services.FriendsList and Core.Services.FriendsList[playerNameLower] or false
                        Radar.FriendCache.IsFriend[playerNameLower] = isFriend
                        if not isFriend then
                            dot.BackgroundColor3 = value
                        end
                    end
                    notify("Enemy Color", "Updated", true)
                end
            }, "EnemyColor"),
            callback = function(value)
                Radar.Config.DotColor = value
                for player, dot in pairs(Radar.Elements.Dots) do
                    local playerNameLower = player.Name:lower()
                    local isFriend = Core.Services.FriendsList and Core.Services.FriendsList[playerNameLower] or false
                    Radar.FriendCache.IsFriend[playerNameLower] = isFriend
                    if not isFriend then
                        dot.BackgroundColor3 = value
                    end
                end
                notify("Enemy Color", "Updated", true)
            end
        }

        -- Цвет друзей
        uiElements.FriendColor = {
            element = UI.Sections.Radar:Colorpicker({
                Name = "Friend Color",
                Default = Radar.Config.FriendColor,
                Callback = function(value)
                    Radar.Config.FriendColor = value
                    for player, dot in pairs(Radar.Elements.Dots) do
                        local playerNameLower = player.Name:lower()
                        local isFriend = Core.Services.FriendsList and Core.Services.FriendsList[playerNameLower] or false
                        Radar.FriendCache.IsFriend[playerNameLower] = isFriend
                        if isFriend then
                            dot.BackgroundColor3 = value
                        end
                    end
                    notify("Friend Color", "Updated", true)
                end
            }, "FriendColor"),
            callback = function(value)
                Radar.Config.FriendColor = value
                for player, dot in pairs(Radar.Elements.Dots) do
                    local playerNameLower = player.Name:lower()
                    local isFriend = Core.Services.FriendsList and Core.Services.FriendsList[playerNameLower] or false
                    Radar.FriendCache.IsFriend[playerNameLower] = isFriend
                    if isFriend then
                        dot.BackgroundColor3 = value
                    end
                end
                notify("Friend Color", "Updated", true)
            end
        }

        -- Цвет локального игрока
        uiElements.LocalPlayerColor = {
            element = UI.Sections.Radar:Colorpicker({
                Name = "Local Player Color",
                Default = Radar.Config.LocalPlayerColor,
                Callback = function(value)
                    Radar.Config.LocalPlayerColor = value
                    if Radar.Elements.LocalPlayerIndicator then
                        Radar.Elements.LocalPlayerIndicator.ImageColor3 = value
                    end
                    notify("Local Player Color", "Updated", true)
                end
            }, "LocalPlayerColor"),
            callback = function(value)
                Radar.Config.LocalPlayerColor = value
                if Radar.Elements.LocalPlayerIndicator then
                    Radar.Elements.LocalPlayerIndicator.ImageColor3 = value
                end
                notify("Local Player Color", "Updated", true)
            end
        }

        -- Цвет перекрестия
        uiElements.CrosshairColor = {
            element = UI.Sections.Radar:Colorpicker({
                Name = "Crosshair Color",
                Default = Radar.Config.CrosshairColor,
                Callback = function(value)
                    Radar.Config.CrosshairColor = value
                    if Radar.Elements.CrosshairVertical then
                        Radar.Elements.CrosshairVertical.BackgroundColor3 = value
                    end
                    if Radar.Elements.CrosshairHorizontal then
                        Radar.Elements.CrosshairHorizontal.BackgroundColor3 = value
                    end
                    notify("Crosshair Color", "Updated", true)
                end
            }, "CrosshairColor"),
            callback = function(value)
                Radar.Config.CrosshairColor = value
                if Radar.Elements.CrosshairVertical then
                    Radar.Elements.CrosshairVertical.BackgroundColor3 = value
                end
                if Radar.Elements.CrosshairHorizontal then
                    Radar.Elements.CrosshairHorizontal.BackgroundColor3 = value
                end
                notify("Crosshair Color", "Updated", true)
            end
        }
    end

    -- Создание секции Radar Config в табе Config
    if UI.Tabs.Config then
        if not UI.Sections.RadarConfig then
            UI.Sections.RadarConfig = UI.Tabs.Config:Section({ Name = "Radar Config", Side = "Right" })
        end

        if UI.Sections.RadarConfig then
            UI.Sections.RadarConfig:Header({ Name = "Radar Settings Sync" })

            UI.Sections.RadarConfig:Button({
                Name = "Sync Settings",
                Callback = function()
                    uiElements.RDEnabled.callback(uiElements.RDEnabled.element:GetState())
                    uiElements.RDScale.callback(uiElements.RDScale.element:GetValue())
                    uiElements.RDSize.callback(uiElements.RDSize.element:GetValue())
                    uiElements.DTSize.callback(uiElements.DTSize.element:GetValue())
                    uiElements.BackgroundTransperencyRD.callback(uiElements.BackgroundTransperencyRD.element:GetValue())
                    uiElements.ShowDebugLabelsRD.callback(uiElements.ShowDebugLabelsRD.element:GetState())
                    uiElements.GradientEnabledRadar.callback(uiElements.GradientEnabledRadar.element:GetState())
                    uiElements.GradientSpeedRadar.callback(uiElements.GradientSpeedRadar.element:GetValue())
                    uiElements.RadarColor.callback(uiElements.RadarColor.element:GetColor())
                    uiElements.EnemyColor.callback(uiElements.EnemyColor.element:GetColor())
                    uiElements.FriendColor.callback(uiElements.FriendColor.element:GetColor())
                    uiElements.LocalPlayerColor.callback(uiElements.LocalPlayerColor.element:GetColor())
                    uiElements.CrosshairColor.callback(uiElements.CrosshairColor.element:GetColor())

                    notify("Radar", "Settings synchronized with UI!", true)
                end
            }, 'SyncSettingsRadar')
        end
    end
end

return module
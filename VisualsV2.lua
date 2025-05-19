local Visuals = {}

function Visuals.Init(UI, Core, notify)
    local State = {
        MenuButton = { Enabled = false, Dragging = false, DragStart = nil, StartPos = nil, TouchStartTime = 0, TouchThreshold = 0.2 },
        Watermark = { Enabled = true, GradientTime = 0, FrameCount = 0, AccumulatedTime = 0, Dragging = false, DragStart = nil, StartPos = nil, LastTimeUpdate = 0, TimeUpdateInterval = 1 }
    }

    local WatermarkConfig = {
        gradientSpeed = 2,
        segmentCount = 12,
        showFPS = true,
        showTime = true,
        updateInterval = 0.5,
        gradientUpdateInterval = 0.1
    }

    local ESP = {
        Settings = {
            Enabled = { Value = false, Default = false },
            EnemyColor = { Value = Color3.fromRGB(255, 0, 0), Default = Color3.fromRGB(255, 0, 0) },
            FriendColor = { Value = Color3.fromRGB(0, 255, 0), Default = Color3.fromRGB(0, 255, 0) },
            TeamCheck = { Value = true, Default = true },
            Thickness = { Value = 1, Default = 1 },
            Transparency = { Value = 0.2, Default = 0.2 },
            TextSize = { Value = 14, Default = 14 },
            TextFont = { Value = Drawing.Fonts.Plex, Default = Drawing.Fonts.Plex },
            TextMethod = { Value = "Drawing", Default = "Drawing" },
            ShowBox = { Value = true, Default = true },
            ShowNames = { Value = true, Default = true },
            GradientEnabled = { Value = false, Default = false },
            FilledEnabled = { Value = false, Default = false },
            FilledTransparency = { Value = 0.5, Default = 0.5 },
            GradientSpeed = { Value = 2, Default = 2 },
            CornerRadius = { Value = 0, Default = 0 },
            HealthBarEnabled = { Value = false, Default = false },
            BarMethod = { Value = "Left", Default = "Left" }
        },
        Elements = {},
        GuiElements = {},
        LastNotificationTime = 0,
        NotificationDelay = 5,
        CloseDistance = 300,
        NearFPS = 50,
        DefaultFPS = 30
    }

    local Cache = { TextBounds = {}, LastGradientUpdate = 0, PlayerCache = {}, LastUpdateTimes = {} }
    local Elements = { Watermark = {} }

    local buttonGui = Instance.new("ScreenGui")
    buttonGui.Name = "MenuToggleButtonGui"
    buttonGui.Parent = Core.Services.CoreGuiService
    buttonGui.ResetOnSpawn = false
    buttonGui.IgnoreGuiInset = false

    local buttonFrame = Instance.new("Frame")
    buttonFrame.Size = UDim2.new(0, 50, 0, 50)
    buttonFrame.Position = UDim2.new(0, 100, 0, 100)
    buttonFrame.BackgroundColor3 = Color3.fromRGB(20, 30, 50)
    buttonFrame.BackgroundTransparency = 0.3
    buttonFrame.BorderSizePixel = 0
    buttonFrame.Visible = State.MenuButton.Enabled
    buttonFrame.Parent = buttonGui

    Instance.new("UICorner", buttonFrame).CornerRadius = UDim.new(0.5, 0)

    local buttonIcon = Instance.new("ImageLabel")
    buttonIcon.Size = UDim2.new(0, 30, 0, 30)
    buttonIcon.Position = UDim2.new(0.5, -15, 0.5, -15)
    buttonIcon.BackgroundTransparency = 1
    buttonIcon.Image = "rbxassetid://18821914323"
    buttonIcon.Parent = buttonFrame

    local function emulateRightControl()
        pcall(function()
            local vim = game:GetService("VirtualInputManager")
            vim:SendKeyEvent(true, Enum.KeyCode.RightControl, false, game)
            task.wait()
            vim:SendKeyEvent(false, Enum.KeyCode.RightControl, false, game)
        end)
    end

    buttonFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            State.MenuButton.TouchStartTime = tick()
            local mousePos = input.UserInputType == Enum.UserInputType.Touch and input.Position or Core.Services.UserInputService:GetMouseLocation()
            if mousePos then
                State.MenuButton.Dragging = true
                State.MenuButton.DragStart = mousePos
                State.MenuButton.StartPos = buttonFrame.Position
            end
        end
    end)

    Core.Services.UserInputService.InputChanged:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) and State.MenuButton.Dragging then
            local mousePos = input.UserInputType == Enum.UserInputType.Touch and input.Position or Core.Services.UserInputService:GetMouseLocation()
            if mousePos then
                local delta = mousePos - State.MenuButton.DragStart
                buttonFrame.Position = UDim2.new(0, State.MenuButton.StartPos.X.Offset + delta.X, 0, State.MenuButton.StartPos.Y.Offset + delta.Y)
            end
        end
    end)

    buttonFrame.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            State.MenuButton.Dragging = false
            if tick() - State.MenuButton.TouchStartTime < State.MenuButton.TouchThreshold then
                emulateRightControl()
            end
        end
    end)

    local function createFrameWithPadding(parent, size, backgroundColor, transparency)
        local frame = Instance.new("Frame")
        frame.Size = size
        frame.BackgroundColor3 = backgroundColor
        frame.BackgroundTransparency = transparency
        frame.BorderSizePixel = 0
        frame.Parent = parent
        Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 5)
        local padding = Instance.new("UIPadding")
        padding.PaddingLeft = UDim.new(0, 5)
        padding.PaddingRight = UDim.new(0, 5)
        padding.Parent = frame
        return frame
    end

    local function initWatermark()
        local elements = Elements.Watermark
        local savedPosition = elements.Container and elements.Container.Position or UDim2.new(0, 350, 0, 10)
        if elements.Gui then elements.Gui:Destroy() end
        elements = {}
        Elements.Watermark = elements

        local gui = Instance.new("ScreenGui")
        gui.Name = "WaterMarkGui"
        gui.ResetOnSpawn = false
        gui.IgnoreGuiInset = true
        gui.Enabled = State.Watermark.Enabled
        gui.Parent = Core.Services.CoreGuiService
        elements.Gui = gui

        local container = Instance.new("Frame")
        container.Size = UDim2.new(0, 0, 0, 30)
        container.Position = savedPosition
        container.BackgroundTransparency = 1
        container.Parent = gui
        elements.Container = container

        local layout = Instance.new("UIListLayout")
        layout.FillDirection = Enum.FillDirection.Horizontal
        layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
        layout.VerticalAlignment = Enum.VerticalAlignment.Center
        layout.Padding = UDim.new(0, 5)
        layout.Parent = container

        local logoBackground = createFrameWithPadding(container, UDim2.new(0, 28, 0, 28), Color3.fromRGB(20, 30, 50), 0.3)
        elements.LogoBackground = logoBackground

        local logoFrame = Instance.new("Frame")
        logoFrame.Size = UDim2.new(0, 20, 0, 20)
        logoFrame.Position = UDim2.new(0.5, -10, 0.5, -10)
        logoFrame.BackgroundTransparency = 1
        logoFrame.Parent = logoBackground
        elements.LogoFrame = logoFrame

        local logoConstraint = Instance.new("UISizeConstraint")
        logoConstraint.MaxSize = Vector2.new(28, 28)
        logoConstraint.MinSize = Vector2.new(28, 28)
        logoConstraint.Parent = logoBackground

        elements.LogoSegments = {}
        local segmentCount = math.max(1, WatermarkConfig.segmentCount)
        for i = 1, segmentCount do
            local segment = Instance.new("ImageLabel")
            segment.Size = UDim2.new(1, 0, 1, 0)
            segment.BackgroundTransparency = 1
            segment.Image = "rbxassetid://7151778302"
            segment.ImageTransparency = 0.4
            segment.Rotation = (i - 1) * (360 / segmentCount)
            segment.Parent = logoFrame
            Instance.new("UICorner", segment).CornerRadius = UDim.new(0.5, 0)
            local gradient = Instance.new("UIGradient")
            gradient.Color = ColorSequence.new(Core.GradientColors.Color1.Value, Core.GradientColors.Color2.Value)
            gradient.Rotation = (i - 1) * (360 / segmentCount)
            gradient.Parent = segment
            elements.LogoSegments[i] = { Segment = segment, Gradient = gradient }
        end

        local playerNameFrame = createFrameWithPadding(container, UDim2.new(0, 0, 0, 20), Color3.fromRGB(20, 30, 50), 0.3)
        elements.PlayerNameFrame = playerNameFrame

        local playerNameLabel = Instance.new("TextLabel")
        playerNameLabel.Size = UDim2.new(0, 0, 1, 0)
        playerNameLabel.BackgroundTransparency = 1
        playerNameLabel.Text = Core.PlayerData.LocalPlayer.Name
        playerNameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        playerNameLabel.TextSize = 14
        playerNameLabel.Font = Enum.Font.GothamBold
        playerNameLabel.TextXAlignment = Enum.TextXAlignment.Center
        playerNameLabel.Parent = playerNameFrame
        elements.PlayerNameLabel = playerNameLabel
        Cache.TextBounds.PlayerName = playerNameLabel.TextBounds.X

        if WatermarkConfig.showFPS then
            local fpsFrame = createFrameWithPadding(container, UDim2.new(0, 0, 0, 20), Color3.fromRGB(20, 30, 50), 0.3)
            elements.FPSFrame = fpsFrame

            local fpsContainer = Instance.new("Frame")
            fpsContainer.Size = UDim2.new(0, 0, 0, 20)
            fpsContainer.BackgroundTransparency = 1
            fpsContainer.Parent = fpsFrame
            elements.FPSContainer = fpsContainer

            local fpsLayout = Instance.new("UIListLayout")
            fpsLayout.FillDirection = Enum.FillDirection.Horizontal
            fpsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
            fpsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
            fpsLayout.Padding = UDim.new(0, 4)
            fpsLayout.Parent = fpsContainer

            local fpsIcon = Instance.new("ImageLabel")
            fpsIcon.Size = UDim2.new(0, 14, 0, 14)
            fpsIcon.BackgroundTransparency = 1
            fpsIcon.Image = "rbxassetid://8587689304"
            fpsIcon.ImageTransparency = 0.3
            fpsIcon.Parent = fpsContainer
            elements.FPSIcon = fpsIcon

            local fpsLabel = Instance.new("TextLabel")
            fpsLabel.BackgroundTransparency = 1
            fpsLabel.Text = "0 FPS"
            fpsLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
            fpsLabel.TextSize = 14
            fpsLabel.Font = Enum.Font.Gotham
            fpsLabel.TextXAlignment = Enum.TextXAlignment.Left
            fpsLabel.Size = UDim2.new(0, 0, 0, 20)
            fpsLabel.Parent = fpsContainer
            elements.FPSLabel = fpsLabel
            Cache.TextBounds.FPS = fpsLabel.TextBounds.X
        end

        if WatermarkConfig.showTime then
            local timeFrame = createFrameWithPadding(container, UDim2.new(0, 0, 0, 20), Color3.fromRGB(20, 30, 50), 0.3)
            elements.TimeFrame = timeFrame

            local timeContainer = Instance.new("Frame")
            timeContainer.Size = UDim2.new(0, 0, 0, 20)
            timeContainer.BackgroundTransparency = 1
            timeContainer.Parent = timeFrame
            elements.TimeContainer = timeContainer

            local timeLayout = Instance.new("UIListLayout")
            timeLayout.FillDirection = Enum.FillDirection.Horizontal
            timeLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
            timeLayout.VerticalAlignment = Enum.VerticalAlignment.Center
            timeLayout.Padding = UDim.new(0, 4)
            timeLayout.Parent = timeContainer

            local timeIcon = Instance.new("ImageLabel")
            timeIcon.Size = UDim2.new(0, 14, 0, 14)
            timeIcon.BackgroundTransparency = 1
            timeIcon.Image = "rbxassetid://4034150594"
            timeIcon.ImageTransparency = 0.3
            timeIcon.Parent = timeContainer
            elements.TimeIcon = timeIcon

            local timeLabel = Instance.new("TextLabel")
            timeLabel.Size = UDim2.new(0, 0, 0, 20)
            timeLabel.BackgroundTransparency = 1
            timeLabel.Text = "00:00:00"
            timeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            timeLabel.TextSize = 14
            timeLabel.Font = Enum.Font.Gotham
            timeLabel.TextXAlignment = Enum.TextXAlignment.Left
            timeLabel.Parent = timeContainer
            elements.TimeLabel = timeLabel
            Cache.TextBounds.Time = timeLabel.TextBounds.X
        end

        local function updateSizes()
            local playerNameWidth = Cache.TextBounds.PlayerName or elements.PlayerNameLabel.TextBounds.X
            elements.PlayerNameLabel.Size = UDim2.new(0, playerNameWidth, 1, 0)
            elements.PlayerNameFrame.Size = UDim2.new(0, playerNameWidth + 10, 0, 20)

            if WatermarkConfig.showFPS and elements.FPSContainer then
                local fpsWidth = Cache.TextBounds.FPS or elements.FPSLabel.TextBounds.X
                elements.FPSLabel.Size = UDim2.new(0, fpsWidth, 0, 20)
                local fpsContainerWidth = elements.FPSIcon.Size.X.Offset + fpsWidth + elements.FPSContainer:FindFirstChild("UIListLayout").Padding.Offset
                elements.FPSContainer.Size = UDim2.new(0, fpsContainerWidth, 0, 20)
                elements.FPSFrame.Size = UDim2.new(0, fpsContainerWidth + 30, 0, 20)
            end

            if WatermarkConfig.showTime and elements.TimeContainer then
                local timeWidth = Cache.TextBounds.Time or elements.TimeLabel.TextBounds.X
                elements.TimeLabel.Size = UDim2.new(0, timeWidth, 0, 20)
                local timeContainerWidth = elements.TimeIcon.Size.X.Offset + timeWidth + elements.TimeContainer:FindFirstChild("UIListLayout").Padding.Offset
                elements.TimeContainer.Size = UDim2.new(0, timeContainerWidth, 0, 20)
                elements.TimeFrame.Size = UDim2.new(0, timeContainerWidth + 10, 0, 20)
            end

            local totalWidth, visibleChildren = 0, 0
            for _, child in ipairs(container:GetChildren()) do
                if child:IsA("GuiObject") and child.Visible then
                    totalWidth = totalWidth + child.Size.X.Offset
                    visibleChildren = visibleChildren + 1
                end
            end
            totalWidth = totalWidth + (layout.Padding.Offset * math.max(0, visibleChildren - 1))
            container.Size = UDim2.new(0, totalWidth, 0, 30)
        end

        updateSizes()
        for _, label in pairs({elements.PlayerNameLabel, elements.FPSLabel, elements.TimeLabel}) do
            if label then
                label:GetPropertyChangedSignal("TextBounds"):Connect(function()
                    Cache.TextBounds[label.Name] = label.TextBounds.X
                    updateSizes()
                end)
            end
        end
    end

    local function updateGradientCircle(deltaTime)
        if not State.Watermark.Enabled or not Elements.Watermark.LogoSegments then return end
        Cache.LastGradientUpdate = Cache.LastGradientUpdate + deltaTime
        if Cache.LastGradientUpdate < WatermarkConfig.gradientUpdateInterval then return end

        State.Watermark.GradientTime = State.Watermark.GradientTime + Cache.LastGradientUpdate
        Cache.LastGradientUpdate = 0
        local t = (math.sin(State.Watermark.GradientTime / WatermarkConfig.gradientSpeed * 2 * math.pi) + 1) / 2
        local color1, color2 = Core.GradientColors.Color1.Value, Core.GradientColors.Color2.Value
        for _, segmentData in ipairs(Elements.Watermark.LogoSegments) do
            segmentData.Gradient.Color = ColorSequence.new(color1:Lerp(color2, t), color2:Lerp(color1, t))
        end
    end

    local function setWatermarkVisibility(visible)
        State.Watermark.Enabled = visible
        if Elements.Watermark.Gui then Elements.Watermark.Gui.Enabled = visible end
    end

    local function handleWatermarkInput(input)
        local target, element = State.Watermark, Elements.Watermark.Container
        local mousePos

        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            if input.UserInputState == Enum.UserInputState.Begin then
                mousePos = Core.Services.UserInputService:GetMouseLocation()
                if element and mousePos.X >= element.Position.X.Offset and mousePos.X <= element.Position.X.Offset + element.Size.X.Offset and
                   mousePos.Y >= element.Position.Y.Offset and mousePos.Y <= element.Position.Y.Offset + element.Size.Y.Offset then
                    target.Dragging = true
                    target.DragStart = mousePos
                    target.StartPos = element.Position
                end
            elseif input.UserInputState == Enum.UserInputState.End then
                target.Dragging = false
            end
        elseif input.UserInputType == Enum.UserInputType.MouseMovement and target.Dragging then
            mousePos = Core.Services.UserInputService:GetMouseLocation()
            local delta = mousePos - target.DragStart
            element.Position = UDim2.new(0, target.StartPos.X.Offset + delta.X, 0, target.StartPos.Y.Offset + delta.Y)
        elseif input.UserInputType == Enum.UserInputType.Touch then
            mousePos = input.Position
            if input.UserInputState == Enum.UserInputState.Begin then
                if element and mousePos.X >= element.Position.X.Offset and mousePos.X <= element.Position.X.Offset + element.Size.X.Offset and
                   mousePos.Y >= element.Position.Y.Offset and mousePos.Y <= element.Position.Y.Offset + element.Size.Y.Offset then
                    target.Dragging = true
                    target.DragStart = mousePos
                    target.StartPos = element.Position
                end
            elseif input.UserInputState == Enum.UserInputState.Change and target.Dragging then
                local delta = mousePos - target.DragStart
                element.Position = UDim2.new(0, target.StartPos.X.Offset + delta.X, 0, target.StartPos.Y.Offset + delta.Y)
            elseif input.UserInputState == Enum.UserInputState.End then
                target.Dragging = false
            end
        end
    end

    Core.Services.UserInputService.InputBegan:Connect(handleWatermarkInput)
    Core.Services.UserInputService.InputChanged:Connect(handleWatermarkInput)
    Core.Services.UserInputService.InputEnded:Connect(handleWatermarkInput)

    task.defer(initWatermark)

    Core.Services.RunService.Heartbeat:Connect(function(deltaTime)
        if not State.Watermark.Enabled then return end
        updateGradientCircle(deltaTime)
        if WatermarkConfig.showFPS and Elements.Watermark.FPSLabel then
            State.Watermark.FrameCount = State.Watermark.FrameCount + 1
            State.Watermark.AccumulatedTime = State.Watermark.AccumulatedTime + deltaTime
            if State.Watermark.AccumulatedTime >= WatermarkConfig.updateInterval then
                Elements.Watermark.FPSLabel.Text = tostring(math.floor(State.Watermark.FrameCount / State.Watermark.AccumulatedTime)) .. " FPS"
                State.Watermark.FrameCount = 0
                State.Watermark.AccumulatedTime = 0
            end
        end
        if WatermarkConfig.showTime and Elements.Watermark.TimeLabel then
            local currentTime = tick()
            if currentTime - State.Watermark.LastTimeUpdate >= State.Watermark.TimeUpdateInterval then
                local timeData = os.date("*t")
                Elements.Watermark.TimeLabel.Text = string.format("%02d:%02d:%02d", timeData.hour, timeData.min, timeData.sec)
                State.Watermark.LastTimeUpdate = currentTime
            end
        end
    end)

    local ESPGui = Instance.new("ScreenGui")
    ESPGui.Name = "ESPTextGui"
    ESPGui.ResetOnSpawn = false
    ESPGui.IgnoreGuiInset = true
    ESPGui.Parent = Core.Services.CoreGuiService

    local supportsQuad = pcall(function()
        local test = Drawing.new("Quad")
        test:Remove()
    end)

    local function createESP(player)
        if ESP.Elements[player] then return end

        local esp = {
            BoxLines = {
                Top = Drawing.new("Line"),
                Bottom = Drawing.new("Line"),
                Left = Drawing.new("Line"),
                Right = Drawing.new("Line")
            },
            Filled = supportsQuad and Drawing.new("Quad") or Drawing.new("Square"),
            HealthBar = {
                Background = Drawing.new("Line"),
                Foreground = Drawing.new("Line")
            },
            NameDrawing = Drawing.new("Text"),
            NameGui = nil,
            LastPosition = nil,
            LastHealth = nil,
            LastVisible = false,
            LastIsFriend = nil,
            LastFriendsList = nil
        }

        for _, line in pairs(esp.BoxLines) do
            line.Thickness = ESP.Settings.Thickness.Value
            line.Transparency = 1 - ESP.Settings.Transparency.Value
            line.Visible = false
        end

        esp.Filled.Filled = true
        esp.Filled.Transparency = 1 - ESP.Settings.FilledTransparency.Value
        esp.Filled.Visible = false

        esp.HealthBar.Background.Thickness = ESP.Settings.Thickness.Value * 2
        esp.HealthBar.Background.Color = Color3.fromRGB(50, 50, 50)
        esp.HealthBar.Background.Transparency = 1 - ESP.Settings.Transparency.Value
        esp.HealthBar.Background.Visible = false

        esp.HealthBar.Foreground.Thickness = ESP.Settings.Thickness.Value * 2
        esp.HealthBar.Foreground.Color = Color3.fromRGB(0, 255, 0)
        esp.HealthBar.Foreground.Transparency = 1 - ESP.Settings.Transparency.Value
        esp.HealthBar.Foreground.Visible = false

        esp.NameDrawing.Size = ESP.Settings.TextSize.Value
        esp.NameDrawing.Font = ESP.Settings.TextFont.Value
        esp.NameDrawing.Center = true
        esp.NameDrawing.Outline = true
        esp.NameDrawing.Visible = false

        if ESP.Settings.TextMethod.Value == "GUI" then
            esp.NameGui = Instance.new("TextLabel")
            esp.NameGui.Size = UDim2.new(0, 200, 0, 20)
            esp.NameGui.BackgroundTransparency = 1
            esp.NameGui.TextSize = ESP.Settings.TextSize.Value
            esp.NameGui.Font = Enum.Font.Gotham
            esp.NameGui.TextColor3 = Color3.fromRGB(255, 255, 255)
            esp.NameGui.TextStrokeTransparency = 0
            esp.NameGui.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
            esp.NameGui.TextXAlignment = Enum.TextXAlignment.Center
            esp.NameGui.Visible = false
            esp.NameGui.Parent = ESPGui
            ESP.GuiElements[player] = esp.NameGui
        end

        ESP.Elements[player] = esp
    end

    local function removeESP(player)
        if not ESP.Elements[player] then return end
        for _, line in pairs(ESP.Elements[player].BoxLines) do line:Remove() end
        ESP.Elements[player].Filled:Remove()
        ESP.Elements[player].HealthBar.Background:Remove()
        ESP.Elements[player].HealthBar.Foreground:Remove()
        ESP.Elements[player].NameDrawing:Remove()
        if ESP.Elements[player].NameGui then
            ESP.Elements[player].NameGui:Destroy()
            ESP.GuiElements[player] = nil
        end
        ESP.Elements[player] = nil
        Cache.PlayerCache[player] = nil
        Cache.LastUpdateTimes[player] = nil
    end

    local function updateESP()
        if not ESP.Settings.Enabled.Value then
            for _, esp in pairs(ESP.Elements) do
                for _, line in pairs(esp.BoxLines) do line.Visible = false end
                esp.Filled.Visible = false
                esp.HealthBar.Background.Visible = false
                esp.HealthBar.Foreground.Visible = false
                esp.NameDrawing.Visible = false
                if esp.NameGui then esp.NameGui.Visible = false end
                esp.LastVisible = false
            end
            return
        end

        local currentTime = tick()
        local camera = Core.PlayerData.Camera
        if not camera then return end

        local localPlayer = Core.PlayerData.LocalPlayer
        local localCharacter = localPlayer.Character
        local localRootPart = localCharacter and localCharacter:FindFirstChild("HumanoidRootPart")
        if not localRootPart then return end

        local cameraPos = camera.CFrame.Position

        for _, player in pairs(Core.Services.Players:GetPlayers()) do
            if player == localPlayer then continue end

            if not ESP.Elements[player] then
                createESP(player)
            end

            local esp = ESP.Elements[player]
            if not esp then continue end

            local character = player.Character
            local rootPart = character and character:FindFirstChild("HumanoidRootPart")
            local humanoid = character and character:FindFirstChild("Humanoid")
            local head = character and character:FindFirstChild("Head")

            if not rootPart or not humanoid or humanoid.Health <= 0 then
                if esp.LastVisible then
                    for _, line in pairs(esp.BoxLines) do line.Visible = false end
                    esp.Filled.Visible = false
                    esp.HealthBar.Background.Visible = false
                    esp.HealthBar.Foreground.Visible = false
                    esp.NameDrawing.Visible = false
                    if esp.NameGui then esp.NameGui.Visible = false end
                    esp.LastVisible = false
                end
                continue
            end

            local distance = (rootPart.Position - cameraPos).Magnitude
            local updateInterval = distance <= ESP.CloseDistance and (1 / ESP.NearFPS) or (1 / ESP.DefaultFPS)
            if currentTime - (Cache.LastUpdateTimes[player] or 0) < updateInterval then
                continue
            end
            Cache.LastUpdateTimes[player] = currentTime

            local rootPos, onScreen = camera:WorldToViewportPoint(rootPart.Position)
            if not onScreen then
                if esp.LastVisible then
                    for _, line in pairs(esp.BoxLines) do line.Visible = false end
                    esp.Filled.Visible = false
                    esp.HealthBar.Background.Visible = false
                    esp.HealthBar.Foreground.Visible = false
                    esp.NameDrawing.Visible = false
                    if esp.NameGui then esp.NameGui.Visible = false end
                    esp.LastVisible = false
                end
                continue
            end

            esp.LastVisible = true
            esp.LastPosition = rootPos
            esp.LastHealth = humanoid.Health

            local headPos = head and camera:WorldToViewportPoint(head.Position + Vector3.new(0, head.Size.Y / 2 + 0.5, 0)) or camera:WorldToViewportPoint(rootPart.Position + Vector3.new(0, 2, 0))
            local lowestPoint = rootPart.Position.Y - 4
            for _, part in pairs(character:GetChildren()) do
                if part:IsA("BasePart") then
                    local bottomY = part.Position.Y - part.Size.Y / 2
                    if bottomY < lowestPoint then lowestPoint = bottomY end
                end
            end
            local feetPos = camera:WorldToViewportPoint(Vector3.new(rootPart.Position.X, lowestPoint, rootPart.Position.Z))

            local height = math.abs(headPos.Y - feetPos.Y)
            local width = math.min(height * 0.6, 100)

            local isFriend = esp.LastIsFriend
            if esp.LastFriendsList ~= Core.Services.FriendsList or esp.LastIsFriend == nil then
                isFriend = Core.Services.FriendsList and Core.Services.FriendsList[player.Name:lower()] or false
                esp.LastIsFriend = isFriend
                esp.LastFriendsList = Core.Services.FriendsList
            end

            local baseColor = (isFriend and ESP.Settings.TeamCheck.Value) and ESP.Settings.FriendColor.Value or ESP.Settings.EnemyColor.Value
            local gradColor1, gradColor2 = Core.GradientColors.Color1.Value, (isFriend and ESP.Settings.TeamCheck.Value) and Color3.fromRGB(0, 255, 0) or Core.GradientColors.Color2.Value

            local topLeft = Vector2.new(rootPos.X - width / 2, headPos.Y)
            local topRight = Vector2.new(rootPos.X + width / 2, headPos.Y)
            local bottomLeft = Vector2.new(rootPos.X - width / 2, feetPos.Y)
            local bottomRight = Vector2.new(rootPos.X + width / 2, feetPos.Y)

            if ESP.Settings.ShowBox.Value then
                local radius = ESP.Settings.CornerRadius.Value
                if radius > 0 then
                    topLeft = topLeft + Vector2.new(radius, radius)
                    topRight = topRight + Vector2.new(-radius, radius)
                    bottomLeft = bottomLeft + Vector2.new(radius, -radius)
                    bottomRight = bottomRight + Vector2.new(-radius, -radius)
                end

                local color = baseColor
                if ESP.Settings.GradientEnabled.Value then
                    local t = (math.sin(currentTime * ESP.Settings.GradientSpeed.Value * 0.5) + 1) / 2
                    color = gradColor1:Lerp(gradColor2, t)
                end

                for _, line in pairs(esp.BoxLines) do
                    line.Color = color
                    line.Thickness = ESP.Settings.Thickness.Value
                    line.Transparency = 1 - ESP.Settings.Transparency.Value
                    line.Visible = true
                end

                esp.BoxLines.Top.From = topLeft
                esp.BoxLines.Top.To = topRight
                esp.BoxLines.Bottom.From = bottomLeft
                esp.BoxLines.Bottom.To = bottomRight
                esp.BoxLines.Left.From = topLeft
                esp.BoxLines.Left.To = bottomLeft
                esp.BoxLines.Right.From = topRight
                esp.BoxLines.Right.To = bottomRight

                if ESP.Settings.FilledEnabled.Value then
                    if supportsQuad then
                        esp.Filled.PointA = topLeft
                        esp.Filled.PointB = topRight
                        esp.Filled.PointC = bottomRight
                        esp.Filled.PointD = bottomLeft
                    else
                        esp.Filled.Position = Vector2.new(topLeft.X, topLeft.Y)
                        esp.Filled.Size = Vector2.new(bottomRight.X - topLeft.X, bottomRight.Y - topLeft.Y)
                    end
                    esp.Filled.Color = color
                    esp.Filled.Transparency = 1 - ESP.Settings.FilledTransparency.Value
                    esp.Filled.Visible = true
                else
                    esp.Filled.Visible = false
                end
            else
                for _, line in pairs(esp.BoxLines) do line.Visible = false end
                esp.Filled.Visible = false
            end

            if ESP.Settings.HealthBarEnabled.Value then
                local healthPercent = humanoid.Health / humanoid.MaxHealth
                local barColor = Color3.fromRGB(255 * (1 - healthPercent), 255 * healthPercent, 0)
                local barLength = (ESP.Settings.BarMethod.Value == "Left" or ESP.Settings.BarMethod.Value == "Right") and height or width
                local barWidth = (ESP.Settings.BarMethod.Value == "Left" or ESP.Settings.BarMethod.Value == "Right") and (width / 5) or (height / 5)
                local barStart, barEnd

                if ESP.Settings.BarMethod.Value == "Left" then
                    barStart = Vector2.new(topLeft.X - barWidth - 2, topLeft.Y)
                    barEnd = Vector2.new(topLeft.X - barWidth - 2, topLeft.Y + barLength)
                    esp.HealthBar.Background.From = barStart
                    esp.HealthBar.Background.To = barEnd
                    esp.HealthBar.Foreground.From = Vector2.new(barStart.X, barEnd.Y)
                    esp.HealthBar.Foreground.To = Vector2.new(barStart.X, barEnd.Y - barLength * healthPercent)
                elseif ESP.Settings.BarMethod.Value == "Right" then
                    barStart = Vector2.new(topRight.X + 2, topRight.Y)
                    barEnd = Vector2.new(topRight.X + 2, topRight.Y + barLength)
                    esp.HealthBar.Background.From = barStart
                    esp.HealthBar.Background.To = barEnd
                    esp.HealthBar.Foreground.From = Vector2.new(barStart.X, barEnd.Y)
                    esp.HealthBar.Foreground.To = Vector2.new(barStart.X, barEnd.Y - barLength * healthPercent)
                elseif ESP.Settings.BarMethod.Value == "Bottom" then
                    barStart = Vector2.new(topLeft.X, bottomLeft.Y + 2)
                    barEnd = Vector2.new(topRight.X, bottomRight.Y + 2)
                    esp.HealthBar.Background.From = barStart
                    esp.HealthBar.Background.To = barEnd
                    esp.HealthBar.Foreground.From = barStart
                    esp.HealthBar.Foreground.To = Vector2.new(barStart.X + barLength * healthPercent, barStart.Y)
                elseif ESP.Settings.BarMethod.Value == "Top" then
                    barStart = Vector2.new(topLeft.X, topLeft.Y - barWidth - 2)
                    barEnd = Vector2.new(topRight.X, topRight.Y - barWidth - 2)
                    esp.HealthBar.Background.From = barStart
                    esp.HealthBar.Background.To = barEnd
                    esp.HealthBar.Foreground.From = barStart
                    esp.HealthBar.Foreground.To = Vector2.new(barStart.X + barLength * healthPercent, barStart.Y)
                end

                esp.HealthBar.Background.Visible = true
                esp.HealthBar.Foreground.Color = barColor
                esp.HealthBar.Foreground.Visible = true
            else
                esp.HealthBar.Background.Visible = false
                esp.HealthBar.Foreground.Visible = false
            end

            if ESP.Settings.ShowNames.Value then
                local t = ESP.Settings.GradientEnabled.Value and (math.sin(currentTime * ESP.Settings.GradientSpeed.Value * 0.5) + 1) / 2 or 0
                local nameColor = ESP.Settings.GradientEnabled.Value and gradColor1:Lerp(gradColor2, t) or baseColor
                local nameY = headPos.Y - 20
                if ESP.Settings.HealthBarEnabled.Value and ESP.Settings.BarMethod.Value == "Top" then
                    nameY = headPos.Y - (width / 5) - 22
                end
                if ESP.Settings.TextMethod.Value == "Drawing" then
                    esp.NameDrawing.Text = player.Name
                    esp.NameDrawing.Position = Vector2.new(rootPos.X, nameY)
                    esp.NameDrawing.Color = nameColor
                    esp.NameDrawing.Size = ESP.Settings.TextSize.Value
                    esp.NameDrawing.Font = ESP.Settings.TextFont.Value
                    esp.NameDrawing.Visible = true
                    if esp.NameGui then esp.NameGui.Visible = false end
                elseif ESP.Settings.TextMethod.Value == "GUI" and esp.NameGui then
                    esp.NameGui.Text = player.Name
                    esp.NameGui.Position = UDim2.new(0, rootPos.X - 100, 0, nameY)
                    esp.NameGui.TextColor3 = nameColor
                    esp.NameGui.TextSize = ESP.Settings.TextSize.Value
                    esp.NameGui.Font = Enum.Font.Gotham
                    esp.NameGui.Visible = true
                    esp.NameDrawing.Visible = false
                end
            else
                esp.NameDrawing.Visible = false
                if esp.NameGui then esp.NameGui.Visible = false end
            end
        end
    end

    task.wait(1)
    for _, player in pairs(Core.Services.Players:GetPlayers()) do
        if player ~= Core.PlayerData.LocalPlayer then createESP(player) end
    end

    Core.Services.Players.PlayerAdded:Connect(function(player)
        if player ~= Core.PlayerData.LocalPlayer then createESP(player) end
    end)

    Core.Services.Players.PlayerRemoving:Connect(removeESP)
    Core.Services.RunService.RenderStepped:Connect(updateESP)

    if UI.Tabs and UI.Tabs.Visuals then
        if UI.Sections and UI.Sections.MenuButton then
            UI.Sections.MenuButton:Header({ Name = "Menu Button Settings" })
            UI.Sections.MenuButton:Toggle({
                Name = "Enabled",
                Default = State.MenuButton.Enabled,
                Callback = function(value)
                    State.MenuButton.Enabled = value
                    buttonFrame.Visible = value
                end
            }, 'EnabledMS')
        end

        if UI.Sections and UI.Sections.Watermark then
            UI.Sections.Watermark:Header({ Name = "Watermark Settings" })
            UI.Sections.Watermark:Toggle({
                Name = "Enabled",
                Default = State.Watermark.Enabled,
                Callback = function(value)
                    setWatermarkVisibility(value)
                    notify("Watermark", "Watermark " .. (value and "Enabled" or "Disabled"), true)
                end
            }, 'EnabledWM')
            UI.Sections.Watermark:Slider({
                Name = "Gradient Speed",
                Minimum = 0.1,
                Maximum = 3.5,
                Default = WatermarkConfig.gradientSpeed,
                Precision = 1,
                Callback = function(value)
                    WatermarkConfig.gradientSpeed = value
                    notify("Watermark", "Gradient Speed set to: " .. value)
                end
            }, 'GradientSpeedWM')
            UI.Sections.Watermark:Slider({
                Name = "Segment Count",
                Minimum = 8,
                Maximum = 16,
                Default = WatermarkConfig.segmentCount,
                Precision = 0,
                Callback = function(value)
                    WatermarkConfig.segmentCount = value
                    task.defer(initWatermark)
                    notify("Watermark", "Segment Count set to: " .. value)
                end
            }, 'SegmentCount')
            UI.Sections.Watermark:Toggle({
                Name = "Show FPS",
                Default = WatermarkConfig.showFPS,
                Callback = function(value)
                    WatermarkConfig.showFPS = value
                    task.defer(initWatermark)
                    notify("Watermark", "Show FPS " .. (value and "Enabled" or "Disabled"), true)
                end
            }, 'ShowFPS')
            UI.Sections.Watermark:Toggle({
                Name = "Show Time",
                Default = WatermarkConfig.showTime,
                Callback = function(value)
                    WatermarkConfig.showTime = value
                    task.defer(initWatermark)
                    notify("Watermark", "Show Time " .. (value and "Enabled" or "Disabled"), true)
                end
            }, 'ShowTime')
        end

        if UI.Sections and UI.Sections.ESP then
            UI.Sections.ESP:Header({ Name = "ESP Settings" })
            UI.Sections.ESP:Toggle({
                Name = "Enabled",
                Default = ESP.Settings.Enabled.Default,
                Callback = function(value)
                    ESP.Settings.Enabled.Value = value
                    if tick() - ESP.LastNotificationTime >= ESP.NotificationDelay then
                        ESP.LastNotificationTime = tick()
                        notify("ESP", "ESP " .. (value and "Enabled" or "Disabled"), true)
                    end
                end
            }, 'EnabledESP')
            UI.Sections.ESP:Colorpicker({
                Name = "Enemy Color",
                Default = ESP.Settings.EnemyColor.Default,
                Callback = function(value)
                    ESP.Settings.EnemyColor.Value = value
                    if tick() - ESP.LastNotificationTime >= ESP.NotificationDelay then
                        ESP.LastNotificationTime = tick()
                        notify("ESP", "Enemy Color set to: R=" .. math.floor(value.R * 255) .. ", G=" .. math.floor(value.G * 255) .. ", B=" .. math.floor(value.B * 255))
                    end
                end
            }, 'EnemyColor')
            UI.Sections.ESP:Colorpicker({
                Name = "Friend Color",
                Default = ESP.Settings.FriendColor.Default,
                Callback = function(value)
                    ESP.Settings.FriendColor.Value = value
                    if tick() - ESP.LastNotificationTime >= ESP.NotificationDelay then
                        ESP.LastNotificationTime = tick()
                        notify("ESP", "Friend Color set to: R=" .. math.floor(value.R * 255) .. ", G=" .. math.floor(value.G * 255) .. ", B=" .. math.floor(value.B * 255))
                    end
                end
            }, 'FriendColor')
            UI.Sections.ESP:Toggle({
                Name = "Friend Check",
                Default = ESP.Settings.TeamCheck.Default,
                Callback = function(value)
                    ESP.Settings.TeamCheck.Value = value
                    if tick() - ESP.LastNotificationTime >= ESP.NotificationDelay then
                        ESP.LastNotificationTime = tick()
                        notify("ESP", "Friend Check " .. (value and "Enabled" or "Disabled"), true)
                    end
                end
            }, 'FriendCheckESP')
            UI.Sections.ESP:Slider({
                Name = "Thickness",
                Minimum = 1,
                Maximum = 5,
                Default = ESP.Settings.Thickness.Default,
                Precision = 0,
                Callback = function(value)
                    ESP.Settings.Thickness.Value = value
                    for _, esp in pairs(ESP.Elements) do
                        for _, line in pairs(esp.BoxLines) do line.Thickness = value end
                        esp.HealthBar.Background.Thickness = value * 2
                        esp.HealthBar.Foreground.Thickness = value * 2
                    end
                    if tick() - ESP.LastNotificationTime >= ESP.NotificationDelay then
                        ESP.LastNotificationTime = tick()
                        notify("ESP", "Thickness set to: " .. value)
                    end
                end
            }, 'ThicknessESP')
            UI.Sections.ESP:Slider({
                Name = "Transparency",
                Minimum = 0,
                Maximum = 1,
                Default = ESP.Settings.Transparency.Default,
                Precision = 1,
                Callback = function(value)
                    ESP.Settings.Transparency.Value = value
                    for _, esp in pairs(ESP.Elements) do
                        for _, line in pairs(esp.BoxLines) do line.Transparency = 1 - value end
                        esp.HealthBar.Background.Transparency = 1 - value
                        esp.HealthBar.Foreground.Transparency = 1 - value
                    end
                    if tick() - ESP.LastNotificationTime >= ESP.NotificationDelay then
                        ESP.LastNotificationTime = tick()
                        notify("ESP", "Transparency set to: " .. value)
                    end
                end
            }, 'TransperencyESP')
            UI.Sections.ESP:Slider({
                Name = "Text Size",
                Minimum = 10,
                Maximum = 30,
                Default = ESP.Settings.TextSize.Default,
                Precision = 0,
                Callback = function(value)
                    ESP.Settings.TextSize.Value = value
                    for _, esp in pairs(ESP.Elements) do
                        esp.NameDrawing.Size = value
                        if esp.NameGui then esp.NameGui.TextSize = value end
                    end
                    if tick() - ESP.LastNotificationTime >= ESP.NotificationDelay then
                        ESP.LastNotificationTime = tick()
                        notify("ESP", "Text Size set to: " .. value)
                    end
                end
            }, 'TextSize')
            UI.Sections.ESP:Dropdown({
                Name = "Text Font",
                Options = {"UI", "System", "Plex", "Monospace"},
                Default = "Plex",
                Callback = function(value)
                    local fontMap = { ["UI"] = Drawing.Fonts.UI, ["System"] = Drawing.Fonts.System, ["Plex"] = Drawing.Fonts.Plex, ["Monospace"] = Drawing.Fonts.Monospace }
                    ESP.Settings.TextFont.Value = fontMap[value] or Drawing.Fonts.Plex
                    for _, esp in pairs(ESP.Elements) do esp.NameDrawing.Font = ESP.Settings.TextFont.Value end
                    if tick() - ESP.LastNotificationTime >= ESP.NotificationDelay then
                        ESP.LastNotificationTime = tick()
                        notify("ESP", "Text Font set to: " .. value .. " (only for Drawing method)", true)
                    end
                end
            }, 'TextFont')
            UI.Sections.ESP:Dropdown({
                Name = "Text Method",
                Options = {"Drawing", "GUI"},
                Default = ESP.Settings.TextMethod.Default,
                Callback = function(value)
                    ESP.Settings.TextMethod.Value = value
                    for _, player in pairs(Core.Services.Players:GetPlayers()) do
                        if player ~= Core.PlayerData.LocalPlayer then
                            removeESP(player)
                            createESP(player)
                        end
                    end
                    if tick() - ESP.LastNotificationTime >= ESP.NotificationDelay then
                        ESP.LastNotificationTime = tick()
                        notify("ESP", "Text Method set to: " .. value, true)
                    end
                end
            }, 'TextMethod')
            UI.Sections.ESP:Toggle({
                Name = "Show Box",
                Default = ESP.Settings.ShowBox.Default,
                Callback = function(value)
                    ESP.Settings.ShowBox.Value = value
                    if tick() - ESP.LastNotificationTime >= ESP.NotificationDelay then
                        ESP.LastNotificationTime = tick()
                        notify("ESP", "Box " .. (value and "Enabled" or "Disabled"), true)
                    end
                end
            }, 'ShowBox')
            UI.Sections.ESP:Toggle({
                Name = "Show Names",
                Default = ESP.Settings.ShowNames.Default,
                Callback = function(value)
                    ESP.Settings.ShowNames.Value = value
                    if tick() - ESP.LastNotificationTime >= ESP.NotificationDelay then
                        ESP.LastNotificationTime = tick()
                        notify("ESP", "Names " .. (value and "Enabled" or "Disabled"), true)
                    end
                end
            }, 'ShowNamesESP')
            UI.Sections.ESP:Toggle({
                Name = "Gradient Enabled",
                Default = ESP.Settings.GradientEnabled.Default,
                Callback = function(value)
                    ESP.Settings.GradientEnabled.Value = value
                    if tick() - ESP.LastNotificationTime >= ESP.NotificationDelay then
                        ESP.LastNotificationTime = tick()
                        notify("ESP", "Gradient " .. (value and "Enabled" or "Disabled"), true)
                    end
                end
            }, 'GradientEnabledESP')
            UI.Sections.ESP:Toggle({
                Name = "Filled Enabled",
                Default = ESP.Settings.FilledEnabled.Default,
                Callback = function(value)
                    ESP.Settings.FilledEnabled.Value = value
                    if tick() - ESP.LastNotificationTime >= ESP.NotificationDelay then
                        ESP.LastNotificationTime = tick()
                        notify("ESP", "Filled " .. (value and "Enabled" or "Disabled"), true)
                    end
                end
            }, 'FilledEnabled')
            UI.Sections.ESP:Slider({
                Name = "Filled Transparency",
                Minimum = 0,
                Maximum = 1,
                Default = ESP.Settings.FilledTransparency.Default,
                Precision = 1,
                Callback = function(value)
                    ESP.Settings.FilledTransparency.Value = value
                    for _, esp in pairs(ESP.Elements) do esp.Filled.Transparency = 1 - value end
                    if tick() - ESP.LastNotificationTime >= ESP.NotificationDelay then
                        ESP.LastNotificationTime = tick()
                        notify("ESP", "Filled Transparency set to: " .. value)
                    end
                end
            }, 'FilledTransperency')
            UI.Sections.ESP:Slider({
                Name = "Gradient Speed",
                Minimum = 1,
                Maximum = 5,
                Default = ESP.Settings.GradientSpeed.Default,
                Precision = 1,
                Callback = function(value)
                    ESP.Settings.GradientSpeed.Value = value
                    if tick() - ESP.LastNotificationTime >= ESP.NotificationDelay then
                        ESP.LastNotificationTime = tick()
                        notify("ESP", "Gradient Speed set to: " .. value)
                    end
                end
            }, 'GradientSpeed')
            UI.Sections.ESP:Slider({
                Name = "Corner Radius",
                Minimum = 0,
                Maximum = 20,
                Default = ESP.Settings.CornerRadius.Default,
                Precision = 0,
                Callback = function(value)
                    ESP.Settings.CornerRadius.Value = value
                    if tick() - ESP.LastNotificationTime >= ESP.NotificationDelay then
                        ESP.LastNotificationTime = tick()
                        notify("ESP", "Corner Radius set to: " .. value)
                    end
                end
            }, 'CornerRadius')
            UI.Sections.ESP:Toggle({
                Name = "Health Bar Enabled",
                Default = ESP.Settings.HealthBarEnabled.Default,
                Callback = function(value)
                    ESP.Settings.HealthBarEnabled.Value = value
                    if tick() - ESP.LastNotificationTime >= ESP.NotificationDelay then
                        ESP.LastNotificationTime = tick()
                        notify("ESP", "Health Bar " .. (value and "Enabled" or "Disabled"), true)
                    end
                end
            }, 'HealthBarEnabled')
            UI.Sections.ESP:Dropdown({
                Name = "Bar Method",
                Options = {"Left", "Right", "Bottom", "Top"},
                Default = ESP.Settings.BarMethod.Default,
                Callback = function(value)
                    ESP.Settings.BarMethod.Value = value
                    if tick() - ESP.LastNotificationTime >= ESP.NotificationDelay then
                        ESP.LastNotificationTime = tick()
                        notify("ESP", "Bar Method set to: " .. value, true)
                    end
                end
            }, 'BarMethod')
        end
    end
end

return Visuals

local AutoFinish = {}

function AutoFinish.Init(UI, Core, notify)
    local State = {
        AutoFinishEnabled = false
    }

    local AutoFinishConfig = {
        DistanceLimit = 30, -- Ограничение расстояния в 30 метров
        CheckInterval = 0.75, -- Проверка каждые 0.75 секунды
        DefaultHoldDuration = 0.65 -- Базовая длительность удержания
    }

    local lastCheck = 0
    local activePlayers = {}
    local playerFriendCache = {} -- Кэш для проверки друзей
    local holdingPrompts = {} -- Хранит активные удержания

    local function processPlayer(player)
        if player == Core.PlayerData.LocalPlayer then return end
        activePlayers[player] = true
    end

    for _, player in ipairs(Core.Services.Players:GetPlayers()) do
        processPlayer(player)
    end

    Core.Services.Players.PlayerAdded:Connect(function(player)
        processPlayer(player)
    end)

    Core.Services.Players.PlayerRemoving:Connect(function(player)
        activePlayers[player] = nil
        playerFriendCache[player] = nil
        holdingPrompts[player] = nil
    end)

    Core.Services.RunService.RenderStepped:Connect(function(deltaTime)
        if not State.AutoFinishEnabled then return end

        lastCheck = lastCheck + deltaTime
        if lastCheck < AutoFinishConfig.CheckInterval then return end
        lastCheck = 0

        local localChar = Core.PlayerData.LocalPlayer.Character
        local localRoot = localChar and localChar:FindFirstChild("HumanoidRootPart")
        if not (localChar and localRoot) then return end

        local localPos = localRoot.Position
        local distanceLimitSqr = AutoFinishConfig.DistanceLimit * AutoFinishConfig.DistanceLimit

        for player in pairs(activePlayers) do
            -- Пропускаем, если уже удерживаем
            if holdingPrompts[player] then continue end

            -- Проверка на друга
            local isFriend = playerFriendCache[player]
            if isFriend == nil then
                isFriend = Core.Services.FriendsList and Core.Services.FriendsList[player.Name:lower()] or false
                playerFriendCache[player] = isFriend
            end
            if isFriend then continue end

            -- Поиск персонажа в Workspace
            local character = Core.Services.Workspace:FindFirstChild(player.Name)
            if not character then continue end

            local humanoid = character:FindFirstChildOfClass("Humanoid")
            local rootPart = character:FindFirstChild("HumanoidRootPart")
            local finishPrompt = rootPart and rootPart:FindFirstChild("FinishPrompt")

            if not (humanoid and rootPart and finishPrompt and finishPrompt:IsA("ProximityPrompt")) then
                continue
            end

            if humanoid.Health <= 0 then continue end
            if not finishPrompt.Enabled then
                notify("AutoFinish", "Prompt disabled for " .. player.Name, true)
                continue
            end

            local targetPos = rootPart.Position
            local distanceSqr = (localPos - targetPos).Magnitude ^ 2
            if distanceSqr > distanceLimitSqr then continue end

            -- Определяем длительность удержания
            local holdDuration = finishPrompt.HoldDuration > 0 and finishPrompt.HoldDuration or AutoFinishConfig.DefaultHoldDuration
            -- Добавляем случайную микрозадержку (+/- 10%)
            holdDuration = holdDuration * (1 + (math.random() - 0.5) * 0.2)

            -- Начинаем удержание
            holdingPrompts[player] = finishPrompt
            pcall(function()
                finishPrompt:InputHoldBegin()
            end)

            -- Планируем завершение удержания
            task.spawn(function()
                task.wait(holdDuration)
                if holdingPrompts[player] == finishPrompt and finishPrompt.Parent then
                    pcall(function()
                        finishPrompt:InputHoldEnd()
                        -- Дополнительный вызов для завершения
                        fireproximityprompt(finishPrompt)
                    end)
                    holdingPrompts[player] = nil
                    notify("AutoFinish", "Completed prompt for " .. player.Name, true)
                else
                    notify("AutoFinish", "Prompt invalid for " .. player.Name, true)
                end
            end)
        end
    end)

    -- Создание новой секции в табе Auto
    if UI.Tabs and UI.Tabs.Auto then
        local AutoFinishSection = UI.Tabs.Auto:Section({ Name = "AutoFinish", Side = "Left" })
        if AutoFinishSection then
            AutoFinishSection:Header({ Name = "AutoFinish Settings" })
            AutoFinishSection:Toggle({
                Name = "AutoFinish Enabled",
                Default = State.AutoFinishEnabled,
                Callback = function(value)
                    State.AutoFinishEnabled = value
                    notify("AutoFinish", "AutoFinish " .. (value and "Enabled" or "Disabled"), true)
                end
            }, "AutoFinishEnabled")
        else
            warn("Failed to create AutoFinish section in Auto tab")
        end
    else
        warn("Auto tab not found in UI.Tabs")
    end
end

return AutoFinish

local AutoFinish = {}

function AutoFinish.Init(UI, Core, notify)
    local State = {
        AutoFinishEnabled = false
    }

    local AutoFinishConfig = {
        DistanceLimit = 30, -- Ограничение расстояния в 30 метров
        CheckInterval = 0.5 -- Проверка каждые 0.5 секунды
    }

    local lastCheck = 0
    local activePlayers = {}
    local playerFriendCache = {} -- Кэш для проверки друзей

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

            local targetPos = rootPart.Position
            local distanceSqr = (localPos - targetPos).Magnitude ^ 2
            if distanceSqr > distanceLimitSqr then continue end

            fireproximityprompt(finishPrompt)
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
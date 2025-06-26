local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")

-- Загрузка EntityX

local Core = nil
local UI = nil
local notify = nil

-- Конфигурация Hook Aim
local Settings = {
    Enabled = false,
    FOV = 200,
    HitChance = 100,
    TargetPart = "Head",
    TeamCheck = true,
    VisibilityCheck = true,
    PrintDelay = 0.2,
    FireDelay = 0.5,
    SortMethod = "Auto",
    LogInterval = 0.05,
    DistanceLimit = 400,
    FOVColor = Color3.fromRGB(255, 0, 0),
    Keybind = nil,
    NPCSupportEnabled = true,
    NPCMethod = "HookAim",
    SelectedTarget = "QuestAI"
}

local lastPrintTime = 0
local lastFireTime = 0
local currentTarget = nil
local lastLogTime = 0

-- Кэш для FriendsList
local Cache = {
    PlayerFriendCache = {},
    FriendsListVersion = 0
}

-- Создание FOV Circle
local fovCircle = Drawing.new("Circle")
fovCircle.Thickness = 2
fovCircle.Color = Settings.FOVColor
fovCircle.Transparency = 0.7
fovCircle.Radius = Settings.FOV
fovCircle.Visible = Settings.Enabled
fovCircle.Filled = false

-- Функция для вывода сообщений с задержкой
local function DelayedPrint(message)
    local currentTime = tick()
    if currentTime - lastPrintTime >= Settings.PrintDelay then
        print("[HookAim Debug] " .. os.date("%H:%M:%S", os.time()) .. ": " .. message)
        lastPrintTime = currentTime
    end
end

-- Проверка видимости цели (адаптировано из GetMouseHit.txt)
local function IsVisible(targetPos)
    if not Settings.VisibilityCheck then return true end
    
    local character = LocalPlayer.Character
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    if not rootPart then
        DelayedPrint("IsVisible: No root part found for local player")
        return false
    end
    
    local rayOrigin = rootPart.Position
    local rayDirection = (targetPos - rayOrigin)
    local raycastParams = RaycastParams.new()
    local filter = { workspace.Characters, workspace.Entities }
    for _, humanoid in pairs(CollectionService:GetTagged("ActiveHumanoid")) do
        table.insert(filter, humanoid)
    end
    raycastParams.FilterDescendantsInstances = filter
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    
    local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
    return not raycastResult or ((raycastResult.Position - targetPos).Magnitude < 5 or raycastResult.Instance.Name == "HumanoidRootPart")
end

-- Проверка нахождения в безопасной зоне
local function IsInSafezone(position)
    local safezone = workspace:FindFirstChild("MapProps") and workspace.MapProps:FindFirstChild("Police") and workspace.MapProps.Police:FindFirstChild("Safezone")
    if not safezone then return false end
    
    local safezonePos = safezone.Position
    local safezoneSize = safezone.Size / 2
    
    local relativePos = position - safezonePos
    return math.abs(relativePos.X) <= safezoneSize.X and
           math.abs(relativePos.Y) <= safezoneSize.Y and
           math.abs(relativePos.Z) <= safezoneSize.Z
end

-- Проверка защиты (ProtectionBubble)
local function HasProtectionBubble(player)
    if not player or not player.Character then return false end
    
    local protectionBubble = workspace:FindFirstChild("Entities") and workspace.Entities:FindFirstChild("ProtectionBubble")
    if not protectionBubble then return false end
    
    local targetPart = player.Character:FindFirstChild(Settings.TargetPart)
    if not targetPart then return false end
    
    local distance = (protectionBubble.Position - targetPart.Position).Magnitude
    return distance < 10
end

-- Проверка наличия Lasso
local function HasLasso(player)
    if not player then return false end
    
    local charactersFolder = workspace:FindFirstChild("Characters")
    if not charactersFolder then return false end
    
    local playerName = player.Name
    if not playerName then return false end
    
    local playerContainer = charactersFolder:FindFirstChild(playerName)
    if not playerContainer then return false end
    
    local fakeLimbs = playerContainer:FindFirstChild("FakeLimbs")
    return fakeLimbs ~= nil
end

-- Проверка возможности атаки игрока
local function CanAttackPlayer(player)
    if not player then
        DelayedPrint("CanAttackPlayer: No player provided")
        return false
    end
    
    if HasLasso(player) then
        DelayedPrint("CanAttackPlayer: Player " .. player.Name .. " has Lasso")
        return false
    end
    
    if not Settings.TeamCheck then
        DelayedPrint("CanAttackPlayer: TeamCheck disabled, allowing attack on " .. player.Name)
        return true
    end
    
    local myTeam = LocalPlayer.Team and LocalPlayer.Team.Name
    local theirTeam = player.Team and player.Team.Name
    
    if not myTeam or not theirTeam then
        DelayedPrint("CanAttackPlayer: Team data missing, allowing attack on " .. player.Name)
        return true
    end
    
    if HasProtectionBubble(player) then
        DelayedPrint("CanAttackPlayer: Player " .. player.Name .. " has ProtectionBubble")
        return false
    end
    
    local targetPart = player.Character and player.Character:FindFirstChild(Settings.TargetPart)
    if targetPart and IsInSafezone(targetPart.Position) then
        if theirTeam == "Wizards" or theirTeam == "Royal Wizards" then
            DelayedPrint("CanAttackPlayer: Player " .. player.Name .. " in safezone and is Wizard/Royal Wizard")
            return false
        end
        DelayedPrint("CanAttackPlayer: Player " .. player.Name .. " in safezone, allowing attack")
        return true
    end
    
    if myTeam == "Shadow Wizards" then
        DelayedPrint("CanAttackPlayer: LocalPlayer is Shadow Wizard, allowing attack on " .. player.Name)
        return true
    elseif myTeam == "Wizards" or myTeam == "Royal Wizards" then
        if theirTeam == "Wizards" or theirTeam == "Royal Wizards" then
            DelayedPrint("CanAttackPlayer: Cannot attack player " .. player.Name .. ", same team (Wizard/Royal Wizard)")
            return false
        end
        DelayedPrint("CanAttackPlayer: Allowing attack on " .. player.Name .. " (different team)")
        return true
    end
    
    DelayedPrint("CanAttackPlayer: Allowing attack on " .. player.Name)
    return true
end

-- Проверка возможности атаки NPC
local function CanAttackNPC(npc)
    if not npc then
        DelayedPrint("CanAttackNPC: No NPC provided")
        return false
    end
    local humanoid = npc:FindFirstChild("Humanoid")
    if not humanoid or humanoid.Health <= 0 then
        DelayedPrint("CanAttackNPC: NPC " .. npc.Name .. " has no Humanoid or is dead")
        return false
    end
    local owner = npc:GetAttribute("Owner")
    if owner and owner == LocalPlayer.Name then
        DelayedPrint("CanAttackNPC: NPC " .. npc.Name .. " is owned by LocalPlayer")
        return false
    end
    DelayedPrint("CanAttackNPC: Allowing attack on NPC " .. npc.Name)
    return true
end

-- Поиск ToolListener и PistolConfig
local function GetToolListener(useBackpack)
    local toolListener = nil
    local wand = nil
    local pistolConfig = nil
    
    local character = LocalPlayer.Character
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    
    if useBackpack and backpack then
        for _, item in pairs(backpack:GetChildren()) do
            if item.ClassName == "Tool" then
                wand = item
                toolListener = wand:FindFirstChild("ToolListnerEvent")
                break
            end
        end
    end
    if not toolListener and character then
        for _, item in pairs(character:GetChildren()) do
            if item.ClassName == "Tool" then
                wand = item
                toolListener = wand:FindFirstChild("ToolListnerEvent")
                break
            end
        end
    end
    
    if not toolListener or not wand then
        DelayedPrint("GetToolListener: Could not find ToolListnerEvent or wand")
        return nil, nil
    end
    
    local playerContainer = workspace:FindFirstChild("Characters") and workspace.Characters:FindFirstChild(LocalPlayer.Name)
    if playerContainer and playerContainer:FindFirstChild(wand.Name) then
        pistolConfig = playerContainer[wand.Name]:FindFirstChild("PistolConfig")
    end
    if not pistolConfig then
        DelayedPrint("GetToolListener: PistolConfig not found for " .. (wand and wand.Name or "Unknown"))
        return toolListener, nil
    end
    
    DelayedPrint("GetToolListener: Found ToolListnerEvent and PistolConfig for " .. wand.Name)
    return toolListener, pistolConfig
end

-- Поиск ближайшей цели (игроки, адаптировано из GetMouseHit.txt)
local function GetClosestPlayerTarget()
    local mousePos = UserInputService:GetMouseLocation()
    local viewportCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local validTargets = {}
    local possibleParts = {"Head", "UpperTorso", "Torso", "LeftLeg", "RightLeg"}

    for _, humanoid in pairs(CollectionService:GetTagged("ActiveHumanoid")) do
        local character = humanoid.Parent
        local player = Players:GetPlayerFromCharacter(character)
        if not player or player == LocalPlayer or character:GetAttribute("G_Cloak") then
            continue
        end

        local playerNameLower = player.Name:lower()
        local isFriend = Cache.PlayerFriendCache[playerNameLower]
        if isFriend == nil and Core and Core.Services and Core.Services.FriendsList then
            isFriend = Core.Services.FriendsList[playerNameLower] == true
            Cache.PlayerFriendCache[playerNameLower] = isFriend
            DelayedPrint("GetClosestPlayerTarget: Updated friend cache for " .. player.Name .. ": " .. tostring(isFriend))
        end
        if isFriend then
            DelayedPrint("GetClosestPlayerTarget: Excluded friend " .. player.Name .. " from targets")
            continue
        end

        local humanoidRoot = character:FindFirstChild("HumanoidRootPart")
        if not humanoidRoot or humanoid.Health <= 0 then
            continue
        end

        local distance = LocalPlayer:DistanceFromCharacter(humanoidRoot.Position)
        if distance > Settings.DistanceLimit then
            DelayedPrint("GetClosestPlayerTarget: Excluded " .. player.Name .. " due to distance (" .. math.floor(distance) .. " > " .. Settings.DistanceLimit .. ")")
            continue
        end

        local targetPart = character:FindFirstChild(Settings.TargetPart)
        if not targetPart then
            for _, partName in ipairs(possibleParts) do
                targetPart = character:FindFirstChild(partName)
                if targetPart then
                    break
                end
            end
        end

        if not targetPart then
            DelayedPrint("GetClosestPlayerTarget: No valid hitbox found for " .. player.Name)
            continue
        end

        if CanAttackPlayer(player) and IsVisible(targetPart.Position) then
            local screenPos, onScreen = Camera:WorldToScreenPoint(targetPart.Position)
            if onScreen then
                local mouseDistance = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                local fovAdjusted = Settings.FOV * (1 - math.clamp(distance / 256, 0.3, 1))
                if mouseDistance <= fovAdjusted then
                    table.insert(validTargets, {
                        Player = player,
                        MouseDistance = mouseDistance,
                        Health = humanoid.Health,
                        TargetPart = targetPart,
                        Distance = distance
                    })
                end
            end
        end
    end

    table.sort(validTargets, function(a, b)
        if Settings.SortMethod == "Distance" then
            return a.Distance < b.Distance
        elseif Settings.SortMethod == "Health" then
            return a.Health < b.Health
        elseif Settings.SortMethod == "Crosshair" then
            return a.MouseDistance < b.MouseDistance
        elseif Settings.SortMethod == "Auto" then
            local aScore = a.Health * 0.7 + a.MouseDistance * 0.3
            local bScore = b.Health * 0.7 + b.MouseDistance * 0.3
            return aScore < bScore
        end
        return a.MouseDistance < b.MouseDistance
    end)

    local target = validTargets[1] and validTargets[1].Player
    local selectedPart = validTargets[1] and validTargets[1].TargetPart
    local targetDistance = validTargets[1] and validTargets[1].Distance or math.huge
    if target then
        DelayedPrint("Targeting player: " .. target.Name .. " (Hitbox: " .. selectedPart.Name .. ", Distance: " .. math.floor(targetDistance) .. " studs)")
        return target, selectedPart, targetDistance
    end
    DelayedPrint("No valid player target found")
    return nil, nil, math.huge
end

-- Raycast (адаптировано из Raycast.txt)
local function RayCast(origin, direction, filter1, filter2, extraFilters)
    local raycastParams = RaycastParams.new()
    local filter = { filter1, filter2, workspace.Entities }
    if extraFilters then
        for _, item in pairs(extraFilters) do
            table.insert(filter, item)
        end
    end
    local iteration = 0
    while true do
        raycastParams.FilterDescendantsInstances = filter
        local result = workspace:Raycast(origin, direction, raycastParams)
        if result then
            local instance = result.Instance
            table.insert(filter, instance)
        end
        iteration = iteration + 1
        if not result or (not result.Instance.Parent:IsA("Accoutrement") or iteration >= 5) then
            return result
        end
    end
end

-- Перенаправление выстрела
local function SilentShot(target, targetPart)
    if not target or not targetPart then
        DelayedPrint("SilentShot: No target or targetPart")
        return
    end

    if not Settings.Enabled and Settings.NPCMethod == "HookAim" then
        DelayedPrint("SilentShot: Hook Aim disabled and NPCMethod is HookAim")
        return
    end

    local targetContainer = target:IsA("Player") and workspace.Characters:FindFirstChild(target.Name) or target
    if not targetContainer or not targetContainer.Parent then
        DelayedPrint("SilentShot: Invalid target container for " .. (target.Name or "Unknown"))
        return
    end

    local currentTime = tick()
    if currentTime - lastFireTime < Settings.FireDelay then
        DelayedPrint("SilentShot: Fire delay not met (" .. string.format("%.4f", currentTime - lastFireTime) .. " < " .. Settings.FireDelay .. ")")
        return
    end

    if math.random(1, 100) > Settings.HitChance then
        DelayedPrint("SilentShot: Hit chance failed (" .. Settings.HitChance .. "%)")
        return
    end

    local humanoid = targetContainer:FindFirstChild("Humanoid")
    if not humanoid then
        DelayedPrint("SilentShot: Humanoid not found for " .. (target.Name or "Unknown"))
        return
    end

    local useBackpack = Settings.NPCMethod == "SelfMode"
    local toolListener, pistolConfig = GetToolListener(useBackpack)
    if not toolListener then
        DelayedPrint("SilentShot: ToolListener not found")
        return
    end

    local originPosition = Camera.CFrame.Position
    local targetPosition = targetPart.Position
    local direction = (targetPosition - originPosition).Unit
    local hitPosition = targetPosition - direction * 1

    -- Адаптация FireRay из Raycast.txt
    local spread = pistolConfig and (pistolConfig:GetAttribute("Spread") or 0) or 0
    if LocalPlayer:GetAttribute("AimingDown") then
        spread = spread * (pistolConfig and pistolConfig:GetAttribute("Aimdown_Amp") or 0.35)
    end
    local rayDirection = direction * 256 -- Используем FireDistance из Raycast.txt
    local rayResult = RayCast(originPosition, rayDirection, LocalPlayer.Character, nil, {})
    local finalHitPosition = rayResult and rayResult.Position or (originPosition + rayDirection)
    local finalInstance = rayResult and rayResult.Instance
    local finalHumanoid = finalInstance and finalInstance.Parent:FindFirstChild("Humanoid") or humanoid

    local args = {
        [1] = "Activate",
        [2] = originPosition,
        [3] = targetPosition,
        [4] = pistolConfig or game:GetService("Players").LocalPlayer:WaitForChild("PistolConfig"),
        [5] = { hitPosition },
        [6] = {
            [1] = {
                [1] = targetPart,
                [2] = hitPosition,
                [3] = direction,
                [4] = "Humanoid"
            }
        },
        [7] = { finalHumanoid },
        [8] = {}
    }

    DelayedPrint("SilentShot: Attempting to fire at " .. (target.Name or "Unknown") .. " (Hitbox: " .. targetPart.Name .. ")")
    local success, err = pcall(function()
        toolListener:FireServer(unpack(args))
    end)

    if success then
        DelayedPrint("SilentShot: Successfully fired at " .. (target.Name or "Unknown") .. " (" .. targetPart.Name .. ")")
        lastFireTime = currentTime
        Core.GunSilentTarget.CurrentTarget = target.Name or "NPC"
    else
        DelayedPrint("SilentShot: Failed to fire - Error: " .. tostring(err))
    end
end

-- Обновление списка друзей
local function UpdateFriendsCheck()
    local currentTime = tick()
    if currentTime - lastLogTime >= Settings.LogInterval then
        if Core and Core.Services and Core.Services.FriendsList then
            local count = 0
            local friends = {}
            for name, isFriend in pairs(Core.Services.FriendsList) do
                if isFriend then
                    count = count + 1
                    table.insert(friends, name)
                end
            end
            DelayedPrint("FriendsList check: Valid, Count: " .. tostring(count) .. ", Friends: " .. (#friends > 0 and table.concat(friends, ", ") or "None"))
        else
            DelayedPrint("Error: Core or FriendsList is nil - Core: " .. tostring(Core) .. ", Services: " .. tostring(Core and Core.Services))
        end
        lastLogTime = currentTime
    end
end

-- Инициализация модуля
function Init(ui, core, notification)
    UI = ui
    Core = core
    notify = notification

    DelayedPrint("HookAim module initializing with Core: " .. tostring(Core))
    if not UI or not Core or not notify then
        DelayedPrint("Warning: UI, Core, or notification is nil during initialization")
        return
    end

    if Core and Core.Services then
        Core.Services.FriendsList = Core.Services.FriendsList or {}
        Cache.FriendsListVersion = Cache.FriendsListVersion + 1
        Cache.PlayerFriendCache = {}
        DelayedPrint("Initialized FriendsList, version: " .. Cache.FriendsListVersion)
    end

    UpdateFriendsCheck()

    UI.TabGroups = UI.TabGroups or { Main = UI.Window:TabGroup() }
    UI.Tabs = UI.Tabs or {}
    UI.Tabs.Combat = UI.TabGroups.Main:Tab({ Name = "Combat", Image = "rbxassetid://4391741881" })

    UI.Sections = UI.Sections or {}
    UI.Sections.HookAim = UI.Tabs.Combat:Section({ Name = "Hook Aim", Side = "Right" })
    UI.Sections.NPCSupport = UI.Tabs.Combat:Section({ Name = "NPC Support", Side = "Right" })

    -- Hook Aim Section
    UI.Sections.HookAim:Header({ Name = "Hook Aim" })

    UI.Sections.HookAim:Toggle({
        Name = "Enabled",
        Default = Settings.Enabled,
        Callback = function(value)
            Settings.Enabled = value
            fovCircle.Visible = value
            notify("Hook Aim", "Toggled " .. (value and "ON" or "OFF"), false)
        end
    }, "HookEnabled")

    UI.Sections.HookAim:Keybind({
        Name = "Toggle Keybind",
        Default = Settings.Keybind,
        Callback = function(key)
            Settings.Keybind = key
            notify("Hook Aim", "Keybind set to: " .. (key and key.Name or "None"), false)
        end
    }, "HookKeybind")

    UI.Sections.HookAim:Slider({
        Name = "FOV",
        Minimum = 50,
        Maximum = 500,
        Default = Settings.FOV,
        Precision = 0,
        Suffix = "s",
        Callback = function(value)
            Settings.FOV = value
            fovCircle.Radius = value
            notify("Hook Aim", "FOV set to: " .. value .. " studs", false)
        end
    }, "HookFOV")

    UI.Sections.HookAim:Colorpicker({
        Name = "FOV Circle Color",
        Default = Settings.FOVColor,
        Callback = function(value)
            Settings.FOVColor = value
            fovCircle.Color = value
            notify("Hook Aim", "FOV Circle color updated", false)
        end
    }, "HookFOVColor")

    UI.Sections.HookAim:Slider({
        Name = "Hit Chance",
        Minimum = 0,
        Maximum = 100,
        Default = Settings.HitChance,
        Precision = 0,
        Suffix = "%",
        Callback = function(value)
            Settings.HitChance = value
            notify("Hook Aim", "Hit Chance set to: " .. value .. "%", false)
        end
    }, "HookHitChance")

    UI.Sections.HookAim:Dropdown({
        Name = "Target Part",
        Options = {"Head", "UpperTorso", "Torso", "LeftLeg", "RightLeg"},
        Default = Settings.TargetPart,
        MultiSelection = false,
        Callback = function(value)
            Settings.TargetPart = value
            notify("Hook Aim", "Target Part set to: " .. value, false)
            EntityX:SetTargetPart(value)
        end
    }, "HookTargetPart")

    UI.Sections.HookAim:Toggle({
        Name = "Team Check",
        Default = Settings.TeamCheck,
        Callback = function(value)
            Settings.TeamCheck = value
            notify("Hook Aim", "Team Check " .. (value and "ON" or "OFF"), false)
        end
    }, "HookTeamCheck")

    UI.Sections.HookAim:Toggle({
        Name = "Visibility Check",
        Default = Settings.VisibilityCheck,
        Callback = function(value)
            Settings.VisibilityCheck = value
            notify("Hook Aim", "Visibility Check " .. (value and "ON" or "OFF"), falseFac
            notify("Hook Aim", "Visibility Check " .. (value and "ON" or "OFF"), false)
        end
    }, "HookVisibilityCheck")

    UI.Sections.HookAim:Slider({
        Name = "Distance Limit",
        Minimum = 50,
        Maximum = 1000,
        Default = Settings.DistanceLimit,
        Precision = 0,
        Suffix = "s",
        Callback = function(value)
            Settings.DistanceLimit = value
            EntityX:SetDistanceLimit(value)
            notify("Hook Aim", "Distance Limit set to: " .. value .. " studs", false)
        end
    }, "HookDistanceLimit")

    UI.Sections.HookAim:Slider({
        Name = "Fire Delay",
        Minimum = 0.001,
        Maximum = 2,
        Default = Settings.FireDelay,
        Precision = 2,
        Suffix = "s",
        Callback = function(value)
            Settings.FireDelay = value
            notify("Hook Aim", "Fire Delay set to: " .. value .. "s", false)
        end
    }, "HookFireDelay")

    UI.Sections.HookAim:Dropdown({
        Name = "Sort Method",
        Options = {"Distance", "Health", "Crosshair", "Auto"},
        Default = Settings.SortMethod,
        MultiSelection = false,
        Callback = function(value)
            Settings.SortMethod = value
            notify("Hook Aim", "Sort Method set to: " .. value, false)
        end
    }, "HookSortMethod")

    -- NPC Support Section
    UI.Sections.NPCSupport:Header({ Name = "NPC Support" })

    UI.Sections.NPCSupport:Toggle({
        Name = "Enabled",
        Default = Settings.NPCSupportEnabled,
        Callback = function(value)
            Settings.NPCSupportEnabled = value
            notify("NPC Support", "Toggled " .. (value and "ON" or "OFF"), false)
        end
    }, "NPCSupportEnabled")

    UI.Sections.NPCSupport:Dropdown({
        Name = "Method",
        Options = {"HookAim", "SelfMode"},
        Default = Settings.NPCMethod,
        MultiSelection = false,
        Callback = function(value)
            Settings.NPCMethod = value
            notify("NPC Support", "Method set to: " .. value, false)
        end
    }, "NPCMethod")

    UI.Sections.NPCSupport:Dropdown({
        Name = "Entities",
        Options = {"QuestAI", "SummonAI"},
        Default = Settings.SelectedTarget,
        MultiSelection = false,
        Callback = function(value)
            Settings.SelectedTarget = value
            notify("NPC Support", "Selected Target set to: " .. value, false)
        end
    }, "HookEntities")

    if Core and Core.Services then
        local lastFriendsList = Core.Services.FriendsList
        RunService.Heartbeat:Connect(function()
            if Core.Services.FriendsList ~= lastFriendsList then
                Cache.FriendsListVersion = Cache.FriendsListVersion + 1
                Cache.PlayerFriendCache = {}
                lastFriendsList = Core.Services.FriendsList
                DelayedPrint("FriendsList updated, resetting cache, new version: " .. Cache.FriendsListVersion)
            end
        end)
    end

    UserInputService.InputBegan:Connect(function(input)
        if Settings.Keybind and input.KeyCode == Settings.Keybind then
            Settings.Enabled = not Settings.Enabled
            fovCircle.Visible = Settings.Enabled
            notify("Hook Aim", "Toggled " .. (value and "ON" or "OFF"), false)
        end
    end)

    DelayedPrint("HookAim module initialized successfully")
end

-- Обновление FOV Circle и логика Hook Aim
RunService.RenderStepped:Connect(function()
    if not Settings.Enabled then
        fovCircle.Visible = false
        currentTarget = nil
        Core.GunSilentTarget.CurrentTarget = nil
        return
    end

    if not UI or not Core then
        DelayedPrint("Warning: UI or Core is nil during RenderStepped")
        return
    end

    local mousePos = UserInputService:GetMouseLocation()
    fovCircle.Position = Vector2.new(mousePos.X, mousePos.Y)
    fovCircle.Visible = Settings.Enabled

    UpdateFriendsCheck()

    local target, targetPart, targetDistance = nil, nil, math.huge
    local npcTarget, npcTargetPart, npcDistance = nil, nil, math.huge

    if Settings.Enabled then
        target, targetPart, targetDistance = GetClosestPlayerTarget()
    end

    if Settings.NPCSupportEnabled then
        npcTarget, npcTargetPart = EntityX:GetClosestNPC()
        if npcTarget and npcTargetPart and CanAttackNPC(npcTarget) and IsVisible(npcTargetPart.Position) then
            npcDistance = (Camera.CFrame.Position - npcTargetPart.Position).Magnitude
            if npcDistance <= Settings.FOV then
                DelayedPrint("Found NPC target: " .. npcTarget.Name .. " (Distance: " .. math.floor(npcDistance) .. " studs)")
            else
                DelayedPrint("NPC " .. npcTarget.Name .. " is outside FOV (" .. math.floor(npcDistance) .. " > " .. Settings.FOV .. ")")
                npcTarget, npcTargetPart = nil, nil
            end
        else
            DelayedPrint("No valid NPC target found")
            npcTarget, npcTargetPart = nil, nil
        end
    end

    if Settings.NPCSupportEnabled and Settings.NPCMethod == "SelfMode" then
        if npcTarget and npcTargetPart then
            target, targetPart = npcTarget, npcTargetPart
            DelayedPrint("Selected NPC target (SelfMode): " .. npcTarget.Name .. " (Distance: " .. math.floor(npcDistance) .. " studs)")
        else
            target, targetPart = nil, nil
            DelayedPrint("No valid NPC target selected in SelfMode")
        end
    elseif Settings.Enabled then
        if npcTarget and npcTargetPart and npcDistance <= targetDistance then
            target, targetPart = npcTarget, npcTargetPart
            DelayedPrint("Selected NPC target: " .. npcTarget.Name .. " (Distance: " .. math.floor(npcDistance) .. " studs)")
        elseif target and targetPart then
            DelayedPrint("Selected player target: " .. target.Name .. " (Distance: " .. math.floor(targetDistance) .. " studs)")
        else
            DelayedPrint("No valid target selected")
        end
    else
        DelayedPrint("No target selected: Hook Aim and NPC Support disabled or no valid targets")
    end

    currentTarget = target
    
    if target and targetPart then
        SilentShot(target, targetPart)
    else
        Core.GunSilentTarget.CurrentTarget = nil
    end
end)

-- Очистка при телепортации
game:GetService("Players").LocalPlayer.OnTeleport:Connect(function()
    fovCircle:Remove()
end)

return {
    Init = Init
}

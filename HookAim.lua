local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")

-- Загрузка EntityX
local EntityX = loadstring(game:HttpGet("https://raw.githubusercontent.com/AndreyAboba/431/refs/heads/main/EntityX.txt", true))()

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

-- Поиск ближайшей цели (игроки, адаптировано из GetMouseHit.txt)
local function GetClosestPlayerTarget()
    local mousePos = UserInputService:GetMouseLocation()
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

-- Хук RayCast (адаптировано из Raycast.txt)
local OriginalRayCast = nil
local function HookedRayCast(self, origin, direction, filter1, filter2, extraFilters)
    if not Settings.Enabled then
        return OriginalRayCast(self, origin, direction, filter1, filter2, extraFilters)
    end

    local target, targetPart = currentTarget, currentTarget and currentTarget.Character and currentTarget.Character:FindFirstChild(Settings.TargetPart)
    if not target or not targetPart then
        return OriginalRayCast(self, origin, direction, filter1, filter2, extraFilters)
    end

    local newDirection = (targetPart.Position - origin).Unit * 256
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
        local result = workspace:Raycast(origin, newDirection, raycastParams)
        if result then
            local instance = result.Instance
            table.insert(filter, instance)
        end
        iteration = iteration + 1
        if not result or (not result.Instance.Parent:IsA("Accoutrement") or iteration >= 5) then
            DelayedPrint("HookedRayCast: Redirected ray to " .. (target.Name or "NPC") .. " at " .. tostring(result and result.Position))
            return result
        end
    end
end

-- Хук FireRay (адаптировано из Raycast.txt)
local OriginalFireRay = nil
local function HookedFireRay(self, origin, character, pistolConfig, direction, shots, extraFilters)
    if not Settings.Enabled then
        return OriginalFireRay(self, origin, character, pistolConfig, direction, shots, extraFilters)
    end

    local target, targetPart = currentTarget, currentTarget and currentTarget.Character and currentTarget.Character:FindFirstChild(Settings.TargetPart)
    if not target or not targetPart then
        return OriginalFireRay(self, origin, character, pistolConfig, direction, shots, extraFilters)
    end

    if math.random(1, 100) > Settings.HitChance then
        DelayedPrint("HookedFireRay: Hit chance failed (" .. Settings.HitChance .. "%)")
        return OriginalFireRay(self, origin, character, pistolConfig, direction, shots, extraFilters)
    end

    local spread = pistolConfig and (pistolConfig:GetAttribute("Spread") or 0) or 0
    if LocalPlayer:GetAttribute("AimingDown") then
        spread = spread * (pistolConfig and pistolConfig:GetAttribute("Aimdown_Amp") or 0.35)
    end
    local newDirection = (targetPart.Position - origin).Unit * 256
    local hitPositions = {}
    local rayResults = {}
    local humanoids = {}
    local gadgets = {}

    for i = 1, shots or 1 do
        local rayResult = HookedRayCast(self, origin, newDirection, character, nil, extraFilters)
        local hitPosition = rayResult and rayResult.Position or (origin + newDirection)
        local instance = rayResult and rayResult.Instance
        local humanoid = instance and instance.Parent:FindFirstChild("Humanoid")
        local gadget = nil
        if instance and instance:GetAttribute("GadgetHealth") then
            gadget = instance
        elseif instance and (instance.Parent:GetAttribute("GadgetHealth") or instance.Parent:GetAttribute("VehicleHealth")) then
            gadget = instance.Parent
        end

        hitPositions[i] = hitPosition
        rayResults[i] = rayResult
        humanoids[i] = humanoid
        gadgets[i] = gadget
    end

    local hitData = {}
    for i, result in ipairs(rayResults) do
        if result then
            hitData[i] = {
                result.Instance,
                result.Position,
                result.Normal,
                humanoids[i] and "Humanoid" or (result.Instance:GetAttribute("HitMaterial") or result.Material.Name)
            }
        end
    end

    DelayedPrint("HookedFireRay: Redirected shot to " .. (target.Name or "NPC") .. " at " .. tostring(hitPositions[1]))
    return hitPositions, hitData, humanoids, gadgets
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

    -- Используем существующую вкладку Combat
    UI.Tabs = UI.Tabs or {}
    UI.Tabs.Combat = UI.Tabs.Combat or UI.TabGroups.Main:Tab({ Name = "Combat", Image = "rbxassetid://4391741881" })

    UI.Sections = UI.Sections or {}
    UI.Sections.HookAim = UI.Tabs.Combat:Section({ Name = "Hook Aim", Side = "Right" })
    UI.Sections.HookNPC = UI.Tabs.Combat:Section({ Name = "Hook NPC", Side = "Right" })

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

    -- Hook NPC Section
    UI.Sections.HookNPC:Header({ Name = "Hook NPC" })

    UI.Sections.HookNPC:Toggle({
        Name = "Enabled",
        Default = Settings.NPCSupportEnabled,
        Callback = function(value)
            Settings.NPCSupportEnabled = value
            notify("Hook NPC", "Toggled " .. (value and "ON" or "OFF"), false)
        end
    }, "HookNPCEnabled")

    UI.Sections.HookNPC:Dropdown({
        Name = "Method",
        Options = {"HookAim", "SelfMode"},
        Default = Settings.NPCMethod,
        MultiSelection = false,
        Callback = function(value)
            Settings.NPCMethod = value
            notify("Hook NPC", "Method set to: " .. value, false)
        end
    }, "HookNPCMethod")

    UI.Sections.HookNPC:Dropdown({
        Name = "Entities",
        Options = {"QuestAI", "SummonAI"},
        Default = Settings.SelectedTarget,
        MultiSelection = false,
        Callback = function(value)
            Settings.SelectedTarget = value
            notify("Hook NPC", "Selected Target set to: " .. value, false)
        end
    }, "HookNPCEntities")

    -- Хук функций RayCast и FireRay
    local RaycastModule = require(game:GetService("ReplicatedStorage").Modules.ToolClient.Raw.Raycast)
    OriginalRayCast = hookfunction(RaycastModule.RayCast, HookedRayCast)
    OriginalFireRay = hookfunction(RaycastModule.FireRay, HookedFireRay)
    DelayedPrint("Hooked RayCast and FireRay functions")

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
            notify("Hook Aim", "Toggled " .. (Settings.Enabled and "ON" or "OFF"), false)
        end
    end)

    DelayedPrint("HookAim module initialized successfully")
end

-- Обновление FOV Circle и выбор цели
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
        DelayedPrint("No target selected: Hook Aim and Hook NPC disabled or no valid targets")
    end

    currentTarget = target
    Core.GunSilentTarget.CurrentTarget = target and (target.Name or "NPC") or nil
end)

-- Очистка при телепортации
game:GetService("Players").LocalPlayer.OnTeleport:Connect(function()
    fovCircle:Remove()
end)

return {
    Init = Init
}

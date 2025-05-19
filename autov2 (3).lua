-- AutoV2.lua
local AutoV2 = {}

-- Module configuration
AutoV2.Config = {
    PickupMinDistance = 20,
    PickupEnabled = false,

    DropEnabled = false,
    UseKeybind = false, -- Changed default to false (no keybind by default)
    DropKeybind = Enum.KeyCode.F,
    ItemsToDrop = {
        ["shiesty"] = true,
        ["hacktoolbasic"] = true,
        ["bottle"] = true,
        ["spray can"] = true,
        ["jar"] = true,
        ["bowling pin"] = true
    },

    ReloadEnabled = false,
    BypassMethod = "ReEquip"
}

-- Module initialization
function AutoV2.Init(MacLib, Core, notify)
    local Players = Core.Services.Players
    local Workspace = Core.Services.Workspace
    local ReplicatedStorage = Core.Services.ReplicatedStorage
    local UserInputService = Core.Services.UserInputService
    local LocalPlayer = Core.PlayerData.LocalPlayer
    local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
    local Remotes = ReplicatedStorage:WaitForChild("Remotes")
    local Get = Remotes:WaitForChild("Get")
    local Send = Remotes:WaitForChild("Send")

    local GameUI = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Core"):WaitForChild("UI"))

    -- Cache v_u_4 for function increment
    local v_u_4
    for _, obj in pairs(getgc(true)) do
        if type(obj) == "table" and not getmetatable(obj) and obj.event and obj.func and type(obj.event) == "number" and type(obj.func) == "number" then
            v_u_4 = obj
            break
        end
    end
    if not v_u_4 then return end

    local droppedItems = Workspace:FindFirstChild("DroppedItems")
    if not droppedItems then return end

    local function getRootPart()
        local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        return character:WaitForChild("HumanoidRootPart")
    end

    local rootPart = getRootPart()
    LocalPlayer.CharacterAdded:Connect(function(newCharacter)
        rootPart = newCharacter:WaitForChild("HumanoidRootPart")
    end)

    local function getItemNames()
        local itemsFolder = ReplicatedStorage:FindFirstChild("Items")
        if not itemsFolder then return {} end

        local itemNames = {}
        for _, categoryName in ipairs({"ammo", "gun", "melee", "money"}) do
            local category = itemsFolder:FindFirstChild(categoryName)
            if category then
                for _, item in ipairs(category:GetChildren()) do
                    itemNames[item:IsA("StringValue") or item:IsA("ObjectValue") and (item.Value or item.Name) or item.Name] = true
                end
            end
        end
        return itemNames
    end

    local itemNames = getItemNames()
    if not next(itemNames) then return end

    -- AutoReload functions
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    LocalPlayer.CharacterAdded:Connect(function(newChar) character = newChar end)

    local function getCurrentWeapon()
        if not character then return nil end
        for _, child in ipairs(character:GetChildren()) do
            if child.ClassName == "Tool" then
                return child
            end
        end
        return nil
    end

    local function isFirearm(weapon)
        if not weapon then return false end
        return ReplicatedStorage:WaitForChild("Items"):WaitForChild("gun"):FindFirstChild(weapon.Name) ~= nil
    end

    local function getCurrentAmmoFromUI()
        local bulletsLabel = GameUI.get("Bullets")
        if not bulletsLabel then return nil end
        local text = bulletsLabel.Text
        local current = tonumber(text:match("^(%d+)/"))
        return current
    end

    local function reEquipWeapon(weapon)
        if not weapon or not character then return end
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid then return end
        humanoid:UnequipTools()
        task.wait(0.1)
        humanoid:EquipTool(weapon)
    end

    local function sendReloadEvent(weapon)
        v_u_4.func = v_u_4.func + 1
        local args = {v_u_4.func, "reload_gun", weapon}
        local success, newAmmo = pcall(Get.InvokeServer, Get, unpack(args))
        if success and newAmmo then
            local bulletsLabel = GameUI.get("Bullets")
            if bulletsLabel then
                local magSize = weapon:GetAttribute("MagSize") or 0
                bulletsLabel.Text = string.format("%d/%d", newAmmo, magSize)
                local ItemUtils = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Inventory"):WaitForChild("ItemUtils"))
                local Data = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Core"):WaitForChild("Data"))
                local itemInfo = ItemUtils.get_item_info(Data, weapon:GetAttribute("ItemGUID"))
                if itemInfo then itemInfo.ammo_amount = newAmmo end

                if AutoV2.Config.BypassMethod == "ReEquip" then
                    reEquipWeapon(weapon)
                end
            end
        end
    end

    local reloadCoroutine
    local function startAutoReload()
        if reloadCoroutine then return end
        reloadCoroutine = coroutine.create(function()
            while AutoV2.Config.ReloadEnabled do
                local weapon = getCurrentWeapon()
                if weapon and isFirearm(weapon) then
                    local currentAmmo = getCurrentAmmoFromUI()
                    if currentAmmo and currentAmmo <= 0 then
                        sendReloadEvent(weapon)
                    end
                end
                task.wait(1)
            end
            reloadCoroutine = nil
        end)
        coroutine.resume(reloadCoroutine)
    end

    local function stopAutoReload()
        AutoV2.Config.ReloadEnabled = false
        reloadCoroutine = nil
    end

    -- AutoPickup functions
    local pickupCoroutine
    local function findNearestDroppedItem()
        local currentRootPart = getRootPart()
        if not currentRootPart then return nil end
        local nearestItem, minDistance = nil, AutoV2.Config.PickupMinDistance
        local rootPosition = currentRootPart.Position
        for _, item in ipairs(droppedItems:GetChildren()) do
            if item.ClassName == "Model" and itemNames[item.Name] then
                local primaryPart = item:FindFirstChild("PrimaryPart") or item:FindFirstChildWhichIsA("BasePart")
                if primaryPart then
                    local distance = (rootPosition - primaryPart.Position).Magnitude
                    if distance <= minDistance then
                        nearestItem, minDistance = item, distance
                    end
                end
            end
        end
        return nearestItem
    end

    local function pickupDroppedItem(item)
        v_u_4.func = v_u_4.func + 1
        local args = {v_u_4.func, "pickup_dropped_item", item}
        pcall(Get.InvokeServer, Get, unpack(args))
    end

    local function startAutoPickup()
        if pickupCoroutine then return end
        pickupCoroutine = coroutine.create(function()
            while AutoV2.Config.PickupEnabled do
                local nearestItem = findNearestDroppedItem()
                if nearestItem then
                    pickupDroppedItem(nearestItem)
                end
                task.wait(0.1)
            end
            pickupCoroutine = nil
        end)
        coroutine.resume(pickupCoroutine)
    end

    local function stopAutoPickup()
        AutoV2.Config.PickupEnabled = false
        pickupCoroutine = nil
    end

    -- AutoDrop functions
    local dropCoroutine
    local function findInventory()
        local itemsFrame = PlayerGui:FindFirstChild("Items")
        if not itemsFrame then return nil end
        local itemsHolder = itemsFrame:FindFirstChild("ItemsHolder")
        if not itemsHolder then return nil end
        return itemsHolder:FindFirstChild("ItemsScrollingFrame")
    end

    local function parseInventoryData()
        local inventory = findInventory()
        if not inventory then return nil, nil end
        local guids, itemsToDrop = {}, {}
        for _, item in ipairs(inventory:GetChildren()) do
            local itemNameObj = item:FindFirstChild("ItemName")
            if not itemNameObj then continue end
            local itemName = string.lower(itemNameObj:IsA("TextLabel") and (itemNameObj.Text or "Unknown") or "Unknown")
            local guid = item.Name
            local itemCount = 1
            local itemCountObj = item:FindFirstChild("ItemCount")
            if itemCountObj and itemCountObj:IsA("TextLabel") then
                itemCount = tonumber(itemCountObj.Text:match("%d+")) or 1
            end
            if guid and AutoV2.Config.ItemsToDrop[itemName] then
                table.insert(guids, guid)
                table.insert(itemsToDrop, {GUID = guid, Item = item, Name = itemName, Count = itemCount})
                if item:IsA("GuiObject") then
                    item.BackgroundTransparency = 1
                    item.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                    item.BorderSizePixel = 0
                    item.BorderColor3 = Color3.fromRGB(0, 0, 0)
                end
            end
        end
        return guids, itemsToDrop
    end

    local function dropItems(itemsToDrop)
        if not itemsToDrop or #itemsToDrop == 0 then return false end
        for _, itemData in ipairs(itemsToDrop) do
            v_u_4.event = v_u_4.event + 1
            local args = {v_u_4.event, "drop_item", itemData.GUID, itemData.Count}
            pcall(Send.FireServer, Send, unpack(args))
        end
        return true
    end

    local function executeDrop()
        local guids, itemsToDrop = parseInventoryData()
        if guids and itemsToDrop and dropItems(itemsToDrop) then
            notify("Auto Drop", "Items dropped successfully!", true)
        end
    end

    local function startAutoDrop()
        if dropCoroutine then return end
        dropCoroutine = coroutine.create(function()
            while AutoV2.Config.DropEnabled do
                if not AutoV2.Config.UseKeybind then
                    executeDrop()
                end
                task.wait(1.5)
            end
            dropCoroutine = nil
        end)
        coroutine.resume(dropCoroutine)
    end

    local function stopAutoDrop()
        AutoV2.Config.DropEnabled = false
        dropCoroutine = nil
    end

    UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
        if input.KeyCode == AutoV2.Config.DropKeybind and not gameProcessedEvent and AutoV2.Config.UseKeybind and AutoV2.Config.DropEnabled then
            task.spawn(executeDrop)
        end
    end)

    if LocalPlayer.Character then
        character = LocalPlayer.Character
        if AutoV2.Config.ReloadEnabled then startAutoReload() end
    end
    LocalPlayer.CharacterAdded:Connect(function(newCharacter)
        character = newCharacter
        if AutoV2.Config.ReloadEnabled then startAutoReload() end
    end)

    -- UI setup with MacLib
    if MacLib and MacLib.Tabs and MacLib.Tabs.Auto then
        local autoPickupSection = MacLib.Tabs.Auto:Section({ Name = "AutoPickup", Side = "Right" })
        autoPickupSection:Header({ Name = "AutoPickup" })
        autoPickupSection:Toggle({
            Name = "Enabled",
            Default = AutoV2.Config.PickupEnabled,
            Callback = function(value)
                AutoV2.Config.PickupEnabled = value
                if value then
                    startAutoPickup()
                    notify("Auto Pickup", "Auto-pickup enabled!", true)
                else
                    stopAutoPickup()
                    notify("Auto Pickup", "Auto-pickup disabled!", true)
                end
            end
        }, 'AutoPickupEnabled')
        autoPickupSection:Slider({
            Name = "Pickup Radius",
            Default = AutoV2.Config.PickupMinDistance,
            Minimum = 5,
            Maximum = 50,
            Precision = 1,
            Callback = function(value)
                AutoV2.Config.PickupMinDistance = value
                notify("Auto Pickup", "Pickup radius set to " .. value .. " meters!", false)
            end
        }, 'PickupRadius')

        local autoDropSection = MacLib.Tabs.Auto:Section({ Name = "AutoDrop", Side = "Left" })
        autoDropSection:Header({ Name = "AutoDrop" })
        autoDropSection:Toggle({
            Name = "Enabled",
            Default = AutoV2.Config.DropEnabled,
            Callback = function(value)
                AutoV2.Config.DropEnabled = value
                if value then
                    startAutoDrop()
                    notify("Auto Drop", "Auto-drop enabled!", true)
                else
                    stopAutoDrop()
                    notify("Auto Drop", "Auto-drop disabled!", true)
                end
            end
        }, 'AutoDropEnabled')
        autoDropSection:Toggle({
            Name = "Use Keybind",
            Default = AutoV2.Config.UseKeybind,
            Callback = function(value)
                AutoV2.Config.UseKeybind = value
                if value then
                    notify("Auto Drop", "Keybind mode enabled!", true)
                else
                    notify("Auto Drop", "Keybind mode disabled!", true)
                end
            end
        }, 'UseKeybindAutoDrop')
        autoDropSection:Keybind({
            Name = "Drop Keybind",
            Default = AutoV2.Config.DropKeybind,
            Callback = function(value) AutoV2.Config.DropKeybind = value end
        }, 'DropKeybind')
        autoDropSection:Dropdown({
            Name = "Items to Drop",
            Multi = true,
            Search = true, -- Added Search = true for the dropdown
            Options = {
                "shiesty", "hacktoolbasic", "bottle", "spray can", "jar", "bowling pin",
                "bike lock", "bronze mop", "chair leg", "metal pipe", "mop", "pool cue",
                "rolling pin", "shank", "silver mop", "taser", "wooden board", "bandage",
                "bull energy", "lockpick", "dice", "brick", "cinder block", "dumbbel plate",
                "glass", "milkshake", "rock", "soda can", "mug" -- Added "mug" to the options
            },
            Default = { "shiesty", "hacktoolbasic", "bottle", "spray can", "jar", "bowling pin" },
            Callback = function(value)
                for key in pairs(AutoV2.Config.ItemsToDrop) do
                    AutoV2.Config.ItemsToDrop[key] = nil
                end
                for item, isSelected in pairs(value) do
                    if isSelected then AutoV2.Config.ItemsToDrop[item] = true end
                end
                notify("Auto Drop", "Items to drop updated!", true)
            end
        }, 'ADItemsToDrop')

        local autoReloadSection = MacLib.Tabs.Auto:Section({ Name = "AutoReload", Side = "Right" })
        autoReloadSection:Header({ Name = "AutoReload" })
        autoReloadSection:Toggle({
            Name = "Enabled",
            Default = AutoV2.Config.ReloadEnabled,
            Callback = function(value)
                AutoV2.Config.ReloadEnabled = value
                if value then
                    startAutoReload()
                    notify("Auto Reload", "Auto-reload enabled!", true)
                else
                    stopAutoReload()
                    notify("Auto Reload", "Auto-reload disabled!", true)
                end
            end
        }, 'EnabledAR')
        autoReloadSection:Dropdown({
            Name = "Bypass Method",
            Options = {"ReEquip"},
            Default = AutoV2.Config.BypassMethod,
            Callback = function(value)
                AutoV2.Config.BypassMethod = value
                notify("Auto Reload", "Bypass method set to " .. value, true)
            end
        }, 'BypassMethodAR')
    end
end

return AutoV2

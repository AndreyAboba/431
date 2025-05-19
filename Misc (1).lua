local Misc = {}

function Misc.Init(UI, Core, notify)
    if not Core.Services.FriendsList then
        Core.Services.FriendsList = {}
    end

    if not (UI.Window and UI.Tabs.Misc and UI.Sections.FriendList) then
        warn("Failed to initialize Friend List: UI components missing")
        return
    end

    -- Кэш и таймеры для оптимизации
    local Cache = {
        PlayerList = {},
        LastUpdate = 0,
        UpdateInterval = 1,
        LastFriendUpdate = 0,
        FriendUpdateThreshold = 0.5
    }

    local function getPlayerList()
        if tick() - Cache.LastUpdate < Cache.UpdateInterval then
            return Cache.PlayerList
        end

        local players = {}
        for _, player in pairs(Core.Services.Players:GetPlayers()) do
            if player ~= Core.PlayerData.LocalPlayer then
                table.insert(players, player.Name)
            end
        end

        Cache.PlayerList = players
        Cache.LastUpdate = tick()
        return players
    end

    -- Преобразуем текущий FriendsList в словарь с нормализацией имён
    local currentSelection = {}
    for _, playerName in pairs(Core.Services.FriendsList) do
        if type(playerName) == "string" then
            currentSelection[playerName:lower()] = true
        end
    end
    Core.Services.FriendsList = currentSelection

    local friendDropdown

    local function updateFriendsList(selected)
        if tick() - Cache.LastFriendUpdate < Cache.FriendUpdateThreshold then
            return
        end
        Cache.LastFriendUpdate = tick()

        local selectedPlayers = {}
        local selectedPlayersArray = {} -- Для отображения в уведомлениях
        if type(selected) == "table" then
            for key, value in pairs(selected) do
                if type(value) == "string" then
                    selectedPlayers[value:lower()] = true
                    table.insert(selectedPlayersArray, value)
                elseif type(key) == "string" and value == true then
                    selectedPlayers[key:lower()] = true
                    table.insert(selectedPlayersArray, key)
                elseif type(key) == "string" then
                    selectedPlayers[key:lower()] = true
                    table.insert(selectedPlayersArray, key)
                end
            end
        elseif type(selected) == "string" then
            selectedPlayers[selected:lower()] = true
            selectedPlayersArray = {selected}
        end

        -- Сравниваем с текущим списком
        local currentArray = {}
        for playerName, _ in pairs(Core.Services.FriendsList) do
            table.insert(currentArray, playerName)
        end
        table.sort(currentArray)
        table.sort(selectedPlayersArray)
        if #selectedPlayersArray == #currentArray and table.concat(selectedPlayersArray, ",") == table.concat(currentArray, ",") then
            return
        end

        Core.Services.FriendsList = selectedPlayers
        currentSelection = selectedPlayers

        notify("Friend List", "Updated friends: " .. (#selectedPlayersArray > 0 and table.concat(selectedPlayersArray, ", ") or "None"), true)
    end

    local function updateFriendDropdownOptions()
        if not friendDropdown then return end

        local newOptions = getPlayerList()

        -- Проверяем, изменился ли список опций
        local currentOptions = friendDropdown:GetOptions() or {}
        local optionsChanged = #newOptions ~= #currentOptions
        if not optionsChanged then
            for i, opt in ipairs(newOptions) do
                if opt ~= currentOptions[i] then
                    optionsChanged = true
                    break
                end
            end
        end

        if optionsChanged then
            friendDropdown:ClearOptions()
            friendDropdown:InsertOptions(newOptions)
        end

        -- Обновляем выбор в Dropdown, но сохраняем всех друзей из FriendsList
        local selectionArray = {}
        for playerName, _ in pairs(Core.Services.FriendsList) do
            -- Добавляем игрока в выбор, только если он сейчас в игре
            for _, option in ipairs(newOptions) do
                if option:lower() == playerName then
                    table.insert(selectionArray, option)
                    break
                end
            end
        end
        friendDropdown:UpdateSelection(selectionArray)
    end

    UI.Sections.FriendList:Header({ Name = "Friend List" })

    -- При инициализации передаём массив имён для Dropdown
    local initialSelectionArray = {}
    for playerName, _ in pairs(currentSelection) do
        table.insert(initialSelectionArray, playerName)
    end
    friendDropdown = UI.Sections.FriendList:Dropdown({
        Name = "Select Friend",
        Options = getPlayerList(),
        Multi = true,
        Default = initialSelectionArray,
        Callback = updateFriendsList
    })

    UI.Sections.FriendList:Button({
        Name = "Refresh Player List",
        Callback = function()
            Cache.LastUpdate = 0
            updateFriendDropdownOptions()
            notify("Friend List", "Player list refreshed")
        end
    })

    UI.Sections.FriendList:Button({
        Name = "Clear Friends List",
        Callback = function()
            Core.Services.FriendsList = {}
            currentSelection = {}
            friendDropdown:UpdateSelection({})
            updateFriendDropdownOptions()
            notify("Friend List", "Friends list cleared")
        end
    })

    UI.Sections.FriendList:Button({
        Name = "Show Friends List",
        Callback = function()
            local friendsArray = {}
            for playerName, _ in pairs(Core.Services.FriendsList) do
                table.insert(friendsArray, playerName)
            end
            notify("Friend List", "Current friends: " .. (#friendsArray > 0 and table.concat(friendsArray, ", ") or "None"), true)
        end
    })

    Core.Services.Players.PlayerAdded:Connect(function()
        task.defer(function()
            Cache.LastUpdate = 0
            updateFriendDropdownOptions()
        end)
    end)

    Core.Services.Players.PlayerRemoving:Connect(function(player)
        task.defer(function()
            Cache.LastUpdate = 0
            updateFriendDropdownOptions()
        end)
    end)
end

return Misc

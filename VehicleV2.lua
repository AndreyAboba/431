-- Модуль Vehicles: VehicleSpeed, VehicleFly и Vehicle Exploit
local Vehicles = {
    VehicleSpeed = {
        Settings = {
            Enabled = { Value = false, Default = false },
            SpeedBoostMultiplier = { Value = 1.65, Default = 1.65 },
            HoldSpeed = { Value = false, Default = false },
            HoldKeybind = { Value = nil, Default = nil },
            ToggleKey = { Value = nil, Default = nil }
        },
        State = {
            IsBoosting = false,
            OriginalAttributes = {},
            CurrentVehicle = nil,
            Connection = nil
        }
    },
    VehicleFly = {
        Settings = {
            Enabled = { Value = false, Default = false },
            FlySpeed = { Value = 50, Default = 50 },
            ToggleKey = { Value = nil, Default = nil }
        },
        State = {
            IsFlying = false,
            FlyBodyVelocity = nil,
            LastWheelReset = 0,
            OriginalWheelData = {},
            Connection = nil
        }
    },
    VehicleExploit = {
        Settings = {
            SelectedVehicle = { Value = nil, Default = nil }
        },
        State = {
            VehiclesList = {},
            VehicleSeats = {},
            LastUpdate = 0,
            UpdateInterval = 1 -- Интервал обновления списка машин (в секундах)
        }
    }
}

function Vehicles.Init(UI, Core, notify)
    local VehicleSpeed = Vehicles.VehicleSpeed
    local VehicleFly = Vehicles.VehicleFly
    local VehicleExploit = Vehicles.VehicleExploit
    local Players = Core.Services.Players
    local ReplicatedStorage = Core.Services.ReplicatedStorage
    local UserInputService = Core.Services.UserInputService
    local LocalPlayer = Core.PlayerData.LocalPlayer
    local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local Humanoid = Character:WaitForChild("Humanoid")
    local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
    local u5 = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Core"):WaitForChild("Net"))
    local u11 = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("VehicleSystem"):WaitForChild("Vehicle"))

    -- Общая функция: получение текущего транспорта
    local function getCurrentVehicle()
        local char = Core.PlayerData.LocalPlayer.Character
        if char and char.Humanoid and char.Humanoid.SeatPart and char.Humanoid.SeatPart:IsA("VehicleSeat") then
            local vehicle = char.Humanoid.SeatPart.Parent
            if vehicle and vehicle:IsDescendantOf(Core.Services.Workspace.Vehicles) then
                return vehicle, char.Humanoid.SeatPart
            end
        end
        return nil, nil
    end

    -- Проверка, является ли транспорт ATV
    local function isATV(vehicle)
        return vehicle and vehicle.Name:lower():find("atv") and true or false
    end

    -- Стабилизация колёс
    local function stabilizeWheels(vehicle, seat)
        if not vehicle or not seat then return end
        for _, part in ipairs(vehicle:GetDescendants()) do
            if part:IsA("BasePart") and part.Name:lower():find("wheel") then
                part.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                part.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                for _, constraint in ipairs(part:GetChildren()) do
                    if constraint:IsA("SpringConstraint") then
                        constraint.Damping = math.clamp(constraint.Damping * 1.2, 0, 1000)
                        constraint.Stiffness = math.clamp(constraint.Stiffness * 1.2, 0, 5000)
                    elseif constraint:IsA("HingeConstraint") then
                        constraint.AngularVelocity = math.clamp(constraint.AngularVelocity, -50, 50)
                    end
                end
            end
        end
    end

    -- Сброс характеристик транспорта
    local function resetVehicleAttributes(vehicle)
        if not vehicle then return end
        local motors = vehicle:FindFirstChild("Motors")
        if not motors then return end

        local attributes = VehicleSpeed.State.OriginalAttributes[vehicle]
        if attributes then
            motors:SetAttribute("forwardMaxSpeed", attributes.forwardMaxSpeed)
            motors:SetAttribute("nitroMaxSpeed", attributes.nitroMaxSpeed)
            motors:SetAttribute("acceleration", attributes.acceleration)
        end
    end

    -- Применение характеристик с учётом множителя
    local function applyVehicleAttributes(vehicle, multiplier)
        if not vehicle then return end
        local motors = vehicle:FindFirstChild("Motors")
        if not motors or not VehicleSpeed.State.OriginalAttributes[vehicle] then return end

        local effectiveMultiplier = isATV(vehicle) and math.min(multiplier, 1.55) or multiplier
        local attrs = VehicleSpeed.State.OriginalAttributes[vehicle]
        motors:SetAttribute("forwardMaxSpeed", attrs.forwardMaxSpeed * effectiveMultiplier)
        motors:SetAttribute("nitroMaxSpeed", attrs.nitroMaxSpeed * effectiveMultiplier)
        motors:SetAttribute("acceleration", attrs.acceleration * effectiveMultiplier)
    end

    -- Функции VehicleSpeed
    VehicleSpeed.Start = function()
        if VehicleSpeed.State.Connection then
            VehicleSpeed.State.Connection:Disconnect()
            VehicleSpeed.State.Connection = nil
        end

        VehicleSpeed.State.Connection = Core.Services.RunService.Heartbeat:Connect(function()
            if not VehicleSpeed.Settings.Enabled.Value then return end

            local vehicle, seat = getCurrentVehicle()
            if not vehicle then
                if VehicleSpeed.State.IsBoosting and VehicleSpeed.State.CurrentVehicle then
                    resetVehicleAttributes(VehicleSpeed.State.CurrentVehicle)
                    VehicleSpeed.State.IsBoosting = false
                    VehicleSpeed.State.CurrentVehicle = nil
                end
                return
            end

            local motors = vehicle:FindFirstChild("Motors")
            if not motors then return end

            if vehicle ~= VehicleSpeed.State.CurrentVehicle then
                if VehicleSpeed.State.CurrentVehicle then
                    resetVehicleAttributes(VehicleSpeed.State.CurrentVehicle)
                end
                VehicleSpeed.State.CurrentVehicle = vehicle
                if not VehicleSpeed.State.OriginalAttributes[vehicle] then
                    VehicleSpeed.State.OriginalAttributes[vehicle] = {
                        forwardMaxSpeed = motors:GetAttribute("forwardMaxSpeed") or 35,
                        nitroMaxSpeed = motors:GetAttribute("nitroMaxSpeed") or 105,
                        acceleration = motors:GetAttribute("acceleration") or 15
                    }
                end
            end

            local shouldBoost = VehicleSpeed.Settings.HoldSpeed.Value and Core.Services.UserInputService:IsKeyDown(VehicleSpeed.Settings.HoldKeybind.Value) or true

            if shouldBoost then
                if not VehicleSpeed.State.IsBoosting then
                    VehicleSpeed.State.IsBoosting = true
                end
                applyVehicleAttributes(vehicle, VehicleSpeed.Settings.SpeedBoostMultiplier.Value)
                stabilizeWheels(vehicle, seat)
            elseif not shouldBoost and VehicleSpeed.State.IsBoosting then
                resetVehicleAttributes(vehicle)
                VehicleSpeed.State.IsBoosting = false
            end
        end)
    end

    VehicleSpeed.Stop = function()
        if VehicleSpeed.State.Connection then
            VehicleSpeed.State.Connection:Disconnect()
            VehicleSpeed.State.Connection = nil
        end

        if VehicleSpeed.State.CurrentVehicle and VehicleSpeed.State.IsBoosting then
            resetVehicleAttributes(VehicleSpeed.State.CurrentVehicle)
        end

        VehicleSpeed.State.IsBoosting = false
        VehicleSpeed.State.CurrentVehicle = nil
        VehicleSpeed.State.OriginalAttributes = {}
    end

    VehicleSpeed.SetSpeedBoostMultiplier = function(newMultiplier)
        VehicleSpeed.Settings.SpeedBoostMultiplier.Value = newMultiplier
        if VehicleSpeed.State.IsBoosting then
            local vehicle = VehicleSpeed.State.CurrentVehicle
            if vehicle then
                applyVehicleAttributes(vehicle, newMultiplier)
            end
        end
    end

    -- Функции VehicleFly
    VehicleFly.EnableFlight = function(vehicle, seat, enable)
        if not vehicle or not seat then return end

        if enable and not VehicleFly.State.IsFlying then
            VehicleFly.State.IsFlying = true
            VehicleFly.State.FlyBodyVelocity = Instance.new("BodyVelocity")
            VehicleFly.State.FlyBodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            VehicleFly.State.FlyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
            VehicleFly.State.FlyBodyVelocity.Parent = seat

            for _, part in ipairs(vehicle:GetDescendants()) do
                if part:IsA("BasePart") and part.Name:lower():find("wheel") then
                    VehicleFly.State.OriginalWheelData[part] = {
                        Position = part.Position - seat.Position,
                        Mass = part.Mass,
                        Constraints = {}
                    }
                    for _, constraint in ipairs(part:GetChildren()) do
                        if constraint:IsA("HingeConstraint") then
                            VehicleFly.State.OriginalWheelData[part].Constraints.Hinge = {
                                TargetAngle = constraint.TargetAngle,
                                AngularVelocity = constraint.AngularVelocity
                            }
                        elseif constraint:IsA("SpringConstraint") then
                            VehicleFly.State.OriginalWheelData[part].Constraints.Spring = {
                                FreeLength = constraint.FreeLength,
                                Stiffness = constraint.Stiffness,
                                Damping = constraint.Damping
                            }
                        end
                    end
                end
            end

            seat.AssemblyLinearVelocity = Vector3.new(seat.AssemblyLinearVelocity.X, 10, seat.AssemblyLinearVelocity.Z)
        elseif not enable and VehicleFly.State.IsFlying then
            VehicleFly.State.IsFlying = false
            if VehicleFly.State.FlyBodyVelocity then
                VehicleFly.State.FlyBodyVelocity:Destroy()
                VehicleFly.State.FlyBodyVelocity = nil
            end

            local pos = seat.Position
            local _, yaw, _ = seat.CFrame:ToEulerAnglesYXZ()
            seat.CFrame = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
            seat.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            seat.AssemblyLinearVelocity = Vector3.new(0, 0, 0)

            for _, part in ipairs(vehicle:GetDescendants()) do
                if part:IsA("BasePart") and part.Name:lower():find("wheel") then
                    part.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                    part.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                    local data = VehicleFly.State.OriginalWheelData[part]
                    if data then
                        for _, constraint in ipairs(part:GetChildren()) do
                            if constraint:IsA("HingeConstraint") and data.Constraints.Hinge then
                                constraint.AngularVelocity = 0
                                constraint.TargetAngle = data.Constraints.Hinge.TargetAngle
                            elseif constraint:IsA("SpringConstraint") and data.Constraints.Spring then
                                constraint.FreeLength = data.Constraints.Spring.FreeLength
                                constraint.Stiffness = data.Constraints.Spring.Stiffness
                                constraint.Damping = data.Constraints.Spring.Damping
                            end
                        end
                    end
                end
            end

            for i = 1, 5 do
                task.wait(0.1)
                if not vehicle.Parent then break end
                for _, part in ipairs(vehicle:GetDescendants()) do
                    if part:IsA("BasePart") and part.Name:lower():find("wheel") then
                        local data = VehicleFly.State.OriginalWheelData[part]
                        if data then
                            local errorDist = (part.Position - seat.Position - data.Position).Magnitude
                            if errorDist > 0.05 and errorDist < 10 then
                                local massFactor = math.clamp(1 / (data.Mass or 1), 0.1, 1)
                                for _, constraint in ipairs(part:GetChildren()) do
                                    if constraint:IsA("SpringConstraint") then
                                        constraint.FreeLength = constraint.FreeLength - errorDist * massFactor * 0.2
                                    end
                                end
                            end
                            local roll, pitch = part.CFrame:ToEulerAnglesXYZ()
                            if math.abs(roll) > math.rad(5) or math.abs(pitch) > math.rad(5) then
                                for _, constraint in ipairs(part:GetChildren()) do
                                    if constraint:IsA("HingeConstraint") and data.Constraints.Hinge then
                                        constraint.TargetAngle = data.Constraints.Hinge.TargetAngle
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    VehicleFly.UpdateFlight = function(vehicle, seat)
        if not vehicle or not seat or not VehicleFly.State.IsFlying or not VehicleFly.State.FlyBodyVelocity then return end

        local humanoid = Core.PlayerData.LocalPlayer.Character and Core.PlayerData.LocalPlayer.Character:FindFirstChild("Humanoid")
        if not humanoid or humanoid.SeatPart ~= seat then
            VehicleFly.EnableFlight(vehicle, seat, false)
            return
        end

        local look = Core.PlayerData.Camera.CFrame.LookVector
        local right = Core.PlayerData.Camera.CFrame.RightVector
        local moveDir = Vector3.new(0, 0, 0)

        if Core.Services.UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + look end
        if Core.Services.UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - look end
        if Core.Services.UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - right end
        if Core.Services.UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + right end
        if Core.Services.UserInputService:IsKeyDown(Enum.KeyCode.E) then moveDir = moveDir + Vector3.new(0, 1, 0) end
        if Core.Services.UserInputService:IsKeyDown(Enum.KeyCode.Q) then moveDir = moveDir - Vector3.new(0, 1, 0) end

        VehicleFly.State.FlyBodyVelocity.Velocity = moveDir.Magnitude > 0 and moveDir.Unit * VehicleFly.Settings.FlySpeed.Value or Vector3.new(0, 0, 0)

        local pos = seat.Position
        local flatLook = Vector3.new(look.X, 0, look.Z).Unit
        seat.CFrame = CFrame.new(pos, pos + flatLook)

        if tick() - VehicleFly.State.LastWheelReset > 0.05 then
            VehicleFly.State.LastWheelReset = tick()
            for _, part in ipairs(vehicle:GetDescendants()) do
                if part:IsA("BasePart") and part.Name:lower():find("wheel") then
                    part.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                    part.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                    local data = VehicleFly.State.OriginalWheelData[part]
                    if data then
                        local errorDist = (part.Position - seat.Position - data.Position).Magnitude
                        if errorDist > 0.05 and errorDist < 10 then
                            local massFactor = math.clamp(1 / (data.Mass or 1), 0.1, 1)
                            for _, constraint in ipairs(part:GetChildren()) do
                                if constraint:IsA("SpringConstraint") then
                                    constraint.FreeLength = constraint.FreeLength - errorDist * massFactor * 0.2
                                end
                            end
                        end
                        local roll, pitch = part.CFrame:ToEulerAnglesXYZ()
                        if math.abs(roll) > math.rad(5) or math.abs(pitch) > math.rad(5) then
                            for _, constraint in ipairs(part:GetChildren()) do
                                if constraint:IsA("HingeConstraint") and data.Constraints.Hinge then
                                    constraint.AngularVelocity = 0
                                    constraint.TargetAngle = data.Constraints.Hinge.TargetAngle
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    VehicleFly.Start = function()
        if VehicleFly.State.Connection then
            VehicleFly.State.Connection:Disconnect()
            VehicleFly.State.Connection = nil
        end

        VehicleFly.State.Connection = Core.Services.RunService.Heartbeat:Connect(function()
            if not VehicleFly.Settings.Enabled.Value then return end

            local vehicle, seat = getCurrentVehicle()
            if vehicle and seat then
                if not VehicleFly.State.IsFlying then
                    VehicleFly.EnableFlight(vehicle, seat, true)
                end
                VehicleFly.UpdateFlight(vehicle, seat)
            else
                if VehicleFly.State.IsFlying then
                    local lastVehicle, lastSeat = getCurrentVehicle()
                    if lastVehicle and lastSeat then
                        VehicleFly.EnableFlight(lastVehicle, lastSeat, false)
                    end
                end
            end
        end)

        notify("VehicleFly", "Started with FlySpeed: " .. VehicleFly.Settings.FlySpeed.Value, true)
    end

    VehicleFly.Stop = function()
        if VehicleFly.State.Connection then
            VehicleFly.State.Connection:Disconnect()
            VehicleFly.State.Connection = nil
        end

        local vehicle, seat = getCurrentVehicle()
        if vehicle and seat and VehicleFly.State.IsFlying then
            VehicleFly.EnableFlight(vehicle, seat, false)
        end

        VehicleFly.State.IsFlying = false
        VehicleFly.State.OriginalWheelData = {}
        notify("VehicleFly", "Stopped", true)
    end

    VehicleFly.SetFlySpeed = function(newSpeed)
        VehicleFly.Settings.FlySpeed.Value = newSpeed
        notify("VehicleFly", "FlySpeed set to: " .. newSpeed, false)
    end

    -- Функции VehicleExploit
    local vehicleDropdown -- Переменная для хранения dropdown

    local function updateVehicleList()
        if tick() - VehicleExploit.State.LastUpdate < VehicleExploit.State.UpdateInterval then
            return VehicleExploit.State.VehiclesList
        end

        VehicleExploit.State.LastUpdate = tick()
        VehicleExploit.State.VehiclesList = {}
        VehicleExploit.State.VehicleSeats = {}
        local vehicleMap = {}
        local vehiclesFolder = Core.Services.Workspace:FindFirstChild("Vehicles")
        if not vehiclesFolder then
            warn("Vehicles folder not found in workspace!")
            return VehicleExploit.State.VehiclesList
        end

        for _, vehicle in ipairs(vehiclesFolder:GetChildren()) do
            if vehicle:IsA("Model") then
                local driverSeat = vehicle:FindFirstChild("DriverSeat")
                if driverSeat and driverSeat.Occupant == nil then
                    local ownerId = vehicle:GetAttribute("OwnerUserId")
                    local ownerName = ownerId and Players:GetNameFromUserIdAsync(ownerId) or "Unknown"
                    local uniqueKey = vehicle.Name .. "_" .. (ownerName or "Unknown")
                    if not vehicleMap[uniqueKey] then
                        vehicleMap[uniqueKey] = true
                        local displayName = string.format("%s (Owner: %s)", vehicle.Name, ownerName)
                        table.insert(VehicleExploit.State.VehiclesList, displayName)
                        VehicleExploit.State.VehicleSeats[displayName] = driverSeat
                    end
                end
            end
        end
        table.sort(VehicleExploit.State.VehiclesList)
        return VehicleExploit.State.VehiclesList
    end

    local function findVehicleByName(nameWithOwner)
        if not nameWithOwner then return nil end
        return VehicleExploit.State.VehicleSeats[nameWithOwner]
    end

    local function stabilizeVehicle(vehicle)
        local chassis = vehicle:FindFirstChild("Chassis", true)
        if chassis and chassis:IsA("BasePart") then
            local originalAnchored = chassis.Anchored
            chassis.Anchored = true
            chassis.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            chassis.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            return function()
                chassis.Anchored = originalAnchored
            end
        end
        return function() end
    end

    local function sitAsPassenger(vehicleSeat)
        if not vehicleSeat then return end

        local vehicle = vehicleSeat.Parent
        local vehicleState = u11.class.get(vehicle)

        if vehicleState and vehicleState.states.locked.get() then
            vehicleState.states.locked.set(false)
        end

        local passengerSeat
        for _, part in pairs(vehicle:GetDescendants()) do
            if part:IsA("Seat") and part.Name ~= "DriverSeat" and part.Occupant == nil then
                passengerSeat = part
                break
            end
        end

        if not passengerSeat then return end

        local originalWalkSpeed = Humanoid.WalkSpeed
        Humanoid.WalkSpeed = 0
        task.wait(0.1)

        local seatPosition = passengerSeat.Position
        local seatCFrame = CFrame.new(seatPosition + Vector3.new(0, 3, 0))
        HumanoidRootPart:PivotTo(seatCFrame)
        task.wait(0.2)

        local restoreVehicle = stabilizeVehicle(vehicle)
        passengerSeat:Sit(Humanoid)

        if Humanoid.SeatPart ~= passengerSeat then
            task.wait(0.5)
            passengerSeat:Sit(Humanoid)
        end

        Humanoid.WalkSpeed = originalWalkSpeed
        restoreVehicle()
    end

    local function sitInVehicle(vehicleSeat)
        if not vehicleSeat then return end

        local vehicle = vehicleSeat.Parent
        local vehicleState = u11.class.get(vehicle)
        if vehicleState and vehicleState.states.locked.get() then
            vehicleState.states.locked.set(false)
        end

        local drivePrompt = vehicleSeat:FindFirstChild("DrivePrompt", true)
        if drivePrompt then
            drivePrompt.Enabled = true
        end

        local restoreVehicle = stabilizeVehicle(vehicle)
        vehicleSeat:Sit(Humanoid)

        if Humanoid.SeatPart ~= vehicleSeat then
            task.wait(0.5)
            vehicleSeat:Sit(Humanoid)
        end

        restoreVehicle()
    end

    local function updateVehicleDropdownOptions()
        if not vehicleDropdown then return end

        local newOptions = updateVehicleList()
        notify("Vehicle Exploit", "Refreshed vehicle list. Found " .. #newOptions .. " vehicles.", true)

        -- Проверяем, изменился ли список опций
        local currentOptions = vehicleDropdown:GetOptions() or {}
        local optionsChanged = #newOptions ~= table.getn(currentOptions)
        if not optionsChanged then
            local currentStr = table.concat(currentOptions, ",")
            local newStr = table.concat(newOptions, ",")
            optionsChanged = currentStr ~= newStr
        end

        if optionsChanged then
            vehicleDropdown:ClearOptions()
            vehicleDropdown:InsertOptions(newOptions)
        end

        -- Обновляем выбор
        local currentSelection = VehicleExploit.Settings.SelectedVehicle.Value
        if currentSelection and vehicleDropdown:IsOption(currentSelection) then
            vehicleDropdown:UpdateSelection(currentSelection)
        else
            vehicleDropdown:UpdateSelection("")
        end
    end

    VehicleExploit.RefreshVehicles = function()
        VehicleExploit.State.LastUpdate = 0 -- Сброс кэша при ручном обновлении
        updateVehicleDropdownOptions()
    end

    VehicleExploit.ControlVehicle = function()
        local vehicleName = VehicleExploit.Settings.SelectedVehicle.Value
        if not vehicleName then
            notify("Vehicle Exploit", "No vehicle selected!", true)
            return
        end
        local vehicleSeat = findVehicleByName(vehicleName)
        if not vehicleSeat then
            notify("Vehicle Exploit", "Vehicle not found: " .. vehicleName, true)
            return
        end
        u5.send("initiate_lockpicking", vehicleSeat.Parent)
        task.wait(0.1)
        u5.send("lockpick_success", vehicleSeat.Parent)
        task.wait(0.1)
        sitInVehicle(vehicleSeat)
    end

    -- Настройка UI для VehicleExploit
    if not UI.Sections.VehicleExploit then
        UI.Sections.VehicleExploit = UI.Tabs.Vehicles:Section({ Name = "Vehicle Exploit", Side = "Left" })
    end
    if UI.Sections.VehicleExploit then
        UI.Sections.VehicleExploit:Header({ Name = "Vehicle Exploit Settings" })
        vehicleDropdown = UI.Sections.VehicleExploit:Dropdown({
            Name = "Vehicle Select",
            Default = "",
            Options = updateVehicleList(),
            Callback = function(value)
                if type(value) == "table" then
                    for k, v in pairs(value) do
                        if v then
                            VehicleExploit.Settings.SelectedVehicle.Value = k
                            notify("Vehicle Exploit", "Selected vehicle: " .. (k or "none"), false)
                            break
                        end
                    end
                else
                    VehicleExploit.Settings.SelectedVehicle.Value = value
                    notify("Vehicle Exploit", "Selected vehicle: " .. (value or "none"), false)
                end
            end
        }, "VehicleSelect")
        UI.Sections.VehicleExploit:Button({
            Name = "Refresh",
            Callback = VehicleExploit.RefreshVehicles
        }, "RefreshVehicles")
        UI.Sections.VehicleExploit:Button({
            Name = "Control Vehicle",
            Callback = VehicleExploit.ControlVehicle
        }, "ControlVehicle")
    end

    -- Обработка посадки/высадки из транспорта
    Core.PlayerData.LocalPlayer.CharacterAdded:Connect(function(character)
        Character = character
        Humanoid = character:WaitForChild("Humanoid")
        HumanoidRootPart = character:WaitForChild("HumanoidRootPart")
        local humanoid = character:WaitForChild("Humanoid")
        humanoid.Seated:Connect(function(isSeated, seatPart)
            if not isSeated then
                if VehicleSpeed.Settings.Enabled.Value and VehicleSpeed.State.IsBoosting then
                    VehicleSpeed.Stop()
                    VehicleSpeed.Start()
                end
                if VehicleFly.Settings.Enabled.Value and VehicleFly.State.IsFlying then
                    VehicleFly.Stop()
                    VehicleFly.Start()
                end
            end
        end)
    end)

    -- Настройка UI для VehicleSpeed
    if UI.Sections.VehicleSpeed then
        UI.Sections.VehicleSpeed:Header({ Name = "Vehicle Speed Settings" })
        UI.Sections.VehicleSpeed:Toggle({
            Name = "Enabled",
            Default = VehicleSpeed.Settings.Enabled.Default,
            Callback = function(value)
                VehicleSpeed.Settings.Enabled.Value = value
                if value then VehicleSpeed.Start() else VehicleSpeed.Stop() end
            end
        }, 'EnabledVS')
        UI.Sections.VehicleSpeed:Slider({
            Name = "Speed Boost Multiplier",
            Minimum = 1,
            Maximum = 5,
            Default = VehicleSpeed.Settings.SpeedBoostMultiplier.Default,
            Precision = 2,
            Callback = VehicleSpeed.SetSpeedBoostMultiplier
        }, 'SpeedBoostMulti')
        UI.Sections.VehicleSpeed:Toggle({
            Name = "Hold Speed",
            Default = VehicleSpeed.Settings.HoldSpeed.Default,
            Callback = function(value)
                VehicleSpeed.Settings.HoldSpeed.Value = value
            end
        }, 'HoldSpeed')
        UI.Sections.VehicleSpeed:Keybind({
            Name = "Hold Keybind",
            Default = VehicleSpeed.Settings.HoldKeybind.Default,
            Callback = function(value)
                if value ~= VehicleSpeed.Settings.HoldKeybind.Value then
                    VehicleSpeed.Settings.HoldKeybind.Value = value
                end
            end
        }, 'HoldKeybind')
        UI.Sections.VehicleSpeed:Keybind({
            Name = "Toggle Key",
            Default = VehicleSpeed.Settings.ToggleKey.Default,
            Callback = function(value)
                VehicleSpeed.Settings.ToggleKey.Value = value
                if VehicleSpeed.Settings.Enabled.Value then
                    if VehicleSpeed.State.Connection then
                        VehicleSpeed.Stop()
                    else
                        VehicleSpeed.Start()
                    end
                end
            end
        }, 'ToggleKeyVS')
    end

    -- Настройка UI для VehicleFly
    if UI.Sections.VehicleFly then
        UI.Sections.VehicleFly:Header({ Name = "Vehicle Fly Settings" })
        UI.Sections.VehicleFly:Toggle({
            Name = "Enabled",
            Default = VehicleFly.Settings.Enabled.Default,
            Callback = function(value)
                VehicleFly.Settings.Enabled.Value = value
                if value then VehicleFly.Start() else VehicleFly.Stop() end
            end
        }, 'Enabled')
        UI.Sections.VehicleFly:Slider({
            Name = "Fly Speed",
            Minimum = 10,
            Maximum = 200,
            Default = VehicleFly.Settings.FlySpeed.Default,
            Precision = 1,
            Callback = VehicleFly.SetFlySpeed
        }, 'FlySpeed')
        UI.Sections.VehicleFly:Keybind({
            Name = "Toggle Key",
            Default = VehicleFly.Settings.ToggleKey.Default,
            Callback = function(value)
                VehicleFly.Settings.ToggleKey.Value = value
                if VehicleFly.Settings.Enabled.Value then
                    if VehicleFly.State.Connection then
                        VehicleFly.Stop()
                    else
                        VehicleFly.Start()
                    end
                else
                    notify("VehicleFly", "Enable Vehicle Fly to use keybind.", true)
                end
            end
        }, 'ToggleKeyVF')
    end
end

return Vehicles

-- Модуль LocalPlayer: Timer, Disabler, Speed, TickSpeed, HighJump, NoRagdoll, FastAttack, Invisible
local LocalPlayer = {}

-- Кэшированные сервисы и данные
local Services = nil
local PlayerData = nil
local notify = nil
local LocalPlayerObj = nil
local core = nil -- Для доступа к core

-- Локальная конфигурация модуля
LocalPlayer.Config = {
    Timer = {
        Enabled = false,
        Speed = 2.5,
        ToggleKey = nil
    },
    Disabler = {
        Enabled = false,
        ToggleKey = nil
    },
    Speed = {
        Enabled = false,
        AutoJump = false,
        Method = "CFrame",
        Speed = 16,
        JumpPower = 50,
        JumpInterval = 0.3,
        PulseTPDist = 5,
        PulseTPDelay = 0.2,
        ToggleKey = nil
    },
    TickSpeed = {
        Enabled = false,
        HighSpeedMultiplier = 1.4,
        NormalSpeedMultiplier = 0.1,
        OnDuration = 0.1,
        OffDuration = 0.22,
        ToggleKey = nil
    },
    HighJump = {
        Enabled = false,
        Method = "Velocity",
        JumpPower = 100,
        JumpKey = nil,
        DefaultJumpHeight = 7.5
    },
    NoRagdoll = {
        Enabled = false
    },
    FastAttack = {
        Enabled = false
    },
    Invisible = {
        Enabled = false,
        Mode = "Full",
        Bypass = false, -- Новая настройка
        ToggleKey = nil
    }
}

-- Состояния модулей
local TimerStatus = {
    Running = false,
    Connection = nil,
    Speed = LocalPlayer.Config.Timer.Speed,
    Key = LocalPlayer.Config.Timer.ToggleKey,
    Enabled = LocalPlayer.Config.Timer.Enabled
}
local DisablerStatus = {
    Running = false,
    Connection = nil,
    Key = LocalPlayer.Config.Disabler.ToggleKey,
    Enabled = LocalPlayer.Config.Disabler.Enabled
}
local SpeedStatus = {
    Running = false,
    Connection = nil,
    Key = LocalPlayer.Config.Speed.ToggleKey,
    Enabled = LocalPlayer.Config.Speed.Enabled,
    Method = LocalPlayer.Config.Speed.Method,
    Speed = LocalPlayer.Config.Speed.Speed,
    AutoJump = LocalPlayer.Config.Speed.AutoJump,
    LastJumpTime = 0,
    JumpCooldown = 0.5,
    JumpPower = LocalPlayer.Config.Speed.JumpPower,
    JumpInterval = LocalPlayer.Config.Speed.JumpInterval,
    PulseTPDistance = LocalPlayer.Config.Speed.PulseTPDist,
    PulseTPFrequency = LocalPlayer.Config.Speed.PulseTPDelay,
    LastPulseTPTime = 0
}
local TickSpeedStatus = {
    Running = false,
    Connection = nil,
    ServerConnection = nil,
    Key = LocalPlayer.Config.TickSpeed.ToggleKey,
    Enabled = LocalPlayer.Config.TickSpeed.Enabled,
    HighSpeedMultiplier = LocalPlayer.Config.TickSpeed.HighSpeedMultiplier,
    NormalSpeedMultiplier = LocalPlayer.Config.TickSpeed.NormalSpeedMultiplier,
    OnDuration = LocalPlayer.Config.TickSpeed.OnDuration,
    OffDuration = LocalPlayer.Config.TickSpeed.OffDuration,
    Timer = 0,
    LastServerPosition = nil
}
local HighJumpStatus = {
    Enabled = LocalPlayer.Config.HighJump.Enabled,
    Method = LocalPlayer.Config.HighJump.Method,
    JumpPower = LocalPlayer.Config.HighJump.JumpPower,
    Key = LocalPlayer.Config.HighJump.JumpKey,
    LastJumpTime = 0,
    JumpCooldown = 1
}
local NoRagdollStatus = {
    Enabled = LocalPlayer.Config.NoRagdoll.Enabled,
    Connection = nil,
    BodyParts = nil
}
local FastAttackStatus = {
    Enabled = LocalPlayer.Config.FastAttack.Enabled,
    Connection = nil,
    LastCheckTime = 0,
    CheckInterval = 0.5
}
local InvisibleStatus = {
    Enabled = LocalPlayer.Config.Invisible.Enabled,
    Mode = LocalPlayer.Config.Invisible.Mode,
    Bypass = LocalPlayer.Config.Invisible.Bypass, -- Новое состояние
    Key = LocalPlayer.Config.Invisible.ToggleKey,
    Running = false,
    Clone = nil,
    OldRoot = nil,
    HipHeight = nil,
    AnimTrack = nil,
    Connection = nil,
    CharacterConnection = nil,
    OriginalSetAttribute = nil -- Для хранения оригинальной функции SetAttribute
}

-- Вспомогательные функции
local function getCharacterData()
    local character = LocalPlayerObj and LocalPlayerObj.Character
    if not character then return nil, nil end
    local humanoid = character:FindFirstChild("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    return humanoid, rootPart
end

local function isCharacterValid(humanoid, rootPart)
    return humanoid and rootPart and humanoid.Health > 0
end

local function isInVehicle(rootPart)
    local currentPart = rootPart
    while currentPart do
        if currentPart:IsA("Seat") or currentPart:IsA("VehicleSeat") then
            return true
        end
        currentPart = currentPart.Parent
    end
    return false
end

local function isInputFocused()
    return Services and Services.UserInputService and Services.UserInputService:GetFocusedTextBox() ~= nil
end

-- Timer Functions
local Timer = {}
Timer.Start = function()
    if TimerStatus.Running or not Services then return end
    local success = pcall(function()
        setfflag("SimEnableStepPhysics", "True")
        setfflag("SimEnableStepPhysicsSelective", "True")
    end)
    if not success then
        warn("Timer: Failed to enable physics flags")
        notify("Timer", "Failed to enable physics simulation.", true)
        return
    end
    TimerStatus.Running = true
    TimerStatus.Connection = Services.RunService.RenderStepped:Connect(function(dt)
        if not TimerStatus.Enabled or TimerStatus.Speed <= 1 then return end
        local humanoid, rootPart = getCharacterData()
        if not isCharacterValid(humanoid, rootPart) then return end
        local success, err = pcall(function()
            Services.RunService:Pause()
            Services.Workspace:StepPhysics(dt * (TimerStatus.Speed - 1), {rootPart})
            Services.RunService:Run()
        end)
        if not success then
            warn("Timer physics step failed: " .. tostring(err))
            Timer.Stop()
            notify("Timer", "Physics step failed. Timer stopped.", true)
        end
    end)
    notify("Timer", "Started with speed: " .. TimerStatus.Speed, true)
end

Timer.Stop = function()
    if TimerStatus.Connection then
        TimerStatus.Connection:Disconnect()
        TimerStatus.Connection = nil
    end
    TimerStatus.Running = false
    notify("Timer", "Stopped", true)
end

Timer.SetSpeed = function(newSpeed)
    TimerStatus.Speed = math.clamp(newSpeed, 1, 15) -- Ограничение скорости
    LocalPlayer.Config.Timer.Speed = TimerStatus.Speed
    notify("Timer", "Speed set to: " .. TimerStatus.Speed, false)
end

-- Disabler Functions
local Disabler = {}
Disabler.DisableSignals = function(character)
    if not character then return end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end
    for _, connection in ipairs(getconnections(rootPart:GetPropertyChangedSignal("CFrame"))) do
        pcall(function() hookfunction(connection.Function, function() end) end)
    end
    for _, connection in ipairs(getconnections(rootPart:GetPropertyChangedSignal("Velocity"))) do
        pcall(function() hookfunction(connection.Function, function() end) end)
    end
end

Disabler.Start = function()
    if DisablerStatus.Running or not LocalPlayerObj then return end
    DisablerStatus.Running = true
    DisablerStatus.Connection = LocalPlayerObj.CharacterAdded:Connect(Disabler.DisableSignals)
    if LocalPlayerObj.Character then
        Disabler.DisableSignals(LocalPlayerObj.Character)
    end
    notify("Disabler", "Started", true)
end

Disabler.Stop = function()
    if DisablerStatus.Connection then
        DisablerStatus.Connection:Disconnect()
        DisablerStatus.Connection = nil
    end
    DisablerStatus.Running = false
    notify("Disabler", "Stopped", true)
end

-- Speed Functions
local Speed = {}
Speed.UpdateMovement = function(humanoid, rootPart, moveDirection, currentTime)
    if not isCharacterValid(humanoid, rootPart) then return end
    if SpeedStatus.Method == "CFrame" then
        if moveDirection.Magnitude > 0 then
            local newCFrame = rootPart.CFrame + (moveDirection * SpeedStatus.Speed * 0.0167)
            rootPart.CFrame = CFrame.new(newCFrame.Position, newCFrame.Position + moveDirection)
        end
    elseif SpeedStatus.Method == "PulseTP" then
        if moveDirection.Magnitude > 0 and currentTime - SpeedStatus.LastPulseTPTime >= SpeedStatus.PulseTPFrequency then
            local teleportVector = moveDirection.Unit * SpeedStatus.PulseTPDistance
            local destination = rootPart.Position + teleportVector
            local raycastParams = RaycastParams.new()
            raycastParams.FilterDescendantsInstances = {LocalPlayerObj.Character}
            raycastParams.FilterType = Enum.RaycastFilterType.Exclude
            local raycastResult = Services.Workspace:Raycast(rootPart.Position, teleportVector, raycastParams)
            if not raycastResult then
                rootPart.CFrame = CFrame.new(destination, destination + moveDirection)
                SpeedStatus.LastPulseTPTime = currentTime
            end
        end
    end
end

Speed.UpdateJumps = function(humanoid, rootPart, currentTime)
    if not isCharacterValid(humanoid, rootPart) then return end
    if SpeedStatus.AutoJump and currentTime - SpeedStatus.LastJumpTime >= SpeedStatus.JumpInterval then
        if humanoid:GetState() ~= Enum.HumanoidStateType.Jumping and humanoid:GetState() ~= Enum.HumanoidStateType.Freefall then
            rootPart.Velocity = Vector3.new(rootPart.Velocity.X, SpeedStatus.JumpPower, rootPart.Velocity.Z)
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            SpeedStatus.LastJumpTime = currentTime
        end
    end
end

Speed.Start = function()
    if SpeedStatus.Running or not Services then return end
    SpeedStatus.Running = true
    SpeedStatus.Connection = Services.RunService.Heartbeat:Connect(function()
        if not SpeedStatus.Enabled then
            SpeedStatus.Running = false
            return
        end
        local humanoid, rootPart = getCharacterData()
        if not isCharacterValid(humanoid, rootPart) then return end
        local currentTime = tick()
        local moveDirection = humanoid.MoveDirection
        Speed.UpdateMovement(humanoid, rootPart, moveDirection, currentTime)
        Speed.UpdateJumps(humanoid, rootPart, currentTime)
    end)
    notify("Speed", "Started with Method: " .. SpeedStatus.Method, true)
end

Speed.Stop = function()
    if SpeedStatus.Connection then
        SpeedStatus.Connection:Disconnect()
        SpeedStatus.Connection = nil
    end
    SpeedStatus.Running = false
    notify("Speed", "Stopped", true)
end

Speed.SetSpeed = function(newSpeed)
    SpeedStatus.Speed = math.clamp(newSpeed, 16, 250)
    LocalPlayer.Config.Speed.Speed = SpeedStatus.Speed
    notify("Speed", "Speed set to: " .. SpeedStatus.Speed, false)
end

Speed.SetMethod = function(newMethod)
    SpeedStatus.Method = newMethod
    LocalPlayer.Config.Speed.Method = newMethod
    notify("Speed", "Method set to: " .. newMethod, false)
    if SpeedStatus.Running then
        Speed.Stop()
        Speed.Start()
    end
end

Speed.SetPulseTPDistance = function(value)
    SpeedStatus.PulseTPDistance = math.clamp(value, 1, 20)
    LocalPlayer.Config.Speed.PulseTPDist = SpeedStatus.PulseTPDistance
    notify("Speed", "PulseTP Distance set to: " .. SpeedStatus.PulseTPDistance, false)
end

Speed.SetPulseTPFrequency = function(value)
    SpeedStatus.PulseTPFrequency = math.clamp(value, 0.1, 1)
    LocalPlayer.Config.Speed.PulseTPDelay = SpeedStatus.PulseTPFrequency
    notify("Speed", "PulseTP Frequency set to: " .. SpeedStatus.PulseTPFrequency, false)
end

Speed.SetJumpPower = function(newPower)
    SpeedStatus.JumpPower = math.clamp(newPower, 10, 100)
    LocalPlayer.Config.Speed.JumpPower = SpeedStatus.JumpPower
    notify("Speed", "JumpPower set to: " .. SpeedStatus.JumpPower, false)
end

Speed.SetJumpInterval = function(newInterval)
    SpeedStatus.JumpInterval = math.clamp(newInterval, 0.1, 2)
    LocalPlayer.Config.Speed.JumpInterval = SpeedStatus.JumpInterval
    notify("Speed", "JumpInterval set to: " .. SpeedStatus.JumpInterval, false)
end

-- TickSpeed Functions
local TickSpeed = {}
TickSpeed.Start = function()
    if TickSpeedStatus.Running or not Services then return end
    local humanoid, rootPart = getCharacterData()
    if not isCharacterValid(humanoid, rootPart) then return end
    if isInVehicle(rootPart) then
        notify("TickSpeed", "Disabled while in vehicle.", true)
        return
    end

    local success, err = pcall(function()
        setsimulationradius(10000)
    end)
    if not success then
        warn("TickSpeed: setsimulationradius failed: " .. tostring(err))
        notify("TickSpeed", "Failed to set simulation radius.", true)
        return
    end

    TickSpeedStatus.Running = true
    TickSpeedStatus.LastServerPosition = rootPart.Position

    TickSpeedStatus.Connection = Services.RunService.Heartbeat:Connect(function(deltaTime)
        local humanoid, rootPart = getCharacterData()
        if not isCharacterValid(humanoid, rootPart) or not TickSpeedStatus.Enabled then
            TickSpeed.Stop()
            return
        end
        if isInVehicle(rootPart) then
            TickSpeed.Stop()
            notify("TickSpeed", "Disabled while in vehicle.", true)
            return
        end

        local moveDirection = humanoid.MoveDirection
        TickSpeedStatus.Timer = (TickSpeedStatus.Timer + deltaTime) % (TickSpeedStatus.OnDuration + TickSpeedStatus.OffDuration)
        local currentMultiplier = TickSpeedStatus.Timer < TickSpeedStatus.OnDuration and TickSpeedStatus.HighSpeedMultiplier or TickSpeedStatus.NormalSpeedMultiplier

        if moveDirection.Magnitude > 0 then
            moveDirection = moveDirection.Unit
            local speed = 16 * currentMultiplier
            local offset = moveDirection * speed * deltaTime
            local newCFrame = rootPart.CFrame + offset
            rootPart.CFrame = CFrame.new(newCFrame.Position, newCFrame.Position + moveDirection)

            local deviation = (rootPart.Position - TickSpeedStatus.LastServerPosition).Magnitude
            if deviation > 5 then
                local correction = (rootPart.Position - TickSpeedStatus.LastServerPosition).Unit * (deviation - 5)
                rootPart.CFrame = CFrame.new(rootPart.Position - correction)
            end
        end
    end)

    TickSpeedStatus.ServerConnection = Services.RunService.Stepped:Connect(function()
        local _, rootPart = getCharacterData()
        if not rootPart then return end
        local serverPos = rootPart.Position
        if (serverPos - TickSpeedStatus.LastServerPosition).Magnitude > 1 then
            TickSpeedStatus.LastServerPosition = serverPos
        end
    end)

    notify("TickSpeed", "Started", true)
end

TickSpeed.Stop = function()
    if TickSpeedStatus.Connection then
        TickSpeedStatus.Connection:Disconnect()
        TickSpeedStatus.Connection = nil
    end
    if TickSpeedStatus.ServerConnection then
        TickSpeedStatus.ServerConnection:Disconnect()
        TickSpeedStatus.ServerConnection = nil
    end
    TickSpeedStatus.Running = false
    TickSpeedStatus.Timer = 0
    local _, rootPart = getCharacterData()
    if rootPart and TickSpeedStatus.LastServerPosition then
        rootPart.CFrame = CFrame.new(TickSpeedStatus.LastServerPosition)
    end
    notify("TickSpeed", "Stopped", true)
end

TickSpeed.SetHighSpeedMultiplier = function(value)
    TickSpeedStatus.HighSpeedMultiplier = math.clamp(value, 1, 3)
    LocalPlayer.Config.TickSpeed.HighSpeedMultiplier = TickSpeedStatus.HighSpeedMultiplier
    notify("TickSpeed", "HighSpeedMultiplier set to: " .. TickSpeedStatus.HighSpeedMultiplier, false)
end

TickSpeed.SetNormalSpeedMultiplier = function(value)
    TickSpeedStatus.NormalSpeedMultiplier = math.clamp(value, 0.1, 1)
    LocalPlayer.Config.TickSpeed.NormalSpeedMultiplier = TickSpeedStatus.NormalSpeedMultiplier
    notify("TickSpeed", "NormalSpeedMultiplier set to: " .. TickSpeedStatus.NormalSpeedMultiplier, false)
end

TickSpeed.SetOnDuration = function(value)
    TickSpeedStatus.OnDuration = math.clamp(value, 0.05, 0.5)
    LocalPlayer.Config.TickSpeed.OnDuration = TickSpeedStatus.OnDuration
    notify("TickSpeed", "OnDuration set to: " .. TickSpeedStatus.OnDuration, false)
end

TickSpeed.SetOffDuration = function(value)
    TickSpeedStatus.OffDuration = math.clamp(value, 0.1, 0.5)
    LocalPlayer.Config.TickSpeed.OffDuration = TickSpeedStatus.OffDuration
    notify("TickSpeed", "OffDuration set to: " .. TickSpeedStatus.OffDuration, false)
end

-- HighJump Functions
local HighJump = {}
HighJump.Trigger = function()
    if not HighJumpStatus.Enabled then
        notify("HighJump", "HighJump is disabled. Enable it to use keybind.", true)
        return
    end

    local humanoid, rootPart = getCharacterData()
    if not isCharacterValid(humanoid, rootPart) then
        notify("HighJump", "Character is not valid.", true)
        return
    end

    local currentTime = tick()
    local state = humanoid:GetState()
    local canJump = state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.Landed
    if not canJump or currentTime - HighJumpStatus.LastJumpTime < HighJumpStatus.JumpCooldown then
        notify("HighJump", not canJump and "You must be on the ground to high jump! State: " .. tostring(state) or "HighJump is on cooldown!", true)
        return
    end

    notify("HighJump", "Attempting jump with method: " .. HighJumpStatus.Method, true)
    if HighJumpStatus.Method == "Velocity" then
        local gravity = Services.Workspace.Gravity or 196.2
        local jumpVelocity = math.sqrt(2 * HighJumpStatus.JumpPower * gravity)
        rootPart.Velocity = Vector3.new(rootPart.Velocity.X, jumpVelocity, rootPart.Velocity.Z)
        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    else -- CFrame method
        local newCFrame = rootPart.CFrame + Vector3.new(0, HighJumpStatus.JumpPower / 10, 0)
        rootPart.CFrame = newCFrame
        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    end

    HighJumpStatus.LastJumpTime = currentTime
    notify("HighJump", "Performed HighJump with method: " .. HighJumpStatus.Method, true)
end

HighJump.SetMethod = function(newMethod)
    HighJumpStatus.Method = newMethod
    LocalPlayer.Config.HighJump.Method = newMethod
    notify("HighJump", "Method set to: " .. newMethod, false)
end

HighJump.SetJumpPower = function(newPower)
    HighJumpStatus.JumpPower = math.clamp(newPower, 50, 200)
    LocalPlayer.Config.HighJump.JumpPower = HighJumpStatus.JumpPower
    notify("HighJump", "JumpPower set to: " .. HighJumpStatus.JumpPower, false)
end

HighJump.RestoreJumpHeight = function()
    local humanoid, _ = getCharacterData()
    if humanoid then
        humanoid.JumpHeight = LocalPlayer.Config.HighJump.DefaultJumpHeight
    end
end

-- NoRagdoll Functions
local NoRagdoll = {}
NoRagdoll.Start = function(character)
    if not character then return end
    if NoRagdollStatus.Connection then
        NoRagdollStatus.Connection:Disconnect()
        NoRagdollStatus.Connection = nil
    end

    local success, parts = pcall(function()
        return {
            LowerTorso = character:WaitForChild("LowerTorso", 5),
            UpperTorso = character:WaitForChild("UpperTorso", 5),
            LeftFoot = character:WaitForChild("LeftFoot", 5),
            RightFoot = character:WaitForChild("RightFoot", 5)
        }
    end)
    if not success or not (parts.LowerTorso and parts.UpperTorso and parts.LeftFoot and parts.RightFoot) then
        warn("NoRagdoll: Failed to find required character parts")
        notify("NoRagdoll", "Failed to initialize: missing character parts.", true)
        return
    end
    NoRagdollStatus.BodyParts = parts

    local function updatePhysics()
        if not NoRagdollStatus.Enabled then return end
        local p = NoRagdollStatus.BodyParts
        if p.LowerTorso:FindFirstChild("MoveForce") then p.LowerTorso.MoveForce.Enabled = false end
        if p.UpperTorso:FindFirstChild("FloatPosition") then p.UpperTorso.FloatPosition.Enabled = false end
        if p.LeftFoot:FindFirstChild("LeftFootPosition") then p.LeftFoot.LeftFootPosition.Enabled = false end
        if p.RightFoot:FindFirstChild("RightFootPosition") then p.RightFoot.RightFootPosition.Enabled = false end
        for _, motor in ipairs(character:GetDescendants()) do
            if motor:IsA("Motor6D") then motor.Enabled = true end
        end
    end

    updatePhysics()
    NoRagdollStatus.Connection = Services.RunService.Heartbeat:Connect(updatePhysics)

    notify("NoRagdoll", "Started", true)
end

NoRagdoll.Stop = function()
    if NoRagdollStatus.Connection then
        NoRagdollStatus.Connection:Disconnect()
        NoRagdollStatus.Connection = nil
    end
    NoRagdollStatus.BodyParts = nil
    notify("NoRagdoll", "Stopped", true)
end

-- FastAttack Functions
local FastAttack = {}
FastAttack.Start = function()
    if FastAttackStatus.Connection or not core or not LocalPlayerObj then return end
    FastAttackStatus.Connection = Services.RunService.Heartbeat:Connect(function()
        if not FastAttackStatus.Enabled then return end
        local currentTime = tick()
        if currentTime - FastAttackStatus.LastCheckTime < FastAttackStatus.CheckInterval then return end
        FastAttackStatus.LastCheckTime = currentTime

        local backpack = LocalPlayerObj:FindFirstChild("Backpack")
        if not backpack then return end

        local encryptedSpeedAttr = core.GetEncryptedAttributeName and core.GetEncryptedAttributeName("speed") or "speed"
        for _, item in ipairs(backpack:GetChildren()) do
            if item.Name == "fists" or item:GetAttribute(encryptedSpeedAttr) ~= nil then
                pcall(function()
                    if not item:GetAttribute(encryptedSpeedAttr) then
                        item:SetAttribute(encryptedSpeedAttr, 1)
                    end
                    item:SetAttribute(encryptedSpeedAttr, 0)
                end)
            end
        end
    end)
    notify("FastAttack", "Started with speed set to 0", true)
end

FastAttack.Stop = function()
    if FastAttackStatus.Connection then
        FastAttackStatus.Connection:Disconnect()
        FastAttackStatus.Connection = nil
    end

    local backpack = LocalPlayerObj and LocalPlayerObj:FindFirstChild("Backpack")
    if backpack then
        local encryptedSpeedAttr = core.GetEncryptedAttributeName and core.GetEncryptedAttributeName("speed") or "speed"
        for _, item in ipairs(backpack:GetChildren()) do
            if item.Name == "fists" or item:GetAttribute(encryptedSpeedAttr) ~= nil then
                pcall(function()
                    if not item:GetAttribute(encryptedSpeedAttr) then
                        item:SetAttribute(encryptedSpeedAttr, 1)
                    end
                    item:SetAttribute(encryptedSpeedAttr, 1)
                end)
            end
        end
    end

    notify("FastAttack", "Stopped, attack speed restored to 1", true)
end

-- Invisible Functions
local Invisible = {}
local DEPTH_OFFSETS = {
    Full = 0.9588,
    Semi = 0.41,
    Low = 0.15
}

local function removeFolders()
    local playerFolder = Services.Workspace:FindFirstChild(LocalPlayerObj.Name)
    if not playerFolder then return end

    local doubleRig = playerFolder:FindFirstChild("DoubleRig")
    if doubleRig then doubleRig:Destroy() end

    local constraints = playerFolder:FindFirstChild("Constraints")
    if constraints then constraints:Destroy() end

    playerFolder.ChildAdded:Connect(function(child)
        if child.Name == "DoubleRig" or child.Name == "Constraints" then
            child:Destroy()
        end
    end)
end

local function doClone()
    if not LocalPlayerObj.Character or not LocalPlayerObj.Character:FindFirstChild("Humanoid") or LocalPlayerObj.Character.Humanoid.Health <= 0 then
        return false
    end

    InvisibleStatus.HipHeight = LocalPlayerObj.Character.Humanoid.HipHeight
    InvisibleStatus.OldRoot = LocalPlayerObj.Character:FindFirstChild("HumanoidRootPart")
    if not InvisibleStatus.OldRoot or not InvisibleStatus.OldRoot.Parent then
        return false
    end

    local tempParent = Instance.new("Model")
    tempParent.Parent = game
    LocalPlayerObj.Character.Parent = tempParent

    InvisibleStatus.Clone = InvisibleStatus.OldRoot:Clone()
    InvisibleStatus.Clone.Parent = LocalPlayerObj.Character
    InvisibleStatus.OldRoot.Parent = Services.Workspace.CurrentCamera
    InvisibleStatus.Clone.CFrame = InvisibleStatus.OldRoot.CFrame

    LocalPlayerObj.Character.PrimaryPart = InvisibleStatus.Clone
    LocalPlayerObj.Character.Parent = Services.Workspace

    for _, v in pairs(LocalPlayerObj.Character:GetDescendants()) do
        if v:IsA("Weld") or v:IsA("Motor6D") then
            if v.Part0 == InvisibleStatus.OldRoot then
                v.Part0 = InvisibleStatus.Clone
            end
            if v.Part1 == InvisibleStatus.OldRoot then
                v.Part1 = InvisibleStatus.Clone
            end
        end
    end

    tempParent:Destroy()
    return true
end

local function revertClone()
    if not InvisibleStatus.OldRoot or not InvisibleStatus.OldRoot:IsDescendantOf(Services.Workspace) or not LocalPlayerObj.Character or LocalPlayerObj.Character.Humanoid.Health <= 0 then
        return false
    end

    local tempParent = Instance.new("Model")
    tempParent.Parent = game
    LocalPlayerObj.Character.Parent = tempParent

    InvisibleStatus.OldRoot.Parent = LocalPlayerObj.Character
    LocalPlayerObj.Character.PrimaryPart = InvisibleStatus.OldRoot
    LocalPlayerObj.Character.Parent = Services.Workspace
    InvisibleStatus.OldRoot.CanCollide = true

    for _, v in pairs(LocalPlayerObj.Character:GetDescendants()) do
        if v:IsA("Weld") or v:IsA("Motor6D") then
            if v.Part0 == InvisibleStatus.Clone then
                v.Part0 = InvisibleStatus.OldRoot
            end
            if v.Part1 == InvisibleStatus.Clone then
                v.Part1 = InvisibleStatus.OldRoot
            end
        end
    end

    if InvisibleStatus.Clone then
        local oldPos = InvisibleStatus.Clone.CFrame
        InvisibleStatus.Clone:Destroy()
        InvisibleStatus.Clone = nil
        InvisibleStatus.OldRoot.CFrame = oldPos
    end

    InvisibleStatus.OldRoot = nil
    if LocalPlayerObj.Character and LocalPlayerObj.Character.Humanoid then
        LocalPlayerObj.Character.Humanoid.HipHeight = InvisibleStatus.HipHeight or 2
    end
    return true
end

local function animationTrickery()
    if not LocalPlayerObj.Character or not LocalPlayerObj.Character:FindFirstChild("Humanoid") or LocalPlayerObj.Character.Humanoid.Health <= 0 then
        return
    end

    local anim = Instance.new("Animation")
    anim.AnimationId = "http://www.roblox.com/asset/?id=18537363391"
    local humanoid = LocalPlayerObj.Character.Humanoid
    local animator = humanoid:FindFirstChild("Animator") or Instance.new("Animator", humanoid)
    InvisibleStatus.AnimTrack = animator:LoadAnimation(anim)
    InvisibleStatus.AnimTrack.Priority = Enum.AnimationPriority.Action4
    InvisibleStatus.AnimTrack:Play(0, 1, 0)
    anim:Destroy()

    InvisibleStatus.AnimTrack.Stopped:Connect(function()
        if InvisibleStatus.Running then
            animationTrickery()
        end
    end)

    task.delay(0, function()
        InvisibleStatus.AnimTrack.TimePosition = 0.77
        task.delay(1, function()
            InvisibleStatus.AnimTrack:AdjustSpeed(math.huge)
        end)
    end)
end

Invisible.Toggle = function()
    if not LocalPlayerObj or not LocalPlayerObj.Character or LocalPlayerObj.Character.Humanoid.Health <= 0 then
        notify("Invisible", "Character is not valid!", true)
        return
    end

    InvisibleStatus.Running = not InvisibleStatus.Running
    if InvisibleStatus.Running then
        removeFolders()
        local success = doClone()
        if success then
            animationTrickery()
            InvisibleStatus.Connection = Services.RunService.PreSimulation:Connect(function(dt)
                if not LocalPlayerObj.Character or not LocalPlayerObj.Character:FindFirstChild("Humanoid") or LocalPlayerObj.Character.Humanoid.Health <= 0 or not InvisibleStatus.OldRoot then
                    return
                end
                local root = LocalPlayerObj.Character.PrimaryPart or LocalPlayerObj.Character:FindFirstChild("HumanoidRootPart")
                if root then
                    local cf = root.CFrame - Vector3.new(0, LocalPlayerObj.Character.Humanoid.HipHeight + (root.Size.Y / 2) - 1 + DEPTH_OFFSETS[InvisibleStatus.Mode], 0)
                    InvisibleStatus.OldRoot.CFrame = cf * CFrame.Angles(math.rad(180), 0, 0)
                    InvisibleStatus.OldRoot.Velocity = root.Velocity
                    InvisibleStatus.OldRoot.CanCollide = false
                end
            end)

            InvisibleStatus.CharacterConnection = LocalPlayerObj.CharacterAdded:Connect(function(newChar)
                wait(1)
                local newHumanoid = newChar:WaitForChild("Humanoid", 1)
                if newHumanoid and InvisibleStatus.Running then
                    InvisibleStatus.OldRoot = nil
                    if InvisibleStatus.AnimTrack then
                        InvisibleStatus.AnimTrack:Stop()
                        InvisibleStatus.AnimTrack:Destroy()
                        InvisibleStatus.AnimTrack = nil
                    end
                    if InvisibleStatus.Connection then InvisibleStatus.Connection:Disconnect() end
                    revertClone()
                    removeFolders()
                    Invisible.Toggle()
                end
            end)

            -- Логика для Bypass
            if InvisibleStatus.Bypass then
                local playerFolder = Services.Workspace:FindFirstChild(LocalPlayerObj.Name)
                if playerFolder and playerFolder:FindFirstChild("Humanoid") then
                    local humanoid = playerFolder.Humanoid
                    pcall(function()
                        humanoid.AutomaticScalingEnabled = false
                        InvisibleStatus.OriginalSetAttribute = humanoid.SetAttribute
                        hookfunction(humanoid.SetAttribute, function(self, attr, value)
                            if attr == "AutomaticScalingEnabled" then return end
                            return InvisibleStatus.OriginalSetAttribute(self, attr, value)
                        end)
                    end)
                    notify("Invisible", "Bypass enabled: AutomaticScalingEnabled disabled.", true)
                else
                    notify("Invisible", "Failed to find Humanoid for Bypass!", true)
                end
            end

            notify("Invisible", "Enabled with mode: " .. InvisibleStatus.Mode .. " (Depth: " .. DEPTH_OFFSETS[InvisibleStatus.Mode] .. ")", true)
        else
            InvisibleStatus.Running = false
            notify("Invisible", "Failed to enable invisibility!", true)
        end
    else
        if InvisibleStatus.AnimTrack then
            InvisibleStatus.AnimTrack:Stop()
            InvisibleStatus.AnimTrack:Destroy()
            InvisibleStatus.AnimTrack = nil
        end
        if InvisibleStatus.Connection then
            InvisibleStatus.Connection:Disconnect()
            InvisibleStatus.Connection = nil
        end
        if InvisibleStatus.CharacterConnection then
            InvisibleStatus.CharacterConnection:Disconnect()
            InvisibleStatus.CharacterConnection = nil
        end

        -- Отключаем Bypass при выключении невидимости
        if InvisibleStatus.Bypass then
            local playerFolder = Services.Workspace:FindFirstChild(LocalPlayerObj.Name)
            if playerFolder and playerFolder:FindFirstChild("Humanoid") then
                local humanoid = playerFolder.Humanoid
                pcall(function()
                    if InvisibleStatus.OriginalSetAttribute then
                        humanoid.SetAttribute = InvisibleStatus.OriginalSetAttribute
                        InvisibleStatus.OriginalSetAttribute = nil
                    end
                    humanoid.AutomaticScalingEnabled = true -- Восстанавливаем по умолчанию
                end)
                notify("Invisible", "Bypass disabled: AutomaticScalingEnabled restored to default.", true)
            end
        end

        revertClone()
        removeFolders()
        notify("Invisible", "Disabled", true)
    end
end

Invisible.SetMode = function(newMode)
    if DEPTH_OFFSETS[newMode] then
        InvisibleStatus.Mode = newMode
        LocalPlayer.Config.Invisible.Mode = newMode
        notify("Invisible", "Mode set to: " .. newMode .. " (Depth: " .. DEPTH_OFFSETS[newMode] .. ")", false)
    else
        notify("Invisible", "Invalid mode selected!", true)
    end
end

Invisible.SetBypass = function(value)
    InvisibleStatus.Bypass = value
    LocalPlayer.Config.Invisible.Bypass = value
    notify("Invisible", "Bypass " .. (value and "Enabled" or "Disabled"), true)
    -- Если невидимость уже активна, применяем или отключаем Bypass
    if InvisibleStatus.Running then
        Invisible.Toggle() -- Отключаем
        Invisible.Toggle() -- Включаем заново с новым значением Bypass
    end
end

-- Настройка UI
local function SetupUI(UI)
    local uiElements = {}

    if UI.Sections.Timer then
        UI.Sections.Timer:Header({ Name = "Timer" })
        uiElements.TimerEnabled = UI.Sections.Timer:Toggle({
            Name = "Enabled",
            Default = LocalPlayer.Config.Timer.Enabled,
            Callback = function(value)
                TimerStatus.Enabled = value
                LocalPlayer.Config.Timer.Enabled = value
                if value then Timer.Start() else Timer.Stop() end
            end
        }, "TimerEnabled")
        uiElements.TimerSpeed = UI.Sections.Timer:Slider({
            Name = "Speed",
            Minimum = 1,
            Maximum = 15,
            Default = LocalPlayer.Config.Timer.Speed,
            Precision = 1,
            Callback = function(value)
                Timer.SetSpeed(value)
            end
        }, "TimerSpeed")
        uiElements.TimerKey = UI.Sections.Timer:Keybind({
            Name = "Toggle Key",
            Default = LocalPlayer.Config.Timer.ToggleKey,
            Callback = function(value)
                TimerStatus.Key = value
                LocalPlayer.Config.Timer.ToggleKey = value
                if isInputFocused() then return end
                if TimerStatus.Enabled then
                    if TimerStatus.Running then Timer.Stop() else Timer.Start() end
                else
                    notify("Timer", "Enable Timer to use keybind.", true)
                end
            end
        }, "TimerKey")
    end

    if UI.Sections.Disabler then
        UI.Sections.Disabler:Header({ Name = "Disabler" })
        uiElements.DisablerEnabled = UI.Sections.Disabler:Toggle({
            Name = "Enabled",
            Default = LocalPlayer.Config.Disabler.Enabled,
            Callback = function(value)
                DisablerStatus.Enabled = value
                LocalPlayer.Config.Disabler.Enabled = value
                if value then Disabler.Start() else Disabler.Stop() end
            end
        }, "DisablerEnabled")
        uiElements.DisablerKey = UI.Sections.Disabler:Keybind({
            Name = "Toggle Key",
            Default = LocalPlayer.Config.Disabler.ToggleKey,
            Callback = function(value)
                DisablerStatus.Key = value
                LocalPlayer.Config.Disabler.ToggleKey = value
                if isInputFocused() then return end
                if DisablerStatus.Enabled then
                    if DisablerStatus.Running then Disabler.Stop() else Disabler.Start() end
                else
                    notify("Disabler", "Enable Disabler to use keybind.", true)
                end
            end
        }, "DisablerKey")
    end

    if UI.Sections.Speed then
        UI.Sections.Speed:Header({ Name = "Speed" })
        uiElements.SpeedEnabled = UI.Sections.Speed:Toggle({
            Name = "Enabled",
            Default = LocalPlayer.Config.Speed.Enabled,
            Callback = function(value)
                SpeedStatus.Enabled = value
                LocalPlayer.Config.Speed.Enabled = value
                if value then Speed.Start() else Speed.Stop() end
            end
        }, "SpeedEnabled")
        uiElements.SpeedAutoJump = UI.Sections.Speed:Toggle({
            Name = "AutoJump",
            Default = LocalPlayer.Config.Speed.AutoJump,
            Callback = function(value)
                SpeedStatus.AutoJump = value
                LocalPlayer.Config.Speed.AutoJump = value
                notify("Speed", "AutoJump " .. (value and "Enabled" or "Disabled"), true)
            end
        }, "SpeedAutoJump")
        uiElements.SpeedMethod = UI.Sections.Speed:Dropdown({
            Name = "Method",
            Options = {"CFrame", "PulseTP"},
            Default = LocalPlayer.Config.Speed.Method,
            Callback = function(value)
                Speed.SetMethod(value)
            end
        }, "SpeedMethod")
        uiElements.Speed = UI.Sections.Speed:Slider({
            Name = "Speed",
            Minimum = 16,
            Maximum = 250,
            Default = LocalPlayer.Config.Speed.Speed,
            Precision = 1,
            Callback = function(value)
                Speed.SetSpeed(value)
            end
        }, "Speed")
        uiElements.SpeedJumpPower = UI.Sections.Speed:Slider({
            Name = "Jump Power",
            Minimum = 10,
            Maximum = 100,
            Default = LocalPlayer.Config.Speed.JumpPower,
            Precision = 1,
            Callback = function(value)
                Speed.SetJumpPower(value)
            end
        }, "SpeedJumpPower")
        uiElements.SpeedJumpInterval = UI.Sections.Speed:Slider({
            Name = "Jump Interval",
            Minimum = 0.1,
            Maximum = 2,
            Default = LocalPlayer.Config.Speed.JumpInterval,
            Precision = 1,
            Callback = function(value)
                Speed.SetJumpInterval(value)
            end
        }, "SpeedJumpInterval")
        uiElements.SpeedPulseTPDistance = UI.Sections.Speed:Slider({
            Name = "PulseTP Dist",
            Minimum = 1,
            Maximum = 20,
            Default = LocalPlayer.Config.Speed.PulseTPDist,
            Precision = 1,
            Callback = function(value)
                Speed.SetPulseTPDistance(value)
            end
        }, "SpeedPulseTPDistance")
        uiElements.SpeedPulseTPFrequency = UI.Sections.Speed:Slider({
            Name = "PulseTP Delay",
            Minimum = 0.1,
            Maximum = 1,
            Default = LocalPlayer.Config.Speed.PulseTPDelay,
            Precision = 2,
            Callback = function(value)
                Speed.SetPulseTPFrequency(value)
            end
        }, "SpeedPulseTPFrequency")
        uiElements.SpeedKey = UI.Sections.Speed:Keybind({
            Name = "Toggle Key",
            Default = LocalPlayer.Config.Speed.ToggleKey,
            Callback = function(value)
                SpeedStatus.Key = value
                LocalPlayer.Config.Speed.ToggleKey = value
                if isInputFocused() then return end
                if SpeedStatus.Enabled then
                    if SpeedStatus.Running then Speed.Stop() else Speed.Start() end
                else
                    notify("Speed", "Enable Speed to use keybind.", true)
                end
            end
        }, "SpeedKey")
    end

    if UI.Sections.TickSpeed then
        UI.Sections.TickSpeed:Header({ Name = "TickSpeed" })
        uiElements.TickSpeedEnabled = UI.Sections.TickSpeed:Toggle({
            Name = "Enabled",
            Default = LocalPlayer.Config.TickSpeed.Enabled,
            Callback = function(value)
                TickSpeedStatus.Enabled = value
                LocalPlayer.Config.TickSpeed.Enabled = value
                if value then TickSpeed.Start() else TickSpeed.Stop() end
            end
        }, "TickSpeedEnabled")
        uiElements.TickSpeedHighMultiplier = UI.Sections.TickSpeed:Slider({
            Name = "High Speed Multiplier",
            Minimum = 1,
            Maximum = 3,
            Default = LocalPlayer.Config.TickSpeed.HighSpeedMultiplier,
            Precision = 1,
            Callback = function(value)
                TickSpeed.SetHighSpeedMultiplier(value)
            end
        }, "TickSpeedHighMultiplier")
        uiElements.TickSpeedNormalMultiplier = UI.Sections.TickSpeed:Slider({
            Name = "Normal Speed Multiplier",
            Minimum = 0.1,
            Maximum = 1,
            Default = LocalPlayer.Config.TickSpeed.NormalSpeedMultiplier,
            Precision = 1,
            Callback = function(value)
                TickSpeed.SetNormalSpeedMultiplier(value)
            end
        }, "TickSpeedNormalMultiplier")
        uiElements.TickSpeedOnDuration = UI.Sections.TickSpeed:Slider({
            Name = "On Duration",
            Minimum = 0.05,
            Maximum = 0.5,
            Default = LocalPlayer.Config.TickSpeed.OnDuration,
            Precision = 2,
            Callback = function(value)
                TickSpeed.SetOnDuration(value)
            end
        }, "TickSpeedOnDuration")
        uiElements.TickSpeedOffDuration = UI.Sections.TickSpeed:Slider({
            Name = "Off Duration",
            Minimum = 0.1,
            Maximum = 0.5,
            Default = LocalPlayer.Config.TickSpeed.OffDuration,
            Precision = 2,
            Callback = function(value)
                TickSpeed.SetOffDuration(value)
            end
        }, "TickSpeedOffDuration")
        uiElements.TickSpeedKey = UI.Sections.TickSpeed:Keybind({
            Name = "Toggle Key",
            Default = LocalPlayer.Config.TickSpeed.ToggleKey,
            Callback = function(value)
                TickSpeedStatus.Key = value
                LocalPlayer.Config.TickSpeed.ToggleKey = value
                if isInputFocused() then return end
                if TickSpeedStatus.Enabled then
                    if TickSpeedStatus.Running then TickSpeed.Stop() else TickSpeed.Start() end
                else
                    notify("TickSpeed", "Enable TickSpeed to use keybind.", true)
                end
            end
        }, "TickSpeedKey")
    end

    if UI.Sections.HighJump then
        UI.Sections.HighJump:Header({ Name = "HighJump" })
        uiElements.HighJumpEnabled = UI.Sections.HighJump:Toggle({
            Name = "Enabled",
            Default = LocalPlayer.Config.HighJump.Enabled,
            Callback = function(value)
                HighJumpStatus.Enabled = value
                LocalPlayer.Config.HighJump.Enabled = value
                if not value then
                    HighJump.RestoreJumpHeight()
                end
                notify("HighJump", "HighJump " .. (value and "Enabled" or "Disabled"), true)
            end
        }, "HighJumpEnabled")
        uiElements.HighJumpMethod = UI.Sections.HighJump:Dropdown({
            Name = "Method",
            Options = {"Velocity", "CFrame"},
            Default = LocalPlayer.Config.HighJump.Method,
            Callback = function(value)
                HighJump.SetMethod(value)
            end
        }, "HighJumpMethod")
        uiElements.HighJumpPower = UI.Sections.HighJump:Slider({
            Name = "Jump Power",
            Minimum = 50,
            Maximum = 200,
            Default = LocalPlayer.Config.HighJump.JumpPower,
            Precision = 1,
            Callback = function(value)
                HighJump.SetJumpPower(value)
            end
        }, "HighJumpPower")
        uiElements.HighJumpKey = UI.Sections.HighJump:Keybind({
            Name = "Jump Key",
            Default = LocalPlayer.Config.HighJump.JumpKey,
            Callback = function(value)
                HighJumpStatus.Key = value
                LocalPlayer.Config.HighJump.JumpKey = value
                if isInputFocused() then return end
                HighJump.Trigger()
            end
        }, "HighJumpKey")
    end

    if UI.Sections.NoRagdoll then
        UI.Sections.NoRagdoll:Header({ Name = "NoRagdoll" })
        uiElements.NoRagdollEnabled = UI.Sections.NoRagdoll:Toggle({
            Name = "Enabled",
            Default = LocalPlayer.Config.NoRagdoll.Enabled,
            Callback = function(value)
                NoRagdollStatus.Enabled = value
                LocalPlayer.Config.NoRagdoll.Enabled = value
                if value then NoRagdoll.Start(LocalPlayerObj.Character) else NoRagdoll.Stop() end
            end
        }, "NoRagdollEnabled")
    end

    if UI.Sections.FastAttack then
        UI.Sections.FastAttack:Header({ Name = "FastAttack" })
        uiElements.FastAttackEnabled = UI.Sections.FastAttack:Toggle({
            Name = "Enabled",
            Default = LocalPlayer.Config.FastAttack.Enabled,
            Callback = function(value)
                FastAttackStatus.Enabled = value
                LocalPlayer.Config.FastAttack.Enabled = value
                if value then FastAttack.Start() else FastAttack.Stop() end
            end
        }, "FastAttackEnabled")
    end

    if UI.Sections.Invisible then
        UI.Sections.Invisible:Header({ Name = "Invisible" })
        uiElements.InvisibleEnabled = UI.Sections.Invisible:Toggle({
            Name = "Enabled",
            Default = LocalPlayer.Config.Invisible.Enabled,
            Callback = function(value)
                InvisibleStatus.Enabled = value
                LocalPlayer.Config.Invisible.Enabled = value
                if value then
                    if not InvisibleStatus.Running then Invisible.Toggle() end
                else
                    if InvisibleStatus.Running then Invisible.Toggle() end
                end
            end
        }, "InvisibleEnabled")
        uiElements.InvisibleMode = UI.Sections.Invisible:Dropdown({
            Name = "Mode",
            Options = {"Full", "Semi", "Low"},
            Default = LocalPlayer.Config.Invisible.Mode,
            Callback = function(value)
                Invisible.SetMode(value)
            end
        }, "InvisibleMode")
        uiElements.InvisibleBypass = UI.Sections.Invisible:Toggle({
            Name = "Bypass",
            Default = LocalPlayer.Config.Invisible.Bypass,
            Callback = function(value)
                Invisible.SetBypass(value)
            end
        }, "InvisibleBypass")
        uiElements.InvisibleKey = UI.Sections.Invisible:Keybind({
            Name = "Toggle Key",
            Default = LocalPlayer.Config.Invisible.ToggleKey,
            Callback = function(value)
                InvisibleStatus.Key = value
                LocalPlayer.Config.Invisible.ToggleKey = value
                if isInputFocused() then return end
                if InvisibleStatus.Enabled then
                    Invisible.Toggle()
                else
                    notify("Invisible", "Enable Invisible to use keybind.", true)
                end
            end
        }, "InvisibleKey")
    end

    local localconfigSection = UI.Tabs.Config:Section({ Name = "Local Player Sync", Side = "Right" })
    localconfigSection:Header({ Name = "LocalPlayer Settings Sync" })
    localconfigSection:Button({
        Name = "Sync Config",
        Callback = function()
            LocalPlayer.Config.Timer.Enabled = uiElements.TimerEnabled:GetState()
            LocalPlayer.Config.Timer.Speed = uiElements.TimerSpeed:GetValue()
            LocalPlayer.Config.Timer.ToggleKey = uiElements.TimerKey:GetBind()

            LocalPlayer.Config.Disabler.Enabled = uiElements.DisablerEnabled:GetState()
            LocalPlayer.Config.Disabler.ToggleKey = uiElements.DisablerKey:GetBind()

            LocalPlayer.Config.Speed.Enabled = uiElements.SpeedEnabled:GetState()
            LocalPlayer.Config.Speed.AutoJump = uiElements.SpeedAutoJump:GetState()
            local speedMethodOptions = uiElements.SpeedMethod:GetOptions()
            for option, selected in pairs(speedMethodOptions) do
                if selected then
                    LocalPlayer.Config.Speed.Method = option
                    break
                end
            end
            LocalPlayer.Config.Speed.Speed = uiElements.Speed:GetValue()
            LocalPlayer.Config.Speed.JumpPower = uiElements.SpeedJumpPower:GetValue()
            LocalPlayer.Config.Speed.JumpInterval = uiElements.SpeedJumpInterval:GetValue()
            LocalPlayer.Config.Speed.PulseTPDist = uiElements.SpeedPulseTPDistance:GetValue()
            LocalPlayer.Config.Speed.PulseTPDelay = uiElements.SpeedPulseTPFrequency:GetValue()
            LocalPlayer.Config.Speed.ToggleKey = uiElements.SpeedKey:GetBind()

            LocalPlayer.Config.TickSpeed.Enabled = uiElements.TickSpeedEnabled:GetState()
            LocalPlayer.Config.TickSpeed.HighSpeedMultiplier = uiElements.TickSpeedHighMultiplier:GetValue()
            LocalPlayer.Config.TickSpeed.NormalSpeedMultiplier = uiElements.TickSpeedNormalMultiplier:GetValue()
            LocalPlayer.Config.TickSpeed.OnDuration = uiElements.TickSpeedOnDuration:GetValue()
            LocalPlayer.Config.TickSpeed.OffDuration = uiElements.TickSpeedOffDuration:GetValue()
            LocalPlayer.Config.TickSpeed.ToggleKey = uiElements.TickSpeedKey:GetBind()

            LocalPlayer.Config.HighJump.Enabled = uiElements.HighJumpEnabled:GetState()
            local highJumpMethodOptions = uiElements.HighJumpMethod:GetOptions()
            for option, selected in pairs(highJumpMethodOptions) do
                if selected then
                    LocalPlayer.Config.HighJump.Method = option
                    break
                end
            end
            LocalPlayer.Config.HighJump.JumpPower = uiElements.HighJumpPower:GetValue()
            LocalPlayer.Config.HighJump.JumpKey = uiElements.HighJumpKey:GetBind()

            LocalPlayer.Config.NoRagdoll.Enabled = uiElements.NoRagdollEnabled:GetState()

            LocalPlayer.Config.FastAttack.Enabled = uiElements.FastAttackEnabled:GetState()

            LocalPlayer.Config.Invisible.Enabled = uiElements.InvisibleEnabled:GetState()
            local invisibleModeOptions = uiElements.InvisibleMode:GetOptions()
            for option, selected in pairs(invisibleModeOptions) do
                if selected then
                    LocalPlayer.Config.Invisible.Mode = option
                    break
                end
            end
            LocalPlayer.Config.Invisible.Bypass = uiElements.InvisibleBypass:GetState()
            LocalPlayer.Config.Invisible.ToggleKey = uiElements.InvisibleKey:GetBind()

            TimerStatus.Enabled = LocalPlayer.Config.Timer.Enabled
            TimerStatus.Speed = LocalPlayer.Config.Timer.Speed
            TimerStatus.Key = LocalPlayer.Config.Timer.ToggleKey
            if TimerStatus.Enabled then
                if not TimerStatus.Running then Timer.Start() end
            else
                if TimerStatus.Running then Timer.Stop() end
            end

            DisablerStatus.Enabled = LocalPlayer.Config.Disabler.Enabled
            DisablerStatus.Key = LocalPlayer.Config.Disabler.ToggleKey
            if DisablerStatus.Enabled then
                if not DisablerStatus.Running then Disabler.Start() end
            else
                if DisablerStatus.Running then Disabler.Stop() end
            end

            SpeedStatus.Enabled = LocalPlayer.Config.Speed.Enabled
            SpeedStatus.AutoJump = LocalPlayer.Config.Speed.AutoJump
            SpeedStatus.Method = LocalPlayer.Config.Speed.Method
            SpeedStatus.Speed = LocalPlayer.Config.Speed.Speed
            SpeedStatus.JumpPower = LocalPlayer.Config.Speed.JumpPower
            SpeedStatus.JumpInterval = LocalPlayer.Config.Speed.JumpInterval
            SpeedStatus.PulseTPDistance = LocalPlayer.Config.Speed.PulseTPDist
            SpeedStatus.PulseTPFrequency = LocalPlayer.Config.Speed.PulseTPDelay
            SpeedStatus.Key = LocalPlayer.Config.Speed.ToggleKey
            if SpeedStatus.Enabled then
                if not SpeedStatus.Running then Speed.Start() end
            else
                if SpeedStatus.Running then Speed.Stop() end
            end

            TickSpeedStatus.Enabled = LocalPlayer.Config.TickSpeed.Enabled
            TickSpeedStatus.HighSpeedMultiplier = LocalPlayer.Config.TickSpeed.HighSpeedMultiplier
            TickSpeedStatus.NormalSpeedMultiplier = LocalPlayer.Config.TickSpeed.NormalSpeedMultiplier
            TickSpeedStatus.OnDuration = LocalPlayer.Config.TickSpeed.OnDuration
            TickSpeedStatus.OffDuration = LocalPlayer.Config.TickSpeed.OffDuration
            TickSpeedStatus.Key = LocalPlayer.Config.TickSpeed.ToggleKey
            if TickSpeedStatus.Enabled then
                if not TickSpeedStatus.Running then TickSpeed.Start() end
            else
                if TickSpeedStatus.Running then TickSpeed.Stop() end
            end

            HighJumpStatus.Enabled = LocalPlayer.Config.HighJump.Enabled
            HighJumpStatus.Method = LocalPlayer.Config.HighJump.Method
            HighJumpStatus.JumpPower = LocalPlayer.Config.HighJump.JumpPower
            HighJumpStatus.Key = LocalPlayer.Config.HighJump.JumpKey
            if not HighJumpStatus.Enabled then
                HighJump.RestoreJumpHeight()
            end

            NoRagdollStatus.Enabled = LocalPlayer.Config.NoRagdoll.Enabled
            if NoRagdollStatus.Enabled then
                NoRagdoll.Start(LocalPlayerObj.Character)
            else
                NoRagdoll.Stop()
            end

            FastAttackStatus.Enabled = LocalPlayer.Config.FastAttack.Enabled
            if FastAttackStatus.Enabled then
                FastAttack.Start()
            else
                FastAttack.Stop()
            end

            InvisibleStatus.Enabled = LocalPlayer.Config.Invisible.Enabled
            InvisibleStatus.Mode = LocalPlayer.Config.Invisible.Mode
            InvisibleStatus.Bypass = LocalPlayer.Config.Invisible.Bypass
            InvisibleStatus.Key = LocalPlayer.Config.Invisible.ToggleKey
            if InvisibleStatus.Enabled then
                if not InvisibleStatus.Running then Invisible.Toggle() end
            else
                if InvisibleStatus.Running then Invisible.Toggle() end
            end

            notify("LocalPlayer", "Config synchronized!", true)
        end
    })
end

function LocalPlayer.Init(UI, coreParam, notifyFunc)
    core = coreParam
    Services = core.Services
    PlayerData = core.PlayerData
    notify = notifyFunc
    LocalPlayerObj = PlayerData.LocalPlayer

    _G.setTimerSpeed = Timer.SetSpeed
    _G.setSpeed = Speed.SetSpeed

    if LocalPlayerObj then
        LocalPlayerObj.CharacterAdded:Connect(function(newChar)
            if NoRagdollStatus.Enabled then
                NoRagdoll.Start(newChar)
            end
            if TickSpeedStatus.Enabled then
                TickSpeed.Start()
            end
            if not HighJumpStatus.Enabled then
                HighJump.RestoreJumpHeight()
            end
            if InvisibleStatus.Enabled and not InvisibleStatus.Running then
                Invisible.Toggle()
            end
        end)
    end

    SetupUI(UI)

    if not HighJumpStatus.Enabled then
        HighJump.RestoreJumpHeight()
    end

    removeFolders()
end

return LocalPlayer

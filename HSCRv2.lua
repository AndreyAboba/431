local HSCR = {}

local CrosshairSettings = {
    Enabled = false,
    Style = { Value = "Dot", Default = "Dot" },
    Size = { Value = 18, Default = 18 },
    Gap = { Value = 5, Default = 5 },
    Length = { Value = 8, Default = 8 },
    DotSize = { Value = 20, Default = 20 },
    DotInnerSize = { Value = 4, Default = 4 },
    DotOutlineThickness = { Value = 2, Default = 2 },
    GradientColor = Color3.fromRGB(0, 0, 255),
    ExpandDistance = { Value = 0.8, Default = 0.8 },
    ExpandDuration = { Value = 0.08, Default = 0.08 },
    ShrinkDuration = { Value = 0.05, Default = 0.05 },
    HeadshotSoundEnabled = false,
    SelectedSound = { Value = "Default", Default = "Default" },
    SoundData = {
        { Label = "Default", SoundId = "138464116325809" },
        { Label = "KillSound", SoundId = "132390332380260" },
        { Label = "Bubble2", SoundId = "9086370184" },
        { Label = "KillSound2", SoundId = "121311089745141" },
        { Label = "KillSound3", SoundId = "104467173440576" },
        { Label = "OUH", SoundId = "7246809481" },
        { Label = "Fart", SoundId = "5622443597" },
        { Label = "PUI", SoundId = "105190141089785" },
        { Label = "minecraftEXP", SoundId = "1053296915" },
        { Label = "Minecraft2", SoundId = "135478009117226" },
        { Label = "TF2 HS", SoundId = "90342360691837" },
        { Label = "CriminalityHS", SoundId = "83773429281082" },
        { Label = "neverlose", SoundId = "97643101798871" },
        { Label = "bameware", SoundId = "92614567965693" },
        { Label = "fatality", SoundId = "115982072912004" },
        { Label = "csgoHS", SoundId = "6937353691" },
        { Label = "PopHS", SoundId = "105543133746827" },
        { Label = "BubblePop", SoundId = "119697580657161" },
        { Label = "NiggaHS", SoundId = "4868633804" },
        { Label = "IdkHS", SoundId = "102911066745395" },
    },
    SoundIds = {},
    OriginalSounds = {
        headshotSound = "138464116325809",
        headshotNormalSound = "135358980250767",
        hitSound = "100758444127105"
    },
    OriginalElements = {},
    OriginalBulletsColor = nil
}

function HSCR.Init(UI, Core, notify)
    local TweenService = game:GetService("TweenService")
    local RunService = game:GetService("RunService")
    local ContentProvider = game:GetService("ContentProvider")
    local SoundService = game:GetService("SoundService")

    local u1 = require(game.ReplicatedStorage.Modules.Core.Audio)
    local u5 = require(game.ReplicatedStorage.Modules.Core.UI)
    local u4 = require(game.ReplicatedStorage.Modules.Core.Util)
    local u6 = require(game.ReplicatedStorage.Modules.Core.Net)
    local u7 = require(game.ReplicatedStorage.Modules.Game.UI.RadialModule)
    local v3 = require(game.ReplicatedStorage.Modules.Core.State)

    if not v3 then
        warn("Failed to load ReplicatedStorage.Modules.Core.State")
        return
    end

    local crosshairScreenGui = u5.get("CrosshairScreenGui")
    local crosshairFrame = u5.get("CrosshairFrame")
    local bulletsLabel = u5.get("Bullets")
    local frame1 = crosshairFrame and crosshairFrame:FindFirstChild("Frame1") and crosshairFrame.Frame1:FindFirstChild("ImageLabel")
    local frame2 = crosshairFrame and crosshairFrame:FindFirstChild("Frame2") and crosshairFrame.Frame2:FindFirstChild("ImageLabel")

    if not crosshairFrame then
        local attempts = 0
        while not crosshairFrame and attempts < 10 do
            task.wait(1)
            crosshairFrame = u5.get("CrosshairFrame")
            attempts = attempts + 1
            warn("Attempt " .. attempts .. " to find crosshairFrame")
        end
        if not crosshairFrame then
            warn("Failed to initialize: CrosshairFrame not found after 10 seconds")
            return
        end
        frame1 = crosshairFrame:FindFirstChild("Frame1") and crosshairFrame.Frame1:FindFirstChild("ImageLabel")
        frame2 = crosshairFrame:FindFirstChild("Frame2") and crosshairFrame.Frame2:FindFirstChild("ImageLabel")
    end

    crosshairFrame.AnchorPoint = Vector2.new(0.5, 0.5)

    local soundsToPreload = {
        CrosshairSettings.OriginalSounds.headshotSound,
        CrosshairSettings.OriginalSounds.headshotNormalSound,
        CrosshairSettings.OriginalSounds.hitSound
    }
    for _, soundData in ipairs(CrosshairSettings.SoundData) do
        table.insert(soundsToPreload, soundData.SoundId)
    end
    ContentProvider:PreloadAsync(soundsToPreload)

    if bulletsLabel then
        CrosshairSettings.OriginalBulletsColor = bulletsLabel.TextColor3
        bulletsLabel.TextColor3 = CrosshairSettings.GradientColor
    end

    local AnimationFunctions = {}
    local radial = u7.new(crosshairFrame)

    local function updateCrosshairDesign()
        if not crosshairFrame or not crosshairFrame.Parent then
            warn("crosshairFrame not found or parented")
            return
        end

        for _, child in pairs(crosshairFrame:GetChildren()) do
            if child.Name ~= "Frame1" and child.Name ~= "Frame2" then
                child:Destroy()
            end
        end

        if not CrosshairSettings.Enabled then
            if frame1 then frame1.Visible = CrosshairSettings.OriginalElements.Frame1Visible or true end
            if frame2 then frame2.Visible = CrosshairSettings.OriginalElements.Frame2Visible or true end
            crosshairFrame.Size = CrosshairSettings.OriginalElements.Size or UDim2.fromOffset(18, 18)
            if bulletsLabel then
                bulletsLabel.TextColor3 = CrosshairSettings.OriginalBulletsColor or Color3.fromRGB(255, 255, 255)
            end
            return
        end

        crosshairFrame.Size = UDim2.fromOffset(CrosshairSettings.Size.Value, CrosshairSettings.Size.Value)
        crosshairFrame.BackgroundTransparency = 1

        if frame1 then frame1.Visible = false end
        if frame2 then frame2.Visible = false end

        if bulletsLabel then
            bulletsLabel.TextColor3 = CrosshairSettings.GradientColor
        end

        if CrosshairSettings.Style.Value == "Dot" then
            local dot = Instance.new("Frame")
            dot.Name = "Dot"
            dot.Size = UDim2.new(0, CrosshairSettings.DotSize.Value, 0, CrosshairSettings.DotSize.Value)
            dot.Position = UDim2.new(0.5, -CrosshairSettings.DotSize.Value / 2, 0.5, -CrosshairSettings.DotSize.Value / 2)
            dot.BackgroundTransparency = 1
            dot.BorderSizePixel = 0
            dot.Parent = crosshairFrame

            local stroke = Instance.new("UIStroke")
            stroke.Thickness = CrosshairSettings.DotOutlineThickness.Value
            stroke.Color = CrosshairSettings.GradientColor
            stroke.Parent = dot

            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(1, 0)
            corner.Parent = dot

            local innerDot = Instance.new("Frame")
            innerDot.Name = "InnerDot"
            innerDot.Size = UDim2.new(0, CrosshairSettings.DotInnerSize.Value, 0, CrosshairSettings.DotInnerSize.Value)
            innerDot.Position = UDim2.new(0.5, -CrosshairSettings.DotInnerSize.Value / 2, 0.5, -CrosshairSettings.DotInnerSize.Value / 2)
            innerDot.BackgroundColor3 = CrosshairSettings.GradientColor
            innerDot.BorderSizePixel = 0
            innerDot.Parent = dot

            local innerCorner = Instance.new("UICorner")
            innerCorner.CornerRadius = UDim.new(1, 0)
            innerCorner.Parent = innerDot
        elseif CrosshairSettings.Style.Value == "Default" then
            local gap = CrosshairSettings.Gap.Value
            local length = CrosshairSettings.Length.Value
            local thickness = 2

            local top = Instance.new("Frame")
            top.Name = "Top"
            top.Size = UDim2.new(0, thickness, 0, length)
            top.Position = UDim2.new(0.5, -thickness / 2, 0.5, -gap - length)
            top.BackgroundColor3 = CrosshairSettings.GradientColor
            top.BorderSizePixel = 0
            top.Parent = crosshairFrame

            local right = Instance.new("Frame")
            right.Name = "Right"
            right.Size = UDim2.new(0, length, 0, thickness)
            right.Position = UDim2.new(0.5, gap, 0.5, -thickness / 2)
            right.BackgroundColor3 = CrosshairSettings.GradientColor
            right.BorderSizePixel = 0
            right.Parent = crosshairFrame

            local bottom = Instance.new("Frame")
            bottom.Name = "Bottom"
            bottom.Size = UDim2.new(0, thickness, 0, length)
            bottom.Position = UDim2.new(0.5, -thickness / 2, 0.5, gap)
            bottom.BackgroundColor3 = CrosshairSettings.GradientColor
            bottom.BorderSizePixel = 0
            bottom.Parent = crosshairFrame

            local left = Instance.new("Frame")
            left.Name = "Left"
            left.Size = UDim2.new(0, length, 0, thickness)
            left.Position = UDim2.new(0.5, -gap - length, 0.5, -thickness / 2)
            left.BackgroundColor3 = CrosshairSettings.GradientColor
            left.BorderSizePixel = 0
            left.Parent = crosshairFrame
        end
    end

    AnimationFunctions.updateCrosshairDesign = updateCrosshairDesign

    local function initiate()
        CrosshairSettings.OriginalElements.Size = crosshairFrame.Size
        CrosshairSettings.OriginalElements.Frame1Visible = frame1 and frame1.Visible
        CrosshairSettings.OriginalElements.Frame2Visible = frame2 and frame2.Visible

        AnimationFunctions.updateCrosshairDesign()

        local u27 = {
            is_reloading = v3.new(false),
            reloading_length = v3.new(0),
        }

        if not u27.is_reloading or not u27.reloading_length then
            warn("Failed to initialize state objects for is_reloading or reloading_length")
            return
        end

        if radial and radial.Init then
            pcall(function() radial:Init() end)
            pcall(function() radial:SetProgress(100) end)
            pcall(function() radial:SetProgressColor(CrosshairSettings.GradientColor) end)
        end

        local lastIsReloading = u27.is_reloading:get()
        RunService.Heartbeat:Connect(function()
            if not CrosshairSettings.Enabled then return end

            local isReloading = u27.is_reloading:get()
            if isReloading ~= lastIsReloading then
                lastIsReloading = isReloading
                if isReloading then
                    local length = u27.reloading_length:get()
                    if radial and radial.SetProgress and radial.TweenProgress then
                        pcall(function() radial:SetProgress(0) end)
                        pcall(function() radial:TweenProgress(100, length) end)
                    end
                elseif radial and radial.StopAnimating then
                    pcall(function() radial:StopAnimating(true) end)
                end
            end
        end)

        u27.hitmarker = function(isHeadshot, isKill)
            warn("Hitmarker triggered: isHeadshot=" .. tostring(isHeadshot) .. ", isKill=" .. tostring(isKill))
            if isKill and CrosshairSettings.HeadshotSoundEnabled then
                local selectedSoundId = CrosshairSettings.SoundIds[CrosshairSettings.SelectedSound.Value] or CrosshairSettings.OriginalSounds.headshotSound
                u1.play(selectedSoundId, 2.5, 1, SoundService)
            elseif isHeadshot and CrosshairSettings.HeadshotSoundEnabled then
                u1.play(CrosshairSettings.OriginalSounds.headshotNormalSound, 1, 1, SoundService)
            elseif not CrosshairSettings.HeadshotSoundEnabled then
                if isHeadshot then
                    u1.play(CrosshairSettings.OriginalSounds.headshotNormalSound, 1, 1, SoundService)
                elseif isKill then
                    u1.play(CrosshairSettings.OriginalSounds.headshotSound, 2.5, 1, SoundService)
                else
                    u1.play(CrosshairSettings.OriginalSounds.hitSound, 1, 1, SoundService)
                end
            end
        end

        local originalU27 = require(game.ReplicatedStorage.Modules.Game.UI.Crosshair)
        if originalU27 then
            if originalU27.hitmarker then
                originalU27.hitmarker = u27.hitmarker
            end
        end
        u6.hook("hit_confirmed", u27.hitmarker)
    end

    initiate()

    local uiElements = {}

    task.defer(function()
        local section = UI.Tabs.Visuals:Section({ Name = "Custom Crosshair & Hitsound", Side = "Right" })
        section:Header({ Name = "Crosshair Settings" })

        uiElements.Enabled = {
            element = section:Toggle({
                Name = "Enabled",
                Default = CrosshairSettings.Enabled,
                Callback = function(value)
                    CrosshairSettings.Enabled = value
                    AnimationFunctions.updateCrosshairDesign()
                end
            }, "CustomCrosshairEnabled"),
            callback = function(value)
                CrosshairSettings.Enabled = value
                AnimationFunctions.updateCrosshairDesign()
            end
        }

        uiElements.Style = {
            element = section:Dropdown({
                Name = "Style",
                Options = {"Dot", "Default"},
                Default = CrosshairSettings.Style.Default,
                Callback = function(value)
                    CrosshairSettings.Style.Value = value
                    AnimationFunctions.updateCrosshairDesign()
                end
            }, "CrosshairStyle"),
            callback = function(value)
                CrosshairSettings.Style.Value = value
                AnimationFunctions.updateCrosshairDesign()
            end
        }

        uiElements.Size = {
            element = section:Slider({
                Name = "Size",
                Minimum = 10,
                Maximum = 30,
                Default = CrosshairSettings.Size.Default,
                Precision = 0,
                Callback = function(value)
                    CrosshairSettings.Size.Value = value
                    AnimationFunctions.updateCrosshairDesign()
                end
            }, "CrosshairSize"),
            callback = function(value)
                CrosshairSettings.Size.Value = value
                AnimationFunctions.updateCrosshairDesign()
            end
        }

        uiElements.Gap = {
            element = section:Slider({
                Name = "Gap (Default Style)",
                Minimum = 2,
                Maximum = 10,
                Default = CrosshairSettings.Gap.Default,
                Precision = 0,
                Callback = function(value)
                    CrosshairSettings.Gap.Value = value
                    AnimationFunctions.updateCrosshairDesign()
                end
            }, "CrosshairGap"),
            callback = function(value)
                CrosshairSettings.Gap.Value = value
                AnimationFunctions.updateCrosshairDesign()
            end
        }

        uiElements.Length = {
            element = section:Slider({
                Name = "Length (Default Style)",
                Minimum = 4,
                Maximum = 12,
                Default = CrosshairSettings.Length.Default,
                Precision = 0,
                Callback = function(value)
                    CrosshairSettings.Length.Value = value
                    AnimationFunctions.updateCrosshairDesign()
                end
            }, "CrosshairLength"),
            callback = function(value)
                CrosshairSettings.Length.Value = value
                AnimationFunctions.updateCrosshairDesign()
            end
        }

        uiElements.DotSize = {
            element = section:Slider({
                Name = "Dot Size (Dot Style)",
                Minimum = 10,
                Maximum = 30,
                Default = CrosshairSettings.DotSize.Default,
                Precision = 0,
                Callback = function(value)
                    CrosshairSettings.DotSize.Value = value
                    AnimationFunctions.updateCrosshairDesign()
                end
            }, "CrosshairDotSize"),
            callback = function(value)
                CrosshairSettings.DotSize.Value = value
                AnimationFunctions.updateCrosshairDesign()
            end
        }

        uiElements.DotInnerSize = {
            element = section:Slider({
                Name = "Dot Inner Size (Dot Style)",
                Minimum = 2,
                Maximum = 10,
                Default = CrosshairSettings.DotInnerSize.Default,
                Precision = 0,
                Callback = function(value)
                    CrosshairSettings.DotInnerSize.Value = value
                    AnimationFunctions.updateCrosshairDesign()
                end
            }, "CrosshairDotInnerSize"),
            callback = function(value)
                CrosshairSettings.DotInnerSize.Value = value
                AnimationFunctions.updateCrosshairDesign()
            end
        }

        uiElements.DotOutlineThickness = {
            element = section:Slider({
                Name = "Dot Outline Thickness (Dot Style)",
                Minimum = 1,
                Maximum = 5,
                Default = CrosshairSettings.DotOutlineThickness.Default,
                Precision = 0,
                Callback = function(value)
                    CrosshairSettings.DotOutlineThickness.Value = value
                    AnimationFunctions.updateCrosshairDesign()
                end
            }, "CrosshairDotOutlineThickness"),
            callback = function(value)
                CrosshairSettings.DotOutlineThickness.Value = value
                AnimationFunctions.updateCrosshairDesign()
            end
        }

        uiElements.ExpandDistance = {
            element = section:Slider({
                Name = "Expand Distance",
                Minimum = 0.1,
                Maximum = 1,
                Default = CrosshairSettings.ExpandDistance.Default,
                Precision = 1,
                Callback = function(value)
                    CrosshairSettings.ExpandDistance.Value = value
                end
            }, "CrosshairExpandDistance"),
            callback = function(value)
                CrosshairSettings.ExpandDistance.Value = value
            end
        }

        uiElements.ExpandDuration = {
            element = section:Slider({
                Name = "Expand Duration",
                Minimum = 0.05,
                Maximum = 0.5,
                Default = CrosshairSettings.ExpandDuration.Default,
                Precision = 2,
                Callback = function(value)
                    CrosshairSettings.ExpandDuration.Value = value
                end
            }, "CrosshairExpandDuration"),
            callback = function(value)
                CrosshairSettings.ExpandDuration.Value = value
            end
        }

        uiElements.ShrinkDuration = {
            element = section:Slider({
                Name = "Shrink Duration",
                Minimum = 0.05,
                Maximum = 0.5,
                Default = CrosshairSettings.ShrinkDuration.Default,
                Precision = 2,
                Callback = function(value)
                    CrosshairSettings.ShrinkDuration.Value = value
                end
            }, "CrosshairShrinkDuration"),
            callback = function(value)
                CrosshairSettings.ShrinkDuration.Value = value
            end
        }

        uiElements.GradientColor = {
            element = section:Colorpicker({
                Name = "Crosshair Color",
                Default = CrosshairSettings.GradientColor,
                Callback = function(value)
                    CrosshairSettings.GradientColor = value
                    AnimationFunctions.updateCrosshairDesign()
                end
            }, "GradientColor"),
            callback = function(value)
                CrosshairSettings.GradientColor = value
                AnimationFunctions.updateCrosshairDesign()
            end
        }

        section:Header({ Name = "Hitsound Settings" })

        uiElements.HeadshotSoundEnabled = {
            element = section:Toggle({
                Name = "Enable Hitsound",
                Default = CrosshairSettings.HeadshotSoundEnabled,
                Callback = function(value)
                    CrosshairSettings.HeadshotSoundEnabled = value
                end
            }, "HeadshotSoundEnabled"),
            callback = function(value)
                CrosshairSettings.HeadshotSoundEnabled = value
            end
        }

        local soundOptions = {}
        for _, sound in ipairs(CrosshairSettings.SoundData) do
            table.insert(soundOptions, sound.Label)
        end

        uiElements.SelectedSound = {
            element = section:Dropdown({
                Name = "Sound",
                Options = soundOptions,
                Default = CrosshairSettings.SelectedSound.Default,
                Callback = function(value)
                    if value and type(value) == "string" then
                        for _, sound in ipairs(CrosshairSettings.SoundData) do
                            if sound.Label == value then
                                CrosshairSettings.SelectedSound.Value = value
                                CrosshairSettings.SoundIds[value] = sound.SoundId
                                break
                            end
                        end
                    end
                end
            }, "HeadshotSound"),
            callback = function(value)
                if value and type(value) == "string" then
                    for _, sound in ipairs(CrosshairSettings.SoundData) do
                        if sound.Label == value then
                            CrosshairSettings.SelectedSound.Value = value
                            CrosshairSettings.SoundIds[value] = sound.SoundId
                            break
                        end
                    end
                end
            end
        }

        local configSection = UI.Tabs.Config:Section({ Name = "Crosshair Config", Side = "Right" })
        configSection:Header({ Name = "Crosshair Settings Sync" })
        configSection:Button({
            Name = "Sync Config",
            Callback = function()
                uiElements.Enabled.callback(uiElements.Enabled.element:GetState())

                local styleOptions = uiElements.Style.element:GetOptions()
                for option, selected in pairs(styleOptions) do
                    if selected then
                        uiElements.Style.callback(option)
                        break
                    end
                end

                uiElements.Size.callback(uiElements.Size.element:GetValue())
                uiElements.Gap.callback(uiElements.Gap.element:GetValue())
                uiElements.Length.callback(uiElements.Length.element:GetValue())
                uiElements.DotSize.callback(uiElements.DotSize.element:GetValue())
                uiElements.DotInnerSize.callback(uiElements.DotInnerSize.element:GetValue())
                uiElements.DotOutlineThickness.callback(uiElements.DotOutlineThickness.element:GetValue())
                uiElements.ExpandDistance.callback(uiElements.ExpandDistance.element:GetValue())
                uiElements.ExpandDuration.callback(uiElements.ExpandDuration.element:GetValue())
                uiElements.ShrinkDuration.callback(uiElements.ShrinkDuration.element:GetValue())

                uiElements.HeadshotSoundEnabled.callback(uiElements.HeadshotSoundEnabled.element:GetState())

                local soundOptions = uiElements.SelectedSound.element:GetOptions()
                for option, selected in pairs(soundOptions) do
                    if selected then
                        uiElements.SelectedSound.callback(option)
                        break
                    end
                end

                notify("Crosshair", "Settings synchronized with UI!", true)
            end
        }, "SyncConfig")
    end)
end

return HSCR

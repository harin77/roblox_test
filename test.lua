-- ==============================================================================
-- SUHO ADVANCED COMBAT ENGINE (AIMLOCK, PREDICTION & SILENT AIM SUITE)
-- Complete Luau Module: Math Vector Prediction, Mouse Hooking & FOV Rendering
-- ==============================================================================

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-- Cleanup Previous Instances
pcall(function()
    if CoreGui:FindFirstChild("SuhoAimSuite") then CoreGui.SuhoAimSuite:Destroy() end
    if LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("SuhoAimSuite") then
        LocalPlayer.PlayerGui.SuhoAimSuite:Destroy()
    end
end)

-- ==============================================================================
-- 1. CONFIGURATION & STATE REPOSITORY
-- ==============================================================================
local Settings = {
    -- Master Core
    AimlockPlayers = false,
    SilentAimPlayers = false,
    SilentAimNPC = false,

    -- Aimlock Configuration
    AimlockRange = 1000,
    AimlockPrediction = true,
    AimlockPredictionAmount = 0.12,
    TargetLowestHP = false,
    AimlockKey = Enum.KeyCode.E,

    -- Silent Aim Configuration
    SARange = 1000,
    SAPrediction = true,
    SAPredictionAmount = 0.20,

    -- Skill Routing
    SkillRouting = true,

    -- Visuals
    FOVRingGatesAimlock = true,
    HighlightTarget = true,
    ShowTracer = true,
    ShowFOVRing = true,
    FOVSize = 200,
    FOVColor = Color3.fromRGB(0, 220, 255),
    TargetColor = Color3.fromRGB(255, 40, 40)
}

local Runtime = {
    CurrentAimlockTarget = nil,
    CurrentSilentTarget = nil,
    AimlockActive = false,
    ScreenCenter = Vector2.zero
}

-- ==============================================================================
-- 2. MATH UTILITIES & TARGETING PIPELINE
-- ==============================================================================
local function getRoot(character)
    if not character then return nil end
    return character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
end

local function getHumanoid(character)
    if not character then return nil end
    return character:FindFirstChildOfClass("Humanoid")
end

local function isEntityAlive(character)
    local hum = getHumanoid(character)
    return hum and hum.Health > 0
end

local function getPredictedPosition(targetPart, predictionMultiplier)
    if not targetPart then return Vector3.zero end
    local velocity = targetPart.AssemblyLinearVelocity or targetPart.Velocity or Vector3.zero
    return targetPart.Position + (velocity * predictionMultiplier)
end

local function isPointInsideFOV(screenPosition, origin, radius)
    return (Vector2.new(screenPosition.X, screenPosition.Y) - origin).Magnitude <= radius
end

-- Pipeline for selecting the best Aimlock candidate
local function acquireAimlockCandidate()
    local myChar = LocalPlayer.Character
    local myRoot = getRoot(myChar)
    if not myRoot then return nil end

    local bestTarget = nil
    local shortestMetric = math.huge
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and isEntityAlive(player.Character) then
            local targetRoot = getRoot(player.Character)
            local targetHum = getHumanoid(player.Character)

            if targetRoot and targetHum then
                local worldDistance = (targetRoot.Position - myRoot.Position).Magnitude
                if worldDistance <= Settings.AimlockRange then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(targetRoot.Position)
                    local screenVector = Vector2.new(screenPos.X, screenPos.Y)
                    local fovDist = (screenVector - screenCenter).Magnitude

                    -- Check FOV constraint if enabled
                    local fovValid = true
                    if Settings.FOVRingGatesAimlock then
                        fovValid = onScreen and (fovDist <= Settings.FOVSize)
                    end

                    if fovValid then
                        if Settings.TargetLowestHP then
                            if targetHum.Health < shortestMetric then
                                shortestMetric = targetHum.Health
                                bestTarget = player.Character
                            end
                        else
                            local cursorMetric = fovDist
                            if cursorMetric < shortestMetric then
                                shortestMetric = cursorMetric
                                bestTarget = player.Character
                            end
                        end
                    end
                end
            end
        end
    end

    return bestTarget
end

-- Pipeline for acquiring Silent Aim candidate (Global or NPC inclusive)
local function acquireSilentCandidate()
    local myChar = LocalPlayer.Character
    local myRoot = getRoot(myChar)
    if not myRoot then return nil end

    local bestTarget = nil
    local shortestDist = Settings.SARange

    -- Scan Players
    if Settings.SilentAimPlayers then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character and isEntityAlive(player.Character) then
                local targetRoot = getRoot(player.Character)
                if targetRoot then
                    local dist = (targetRoot.Position - myRoot.Position).Magnitude
                    if dist <= shortestDist then
                        shortestDist = dist
                        bestTarget = targetRoot
                    end
                end
            end
        end
    end

    -- Scan Workspace NPCs / Enemies
    if Settings.SilentAimNPC then
        local searchFolders = { Workspace:FindFirstChild("Enemies"), Workspace:FindFirstChild("NPCs"), Workspace }
        for _, folder in ipairs(searchFolders) do
            if folder then
                for _, model in ipairs(folder:GetChildren()) do
                    if model:IsA("Model") and not Players:GetPlayerFromCharacter(model) and isEntityAlive(model) then
                        local root = getRoot(model)
                        if root then
                            local dist = (root.Position - myRoot.Position).Magnitude
                            if dist <= shortestDist then
                                shortestDist = dist
                                bestTarget = root
                            end
                        end
                    end
                end
            end
        end
    end

    return bestTarget
end

-- ==============================================================================
-- 3. SILENT AIM METAMETHOD HOOK (HOOKMETAMETHOD IMPLEMENTATION)
-- ==============================================================================
local OriginalNamecall = nil
local OriginalIndex = nil

local function setupSilentMetatableHooks()
    if not hookmetamethod then
        warn("[SUHO SA] Executor does not support hookmetamethod. Silent Aim will run on soft mode.")
        return
    end

    local rawMeta = getrawmetatable(game)
    setreadonly(rawMeta, false)

    OriginalNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local method = getnamecallmethod()
        local args = { ... }

        if Settings.SilentAimPlayers or Settings.SilentAimNPC then
            if Runtime.CurrentSilentTarget and isEntityAlive(Runtime.CurrentSilentTarget.Parent) then
                local targetHit = Runtime.CurrentSilentTarget.Position
                if Settings.SAPrediction then
                    targetHit = getPredictedPosition(Runtime.CurrentSilentTarget, Settings.SAPredictionAmount)
                end

                -- CommF_ Remote invocation spoofing for Skill / Combat routing
                if Settings.SkillRouting and tostring(self) == "CommF_" and (args[1] == "Attack" or args[1] == "Skill") then
                    args[2] = targetHit
                    return OriginalNamecall(self, table.unpack(args))
                end

                -- Raycast parameter diversion
                if method == "Raycast" and self == Workspace then
                    if typeof(args[2]) == "Vector3" then
                        args[2] = (targetHit - args[1]).Unit * args[2].Magnitude
                        return OriginalNamecall(self, table.unpack(args))
                    end
                end
            end
        end

        return OriginalNamecall(self, ...)
    end))

    OriginalIndex = hookmetamethod(game, "__index", newcclosure(function(self, key)
        if not checkcaller() and (Settings.SilentAimPlayers or Settings.SilentAimNPC) then
            if Runtime.CurrentSilentTarget and isEntityAlive(Runtime.CurrentSilentTarget.Parent) then
                local targetHit = Runtime.CurrentSilentTarget.Position
                if Settings.SAPrediction then
                    targetHit = getPredictedPosition(Runtime.CurrentSilentTarget, Settings.SAPredictionAmount)
                end

                -- Redirect Mouse.Hit and Mouse.Target
                if self == Mouse then
                    if key == "Hit" or key == "hit" then
                        return CFrame.new(targetHit)
                    elseif key == "Target" or key == "target" then
                        return Runtime.CurrentSilentTarget
                    end
                end
            end
        end

        return OriginalIndex(self, key)
    end))

    setreadonly(rawMeta, true)
    print("[SUHO SA] Engine successfully hooked __namecall and __index.")
end

setupSilentMetatableHooks()

-- ==============================================================================
-- 4. VISUALS ENGINE (FOV RING, TRACERS, HIGHLIGHTS)
-- ==============================================================================
local VisualDrawing = {
    FOVCircle = nil,
    Tracer = nil
}

if Drawing and Drawing.new then
    VisualDrawing.FOVCircle = Drawing.new("Circle")
    VisualDrawing.FOVCircle.Thickness = 1.5
    VisualDrawing.FOVCircle.NumSides = 48
    VisualDrawing.FOVCircle.Filled = false
    VisualDrawing.FOVCircle.Transparency = 1
    VisualDrawing.FOVCircle.Visible = false

    VisualDrawing.Tracer = Drawing.new("Line")
    VisualDrawing.Tracer.Thickness = 1.5
    VisualDrawing.Tracer.Transparency = 0.9
    VisualDrawing.Tracer.Visible = false
end

local TargetHighlight = Instance.new("Highlight")
TargetHighlight.Name = "SuhoTargetHighlight"
TargetHighlight.FillColor = Settings.TargetColor
TargetHighlight.OutlineColor = Color3.fromRGB(255, 255, 255)
TargetHighlight.FillTransparency = 0.5
TargetHighlight.OutlineTransparency = 0.1
TargetHighlight.Enabled = false
pcall(function() TargetHighlight.Parent = CoreGui end)

-- ==============================================================================
-- 5. MASTER EXECUTION PIPELINE (RENDERSTEPPED / STEERING)
-- ==============================================================================
RunService.RenderStepped:Connect(function()
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    Runtime.ScreenCenter = screenCenter

    -- FOV Ring Drawing
    if VisualDrawing.FOVCircle then
        if Settings.ShowFOVRing then
            VisualDrawing.FOVCircle.Visible = true
            VisualDrawing.FOVCircle.Position = screenCenter
            VisualDrawing.FOVCircle.Radius = Settings.FOVSize
            VisualDrawing.FOVCircle.Color = Settings.FOVColor
        else
            VisualDrawing.FOVCircle.Visible = false
        end
    end

    -- Update Targets
    if Settings.SilentAimPlayers or Settings.SilentAimNPC then
        Runtime.CurrentSilentTarget = acquireSilentCandidate()
    else
        Runtime.CurrentSilentTarget = nil
    end

    if Settings.AimlockPlayers and Runtime.AimlockActive then
        if not Runtime.CurrentAimlockTarget or not isEntityAlive(Runtime.CurrentAimlockTarget) then
            Runtime.CurrentAimlockTarget = acquireAimlockCandidate()
        end
    else
        Runtime.CurrentAimlockTarget = nil
    end

    -- Camera Aimlock Steering
    if Runtime.AimlockActive and Runtime.CurrentAimlockTarget then
        local targetRoot = getRoot(Runtime.CurrentAimlockTarget)
        if targetRoot then
            local aimPos = targetRoot.Position
            if Settings.AimlockPrediction then
                aimPos = getPredictedPosition(targetRoot, Settings.AimlockPredictionAmount)
            end
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, aimPos)
        end
    end

    -- Visual Highlights
    local primaryVisual = Runtime.CurrentAimlockTarget or (Runtime.CurrentSilentTarget and Runtime.CurrentSilentTarget.Parent)
    if primaryVisual and Settings.HighlightTarget and isEntityAlive(primaryVisual) then
        TargetHighlight.Adornee = primaryVisual
        TargetHighlight.Enabled = true
    else
        TargetHighlight.Enabled = false
        TargetHighlight.Adornee = nil
    end

    -- Tracer Line Drawing
    if VisualDrawing.Tracer then
        if Settings.ShowTracer and primaryVisual and isEntityAlive(primaryVisual) then
            local root = getRoot(primaryVisual)
            if root then
                local sPos, onScreen = Camera:WorldToViewportPoint(root.Position)
                if onScreen then
                    VisualDrawing.Tracer.Visible = true
                    VisualDrawing.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                    VisualDrawing.Tracer.To = Vector2.new(sPos.X, sPos.Y)
                    VisualDrawing.Tracer.Color = Settings.TargetColor
                else
                    VisualDrawing.Tracer.Visible = false
                end
            else
                VisualDrawing.Tracer.Visible = false
            end
        else
            VisualDrawing.Tracer.Visible = false
        end
    end
end)

-- Keybind Listener for Aimlock
UserInputService.InputBegan:Connect(function(input, processed)
    if not processed and input.KeyCode == Settings.AimlockKey then
        Runtime.AimlockActive = not Runtime.AimlockActive
        if not Runtime.AimlockActive then
            Runtime.CurrentAimlockTarget = nil
        end
    end
end)

-- ==============================================================================
-- 6. DEVELOPER DASHBOARD GUI (PRECISION HUD LAYOUT)
-- ==============================================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SuhoAimSuite"
ScreenGui.ResetOnSpawn = false
pcall(function() ScreenGui.Parent = CoreGui end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 480, 0, 520)
Main.Position = UDim2.new(0.5, -240, 0.5, -260)
Main.BackgroundColor3 = Color3.fromRGB(15, 17, 23)
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
Main.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 8)
MainCorner.Parent = Main

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(35, 40, 55)
MainStroke.Thickness = 1.2
MainStroke.Parent = Main

-- Top Header
local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 36)
TopBar.BackgroundColor3 = Color3.fromRGB(20, 23, 31)
TopBar.BorderSizePixel = 0
TopBar.Parent = Main

local TopCorner = Instance.new("UICorner")
TopCorner.CornerRadius = UDim.new(0, 8)
TopCorner.Parent = TopBar

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(0.7, 0, 1, 0)
Title.Position = UDim2.new(0.04, 0, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "DEVELOPER AIMBOT & SILENT AIM CONTROL"
Title.TextColor3 = Color3.fromRGB(240, 245, 255)
Title.Font = Enum.Font.SourceSansBold
Title.TextSize = 13
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TopBar

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 26, 0, 24)
CloseBtn.Position = UDim2.new(1, -30, 0, 6)
CloseBtn.BackgroundColor3 = Color3.fromRGB(160, 40, 40)
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Font = Enum.Font.SourceSansBold
CloseBtn.TextSize = 12
CloseBtn.Parent = TopBar

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 4)
CloseCorner.Parent = CloseBtn

CloseBtn.MouseButton1Click:Connect(function()
    if VisualDrawing.FOVCircle then VisualDrawing.FOVCircle:Remove() end
    if VisualDrawing.Tracer then VisualDrawing.Tracer:Remove() end
    TargetHighlight:Destroy()
    ScreenGui:Destroy()
end)

-- Main Scroll Container
local Content = Instance.new("ScrollingFrame")
Content.Size = UDim2.new(0.92, 0, 0.90, -42)
Content.Position = UDim2.new(0.04, 0, 0, 42)
Content.BackgroundTransparency = 1
Content.BorderSizePixel = 0
Content.ScrollBarThickness = 4
Content.ScrollBarImageColor3 = Color3.fromRGB(60, 70, 95)
Content.Parent = Main

local Layout = Instance.new("UIListLayout")
Layout.Padding = UDim.new(0, 6)
Layout.SortOrder = Enum.SortOrder.LayoutOrder
Layout.Parent = Content

-- Helper Builders
local function createHeader(text)
    local header = Instance.new("TextLabel")
    header.Size = UDim2.new(1, -8, 0, 24)
    header.BackgroundTransparency = 1
    header.Text = "=== " .. string.upper(text) .. " ==="
    header.TextColor3 = Color3.fromRGB(0, 180, 255)
    header.Font = Enum.Font.SourceSansBold
    header.TextSize = 12
    header.TextXAlignment = Enum.TextXAlignment.Left
    header.Parent = Content
    return header
end

local function createToggle(text, stateVar, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -8, 0, 32)
    btn.Font = Enum.Font.SourceSansBold
    btn.TextSize = 12
    btn.Parent = Content

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 5)
    corner.Parent = btn

    local function render()
        btn.BackgroundColor3 = Settings[stateVar] and Color3.fromRGB(40, 120, 75) or Color3.fromRGB(24, 27, 36)
        btn.Text = "  " .. text .. (Settings[stateVar] and " : [ACTIVE]" or " : [OFF]")
        btn.TextColor3 = Settings[stateVar] and Color3.fromRGB(150, 255, 150) or Color3.fromRGB(210, 215, 230)
        btn.TextXAlignment = Enum.TextXAlignment.Left
    end
    render()

    btn.MouseButton1Click:Connect(function()
        Settings[stateVar] = not Settings[stateVar]
        render()
        if callback then callback(Settings[stateVar]) end
    end)
    return btn
end

local function createStatusRow(titleText, dynamicValueFn)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -8, 0, 28)
    frame.BackgroundColor3 = Color3.fromRGB(20, 23, 31)
    frame.BorderSizePixel = 0
    frame.Parent = Content

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = frame

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0.5, 0, 1, 0)
    title.Position = UDim2.new(0.03, 0, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = titleText
    title.TextColor3 = Color3.fromRGB(190, 195, 210)
    title.Font = Enum.Font.SourceSansBold
    title.TextSize = 12
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = frame

    local val = Instance.new("TextLabel")
    val.Size = UDim2.new(0.45, 0, 1, 0)
    val.Position = UDim2.new(0.52, 0, 0, 0)
    val.BackgroundTransparency = 1
    val.Text = "..."
    val.TextColor3 = Color3.fromRGB(100, 215, 255)
    val.Font = Enum.Font.SourceSans
    val.TextSize = 12
    val.TextXAlignment = Enum.TextXAlignment.Right
    val.Parent = frame

    task.spawn(function()
        while ScreenGui.Parent do
            val.Text = tostring(dynamicValueFn())
            task.wait(0.2)
        end
    end)
    return frame
end

local function createSlider(titleText, stateVar, minVal, maxVal, step, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -8, 0, 36)
    frame.BackgroundColor3 = Color3.fromRGB(20, 23, 31)
    frame.BorderSizePixel = 0
    frame.Parent = Content

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 5)
    corner.Parent = frame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.5, 0, 1, 0)
    label.Position = UDim2.new(0.03, 0, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = titleText .. ": " .. tostring(Settings[stateVar])
    label.TextColor3 = Color3.fromRGB(220, 225, 240)
    label.Font = Enum.Font.SourceSansBold
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local minusBtn = Instance.new("TextButton")
    minusBtn.Size = UDim2.new(0, 30, 0, 24)
    minusBtn.Position = UDim2.new(0.70, 0, 0.16, 0)
    minusBtn.BackgroundColor3 = Color3.fromRGB(35, 40, 55)
    minusBtn.Text = "-"
    minusBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    minusBtn.Font = Enum.Font.SourceSansBold
    minusBtn.TextSize = 13
    minusBtn.Parent = frame

    local pCorner1 = Instance.new("UICorner")
    pCorner1.CornerRadius = UDim.new(0, 4)
    pCorner1.Parent = minusBtn

    local plusBtn = Instance.new("TextButton")
    plusBtn.Size = UDim2.new(0, 30, 0, 24)
    plusBtn.Position = UDim2.new(0.86, 0, 0.16, 0)
    plusBtn.BackgroundColor3 = Color3.fromRGB(35, 40, 55)
    plusBtn.Text = "+"
    plusBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    plusBtn.Font = Enum.Font.SourceSansBold
    plusBtn.TextSize = 13
    plusBtn.Parent = frame

    local pCorner2 = Instance.new("UICorner")
    pCorner2.CornerRadius = UDim.new(0, 4)
    pCorner2.Parent = plusBtn

    local function update(delta)
        Settings[stateVar] = math.clamp(Settings[stateVar] + delta, minVal, maxVal)
        label.Text = titleText .. ": " .. string.format(type(step) == "number" and step < 1 and "%.2f" or "%d", Settings[stateVar])
        if callback then callback(Settings[stateVar]) end
    end

    minusBtn.MouseButton1Click:Connect(function() update(-step) end)
    plusBtn.MouseButton1Click:Connect(function() update(step) end)
    return frame
end

-- ==============================================================================
-- 7. BUILD CONTROL DASHBOARD PANELS
-- ==============================================================================

-- SECTION: AIMBOT / SILENT AIM MASTER
createHeader("Aimbot / Silent Aim")
createToggle("Aimlock Players (Press E to Toggle)", "AimlockPlayers")
createToggle("Silent Aim Players", "SilentAimPlayers")

-- SECTION: AIMLOCK SETTINGS
createHeader("Aimlock Settings")
createToggle("Silent Aim NPC", "SilentAimNPC")
createSlider("Aimlock Range", "AimlockRange", 100, 5000, 100)
createToggle("Aimlock Prediction", "AimlockPrediction")
createSlider("Prediction Amount", "AimlockPredictionAmount", 0.01, 1.0, 0.02)
createToggle("Target Lowest HP", "TargetLowestHP")
createStatusRow("Aimlock Target", function()
    if Runtime.CurrentAimlockTarget then
        return Runtime.CurrentAimlockTarget.Name
    end
    return "(None)"
end)

-- SECTION: SILENT AIM SETTINGS
createHeader("Silent Aim Settings")
createSlider("SA Range (independent)", "SARange", 100, 5000, 100)
createToggle("SA Prediction", "SAPrediction")
createSlider("SA Prediction Amount", "SAPredictionAmount", 0.01, 1.0, 0.02)
createStatusRow("Silent Lock Target", function()
    if Runtime.CurrentSilentTarget and Runtime.CurrentSilentTarget.Parent then
        return Runtime.CurrentSilentTarget.Parent.Name
    end
    return "(None)"
end)

-- SECTION: SKILL ROUTING
createHeader("Skill Routing")
createToggle("Skill Routing (Redirect CommF_ & Hit)", "SkillRouting")

-- SECTION: VISUALS
createHeader("Visuals")
createToggle("FOV Ring gates Aimlock", "FOVRingGatesAimlock")
createToggle("Highlight Target", "HighlightTarget")
createToggle("Show Tracer", "ShowTracer")
createToggle("Show FOV Ring", "ShowFOVRing")
createSlider("FOV Size", "FOVSize", 50, 800, 25)

-- Canvas Fitting
Content.CanvasSize = UDim2.new(0, 0, 0, #Content:GetChildren() * 40)

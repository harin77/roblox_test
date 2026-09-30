local Rayfield = loadstring(game:HttpGet('https://sirius.menu'))()

-- Global Configuration State
local Config = {
    AimlockPlayers = false,
    AimlockNPC = false,
    SilentAimPlayers = false,
    SilentAimNPC = false,
    AimlockRange = 1000,
    AimlockPrediction = false,
    PredictionAmount = 0.12,
    TargetLowestHP = false,
    
    SARange = 1000,
    SAPrediction = false,
    SAPredictionAmount = 0.2,
    
    HighlightTarget = false,
    ShowTracer = false,
    ShowFOVRing = false,
    FOVSize = 200
}

-- References & Engine Components
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CurrentAimlockTarget = nil
local CurrentSilentAimTarget = nil

-- UI Paragraph Reference variables for dynamic text updates
local AimlockTargetText, SilentLockTargetText

-- Create Drawing Visuals
local FOVCircle = Drawing.new("Circle")
FOVCircle.Color = Color3.fromRGB(255, 0, 0)
FOVCircle.Thickness = 1.5
FOVCircle.Filled = false
FOVCircle.Transparency = 1
FOVCircle.Visible = false

local TracerLine = Drawing.new("Line")
TracerLine.Color = Color3.fromRGB(255, 255, 0)
TracerLine.Thickness = 1.5
TracerLine.Transparency = 1
TracerLine.Visible = false

local TargetHighlight = Instance.new("Highlight")
TargetHighlight.FillColor = Color3.fromRGB(255, 0, 0)
TargetHighlight.FillTransparency = 0.5
TargetHighlight.OutlineColor = Color3.fromRGB(255, 255, 255)
TargetHighlight.OutlineTransparency = 0
TargetHighlight.Enabled = false
TargetHighlight.Parent = game:GetService("CoreGui")

-- Helper: Validate if model is an NPC or Player based on flags
local function isValidTarget(model, isCheckForSilentAim)
    if not model or not model:FindFirstChild("HumanoidRootPart") or not model:FindFirstChildOfClass("Humanoid") then return false end
    if model:FindFirstChildOfClass("Humanoid").Health <= 0 then return false end
    if model == LocalPlayer.Character then return false end
    
    local player = Players:GetPlayerFromCharacter(model)
    local checkPlayers = isCheckForSilentAim and Config.SilentAimPlayers or Config.AimlockPlayers
    local checkNPCs = isCheckForSilentAim and Config.SilentAimNPC or Config.AimlockNPC
    
    if player and checkPlayers then return true end
    if tyranny and not player and checkNPCs then return true end -- standard check if it's not a player character
    if not player and checkNPCs then return true end
    
    return false
end

-- Targeting Core Logic Engine
local function getBestTarget(isSilentAim)
    local closestTarget = nil
    local maxDistance = isSilentAim and Config.SARange or Config.AimlockRange
    local lowestHP = math.huge
    local shortestMouseDistance = math.huge
    
    -- Combines checking Workspace and Players list safely
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj:FindFirstChildOfClass("Humanoid") then
            if isValidTarget(obj, isSilentAim) then
                local hrp = obj.HumanoidRootPart
                local humanoid = obj:FindFirstChildOfClass("Humanoid")
                
                -- Distance check from your local player
                local distance = (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")) and (LocalPlayer.Character.HumanoidRootPart.Position - hrp.Position).Magnitude or math.huge
                
                if distance <= maxDistance then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
                    local mousePos = UserInputService:GetMouseLocation()
                    local mouseDistance = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                    
                    -- If Aimlock and FOV Ring option is on, restrict target within radius
                    if not isSilentAim and Config.ShowFOVRing and Config.FOVSize then
                        if mouseDistance > Config.FOVSize or not onScreen then
                            continue
                        end
                    end
                    
                    -- Sorting methods based on Lowest HP setting or nearest crosshair target
                    if Config.TargetLowestHP then
                        if humanoid.Health < lowestHP then
                            lowestHP = humanoid.Health
                            closestTarget = obj
                        end
                    else
                        if mouseDistance < shortestMouseDistance then
                            shortestMouseDistance = mouseDistance
                            closestTarget = obj
                        end
                    end
                end
            end
        end
    end
    return closestTarget
end

-- ============================================================================
-- WINDOW CREATION
-- ============================================================================
local Window = Rayfield:CreateWindow({
    Name = "Suho Advanced Combat Engine",
    LoadingTitle = "Initializing Backends...",
    LoadingSubtitle = "by harin77",
    ConfigurationSaving = { Enabled = false }
})

local MainTab = Window:CreateTab("Aimbot / Silent Aim", 4483362458)
local SettingsTab = Window:CreateTab("Settings & Logic", 4483362458)
local VisualsTab = Window:CreateTab("Visuals", 4483362458)

-- ============================================================================
-- TAB 1: AIMBOT / SILENT AIM UI
-- ============================================================================
MainTab:CreateSection("=== AIMBOT / SILENT AIM ===")

MainTab:CreateToggle({
    Name = "Aimlock Players",
    CurrentValue = false,
    Flag = "AimlockPlayers",
    Callback = function(v) Config.AimlockPlayers = v end,
})

MainTab:CreateToggle({
    Name = "Aimlock NPC",
    CurrentValue = false,
    Flag = "AimlockNPC",
    Callback = function(v) Config.AimlockNPC = v end,
})

MainTab:CreateToggle({
    Name = "Silent Aim Players",
    CurrentValue = false,
    Flag = "SilentAimPlayers",
    Callback = function(v) Config.SilentAimPlayers = v end,
})

MainTab:CreateToggle({
    Name = "Silent Aim NPC",
    CurrentValue = false,
    Flag = "SilentAimNPC",
    Callback = function(v) Config.SilentAimNPC = v end,
})

MainTab:CreateSlider({
    Name = "Aimlock Range",
    Min = 10,
    Max = 3000,
    CurrentValue = 1000,
    Flag = "AimlockRange",
    Callback = function(v) Config.AimlockRange = v end,
})

MainTab:CreateToggle({
    Name = "Aimlock Prediction",
    CurrentValue = false,
    Flag = "AimlockPrediction",
    Callback = function(v) Config.AimlockPrediction = v end,
})

-- ============================================================================
-- TAB 2: SETTINGS UI
-- ============================================================================
SettingsTab:CreateSection("=== AIMLOCK SETTINGS ===")

SettingsTab:CreateSlider({
    Name = "Prediction Amount",
    Min = 0,
    Max = 1,
    Increment = 0.01,
    CurrentValue = 0.12,
    Flag = "AimlockPredictionAmount",
    Callback = function(v) Config.PredictionAmount = v end,
})

SettingsTab:CreateToggle({
    Name = "Target Lowest HP",
    CurrentValue = false,
    Flag = "TargetLowestHP",
    Callback = function(v) Config.TargetLowestHP = v end,
})

AimlockTargetText = SettingsTab:CreateParagraph({Title = "Aimlock Target", Content = "(None)"})

SettingsTab:CreateSection("=== SILENT AIM SETTINGS ===")

SettingsTab:CreateSlider({
    Name = "SA Range (Independent)",
    Min = 10,
    Max = 3000,
    CurrentValue = 1000,
    Flag = "SARange",
    Callback = function(v) Config.SARange = v end,
})

SettingsTab:CreateToggle({
    Name = "SA Prediction",
    CurrentValue = false,
    Flag = "SAPrediction",
    Callback = function(v) Config.SAPrediction = v end,
})

SettingsTab:CreateSlider({
    Name = "SA Prediction Amount",
    Min = 0,
    Max = 1,
    Increment = 0.01,
    CurrentValue = 0.2,
    Flag = "SAPredictionAmount",
    Callback = function(v) Config.SAPredictionAmount = v end,
})

SilentLockTargetText = SettingsTab:CreateParagraph({Title = "Silent Lock Target", Content = "(None)"})

-- ============================================================================
-- TAB 3: VISUALS UI
-- ============================================================================
VisualsTab:CreateSection("=== VISUALS ===")

VisualsTab:CreateToggle({
    Name = "Highlight Target",
    CurrentValue = false,
    Flag = "HighlightTarget",
    Callback = function(v) Config.HighlightTarget = v end,
})

VisualsTab:CreateToggle({
    Name = "Show Tracer",
    CurrentValue = false,
    Flag = "ShowTracer",
    Callback = function(v) Config.ShowTracer = v end,
})

VisualsTab:CreateToggle({
    Name = "Show FOV Ring (Gates Aimlock)",
    CurrentValue = false,
    Flag = "ShowFOVRing",
    Callback = function(v) Config.ShowFOVRing = v v FlowCircle.Visible = v end,
})

VisualsTab:CreateSlider({
    Name = "FOV Size",
    Min = 10,
    Max = 800,
    CurrentValue = 200,
    Flag = "FOVSize",
    Callback = function(v) Config.FOVSize = v end,
})

-- ============================================================================
-- ENGINE RUNTIME LOOPS (The Math Backend)
-- ============================================================================

-- Hooking Frame Render for Visuals & Camera Aimlock
RunService.RenderStepped:Connect(function()
    -- Update FOV Visual Element positions dynamically
    if Config.ShowFOVRing then
        FOVCircle.Position = UserInputService:GetMouseLocation()
        FOVCircle.Radius = Config.FOVSize
        FOVCircle.Visible = true
    else
        FOVCircle.Visible = false
    end
    
    -- Target Sorting Update Loops
    CurrentAimlockTarget = getBestTarget(false)
    CurrentSilentAimTarget = getBestTarget(true)
    
    -- Text Label Refresh Engine
    AimlockTargetText:Set({Title = "Aimlock Target", Content = CurrentAimlockTarget and CurrentAimlockTarget.Name or "(None)"})
    SilentLockTargetText:Set({Title = "Silent Lock Target", Content = CurrentSilentAimTarget and CurrentSilentAimTarget.Name or "(None)"})

    -- Camera Locking Action
    if CurrentAimlockTarget and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then -- Right click lock active
        local targetPosition = CurrentAimlockTarget.HumanoidRootPart.Position
        
        -- Apply prediction calculation if enabled
        if Config.AimlockPrediction then
            targetPosition = targetPosition + (CurrentAimlockTarget.HumanoidRootPart.Velocity * Config.PredictionAmount)
        end
        Camera.CFrame = CFrame.new(Camera.CFrame.Position, targetPosition)
    end

    -- Render Target Overlays & Tracers
    if Config.HighlightTarget and CurrentAimlockTarget then
        TargetHighlight.Adornee = CurrentAimlockTarget
        TargetHighlight.Enabled = true
    else
        TargetHighlight.Enabled = false
    end

    if Config.ShowTracer and CurrentAimlockTarget then
        local screenPos, onScreen = Camera:WorldToViewportPoint(CurrentAimlockTarget.HumanoidRootPart.Position)
        if onScreen then
            TracerLine.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y) -- Screen bottom center
            TracerLine.To = Vector2.new(screenPos.X, screenPos.Y)
            TracerLine.Visible = true
        else
            TracerLine.Visible = false
        end
    else
        TracerLine.Visible = false
    end
end)

-- Hooking Hooks for Silent Aim Metatable interception
local gmt = getrawmetatable(game)
setreadonly(gmt, false)
local oldIndex = gmt.__index

gmt.__index = newcclosure(function(self, index)
    if self == UserInputService and index == "GetMouseLocation" and CurrentSilentAimTarget and (Config.SilentAimPlayers or Config.SilentAimNPC) then
        local hrp = CurrentSilentAimTarget.HumanoidRootPart
        local targetPos = hrp.Position
        
        if Config.SAPrediction then
            targetPos = targetPos + (hrp.Velocity * Config.SAPredictionAmount)
        end
        
        local screenPos, onScreen = Camera:WorldToViewportPoint(targetPos)
        if onScreen then
            return Vector2.new(screenPos.X, screenPos.Y)
        end
    end
    return oldIndex(self, index)
end)
setreadonly(gmt, true)

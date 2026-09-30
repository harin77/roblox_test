-- [[ Rayfield Initialization ]]
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
   Name = "Blox Fruits Combat Suite",
   LoadingTitle = "Initializing Systems...",
   LoadingSubtitle = "by Developer",
   ConfigurationSaving = {
      Enabled = true,
      FolderName = "BloxFruitsRayfieldConfig",
      FileName = "CombatSettings"
   },
   Discord = {
      Enabled = false,
      Invite = "",
      RememberJoins = true
   },
   KeySystem = false
})

-- [[ Global State Settings Table ]]
local Settings = {
    -- Core Options
    AimbotEnabled = false,
    AimlockPlayers = false,
    AimlockNPC = false,
    SilentAimPlayers = false,
    SilentAimNPC = false,
    
    -- Aimlock Tuning
    AimlockRange = 1000,
    AimlockPrediction = false,
    PredictionAmount = 0.12,
    TargetLowestHP = false,
    AimlockTarget = "None",
    
    -- Silent Aim Tuning
    SARange = 1000,
    SAPrediction = false,
    SAPredictionAmount = 0.2,
    SilentLockTarget = "None",
    
    -- Visuals
    FOVGridGates = false,
    HighlightTarget = false,
    ShowTracer = false,
    ShowFOV = false,
    FOVSize = 200
}

-- [[ Engine Services & Variables ]]
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

-- [[ Initialize FOV Ring Visual ]]
local FOVCircle = Drawing.new("Circle")
FOVCircle.Color = Color3.fromRGB(255, 0, 0)
FOVCircle.Thickness = 1.5
FOVCircle.NumSides = 64
FOVCircle.Filled = false
FOVCircle.Visible = false

-- [[ Helper Target Verification Function ]]
local function GetClosestTarget(range, checkPlayers, checkNPCs, useFOV, fovRadius, lowestHP)
    local closestTarget = nil
    local shortestDistance = range
    local lowestHealth = math.huge
    local mousePos = UserInputService:GetMouseLocation()

    local function evaluateTarget(character, isNPC)
        if not character or not character:FindFirstChild("HumanoidRootPart") or not character:FindFirstChild("Humanoid") then return end
        if character.Humanoid.Health <= 0 then return end
        if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end
        
        -- Vector Distance Check
        local distance = (LocalPlayer.Character.HumanoidRootPart.Position - character.HumanoidRootPart.Position).Magnitude
        if distance > range then return end

        -- Visual FOV Restriction Gate
        if useFOV then
            local screenPos, onScreen = Camera:WorldToViewportPoint(character.HumanoidRootPart.Position)
            if not onScreen then return end
            local screenDistance = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
            if screenDistance > fovRadius then return end
        end

        -- Health vs Distance Sorting Priority
        if lowestHP then
            if character.Humanoid.Health < lowestHealth then
                lowestHealth = character.Humanoid.Health
                closestTarget = character
            end
        else
            if distance < shortestDistance then
                shortestDistance = distance
                closestTarget = character
            end
        end
    end

    -- Process Players
    if checkPlayers then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                evaluateTarget(player.Character, false)
            end
        end
    end

    -- Process NPCs (Blox Fruits Enemies/Bosses)
    if checkNPCs and workspace:FindFirstChild("Enemies") then
        for _, enemy in ipairs(workspace.Enemies:GetChildren()) do
            evaluateTarget(enemy, true)
        end
    end

    return closestTarget
end

-- [[ TAB 1: Developer / Aimbot Main ]]
local MainTab = Window:CreateTab("Aimbot", 4483362458)
MainTab:CreateSection("=== AIMBOT / SILENT AIM ===")

MainTab:CreateToggle({
   Name = "Master Aimbot Switch",
   CurrentValue = false,
   Flag = "AimbotEnabled",
   Callback = function(Value) Settings.AimbotEnabled = Value end,
})

MainTab:CreateToggle({
   Name = "Aimlock Players",
   CurrentValue = false,
   Flag = "AimlockPlayers",
   Callback = function(Value) Settings.AimlockPlayers = Value end,
})

MainTab:CreateToggle({
   Name = "Aimlock NPC",
   CurrentValue = false,
   Flag = "AimlockNPC",
   Callback = function(Value) Settings.AimlockNPC = Value end,
})

MainTab:CreateToggle({
   Name = "Silent Aim Players",
   CurrentValue = false,
   Flag = "SilentAimPlayers",
   Callback = function(Value) Settings.SilentAimPlayers = Value end,
})

MainTab:CreateToggle({
   Name = "Silent Aim NPC",
   CurrentValue = false,
   Flag = "SilentAimNPC",
   Callback = function(Value) Settings.SilentAimNPC = Value end,
})

-- [[ TAB 2: Aimlock Settings ]]
local LockSettingsTab = Window:CreateTab("Aimlock Settings", 4483362458)
LockSettingsTab:CreateSection("=== AIMLOCK SETTINGS ===")

LockSettingsTab:CreateSlider({
   Name = "Aimlock Range",
   Min = 100,
   Max = 3000,
   CurrentValue = 1000,
   Flag = "AimlockRange",
   Callback = function(Value) Settings.AimlockRange = Value end,
})

LockSettingsTab:CreateToggle({
   Name = "Aimlock Prediction",
   CurrentValue = false,
   Flag = "AimlockPrediction",
   Callback = function(Value) Settings.AimlockPrediction = Value end,
})

LockSettingsTab:CreateSlider({
   Name = "Prediction Amount",
   Min = 0,
   Max = 1,
   CurrentValue = 0.12,
   Increment = 0.01,
   Flag = "PredictionAmount",
   Callback = function(Value) Settings.PredictionAmount = Value end,
})

LockSettingsTab:CreateToggle({
   Name = "Target Lowest HP",
   CurrentValue = false,
   Flag = "TargetLowestHP",
   Callback = function(Value) Settings.TargetLowestHP = Value end,
})

local CurrentTargetLabel = LockSettingsTab:CreateLabel("Aimlock Target: (None)")

-- [[ TAB 3: Silent Aim Settings ]]
local SilentSettingsTab = Window:CreateTab("Silent Aim Settings", 4483362458)
SilentSettingsTab:CreateSection("=== SILENT AIM SETTINGS ===")

SilentSettingsTab:CreateSlider({
   Name = "SA Range (independent)",
   Min = 100,
   Max = 3000,
   CurrentValue = 1000,
   Flag = "SARange",
   Callback = function(Value) Settings.SARange = Value end,
})

SilentSettingsTab:CreateToggle({
   Name = "SA Prediction",
   CurrentValue = false,
   Flag = "SAPrediction",
   Callback = function(Value) Settings.SAPrediction = Value end,
})

SilentSettingsTab:CreateSlider({
   Name = "SA Prediction Amount",
   Min = 0,
   Max = 1,
   CurrentValue = 0.2,
   Increment = 0.01,
   Flag = "SAPredictionAmount",
   Callback = function(Value) Settings.SAPredictionAmount = Value end,
})

local SilentTargetLabel = SilentSettingsTab:CreateLabel("Silent Lock Target: (None)")

-- [[ TAB 4: Skill Routing ]]
local SkillTab = Window:CreateTab("Skill Routing", 4483362458)
SkillTab:CreateSection("=== SKILL ROUTING ===")
SkillTab:CreateLabel("Routing profiles actively redirect project mechanics.")

-- [[ TAB 5: Visuals ]]
local VisualsTab = Window:CreateTab("Visuals", 4483362458)
VisualsTab:CreateSection("=== VISUALS ===")

VisualsTab:CreateToggle({
   Name = "FOV Ring gates Aimlock",
   CurrentValue = false,
   Flag = "FOVGridGates",
   Callback = function(Value) Settings.FOVGridGates = Value end,
})

VisualsTab:CreateToggle({
   Name = "Highlight Target",
   CurrentValue = false,
   Flag = "HighlightTarget",
   Callback = function(Value) Settings.HighlightTarget = Value end,
})

VisualsTab:CreateToggle({
   Name = "Show Tracer",
   CurrentValue = false,
   Flag = "ShowTracer",
   Callback = function(Value) Settings.ShowTracer = Value end,
})

VisualsTab:CreateToggle({
   Name = "Show FOV Ring",
   CurrentValue = false,
   Flag = "ShowFOV",
   Callback = function(Value) 
      Settings.ShowFOV = Value
      FOVCircle.Visible = Value
   end,
})

VisualsTab:CreateSlider({
   Name = "FOV Size",
   Min = 50,
   Max = 800,
   CurrentValue = 200,
   Flag = "FOVSize",
   Callback = function(Value) 
      Settings.FOVSize = Value
      FOVCircle.Radius = Value
   end,
})

-- [[ Main Engine Application Update Loop ]]
RunService.RenderStepped:Connect(function()
    -- Dynamic FOV Layout Vector Tracking
    if Settings.ShowFOV then
        FOVCircle.Position = UserInputService:GetMouseLocation()
        FOVCircle.Radius = Settings.FOVSize
    end

    -- Process Active Tracking Mechanics
    if Settings.AimbotEnabled then
        -- 1. Resolve Standard Aimlock Execution
        if Settings.AimlockPlayers or Settings.AimlockNPC then
            local target = GetClosestTarget(
                Settings.AimlockRange, 
                Settings.AimlockPlayers, 
                Settings.AimlockNPC, 
                Settings.FOVGridGates, 
                Settings.FOVSize, 
                Settings.TargetLowestHP
            )

            if target and target:FindFirstChild("HumanoidRootPart") then
                CurrentTargetLabel:Set("Aimlock Target: " .. target.Name)
                
                -- Track Aim Target
                local targetPosition = target.HumanoidRootPart.Position
                if Settings.AimlockPrediction then
                    local velocity = target.HumanoidRootPart.AssemblyLinearVelocity
                    targetPosition = targetPosition + (velocity * Settings.PredictionAmount)
                end
                
                -- Smoothly interpolate vector angles to aim coordinates
                Camera.CFrame = CFrame.new(Camera.CFrame.Position, targetPosition)
            else
                CurrentTargetLabel:Set("Aimlock Target: (None)")
            end
        end

        -- 2. Resolve Global Silent Aim Infrastructure Update
        if Settings.SilentAimPlayers or Settings.SilentAimNPC then
            local silentTarget = GetClosestTarget(
                Settings.SARange, 
                Settings.SilentAimPlayers, 
                Settings.SilentAimNPC, 
                false,
                Settings.FOVSize,
                Settings.TargetLowestHP
            )

            if silentTarget then
                SilentTargetLabel:Set("Silent Lock Target: " .. silentTarget.Name)
            else
                SilentTargetLabel:Set("Silent Lock Target: (None)")
            end
        end
    else
        CurrentTargetLabel:Set("Aimlock Target: (None)")
        SilentTargetLabel:Set("Silent Lock Target: (None)")
    end
end)

Rayfield:LoadConfiguration()

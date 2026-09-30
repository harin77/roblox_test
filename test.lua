local Rayfield = loadstring(game:HttpGet('https://sirius.menu'))()

local Window = Rayfield:CreateWindow({
    Name = "Suho Advanced Combat Engine",
    LoadingTitle = "Loading Combat Interface...",
    LoadingSubtitle = "by harin77",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "SuhoCombatEngine",
        FileName = "Config"
    },
    Discord = {
        Enabled = false,
        Invite = "",
        RememberJoins = true
    },
    KeySystem = false
})

-- ============================================================================
-- TABS DEFINITION
-- ============================================================================
local MainTab = Window:CreateTab("Aimbot / Silent Aim", 4483362458)
local SettingsTab = Window:CreateTab("Settings & Logic", 4483362458)
local VisualsTab = Window:CreateTab("Visuals", 4483362458)

-- ============================================================================
-- TAB 1: AIMBOT / SILENT AIM
-- ============================================================================
MainTab:CreateSection("=== AIMBOT / SILENT AIM ===")

MainTab:CreateToggle({
    Name = "Aimlock Players",
    CurrentValue = false,
    Flag = "AimlockPlayers",
    Callback = function(Value)
        print("Aimlock Players:", Value)
    end,
})

MainTab:CreateToggle({
    Name = "Aimlock NPC",
    CurrentValue = false,
    Flag = "AimlockNPC",
    Callback = function(Value)
        print("Aimlock NPC:", Value)
    end,
})

MainTab:CreateToggle({
    Name = "Silent Aim Players",
    CurrentValue = false,
    Flag = "SilentAimPlayers",
    Callback = function(Value)
        print("Silent Aim Players:", Value)
    end,
})

MainTab:CreateToggle({
    Name = "Silent Aim NPC",
    CurrentValue = false,
    Flag = "SilentAimNPC",
    Callback = function(Value)
        print("Silent Aim NPC:", Value)
    end,
})

MainTab:CreateSlider({
    Name = "Aimlock Range",
    Min = 10,
    Max = 3000,
    CurrentValue = 1000,
    Flag = "AimlockRange",
    Callback = function(Value)
        print("Aimlock Range changed to:", Value)
    end,
})

MainTab:CreateToggle({
    Name = "Aimlock Prediction",
    CurrentValue = false,
    Flag = "AimlockPrediction",
    Callback = function(Value)
        print("Aimlock Prediction:", Value)
    end,
})

MainTab:CreateSection("=== SKILL ROUTING ===")
MainTab:CreateButton({
    Name = "Initialize Skill Routing",
    Callback = function()
        print("Skill routing triggered.")
    end,
})

-- ============================================================================
-- TAB 2: SETTINGS & LOGIC
-- ============================================================================
SettingsTab:CreateSection("=== AIMLOCK SETTINGS ===")

SettingsTab:CreateSlider({
    Name = "Prediction Amount",
    Min = 0,
    Max = 1,
    Increment = 0.01,
    CurrentValue = 0.12,
    Flag = "AimlockPredictionAmount",
    Callback = function(Value)
        print("Aimlock Prediction Amount:", Value)
    end,
})

SettingsTab:CreateToggle({
    Name = "Target Lowest HP",
    CurrentValue = false,
    Flag = "TargetLowestHP",
    Callback = function(Value)
        print("Target Lowest HP status:", Value)
    end,
})

SettingsTab:CreateParagraph({Title = "Aimlock Target", Content = "(None)"})

SettingsTab:CreateSection("=== SILENT AIM SETTINGS ===")

SettingsTab:CreateSlider({
    Name = "SA Range (Independent)",
    Min = 10,
    Max = 3000,
    CurrentValue = 1000,
    Flag = "SARange",
    Callback = function(Value)
        print("SA Range:", Value)
    end,
})

SettingsTab:CreateToggle({
    Name = "SA Prediction",
    CurrentValue = false,
    Flag = "SAPrediction",
    Callback = function(Value)
        print("SA Prediction status:", Value)
    end,
})

SettingsTab:CreateSlider({
    Name = "SA Prediction Amount",
    Min = 0,
    Max = 1,
    Increment = 0.01,
    CurrentValue = 0.2,
    Flag = "SAPredictionAmount",
    Callback = function(Value)
        print("SA Prediction Amount:", Value)
    end,
})

SettingsTab:CreateParagraph({Title = "Silent Lock Target", Content = "(None)"})

-- ============================================================================
-- TAB 3: VISUALS
-- ============================================================================
VisualsTab:CreateSection("=== VISUALS ===")

VisualsTab:CreateParagraph({
    Title = "FOV Ring gates Aimlock", 
    Content = "When FOV Ring is ON, Aimlock only locks targets inside the circle.\nSilent Aim is always global."
})

VisualsTab:CreateToggle({
    Name = "Highlight Target",
    CurrentValue = false,
    Flag = "HighlightTarget",
    Callback = function(Value)
        print("Highlight Target:", Value)
    end,
})

VisualsTab:CreateToggle({
    Name = "Show Tracer",
    CurrentValue = false,
    Flag = "ShowTracer",
    Callback = function(Value)
        print("Show Tracer:", Value)
    end,
})

VisualsTab:CreateToggle({
    Name = "Show FOV Ring (Gates Aimlock)",
    CurrentValue = false,
    Flag = "ShowFOVRing",
    Callback = function(Value)
        print("Show FOV Ring status:", Value)
    end,
})

VisualsTab:CreateSlider({
    Name = "FOV Size",
    Min = 10,
    Max = 800,
    CurrentValue = 200,
    Flag = "FOVSize",
    Callback = function(Value)
        print("FOV Size adjusted to:", Value)
    end,
})

Rayfield:LoadConfiguration()

-- Blox Fruits Aimbot / Silent Aim / Hitbox / Skill Routing
-- Rayfield Menu | [Ghaith] for WVERZNXRL

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer

local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
local CommF_ = Remotes and Remotes:WaitForChild("CommF_", 10)
if not CommF_ then
    warn("[Ghaith] CommF_ not found — silent aim disabled. Are you in-game?")
end

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- ═══ STATE ═══
local State = {
    AimlockPlayers = false,
    AimlockNPC = false,
    SilentAimPlayers = false,
    SilentAimNPC = false,
    AimlockRange = 1000,
    AimlockPrediction = false,
    PredictionAmount = 0.12,
    TargetLowestHP = false,
    AimlockTarget = "None",
    SilentAimRange = 1000,
    SAPrediction = false,
    SAPredictionAmount = 0.2,
    SilentLockTarget = "None",
    SkillRouting = false,
    SkillRange = 30,
    SkillDelay = 0.2,
    HighlightTarget = false,
    ShowTracer = false,
    ShowFOVRing = false,
    FOVSize = 200,
    ManualTargetEnabled = false,
    ManualTargetPlayer = "None",
    HitboxEnabled = false,
    HitboxSize = 5,
    ShowHitbox = false,
    AntiCheatBypass = true,
}

-- ═══ VISUAL OBJECTS ═══
local Highlight = nil
local Tracer = nil
local FOVCircle = nil
local HitboxBox = nil

local function safeDrawing(class, props)
    if not Drawing or not Drawing.new then return nil end
    local obj
    local ok = pcall(function() obj = Drawing.new(class) end)
    if not ok or not obj then return nil end
    if props then
        for k, v in pairs(props) do
            pcall(function() obj[k] = v end)
        end
    end
    return obj
end

Tracer = safeDrawing("Line", {
    Visible = false,
    Color = Color3.fromRGB(0, 255, 0),
    Thickness = 2,
    Transparency = 1,
})

FOVCircle = safeDrawing("Circle", {
    Visible = false,
    Color = Color3.fromRGB(255, 255, 255),
    Thickness = 1,
    Radius = 200,
    Filled = false,
    Transparency = 1,
})

HitboxBox = safeDrawing("Square", {
    Visible = false,
    Color = Color3.fromRGB(0, 255, 255),
    Thickness = 1,
    Filled = false,
    Transparency = 1,
})

if not Tracer then
    warn("[Ghaith] Drawing API unavailable. Tracer / FOV / hitbox visuals disabled. Use an executor with Drawing support.")
end

-- ═══ HITBOX PARTS ═══
local HITBOX_PARTS = {
    "HumanoidRootPart", "Head",
    "UpperTorso", "LowerTorso", "Torso",
    "LeftUpperArm", "RightUpperArm",
    "LeftLowerArm", "RightLowerArm",
    "LeftHand", "RightHand",
    "LeftUpperLeg", "RightUpperLeg",
    "LeftLowerLeg", "RightLowerLeg",
    "LeftFoot", "RightFoot",
}

local modifiedHitboxes = {}

-- ═══ HELPERS ═══
local function isAlive(plr)
    return plr.Character
        and plr.Character:FindFirstChild("Humanoid")
        and plr.Character.Humanoid.Health > 0
end

local function getPlayers()
    local plrs = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and isAlive(plr) then
            if State.ManualTargetEnabled and State.ManualTargetPlayer ~= "None" then
                if plr.Name == State.ManualTargetPlayer then
                    table.insert(plrs, plr)
                end
            else
                table.insert(plrs, plr)
            end
        end
    end
    return plrs
end

local function getNPCs()
    local npcs = {}
    if State.ManualTargetEnabled then return npcs end

    -- check both Workspace.Enemies and ReplicatedStorage (per bf.lua)
    local containers = {}
    local wEnemies = Workspace:FindFirstChild("Enemies")
    if wEnemies then table.insert(containers, wEnemies) end
    local rEnemies = ReplicatedStorage:FindFirstChild("Enemies")
    if rEnemies then table.insert(containers, rEnemies) end

    for _, container in ipairs(containers) do
        for _, npc in ipairs(container:GetChildren()) do
            if npc:IsA("Model")
                and npc:FindFirstChild("Humanoid")
                and npc.Humanoid.Health > 0
                and npc:FindFirstChild("HumanoidRootPart") then
                table.insert(npcs, npc)
            end
        end
    end
    return npcs
end

local function getTargets(includePlayers, includeNPCs)
    local targets = {}
    if includePlayers then
        for _, plr in ipairs(getPlayers()) do
            table.insert(targets, plr.Character)
        end
    end
    if includeNPCs then
        for _, npc in ipairs(getNPCs()) do
            table.insert(targets, npc)
        end
    end
    return targets
end

local function predictPosition(target, amount)
    local root = target:FindFirstChild("HumanoidRootPart")
        or target:FindFirstChild("Torso")
        or target:FindFirstChild("UpperTorso")
    if not root then return target.Position end
    return root.Position + root.Velocity * amount
end

local function getClosestTarget(range, checkFOV, fovSize, targetLowestHP, specificTarget, includePlayers, includeNPCs)
    if State.ManualTargetEnabled and State.ManualTargetPlayer ~= "None" then
        local plr = Players:FindFirstChild(State.ManualTargetPlayer)
        if plr and plr ~= LocalPlayer and isAlive(plr) then
            local root = plr.Character:FindFirstChild("HumanoidRootPart")
            if root then
                local d = (Camera.CFrame.Position - root.Position).Magnitude
                if d <= range then return plr.Character end
            end
        end
        return nil
    end

    local targets = getTargets(includePlayers, includeNPCs)
    local closest, closestDist = nil, range or math.huge
    local mousePos = UserInputService:GetMouseLocation()
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

    for _, target in ipairs(targets) do
        if not (specificTarget and specificTarget ~= "None" and target.Name ~= specificTarget) then
            local root = target:FindFirstChild("HumanoidRootPart")
                or target:FindFirstChild("Torso")
                or target:FindFirstChild("UpperTorso")
            if root then
                local pos = root.Position
                local screenPos, onScreen = Camera:WorldToViewportPoint(pos)
                if onScreen then
                    local screenDist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                    local passFOV = true
                    if checkFOV then
                        local fovDist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
                        if fovDist > fovSize then passFOV = false end
                    end
                    if passFOV then
                        local worldDist = (Camera.CFrame.Position - pos).Magnitude
                        if worldDist <= range then
                            if targetLowestHP then
                                local hum = target:FindFirstChild("Humanoid")
                                if hum then
                                    if closest then
                                        local ch = closest:FindFirstChild("Humanoid")
                                        if ch and hum.Health >= ch.Health then
                                            -- skip
                                        else
                                            closest, closestDist = target, worldDist
                                        end
                                    else
                                        closest, closestDist = target, worldDist
                                    end
                                end
                            else
                                if screenDist < closestDist then
                                    closest, closestDist = target, screenDist
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return closest
end

-- ═══ HITBOX ═══
local function applyHitbox(character, size)
    if not character then return end
    local data = modifiedHitboxes[character]
    if not data then
        data = { parts = {} }
        modifiedHitboxes[character] = data
    end
    for _, name in ipairs(HITBOX_PARTS) do
        local part = character:FindFirstChild(name)
        if part and part:IsA("BasePart") then
            if not data.parts[part] then
                data.parts[part] = {
                    size = part.Size,
                    canCollide = part.CanCollide,
                    massless = part.Massless,
                }
            end
            part.Size = Vector3.new(size, size, size)
            part.CanCollide = false
            part.Massless = true
        end
    end
end

local function restoreHitbox(character)
    if not character then return end
    local data = modifiedHitboxes[character]
    if not data then return end
    for part, orig in pairs(data.parts) do
        if part and part.Parent then
            part.Size = orig.size
            part.CanCollide = orig.canCollide
            part.Massless = orig.massless
        end
    end
    modifiedHitboxes[character] = nil
end

local function restoreAllHitboxes()
    for character, _ in pairs(modifiedHitboxes) do
        restoreHitbox(character)
    end
end

local function getHitboxTargets()
    local targets = {}
    if State.ManualTargetEnabled and State.ManualTargetPlayer ~= "None" then
        local plr = Players:FindFirstChild(State.ManualTargetPlayer)
        if plr and plr ~= LocalPlayer and isAlive(plr) then
            table.insert(targets, plr.Character)
        end
        return targets
    end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and isAlive(plr) then
            local root = plr.Character:FindFirstChild("HumanoidRootPart")
            if root and (Camera.CFrame.Position - root.Position).Magnitude <= State.AimlockRange then
                table.insert(targets, plr.Character)
            end
        end
    end
    if State.AimlockNPC then
        for _, npc in ipairs(getNPCs()) do
            table.insert(targets, npc)
        end
    end
    return targets
end

-- ═══ SKILL ROUTING — VIM based (confirmed by bf.lua) ═══
local SKILL_KEYS = {"Z", "X", "C", "V", "F"}
local skillIndex = 1
local lastSkillFire = 0

local function fireSkill(key)
    local ok = pcall(function()
        VirtualInputManager:SendKeyEvent(true, key, false, game)
    end)
    if ok then
        task.wait(0.03)
        pcall(function()
            VirtualInputManager:SendKeyEvent(false, key, false, game)
        end)
        return true
    end
    return false
end

-- ═══ ANTI-CHEAT BYPASS + SILENT AIM (single __namecall hook) ═══
-- Blox Fruits registers hits by reading mouse position. Combat remote fires as
-- CommF_:FireServer("RemoteEvent", MousePos). We inject target position there.
-- Same hook also drops detection remotes.
if getrawmetatable and setreadonly and newcclosure then
    local rawMeta = getrawmetatable(game)
    setreadonly(rawMeta, false)
    local oldNamecall = rawMeta.__namecall

    rawMeta.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        local args = {...}

        if method == "FireServer" or method == "InvokeServer" then
            -- ─── anti-cheat bypass ───
            if State.AntiCheatBypass then
                local first = tostring(args[1])
                if first == "TeleportDetect" or first == "CHECKER_1" or first == "CHECKER"
                or first == "GUI_CHECK" or first == "OneMoreTime" or first == "checkingSPEED"
                or first == "BANREMOTE" or first == "PERMAIDBAN" or first == "KICKREMOTE"
                or first == "BR_KICKPC" or first == "BR_KICKMOBILE" then
                    return
                end
            end

            -- ─── silent aim — MousePos injection ───
            if self == CommF_ and method == "FireServer" then
                if tostring(args[1]) == "RemoteEvent" then
                    if tostring(args[2]) ~= "true" and tostring(args[2]) ~= "false" then
                        if State.SilentAimPlayers or State.SilentAimNPC
                        or (State.ManualTargetEnabled and State.ManualTargetPlayer ~= "None") then
                            local target = getClosestTarget(
                                State.SilentAimRange, false, 0, false,
                                State.SilentLockTarget,
                                State.SilentAimPlayers, State.SilentAimNPC
                            )
                            if target then
                                local root = target:FindFirstChild("HumanoidRootPart")
                                    or target:FindFirstChild("Torso")
                                    or target:FindFirstChild("UpperTorso")
                                if root then
                                    local aimPos = root.Position
                                    if State.SAPrediction then
                                        aimPos = predictPosition(target, State.SAPredictionAmount)
                                    end
                                    args[2] = aimPos
                                    return oldNamecall(self, table.unpack(args))
                                end
                            end
                        end
                    end
                end
            end
        end

        return oldNamecall(self, ...)
    end)
    setreadonly(rawMeta, true)
end

-- ═══ UI ═══
local Window = Rayfield:CreateWindow({
    Name = "Blox Fruits Aimbot | [Ghaith]",
    LoadingTitle = "Loading...",
    LoadingSubtitle = "by [Ghaith]",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false
})

local AimbotTab = Window:CreateTab("Aimbot", 4483362458)
local SilentTab = Window:CreateTab("Silent Aim", 4483362458)
local VisualsTab = Window:CreateTab("Visuals", 4483362458)
local SkillTab = Window:CreateTab("Skill Routing", 4483362458)
local SettingsTab = Window:CreateTab("Settings", 4483362458)

local function getPlayerList()
    local list = {"None"}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            table.insert(list, plr.Name)
        end
    end
    return list
end

local function updateTargetList()
    local list = {"None"}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            table.insert(list, plr.Name)
        end
    end
    for _, container in ipairs({Workspace:FindFirstChild("Enemies"), ReplicatedStorage:FindFirstChild("Enemies")}) do
        if container then
            for _, npc in ipairs(container:GetChildren()) do
                if npc:IsA("Model") then
                    table.insert(list, npc.Name)
                end
            end
        end
    end
    return list
end

-- ─── AIMBOT TAB ───
AimbotTab:CreateToggle({Name = "Aimlock Players", CurrentValue = false, Flag = "AimlockPlayers", Callback = function(v) State.AimlockPlayers = v end})
AimbotTab:CreateToggle({Name = "Aimlock NPC", CurrentValue = false, Flag = "AimlockNPC", Callback = function(v) State.AimlockNPC = v end})
AimbotTab:CreateSlider({Name = "Aimlock Range", Range = {0, 2000}, Increment = 10, Suffix = " studs", CurrentValue = 1000, Flag = "AimlockRange", Callback = function(v) State.AimlockRange = v end})
AimbotTab:CreateToggle({Name = "Aimlock Prediction", CurrentValue = false, Flag = "AimlockPrediction", Callback = function(v) State.AimlockPrediction = v end})
AimbotTab:CreateSlider({Name = "Prediction Amount", Range = {0, 1}, Increment = 0.01, CurrentValue = 0.12, Flag = "PredictionAmount", Callback = function(v) State.PredictionAmount = v end})
AimbotTab:CreateToggle({Name = "Target Lowest HP", CurrentValue = false, Flag = "TargetLowestHP", Callback = function(v) State.TargetLowestHP = v end})

AimbotTab:CreateSection("Manual Target Player")
AimbotTab:CreateToggle({Name = "Manual Target Player (lock to one)", CurrentValue = false, Flag = "ManualTargetEnabled", Callback = function(v) State.ManualTargetEnabled = v end})
local manualTargetDropdown = AimbotTab:CreateDropdown({Name = "Select Player", Options = getPlayerList(), CurrentOption = "None", Flag = "ManualTargetPlayer", Callback = function(v) State.ManualTargetPlayer = v[1] end})
AimbotTab:CreateButton({Name = "Refresh Player List", Callback = function() manualTargetDropdown:SetOptions(getPlayerList()) end})
AimbotTab:CreateDropdown({Name = "Aimlock Target", Options = updateTargetList(), CurrentOption = "None", Flag = "AimlockTarget", Callback = function(v) State.AimlockTarget = v[1] end})

-- ─── SILENT AIM TAB ───
SilentTab:CreateToggle({Name = "Silent Aim Players", CurrentValue = false, Flag = "SilentAimPlayers", Callback = function(v) State.SilentAimPlayers = v end})
SilentTab:CreateToggle({Name = "Silent Aim NPC", CurrentValue = false, Flag = "SilentAimNPC", Callback = function(v) State.SilentAimNPC = v end})
SilentTab:CreateSlider({Name = "SA Range (independent)", Range = {0, 2000}, Increment = 10, Suffix = " studs", CurrentValue = 1000, Flag = "SilentAimRange", Callback = function(v) State.SilentAimRange = v end})
SilentTab:CreateToggle({Name = "SA Prediction", CurrentValue = false, Flag = "SAPrediction", Callback = function(v) State.SAPrediction = v end})
SilentTab:CreateSlider({Name = "SA Prediction Amount", Range = {0, 1}, Increment = 0.01, CurrentValue = 0.2, Flag = "SAPredictionAmount", Callback = function(v) State.SAPredictionAmount = v end})
SilentTab:CreateDropdown({Name = "Silent Lock Target", Options = updateTargetList(), CurrentOption = "None", Flag = "SilentLockTarget", Callback = function(v) State.SilentLockTarget = v[1] end})
SilentTab:CreateParagraph({Title = "How Silent Aim Works", Content = "Injects target position into CommF_'s MousePos argument on fire. Blox Fruits reads mouse position to determine hit location."})

-- ─── VISUALS TAB ───
VisualsTab:CreateToggle({Name = "Highlight Target", CurrentValue = false, Flag = "HighlightTarget", Callback = function(v) State.HighlightTarget = v end})
VisualsTab:CreateToggle({Name = "Show Tracer", CurrentValue = false, Flag = "ShowTracer", Callback = function(v) State.ShowTracer = v end})
VisualsTab:CreateToggle({Name = "Show FOV Ring (gates Aimlock)", CurrentValue = false, Flag = "ShowFOVRing", Callback = function(v) State.ShowFOVRing = v end})
VisualsTab:CreateSlider({Name = "FOV Size", Range = {50, 1000}, Increment = 10, Suffix = " px", CurrentValue = 200, Flag = "FOVSize", Callback = function(v) State.FOVSize = v end})

VisualsTab:CreateSection("Hitbox")
VisualsTab:CreateToggle({Name = "Expand Hitbox", CurrentValue = false, Flag = "HitboxEnabled", Callback = function(v)
    State.HitboxEnabled = v
    if not v then restoreAllHitboxes() end
end})
VisualsTab:CreateSlider({Name = "Hitbox Size", Range = {1, 15}, Increment = 0.5, Suffix = " studs", CurrentValue = 5, Flag = "HitboxSize", Callback = function(v) State.HitboxSize = v end})
VisualsTab:CreateToggle({Name = "Show Hitbox (visual box)", CurrentValue = false, Flag = "ShowHitbox", Callback = function(v) State.ShowHitbox = v end})

-- ─── SKILL ROUTING TAB ───
SkillTab:CreateToggle({Name = "Skill Routing (auto-cast)", CurrentValue = false, Flag = "SkillRouting", Callback = function(v) State.SkillRouting = v end})
SkillTab:CreateSlider({Name = "Skill Activation Range", Range = {5, 100}, Increment = 1, Suffix = " studs", CurrentValue = 30, Flag = "SkillRange", Callback = function(v) State.SkillRange = v end})
SkillTab:CreateSlider({Name = "Skill Delay", Range = {0.05, 1}, Increment = 0.05, Suffix = " s", CurrentValue = 0.2, Flag = "SkillDelay", Callback = function(v) State.SkillDelay = v end})
SkillTab:CreateParagraph({Title = "Skill Routing", Content = "Cycles Z -> X -> C -> V -> F when target is within range. Uses VirtualInputManager — Blox Fruits registers it as real keypresses."})

-- ─── SETTINGS TAB ───
SettingsTab:CreateToggle({Name = "Anti-Cheat Bypass", CurrentValue = true, Flag = "AntiCheatBypass", Callback = function(v) State.AntiCheatBypass = v end})
SettingsTab:CreateParagraph({Title = "Anti-Cheat Bypass", Content = "Blocks CHECKER, BANREMOTE, KICKREMOTE, and other detection remotes. Must stay on for silent aim to fire safely."})

-- auto-refresh
task.spawn(function()
    while task.wait(3) do
        pcall(function() manualTargetDropdown:SetOptions(getPlayerList()) end)
    end
end)

-- ═══ MAIN LOOP ═══
RunService.RenderStepped:Connect(function()
    local activeTarget = getClosestTarget(
        State.AimlockRange, State.ShowFOVRing, State.FOVSize,
        State.TargetLowestHP, State.AimlockTarget,
        State.AimlockPlayers, State.AimlockNPC
    )

    -- AIMLOCK
    if (State.AimlockPlayers or State.AimlockNPC or State.ManualTargetEnabled) and activeTarget then
        local root = activeTarget:FindFirstChild("HumanoidRootPart")
            or activeTarget:FindFirstChild("Torso")
            or activeTarget:FindFirstChild("UpperTorso")
        if root then
            local aimPos = root.Position
            if State.AimlockPrediction then
                aimPos = predictPosition(activeTarget, State.PredictionAmount)
            end
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, aimPos)
        end
    end

    -- SKILL ROUTING
    if State.SkillRouting then
        local myChar = LocalPlayer.Character
        local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
        local myHum = myChar and myChar:FindFirstChild("Humanoid")
        if myRoot and myHum and myHum.Health > 0 and activeTarget then
            local tRoot = activeTarget:FindFirstChild("HumanoidRootPart")
            if tRoot then
                local dist = (tRoot.Position - myRoot.Position).Magnitude
                if dist <= State.SkillRange and tick() - lastSkillFire >= State.SkillDelay then
                    lastSkillFire = tick()
                    fireSkill(SKILL_KEYS[skillIndex])
                    skillIndex = (skillIndex % #SKILL_KEYS) + 1
                end
            end
        end
    end

    -- HITBOX
    if State.HitboxEnabled then
        local hbTargets = getHitboxTargets()
        local hbSet = {}
        for _, char in ipairs(hbTargets) do
            applyHitbox(char, State.HitboxSize)
            hbSet[char] = true
        end
        for char, _ in pairs(modifiedHitboxes) do
            if not hbSet[char] then restoreHitbox(char) end
        end
    end

    -- SHOW HITBOX (visual square)
    if State.ShowHitbox and HitboxBox and activeTarget then
        local root = activeTarget:FindFirstChild("HumanoidRootPart")
        if root then
            local cf = root.CFrame
            local sz = root.Size
            local corners = {
                cf * Vector3.new(sz.X/2, sz.Y/2, sz.Z/2),
                cf * Vector3.new(-sz.X/2, sz.Y/2, sz.Z/2),
                cf * Vector3.new(sz.X/2, -sz.Y/2, sz.Z/2),
                cf * Vector3.new(-sz.X/2, -sz.Y/2, sz.Z/2),
                cf * Vector3.new(sz.X/2, sz.Y/2, -sz.Z/2),
                cf * Vector3.new(-sz.X/2, sz.Y/2, -sz.Z/2),
                cf * Vector3.new(sz.X/2, -sz.Y/2, -sz.Z/2),
                cf * Vector3.new(-sz.X/2, -sz.Y/2, -sz.Z/2),
            }
            local minX, minY = math.huge, math.huge
            local maxX, maxY = -math.huge, -math.huge
            for _, c in ipairs(corners) do
                local sp, onScreen = Camera:WorldToViewportPoint(c)
                if onScreen then
                    minX = math.min(minX, sp.X); minY = math.min(minY, sp.Y)
                    maxX = math.max(maxX, sp.X); maxY = math.max(maxY, sp.Y)
                end
            end
            if minX < math.huge then
                pcall(function()
                    HitboxBox.Size = Vector2.new(maxX - minX, maxY - minY)
                    HitboxBox.Position = Vector2.new(minX, minY)
                    HitboxBox.Visible = true
                end)
            else
                pcall(function() HitboxBox.Visible = false end)
            end
        end
    elseif HitboxBox then
        pcall(function() HitboxBox.Visible = false end)
    end

    -- HIGHLIGHT
    if State.HighlightTarget and activeTarget then
        if not Highlight or Highlight.Parent ~= activeTarget then
            if Highlight then Highlight:Destroy() end
            Highlight = Instance.new("Highlight")
            Highlight.FillColor = Color3.fromRGB(255, 0, 0)
            Highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
            Highlight.Parent = activeTarget
        end
    elseif Highlight then
        Highlight:Destroy()
        Highlight = nil
    end

    -- TRACER
    if Tracer then
        if State.ShowTracer and activeTarget then
            local root = activeTarget:FindFirstChild("HumanoidRootPart")
                or activeTarget:FindFirstChild("Torso")
                or activeTarget:FindFirstChild("UpperTorso")
            if root then
                local sp, onScreen = Camera:WorldToViewportPoint(root.Position)
                if onScreen then
                    pcall(function()
                        Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                        Tracer.To = Vector2.new(sp.X, sp.Y)
                        Tracer.Visible = true
                    end)
                else
                    pcall(function() Tracer.Visible = false end)
                end
            end
        else
            pcall(function() Tracer.Visible = false end)
        end
    end

    -- FOV RING
    if FOVCircle then
        if State.ShowFOVRing then
            pcall(function()
                FOVCircle.Visible = true
                FOVCircle.Radius = State.FOVSize
                FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
            end)
        else
            pcall(function() FOVCircle.Visible = false end)
        end
    end
end)

-- cleanup on respawn
LocalPlayer.CharacterRemoving:Connect(function(char)
    restoreHitbox(char)
end)

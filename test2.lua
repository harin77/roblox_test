-- Blox Fruits Aimbot / Silent Aim / Skills - Universal
-- [Ghaith] for WVERZNXRL
-- version 4

print("[Ghaith] script version 4 loaded")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

-- ============================================================
-- UI FIRST
-- ============================================================
local Rayfield
local ok, err = pcall(function()
    Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
end)
if not ok or not Rayfield then
    warn("[Ghaith] Rayfield failed to load: " .. tostring(err))
    return
end

-- ============================================================
-- STATE
-- ============================================================
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

-- ============================================================
-- VISUAL OBJECTS (all pcall-wrapped)
-- ============================================================
local VisualFolder
pcall(function()
    VisualFolder = Instance.new("Folder")
    VisualFolder.Name = "GhaithVisuals"
    VisualFolder.Parent = Workspace
end)

-- tracer: stretched part (ESP line)
local tracerPart
pcall(function()
    tracerPart = Instance.new("Part")
    tracerPart.Name = "TracerLine"
    tracerPart.Anchored = true
    tracerPart.CanCollide = false
    tracerPart.CanQuery = false
    tracerPart.CanTouch = false
    tracerPart.Material = Enum.Material.Neon
    tracerPart.Color = Color3.fromRGB(0, 255, 0)
    tracerPart.Size = Vector3.new(0.2, 0.2, 1)
    tracerPart.Transparency = 1
    tracerPart.Parent = VisualFolder
end)

-- fov ring: 4 thin parts as a frame
local fovFrame = {}
pcall(function()
    for i = 1, 4 do
        local p = Instance.new("Part")
        p.Name = "FOVEdge" .. i
        p.Anchored = true
        p.CanCollide = false
        p.CanQuery = false
        p.CanTouch = false
        p.Material = Enum.Material.Neon
        p.Color = Color3.fromRGB(255, 255, 255)
        p.Size = Vector3.new(0.1, 0.1, 1)
        p.Transparency = 1
        p.Parent = VisualFolder
        fovFrame[i] = p
    end
end)

-- hitbox visual box
local hitboxPart
pcall(function()
    hitboxPart = Instance.new("Part")
    hitboxPart.Name = "HitboxVisual"
    hitboxPart.Anchored = true
    hitboxPart.CanCollide = false
    hitboxPart.CanQuery = false
    hitboxPart.CanTouch = false
    hitboxPart.Material = Enum.Material.Neon
    hitboxPart.Color = Color3.fromRGB(0, 255, 255)
    hitboxPart.Size = Vector3.new(4, 4, 4)
    hitboxPart.Transparency = 1
    hitboxPart.Parent = VisualFolder
end)

-- ============================================================
-- HITBOX PARTS
-- ============================================================
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

-- ============================================================
-- HELPERS
-- ============================================================
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
    local containers = {}
    local we = Workspace:FindFirstChild("Enemies")
    if we then table.insert(containers, we) end
    local re = ReplicatedStorage:FindFirstChild("Enemies")
    if re then table.insert(containers, re) end
    for _, c in ipairs(containers) do
        for _, npc in ipairs(c:GetChildren()) do
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

local function getTargets(incP, incN)
    local t = {}
    if incP then
        for _, p in ipairs(getPlayers()) do
            table.insert(t, p.Character)
        end
    end
    if incN then
        for _, n in ipairs(getNPCs()) do
            table.insert(t, n)
        end
    end
    return t
end

local function predictPosition(target, amount)
    local root = target:FindFirstChild("HumanoidRootPart")
        or target:FindFirstChild("Torso")
        or target:FindFirstChild("UpperTorso")
    if not root then return target.Position end
    return root.Position + root.Velocity * amount
end

local function getClosestTarget(range, checkFOV, fovSize, lowHP, specific, incP, incN)
    if State.ManualTargetEnabled and State.ManualTargetPlayer ~= "None" then
        local plr = Players:FindFirstChild(State.ManualTargetPlayer)
        if plr and plr ~= LocalPlayer and isAlive(plr) then
            local root = plr.Character:FindFirstChild("HumanoidRootPart")
            if root and (Camera.CFrame.Position - root.Position).Magnitude <= range then
                return plr.Character
            end
        end
        return nil
    end

    local targets = getTargets(incP, incN)
    local closest, closestDist = nil, range or math.huge
    local mousePos = UserInputService:GetMouseLocation()
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

    for _, target in ipairs(targets) do
        if not (specific and specific ~= "None" and target.Name ~= specific) then
            local root = target:FindFirstChild("HumanoidRootPart")
                or target:FindFirstChild("Torso")
                or target:FindFirstChild("UpperTorso")
            if root then
                local pos = root.Position
                local sp, onScreen = Camera:WorldToViewportPoint(pos)
                if onScreen then
                    local sd = (Vector2.new(sp.X, sp.Y) - mousePos).Magnitude
                    local passFOV = true
                    if checkFOV then
                        local fd = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                        if fd > fovSize then passFOV = false end
                    end
                    if passFOV then
                        local wd = (Camera.CFrame.Position - pos).Magnitude
                        if wd <= range then
                            if lowHP then
                                local hum = target:FindFirstChild("Humanoid")
                                if hum then
                                    if closest then
                                        local ch = closest:FindFirstChild("Humanoid")
                                        if ch and hum.Health >= ch.Health then
                                            -- skip
                                        else
                                            closest, closestDist = target, wd
                                        end
                                    else
                                        closest, closestDist = target, wd
                                    end
                                end
                            else
                                if sd < closestDist then
                                    closest, closestDist = target, sd
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

-- ============================================================
-- HITBOX
-- ============================================================
local function applyHitbox(char, size)
    if not char then return end
    local data = modifiedHitboxes[char]
    if not data then
        data = { parts = {} }
        modifiedHitboxes[char] = data
    end
    for _, name in ipairs(HITBOX_PARTS) do
        local part = char:FindFirstChild(name)
        if part and part:IsA("BasePart") then
            if not data.parts[part] then
                data.parts[part] = { size = part.Size, canCollide = part.CanCollide, massless = part.Massless }
            end
            part.Size = Vector3.new(size, size, size)
            part.CanCollide = false
            part.Massless = true
        end
    end
end

local function restoreHitbox(char)
    if not char then return end
    local data = modifiedHitboxes[char]
    if not data then return end
    for part, orig in pairs(data.parts) do
        if part and part.Parent then
            part.Size = orig.size
            part.CanCollide = orig.canCollide
            part.Massless = orig.massless
        end
    end
    modifiedHitboxes[char] = nil
end

local function restoreAllHitboxes()
    for c, _ in pairs(modifiedHitboxes) do
        restoreHitbox(c)
    end
end

local function getHitboxTargets()
    local t = {}
    if State.ManualTargetEnabled and State.ManualTargetPlayer ~= "None" then
        local plr = Players:FindFirstChild(State.ManualTargetPlayer)
        if plr and plr ~= LocalPlayer and isAlive(plr) then
            table.insert(t, plr.Character)
        end
        return t
    end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and isAlive(plr) then
            local root = plr.Character:FindFirstChild("HumanoidRootPart")
            if root and (Camera.CFrame.Position - root.Position).Magnitude <= State.AimlockRange then
                table.insert(t, plr.Character)
            end
        end
    end
    if State.AimlockNPC then
        for _, npc in ipairs(getNPCs()) do
            table.insert(t, npc)
        end
    end
    return t
end

-- ============================================================
-- SKILLS
-- ============================================================
local SKILL_KEYS = {"Z", "X", "C", "V", "F"}
local skillIndex = 1
local lastSkillFire = 0

local function getEquippedTool()
    local char = LocalPlayer.Character
    if not char then return nil end
    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("Tool") then return child end
    end
    return nil
end

local function fireSkill(key)
    local tool = getEquippedTool()
    if tool then
        local ok = pcall(function() tool:Activate() end)
        if ok then return true end
    end
    local vim = game:GetService("VirtualInputManager")
    local ok2 = pcall(function()
        vim:SendKeyEvent(true, key, false, game)
        task.wait(0.03)
        vim:SendKeyEvent(false, key, false, game)
    end)
    if ok2 then return true end
    if keypress and keyrelease then
        local ok3 = pcall(function()
            keypress(string.byte(key))
            task.wait(0.03)
            keyrelease(string.byte(key))
        end)
        if ok3 then return true end
    end
    return false
end

-- ============================================================
-- NAMECALL HOOK (silent aim + anti-cheat)
-- ============================================================
local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
local CommF_ = Remotes and Remotes:FindFirstChild("CommF_")

local hookInstalled = false
if getrawmetatable and setreadonly and newcclosure and CommF_ then
    local ok = pcall(function()
        local rawMeta = getrawmetatable(game)
        setreadonly(rawMeta, false)
        local oldNamecall = rawMeta.__namecall
        rawMeta.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()
            local args = {...}
            if method == "FireServer" or method == "InvokeServer" then
                if State.AntiCheatBypass then
                    local first = tostring(args[1])
                    if first == "TeleportDetect" or first == "CHECKER_1" or first == "CHECKER"
                    or first == "GUI_CHECK" or first == "OneMoreTime" or first == "checkingSPEED"
                    or first == "BANREMOTE" or first == "PERMAIDBAN" or first == "KICKREMOTE"
                    or first == "BR_KICKPC" or first == "BR_KICKMOBILE" then
                        return
                    end
                end
                if self == CommF_ and method == "FireServer" then
                    if tostring(args[1]) == "RemoteEvent"
                    and tostring(args[2]) ~= "true" and tostring(args[2]) ~= "false" then
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
            return oldNamecall(self, ...)
        end)
        setreadonly(rawMeta, true)
    end)
    hookInstalled = ok
end

-- ============================================================
-- RAYFIELD UI
-- ============================================================
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
local SkillTab = Window:CreateTab("Skills", 4483362458)
local SettingsTab = Window:CreateTab("Settings", 4483362458)

local function getPlayerList()
    local l = {"None"}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then table.insert(l, p.Name) end
    end
    return l
end

local function updateTargetList()
    local l = {"None"}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then table.insert(l, p.Name) end
    end
    local c1 = Workspace:FindFirstChild("Enemies")
    local c2 = ReplicatedStorage:FindFirstChild("Enemies")
    for _, c in ipairs({c1, c2}) do
        if c then
            for _, n in ipairs(c:GetChildren()) do
                if n:IsA("Model") then table.insert(l, n.Name) end
            end
        end
    end
    return l
end

AimbotTab:CreateToggle({Name = "Aimlock Players", CurrentValue = false, Flag = "AimlockPlayers", Callback = function(v) State.AimlockPlayers = v end})
AimbotTab:CreateToggle({Name = "Aimlock NPC", CurrentValue = false, Flag = "AimlockNPC", Callback = function(v) State.AimlockNPC = v end})
AimbotTab:CreateSlider({Name = "Aimlock Range", Range = {0, 2000}, Increment = 10, Suffix = " studs", CurrentValue = 1000, Flag = "AimlockRange", Callback = function(v) State.AimlockRange = v end})
AimbotTab:CreateToggle({Name = "Aimlock Prediction", CurrentValue = false, Flag = "AimlockPrediction", Callback = function(v) State.AimlockPrediction = v end})
AimbotTab:CreateSlider({Name = "Prediction Amount", Range = {0, 1}, Increment = 0.01, CurrentValue = 0.12, Flag = "PredictionAmount", Callback = function(v) State.PredictionAmount = v end})
AimbotTab:CreateToggle({Name = "Target Lowest HP", CurrentValue = false, Flag = "TargetLowestHP", Callback = function(v) State.TargetLowestHP = v end})

AimbotTab:CreateSection("Manual Target")
AimbotTab:CreateToggle({Name = "Lock to one player", CurrentValue = false, Flag = "ManualTargetEnabled", Callback = function(v) State.ManualTargetEnabled = v end})
local manualDrop = AimbotTab:CreateDropdown({Name = "Select Player", Options = getPlayerList(), CurrentOption = "None", Flag = "ManualTargetPlayer", Callback = function(v) State.ManualTargetPlayer = v[1] end})
AimbotTab:CreateButton({Name = "Refresh Player List", Callback = function() manualDrop:SetOptions(getPlayerList()) end})
AimbotTab:CreateDropdown({Name = "Aimlock Target Filter", Options = updateTargetList(), CurrentOption = "None", Flag = "AimlockTarget", Callback = function(v) State.AimlockTarget = v[1] end})

SilentTab:CreateToggle({Name = "Silent Aim Players", CurrentValue = false, Flag = "SilentAimPlayers", Callback = function(v) State.SilentAimPlayers = v end})
SilentTab:CreateToggle({Name = "Silent Aim NPC", CurrentValue = false, Flag = "SilentAimNPC", Callback = function(v) State.SilentAimNPC = v end})
SilentTab:CreateSlider({Name = "SA Range", Range = {0, 2000}, Increment = 10, Suffix = " studs", CurrentValue = 1000, Flag = "SilentAimRange", Callback = function(v) State.SilentAimRange = v end})
SilentTab:CreateToggle({Name = "SA Prediction", CurrentValue = false, Flag = "SAPrediction", Callback = function(v) State.SAPrediction = v end})
SilentTab:CreateSlider({Name = "SA Prediction Amount", Range = {0, 1}, Increment = 0.01, CurrentValue = 0.2, Flag = "SAPredictionAmount", Callback = function(v) State.SAPredictionAmount = v end})
SilentTab:CreateDropdown({Name = "Silent Lock Target", Options = updateTargetList(), CurrentOption = "None", Flag = "SilentLockTarget", Callback = function(v) State.SilentLockTarget = v[1] end})
SilentTab:CreateParagraph({Title = "Hook Status", Content = hookInstalled and "Silent aim active." or "Executor blocks namecall hook - use aimlock."})

VisualsTab:CreateToggle({Name = "Highlight Target", CurrentValue = false, Flag = "HighlightTarget", Callback = function(v) State.HighlightTarget = v end})
VisualsTab:CreateToggle({Name = "Show Tracer (line)", CurrentValue = false, Flag = "ShowTracer", Callback = function(v) State.ShowTracer = v end})
VisualsTab:CreateToggle({Name = "Show FOV Ring", CurrentValue = false, Flag = "ShowFOVRing", Callback = function(v) State.ShowFOVRing = v end})
VisualsTab:CreateSlider({Name = "FOV Size", Range = {50, 1000}, Increment = 10, Suffix = " px", CurrentValue = 200, Flag = "FOVSize", Callback = function(v) State.FOVSize = v end})

VisualsTab:CreateSection("Hitbox")
VisualsTab:CreateToggle({Name = "Expand Hitbox", CurrentValue = false, Flag = "HitboxEnabled", Callback = function(v)
    State.HitboxEnabled = v
    if not v then restoreAllHitboxes() end
end})
VisualsTab:CreateSlider({Name = "Hitbox Size", Range = {1, 15}, Increment = 0.5, Suffix = " studs", CurrentValue = 5, Flag = "HitboxSize", Callback = function(v) State.HitboxSize = v end})
VisualsTab:CreateToggle({Name = "Show Hitbox Visual", CurrentValue = false, Flag = "ShowHitbox", Callback = function(v) State.ShowHitbox = v end})

SkillTab:CreateToggle({Name = "Skill Routing (auto-cast)", CurrentValue = false, Flag = "SkillRouting", Callback = function(v) State.SkillRouting = v end})
SkillTab:CreateSlider({Name = "Skill Range", Range = {5, 100}, Increment = 1, Suffix = " studs", CurrentValue = 30, Flag = "SkillRange", Callback = function(v) State.SkillRange = v end})
SkillTab:CreateSlider({Name = "Skill Delay", Range = {0.05, 1}, Increment = 0.05, Suffix = " s", CurrentValue = 0.2, Flag = "SkillDelay", Callback = function(v) State.SkillDelay = v end})
SkillTab:CreateParagraph({Title = "Method", Content = "Tries Tool Activate, then VIM, then keypress."})

SettingsTab:CreateToggle({Name = "Anti-Cheat Bypass", CurrentValue = true, Flag = "AntiCheatBypass", Callback = function(v) State.AntiCheatBypass = v end})
SettingsTab:CreateParagraph({Title = "Hook", Content = hookInstalled and "installed" or "blocked by executor"})

task.spawn(function()
    while task.wait(3) do
        pcall(function() manualDrop:SetOptions(getPlayerList()) end)
    end
end)

-- ============================================================
-- TRACER UPDATE - NaN-safe
-- ============================================================
local function updateTracer(fromPos, toPos)
    if not tracerPart then return end

    if typeof(fromPos) ~= "Vector3" or typeof(toPos) ~= "Vector3" then
        tracerPart.Transparency = 1
        return
    end
    -- NaN check
    if fromPos.X ~= fromPos.X or fromPos.Y ~= fromPos.Y or fromPos.Z ~= fromPos.Z then
        tracerPart.Transparency = 1
        return
    end
    if toPos.X ~= toPos.X or toPos.Y ~= toPos.Y or toPos.Z ~= toPos.Z then
        tracerPart.Transparency = 1
        return
    end

    local delta = toPos - fromPos
    local len = delta.Magnitude

    if len ~= len or len < 0.5 then
        tracerPart.Transparency = 1
        return
    end
    if len > 5000 then len = 5000 end

    local mid = fromPos + delta * 0.5
    local unit = delta.Unit
    if unit.X ~= unit.X or unit.Y ~= unit.Y or unit.Z ~= unit.Z then
        tracerPart.Transparency = 1
        return
    end

    pcall(function()
        tracerPart.CFrame = CFrame.new(mid, mid + unit)
        tracerPart.Size = Vector3.new(0.2, 0.2, len)
        tracerPart.Transparency = 0
    end)
end

-- ============================================================
-- FOV RING UPDATE
-- ============================================================
local function updateFOVRing()
    if #fovFrame < 4 then return end
    local size = State.FOVSize / 200
    if size ~= size or size < 0.1 then size = 1 end

    local center = Camera.CFrame * CFrame.new(0, 0, -3)

    pcall(function()
        fovFrame[1].CFrame = center * CFrame.new(0, size, 0)
        fovFrame[1].Size = Vector3.new(0.1, 0.05, size * 2)
        fovFrame[1].Transparency = 0.3

        fovFrame[2].CFrame = center * CFrame.new(0, -size, 0)
        fovFrame[2].Size = Vector3.new(0.1, 0.05, size * 2)
        fovFrame[2].Transparency = 0.3

        fovFrame[3].CFrame = center * CFrame.new(-size, 0, 0) * CFrame.Angles(math.rad(90), 0, 0)
        fovFrame[3].Size = Vector3.new(0.1, 0.05, size * 2)
        fovFrame[3].Transparency = 0.3

        fovFrame[4].CFrame = center * CFrame.new(size, 0, 0) * CFrame.Angles(math.rad(90), 0, 0)
        fovFrame[4].Size = Vector3.new(0.1, 0.05, size * 2)
        fovFrame[4].Transparency = 0.3
    end)
end

local function hideFOVRing()
    for _, p in ipairs(fovFrame) do
        pcall(function() p.Transparency = 1 end)
    end
end

-- ============================================================
-- MAIN LOOP
-- ============================================================
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

    -- SKILLS
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
        local targets = getHitboxTargets()
        local set = {}
        for _, c in ipairs(targets) do
            applyHitbox(c, State.HitboxSize)
            set[c] = true
        end
        for c, _ in pairs(modifiedHitboxes) do
            if not set[c] then restoreHitbox(c) end
        end
    end

    -- HITBOX VISUAL
    if hitboxPart then
        if State.ShowHitbox and activeTarget then
            local root = activeTarget:FindFirstChild("HumanoidRootPart")
            if root then
                pcall(function()
                    hitboxPart.CFrame = root.CFrame
                    hitboxPart.Size = root.Size
                    hitboxPart.Transparency = 0.5
                end)
            end
        else
            pcall(function() hitboxPart.Transparency = 1 end)
        end
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
    if tracerPart then
        if State.ShowTracer and activeTarget then
            local root = activeTarget:FindFirstChild("HumanoidRootPart")
                or activeTarget:FindFirstChild("Torso")
                or activeTarget:FindFirstChild("UpperTorso")
            if root then
                local camPos = Camera.CFrame.Position + Camera.CFrame.LookVector * 1.5
                updateTracer(camPos, root.Position)
            else
                pcall(function() tracerPart.Transparency = 1 end)
            end
        else
            pcall(function() tracerPart.Transparency = 1 end)
        end
    end

    -- FOV RING
    if State.ShowFOVRing then
        updateFOVRing()
    else
        hideFOVRing()
    end
end)

LocalPlayer.CharacterRemoving:Connect(function(c) restoreHitbox(c) end)

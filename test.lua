-- Blox Fruits Aimbot / Silent Aim / Skills - Universal PC + Mobile
-- [Ghaith] for WVERZNXRL

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
local CommF_ = Remotes and Remotes:FindFirstChild("CommF_")

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- STATE
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

-- MOBILE-SAFE VISUALS (Part + Beam based)
local VisualFolder = Instance.new("Folder")
VisualFolder.Name = "GhaithVisuals"
VisualFolder.Parent = Workspace

local tracerPart0 = Instance.new("Part")
tracerPart0.Name = "TracerStart"
tracerPart0.Anchored = true
tracerPart0.CanCollide = false
tracerPart0.Transparency = 1
tracerPart0.Size = Vector3.new(0.1, 0.1, 0.1)
tracerPart0.Parent = VisualFolder

local tracerAtt0 = Instance.new("Attachment")
tracerAtt0.Parent = tracerPart0

local tracerPart1 = Instance.new("Part")
tracerPart1.Name = "TracerEnd"
tracerPart1.Anchored = true
tracerPart1.CanCollide = false
tracerPart1.Transparency = 1
tracerPart1.Size = Vector3.new(0.1, 0.1, 0.1)
tracerPart1.Parent = VisualFolder

local tracerAtt1 = Instance.new("Attachment")
tracerAtt1.Parent = tracerPart1

local tracerBeam = Instance.new("Beam")
tracerBeam.Attachment0 = tracerAtt0
tracerBeam.Attachment1 = tracerAtt1
tracerBeam.Color = ColorSequence.new(Color3.fromRGB(0, 255, 0))
tracerBeam.Thickness = 0.15
tracerBeam.FaceCamera = true
tracerBeam.Enabled = false
tracerBeam.Parent = tracerPart0

local fovPart = Instance.new("Part")
fovPart.Name = "FOVRing"
fovPart.Anchored = true
fovPart.CanCollide = false
fovPart.Shape = Enum.PartType.Cylinder
fovPart.Material = Enum.Material.Neon
fovPart.Color = Color3.fromRGB(255, 255, 255)
fovPart.Transparency = 0.7
fovPart.Size = Vector3.new(0.05, 5, 5)
fovPart.Parent = VisualFolder
fovPart.Transparency = 1

local hitboxPart = Instance.new("Part")
hitboxPart.Name = "HitboxVisual"
hitboxPart.Anchored = true
hitboxPart.CanCollide = false
hitboxPart.Material = Enum.Material.Neon
hitboxPart.Color = Color3.fromRGB(0, 255, 255)
hitboxPart.Transparency = 0.5
hitboxPart.Parent = VisualFolder
hitboxPart.Transparency = 1

-- HITBOX PARTS
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

-- HELPERS
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

-- HITBOX
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

-- SKILLS
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
    -- method 1: Tool:Activate (mobile-safe)
    local tool = getEquippedTool()
    if tool then
        local ok = pcall(function() tool:Activate() end)
        if ok then return true end
    end
    -- method 2: VirtualInputManager key event
    local vim = game:GetService("VirtualInputManager")
    local ok2 = pcall(function()
        vim:SendKeyEvent(true, key, false, game)
        task.wait(0.03)
        vim:SendKeyEvent(false, key, false, game)
    end)
    if ok2 then return true end
    -- method 3: raw keypress
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

-- NAMECALL HOOK (silent aim + anti-cheat)
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

if not hookInstalled then
    warn("[Ghaith] namecall hook unavailable - silent aim disabled. aimlock still works.")
end

-- UI
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

AimbotTab:CreateSection("Manual Target Player")
AimbotTab:CreateToggle({Name = "Manual Target (lock to one)", CurrentValue = false, Flag = "ManualTargetEnabled", Callback = function(v) State.ManualTargetEnabled = v end})
local manualDrop = AimbotTab:CreateDropdown({Name = "Select Player", Options = getPlayerList(), CurrentOption = "None", Flag = "ManualTargetPlayer", Callback = function(v) State.ManualTargetPlayer = v[1] end})
AimbotTab:CreateButton({Name = "Refresh Player List", Callback = function() manualDrop:SetOptions(getPlayerList()) end})
AimbotTab:CreateDropdown({Name = "Aimlock Target", Options = updateTargetList(), CurrentOption = "None", Flag = "AimlockTarget", Callback = function(v) State.AimlockTarget = v[1] end})

SilentTab:CreateToggle({Name = "Silent Aim Players", CurrentValue = false, Flag = "SilentAimPlayers", Callback = function(v) State.SilentAimPlayers = v end})
SilentTab:CreateToggle({Name = "Silent Aim NPC", CurrentValue = false, Flag = "SilentAimNPC", Callback = function(v) State.SilentAimNPC = v end})
SilentTab:CreateSlider({Name = "SA Range", Range = {0, 2000}, Increment = 10, Suffix = " studs", CurrentValue = 1000, Flag = "SilentAimRange", Callback = function(v) State.SilentAimRange = v end})
SilentTab:CreateToggle({Name = "SA Prediction", CurrentValue = false, Flag = "SAPrediction", Callback = function(v) State.SAPrediction = v end})
SilentTab:CreateSlider({Name = "SA Prediction Amount", Range = {0, 1}, Increment = 0.01, CurrentValue = 0.2, Flag = "SAPredictionAmount", Callback = function(v) State.SAPredictionAmount = v end})
SilentTab:CreateDropdown({Name = "Silent Lock Target", Options = updateTargetList(), CurrentOption = "None", Flag = "SilentLockTarget", Callback = function(v) State.SilentLockTarget = v[1] end})
SilentTab:CreateParagraph({Title = "Hook Status", Content = hookInstalled and "Silent aim active." or "Executor blocks namecall hook. Silent aim unavailable - use aimlock."})

VisualsTab:CreateToggle({Name = "Highlight Target", CurrentValue = false, Flag = "HighlightTarget", Callback = function(v) State.HighlightTarget = v end})
VisualsTab:CreateToggle({Name = "Show Tracer (beam)", CurrentValue = false, Flag = "ShowTracer", Callback = function(v) State.ShowTracer = v end})
VisualsTab:CreateToggle({Name = "Show FOV Ring (part)", CurrentValue = false, Flag = "ShowFOVRing", Callback = function(v) State.ShowFOVRing = v end})
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
SkillTab:CreateParagraph({Title = "Method", Content = "Tries Tool Activate first, then VIM, then keypress. First success wins."})

SettingsTab:CreateToggle({Name = "Anti-Cheat Bypass", CurrentValue = true, Flag = "AntiCheatBypass", Callback = function(v) State.AntiCheatBypass = v end})
SettingsTab:CreateParagraph({Title = "Hook", Content = hookInstalled and "installed" or "blocked by executor"})

task.spawn(function()
    while task.wait(3) do
        pcall(function() manualDrop:SetOptions(getPlayerList()) end)
    end
end)

-- MAIN LOOP
RunService.RenderStepped:Connect(function()
    local activeTarget = getClosestTarget(
        State.AimlockRange, State.ShowFOVRing, State.FOVSize,
        State.TargetLowestHP, State.AimlockTarget,
        State.AimlockPlayers, State.AimlockNPC
    )

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

    if State.ShowHitbox and activeTarget then
        local root = activeTarget:FindFirstChild("HumanoidRootPart")
        if root then
            hitboxPart.CFrame = root.CFrame
            hitboxPart.Size = root.Size
            hitboxPart.Transparency = 0.5
        end
    else
        hitboxPart.Transparency = 1
    end

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

    if State.ShowTracer and activeTarget then
        local root = activeTarget:FindFirstChild("HumanoidRootPart")
            or activeTarget:FindFirstChild("Torso")
            or activeTarget:FindFirstChild("UpperTorso")
        if root then
            local camPos = Camera.CFrame.Position + Camera.CFrame.LookVector * 2
            tracerPart0.CFrame = CFrame.new(camPos)
            tracerPart1.CFrame = CFrame.new(root.Position)
            tracerBeam.Enabled = true
        end
    else
        tracerBeam.Enabled = false
    end

    if State.ShowFOVRing then
        local worldSize = State.FOVSize / 100
        fovPart.CFrame = Camera.CFrame * CFrame.new(0, 0, -3) * CFrame.Angles(0, 0, math.rad(90))
        fovPart.Size = Vector3.new(0.05, worldSize, worldSize)
        fovPart.Transparency = 0.7
    else
        fovPart.Transparency = 1
    end
end)

LocalPlayer.CharacterRemoving:Connect(function(c) restoreHitbox(c) end)

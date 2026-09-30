-- Blox Fruits Aimbot / Silent Aim | Rayfield Menu
-- [Ghaith] for WVERZNXRL

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
local CommF_ = Remotes and Remotes:WaitForChild("CommF_", 10)

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

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
    HighlightTarget = false,
    ShowTracer = false,
    ShowFOVRing = false,
    FOVSize = 200,
    ManualTargetEnabled = false,
    ManualTargetPlayer = "None",
    HitboxEnabled = false,
    HitboxSize = 5,
    ShowHitbox = false,
}

local Highlight = nil
local Tracer = nil
local FOVCircle = nil
local HitboxBox = nil

if Drawing then
    Tracer = Drawing.new("Line")
    Tracer.Visible = false
    Tracer.Color = Color3.fromRGB(255, 0, 0)
    Tracer.Thickness = 1
    Tracer.Transparency = 1

    FOVCircle = Drawing.new("Circle")
    FOVCircle.Visible = false
    FOVCircle.Color = Color3.fromRGB(255, 255, 255)
    FOVCircle.Thickness = 1
    FOVCircle.Radius = State.FOVSize
    FOVCircle.Filled = false
    FOVCircle.Transparency = 1

    HitboxBox = Drawing.new("Square")
    HitboxBox.Visible = false
    HitboxBox.Color = Color3.fromRGB(0, 255, 255)
    HitboxBox.Thickness = 1
    HitboxBox.Filled = false
    HitboxBox.Transparency = 1
end

-- all body parts we expand. Blox Fruits hit detection reads these, not just root.
local HITBOX_PARTS = {
    "HumanoidRootPart",
    "Head",
    "UpperTorso", "LowerTorso", "Torso",
    "LeftUpperArm", "RightUpperArm",
    "LeftLowerArm", "RightLowerArm",
    "LeftHand", "RightHand",
    "LeftUpperLeg", "RightUpperLeg",
    "LeftLowerLeg", "RightLowerLeg",
    "LeftFoot", "RightFoot",
}

-- [character] = { parts = { [part] = { size, canCollide, massless } } }
local modifiedHitboxes = {}

local function isAlive(plr)
    return plr.Character and plr.Character:FindFirstChild("Humanoid") and plr.Character.Humanoid.Health > 0
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
    local enemiesFolder = Workspace:FindFirstChild("Enemies")
    if enemiesFolder then
        for _, npc in ipairs(enemiesFolder:GetChildren()) do
            if npc:IsA("Model") and npc:FindFirstChild("Humanoid") and npc.Humanoid.Health > 0 then
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

local function predictPosition(target, predictionAmount)
    local root = target:FindFirstChild("HumanoidRootPart") or target:FindFirstChild("Torso") or target:FindFirstChild("UpperTorso")
    if not root then return target.Position end
    return root.Position + root.Velocity * predictionAmount
end

local function getClosestTarget(range, checkFOV, fovSize, targetLowestHP, specificTarget, includePlayers, includeNPCs)
    if State.ManualTargetEnabled and State.ManualTargetPlayer ~= "None" then
        local plr = Players:FindFirstChild(State.ManualTargetPlayer)
        if plr and plr ~= LocalPlayer and isAlive(plr) then
            local root = plr.Character:FindFirstChild("HumanoidRootPart") or plr.Character:FindFirstChild("Torso") or plr.Character:FindFirstChild("UpperTorso")
            if root then
                local worldDist = (Camera.CFrame.Position - root.Position).Magnitude
                if worldDist <= range then
                    return plr.Character
                end
            end
        end
        return nil
    end

    local targets = getTargets(includePlayers, includeNPCs)
    local closest = nil
    local closestDist = range or math.huge
    local mousePos = UserInputService:GetMouseLocation()
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

    for _, target in ipairs(targets) do
        if not (specificTarget and specificTarget ~= "None" and target.Name ~= specificTarget) then
            local root = target:FindFirstChild("HumanoidRootPart") or target:FindFirstChild("Torso") or target:FindFirstChild("UpperTorso")
            if root then
                local pos = root.Position
                local screenPos, onScreen = Camera:WorldToViewportPoint(pos)
                if onScreen then
                    local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                    local passFOV = true
                    if checkFOV then
                        local fovDist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
                        if fovDist > fovSize then passFOV = false end
                    end
                    if passFOV then
                        local worldDist = (Camera.CFrame.Position - pos).Magnitude
                        if worldDist <= range then
                            if targetLowestHP then
                                local humanoid = target:FindFirstChild("Humanoid")
                                if humanoid then
                                    if closest then
                                        local ch = closest:FindFirstChild("Humanoid")
                                        if ch and humanoid.Health >= ch.Health then
                                            -- skip
                                        else
                                            closest = target
                                            closestDist = worldDist
                                        end
                                    else
                                        closest = target
                                        closestDist = worldDist
                                    end
                                end
                            else
                                if dist < closestDist then
                                    closest = target
                                    closestDist = dist
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
-- expands ALL body parts, stores originals per part, re-applies every frame
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

-- returns characters hitbox should apply to — independent of aimlock toggles
local function getHitboxTargets()
    local targets = {}
    if State.ManualTargetEnabled and State.ManualTargetPlayer ~= "None" then
        local plr = Players:FindFirstChild(State.ManualTargetPlayer)
        if plr and plr ~= LocalPlayer and isAlive(plr) then
            table.insert(targets, plr.Character)
        end
        return targets
    end
    -- all alive players within range
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and isAlive(plr) then
            local root = plr.Character:FindFirstChild("HumanoidRootPart")
            if root then
                local d = (Camera.CFrame.Position - root.Position).Magnitude
                if d <= State.AimlockRange then
                    table.insert(targets, plr.Character)
                end
            end
        end
    end
    -- npcs if aimlock NPC is on
    if State.AimlockNPC then
        for _, npc in ipairs(getNPCs()) do
            table.insert(targets, npc)
        end
    end
    return targets
end

-- ═══ SILENT AIM HOOK ═══
if CommF_ then
    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        if self == CommF_ and method == "FireServer" then
            local args = {...}
            if State.SilentAimPlayers or State.SilentAimNPC or (State.ManualTargetEnabled and State.ManualTargetPlayer ~= "None") then
                local target = getClosestTarget(State.SilentAimRange, false, 0, false, State.SilentLockTarget, State.SilentAimPlayers, State.SilentAimNPC)
                if target then
                    local root = target:FindFirstChild("HumanoidRootPart") or target:FindFirstChild("Torso") or target:FindFirstChild("UpperTorso")
                    if root then
                        local aimPos = root.Position
                        if State.SAPrediction then
                            aimPos = predictPosition(target, State.SAPredictionAmount)
                        end
                        for i, v in ipairs(args) do
                            if typeof(v) == "CFrame" then
                                args[i] = CFrame.new(v.Position, aimPos)
                            elseif typeof(v) == "Vector3" then
                                args[i] = aimPos
                            end
                        end
                    end
                end
            end
            return oldNamecall(self, table.unpack(args))
        end
        return oldNamecall(self, ...)
    end)
end

-- ═══ RAYFIELD UI ═══
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
    local enemies = Workspace:FindFirstChild("Enemies")
    if enemies then
        for _, npc in ipairs(enemies:GetChildren()) do
            if npc:IsA("Model") then
                table.insert(list, npc.Name)
            end
        end
    end
    return list
end

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

SilentTab:CreateToggle({Name = "Silent Aim Players", CurrentValue = false, Flag = "SilentAimPlayers", Callback = function(v) State.SilentAimPlayers = v end})
SilentTab:CreateToggle({Name = "Silent Aim NPC", CurrentValue = false, Flag = "SilentAimNPC", Callback = function(v) State.SilentAimNPC = v end})
SilentTab:CreateSlider({Name = "SA Range (independent)", Range = {0, 2000}, Increment = 10, Suffix = " studs", CurrentValue = 1000, Flag = "SilentAimRange", Callback = function(v) State.SilentAimRange = v end})
SilentTab:CreateToggle({Name = "SA Prediction", CurrentValue = false, Flag = "SAPrediction", Callback = function(v) State.SAPrediction = v end})
SilentTab:CreateSlider({Name = "SA Prediction Amount", Range = {0, 1}, Increment = 0.01, CurrentValue = 0.2, Flag = "SAPredictionAmount", Callback = function(v) State.SAPredictionAmount = v end})
SilentTab:CreateDropdown({Name = "Silent Lock Target", Options = updateTargetList(), CurrentOption = "None", Flag = "SilentLockTarget", Callback = function(v) State.SilentLockTarget = v[1] end})

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

SkillTab:CreateToggle({Name = "Skill Routing", CurrentValue = false, Flag = "SkillRouting", Callback = function(v) State.SkillRouting = v end})

task.spawn(function()
    while task.wait(3) do
        manualTargetDropdown:SetOptions(getPlayerList())
    end
end)

-- ═══ MAIN LOOP ═══
RunService.RenderStepped:Connect(function()
    -- current aim target (for aimlock / highlight / tracer)
    local activeTarget = getClosestTarget(
        State.AimlockRange, State.ShowFOVRing, State.FOVSize,
        State.TargetLowestHP, State.AimlockTarget,
        State.AimlockPlayers, State.AimlockNPC
    )

    -- AIMLOCK
    if (State.AimlockPlayers or State.AimlockNPC or State.ManualTargetEnabled) and activeTarget then
        local root = activeTarget:FindFirstChild("HumanoidRootPart") or activeTarget:FindFirstChild("Torso") or activeTarget:FindFirstChild("UpperTorso")
        if root then
            local aimPos = root.Position
            if State.AimlockPrediction then
                aimPos = predictPosition(activeTarget, State.PredictionAmount)
            end
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, aimPos)
        end
    end

    -- HITBOX — runs independent of aimlock
    if State.HitboxEnabled then
        local hbTargets = getHitboxTargets()
        local hbSet = {}
        for _, char in ipairs(hbTargets) do
            applyHitbox(char, State.HitboxSize)
            hbSet[char] = true
        end
        -- restore any that dropped out
        for char, _ in pairs(modifiedHitboxes) do
            if not hbSet[char] then
                restoreHitbox(char)
            end
        end
    end

    -- SHOW HITBOX (visual square around active target root)
    if State.ShowHitbox and HitboxBox and activeTarget then
        local root = activeTarget:FindFirstChild("HumanoidRootPart")
        if root then
            local cf = root.CFrame
            local size = root.Size
            local corners = {
                cf * Vector3.new(size.X/2, size.Y/2, size.Z/2),
                cf * Vector3.new(-size.X/2, size.Y/2, size.Z/2),
                cf * Vector3.new(size.X/2, -size.Y/2, size.Z/2),
                cf * Vector3.new(-size.X/2, -size.Y/2, size.Z/2),
                cf * Vector3.new(size.X/2, size.Y/2, -size.Z/2),
                cf * Vector3.new(-size.X/2, size.Y/2, -size.Z/2),
                cf * Vector3.new(size.X/2, -size.Y/2, -size.Z/2),
                cf * Vector3.new(-size.X/2, -size.Y/2, -size.Z/2),
            }
            local minX, minY = math.huge, math.huge
            local maxX, maxY = -math.huge, -math.huge
            for _, corner in ipairs(corners) do
                local sp, onScreen = Camera:WorldToViewportPoint(corner)
                if onScreen then
                    minX = math.min(minX, sp.X)
                    minY = math.min(minY, sp.Y)
                    maxX = math.max(maxX, sp.X)
                    maxY = math.max(maxY, sp.Y)
                end
            end
            if minX < math.huge then
                HitboxBox.Size = Vector2.new(maxX - minX, maxY - minY)
                HitboxBox.Position = Vector2.new(minX, minY)
                HitboxBox.Visible = true
            else
                HitboxBox.Visible = false
            end
        end
    else
        if HitboxBox then HitboxBox.Visible = false end
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
    else
        if Highlight then Highlight:Destroy() Highlight = nil end
    end

    -- TRACER
    if State.ShowTracer and Tracer and activeTarget then
        local root = activeTarget:FindFirstChild("HumanoidRootPart") or activeTarget:FindFirstChild("Torso") or activeTarget:FindFirstChild("UpperTorso")
        if root then
            local screenPos, onScreen = Camera:WorldToViewportPoint(root.Position)
            if onScreen then
                Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                Tracer.To = Vector2.new(screenPos.X, screenPos.Y)
                Tracer.Visible = true
            else
                Tracer.Visible = false
            end
        end
    else
        if Tracer then Tracer.Visible = false end
    end

    -- FOV RING
    if State.ShowFOVRing and FOVCircle then
        FOVCircle.Visible = true
        FOVCircle.Radius = State.FOVSize
        FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    else
        if FOVCircle then FOVCircle.Visible = false end
    end
end)

LocalPlayer.CharacterRemoving:Connect(function(char)
    restoreHitbox(char)
end)

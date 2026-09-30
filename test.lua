-- ==============================================================================
-- SUHO MASTER SUITE v4 — RAYFIELD EDITION
-- Smooth Lerp Collect · Anti-Rubberband · Priority Filter · Dealer Snipe
-- executor: Rayfield-compatible (Delta, Synapse, Xeno, Solara)
-- ==============================================================================

local Rayfield          = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Players           = game:GetService("Players")
local Workspace         = game:GetService("Workspace")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local VirtualUser       = game:GetService("VirtualUser")
local Lighting          = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera
local Remotes     = ReplicatedStorage:WaitForChild("Remotes", 5)
local CommF       = Remotes and Remotes:FindFirstChild("CommF_")

-- ==============================================================================
-- 1. CONFIGURATION
-- ==============================================================================
local Config = {
    -- Fruits
    FruitESP        = true,
    AutoCollect     = false,
    AutoStore       = true,
    TravelSpeed     = 160,
    TargetFruits    = {},
    PriorityCollect = true,

    -- Auto-Clicker & Skills
    AutoClicker     = false,
    ClickDelay      = 0.05,
    AutoSkillZ      = false,
    AutoSkillX      = false,
    AutoSkillC      = false,
    AutoSkillV      = false,

    -- Movement
    SpeedBypass     = false,
    TargetSpeed     = 60,
    NoClip          = false,
    WaterLavaWalk   = false,
    Fly             = false,
    FlySpeed        = 70,
    InfJump         = false,

    -- Visuals
    PlayerESP       = false,
    FullBright      = false,
}

local EspFruitObjects  = {}
local EspPlayerObjects = {}
local IsCollecting     = false
local IsStoring        = false
local WaterPlatform    = nil
local FlightGyro, FlightVelocity = nil, nil
local JumpConn         = nil

local TIER_RANK = { MYTHICAL = 5, LEGENDARY = 4, RARE = 3, UNCOMMON = 2, COMMON = 1 }

-- ==============================================================================
-- 2. FRUIT DATABASE
-- ==============================================================================
local FruitDatabase = {
    ["Rocket-Rocket"]       = { Tier = "COMMON",    Color = Color3.fromRGB(180, 180, 180), Name = "Rocket",    Aliases = {"rocket", "kilo"} },
    ["Spin-Spin"]           = { Tier = "COMMON",    Color = Color3.fromRGB(180, 180, 180), Name = "Spin",      Aliases = {"spin"} },
    ["Blade-Blade"]         = { Tier = "COMMON",    Color = Color3.fromRGB(180, 180, 180), Name = "Blade",     Aliases = {"blade", "chop"} },
    ["Spring-Spring"]       = { Tier = "COMMON",    Color = Color3.fromRGB(180, 180, 180), Name = "Spring",    Aliases = {"spring"} },
    ["Bomb-Bomb"]           = { Tier = "COMMON",    Color = Color3.fromRGB(180, 180, 180), Name = "Bomb",      Aliases = {"bomb"} },
    ["Smoke-Smoke"]         = { Tier = "COMMON",    Color = Color3.fromRGB(180, 180, 180), Name = "Smoke",     Aliases = {"smoke"} },
    ["Spike-Spike"]         = { Tier = "COMMON",    Color = Color3.fromRGB(180, 180, 180), Name = "Spike",     Aliases = {"spike"} },
    ["Flame-Flame"]         = { Tier = "UNCOMMON",  Color = Color3.fromRGB(255, 130, 40),  Name = "Flame",     Aliases = {"flame", "fire", "mera"} },
    ["Eagle-Eagle"]         = { Tier = "UNCOMMON",  Color = Color3.fromRGB(120, 180, 255), Name = "Falcon",    Aliases = {"falcon", "eagle"} },
    ["Ice-Ice"]             = { Tier = "UNCOMMON",  Color = Color3.fromRGB(90, 230, 120),  Name = "Ice",       Aliases = {"ice", "hie"} },
    ["Sand-Sand"]           = { Tier = "UNCOMMON",  Color = Color3.fromRGB(220, 190, 110), Name = "Sand",      Aliases = {"sand", "suna"} },
    ["Dark-Dark"]           = { Tier = "UNCOMMON",  Color = Color3.fromRGB(100, 70, 140),  Name = "Dark",      Aliases = {"dark", "yami"} },
    ["Diamond-Diamond"]     = { Tier = "UNCOMMON",  Color = Color3.fromRGB(120, 220, 255), Name = "Diamond",   Aliases = {"diamond"} },
    ["Light-Light"]         = { Tier = "RARE",      Color = Color3.fromRGB(255, 235, 70),  Name = "Light",     Aliases = {"light", "pika"} },
    ["Rubber-Rubber"]       = { Tier = "RARE",      Color = Color3.fromRGB(120, 180, 255), Name = "Rubber",    Aliases = {"rubber", "gomu"} },
    ["Ghost-Ghost"]         = { Tier = "RARE",      Color = Color3.fromRGB(100, 210, 255), Name = "Ghost",     Aliases = {"ghost", "revive"} },
    ["Magma-Magma"]         = { Tier = "RARE",      Color = Color3.fromRGB(255, 85, 20),   Name = "Magma",     Aliases = {"magma", "magu"} },
    ["Creation-Creation"]   = { Tier = "LEGENDARY", Color = Color3.fromRGB(180, 70, 255),  Name = "Barrier",   Aliases = {"barrier", "creation"} },
    ["Quake-Quake"]         = { Tier = "LEGENDARY", Color = Color3.fromRGB(180, 70, 255),  Name = "Quake",     Aliases = {"quake", "gura"} },
    ["Buddha-Buddha"]       = { Tier = "LEGENDARY", Color = Color3.fromRGB(245, 200, 50),  Name = "Buddha",    Aliases = {"buddha", "daibutsu", "human"} },
    ["Love-Love"]           = { Tier = "LEGENDARY", Color = Color3.fromRGB(255, 130, 200), Name = "Love",      Aliases = {"love", "mero"} },
    ["Spider-Spider"]       = { Tier = "LEGENDARY", Color = Color3.fromRGB(180, 70, 255),  Name = "Spider",    Aliases = {"spider", "string", "ito"} },
    ["Sound-Sound"]         = { Tier = "LEGENDARY", Color = Color3.fromRGB(180, 70, 255),  Name = "Sound",     Aliases = {"sound", "oto"} },
    ["Phoenix-Phoenix"]     = { Tier = "LEGENDARY", Color = Color3.fromRGB(100, 230, 210), Name = "Phoenix",   Aliases = {"phoenix", "tori"} },
    ["Portal-Portal"]       = { Tier = "LEGENDARY", Color = Color3.fromRGB(70, 170, 255),  Name = "Portal",    Aliases = {"portal", "door"} },
    ["Lightning-Lightning"] = { Tier = "LEGENDARY", Color = Color3.fromRGB(120, 210, 255), Name = "Rumble",    Aliases = {"rumble", "lightning", "goro"} },
    ["Pain-Pain"]           = { Tier = "LEGENDARY", Color = Color3.fromRGB(180, 70, 255),  Name = "Pain",      Aliases = {"pain", "paw", "nikyu"} },
    ["Blizzard-Blizzard"]   = { Tier = "LEGENDARY", Color = Color3.fromRGB(140, 220, 255), Name = "Blizzard",  Aliases = {"blizzard", "snow", "yuki"} },
    ["Gravity-Gravity"]     = { Tier = "MYTHICAL",  Color = Color3.fromRGB(130, 60, 200),  Name = "Gravity",   Aliases = {"gravity", "zushi"} },
    ["Mammoth-Mammoth"]     = { Tier = "MYTHICAL",  Color = Color3.fromRGB(160, 90, 50),   Name = "Mammoth",   Aliases = {"mammoth", "zou"} },
    ["T-Rex-T-Rex"]         = { Tier = "MYTHICAL",  Color = Color3.fromRGB(210, 70, 50),   Name = "T-Rex",     Aliases = {"trex", "t-rex", "t_rex"} },
    ["Dough-Dough"]         = { Tier = "MYTHICAL",  Color = Color3.fromRGB(245, 215, 170), Name = "Dough",     Aliases = {"dough", "mochi"} },
    ["Shadow-Shadow"]       = { Tier = "MYTHICAL",  Color = Color3.fromRGB(150, 70, 200),  Name = "Shadow",    Aliases = {"shadow", "kage"} },
    ["Venom-Venom"]         = { Tier = "MYTHICAL",  Color = Color3.fromRGB(200, 60, 255),  Name = "Venom",     Aliases = {"venom", "doku"} },
    ["Control-Control"]     = { Tier = "MYTHICAL",  Color = Color3.fromRGB(255, 80, 80),   Name = "Control",   Aliases = {"control", "ope"} },
    ["Gas-Gas"]             = { Tier = "MYTHICAL",  Color = Color3.fromRGB(255, 75, 75),   Name = "Gas",       Aliases = {"gas", "gasu"} },
    ["Spirit-Spirit"]       = { Tier = "MYTHICAL",  Color = Color3.fromRGB(255, 90, 90),   Name = "Spirit",    Aliases = {"spirit", "soul", "soru"} },
    ["Yeti-Yeti"]           = { Tier = "MYTHICAL",  Color = Color3.fromRGB(200, 230, 255), Name = "Yeti",      Aliases = {"yeti"} },
    ["Tiger-Tiger"]         = { Tier = "MYTHICAL",  Color = Color3.fromRGB(255, 140, 40),  Name = "Tiger",     Aliases = {"tiger"} },
    ["Kitsune-Kitsune"]     = { Tier = "MYTHICAL",  Color = Color3.fromRGB(255, 60, 60),   Name = "Kitsune",   Aliases = {"kitsune", "fox"} },
    ["Magnet-Magnet"]       = { Tier = "MYTHICAL",  Color = Color3.fromRGB(255, 80, 80),   Name = "Magnet",    Aliases = {"magnet", "jiki"} },
    ["Dragon-Dragon"]       = { Tier = "MYTHICAL",  Color = Color3.fromRGB(255, 50, 50),   Name = "Dragon",    Aliases = {"dragon", "ryu", "dragoneast", "dragonwest"} },
}

-- ==============================================================================
-- 3. HELPERS
-- ==============================================================================
local function cleanKeyword(s)
    if typeof(s) ~= "string" then return "" end
    return s:lower():gsub("/", ""):gsub("%-%-", ""):gsub("%-", "_"):gsub("%s", "")
end

local function getRoot(char)
    char = char or LocalPlayer.Character
    return char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
end

local function getHum(char)
    char = char or LocalPlayer.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function isRealGroundFruit(inst)
    if not inst or not inst.Parent or not inst:IsDescendantOf(Workspace) then return nil end
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character and inst:IsDescendantOf(p.Character) then return nil end
        if p:FindFirstChild("Backpack") and inst:IsDescendantOf(p.Backpack) then return nil end
    end
    local path = string.lower(inst:GetFullName())
    if path:find("map") or path:find("island") or path:find("bush") or path:find("tree")
       or path:find("npc") or path:find("enemy") or path:find("house") then return nil end
    local name = string.lower(inst.Name)
    local isFruitContainer = inst:IsA("Tool") or inst:IsA("Model")
    if isFruitContainer and (name:find("fruit") or name:find("%-") or name:find("_") or name == "") then
        local primary = inst:FindFirstChild("Handle")
            or inst:FindFirstChildWhichIsA("MeshPart")
            or inst:FindFirstChildWhichIsA("BasePart")
        if primary and primary:IsA("BasePart") and primary.Transparency < 0.95 then
            if primary.Position.Y > -400 and primary.Position.Y < 4000 and primary.Size.Magnitude < 14 then
                return primary
            end
        end
    end
    return nil
end

local function identifyFruit(inst, handle)
    local pool = { inst.Name, handle and handle.Name or "" }
    pcall(function()
        for _, desc in ipairs(inst:GetDescendants()) do
            if desc:IsA("StringValue") and desc.Value ~= "" then
                table.insert(pool, desc.Value)
            elseif desc:IsA("SpecialMesh") then
                table.insert(pool, tostring(desc.MeshId))
                table.insert(pool, tostring(desc.TextureId))
            elseif desc:IsA("MeshPart") then
                table.insert(pool, tostring(desc.MeshId))
                table.insert(pool, tostring(desc.TextureID))
            end
        end
    end)
    for _, rawStr in ipairs(pool) do
        local cleaned = cleanKeyword(rawStr)
        if cleaned ~= "" and cleaned ~= "fruit" and cleaned ~= "handle" then
            for storeKey, data in pairs(FruitDatabase) do
                local baseKey  = cleanKeyword(storeKey)
                local baseName = cleanKeyword(data.Name)
                if cleaned:find(baseKey) or cleaned:find(baseName) then
                    return data.Name .. " Fruit", data.Tier, data.Color, storeKey
                end
                if data.Aliases then
                    for _, alias in ipairs(data.Aliases) do
                        if cleaned:find(cleanKeyword(alias)) then
                            return data.Name .. " Fruit", data.Tier, data.Color, storeKey
                        end
                    end
                end
            end
        end
    end
    if handle and handle:IsA("BasePart") then
        local c = handle.Color
        if (c.R > 0.65 and c.G > 0.50 and c.B < 0.40) or (handle.Material == Enum.Material.Neon and c.R > 0.6 and c.G > 0.5) then
            return "Light Fruit", "RARE", Color3.fromRGB(255, 235, 70), "Light-Light"
        elseif c.B > 0.7 and c.G > 0.6 and c.R < 0.5 then
            return "Ice Fruit", "UNCOMMON", Color3.fromRGB(90, 230, 120), "Ice-Ice"
        elseif c.R > 0.8 and c.G > 0.3 and c.B < 0.25 then
            return "Flame Fruit", "UNCOMMON", Color3.fromRGB(255, 130, 40), "Flame-Flame"
        end
    end
    return "Ground Fruit", "COMMON", Color3.fromRGB(220, 220, 220), "Fruit"
end

-- ==============================================================================
-- 4. STORE LOGIC
-- ==============================================================================
local function storeInventoryFruit(tool)
    if not Config.AutoStore or not tool or not CommF or IsStoring then return end
    IsStoring = true
    task.spawn(function()
        local char = LocalPlayer.Character
        local hum  = getHum(char)
        if not char or not hum then IsStoring = false return end
        local handle = tool:FindFirstChild("Handle") or tool:FindFirstChildWhichIsA("BasePart")
        local _, _, _, storeKey = identifyFruit(tool, handle)
        if tool.Parent ~= char then
            hum:EquipTool(tool)
            task.wait(0.2)
        end
        pcall(function() CommF:InvokeServer("StoreFruit", storeKey, tool) end)
        task.wait(0.15)
        pcall(function() hum:UnequipTools() end)
        IsStoring = false
    end)
end

-- ==============================================================================
-- 5. SMOOTH LERP COLLECTOR
-- ==============================================================================
local function smoothTravelCollect(handlePart, fruitObj)
    if IsCollecting then return end
    local char = LocalPlayer.Character
    local root = getRoot(char)
    local hum  = getHum(char)
    if not char or not root or not hum then return end

    IsCollecting = true

    local prevCollide = {}
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            prevCollide[part] = part.CanCollide
            part.CanCollide = false
        end
    end

    local bodyVel = Instance.new("BodyVelocity")
    bodyVel.velocity  = Vector3.zero
    bodyVel.maxForce  = Vector3.new(9e9, 9e9, 9e9)
    bodyVel.Parent    = root

    local bodyGyro = Instance.new("BodyGyro")
    bodyGyro.maxTorque = Vector3.new(9e9, 9e9, 9e9)
    bodyGyro.P         = 9e4
    bodyGyro.cframe    = root.CFrame
    bodyGyro.Parent    = root

    local timeout = tick() + 15
    while fruitObj:IsDescendantOf(Workspace) and handlePart.Parent and tick() < timeout do
        local currentPos = root.Position
        local targetPos  = handlePart.Position + Vector3.new(0, 1, 0)
        local dist       = (targetPos - currentPos).Magnitude
        if dist <= 3.5 then break end

        local travelStep = math.min(dist, (Config.TravelSpeed / 60))
        local nextPos    = currentPos + ((targetPos - currentPos).Unit * travelStep)
        root.CFrame      = CFrame.new(nextPos, targetPos)
        bodyGyro.cframe  = CFrame.new(nextPos, targetPos)
        bodyVel.velocity = Vector3.zero

        for part, _ in pairs(prevCollide) do
            if part.Parent then part.CanCollide = false end
        end
        RunService.Heartbeat:Wait()
    end

    for _ = 1, 10 do
        if not fruitObj:IsDescendantOf(Workspace) then break end
        root.CFrame = handlePart.CFrame
        for _, desc in ipairs(fruitObj:GetDescendants()) do
            if desc:IsA("ProximityPrompt") then
                if fireproximityprompt then
                    fireproximityprompt(desc)
                else
                    desc:InputHoldBegin()
                    task.wait(desc.HoldDuration + 0.05)
                    desc:InputHoldEnd()
                end
            end
        end
        if firetouchinterest then
            pcall(function()
                firetouchinterest(root, handlePart, 0)
                task.wait(0.02)
                firetouchinterest(root, handlePart, 1)
            end)
        end
        task.wait(0.08)
    end

    if bodyVel  then bodyVel:Destroy()  end
    if bodyGyro then bodyGyro:Destroy() end
    for part, state in pairs(prevCollide) do
        if part.Parent then part.CanCollide = state end
    end
    task.wait(0.2)

    if Config.AutoStore then
        for _, loc in ipairs({LocalPlayer.Character, LocalPlayer.Backpack}) do
            if loc then
                for _, item in ipairs(loc:GetChildren()) do
                    if item:IsA("Tool") and (item.Name:lower():find("fruit") or item.Name:find("%-")) then
                        storeInventoryFruit(item)
                    end
                end
            end
        end
    end

    IsCollecting = false
end

-- ==============================================================================
-- 6. TARGET SELECTION (PRIORITY + FILTER)
-- ==============================================================================
local function fruitPassesFilter(fruitData)
    if #Config.TargetFruits == 0 then return true end
    for _, wanted in ipairs(Config.TargetFruits) do
        if string.find(fruitData.Name, wanted, 1, true) then return true end
    end
    return false
end

local function selectCollectTarget(groundFruits, myPos)
    local best, bestScore = nil, -math.huge
    for _, f in ipairs(groundFruits) do
        if not fruitPassesFilter(f) then continue end
        local dist = (myPos - f.Handle.Position).Magnitude
        local score
        if Config.PriorityCollect then
            score = (TIER_RANK[f.Tier] or 1) * 1000 - dist
        else
            score = -dist
        end
        if score > bestScore then best, bestScore = f, score end
    end
    return best
end

-- ==============================================================================
-- 7. COMBAT LOOPS
-- ==============================================================================
task.spawn(function()
    while true do
        if Config.AutoClicker and LocalPlayer.Character then
            pcall(function()
                VirtualUser:Button1Down(Vector2.new(0, 0), Workspace.CurrentCamera.CFrame)
                task.wait(0.01)
                VirtualUser:Button1Up(Vector2.new(0, 0), Workspace.CurrentCamera.CFrame)
            end)
            pcall(function()
                if CommF then CommF:InvokeServer("Attack", Vector3.zero) end
            end)
        end
        task.wait(math.clamp(Config.ClickDelay, 0.01, 1))
    end
end)

task.spawn(function()
    while true do
        if LocalPlayer.Character then
            local char = LocalPlayer.Character
            local tool = char:FindFirstChildOfClass("Tool")
            if tool then
                if Config.AutoSkillZ then VirtualUser:SetKeyDown("z"); task.wait(0.05); VirtualUser:SetKeyUp("z") end
                if Config.AutoSkillX then VirtualUser:SetKeyDown("x"); task.wait(0.05); VirtualUser:SetKeyUp("x") end
                if Config.AutoSkillC then VirtualUser:SetKeyDown("c"); task.wait(0.05); VirtualUser:SetKeyUp("c") end
                if Config.AutoSkillV then VirtualUser:SetKeyDown("v"); task.wait(0.05); VirtualUser:SetKeyUp("v") end
            end
        end
        task.wait(0.3)
    end
end)

-- ==============================================================================
-- 8. MOVEMENT LOOPS
-- ==============================================================================
RunService.Heartbeat:Connect(function()
    if not Config.SpeedBypass then return end
    local root = getRoot()
    local hum  = getHum()
    if not root or not hum then return end
    local moveDir = hum.MoveDirection
    if moveDir.Magnitude > 0 then
        root.AssemblyLinearVelocity = Vector3.new(
            moveDir.X * Config.TargetSpeed,
            root.AssemblyLinearVelocity.Y,
            moveDir.Z * Config.TargetSpeed
        )
    end
end)

RunService.Stepped:Connect(function()
    local char = LocalPlayer.Character
    if not char then return end
    local hum  = getHum(char)
    local root = getRoot(char)

    if Config.WaterLavaWalk and hum and root then
        if hum:GetState() == Enum.HumanoidStateType.Swimming then
            hum:SetStateEnabled(Enum.HumanoidStateType.Swimming, false)
            hum:ChangeState(Enum.HumanoidStateType.RunningNoPhysics)
        end
        if not WaterPlatform or not WaterPlatform.Parent then
            WaterPlatform = Instance.new("Part")
            WaterPlatform.Name        = "OceanLavaBarrier"
            WaterPlatform.Size        = Vector3.new(18, 1.2, 18)
            WaterPlatform.Transparency = 1
            WaterPlatform.Anchored    = true
            WaterPlatform.CanCollide  = true
            WaterPlatform.Material    = Enum.Material.SmoothPlastic
            WaterPlatform.Parent      = Workspace
        end
        local targetY = math.max(-1.5, root.Position.Y - 3.25)
        WaterPlatform.CFrame = CFrame.new(root.Position.X, targetY, root.Position.Z)
    else
        if WaterPlatform then WaterPlatform:Destroy(); WaterPlatform = nil end
        if hum then hum:SetStateEnabled(Enum.HumanoidStateType.Swimming, true) end
    end

    if Config.NoClip then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end
        end
    end
end)

local function setFlight(state)
    Config.Fly = state
    local root = getRoot()
    local hum  = getHum()
    if not state then
        if FlightGyro     then FlightGyro:Destroy();     FlightGyro = nil     end
        if FlightVelocity then FlightVelocity:Destroy(); FlightVelocity = nil end
        if hum then hum.PlatformStand = false end
        return
    end
    if not root or not hum then return end
    hum.PlatformStand = true

    FlightGyro = Instance.new("BodyGyro")
    FlightGyro.P         = 9e4
    FlightGyro.maxTorque = Vector3.new(9e9, 9e9, 9e9)
    FlightGyro.cframe    = root.CFrame
    FlightGyro.Parent    = root

    FlightVelocity = Instance.new("BodyVelocity")
    FlightVelocity.velocity = Vector3.zero
    FlightVelocity.maxForce = Vector3.new(9e9, 9e9, 9e9)
    FlightVelocity.Parent   = root

    task.spawn(function()
        while Config.Fly and root and hum do
            local moveDir = hum.MoveDirection
            local forward = Camera.CFrame.LookVector
            local right   = Camera.CFrame.RightVector
            local targetVel = Vector3.zero
            if moveDir.Magnitude > 0 then
                targetVel = (forward * (moveDir:Dot(forward) * Config.FlySpeed))
                          + (right   * (moveDir:Dot(right)   * Config.FlySpeed))
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                targetVel = targetVel + Vector3.new(0, Config.FlySpeed, 0)
            elseif UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                targetVel = targetVel - Vector3.new(0, Config.FlySpeed, 0)
            end
            FlightVelocity.velocity = targetVel
            FlightGyro.cframe       = Camera.CFrame
            RunService.RenderStepped:Wait()
        end
    end)
end

local function setInfJump(state)
    Config.InfJump = state
    if JumpConn then JumpConn:Disconnect(); JumpConn = nil end
    if state then
        JumpConn = UserInputService.JumpRequest:Connect(function()
            local hum = getHum()
            if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
        end)
    end
end

-- ==============================================================================
-- 9. DEALER / SHOP HELPERS
-- ==============================================================================
local function getNextRestock(isAdvanced)
    local interval = isAdvanced and 7200 or 14400
    local now    = DateTime.now().UnixTimestamp
    local target = now - (now % interval) + interval
    local remaining = math.max(0, target - now)
    local hours = math.floor(remaining / 3600)
    local mins  = math.floor((remaining % 3600) / 60)
    local secs  = remaining % 60
    return string.format("%02d:%02d:%02d", hours, mins, secs)
end

local function fetchStock(isAdvanced)
    if not CommF then return {} end
    local ok, stock = pcall(function() return CommF:InvokeServer("GetFruits", isAdvanced) end)
    if ok and typeof(stock) == "table" then return stock end
    return {}
end

local function buyFruitWithBeli(fruitName)
    if not CommF then return end
    task.spawn(function()
        local ok, res = pcall(function() return CommF:InvokeServer("BuyFruit", fruitName) end)
        print("[SHOP] BuyFruit ->", fruitName, tostring(ok), tostring(res))
    end)
end

-- ==============================================================================
-- 10. RAYFIELD UI
-- ==============================================================================
local Window = Rayfield:CreateWindow({
    Name = "SUHO MASTER SUITE v4",
    LoadingTitle = "loading the gift",
    LoadingSubtitle = "for WVERZNXRL",
    ConfigurationSaving = { Enabled = true, FolderName = "SuhoV4", FileName = "config" },
    KeySystem = false,
})

-- ---------- TAB: FRUITS ----------
local FruitTab = Window:CreateTab("Fruits", 4483362458)
FruitTab:CreateSection("Ground Fruits")

FruitTab:CreateToggle({
    Name = "Ground Fruit ESP",
    CurrentValue = Config.FruitESP,
    Flag = "FruitESP",
    Callback = function(v)
        Config.FruitESP = v
        for _, d in pairs(EspFruitObjects) do if d.Gui then d.Gui.Enabled = v end end
    end,
})

FruitTab:CreateToggle({
    Name = "Smooth Auto-Collect (Anti-Rubberband)",
    CurrentValue = Config.AutoCollect,
    Flag = "AutoCollect",
    Callback = function(v) Config.AutoCollect = v end,
})

FruitTab:CreateToggle({
    Name = "Auto-Store Inventory",
    CurrentValue = Config.AutoStore,
    Flag = "AutoStore",
    Callback = function(v) Config.AutoStore = v end,
})

FruitTab:CreateSlider({
    Name = "Collect Speed",
    Range = {50, 300},
    Increment = 10,
    Suffix = "studs/s",
    CurrentValue = Config.TravelSpeed,
    Flag = "TravelSpeed",
    Callback = function(v) Config.TravelSpeed = v end,
})

FruitTab:CreateToggle({
    Name = "Priority Collect (Mythical > Common)",
    CurrentValue = Config.PriorityCollect,
    Flag = "PriorityCollect",
    Callback = function(v) Config.PriorityCollect = v end,
})

-- ---------- TAB: TARGET FILTER ----------
local FilterTab = Window:CreateTab("Target Filter", 4483362458)
FilterTab:CreateSection("Only collect selected fruits")
FilterTab:CreateParagraph({
    Title = "How it works",
    Content = "Empty selection = collect everything. Select fruits below to restrict. Priority still applies within selection."
})

local FILTER_LIST = {
    "Rocket","Spin","Blade","Spring","Bomb","Smoke","Spike","Flame","Falcon","Ice",
    "Sand","Dark","Diamond","Light","Rubber","Ghost","Magma","Barrier","Quake","Buddha",
    "Love","Spider","Sound","Phoenix","Portal","Rumble","Pain","Blizzard","Gravity",
    "Mammoth","T-Rex","Dough","Shadow","Venom","Control","Gas","Spirit","Yeti","Tiger",
    "Kitsune","Magnet","Dragon",
}

for _, fruitName in ipairs(FILTER_LIST) do
    FilterTab:CreateToggle({
        Name = fruitName,
        CurrentValue = false,
        Flag = "Filter_" .. fruitName,
        Callback = function(state)
            if state then
                table.insert(Config.TargetFruits, fruitName)
            else
                for i, v in ipairs(Config.TargetFruits) do
                    if v == fruitName then table.remove(Config.TargetFruits, i) break end
                end
            end
        end,
    })
end

FilterTab:CreateButton({
    Name = "Clear All Filters (Collect All)",
    Callback = function()
        Config.TargetFruits = {}
        Rayfield:Notify({ Title = "Filter cleared", Content = "Collecting all fruit tiers again.", Duration = 3 })
    end,
})

-- ---------- TAB: AUTO-CLICKER ----------
local CombatTab = Window:CreateTab("Auto-Clicker", 4483362458)
CombatTab:CreateSection("Combat")

CombatTab:CreateToggle({
    Name = "Fast Auto-Clicker (M1 / Attack)",
    CurrentValue = Config.AutoClicker,
    Flag = "AutoClicker",
    Callback = function(v) Config.AutoClicker = v end,
})

CombatTab:CreateSlider({
    Name = "Click Delay",
    Range = {0.01, 0.5},
    Increment = 0.01,
    Suffix = "s",
    CurrentValue = Config.ClickDelay,
    Flag = "ClickDelay",
    Callback = function(v) Config.ClickDelay = v end,
})

CombatTab:CreateSection("Skills")
CombatTab:CreateToggle({ Name = "Auto Skill [Z]", CurrentValue = Config.AutoSkillZ, Flag = "SkillZ", Callback = function(v) Config.AutoSkillZ = v end })
CombatTab:CreateToggle({ Name = "Auto Skill [X]", CurrentValue = Config.AutoSkillX, Flag = "SkillX", Callback = function(v) Config.AutoSkillX = v end })
CombatTab:CreateToggle({ Name = "Auto Skill [C]", CurrentValue = Config.AutoSkillC, Flag = "SkillC", Callback = function(v) Config.AutoSkillC = v end })
CombatTab:CreateToggle({ Name = "Auto Skill [V]", CurrentValue = Config.AutoSkillV, Flag = "SkillV", Callback = function(v) Config.AutoSkillV = v end })

-- ---------- TAB: FRUIT SHOP ----------
local ShopTab = Window:CreateTab("Fruit Shop", 4483362458)
ShopTab:CreateSection("Dealer Stock")

local RestockLabel = ShopTab:CreateLabel("Dealer: calculating... | Mirage: calculating...")

task.spawn(function()
    while task.wait(1) do
        pcall(function()
            RestockLabel:Set(string.format("Dealer: %s | Mirage: %s", getNextRestock(false), getNextRestock(true)))
        end)
    end
end)

local function renderStockRayfield(isAdvanced)
    local rawStock = fetchStock(isAdvanced)
    local onSale = {}
    for _, item in ipairs(rawStock) do
        if item.OnSale then table.insert(onSale, item) end
    end
    if #onSale == 0 then
        Rayfield:Notify({ Title = "Stock", Content = "No fruits on sale right now.", Duration = 3 })
        return
    end
    local names = {}
    for _, item in ipairs(onSale) do table.insert(names, item.Name) end
    local pick = nil
    ShopTab:CreateDropdown({
        Name = "On Sale (pick to buy)",
        Options = names,
        CurrentOption = {},
        MultipleOptions = false,
        Flag = "StockPick_" .. tostring(isAdvanced),
        Callback = function(opt) pick = opt end,
    })
end

ShopTab:CreateButton({
    Name = "Fetch Normal Dealer Stock",
    Callback = function() renderStockRayfield(false) end,
})
ShopTab:CreateButton({
    Name = "Fetch Mirage Dealer Stock",
    Callback = function() renderStockRayfield(true) end,
})

ShopTab:CreateInput({
    Name = "Buy Fruit by Name (instant get)",
    PlaceholderText = "e.g. Dough-Dough",
    RemoveTextAfterFocusLost = false,
    Callback = function(text)
        if text and text ~= "" then
            buyFruitWithBeli(text)
            Rayfield:Notify({ Title = "Snipe sent", Content = "BuyFruit -> " .. text, Duration = 3 })
        end
    end,
})

ShopTab:CreateButton({
    Name = "Instant Get: Dough",
    Callback = function() buyFruitWithBeli("Dough-Dough") end,
})
ShopTab:CreateButton({
    Name = "Instant Get: Kitsune",
    Callback = function() buyFruitWithBeli("Kitsune-Kitsune") end,
})
ShopTab:CreateButton({
    Name = "Instant Get: Dragon",
    Callback = function() buyFruitWithBeli("Dragon-Dragon") end,
})
ShopTab:CreateButton({
    Name = "Instant Get: Leopard",
    Callback = function() buyFruitWithBeli("Leopard-Leopard") end,
})
ShopTab:CreateButton({
    Name = "Instant Get: Venom",
    Callback = function() buyFruitWithBeli("Venom-Venom") end,
})

-- ---------- TAB: MOVEMENT ----------
local MoveTab = Window:CreateTab("Movement", 4483362458)
MoveTab:CreateSection("Locomotion")

MoveTab:CreateToggle({
    Name = "Fast Speed Propulsion",
    CurrentValue = Config.SpeedBypass,
    Flag = "SpeedBypass",
    Callback = function(v) Config.SpeedBypass = v end,
})
MoveTab:CreateSlider({
    Name = "Speed Value",
    Range = {16, 300},
    Increment = 4,
    Suffix = "studs/s",
    CurrentValue = Config.TargetSpeed,
    Flag = "TargetSpeed",
    Callback = function(v) Config.TargetSpeed = v end,
})
MoveTab:CreateToggle({
    Name = "Water & Lava Walk",
    CurrentValue = Config.WaterLavaWalk,
    Flag = "WaterLavaWalk",
    Callback = function(v)
        Config.WaterLavaWalk = v
        if not v and WaterPlatform then WaterPlatform:Destroy(); WaterPlatform = nil end
    end,
})
MoveTab:CreateToggle({
    Name = "Fast NoClip",
    CurrentValue = Config.NoClip,
    Flag = "NoClip",
    Callback = function(v) Config.NoClip = v end,
})
MoveTab:CreateToggle({
    Name = "6-Axis Flight",
    CurrentValue = Config.Fly,
    Flag = "Fly",
    Callback = function(v) setFlight(v) end,
})
MoveTab:CreateSlider({
    Name = "Flight Speed",
    Range = {30, 300},
    Increment = 10,
    Suffix = "studs/s",
    CurrentValue = Config.FlySpeed,
    Flag = "FlySpeed",
    Callback = function(v) Config.FlySpeed = v end,
})
MoveTab:CreateToggle({
    Name = "Infinite Jump",
    CurrentValue = Config.InfJump,
    Flag = "InfJump",
    Callback = function(v) setInfJump(v) end,
})

-- ---------- TAB: VISUALS ----------
local VisTab = Window:CreateTab("Visuals", 4483362458)
VisTab:CreateSection("Lighting & ESP")

VisTab:CreateToggle({
    Name = "Full Brightness",
    CurrentValue = Config.FullBright,
    Flag = "FullBright",
    Callback = function(v)
        Config.FullBright = v
        if v then
            Lighting.Ambient = Color3.fromRGB(255, 255, 255)
            Lighting.Brightness = 2
            Lighting.ClockTime = 14
            Lighting.FogEnd = 1e5
            Lighting.GlobalShadows = false
        else
            Lighting.Ambient = Color3.fromRGB(128, 128, 128)
            Lighting.Brightness = 1
            Lighting.ClockTime = 14
            Lighting.FogEnd = 1000
            Lighting.GlobalShadows = true
        end
    end,
})

VisTab:CreateToggle({
    Name = "Player ESP",
    CurrentValue = Config.PlayerESP,
    Flag = "PlayerESP",
    Callback = function(v)
        Config.PlayerESP = v
        if not v then
            for _, d in pairs(EspPlayerObjects) do if d.Gui then d.Gui:Destroy() end end
            table.clear(EspPlayerObjects)
        end
    end,
})

-- ==============================================================================
-- 11. SCANNER LOOP (ESP + AUTO-COLLECT)
-- ==============================================================================
task.spawn(function()
    while true do
        local groundFruits = {}
        local activeSet    = {}

        for _, item in ipairs(Workspace:GetDescendants()) do
            local handle = isRealGroundFruit(item)
            if handle then
                activeSet[item] = true
                local name, tier, color, storeKey = identifyFruit(item, handle)
                table.insert(groundFruits, {
                    Object   = item,
                    Handle   = handle,
                    Name     = name,
                    Tier     = tier,
                    Color    = color,
                    StoreKey = storeKey,
                })
            end
        end

        for obj, data in pairs(EspFruitObjects) do
            if not activeSet[obj] or not obj.Parent or not obj:IsDescendantOf(Workspace) then
                if data.Gui then data.Gui:Destroy() end
                EspFruitObjects[obj] = nil
            end
        end

        local rootInst = getRoot()
        local myPos    = rootInst and rootInst.Position or Vector3.zero

        if #groundFruits > 0 and myPos ~= Vector3.zero then
            for _, f in ipairs(groundFruits) do
                local dist     = math.floor((myPos - f.Handle.Position).Magnitude)
                local posText  = string.format("X:%d Y:%d Z:%d",
                    math.floor(f.Handle.Position.X),
                    math.floor(f.Handle.Position.Y),
                    math.floor(f.Handle.Position.Z))

                if Config.FruitESP then
                    if not EspFruitObjects[f.Object] then
                        local bb = Instance.new("BillboardGui")
                        bb.Size          = UDim2.new(0, 180, 0, 48)
                        bb.AlwaysOnTop   = true
                        bb.ExtentsOffset = Vector3.new(0, 2.5, 0)
                        bb.Adornee       = f.Handle
                        bb.Parent        = f.Handle

                        local lbl = Instance.new("TextLabel")
                        lbl.Size                   = UDim2.new(1, 0, 1, 0)
                        lbl.BackgroundTransparency = 1
                        lbl.Text                   = string.format("[%s]\n%s\n%dm (%s)", f.Tier, f.Name, dist, posText)
                        lbl.TextColor3             = f.Color
                        lbl.Font                   = Enum.Font.SourceSansBold
                        lbl.TextSize               = 12
                        lbl.TextStrokeTransparency = 0
                        lbl.Parent                 = bb

                        EspFruitObjects[f.Object] = { Gui = bb, Label = lbl }
                    else
                        pcall(function()
                            EspFruitObjects[f.Object].Label.Text = string.format("[%s]\n%s\n%dm (%s)", f.Tier, f.Name, dist, posText)
                            EspFruitObjects[f.Object].Gui.Adornee = f.Handle
                            EspFruitObjects[f.Object].Gui.Enabled = true
                        end)
                    end
                end
            end

            if Config.AutoCollect and not IsCollecting then
                local target = selectCollectTarget(groundFruits, myPos)
                if target then
                    task.spawn(function()
                        smoothTravelCollect(target.Handle, target.Object)
                    end)
                end
            end
        end

        if Config.AutoStore and not IsStoring then
            for _, loc in ipairs({LocalPlayer.Character, LocalPlayer.Backpack}) do
                if loc then
                    for _, item in ipairs(loc:GetChildren()) do
                        if item:IsA("Tool") and (item.Name:lower():find("fruit") or item.Name:find("%-")) then
                            storeInventoryFruit(item)
                        end
                    end
                end
            end
        end

        task.wait(1.5)
    end
end)

-- ==============================================================================
-- 12. PLAYER ESP LOOP
-- ==============================================================================
task.spawn(function()
    while true do
        if Config.PlayerESP then
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character then
                    local head = player.Character:FindFirstChild("Head")
                    if head and not EspPlayerObjects[player] then
                        local bb = Instance.new("BillboardGui")
                        bb.Size          = UDim2.new(0, 120, 0, 32)
                        bb.AlwaysOnTop   = true
                        bb.ExtentsOffset = Vector3.new(0, 3, 0)
                        bb.Adornee       = head
                        bb.Parent        = head

                        local lbl = Instance.new("TextLabel")
                        lbl.Size                   = UDim2.new(1, 0, 1, 0)
                        lbl.BackgroundTransparency = 1
                        lbl.Text                   = player.Name
                        lbl.TextColor3             = Color3.fromRGB(255, 90, 90)
                        lbl.Font                   = Enum.Font.SourceSansBold
                        lbl.TextSize               = 13
                        lbl.TextStrokeTransparency = 0
                        lbl.Parent                 = bb

                        EspPlayerObjects[player] = { Gui = bb }
                    end
                end
            end
        end
        task.wait(1)
    end
end)

Rayfield:Notify({
    Title = "SUHO v4 loaded",
    Content = "Fruits tab -> Auto-Collect. Filter tab -> restrict targets.",
    Duration = 6,
    Image = 4483362458,
})

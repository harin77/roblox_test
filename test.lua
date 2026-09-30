-- ==============================================================================
-- SUHO ADVANCED COMBAT ENGINE (WITH ON-SCREEN ERROR REPORTER & DEBUGGER)
-- Catches crashes, tests mobile executor hooks, and displays line errors
-- ==============================================================================

local function initScript()
    local Players = game:GetService("Players")
    local Workspace = game:GetService("Workspace")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local CoreGui = game:GetService("CoreGui")

    local LocalPlayer = Players.LocalPlayer
    local Camera = Workspace.CurrentCamera
    local Mouse = LocalPlayer:GetMouse()

    -- On-Screen Error Logging Facility
    local function spawnDebugWindow(errMessage)
        pcall(function()
            local dbgGui = Instance.new("ScreenGui")
            dbgGui.Name = "SuhoDebugErrorUI"
            dbgGui.ResetOnSpawn = false
            
            local parent = CoreGui
            pcall(function()
                local t = Instance.new("Folder")
                t.Parent = CoreGui
                t:Destroy()
            end)
            if not parent then parent = LocalPlayer:WaitForChild("PlayerGui") end
            dbgGui.Parent = parent

            local box = Instance.new("Frame")
            box.Size = UDim2.new(0.85, 0, 0.4, 0)
            box.Position = UDim2.new(0.075, 0, 0.3, 0)
            box.BackgroundColor3 = Color3.fromRGB(35, 10, 10)
            box.BorderSizePixel = 2
            box.BorderColor3 = Color3.fromRGB(255, 60, 60)
            box.Active = true
            box.Draggable = true
            box.Parent = dbgGui

            local title = Instance.new("TextLabel")
            title.Size = UDim2.new(1, 0, 0, 30)
            title.BackgroundColor3 = Color3.fromRGB(50, 15, 15)
            title.Text = "SUHO ERROR TRACE (TAKE A SCREENSHOT)"
            title.TextColor3 = Color3.fromRGB(255, 200, 200)
            title.Font = Enum.Font.SourceSansBold
            title.TextSize = 13
            title.Parent = box

            local text = Instance.new("TextBox")
            text.Size = UDim2.new(0.96, 0, 0.8, -36)
            text.Position = UDim2.new(0.02, 0, 0, 34)
            text.BackgroundTransparency = 1
            text.Text = tostring(errMessage)
            text.TextColor3 = Color3.fromRGB(255, 255, 255)
            text.Font = Enum.Font.Code
            text.TextSize = 11
            text.TextWrapped = true
            text.ClearTextOnFocus = false
            text.TextEditable = false
            text.TextXAlignment = Enum.TextXAlignment.Left
            text.TextYAlignment = Enum.TextYAlignment.Top
            text.Parent = box

            local close = Instance.new("TextButton")
            close.Size = UDim2.new(0, 70, 0, 24)
            close.Position = UDim2.new(0.5, -35, 1, -30)
            close.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
            close.Text = "DISMISS"
            close.TextColor3 = Color3.fromRGB(255, 255, 255)
            close.Font = Enum.Font.SourceSansBold
            close.TextSize = 12
            close.Parent = box
            close.MouseButton1Click:Connect(function() dbgGui:Destroy() end)
        end)
    end

    -- Cleanup Previous UI
    pcall(function()
        if CoreGui:FindFirstChild("SuhoAimHybridSuite") then CoreGui.SuhoAimHybridSuite:Destroy() end
    end)
    pcall(function()
        if LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("SuhoAimHybridSuite") then
            LocalPlayer.PlayerGui.SuhoAimHybridSuite:Destroy()
        end
    end)

    -- Safe UI Parent Resolver
    local function getSafeUiParent()
        local success, parent = pcall(function()
            local test = Instance.new("Folder")
            test.Name = "SuhoTestFolder"
            test.Parent = CoreGui
            test:Destroy()
            return CoreGui
        end)
        if success and parent then
            return CoreGui
        end
        return LocalPlayer:WaitForChild("PlayerGui")
    end

    -- Settings
    local Settings = {
        AimlockPlayers = false,
        SilentAimPlayers = false,
        SilentAimNPC = false,

        AimlockRange = 1000,
        AimlockPrediction = true,
        AimlockPredictionAmount = 0.12,
        TargetLowestHP = false,
        AimlockKey = Enum.KeyCode.E,

        SARange = 1000,
        SAPrediction = true,
        SAPredictionAmount = 0.20,

        SkillRouting = true,

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

    -- Target Helpers
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
                                if fovDist < shortestMetric then
                                    shortestMetric = fovDist
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

    local function acquireSilentCandidate()
        local myChar = LocalPlayer.Character
        local myRoot = getRoot(myChar)
        if not myRoot then return nil end

        local bestTarget = nil
        local shortestDist = Settings.SARange

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

    -- Hook Capability Check with Safe Sandbox
    local hookOk, hookErr = pcall(function()
        if hookmetamethod and getrawmetatable then
            local rawMeta = getrawmetatable(game)
            setreadonly(rawMeta, false)

            local oldNamecall = rawMeta.__namecall
            local oldIndex = rawMeta.__index

            rawMeta.__namecall = newcclosure(function(self, ...)
                local method = getnamecallmethod()
                local args = { ... }

                if (Settings.SilentAimPlayers or Settings.SilentAimNPC) and Runtime.CurrentSilentTarget and isEntityAlive(Runtime.CurrentSilentTarget.Parent) then
                    local targetHit = Runtime.CurrentSilentTarget.Position
                    if Settings.SAPrediction then
                        targetHit = getPredictedPosition(Runtime.CurrentSilentTarget, Settings.SAPredictionAmount)
                    end

                    if Settings.SkillRouting and tostring(self) == "CommF_" and (args[1] == "Attack" or args[1] == "Skill") then
                        args[2] = targetHit
                        return oldNamecall(self, table.unpack(args))
                    end

                    if method == "Raycast" and self == Workspace and typeof(args[2]) == "Vector3" then
                        args[2] = (targetHit - args[1]).Unit * args[2].Magnitude
                        return oldNamecall(self, table.unpack(args))
                    end
                end

                return oldNamecall(self, ...)
            end)

            rawMeta.__index = newcclosure(function(self, key)
                if not checkcaller() and (Settings.SilentAimPlayers or Settings.SilentAimNPC) then
                    if Runtime.CurrentSilentTarget and isEntityAlive(Runtime.CurrentSilentTarget.Parent) then
                        local targetHit = Runtime.CurrentSilentTarget.Position
                        if Settings.SAPrediction then
                            targetHit = getPredictedPosition(Runtime.CurrentSilentTarget, Settings.SAPredictionAmount)
                        end

                        if self == Mouse then
                            if key == "Hit" or key == "hit" then
                                return CFrame.new(targetHit)
                            elseif key == "Target" or key == "target" then
                                return Runtime.CurrentSilentTarget
                            end
                        end
                    end
                end

                return oldIndex(self, key)
            end)

            setreadonly(rawMeta, true)
        end
    end)
    if not hookOk then
        warn("[SUHO DEBUG] Metamethod hook bypassed: " .. tostring(hookErr))
    end

    -- Visual Drawings
    local VisualDrawing = { FOVCircle = nil, Tracer = nil }
    pcall(function()
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
    end)

    local TargetHighlight = Instance.new("Highlight")
    TargetHighlight.Name = "SuhoTargetHighlightHybrid"
    TargetHighlight.FillColor = Settings.TargetColor
    TargetHighlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    TargetHighlight.FillTransparency = 0.5
    TargetHighlight.OutlineTransparency = 0.1
    TargetHighlight.Enabled = false
    pcall(function() TargetHighlight.Parent = getSafeUiParent() end)

    RunService.RenderStepped:Connect(function()
        local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        Runtime.ScreenCenter = screenCenter

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

        local primaryVisual = Runtime.CurrentAimlockTarget or (Runtime.CurrentSilentTarget and Runtime.CurrentSilentTarget.Parent)
        if primaryVisual and Settings.HighlightTarget and isEntityAlive(primaryVisual) then
            TargetHighlight.Adornee = primaryVisual
            TargetHighlight.Enabled = true
        else
            TargetHighlight.Enabled = false
            TargetHighlight.Adornee = nil
        end

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

    -- Keybind Listener
    UserInputService.InputBegan:Connect(function(input, processed)
        if not processed and input.KeyCode == Settings.AimlockKey then
            Runtime.AimlockActive = not Runtime.AimlockActive
            if not Runtime.AimlockActive then
                Runtime.CurrentAimlockTarget = nil
            end
        end
    end)

    -- GUI Assembly
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "SuhoAimHybridSuite"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.Parent = getSafeUiParent()

    local ToggleButton = Instance.new("TextButton")
    ToggleButton.Name = "ToggleButton"
    ToggleButton.Size = UDim2.new(0, 50, 0, 50)
    ToggleButton.Position = UDim2.new(0.02, 0, 0.25, 0)
    ToggleButton.BackgroundColor3 = Color3.fromRGB(24, 27, 36)
    ToggleButton.Text = "AIM"
    ToggleButton.TextColor3 = Color3.fromRGB(0, 220, 255)
    ToggleButton.Font = Enum.Font.SourceSansBold
    ToggleButton.TextSize = 13
    ToggleButton.Active = true
    ToggleButton.Draggable = true
    ToggleButton.Parent = ScreenGui

    local TCorner = Instance.new("UICorner")
    TCorner.CornerRadius = UDim.new(1, 0)
    TCorner.Parent = ToggleButton

    local TStroke = Instance.new("UIStroke")
    TStroke.Color = Color3.fromRGB(0, 180, 255)
    TStroke.Thickness = 1.6
    TStroke.Parent = ToggleButton

    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0.85, 0, 0.65, 0)
    MainFrame.Position = UDim2.new(0.075, 0, 0.18, 0)
    MainFrame.BackgroundColor3 = Color3.fromRGB(16, 18, 24)
    MainFrame.BorderSizePixel = 0
    MainFrame.Active = true
    MainFrame.Draggable = true
    MainFrame.Visible = true
    MainFrame.Parent = ScreenGui

    local SizeConstraint = Instance.new("UISizeConstraint")
    SizeConstraint.MinSize = Vector2.new(340, 280)
    SizeConstraint.MaxSize = Vector2.new(480, 420)
    SizeConstraint.Parent = MainFrame

    local MainCorner = Instance.new("UICorner")
    MainCorner.CornerRadius = UDim.new(0, 8)
    MainCorner.Parent = MainFrame

    local MainStroke = Instance.new("UIStroke")
    MainStroke.Color = Color3.fromRGB(38, 42, 56)
    MainStroke.Thickness = 1.2
    MainStroke.Parent = MainFrame

    local TopBar = Instance.new("Frame")
    TopBar.Name = "TopBar"
    TopBar.Size = UDim2.new(1, 0, 0, 36)
    TopBar.BackgroundColor3 = Color3.fromRGB(22, 25, 34)
    TopBar.BorderSizePixel = 0
    TopBar.Parent = MainFrame

    local TopCorner = Instance.new("UICorner")
    TopCorner.CornerRadius = UDim.new(0, 8)
    TopCorner.Parent = TopBar

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(0.65, 0, 1, 0)
    Title.Position = UDim2.new(0.04, 0, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Text = "SUHO COMBAT ENGINE [TOUCH & PC]"
    Title.TextColor3 = Color3.fromRGB(240, 245, 255)
    Title.Font = Enum.Font.SourceSansBold
    Title.TextSize = 13
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = TopBar

    local MinBtn = Instance.new("TextButton")
    MinBtn.Name = "MinimizeButton"
    MinBtn.Size = UDim2.new(0, 26, 0, 24)
    MinBtn.Position = UDim2.new(1, -62, 0, 6)
    MinBtn.BackgroundColor3 = Color3.fromRGB(45, 50, 65)
    MinBtn.Text = "-"
    MinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    MinBtn.Font = Enum.Font.SourceSansBold
    MinBtn.TextSize = 14
    MinBtn.Parent = TopBar

    local MinCorner = Instance.new("UICorner")
    MinCorner.CornerRadius = UDim.new(0, 4)
    MinCorner.Parent = MinBtn

    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Name = "CloseButton"
    CloseBtn.Size = UDim2.new(0, 26, 0, 24)
    CloseBtn.Position = UDim2.new(1, -32, 0, 6)
    CloseBtn.BackgroundColor3 = Color3.fromRGB(160, 40, 40)
    CloseBtn.Text = "X"
    CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    CloseBtn.Font = Enum.Font.SourceSansBold
    CloseBtn.TextSize = 12
    CloseBtn.Parent = TopBar

    local CloseCorner = Instance.new("UICorner")
    CloseCorner.CornerRadius = UDim.new(0, 4)
    CloseCorner.Parent = CloseBtn

    local Sidebar = Instance.new("Frame")
    Sidebar.Size = UDim2.new(0, 110, 1, -44)
    Sidebar.Position = UDim2.new(0, 6, 0, 40)
    Sidebar.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
    Sidebar.BorderSizePixel = 0
    Sidebar.Parent = MainFrame

    local SideCorner = Instance.new("UICorner")
    SideCorner.CornerRadius = UDim.new(0, 6)
    SideCorner.Parent = Sidebar

    local SideLayout = Instance.new("UIListLayout")
    SideLayout.Padding = UDim.new(0, 4)
    SideLayout.Parent = Sidebar

    local PageContainer = Instance.new("Frame")
    PageContainer.Size = UDim2.new(1, -126, 1, -44)
    PageContainer.Position = UDim2.new(0, 120, 0, 40)
    PageContainer.BackgroundTransparency = 1
    PageContainer.Parent = MainFrame

    local Pages = {}
    local TabButtons = {}

    local function createPage(pageName)
        local scroll = Instance.new("ScrollingFrame")
        scroll.Size = UDim2.new(1, 0, 1, 0)
        scroll.BackgroundTransparency = 1
        scroll.BorderSizePixel = 0
        scroll.ScrollBarThickness = 4
        scroll.ScrollBarImageColor3 = Color3.fromRGB(60, 70, 95)
        scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
        scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
        scroll.Visible = false
        scroll.Parent = PageContainer

        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 6)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Parent = scroll

        Pages[pageName] = scroll
        return scroll
    end

    local function switchTab(selected)
        for name, page in pairs(Pages) do
            page.Visible = (name == selected)
        end
        for name, btn in pairs(TabButtons) do
            if name == selected then
                btn.BackgroundColor3 = Color3.fromRGB(40, 115, 70)
                btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            else
                btn.BackgroundColor3 = Color3.fromRGB(26, 29, 39)
                btn.TextColor3 = Color3.fromRGB(180, 185, 200)
            end
        end
    end

    local function addTabButton(tabName)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -6, 0, 30)
        btn.Position = UDim2.new(0, 3, 0, 0)
        btn.BackgroundColor3 = Color3.fromRGB(26, 29, 39)
        btn.Text = tabName
        btn.TextColor3 = Color3.fromRGB(180, 185, 200)
        btn.Font = Enum.Font.SourceSansBold
        btn.TextSize = 12
        btn.Parent = Sidebar

        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 4)
        c.Parent = btn

        btn.MouseButton1Click:Connect(function() switchTab(tabName) end)
        TabButtons[tabName] = btn
    end

    local function createHeader(page, text)
        local header = Instance.new("TextLabel")
        header.Size = UDim2.new(1, -6, 0, 24)
        header.BackgroundTransparency = 1
        header.Text = "=== " .. string.upper(text) .. " ==="
        header.TextColor3 = Color3.fromRGB(0, 180, 255)
        header.Font = Enum.Font.SourceSansBold
        header.TextSize = 11
        header.TextXAlignment = Enum.TextXAlignment.Left
        header.Parent = page
        return header
    end

    local function createToggle(page, text, stateVar, callback)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -6, 0, 32)
        btn.Font = Enum.Font.SourceSansBold
        btn.TextSize = 11
        btn.Parent = page

        local bCorner = Instance.new("UICorner")
        bCorner.CornerRadius = UDim.new(0, 5)
        bCorner.Parent = btn

        local function render()
            btn.BackgroundColor3 = Settings[stateVar] and Color3.fromRGB(40, 115, 70) or Color3.fromRGB(28, 30, 40)
            btn.Text = "  " .. text .. (Settings[stateVar] and " : [ON]" or " : [OFF]")
            btn.TextColor3 = Settings[stateVar] and Color3.fromRGB(140, 255, 140) or Color3.fromRGB(240, 110, 110)
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

    local function createSlider(page, titleText, stateVar, minVal, maxVal, step, callback)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, -6, 0, 34)
        frame.BackgroundColor3 = Color3.fromRGB(24, 27, 36)
        frame.BorderSizePixel = 0
        frame.Parent = page

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 5)
        corner.Parent = frame

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0.55, 0, 1, 0)
        label.Position = UDim2.new(0.03, 0, 0, 0)
        label.BackgroundTransparency = 1
        label.Text = titleText .. ": " .. tostring(Settings[stateVar])
        label.TextColor3 = Color3.fromRGB(220, 225, 240)
        label.Font = Enum.Font.SourceSansBold
        label.TextSize = 11
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = frame

        local minusBtn = Instance.new("TextButton")
        minusBtn.Size = UDim2.new(0, 28, 0, 22)
        minusBtn.Position = UDim2.new(0.68, 0, 0.18, 0)
        minusBtn.BackgroundColor3 = Color3.fromRGB(38, 42, 56)
        minusBtn.Text = "-"
        minusBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        minusBtn.Font = Enum.Font.SourceSansBold
        minusBtn.TextSize = 13
        minusBtn.Parent = frame

        local pCorner1 = Instance.new("UICorner")
        pCorner1.CornerRadius = UDim.new(0, 4)
        pCorner1.Parent = minusBtn

        local plusBtn = Instance.new("TextButton")
        plusBtn.Size = UDim2.new(0, 28, 0, 22)
        plusBtn.Position = UDim2.new(0.85, 0, 0.18, 0)
        plusBtn.BackgroundColor3 = Color3.fromRGB(38, 42, 56)
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

    local function createStatusRow(page, titleText, dynamicValueFn)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, -6, 0, 28)
        frame.BackgroundColor3 = Color3.fromRGB(24, 27, 36)
        frame.BorderSizePixel = 0
        frame.Parent = page

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 4)
        corner.Parent = frame

        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(0.48, 0, 1, 0)
        title.Position = UDim2.new(0.03, 0, 0, 0)
        title.BackgroundTransparency = 1
        title.Text = titleText
        title.TextColor3 = Color3.fromRGB(190, 195, 210)
        title.Font = Enum.Font.SourceSansBold
        title.TextSize = 11
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.Parent = frame

        local val = Instance.new("TextLabel")
        val.Size = UDim2.new(0.45, 0, 1, 0)
        val.Position = UDim2.new(0.52, 0, 0, 0)
        val.BackgroundTransparency = 1
        val.Text = "..."
        val.TextColor3 = Color3.fromRGB(100, 215, 255)
        val.Font = Enum.Font.SourceSans
        val.TextSize = 11
        val.TextXAlignment = Enum.TextXAlignment.Right
        val.Parent = frame

        task.spawn(function()
            while ScreenGui.Parent do
                val.Text = tostring(dynamicValueFn())
                task.wait(0.25)
            end
        end)
        return frame
    end

    -- TAB 1: AIMLOCK
    local AimlockPage = createPage("Aimlock")
    addTabButton("Aimlock")

    createHeader(AimlockPage, "Aimbot Master")
    createToggle(AimlockPage, "Aimlock Players (Press E or Button)", "AimlockPlayers")

    local TouchAimBtn = Instance.new("TextButton")
    TouchAimBtn.Size = UDim2.new(1, -6, 0, 30)
    TouchAimBtn.BackgroundColor3 = Color3.fromRGB(35, 75, 120)
    TouchAimBtn.Text = "Toggle Aimlock On/Off (Mobile Tap)"
    TouchAimBtn.TextColor3 = Color3.fromRGB(220, 235, 255)
    TouchAimBtn.Font = Enum.Font.SourceSansBold
    TouchAimBtn.TextSize = 11
    TouchAimBtn.Parent = AimlockPage

    local TAB_Corner = Instance.new("UICorner")
    TAB_Corner.CornerRadius = UDim.new(0, 4)
    TAB_Corner.Parent = TouchAimBtn

    TouchAimBtn.MouseButton1Click:Connect(function()
        Runtime.AimlockActive = not Runtime.AimlockActive
        if not Runtime.AimlockActive then
            Runtime.CurrentAimlockTarget = nil
        end
    end)

    createHeader(AimlockPage, "Aimlock Settings")
    createSlider(AimlockPage, "Aimlock Range", "AimlockRange", 100, 5000, 100)
    createToggle(AimlockPage, "Aimlock Prediction", "AimlockPrediction")
    createSlider(AimlockPage, "Prediction Amount", "AimlockPredictionAmount", 0.01, 1.0, 0.02)
    createToggle(AimlockPage, "Target Lowest HP", "TargetLowestHP")
    createStatusRow(AimlockPage, "Aimlock Target", function()
        if Runtime.CurrentAimlockTarget then
            return Runtime.CurrentAimlockTarget.Name
        end
        return "(None)"
    end)

    -- TAB 2: SILENT AIM
    local SilentPage = createPage("Silent Aim")
    addTabButton("Silent Aim")

    createHeader(SilentPage, "Silent Aim Master")
    createToggle(SilentPage, "Silent Aim Players", "SilentAimPlayers")
    createToggle(SilentPage, "Silent Aim NPC", "SilentAimNPC")

    createHeader(SilentPage, "Silent Aim Settings")
    createSlider(SilentPage, "SA Range", "SARange", 100, 5000, 100)
    createToggle(SilentPage, "SA Prediction", "SAPrediction")
    createSlider(SilentPage, "SA Prediction Amount", "SAPredictionAmount", 0.01, 1.0, 0.02)
    createStatusRow(SilentPage, "Silent Lock Target", function()
        if Runtime.CurrentSilentTarget and Runtime.CurrentSilentTarget.Parent then
            return Runtime.CurrentSilentTarget.Parent.Name
        end
        return "(None)"
    end)

    createHeader(SilentPage, "Routing")
    createToggle(SilentPage, "Skill Routing (CommF_ & Raycast)", "SkillRouting")

    -- TAB 3: VISUALS
    local VisualPage = createPage("Visuals")
    addTabButton("Visuals")

    createHeader(VisualPage, "Render Overlays")
    createToggle(VisualPage, "FOV Ring gates Aimlock", "FOVRingGatesAimlock")
    createToggle(VisualPage, "Highlight Target", "HighlightTarget")
    createToggle(VisualPage, "Show Tracer Line", "ShowTracer")
    createToggle(VisualPage, "Show FOV Ring", "ShowFOVRing")
    createSlider(VisualPage, "FOV Circle Size", "FOVSize", 50, 800, 25)

    -- UI Visibility Events
    local function toggleVisibility()
        MainFrame.Visible = not MainFrame.Visible
    end

    ToggleButton.MouseButton1Click:Connect(toggleVisibility)
    MinBtn.MouseButton1Click:Connect(function() MainFrame.Visible = false end)

    CloseBtn.MouseButton1Click:Connect(function()
        if VisualDrawing.FOVCircle then VisualDrawing.FOVCircle:Remove() end
        if VisualDrawing.Tracer then VisualDrawing.Tracer:Remove() end
        TargetHighlight:Destroy()
        ScreenGui:Destroy()
    end)

    UserInputService.InputBegan:Connect(function(input, gpe)
        if not gpe and input.KeyCode == Enum.KeyCode.H then
            toggleVisibility()
        end
    end)

    switchTab("Aimlock")
end

-- Protected Execution with Error Reporting
local success, runtimeError = xpcall(initScript, debug.traceback)
if not success then
    warn("[SUHO CRASH DETECTED]:\n" .. tostring(runtimeError))
    
    -- Display the error directly on screen
    pcall(function()
        local Players = game:GetService("Players")
        local CoreGui = game:GetService("CoreGui")
        local LocalPlayer = Players.LocalPlayer

        local dbgGui = Instance.new("ScreenGui")
        dbgGui.Name = "SuhoCrashUI"
        dbgGui.ResetOnSpawn = false
        
        local parent = CoreGui
        pcall(function()
            local t = Instance.new("Folder")
            t.Parent = CoreGui
            t:Destroy()
        end)
        if not parent then parent = LocalPlayer:WaitForChild("PlayerGui") end
        dbgGui.Parent = parent

        local box = Instance.new("Frame")
        box.Size = UDim2.new(0.85, 0, 0.45, 0)
        box.Position = UDim2.new(0.075, 0, 0.25, 0)
        box.BackgroundColor3 = Color3.fromRGB(28, 12, 12)
        box.BorderSizePixel = 2
        box.BorderColor3 = Color3.fromRGB(255, 70, 70)
        box.Active = true
        box.Draggable = true
        box.Parent = dbgGui

        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, 0, 0, 30)
        title.BackgroundColor3 = Color3.fromRGB(45, 15, 15)
        title.Text = "SUHO EXECUTION ERROR DETECTED"
        title.TextColor3 = Color3.fromRGB(255, 200, 200)
        title.Font = Enum.Font.SourceSansBold
        title.TextSize = 13
        title.Parent = box

        local text = Instance.new("TextBox")
        text.Size = UDim2.new(0.96, 0, 0.8, -36)
        text.Position = UDim2.new(0.02, 0, 0, 34)
        text.BackgroundTransparency = 1
        text.Text = tostring(runtimeError)
        text.TextColor3 = Color3.fromRGB(255, 255, 255)
        text.Font = Enum.Font.Code
        text.TextSize = 11
        text.TextWrapped = true
        text.ClearTextOnFocus = false
        text.TextEditable = false
        text.TextXAlignment = Enum.TextXAlignment.Left
        text.TextYAlignment = Enum.TextYAlignment.Top
        text.Parent = box

        local close = Instance.new("TextButton")
        close.Size = UDim2.new(0, 80, 0, 26)
        close.Position = UDim2.new(0.5, -40, 1, -32)
        close.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
        close.Text = "CLOSE"
        close.TextColor3 = Color3.fromRGB(255, 255, 255)
        close.Font = Enum.Font.SourceSansBold
        close.TextSize = 12
        close.Parent = box
        close.MouseButton1Click:Connect(function() dbgGui:Destroy() end)
    end)
end

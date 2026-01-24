print("Starting script...")
if typeof(clear) == "function" then clear() end

-- SERVICES
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local RS = game:GetService("ReplicatedStorage")

-- SETTINGS & VARIABLES
local localPlayer = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local RAYCAST_COOLDOWN = 0.15
local TARGET_HITBOX_SIZE = Vector3.new(15, 15, 15)

local activeNPCs = {}
local trackedParts = {}
local originalSizes = {}
local wallConnections = {}

-- TOGGLES
local wallEnabled = false
local silentEnabled = false
local showHitbox = false
local guiVisible = true
local isUnloaded = false

local patchOptions = { recoil = false, firemodes = false }

-- COLORS
local visibleColor = Color3.fromRGB(0, 255, 0)
local hiddenColor = Color3.fromRGB(255, 0, 0)

--- HELPERS ---
local function getRootPart(model)
    return model:FindFirstChild("Root") or model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("UpperTorso")
end

local function hasAIChild(model)
    for _, c in ipairs(model:GetChildren()) do
        if type(c.Name) == "string" and c.Name:sub(1, 3) == "AI_" then return true end
    end
    return false
end

local function createBoxForPart(part)
    if not part or part:FindFirstChild("Wall_Box") then return end
    local box = Instance.new("BoxHandleAdornment")
    box.Name = "Wall_Box"
    box.Size = part.Size + Vector3.new(0.1, 0.1, 0.1)
    box.Adornee = part
    box.AlwaysOnTop = true
    box.ZIndex = 10
    box.Color3 = visibleColor
    box.Transparency = 0.3
    box.Parent = part
    trackedParts[part] = true
end

local function destroyAllBoxes()
    for part, _ in pairs(trackedParts) do
        if part and part:FindFirstChild("Wall_Box") then pcall(function() part.Wall_Box:Destroy() end) end
    end
    trackedParts = {}
end

local function applySilentHitbox(model, root)
    if not originalSizes[model] then originalSizes[model] = root.Size end
    root.Size = TARGET_HITBOX_SIZE
    root.Transparency = showHitbox and 0.85 or 1
    root.CanCollide = true
end

local function restoreOriginalSize(model)
    local root = getRootPart(model)
    if root and originalSizes[model] then
        root.Size = originalSizes[model]
        root.Transparency = 1
        root.CanCollide = false
    end
    originalSizes[model] = nil
end

local function addNPC(model)
    if activeNPCs[model] or model.Name ~= "Male" or not hasAIChild(model) then return end
    local head = model:FindFirstChild("Head")
    local root = getRootPart(model)
    if not head or not root then return end
    activeNPCs[model] = { head = head, root = root }
    if wallEnabled then createBoxForPart(head) end
end

local function patchWeapons(options)
    local weaponsFolder = RS:FindFirstChild("Shared")
        and RS.Shared:FindFirstChild("Configs")
        and RS.Shared.Configs:FindFirstChild("Weapon")
        and RS.Shared.Configs.Weapon:FindFirstChild("Weapons_Player")
    
    if not weaponsFolder then return end

    for _, platform in pairs(weaponsFolder:GetChildren()) do
        if platform.Name:match("^Platform_") then
            for _, weapon in pairs(platform:GetChildren()) do
                for _, child in pairs(weapon:GetChildren()) do
                    if child:IsA("ModuleScript") and child.Name:match("^Receiver%.") then
                        local success, receiver = pcall(require, child)
                        if success and receiver and receiver.Config and receiver.Config.Tune then
                            local tune = receiver.Config.Tune
                            if options.recoil then
                                tune.Recoil_X = 0 tune.Recoil_Z = 0 tune.RecoilForce_Tap = 0
                                tune.RecoilForce_Impulse = 0 tune.Recoil_Range = Vector2.zero
                                tune.Recoil_Camera = 0 tune.RecoilAccelDamp_Crouch = Vector3.new(1, 1, 1)
                                tune.RecoilAccelDamp_Prone = Vector3.new(1, 1, 1)
                            end
                            if options.firemodes then 
                                tune.Firemodes = {3, 2, 1, 0} 
                            end
                        end
                    end
                end
            end
        end
    end
end

--- GUI ---

local sg = Instance.new("ScreenGui", localPlayer.PlayerGui)
sg.Name = "BRM5_Simple"
sg.ResetOnSpawn = false
sg.DisplayOrder = 9999

local main = Instance.new("Frame", sg)
main.Size = UDim2.new(0, 420, 0, 260)
main.Position = UDim2.new(0.5, -210, 0.5, -130)
main.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
main.BorderSizePixel = 0
main.Active = true
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 8)

-- Draggable top bar
local dragging, dragInput, dragStart, startPos
local function updateDrag(input)
    local delta = input.Position - dragStart
    main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end

local topBar = Instance.new("Frame", main)
topBar.Size = UDim2.new(1, 0, 0, 36)
topBar.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
topBar.BorderSizePixel = 0
Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 8)

topBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = main.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)

topBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then dragInput = input end
end)

RunService.RenderStepped:Connect(function()
    if dragging and dragInput then updateDrag(dragInput) end
end)

local title = Instance.new("TextLabel", topBar)
title.Size = UDim2.new(1, -20, 1, 0)
title.Position = UDim2.new(0, 10, 0, 0)
title.Text = "BRM5 - Simple"
title.Font = "GothamBold"
title.TextColor3 = Color3.fromRGB(85, 170, 255)
title.TextSize = 16
title.TextXAlignment = "Left"
title.BackgroundTransparency = 1

-- Sidebar & content
local sidebar = Instance.new("Frame", main)
sidebar.Position = UDim2.new(0, 0, 0, 36)
sidebar.Size = UDim2.new(0, 120, 1, -36)
sidebar.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
sidebar.BorderSizePixel = 0
Instance.new("UICorner", sidebar).CornerRadius = UDim.new(0, 6)

local sideLayout = Instance.new("UIListLayout", sidebar)
sideLayout.Padding = UDim.new(0, 8)
sideLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
sideLayout.SortOrder = Enum.SortOrder.LayoutOrder

local container = Instance.new("Frame", main)
container.Position = UDim2.new(0, 130, 0, 46)
container.Size = UDim2.new(1, -140, 1, -56)
container.BackgroundTransparency = 1

local function createTab()
    local f = Instance.new("ScrollingFrame", container)
    f.Size = UDim2.new(1, 0, 1, 0)
    f.BackgroundTransparency = 1
    f.Visible = false
    f.ScrollBarThickness = 2
    f.CanvasSize = UDim2.new(0, 0, 0, 0)
    f.AutomaticCanvasSize = Enum.AutomaticSize.Y

    local l = Instance.new("UIListLayout", f)
    l.Padding = UDim.new(0, 12)
    l.HorizontalAlignment = Enum.HorizontalAlignment.Center
    l.SortOrder = Enum.SortOrder.LayoutOrder

    return f
end

local tabMain = createTab()
local tabUnload = createTab()
tabMain.Visible = true

local tabButtons = {}

local function addTabBtn(name, target)
    local b = Instance.new("TextButton", sidebar)
    b.Size = UDim2.new(1, -16, 0, 34)
    b.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    b.TextColor3 = Color3.new(0.8, 0.8, 0.8)
    b.Font = "GothamMedium"
    b.TextSize = 13
    Instance.new("UICorner", b)

    tabButtons[name] = b
    if name == "Combat & Visuals" then
        b.BackgroundColor3 = Color3.fromRGB(85, 170, 255)
        b.TextColor3 = Color3.new(0, 0, 0)
    end

    b.Text = name
    b.MouseButton1Click:Connect(function()
        for n, btn in pairs(tabButtons) do
            btn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
            btn.TextColor3 = Color3.new(0.8, 0.8, 0.8)
        end
        b.BackgroundColor3 = Color3.fromRGB(85, 170, 255)
        b.TextColor3 = Color3.new(0, 0, 0)

        tabMain.Visible = false
        tabUnload.Visible = false
        target.Visible = true
    end)
end

addTabBtn("Combat & Visuals", tabMain)

-- Simple toggle creator
local function createToggle(parent, text, cb)
    local btn = Instance.new("TextButton", parent)
    btn.Size = UDim2.new(1, -10, 0, 34)
    btn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    btn.Text = text
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = "Gotham"
    btn.TextSize = 13
    Instance.new("UICorner", btn)
    local act = false
    btn.MouseButton1Click:Connect(function()
        act = not act
        btn.BackgroundColor3 = act and Color3.fromRGB(85, 170, 255) or Color3.fromRGB(35, 35, 35)
        btn.TextColor3 = act and Color3.new(0, 0, 0) or Color3.new(1, 1, 1)
        cb(act)
    end)
end

-- Combat & Visuals content (combined)
createToggle(tabMain, "Silent Hitbox", function(v) silentEnabled = v end)
createToggle(tabMain, "Show Hitbox", function(v) showHitbox = v end)
createToggle(tabMain, "Wall ESP", function(v)
    wallEnabled = v
    if wallEnabled then 
        for _, d in pairs(activeNPCs) do createBoxForPart(d.head) end 
    else 
        destroyAllBoxes() 
    end
end)

-- UNLOAD BUTTON
local unl = Instance.new("TextButton", sidebar)
unl.Size = UDim2.new(0, 110, 0, 35)
unl.AnchorPoint = Vector2.new(0.5, 0)
unl.Position = UDim2.new(0.5, 0, 0, 0)
unl.Text = "Unload Script"
unl.BackgroundColor3 = Color3.fromRGB(120, 40, 40)
unl.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", unl)
unl.MouseButton1Click:Connect(function()
    isUnloaded = true
    destroyAllBoxes()
    for m, _ in pairs(activeNPCs) do restoreOriginalSize(m) end
    for _, c in ipairs(wallConnections) do pcall(function() c:Disconnect() end) end
    sg:Destroy()
end)
--- MAIN LOOPS ---

-- Detect NPCs already present
for _, m in ipairs(Workspace:GetChildren()) do
    if m:IsA("Model") and m.Name == "Male" then if hasAIChild(m) then addNPC(m) end end
end

-- Detect new NPCs when they spawn
table.insert(wallConnections, Workspace.ChildAdded:Connect(function(m)
    if m:IsA("Model") and m.Name == "Male" then 
        task.delay(0.2, function() if hasAIChild(m) then addNPC(m) end end) 
    end
end))

RunService.RenderStepped:Connect(function()
    if isUnloaded then return end

    for m, d in pairs(activeNPCs) do
        if wallEnabled and d.head and d.head:FindFirstChild("Wall_Box") then
            local origin = camera.CFrame.Position
            local rp = RaycastParams.new()
            rp.FilterType = Enum.RaycastFilterType.Blacklist
            rp.FilterDescendantsInstances = {localPlayer.Character, d.head}
            local r = Workspace:Raycast(origin, d.head.Position - origin, rp)
            if d.head and d.head:FindFirstChild("Wall_Box") then
                d.head.Wall_Box.Color3 = (not r or (r.Instance and r.Instance:IsDescendantOf(m))) and visibleColor or hiddenColor
            end
        end

        if silentEnabled and d.root then applySilentHitbox(m, d.root) end
    end
end)

-- Toggle GUI visibility with INSERT
UserInputService.InputBegan:Connect(function(i, gp)
    if not gp and i.KeyCode == Enum.KeyCode.Insert then
        guiVisible = not guiVisible
        main.Visible = guiVisible
    end
end)

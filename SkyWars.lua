--[[
    💎 AUTO FARM DE GEMAS - UI Premium
    Autor: Script gerado sob medida
    Compatível com: Delta, Fluxus, Codex, Hydrogen, Krnl
--]]

-- ============================================================
-- SERVIÇOS
-- ============================================================
local Players        = game:GetService("Players")
local RunService     = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService   = game:GetService("TweenService")
local CoreGui        = game:GetService("CoreGui")
local Stats          = game:GetService("Stats")

local LocalPlayer    = Players.LocalPlayer
local Mouse          = LocalPlayer:GetMouse()

-- ============================================================
-- CONFIGURAÇÕES GERAIS
-- ============================================================
local CONFIG = {
    CollectInterval = 0.05,   -- intervalo entre coletas (segundos)
    MaxDistance     = 500,    -- distância máxima para buscar gemas
    AutoTeleport    = true,   -- teleporta até a gema antes de coletar
    SearchPatterns  = {
        "Gem", "Gems", "Gemstone", "Diamond", "Diamonds",
        "Crystal", "Crystals", "Coin", "Coins", "Collect"
    }
}

-- ============================================================
-- ESTADO GLOBAL
-- ============================================================
local State = {
    Farming      = false,
    GemCount     = 0,
    TotalGems    = 0,
    Conn         = nil,
    StartTime    = 0,
    GemFolder    = nil,   -- referência ao container de gemas
}

-- ============================================================
-- UTILITÁRIOS
-- ============================================================
local function getHiddenUI()
    if gethui then return gethui() end
    return CoreGui
end

local function safeDestroy(obj)
    if obj and obj.Parent then pcall(function() obj:Destroy() end) end
end

local function findGemFolder()
    -- Procura em Workspace e em ReplicatedStorage por um container de gemas
    local candidates = {}
    for _, parent in ipairs({workspace, game:GetService("ReplicatedStorage"), game:GetService("ReplicatedStorage"):FindFirstChild("Assets")}) do
        if parent then
            for _, child in ipairs(parent:GetChildren()) do
                for _, pat in ipairs(CONFIG.SearchPatterns) do
                    if child.Name:lower():find(pat:lower()) then
                        table.insert(candidates, child)
                    end
                end
            end
        end
    end
    return candidates
end

local function isGem(obj)
    if not obj or not obj.Parent then return false end
    for _, pat in ipairs(CONFIG.SearchPatterns) do
        if obj.Name:lower():find(pat:lower()) then return true end
    end
    return false
end

-- Tenta coletar via métodos legítimos do jogo:
-- 1. Toque (Firetouchinterest) se a gema tiver um Handle/BasePart
-- 2. Ativação de ProximityPrompt
-- 3. Chamada de RemoteEvent "Collect" se existir
local function tryCollect(gem)
    if not gem or not gem.Parent then return false end
    local success = false

    -- 1) ProximityPrompt
    local prompt = gem:FindFirstChildOfClass("ProximityPrompt")
        or (gem:IsA("BasePart") and gem:FindFirstChildOfClass("ProximityPrompt"))
    if prompt then
        pcall(function() prompt:InputHoldBegin(); task.wait(0.05); prompt:InputHoldEnd() end)
        success = true
    end

    -- 2) Toque físico
    local part = gem:IsA("BasePart") and gem or gem:FindFirstChildWhichIsA("BasePart", true)
    if part then
        pcall(function()
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp and firetouchinterest then
                firetouchinterest(hrp, part, 0)
                task.wait()
                firetouchinterest(hrp, part, 1)
                success = true
            end
        end)
    end

    -- 3) RemoteEvent Collect (heurística)
    for _, rem in ipairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
        if rem:IsA("RemoteEvent") or rem:IsA("RemoteFunction") then
            local n = rem.Name:lower()
            if n:find("collect") or n:find("gem") or n:find("pick") then
                pcall(function()
                    if rem:IsA("RemoteEvent") then
                        rem:FireServer(gem)
                    else
                        rem:InvokeServer(gem)
                    end
                    success = true
                end)
                break
            end
        end
    end

    return success
end

local function teleportTo(gem)
    if not CONFIG.AutoTeleport then return end
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local target = gem:IsA("BasePart") and gem or gem:FindFirstChildWhichIsA("BasePart", true)
    if hrp and target then
        hrp.CFrame = target.CFrame + Vector3.new(0, 3, 0)
    end
end

-- ============================================================
-- LOOP DE FARM
-- ============================================================
local function farmTick()
    local folder = State.GemFolder
    if not folder or not folder.Parent then
        local folders = findGemFolder()
        State.GemFolder = folders[1]
        folder = State.GemFolder
    end

    if not folder then return end

    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local best, bestDist = nil, CONFIG.MaxDistance
    for _, gem in ipairs(folder:GetChildren()) do
        if isGem(gem) then
            local part = gem:IsA("BasePart") and gem or gem:FindFirstChildWhichIsA("BasePart", true)
            if part then
                local d = (part.Position - hrp.Position).Magnitude
                if d < bestDist then best, bestDist = gem, d end
            end
        end
    end

    if best then
        teleportTo(best)
        if tryCollect(best) then
            State.GemCount = State.GemCount + 1
            State.TotalGems = State.TotalGems + 1
        end
    end
end

local function startFarm()
    if State.Farming then return end
    State.Farming = true
    State.StartTime = tick()

    State.Conn = RunService.Heartbeat:Connect(function()
        if not State.Farming then return end
        local ok, err = pcall(farmTick)
        if not ok then warn("[AutoFarm] erro:", err) end
    end)

    -- Delay mínimo para não travar
    task.spawn(function()
        while State.Farming do
            task.wait(CONFIG.CollectInterval)
        end
    end)
end

local function stopFarm()
    State.Farming = false
    if State.Conn then State.Conn:Disconnect(); State.Conn = nil end
end

-- ============================================================
-- INTERFACE GRÁFICA
-- ============================================================
local function createUI()
    safeDestroy(getHiddenUI():FindFirstChild("GemFarmUI"))

    -- ScreenGui principal
    local gui = Instance.new("ScreenGui")
    gui.Name = "GemFarmUI"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = getHiddenUI()

    -- Fundo principal
    local main = Instance.new("Frame")
    main.Name = "Main"
    main.Size = UDim2.new(0, 320, 0, 240)
    main.Position = UDim2.new(0.5, -160, 0.5, -120)
    main.BackgroundColor3 = Color3.fromRGB(20, 18, 34)
    main.BackgroundTransparency = 0.08
    main.BorderSizePixel = 0
    main.Active = true
    main.Draggable = false -- usaremos arrasto manual (mobile-friendly)
    main.Parent = gui

    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 18)
    mainCorner.Parent = main

    local mainStroke = Instance.new("UIStroke")
    mainStroke.Color = Color3.fromRGB(140, 90, 255)
    mainStroke.Thickness = 1.5
    mainStroke.Transparency = 0.4
    mainStroke.Parent = main

    -- Gradiente de fundo
    local grad = Instance.new("UIGradient")
    grad.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(28, 22, 52)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(14, 12, 26)),
    }
    grad.Rotation = 120
    grad.Parent = main

    -- Sombra
    local shadow = Instance.new("ImageLabel")
    shadow.Name = "Shadow"
    shadow.Image = "rbxassetid://6014261993"
    shadow.ImageColor3 = Color3.new(0, 0, 0)
    shadow.ImageTransparency = 0.55
    shadow.ScaleType = Enum.ScaleType.Slice
    shadow.SliceCenter = Rect.new(49, 49, 450, 450)
    shadow.Size = UDim2.new(1, 40, 1, 40)
    shadow.Position = UDim2.new(0, -20, 0, -20)
    shadow.BackgroundTransparency = 1
    shadow.ZIndex = 0
    shadow.Parent = main

    -- ================= TÍTULO / BARRA SUPERIOR =================
    local topBar = Instance.new("Frame")
    topBar.Size = UDim2.new(1, 0, 0, 44)
    topBar.BackgroundTransparency = 1
    topBar.Parent = main

    local title = Instance.new("TextLabel")
    title.Text = "💎  Auto Farm Gemas"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16
    title.TextColor3 = Color3.fromRGB(235, 225, 255)
    title.BackgroundTransparency = 1
    title.Size = UDim2.new(1, -90, 1, 0)
    title.Position = UDim2.new(0, 16, 0, 0)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = topBar

    -- Botão minimizar
    local minBtn = Instance.new("TextButton")
    minBtn.Text = "–"
    minBtn.Font = Enum.Font.GothamBold
    minBtn.TextSize = 18
    minBtn.TextColor3 = Color3.fromRGB(200, 190, 230)
    minBtn.BackgroundColor3 = Color3.fromRGB(45, 40, 70)
    minBtn.BorderSizePixel = 0
    minBtn.Size = UDim2.new(0, 28, 0, 28)
    minBtn.Position = UDim2.new(1, -66, 0, 8)
    minBtn.AutoButtonColor = false
    minBtn.Parent = topBar

    local minCorner = Instance.new("UICorner")
    minCorner.CornerRadius = UDim.new(1, 0)
    minCorner.Parent = minBtn

    -- Botão fechar
    local closeBtn = Instance.new("TextButton")
    closeBtn.Text = "✕"
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 14
    closeBtn.TextColor3 = Color3.fromRGB(255, 210, 210)
    closeBtn.BackgroundColor3 = Color3.fromRGB(70, 30, 40)
    closeBtn.BorderSizePixel = 0
    closeBtn.Size = UDim2.new(0, 28, 0, 28)
    closeBtn.Position = UDim2.new(1, -34, 0, 8)
    closeBtn.AutoButtonColor = false
    closeBtn.Parent = topBar

    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(1, 0)
    closeCorner.Parent = closeBtn

    -- Hover suave nos botões de topo
    local function hover(btn, normal, hoverColor)
        btn.MouseEnter:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = hoverColor}):Play()
        end)
        btn.MouseLeave:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = normal}):Play()
        end)
    end
    hover(minBtn, Color3.fromRGB(45, 40, 70), Color3.fromRGB(70, 60, 110))
    hover(closeBtn, Color3.fromRGB(70, 30, 40), Color3.fromRGB(120, 40, 55))

    -- ================= PAINEL DE STATUS =================
    local statusPanel = Instance.new("Frame")
    statusPanel.Size = UDim2.new(1, -32, 0, 52)
    statusPanel.Position = UDim2.new(0, 16, 0, 52)
    statusPanel.BackgroundColor3 = Color3.fromRGB(30, 26, 50)
    statusPanel.BackgroundTransparency = 0.2
    statusPanel.BorderSizePixel = 0
    statusPanel.Parent = main

    local spCorner = Instance.new("UICorner")
    spCorner.CornerRadius = UDim.new(0, 12)
    spCorner.Parent = statusPanel

    local statusDot = Instance.new("Frame")
    statusDot.Size = UDim2.new(0, 10, 0, 10)
    statusDot.Position = UDim2.new(0, 14, 0.5, -5)
    statusDot.BackgroundColor3 = Color3.fromRGB(120, 120, 140)
    statusDot.BorderSizePixel = 0
    statusDot.Parent = statusPanel

    local sdCorner = Instance.new("UICorner")
    sdCorner.CornerRadius = UDim.new(1, 0)
    sdCorner.Parent = statusDot

    local statusLabel = Instance.new("TextLabel")
    statusLabel.Text = "Desativado"
    statusLabel.Font = Enum.Font.GothamMedium
    statusLabel.TextSize = 13
    statusLabel.TextColor3 = Color3.fromRGB(200, 190, 220)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Position = UDim2.new(0, 32, 0, 0)
    statusLabel.Size = UDim2.new(1, -40, 0.5, 0)
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.Parent = statusPanel

    local gemCounter = Instance.new("TextLabel")
    gemCounter.Text = "Gemas coletadas: 0"
    gemCounter.Font = Enum.Font.GothamBold
    gemCounter.TextSize = 15
    gemCounter.TextColor3 = Color3.fromRGB(180, 220, 255)
    gemCounter.BackgroundTransparency = 1
    gemCounter.Position = UDim2.new(0, 32, 0.5, 0)
    gemCounter.Size = UDim2.new(1, -40, 0.5, 0)
    gemCounter.TextXAlignment = Enum.TextXAlignment.Left
    gemCounter.Parent = statusPanel

    -- ================= BOTÃO PRINCIPAL =================
    local mainBtn = Instance.new("TextButton")
    mainBtn.Name = "MainButton"
    mainBtn.Text = "💎  Auto Farm Gemas"
    mainBtn.Font = Enum.Font.GothamBold
    mainBtn.TextSize = 15
    mainBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    mainBtn.BackgroundColor3 = Color3.fromRGB(120, 70, 240)
    mainBtn.BorderSizePixel = 0
    mainBtn.Size = UDim2.new(1, -32, 0, 52)
    mainBtn.Position = UDim2.new(0, 16, 0, 118)
    mainBtn.AutoButtonColor = false
    mainBtn.Parent = main

    local mbCorner = Instance.new("UICorner")
    mbCorner.CornerRadius = UDim.new(0, 12)
    mbCorner.Parent = mainBtn

    local mbGrad = Instance.new("UIGradient")
    mbGrad.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(150, 90, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(90, 60, 220)),
    }
    mbGrad.Rotation = 90
    mbGrad.Parent = mainBtn

    local mbStroke = Instance.new("UIStroke")
    mbStroke.Color = Color3.fromRGB(200, 170, 255)
    mbStroke.Thickness = 1
    mbStroke.Transparency = 0.5
    mbStroke.Parent = mainBtn

    -- Indicador de carregamento (spinner)
    local spinner = Instance.new("Frame")
    spinner.Size = UDim2.new(0, 18, 0, 18)
    spinner.Position = UDim2.new(1, -34, 0.5, -9)
    spinner.BackgroundTransparency = 1
    spinner.Visible = false
    spinner.Parent = mainBtn

    local spinnerImg = Instance.new("ImageLabel")
    spinnerImg.Image = "rbxassetid://4965945816"
    spinnerImg.ImageColor3 = Color3.fromRGB(255, 255, 255)
    spinnerImg.BackgroundTransparency = 1
    spinnerImg.Size = UDim2.new(1, 0, 1, 0)
    spinnerImg.Parent = spinner

    local spinConn
    local function startSpinner()
        spinner.Visible = true
        if spinConn then spinConn:Disconnect() end
        spinConn = RunService.RenderStepped:Connect(function(dt)
            spinnerImg.Rotation = (spinnerImg.Rotation + dt * 360) % 360
        end)
    end
    local function stopSpinner()
        spinner.Visible = false
        if spinConn then spinConn:Disconnect(); spinConn = nil end
        spinnerImg.Rotation = 0
    end

    -- ================= RODAPÉ =================
    local footer = Instance.new("TextLabel")
    footer.Text = "Arraste para mover • Duplo clique no botão para alternar"
    footer.Font = Enum.Font.Gotham
    footer.TextSize = 10
    footer.TextColor3 = Color3.fromRGB(140, 130, 170)
    footer.BackgroundTransparency = 1
    footer.Size = UDim2.new(1, -32, 0, 20)
    footer.Position = UDim2.new(0, 16, 1, -28)
    footer.TextXAlignment = Enum.TextXAlignment.Center
    footer.Parent = main

    -- ================= FUNÇÕES DE ESTADO VISUAL =================
    local function setUIState(active)
        local targetColor = active and Color3.fromRGB(40, 200, 120) or Color3.fromRGB(120, 70, 240)
        local targetDot   = active and Color3.fromRGB(80, 255, 160) or Color3.fromRGB(120, 120, 140)
        local targetGrad0 = active and Color3.fromRGB(60, 230, 150) or Color3.fromRGB(150, 90, 255)
        local targetGrad1 = active and Color3.fromRGB(30, 180, 110) or Color3.fromRGB(90, 60, 220)

        TweenService:Create(mainBtn, TweenInfo.new(0.3), {BackgroundColor3 = targetColor}):Play()
        TweenService:Create(statusDot, TweenInfo.new(0.3), {BackgroundColor3 = targetDot}):Play()
        TweenService:Create(mbGrad, TweenInfo.new(0.3), {Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, targetGrad0),
            ColorSequenceKeypoint.new(1, targetGrad1),
        }}):Play()

        if active then
            statusLabel.Text = "FARM ATIVO"
            statusLabel.TextColor3 = Color3.fromRGB(160, 255, 200)
            mainBtn.Text = "⏹  Parar Auto Farm"
            statusDot.BackgroundColor3 = targetDot
        else
            statusLabel.Text = "Desativado"
            statusLabel.TextColor3 = Color3.fromRGB(200, 190, 220)
            mainBtn.Text = "💎  Auto Farm Gemas"
        end
    end

    -- ================= AÇÃO DO BOTÃO =================
    local busy = false
    mainBtn.MouseButton1Click:Connect(function()
        if busy then return end
        busy = true

        -- Animação de clique
        TweenService:Create(mainBtn, TweenInfo.new(0.08), {Size = UDim2.new(1, -40, 0, 48)}):Play()
        task.wait(0.09)
        TweenService:Create(mainBtn, TweenInfo.new(0.12), {Size = UDim2.new(1, -32, 0, 52)}):Play()

        if not State.Farming then
            -- Iniciando: mostra spinner
            startSpinner()
            mainBtn.Text = "⏳  Iniciando..."
            task.wait(0.4) -- pequena animação de carregamento
            startFarm()
            stopSpinner()
            setUIState(true)
        else
            stopFarm()
            setUIState(false)
        end

        busy = false
    end)

    -- Hover no botão principal (apenas desktop)
    mainBtn.MouseEnter:Connect(function()
        if not State.Farming then
            TweenService:Create(mainBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(140, 90, 255)}):Play()
        else
            TweenService:Create(mainBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(50, 220, 140)}):Play()
        end
    end)
    mainBtn.MouseLeave:Connect(function()
        if not State.Farming then
            TweenService:Create(mainBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(120, 70, 240)}):Play()
        else
            TweenService:Create(mainBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(40, 200, 120)}):Play()
        end
    end)

    -- ================= MINIMIZAR =================
    local minimized = false
    local originalSize = main.Size
    local originalPos  = main.Position

    local function setMinimized(state)
        minimized = state
        if state then
            TweenService:Create(main, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {
                Size = UDim2.new(0, 320, 0, 44)
            }):Play()
            statusPanel.Visible = false
            mainBtn.Visible = false
            footer.Visible = false
            minBtn.Text = "+"
        else
            TweenService:Create(main, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {
                Size = originalSize
            }):Play()
            task.delay(0.1, function()
                statusPanel.Visible = true
                mainBtn.Visible = true
                footer.Visible = true
            end)
            minBtn.Text = "–"
        end
    end

    minBtn.MouseButton1Click:Connect(function()
        setMinimized(not minimized)
    end)

    -- ================= FECHAR =================
    closeBtn.MouseButton1Click:Connect(function()
        stopFarm()
        stopSpinner()
        TweenService:Create(main, TweenInfo.new(0.2), {
            Size = UDim2.new(0, 0, 0, 0),
            BackgroundTransparency = 1
        }):Play()
        task.wait(0.22)
        gui:Destroy()
    end)

    -- ================= ARRASTO (mobile + desktop) =================
    local dragging, dragStart, startPos
    local function beginDrag(input)
        dragging = true
        dragStart = input.Position
        startPos = main.Position
    end
    local function updateDrag(input)
        if not dragging then return end
        local delta = input.Position - dragStart
        main.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
    local function endDrag() dragging = false end

    topBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            beginDrag(input)
        end
    end)
    topBar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
            updateDrag(input)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
            updateDrag(input)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            endDrag()
        end
    end)

    -- ================= ATUALIZAÇÃO DO CONTADOR =================
    local lastCount = -1
    task.spawn(function()
        while gui.Parent do
            if State.GemCount ~= lastCount then
                lastCount = State.GemCount
                gemCounter.Text = ("Gemas coletadas: %d"):format(State.GemCount)

                -- Pulso suave no contador
                TweenService:Create(gemCounter, TweenInfo.new(0.1), {
                    TextColor3 = Color3.fromRGB(255, 230, 150)
                }):Play()
                task.wait(0.12)
                TweenService:Create(gemCounter, TweenInfo.new(0.2), {
                    TextColor3 = Color3.fromRGB(180, 220, 255)
                }):Play()
            end
            task.wait(0.1)
        end
    end)

    return gui
end

-- ============================================================
-- INICIALIZAÇÃO (não inicia o farm!)
-- ============================================================
createUI()

print("[💎 AutoFarm] Interface carregada. Clique no botão para iniciar.")

--[[
    ========================================================================
    [한글 키보드 탈출 ⌨️] - 프리미엄 통합 스크립트 허브 (Hangul Keyboard Escape Hub)
    ========================================================================
    제작: Antigravity AI
    버전: v1.1.0 (유저 제보 피드백 반영 에디션)
    단축키: Insert 키 또는 RightControl 키 (UI 토글)
    대응 게임: +1 Speed Hangul Keyboard Escape | Pastel
    ========================================================================
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- ============ 게임 검증 (PlaceId 체크) ============
local targetPlaceId = 139083049292788
local isCorrectGame = (game.PlaceId == targetPlaceId)
if not isCorrectGame then
    warn("[Hangul Keyboard Escape Hub] 올바른 게임(139083049292788)이 아닙니다. 일부 파밍 기능이 작동하지 않을 수 있습니다.")
end

-- ============ 상태 설정 ============
local settings = {
    -- 자동 파밍 설정
    autoWalk = false,
    autoTreadmill = false,
    autoRebirth = false,
    autoClickUpgrades = false,
    
    -- 텔레포트 설정
    selectedStage = 1,
    autoCompleteObby = false,
    
    -- 플레이어 설정
    walkSpeedEnabled = false,
    walkSpeedValue = 16,
    jumpPowerEnabled = false,
    jumpPowerValue = 50,
    infJump = false,
    noclip = false,
    fly = false,
    flySpeed = 50,
    
    -- ESP 설정
    espEnabled = false,
    espBoxes = true,
    espNames = true,
    espTracers = false,
    espColor = Color3.fromRGB(255, 95, 150), -- 파스텔 핑크 색상 테마
    
    -- 기타 설정
    fullbright = false,
    lagReducer = false
}

-- ============ 유저 제공 및 실시간 분석 좌표 데이터 ============
local stageCoords = {
    [1] = Vector3.new(497.36, 6.62, 13.24),
    [2] = Vector3.new(638.48, 6.81, 13.33),
    [3] = Vector3.new(844.73, 6.53, 12.52),
    [4] = Vector3.new(1067.10, 5.64, 13.63),
    [5] = Vector3.new(1328.37, 4.88, 13.44),
    [6] = Vector3.new(1506.86, 48.18, 12.44),
    [7] = Vector3.new(1559.88, 32.23, 274.63),
    [8] = Vector3.new(1559.79, 278.49, 351.92),
    [9] = Vector3.new(1559.97, 277.90, 791.16),
    [10] = Vector3.new(1559.74, 297.93, 1583.05),
    [11] = Vector3.new(1559.57, 298.34, 1931.19),
    [12] = Vector3.new(1687.24, 297.72, 2270.87),
    [13] = Vector3.new(1686.23, 275.47, 2810.40),
    [14] = Vector3.new(1713.65, 727.21, 2809.52),
    [15] = Vector3.new(1900.60, 794.99, 2402.75)
}

-- ============ 유틸리티 함수 ============
local function notify(title, text, duration)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = title,
            Text = text,
            Icon = "rbxassetid://6023426926",
            Duration = duration or 3
        })
    end)
end

local function getRoot()
    local char = player.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
    local char = player.Character
    return char and char:FindFirstChild("Humanoid")
end

local function teleportTo(position)
    local root = getRoot()
    if root then
        pcall(function()
            -- 1. 텔레포트 전 물리 낙하 방지를 위해 캐릭터 임시 고정(Anchor)
            root.Anchored = true
            
            -- 2. StreamingEnabled 대응: 서버에 해당 영역 에셋 스트리밍 요청
            pcall(function()
                player:RequestStreamAroundAsync(position)
            end)
            
            -- 3. 좌표 이동
            root.CFrame = CFrame.new(position + Vector3.new(0, 3, 0))
            
            -- 4. 맵이 로드될 때까지 잠시 대기 (렉 및 낙사 방지)
            task.wait(0.35)
            
            -- 5. 고정 해제
            root.Anchored = false
        end)
    else
        notify("❌ 이동 실패", "캐릭터 위치를 찾을 수 없습니다.")
    end
end

-- ============ 게임 오브젝트 검색 유틸리티 ============

-- 1x 속도 러닝머신 검색
local function getTreadmill()
    local folder = workspace:FindFirstChild("Treadmills")
    if folder then
        local target = folder:FindFirstChild("NormalTreadmill_1")
        if target then return target end
        return folder:FindFirstChildOfClass("Model")
    end
    -- Fallback
    for _, v in pairs(workspace:GetDescendants()) do
        if v:IsA("Model") and (v.Name == "NormalTreadmill_1" or v.Name:find("Treadmill")) then
            return v
        end
    end
    return nil
end

-- 체크포인트 검색 (SurfaceGui 텍스트 파싱 기반 동적 스캔)
local function getCheckpoints()
    local checkpoints = {}
    
    -- 하드코딩 좌표 먼저 주입
    for stageNum, coord in pairs(stageCoords) do
        checkpoints[stageNum] = { Position = coord, IsHardcoded = true }
    end
    
    -- 실시간 맵 오브젝트 탐색 후 주입 (16단계 이상 동적 탐색용)
    pcall(function()
        local stageParts = workspace.Map.Parts.StageParts:GetChildren()
        for _, part in pairs(stageParts) do
            if part:IsA("BasePart") then
                local gui = part:FindFirstChildOfClass("SurfaceGui")
                local label = gui and gui:FindFirstChildOfClass("TextLabel")
                if label then
                    local num = tonumber(label.Text:match("%d+"))
                    if num then
                        -- 하드코딩되지 않은 새로운 단계가 발견되면 저장
                        if not checkpoints[num] then
                            checkpoints[num] = part
                        end
                    end
                end
            end
        end
    end)
    
    return checkpoints
end

-- 버튼 클릭 기능 통합 처리 (Roblox & Executor 환경 최적화)
local function clickButton(button)
    if button and button:IsA("GuiButton") then
        pcall(function() button:Activate() end)
        pcall(function()
            if getconnections then
                for _, conn in pairs(getconnections(button.MouseButton1Click)) do
                    conn:Fire()
                end
                for _, conn in pairs(getconnections(button.Activated)) do
                    conn:Fire()
                end
            end
        end)
    end
end

-- ============ 자동화 기능 루프 ============

-- 1. 자동 걷기 (humanoid:Move 방식 - 100% 정상 작동)
task.spawn(function()
    while true do
        if settings.autoWalk then
            pcall(function()
                local hum = getHumanoid()
                if hum then
                    -- 0.2초간 앞으로 걷기
                    local t = 0
                    while t < 0.2 and settings.autoWalk do
                        hum:Move(Vector3.new(0, 0, -1), true)
                        t = t + task.wait()
                    end
                    -- 0.2초간 뒤로 걷기
                    t = 0
                    while t < 0.2 and settings.autoWalk do
                        hum:Move(Vector3.new(0, 0, 1), true)
                        t = t + task.wait()
                    end
                end
            end)
        else
            task.wait(0.2)
        end
    end
end)

-- 2. 자동 러닝머신 훈련 (컨베이어 앵커 고정 + 앞으로 달리기)
task.spawn(function()
    local wasTraining = false
    while true do
        if settings.autoTreadmill then
            pcall(function()
                local treadmill = getTreadmill()
                local conveyor = treadmill and treadmill:FindFirstChild("Conveyor")
                local root = getRoot()
                local hum = getHumanoid()
                
                if conveyor and root then
                    -- 앵커가 풀렸거나 캐릭터가 처음 진입했을 때 텔레포트 후 앵커 고정
                    if not root.Anchored then
                        root.CFrame = conveyor.CFrame * CFrame.new(0, 2.5, 0)
                        root.Anchored = true
                    end
                    wasTraining = true
                    if hum then
                        hum:Move(Vector3.new(0, 0, -1), true)
                    end
                elseif treadmill and root then
                    if not root.Anchored then
                        root.CFrame = treadmill:GetPivot() * CFrame.new(0, 2.5, 0)
                        root.Anchored = true
                    end
                    wasTraining = true
                    if hum then
                        hum:Move(Vector3.new(0, 0, -1), true)
                    end
                end
            end)
            task.wait() -- 매 프레임 입력 유지
        else
            -- 훈련 종료 시 앵커 해제
            if wasTraining then
                pcall(function()
                    local root = getRoot()
                    if root then
                        root.Anchored = false
                    end
                end)
                wasTraining = false
            end
            task.wait(0.2)
        end
    end
end)

-- 3. 자동 환생 (Auto Rebirth)
local function canRebirth()
    local possible = false
    pcall(function()
        local label = player.PlayerGui.Hud.Canvas.BottomFrame.Bar_2:FindFirstChild("LevelLabel", true)
        if label then
            local current, required = label.Text:match("(%d+)%s*/%s*(%d+)")
            if not current then
                current, required = label.Text:match("(%d+)/(%d+)")
            end
            current = tonumber(current)
            required = tonumber(required)
            if current and required and current >= required then
                possible = true
            end
        end
    end)
    return possible
end

local function triggerRebirth()
    if not canRebirth() then return end
    
    pcall(function()
        local canvas = player.PlayerGui:WaitForChild("Hud"):WaitForChild("Canvas")
        
        -- 1. 환생 프레임 열기 (만약 닫혀있다면)
        local rebirthFrame = canvas:FindFirstChild("RebirthFrame")
        if rebirthFrame and not rebirthFrame.Visible then
            local openBtn = canvas:FindFirstChild("LeftFrame"):FindFirstChild("A"):FindFirstChild("Rebirth")
            if openBtn then
                clickButton(openBtn)
            end
        end
        
        task.wait(0.2)
        
        -- 2. 실제 환생 승인 버튼 클릭
        local rebirthBtn = rebirthFrame and rebirthFrame:FindFirstChild("Main"):FindFirstChild("Buttons"):FindFirstChild("RebirthButton")
        if rebirthBtn then
            clickButton(rebirthBtn)
            notify("자동 환생", "성공적으로 환생했습니다!")
        end
    end)
end

task.spawn(function()
    while true do
        if settings.autoRebirth then
            triggerRebirth()
        end
        task.wait(1.5)
    end
end)

-- 4. 자동 무료 배율 업그레이드 (Wins가 충족될 때 최선의 발판 자동 터치)
local lastTouchedMulti = nil
task.spawn(function()
    while true do
        if settings.autoClickUpgrades then
            pcall(function()
                local wins = player.leaderstats.Wins.Value
                local bestMulti = nil
                local bestWins = -1
                
                local config = require(game.ReplicatedStorage.Modules.Shared.Config.FreeSpeedMultiConfig)
                for name, data in pairs(config.Multipliers) do
                    if wins >= data.RequiredWins and data.RequiredWins > bestWins then
                        bestWins = data.RequiredWins
                        bestMulti = name
                    end
                end
                
                if bestMulti and bestMulti ~= lastTouchedMulti then
                    local model = workspace.FreeSpeedMultipliers:FindFirstChild(bestMulti)
                    local part = model and (model:FindFirstChild("Main") or model:FindFirstChildOfClass("BasePart"))
                    if part then
                        local root = getRoot()
                        if root then
                            local oldCF = root.CFrame
                            root.CFrame = part.CFrame + Vector3.new(0, 2, 0)
                            task.wait(0.15)
                            root.CFrame = oldCF
                            lastTouchedMulti = bestMulti
                            notify("배율 업그레이드", "무료 스피드 배율 [" .. bestMulti .. "]을(를) 장착했습니다!")
                        end
                    end
                end
            end)
        end
        task.wait(1.0) -- 배율 체크는 1초 주기로 충분합니다.
    end
end)

-- ============ 텔레포트 기능 ============

local completingObby = false
local function runAutoCompleteObby()
    if completingObby then return end
    completingObby = true
    
    notify("자동 클리어", "스테이지 자동 클리어를 시작합니다. 잠시 기다려 주세요...")
    
    local checkpoints = getCheckpoints()
    
    -- 정렬된 스테이지 목록 가져오기
    local sortedStages = {}
    for stageNum in pairs(checkpoints) do
        table.insert(sortedStages, stageNum)
    end
    table.sort(sortedStages)
    
    for _, stageNum in ipairs(sortedStages) do
        if not settings.autoCompleteObby then break end
        
        local checkpoint = checkpoints[stageNum]
        if checkpoint then
            teleportTo(checkpoint.Position)
            task.wait(0.6) -- 안티치트 우회용 안전 딜레이
        end
    end
    
    notify("자동 클리어", "자동 클리어 작동이 종료되었습니다.")
    completingObby = false
    settings.autoCompleteObby = false
end

-- ============ 물리 및 캐릭터 치트 적용 ============

RunService.PostSimulation:Connect(function()
    local hum = getHumanoid()
    if hum then
        if settings.walkSpeedEnabled then
            hum.WalkSpeed = settings.walkSpeedValue
        end
        if settings.jumpPowerEnabled then
            hum.JumpPower = settings.jumpPowerValue
        end
    end
end)

-- 무한 점프
UserInputService.JumpRequest:Connect(function()
    if settings.infJump then
        local hum = getHumanoid()
        if hum then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

-- 벽 통과 (Noclip)
RunService.Stepped:Connect(function()
    if settings.noclip and player.Character then
        for _, part in pairs(player.Character:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end
end)

-- 비행 (Fly)
local flyBV, flyBG
RunService.RenderStepped:Connect(function()
    local root = getRoot()
    local hum = getHumanoid()
    if settings.fly and root and hum then
        if not flyBV then
            flyBV = Instance.new("BodyVelocity")
            flyBV.MaxForce = Vector3.new(1e9, 1e9, 1e9)
            flyBV.Velocity = Vector3.new(0, 0, 0)
            flyBV.Parent = root
        end
        if not flyBG then
            flyBG = Instance.new("BodyGyro")
            flyBG.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
            flyBG.CFrame = root.CFrame
            flyBG.Parent = root
        end
        
        hum.PlatformStand = true
        local moveDir = Vector3.new(0, 0, 0)
        local camCF = camera.CFrame
        
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + camCF.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - camCF.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - camCF.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + camCF.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveDir = moveDir - Vector3.new(0, 1, 0) end
        
        flyBV.Velocity = moveDir.Unit * settings.flySpeed
        flyBG.CFrame = camCF
        if moveDir.Magnitude == 0 then flyBV.Velocity = Vector3.new(0, 0, 0) end
    else
        if flyBV then flyBV:Destroy() flyBV = nil end
        if flyBG then flyBG:Destroy() flyBG = nil end
        if hum and hum.PlatformStand then hum.PlatformStand = false end
    end
end)

-- Fullbright (조명 최댓값 고정)
local Lighting = game:GetService("Lighting")
local origAmbient = Lighting.Ambient
local origOutdoorAmbient = Lighting.OutdoorAmbient
local origBrightness = Lighting.Brightness
local origFogEnd = Lighting.FogEnd

RunService.RenderStepped:Connect(function()
    if settings.fullbright then
        Lighting.Ambient = Color3.fromRGB(255, 255, 255)
        Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
        Lighting.Brightness = 2
        Lighting.FogEnd = 999999
    end
end)

local function disableFullbright()
    Lighting.Ambient = origAmbient
    Lighting.OutdoorAmbient = origOutdoorAmbient
    Lighting.Brightness = origBrightness
    Lighting.FogEnd = origFogEnd
end

-- Lag Reducer (렉 줄이기 최적화 - 실시간 스트리밍 최적화 적용)
local function reduceLagForPart(v)
    if not settings.lagReducer then return end
    pcall(function()
        if v:IsA("Decal") or v:IsA("Texture") then
            v.Transparency = 1
        elseif v:IsA("ParticleEmitter") or v:IsA("Trail") then
            v.Enabled = false
        elseif v:IsA("PostEffect") then
            v.Enabled = false
        elseif v:IsA("BasePart") then
            v.CastShadow = false
        end
    end)
end

workspace.DescendantAdded:Connect(function(v)
    if settings.lagReducer then
        reduceLagForPart(v)
    end
end)

local origGlobalShadows = Lighting.GlobalShadows
local function applyLagReducer(state)
    settings.lagReducer = state
    pcall(function()
        if state then
            Lighting.GlobalShadows = false
            for _, v in pairs(workspace:GetDescendants()) do
                reduceLagForPart(v)
            end
        else
            Lighting.GlobalShadows = origGlobalShadows
        end
    end)
end

-- ============ ESP 기능 ============
local activePlayerESPs = {}

local function createPlayerESP(targetPlayer)
    if targetPlayer == player then return end
    
    local esp = {
        box = Drawing.new("Square"),
        name = Drawing.new("Text"),
        tracer = Drawing.new("Line")
    }
    
    esp.box.Thickness = 1.5
    esp.box.Filled = false
    esp.box.Color = settings.espColor
    
    esp.name.Size = 13
    esp.name.Center = true
    esp.name.Outline = true
    esp.name.Color = Color3.fromRGB(255, 255, 255)
    
    esp.tracer.Thickness = 1.0
    esp.tracer.Color = settings.espColor
    
    activePlayerESPs[targetPlayer] = esp
end

local function removePlayerESP(targetPlayer)
    local esp = activePlayerESPs[targetPlayer]
    if esp then
        esp.box:Destroy()
        esp.name:Destroy()
        esp.tracer:Destroy()
        activePlayerESPs[targetPlayer] = nil
    end
end

for _, p in pairs(Players:GetPlayers()) do createPlayerESP(p) end
Players.PlayerAdded:Connect(createPlayerESP)
Players.PlayerRemoving:Connect(removePlayerESP)

RunService.RenderStepped:Connect(function()
    for targetPlayer, esp in pairs(activePlayerESPs) do
        local char = targetPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        
        if settings.espEnabled and root and char:FindFirstChild("Humanoid") and char.Humanoid.Health > 0 then
            local pos, onScreen = camera:WorldToViewportPoint(root.Position)
            
            if onScreen then
                local sizeY = (camera:WorldToViewportPoint(root.Position + Vector3.new(0, 3, 0)).Y - camera:WorldToViewportPoint(root.Position - Vector3.new(0, 3.5, 0)).Y)
                local sizeX = sizeY * 0.6
                
                esp.box.Size = Vector2.new(sizeX, sizeY)
                esp.box.Position = Vector2.new(pos.X - sizeX / 2, pos.Y - sizeY / 2)
                esp.box.Visible = settings.espBoxes
                
                local speedInfo = ""
                pcall(function()
                    if targetPlayer:FindFirstChild("leaderstats") and targetPlayer.leaderstats:FindFirstChild("Speed") then
                        speedInfo = " [" .. tostring(targetPlayer.leaderstats.Speed.Value) .. "]"
                    end
                end)
                esp.name.Text = targetPlayer.Name .. speedInfo
                esp.name.Position = Vector2.new(pos.X, pos.Y - sizeY / 2 - 15)
                esp.name.Visible = settings.espNames
                
                esp.tracer.From = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y)
                esp.tracer.To = Vector2.new(pos.X, pos.Y + sizeY / 2)
                esp.tracer.Visible = settings.espTracers
            else
                esp.box.Visible = false
                esp.name.Visible = false
                esp.tracer.Visible = false
            end
        else
            esp.box.Visible = false
            esp.name.Visible = false
            esp.tracer.Visible = false
        end
    end
end)

-- ================================================================
--                      GUI 디자인 및 구현 (파스텔 테마)
-- ================================================================

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "HangulEscapeHubGUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = player:WaitForChild("PlayerGui")

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 560, 0, 380)
MainFrame.Position = UDim2.new(0.5, -280, 0.5, -190)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 10)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Thickness = 1.8
MainStroke.Color = Color3.fromRGB(255, 95, 150)
MainStroke.Transparency = 0.3
MainStroke.Parent = MainFrame

-- ============ 사이드바 ============
local Sidebar = Instance.new("Frame")
Sidebar.Name = "Sidebar"
Sidebar.Size = UDim2.new(0, 150, 1, 0)
Sidebar.BackgroundColor3 = Color3.fromRGB(28, 26, 36)
Sidebar.BorderSizePixel = 0
Sidebar.Parent = MainFrame

local SidebarCorner = Instance.new("UICorner")
SidebarCorner.CornerRadius = UDim.new(0, 10)
SidebarCorner.Parent = Sidebar

local SidebarTitle = Instance.new("TextLabel")
SidebarTitle.Size = UDim2.new(1, 0, 0, 45)
SidebarTitle.BackgroundTransparency = 1
SidebarTitle.Text = "⌨️ HANGUL ESCAPE"
SidebarTitle.TextColor3 = Color3.fromRGB(255, 240, 245)
SidebarTitle.TextSize = 12
SidebarTitle.Font = Enum.Font.GothamBold
SidebarTitle.Parent = Sidebar

local SidebarSeparator = Instance.new("Frame")
SidebarSeparator.Size = UDim2.new(0.85, 0, 0, 1.5)
SidebarSeparator.Position = UDim2.new(0.075, 0, 0, 45)
SidebarSeparator.BackgroundColor3 = Color3.fromRGB(255, 95, 150)
SidebarSeparator.BackgroundTransparency = 0.5
SidebarSeparator.BorderSizePixel = 0
SidebarSeparator.Parent = Sidebar

local SidebarList = Instance.new("Frame")
SidebarList.Size = UDim2.new(1, 0, 1, -55)
SidebarList.Position = UDim2.new(0, 0, 0, 55)
SidebarList.BackgroundTransparency = 1
SidebarList.Parent = Sidebar

local SidebarLayout = Instance.new("UIListLayout")
SidebarLayout.SortOrder = Enum.SortOrder.LayoutOrder
SidebarLayout.Padding = UDim.new(0, 5)
SidebarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
SidebarLayout.Parent = SidebarList

-- ============ 우측 콘텐츠 패널 ============
local ContentPanel = Instance.new("Frame")
ContentPanel.Name = "ContentPanel"
ContentPanel.Size = UDim2.new(1, -165, 1, -40)
ContentPanel.Position = UDim2.new(0, 157, 0, 35)
ContentPanel.BackgroundTransparency = 1
ContentPanel.Parent = MainFrame

local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, -150, 0, 30)
TopBar.Position = UDim2.new(0, 150, 0, 0)
TopBar.BackgroundTransparency = 1
TopBar.Parent = MainFrame

local ToggleLabel = Instance.new("TextLabel")
ToggleLabel.Size = UDim2.new(1, -80, 1, 0)
ToggleLabel.Position = UDim2.new(0, 10, 0, 0)
ToggleLabel.BackgroundTransparency = 1
ToggleLabel.Text = "[Insert / RCtrl] 키로 메뉴 열고 닫기"
ToggleLabel.TextColor3 = Color3.fromRGB(150, 140, 160)
ToggleLabel.TextSize = 11
ToggleLabel.Font = Enum.Font.Gotham
ToggleLabel.TextXAlignment = Enum.TextXAlignment.Left
ToggleLabel.Parent = TopBar

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 24, 0, 24)
CloseBtn.Position = UDim2.new(1, -30, 0.5, -12)
CloseBtn.BackgroundColor3 = Color3.fromRGB(240, 90, 90)
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.TextSize = 12
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.Parent = TopBar
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 5)

-- ============ 탭 전환 시스템 ============
local tabs = {}
local currentTab = nil

local function createTabContent(name)
    local frame = Instance.new("ScrollingFrame")
    frame.Name = name .. "Tab"
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundTransparency = 1
    frame.ScrollBarThickness = 3
    frame.ScrollBarImageColor3 = Color3.fromRGB(255, 95, 150)
    frame.Visible = false
    frame.Parent = ContentPanel
    
    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 6)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.Parent = frame
    
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        frame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 15)
    end)
    
    return frame
end

local function switchTab(tabName)
    for name, tabData in pairs(tabs) do
        if name == tabName then
            tabData.button.BackgroundColor3 = Color3.fromRGB(255, 95, 150)
            tabData.button.TextColor3 = Color3.fromRGB(255, 255, 255)
            tabData.content.Visible = true
            currentTab = tabName
        else
            tabData.button.BackgroundColor3 = Color3.fromRGB(36, 34, 46)
            tabData.button.TextColor3 = Color3.fromRGB(180, 170, 190)
            tabData.content.Visible = false
        end
    end
end

local function addTab(tabName, order, icon)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0.9, 0, 0, 32)
    button.BackgroundColor3 = Color3.fromRGB(36, 34, 46)
    button.Text = "  " .. icon .. "  " .. tabName
    button.TextColor3 = Color3.fromRGB(180, 170, 190)
    button.TextSize = 11
    button.Font = Enum.Font.GothamSemibold
    button.TextXAlignment = Enum.TextXAlignment.Left
    button.BorderSizePixel = 0
    button.LayoutOrder = order
    button.Parent = SidebarList
    
    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0, 6)
    buttonCorner.Parent = button
    
    local content = createTabContent(tabName)
    
    tabs[tabName] = {
        button = button,
        content = content
    }
    
    button.MouseButton1Click:Connect(function()
        switchTab(tabName)
    end)
    
    if order == 1 then
        switchTab(tabName)
    end
end

-- ============ UI 헬퍼 컴포넌트 ============

local function createSection(parent, text, order)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.95, 0, 0, 22)
    label.BackgroundTransparency = 1
    label.Text = "  " .. text
    label.TextColor3 = Color3.fromRGB(255, 95, 150)
    label.TextSize = 11
    label.Font = Enum.Font.GothamBold
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.LayoutOrder = order
    label.Parent = parent
end

local function createToggle(parent, text, order, default, callback)
    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(0.95, 0, 0, 35)
    bg.BackgroundColor3 = Color3.fromRGB(26, 25, 35)
    bg.BorderSizePixel = 0
    bg.LayoutOrder = order
    bg.Parent = parent
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 6)
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.7, 0, 1, 0)
    label.Position = UDim2.new(0, 10, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(220, 220, 230)
    label.TextSize = 12
    label.Font = Enum.Font.GothamSemibold
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = bg
    
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 45, 0, 22)
    btn.Position = UDim2.new(1, -55, 0.5, -11)
    btn.BackgroundColor3 = default and Color3.fromRGB(255, 95, 150) or Color3.fromRGB(48, 46, 60)
    btn.Text = ""
    btn.Parent = bg
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 11)
    
    local circle = Instance.new("Frame")
    circle.Size = UDim2.new(0, 18, 0, 18)
    circle.Position = default and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
    circle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    circle.BorderSizePixel = 0
    circle.Parent = btn
    Instance.new("UICorner", circle).CornerRadius = UDim.new(0, 9)
    
    local active = default
    btn.MouseButton1Click:Connect(function()
        active = not active
        callback(active)
        
        local targetColor = active and Color3.fromRGB(255, 95, 150) or Color3.fromRGB(48, 46, 60)
        local targetPos = active and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
        
        TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = targetColor}):Play()
        TweenService:Create(circle, TweenInfo.new(0.2), {Position = targetPos}):Play()
    end)
end

local function createSlider(parent, text, min, max, default, order, isDecimal, callback)
    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(0.95, 0, 0, 45)
    bg.BackgroundColor3 = Color3.fromRGB(26, 25, 35)
    bg.BorderSizePixel = 0
    bg.LayoutOrder = order
    bg.Parent = parent
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 6)
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.6, 0, 0, 20)
    label.Position = UDim2.new(0, 10, 0, 2)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(220, 220, 230)
    label.TextSize = 11
    label.Font = Enum.Font.GothamSemibold
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = bg
    
    local valueLabel = Instance.new("TextLabel")
    valueLabel.Size = UDim2.new(0.3, 0, 0, 20)
    valueLabel.Position = UDim2.new(0.7, -10, 0, 2)
    valueLabel.BackgroundTransparency = 1
    valueLabel.Text = isDecimal and string.format("%.1f", default) or tostring(default)
    valueLabel.TextColor3 = Color3.fromRGB(255, 95, 150)
    valueLabel.TextSize = 11
    valueLabel.Font = Enum.Font.GothamBold
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.Parent = bg
    
    local sliderBtn = Instance.new("TextButton")
    sliderBtn.Size = UDim2.new(0.9, 0, 0, 6)
    sliderBtn.Position = UDim2.new(0.05, 0, 0.7, -3)
    sliderBtn.BackgroundColor3 = Color3.fromRGB(48, 46, 60)
    sliderBtn.Text = ""
    sliderBtn.Parent = bg
    Instance.new("UICorner", sliderBtn).CornerRadius = UDim.new(0, 3)
    
    local sliderFill = Instance.new("Frame")
    sliderFill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    sliderFill.BackgroundColor3 = Color3.fromRGB(255, 95, 150)
    sliderFill.BorderSizePixel = 0
    sliderFill.Parent = sliderBtn
    Instance.new("UICorner", sliderFill).CornerRadius = UDim.new(0, 3)
    
    local sliding = false
    
    local function updateSlider(input)
        local pos = math.clamp((input.Position.X - sliderBtn.AbsolutePosition.X) / sliderBtn.AbsoluteSize.X, 0, 1)
        sliderFill.Size = UDim2.new(pos, 0, 1, 0)
        local value = min + (pos * (max - min))
        if isDecimal then
            value = math.round(value * 10) / 10
            valueLabel.Text = string.format("%.1f", value)
        else
            value = math.round(value)
            valueLabel.Text = tostring(value)
        end
        callback(value)
    end
    
    sliderBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            sliding = true
            updateSlider(input)
        end
    end)
    
    sliderBtn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            sliding = false
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if sliding and input.UserInputType == Enum.UserInputType.MouseMovement then
            updateSlider(input)
        end
    end)
end

local function createButton(parent, text, order, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.95, 0, 0, 32)
    btn.BackgroundColor3 = Color3.fromRGB(36, 34, 46)
    btn.BorderSizePixel = 0
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(250, 240, 245)
    btn.TextSize = 12
    btn.Font = Enum.Font.GothamBold
    btn.LayoutOrder = order
    btn.Parent = parent
    
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(255, 95, 150)}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(36, 34, 46)}):Play()
    end)
    
    btn.MouseButton1Click:Connect(function()
        callback()
    end)
end

-- ================================================================
--                       탭 구성 및 기능 세팅
-- ================================================================

addTab("자동 파밍", 1, "⚡")
addTab("텔레포트", 2, "🌀")
addTab("플레이어", 3, "👤")
addTab("기타", 4, "⚙️")

-- ---------------- 1. 자동 파밍 탭 ----------------
local tabFarm = tabs["자동 파밍"].content
createSection(tabFarm, "Auto Farming Options", 1)

createToggle(tabFarm, "자동 걷기 (Auto Walk - 제자리 걷기)", 2, settings.autoWalk, function(v)
    settings.autoWalk = v
    if v then notify("자동 걷기", "제자리 걷기 파밍이 켜졌습니다. 걸을 때마다 스피드가 오릅니다.") end
end)

createToggle(tabFarm, "자동 러닝머신 훈련 (Auto Treadmill)", 3, settings.autoTreadmill, function(v)
    settings.autoTreadmill = v
    if v then notify("자동 러닝머신", "러닝머신으로 이동하여 훈련 매크로를 시작합니다.") end
end)

createToggle(tabFarm, "자동 환생 (Auto Rebirth)", 4, settings.autoRebirth, function(v)
    settings.autoRebirth = v
    if v then notify("자동 환생", "스피드가 모이면 자동으로 환생합니다.") end
end)

createToggle(tabFarm, "자동 배율 업그레이드 (Auto Multiplier Upgrade)", 5, settings.autoClickUpgrades, function(v)
    settings.autoClickUpgrades = v
    if v then notify("자동 업그레이드", "Wins 조건이 충족되면 무료 배율 발판을 자동으로 밟아 업그레이드합니다.") end
end)


-- ---------------- 2. 텔레포트 탭 ----------------
local tabTeleport = tabs["텔레포트"].content
createSection(tabTeleport, "Obby Stage Teleports", 1)

createSlider(tabTeleport, "텔레포트 타겟 스테이지 (Stage 1-25)", 1, 25, settings.selectedStage, 2, false, function(v)
    settings.selectedStage = v
end)

createButton(tabTeleport, "선택한 스테이지로 이동 (Teleport to Stage)", 3, function()
    local checkpoints = getCheckpoints()
    local part = checkpoints[settings.selectedStage]
    if part then
        teleportTo(part.Position)
        notify("텔레포트 성공", "스테이지 " .. tostring(settings.selectedStage) .. "(으)로 이동했습니다.")
    else
        notify("텔레포트 실패", "스테이지 " .. tostring(settings.selectedStage) .. " 파트를 맵에서 찾을 수 없습니다.")
    end
end)

createToggle(tabTeleport, "자동 오비 클리어 (Auto Complete Obby)", 4, settings.autoCompleteObby, function(v)
    settings.autoCompleteObby = v
    if v then
        task.spawn(runAutoCompleteObby)
    end
end)


-- ---------------- 3. 플레이어 탭 ----------------
local tabPlayer = tabs["플레이어"].content
createSection(tabPlayer, "Player Character Settings", 1)

createToggle(tabPlayer, "이동 속도 고정 (WalkSpeed Change)", 2, settings.walkSpeedEnabled, function(v)
    settings.walkSpeedEnabled = v
    if not v then
        local hum = getHumanoid()
        if hum then hum.WalkSpeed = 16 end
    end
end)

createSlider(tabPlayer, "이동 속도 값 설정 (WalkSpeed)", 16, 300, settings.walkSpeedValue, 3, false, function(v)
    settings.walkSpeedValue = v
end)

createToggle(tabPlayer, "점프력 변경 (JumpPower Change)", 4, settings.jumpPowerEnabled, function(v)
    settings.jumpPowerEnabled = v
    if not v then
        local hum = getHumanoid()
        if hum then hum.JumpPower = 50 end
    end
end)

createSlider(tabPlayer, "점프력 값 설정 (JumpPower)", 50, 300, settings.jumpPowerValue, 5, false, function(v)
    settings.jumpPowerValue = v
end)

createToggle(tabPlayer, "무한 점프 활성화 (Infinite Jump)", 6, settings.infJump, function(v)
    settings.infJump = v
end)

createToggle(tabPlayer, "벽 통과 활성화 (Noclip)", 7, settings.noclip, function(v)
    settings.noclip = v
end)

createToggle(tabPlayer, "비행 기능 활성화 (Fly Mode)", 8, settings.fly, function(v)
    settings.fly = v
    if v then notify("비행 모드", "W/A/S/D로 이동, Space 키로 상승, Shift 키로 하강합니다.") end
end)

createSlider(tabPlayer, "비행 속도 설정 (Fly Speed)", 10, 200, settings.flySpeed, 9, false, function(v)
    settings.flySpeed = v
end)


-- ---------------- 4. 기타 탭 ----------------
local tabMisc = tabs["기타"].content
createSection(tabMisc, "Visuals & Rendering Hacks", 1)

createToggle(tabMisc, "밝기 고정 (Fullbright)", 2, settings.fullbright, function(v)
    settings.fullbright = v
    if not v then disableFullbright() end
end)

createToggle(tabMisc, "최적화 렉 줄이기 (Dynamic Lag Reducer)", 3, settings.lagReducer, function(v)
    applyLagReducer(v)
    if v then
        notify("최적화 켜짐", "그림자 제거 및 새로 로드되는 구역의 렉 요소를 실시간으로 제거합니다.")
    else
        notify("최적화 꺼짐", "렉 최적화 기능이 꺼졌습니다. (에셋 복구는 재접속 필요)")
    end
end)

createSection(tabMisc, "Player ESP Options", 4)

createToggle(tabMisc, "플레이어 ESP (Player ESP)", 5, settings.espEnabled, function(v)
    settings.espEnabled = v
end)

createToggle(tabMisc, "ESP 박스 표시 (Show Boxes)", 6, settings.espBoxes, function(v)
    settings.espBoxes = v
end)

createToggle(tabMisc, "ESP 이름/스피드 표시 (Show Names)", 7, settings.espNames, function(v)
    settings.espNames = v
end)

createToggle(tabMisc, "ESP 트레이서 선 표시 (Show Tracers)", 8, settings.espTracers, function(v)
    settings.espTracers = v
end)


-- ============ GUI 토글 및 닫기 바인딩 ============

CloseBtn.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
end)

local guiVisible = true
UserInputService.InputBegan:Connect(function(input, gpe)
    if not gpe and (input.KeyCode == Enum.KeyCode.Insert or input.KeyCode == Enum.KeyCode.RightControl) then
        guiVisible = not guiVisible
        MainFrame.Visible = guiVisible
    end
end)

notify("Hub Loaded!", "[Insert] 또는 [RCtrl] 키를 눌러 메뉴를 열고 닫을 수 있습니다.", 5)

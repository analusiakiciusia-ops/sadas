--[[
    MM2 Candy Farm - 稳定修复版
    修改要点：
    1. 先设置 SecureMode 再加载 Rayfield
    2. 使用 pcall 保护加载过程
    3. 糖果扫描加入距离限制与降频，避免每帧全图遍历
    4. 传送前做简单检测，避免在非角色状态强行传送
]]

-- 先开启 Rayfield 安全模式
getgenv().SecureMode = true

local success, Rayfield = pcall(function()
    return loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
end)

if not success or not Rayfield then
    warn("Rayfield 加载失败，脚本终止")
    return
end

local Window = Rayfield:CreateWindow({
    Name = "MM2 Candy Farm",
    LoadingTitle = "加载中...",
    LoadingSubtitle = "Candy Farm",
    Theme = "Default",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false
})

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

local autoFarmEnabled = false
local candyTarget = 50
local teleportDelay = 0.5
local scanRadius = 300 -- 只扫描角色周围 300 格内的糖果
local isBusy = false

-- 获取当前糖果数量（保守估算，读不到就返回 0）
local function getCandyCount()
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return 0 end
    local ok, result = pcall(function()
        for _, gui in ipairs(playerGui:GetChildren()) do
            for _, desc in ipairs(gui:GetDescendants()) do
                if desc:IsA("TextLabel") and desc.Text:match("^%d+$") then
                    local pName = desc.Parent and desc.Parent.Name or ""
                    if pName:lower():find("candy") or pName:lower():find("event") then
                        return tonumber(desc.Text)
                    end
                end
            end
        end
        return nil
    end)
    return ok and result or 0
end

-- 查找附近最近的糖果，限制扫描半径与频率
local function findNearestCandy()
    local char = LocalPlayer.Character
    if not char then return nil end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return nil end

    local myPos = root.Position
    local nearest, minDist = nil, math.huge

    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") or obj:IsA("MeshPart") then
            local name = obj.Name:lower()
            if name:find("candy") or name:find("sweet") or name:find("treat") then
                local dist = (obj.Position - myPos).Magnitude
                if dist < scanRadius and dist < minDist then
                    minDist = dist
                    nearest = obj
                end
            end
        end
    end
    return nearest
end

-- 安全传送：只改一次，不反复覆盖
local function safeTeleport(position)
    local char = LocalPlayer.Character
    if not char then return false end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    root.CFrame = CFrame.new(position + Vector3.new(0, 3, 0))
    return true
end

local function startAutoFarm()
    if isBusy then return end
    isBusy = true
    task.spawn(function()
        while autoFarmEnabled do
            local char = LocalPlayer.Character
            if not char or not char:FindFirstChild("HumanoidRootPart") then
                task.wait(1)
                continue
            end

            local count = getCandyCount()
            if count >= candyTarget then
                autoFarmEnabled = false
                Rayfield:Notify({
                    Title = "完成",
                    Content = "已收集 " .. count .. " 个糖果，自动停止",
                    Duration = 5
                })
                break
            end

            local candy = findNearestCandy()
            if candy then
                safeTeleport(candy.Position)
                task.wait(teleportDelay + math.random() * 0.2) -- 加入随机延迟，降低机械感
            else
                task.wait(1.5) -- 附近没有糖果就等久一点，减少无意义扫描
            end

            RunService.Heartbeat:Wait()
        end
        isBusy = false
    end)
end

local MainTab = Window:CreateTab("Candy Farm", 4483362458)

MainTab:CreateToggle({
    Name = "自动传送收集",
    CurrentValue = false,
    Flag = "AutoFarm",
    Callback = function(v)
        autoFarmEnabled = v
        if v then
            startAutoFarm()
        end
    end
})

MainTab:CreateSlider({
    Name = "目标数量",
    Range = {10, 300},
    Increment = 10,
    Suffix = "个",
    CurrentValue = 50,
    Flag = "Target",
    Callback = function(v)
        candyTarget = v
    end
})

MainTab:CreateSlider({
    Name = "传送延迟",
    Range = {0.3, 1.5},
    Increment = 0.1,
    Suffix = "秒",
    CurrentValue = 0.5,
    Flag = "Delay",
    Callback = function(v)
        teleportDelay = v
    end
})

MainTab:CreateSlider({
    Name = "扫描半径",
    Range = {100, 500},
    Increment = 50,
    Suffix = "格",
    CurrentValue = 300,
    Flag = "Radius",
    Callback = function(v)
        scanRadius = v
    end
})

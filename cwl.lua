--[[
    Murder Mystery 2 - Candy Auto Farm GUI
    Ładuje Rayfield (sirius.menu) i implementuje teleportację do cukierków + zbieranie do progu.
    Wymaga: executor z obsługą loadstring, HttpGet, Rayfield.
    Uwaga: skrypt może zostać wykryty przez anti-cheat Roblox/MM2. Używaj na własną odpowiedzialność.
]]

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "MM2 Candy Farm",
    LoadingTitle = "Ładowanie...",
    LoadingSubtitle = "Candy Auto Farm",
    Theme = "Default",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "MM2CandyFarm",
        FileName = "Config"
    },
    KeySystem = false
})

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

-- Stan skryptu
local autoFarmEnabled = false
local candyTarget = 50
local collectedCount = 0
local teleportDelay = 0.3
local isBusy = false

-- Funkcja pobierająca aktualną liczbę cukierków z GUI gry
local function getCandyCount()
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return collectedCount end
    
    -- Próba odczytu z typowego UI MM2 (może się różnić w zależności od eventu)
    local success, result = pcall(function()
        local mainGui = playerGui:FindFirstChild("MainGUI") or playerGui:FindFirstChild("HUD")
        if mainGui then
            for _, descendant in ipairs(mainGui:GetDescendants()) do
                if descendant:IsA("TextLabel") and descendant.Text:match("%d+") then
                    local parentName = descendant.Parent and descendant.Parent.Name or ""
                    if parentName:lower():find("candy") or parentName:lower():find("event") then
                        return tonumber(descendant.Text:match("%d+"))
                    end
                end
            end
        end
        return collectedCount
    end)
    
    if success and result then
        return result
    end
    return collectedCount
end

-- Funkcja znajdująca najbliższy cukierkowy obiekt w workspace
local function findNearestCandy()
    local nearest = nil
    local shortestDist = math.huge
    local char = LocalPlayer.Character
    if not char then return nil end
    
    local rootPart = char:FindFirstChild("HumanoidRootPart")
    if not rootPart then return nil end
    
    local myPos = rootPart.Position
    
    -- Szukaj obiektów zawierających "candy" w nazwie (typowe dla eventów MM2)
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") or obj:IsA("MeshPart") then
            local name = obj.Name:lower()
            if name:find("candy") or name:find("sweet") or name:find("treat") then
                local dist = (obj.Position - myPos).Magnitude
                if dist < shortestDist then
                    shortestDist = dist
                    nearest = obj
                end
            end
        end
    end
    
    return nearest, shortestDist
end

-- Teleportacja do pozycji z zachowaniem płynności
local function teleportTo(position)
    local char = LocalPlayer.Character
    if not char then return false end
    
    local rootPart = char:FindFirstChild("HumanoidRootPart")
    if not rootPart then return false end
    
    -- Ustawienie CFrame bezpośrednio (może powodować rubberbanding, ale jest najszybsze)
    rootPart.CFrame = CFrame.new(position + Vector3.new(0, 3, 0))
    return true
end

-- Główna pętla auto farmy
local function startAutoFarm()
    if isBusy then return end
    isBusy = true
    
    task.spawn(function()
        while autoFarmEnabled do
            local char = LocalPlayer.Character
            if not char or not char:FindFirstChild("HumanoidRootPart") then
                task.wait(0.5)
                continue
            end
            
            -- Sprawdź aktualny stan cukierków
            local currentCandy = getCandyCount()
            collectedCount = currentCandy
            
            -- Warunek stopu: osiągnięto cel
            if collectedCount >= candyTarget then
                autoFarmEnabled = false
                Rayfield:Notify({
                    Title = "Cel osiągnięty",
                    Content = "Zebrano " .. collectedCount .. " cukierków. Zatrzymano.",
                    Duration = 5
                })
                break
            end
            
            -- Znajdź najbliższy cukierka
            local candy, dist = findNearestCandy()
            
            if candy then
                -- Teleportuj się do cukierka
                teleportTo(candy.Position)
                task.wait(teleportDelay)
                
                -- Po teleportacji sprawdź, czy cukier zniknął (zebrany)
                -- Jeśli nie zniknął w ciągu X sekund, spróbuj ponownie
                local retry = 0
                while candy.Parent and retry < 3 do
                    task.wait(0.2)
                    retry = retry + 1
                end
            else
                -- Brak cukierków w zasięgu – czekaj
                task.wait(1)
            end
            
            RunService.Heartbeat:Wait()
        end
        isBusy = false
    end)
end

-- Zakładka główna
local MainTab = Window:CreateTab("Candy Farm", 4483362458)

MainTab:CreateToggle({
    Name = "Auto Farm (Teleport + Zbieranie)",
    CurrentValue = false,
    Flag = "AutoFarmToggle",
    Callback = function(value)
        autoFarmEnabled = value
        if value then
            collectedCount = getCandyCount()
            startAutoFarm()
        end
    end
})

MainTab:CreateSlider({
    Name = "Cel (liczba cukierków)",
    Range = {10, 500},
    Increment = 10,
    Suffix = "szt.",
    CurrentValue = 50,
    Flag = "CandyTargetSlider",
    Callback = function(value)
        candyTarget = value
    end
})

MainTab:CreateSlider({
    Name = "Opóźnienie teleportacji",
    Range = {0.1, 1.0},
    Increment = 0.05,
    Suffix = "s",
    CurrentValue = 0.3,
    Flag = "TeleportDelaySlider",
    Callback = function(value)
        teleportDelay = value
    end
})

MainTab:CreateButton({
    Name = "Reset licznika",
    Callback = function()
        collectedCount = 0
        Rayfield:Notify({
            Title = "Reset",
            Content = "Licznik cukierków zresetowany.",
            Duration = 3
        })
    end
})

MainTab:CreateButton({
    Name = "Pokaż aktualny stan",
    Callback = function()
        local count = getCandyCount()
        Rayfield:Notify({
            Title = "Stan cukierków",
            Content = "Aktualnie: " .. count .. " / Cel: " .. candyTarget,
            Duration = 4
        })
    end
})

-- Zakładka informacyjna
local InfoTab = Window:CreateTab("Info", 4483362458)

InfoTab:CreateLabel("Instrukcja:")
InfoTab:CreateLabel("1. Włącz 'Auto Farm'")
InfoTab:CreateLabel("2. Skrypt teleportuje się do cukierków i je zbiera")
InfoTab:CreateLabel("3. Po osiągnięciu celu automatycznie się zatrzyma")
InfoTab:CreateLabel("")
InfoTab:CreateLabel("Uwaga: Cukierki muszą istnieć w workspace.")
InfoTab:CreateLabel("Jeśli skrypt nie znajduje cukierków, upewnij się, że event jest aktywny.")

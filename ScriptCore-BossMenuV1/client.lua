-- ScriptCore.dk - Boss Menu Client Side
-- Resource-name lock
local currentResourceName = GetCurrentResourceName()
local requiredResourceName = Config.RequiredResourceName or "ScriptCore-BossMenuV1"
if currentResourceName ~= requiredResourceName then
    print(("^1[ScriptCore BossMenu]^7 Resource skal hedde ^2%s^7. Den hedder lige nu ^1%s^7, derfor starter client ikke."):format(requiredResourceName, currentResourceName))
    return
end

local ESX = exports["es_extended"]:getSharedObject()
local tabletObj = nil
local PlayerData = {}
local menuOpen = false

CreateThread(function()
    while not ESX.GetPlayerData().job do
        Wait(100)
    end
    PlayerData = ESX.GetPlayerData()
end)

RegisterNetEvent('esx:playerLoaded', function(xPlayer)
    PlayerData = xPlayer
end)

RegisterNetEvent('esx:setJob', function(job)
    PlayerData.job = job

    -- Hvis man skifter job mens bossmenuen er åben, så reloades data automatisk.
    if menuOpen then
        Wait(300)
        ESX.TriggerServerCallback('scriptcore_boss:getData', function(newData)
            if newData then
                SendNUIMessage({ action = "refresh", data = newData })
            else
                CloseBossMenu()
            end
        end)
    end
end)

function CloseBossMenu()
    menuOpen = false
    SetNuiFocus(false, false)
    StopAnimTask(PlayerPedId(), Config.TabletAnimDict, Config.TabletAnimName, 1.0)
    if tabletObj then
        DeleteEntity(tabletObj)
        tabletObj = nil
    end
    SendNUIMessage({ action = "forceClose" })
end

function OpenBossMenu()
    ESX.TriggerServerCallback('scriptcore_boss:getData', function(data)
        if not data then
            TriggerEvent('ox_lib:notify', {type = 'error', description = 'Ingen adgang eller job-data blev ikke fundet.', duration = 5000})
            return
        end

        local playerPed = PlayerPedId()
        if tabletObj then DeleteEntity(tabletObj) tabletObj = nil end
        StopAnimTask(playerPed, Config.TabletAnimDict, Config.TabletAnimName, 1.0)

        RequestAnimDict(Config.TabletAnimDict)
        while not HasAnimDictLoaded(Config.TabletAnimDict) do Wait(1) end
        TaskPlayAnim(playerPed, Config.TabletAnimDict, Config.TabletAnimName, 8.0, -8.0, -1, 50, 0, false, false, false)

        local model = GetHashKey(Config.TabletModel)
        RequestModel(model)
        while not HasModelLoaded(model) do Wait(1) end
        tabletObj = CreateObject(model, 0.0, 0.0, 0.0, true, true, false)
        AttachEntityToEntity(tabletObj, playerPed, GetPedBoneIndex(playerPed, Config.TabletBone), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)

        menuOpen = true
        SetNuiFocus(true, true)
        SendNUIMessage({
            action = "open",
            money = data.money,
            employees = data.employees,
            jobGrades = data.jobGrades,
            logs = data.logs,
            jobName = data.jobName,
            jobLabel = data.jobLabel,
            gradeLabel = data.gradeLabel,
            onlineCount = data.onlineCount
        })
    end)
end

RegisterCommand(Config.Command, function()
    -- Brug serveren som sandhed, så /setjob Police -> Brand ikke fejler pga. gammel client-cache.
    ESX.TriggerServerCallback('scriptcore_boss:canOpen', function(canOpen)
        if canOpen then
            OpenBossMenu()
        else
            TriggerEvent('ox_lib:notify', {type = 'error', description = 'Ingen adgang.', duration = 5000})
        end
    end)
end)

RegisterNUICallback("close", function(data, cb)
    CloseBossMenu()
    cb('ok')
end)

RegisterNUICallback("finance", function(data, cb)
    ESX.TriggerServerCallback('scriptcore_boss:finance', function(result)
        cb(result or { ok = false })
    end, data)
end)

RegisterNUICallback("changeRank", function(data, cb)
    ESX.TriggerServerCallback('scriptcore_boss:changeRank', function(result)
        cb(result or { ok = false })
    end, data)
end)

RegisterNUICallback("fire", function(data, cb)
    ESX.TriggerServerCallback('scriptcore_boss:fire', function(result)
        cb(result or { ok = false })
    end, data)
end)

RegisterNUICallback("hire", function(data, cb)
    ESX.TriggerServerCallback('scriptcore_boss:hire', function(result)
        cb(result or { ok = false })
    end, data)
end)


RegisterNUICallback("createRank", function(data, cb)
    ESX.TriggerServerCallback('scriptcore_boss:createRank', function(result)
        cb(result or { ok = false })
    end, data)
end)

RegisterNUICallback("deleteRank", function(data, cb)
    ESX.TriggerServerCallback('scriptcore_boss:deleteRank', function(result)
        cb(result or { ok = false })
    end, data)
end)

RegisterNUICallback("refreshData", function(data, cb)
    ESX.TriggerServerCallback('scriptcore_boss:getData', function(newData)
        cb(newData or false)
    end)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        if tabletObj then DeleteEntity(tabletObj) tabletObj = nil end
        SetNuiFocus(false, false)
    end
end)

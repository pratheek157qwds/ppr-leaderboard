local uiOpen = false

RegisterCommand(Config.CommandName, function()
    if not uiOpen then
        TriggerServerEvent('ppr-leaderboard:server:getLeaderboard')
    else
        CloseLeaderboard()
    end
end, false)

if Config.UseKeybind then
    RegisterKeyMapping(Config.CommandName, 'Open Economy Leaderboard', 'keyboard', Config.Keybind)
end

RegisterNetEvent('ppr-leaderboard:client:openLeaderboard', function(playersData, uiTitle)
    uiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'showLeaderboard',
        players = playersData,
        serverTitle = uiTitle
    })
end)

function CloseLeaderboard()
    uiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = 'hideLeaderboard'
    })
end

RegisterNUICallback('close', function(data, cb)
    uiOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)

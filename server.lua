local CachedLeaderboard = {}
local LastCacheTime = 0

local function HexToDec(hexVal)
    if not hexVal then return nil end
    hexVal = hexVal:gsub("steam:", "")
    local dec = tonumber(hexVal, 16)
    if dec then
        return string.format("%.0f", dec)
    end
    return nil
end

local function ExtractIds(identifier)
    if not identifier then return nil, nil end
    local steam = nil
    local discord = nil
    if identifier:find("steam:") then
        steam = identifier:gsub("steam:", "")
    elseif identifier:find("discord:") then
        discord = identifier:gsub("discord:", "")
    end
    return steam, discord
end

local function FetchSteamAvatar(steamHex, cb)
    local steamDec = HexToDec(steamHex)
    if not steamDec or Config.SteamAPIKey == "" then
        cb(nil)
        return
    end

    local url = string.format("https://api.steampowered.com/ISteamUser/GetPlayerSummaries/v0002/?key=%s&steamids=%s", Config.SteamAPIKey, steamDec)
    PerformHttpRequest(url, function(statusCode, response, headers)
        if statusCode == 200 and response then
            local data = json.decode(response)
            if data and data.response and data.response.players and data.response.players[1] then
                cb(data.response.players[1].avatarfull)
                return
            end
        end
        cb(nil)
    end, "GET")
end

local function FetchDiscordAvatar(discordId, cb)
    if not discordId or Config.DiscordBotToken == "" then
        cb(nil)
        return
    end

    local url = string.format("https://discord.com/api/v10/users/%s", discordId)
    PerformHttpRequest(url, function(statusCode, response, headers)
        if statusCode == 200 and response then
            local data = json.decode(response)
            if data and data.avatar then
                local animated = data.avatar:sub(1, 2) == "a_"
                local format = animated and "gif" or "png"
                local avatarUrl = string.format("https://cdn.discordapp.com/avatars/%s/%s.%s", discordId, data.avatar, format)
                cb(avatarUrl)
                return
            end
        end
        cb(nil)
    end, "GET", "", {["Authorization"] = "Bot " .. Config.DiscordBotToken})
end

local function FetchAvatar(steamHex, discordId, dbMugshot, cb)
    if Config.AvatarSource == 'mugshot' then
        cb(dbMugshot ~= "" and dbMugshot or nil)
    elseif Config.AvatarSource == 'steam' and steamHex then
        FetchSteamAvatar(steamHex, cb)
    elseif Config.AvatarSource == 'discord' and discordId then
        FetchDiscordAvatar(discordId, cb)
    else
        cb(Config.DefaultAvatar ~= "" and Config.DefaultAvatar or nil)
    end
end

local function QuerySavings(cb)
    if not Config.Savings.Enabled or Config.Savings.Type ~= 'table' then
        cb({})
        return
    end

    local query = string.format("SELECT `%s` as owner, `%s` as amount FROM `%s`", 
        Config.Savings.OwnerColumn, Config.Savings.ValueColumn, Config.Savings.TableName)
    
    if Config.Savings.QueryFilter and Config.Savings.QueryFilter ~= "" then
        query = query .. " WHERE " .. Config.Savings.QueryFilter
    end

    MySQL.query(query, {}, function(results)
        local savingsMap = {}
        if results then
            for _, row in ipairs(results) do
                if row.owner then
                    savingsMap[tostring(row.owner)] = tonumber(row.amount) or 0
                end
            end
        end
        cb(savingsMap)
    end)
end

local function FetchLeaderboardData()
    print("[ppr-leaderboard] Refreshing economy leaderboard cache...")
    
    QuerySavings(function(savingsMap)
        if Config.Framework == 'qb-core' then
            local query = "SELECT citizenid, charinfo, money, license"
            if Config.AvatarSource == 'mugshot' and Config.MugshotColumn ~= 'charinfo' then
                query = query .. ", `" .. Config.MugshotColumn .. "`"
            end
            query = query .. " FROM players"

            MySQL.query(query, {}, function(results)
                if not results then return end

                local tempPlayers = {}
                for _, row in ipairs(results) do
                    local charinfo = json.decode(row.charinfo or "{}")
                    local money = json.decode(row.money or "{}")
                    
                    local firstname = charinfo.firstname or "Citizen"
                    local lastname = charinfo.lastname or ""
                    local name = firstname .. " " .. lastname

                    local cash = tonumber(money.cash) or 0
                    local bank = tonumber(money.bank) or 0
                    
                    local savings = 0
                    if Config.Savings.Enabled then
                        if Config.Savings.Type == 'column' and charinfo[Config.Savings.ColumnName] then
                            savings = tonumber(charinfo[Config.Savings.ColumnName]) or 0
                        elseif Config.Savings.Type == 'table' then
                            savings = savingsMap[row.citizenid] or 0
                        end
                    end

                    local steamHex = row.license or ""
                    local discordId = nil
                    
                    local dbMugshot = ""
                    if Config.AvatarSource == 'mugshot' then
                        if Config.MugshotColumn == 'charinfo' then
                            dbMugshot = charinfo.mugshot or charinfo.mugshotbase64 or ""
                        else
                            dbMugshot = row[Config.MugshotColumn] or ""
                        end
                    end
                    
                    table.insert(tempPlayers, {
                        identifier = row.citizenid,
                        name = name,
                        cash = cash,
                        bank = bank,
                        savings = savings,
                        steam = steamHex,
                        discord = discordId,
                        mugshot = dbMugshot,
                        avatar = ""
                    })
                end

                table.sort(tempPlayers, function(a, b)
                    return (a.cash + a.bank + a.savings) > (b.cash + b.bank + b.savings)
                end)

                local topTen = {}
                local count = math.min(10, #tempPlayers)
                local resolved = 0

                if count == 0 then
                    CachedLeaderboard = {}
                    LastCacheTime = os.time()
                    return
                end

                for i = 1, count do
                    local p = tempPlayers[i]
                    topTen[i] = p

                    FetchAvatar(p.steam, p.discord, p.mugshot, function(avatarUrl)
                        topTen[i].avatar = avatarUrl or ""
                        resolved = resolved + 1

                        if resolved == count then
                            CachedLeaderboard = topTen
                            LastCacheTime = os.time()
                            print("[ppr-leaderboard] Cache successfully updated with " .. count .. " profiles.")
                        end
                    end)
                end
            end)

        elseif Config.Framework == 'esx' then
            local query = "SELECT identifier, firstname, lastname, accounts"
            if Config.AvatarSource == 'mugshot' then
                query = query .. ", `" .. Config.MugshotColumn .. "`"
            end
            query = query .. " FROM users"

            MySQL.query(query, {}, function(results)
                if not results then return end

                local tempPlayers = {}
                for _, row in ipairs(results) do
                    local firstname = row.firstname or "Citizen"
                    local lastname = row.lastname or ""
                    local name = firstname .. " " .. lastname

                    local accounts = json.decode(row.accounts or "{}")
                    local cash = 0
                    local bank = 0

                    if accounts.money then cash = tonumber(accounts.money) or 0 end
                    if accounts.bank then bank = tonumber(accounts.bank) or 0 end

                    if cash == 0 and bank == 0 then
                        cash = tonumber(row.money) or 0
                        bank = tonumber(row.bank) or 0
                    end

                    local savings = 0
                    if Config.Savings.Enabled then
                        if Config.Savings.Type == 'column' and row[Config.Savings.ColumnName] then
                            savings = tonumber(row[Config.Savings.ColumnName]) or 0
                        elseif Config.Savings.Type == 'table' then
                            savings = savingsMap[row.identifier] or 0
                        end
                    end

                    local steamHex = row.identifier or ""
                    local discordId = nil
                    
                    local dbMugshot = ""
                    if Config.AvatarSource == 'mugshot' then
                        dbMugshot = row[Config.MugshotColumn] or ""
                    end

                    table.insert(tempPlayers, {
                        identifier = row.identifier,
                        name = name,
                        cash = cash,
                        bank = bank,
                        savings = savings,
                        steam = steamHex,
                        discord = discordId,
                        mugshot = dbMugshot,
                        avatar = ""
                    })
                end

                table.sort(tempPlayers, function(a, b)
                    return (a.cash + a.bank + a.savings) > (b.cash + b.bank + b.savings)
                end)

                local topTen = {}
                local count = math.min(10, #tempPlayers)
                local resolved = 0

                if count == 0 then
                    CachedLeaderboard = {}
                    LastCacheTime = os.time()
                    return
                end

                for i = 1, count do
                    local p = tempPlayers[i]
                    topTen[i] = p

                    FetchAvatar(p.steam, p.discord, p.mugshot, function(avatarUrl)
                        topTen[i].avatar = avatarUrl or ""
                        resolved = resolved + 1

                        if resolved == count then
                            CachedLeaderboard = topTen
                            LastCacheTime = os.time()
                            print("[ppr-leaderboard] Cache successfully updated with " .. count .. " profiles.")
                        end
                    end)
                end
            end)

        elseif Config.Framework == 'custom' then
            MySQL.query(Config.CustomQueries.GetTopPlayers, {}, function(results)
                if not results then return end

                local topTen = {}
                local count = math.min(10, #results)
                local resolved = 0

                if count == 0 then
                    CachedLeaderboard = {}
                    LastCacheTime = os.time()
                    return
                end

                for i = 1, count do
                    local row = results[i]
                    local steamHex, discordId = ExtractIds(row.identifier)

                    topTen[i] = {
                        identifier = row.identifier,
                        name = row.name or "Citizen",
                        cash = tonumber(row.cash) or 0,
                        bank = tonumber(row.bank) or 0,
                        savings = tonumber(row.savings) or 0,
                        steam = steamHex,
                        discord = discordId,
                        mugshot = row.avatar or "",
                        avatar = ""
                    }

                    FetchAvatar(steamHex, discordId, topTen[i].mugshot, function(avatarUrl)
                        topTen[i].avatar = avatarUrl or ""
                        resolved = resolved + 1

                        if resolved == count then
                            CachedLeaderboard = topTen
                            LastCacheTime = os.time()
                            print("[ppr-leaderboard] Custom Query Cache updated successfully.")
                        end
                    end)
                end
            end)
        end
    end)
end

Citizen.CreateThread(function()
    Citizen.Wait(5000)
    FetchLeaderboardData()

    while true do
        Citizen.Wait(Config.CacheTimer * 60 * 1000)
        FetchLeaderboardData()
    end
end)

RegisterCommand('refreshleaderboard', function(source, args, rawCommand)
    if source == 0 or IsPlayerAceAllowed(source, "admin") then
        FetchLeaderboardData()
        if source > 0 then
            TriggerClientEvent('chat:addMessage', source, { args = { '^2[Leaderboard]', 'Database cache refresh triggered.' } })
        end
    else
        TriggerClientEvent('chat:addMessage', source, { args = { '^1[Error]', 'You do not have permission to run this command.' } })
    end
end, false)

RegisterNetEvent('ppr-leaderboard:server:getLeaderboard', function()
    local src = source
    
    if #CachedLeaderboard == 0 or (os.time() - LastCacheTime) > (Config.CacheTimer * 60) then
        FetchLeaderboardData()
        Citizen.Wait(1200)
    end

    TriggerClientEvent('ppr-leaderboard:client:openLeaderboard', src, CachedLeaderboard, Config.UiTitle)
end)

Config = {}

Config.Framework = 'qb-core'
Config.CommandName = 'leaderboard'
Config.UseKeybind = true
Config.Keybind = 'F9'
Config.UiTitle = 'PPR LEADERBOARD'
Config.CacheTimer = 15

Config.Savings = {
    Enabled = true,
    Type = 'table',
    ColumnName = 'savings',
    TableName = 'bank_accounts',
    ValueColumn = 'amount',
    OwnerColumn = 'citizenid',
    QueryFilter = "type = 'savings'"
}

Config.AvatarSource = 'mugshot'
Config.MugshotColumn = 'mugshot'
Config.SteamAPIKey = ''
Config.DiscordBotToken = ''
Config.DefaultAvatar = ''

Config.CustomQueries = {
    GetTopPlayers = [[
        SELECT 
            identifier, 
            name, 
            cash, 
            bank, 
            IFNULL(savings, 0) as savings,
            avatar
        FROM (
            SELECT 
                u.identifier, 
                CONCAT(u.firstname, ' ', u.lastname) as name, 
                u.cash, 
                u.bank, 
                s.amount as savings,
                u.mugshot as avatar
            FROM users u
            LEFT JOIN bank_accounts s ON u.identifier = s.owner AND s.type = 'savings'
        ) t
        ORDER BY (cash + bank + savings) DESC 
        LIMIT 10
    ]]
}

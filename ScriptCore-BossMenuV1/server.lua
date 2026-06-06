-- ScriptCore.dk - Boss Menu Server Side
-- Resource-name lock
local currentResourceName = GetCurrentResourceName()
local requiredResourceName = Config.RequiredResourceName or "ScriptCore-BossMenuV1"
if currentResourceName ~= requiredResourceName then
    print(("^1[ScriptCore BossMenu]^7 Resource skal hedde ^2%s^7. Den hedder lige nu ^1%s^7, derfor starter scriptet ikke."):format(requiredResourceName, currentResourceName))
    return
end

local ESX = exports["es_extended"]:getSharedObject()

local function DebugPrint(message)
    if Config.Debug then
        print(('[ScriptCore BossMenu] %s'):format(message))
    end
end

local function GetPlayerJob(xPlayer)
    if not xPlayer then return nil end
    if xPlayer.getJob then
        local ok, job = pcall(function() return xPlayer.getJob() end)
        if ok and job then return job end
    end
    return xPlayer.job
end

local function GetIdentifier(xPlayer)
    if not xPlayer then return nil end
    if xPlayer.identifier then return xPlayer.identifier end
    if xPlayer.getIdentifier then
        local ok, identifier = pcall(function() return xPlayer.getIdentifier() end)
        if ok then return identifier end
    end
    return nil
end

local function GetCharacterName(xPlayer)
    if not xPlayer then return "Ukendt" end

    local firstName = xPlayer.get and xPlayer.get('firstName') or nil
    local lastName = xPlayer.get and xPlayer.get('lastName') or nil
    if firstName or lastName then
        return ((firstName or "") .. " " .. (lastName or "")):gsub("^%s+", ""):gsub("%s+$", "")
    end

    if xPlayer.getName then
        local ok, name = pcall(function() return xPlayer.getName() end)
        if ok and name and name ~= "" then return name end
    end

    if xPlayer.name and xPlayer.name ~= "" then return xPlayer.name end
    if xPlayer.source then return GetPlayerName(xPlayer.source) or "Ukendt" end
    return "Ukendt"
end

local function GetJobGradeNumber(job)
    if not job then return 0 end
    return tonumber(job.grade) or tonumber(job.grade_level) or 0
end

local function IsBossGradeName(job)
    if not job then return false end
    local gradeName = tostring(job.grade_name or job.gradeName or job.name or ""):lower()
    return gradeName == "boss" or gradeName == "chef"
end


local function GetPlayerCash(xPlayer)
    if not xPlayer then return 0 end
    if xPlayer.getAccount then
        local ok, account = pcall(function() return xPlayer.getAccount('money') end)
        if ok and account and account.money then return tonumber(account.money) or 0 end
    end
    if xPlayer.getMoney then
        local ok, money = pcall(function() return xPlayer.getMoney() end)
        if ok then return tonumber(money) or 0 end
    end
    return 0
end

local function RemovePlayerCash(xPlayer, amount)
    if xPlayer.removeAccountMoney then
        local ok = pcall(function() xPlayer.removeAccountMoney('money', amount) end)
        if ok then return true end
    end
    if xPlayer.removeMoney then
        local ok = pcall(function() xPlayer.removeMoney(amount) end)
        if ok then return true end
    end
    return false
end

local function AddPlayerCash(xPlayer, amount)
    if xPlayer.addAccountMoney then
        local ok = pcall(function() xPlayer.addAccountMoney('money', amount) end)
        if ok then return true end
    end
    if xPlayer.addMoney then
        local ok = pcall(function() xPlayer.addMoney(amount) end)
        if ok then return true end
    end
    return false
end

local function GetSocietyName(jobName)
    local cfg = Config.BossJobs and Config.BossJobs[jobName]
    return (cfg and cfg.society) or ('society_' .. jobName)
end

local AddonAccountDataHasOwner = nil

local function HasAddonAccountDataOwnerColumn(cb)
    if AddonAccountDataHasOwner ~= nil then
        return cb(AddonAccountDataHasOwner)
    end

    MySQL.Async.fetchScalar([[
        SELECT COUNT(*)
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'addon_account_data'
          AND COLUMN_NAME = 'owner'
    ]], {}, function(count)
        AddonAccountDataHasOwner = (tonumber(count) or 0) > 0
        cb(AddonAccountDataHasOwner)
    end)
end

local function EnsureSocietyAccount(jobName, cb)
    local society = GetSocietyName(jobName)
    local label = (Config.BossJobs[jobName] and Config.BossJobs[jobName].label) or jobName

    MySQL.Async.execute('INSERT IGNORE INTO addon_account (name, label, shared) VALUES (@name, @label, 1)', {
        ['@name'] = society,
        ['@label'] = label
    }, function()
        HasAddonAccountDataOwnerColumn(function(hasOwner)
            local query = hasOwner
                and 'INSERT IGNORE INTO addon_account_data (account_name, money, owner) VALUES (@name, 0, NULL)'
                or  'INSERT IGNORE INTO addon_account_data (account_name, money) VALUES (@name, 0)'

            MySQL.Async.execute(query, {
                ['@name'] = society
            }, function()
                cb(society)
            end)
        end)
    end)
end

local function GetSocietyMoneyFromSQL(society, cb)
    HasAddonAccountDataOwnerColumn(function(hasOwner)
        local query = hasOwner
            and 'SELECT money FROM addon_account_data WHERE account_name = @account AND (owner IS NULL OR owner = "") LIMIT 1'
            or  'SELECT money FROM addon_account_data WHERE account_name = @account LIMIT 1'

        MySQL.Async.fetchScalar(query, {
            ['@account'] = society
        }, function(money)
            cb(tonumber(money) or 0)
        end)
    end)
end

local function SaveSocietyMoney(society, money, cb)
    money = tonumber(money) or 0

    HasAddonAccountDataOwnerColumn(function(hasOwner)
        local query = hasOwner
            and 'UPDATE addon_account_data SET money = @money WHERE account_name = @account AND (owner IS NULL OR owner = "")'
            or  'UPDATE addon_account_data SET money = @money WHERE account_name = @account'

        MySQL.Async.execute(query, {
            ['@money'] = money,
            ['@account'] = society
        }, function(rowsChanged)
            if (tonumber(rowsChanged) or 0) > 0 then
                if cb then cb(true, money) end
                return
            end

            local insertQuery = hasOwner
                and 'INSERT INTO addon_account_data (account_name, money, owner) VALUES (@account, @money, NULL)'
                or  'INSERT INTO addon_account_data (account_name, money) VALUES (@account, @money)'

            MySQL.Async.execute(insertQuery, {
                ['@money'] = money,
                ['@account'] = society
            }, function()
                if cb then cb(true, money) end
            end)
        end)
    end)
end

local function SetAddonAccountCacheMoney(account, money)
    if account then
        account.money = tonumber(money) or 0
    end
end


local function AddBossLog(jobName, action, message, actorPlayer, targetName, targetIdentifier, amount)
    MySQL.Async.execute('INSERT INTO scriptcore_boss_logs (job_name, action, message, actor_name, actor_identifier, target_name, target_identifier, amount) VALUES (@job, @action, @message, @actorName, @actorId, @targetName, @targetId, @amount)', {
        ['@job'] = jobName,
        ['@action'] = action,
        ['@message'] = message,
        ['@actorName'] = actorPlayer and GetCharacterName(actorPlayer) or 'System',
        ['@actorId'] = actorPlayer and (GetIdentifier(actorPlayer) or 'unknown') or 'system',
        ['@targetName'] = targetName,
        ['@targetId'] = targetIdentifier,
        ['@amount'] = amount
    })
end

local function GetBossLogs(jobName, cb)
    MySQL.Async.fetchAll('SELECT id, job_name, action, message, actor_name, actor_identifier, target_name, target_identifier, amount, DATE_FORMAT(created_at, "%Y-%m-%d %H:%i:%s") as created_at FROM scriptcore_boss_logs WHERE job_name = @job ORDER BY id DESC LIMIT 50', {
        ['@job'] = jobName
    }, function(logs)
        cb(logs or {})
    end)
end

local function LogTransaction(jobName, txType, amount, xPlayer)
    MySQL.Async.execute('INSERT INTO scriptcore_boss_transactions (job_name, type, amount, player_name, player_id) VALUES (@job, @type, @amount, @name, @id)', {
        ['@job'] = jobName,
        ['@type'] = txType,
        ['@amount'] = tonumber(amount) or 0,
        ['@name'] = GetCharacterName(xPlayer),
        ['@id'] = GetIdentifier(xPlayer) or 'unknown'
    })
end

local function PersistUserJob(identifier, jobName, grade, cb)
    if not identifier then
        if cb then cb(false) end
        return
    end

    MySQL.Async.execute('UPDATE users SET job = @job, job_grade = @grade WHERE identifier = @identifier', {
        ['@job'] = jobName,
        ['@grade'] = tonumber(grade) or 0,
        ['@identifier'] = identifier
    }, function(rowsChanged)
        DebugPrint(('Gemte job: %s -> %s grade %s'):format(identifier, jobName, tostring(grade)))
        if cb then cb((rowsChanged or 0) > 0) end
    end)
end

-- RANGS LIGGER I SQL:
-- Scriptet opretter ikke politi/brand/ambulance-rangs.
-- Boss-adgang styres i Config.BossJobs[job].bossGrade.
-- Eksempel: bossGrade = 11 giver adgang til grade 11 og højere.
local function CheckBoss(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb(false, nil, nil) end

    local job = GetPlayerJob(xPlayer)
    if not job or not job.name then return cb(false, xPlayer, job) end

    local bossConfig = Config.BossJobs[job.name]
    if not bossConfig then return cb(false, xPlayer, job) end

    local playerGrade = GetJobGradeNumber(job)
    local requiredGrade = tonumber(bossConfig.bossGrade or bossConfig.grade or bossConfig.minGrade)

    if requiredGrade ~= nil then
        return cb(playerGrade >= requiredGrade, xPlayer, job)
    end

    -- Fallback hvis du glemmer bossGrade i configen.
    -- Så virker ESX-rangnavne som boss/chef stadig.
    if IsBossGradeName(job) then
        return cb(true, xPlayer, job)
    end

    return cb(false, xPlayer, job)
end

local function GradeExists(grades, rank)
    if #grades == 0 then return true end
    for _, grade in ipairs(grades) do
        if tonumber(grade.grade) == tonumber(rank) then
            return true
        end
    end
    return false
end

local function GetGradeLabel(grades, rank)
    for _, grade in ipairs(grades) do
        if tonumber(grade.grade) == tonumber(rank) then
            return grade.label or grade.name or "Ukendt"
        end
    end
    return "Ukendt"
end



local function NormalizeGradeName(label, grade)
    local name = tostring(label or ('rank_' .. tostring(grade))):lower()
    name = name:gsub('æ', 'ae'):gsub('ø', 'oe'):gsub('å', 'aa')
    name = name:gsub('[^%w_]+', '_'):gsub('^_+', ''):gsub('_+$', '')
    if name == '' then name = 'rank_' .. tostring(grade) end
    return name
end

local function RefreshBossDataCallback(source, cb, delay)
    Citizen.SetTimeout(delay or 250, function()
        BuildBossData(source, function(newData)
            cb({ ok = true, data = newData })
        end)
    end)
end

local function InsertOrUpdateEmployee(employees, employeeMap, employee)
    if not employee.id then return end

    if employeeMap[employee.id] then
        local existing = employeeMap[employee.id]
        existing.name = employee.name or existing.name
        existing.grade = employee.grade or existing.grade
        existing.gradeLabel = employee.gradeLabel or existing.gradeLabel
        existing.online = employee.online or existing.online
        return
    end

    table.insert(employees, employee)
    employeeMap[employee.id] = employee
end

local function MergeOnlinePlayers(jobName, grades, employees, employeeMap)
    for _, playerId in ipairs(ESX.GetPlayers()) do
        local onlinePlayer = ESX.GetPlayerFromId(playerId)
        local onlineJob = GetPlayerJob(onlinePlayer)

        if onlinePlayer and onlineJob and onlineJob.name == jobName then
            local identifier = GetIdentifier(onlinePlayer)
            local rank = GetJobGradeNumber(onlineJob)

            InsertOrUpdateEmployee(employees, employeeMap, {
                id = identifier,
                name = GetCharacterName(onlinePlayer),
                grade = rank,
                gradeLabel = onlineJob.grade_label or onlineJob.gradeLabel or GetGradeLabel(grades, rank),
                online = true
            })
        end
    end
end

local function BuildBossData(source, cb)
    CheckBoss(source, function(isBoss, xPlayer, job)
        if not isBoss or not xPlayer or not job then return cb(nil) end

        local jobName = job.name

        MySQL.Async.fetchAll('SELECT grade, name, label, salary FROM job_grades WHERE job_name = @job ORDER BY grade ASC', {
            ['@job'] = jobName
        }, function(grades)
            grades = grades or {}

            MySQL.Async.fetchAll('SELECT identifier, firstname, lastname, job_grade FROM users WHERE job = @job ORDER BY job_grade DESC', {
                ['@job'] = jobName
            }, function(users)
                local employees = {}
                local employeeMap = {}

                if users and #users > 0 then
                    for _, user in ipairs(users) do
                        local rank = tonumber(user.job_grade) or 0
                        local firstName = user.firstname or "Ukendt"
                        local lastName = user.lastname or ""

                        InsertOrUpdateEmployee(employees, employeeMap, {
                            id = user.identifier,
                            name = (firstName .. " " .. lastName):gsub("%s+$", ""),
                            grade = rank,
                            gradeLabel = GetGradeLabel(grades, rank),
                            online = false
                        })
                    end
                end

                -- ESX job-skift kan være opdateret online før SQL-tabellen er gemt.
                -- Derfor flettes online spillere ind i listen, så fx Police -> Brand vises med det samme.
                MergeOnlinePlayers(jobName, grades, employees, employeeMap)

                table.sort(employees, function(a, b)
                    if tonumber(a.grade) == tonumber(b.grade) then
                        return tostring(a.name) < tostring(b.name)
                    end
                    return (tonumber(a.grade) or 0) > (tonumber(b.grade) or 0)
                end)

                EnsureSocietyAccount(jobName, function(society)
                    TriggerEvent('esx_addonaccount:getSharedAccount', society, function(account)
                        GetSocietyMoneyFromSQL(society, function(sqlMoney)
                            SetAddonAccountCacheMoney(account, sqlMoney)
                            GetBossLogs(jobName, function(logs)
                                cb({
                                    money = sqlMoney,
                                    employees = employees,
                                    jobGrades = grades,
                                    logs = logs,
                                    jobName = jobName,
                                    jobLabel = job.label or (Config.BossJobs[jobName] and Config.BossJobs[jobName].label) or jobName,
                                    gradeLabel = job.grade_label or job.gradeLabel or GetGradeLabel(grades, GetJobGradeNumber(job)),
                                    onlineCount = #ESX.GetPlayers()
                                })
                            end)
                        end)
                    end)
                end)
            end)
        end)
    end)
end

ESX.RegisterServerCallback('scriptcore_boss:canOpen', function(source, cb)
    CheckBoss(source, function(isBoss)
        cb(isBoss)
    end)
end)

ESX.RegisterServerCallback('scriptcore_boss:getData', function(source, cb)
    BuildBossData(source, cb)
end)

ESX.RegisterServerCallback('scriptcore_boss:finance', function(source, cb, data)
    CheckBoss(source, function(isBoss, xPlayer, job)
        if not isBoss or not xPlayer or not job then return cb({ ok = false, error = 'Ingen adgang.' }) end

        local amount = tonumber(data and data.amount)
        if not amount or amount <= 0 then return cb({ ok = false, error = 'Ugyldigt beløb.' }) end

        EnsureSocietyAccount(job.name, function(society)
            TriggerEvent('esx_addonaccount:getSharedAccount', society, function(account)
                if not account then return cb({ ok = false, error = 'Society konto blev ikke fundet.' }) end

                GetSocietyMoneyFromSQL(society, function(currentMoney)
                    if data.type == "deposit" then
                        local cash = GetPlayerCash(xPlayer)

                        if cash < amount then
                            TriggerClientEvent('ox_lib:notify', source, {type = 'error', description = "Du har ikke nok penge.", duration = 5000})
                            return cb({ ok = false, error = 'Ikke nok penge.' })
                        end

                        if not RemovePlayerCash(xPlayer, amount) then
                            return cb({ ok = false, error = 'Kunne ikke fjerne penge fra spilleren.' })
                        end

                        local newMoney = currentMoney + amount
                        SaveSocietyMoney(society, newMoney, function()
                            SetAddonAccountCacheMoney(account, newMoney)
                            LogTransaction(job.name, 'deposit', amount, xPlayer)
                            AddBossLog(job.name, 'deposit', ('Indsatte %s kr. på kontoen.'):format(amount), xPlayer, nil, nil, amount)
                            TriggerClientEvent('ox_lib:notify', source, {type = 'success', description = "Du indsatte " .. amount .. " kr.", duration = 5000})

                            Citizen.SetTimeout(150, function()
                                BuildBossData(source, function(newData)
                                    cb({ ok = true, data = newData })
                                end)
                            end)
                        end)
                    elseif data.type == "withdraw" then
                        if currentMoney < amount then
                            TriggerClientEvent('ox_lib:notify', source, {type = 'error', description = "Der er ikke nok penge på kontoen.", duration = 5000})
                            return cb({ ok = false, error = 'Ikke nok society penge.' })
                        end

                        local newMoney = currentMoney - amount
                        SaveSocietyMoney(society, newMoney, function()
                            SetAddonAccountCacheMoney(account, newMoney)

                            if not AddPlayerCash(xPlayer, amount) then
                                SaveSocietyMoney(society, currentMoney, function()
                                    SetAddonAccountCacheMoney(account, currentMoney)
                                    cb({ ok = false, error = 'Kunne ikke give penge til spilleren.' })
                                end)
                                return
                            end

                            LogTransaction(job.name, 'withdraw', amount, xPlayer)
                            AddBossLog(job.name, 'withdraw', ('Hævede %s kr. fra kontoen.'):format(amount), xPlayer, nil, nil, amount)
                            TriggerClientEvent('ox_lib:notify', source, {type = 'success', description = "Du hævede " .. amount .. " kr.", duration = 5000})

                            Citizen.SetTimeout(150, function()
                                BuildBossData(source, function(newData)
                                    cb({ ok = true, data = newData })
                                end)
                            end)
                        end)
                    else
                        return cb({ ok = false, error = 'Ugyldig handling.' })
                    end
                end)
            end)
        end)
    end)
end)

ESX.RegisterServerCallback('scriptcore_boss:hire', function(source, cb, data)
    CheckBoss(source, function(isBoss, xPlayer, job)
        if not isBoss or not xPlayer or not job then return cb({ ok = false, error = 'Ingen adgang.' }) end

        local targetId = tonumber(data and data.targetId)
        local rankId = tonumber(data and data.rank) or 0
        local targetPlayer = targetId and ESX.GetPlayerFromId(targetId) or nil

        if not targetPlayer then
            TriggerClientEvent('ox_lib:notify', source, {type = 'error', description = "Spilleren blev ikke fundet.", duration = 5000})
            return cb({ ok = false, error = 'Spilleren blev ikke fundet.' })
        end

        MySQL.Async.fetchAll('SELECT grade, name, label, salary FROM job_grades WHERE job_name = @job ORDER BY grade ASC', {
            ['@job'] = job.name
        }, function(grades)
            grades = grades or {}
            if not GradeExists(grades, rankId) then
                TriggerClientEvent('ox_lib:notify', source, {type = 'error', description = "Rangen findes ikke til dette job.", duration = 5000})
                return cb({ ok = false, error = 'Rangen findes ikke.' })
            end

            local targetIdentifier = GetIdentifier(targetPlayer)
            targetPlayer.setJob(job.name, rankId)

            -- Tving SQL til at blive opdateret med det samme, så ansættelsen bliver gemt og vises efter restart/relog.
            PersistUserJob(targetIdentifier, job.name, rankId, function()
                AddBossLog(job.name, 'hire', ('Ansatte %s som %s.'):format(GetCharacterName(targetPlayer), GetGradeLabel(grades, rankId)), xPlayer, GetCharacterName(targetPlayer), targetIdentifier, nil)
                TriggerClientEvent('ox_lib:notify', source, {type = 'success', description = "Du ansatte en ny medarbejder.", duration = 5000})
                TriggerClientEvent('ox_lib:notify', targetId, {type = 'success', description = "Du blev ansat som " .. (job.label or job.name), duration = 5000})

                Citizen.SetTimeout(250, function()
                    BuildBossData(source, function(newData)
                        cb({ ok = true, data = newData })
                    end)
                end)
            end)
        end)
    end)
end)

ESX.RegisterServerCallback('scriptcore_boss:changeRank', function(source, cb, data)
    CheckBoss(source, function(isBoss, xPlayer, job)
        if not isBoss or not xPlayer or not job then return cb({ ok = false, error = 'Ingen adgang.' }) end

        local targetIdentifier = data and data.targetId
        local newRank = tonumber(data and data.rank)
        if not targetIdentifier or newRank == nil then return cb({ ok = false, error = 'Mangler data.' }) end

        MySQL.Async.fetchAll('SELECT grade, name, label, salary FROM job_grades WHERE job_name = @job ORDER BY grade ASC', {
            ['@job'] = job.name
        }, function(grades)
            grades = grades or {}
            if not GradeExists(grades, newRank) then
                TriggerClientEvent('ox_lib:notify', source, {type = 'error', description = "Rangen findes ikke til dette job.", duration = 5000})
                return cb({ ok = false, error = 'Rangen findes ikke.' })
            end

            local targetPlayer = ESX.GetPlayerFromIdentifier(targetIdentifier)
            if targetPlayer then
                targetPlayer.setJob(job.name, newRank)
            end

            PersistUserJob(targetIdentifier, job.name, newRank, function()
                AddBossLog(job.name, 'change_rank', ('Ændrede rang til %s.'):format(GetGradeLabel(grades, newRank)), xPlayer, targetPlayer and GetCharacterName(targetPlayer) or 'Offline spiller', targetIdentifier, nil)
                TriggerClientEvent('ox_lib:notify', source, {type = 'success', description = "Rang ændret og gemt.", duration = 5000})

                Citizen.SetTimeout(250, function()
                    BuildBossData(source, function(newData)
                        cb({ ok = true, data = newData })
                    end)
                end)
            end)
        end)
    end)
end)

ESX.RegisterServerCallback('scriptcore_boss:fire', function(source, cb, data)
    CheckBoss(source, function(isBoss, xPlayer, job)
        if not isBoss or not xPlayer or not job then return cb({ ok = false, error = 'Ingen adgang.' }) end

        local targetIdentifier = data and data.targetId
        if not targetIdentifier then return cb({ ok = false, error = 'Mangler spiller.' }) end

        local targetPlayer = ESX.GetPlayerFromIdentifier(targetIdentifier)
        if targetPlayer then
            targetPlayer.setJob('unemployed', 0)
            TriggerClientEvent('ox_lib:notify', targetPlayer.source, {type = 'error', description = "Du blev fyret.", duration = 5000})
        end

        PersistUserJob(targetIdentifier, 'unemployed', 0, function()
            AddBossLog(job.name, 'fire', 'Fyrede en medarbejder.', xPlayer, targetPlayer and GetCharacterName(targetPlayer) or 'Offline spiller', targetIdentifier, nil)
            TriggerClientEvent('ox_lib:notify', source, {type = 'success', description = "Medarbejder fyret og gemt.", duration = 5000})

            Citizen.SetTimeout(250, function()
                BuildBossData(source, function(newData)
                    cb({ ok = true, data = newData })
                end)
            end)
        end)
    end)
end)


ESX.RegisterServerCallback('scriptcore_boss:createRank', function(source, cb, data)
    CheckBoss(source, function(isBoss, xPlayer, job)
        if not isBoss or not xPlayer or not job then return cb({ ok = false, error = 'Ingen adgang.' }) end

        local grade = tonumber(data and data.grade)
        local label = tostring(data and data.label or ''):gsub('^%s+', ''):gsub('%s+$', '')
        local salary = tonumber(data and data.salary) or 0

        if grade == nil or grade < 0 then
            return cb({ ok = false, error = 'Ugyldigt rang nummer.' })
        end

        if label == '' then
            return cb({ ok = false, error = 'Skriv et rang navn.' })
        end

        if salary < 0 then salary = 0 end
        local name = NormalizeGradeName(label, grade)

        MySQL.Async.fetchAll('SELECT grade FROM job_grades WHERE job_name = @job AND grade = @grade LIMIT 1', {
            ['@job'] = job.name,
            ['@grade'] = grade
        }, function(existing)
            if existing and #existing > 0 then
                return cb({ ok = false, error = 'Der findes allerede en rang med det nummer.' })
            end

            MySQL.Async.execute('INSERT INTO job_grades (job_name, grade, name, label, salary) VALUES (@job, @grade, @name, @label, @salary)', {
                ['@job'] = job.name,
                ['@grade'] = grade,
                ['@name'] = name,
                ['@label'] = label,
                ['@salary'] = salary
            }, function()
                AddBossLog(job.name, 'create_rank', ('Oprettede rangen %s med grade %s.'):format(label, grade), xPlayer, label, tostring(grade), nil)
                TriggerClientEvent('ox_lib:notify', source, {type = 'success', description = 'Rang oprettet og gemt.', duration = 5000})
                RefreshBossDataCallback(source, cb, 150)
            end)
        end)
    end)
end)

ESX.RegisterServerCallback('scriptcore_boss:deleteRank', function(source, cb, data)
    CheckBoss(source, function(isBoss, xPlayer, job)
        if not isBoss or not xPlayer or not job then return cb({ ok = false, error = 'Ingen adgang.' }) end

        local grade = tonumber(data and data.grade)
        if grade == nil then return cb({ ok = false, error = 'Ugyldigt rang nummer.' }) end

        local bossConfig = Config.BossJobs and Config.BossJobs[job.name]
        local bossGrade = bossConfig and tonumber(bossConfig.bossGrade or bossConfig.grade or bossConfig.minGrade)
        if bossGrade ~= nil and grade == bossGrade then
            return cb({ ok = false, error = 'Du kan ikke slette den rang, som har adgang til BossMenu i config.lua.' })
        end

        local currentGrade = GetJobGradeNumber(job)
        if currentGrade == grade then
            return cb({ ok = false, error = 'Du kan ikke slette din egen aktive rang.' })
        end

        MySQL.Async.fetchAll('SELECT COUNT(*) as count FROM users WHERE job = @job AND job_grade = @grade', {
            ['@job'] = job.name,
            ['@grade'] = grade
        }, function(result)
            local count = result and result[1] and tonumber(result[1].count) or 0
            if count > 0 then
                return cb({ ok = false, error = 'Der er ansatte med den rang. Skift deres rang eller fyr dem først.' })
            end

            MySQL.Async.execute('DELETE FROM job_grades WHERE job_name = @job AND grade = @grade', {
                ['@job'] = job.name,
                ['@grade'] = grade
            }, function(rowsChanged)
                if not rowsChanged or rowsChanged < 1 then
                    return cb({ ok = false, error = 'Rangen blev ikke fundet.' })
                end

                AddBossLog(job.name, 'delete_rank', ('Slettede rangen med grade %s.'):format(grade), xPlayer, tostring(grade), tostring(grade), nil)
                TriggerClientEvent('ox_lib:notify', source, {type = 'success', description = 'Rang slettet.', duration = 5000})
                RefreshBossDataCallback(source, cb, 150)
            end)
        end)
    end)
end)

-- Gamle events beholdes, så ældre UI-kald ikke crasher. Den nye UI bruger callbacks ovenfor.
RegisterServerEvent('scriptcore_boss:finance')
AddEventHandler('scriptcore_boss:finance', function(data) end)
RegisterServerEvent('scriptcore_boss:hire')
AddEventHandler('scriptcore_boss:hire', function(data) end)
RegisterServerEvent('scriptcore_boss:changeRank')
AddEventHandler('scriptcore_boss:changeRank', function(data) end)
RegisterServerEvent('scriptcore_boss:fire')
AddEventHandler('scriptcore_boss:fire', function(data) end)
RegisterServerEvent('scriptcore_boss:createRank')
AddEventHandler('scriptcore_boss:createRank', function(data) end)
RegisterServerEvent('scriptcore_boss:deleteRank')
AddEventHandler('scriptcore_boss:deleteRank', function(data) end)

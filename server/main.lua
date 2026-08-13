local Config = lib.require "config"
local Framework = lib.require "server.modules.framework"
local Outcomes = lib.require "server.modules.outcomes"
local Admin = lib.require "server.modules.admin"
local debugPrint = lib.require "shared.debugPrint"

local Registry = Config.registry
local LockConfig = Config.lock
local GameSettings = Config.gameSettings
local BUSY_PREFIX <const> = "machine_busy_"
local MULTIPLIER_TOLERANCE <const> = 0.0001

local STAKE_UPDATE_MS <const> = 150

local Locks = {}

---@type table<integer, ArcadeRound>
local Rounds = {}

---@type table<string, table<integer, boolean>>
local Watchers = {}

for machineId in pairs(Registry) do
    Watchers[machineId] = {}
end

local function publish(machineId, value)
    GlobalState:set(BUSY_PREFIX .. machineId, value or nil, true)
end

---@param machineId string
---@param message ArcadeSpectateMessage
local function updateWatchers(machineId, message)
    local watchers = Watchers[machineId]

    if not watchers then return end

    local lock = Locks[machineId]
    local holder = lock and lock.source
    local targets = {}
    local count = 0

    for target in pairs(watchers) do
        if target ~= holder then
            count = count + 1
            targets[count] = target
        end
    end

    if count == 0 then return end

    lib.triggerClientEvent("zkm-arcadegames:spectate", targets, machineId, message)
end

---@return ArcadeSpectateSyncMessage
local function watcherState(machineId)
    local lock = Locks[machineId]

    return {
        action = "spectateSync",
        game = Registry[machineId].game,
        stake = lock and lock.stake or 0,
        roundLive = lock ~= nil and Rounds[lock.source] ~= nil,
    }
end

local function updateStake(machineId)
    local lock = Locks[machineId]

    if not lock then return end

    local now = GetGameTimer()
    local since = now - (lock.stakeSentAt or 0)

    if since >= STAKE_UPDATE_MS then
        lock.stakeSentAt = now

        return updateWatchers(machineId, { action = "spectateStake", stake = lock.stake })
    end

    if lock.stakePending then return end

    lock.stakePending = true

    SetTimeout(STAKE_UPDATE_MS - since, function()
        local current = Locks[machineId]

        if not current or not current.stakePending then return end

        current.stakePending = false
        current.stakeSentAt = GetGameTimer()

        updateWatchers(machineId, { action = "spectateStake", stake = current.stake })
    end)
end

local function release(machineId)
    local lock = Locks[machineId]

    if not lock then return end

    Locks[machineId] = nil
    Rounds[lock.source] = nil
    publish(machineId, false)
    updateWatchers(machineId, { action = "spectateExit" })
end

local function isNearby(source, machine)
    if not DoesPlayerExist(source) then return false end

    local ped = GetPlayerPed(source)

    if not ped or ped == 0 then return false end

    return #(GetEntityCoords(ped) - machine.position) <= LockConfig.maxDistance
end

---@return ArcadeLockResult
lib.callback.register("zkm-arcadegames:acquireLock", function(source, machineId)
    local machine = Registry[machineId]

    if not machine then return { ok = false, reason = "unknown_machine" } end
    if Locks[machineId] then return { ok = false, reason = "busy" } end
    if Admin.isMoving(machineId) then return { ok = false, reason = "busy" } end
    if not isNearby(source, machine) then return { ok = false, reason = "too_far" } end

    local settings = GameSettings[machine.game]

    Locks[machineId] = { source = source, stake = settings and settings.minBet or 0 }
    Rounds[source] = nil
    publish(machineId, true)
    updateWatchers(machineId, watcherState(machineId))

    debugPrint("info", ("Player %s (%d) locked machine %s (%s)")
        :format(GetPlayerName(source) or source, source, machineId, machine.game))

    return { ok = true, balance = Framework.getBalance(source) }
end)

---@return ArcadeBetResult
lib.callback.register("zkm-arcadegames:placeBet", function(source, machineId, bet, risk, bombs)
    local lock = Locks[machineId]

    if not lock or lock.source ~= source then return { ok = false, reason = "no_session" } end
    if Rounds[source] then return { ok = false, reason = "round_open" } end

    local machine = Registry[machineId]
    local settings = machine and GameSettings[machine.game]

    if not settings then return { ok = false, reason = "unknown_game" } end

    bet = math.floor(tonumber(bet) or 0)

    if bet < settings.minBet or bet > settings.maxBet then
        return { ok = false, reason = "bad_bet" }
    end

    local outcome, reason = Outcomes.create(machine.game, risk, bombs)

    if not outcome then return { ok = false, reason = reason or "bad_request" } end
    if not Framework.removeMoney(source, bet) then return { ok = false, reason = "no_funds" } end

    local round = { machineId = machineId, game = machine.game, bet = bet, outcome = outcome }

    Rounds[source] = round
    lock.stake = bet

    if machine.game == "crash" then
        Citizen.SetTimeout(Outcomes.calculateBustDelay(round), function()
            if Rounds[source] ~= round then return end

            Rounds[source] = nil

            local crashAt = round.outcome.crashAt
            TriggerClientEvent("zkm-arcadegames:crashBusted", source, machineId, crashAt)
            updateWatchers(machineId, { action = "spectateBust", crashAt = crashAt })
        end)
    end

    local message = {
        action = "spectateRound",
        game = machine.game,
        bet = bet,
        outcome = Outcomes.opening(round),
    }

    if machine.game == "plinko" then message.risk = risk end

    updateWatchers(machineId, message)

    debugPrint("info", ("Player %s (%d) placed bet %d on %s (%s)")
        :format(GetPlayerName(source) or source, source, bet, machineId, machine.game))

    return {
        ok = true,
        balance = Framework.getBalance(source),
        outcome = Outcomes.opening(round),
    }
end)

---@return ArcadeRevealResult
lib.callback.register("zkm-arcadegames:reveal", function(source, higher)
    local round = Rounds[source]
    if not round or round.game ~= "hol" then return { ok = false, reason = "no_round" } end

    local reveal, reason = Outcomes.reveal(round, higher == true)
    if not reveal then return { ok = false, reason = reason } end

    updateWatchers(round.machineId, { action = "spectateReveal", reveal = reveal })

    return { ok = true, reveal = reveal }
end)

---@return ArcadePickResult
lib.callback.register("zkm-arcadegames:pickTile", function(source, tile)
    local round = Rounds[source]
    if not round or round.game ~= "mines" then return { ok = false, reason = "no_round" } end

    local pick, reason = Outcomes.pick(round, tile)
    if not pick then return { ok = false, reason = reason } end

    updateWatchers(round.machineId, { action = "spectatePick", pick = pick })

    return { ok = true, pick = pick }
end)

---@return ArcadeBetResult
lib.callback.register("zkm-arcadegames:settle", function(source, multiplier)
    local round = Rounds[source]
    if not round then return { ok = false, reason = "no_round" } end

    Rounds[source] = nil

    local bombTiles = round.game == "mines" and round.outcome.bombTiles or nil
    local claimed = math.max(tonumber(multiplier) or 0, 0)
    local earned, reason

    if round.game == "crash" then
        earned, reason = Outcomes.settleCrash(round, claimed)
    else
        local expected = Outcomes.multiplier(round)

        if math.abs(claimed - expected) > MULTIPLIER_TOLERANCE then
            reason = "outcome_mismatch"
        else
            earned = expected
        end
    end

    if not earned then
        lib.print.warn(("%s claimed %.4fx on %s but the round was not worth it, paying nothing")
            :format(GetPlayerName(source) or source, claimed, round.game))

        updateWatchers(round.machineId, {
            action = "spectateSettle",
            multiplier = 0,
            bombTiles = bombTiles,
        })

        return {
            ok = false,
            reason = reason,
            balance = Framework.getBalance(source),
            bombTiles = bombTiles,
        }
    end

    local cap = GameSettings[round.game].maxMultiplier
    local honoured = math.min(earned, cap)
    local payout = math.floor(round.bet * honoured)

    if payout > 0 then Framework.addMoney(source, payout) end

    updateWatchers(round.machineId, {
        action = "spectateSettle",
        multiplier = honoured,
        bombTiles = bombTiles,
    })

    debugPrint("info", ("Player %s (%d) settled %s for %d (bet %d, %.2fx)")
        :format(GetPlayerName(source) or source, source, round.game, payout, round.bet, honoured))

    return { ok = true, balance = Framework.getBalance(source), bombTiles = bombTiles }
end)

RegisterNetEvent("zkm-arcadegames:releaseLock", function(machineId)
    local src = source
    local lock = Locks[machineId]

    if lock and lock.source == src then
        release(machineId)
        debugPrint("info", ("Player %s (%d) unlocked machine %s")
            :format(GetPlayerName(src) or src, src, machineId))
    end
end)

RegisterNetEvent("zkm-arcadegames:watch", function(machineId, watching)
    local src = source
    local watchers = Watchers[machineId]

    if not watchers then return end

    if not watching then
        watchers[src] = nil

        return
    end

    watchers[src] = true

    local lock = Locks[machineId]

    if not lock or lock.source == src then return end

    TriggerClientEvent("zkm-arcadegames:spectate", src, machineId, watcherState(machineId))
end)

RegisterNetEvent("zkm-arcadegames:setStake", function(machineId, stake)
    local src = source
    local lock = Locks[machineId]

    if not lock or lock.source ~= src then return end

    local machine = Registry[machineId]
    local settings = machine and GameSettings[machine.game]

    if not settings then return end

    stake = tonumber(stake)

    if not stake or not (stake >= settings.minBet and stake <= settings.maxBet) then return end

    stake = math.floor(stake)

    if stake == lock.stake then return end

    lock.stake = stake

    updateStake(machineId)
end)

AddEventHandler("playerDropped", function()
    local src = source

    for _, watchers in pairs(Watchers) do
        watchers[src] = nil
    end

    for machineId, lock in pairs(Locks) do
        if lock.source == src then
            release(machineId)
            lib.print.info(("released %s held by %d (dropped)"):format(machineId, src))
        end
    end

    Rounds[src] = nil
end)

local function isSessionAlive(machineId, lock)
    local machine = Registry[machineId]

    return machine ~= nil and isNearby(lock.source, machine)
end

Citizen.CreateThread(function()
    local sweepMs = LockConfig.sweepMs
    local timeoutMs = LockConfig.timeoutMs

    while true do
        Citizen.Wait(sweepMs)

        local now = GetGameTimer()

        for machineId, lock in pairs(Locks) do
            if isSessionAlive(machineId, lock) then
                lock.staleSince = nil
            elseif not lock.staleSince then
                lock.staleSince = now
            elseif now - lock.staleSince > timeoutMs then
                release(machineId)
                lib.print.warn(("released %s held by %d (stale session)"):format(machineId, lock.source))
            end
        end
    end
end)

Citizen.CreateThread(function()
    for machineId in pairs(Registry) do
        publish(machineId, false)
    end
end)

AddEventHandler("onResourceStop", function(resource)
    if resource ~= cache.resource then return end

    for machineId in pairs(Locks) do
        publish(machineId, false)
    end

    Locks = {}
    Rounds = {}
    Watchers = {}
end)

Admin.occupant = function(machineId)
    local lock = Locks[machineId]
    return lock and GetPlayerName(lock.source) or nil
end

Admin.trackWatcher = function(machineId)
    Watchers[machineId] = Watchers[machineId] or {}
end

Admin.untrackWatcher = function(machineId)
    Watchers[machineId] = nil
end
local Config = lib.require "config"

local Framework = {}

local ACCOUNTS = Config.account
local STAKE_REASON <const> = "arcade-stake"
local PAYOUT_REASON <const> = "arcade-payout"

---@type 'esx' | 'qbx' | 'none'
local active = "none"
local account
local Core

---@param resource string
---@return boolean started
local function awaitResource(resource)
    if GetResourceState(resource) == "started" then return true end

    local deadline = GetGameTimer() + 10000

    lib.print.info(("waiting for %s to start"):format(resource))

    while GetResourceState(resource) ~= "started" do
        if GetGameTimer() > deadline then
            lib.print.error(("%s did not start within 10s, the arcade will run in standalone mode (free play, no economy)")
                :format(resource))
            return false
        end

        Citizen.Wait(500)
    end

    return true
end

if Config.framework == "esx" or (Config.framework == "auto" and GetResourceState("es_extended") ~= "missing") then
    if awaitResource("es_extended") then
        active = "esx"
        account = ACCOUNTS.esx
        Core = exports.es_extended:getSharedObject()
    end
elseif Config.framework == "qbx" or (Config.framework == "auto" and GetResourceState("qbx_core") ~= "missing") then
    if awaitResource("qbx_core") then
        active = "qbx"
        account = ACCOUNTS.qbx
        Core = exports.qbx_core
    end
else
    lib.print.warn("No supported framework detected, the arcade will run in standalone mode (free play, no economy).")
end

Framework.standalone = active == "none"

local STANDALONE_BALANCE = 0

for game in pairs(Config.games) do
    local settings = Config.gameSettings[game]

    if settings and settings.maxBet and settings.maxBet > STANDALONE_BALANCE then
        STANDALONE_BALANCE = settings.maxBet
    end
end

local function getPlayer(source)
    if active == "esx" then return Core.Player and Core.Player(source) or Core.GetPlayerFromId(source) end
    if active == "qbx" then return Core:GetPlayer(source) end

    return nil
end

---@param source integer
---@return integer
function Framework.getBalance(source)
    if active == "none" then return STANDALONE_BALANCE end

    if active == "esx" then
        local player = getPlayer(source)
        if not player then return 0 end

        local esxAccount = player.getAccount(account)

        if esxAccount then return math.floor(esxAccount.money) end
    elseif active == "qbx" then
        local money = Core:GetMoney(source, account)

        if money then return math.floor(money) end
    end

    lib.print.error(("Player has no %q account, check Config.account"):format(account))

    return 0
end

---@param source integer
---@param amount integer
---@return boolean
function Framework.removeMoney(source, amount)
    if active == "none" then return true end

    if active == "esx" then
        local player = getPlayer(source)
        if not player then return false end

        if Framework.getBalance(source) < amount then return false end

        player.removeAccountMoney(account, amount, STAKE_REASON)

        return true
    end

    return Core:RemoveMoney(source, account, amount, STAKE_REASON) == true
end

---@param source integer
---@param amount integer
---@return boolean
function Framework.addMoney(source, amount)
    if active == "none" then return true end

    if active == "esx" then
        local player = getPlayer(source)
        if not player then return false end

        player.addAccountMoney(account, amount, PAYOUT_REASON)

        return true
    end

    return Core:AddMoney(source, account, amount, PAYOUT_REASON)
end

return Framework
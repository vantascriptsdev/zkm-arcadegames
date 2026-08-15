local Config = lib.require "config"
local Machines = lib.require "client.modules.machines"
local Camera = lib.require "client.modules.camera"
local debugPrint = lib.require "shared.debugPrint"

local Play = {}

local CamConfig = Config.camera
local AnimConfig = Config.anim
local EXIT_CONTROL <const> = 194
local ANIM_BLEND <const> = 4.0
local ANIM_LOOP <const> = 1

local LOCK_ERRORS <const> = {
    busy = "This machine is already in use.",
    too_far = "You are too far from the machine.",
    unknown_machine = "This machine is out of order.",
}

local current
local entering = false
local pedChanged = false
local anim

local function startAnim(instance)
    if not AnimConfig then return end

    local ped = cache.ped
    local clip = IsPedMale(ped) and AnimConfig.male or AnimConfig.female
    local offset = AnimConfig.standOffset
    local stand = GetOffsetFromEntityInWorldCoords(instance.entity, offset.x, offset.y, offset.z)

    SetEntityCoords(ped, stand.x, stand.y, stand.z, false, false, false, false)
    SetEntityHeading(ped, GetEntityHeading(instance.entity))

    if not DoesAnimDictExist(clip.dict) then
        return lib.print.warn(("anim dict %q does not exist, the ped will just stand there"):format(clip.dict))
    end

    lib.requestAnimDict(clip.dict)

    if current ~= instance then return end

    anim = clip

    TaskPlayAnim(ped, clip.dict, clip.clip, ANIM_BLEND, -ANIM_BLEND, -1, ANIM_LOOP, 0.0, false, false, false)
end

local function cleanup(blend)
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)

    if blend then
        Camera.exit()
    else
        Camera.destroy()
        RenderScriptCams(false, false, 0, true, true)
    end

    if pedChanged then
        local ped = cache.ped

        if anim then
            StopAnimTask(ped, anim.dict, anim.clip, ANIM_BLEND)
            anim = nil
        end

        FreezeEntityPosition(ped, false)
        SetEntityLocallyVisible(ped)
        DisplayRadar(true)

        pedChanged = false
    end

    current = nil
    entering = false
end

local function runSession(instance)
    local hidePed = CamConfig.hidePed

    Citizen.CreateThread(function()
        while current == instance do
            DisableAllControlActions(0)
            DisableAllControlActions(1)
            DisableAllControlActions(2)
            HideHudAndRadarThisFrame()

            if hidePed then SetEntityLocallyInvisible(cache.ped) end

            if IsDisabledControlJustPressed(0, EXIT_CONTROL) then Play.stop() end

            Citizen.Wait(0)
        end
    end)
end

function Play.start(machineId)
    if current or entering then return end

    local instance = Machines.get(machineId)

    if not instance then
        return lib.print.warn(("Play.start called with unknown machine id %s"):format(machineId))
    end

    if Machines.isOccupied(machineId) then
        return lib.notify({ type = "error", description = "This machine is already in use." })
    end

    entering = true

    local lock = lib.callback.await("zkm-arcadegames:acquireLock", false, machineId)

    if not lock or not lock.ok then
        entering = false

        return lib.notify({
            type = "error",
            description = LOCK_ERRORS[lock and lock.reason] or LOCK_ERRORS.busy
        })
    end

    current = instance

    FreezeEntityPosition(cache.ped, true)
    DisplayRadar(false)
    pedChanged = true

    debugPrint("info", ("Entered machine %s (%s)"):format(instance.id, instance.game))

    Camera.enter(instance.entity)
    runSession(instance)
    startAnim(instance)

    Citizen.Wait(CamConfig.enterMs + 50)

    if current ~= instance then return end

    SetNuiFocus(true, true)

    SendNUIMessage({
        action = "enterPlay",
        machineId = instance.id,
        game = instance.game,
        rect = Camera.screenRect(instance.entity),
        gameSettings = Config.gameSettings,
        balance = lock.balance,
    })

    entering = false
end

function Play.stop(blend)
    local instance = current

    if not instance then
        return cleanup(blend ~= false)
    end

    SendNUIMessage({ action = "exitPlay" })
    cleanup(blend ~= false)

    TriggerServerEvent("zkm-arcadegames:releaseLock", instance.id)

    debugPrint("info", ("Left machine %s"):format(instance.id))
end

function Play.active()
    return current
end

RegisterNuiCallback("exitPlay", function(_, cb)
    Play.stop()
    cb(1)
end)

RegisterNuiCallback("close", function(_, cb)
    Play.stop()
    cb(1)
end)

RegisterNuiCallback("setStake", function(data, cb)
    local instance = current

    if instance then
        TriggerServerEvent("zkm-arcadegames:setStake", instance.id, data.bet)
    end

    cb(1)
end)

RegisterNuiCallback("placeBet", function(data, cb)
    local instance = current

    if not instance then return cb({ ok = false, reason = "no_session" }) end

    local result = lib.callback.await("zkm-arcadegames:placeBet", false, instance.id, data.bet, data.risk, data.bombs)

    cb(result or { ok = false, reason = "no_session" })
end)

RegisterNuiCallback("reveal", function(data, cb)
    local result = lib.callback.await("zkm-arcadegames:reveal", false, data.higher)

    cb(result or { ok = false, reason = "no_round" })
end)

RegisterNuiCallback("pickTile", function(data, cb)
    local result = lib.callback.await("zkm-arcadegames:pickTile", false, data.tile)

    cb(result or { ok = false, reason = "no_round" })
end)

RegisterNuiCallback("settle", function(data, cb)
    local result = lib.callback.await("zkm-arcadegames:settle", false, data.multiplier)

    cb(result or { ok = false, reason = "no_round" })
end)

---@param machineId string
---@param crashAt number
RegisterNetEvent("zkm-arcadegames:crashBusted", function(machineId, crashAt)
    local instance = current

    if not instance or instance.id ~= machineId then return end

    SendNUIMessage({ action = "crashBusted", crashAt = crashAt })
end)

lib.addKeybind({
    name = "zkm_arcade_exit",
    description = "Leave the arcade machine",
    defaultKey = "BACK",
    onPressed = function()
        if current then Play.stop() end
    end
})

return Play
local Config = lib.require "config"
local Machines = lib.require "client.modules.machines"
local Play = lib.require "client.modules.play"

local Admin = {}

local PlacementConfig = Config.admin.placement
local LockConfig = Config.lock

local GAME_ORDER <const> = { "crash", "plinko", "hol", "mines" }

local surfaceOpen = false

local placing = false
local mode = "new"
local machineId
local game
local stepIndex = #PlacementConfig.steps
local valid = true
local reason
local x, y, z, heading = 0.0, 0.0, 0.0, 0.0
local ghost
local originalCoords
local returnCoords
local dragging = false

local Held = {}

---@param flat { id: string, game: ArcadeGameId, x: number, y: number, z: number, heading: number }
local function defineMachine(flat)
    Machines.define({
        id = flat.id,
        game = flat.game,
        coords = vector4(flat.x, flat.y, flat.z, flat.heading),
        position = vector3(flat.x, flat.y, flat.z),
    })
end

Citizen.CreateThread(function()
    local machines = lib.callback.await("zkm-arcadegames:adminSpawnList", false)

    if not machines then return end

    for i = 1, #machines do
        local machine = machines[i]

        if not Machines.isDefined(machine.id) then defineMachine(machine) end
    end
end)

RegisterNetEvent("zkm-arcadegames:adminMachineUpserted", function(machine)
    if not Machines.isDefined(machine.id) then
        defineMachine(machine)
        return
    end

    Machines.move(machine.id, vector4(machine.x, machine.y, machine.z, machine.heading))
    Machines.setGame(machine.id, machine.game)
end)

RegisterNetEvent("zkm-arcadegames:adminMachineRemoved", function(removedId)
    Machines.remove(removedId)
end)

local function enabledGames()
    local list = {}

    for i = 1, #GAME_ORDER do
        if Config.games[GAME_ORDER[i]] then list[#list + 1] = GAME_ORDER[i] end
    end

    return list
end

local function nextGame(current)
    local list = enabledGames()

    if #list == 0 then return current end

    for i = 1, #list do
        if list[i] == current then return list[i % #list + 1] end
    end

    return list[1]
end

local function forward(deg)
    local rad = math.rad(deg)
    return vector3(-math.sin(rad), math.cos(rad), 0.0)
end

local function checkValidity()
    local nearest, nearestId
    local instances = Machines.all()

    for i = 1, #instances do
        local instance = instances[i]

        if instance.id ~= machineId then
            local distance = #(vector3(x, y, z) - instance.position)

            if not nearest or distance < nearest then
                nearest, nearestId = distance, instance.id
            end
        end
    end

    if nearest and nearest < PlacementConfig.minDistance then
        valid, reason = false, ("Too close to machine %s"):format(nearestId)
    else
        valid, reason = true, nil
    end
end

local function pushState(fields)
    fields.action = "placementState"
    SendNUIMessage(fields)
end

local function applyTransform()
    if mode == "new" then
        if ghost then
            SetEntityCoords(ghost, x, y, z, false, false, false, false)
            SetEntityHeading(ghost, heading)
        end
    else
        Machines.move(machineId, vector4(x, y, z, heading))
    end

    local wasValid = valid

    checkValidity()
    SendNUIMessage({ action = "placementTransform", x = x, y = y, z = z, heading = heading })

    if valid ~= wasValid then pushState({ valid = valid, reason = reason }) end
end

local function stepAmount()
    return PlacementConfig.steps[stepIndex]
end

local NUDGE_CREATORS <const> = {
    ["forward"] = function(sign)
        local dir = forward(heading)

        x = x + dir.x * sign * stepAmount()
        y = y + dir.y * sign * stepAmount()
    end,
    ["right"] = function(sign)
        local dir = forward(heading - 90.0)

        x = x + dir.x * sign * stepAmount()
        y = y + dir.y * sign * stepAmount()
    end,
    ["height"] = function(sign)
        z = z + sign * stepAmount()
    end,
    ["rotate"] = function(sign)
        heading = (heading + sign * PlacementConfig.rotateSteps[stepIndex]) % 360.0
    end,
}

local function nudge(axis, sign)
    NUDGE_CREATORS[axis](sign)
    applyTransform()
end

local function snapToGround()
    local instance = mode ~= "new" and Machines.get(machineId) or nil
    local entity = mode == "new" and ghost or (instance and instance.entity)

    if not entity or not DoesEntityExist(entity) then
        return lib.notify({ type = "error", description = "No ground found below." })
    end

    PlaceObjectOnGroundProperly(entity)

    local coords = GetEntityCoords(entity)
    x, y, z = coords.x, coords.y, coords.z

    applyTransform()
end

local function rotationToDirection(rot)
    local yaw = math.rad(rot.z)
    local pitch = math.rad(rot.x)
    local flat = math.abs(math.cos(pitch))

    return vector3(-math.sin(yaw) * flat, math.cos(yaw) * flat, math.sin(pitch))
end

local function lookRay()
    local camCoord = GetGameplayCamCoord()
    local dest = camCoord + rotationToDirection(GetGameplayCamRot(2)) * 100.0

    local rayHandle = StartShapeTestRay(camCoord.x, camCoord.y, camCoord.z, dest.x, dest.y, dest.z, 1, cache.ped, 0)
    local _, hit, endCoords, _, entityHit = GetShapeTestResult(rayHandle)

    local instance = Machines.get(machineId)
    if entityHit and (instance and instance.entity) and entityHit == instance.entity then return end

    return hit, endCoords
end

local DUI_URL <const> = "https://cfx-nui-zkm-arcadegames/web/dist/index.html"
local GHOST_TXD_NAME <const> = "zkm_arcade_ghost_screen"
local GHOST_DUI_SIZE <const> = 800

local TOP_LEFT <const> = vector3(-0.279, 0.020, 1.405)
local TOP_RIGHT <const> = vector3(0.279, 0.020, 1.405)
local BOTTOM_LEFT <const> = vector3(-0.279, -0.18, 1.03)
local BOTTOM_RIGHT <const> = vector3(0.279, -0.18, 1.03)

local ghostDui = CreateDui(("%s?surface=dui&game=crash"):format(DUI_URL), GHOST_DUI_SIZE, GHOST_DUI_SIZE)
local ghostReady = false

CreateRuntimeTextureFromDuiHandle(CreateRuntimeTxd(GHOST_TXD_NAME), "screen", GetDuiHandle(ghostDui))

local function setGhostGame(newGame)
    ghostReady = false

    SetDuiUrl(ghostDui, ("%s?surface=dui&game=%s"):format(DUI_URL, newGame))

    Citizen.CreateThread(function()
        while not IsDuiAvailable(ghostDui) do Citizen.Wait(50) end

        SendDuiMessage(ghostDui, json.encode({ action = "setConfig", gameSettings = Config.gameSettings }))
        ghostReady = true
    end)
end

local function open()
    Citizen.CreateThreadNow(function()
        local result = lib.callback.await("zkm-arcadegames:adminFetch", false)

        if not result or not result.ok then
            return lib.notify({ type = "error", description = "You do not have permission for that." })
        end

        surfaceOpen = true
        SetNuiFocus(true, true)
        SendNUIMessage({ action = "adminOpen", machines = result.machines })
    end)
end

local function startPlacement(newMode, data)
    mode = newMode
    machineId = data.machineId
    game = data.game
    stepIndex = #PlacementConfig.steps
    x, y, z, heading = data.x, data.y, data.z, data.heading
    originalCoords = newMode == "move" and vector4(data.x, data.y, data.z, data.heading) or nil

    if newMode == "new" then
        lib.requestModel(Config.propModel)

        ghost = CreateObjectNoOffset(Config.propModel, x, y, z, false, false, false)

        SetEntityHeading(ghost, heading)
        SetEntityAlpha(ghost, 200, false)
        SetEntityCollision(ghost, false, false)
        SetModelAsNoLongerNeeded(Config.propModel)

        setGhostGame(game)
    else
        Machines.lock(machineId)

        local ped = cache.ped
        local pedCoords = GetEntityCoords(ped)

        if #(pedCoords - vector3(x, y, z)) > LockConfig.maxDistance then
            returnCoords = vector4(pedCoords.x, pedCoords.y, pedCoords.z, GetEntityHeading(ped))

            SetEntityCoords(ped, x, y, z, false, false, false, false)
            SetEntityHeading(ped, heading)
        end
    end

    checkValidity()

    surfaceOpen = false
    SetNuiFocus(false, false)
    FreezeEntityPosition(cache.ped, true)

    SendNUIMessage({
        action = "enterPlacement",
        mode = mode,
        machineId = machineId,
        game = game,
        x = x,
        y = y,
        z = z,
        heading = heading,
        step = stepAmount(),
        valid = valid,
        reason = reason,
    })

    placing = true

    Citizen.CreateThread(function()
        while placing do
            if next(Held) then
                for _, action in pairs(Held) do action() end
            end

            Citizen.Wait(100)
        end
    end)

    local function drawGhostScreen()
        if not ghost or not ghostReady then return end

        local tl = GetOffsetFromEntityInWorldCoords(ghost, TOP_LEFT.x, TOP_LEFT.y, TOP_LEFT.z)
        local tr = GetOffsetFromEntityInWorldCoords(ghost, TOP_RIGHT.x, TOP_RIGHT.y, TOP_RIGHT.z)
        local bl = GetOffsetFromEntityInWorldCoords(ghost, BOTTOM_LEFT.x, BOTTOM_LEFT.y, BOTTOM_LEFT.z)
        local br = GetOffsetFromEntityInWorldCoords(ghost, BOTTOM_RIGHT.x, BOTTOM_RIGHT.y, BOTTOM_RIGHT.z)

        DrawTexturedPoly(
            bl.x, bl.y, bl.z, br.x, br.y, br.z, tl.x, tl.y, tl.z,
            255, 255, 255, 255, GHOST_TXD_NAME, "screen",
            0.0, 1.0, 0.0,
            1.0, 1.0, 0.0,
            0.0, 0.0, 0.0
        )

        DrawTexturedPoly(
            br.x, br.y, br.z, tr.x, tr.y, tr.z, tl.x, tl.y, tl.z,
            255, 255, 255, 255, GHOST_TXD_NAME, "screen",
            1.0, 1.0, 0.0,
            1.0, 0.0, 0.0,
            0.0, 0.0, 0.0
        )
    end

    Citizen.CreateThread(function()
        while placing do
            DisableAllControlActions(0)
            DisableAllControlActions(1)
            DisableAllControlActions(2)

            EnableControlAction(0, 1, true)
            EnableControlAction(0, 2, true)

            if mode == "new" then drawGhostScreen() end

            if dragging then
                local hit, endCoords = lookRay()

                if hit then
                    x, y, z = endCoords.x, endCoords.y, endCoords.z
                    applyTransform()
                end
            end

            Citizen.Wait(0)
        end
    end)
end

local function endPlacement()
    placing = false

    if mode == "move" then Machines.unlock(machineId) end

    FreezeEntityPosition(cache.ped, false)

    if ghost and DoesEntityExist(ghost) then DeleteEntity(ghost) end
    ghost = nil

    if returnCoords then
        SetEntityCoords(cache.ped, returnCoords.x, returnCoords.y, returnCoords.z, false, false, false, false)
        SetEntityHeading(cache.ped, returnCoords.w)
        returnCoords = nil
    end

    SendNUIMessage({ action = "exitPlacement" })
    open()
end

local function initialPlacementData()
    local ped = cache.ped
    local coords = GetEntityCoords(ped)
    local pedHeading = GetEntityHeading(ped)
    local ahead = coords + forward(pedHeading) * 2.0

    return { game = enabledGames()[1] or "crash", x = ahead.x, y = ahead.y, z = coords.z, heading = pedHeading }
end

local function repeatable(name, description, defaultKey, action)
    lib.addKeybind({
        name = name,
        description = description,
        defaultKey = defaultKey,
        onPressed = function()
            if not placing then return end

            action()
            Held[name] = action
        end,
        onReleased = function()
            Held[name] = nil
        end,
    })
end

local NUDGE_KEYBINDS <const> = {
    { name = "zkm_arcade_admin_forward",  description = "Machine creator: nudge forward", defaultKey = "W", axis = "forward", sign = 1 },
    { name = "zkm_arcade_admin_back",     description = "Machine creator: nudge back",    defaultKey = "S", axis = "forward", sign = -1 },
    { name = "zkm_arcade_admin_left",     description = "Machine creator: nudge left",    defaultKey = "A", axis = "right",   sign = -1 },
    { name = "zkm_arcade_admin_right",    description = "Machine creator: nudge right",   defaultKey = "D", axis = "right",   sign = 1 },
    { name = "zkm_arcade_admin_down",     description = "Machine creator: lower height",  defaultKey = "Q", axis = "height",  sign = -1 },
    { name = "zkm_arcade_admin_up",       description = "Machine creator: raise height",  defaultKey = "R", axis = "height",  sign = 1 },
    { name = "zkm_arcade_admin_rotleft",  description = "Machine creator: rotate left",   defaultKey = "Z", axis = "rotate",  sign = -1 },
    { name = "zkm_arcade_admin_rotright", description = "Machine creator: rotate right",  defaultKey = "C", axis = "rotate",  sign = 1 },
}

for _, bind in ipairs(NUDGE_KEYBINDS) do
    repeatable(bind.name, bind.description, bind.defaultKey, function() nudge(bind.axis, bind.sign) end)
end

lib.addKeybind({
    name = "zkm_arcade_admin_snap",
    description = "Machine creator: snap to ground",
    defaultKey = "F",
    onPressed = function() if placing then snapToGround() end end,
})

lib.addKeybind({
    name = "zkm_arcade_admin_drag",
    description = "Machine creator: hold to position at where you are looking",
    defaultKey = "M",
    onPressed = function() if placing then dragging = true end end,
    onReleased = function() dragging = false end,
})

lib.addKeybind({
    name = "zkm_arcade_admin_cyclegame",
    description = "Machine creator: cycle game",
    defaultKey = "G",
    onPressed = function()
        if not placing then return end

        game = nextGame(game)
        pushState({ game = game })

        if mode == "new" then setGhostGame(game) end
    end,
})

lib.addKeybind({
    name = "zkm_arcade_admin_step",
    description = "Machine creator: cycle step size",
    defaultKey = "X",
    onPressed = function()
        if not placing then return end

        stepIndex = stepIndex % #PlacementConfig.steps + 1
        pushState({ step = stepAmount() })
    end,
})

lib.addKeybind({
    name = "zkm_arcade_admin_confirm",
    description = "Machine creator: confirm placement",
    defaultKey = "RETURN",
    onPressed = function()
        if not placing or not valid then return end

        local result = lib.callback.await("zkm-arcadegames:adminSave", false, {
            mode = mode, machineId = machineId, game = game, x = x, y = y, z = z, heading = heading,
        })

        if not result or not result.ok then
            return lib.notify({ type = "error", description = "Could not save that machine." })
        end

        endPlacement()
    end,
})

lib.addKeybind({
    name = "zkm_arcade_admin_cancel",
    description = "Machine creator: cancel placement",
    defaultKey = "ESCAPE",
    onPressed = function()
        if not placing then return end

        if mode == "move" and originalCoords then
            Machines.move(machineId, originalCoords)
            TriggerServerEvent("zkm-arcadegames:adminMoveCancel", machineId)
        end

        endPlacement()
    end,
})

RegisterNuiCallback("adminFetch", function(_, cb)
    local result = lib.callback.await("zkm-arcadegames:adminFetch", false)

    cb(result or { ok = false, reason = "bad_request" })
end)

RegisterNuiCallback("adminCreate", function(_, cb)
    if placing then return cb({ ok = false, reason = "placement_open" }) end

    local result = lib.callback.await("zkm-arcadegames:adminCreate", false)

    if not result or not result.ok then return cb(result or { ok = false, reason = "bad_request" }) end

    cb({ ok = true })

    startPlacement("new", initialPlacementData())
end)

RegisterNuiCallback("adminMove", function(data, cb)
    if placing then return cb({ ok = false, reason = "placement_open" }) end

    local result = lib.callback.await("zkm-arcadegames:adminMove", false, data.id)

    if not result or not result.ok then return cb(result or { ok = false, reason = "bad_request" }) end

    cb({ ok = true })

    startPlacement("move", {
        machineId = data.id,
        game = result.game,
        x = result.x,
        y = result.y,
        z = result.z,
        heading = result.heading,
    })
end)

RegisterNuiCallback("adminTeleport", function(data, cb)
    local result = lib.callback.await("zkm-arcadegames:adminTeleport", false, data.id)

    if result and result.ok then
        SetEntityCoords(cache.ped, result.x, result.y, result.z, false, false, false, false)
        SetEntityHeading(cache.ped, result.heading)
    end

    cb(result and { ok = result.ok, reason = result.reason } or { ok = false, reason = "bad_request" })
end)

RegisterNuiCallback("adminDelete", function(data, cb)
    local result = lib.callback.await("zkm-arcadegames:adminDelete", false, data.id)

    cb(result or { ok = false, reason = "bad_request" })
end)

RegisterNuiCallback("adminClose", function(_, cb)
    if surfaceOpen then
        surfaceOpen = false
        SetNuiFocus(false, false)
    end

    cb(1)
end)

RegisterNetEvent("zkm-arcadegames:adminOpenCommand", function()
    if placing or surfaceOpen then return end

    if Play.active() then
        return lib.notify({ type = "error", description = "Leave the machine before managing cabinets." })
    end

    open()
end)

return Admin
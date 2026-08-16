local Config = lib.require "config"

local Machines = {}

---@type table<string, { id: string, game: ArcadeGameId, coords: vector4, position: vector3 }>
local Definitions = {}
local Instances = {}
local Ordered = {}
local StreamPoints = {}
local Locked = {}

local EnterHandlers = {}
local ExitHandlers = {}

local TOP_LEFT <const> = vector3(-0.279, 0.020, 1.405)
local TOP_RIGHT <const> = vector3(0.279, 0.020, 1.405)
local BOTTOM_LEFT <const> = vector3(-0.279, -0.18, 1.03)
local BOTTOM_RIGHT <const> = vector3(0.279, -0.18, 1.03)

local LIGHT_X <const> = (TOP_LEFT.x + TOP_RIGHT.x) * 0.5
local LIGHT_Y <const> = TOP_LEFT.y - 0.05
local LIGHT_Z <const> = TOP_LEFT.z + 0.06

local DUI_URL <const> = "https://cfx-nui-zkm-arcadegames/web/dist/index.html"
local BUSY_PREFIX <const> = "machine_busy_"
local PREFIX_LENGTH <const> = #BUSY_PREFIX
local DUI_SIZE <const> = 800 -- width/height of the dui frame
local SESSION <const> = GetGameTimer()

local STREAM_DISTANCE <const> = Config.render.sleepDistance

local modelLoaded = false

local function ensureModel()
    if modelLoaded then return end

    lib.requestModel(Config.propModel)

    modelLoaded = true
end

local function releaseModelIfUnused()
    if not modelLoaded or Ordered[1] then return end

    SetModelAsNoLongerNeeded(Config.propModel)

    modelLoaded = false
end

local function sendDui(instance, message)
    SendDuiMessage(instance.dui, json.encode(message))
end

local function drawScreen(instance)
    local entity = instance.entity
    local txd = instance.txdName

    local topLeft = GetOffsetFromEntityInWorldCoords(entity, TOP_LEFT.x, TOP_LEFT.y, TOP_LEFT.z)
    local topRight = GetOffsetFromEntityInWorldCoords(entity, TOP_RIGHT.x, TOP_RIGHT.y, TOP_RIGHT.z)
    local bottomLeft = GetOffsetFromEntityInWorldCoords(entity, BOTTOM_LEFT.x, BOTTOM_LEFT.y, BOTTOM_LEFT.z)
    local bottomRight = GetOffsetFromEntityInWorldCoords(entity, BOTTOM_RIGHT.x, BOTTOM_RIGHT.y, BOTTOM_RIGHT.z)

    DrawTexturedPoly(
        bottomLeft.x, bottomLeft.y, bottomLeft.z, bottomRight.x, bottomRight.y, bottomRight.z, topLeft.x, topLeft.y,
        topLeft.z,
        255, 255, 255, 255, txd, "screen",
        0.0, 1.0, 0.0,
        1.0, 1.0, 0.0,
        0.0, 0.0, 0.0
    )

    DrawTexturedPoly(
        bottomRight.x, bottomRight.y, bottomRight.z, topRight.x, topRight.y, topRight.z, topLeft.x, topLeft.y, topLeft.z,
        255, 255, 255, 255, txd, "screen",
        1.0, 1.0, 0.0,
        1.0, 0.0, 0.0,
        0.0, 0.0, 0.0
    )
end

local function drawBusyLight(instance)
    local coords = GetOffsetFromEntityInWorldCoords(instance.entity, LIGHT_X, LIGHT_Y, LIGHT_Z)

    DrawLightWithRange(coords.x, coords.y, coords.z, 255, 40, 40, 1.4, 2.0)
end

local function spawn(definition)
    ensureModel()

    local coords = definition.coords
    local entity = CreateObjectNoOffset(Config.propModel, coords.x, coords.y, coords.z, false, false, false)

    SetEntityHeading(entity, coords.w)
    FreezeEntityPosition(entity, true)
    SetEntityInvincible(entity, true)
    SetEntityAsMissionEntity(entity, true, true)
    PlaceObjectOnGroundProperly(entity)

    local dui = CreateDui(("%s?surface=dui&game=%s"):format(DUI_URL, definition.game), DUI_SIZE, DUI_SIZE)
    local txdName = ("arcade_screen_%s_%d"):format(definition.id, SESSION)

    CreateRuntimeTextureFromDuiHandle(CreateRuntimeTxd(txdName), "screen", GetDuiHandle(dui))

    return {
        id = definition.id,
        game = definition.game,
        coords = coords,
        position = definition.position,
        entity = entity,
        dui = dui,
        txdName = txdName,
        occupied = GlobalState[BUSY_PREFIX .. definition.id] == true,
        inRange = false,
        ready = false,
    }
end

local function despawn(instance)
    if DoesEntityExist(instance.entity) then DeleteEntity(instance.entity) end

    DestroyDui(instance.dui)

    releaseModelIfUnused()
end

local function pushInitialState(instance)
    Citizen.CreateThread(function()
        while not IsDuiAvailable(instance.dui) do Citizen.Wait(50) end

        sendDui(instance, {
            action = "setConfig",
            gameSettings = Config.gameSettings,
        })

        if instance.occupied then
            sendDui(instance, { action = "setOccupied", occupied = true })
        end

        instance.ready = true
    end)
end

local function setOccupied(machineId, occupied)
    local instance = Instances[machineId]

    if not instance or instance.occupied == occupied then return end

    instance.occupied = occupied

    sendDui(instance, { action = "setOccupied", occupied = occupied })
end

---@param machineId string
local function handleEnter(machineId)
    local definition = Definitions[machineId]

    if not definition or Instances[machineId] then return end

    local instance = spawn(definition)

    Instances[machineId] = instance
    Ordered[#Ordered + 1] = instance

    pushInitialState(instance)

    for i = 1, #EnterHandlers do
        EnterHandlers[i](instance)
    end
end

---@param machineId string
local function handleExit(machineId)
    if Locked[machineId] then return end

    local instance = Instances[machineId]

    if not instance then return end

    Instances[machineId] = nil

    for i = 1, #Ordered do
        if Ordered[i] == instance then
            table.remove(Ordered, i)
            break
        end
    end

    for i = 1, #ExitHandlers do
        ExitHandlers[i](instance)
    end

    if instance.inRange then
        TriggerServerEvent("zkm-arcadegames:watch", machineId, false)
    end

    despawn(instance)
end

function Machines.onEnter(cb)
    EnterHandlers[#EnterHandlers + 1] = cb
end

function Machines.onExit(cb)
    ExitHandlers[#ExitHandlers + 1] = cb
end

---@param machineId string
function Machines.lock(machineId)
    Locked[machineId] = true

    handleEnter(machineId)
end

---@param machineId string
function Machines.unlock(machineId)
    Locked[machineId] = nil

    local definition = Definitions[machineId]

    if not definition then return end

    local distance = #(GetEntityCoords(cache.ped) - definition.position)

    if distance > STREAM_DISTANCE then handleExit(machineId) end
end

local function startDrawLoop()
    local drawDistance = Config.render.drawDistance
    local exitDistance = drawDistance + 2.0

    Citizen.CreateThread(function()
        while true do
            if not Ordered[1] then
                Citizen.Wait(1000)
            else
                local coords = GetEntityCoords(cache.ped)

                for i = 1, #Ordered do
                    local instance = Ordered[i]
                    local distance = #(coords - instance.position)

                    local threshold = instance.inRange and exitDistance or drawDistance
                    local inRange = instance.ready and distance <= threshold

                    if inRange ~= instance.inRange then
                        instance.inRange = inRange

                        TriggerServerEvent("zkm-arcadegames:watch", instance.id, inRange)

                        if not inRange then sendDui(instance, { action = "spectateExit" }) end
                    end

                    if distance <= drawDistance then
                        drawScreen(instance)

                        if instance.occupied then drawBusyLight(instance) end
                    end
                end

                Citizen.Wait(0)
            end
        end
    end)
end

function Machines.all()
    return Ordered
end

function Machines.get(machineId)
    return Instances[machineId]
end

function Machines.isDefined(machineId)
    return Definitions[machineId] ~= nil
end

function Machines.isOccupied(machineId)
    local instance = Instances[machineId]
    return instance ~= nil and instance.occupied
end

---@param machine { id: string, game: ArcadeGameId, coords: vector4, position: vector3 }
function Machines.define(machine)
    local id = machine.id

    if Definitions[id] then return end

    Definitions[id] = {
        id = id,
        game = machine.game,
        coords = machine.coords,
        position = machine.position,
    }

    local point = lib.points.new({ coords = machine.position, distance = STREAM_DISTANCE })

    function point:onEnter() handleEnter(id) end

    function point:onExit() handleExit(id) end

    StreamPoints[id] = point
end

Citizen.CreateThread(function()
    AddStateBagChangeHandler(nil, "global", function(_, key, value)
        if key:sub(1, PREFIX_LENGTH) ~= BUSY_PREFIX then return end

        setOccupied(key:sub(PREFIX_LENGTH + 1), value == true)
    end)

    ---@param machineId string
    ---@param message ArcadeSpectateMessage
    RegisterNetEvent("zkm-arcadegames:spectate", function(machineId, message)
        local instance = Instances[machineId]

        if instance then sendDui(instance, message) end
    end)

    startDrawLoop()
end)

function Machines.cleanup()
    for _, point in pairs(StreamPoints) do
        point:remove()
    end

    StreamPoints = {}
    Locked = {}

    for i = 1, #Ordered do
        local instance = Ordered[i]

        for j = 1, #ExitHandlers do
            ExitHandlers[j](instance)
        end

        if DoesEntityExist(instance.entity) then DeleteEntity(instance.entity) end

        DestroyDui(instance.dui)
    end

    if modelLoaded then
        SetModelAsNoLongerNeeded(Config.propModel)
        modelLoaded = false
    end

    Definitions = {}
    Instances = {}
    Ordered = {}
end

---@param machineId string
---@param coords vector4
function Machines.move(machineId, coords)
    local definition = Definitions[machineId]

    if not definition then return end

    definition.coords = coords
    definition.position = coords.xyz

    local point = StreamPoints[machineId]

    if point then point.coords = definition.position end

    local instance = Instances[machineId]

    if not instance then return end

    instance.coords = coords
    instance.position = coords.xyz

    SetEntityCoords(instance.entity, coords.x, coords.y, coords.z, false, false, false, false)
    SetEntityHeading(instance.entity, coords.w)
end

---@param machineId string
---@param game ArcadeGameId
function Machines.setGame(machineId, game)
    local definition = Definitions[machineId]

    if not definition then return end

    definition.game = game

    local instance = Instances[machineId]

    if not instance or instance.game == game then return end

    instance.game = game
    instance.ready = false

    SetDuiUrl(instance.dui, ("%s?surface=dui&game=%s"):format(DUI_URL, game))
    pushInitialState(instance)
end

---@param machineId string
function Machines.remove(machineId)
    local point = StreamPoints[machineId]

    if point then
        point:remove()
        StreamPoints[machineId] = nil
    end

    Locked[machineId] = nil

    local instance = Instances[machineId]

    if instance then
        Instances[machineId] = nil

        for i = 1, #Ordered do
            if Ordered[i] == instance then
                table.remove(Ordered, i)
                break
            end
        end

        for i = 1, #ExitHandlers do
            ExitHandlers[i](instance)
        end

        despawn(instance)
    end

    Definitions[machineId] = nil
end

return Machines
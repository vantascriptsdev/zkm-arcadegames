local Config = lib.require "config"
local debugPrint = lib.require "shared.debugPrint"

local Admin = {}

local AdminConfig = Config.admin
local Registry = Config.registry

Admin.occupant = function(_) return nil end
Admin.trackWatcher = function(_) end
Admin.untrackWatcher = function(_) end

---@type table<string, integer>
local Moving = {}

function Admin.isMoving(machineId)
    return Moving[machineId] ~= nil
end

local nextSeq = 0

local function nextId()
    nextSeq = nextSeq + 1

    return ("%04d"):format(nextSeq)
end

local function ensureSchema()
    local sql = LoadResourceFile(cache.resource, "sql/schema.sql")

    if not sql or sql == "" then
        return lib.print.error("sql/schema.sql is missing or empty, the machine table was not created")
    end

    for statement in sql:gmatch("([^;]+)") do
        local trimmed = statement:gsub("^%s+", ""):gsub("%s+$", "")

        if trimmed ~= "" then MySQL.query.await(trimmed) end
    end
end

local COMMAND_NAME <const> = "arcadeadmin"
local COMMAND_ACE <const> = "command." .. COMMAND_NAME

local function allowed(source)
    return IsPlayerAceAllowed(source, COMMAND_ACE)
end

local function registerMachine(id, game, x, y, z, heading, createdBy, createdAt)
    Registry[id] = {
        id = id,
        game = game,
        coords = vector4(x, y, z, heading),
        position = vector3(x, y, z),
        createdBy = createdBy,
        createdAt = createdAt,
    }

    Admin.trackWatcher(id)
end

local function loadMachines()
    local rows = MySQL.query.await(
        "SELECT id, game, x, y, z, heading, created_by, created_at FROM zkm_arcade_machines"
    ) or {}

    for i = 1, #rows do
        local row = rows[i]

        registerMachine(row.id, row.game, tonumber(row.x) or 0, tonumber(row.y) or 0, tonumber(row.z) or 0,
            tonumber(row.heading) or 0, row.created_by, tonumber(row.created_at) or 0)
    end
end

---@return ArcadeAdminMachine[]
function Admin.list()
    local machines = {}
    local count = 0

    for id, machine in pairs(Registry) do
        count = count + 1
        machines[count] = {
            id = id,
            game = machine.game,
            x = machine.coords.x,
            y = machine.coords.y,
            z = machine.coords.z,
            heading = machine.coords.w,
            createdBy = machine.createdBy,
            createdAt = machine.createdAt,
            occupiedBy = Admin.occupant(id) or nil,
        }
    end

    return machines
end

---@return { id: string, game: ArcadeGameId, x: number, y: number, z: number, heading: number }[]
function Admin.spawnList()
    local rows = {}
    local count = 0

    for id, machine in pairs(Registry) do
        count = count + 1
        rows[count] = {
            id = id,
            game = machine.game,
            x = machine.coords.x,
            y = machine.coords.y,
            z = machine.coords.z,
            heading = machine.coords.w,
        }
    end

    return rows
end

Citizen.CreateThread(function()
    ensureSchema()
    nextSeq = MySQL.scalar.await("SELECT MAX(CAST(id AS UNSIGNED)) FROM zkm_arcade_machines") or 0
    loadMachines()
end)

---@return ArcadeAdminMachinesResult
lib.callback.register("zkm-arcadegames:adminFetch", function(source)
    if not allowed(source) then return { ok = false, reason = "no_permission" } end

    return { ok = true, machines = Admin.list() }
end)

---@return ArcadeAdminResult
lib.callback.register("zkm-arcadegames:adminCreate", function(source)
    if not allowed(source) then return { ok = false, reason = "no_permission" } end

    return { ok = true }
end)

lib.callback.register("zkm-arcadegames:adminMove", function(source, machineId)
    if not allowed(source) then return { ok = false, reason = "no_permission" } end
    if Admin.occupant(machineId) then return { ok = false, reason = "occupied" } end

    local machine = Registry[machineId]

    if not machine then return { ok = false, reason = "unknown_machine" } end

    Moving[machineId] = source

    return {
        ok = true,
        game = machine.game,
        x = machine.coords.x,
        y = machine.coords.y,
        z = machine.coords.z,
        heading = machine.coords.w,
    }
end)

RegisterNetEvent("zkm-arcadegames:adminMoveCancel", function(machineId)
    local src = source

    if Moving[machineId] == src then Moving[machineId] = nil end
end)

AddEventHandler("playerDropped", function()
    local src = source

    for machineId, holder in pairs(Moving) do
        if holder == src then Moving[machineId] = nil end
    end
end)

lib.callback.register("zkm-arcadegames:adminTeleport", function(source, machineId)
    if not allowed(source) then return { ok = false, reason = "no_permission" } end

    local machine = Registry[machineId]

    if not machine then return { ok = false, reason = "unknown_machine" } end

    return {
        ok = true,
        x = machine.coords.x,
        y = machine.coords.y,
        z = machine.coords.z,
        heading = machine.coords.w,
    }
end)

---@return ArcadeAdminResult
lib.callback.register("zkm-arcadegames:adminDelete", function(source, machineId)
    if not allowed(source) then return { ok = false, reason = "no_permission" } end
    if not Registry[machineId] then return { ok = false, reason = "unknown_machine" } end
    if Admin.occupant(machineId) then return { ok = false, reason = "occupied" } end

    MySQL.update.await("DELETE FROM zkm_arcade_machines WHERE id = ?", { machineId })

    Registry[machineId] = nil
    Admin.untrackWatcher(machineId)

    TriggerClientEvent("zkm-arcadegames:adminMachineRemoved", -1, machineId)

    debugPrint("info", ("Admin %s (%d) deleted machine %s")
        :format(GetPlayerName(source) or source, source, machineId))

    return { ok = true }
end)

---@return ArcadeAdminResult
lib.callback.register("zkm-arcadegames:adminSave", function(source, payload)
    if not allowed(source) then return { ok = false, reason = "no_permission" } end
    if type(payload) ~= "table" then return { ok = false, reason = "bad_request" } end

    local mode = payload.mode
    local game = payload.game
    local x = tonumber(payload.x)
    local y = tonumber(payload.y)
    local z = tonumber(payload.z)
    local heading = tonumber(payload.heading)

    if not Config.games[game] then return { ok = false, reason = "bad_request" } end
    if not (x and y and z and heading) then return { ok = false, reason = "bad_request" } end

    if mode == "move" then
        local machineId = payload.machineId

        local existing = Registry[machineId]

        if not machineId or not existing then return { ok = false, reason = "unknown_machine" } end

        MySQL.update.await(
            "UPDATE zkm_arcade_machines SET game = ?, x = ?, y = ?, z = ?, heading = ? WHERE id = ?",
            { game, x, y, z, heading, machineId }
        )

        registerMachine(machineId, game, x, y, z, heading, existing.createdBy, existing.createdAt)
        Moving[machineId] = nil

        TriggerClientEvent("zkm-arcadegames:adminMachineUpserted", -1, {
            id = machineId, game = game, x = x, y = y, z = z, heading = heading,
        })

        debugPrint("info", ("Admin %s (%d) moved machine %s")
            :format(GetPlayerName(source) or source, source, machineId))

        return { ok = true }
    end

    local id = nextId()
    local createdBy = GetPlayerName(source) or tostring(source)
    local createdAt = os.time()

    MySQL.insert.await(
        "INSERT INTO zkm_arcade_machines (id, game, x, y, z, heading, created_by, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        { id, game, x, y, z, heading, createdBy, createdAt }
    )

    registerMachine(id, game, x, y, z, heading, createdBy, createdAt)

    TriggerClientEvent("zkm-arcadegames:adminMachineUpserted", -1, {
        id = id, game = game, x = x, y = y, z = z, heading = heading,
    })

    debugPrint("info", ("Admin %s (%d) created machine %s (%s)")
        :format(GetPlayerName(source) or source, source, id, game))

    return { ok = true }
end)

lib.callback.register("zkm-arcadegames:adminSpawnList", function()
    return Admin.spawnList()
end)

lib.addCommand(COMMAND_NAME, {
    help = "Open the arcade machine manager",
    restricted = AdminConfig.ace,
}, function(source)
    TriggerClientEvent("zkm-arcadegames:adminOpenCommand", source)
end)

return Admin
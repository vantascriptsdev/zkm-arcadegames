local Machines = lib.require "client.modules.machines"
local Play = lib.require "client.modules.play"
local Target = lib.require "client.modules.target"

local function canPlay(machineId)
    return not Machines.isOccupied(machineId) and Play.active() == nil
end

---@param instance table machine instance that just streamed in
local function addInteraction(instance)
    local machineId = instance.id

    Target.add(instance, function()
        return canPlay(machineId)
    end, function()
        Play.start(machineId)
    end)
end

-- this has to be done here because play.lua cannot be imported in machines.lua (because of a circular require)
Machines.onEnter(addInteraction)
Machines.onExit(Target.remove)

Machines.init()

AddEventHandler("onResourceStop", function(resource)
    if resource ~= cache.resource then return end

    Play.stop(false)
    lib.hideTextUI()
    Machines.cleanup()
end)
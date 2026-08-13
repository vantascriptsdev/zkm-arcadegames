local Config = lib.require "config"

local Target = {}

local TargetConfig = Config.target
local INTERACT_CONTROL <const> = 38 -- E key
local OPTION_PREFIX <const> = "zkm_arcade_play_"

local Points = {}

---@type table<string, ArcadeTargetProvider>
local Providers = {}

Providers.ox_target = {
    add = function(instance, canInteract, onSelect)
        exports.ox_target:addLocalEntity(instance.entity, {
            {
                name = OPTION_PREFIX .. instance.id,
                icon = TargetConfig.icon,
                label = TargetConfig.label,
                distance = TargetConfig.distance,
                canInteract = canInteract,
                onSelect = onSelect,
            }
        })
    end,
    remove = function(instance)
        exports.ox_target:removeLocalEntity(instance.entity, OPTION_PREFIX .. instance.id)
    end,
}

-- example for another target resource, uncomment/adjust and add its resource name to
-- PROVIDER_ORDER:
--
-- Providers.qb_target = {
--     add = function(instance, canInteract, onSelect)
--         exports["qb-target"]:AddTargetEntity(instance.entity, {
--             options = {
--                 {
--                     icon = TargetConfig.icon,
--                     label = TargetConfig.label,
--                     canInteract = canInteract,
--                     action = onSelect,
--                 }
--             },
--             distance = TargetConfig.distance,
--         })
--     end,
--     remove = function(instance)
--         exports["qb-target"]:RemoveTargetEntity(instance.entity)
--     end,
-- }

-- if you added a new provider please make sure to add it here
local PROVIDER_ORDER <const> = { "ox_target" }

local activeProvider

for i = 1, #PROVIDER_ORDER do
    local resource = PROVIDER_ORDER[i]

    if GetResourceState(resource) ~= "missing" then
        activeProvider = Providers[resource]
        break
    end
end

if not activeProvider then
    lib.print.info("no supported target resource found, falling back to proximity interaction.")
end

---@param instance table machine instance that just streamed in
---@param canInteract fun(): boolean
---@param onSelect fun()
function Target.add(instance, canInteract, onSelect)
    if activeProvider then
        activeProvider.add(instance, canInteract, onSelect)
        return
    end

    local prompt <const> = ("[E] %s"):format(TargetConfig.label)
    local point = lib.points.new({
        coords = instance.position,
        distance = TargetConfig.distance,
    })

    function point:onEnter()
        if canInteract() then
            lib.showTextUI(prompt)
            self.prompting = true
        end
    end

    function point:onExit()
        if self.prompting then
            lib.hideTextUI()
            self.prompting = false
        end
    end

    function point:nearby()
        local allowed = canInteract()

        if allowed ~= self.prompting then
            if allowed then lib.showTextUI(prompt) else lib.hideTextUI() end

            self.prompting = allowed
        end

        if allowed and IsControlJustReleased(0, INTERACT_CONTROL) then
            lib.hideTextUI()
            self.prompting = false

            Citizen.CreateThread(onSelect)
        end
    end

    Points[instance.id] = point
end

---@param instance table machine instance that's about to stream out
function Target.remove(instance)
    if activeProvider then
        activeProvider.remove(instance)
        return
    end

    local point = Points[instance.id]

    if point then
        point:remove()
        Points[instance.id] = nil
    end
end

return Target
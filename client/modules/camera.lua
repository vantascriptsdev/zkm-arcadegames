local Config = lib.require "config"

local Camera = {}

local CamConfig = Config.camera
local OFFSETS <const> = {
    topLeft     = vector3(-0.279, 0.020, 1.405),
    topRight    = vector3(0.279, 0.020, 1.405),
    bottomLeft  = vector3(-0.279, -0.18, 1.03),
    bottomRight = vector3(0.279, -0.18, 1.03),
}

local activeCam, blendCam

local function normalize(vec)
    local length = #vec
    return length > 0.0 and (vec / length) or vec
end

local function cross(lhs, rhs)
    return vector3(
        lhs.y * rhs.z - lhs.z * rhs.y,
        lhs.z * rhs.x - lhs.x * rhs.z,
        lhs.x * rhs.y - lhs.y * rhs.x
    )
end

local function dot(lhs, rhs)
    return lhs.x * rhs.x + lhs.y * rhs.y + lhs.z * rhs.z
end

local function rotateAbout(vec, axis, degrees)
    if degrees == 0.0 then return vec end

    local radians = math.rad(degrees)
    local cosAngle, sinAngle = math.cos(radians), math.sin(radians)

    return vec * cosAngle + cross(axis, vec) * sinAngle + axis * (dot(axis, vec) * (1.0 - cosAngle))
end

local function dirToRot(dir)
    return vector3(
        math.deg(math.asin(math.max(-1.0, math.min(1.0, dir.z)))),
        0.0,
        math.deg(math.atan(-dir.x, dir.y))
    )
end

local function screenBasis()
    local centre = (OFFSETS.topLeft + OFFSETS.topRight + OFFSETS.bottomLeft + OFFSETS.bottomRight) / 4.0
    local rightEdge = OFFSETS.topRight - OFFSETS.topLeft
    local upEdge = OFFSETS.topLeft - OFFSETS.bottomLeft

    local right = normalize(rightEdge)
    local up = normalize(upEdge)
    local normal = normalize(cross(right, up))

    if CamConfig.flipNormal then normal = -normal end

    return centre, right, up, normal, #rightEdge, #upEdge
end

local function fitDistance(width, height)
    local aspect = GetAspectRatio(false)

    if aspect ~= aspect or aspect <= 0.0 then aspect = 16.0 / 9.0 end

    local halfFov = math.tan(math.rad(CamConfig.fov) * 0.5)
    local fill = math.max(0.05, math.min(1.0, CamConfig.fill))

    local byHeight = (height / (2.0 * fill)) / halfFov
    local byWidth = (width / (2.0 * fill)) / (halfFov * aspect)

    return math.max(CamConfig.minDistance, byHeight, byWidth)
end

function Camera.frame(entity)
    local centre, right, up, normal, width, height = screenBasis()
    local distance = fitDistance(width, height)

    local axis = rotateAbout(normal, right, -CamConfig.pitchBias)
    axis = normalize(rotateAbout(axis, up, CamConfig.yawBias))

    local localPos = centre
        + axis * distance
        + right * CamConfig.lateralOffset
        + up * CamConfig.heightOffset

    local pos = GetOffsetFromEntityInWorldCoords(entity, localPos.x, localPos.y, localPos.z)
    local lookAt = GetOffsetFromEntityInWorldCoords(entity, centre.x, centre.y, centre.z)

    return {
        pos = pos,
        rot = dirToRot(normalize(lookAt - pos)),
        lookAt = lookAt,
        distance = distance,
        fov = CamConfig.fov,
    }
end

function Camera.screenRect(entity)
    local corners = { OFFSETS.topLeft, OFFSETS.topRight, OFFSETS.bottomLeft, OFFSETS.bottomRight }
    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge

    for i = 1, 4 do
        local corner = corners[i]
        local world = GetOffsetFromEntityInWorldCoords(entity, corner.x, corner.y, corner.z)
        local onScreen, x, y = GetScreenCoordFromWorldCoord(world.x, world.y, world.z)

        if not onScreen then return end

        if x < minX then minX = x end
        if y < minY then minY = y end
        if x > maxX then maxX = x end
        if y > maxY then maxY = y end
    end

    return { x = minX, y = minY, w = maxX - minX, h = maxY - minY }
end

function Camera.enter(entity)
    local frame = Camera.frame(entity)

    Camera.destroy()

    local fromCoords = GetGameplayCamCoord()
    local fromRot = GetGameplayCamRot(2)

    blendCam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamCoord(blendCam, fromCoords.x, fromCoords.y, fromCoords.z)
    SetCamRot(blendCam, fromRot.x, fromRot.y, fromRot.z, 2)
    SetCamFov(blendCam, GetGameplayCamFov())

    activeCam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamCoord(activeCam, frame.pos.x, frame.pos.y, frame.pos.z)
    SetCamRot(activeCam, frame.rot.x, frame.rot.y, frame.rot.z, 2)
    SetCamFov(activeCam, frame.fov)
    SetCamNearClip(activeCam, CamConfig.nearClip)

    SetCamActiveWithInterp(activeCam, blendCam, CamConfig.enterMs, 1, 1)
    RenderScriptCams(true, false, 0, true, true)

    return frame
end

function Camera.exit()
    if not activeCam then return end

    local duration = CamConfig.exitMs
    local retiring, retiringBlend = activeCam, blendCam

    activeCam, blendCam = nil, nil

    RenderScriptCams(false, true, duration, true, true)

    Citizen.SetTimeout(duration + 100, function()
        if DoesCamExist(retiring) then DestroyCam(retiring, false) end
        if retiringBlend and DoesCamExist(retiringBlend) then DestroyCam(retiringBlend, false) end
    end)
end

function Camera.destroy()
    if activeCam then
        DestroyCam(activeCam, false)
        activeCam = nil
    end

    if blendCam then
        DestroyCam(blendCam, false)
        blendCam = nil
    end
end

return Camera
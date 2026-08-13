local Config = {}
Config.propModel = `vw_prop_vw_arcade_01a` -- the draw offsets are specifically tailored to this model, if you change it, you will have to rebase the offsets.

-- debug prints
Config.debug = true

-- 'auto', 'esx' or 'qbx'
Config.framework = "auto"

-- which money account bets come out of, 'money' is cash in hand on esx, 'bank' would be the bank
Config.account = {
    esx = "money",
    qbx = "cash",
}

-- if you dont want a game to be playable, set it to false
Config.games = {
    crash = true,
    plinko = true,
    hol = true, -- higher or lower
    mines = true,
}

Config.gameSettings = {
    -- target long-run return-to-player for every game in the arcade; 0.95 = a flat 5% house cut.
    -- & how this works is it basically re-calculates the odds based on this (takes a cut from it)
    houseEdge = 0.95,
    crash = {
        minBet = 100,
        maxBet = 10000,
        maxMultiplier = 40.0,
        growthPerTick = 0.0075, -- multiplier climbs 0.75% per tick, works out around 1.16x a second
        tickMs = 50, -- how often it ticks up, lower is smoother but the whole thing runs faster
        crashSpread = 0.97, -- how high the crash point can roll, nearer 1.0 = rare but huge rounds
        claimGraceMs = 1000, -- lag forgiveness on cashout so people with ping still get paid
    },
    plinko = {
        minBet = 250,
        maxBet = 25000,
        maxMultiplier = 170.0,
        -- board is a fixed 12 rows, each array needs exactly 13 numbers
        payouts = {
            LOW = { 6.04, 2.26, 1.51, 1.19, 1.08, 0.97, 0.54, 0.97, 1.08, 1.19, 1.51, 2.26, 6.04 },
            MED = { 28.27, 7.71, 2.57, 1.80, 1.16, 0.64, 0.39, 0.64, 1.16, 1.80, 2.57, 7.71, 28.27 },
            HIGH = { 162.94, 23.00, 7.76, 1.92, 0.67, 0.19, 0.19, 0.19, 0.67, 1.92, 7.76, 23.00, 162.94 },
        },
    },
    hol = {
        minBet = 100,
        maxBet = 5000,
        maxMultiplier = 10.0,
        maxRounds = 12, -- max amount of guesses
    },
    mines = {
        minBet = 100,
        maxBet = 10000,
        maxMultiplier = 2500.0, -- if you hit all 25 diamonds you get a huge payout, you can cap it here
        tiles = 25, -- board size, keep it a square number so the grid stays even (25 is 5x5)
        minBombs = 1,
        maxBombs = 24,
    },
}

Config.render = {
    drawDistance = 25.0,
    sleepDistance = 40.0, -- past this a machine's entity + dui screen don't even exist, saves CPU/memory
}

Config.target = {
    label = "Play",
    icon = "fa-solid fa-gamepad",
    distance = 1.6,
}

Config.camera = {
    fov = 40.0, -- zoom, smaller numbers zoom in harder
    fill = 0.72, -- how much of your monitor the machine screen takes up, 0.72 is 72%
    pitchBias = 0.0, -- tilt the cam up or down in degrees if the angle feels off
    yawBias = 0.0, -- same thing as pitchBias but left and right
    lateralOffset = 0.0, -- slide the cam sideways in meters
    heightOffset = 0.0,
    flipNormal = false, -- set true if the cam ends up behind or inside the machine
    minDistance = 0.35, -- never let the cam get closer than this or it clips through the screen
    nearClip = 0.05, -- how close things can get before they stop rendering, keep it tiny
    enterMs = 900,
    exitMs = 700,
    hidePed = true, -- hide your OWN ped while playing (just locally, others will still be able to see you playing an animation)
}

Config.anim = {
    male = { dict = "amb@prop_human_atm@male@base", clip = "base" },
    female = { dict = "amb@prop_human_atm@female@base", clip = "base" },
    standOffset = vector3(0.1, -0.75, 0.0), -- where the ped gets stood, in meters from the machine
}

-- keeps two people off the same machine, and stops anyone alt f4ing mid round to dodge a loss
Config.lock = {
    timeoutMs = 30000, -- the server has to see the player gone from the machine for this long before it frees the machine
    sweepMs = 10000, -- how often the server goes looking for dead sessions
    nuiReadyTimeoutMs = 8000, -- screen doesn't answer in this long, boot the player out with an error
    maxDistance = 5.0, -- you have to be this close in meters to claim a machine
}

Config.admin = {
    ace = {
        "group.admin"
    },
    placement = {
        steps = { 0.05, 0.1, 0.5, 1.0 },
        rotateSteps = { 0.5, 1.0, 5.0, 15.0 },
        minDistance = 1.0, -- minimum distance to the closest arcade machine
        repeatMs = 120,
    },
}

Config.registry = {}

for game in pairs(Config.games) do
    if not Config.gameSettings[game] then
        lib.print.warn(("Config.gameSettings has no entry for game %q, the NUI will fall back to its own bet limits"):format(tostring(game)))
    end
end

return Config
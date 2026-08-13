local Config = lib.require "config"

local Outcomes = {}

local HOUSE_EDGE <const> = Config.gameSettings.houseEdge

local CRASH_SPREAD <const> = Config.gameSettings.crash.crashSpread
local CRASH_GROWTH_PER_TICK <const> = Config.gameSettings.crash.growthPerTick
local CRASH_TICK_MS <const> = Config.gameSettings.crash.tickMs
local CRASH_CLAIM_GRACE_MS <const> = Config.gameSettings.crash.claimGraceMs

local HOL_MAX_ROUNDS <const> = Config.gameSettings.hol.maxRounds

local PLINKO_ROWS <const> = 12 -- NOTE: has to match ROWS in web/src/state/plinko.svelte.ts. (i do not recommend switching it up, it's not made for supporting much lower/higher values)
local PlinkoPayouts = Config.gameSettings.plinko.payouts

local MINES_TILES <const> = Config.gameSettings.mines.tiles
local MINES_MIN_BOMBS <const> = Config.gameSettings.mines.minBombs
local MINES_MAX_BOMBS <const> = Config.gameSettings.mines.maxBombs

local MIN_CRASH_POINT <const> = 1.01
local CARD_MIN_VALUE <const> = 2
local CARD_MAX_VALUE <const> = 14
local CARD_VALUE_COUNT <const> = CARD_MAX_VALUE - CARD_MIN_VALUE + 1
local SUIT_COUNT <const> = 4
local BASE_MULTIPLIER <const> = 1.0
local NO_PAYOUT <const> = 0.0
local COIN_FLIP <const> = 0.5

local function drawCard()
    return {
        value = math.random(CARD_MIN_VALUE, CARD_MAX_VALUE),
        suit = math.random(0, SUIT_COUNT - 1),
    }
end

local function createCrash()
    local roll = math.random() * CRASH_SPREAD

    return {
        crashAt = math.max(MIN_CRASH_POINT, (1 / (1 - roll)) * HOUSE_EDGE),
        startedAt = GetGameTimer(),
    }
end

local function createHol()
    local cards = {}

    for index = 1, HOL_MAX_ROUNDS + 1 do
        cards[index] = drawCard()
    end

    return { cards = cards, revealed = 1, streak = 0, fairMultiplier = 1.0, busted = false }
end

local function minesMultiplier(bombs, picks)
    local multiplier = HOUSE_EDGE

    for index = 0, picks - 1 do
        multiplier = multiplier * (MINES_TILES - index) / (MINES_TILES - bombs - index)
    end

    return multiplier
end

---@return ArcadeMinesOutcome?
---@return ArcadeBetError?
local function createMines(bombs)
    bombs = math.floor(tonumber(bombs) or 0)

    if bombs < MINES_MIN_BOMBS or bombs > MINES_MAX_BOMBS then return nil, "bad_bombs" end
    if bombs >= MINES_TILES then return nil, "bad_bombs" end

    local pool = {}

    for index = 1, MINES_TILES do
        pool[index] = index - 1
    end

    for index = MINES_TILES, 2, -1 do
        local swap = math.random(index)

        pool[index], pool[swap] = pool[swap], pool[index]
    end

    local bombTiles = {}
    local bombAt = {}

    for index = 1, bombs do
        local tile = pool[index]

        bombTiles[index] = tile
        bombAt[tile] = true
    end

    return {
        tiles = MINES_TILES,
        bombs = bombs,
        bombTiles = bombTiles,
        bombAt = bombAt,
        picked = {},
        picks = 0,
        busted = false,
    }
end

local function createPlinko(risk)
    local payouts = PlinkoPayouts[risk]

    if not payouts then return nil end

    local path = {}
    local drift = 0

    for row = 1, PLINKO_ROWS do
        local direction = math.random() < COIN_FLIP and -1 or 1

        path[row] = direction
        drift = drift + direction
    end

    local slot = (drift + PLINKO_ROWS) // 2

    return { path = path, slot = slot, multiplier = payouts[slot + 1] }
end

local OUTCOME_CREATORS <const> = {
    ["crash"] = createCrash,
    ["hol"] = createHol,
    ["plinko"] = function(risk)
        return createPlinko(risk)
    end,
    ["mines"] = function(bombs)
        return createMines(bombs)
    end
}

---@param game ArcadeGameId
---@param risk? ArcadeRiskLevel plinko only
---@param bombs? integer mines only
---@return ArcadeOutcome?
---@return ArcadeBetError?
function Outcomes.create(game, risk, bombs)
    local createOutcome = OUTCOME_CREATORS[game]
    if createOutcome then
        local param = game == "plinko" and risk or (game == "mines" and bombs or nil)
        return createOutcome(param)
    end

    return nil
end

---@param round ArcadeRound
---@return table
function Outcomes.opening(round)
    local outcome = round.outcome

    if round.game == "crash" then return {} end
    if round.game == "hol" then return { card = outcome.cards[1] } end
    if round.game == "mines" then return { tiles = outcome.tiles, bombs = outcome.bombs } end

    return { path = outcome.path, slot = outcome.slot, multiplier = outcome.multiplier }
end

---@param round ArcadeRound
---@param tile integer 0-indexed
---@return ArcadeMinesPick?
---@return ArcadeBetError?
function Outcomes.pick(round, tile)
    local outcome = round.outcome
    local safeTotal <const> = outcome.tiles - outcome.bombs

    if outcome.busted or outcome.picks >= safeTotal then return nil, "round_over" end

    tile = math.floor(tonumber(tile) or -1)

    if tile < 0 or tile >= outcome.tiles then return nil, "bad_tile" end
    if outcome.picked[tile] then return nil, "bad_tile" end

    outcome.picked[tile] = true

    if outcome.bombAt[tile] then
        outcome.busted = true

        return {
            tile = tile,
            bomb = true,
            gems = outcome.picks,
            multiplier = NO_PAYOUT,
            exhausted = false,
            bombTiles = outcome.bombTiles,
        }
    end

    outcome.picks = outcome.picks + 1

    local exhausted <const> = outcome.picks >= safeTotal

    return {
        tile = tile,
        bomb = false,
        gems = outcome.picks,
        multiplier = Outcomes.multiplier(round),
        exhausted = exhausted,
        bombTiles = exhausted and outcome.bombTiles or nil,
    }
end

---@param round ArcadeRound
---@param higher boolean
---@return ArcadeReveal?
---@return ArcadeBetError?
function Outcomes.reveal(round, higher)
    local outcome = round.outcome
    local total <const> = #outcome.cards

    if outcome.busted or outcome.revealed >= total then return nil, "round_over" end

    local current = outcome.cards[outcome.revealed]
    local revealed = outcome.cards[outcome.revealed + 1]
    local correct

    if higher then
        correct = revealed.value > current.value
    else
        correct = revealed.value < current.value
    end

    outcome.revealed = outcome.revealed + 1

    if correct then
        local winCount = higher and (CARD_MAX_VALUE - current.value) or (current.value - CARD_MIN_VALUE)

        outcome.streak = outcome.streak + 1
        outcome.fairMultiplier = outcome.fairMultiplier * CARD_VALUE_COUNT / winCount
    else
        outcome.busted = true
    end

    return {
        card = revealed,
        correct = correct,
        streak = outcome.streak,
        multiplier = Outcomes.multiplier(round),
        exhausted = outcome.revealed >= total,
    }
end

---@param round ArcadeRound
---@return number
function Outcomes.multiplier(round)
    local outcome = round.outcome

    if round.game == "hol" then
        if outcome.busted then return NO_PAYOUT end

        return HOUSE_EDGE * outcome.fairMultiplier
    end

    if round.game == "mines" then
        if outcome.busted then return NO_PAYOUT end

        return minesMultiplier(outcome.bombs, outcome.picks)
    end

    if round.game == "plinko" then return outcome.multiplier end

    return NO_PAYOUT
end

---@param round ArcadeRound
---@param claimed number
---@return number? multiplier
---@return ArcadeBetError? reason
function Outcomes.settleCrash(round, claimed)
    local outcome = round.outcome

    if claimed <= BASE_MULTIPLIER then return NO_PAYOUT end
    if claimed >= outcome.crashAt then return nil, "outcome_mismatch" end

    local elapsed = (GetGameTimer() + CRASH_CLAIM_GRACE_MS) - outcome.startedAt
    local earned = (1 + CRASH_GROWTH_PER_TICK) ^ (elapsed / CRASH_TICK_MS)

    if claimed > earned then return nil, "outcome_mismatch" end

    return claimed
end

---@param round ArcadeRound
---@return integer ms until the round crashes if nobody cashes out
function Outcomes.calculateBustDelay(round)
    local ticks = math.log(round.outcome.crashAt) / math.log(1 + CRASH_GROWTH_PER_TICK)

    return math.floor(ticks * CRASH_TICK_MS)
end

return Outcomes
---@alias ArcadeGameId 'crash' | 'plinko' | 'hol' | 'mines'

---@alias ArcadeLockError 'busy' | 'unknown_machine' | 'too_far'

---@class ArcadePropOffsets
---@field topLeft vector3
---@field topRight vector3
---@field bottomLeft vector3
---@field bottomRight vector3

---@alias ArcadeRiskLevel 'LOW' | 'MED' | 'HIGH'

---@class ArcadeGameSettings
---@field minBet integer smallest stake the cabinet will accept
---@field maxBet integer largest stake the cabinet will accept
---@field maxMultiplier number largest payout multiple the server will honour when settling
---@field growthPerTick? number crash: multiplier growth applied every tickMs
---@field tickMs? integer crash: milliseconds between growth steps
---@field crashSpread? number crash: width of the crash point distribution
---@field claimGraceMs? integer crash: latency allowance when validating a cash out
---@field payouts? table<ArcadeRiskLevel, number[]> plinko: hand-tuned slot payouts, indexed left to right
---@field maxRounds? integer hol: guesses available before the deck runs out
---@field tiles? integer mines: tiles on the board, a square number
---@field minBombs? integer mines: fewest bombs the cabinet will arm
---@field maxBombs? integer mines: most bombs the cabinet will arm, always below tiles

---@class ArcadeRenderConfig
---@field drawDistance number metres beyond which a cabinet's screen stops drawing
---@field sleepDistance number metres beyond which the draw loop drops to a slow poll

---@class ArcadeTargetConfig
---@field label string
---@field icon string
---@field distance number interaction range, used by ox_target and the fallback prompt

---@class ArcadeCameraConfig
---@field fov number vertical field of view, degrees
---@field fill number fraction of the viewport height the screen quad should fill
---@field pitchBias number degrees above (+) or below (-) the screen normal
---@field yawBias number degrees to the viewer's right (+) or left (-)
---@field lateralOffset number metres along the screen's horizontal axis
---@field heightOffset number metres along the screen's vertical axis
---@field flipNormal boolean invert the derived screen normal
---@field minDistance number hard floor on camera distance, metres
---@field nearClip number
---@field enterMs integer blend duration into the cabinet camera
---@field exitMs integer blend duration back to the gameplay camera
---@field hidePed boolean hide the player's own ped while playing

---@class ArcadeAnimClip
---@field dict string
---@field clip string

---@class ArcadeAnimConfig
---@field male ArcadeAnimClip
---@field female ArcadeAnimClip
---@field standOffset vector3 metres from the cabinet origin, where the ped is stood to play

---@class ArcadeLockConfig
---@field timeoutMs integer release a lock this long after its holder stops looking like a live session
---@field sweepMs integer how often the server sweeps for stale locks
---@field maxDistance number server-side range check when claiming a cabinet

---@class ArcadeConfig
---@field propModel integer
---@field duiPage string
---@field framework 'auto' | 'esx' | 'qbx'
---@field account table<'esx' | 'qbx', string> per-framework account the stake is taken from and paid back into
---@field busyKeyPrefix string GlobalState key prefix for a cabinet's busy flag
---@field games table<string, boolean>
---@field gameSettings table<ArcadeGameId, ArcadeGameSettings> per-game bet limits, forwarded to the UI; also carries a shared `houseEdge` key (see config.lua) that crash, mines, and hol all price their odds off
---@field propOffsets ArcadePropOffsets
---@field registry table<string, ArcadeMachine> machines loaded from the DB by the admin tool, keyed by id
---@field render ArcadeRenderConfig
---@field target ArcadeTargetConfig
---@field camera ArcadeCameraConfig
---@field anim? ArcadeAnimConfig nil disables the ped idle entirely
---@field lock ArcadeLockConfig

---@class ArcadeMachine
---@field id string stable identifier, the zkm_arcade_machines primary key
---@field game ArcadeGameId
---@field coords vector4 world position + heading
---@field position vector3 coords.xyz, cached for distance checks
---@field createdBy string display name of the admin who placed it
---@field createdAt integer unix timestamp in seconds, os.time()

---@class ArcadeMachineInstance : ArcadeMachine
---@field entity integer local (non-networked) prop handle
---@field dui integer DUI object handle, created once and never destroyed
---@field txdName string
---@field occupied boolean mirror of GlobalState['machine_busy_<id>']
---@field inRange boolean the local ped is close enough to draw, and so to spectate
---@field ready boolean the DUI page has loaded and will accept messages

---@class ArcadeScreenRect
---@field x number
---@field y number
---@field w number
---@field h number

---@class ArcadeCamFrame
---@field pos vector3
---@field rot vector3 GTA rotation order 2
---@field lookAt vector3 world-space centre of the screen quad
---@field distance number metres from the screen centre along the view axis
---@field fov number

---@class ArcadeLock
---@field source integer
---@field staleSince? integer GetGameTimer() when the session first stopped looking alive
---@field stake integer the holder's current bet, mirrored to spectators before they press play
---@field stakeSentAt? integer GetGameTimer() of the last stake broadcast
---@field stakePending? boolean a stake broadcast is throttled and waiting to flush

---@class ArcadeCard
---@field value integer 2-14, where 11-14 are J/Q/K/A
---@field suit integer 0-3, matching the suit order the NUI renders

---@class ArcadeCrashOutcome
---@field crashAt number multiplier the round busts at
---@field startedAt integer GetGameTimer() when the round was created

---@class ArcadeHolOutcome
---@field cards ArcadeCard[] pre-dealt run, revealed to the client one at a time
---@field revealed integer how many cards the client has been shown
---@field streak integer correct guesses so far
---@field fairMultiplier number running product of 1/trueOdds for each correct guess, before houseEdge
---@field busted boolean

---@class ArcadePlinkoOutcome
---@field path integer[] per-row drift, -1 left or 1 right
---@field slot integer landing slot, 0-indexed from the left
---@field multiplier number payout for that slot at the chosen risk

---@class ArcadeMinesOutcome
---@field tiles integer board size the round was opened with
---@field bombs integer bombs hidden on the board
---@field bombTiles integer[] bomb positions, 0-indexed, never sent until the round is over
---@field bombAt table<integer, boolean> bombTiles as a set, for pick lookups
---@field picked table<integer, boolean> tiles the client has already spent
---@field picks integer gems found so far
---@field busted boolean

---@alias ArcadeOutcome ArcadeCrashOutcome | ArcadeHolOutcome | ArcadePlinkoOutcome | ArcadeMinesOutcome

---@class ArcadeRound
---@field machineId string
---@field game ArcadeGameId
---@field bet integer stake already taken from the player
---@field outcome ArcadeOutcome rolled when the stake was taken, consumed on settle

---@class ArcadeReveal
---@field card ArcadeCard
---@field correct boolean
---@field streak integer
---@field multiplier number payout multiple if the player cashes out now
---@field exhausted boolean no cards left, the client must cash out

---@class ArcadeMinesPick
---@field tile integer tile the player spent, 0-indexed
---@field bomb boolean the tile was a bomb and the round is over
---@field gems integer gems found so far
---@field multiplier number payout multiple if the player cashes out now
---@field exhausted boolean every safe tile is found, the client must cash out
---@field bombTiles? integer[] every bomb position, only once the round is over

---@alias ArcadeBetError 'no_session' | 'no_round' | 'round_open' | 'unknown_game' | 'bad_bet' | 'no_funds' | 'bad_request' | 'round_over' | 'outcome_mismatch' | 'bad_bombs' | 'bad_tile'

---@class ArcadeBetResult
---@field ok boolean
---@field balance? integer balance after the stake or payout was applied
---@field reason? ArcadeBetError
---@field outcome? table what the client needs to animate the round
---@field bombTiles? integer[] mines: bomb positions, released once the round is settled

---@class ArcadeRevealResult
---@field ok boolean
---@field reason? ArcadeBetError
---@field reveal? ArcadeReveal

---@class ArcadePickResult
---@field ok boolean
---@field reason? ArcadeBetError
---@field pick? ArcadeMinesPick

---@class ArcadeLockResult
---@field ok boolean
---@field balance? integer
---@field reason? ArcadeLockError

---@class ArcadeEnterPlayMessage
---@field action 'enterPlay'
---@field machineId string
---@field game ArcadeGameId
---@field rect? ArcadeScreenRect nil when part of the quad is off-camera
---@field gameSettings table<ArcadeGameId, ArcadeGameSettings>
---@field balance integer

---@class ArcadeSetConfigMessage
---@field action 'setConfig'
---@field gameSettings table<ArcadeGameId, ArcadeGameSettings>

---@class ArcadeCrashBustedMessage
---@field action 'crashBusted'
---@field crashAt number multiplier the round busted at, pushed once it actually happened

---@class ArcadeSpectateSyncMessage
---@field action 'spectateSync'
---@field game ArcadeGameId
---@field stake integer the holder's bet as it stands right now
---@field roundLive boolean a round is already animating, so this watcher waits for the next one

---@class ArcadeSpectateStakeMessage
---@field action 'spectateStake'
---@field stake integer

---@class ArcadeSpectateRoundMessage
---@field action 'spectateRound'
---@field game ArcadeGameId
---@field bet integer stake the round was opened with
---@field risk? ArcadeRiskLevel plinko only
---@field outcome table the same opening payload the active player animates

---@class ArcadeSpectateRevealMessage
---@field action 'spectateReveal'
---@field reveal ArcadeReveal

---@class ArcadeSpectatePickMessage
---@field action 'spectatePick'
---@field pick ArcadeMinesPick

---@class ArcadeSpectateSettleMessage
---@field action 'spectateSettle'
---@field multiplier number payout multiple the server honoured, 0 when the round was lost
---@field bombTiles? integer[] mines: bomb positions, so a watched board finishes revealing

---@class ArcadeSpectateExitMessage
---@field action 'spectateExit'

---@class ArcadeSpectateBustMessage
---@field action 'spectateBust'
---@field crashAt number crash: multiplier the round busted at, revealed only once it happened

---@alias ArcadeSpectateMessage ArcadeSpectateSyncMessage | ArcadeSpectateStakeMessage | ArcadeSpectateRoundMessage | ArcadeSpectateRevealMessage | ArcadeSpectatePickMessage | ArcadeSpectateSettleMessage | ArcadeSpectateExitMessage | ArcadeSpectateBustMessage

---@class ArcadeTargetProvider
---@field add fun(instance: table, canInteract: fun(): boolean, onSelect: fun())
---@field remove fun(instance: table)

---@alias ArcadeAdminError 'no_permission' | 'unknown_machine' | 'occupied' | 'placement_open' | 'bad_request'

---@class ArcadeAdminMachine
---@field id string stable machine identifier, also the manager sort key
---@field game ArcadeGameId
---@field x number
---@field y number
---@field z number
---@field heading number degrees, 0-360
---@field createdBy string display name of the admin who placed it
---@field createdAt integer unix timestamp in seconds, os.time()
---@field occupiedBy? string player name while in use, nil when free

---@class ArcadeAdminOccupancy
---@field id string
---@field occupiedBy? string

---@alias ArcadePlacementMode 'new' | 'move'
---@alias ArcadePlacementStep number metres per W/A/S/D/Q/R nudge, one of Config.admin.placement.steps

---@class ArcadeAdminResult
---@field ok boolean
---@field reason? ArcadeAdminError

---@class ArcadeAdminMachinesResult : ArcadeAdminResult
---@field machines? ArcadeAdminMachine[]

---@class ArcadeAdminOpenMessage
---@field action 'adminOpen'
---@field machines? ArcadeAdminMachine[]
---@field loading? boolean

---@class ArcadeAdminCloseMessage
---@field action 'adminClose'

---@class ArcadeAdminLoadingMessage
---@field action 'adminLoading'
---@field loading boolean

---@class ArcadeAdminOccupancyMessage
---@field action 'adminOccupancy'
---@field occupancy ArcadeAdminOccupancy[]

---@class ArcadeEnterPlacementMessage
---@field action 'enterPlacement'
---@field mode ArcadePlacementMode
---@field machineId? string
---@field game ArcadeGameId
---@field x number
---@field y number
---@field z number
---@field heading number
---@field step? ArcadePlacementStep
---@field valid? boolean
---@field reason? string

---@class ArcadePlacementTransformMessage
---@field action 'placementTransform'
---@field x number
---@field y number
---@field z number
---@field heading number

---@class ArcadePlacementStateMessage
---@field action 'placementState'
---@field game? ArcadeGameId
---@field step? ArcadePlacementStep
---@field valid? boolean
---@field reason? string

---@class ArcadeExitPlacementMessage
---@field action 'exitPlacement'

---@alias ArcadeAdminMessage ArcadeAdminOpenMessage | ArcadeAdminCloseMessage | ArcadeAdminLoadingMessage | ArcadeAdminOccupancyMessage | ArcadeEnterPlacementMessage | ArcadePlacementTransformMessage | ArcadePlacementStateMessage | ArcadeExitPlacementMessage
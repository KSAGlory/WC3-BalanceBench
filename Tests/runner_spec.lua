-- Run with a standalone Lua 5.3+ interpreter:
-- lua Tests/runner_spec.lua Scripts/BalanceBench.lua
-- This uses fake WC3 natives and does not validate the actual game's behavior.

local source = (arg and arg[1]) or "Scripts/BalanceBench.lua"
local units, timers, messages = {}, {}, {}
local failCreateAt = nil
local createAttempts = 0
local removeCalls = 0

UNIT_TYPE_DEAD = "DEAD"
UNIT_STATE_LIFE = "LIFE"
UNIT_STATE_MAX_LIFE = "MAX_LIFE"
UNIT_STATE_MANA = "MANA"
UNIT_STATE_MAX_MANA = "MAX_MANA"
PLAYER_SLOT_STATE_PLAYING = "PLAYING"

function Player(index) return index end
function GetPlayerSlotState(_) return PLAYER_SLOT_STATE_PLAYING end
function GetPlayableMapRect() return { minX = -2048, maxX = 2048, minY = -2048, maxY = 2048 } end
function GetRectMinX(rect) return rect.minX end
function GetRectMaxX(rect) return rect.maxX end
function GetRectMinY(rect) return rect.minY end
function GetRectMaxY(rect) return rect.maxY end
function FourCC(text) return text end
function CreateTrigger() return {} end
function TriggerRegisterPlayerChatEvent() return {} end
function TriggerAddAction(trigger, fn) trigger.action = fn end
function DestroyTrigger(trigger) trigger.destroyed = true end
function GetEventPlayerChatString() return "" end
function DisplayTimedTextToPlayer(_, _, _, _, value) table.insert(messages, value) end
function CreateTimer()
    local timer = { active = false }
    table.insert(timers, timer)
    return timer
end
function TimerStart(timer, _, _, callback) timer.active = true; timer.callback = callback end
function PauseTimer(timer) timer.active = false end
function DestroyTimer(timer) timer.active = false; timer.destroyed = true end
function CreateUnit(owner, rawcode, x, y)
    createAttempts = createAttempts + 1
    if failCreateAt == createAttempts then return nil end
    local unit = { owner = owner, rawcode = rawcode, x = x, y = y, hp = 100, dead = false, removed = false }
    table.insert(units, unit)
    return unit
end
function GetUnitTypeId(unit) return unit.removed and 0 or unit.rawcode end
function GetWidgetLife(unit) return unit.dead and 0 or unit.hp end
function IsUnitType(unit, kind) return kind == UNIT_TYPE_DEAD and unit.dead end
function PauseUnit(unit, paused) unit.paused = paused end
function GetUnitState(unit, kind)
    if kind == UNIT_STATE_MAX_LIFE then return 100 end
    if kind == UNIT_STATE_MAX_MANA then return 0 end
    return unit.hp
end
function SetUnitState(unit, kind, value)
    if kind == UNIT_STATE_LIFE then unit.hp = value end
end
function IssuePointOrder(unit, order, x, y)
    assert(order == "attack")
    unit.order = { x = x, y = y }
    unit.orderActive = true
    return true
end
function GetUnitCurrentOrder(unit) return unit.orderActive and 1 or 0 end
function IssueTargetOrder(unit, order, target)
    assert(order == "attack")
    unit.target = target
    unit.orderActive = true
    return true
end
function RemoveUnit(unit)
    assert(not unit.removed, "double removal")
    unit.removed = true
    removeCalls = removeCalls + 1
end

local function step(times)
    for _ = 1, times do
        for _, timer in ipairs(timers) do
            if timer.active then timer.callback() end
        end
    end
end

local function active_units()
    local result = {}
    for _, unit in ipairs(units) do
        if not unit.removed then table.insert(result, unit) end
    end
    return result
end

local function active_timers()
    local count = 0
    for _, timer in ipairs(timers) do if timer.active then count = count + 1 end end
    return count
end

local function config()
    return {
        scenario = "fixture", label = "baseline", rounds = 2,
        timeoutSeconds = 1, pollSeconds = 0.1, intermissionSeconds = 0,
        teamA = { rawcode = "hfoo", count = 1 },
        teamB = { rawcode = "ogru", count = 1 },
        arena = {
            centerX = 0, centerY = 0, halfWidth = 1024,
            halfHeight = 768, separation = 768, spacing = 96,
        }
    }
end

assert(loadfile(source))()

-- Rejected configuration does not install callbacks or spawn anything.
local bad = config()
bad.rounds = 3
local valid, reason = BalanceBench.install(bad)
assert(not valid and reason:find("rounds"))
assert(createAttempts == 0)

local unrelated = { rawcode = "keep", hp = 100, dead = false, removed = false }
table.insert(units, unrelated)

-- One snapshot eliminates both teams. The next round swaps sides and owners.
assert(BalanceBench.install(config()))
assert(BalanceBench.start())
local first = active_units()
assert(#first == 3 and first[2].owner == 0 and first[3].owner == 1)
assert(first[2].x < first[3].x)
first[2].orderActive = false
step(1)
assert(first[2].target == first[3])
first[2].dead, first[3].dead = true, true
step(1)
assert(#BalanceBench.report() == 1 and BalanceBench.report()[1].outcome == "BOTH")
step(1)
local second = active_units()
assert(#second == 3 and second[2].owner == 1 and second[3].owner == 0)
assert(second[2].x > second[3].x)
second[3].dead = true
step(1)
local results = BalanceBench.report()
assert(#results == 2 and results[2].outcome == "A")
assert(results[1].aOnLeft and not results[2].aOnLeft)
assert(#active_units() == 1 and not unrelated.removed)
assert(active_timers() == 0)

-- Stop excludes an unfinished round; restart begins from a clean result set.
assert(BalanceBench.start())
assert(not BalanceBench.start())
assert(BalanceBench.stop())
assert(#BalanceBench.report() == 0 and active_timers() == 0)
assert(#active_units() == 1 and not unrelated.removed)
assert(BalanceBench.start())
step(10)
assert(#BalanceBench.report() == 1 and BalanceBench.report()[1].outcome == "TIMEOUT")
assert(BalanceBench.stop())
assert(#BalanceBench.report() == 1 and active_timers() == 0)
assert(#active_units() == 1 and not unrelated.removed)

-- Failed creation removes the earlier unit and reports an error.
failCreateAt = createAttempts + 2
local started, errorText = BalanceBench.start()
assert(not started and tostring(errorText):find("CreateUnit"))
assert(#BalanceBench.report() == 0)
assert(#active_units() == 1 and not unrelated.removed)
assert(active_timers() == 0)
failCreateAt = nil

assert(BalanceBench.uninstall())
assert(removeCalls == createAttempts - 1)
print("BalanceBench fake-native lifecycle tests passed")

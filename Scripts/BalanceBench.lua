-- WC3 Balance Bench: Lua map script for a dedicated test arena.
-- Paste into the Lua map's header custom script, before ExampleConfig.lua.
BalanceBench = BalanceBench or {}

do
    local BB = BalanceBench
    local config = nil
    local chatTrigger = nil
    local clock = nil
    local state = "IDLE"
    local batch = nil
    local owned = { A = {}, B = {} }
    local generation = 0
    local runNumber = 0
    local elapsed = 0
    local intermission = 0

    local function say(message, seconds)
        DisplayTimedTextToPlayer(Player(0), 0, 0, seconds or 12, "|cff80d7ff[Balance Bench]|r " .. tostring(message))
    end

    local function finite(value)
        return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
    end

    local function integer(value, low, high)
        return finite(value) and math.fmod(value, 1) == 0 and value >= low and value <= high
    end

    local function copy_and_validate(input)
        if type(input) ~= "table" then error("configuration must be a table") end
        if type(input.scenario) ~= "string" or input.scenario == "" or #input.scenario > 64 then
            error("scenario must be 1-64 characters")
        end
        if type(input.label) ~= "string" or input.label == "" or #input.label > 64 then
            error("label must be 1-64 characters")
        end
        if not integer(input.rounds, 2, 100) or math.fmod(input.rounds, 2) ~= 0 then
            error("rounds must be an even integer from 2 to 100")
        end
        if not finite(input.timeoutSeconds) or input.timeoutSeconds < 1 or input.timeoutSeconds > 600 then
            error("timeoutSeconds must be 1-600")
        end
        if not finite(input.pollSeconds) or input.pollSeconds < 0.05 or input.pollSeconds > 1 then
            error("pollSeconds must be 0.05-1")
        end
        if not finite(input.intermissionSeconds) or input.intermissionSeconds < 0 or input.intermissionSeconds > 30 then
            error("intermissionSeconds must be 0-30")
        end
        if type(input.teamA) ~= "table" or type(input.teamB) ~= "table" then
            error("teamA and teamB are required")
        end
        local function team(source, name)
            if type(source.rawcode) ~= "string" or #source.rawcode ~= 4 then
                error(name .. ".rawcode must be four characters")
            end
            if not integer(source.count, 1, 24) then
                error(name .. ".count must be 1-24")
            end
            return { rawcode = source.rawcode, count = source.count }
        end
        local a = team(input.teamA, "teamA")
        local b = team(input.teamB, "teamB")
        local arena = input.arena
        if type(arena) ~= "table" then error("arena is required") end
        local keys = { "centerX", "centerY", "halfWidth", "halfHeight", "separation", "spacing" }
        local bounds = {}
        for _, key in ipairs(keys) do
            if not finite(arena[key]) then error("arena." .. key .. " must be finite") end
            bounds[key] = arena[key]
        end
        if bounds.halfWidth < 256 or bounds.halfHeight < 256 or bounds.separation < 256
            or bounds.spacing < 32 or bounds.spacing > 256 then
            error("arena dimensions/separation/spacing are too small or invalid")
        end
        local widest = math.max(a.count, b.count)
        local yExtent = ((widest - 1) / 2) * bounds.spacing + 96
        local xExtent = bounds.separation / 2 + 96
        if xExtent > bounds.halfWidth or yExtent > bounds.halfHeight then
            error("formations do not fit inside arena bounds")
        end
        local map = GetPlayableMapRect()
        if bounds.centerX - bounds.halfWidth < GetRectMinX(map)
            or bounds.centerX + bounds.halfWidth > GetRectMaxX(map)
            or bounds.centerY - bounds.halfHeight < GetRectMinY(map)
            or bounds.centerY + bounds.halfHeight > GetRectMaxY(map) then
            error("arena is outside the playable map")
        end
        if Player(0) == nil or Player(1) == nil then
            error("test player slots 0 and 1 are unavailable")
        end
        return {
            scenario = input.scenario, label = input.label,
            rounds = input.rounds, timeoutSeconds = input.timeoutSeconds,
            pollSeconds = input.pollSeconds, intermissionSeconds = input.intermissionSeconds,
            teamA = a, teamB = b, arena = bounds
        }
    end

    local function clear_units()
        for _, team in ipairs({ "A", "B" }) do
            for _, unit in ipairs(owned[team]) do
                if unit ~= nil then RemoveUnit(unit) end
            end
            owned[team] = {}
        end
    end

    local function stop_clock()
        if clock ~= nil then
            PauseTimer(clock)
            DestroyTimer(clock)
            clock = nil
        end
    end

    local function aggregate()
        local counts = { A = 0, B = 0, BOTH = 0, TIMEOUT = 0 }
        local total = 0
        if batch ~= nil then
            for _, result in ipairs(batch.results) do
                counts[result.outcome] = counts[result.outcome] + 1
                total = total + result.seconds
            end
        end
        return counts, total
    end

    local function print_report()
        if batch == nil then
            say("No batch yet. Use -bb start.")
            return
        end
        local counts, total = aggregate()
        local completed = #batch.results
        local average = completed > 0 and total / completed or 0
        say(string.format("\37s / \37s | run \37d | \37s | \37d/\37d rounds",
            batch.config.scenario, batch.config.label, batch.id,
            state, completed, batch.config.rounds), 20)
        say(string.format("A \37s x\37d: \37d wins | B \37s x\37d: \37d wins | both: \37d | timeout: \37d | avg: \37.1fs",
            batch.config.teamA.rawcode, batch.config.teamA.count, counts.A,
            batch.config.teamB.rawcode, batch.config.teamB.count, counts.B,
            counts.BOTH, counts.TIMEOUT, average), 20)
        if batch.reason ~= nil then say("Reason: " .. batch.reason, 20) end
        local first = math.max(1, completed - 2)
        for i = first, completed do
            local result = batch.results[i]
            say(string.format("Round \37d: \37s, \37.1fs, survivors A:\37d B:\37d\37s",
                i, result.outcome, result.seconds, result.survivorsA,
                result.survivorsB, result.aOnLeft and " (A left)" or " (A right)"), 20)
        end
    end

    local function terminate(terminal, reason)
        generation = generation + 1
        stop_clock()
        clear_units()
        state = terminal
        if batch ~= nil then batch.reason = reason end
        print_report()
    end

    local function snapshot(team)
        local count, hp = 0, 0
        for _, unit in ipairs(owned[team]) do
            if unit ~= nil and GetUnitTypeId(unit) ~= 0 and GetWidgetLife(unit) > 0.405
                and not IsUnitType(unit, UNIT_TYPE_DEAD) then
                count = count + 1
                hp = hp + GetWidgetLife(unit)
            end
        end
        return count, hp
    end

    local function alive(unit)
        return unit ~= nil and GetUnitTypeId(unit) ~= 0
            and GetWidgetLife(unit) > 0.405
            and not IsUnitType(unit, UNIT_TYPE_DEAD)
    end

    local function wake_idle_team(attackers, defenders)
        local target = nil
        for _, unit in ipairs(defenders) do
            if alive(unit) then target = unit; break end
        end
        if target == nil then return end
        for _, unit in ipairs(attackers) do
            if alive(unit) and GetUnitCurrentOrder(unit) == 0 then
                if not IssueTargetOrder(unit, "attack", target) then
                    error("attack order failed for idle unit")
                end
            end
        end
    end

    local function spawn(teamName, x, owner, facing)
        local team = teamName == "A" and batch.config.teamA or batch.config.teamB
        local arena = batch.config.arena
        for i = 1, team.count do
            local y = arena.centerY + (i - (team.count + 1) / 2) * arena.spacing
            local unit = CreateUnit(owner, FourCC(team.rawcode), x, y, facing)
            if unit == nil then error("CreateUnit failed for " .. teamName .. " " .. team.rawcode) end
            table.insert(owned[teamName], unit)
            if GetUnitTypeId(unit) == 0 then
                error("invalid unit rawcode for " .. teamName .. ": " .. team.rawcode)
            end
            PauseUnit(unit, true)
            SetUnitState(unit, UNIT_STATE_LIFE, GetUnitState(unit, UNIT_STATE_MAX_LIFE))
            SetUnitState(unit, UNIT_STATE_MANA, GetUnitState(unit, UNIT_STATE_MAX_MANA))
        end
    end

    local function prepare_round()
        clear_units()
        local round = #batch.results + 1
        local arena = batch.config.arena
        local aLeft = math.fmod(round, 2) == 1
        local leftX = arena.centerX - arena.separation / 2
        local rightX = arena.centerX + arena.separation / 2
        local aX = aLeft and leftX or rightX
        local bX = aLeft and rightX or leftX
        local aPlayer = aLeft and Player(0) or Player(1)
        local bPlayer = aLeft and Player(1) or Player(0)
        batch.aOnLeft = aLeft
        spawn("A", aX, aPlayer, aLeft and 0 or 180)
        spawn("B", bX, bPlayer, aLeft and 180 or 0)
        -- Both formations exist before either one can acquire a target.
        for _, team in ipairs({ "A", "B" }) do
            for _, unit in ipairs(owned[team]) do PauseUnit(unit, false) end
        end
        for _, unit in ipairs(owned.A) do
            if not IssuePointOrder(unit, "attack", bX, arena.centerY) then
                error("attack-move order failed for team A")
            end
        end
        for _, unit in ipairs(owned.B) do
            if not IssuePointOrder(unit, "attack", aX, arena.centerY) then
                error("attack-move order failed for team B")
            end
        end
        elapsed = 0
        state = "FIGHT"
    end

    local function tick()
        if state == "INTERMISSION" then
            intermission = intermission - batch.config.pollSeconds
            if intermission <= 0 then prepare_round() end
            return
        end
        if state ~= "FIGHT" then return end
        elapsed = elapsed + batch.config.pollSeconds
        local aCount, aHp = snapshot("A")
        local bCount, bHp = snapshot("B")
        local outcome = nil
        if aCount == 0 and bCount == 0 then outcome = "BOTH"
        elseif bCount == 0 then outcome = "A"
        elseif aCount == 0 then outcome = "B"
        elseif elapsed + 0.0001 >= batch.config.timeoutSeconds then outcome = "TIMEOUT" end
        if outcome == nil then
            wake_idle_team(owned.A, owned.B)
            wake_idle_team(owned.B, owned.A)
            return
        end
        local round = #batch.results + 1
        table.insert(batch.results, {
            outcome = outcome, seconds = elapsed,
            survivorsA = aCount, survivorsB = bCount,
            hpA = aHp, hpB = bHp, aOnLeft = batch.aOnLeft
        })
        say(string.format("Round \37d/\37d: \37s, \37.1fs (A:\37d B:\37d)",
            round, batch.config.rounds, outcome, elapsed, aCount, bCount), 8)
        clear_units()
        if round >= batch.config.rounds then
            terminate("COMPLETE", nil)
        else
            intermission = batch.config.intermissionSeconds
            state = "INTERMISSION"
        end
    end

    function BB.install(input)
        if chatTrigger ~= nil then return false, "already installed" end
        local ok, value = pcall(copy_and_validate, input)
        if not ok then return false, value end
        config = value
        local trigger = CreateTrigger()
        if trigger == nil then config = nil; return false, "CreateTrigger failed" end
        local setup, setupError = pcall(function()
            for _, command in ipairs({ "-bb start", "-bb stop", "-bb report" }) do
                TriggerRegisterPlayerChatEvent(trigger, Player(0), command, true)
            end
            TriggerAddAction(trigger, function()
                local command = GetEventPlayerChatString()
                if command == "-bb start" then BB.start()
                elseif command == "-bb stop" then BB.stop()
                elseif command == "-bb report" then BB.report() end
            end)
        end)
        if not setup then
            DestroyTrigger(trigger)
            config = nil
            return false, setupError
        end
        chatTrigger = trigger
        say("Installed: " .. config.scenario .. " / " .. config.label .. ". Type -bb start, -bb stop, or -bb report.", 20)
        return true
    end

    function BB.start()
        if config == nil then return false, "not installed" end
        if state == "FIGHT" or state == "INTERMISSION" then
            say("A batch is running. Use -bb stop first.")
            return false, "already running"
        end
        if GetPlayerSlotState(Player(0)) ~= PLAYER_SLOT_STATE_PLAYING
            or GetPlayerSlotState(Player(1)) ~= PLAYER_SLOT_STATE_PLAYING then
            say("Both Red and Blue must be active player slots in the demo.")
            return false, "test player slots are not active"
        end
        generation = generation + 1
        local myGeneration = generation
        runNumber = runNumber + 1
        batch = { id = runNumber, config = config, results = {}, reason = nil }
        state = "PREPARE"
        local ok, err = pcall(function()
            clock = CreateTimer()
            if clock == nil then error("CreateTimer failed") end
            prepare_round()
            TimerStart(clock, config.pollSeconds, true, function()
                if myGeneration ~= generation then return end
                local good, tickError = pcall(tick)
                if not good then terminate("ERROR", tostring(tickError)) end
            end)
        end)
        if not ok then
            terminate("ERROR", tostring(err))
            return false, err
        end
        say(string.format("Run \37d started: \37s / \37s, A \37s x\37d vs B \37s x\37d, \37d rounds, \37.1fs timeout",
            batch.id, config.scenario, config.label,
            config.teamA.rawcode, config.teamA.count,
            config.teamB.rawcode, config.teamB.count,
            config.rounds, config.timeoutSeconds), 20)
        return true
    end

    function BB.stop()
        if state ~= "FIGHT" and state ~= "INTERMISSION" and state ~= "PREPARE" then
            say("No batch is running.")
            return false, "not running"
        end
        terminate("ABORTED", "stopped by user; current round not counted")
        return true
    end

    function BB.report()
        print_report()
        return batch ~= nil and batch.results or nil
    end

    function BB.uninstall()
        if state == "FIGHT" or state == "INTERMISSION" or state == "PREPARE" then
            terminate("ABORTED", "uninstalled; current round not counted")
        else
            stop_clock()
            clear_units()
        end
        if chatTrigger ~= nil then DestroyTrigger(chatTrigger); chatTrigger = nil end
        config = nil
        say("Uninstalled.")
        return true
    end
end

-- Paste below BalanceBench.lua in the Lua map's header custom script.
-- Change the scenario, label and unit rawcodes before a new comparison run.
BalanceBenchConfig = {
    scenario = "footmen-vs-grunts",
    label = "baseline",
    rounds = 20,
    timeoutSeconds = 60,
    pollSeconds = 0.10,
    intermissionSeconds = 1,
    teamA = { rawcode = "hfoo", count = 3 },
    teamB = { rawcode = "ogru", count = 2 },
    arena = {
        centerX = 0, centerY = 0,
        halfWidth = 1024, halfHeight = 768,
        separation = 768, spacing = 96,
    },
}

-- In a separate Map Initialization GUI trigger, add one Custom Script action:
-- BalanceBenchDemoSetup()
function BalanceBenchDemoSetup()
    -- Hostility belongs to this dedicated demo. The runner never edits alliances.
    SetPlayerAlliance(Player(0), Player(1), ALLIANCE_PASSIVE, false)
    SetPlayerAlliance(Player(1), Player(0), ALLIANCE_PASSIVE, false)
    local installed, reason = BalanceBench.install(BalanceBenchConfig)
    if not installed then
        DisplayTimedTextToPlayer(Player(0), 0, 0, 30, "[Balance Bench] Setup failed: " .. tostring(reason))
    end
end

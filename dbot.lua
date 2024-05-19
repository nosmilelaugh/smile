-- danger bot
LatestGameState = LatestGameState or nil
InAction = InAction or false
Logs = Logs or {}

colors = {
    red = "\27[31m",
    green = "\27[32m",
    blue = "\27[34m",
    reset = "\27[0m",
    gray = "\27[90m"
}

function addLog(msg, text)
    Logs[msg] = Logs[msg] or {}
    table.insert(Logs[msg], text)
end

function distance(x1, y1, x2, y2)
    return math.sqrt((x2 - x1)^2 + (y2 - y1)^2)
end

function moveQuicklyToEnemy(target)
    local me = LatestGameState.Players[ao.id]
    local newX = target.x + (math.random() - 0.5) * 2 * 10 -- Random offset to confuse the enemy
    local newY = target.y + (math.random() - 0.5) * 2 * 10
    ao.send({ Target = Game, Action = "Move", Player = ao.id, X = newX, Y = newY })
end

function findOptimalEnemy()
    local optimalPlayer = nil
    local bestRatio = -math.huge

    for target, state in pairs(LatestGameState.Players) do
        if target ~= ao.id then
            local ratio = state.health / state.energy
            if ratio > bestRatio then
                optimalPlayer = state
                bestRatio = ratio
            end
        end
    end

    return optimalPlayer
end

function attackOptimalPlayer()
    local optimalEnemy = findOptimalEnemy()
    local me = LatestGameState.Players[ao.id]

    if optimalEnemy then
        moveQuicklyToEnemy(optimalEnemy)
        if me.energy > 0 then
            local attackEnergy = me.energy -- Use all available energy for attack
            print(colors.red .. "Attacking optimal enemy with energy: " .. attackEnergy .. colors.reset)
            ao.send({ Target = Game, Action = "PlayerAttack", Player = ao.id, AttackEnergy = tostring(attackEnergy) })
        end
        InAction = false
    else
        print(colors.gray .. "No enemies found." .. colors.reset)
        InAction = false
    end
end

function decideNextAction()
    if not InAction then
        InAction = true
        attackOptimalPlayer()
    end
end

Handlers.add("PrintAnnouncements", Handlers.utils.hasMatchingTag("Action", "Announcement"), function(msg)
    if (msg.Event == "Tick" or msg.Event == "Started-Game") and not InAction then
        InAction = true
        ao.send({ Target = Game, Action = "GetGameState" })
    elseif InAction then
        print("Previous action still in progress. Skipping.")
    end

    print(colors.green .. msg.Event .. ": " .. msg.Data .. colors.reset)
end)

Handlers.add("GetGameStateOnTick", Handlers.utils.hasMatchingTag("Action", "Tick"), function()
    if not InAction then
        InAction = true
        print(colors.gray .. "Getting game state..." .. colors.reset)
        ao.send({ Target = Game, Action = "GetGameState" })
    else
        print("Previous action still in progress. Skipping.")
    end
end)

Handlers.add("UpdateGameState", Handlers.utils.hasMatchingTag("Action", "GameState"), function(msg)
    local json = require("json")
    LatestGameState = json.decode(msg.Data)
    ao.send({ Target = ao.id, Action = "UpdatedGameState" })
    print("Game state updated.")
    decideNextAction()
end)

Handlers.add("decideNextAction", Handlers.utils.hasMatchingTag("Action", "UpdatedGameState"), function()
    if LatestGameState.GameMode ~= "Playing" then
        print("Game not started")
        InAction = false
        return
    end
    decideNextAction()
    ao.send({ Target = ao.id, Action = "Tick" })
end)

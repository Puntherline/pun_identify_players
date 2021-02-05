-- Player connects
AddEventHandler("playerConnecting", function(name, setKickReason, deferrals)

    -- First time joining adaptive card
    local newPlayerCard = {
        ["type"] = "AdaptiveCard",
        ["$schema"] = "http://adaptivecards.io/schemas/adaptive-card.json",
        ["version"] = "1.3",
        ["body"] = {
            {
                ["type"] = "TextBlock",
                ["text"] = "We're saving your identifiers to improve the reliability of our services. We do our best to keep your identifiers private, but we can't promise you that they might leak.",
                ["wrap"] = true
            },
            {
                ["type"] = "Input.Toggle",
                ["value"] = "false",
                ["isRequired"] = true,
                ["id"] = "accept_terms",
                ["label"] = "Are you okay with that?",
                ["errorMessage"] = "You can't join without accepting the terms!"
            },
            {
                ["type"] = "ActionSet",
                ["actions"] = {
                    {
                        ["type"] = "Action.Submit",
                        ["title"] = "Confirm",
                        ["style"] = "positive",
                        ["associatedInputs"] = "none"
                    }
                }
            }
        }
    }

    -- Unbanned adaptive card
    local unbannedPlayerCard = {
        ["type"] = "AdaptiveCard",
        ["$schema"] = "http://adaptivecards.io/schemas/adaptive-card.json",
        ["version"] = "1.3",
        ["body"] = {
            {
                ["type"] = "TextBlock",
                ["text"] = "Your ban has expired. Please regard the rules this time.",
                ["wrap"] = true
            },
            {
                ["type"] = "ActionSet",
                ["actions"] = {
                    {
                        ["type"] = "Action.Submit",
                        ["title"] = "Confirm",
                        ["style"] = "positive",
                        ["associatedInputs"] = "none"
                    }
                }
            }
        }
    }

    -- How many points each match in the database counts as
    -- Note: Using higher values with more variety might prevent draws
    local matchPts = {
        steam = 18, -- Bound to Steam account | Everybody knows about this
        license = 48, -- Bound to R* account | Everybody knows about this
        xbl = 21, -- Changes with MS account | Some know about this
        live = 18, -- Changes with MS account | Some know about this
        discord = 23, -- Bound to Discord account | Some know about this
        fivem = 19, -- Bound to FiveM (cfx.re) account | Few know about and use this
        tokens = 2 -- Possibly changes when using a different R* account | Very few know about this
    }

    -- Creating player table and inserting source and kvp if present
    local player = {
        source = source,
        kvp = GetResourceKvpInt("ban_status"),
        name = string.sub(name, 1, 50),
        tokens = {},
        identifiers = {}
    }

    -- Adding identifiers to player table
    player.identifiers = GetPlayerIdentifiers(player.source)

    for _, v in pairs(player.identifiers) do
        player[string.sub(v, 1, string.find(v, ":") - 1)] = v
    end

    -- Defer player
    deferrals.defer()
    Citizen.Wait(100)

    -- Adding all player tokens to player table as json string
    local num_tokens = GetNumPlayerTokens(player.source)

    for i = 1, num_tokens do
        player.tokens[i] = GetPlayerToken(player.source, i)
        if i == num_tokens then
            player.tokens = json.encode(player.tokens)
        end
    end

    -- Find all matches in database
    MySQL.Async.fetchAll(
        "SELECT * FROM player_logs WHERE steam = @steam OR license = @license OR xbl = @xbl OR live = @live OR discord = @discord OR fivem = @fivem OR tokens = @tokens",
        {
            ["@steam"] = player.steam,
            ["@license"] = player.license,
            ["@xbl"] = player.xbl,
            ["@live"] = player.live,
            ["@discord"] = player.discord,
            ["@fivem"] = player.fivem,
            ["@tokens"] = player.tokens
        },
        function(result)

            -- Nothing returned (database unavailable)
            if result == nil then
                deferrals.done("\nI'm sorry, our database seems to be unavailable right now. Please check back later!")
                return
            end

            -- No matches
            if #result == 0 then

                -- Resource KVP is empty
                if player.kvp == 0 then
                    AddPlayerToDatabase(player)
                    deferrals.presentCard(newPlayerCard, function(data)
                        deferrals.done()
                    end)

                -- KVP ban expired
                elseif player.kvp < os.time() then
                    DeleteResourceKvp("ban_status")
                    AddPlayerToDatabase(player)
                    deferrals.presentCard(unbannedPlayerCard, function(data)
                        deferrals.done()
                    end)

                -- KVP ban is not expired
                elseif player.kvp > os.time() then
                    AddPlayerToDatabase(player, player.kvp)
                    local banned_until = os.date("%A, %B ", player.kvp)..GetOrdinalIndicator(os.date("%d", player.kvp))..os.date(" %Y - %I:%M %p", player.kvp)
                    deferrals.done("\nYou are still banned from joining this server. Your ban will expire on "..banned_until.." +1 GMT")

                -- Something weird going on
                else
                    deferrals.done("\nI'm sorry, something went wrong.\nError ID: 35829")
                end

            -- One match
            elseif #result == 1 then

                -- No ban record in database
                if result[1].ban_time == 0 then

                    -- No resource KVP
                    if player.kvp == 0 then
                        UpdatePlayerInDatabase(player, result[1])
                        deferrals.done()

                    -- KVP ban expired
                    elseif player.kvp < os.time() then
                        UpdatePlayerInDatabase(player, result[1])
                        DeleteResourceKvp("ban_status")
                        deferrals.presentCard(unbannedPlayerCard, function(data)
                            deferrals.done()
                        end)

                    -- KVP ban is not expired
                    elseif player.kvp > os.time() then
                        UpdatePlayerInDatabase(player, result[1], player.kvp)
                        local banned_until = os.date("%A, %B ", player.kvp)..GetOrdinalIndicator(os.date("%d", player.kvp))..os.date(" %Y - %I:%M %p", player.kvp)
                        deferrals.done("\nYou are still banned from joining this server. Your ban will expire on "..banned_until.." +1 GMT")
                    end

                -- Database ban expired
                elseif result[1].ban_time / 1000 < os.time() then
                    DeletePlayerBan(result[1].id)
                    deferrals.presentCard(unbannedPlayerCard, function(data)
                        deferrals.done()
                    end)

                -- Database ban is not expired
                elseif result[1].ban_time / 1000 > os.time() then
                    UpdatePlayerInDatabase(player, result[1], result[1].ban_time / 1000)
                    SetResourceKvpInt("ban_status", result[1].ban_time / 1000)
                    local banned_until = os.date("%A, %B ", result[1].ban_time / 1000)..GetOrdinalIndicator(os.date("%d", result[1].ban_time / 1000))..os.date(" %Y - %I:%M %p", result[1].ban_time / 1000)
                    deferrals.done("\nYou are still banned from joining this server. Your ban will expire on "..banned_until.." +1 GMT")

                -- Something weird going on
                else
                    deferrals.done("\nI'm sorry, something went wrong.\nError ID: 88091")
                end

            -- More than one match
            elseif #result > 1 then

                -- Check ban status on all identifiers (I'm lazy, refuse connection on first find and don't update anything)
                -- Also, while we're at it, creating KVP for this person for trying to use an already banned account.
                for i = 1, #result do
                    if result[i].ban_time / 1000 > os.time() then
                        SetResourceKvpInt("ban_status", result[i].ban_time / 1000)
                        local banned_until = os.date("%A, %B ", result[i].ban_time / 1000)..GetOrdinalIndicator(os.date("%d", result[i].ban_time / 1000))..os.date(" %Y - %I:%M %p", result[i].ban_time / 1000)
                        deferrals.done("\nYou are still banned from joining this server. Your ban will expire on "..banned_until.." +1 GMT")
                        return
                    end
                end

                -- Compare each result to every known identifier
                local points = {}

                for i = 1, #result do
                    for k, v in pairs(matchPts) do
                        if result[i][k] == player[k] then
                            points[i] = (points[i] or 0) + v
                        end
                    end
                end

                -- Getting result with highest points
                local best_result = 0
                local most_points = 0

                for i = 1, #points do
                    if points[i] > most_points then
                        best_result = i
                    end
                end

                -- No resource KVP
                if player.kvp == 0 then
                    UpdatePlayerInDatabase(player, result[best_result])
                    deferrals.done()

                -- KVP ban expired
                elseif player.kvp < os.time() then
                    UpdatePlayerInDatabase(player, result[best_result])
                    DeleteResourceKvp("ban_status")
                    deferrals.presentCard(unbannedPlayerCard, function(data)
                        deferrals.done()
                    end)

                -- KVP ban is not expired
                elseif player.kvp > os.time() then
                    UpdatePlayerInDatabase(player, result[best_result], player.kvp)
                    local banned_until = os.date("%A, %B ", player.kvp)..GetOrdinalIndicator(os.date("%d", player.kvp))..os.date(" %Y - %I:%M %p", player.kvp)
                    deferrals.done("\nYou are still banned from joining this server. Your ban will expire on "..banned_until.." +1 GMT")
                end
            end
        end
    )
end)



-- Update player info in database
function UpdatePlayerInDatabase(player, old_info, ban_time)

    -- Keep old info if it exists
    local new = {
        name = player.name,
        steam = player.steam or old_info.steam,
        license = player.license or old_info.license,
        xbl = player.xbl or old_info.xbl,
        live = player.live or old_info.live,
        discord = player.discord or old_info.discord,
        fivem = player.fivem or old_info.fivem,
        tokens = player.tokens or old_info.tokens,
        ban_time = ban_time or old_info.ban_time
    }

    -- Update everything in the database
    MySQL.Async.execute(
        "UPDATE player_logs SET name = @name, steam = @steam, license = @license, xbl = @xbl, live = @live, discord = @discord, fivem = @fivem, tokens = @tokens",
        {
            ["@name"] = new.name,
            ["@steam"] = new.steam,
            ["@license"] = new.license,
            ["@xbl"] = new.xbl,
            ["@live"] = new.live,
            ["@discord"] = new.discord,
            ["@fivem"] = new.fivem,
            ["@tokens"] = new.tokens
        },
        function(affectedRows)
            -- For debugging or advanced use
            --print(affectedRows)
        end
    )
end



-- Setting player ban status to null and deleting resource KVP
function DeletePlayerBan(id)
    DeleteResourceKvp("ban_status")

    MySQL.Async.execute(
        "UPDATE player_logs SET ban_time = NULL, ban_reason = NULL WHERE id = @id",
        {
            ["@id"] = id
        },
        function(affectedRows)
            -- For debugging or advanced use
            --print(affectedRows)
        end
    )
end



-- Add player to the database
function AddPlayerToDatabase(player, ban_time)

    -- If ban_time was specified, convert it to YYYY-MM-DD HH-MM-SS
    if ban_time then
        ban_time = os.date("%Y-%m-%d %H:%M:%S", ban_time)
    end

    -- Insert into database
    MySQL.Async.insert(
        "INSERT INTO player_logs (name, steam, license, xbl, live, discord, fivem, tokens, ban_time) VALUES (@name, @steam, @license, @xbl, @live, @discord, @fivem, @tokens, @ban_time)",
        {
            ["@name"] = player.name,
            ["@steam"] = player.steam,
            ["@license"] = player.license,
            ["@xbl"] = player.xbl,
            ["@live"] = player.live,
            ["@discord"] = player.discord,
            ["@fivem"] = player.fivem,
            ["@tokens"] = player.tokens,
            ["@ban_time"] = ban_time
        },
        function(insertId)
            -- For debugging or advanced use
            --print(insertId)
        end
    )
end



function GetOrdinalIndicator(input)

    -- Weeding out bad results
    if tonumber(input) == nil then
        local error = string.format("[pun.ordinal error: number or string containing numbers expected, got %s]", input)
        return error
    end

    -- Locals
    local number = math.floor(tonumber(input))
    local ordinal = "th"
    local ordinals = {[1] = "st", [2] = "nd", [3] = "rd", [11] = "th", [12] = "th", [13] = "th"}

    -- Single digit
    if string.len(number) == 1 then
        ordinal = ordinals[number] or ordinal

    -- More than single digit
    else
        local last_two_digits = tonumber(string.sub(number, string.len(number) - 1))
        local last_digit = tonumber(string.sub(number, string.len(number)))

        -- Last two digits exist as key in ordinals table
        if ordinals[last_two_digits] then
            ordinal = ordinals[last_two_digits]

        -- If above is false, see if single digit matches, else use "th"
        else
            ordinal = ordinals[last_digit] or ordinal
        end
    end

    -- Return result
    local result = number..ordinal
    return result
end

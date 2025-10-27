-- control.lua
-- AutoPlacer module main file, implements the function of automatically placing entity ghosts

-- Define the name of the shortcut key
local SHORTCUT = 'autoplacer-toggle'

-- Check if the player has researched the relevant technology to enable this function
-- Only players who have researched the "autoplacer" technology can use this function
local function is_available(player)
    return player.force.technologies["autoplacer"].researched
end

-- Set the toggle state of the shortcut key (on/off)
local function set_toggled(player, state)
    player.set_shortcut_toggled(SHORTCUT, state)
end

-- Check if the shortcut is currently in the on state
local function is_toggled(player)
    return player.is_shortcut_toggled(SHORTCUT)
end

-- Check if the distance between the player and the target position is within the build range
local function is_within_build_range(player, target_position)
    local player_position = player.position
    local build_distance = player.build_distance
    
    -- Check for the new range technologies and calculate build distance
    if player.force.technologies["autoplacer-range-1"].researched then
        build_distance = build_distance * 2  -- Double the range
    end
    
    if player.force.technologies["autoplacer-range-2"].researched then
        build_distance = build_distance * 2  -- Double the range again (4x total)
    end

    if player.force.technologies["autoplacer-range-3"].researched then
        local range_upgrade_level = player.force.technologies["autoplacer-range-3"].level - 2
        if range_upgrade_level >= 1 then
            build_distance = build_distance * (2 ^ range_upgrade_level)
        end
    end
    
    local distance = math.sqrt((target_position.x - player_position.x)^2 + (target_position.y - player_position.y)^2)
    return distance <= build_distance
end

-- Core function to toggle shortcut state for the player
local function toggle_shortcut(player)
    if not player then return end

    -- If the technology is not researched, forcibly disable the shortcut and return
    if not is_available(player) then
        set_toggled(player, false)
        return
    end

    -- Toggle state and show prompt message to the player
    if is_toggled(player) then
        player.print({"autoplacer.messages.disabled"})
        set_toggled(player, false)
    else
        player.print({"autoplacer.messages.enabled"})
        set_toggled(player, true)
    end
end

-- Handle Lua shortcut events (triggered when the player presses the defined shortcut key)
script.on_event(defines.events.on_lua_shortcut, function(event)
    if event.prototype_name == SHORTCUT then
        toggle_shortcut(game.get_player(event.player_index))
    end
end)

-- Handle custom key input events (another trigger method)
script.on_event(SHORTCUT, function(event)
    toggle_shortcut(game.get_player(event.player_index))
end)

-- Handle console commands
commands.add_command("autoplacer-research", {"autoplacer.command.description"}, function(command)
    local player = game.get_player(command.player_index)
    if not player then
        -- If command is run from server console, apply to all forces
        for _, force in pairs(game.forces) do
            if force.technologies["autoplacer"] and not force.technologies["autoplacer"].researched then
                force.technologies["autoplacer"].researched = true
                game.print({"autoplacer.command.researched-server", force.name})
            end
        end
        return
    end
    
    -- Check if player has admin privileges (optional, you can remove this check if you want all players to use it)
    if not player.admin then
        player.print({"autoplacer.command.no-permission"})
        return
    end
    
    -- Check if technology is already researched
    if player.force.technologies["autoplacer"].researched then
        player.print({"autoplacer.command.already-researched"})
        return
    end
    
    -- Research the technology
    player.force.technologies["autoplacer"].researched = true
    player.print({"autoplacer.command.researched"})
end)

-- Handle console commands for range technologies
commands.add_command("autoplacer-range", {"autoplacer.command.range-description"}, function(command)
    local player = game.get_player(command.player_index)
    if not player then
        -- If command is run from server console, apply to all forces
        for _, force in pairs(game.forces) do
            for i = 1, 3 do
                local tech_name = "autoplacer-range-" .. i
                if force.technologies[tech_name] and not force.technologies[tech_name].researched then
                    force.technologies[tech_name].researched = true
                    game.print({"autoplacer.command.range-researched-server", tech_name, force.name})
                end
            end
        end
        return
    end
    
    -- Check if player has admin privileges
    if not player.admin then
        player.print({"autoplacer.command.no-permission"})
        return
    end
    
    -- Research all range technologies
    for i = 1, 3 do
        local tech_name = "autoplacer-range-" .. i
        if not player.force.technologies[tech_name].researched then
            player.force.technologies[tech_name].researched = true
            player.print({"autoplacer.command.range-researched", tech_name})
        else
            player.print({"autoplacer.command.range-already-researched", tech_name})
        end
    end
end)

-- Listen for two key events to implement the auto-placement feature:
--   1. When the selected entity changes (including dragging the cursor over ghosts)
--   2. When the cursor item changes (such as switching hotbar items or using the pipette tool)
script.on_event({
    defines.events.on_selected_entity_changed,
    defines.events.on_player_cursor_stack_changed
}, function(event)
    local player = game.get_player(event.player_index)
    if not player then return end

    -- Ensure the auto-placement feature is enabled
    if not is_toggled(player) then return end

    -- Check if the player is hovering over an entity ghost
    -- Entity ghosts are placeholders in Factorio that represent entities to be placed
    local hovered_entity = player.selected
    if hovered_entity and hovered_entity.name == "entity-ghost" then
        -- Get the prototype information of the ghost entity
        local ghost_prototype = hovered_entity.ghost_prototype
        if not ghost_prototype then return end

        -- Get the list of items that can place this ghost
        local item_list = ghost_prototype.items_to_place_this
        local cursor_stack = player.cursor_stack

        -- Check if there is an item in the cursor
        local has_cursor_item = cursor_stack and cursor_stack.valid_for_read

        -- Check if the item in the cursor can be used to build the currently hovered ghost
        local matching_item = nil
        if has_cursor_item then
            for _, item in pairs(item_list) do
                if cursor_stack.name == item.name and cursor_stack.quality == hovered_entity.quality then
                    matching_item = item
                    break
                end
            end
        end

        -- Only check the build range if the item in the cursor can place the current ghost
        if matching_item then
            -- Check if the target position is within the player's build range
            if not is_within_build_range(player, hovered_entity.position) then
                -- Out of build range, show prompt message
                player.create_local_flying_text({
                    text = {"autoplacer.messages.out-of-range"},
                    position = hovered_entity.position,
                    color = {r = 1, g = 0.4, b = 0.4},
                    time_to_live = 600
                })
                return
            end
        end

        -- Check if an entity can be placed at that position, preventing construction on colliding entities or terrain
        -- Using the surface version of the function avoids issues with replacement entities (such as placing a belt on an underground belt)
        if not player.surface.can_place_entity({
            name = hovered_entity.ghost_name,
            position = hovered_entity.position,
            direction = hovered_entity.direction,
            force = player.force,
            build_check_type = defines.build_check_type.ghost_revive,
        }) then return end

        -- If a matching item is found, perform the build operation
        if matching_item then
            -- Reduce the quantity of items in the cursor (consume one item)
            cursor_stack.count = cursor_stack.count - 1

            -- Try to "revive" the ghost entity into a real entity
            -- This is the key method for converting ghosts in blueprints to real entities
            local revived, _ = hovered_entity.revive({ raise_revive = true })
            if not revived then
                -- If revival fails, return the item to the player
                player.insert({name = matching_item.name, count = 1, quality = hovered_entity.quality})
                player.create_local_flying_text({
                    text = {"autoplacer.messages.build-failed"},
                    position = hovered_entity.position,
                    color = {r = 1, g = 0.4, b = 0.4},
                })
            end
            return
        end
    end
end)
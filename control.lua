-- control.lua
-- 优化后的自动放置器模块主文件
-- 包含自动放置实体幽灵和智能自动拆除功能
-- 安全版本：彻底解决全局变量访问问题

-- 配置常量
local CONFIG = {
    SHORTCUT = 'autoplacer-toggle',
    DECON_SHORTCUT = 'autodecon-toggle',
    CHECK_INTERVAL = 3600,    -- 检查间隔（tick）
    FEEDBACK_DURATION = 300,  -- 提示消息持续时间（tick）
    MAX_BUILD_DISTANCE = 256, -- 最大建造距离缓存
    VERSION = "2.2"
}

-- 全局状态管理器
local StateManager = {}

function StateManager:init()
    -- 安全地初始化全局变量
    if not global then global = {} end
    global.player_states = global.player_states or {}
    global.version = CONFIG.VERSION
    global.last_check = global.last_check or {}

    -- 为所有现有玩家初始化状态
    for _, player in pairs(game.players) do
        self:ensure_player_state(player)
    end
end

function StateManager:ensure_player_state(player)
    -- 安全地初始化全局变量
    if not global then global = {} end
    if not global.player_states then global.player_states = {} end

    local index = player.index
    if not global.player_states[index] then
        global.player_states[index] = {
            autoplacer_enabled = false,
            autodecon_enabled = false,
            last_decon_check = 0,
            last_autoplacer_check = 0
        }
    end

    -- 检查技术可用性
    local state = global.player_states[index]
    if state and not state.autoplacer_enabled and self:is_autoplacer_available(player) then
        state.autoplacer_enabled = true
    end

    if state and not state.autodecon_enabled and self:is_decon_available(player) then
        state.autodecon_enabled = true
    end
end

function StateManager:is_autoplacer_available(player)
    if not player or not player.force then return false end
    return player.force.technologies["autoplacer"].researched
end

function StateManager:is_decon_available(player)
    if not player or not player.force then return false end
    return player.force.technologies["autodecon"].researched
end

function StateManager:get_player_state(player)
    self:ensure_player_state(player)
    -- 安全检查
    if not global or not global.player_states then return nil end
    return global.player_states[player.index]
end

-- 技术检查器
local TechChecker = {}

function TechChecker:is_available(player, tech_name)
    if not player or not player.force then return false end
    return player.force.technologies[tech_name] and player.force.technologies[tech_name].researched
end

function TechChecker:research_for_all_forces(technology_name)
    for _, force in pairs(game.forces) do
        if force.technologies[technology_name] and not force.technologies[technology_name].researched then
            force.technologies[technology_name].researched = true
            game.print({ "autoplacer.command.researched-server", force.name })
        end
    end
end

-- 快捷键管理器
local ShortcutManager = {}

function ShortcutManager:set_toggled(player, shortcut_name, state)
    if player and player.set_shortcut_toggled then
        player.set_shortcut_toggled(shortcut_name, state)
    end
end

function ShortcutManager:toggle(player, shortcut_name, state_manager)
    if not player then return end

    local player_state = state_manager:get_player_state(player)
    if not player_state then return end

    local tech_available = state_manager:is_autoplacer_available(player)

    if not tech_available then
        self:set_toggled(player, shortcut_name, false)
        player.print({ "autoplacer.messages.unavailable" })
        return
    end

    player_state.autoplacer_enabled = not player_state.autoplacer_enabled
    self:set_toggled(player, shortcut_name, player_state.autoplacer_enabled)

    local message_key = player_state.autoplacer_enabled and "autoplacer.messages.enabled" or
    "autoplacer.messages.disabled"
    player.print({ message_key })
end

function ShortcutManager:toggle_decon(player, state_manager)
    if not player then return end

    local player_state = state_manager:get_player_state(player)
    if not player_state then return end

    local tech_available = state_manager:is_decon_available(player)

    if not tech_available then
        player.print({ "autodecon.messages.unavailable" })
        return
    end

    player_state.autodecon_enabled = not player_state.autodecon_enabled
    self:set_toggled(player, CONFIG.DECON_SHORTCUT, player_state.autodecon_enabled)

    local message_key = player_state.autodecon_enabled and "autodecon.messages.enabled" or "autodecon.messages.disabled"
    player.print({ message_key })
end

-- 建造范围检查器
local BuildRangeChecker = {}

function BuildRangeChecker:get_build_distance(player)
    return player.build_distance or CONFIG.MAX_BUILD_DISTANCE
end

function BuildRangeChecker:is_within_range(player, target_position)
    local player_pos = player.position
    local build_dist = self:get_build_distance(player)
    local distance = math.sqrt((target_position.x - player_pos.x) ^ 2 + (target_position.y - player_pos.y) ^ 2)
    return distance <= build_dist
end

-- 反馈消息管理器
local FeedbackManager = {}

function FeedbackManager:show_build_failed(player, position)
    self:show_flying_text(player, position, "autoplacer.messages.build-failed", { 1, 0.4, 0.4 })
end

function FeedbackManager:show_range_error(player, position)
    self:show_flying_text(player, position, "autoplacer.messages.out-of-range", { 1, 0.4, 0.4 })
end

function FeedbackManager:show_marked_for_decon(player, position)
    self:show_flying_text(player, position, "autodecon.messages.marked-for-decon", { 1, 0.8, 0.2 })
end

function FeedbackManager:show_flying_text(player, position, message_key, color)
    if player and player.create_local_flying_text then
        player.create_local_flying_text({
            text = { message_key },
            position = position,
            color = color,
            time_to_live = CONFIG.FEEDBACK_DURATION
        })
    end
end

-- 智能采矿机管理器
local SmartMinerManager = {}

function SmartMinerManager:is_miner_depleted(miner)
    if not miner or not miner.valid or miner.type ~= "mining-drill" then
        return false
    end

    local resource = nil

    if miner.mining_target and miner.mining_target.valid then
        resource = miner.mining_target
    end

    if not resource then
        local resources = miner.surface.find_entities_filtered {
            position = miner.position,
            type = "resource"
        }
        if #resources > 0 then
            resource = resources[1]
        end
    end

    if not resource then
        return true
    end

    return resource.amount <= 0
end

function SmartMinerManager:mark_depleted_miners(player, state_manager)
    local player_state = state_manager:get_player_state(player)
    if not player_state or not player_state.autodecon_enabled then
        return
    end

    local current_tick = game.tick
    if current_tick - (player_state.last_decon_check or 0) < CONFIG.CHECK_INTERVAL then
        return
    end

    player_state.last_decon_check = current_tick

    local surface = player.surface
    -- 不限制范围，检查整个地图上的采矿机
    local entities = surface.find_entities_filtered {
        type = "mining-drill",
        force = player.force
    }

    local marked_count = 0
    for _, miner in pairs(entities) do
        if self:is_miner_depleted(miner) and not miner.to_be_deconstructed(player.force) then
            miner.order_deconstruction(player.force)
            FeedbackManager:show_marked_for_decon(player, miner.position)
            marked_count = marked_count + 1
        end
    end
end

-- 自动放置管理器
local AutoPlacerManager = {}

function AutoPlacerManager:can_place_entity(player, ghost)
    return player.surface.can_place_entity({
        name = ghost.ghost_name,
        position = ghost.position,
        direction = ghost.direction,
        force = player.force,
        build_check_type = defines.build_check_type.ghost_revive
    })
end

function AutoPlacerManager:handle_cursor_change(event, state_manager)
    local player = game.get_player(event.player_index)
    if not player then return end

    local player_state = state_manager:get_player_state(player)
    if not player_state or not player_state.autoplacer_enabled then return end

    local hovered_entity = player.selected
    if not hovered_entity or hovered_entity.name ~= "entity-ghost" then return end

    local ghost_prototype = hovered_entity.ghost_prototype
    if not ghost_prototype then return end

    local cursor_stack = player.cursor_stack
    if not cursor_stack or not cursor_stack.valid_for_read then return end

    local matching_item = nil
    for _, item in pairs(ghost_prototype.items_to_place_this) do
        if cursor_stack.name == item.name and cursor_stack.quality == hovered_entity.quality then
            matching_item = item
            break
        end
    end

    if not matching_item then return end

    if not BuildRangeChecker:is_within_range(player, hovered_entity.position) then
        FeedbackManager:show_range_error(player, hovered_entity.position)
        return
    end

    if not self:can_place_entity(player, hovered_entity) then
        return
    end

    self:attempt_build(player, hovered_entity, matching_item, cursor_stack)
end

function AutoPlacerManager:attempt_build(player, ghost, matching_item, cursor_stack)
    cursor_stack.count = cursor_stack.count - 1

    local revived, result = ghost.revive({ raise_revive = true })
    if not revived then
        player.insert({ name = matching_item.name, count = 1, quality = ghost.quality })
        FeedbackManager:show_build_failed(player, ghost.position)
    end
end

-- 命令管理器
local CommandManager = {}

function CommandManager:add_research_command(name, tech_name, message_keys)
    commands.add_command(name, { message_keys.description }, function(command)
        local player = game.get_player(command.player_index)

        if player and not player.admin then
            player.print({ message_keys.no_permission })
            return
        end

        if not player then
            TechChecker:research_for_all_forces(tech_name)
            return
        end

        local force = player.force
        if force.technologies[tech_name].researched then
            player.print({ message_keys.already_researched })
            return
        end

        force.technologies[tech_name].researched = true
        player.print({ message_keys.researched })
    end)
end

-- 初始化
local function init()
    StateManager:init()
end

-- 事件处理
script.on_init(init)
script.on_configuration_changed(init)

-- 技术研究完成事件
script.on_event(defines.events.on_research_finished, function(event)
    local research = event.research
    local force = research.force

    if research.name == "autodecon" then
        for _, player in pairs(force.players) do
            local player_state = StateManager:get_player_state(player)
            if player_state then
                player_state.autodecon_enabled = true
                player.print({ "autodecon.messages.enabled" })
            end
        end
    end
end)

-- 玩家创建事件
script.on_event(defines.events.on_player_created, function(event)
    local player = game.get_player(event.player_index)
    if player then
        StateManager:ensure_player_state(player)
    end
end)

-- 快捷键事件
script.on_event(defines.events.on_lua_shortcut, function(event)
    local player = game.get_player(event.player_index)
    if not player then return end

    if event.prototype_name == CONFIG.SHORTCUT then
        ShortcutManager:toggle(player, CONFIG.SHORTCUT, StateManager)
    elseif event.prototype_name == CONFIG.DECON_SHORTCUT then
        ShortcutManager:toggle_decon(player, StateManager)
    end
end)

-- 光标和选择事件
script.on_event({
    defines.events.on_selected_entity_changed,
    defines.events.on_player_cursor_stack_changed
}, function(event)
    AutoPlacerManager:handle_cursor_change(event, StateManager)
end)

-- 定期检查事件
script.on_event(defines.events.on_tick, function(event)
    if event.tick % CONFIG.CHECK_INTERVAL ~= 0 then return end

    -- 使用 pcall 保护整个检查过程
    pcall(function()
        for _, player in pairs(game.players) do
            if player.connected then
                SmartMinerManager:mark_depleted_miners(player, StateManager)
            end
        end
    end)
end)

-- 添加命令
CommandManager:add_research_command("autoplacer-research", "autoplacer", {
    description = "autoplacer.command.description",
    no_permission = "autoplacer.command.no-permission",
    already_researched = "autoplacer.command.already-researched",
    researched = "autoplacer.command.researched"
})

CommandManager:add_research_command("autodecon-research", "autodecon", {
    description = "autodecon.command.description",
    no_permission = "autodecon.command.no-permission",
    already_researched = "autodecon.command.already-researched",
    researched = "autodecon.command.researched"
})

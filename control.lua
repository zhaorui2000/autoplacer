-- control.lua
-- AutoPlacer mod - 自动放置器模块主文件
-- 实现自动放置实体幽灵的功能，优化版本
-- 版本: 2.0.0

local AutoPlacer = {} -- 主模块表

-- 常量定义
AutoPlacer.CONSTANTS = {
    SHORTCUT = 'autoplacer-toggle',
    TECHNOLOGY_NAME = 'autoplacer',
    MAX_DISTANCE_CACHE_TIME = 30, -- 最大距离缓存时间（tick）
    MAX_DISTANCE_CACHE_SIZE = 100 -- 缓存大小限制
}

-- 距离计算缓存系统
local distance_cache = {}
local function get_cached_distance(player_index, target_position)
    local cache_key = string.format("%s_%s_%s", player_index, target_position.x, target_position.y)
    local cached = distance_cache[cache_key]

    if cached and cached.tick and (game.tick - cached.tick) < AutoPlacer.CONSTANTS.MAX_DISTANCE_CACHE_TIME then
        return cached.distance
    end

    return nil
end

local function set_cached_distance(player_index, target_position, distance)
    local cache_key = string.format("%s_%s_%s", player_index, target_position.x, target_position.y)

    -- 缓存管理：限制缓存大小
    if #distance_cache >= AutoPlacer.CONSTANTS.MAX_DISTANCE_CACHE_SIZE then
        table.remove(distance_cache, 1)
    end

    distance_cache[cache_key] = {
        distance = distance,
        tick = game.tick
    }
end

-- 优化的玩家状态检查
function AutoPlacer:is_available(player)
    if not player or not player.valid then return false end
    local tech = player.force.technologies[AutoPlacer.CONSTANTS.TECHNOLOGY_NAME]
    return tech and tech.researched == true
end

-- 优化的快捷键状态管理
function AutoPlacer:set_toggled(player, state)
    if not player or not player.valid then return end
    player.set_shortcut_toggled(AutoPlacer.CONSTANTS.SHORTCUT, state)
end

function AutoPlacer:is_toggled(player)
    if not player or not player.valid then return false end
    return player.is_shortcut_toggled(AutoPlacer.CONSTANTS.SHORTCUT)
end

-- 优化的距离检查（使用缓存）
function AutoPlacer:is_within_build_range(player, target_position)
    if not player or not player.valid then return false end

    local player_index = player.index
    local cached_distance = get_cached_distance(player_index, target_position)
    local distance

    if cached_distance then
        distance = cached_distance
    else
        local player_position = player.position
        local dx = target_position.x - player_position.x
        local dy = target_position.y - player_position.y
        distance = math.sqrt(dx * dx + dy * dy)
        set_cached_distance(player_index, target_position, distance)
    end

    return distance <= player.build_distance
end

-- 优化的核心功能：切换玩家的快捷键状态
function AutoPlacer:toggle_shortcut(player)
    if not player or not player.valid then return end

    -- 如果技术未研究，强制禁用快捷键并返回
    if not AutoPlacer:is_available(player) then
        AutoPlacer:set_toggled(player, false)
        return
    end

    -- 切换状态并向玩家显示提示消息
    if AutoPlacer:is_toggled(player) then
        player.print({ "autoplacer.messages.disabled" })
        AutoPlacer:set_toggled(player, false)
    else
        player.print({ "autoplacer.messages.enabled" })
        AutoPlacer:set_toggled(player, true)
    end
end

-- 优化的Lua快捷键事件处理
local function on_lua_shortcut(event)
    if not event or not event.player_index then return end
    if event.prototype_name ~= AutoPlacer.CONSTANTS.SHORTCUT then return end

    local player = game.get_player(event.player_index)
    if player and player.valid then
        AutoPlacer:toggle_shortcut(player)
    end
end

-- 优化的自定义按键输入事件处理
local function on_custom_input(event)
    if not event or not event.player_index then return end

    local player = game.get_player(event.player_index)
    if player and player.valid then
        AutoPlacer:toggle_shortcut(player)
    end
end

-- 注册事件处理器
script.on_event(defines.events.on_lua_shortcut, on_lua_shortcut)
script.on_event(AutoPlacer.CONSTANTS.SHORTCUT, on_custom_input)

-- 优化的控制台命令系统
function AutoPlacer:research_for_force(force)
    if not force or not force.valid then return false end
    local tech = force.technologies[AutoPlacer.CONSTANTS.TECHNOLOGY_NAME]
    if tech and not tech.researched then
        tech.researched = true
        return true
    end
    return false
end

function AutoPlacer:research_for_all_forces()
    local researched_count = 0
    for _, force in pairs(game.forces) do
        if AutoPlacer:research_for_force(force) then
            game.print({ "autoplacer.command.researched-server", force.name })
            researched_count = researched_count + 1
        end
    end
    return researched_count
end

-- 控制台命令处理器
local function on_research_command(command)
    if not command then return end

    local player = game.get_player(command.player_index)

    if not player then
        -- 服务器控制台命令
        local count = AutoPlacer:research_for_all_forces()
        if count > 0 then
            game.print(string.format("Auto Placer technology researched for %d force(s).", count))
        else
            game.print("All forces already have Auto Placer technology researched.")
        end
        return
    end

    -- 检查管理员权限
    if not player.admin then
        player.print({ "autoplacer.command.no-permission" })
        return
    end

    -- 检查并研究技术
    if AutoPlacer:research_for_force(player.force) then
        player.print({ "autoplacer.command.researched" })
    else
        player.print({ "autoplacer.command.already-researched" })
    end
end

-- 注册控制台命令
commands.add_command("autoplacer-research", { "autoplacer.command.description" }, on_research_command)



-- 优化的消息显示系统
AutoPlacer.MESSAGE_COLORS = {
    error = { r = 1, g = 0.4, b = 0.4, a = 1 },
    warning = { r = 1, g = 0.8, b = 0.2, a = 1 },
    success = { r = 0.4, g = 1, b = 0.4, a = 1 },
    info = { r = 0.4, g = 0.6, b = 1, a = 1 }
}

function AutoPlacer:show_flying_text(player, position, text, color_type, time_to_live)
    if not player or not player.valid then return end

    color_type = color_type or "error"
    time_to_live = time_to_live or 600

    player.create_local_flying_text({
        text = text,
        position = position,
        color = AutoPlacer.MESSAGE_COLORS[color_type],
        time_to_live = time_to_live
    })
end

function AutoPlacer:show_range_message(player, position)
    AutoPlacer:show_flying_text(player, position, { "autoplacer.messages.out-of-range" }, "warning")
end

function AutoPlacer:show_build_failed_message(player, position)
    AutoPlacer:show_flying_text(player, position, { "autoplacer.messages.build-failed" }, "error")
end

function AutoPlacer:refund_item(player, item_name, quality, position)
    if not player or not player.valid then return end

    player.insert({ name = item_name, count = 1, quality = quality })
    AutoPlacer:show_build_failed_message(player, position)
end

-- 优化的自动放置核心功能
function AutoPlacer:can_place_ghost(player, ghost_entity)
    if not player or not player.valid or not ghost_entity or not ghost_entity.valid then
        return false, "Invalid player or ghost entity"
    end

    -- 检查幽灵实体类型
    if ghost_entity.name ~= "entity-ghost" then
        return false, "Not a ghost entity"
    end

    -- 获取幽灵原型信息
    local ghost_prototype = ghost_entity.ghost_prototype
    if not ghost_prototype then
        return false, "Invalid ghost prototype"
    end

    return true
end

function AutoPlacer:find_matching_item(player, ghost_entity, item_list)
    if not player or not player.valid then return nil end

    local cursor_stack = player.cursor_stack
    if not cursor_stack or not cursor_stack.valid_for_read then
        return nil
    end

    -- 检查光标中的物品是否可用于建造当前悬停的幽灵
    for _, item in pairs(item_list) do
        if cursor_stack.name == item.name and cursor_stack.quality == ghost_entity.quality then
            return item
        end
    end

    return nil
end

function AutoPlacer:execute_placement(player, ghost_entity, matching_item)
    if not player or not player.valid or not ghost_entity or not ghost_entity.valid or not matching_item then
        return false
    end

    local cursor_stack = player.cursor_stack
    if not cursor_stack or cursor_stack.count < 1 then
        return false
    end

    -- 减少光标中物品的数量
    cursor_stack.count = cursor_stack.count - 1

    -- 尝试"复活"幽灵实体为真实实体
    local revived, reason = ghost_entity.revive({ raise_revive = true })
    if not revived then
        -- 如果复活失败，将物品归还给玩家
        self:refund_item(player, matching_item.name, ghost_entity.quality, ghost_entity.position)
        return false
    end

    return true
end

-- 优化的自动放置事件处理器
local function on_auto_placer_event(event)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end

    -- 确保自动放置功能已启用
    if not AutoPlacer:is_toggled(player) then return end

    -- 检查玩家是否悬停在实体幽灵上
    local hovered_entity = player.selected
    if not hovered_entity or hovered_entity.name ~= "entity-ghost" then return end

    -- 验证幽灵实体
    local can_place, error_msg = AutoPlacer:can_place_ghost(player, hovered_entity)
    if not can_place then
        -- 可选：记录错误消息用于调试
        return
    end

    -- 获取幽灵实体的原型信息
    local ghost_prototype = hovered_entity.ghost_prototype
    if not ghost_prototype then return end

    -- 获取可以放置此幽灵的物品列表
    local item_list = ghost_prototype.items_to_place_this
    if not item_list then return end

    -- 查找匹配的物品
    local matching_item = AutoPlacer:find_matching_item(player, hovered_entity, item_list)

    -- 只有当光标中的物品可以放置当前幽灵时才检查建造范围
    if matching_item then
        -- 检查目标位置是否在玩家的建造范围内
        if not AutoPlacer:is_within_build_range(player, hovered_entity.position) then
            -- 超出建造范围，显示提示信息
            AutoPlacer:show_range_message(player, hovered_entity.position)
            return
        end
    else
        return -- 没有匹配物品，直接返回
    end

    -- 检查是否可以在该位置放置实体
    if not player.surface.can_place_entity({
            name = hovered_entity.ghost_name,
            position = hovered_entity.position,
            direction = hovered_entity.direction,
            force = player.force,
            build_check_type = defines.build_check_type.ghost_revive,
        }) then
        return
    end

    -- 执行建造操作
    AutoPlacer:execute_placement(player, hovered_entity, matching_item)
end

-- 注册自动放置相关事件
script.on_event({
    defines.events.on_selected_entity_changed,
    defines.events.on_player_cursor_stack_changed
}, on_auto_placer_event)

-- 返回模块供其他脚本使用
return AutoPlacer

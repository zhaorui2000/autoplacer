-- control.lua
-- 自动放置器模块主文件，实现自动放置实体幽灵的功能

-- 快捷键名称定义
local SHORTCUT = 'autoplacer-toggle'

-- 检查玩家是否已研究相关技术以启用此功能
-- 只有研究"autoplacer"技术的玩家才能使用此功能
local function is_available(player)
    return player.force.technologies["autoplacer"].researched
end

-- 设置快捷键的切换状态（开/关）
local function set_toggled(player, state)
    player.set_shortcut_toggled(SHORTCUT, state)
end

-- 检查快捷键当前是否处于开启状态
local function is_toggled(player)
    return player.is_shortcut_toggled(SHORTCUT)
end

-- 计算玩家的最大建造距离
local function get_build_distance(player)
    local distance = player.build_distance

    -- 检查新范围技术并计算建造距离
    if player.force.technologies["autoplacer-range-1"].researched then
        distance = distance * 2 -- 距离翻倍
    end

    if player.force.technologies["autoplacer-range-2"].researched then
        distance = distance * 2 -- 再次翻倍（总计4倍）
    end

    if player.force.technologies["autoplacer-range-3"].researched then
        local range_upgrade_level = player.force.technologies["autoplacer-range-3"].level - 2
        if range_upgrade_level >= 1 then
            distance = distance * (2 ^ range_upgrade_level)
        end
    end

    return distance
end

-- 检查玩家与目标位置的距离是否在建造范围内
local function is_within_build_range(player, target_position)
    local player_position = player.position
    local build_distance = get_build_distance(player)
    local distance = math.sqrt((target_position.x - player_position.x) ^ 2 + (target_position.y - player_position.y) ^ 2)
    return distance <= build_distance
end

-- 核心功能：切换玩家的快捷键状态
local function toggle_shortcut(player)
    if not player then return end

    -- 如果技术未研究，强制禁用快捷键并返回
    if not is_available(player) then
        set_toggled(player, false)
        return
    end

    -- 切换状态并向玩家显示提示消息
    if is_toggled(player) then
        player.print({ "autoplacer.messages.disabled" })
        set_toggled(player, false)
    else
        player.print({ "autoplacer.messages.enabled" })
        set_toggled(player, true)
    end
end

-- 处理Lua快捷键事件（当玩家按下定义的快捷键时触发）
script.on_event(defines.events.on_lua_shortcut, function(event)
    if event.prototype_name == SHORTCUT then
        toggle_shortcut(game.get_player(event.player_index))
    end
end)

-- 处理自定义按键输入事件（另一种触发方式）
script.on_event(SHORTCUT, function(event)
    toggle_shortcut(game.get_player(event.player_index))
end)

-- 为所有势力研究自动放置器技术
local function research_for_all_forces(technology_name)
    for _, force in pairs(game.forces) do
        if force.technologies[technology_name] and not force.technologies[technology_name].researched then
            force.technologies[technology_name].researched = true
            game.print({ "autoplacer.command.researched-server", force.name })
        end
    end
end

-- 处理控制台命令：研究自动放置器技术
commands.add_command("autoplacer-research", { "autoplacer.command.description" }, function(command)
    local player = game.get_player(command.player_index)
    if not player then
        -- 如果从服务器控制台运行命令，应用于所有势力
        research_for_all_forces("autoplacer")
        return
    end

    -- 检查玩家是否有管理员权限（可选，您可以根据需要移除此检查）
    if not player.admin then
        player.print({ "autoplacer.command.no-permission" })
        return
    end

    -- 检查技术是否已经研究
    if player.force.technologies["autoplacer"].researched then
        player.print({ "autoplacer.command.already-researched" })
        return
    end

    -- 研究技术
    player.force.technologies["autoplacer"].researched = true
    player.print({ "autoplacer.command.researched" })
end)

-- 处理控制台命令：研究范围技术
commands.add_command("autoplacer-range", { "autoplacer.command.range-description" }, function(command)
    local player = game.get_player(command.player_index)
    if not player then
        -- 如果从服务器控制台运行命令，应用于所有势力
        for i = 1, 3 do
            research_for_all_forces("autoplacer-range-" .. i)
        end
        return
    end

    -- 检查玩家是否有管理员权限
    if not player.admin then
        player.print({ "autoplacer.command.no-permission" })
        return
    end

    -- 研究所有范围技术
    for i = 1, 3 do
        local tech_name = "autoplacer-range-" .. i
        if not player.force.technologies[tech_name].researched then
            player.force.technologies[tech_name].researched = true
            player.print({ "autoplacer.command.range-researched", tech_name })
        else
            player.print({ "autoplacer.command.range-already-researched", tech_name })
        end
    end
end)

-- 显示范围提示信息
local function show_range_message(player, position, message_key)
    player.create_local_flying_text({
        text = { message_key },
        position = position,
        color = { r = 1, g = 0.4, b = 0.4 },
        time_to_live = 600
    })
end

-- 显示建造失败提示信息
local function show_build_failed_message(player, position)
    player.create_local_flying_text({
        text = { "autoplacer.messages.build-failed" },
        position = position,
        color = { r = 1, g = 0.4, b = 0.4 },
    })
end

-- 处理物品归还
local function refund_item(player, item_name, quality, position)
    player.insert({ name = item_name, count = 1, quality = quality })
    show_build_failed_message(player, position)
end

-- 监听两个关键事件以实现自动放置功能：
--   1. 当所选实体改变时（包括将光标拖拽到幽灵上）
--   2. 当光标物品改变时（如切换快捷栏物品或使用吸管工具）
script.on_event({
    defines.events.on_selected_entity_changed,
    defines.events.on_player_cursor_stack_changed
}, function(event)
    local player = game.get_player(event.player_index)
    if not player then return end

    -- 确保自动放置功能已启用
    if not is_toggled(player) then return end

    -- 检查玩家是否悬停在实体幽灵上
    -- 实体幽灵是Factorio中代表要放置实体的占位符
    local hovered_entity = player.selected
    if hovered_entity and hovered_entity.name == "entity-ghost" then
        -- 获取幽灵实体的原型信息
        local ghost_prototype = hovered_entity.ghost_prototype
        if not ghost_prototype then return end

        -- 获取可以放置此幽灵的物品列表
        local item_list = ghost_prototype.items_to_place_this
        local cursor_stack = player.cursor_stack

        -- 检查光标中是否有物品
        local has_cursor_item = cursor_stack and cursor_stack.valid_for_read

        -- 检查光标中的物品是否可用于建造当前悬停的幽灵
        local matching_item = nil
        if has_cursor_item then
            for _, item in pairs(item_list) do
                if cursor_stack.name == item.name and cursor_stack.quality == hovered_entity.quality then
                    matching_item = item
                    break
                end
            end
        end

        -- 只有当光标中的物品可以放置当前幽灵时才检查建造范围
        if matching_item then
            -- 检查目标位置是否在玩家的建造范围内
            if not is_within_build_range(player, hovered_entity.position) then
                -- 超出建造范围，显示提示信息
                show_range_message(player, hovered_entity.position, { "autoplacer.messages.out-of-range" })
                return
            end
        end

        -- 检查是否可以在该位置放置实体，防止在碰撞实体或地形上建造
        -- 使用表面版本的函数可以避免替换实体的问题（如在地下传送带上放置传送带）
        if not player.surface.can_place_entity({
                name = hovered_entity.ghost_name,
                position = hovered_entity.position,
                direction = hovered_entity.direction,
                force = player.force,
                build_check_type = defines.build_check_type.ghost_revive,
            }) then
            return
        end

        -- 如果找到匹配的物品，执行建造操作
        if matching_item then
            -- 减少光标中物品的数量（消耗一个物品）
            cursor_stack.count = cursor_stack.count - 1

            -- 尝试"复活"幽灵实体为真实实体
            -- 这是将蓝图中的幽灵转换为实体的关键方法
            local revived, _ = hovered_entity.revive({ raise_revive = true })
            if not revived then
                -- 如果复活失败，将物品归还给玩家
                refund_item(player, matching_item.name, hovered_entity.quality, hovered_entity.position)
            end
            return
        end
    end
end)

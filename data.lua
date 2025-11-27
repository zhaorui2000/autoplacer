-- data.lua
-- AutoPlacer mod 数据定义文件
-- 定义模组的自定义输入、技术树和快捷键
-- 版本: 2.0.0

-- 常量定义
local AutoPlacerData = {
  MOD_NAME = "__autoplacer__",
  ICON_PATH_LARGE = "__autoplacer__/graphics/autoplacer/512.png",
  ICON_PATH_SMALL = "__autoplacer__/graphics/autoplacer/32.png"
}

-- 验证必需函数是否存在
if not data or not data.extend then
  error("AutoPlacer: data.extend function not available!")
end

-- 定义自定义输入
local custom_input = {
  type = "custom-input",
  name = "autoplacer-toggle",
  key_sequence = "CONTROL + G"
  -- 移除consuming字段，使用默认值
}

-- 定义"Auto Placer"技术
local technology = {
  type = "technology",
  name = "autoplacer",
  icons = {
    {
      icon = AutoPlacerData.ICON_PATH_LARGE,
      icon_size = 512,
      icon_mipmaps = 4
    }
  },
  prerequisites = { "automation-2" },
  unit = {
    count = 100,
    ingredients = {
      { "automation-science-pack", 1 },
      { "logistic-science-pack",   1 }
    },
    time = 30 -- 优化：减少研发时间从100到30
  },
  -- 增加升级效果，让技术更有价值
  effects = {
    {
      type = "nothing",
      effect_id = "autoplacer-basic"
    }
  }
}

-- 定义游戏内快捷键（在科技树界面解锁后显示）
local shortcut = {
  type = "shortcut",
  name = "autoplacer-toggle",
  order = "a[automation]-p[placer]", -- 优化：更清晰的排序
  action = "lua",
  technology_to_unlock = "autoplacer",
  unavailable_until_unlocked = true,
  toggleable = true,
  localised_name = { "autoplacer.gui.toggle-button" },
  associated_control_input = "autoplacer-toggle",
  icons = {
    {
      icon = AutoPlacerData.ICON_PATH_SMALL,
      icon_size = 32,
      icon_mipmaps = 3
    }
  },
  small_icons = {
    {
      icon = AutoPlacerData.ICON_PATH_SMALL,
      icon_size = 32,
      icon_mipmaps = 3
    }
  }
}

-- 扩展数据表
local extended_data = {
  custom_input,
  technology,
  shortcut
}

-- 应用扩展
local success, result = pcall(data.extend, extended_data)

if not success then
  error("AutoPlacer: Failed to extend data: " .. tostring(result))
end

-- 验证扩展结果
if result then
  log("AutoPlacer: Data extension completed successfully")
else
  log("AutoPlacer: Warning - Data extension returned nil")
end

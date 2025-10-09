-- data.lua
-- AutoPlacer mod data definition file
-- This file defines the mod's custom inputs, technology tree, and shortcut for technology unlock

data:extend({
  -- Define custom shortcut input
  {
    type = "custom-input",
    name = "autoplacer-toggle",
    key_sequence = "CONTROL + G",
    consuming = "none"
  },
  
  -- Define "Auto Placer" technology
  {
    type = "technology",
    name = "autoplacer",
    icons = {
      {
        icon = "__autoplacer__/graphics/autoplacer/512.png",
        icon_size = 512
      }
    },
    prerequisites = { "automation-2" },
    unit = {
      count = 100,
      ingredients = {
        { "automation-science-pack", 1 },
        { "logistic-science-pack", 1 }
      },
      time = 100
    }
  },
  
  -- Define "Auto Placer Range 1" technology
  {
    type = "technology",
    name = "autoplacer-range-1",
    icons = {
      {
        icon = "__autoplacer__/graphics/autoplacer-range/512.png",
        icon_size = 512
      }
    },
    prerequisites = { "autoplacer" },
    unit = {
      count = 200,
      ingredients = {
        { "automation-science-pack", 1 },
        { "logistic-science-pack", 1 },
        { "production-science-pack", 1 }
      },
      time = 200
    }
  },
  
  -- Define "Auto Placer Range 2" technology
  {
    type = "technology",
    name = "autoplacer-range-2",
    icons = {
      {
        icon = "__autoplacer__/graphics/autoplacer-range/512.png",
        icon_size = 512
      }
    },
    prerequisites = { "autoplacer-range-1" },
    unit = {
      count = 300,
      ingredients = {
        { "automation-science-pack", 1 },
        { "logistic-science-pack", 1 },
        { "production-science-pack", 1 }
      },
      time = 300
    }
  },
  
  -- Define "Auto Placer Range 3" technology
  {
    type = "technology",
    name = "autoplacer-range-3",
    icons = {
      {
        icon = "__autoplacer__/graphics/autoplacer-range/512.png",
        icon_size = 512
      }
    },
    prerequisites = { "autoplacer-range-2" },
    upgrade = true,
    max_level = "infinite",
    unit = {
      count_formula = "500*L",
      ingredients = {
        { "automation-science-pack", 1 },
        { "logistic-science-pack", 1 },
        { "production-science-pack", 1 },
        { "space-science-pack", 1 },
      },
      time = 500
    }
  },
  
  -- Define in-game shortcut (displayed in technology tree interface after technology unlock)
  {
    type = "shortcut",
    name = "autoplacer-toggle",
    order = "a[auto]-p[placer]",
    action = "lua",
    technology_to_unlock = "autoplacer",
    unavailable_until_unlocked = true,
    toggleable = true,
    localised_name = { "autoplacer.gui.toggle-button" },
    associated_control_input = "autoplacer-toggle",
    icons = {
      {
        icon = "__autoplacer__/graphics/autoplacer/32.png",
        icon_size = 32
      }
    },
    small_icons = {
      {
        icon = "__autoplacer__/graphics/autoplacer/32.png",
        icon_size = 32
      }
    }
  }
})
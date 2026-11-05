local icons = {
  {
    icon = "__base__/graphics/icons/small-worm.png",
    icon_size = 64,
    tint = { r = 1, g = 0.35, b = 0.35, a = 1 },
  },
}

data:extend({
  {
    type = "custom-input",
    name = "atmos-enemy-range-toggle",
    action = "lua",
    key_sequence = "CONTROL + SHIFT + R",
    order = "a",
  },
  {
    type = "custom-input",
    name = "atmos-enemy-range-panel",
    action = "lua",
    key_sequence = "CONTROL + SHIFT + E",
    order = "b",
  },
  {
    type = "shortcut",
    name = "atmos-enemy-range-toggle",
    localised_name = { "shortcut-name.atmos-enemy-range-toggle" },
    icons = icons,
    small_icons = icons,
    action = "lua",
    associated_control_input = "atmos-enemy-range-toggle",
    order = "c[toggles]-d[enemy-range]",
    toggleable = true,
  },
})

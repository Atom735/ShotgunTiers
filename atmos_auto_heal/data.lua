local icons = {
  {
    icon = "__base__/graphics/icons/fish.png",
    icon_size = 64,
  },
}

data:extend({
  {
    type = "custom-input",
    name = "atmos-auto-heal-toggle",
    action = "lua",
    key_sequence = "CONTROL + SHIFT + H",
    order = "a",
  },
  {
    type = "custom-input",
    name = "atmos-auto-heal-panel",
    action = "lua",
    key_sequence = "CONTROL + SHIFT + J",
    order = "b",
  },
  {
    type = "shortcut",
    name = "atmos-auto-heal-toggle",
    localised_name = { "shortcut-name.atmos-auto-heal-toggle" },
    icons = icons,
    small_icons = icons,
    action = "lua",
    associated_control_input = "atmos-auto-heal-toggle",
    order = "c[toggles]-e[auto-heal]",
    toggleable = true,
  },
})

local shortcut_icon = {
  icon = "__base__/graphics/icons/shotgun.png",
  icon_size = 64,
}

data:extend({
  {
    type = "custom-input",
    name = "atmos-auto-fire-toggle",
    key_sequence = "CONTROL + ALT + G",
    action = "lua",
    order = "a",
    localised_name = { "controls.atmos-auto-fire-toggle" },
  },
  {
    type = "shortcut",
    name = "atmos-auto-fire-toggle",
    localised_name = { "shortcut-name.atmos-auto-fire-toggle" },
    action = "lua",
    toggleable = true,
    associated_control_input = "atmos-auto-fire-toggle",
    order = "c[toggles]-e[atmos-auto-fire]",
    icons = { shortcut_icon },
    small_icons = { shortcut_icon },
  },
})

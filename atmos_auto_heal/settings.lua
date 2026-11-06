data:extend({
  {
    type = "int-setting",
    name = "atmos-auto-heal-threshold",
    setting_type = "runtime-per-user",
    default_value = 70,
    minimum_value = 1,
    maximum_value = 99,
    order = "a",
  },
  {
    type = "bool-setting",
    name = "atmos-auto-heal-avoid-overheal",
    setting_type = "runtime-per-user",
    default_value = true,
    order = "b",
  },
})

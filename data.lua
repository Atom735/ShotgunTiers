local damage_step = settings.startup["shotguntiers-damage-bonus"].value / 100
local range_step = settings.startup["shotguntiers-range-bonus"].value / 100
local speed_step = settings.startup["shotguntiers-speed-bonus"].value / 100
local ammo_damage_step = settings.startup["shotguntiers-ammo-damage-bonus"].value / 100

local gun_names = {
  "shotgun",
  "combat-shotgun",
  "pistol",
  "submachine-gun",
  "rocket-launcher",
}

local ammo_names = {
  "firearm-magazine",
  "piercing-rounds-magazine",
  "uranium-rounds-magazine",
  "shotgun-shell",
  "piercing-shotgun-shell",
  "rocket",
}

local guns_raw = data.raw.gun
local ammo_raw = data.raw.ammo
local recipes_raw = data.raw.recipe

local function scale_ammo_damage(node, multiplier, visited)
  if type(node) ~= "table" then
    return
  end

  visited = visited or {}
  if visited[node] then
    return
  end
  visited[node] = true

  local damage = node.damage
  if type(damage) == "table" and type(damage.amount) == "number" then
    damage.amount = damage.amount * multiplier
  end

  for _, value in pairs(node) do
    if type(value) == "table" then
      scale_ammo_damage(value, multiplier, visited)
    end
  end
end

local function clear_icon_keys(proto)
  proto.icon = nil
  proto.icon_size = nil
  proto.icon_mipmaps = nil
  proto.icon_dark = nil
  proto.icon_design = nil
end

local function build_tier_icons(base_proto, tier)
  local icons = {}

  if base_proto.icons then
    for _, layer in ipairs(base_proto.icons) do
      icons[#icons + 1] = table.deepcopy(layer)
    end
  elseif base_proto.icon then
    icons[1] = {
      icon = base_proto.icon,
      icon_size = base_proto.icon_size or 64,
      icon_mipmaps = base_proto.icon_mipmaps,
    }
  else
    return nil
  end

  if tier < 10 then
    icons[#icons + 1] = {
      icon = "__core__/graphics/icons/mip/" .. tier .. ".png",
      icon_size = 32,
      scale = 0.5,
      shift = { -8, 8 },
    }
  else
    icons[#icons + 1] = {
      icon = "__core__/graphics/story-elements/achievement-unlocked.png",
      icon_size = 128,
      scale = 0.2,
      shift = { -8, 8 },
    }
  end

  return icons
end

local function tier_item_name(base_name, tier)
  return base_name .. "-t" .. tier
end

local function previous_item_name(base_name, tier)
  if tier == 2 then
    return base_name
  end
  return tier_item_name(base_name, tier - 1)
end

local function is_recipe_enabled(recipe)
  if not recipe then
    return true
  end
  if recipe.enabled == false then
    return false
  end
  return true
end

local function make_tier_recipe(base_name, tier, result_type)
  local base_recipe = recipes_raw[base_name]
  local recipe = {
    type = "recipe",
    name = tier_item_name(base_name, tier),
    localised_name = { "item-name." .. tier_item_name(base_name, tier) },
    category = base_recipe and base_recipe.category or nil,
    subgroup = base_recipe and base_recipe.subgroup or nil,
    order = (base_recipe and base_recipe.order or base_name) .. "-t" .. tier,
    energy_required = base_recipe and base_recipe.energy_required or 0.5,
    enabled = is_recipe_enabled(base_recipe),
    apply_recipe_coefficients = false,
    allow_as_intermediate = false,
    ingredients = {
      { type = "item", name = previous_item_name(base_name, tier), amount = 5 },
    },
    results = {
      { type = "item", name = tier_item_name(base_name, tier), amount = 1 },
    },
  }

  if result_type == "gun" or result_type == "ammo" then
    recipe.allow_decomposition = false
  end

  return recipe
end

local function create_gun_tiers(base_name)
  local base = guns_raw[base_name]
  if not base then
    return
  end

  for tier = 2, 10 do
    local modifier = tier - 1
    local proto = table.deepcopy(base)
    proto.name = tier_item_name(base_name, tier)
    proto.order = (base.order or base_name) .. "-t" .. tier
    proto.localised_name = { "item-name." .. proto.name }

    local attack = proto.attack_parameters
    if attack then
      local damage_mult = (1 + damage_step) ^ modifier
      local range_mult = (1 + range_step) ^ modifier
      local speed_div = (1 + speed_step) ^ modifier

      attack.damage_modifier = (attack.damage_modifier or 1) * damage_mult
      if type(attack.range) == "number" then
        attack.range = attack.range * range_mult
      end
      if type(attack.min_range) == "number" then
        attack.min_range = attack.min_range * range_mult
      end
      if type(attack.cooldown) == "number" then
        attack.cooldown = attack.cooldown / speed_div
      end
    end

    clear_icon_keys(proto)
    proto.icons = build_tier_icons(base, tier)

    data:extend({ proto, make_tier_recipe(base_name, tier, "gun") })
  end
end

local function create_ammo_tiers(base_name)
  local base = ammo_raw[base_name]
  if not base then
    return
  end

  for tier = 2, 10 do
    local modifier = tier - 1
    local proto = table.deepcopy(base)
    proto.name = tier_item_name(base_name, tier)
    proto.order = (base.order or base_name) .. "-t" .. tier
    proto.localised_name = { "item-name." .. proto.name }

    local damage_mult = (1 + ammo_damage_step) ^ modifier
    if proto.ammo_type then
      scale_ammo_damage(proto.ammo_type.action, damage_mult, {})
    end

    clear_icon_keys(proto)
    proto.icons = build_tier_icons(base, tier)

    data:extend({ proto, make_tier_recipe(base_name, tier, "ammo") })
  end
end

for i = 1, #gun_names do
  create_gun_tiers(gun_names[i])
end

for i = 1, #ammo_names do
  create_ammo_tiers(ammo_names[i])
end

local damage_step = settings.startup["shotguntiers-damage-bonus"].value / 100
local range_step = settings.startup["shotguntiers-range-bonus"].value / 100
local speed_step = settings.startup["shotguntiers-speed-bonus"].value / 100
local ammo_damage_step = settings.startup["shotguntiers-ammo-damage-bonus"].value / 100

local MAX_TIER = 5

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
local projectiles_raw = data.raw.projectile

local created_projectiles = {}

local function tier_item_name(base_name, tier)
  return base_name .. "-t" .. tier
end

local function previous_item_name(base_name, tier)
  if tier == 2 then
    return base_name
  end
  return tier_item_name(base_name, tier - 1)
end

local function tier_order_suffix(tier)
  return string.format("-t%02d", tier)
end

local function scale_damage_amounts(node, multiplier, visited)
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
      scale_damage_amounts(value, multiplier, visited)
    end
  end
end

local function ensure_tier_projectile(base_projectile_name, tier, multiplier)
  local new_name = tier_item_name(base_projectile_name, tier)
  if created_projectiles[new_name] then
    return new_name
  end

  local base = projectiles_raw[base_projectile_name]
  if not base then
    return base_projectile_name
  end

  local proto = table.deepcopy(base)
  proto.name = new_name
  proto.localised_name = proto.localised_name or { "entity-name." .. base_projectile_name }
  scale_damage_amounts(proto.action, multiplier, {})
  data:extend({ proto })
  created_projectiles[new_name] = true
  return new_name
end

-- Scales inline damage and retargets projectile deliveries to tiered clones.
local function enhance_ammo_action(node, tier, multiplier, visited)
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

  if type(node.projectile) == "string" then
    node.projectile = ensure_tier_projectile(node.projectile, tier, multiplier)
  end

  for _, value in pairs(node) do
    if type(value) == "table" then
      enhance_ammo_action(value, tier, multiplier, visited)
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

  if tier < MAX_TIER then
    icons[#icons + 1] = {
      icon = "__base__/graphics/icons/signal/signal_" .. tier .. ".png",
      scale = 0.25,
      shift = { -8, 8 },
    }
  else
    icons[#icons + 1] = {
      icon = "__base__/graphics/icons/signal/signal-star.png",
      scale = 0.25,
      shift = { -8, 8 },
    }
  end

  return icons
end

local function make_tier_recipe(base_name, tier, base_item)
  local base_recipe = recipes_raw[base_name]
  return {
    type = "recipe",
    name = tier_item_name(base_name, tier),
    localised_name = { "item-name." .. tier_item_name(base_name, tier) },
    categories = (base_recipe and base_recipe.categories) or { "crafting" },
    subgroup = (base_item and base_item.subgroup) or (base_recipe and base_recipe.subgroup) or nil,
    order = ((base_item and base_item.order) or (base_recipe and base_recipe.order) or base_name)
      .. tier_order_suffix(tier),
    energy_required = 0.01,
    enabled = true,
    unlock_results = true,
    apply_recipe_coefficients = false,
    allow_as_intermediate = false,
    allow_decomposition = false,
    ingredients = {
      { type = "item", name = previous_item_name(base_name, tier), amount = 5 },
    },
    results = {
      { type = "item", name = tier_item_name(base_name, tier), amount = 1 },
    },
  }
end

local function create_gun_tiers(base_name)
  local base = guns_raw[base_name]
  if not base then
    return
  end

  for tier = 2, MAX_TIER do
    local modifier = tier - 1
    local proto = table.deepcopy(base)
    proto.name = tier_item_name(base_name, tier)
    proto.order = (base.order or base_name) .. tier_order_suffix(tier)
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

    data:extend({ proto, make_tier_recipe(base_name, tier, base) })
  end
end

local function create_ammo_tiers(base_name)
  local base = ammo_raw[base_name]
  if not base then
    return
  end

  for tier = 2, MAX_TIER do
    local modifier = tier - 1
    local proto = table.deepcopy(base)
    proto.name = tier_item_name(base_name, tier)
    proto.order = (base.order or base_name) .. tier_order_suffix(tier)
    proto.localised_name = { "item-name." .. proto.name }

    local damage_mult = (1 + ammo_damage_step) ^ modifier
    if proto.ammo_type then
      enhance_ammo_action(proto.ammo_type.action, tier, damage_mult, {})
    end

    clear_icon_keys(proto)
    proto.icons = build_tier_icons(base, tier)

    data:extend({ proto, make_tier_recipe(base_name, tier, base) })
  end
end

for i = 1, #gun_names do
  create_gun_tiers(gun_names[i])
end

for i = 1, #ammo_names do
  create_ammo_tiers(ammo_names[i])
end

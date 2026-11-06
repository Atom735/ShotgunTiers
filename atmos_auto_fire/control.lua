local SHORTCUT_NAME = "atmos-auto-fire-toggle"
local BUTTON_NAME = "atmos_auto_fire_settings"
local FRAME_NAME = "atmos_auto_fire_frame"
local STATUS_NAME = "atmos_auto_fire_status"
local IGNORE_CHECK = "atmos_auto_fire_ignore_friendly"
local DEBUG_CHECK = "atmos_auto_fire_debug"
local ALLOW_HOLDER = "atmos_auto_fire_allow_holder"
local FORBID_HOLDER = "atmos_auto_fire_forbid_holder"

local SCAN_INTERVAL = 5
local FOOT_CLEARANCE_SQ = 0.49
local DIST_MIN = 1
local DIST_MAX_PERCENT = 100
local DIST_MAX_METERS = 100

local HOSTILE_TYPES = {
  "unit",
  "spider-unit",
  "segmented-unit",
  "unit-spawner",
  "turret",
  "combat-robot",
}

local TYPE_OPTIONS = {
  { id = "all", locale = "filter-all" },
  { id = "entity", locale = "filter-entity" },
  { id = "unit-spawner", locale = "filter-type-unit-spawner" },
  { id = "combat-robot", locale = "filter-type-combat-robot" },
  { id = "unit", locale = "filter-type-unit" },
  { id = "turret", locale = "filter-type-turret" },
  { id = "spider-unit", locale = "filter-type-spider-unit" },
  { id = "segmented-unit", locale = "filter-type-segmented-unit" },
}

local TYPE_OPTION_INDEX = {}
for i = 1, #TYPE_OPTIONS do
  TYPE_OPTION_INDEX[TYPE_OPTIONS[i].id] = i
end

local ENTITY_ELEM_FILTERS = {
  { filter = "type", type = "unit" },
  { filter = "type", type = "spider-unit" },
  { filter = "type", type = "segmented-unit" },
  { filter = "type", type = "unit-spawner" },
  { filter = "type", type = "turret" },
  { filter = "type", type = "combat-robot" },
  { filter = "type", type = "ammo-turret" },
  { filter = "type", type = "electric-turret" },
  { filter = "type", type = "fluid-turret" },
  { filter = "type", type = "artillery-turret" },
}

local IGNORE_FRIENDLY_TYPES = {
  ["character"] = true,
  ["character-corpse"] = true,
  ["corpse"] = true,
  ["entity-ghost"] = true,
  ["tile-ghost"] = true,
  ["item-request-proxy"] = true,
  ["item-entity"] = true,
  ["explosion"] = true,
  ["fire"] = true,
  ["stream"] = true,
  ["beam"] = true,
  ["projectile"] = true,
  ["flying-text"] = true,
  ["particle-source"] = true,
  ["particle"] = true,
  ["leaf-particle"] = true,
  ["speech-bubble"] = true,
  ["highlight-box"] = true,
  ["sticker"] = true,
  ["smoke-with-trigger"] = true,
  ["trivial-smoke"] = true,
  ["smoke"] = true,
  ["tree"] = true,
  ["fish"] = true,
  ["resource"] = true,
  ["simple-entity"] = true,
  ["combat-robot"] = true,
  ["construction-robot"] = true,
  ["logistic-robot"] = true,
  ["capture-robot"] = true,
  ["unit"] = true,
  ["spider-unit"] = true,
  ["segmented-unit"] = true,
  ["deconstructible-tile-proxy"] = true,
  ["arrow"] = true,
  ["artillery-flare"] = true,
}

local spread_cache = {}
local gui_lock = false

local function rule_all(distance, mode)
  return {
    kind = "all",
    distance = distance,
    distance_mode = mode,
  }
end

local function rule_type(entity_type, distance, mode)
  return {
    kind = "type",
    entity_type = entity_type,
    distance = distance,
    distance_mode = mode,
  }
end

local function rule_entity(name, distance, mode)
  return {
    kind = "entity",
    name = name,
    distance = distance,
    distance_mode = mode,
  }
end

local function rule_forbid(name)
  return {
    kind = "entity",
    name = name,
  }
end

local function prototype_exists(name)
  return prototypes.entity[name] ~= nil
end

local function append_existing(list, names, distance, mode)
  for i = 1, #names do
    local name = names[i]
    if prototype_exists(name) then
      list[#list + 1] = rule_entity(name, distance, mode)
    end
  end
end

local function default_allow()
  local list = {
    rule_all(10, "percent"),
    rule_type("unit-spawner", 100, "percent"),
    rule_type("combat-robot", 100, "percent"),
  }
  append_existing(list, {
    "behemoth-worm-turret",
    "big-worm-turret",
    "medium-worm-turret",
    "small-worm-turret",
  }, 100, "percent")
  append_existing(list, {
    "behemoth-spitter",
    "big-spitter",
    "medium-spitter",
    "small-spitter",
  }, 100, "percent")
  append_existing(list, {
    "behemoth-biter",
    "big-biter",
    "medium-biter",
    "small-biter",
  }, 100, "percent")
  list[#list + 1] = rule_all(100, "percent")
  return list
end

local function default_forbid()
  local list = {}
  local names = { "gun-turret", "laser-turret", "flamethrower-turret" }
  for i = 1, #names do
    if prototype_exists(names[i]) then
      list[#list + 1] = rule_forbid(names[i])
    end
  end
  return list
end

local function clamp_distance(value, mode)
  local number = math.floor((tonumber(value) or 0) + 0.5)
  local max_value = mode == "meters" and DIST_MAX_METERS or DIST_MAX_PERCENT
  if number < DIST_MIN then
    number = DIST_MIN
  elseif number > max_value then
    number = max_value
  end
  return number
end

local function sanitize_allow_entry(entry)
  if type(entry) ~= "table" then
    return nil
  end
  local mode = entry.distance_mode == "meters" and "meters" or "percent"
  local distance = clamp_distance(entry.distance or 100, mode)
  if entry.kind == "all" then
    return rule_all(distance, mode)
  end
  if entry.kind == "type" and type(entry.entity_type) == "string" and entry.entity_type ~= "" then
    return rule_type(entry.entity_type, distance, mode)
  end
  if entry.kind == "entity" and type(entry.name) == "string" and entry.name ~= "" then
    return rule_entity(entry.name, distance, mode)
  end
  -- Legacy fallbacks from older incomplete rows.
  if type(entry.name) == "string" and entry.name ~= "" then
    return rule_entity(entry.name, distance, mode)
  end
  if type(entry.entity_type) == "string" and entry.entity_type ~= "" then
    return rule_type(entry.entity_type, distance, mode)
  end
  return rule_all(distance, mode)
end

local function sanitize_forbid_entry(entry)
  if type(entry) ~= "table" then
    return nil
  end
  local name = entry.name
  if type(name) ~= "string" or name == "" then
    return nil
  end
  return rule_forbid(name)
end

local function sanitize_list(raw, sanitizer, fallback, allow_empty)
  local cleaned = {}
  if type(raw) == "table" then
    for i = 1, #raw do
      local entry = sanitizer(raw[i])
      if entry then
        cleaned[#cleaned + 1] = entry
      end
    end
  end
  if #cleaned == 0 then
    if allow_empty and type(raw) == "table" then
      return cleaned
    end
    return fallback()
  end
  return cleaned
end

local function ensure_config(player_index)
  storage.player_configs = storage.player_configs or {}
  local config = storage.player_configs[player_index]
  if type(config) ~= "table" then
    config = {}
    storage.player_configs[player_index] = config
  end

  if type(config.enabled) ~= "boolean" then
    config.enabled = true
  end
  if type(config.debug) ~= "boolean" then
    config.debug = false
  end
  if type(config.ignore_friendly) ~= "boolean" then
    config.ignore_friendly = true
  end

  -- Drop legacy fields from 1.0.x.
  config.panic_radius = nil
  config.priorities = nil

  config.allow = sanitize_list(config.allow, sanitize_allow_entry, default_allow, false)
  config.forbid = sanitize_list(config.forbid, sanitize_forbid_entry, default_forbid, true)
  return config
end

local function ensure_runtime(player_index)
  storage.runtime = storage.runtime or {}
  local runtime = storage.runtime[player_index]
  if type(runtime) ~= "table" then
    runtime = {}
    storage.runtime[player_index] = runtime
  end
  return runtime
end

local function find_gui(parent, name)
  if not parent or not parent.valid then
    return nil
  end
  if parent.name == name then
    return parent
  end
  local children = parent.children
  for i = 1, #children do
    local found = find_gui(children[i], name)
    if found then
      return found
    end
  end
  return nil
end

local function forbid_set(config)
  local set = {}
  for i = 1, #config.forbid do
    local name = config.forbid[i].name
    if name then
      set[name] = true
    end
  end
  return set
end

local function sync_visuals(player, config)
  player.set_shortcut_toggled(SHORTCUT_NAME, config.enabled)
  local button = player.gui.top[BUTTON_NAME]
  if button then
    button.toggled = config.enabled
  end
  local frame = player.gui.screen[FRAME_NAME]
  if frame then
    local status = find_gui(frame, STATUS_NAME)
    if status then
      status.caption = config.enabled and { "atmos-auto-fire.status-on" } or { "atmos-auto-fire.status-off" }
    end
  end
end

local function combat_context(player)
  if not player or not player.valid then
    return nil
  end
  if player.controller_type ~= defines.controllers.character or player.vehicle then
    return nil
  end
  local character = player.character
  if not character or not character.valid then
    return nil
  end
  local gun_index = character.selected_gun_index
  if not gun_index or gun_index < 1 then
    return nil
  end
  local guns = character.get_inventory(defines.inventory.character_guns)
  local ammos = character.get_inventory(defines.inventory.character_ammo)
  if not guns or not ammos then
    return nil
  end
  local gun = guns[gun_index]
  if not gun or not gun.valid_for_read then
    return nil
  end
  if not string.find(gun.name, "shotgun", 1, true) then
    return nil
  end
  return {
    character = character,
    gun = gun,
    ammo = ammos[gun_index],
    gun_index = gun_index,
  }
end

local function weapon_stats(force, gun_stack, ammo_stack)
  local params = gun_stack.prototype.attack_parameters or {}
  local ammo_type = nil
  local ammo_ok, ammo_result = pcall(function()
    return ammo_stack.prototype.get_ammo_type("player") or ammo_stack.prototype.get_ammo_type()
  end)
  if ammo_ok then
    ammo_type = ammo_result
  end

  local range = params.range or 15
  local min_range = params.min_range or 0
  local cooldown_modifier = 1
  if ammo_type then
    if type(ammo_type.range_modifier) == "number" and ammo_type.range_modifier > 0 then
      range = range * ammo_type.range_modifier
    end
    if type(ammo_type.cooldown_modifier) == "number" and ammo_type.cooldown_modifier > 0 then
      cooldown_modifier = ammo_type.cooldown_modifier
    end
  end

  local category = params.ammo_category
  if not category and params.ammo_categories then
    category = params.ammo_categories[1]
  end
  if not category then
    category = "shotgun-shell"
  end

  local speed = 0
  local speed_ok, speed_value = pcall(function()
    return force.get_gun_speed_modifier(category)
  end)
  if speed_ok and type(speed_value) == "number" then
    speed = speed_value
  end
  local denom = 1 + speed
  if denom < 0.05 then
    denom = 0.05
  end
  local cooldown = math.max(1, math.floor(((params.cooldown or 60) * cooldown_modifier / denom) + 0.5))

  local damage_bonus = (params.damage_modifier or 1) - 1
  if damage_bonus < 0 then
    damage_bonus = 0
  end
  return range, min_range, cooldown, damage_bonus
end

local function cone_spread(ammo_name)
  local cached = spread_cache[ammo_name]
  if cached then
    return cached
  end
  local spread = 0.6
  local proto = prototypes.item[ammo_name]
  if proto then
    local ammo_type = nil
    local ok, result = pcall(function()
      return proto.get_ammo_type("player") or proto.get_ammo_type()
    end)
    if ok then
      ammo_type = result
    end
    local function walk(node)
      if type(node) ~= "table" then
        return
      end
      if node.type == "area" and type(node.radius) == "number" and node.radius > spread then
        spread = node.radius
      end
      for _, value in pairs(node) do
        if type(value) == "table" then
          walk(value)
        end
      end
    end
    if ammo_type and ammo_type.action then
      walk(ammo_type.action)
    end
  end
  spread_cache[ammo_name] = spread
  return spread
end

local function distance_sq(a, b)
  local dx = a.x - b.x
  local dy = a.y - b.y
  return dx * dx + dy * dy
end

local function is_hostile(origin, other)
  if not other or other == origin then
    return false
  end
  if origin.get_cease_fire(other) or origin.get_friend(other) then
    return false
  end
  return true
end

local function entry_max_range(entry, weapon_range)
  local distance = entry.distance or 100
  if entry.distance_mode == "meters" then
    return math.min(weapon_range, distance)
  end
  return weapon_range * (distance / 100)
end

local function entry_matches(entry, entity)
  if entry.kind == "all" then
    return true
  end
  if entry.kind == "type" then
    return entity.type == entry.entity_type
  end
  if entry.kind == "entity" then
    return entity.name == entry.name
  end
  return false
end

local function is_blocker(entity, forbidden)
  if not entity.valid then
    return false
  end
  if forbidden[entity.name] then
    return true
  end
  if IGNORE_FRIENDLY_TYPES[entity.type] then
    return false
  end
  return true
end

local function friendly_forces(force)
  local list = { force }
  for _, other in pairs(game.forces) do
    if other ~= force and force.get_friend(other) then
      list[#list + 1] = other
    end
  end
  return list
end

local function collect_blockers(surface, origin, radius, force, forbidden)
  local found = surface.find_entities_filtered({
    position = origin,
    radius = radius,
    force = friendly_forces(force),
  })
  local blockers = {}
  for i = 1, #found do
    local entity = found[i]
    if is_blocker(entity, forbidden) then
      local pos = entity.position
      local dx = pos.x - origin.x
      local dy = pos.y - origin.y
      if dx * dx + dy * dy >= FOOT_CLEARANCE_SQ then
        blockers[#blockers + 1] = entity.bounding_box
      end
    end
  end
  return blockers
end

local function cone_hits_box(origin, aim, box, spread)
  local dx = aim.x - origin.x
  local dy = aim.y - origin.y
  local len = math.sqrt(dx * dx + dy * dy)
  if len < 0.2 then
    return false
  end
  local steps = math.ceil(len / 0.5)
  if steps < 1 then
    steps = 1
  elseif steps > 64 then
    steps = 64
  end
  local start_dist = 0.9
  if len <= start_dist then
    start_dist = len * 0.5
  end
  local left = box.left_top.x
  local top = box.left_top.y
  local right = box.right_bottom.x
  local bottom = box.right_bottom.y
  for step = 0, steps do
    local along = len * step / steps
    if along >= start_dist then
      local t = along / len
      local x = origin.x + dx * t
      local y = origin.y + dy * t
      local pad = spread * t + 0.05
      if x >= left - pad and x <= right + pad and y >= top - pad and y <= bottom + pad then
        return true
      end
    end
  end
  return false
end

local function cone_blocked(origin, aim, spread, blockers)
  for i = 1, #blockers do
    if cone_hits_box(origin, aim, blockers[i], spread) then
      return true, i
    end
  end
  return false
end

local function pick_target(player, character, config, range, min_range, spread, debug)
  local origin = character.position
  local min_sq = min_range * min_range
  local forbidden = forbid_set(config)

  local found = character.surface.find_entities_filtered({
    position = origin,
    radius = range,
    type = HOSTILE_TYPES,
  })

  local hostiles = {}
  for i = 1, #found do
    local entity = found[i]
    if entity.valid
      and entity.health
      and entity.health > 0
      and not forbidden[entity.name]
      and is_hostile(player.force, entity.force)
    then
      local dist_sq = distance_sq(origin, entity.position)
      if dist_sq >= min_sq and dist_sq <= (range * range) then
        hostiles[#hostiles + 1] = {
          entity = entity,
          dist_sq = dist_sq,
        }
      end
    end
  end

  if debug then
    debug.hostiles = hostiles
  end
  if #hostiles == 0 then
    return nil
  end

  local blockers = nil
  if config.ignore_friendly then
    blockers = collect_blockers(character.surface, origin, range + spread + 1, player.force, forbidden)
  end
  if debug then
    debug.blockers = blockers or {}
    debug.hit_blockers = {}
  end

  local rule_ranges = {}
  for i = 1, #config.allow do
    local max_range = entry_max_range(config.allow[i], range)
    rule_ranges[i] = max_range * max_range
  end

  local best = nil
  for j = 1, #hostiles do
    local candidate = hostiles[j]
    local entity = candidate.entity
    for i = 1, #config.allow do
      if candidate.dist_sq <= rule_ranges[i] and entry_matches(config.allow[i], entity) then
        candidate.rank = i
        break
      end
    end
    local contender = candidate.rank
      and (not best or candidate.rank < best.rank or (candidate.rank == best.rank and candidate.dist_sq < best.dist_sq))
    if candidate.rank and blockers and (contender or debug) then
      local blocked, hit = cone_blocked(origin, entity.position, spread, blockers)
      candidate.blocked = blocked
      if blocked and debug then
        debug.hit_blockers[hit] = true
      end
    end
    if contender and not candidate.blocked then
      best = candidate
    end
  end
  return best and best.entity or nil
end

local DEBUG_COLORS = {
  range = { r = 0.6, g = 0.6, b = 0.6, a = 0.35 },
  rule = { r = 0.35, g = 0.55, b = 1, a = 0.25 },
  skipped = { r = 0.6, g = 0.6, b = 0.6, a = 0.6 },
  eligible = { r = 1, g = 0.85, b = 0.2, a = 0.8 },
  blocked = { r = 1, g = 0.2, b = 0.2, a = 0.9 },
  chosen = { r = 0.2, g = 1, b = 0.3, a = 1 },
  blocker = { r = 1, g = 0.5, b = 0.1, a = 0.5 },
  hit_blocker = { r = 1, g = 0.1, b = 0.1, a = 0.9 },
}

local function draw_cone(common, origin, aim, spread, color)
  local dx = aim.x - origin.x
  local dy = aim.y - origin.y
  local len = math.sqrt(dx * dx + dy * dy)
  if len < 0.2 then
    return
  end
  local px = -dy / len * spread
  local py = dx / len * spread
  local function line(to)
    common.from = origin
    common.to = to
    common.color = color
    common.width = 1
    rendering.draw_line(common)
  end
  line({ x = aim.x + px, y = aim.y + py })
  line({ x = aim.x - px, y = aim.y - py })
  line(aim)
end

local function draw_debug(player, character, config, range, min_range, spread, debug, target)
  local ttl = SCAN_INTERVAL + 1
  local function common()
    return { surface = character.surface, players = { player }, time_to_live = ttl, draw_on_ground = false }
  end
  local origin = character.position

  local c = common()
  c.target = character
  c.color = DEBUG_COLORS.range
  c.radius = range
  c.width = 2
  rendering.draw_circle(c)
  if min_range > 0 then
    c = common()
    c.target = character
    c.color = DEBUG_COLORS.range
    c.radius = min_range
    c.width = 1
    rendering.draw_circle(c)
  end
  for i = 1, #config.allow do
    local rule_range = entry_max_range(config.allow[i], range)
    if rule_range < range - 0.01 then
      c = common()
      c.target = character
      c.color = DEBUG_COLORS.rule
      c.radius = rule_range
      c.width = 1
      rendering.draw_circle(c)
    end
  end

  for i, box in pairs(debug.blockers or {}) do
    c = common()
    c.left_top = box.left_top
    c.right_bottom = box.right_bottom
    c.color = debug.hit_blockers[i] and DEBUG_COLORS.hit_blocker or DEBUG_COLORS.blocker
    c.width = debug.hit_blockers[i] and 3 or 1
    rendering.draw_rectangle(c)
  end

  for _, candidate in pairs(debug.hostiles or {}) do
    local entity = candidate.entity
    if entity.valid then
      local color = DEBUG_COLORS.skipped
      if entity == target then
        color = DEBUG_COLORS.chosen
      elseif candidate.blocked then
        color = DEBUG_COLORS.blocked
      elseif candidate.rank then
        color = DEBUG_COLORS.eligible
      end
      c = common()
      c.target = entity
      c.color = color
      c.radius = 0.6
      c.width = entity == target and 3 or 2
      rendering.draw_circle(c)
      c = common()
      c.target = { entity = entity, offset = { 0, -1 } }
      c.color = color
      c.text = candidate.rank and ("#" .. candidate.rank) or "-"
      c.alignment = "center"
      c.scale = 1
      rendering.draw_text(c)
      if candidate.rank and config.ignore_friendly then
        draw_cone(common(), origin, entity.position, spread, color)
      end
    end
  end

  if target and target.valid then
    c = common()
    c.from = character
    c.to = target
    c.color = DEBUG_COLORS.chosen
    c.width = 3
    rendering.draw_line(c)
  end
end
local function type_captions()
  local captions = {}
  for i = 1, #TYPE_OPTIONS do
    captions[i] = { "atmos-auto-fire." .. TYPE_OPTIONS[i].locale }
  end
  return captions
end

local function filter_id_for_entry(entry)
  if entry.kind == "all" then
    return "all"
  end
  if entry.kind == "entity" then
    return "entity"
  end
  return entry.entity_type or "unit"
end

local function make_small_button(parent, caption, tooltip, tags)
  local button = parent.add({
    type = "button",
    caption = caption,
    tooltip = tooltip,
    tags = tags,
  })
  button.style.width = 28
  button.style.height = 28
  button.style.padding = 0
  return button
end

local function add_distance_controls(row, list_name, index, entry)
  local mode = entry.distance_mode == "meters" and "meters" or "percent"
  local max_value = mode == "meters" and DIST_MAX_METERS or DIST_MAX_PERCENT
  local distance = clamp_distance(entry.distance, mode)

  local slider = row.add({
    type = "slider",
    minimum_value = DIST_MIN,
    maximum_value = max_value,
    value = distance,
    value_step = 1,
    discrete_slider = true,
    tags = { atmos_auto_fire = "distance-slider", list = list_name, index = index },
  })
  slider.style.minimal_width = 120
  slider.style.maximal_width = 160

  local text = row.add({
    type = "textfield",
    text = tostring(distance),
    numeric = true,
    allow_decimal = false,
    allow_negative = false,
    lose_focus_on_confirm = true,
    tags = { atmos_auto_fire = "distance-text", list = list_name, index = index },
  })
  text.style.width = 40

  local mode_switch = row.add({
    type = "switch",
    switch_state = mode == "percent" and "right" or "left",
    left_label_caption = { "atmos-auto-fire.unit-meters" },
    right_label_caption = { "atmos-auto-fire.unit-percent" },
    tooltip = { "atmos-auto-fire.unit-tooltip" },
    tags = { atmos_auto_fire = "distance-mode", list = list_name, index = index },
  })
  return mode_switch
end

local function add_allow_row(table_gui, index, entry, total)
  local filter_id = filter_id_for_entry(entry)
  local drop = table_gui.add({
    type = "drop-down",
    items = type_captions(),
    selected_index = TYPE_OPTION_INDEX[filter_id] or 1,
    tags = { atmos_auto_fire = "allow-filter", index = index },
  })
  drop.style.minimal_width = 120

  if filter_id == "entity" then
    local elem = table_gui.add({
      type = "choose-elem-button",
      elem_type = "entity",
      entity = entry.name,
      elem_filters = ENTITY_ELEM_FILTERS,
      tags = { atmos_auto_fire = "allow-entity", index = index },
    })
    elem.style.size = 28
  else
    local star = table_gui.add({
      type = "sprite-button",
      sprite = filter_id == "all" and "utility/check_mark_white" or "utility/add",
      style = "slot_button",
      enabled = false,
      tooltip = { "atmos-auto-fire." .. (TYPE_OPTIONS[TYPE_OPTION_INDEX[filter_id] or 1].locale) },
    })
    star.style.size = 28
  end

  add_distance_controls(table_gui, "allow", index, entry)

  if index > 1 then
    make_small_button(table_gui, { "atmos-auto-fire.move-up" }, { "atmos-auto-fire.move-up-tooltip" }, {
      atmos_auto_fire = "allow-up",
      index = index,
    })
  else
    table_gui.add({ type = "empty-widget" }).style.size = 28
  end
  if index < total then
    make_small_button(table_gui, { "atmos-auto-fire.move-down" }, { "atmos-auto-fire.move-down-tooltip" }, {
      atmos_auto_fire = "allow-down",
      index = index,
    })
  else
    table_gui.add({ type = "empty-widget" }).style.size = 28
  end
  make_small_button(table_gui, "X", { "atmos-auto-fire.remove-row" }, {
    atmos_auto_fire = "allow-remove",
    index = index,
  })
end

local function add_forbid_row(table_gui, index, entry)
  local elem = table_gui.add({
    type = "choose-elem-button",
    elem_type = "entity",
    entity = entry.name,
    elem_filters = ENTITY_ELEM_FILTERS,
    tags = { atmos_auto_fire = "forbid-entity", index = index },
  })
  elem.style.size = 28

  local label = table_gui.add({
    type = "label",
    caption = entry.name and { "entity-name." .. entry.name } or { "atmos-auto-fire.pick-entity" },
  })
  label.style.minimal_width = 160
  label.style.horizontally_stretchable = true

  make_small_button(table_gui, "X", { "atmos-auto-fire.remove-row" }, {
    atmos_auto_fire = "forbid-remove",
    index = index,
  })
end

local function rebuild_allow_list(player)
  local config = ensure_config(player.index)
  local frame = player.gui.screen[FRAME_NAME]
  if not frame then
    return
  end
  local holder = find_gui(frame, ALLOW_HOLDER)
  if not holder then
    return
  end
  holder.clear()
  local table_gui = holder.add({
    type = "table",
    column_count = 8,
    name = "atmos_auto_fire_allow_table",
  })
  for i = 1, #config.allow do
    add_allow_row(table_gui, i, config.allow[i], #config.allow)
  end
end

local function rebuild_forbid_list(player)
  local config = ensure_config(player.index)
  local frame = player.gui.screen[FRAME_NAME]
  if not frame then
    return
  end
  local holder = find_gui(frame, FORBID_HOLDER)
  if not holder then
    return
  end
  holder.clear()
  local table_gui = holder.add({
    type = "table",
    column_count = 3,
    name = "atmos_auto_fire_forbid_table",
  })
  for i = 1, #config.forbid do
    add_forbid_row(table_gui, i, config.forbid[i])
  end
end

local function move_allow(player, index, direction)
  local config = ensure_config(player.index)
  local destination = index + direction
  if destination < 1 or destination > #config.allow then
    return
  end
  config.allow[index], config.allow[destination] = config.allow[destination], config.allow[index]
  rebuild_allow_list(player)
end

local function set_allow_distance(player, index, value, source)
  local config = ensure_config(player.index)
  local entry = config.allow[index]
  if not entry then
    return
  end
  entry.distance = clamp_distance(value, entry.distance_mode)
  if gui_lock then
    return
  end
  local frame = player.gui.screen[FRAME_NAME]
  if not frame then
    return
  end
  gui_lock = true
  local holder = find_gui(frame, ALLOW_HOLDER)
  if holder then
    local children = holder.children[1] and holder.children[1].children or {}
    -- Each allow row uses 8 cells; locate slider/text for this index.
    local base = (index - 1) * 8
    local slider = children[base + 3]
    local text = children[base + 4]
    if source ~= "slider" and slider and slider.type == "slider" then
      slider.slider_value = entry.distance
    end
    if source ~= "text" and text and text.type == "textfield" then
      text.text = tostring(entry.distance)
    end
  end
  gui_lock = false
end

local function set_allow_mode(player, index, mode)
  local config = ensure_config(player.index)
  local entry = config.allow[index]
  if not entry then
    return
  end
  local old_mode = entry.distance_mode
  entry.distance_mode = mode == "meters" and "meters" or "percent"
  if old_mode ~= entry.distance_mode then
    -- Keep the numeric value, just reclamp to the new scale.
    entry.distance = clamp_distance(entry.distance, entry.distance_mode)
  end
  rebuild_allow_list(player)
end

local function set_allow_filter(player, index, selected_index)
  local config = ensure_config(player.index)
  local entry = config.allow[index]
  local option = TYPE_OPTIONS[selected_index]
  if not entry or not option then
    return
  end
  local distance = entry.distance or 100
  local mode = entry.distance_mode == "meters" and "meters" or "percent"
  if option.id == "all" then
    config.allow[index] = rule_all(distance, mode)
  elseif option.id == "entity" then
    config.allow[index] = rule_entity(entry.name or "small-biter", distance, mode)
  else
    config.allow[index] = rule_type(option.id, distance, mode)
  end
  rebuild_allow_list(player)
end

local function build_window(player)
  local existing = player.gui.screen[FRAME_NAME]
  if existing then
    existing.destroy()
  end
  local config = ensure_config(player.index)
  local frame = player.gui.screen.add({
    type = "frame",
    name = FRAME_NAME,
    direction = "vertical",
  })
  frame.auto_center = true

  local titlebar = frame.add({ type = "flow", direction = "horizontal" })
  titlebar.drag_target = frame
  titlebar.add({
    type = "label",
    caption = { "atmos-auto-fire.window-title" },
    style = "frame_title",
    ignored_by_interaction = true,
  })
  local drag = titlebar.add({ type = "empty-widget", style = "draggable_space_header" })
  drag.style.height = 24
  drag.style.horizontally_stretchable = true
  drag.drag_target = frame
  titlebar.add({
    type = "sprite-button",
    name = "atmos_auto_fire_close",
    sprite = "utility/close",
    hovered_sprite = "utility/close_black",
    clicked_sprite = "utility/close_black",
    style = "frame_action_button",
    tooltip = { "atmos-auto-fire.close" },
    tags = { atmos_auto_fire = "close" },
  })

  local inner = frame.add({
    type = "frame",
    style = "inside_shallow_frame_with_padding",
    direction = "vertical",
  })
  inner.style.minimal_width = 560

  inner.add({
    type = "label",
    name = STATUS_NAME,
    caption = config.enabled and { "atmos-auto-fire.status-on" } or { "atmos-auto-fire.status-off" },
  })

  inner.add({
    type = "checkbox",
    name = IGNORE_CHECK,
    caption = { "atmos-auto-fire.ignore-friendly" },
    state = config.ignore_friendly,
  })

  inner.add({
    type = "checkbox",
    name = DEBUG_CHECK,
    caption = { "atmos-auto-fire.debug" },
    tooltip = { "atmos-auto-fire.debug-tooltip" },
    state = config.debug,
  })

  inner.add({ type = "label", caption = { "atmos-auto-fire.allow-title" }, style = "caption_label" })
  local allow_hint = inner.add({ type = "label", caption = { "atmos-auto-fire.allow-hint" } })
  allow_hint.style.maximal_width = 540

  local allow_scroll = inner.add({
    type = "scroll-pane",
    name = "atmos_auto_fire_allow_scroll",
    direction = "vertical",
  })
  allow_scroll.style.maximal_height = 280
  allow_scroll.style.minimal_height = 120
  local allow_holder = allow_scroll.add({
    type = "flow",
    name = ALLOW_HOLDER,
    direction = "vertical",
  })

  local allow_buttons = inner.add({ type = "flow", direction = "horizontal" })
  allow_buttons.add({
    type = "button",
    caption = { "atmos-auto-fire.add-allow" },
    tags = { atmos_auto_fire = "allow-add" },
  })

  inner.add({ type = "label", caption = { "atmos-auto-fire.forbid-title" }, style = "caption_label" })
  local forbid_hint = inner.add({ type = "label", caption = { "atmos-auto-fire.forbid-hint" } })
  forbid_hint.style.maximal_width = 540

  local forbid_scroll = inner.add({
    type = "scroll-pane",
    name = "atmos_auto_fire_forbid_scroll",
    direction = "vertical",
  })
  forbid_scroll.style.maximal_height = 140
  local forbid_holder = forbid_scroll.add({
    type = "flow",
    name = FORBID_HOLDER,
    direction = "vertical",
  })

  local forbid_buttons = inner.add({ type = "flow", direction = "horizontal" })
  forbid_buttons.add({
    type = "button",
    caption = { "atmos-auto-fire.add-forbid" },
    tags = { atmos_auto_fire = "forbid-add" },
  })

  rebuild_allow_list(player)
  rebuild_forbid_list(player)
  player.opened = frame
end

local function close_window(player)
  local frame = player.gui.screen[FRAME_NAME]
  if frame then
    frame.destroy()
  end
end

local function toggle_window(player)
  if player.gui.screen[FRAME_NAME] then
    close_window(player)
  else
    build_window(player)
  end
end

local function ensure_top_button(player)
  if player.gui.top[BUTTON_NAME] then
    return
  end
  local button = player.gui.top.add({
    type = "sprite-button",
    name = BUTTON_NAME,
    sprite = "item/shotgun",
    style = "slot_button",
    tooltip = { "atmos-auto-fire.open-settings" },
    tags = { atmos_auto_fire = "settings" },
  })
  button.toggled = ensure_config(player.index).enabled
end

local function setup_player(player)
  local config = ensure_config(player.index)
  ensure_runtime(player.index)
  ensure_top_button(player)
  sync_visuals(player, config)
end

local function has_ammo(context)
  local ammo = context.ammo
  return ammo and ammo.valid_for_read and ammo.is_ammo and (ammo.ammo or 0) > 0
end

local function release_trigger(character, runtime)
  if runtime.firing and character and character.valid then
    character.shooting_state = {
      state = defines.shooting.not_shooting,
      position = character.position,
    }
  end
  runtime.firing = false
  runtime.target = nil
end

local function disarm(player, runtime)
  release_trigger(player.character, runtime)
end

local function target_in_reach(player, context, target)
  if not (target and target.valid and target.health and target.health > 0) then
    return false
  end
  local character = context.character
  if target.surface_index ~= character.surface_index then
    return false
  end
  local range, min_range = weapon_stats(player.force, context.gun, context.ammo)
  local dist_sq = distance_sq(character.position, target.position)
  return dist_sq >= min_range * min_range and dist_sq <= range * range
end

local function scan(player)
  local config = ensure_config(player.index)
  local runtime = ensure_runtime(player.index)
  if not config.enabled then
    disarm(player, runtime)
    return
  end
  local context = combat_context(player)
  if not context or not has_ammo(context) then
    disarm(player, runtime)
    return
  end
  local range, min_range = weapon_stats(player.force, context.gun, context.ammo)
  local spread = cone_spread(context.ammo.name)
  local trace = config.debug and {} or nil
  runtime.target = pick_target(player, context.character, config, range, min_range, spread, trace)
  if trace then
    draw_debug(player, context.character, config, range, min_range, spread, trace, runtime.target)
  end
  if not runtime.target then
    release_trigger(context.character, runtime)
  end
end

-- The engine rewrites shooting_state from player input every tick, so it must be held each tick.
local function hold_trigger(player)
  local runtime = ensure_runtime(player.index)
  local target = runtime.target
  if not target then
    return
  end
  local context = combat_context(player)
  if not context or not has_ammo(context) or not target_in_reach(player, context, target) then
    disarm(player, runtime)
    return
  end
  context.character.shooting_state = {
    state = defines.shooting.shooting_selected,
    position = target.position,
  }
  runtime.firing = true
end

local function toggle_enabled(player)
  local runtime = ensure_runtime(player.index)
  if runtime.last_toggle_tick == game.tick then
    return
  end
  runtime.last_toggle_tick = game.tick
  local config = ensure_config(player.index)
  config.enabled = not config.enabled
  if not config.enabled then
    disarm(player, runtime, game.tick)
  end
  sync_visuals(player, config)
  player.create_local_flying_text({
    text = config.enabled and { "atmos-auto-fire.status-on" } or { "atmos-auto-fire.status-off" },
    position = player.position,
    color = config.enabled and { r = 0.55, g = 1, b = 0.55 } or { r = 1, g = 0.45, b = 0.4 },
  })
end

local function boot()
  storage.player_configs = storage.player_configs or {}
  storage.runtime = storage.runtime or {}
  for _, player in pairs(game.players) do
    setup_player(player)
  end
end

script.on_init(boot)
script.on_configuration_changed(boot)

script.on_event(defines.events.on_player_created, function(event)
  local player = game.get_player(event.player_index)
  if player then
    setup_player(player)
  end
end)

script.on_event(defines.events.on_player_joined_game, function(event)
  local player = game.get_player(event.player_index)
  if player then
    setup_player(player)
  end
end)

script.on_event(defines.events.on_player_removed, function(event)
  local runtime = storage.runtime and storage.runtime[event.player_index]
  if runtime then
    storage.runtime[event.player_index] = nil
  end
  if storage.player_configs then
    storage.player_configs[event.player_index] = nil
  end
end)

script.on_event(defines.events.on_player_left_game, function(event)
  local player = game.get_player(event.player_index)
  local runtime = storage.runtime and storage.runtime[event.player_index]
  if player and runtime then
    disarm(player, runtime, game.tick)
  end
end)

script.on_event(defines.events.on_player_died, function(event)
  local player = game.get_player(event.player_index)
  local runtime = storage.runtime and storage.runtime[event.player_index]
  if player and runtime then
    disarm(player, runtime, game.tick)
  end
end)

script.on_event(defines.events.on_tick, function(event)
  local configs = storage.player_configs
  if not configs then
    return
  end
  local rescan = event.tick % SCAN_INTERVAL == 0
  for _, player in pairs(game.connected_players) do
    if configs[player.index] then
      if rescan then
        scan(player)
      end
      hold_trigger(player)
    end
  end
end)

script.on_event(SHORTCUT_NAME, function(event)
  local player = game.get_player(event.player_index)
  if player then
    toggle_enabled(player)
  end
end)

script.on_event(defines.events.on_lua_shortcut, function(event)
  if event.prototype_name ~= SHORTCUT_NAME then
    return
  end
  local player = game.get_player(event.player_index)
  if player then
    toggle_enabled(player)
  end
end)

script.on_event(defines.events.on_gui_click, function(event)
  local element = event.element
  if not (element and element.valid) then
    return
  end
  local player = game.get_player(event.player_index)
  if not player then
    return
  end
  local tags = element.tags
  if element.name == BUTTON_NAME or (tags and tags.atmos_auto_fire == "settings") then
    toggle_window(player)
    sync_visuals(player, ensure_config(player.index))
    return
  end
  if element.name == "atmos_auto_fire_close" or (tags and tags.atmos_auto_fire == "close") then
    close_window(player)
    return
  end
  if not tags or not tags.atmos_auto_fire then
    return
  end

  local config = ensure_config(player.index)
  local action = tags.atmos_auto_fire
  if action == "allow-add" then
    config.allow[#config.allow + 1] = rule_all(100, "percent")
    rebuild_allow_list(player)
  elseif action == "forbid-add" then
    config.forbid[#config.forbid + 1] = rule_forbid("gun-turret")
    rebuild_forbid_list(player)
  elseif action == "allow-up" then
    move_allow(player, tags.index, -1)
  elseif action == "allow-down" then
    move_allow(player, tags.index, 1)
  elseif action == "allow-remove" then
    if #config.allow > 1 then
      table.remove(config.allow, tags.index)
      rebuild_allow_list(player)
    end
  elseif action == "forbid-remove" then
    table.remove(config.forbid, tags.index)
    rebuild_forbid_list(player)
  end
end)

script.on_event(defines.events.on_gui_selection_state_changed, function(event)
  local element = event.element
  if not (element and element.valid and element.tags and element.tags.atmos_auto_fire == "allow-filter") then
    return
  end
  local player = game.get_player(event.player_index)
  if player then
    set_allow_filter(player, element.tags.index, element.selected_index)
  end
end)

script.on_event(defines.events.on_gui_elem_changed, function(event)
  local element = event.element
  if not (element and element.valid and element.tags and element.tags.atmos_auto_fire) then
    return
  end
  local player = game.get_player(event.player_index)
  if not player then
    return
  end
  local config = ensure_config(player.index)
  local action = element.tags.atmos_auto_fire
  local index = element.tags.index
  if action == "allow-entity" then
    local entry = config.allow[index]
    if entry and element.elem_value then
      entry.kind = "entity"
      entry.name = element.elem_value
      entry.entity_type = nil
    end
  elseif action == "forbid-entity" then
    local entry = config.forbid[index]
    if entry then
      if element.elem_value then
        entry.name = element.elem_value
      end
      rebuild_forbid_list(player)
    end
  end
end)

script.on_event(defines.events.on_gui_value_changed, function(event)
  local element = event.element
  if not (element and element.valid and element.tags and element.tags.atmos_auto_fire == "distance-slider") or gui_lock then
    return
  end
  local player = game.get_player(event.player_index)
  if player then
    set_allow_distance(player, element.tags.index, element.slider_value, "slider")
  end
end)

script.on_event(defines.events.on_gui_text_changed, function(event)
  local element = event.element
  if not (element and element.valid and element.tags and element.tags.atmos_auto_fire == "distance-text") or gui_lock then
    return
  end
  if element.text == "" then
    return
  end
  local player = game.get_player(event.player_index)
  if player then
    set_allow_distance(player, element.tags.index, element.text, "text")
  end
end)

script.on_event(defines.events.on_gui_switch_state_changed, function(event)
  local element = event.element
  if not (element and element.valid and element.tags and element.tags.atmos_auto_fire == "distance-mode") then
    return
  end
  local player = game.get_player(event.player_index)
  if not player then
    return
  end
  local mode = element.switch_state == "right" and "percent" or "meters"
  set_allow_mode(player, element.tags.index, mode)
end)

script.on_event(defines.events.on_gui_checked_state_changed, function(event)
  local element = event.element
  if not (element and element.valid and (element.name == IGNORE_CHECK or element.name == DEBUG_CHECK)) then
    return
  end
  local player = game.get_player(event.player_index)
  if not player then
    return
  end
  local config = ensure_config(player.index)
  if element.name == IGNORE_CHECK then
    config.ignore_friendly = element.state
  else
    config.debug = element.state
  end
end)

script.on_event(defines.events.on_gui_closed, function(event)
  local element = event.element
  if element and element.valid and element.name == FRAME_NAME then
    element.destroy()
  end
end)

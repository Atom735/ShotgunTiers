local util = require("util")

local PANEL_NAME = "atmos-enemy-range-panel"
local UPDATE_NTH_TICK = 20
local MOVE_EPS2 = 0.25 -- squared tiles; skip rescans for tiny movement

local CATEGORY_BY_TYPE = {
  ["turret"] = "worms",
  ["ammo-turret"] = "ammo",
  ["electric-turret"] = "electric",
  ["fluid-turret"] = "fluid",
  ["artillery-turret"] = "artillery",
}

local SHOW_SETTING = {
  worms = "atmos-enemy-range-show-worms",
  ammo = "atmos-enemy-range-show-ammo-turrets",
  electric = "atmos-enemy-range-show-electric-turrets",
  fluid = "atmos-enemy-range-show-fluid-turrets",
  artillery = "atmos-enemy-range-show-artillery",
}

local COLOR_SETTING = {
  worms = "atmos-enemy-range-color-worms",
  ammo = "atmos-enemy-range-color-ammo",
  electric = "atmos-enemy-range-color-electric",
  fluid = "atmos-enemy-range-color-fluid",
  artillery = "atmos-enemy-range-color-artillery",
}

local CATEGORY_ORDER = { "worms", "ammo", "electric", "fluid", "artillery" }

local ENTITY_TYPES = {
  "turret",
  "ammo-turret",
  "electric-turret",
  "fluid-turret",
  "artillery-turret",
}

local STYLES = { "filled", "outline", "filled-outline" }

-- Prototype name -> attack range cache (immutable for a game load).
local range_cache = {}

local function player_state(player_index)
  local players = storage.players
  local state = players[player_index]
  if state then
    return state
  end
  state = {
    enabled = false,
    overlays = {},
    panel_open = false,
    style = nil,
    categories = nil,
    render_cache = nil,
    last_x = nil,
    last_y = nil,
    last_surface_index = nil,
    force_version = 0,
    enemy_forces = nil,
  }
  players[player_index] = state
  return state
end

local function clear_overlays(state)
  for _, entry in pairs(state.overlays) do
    if entry.fill and entry.fill.valid then
      entry.fill.destroy()
    end
    if entry.outline and entry.outline.valid then
      entry.outline.destroy()
    end
  end
  state.overlays = {}
end

local function ensure_category_overrides(player, state)
  if state.categories then
    return
  end
  local categories = {}
  local settings = player.mod_settings
  for category, setting_name in pairs(SHOW_SETTING) do
    categories[category] = settings[setting_name].value
  end
  state.categories = categories
end

local function style_flags(style_name)
  if style_name == "filled" then
    return true, false
  end
  if style_name == "filled-outline" then
    return true, true
  end
  return false, true
end

local function rebuild_render_cache(player, state)
  local settings = player.mod_settings
  local style = state.style or settings["atmos-enemy-range-style"].value
  local want_fill, want_outline = style_flags(style)
  local colors = {}
  for category, setting_name in pairs(COLOR_SETTING) do
    colors[category] = util.premul_color(settings[setting_name].value)
  end
  local outline_colors = {}
  for category, color in pairs(colors) do
    outline_colors[category] = {
      r = color.r,
      g = color.g,
      b = color.b,
      a = math.min(1, (color.a or 0.35) + 0.35),
    }
  end

  local types = {}
  ensure_category_overrides(player, state)
  for i = 1, #ENTITY_TYPES do
    local entity_type = ENTITY_TYPES[i]
    if state.categories[CATEGORY_BY_TYPE[entity_type]] then
      types[#types + 1] = entity_type
    end
  end

  state.render_cache = {
    style = style,
    want_fill = want_fill,
    want_outline = want_outline,
    width = settings["atmos-enemy-range-outline-width"].value,
    radius = settings["atmos-enemy-range-search-radius"].value,
    colors = colors,
    outline_colors = outline_colors,
    types = types,
  }
end

local function get_render_cache(player, state)
  if not state.render_cache then
    rebuild_render_cache(player, state)
  end
  return state.render_cache
end

local function get_attack_range(entity)
  local name = entity.name
  local cached = range_cache[name]
  if cached ~= nil then
    return cached
  end

  local proto = entity.prototype
  local range = 0
  if proto then
    if entity.type == "artillery-turret" then
      local automatic = proto.automatic_range
      if type(automatic) == "number" then
        range = automatic
      end
    end
    if range <= 0 then
      local attack = proto.attack_parameters
      if attack and type(attack.range) == "number" then
        range = attack.range
      else
        range = proto.turret_range or 0
      end
    end
  end

  range_cache[name] = range
  return range
end

local function enemy_forces_for(player, state)
  -- Forces rarely change; rebuild when missing.
  local cached = state.enemy_forces
  if cached then
    return cached
  end
  local result = {}
  local player_force = player.force
  for _, force in pairs(game.forces) do
    if player_force.is_enemy(force) then
      result[#result + 1] = force
    end
  end
  state.enemy_forces = result
  return result
end

local function destroy_entry(entry)
  if entry.fill and entry.fill.valid then
    entry.fill.destroy()
  end
  if entry.outline and entry.outline.valid then
    entry.outline.destroy()
  end
end

local function create_overlays(player, entity, category, cache)
  local range = get_attack_range(entity)
  if range <= 0 then
    return nil
  end

  local entry = { category = category, range = range }
  local surface = entity.surface
  local players = { player.index }

  if cache.want_fill then
    entry.fill = rendering.draw_circle({
      color = cache.colors[category],
      radius = range,
      filled = true,
      target = entity,
      surface = surface,
      players = players,
      draw_on_ground = true,
    })
  end

  if cache.want_outline then
    entry.outline = rendering.draw_circle({
      color = cache.outline_colors[category],
      radius = range,
      filled = false,
      width = cache.width,
      target = entity,
      surface = surface,
      players = players,
      draw_on_ground = true,
    })
  end

  return entry
end

local function refresh_player(player, force_rescan)
  local state = player_state(player.index)
  if not state.enabled or not player.connected then
    clear_overlays(state)
    return
  end

  local character = player.character
  local position = player.position
  local surface = player.surface
  if character and character.valid then
    position = character.position
    surface = character.surface
  end

  local cache = get_render_cache(player, state)
  if #cache.types == 0 then
    clear_overlays(state)
    return
  end

  local forces = enemy_forces_for(player, state)
  if #forces == 0 then
    clear_overlays(state)
    return
  end

  local x, y = position.x, position.y
  local surface_index = surface.index
  if not force_rescan
    and state.last_x
    and state.last_surface_index == surface_index
  then
    local dx = x - state.last_x
    local dy = y - state.last_y
    if (dx * dx + dy * dy) < MOVE_EPS2 and next(state.overlays) ~= nil then
      -- Still prune destroyed entities cheaply.
      for unit, entry in pairs(state.overlays) do
        local fill_ok = (not entry.fill) or entry.fill.valid
        local outline_ok = (not entry.outline) or entry.outline.valid
        if not (fill_ok and outline_ok) then
          destroy_entry(entry)
          state.overlays[unit] = nil
        end
      end
      return
    end
  end

  state.last_x = x
  state.last_y = y
  state.last_surface_index = surface_index

  local seen = {}
  local entities = surface.find_entities_filtered({
    position = position,
    radius = cache.radius,
    type = cache.types,
    force = forces,
  })

  local overlays = state.overlays
  for i = 1, #entities do
    local entity = entities[i]
    if entity.valid then
      local category = CATEGORY_BY_TYPE[entity.type]
      local unit = entity.unit_number
      if category and unit and state.categories[category] then
        seen[unit] = true
        local entry = overlays[unit]
        if not entry then
          entry = create_overlays(player, entity, category, cache)
          if entry then
            overlays[unit] = entry
          end
        end
      end
    end
  end

  for unit, entry in pairs(overlays) do
    if not seen[unit] then
      destroy_entry(entry)
      overlays[unit] = nil
    end
  end
end

local function any_enabled()
  for _, state in pairs(storage.players) do
    if state.enabled then
      return true
    end
  end
  return false
end

local function on_tick()
  for _, player in pairs(game.connected_players) do
    local state = storage.players[player.index]
    if state and state.enabled then
      refresh_player(player, false)
    end
  end
end

local function sync_tick_handler()
  if any_enabled() then
    script.on_nth_tick(UPDATE_NTH_TICK, on_tick)
  else
    script.on_nth_tick(UPDATE_NTH_TICK, nil)
  end
end

local function invalidate_visuals(player, state)
  state.render_cache = nil
  state.enemy_forces = nil
  state.last_x = nil
  clear_overlays(state)
end

local function sync_panel_enabled(player, enabled)
  local panel = player.gui.screen[PANEL_NAME]
  if panel and panel.enabled_box and panel.enabled_box.valid then
    panel.enabled_box.state = enabled
  end
end

local function set_enabled(player, enabled)
  local state = player_state(player.index)
  state.enabled = not not enabled
  ensure_category_overrides(player, state)
  if not state.style then
    state.style = player.mod_settings["atmos-enemy-range-style"].value
  end
  player.set_shortcut_toggled("atmos-enemy-range-toggle", state.enabled)
  if not state.enabled then
    invalidate_visuals(player, state)
  else
    state.render_cache = nil
    refresh_player(player, true)
  end
  sync_tick_handler()
  sync_panel_enabled(player, state.enabled)
end

local function toggle_enabled(player)
  set_enabled(player, not player_state(player.index).enabled)
end

local function destroy_panel(player)
  local panel = player.gui.screen[PANEL_NAME]
  if panel then
    panel.destroy()
  end
  player_state(player.index).panel_open = false
end

local function build_panel(player)
  destroy_panel(player)
  local state = player_state(player.index)
  ensure_category_overrides(player, state)
  if not state.style then
    state.style = player.mod_settings["atmos-enemy-range-style"].value
  end
  state.panel_open = true

  local frame = player.gui.screen.add({
    type = "frame",
    name = PANEL_NAME,
    direction = "vertical",
    caption = { "atmos-enemy-range.panel-title" },
  })
  frame.auto_center = true

  local enabled_box = frame.add({
    type = "checkbox",
    name = "enabled_box",
    caption = { "atmos-enemy-range.enable" },
    state = state.enabled,
  })
  enabled_box.tags = { aerv = "enabled" }

  frame.add({
    type = "label",
    caption = { "atmos-enemy-range.style-label" },
  })

  local style_box = frame.add({
    type = "drop-down",
    name = "style_box",
    items = {
      { "string-mod-setting.atmos-enemy-range-style-filled" },
      { "string-mod-setting.atmos-enemy-range-style-outline" },
      { "string-mod-setting.atmos-enemy-range-style-filled-outline" },
    },
  })
  local selected = 2
  for i = 1, #STYLES do
    if STYLES[i] == state.style then
      selected = i
      break
    end
  end
  style_box.selected_index = selected
  style_box.tags = { aerv = "style" }

  frame.add({ type = "line" })
  frame.add({
    type = "label",
    caption = { "atmos-enemy-range.categories-label" },
  })

  local captions = {
    worms = { "atmos-enemy-range.cat-worms" },
    ammo = { "atmos-enemy-range.cat-ammo" },
    electric = { "atmos-enemy-range.cat-electric" },
    fluid = { "atmos-enemy-range.cat-fluid" },
    artillery = { "atmos-enemy-range.cat-artillery" },
  }

  for i = 1, #CATEGORY_ORDER do
    local key = CATEGORY_ORDER[i]
    local box = frame.add({
      type = "checkbox",
      name = "cat_" .. key,
      caption = captions[key],
      state = not not state.categories[key],
    })
    box.tags = { aerv = "category", category = key }
  end

  frame.add({ type = "line" })
  frame.add({
    type = "label",
    caption = { "atmos-enemy-range.hint-colors" },
  })

  local buttons = frame.add({ type = "flow", direction = "horizontal" })
  buttons.add({
    type = "button",
    name = "aerv_close",
    caption = { "atmos-enemy-range.close" },
    tags = { aerv = "close" },
  })
  buttons.add({
    type = "button",
    name = "aerv_refresh",
    caption = { "atmos-enemy-range.refresh" },
    tags = { aerv = "refresh" },
  })
end

local function toggle_panel(player)
  local state = player_state(player.index)
  if state.panel_open and player.gui.screen[PANEL_NAME] then
    destroy_panel(player)
  else
    build_panel(player)
  end
end

local function restyle_player(player)
  local state = player_state(player.index)
  invalidate_visuals(player, state)
  if state.enabled then
    refresh_player(player, true)
  end
end

script.on_init(function()
  storage.players = {}
end)

script.on_load(function()
  storage.players = storage.players or {}
  sync_tick_handler()
end)

script.on_configuration_changed(function()
  storage.players = storage.players or {}
  range_cache = {}
  for _, player in pairs(game.players) do
    local state = player_state(player.index)
    state.enemy_forces = nil
    state.render_cache = nil
    player.set_shortcut_toggled("atmos-enemy-range-toggle", state.enabled)
    if state.enabled then
      refresh_player(player, true)
    else
      clear_overlays(state)
    end
  end
  sync_tick_handler()
end)

script.on_event("atmos-enemy-range-toggle", function(event)
  local player = game.get_player(event.player_index)
  if player then
    toggle_enabled(player)
  end
end)

script.on_event("atmos-enemy-range-panel", function(event)
  local player = game.get_player(event.player_index)
  if player then
    toggle_panel(player)
  end
end)

script.on_event(defines.events.on_lua_shortcut, function(event)
  if event.prototype_name ~= "atmos-enemy-range-toggle" then
    return
  end
  local player = game.get_player(event.player_index)
  if player then
    toggle_enabled(player)
  end
end)

script.on_event(defines.events.on_gui_checked_state_changed, function(event)
  local element = event.element
  if not (element and element.valid and element.tags and element.tags.aerv) then
    return
  end
  local player = game.get_player(event.player_index)
  if not player then
    return
  end

  local state = player_state(player.index)
  if element.tags.aerv == "enabled" then
    set_enabled(player, element.state)
  elseif element.tags.aerv == "category" and element.tags.category then
    ensure_category_overrides(player, state)
    state.categories[element.tags.category] = element.state
    restyle_player(player)
  end
end)

script.on_event(defines.events.on_gui_selection_state_changed, function(event)
  local element = event.element
  if not (element and element.valid and element.tags and element.tags.aerv == "style") then
    return
  end
  local player = game.get_player(event.player_index)
  if not player then
    return
  end
  local state = player_state(player.index)
  state.style = STYLES[element.selected_index] or "outline"
  restyle_player(player)
end)

script.on_event(defines.events.on_gui_click, function(event)
  local element = event.element
  if not (element and element.valid and element.tags and element.tags.aerv) then
    return
  end
  local player = game.get_player(event.player_index)
  if not player then
    return
  end
  if element.tags.aerv == "close" then
    destroy_panel(player)
  elseif element.tags.aerv == "refresh" then
    local state = player_state(player.index)
    state.enemy_forces = nil
    refresh_player(player, true)
  end
end)

script.on_event(defines.events.on_runtime_mod_setting_changed, function(event)
  if not event.player_index then
    return
  end
  if not string.find(event.setting, "atmos-enemy-range-", 1, true) then
    return
  end
  local player = game.get_player(event.player_index)
  if not player then
    return
  end

  local state = player_state(player.index)
  if event.setting == "atmos-enemy-range-style" then
    state.style = player.mod_settings["atmos-enemy-range-style"].value
  else
    for category, setting_name in pairs(SHOW_SETTING) do
      if event.setting == setting_name then
        ensure_category_overrides(player, state)
        state.categories[category] = player.mod_settings[setting_name].value
        break
      end
    end
  end

  restyle_player(player)
  if state.panel_open then
    build_panel(player)
  end
end)

script.on_event(defines.events.on_forces_merged, function()
  for _, state in pairs(storage.players) do
    state.enemy_forces = nil
  end
end)

script.on_event(defines.events.on_player_removed, function(event)
  local state = storage.players[event.player_index]
  if state then
    clear_overlays(state)
    storage.players[event.player_index] = nil
    sync_tick_handler()
  end
end)

script.on_event(defines.events.on_player_left_game, function(event)
  local state = storage.players[event.player_index]
  if state then
    clear_overlays(state)
  end
end)

script.on_event(defines.events.on_player_joined_game, function(event)
  local player = game.get_player(event.player_index)
  if not player then
    return
  end
  local state = player_state(player.index)
  state.enemy_forces = nil
  player.set_shortcut_toggled("atmos-enemy-range-toggle", state.enabled)
  if state.enabled then
    refresh_player(player, true)
    sync_tick_handler()
  end
end)

script.on_event(defines.events.on_player_changed_surface, function(event)
  local player = game.get_player(event.player_index)
  if not player then
    return
  end
  local state = player_state(player.index)
  clear_overlays(state)
  state.last_x = nil
  if state.enabled then
    refresh_player(player, true)
  end
end)

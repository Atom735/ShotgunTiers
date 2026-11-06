local PANEL_NAME = "atmos-auto-heal-panel"
local CHECK_NTH_TICK = 15
local DEFAULT_COOLDOWN = 30

-- name -> { heal = number, cooldown = ticks }; rebuilt on every load.
local heal_items = nil
local heal_order = nil

local function find_heal_amount(node, visited)
  if type(node) ~= "table" or visited[node] then
    return 0
  end
  visited[node] = true

  local total = 0
  local damage = node.damage
  if type(damage) == "table" and type(damage.amount) == "number" and damage.amount < 0 then
    total = total - damage.amount
  end
  for _, value in pairs(node) do
    if type(value) == "table" then
      total = total + find_heal_amount(value, visited)
    end
  end
  return total
end

local function scan_heal_items()
  heal_items = {}
  heal_order = {}
  for name, proto in pairs(prototypes.get_item_filtered({ { filter = "type", type = "capsule" } })) do
    local ok, action = pcall(function()
      return proto.capsule_action
    end)
    if ok and action and action.type == "use-on-self" and action.attack_parameters then
      local params = action.attack_parameters
      local heal = find_heal_amount(params, {})
      if heal > 0 then
        heal_items[name] = {
          heal = heal,
          cooldown = math.max(1, math.floor(params.cooldown or DEFAULT_COOLDOWN)),
        }
        heal_order[#heal_order + 1] = name
      end
    end
  end
  table.sort(heal_order, function(a, b)
    local ha, hb = heal_items[a].heal, heal_items[b].heal
    if ha ~= hb then
      return ha < hb
    end
    return a < b
  end)
end

local function get_heal_items()
  if not heal_items then
    scan_heal_items()
  end
  return heal_items, heal_order
end

local function player_state(player_index)
  local state = storage.players[player_index]
  if not state then
    state = {
      enabled = true,
      priority = {},
      disabled = {},
      next_tick = 0,
      panel_open = false,
    }
    storage.players[player_index] = state
  end
  return state
end

-- Keep stored priority in sync with currently loaded heal items.
local function sync_priority(state)
  local items, order = get_heal_items()
  local seen = {}
  local merged = {}
  for i = 1, #state.priority do
    local name = state.priority[i]
    if items[name] and not seen[name] then
      seen[name] = true
      merged[#merged + 1] = name
    end
  end
  for i = 1, #order do
    local name = order[i]
    if not seen[name] then
      merged[#merged + 1] = name
    end
  end
  state.priority = merged
  for name in pairs(state.disabled) do
    if not items[name] then
      state.disabled[name] = nil
    end
  end
end

local function try_heal(player, state, tick)
  if tick < state.next_tick then
    return
  end

  local character = player.character
  if not (character and character.valid) then
    return
  end

  local max_health = character.max_health
  local health = character.health
  if not max_health or max_health <= 0 or health >= max_health then
    return
  end

  local settings = player.mod_settings
  local threshold = settings["atmos-auto-heal-threshold"].value / 100
  if health / max_health >= threshold then
    return
  end

  local inventory = character.get_main_inventory()
  if not inventory then
    return
  end

  local items = get_heal_items()
  local missing = max_health - health
  local avoid_overheal = settings["atmos-auto-heal-avoid-overheal"].value
  local fallback = nil

  for i = 1, #state.priority do
    local name = state.priority[i]
    local info = items[name]
    if info and not state.disabled[name] and inventory.get_item_count(name) > 0 then
      if not avoid_overheal or info.heal <= missing then
        fallback = name
        break
      end
      fallback = fallback or name
    end
  end

  if not fallback then
    return
  end

  if inventory.remove({ name = fallback, count = 1 }) < 1 then
    return
  end

  local info = items[fallback]
  character.health = math.min(max_health, health + info.heal)
  state.next_tick = tick + info.cooldown
end

local function any_enabled()
  for _, state in pairs(storage.players) do
    if state.enabled then
      return true
    end
  end
  return false
end

local function on_check(event)
  for _, player in pairs(game.connected_players) do
    local state = storage.players[player.index]
    if state and state.enabled then
      try_heal(player, state, event.tick)
    end
  end
end

local function sync_tick_handler()
  script.on_nth_tick(CHECK_NTH_TICK, any_enabled() and on_check or nil)
end

local function destroy_panel(player)
  local panel = player.gui.screen[PANEL_NAME]
  if panel then
    panel.destroy()
  end
  player_state(player.index).panel_open = false
end

local function build_panel(player)
  local old = player.gui.screen[PANEL_NAME]
  local location = old and old.location
  if old then
    old.destroy()
  end

  local state = player_state(player.index)
  sync_priority(state)
  state.panel_open = true
  local items = get_heal_items()

  local frame = player.gui.screen.add({
    type = "frame",
    name = PANEL_NAME,
    direction = "vertical",
    caption = { "atmos-auto-heal.panel-title" },
  })
  if location then
    frame.location = location
  else
    frame.auto_center = true
  end

  frame.add({
    type = "checkbox",
    caption = { "atmos-auto-heal.enable" },
    state = state.enabled,
    tags = { aah = "enabled" },
  })
  frame.add({ type = "label", caption = { "atmos-auto-heal.priority-hint" } })

  if #state.priority == 0 then
    frame.add({ type = "label", caption = { "atmos-auto-heal.no-items" } })
  end

  local tbl = frame.add({ type = "table", column_count = 6 })
  for i = 1, #state.priority do
    local name = state.priority[i]
    tbl.add({ type = "label", caption = tostring(i) .. "." })
    tbl.add({
      type = "checkbox",
      state = not state.disabled[name],
      tags = { aah = "item-enabled", item = name },
      tooltip = { "atmos-auto-heal.item-enabled-tooltip" },
    })
    tbl.add({ type = "sprite", sprite = "item/" .. name })
    tbl.add({
      type = "label",
      caption = { "", prototypes.item[name].localised_name, "  [color=green]+", tostring(math.floor(items[name].heal)), "[/color]" },
    })
    tbl.add({
      type = "sprite-button",
      sprite = "utility/speed_up",
      style = "mini_button",
      enabled = i > 1,
      tags = { aah = "up", index = i },
      tooltip = { "atmos-auto-heal.move-up" },
    })
    tbl.add({
      type = "sprite-button",
      sprite = "utility/speed_down",
      style = "mini_button",
      enabled = i < #state.priority,
      tags = { aah = "down", index = i },
      tooltip = { "atmos-auto-heal.move-down" },
    })
  end

  frame.add({ type = "line" })
  local buttons = frame.add({ type = "flow", direction = "horizontal" })
  buttons.add({
    type = "button",
    caption = { "atmos-auto-heal.reset" },
    tags = { aah = "reset" },
  })
  buttons.add({
    type = "button",
    caption = { "atmos-auto-heal.close" },
    tags = { aah = "close" },
  })
end

local function set_enabled(player, enabled)
  local state = player_state(player.index)
  state.enabled = enabled
  player.set_shortcut_toggled("atmos-auto-heal-toggle", enabled)
  sync_tick_handler()
  if state.panel_open then
    build_panel(player)
  end
end

local function init_player(player)
  local state = player_state(player.index)
  sync_priority(state)
  player.set_shortcut_toggled("atmos-auto-heal-toggle", state.enabled)
end

script.on_init(function()
  storage.players = {}
  for _, player in pairs(game.players) do
    init_player(player)
  end
  sync_tick_handler()
end)

script.on_load(function()
  sync_tick_handler()
end)

script.on_configuration_changed(function()
  storage.players = storage.players or {}
  heal_items = nil
  for _, player in pairs(game.players) do
    init_player(player)
    if player.gui.screen[PANEL_NAME] then
      build_panel(player)
    end
  end
  sync_tick_handler()
end)

script.on_event(defines.events.on_player_created, function(event)
  local player = game.get_player(event.player_index)
  if player then
    init_player(player)
    sync_tick_handler()
  end
end)

script.on_event(defines.events.on_player_removed, function(event)
  storage.players[event.player_index] = nil
  sync_tick_handler()
end)

local function on_toggle(event)
  local player = game.get_player(event.player_index)
  if player then
    set_enabled(player, not player_state(player.index).enabled)
  end
end

script.on_event("atmos-auto-heal-toggle", on_toggle)

script.on_event(defines.events.on_lua_shortcut, function(event)
  if event.prototype_name == "atmos-auto-heal-toggle" then
    on_toggle(event)
  end
end)

script.on_event("atmos-auto-heal-panel", function(event)
  local player = game.get_player(event.player_index)
  if not player then
    return
  end
  if player.gui.screen[PANEL_NAME] then
    destroy_panel(player)
  else
    build_panel(player)
  end
end)

script.on_event(defines.events.on_gui_checked_state_changed, function(event)
  local element = event.element
  local tags = element.valid and element.tags
  if not (tags and tags.aah) then
    return
  end
  local player = game.get_player(event.player_index)
  if not player then
    return
  end
  local state = player_state(player.index)
  if tags.aah == "enabled" then
    set_enabled(player, element.state)
  elseif tags.aah == "item-enabled" and tags.item then
    state.disabled[tags.item] = (not element.state) or nil
  end
end)

script.on_event(defines.events.on_gui_click, function(event)
  local element = event.element
  local tags = element.valid and element.tags
  if not (tags and tags.aah) then
    return
  end
  local player = game.get_player(event.player_index)
  if not player then
    return
  end
  local state = player_state(player.index)
  local priority = state.priority
  local index = tags.index

  if tags.aah == "up" and index and index > 1 then
    priority[index], priority[index - 1] = priority[index - 1], priority[index]
    build_panel(player)
  elseif tags.aah == "down" and index and index < #priority then
    priority[index], priority[index + 1] = priority[index + 1], priority[index]
    build_panel(player)
  elseif tags.aah == "reset" then
    state.priority = {}
    state.disabled = {}
    build_panel(player)
  elseif tags.aah == "close" then
    destroy_panel(player)
  end
end)

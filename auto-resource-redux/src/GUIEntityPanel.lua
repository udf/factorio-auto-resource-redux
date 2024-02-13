local GUIEntityPanel = {}
local GUICommon = require "src.GUICommon"
local GUIDispatcher = require "src.GUIDispatcher"
local EntityManager = require "src.EntityManager"

local GUI_CLOSE_EVENT = "arr-entity-panel-close"
local EntityTypeGUIAnchors = {
  ["assembling-machine"] = defines.relative_gui_type.assembling_machine_gui,
  ["car"] = defines.relative_gui_type.car_gui,
  ["logistic-container"] = defines.relative_gui_type.container_gui,
  ["furnace"] = defines.relative_gui_type.furnace_gui,
  ["lab"] = defines.relative_gui_type.lab_gui,
  ["mining-drill"] = defines.relative_gui_type.mining_drill_gui,
  ["boiler"] = defines.relative_gui_type.entity_with_energy_source_gui,
  ["ammo-turret"] = defines.relative_gui_type.container_gui,
  ["reactor"] = defines.relative_gui_type.reactor_gui,
  ["storage-tank"] = defines.relative_gui_type.storage_tank_gui,
  ["rocket-silo"] = defines.relative_gui_type.rocket_silo_gui,
  ["spider-vehicle"] = defines.relative_gui_type.spider_vehicle_gui
}

local function get_location_key(player, entity_name)
  return ("%d;%s;%s;%s"):format(
    player.index,
    player.opened.get_mod(),
    entity_name,
    player.opened.name
  )
end

local function add_gui_content(window, entity)
  local frame = window.add({
    type = "frame",
    style = "inside_shallow_frame_with_padding"
  })
  frame.add({
    type = "label",
    caption = "Allan please add details"
  })
end

local function close_gui(player)
  local last_position = nil
  local window = player.gui.relative[GUICommon.GUI_ENTITY_PANEL]
  if window then
    window.destroy()
  end

  window = player.gui.screen[GUICommon.GUI_ENTITY_PANEL]
  if window then
    last_position = window.location
    window.destroy()
  end
  return last_position
end

local function on_gui_opened(event, tags, player)
  local last_position = close_gui(player)
  local entity = event.entity
  if not entity or not EntityManager.can_manage(entity) then
    return
  end

  -- if .opened is a custom UI, then open on screen instead because we can't anchor
  if player.opened and player.opened.object_name == "LuaGuiElement" then
    local parent = player.gui.screen
    local window = parent.add({
      type = "frame",
      name = GUICommon.GUI_ENTITY_PANEL,
      direction = "vertical",
      style = "inner_frame_in_outer_frame",
      tags = { entity_name = entity.name }
    })
    GUICommon.create_header(window, "Auto Resource", GUI_CLOSE_EVENT)
    -- use the location from the previous time a similar UI was opened
    -- this might be incorrect, but should be corrected on the next tick
    local location_key = get_location_key(player, entity.name)
    last_position = global.entity_panel_location[location_key] or last_position
    if last_position then
      window.location = last_position
    else
      window.force_auto_center()
    end
    -- the position of the parent GUI will only be known on the next tick
    -- so set a flag for on_tick to reposition us later
    global.entity_panel_pending_relocations[player.index] = {
      player = player,
      tick = game.tick + 1
    }
    add_gui_content(window, entity)
    return
  end

  local anchor = EntityTypeGUIAnchors[entity.type]
  if not anchor then
    log(("FIXME: don't know how to anchor to entity GUI name=%s type=%s"):format(entity.name, entity.type))
    return
  end

  local relative = player.gui.relative
  local window = relative[GUICommon.GUI_ENTITY_PANEL]
  window = relative.add({
    type = "frame",
    name = GUICommon.GUI_ENTITY_PANEL,
    direction = "vertical",
    style = "inner_frame_in_outer_frame",
    anchor = {
      position = defines.relative_gui_position.right,
      gui = anchor,
    },
    caption = "Auto Resource",
    tags = { entity_id = entity.unit_number }
  })
  add_gui_content(window, entity)
end

local function on_gui_closed(event, tags, player)
  close_gui(player)
end

function GUIEntityPanel.on_tick()
  -- assume mod UI is centered and reposition our panel based on the guessed width
  for player_id, t in pairs(global.entity_panel_pending_relocations) do
    if game.tick < t.tick then
      goto continue
    end
    if t.player.opened then
      local window = t.player.gui.screen[GUICommon.GUI_ENTITY_PANEL]
      local parent_location = t.player.opened.location
      local tags = window.tags
      -- remember the location, so we can use it for the initial frame when a similar UI opens
      -- we don't account for the parent size, so it might positioned incorrectly
      -- but it is less distracting than being in the center
      local basic_location_key = get_location_key(t.player, tags.entity_name)
      tags.location_key = ("%s;%d;%d"):format(basic_location_key, parent_location.x, parent_location.y)
      window.tags = tags
      local previous_location = global.entity_panel_location[tags.location_key]
      if previous_location then
        window.location = previous_location
        global.entity_panel_location[basic_location_key] = previous_location
      else
        local res = t.player.display_resolution
        local guessed_width = (res.width / 2 - parent_location.x) * 2
        if guessed_width > 0 then
          window.location = { parent_location.x + guessed_width, parent_location.y }
          global.entity_panel_location[basic_location_key] = window.location
        end
      end
    end
    global.entity_panel_pending_relocations[player_id] = nil
    ::continue::
  end
end

function GUIEntityPanel.on_location_changed(event)
  if event.element.name == GUICommon.GUI_ENTITY_PANEL then
    local location_key = event.element.tags.location_key
    if location_key then
      global.entity_panel_location[location_key] = event.element.location
    end
  end
end

function GUIEntityPanel.initialise()
  if global.entity_panel_pending_relocations == nil then
    global.entity_panel_pending_relocations = {}
  end
  if global.entity_panel_location == nil then
    global.entity_panel_location = {}
  end
end

GUIDispatcher.register(defines.events.on_gui_click, GUI_CLOSE_EVENT, on_gui_closed)

GUIDispatcher.register(defines.events.on_gui_opened, nil, on_gui_opened)
GUIDispatcher.register(defines.events.on_gui_closed, nil, on_gui_closed)

return GUIEntityPanel

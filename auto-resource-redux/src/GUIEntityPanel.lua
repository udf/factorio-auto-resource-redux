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
  ["rocket-silo"] = defines.relative_gui_type.rocket_silo_gui,
  ["spider-vehicle"] = defines.relative_gui_type.spider_vehicle_gui
}

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
  local window = player.gui.relative[GUICommon.GUI_ENTITY_PANEL]
  if window then
    window.destroy()
  end

  window = player.gui.screen[GUICommon.GUI_ENTITY_PANEL]
  if window then
    window.destroy()
  end
end

local function on_gui_opened(event, tags, player)
  close_gui(player)

  -- TODO: might need to open on screen if custom GUI has replaced one of the in game ones
  local entity = event.entity
  if not entity or not EntityManager.can_manage(entity) then
    return
  end

  -- if .opened is a custom UI, then open on screen instead because we can't anchor
  if player.opened and player.opened.object_name == "LuaGuiElement" then
    local parent = player.gui.screen
    local location_key = ("%d;%s;%s;%s"):format(player.index, player.opened.get_mod(), entity.name, player.opened.name)
    local window = parent.add({
      type = "frame",
      name = GUICommon.GUI_ENTITY_PANEL,
      direction = "vertical",
      style = "inner_frame_in_outer_frame",
      tags = { location_key = location_key }
    })
    GUICommon.create_header(window, "Auto Resource", GUI_CLOSE_EVENT)
    if global.entity_panel_location[location_key] then
      window.location = global.entity_panel_location[location_key]
    else
      window.force_auto_center()
      global.entity_panel_pending_relocations[player.index] = {
        player = player,
        tick = game.tick + 1
      }
    end
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
      local location = t.player.opened.location
      local res = t.player.display_resolution
      local guessed_width = (res.width / 2 - location.x) * 2
      if guessed_width > 0 then
        window.location = { location.x + guessed_width, location.y }
        global.entity_panel_location[window.tags.location_key] = window.location
      end
    end
    global.entity_panel_pending_relocations[player_id] = nil
    ::continue::
  end
end

function GUIEntityPanel.on_location_changed(event)
  if event.element.name == GUICommon.GUI_ENTITY_PANEL then
    global.entity_panel_location[event.element.tags.location_key] = event.element.location
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

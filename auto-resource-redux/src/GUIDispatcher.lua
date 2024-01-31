local GUIDispatcher = {}

GUIDispatcher.ON_CONFIRM = "arr-gui-confirm"

-- { on_click = { event_tag = fn, ... }, ... }
local registered_tagged_events = {
  [defines.events.on_gui_click] = {},
  [defines.events.on_gui_closed] = {},
  [defines.events.on_gui_value_changed] = {},
  [defines.events.on_gui_text_changed] = {},
  [GUIDispatcher.ON_CONFIRM] = {},
}
-- { on_click = { fn1, fn2, ... }, ... }
local registered_events = {
  [defines.events.on_gui_click] = {},
  [defines.events.on_gui_closed] = {},
  [defines.events.on_gui_value_changed] = {},
  [defines.events.on_gui_text_changed] = {},
  [GUIDispatcher.ON_CONFIRM] = {},
}

function GUIDispatcher.register(event_name, event_tag, handler)
  if event_tag then
    registered_tagged_events[event_name][event_tag] = handler
  else
    table.insert(registered_events[event_name], handler)
  end
end

function GUIDispatcher.on_event(event)
  local player = game.get_player(event.player_index)
  local tags = (event.element or {}).tags or {}
  local event_name = event.input_name or event.name
  local event_tags = tags['event']
  local fired_handlers = {}
  if type(event_tags) == "string" then
    event_tags = { [event_tags] = true }
  end
  if event_tags then
    for event_tag, _ in pairs(event_tags) do
      local handler = registered_tagged_events[event_name][event_tag]
      if handler then
        handler(event, tags, player)
        fired_handlers[handler] = true
      end
    end
  end

  -- fire all handlers that accept all events
  for event_tag, fn in pairs(registered_events[event_name]) do
    if fired_handlers[fn] == nil then
      fn(event, nil, player)
    end
  end
end

return GUIDispatcher

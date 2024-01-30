local GUIDispatcher = {}

GUIDispatcher.ON_CONFIRM = "arr-gui-confirm"

-- { on_click = { event_tag = {fn1, fn2}, ... }, ... }
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

function GUIDispatcher.register(event_name, event_tag, handler_fn)
  if event_tag then
    handlers = registered_tagged_events[event_name][event_tag] or {}
    table.insert(handlers, handler_fn)
    registered_tagged_events[event_name][event_tag] = handlers
  else
    table.insert(registered_events[event_name], handler_fn)
  end
end

function GUIDispatcher.on_event(event)
  local player = game.get_player(event.player_index)
  local tags = (event.element or {}).tags or {}
  local event_name = event.input_name or event.name
  local handlers = registered_tagged_events[event_name][tags['event']]
  if handlers then
    for _, handler in ipairs(handlers) do
      handler(event, tags, player)
    end
  end

  -- fire all handlers that accept all events
  for event_tag, fn in pairs(registered_events[event_name]) do
    if fn ~= handler then
      fn(event, nil, player)
    end
  end
end

return GUIDispatcher

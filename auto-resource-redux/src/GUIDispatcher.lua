local GUIDispatcher = {}

-- { on_click = { event_tag = fn, ... }, ... }
local registered_tagged_events = {
  [defines.events.on_gui_click] = {},
  [defines.events.on_gui_closed] = {},
}
-- { on_click = { fn1, fn2, ... }, ... }
local registered_events = {
  [defines.events.on_gui_click] = {},
  [defines.events.on_gui_closed] = {},
}

function GUIDispatcher.register(event_name, event_tag, handler, always_run)
  registered_tagged_events[event_name][event_tag] = handler
  if always_run then
    table.insert(registered_events[event_name], handler)
  end
end

function GUIDispatcher.on_event(event)
  local player = game.get_player(event.player_index)
  local tags = (event.element or {}).tags or {}
  local handler = registered_tagged_events[event.name][tags['event']]
  if handler then
    handler(event, tags, player)
  end

  -- fire all handlers that accept all events
  for event_tag, fn in pairs(registered_events[event.name]) do
    if fn ~= handler then
      fn(event, nil, player)
    end
  end
end

return GUIDispatcher
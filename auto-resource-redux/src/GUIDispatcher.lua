local GUIDispatcher = {}

-- { on_click = { event_tag = fn, ... }, ... }
local registered_events = {
  [defines.events.on_gui_click] = {},
  [defines.events.on_gui_closed] = {},
}

function GUIDispatcher.register(event_name, event_tag, handler)
  registered_events[event_name][event_tag] = handler
end

function GUIDispatcher.on_event(event)
  if not event.element then
    return
  end
  local tags = event.element.tags
  local event_tag = tags['event']
  if not event_tag then
    return
  end
  local handler = registered_events[event.name][event_tag]
  if handler then
    handler(event, tags, game.get_player(event.player_index))
  end
end

return GUIDispatcher
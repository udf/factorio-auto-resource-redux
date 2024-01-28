local GUIDispatcher = {}

GUIDispatcher.ON_CLICK = "on_click"

-- { on_click = { event_tag = fn, ... }, ... }
local registered_events = {
  [GUIDispatcher.ON_CLICK] = {}
}

function GUIDispatcher.register(event_name, event_tag, handler)
  registered_events[event_name][event_tag] = handler
end

function GUIDispatcher.on_click(event)
  local tags = event.element.tags
  local event_tag = tags['event']
  if not event_tag then
    return
  end
  local handler = registered_events[GUIDispatcher.ON_CLICK][event_tag]
  if handler then
    handler(event, tags, game.get_player(event.player_index))
  end
end

return GUIDispatcher
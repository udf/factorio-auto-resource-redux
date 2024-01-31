local RichText = {}

RichText.COLOUR_END = "[/color]"
RichText.COLOUR_LABEL = "[color=#e6d0ae]"
RichText.COLOUR_HINT = "[color=#80cef0]"
RichText.COLOUR_RED = "[color=red]"
RichText.COLOUR_GREEN = "[color=green]"
RichText.FONT_END = "[/font]"
RichText.FONT_BOLD = "[font=default-bold]"

RichText.COLOUR_FONT_END = RichText.COLOUR_END .. RichText.FONT_END
RichText.HINT = RichText.FONT_BOLD .. RichText.COLOUR_HINT
RichText.HINT_END = RichText.COLOUR_FONT_END
RichText.LABEL = RichText.FONT_BOLD .. RichText.COLOUR_LABEL
RichText.LABEL_END = RichText.COLOUR_FONT_END

function RichText.get_coloured_text(colour, text)
  local r, g, b = colour.r, colour.g, colour.b
  if r <= 1 and g <= 1 and b <= 1 then
    r, g, b = r * 255, g * 255, b * 255
  end
  return ("[color=%d,%d,%d]%s[/color]"):format(r, g, b, text)
end

return RichText

local RichTextConstants = {}

RichTextConstants.COLOUR_END = "[/color]"
RichTextConstants.COLOUR_LABEL = "[color=#e6d0ae]"
RichTextConstants.COLOUR_HINT = "[color=#80cef0]"
RichTextConstants.COLOUR_RED = "[color=red]"
RichTextConstants.COLOUR_GREEN = "[color=green]"
RichTextConstants.FONT_END = "[/font]"
RichTextConstants.FONT_BOLD = "[font=default-bold]"

RichTextConstants.COLOUR_FONT_END = RichTextConstants.COLOUR_END .. RichTextConstants.FONT_END
RichTextConstants.HINT = RichTextConstants.FONT_BOLD .. RichTextConstants.COLOUR_HINT
RichTextConstants.HINT_END = RichTextConstants.COLOUR_FONT_END
RichTextConstants.LABEL = RichTextConstants.FONT_BOLD .. RichTextConstants.COLOUR_LABEL
RichTextConstants.LABEL_END = RichTextConstants.COLOUR_FONT_END

function RichTextConstants.get_coloured_text(colour, text)
  local r, g, b = colour.r, colour.g, colour.b
  if r <= 1 and g <= 1 and b <= 1 then
    r, g, b = r * 255, g * 255, b * 255
  end
  return ("[color=%d,%d,%d]%s[/color]"):format(r, g, b, text)
end

return RichTextConstants

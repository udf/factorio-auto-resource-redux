local logo = {
  type = "sprite",
  name = "arr-logo",
  filename = "__auto-resource-redux__/graphics/logo.png",
  priority = "medium",
  width = 64,
  height = 64,
  generate_sdf = true
}

local logo_disabled = {
  type = "sprite",
  name = "arr-logo-disabled",
  filename = "__auto-resource-redux__/graphics/logo-disabled.png",
  priority = "medium",
  width = 64,
  height = 64,
  generate_sdf = true
}

local asterisk_icon = {
  type = "sprite",
  name = "arr-asterisk-icon",
  filename = "__auto-resource-redux__/graphics/asterisk-icon.png",
  priority = "medium",
  width = 28,
  height = 28,
  generate_sdf = true
}

data:extend({
  logo,
  logo_disabled,
  asterisk_icon
})


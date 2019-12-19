JokerPanel = class()

JokerPanel.COLORS = {
  exp = Color(0.5, 1, 1),
  hp_normal = Color(0.5, 1, 0.5),
  hp_low = Color(1, 1, 0.5),
  hp_critical = Color(1, 0.5, 0.5)
}

local function hp_ratio_to_color(hp_ratio)
  return hp_ratio <= 0.15 and JokerPanel.COLORS.hp_critical or hp_ratio <= 0.5 and JokerPanel.COLORS.hp_low or JokerPanel.COLORS.hp_normal
end

function JokerPanel:init(panel, w)
  self._padding = 8

  self._parent_panel = panel
  self._panel = self._parent_panel:panel({
    w = w,
    h = 52,
    layer = 50
  })

  self._panel_bg = self._panel:rect({
    name = "bg",
    color = Color.black:with_alpha(0.2),
    layer = -100
  })

  self._name_text = self._panel:text({
    name = "name",
    text = "",
    font = tweak_data.menu.pd2_medium_font,
    font_size = 16,
    color = Color.white,
    x = self._padding,
    y = self._padding - 1
  })

  self._lvl_text = self._panel:text({
    name = "level",
    text = "",
    font = tweak_data.menu.pd2_medium_font,
    font_size = 16,
    color = Color.white,
    y = self._padding - 1
  })

  self._hp_bar_bg = self._panel:rect({
    name = "hp_bg",
    color = Color.black:with_alpha(0.3),
    w = self._panel:w() - self._padding * 2,
    h = 12,
    x = self._padding,
    y = 24,
    layer = -10
  })
  self._hp_bar = self._panel:rect({
    name = "hp",
    color = self.COLORS.normal,
    w = self._hp_bar_bg:w(),
    h = self._hp_bar_bg:h(),
    x = self._hp_bar_bg:x(),
    y = self._hp_bar_bg:y(),
    layer = -1
  })
  self._hp_text = self._panel:text({
    name = "hp_text",
    text = "",
    font = tweak_data.menu.small_font,
    font_size = 9,
    align = "center",
    vertical = "center",
    w = self._hp_bar_bg:w(),
    h = self._hp_bar_bg:h(),
    x = self._hp_bar_bg:x(),
    y = self._hp_bar_bg:y()
  })
  self._hp_ratio = 1

  self._exp_bar_bg = self._panel:rect({
    name = "exp_bg",
    color = Color.black:with_alpha(0.3),
    w = self._panel:w() - self._padding * 2,
    h = 4,
    x = self._padding,
    y = 40,
    layer = -10
  })
  self._exp_bar = self._panel:rect({
    name = "exp",
    color = self.COLORS.exp,
    w = self._exp_bar_bg:w(),
    h = self._exp_bar_bg:h(),
    x = self._exp_bar_bg:x(),
    y = self._exp_bar_bg:y(),
    layer = -1
  })
  self._exp_ratio = 0

  self._border = BoxGuiObject:new(self._panel, {
    layer = 50,
    left = 1,
    right = 1,
    top = 1,
    bottom = 1
  })
end

function JokerPanel:set_width(w)
  self._panel:set_w(w)
  self._panel_bg:set_w(w)
  self._lvl_text:set_right(self._panel:w() - self._padding)
  local max_w = self._panel:w() - self._padding * 2
  self._hp_bar:set_w((self._hp_bar:w() / self._hp_bar_bg:w()) * max_w)
  self._hp_bar_bg:set_w(max_w)
  self._hp_text:set_w(max_w)
  self._exp_bar:set_w((self._exp_bar:w() / self._exp_bar_bg:w()) * max_w)
  self._exp_bar_bg:set_w(max_w)
  self._border:create_sides(self._panel, {
    layer = 50,
    left = 1,
    right = 1,
    top = 1,
    bottom = 1
  })
end

function JokerPanel:set_position(x, y)
  self._panel:set_position(x, y)
end

function JokerPanel:update_name(name)
  self._name_text:set_text(name)
end

function JokerPanel:update_level(level)
  self._lvl_text:set_text(tostring(level))
  local _, _, w, h = self._lvl_text:text_rect()
  self._lvl_text:set_size(w, h)
  self._lvl_text:set_right(self._panel:w() - self._padding)
end

function JokerPanel:update_hp(hp, hp_ratio, instant)
  self._hp_bar:stop()
  hp_ratio = math.max(0, math.min(1, hp_ratio))
  local max_w = self._panel:w() - self._padding * 2
  if instant then
    self._hp_bar:set_color(hp_ratio_to_color(hp_ratio))
    self._hp_bar:set_w(max_w * hp_ratio)
    self._hp_text:set_text(math.ceil(hp * hp_ratio * 10) .. " / " .. math.ceil(hp * 10))
  else
    local start = self._hp_ratio
    self._hp_bar:animate(function ()
      over(0.25, function (p)
        local f = math.lerp(start, hp_ratio, p)
        self._hp_bar:set_color(hp_ratio_to_color(f))
        self._hp_bar:set_w(max_w * f)
        self._hp_text:set_text(math.ceil(hp * f * 10) .. " / " .. math.ceil(hp * 10))
      end)
    end)
  end
  self._hp_ratio = hp_ratio
end

function JokerPanel:update_exp(exp_ratio, instant)
  self._exp_bar:stop()
  exp_ratio = math.max(0, math.min(1, exp_ratio))
  local max_w = self._panel:w() - self._padding * 2
  if instant then
    self._exp_bar:set_w(max_w * exp_ratio)
  else
    local start = self._exp_ratio
    self._exp_bar:animate(function ()
      over(0.5, function (p)
        local f = math.lerp(start, exp_ratio, p)
        self._exp_bar:set_w(max_w * f)
      end)
    end)
  end
  self._exp_ratio = exp_ratio
end

function JokerPanel:remove()
  self._hp_bar:stop()
  self._exp_bar:stop()
  self._parent_panel:remove(self._panel)
end
if not Jokermon then
  _G.Jokermon = {}
  
  dofile(ModPath .. "req/JokerPanel.lua")

  Jokermon.mod_path = ModPath
  Jokermon.save_path = SavePath
  Jokermon.settings = {
    panel_x_pos = 0.03,
    panel_y_pos = 0.2,
    panel_spacing = 8,
    panel_layout = 1,
    show_messages = true
  }
  Jokermon.jokers = {}
  Jokermon.panels = {}
  Jokermon.units = {}
  Jokermon._num_panels = 0
  Jokermon._queued_keys = {}
  Jokermon._queued_jokers = {}

  function Jokermon:spawn(joker, index, player_unit)
    if not alive(player_unit) then
      return
    end
    if joker.hp_ratio > 0 then
      local is_local_player = player_unit == managers.player:local_player()
      local xml = ScriptSerializer:from_custom_xml(string.format("<table type=\"table\" id=\"@ID%s@\">", joker.uname))
      local ids = xml and xml.id
      if ids and PackageManager:unit_data(ids) then
        if is_local_player then
          table.insert(self._queued_keys, index)
        end
        if Network:is_client() then
          LuaNetworking:SendToPeer(1, "jokermon_request_spawn", json.encode(joker))
          return true
        end
        local unit = World:spawn_unit(ids, player_unit:position() + Vector3(math.random(-300, 300), math.random(-300, 300), 0), player_unit:rotation())
        unit:movement():set_team({ id = "law1", foes = {}, friends = {} })
        if Keepers then
          Keepers.joker_names[player_unit:network():peer():id()] = joker.name
        end
        managers.groupai:state():convert_hostage_to_criminal(unit, not is_local_player and player_unit)
        self:set_unit_stats(unit, joker)
        return true
      elseif is_local_player and self.settings.show_messages then
        managers.chat:_receive_message(1, "JOKERMON", joker.name .. " can't accompany you on this heist!", tweak_data.system_chat_color)
      end
    end
  end

  function Jokermon:add_joker(joker)
    table.insert(self.jokers, joker)
    if self.settings.show_messages then
      managers.chat:_receive_message(1, "JOKERMON", "Captured \"" .. joker.name .. "\" Lv." .. joker.level .. "!", tweak_data.system_chat_color)
    end
    self:save(true)
  end

  function Jokermon:setup_joker(key, unit, joker)
    if not alive(unit) then
      return
    end
    -- Save to units
    self.units[key] = unit
    unit:base()._jokermon_key = key
    -- Create panel
    self:add_panel(key, joker)
  end

  function Jokermon:get_base_stats(joker)
    return tweak_data.character[joker.tweak].jokermon_stats
  end

  function Jokermon:get_needed_exp(joker, level)
    local exp_rate = self:get_base_stats(joker).exp_rate
    return 10 * math.ceil(math.pow(math.min(level, 100), exp_rate))
  end

  function Jokermon:get_exp_ratio(joker)
    if joker.level >= 100 then
      return 1
    end
    local needed_current, needed_next = self:get_needed_exp(joker, joker.level), self:get_needed_exp(joker, joker.level + 1)
    return (joker.exp - needed_current) / (needed_next - needed_current)
  end

  function Jokermon:layout_panels()
    local i = 0
    local x, y
    local x_pos, y_pos, spacing = self.settings.panel_x_pos, self.settings.panel_y_pos, self.settings.panel_spacing
    for _, panel in pairs(self.panels) do
      if self.settings.panel_layout == 1 then
        x = (panel._parent_panel:w() - panel._panel:w()) * x_pos
        y = (panel._parent_panel:h() - panel._panel:h() * self._num_panels - spacing * (self._num_panels - 1)) * y_pos + (panel._panel:h() + spacing) * i
      else
        x = (panel._parent_panel:w() - panel._panel:w() * self._num_panels - spacing * (self._num_panels - 1)) * x_pos + (panel._panel:w() + spacing) * i
        y = (panel._parent_panel:h() - panel._panel:h()) * y_pos
      end
      panel:set_position(x, y)
      i = i + 1
    end
  end

  function Jokermon:add_panel(key, joker)
    local hud = managers.hud:script(PlayerBase.PLAYER_INFO_HUD_FULLSCREEN_PD2)
    if not hud then
      return
    end
    local panel = JokerPanel:new(hud.panel)
    panel:update_name(joker.name)
    panel:update_hp(joker.hp, joker.hp_ratio, true)
    panel:update_level(joker.level)
    panel:update_exp(self:get_exp_ratio(joker), true)
    if not self.panels[key] then
      self._num_panels = self._num_panels + 1
    end
    self.panels[key] = panel
    self:layout_panels()
  end

  function Jokermon:remove_panel(key)
    if self.panels[key] then
      self.panels[key]:remove()
      self.panels[key] = nil
      self._num_panels = self._num_panels - 1
      self:layout_panels()
    end
  end

  function Jokermon:set_unit_stats(unit, joker)
    if not alive(unit) then
      return
    end
    local u_damage = unit:character_damage()
    u_damage._HEALTH_INIT = joker.hp
    u_damage._health_ratio = joker.hp_ratio
    u_damage._health = u_damage._health_ratio * u_damage._HEALTH_INIT
    u_damage._HEALTH_INIT_PRECENT = u_damage._HEALTH_INIT / u_damage._HEALTH_GRANULARITY
  end

  function Jokermon:give_exp(key, exp)
    local joker = self.jokers[key]
    if joker and joker.level < 100 then
      local panel = self.panels[key]
      local old_level = joker.level
      joker.exp = joker.exp + exp
      while joker.level < 100 and self:get_exp_ratio(joker) >= 1 do
        -- update stats
        joker.level = joker.level + 1
        joker.hp = joker.hp + self:get_base_stats(joker).base_hp * ((joker.level - 1) / 99)
      end
      if joker.level ~= old_level then
        self:set_unit_stats(self.units[key], joker)
        if panel then
          panel:update_hp(joker.hp, joker.hp_ratio)
          panel:update_level(joker.level)
          panel:update_exp(0, true)
        end
        if self.settings.show_messages then
          managers.chat:_receive_message(1, "JOKERMON", joker.name .. " reached Lv." .. joker.level .. "!", tweak_data.system_chat_color)
        end
      end
      if panel then
        panel:update_exp(self:get_exp_ratio(joker))
      end
    end
  end

  function Jokermon:save(full_save)
    local file = io.open(self.save_path .. "jokermon_settings.txt", "w+")
    if file then
      file:write(json.encode(self.settings))
      file:close()
    end
    if full_save then
      file = io.open(self.save_path .. "jokermon.txt", "w+")
      if file then
        file:write(json.encode(self.jokers))
        file:close()
      end
    end
  end
  
  function Jokermon:load()
    local file = io.open(self.save_path .. "jokermon_settings.txt", "r")
    if file then
      local data = json.decode(file:read("*all"))
      file:close()
      for k, v in pairs(data) do
        self.settings[k] = v
      end
    end
    file = io.open(self.save_path .. "jokermon.txt", "r")
    if file then
      self.jokers = json.decode(file:read("*all"))
      file:close()
    end
  end

  Jokermon:load()
  
  Hooks:Add("HopLibOnMinionAdded", "HopLibOnMinionAddedJokermon", function(unit, player_unit)
    if not player_unit == managers.player:local_player() then
      if Network:is_server() then
        LuaNetworking:SendToPeer(player_unit:network():peer():id(), "jokermon_uname", unit:name():key())
      end
      return
    end

    local key = Jokermon._queued_keys[1]
    if key then
      table.remove(Jokermon._queued_keys, 1)
      -- Use existing Jokermon entry
      local info = HopLib:unit_info_manager():get_info(unit)
      local joker = Jokermon.jokers[key]
      info._nickname = joker.name
      Jokermon:set_unit_stats(unit, joker)
      Jokermon:setup_joker(key, unit, joker)
    else
      -- Create new Jokermon entry
      key = #Jokermon.jokers + 1
      local joker = {
        tweak = unit:base()._tweak_table,
        uname = unit:name():key(),
        name = HopLib:unit_info_manager():get_info(unit):nickname(),
        hp = unit:character_damage()._HEALTH_INIT,
        hp_ratio = 1,
        level = math.floor(1 + math.random(20, 70) * (tweak_data:difficulty_to_index(Global.game_settings.difficulty) / #tweak_data.difficulties)),
        exp = 0
      }
      joker.exp = Jokermon:get_needed_exp(joker, joker.level)

      if Network:is_server() then
        Jokermon:add_joker(joker)
        Jokermon:setup_joker(key, unit, joker)
      else
        table.insert(Jokermon._queued_jokers, { 
          key = key,
          unit = unit,
          joker = joker })
      end
    end

  end)

  Hooks:Add("HopLibOnMinionRemoved", "HopLibOnMinionRemovedJokermon", function(unit)
    local key = unit:base()._jokermon_key
    local joker = key and Jokermon.jokers[key]
    if joker then
      joker.hp_ratio = unit:character_damage()._health_ratio
      if joker.hp_ratio <= 0 and Jokermon.settings.show_messages then
        managers.chat:_receive_message(1, "JOKERMON", joker.name .. " fainted!", tweak_data.system_chat_color)
      end
      Jokermon:save(true)
      Jokermon:remove_panel(key)
      Jokermon.units[key] = nil
    end
  end)

  Hooks:Add("HopLibOnUnitDamaged", "HopLibOnUnitDamagedJokermon", function(unit, damage_info)
    local key = unit:base()._jokermon_key
    local joker = key and Jokermon.jokers[key]
    if joker then
      joker.hp_ratio = unit:character_damage()._health_ratio
      Jokermon.panels[key]:update_hp(joker.hp, joker.hp_ratio)
    end
  end)

  Hooks:Add("HopLibOnUnitDied", "HopLibOnUnitDiedJokermon", function(unit, damage_info)
    if alive(damage_info.attacker_unit) and damage_info.attacker_unit:base()._jokermon_key then
      Jokermon:give_exp(damage_info.attacker_unit:base()._jokermon_key, unit:character_damage()._HEALTH_INIT)
    end
  end)
  
  Hooks:Add("NetworkReceivedData", "NetworkReceivedDataJokermon", function(sender, id, data)
    if id == "jokermon_request_spawn" then
      Jokermon:spawn(json.decode(data), nil, LuaNetworking:GetPeers()[sender]:unit())
    elseif id == "jokermon_uname" then
      local joker_data = Jokermon._queued_jokers[1]
      if joker_data then
        table.remove(Jokermon._queued_jokers, 1)
        joker_data.joker.uname = data
        Jokermon:add_joker(joker_data.joker)
        Jokermon:setup_joker(joker_data.key, joker_data.unit, joker_data.joker)
      end
    end
  end)
  
end

if RequiredScript then

  local fname = Jokermon.mod_path .. "lua/" .. RequiredScript:gsub(".+/(.+)", "%1.lua")
  if io.file_is_readable(fname) then
    dofile(fname)
  end

end
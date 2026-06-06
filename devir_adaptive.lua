local config_names = {"Global", "Scout", "AWP", "Auto", "Pistol", "Revolver", "Deagle", "Rifle", "SMG", "Shotgun", "Taser"}
local pui = require("gamesense/pui")
local vector = require('vector')
local clipboard = require("gamesense/clipboard")
local base64 = require("gamesense/base64")

local menu = {
    coded_by_devirsaint = pui.label("LUA", "B", "Coded by devirsaint"),
    export_cfg = pui.button("LUA", "B", "Export", function() export() end),
    import_cfg = pui.button("LUA", "B", "Import", function() import() end),
    md_key = pui.hotkey("LUA", "B", "Override minimum damage key"),
    hc_key = pui.hotkey("LUA", "B", "Override hit chance key"),
    hb_key = pui.hotkey("LUA", "B", "Override hit box key"),
    un_key = pui.hotkey("LUA", "B", "Override unsafe hitboxes key"),
    damage_indicator_left = pui.combobox("LUA", "B", "Leftside Damage indicator", {"Disabled", "On key", "Always on"}),
    damage_indicator = pui.combobox("LUA", "B", "Damage indicator", {"Disabled", "On key", "Always on"}),
    x_damage = pui.slider("LUA", "B", "X", -50, 50, 0, true),
    y_damage = pui.slider("LUA", "B", "Y", -50, 50, 0, true),
    cond = pui.combobox("LUA", "B", "View weapon", config_names),
    adaptive = {},
}

menu.x_damage:depend({menu.damage_indicator, "Disabled", true})
menu.y_damage:depend({menu.damage_indicator, "Disabled", true})

local ref = {
    dt = pui.reference("RAGE", "Aimbot", "Double tap"),
    fake_duck = pui.reference("RAGE","Other","Duck peek assist"),
    enabled = pui.reference("RAGE", "Aimbot", "Enabled"),
    target_selection = pui.reference("RAGE", "Aimbot", "Target selection"),
    target_hitbox = pui.reference("RAGE", "Aimbot", "Target hitbox"),
    multipoint = {pui.reference("RAGE", "Aimbot", "Multi-point")},
    unsafe = pui.reference("RAGE", "Aimbot", "Avoid unsafe hitboxes"),
    multipoint_scale = pui.reference("RAGE", "Aimbot", "Multi-point scale"),
    prefer_safepoint = pui.reference("RAGE", "Aimbot", "Prefer safe point"),
    force_safepoint = pui.reference("RAGE", "Aimbot", "Force safe point"),
    automatic_fire = pui.reference("RAGE", "Other", "Automatic fire"),
    automatic_penetration = pui.reference("RAGE", "Other", "Automatic penetration"),
    silent_aim = pui.reference("RAGE", "Other", "Silent aim"),
    hitchance = pui.reference("RAGE", "Aimbot", "Minimum hit chance"),
    mindamage = pui.reference("RAGE", "Aimbot", "Minimum damage"),
    automatic_scope = pui.reference("RAGE", "Aimbot", "Automatic scope"),
    reduce_aimstep = pui.reference("RAGE", "Other", "Reduce aim step"),
    og_spread = pui.reference("RAGE", "Other", "Log misses due to spread"),
    prefer_bodyaim = pui.reference("RAGE", "Aimbot", "Prefer body aim"),
    prefer_bodyaim_disablers = pui.reference("RAGE", "Aimbot", "Prefer body aim disablers"),
    doubletap_hc = pui.reference("RAGE", "Aimbot", "Double tap hit chance"),
    doubletap_stop = pui.reference("RAGE", "Aimbot", "Double tap quick stop"),
    accuracy_boost = pui.reference("RAGE", "Other", "Accuracy boost"),
    quick_stop = {pui.reference("RAGE", "Aimbot", "Quick stop")},    
    delay_shot = pui.reference("RAGE", "Other", "Delay shot"),
}

local rage = {
    target_selection = "",
    target_hitbox = {},
    multipoint = {},
    unsafe = {},
    multipoint_scale = {},
    prefer_safepoint = false,
    force_safepoint = false,
    automatic_fire = true,
    automatic_penetration = true,
    silent_aim = true,
    hitchance = 0,
    mindamage = 0,
    automatic_scope = false,
    prefer_bodyaim = false,
    prefer_bodyaim_disablers = {},
    doubletap_hc = 0,
    doubletap_stop = {},
    accuracy_boost = "",
    quick_stop = {false, {}},
    delay_shot = false,
}

for i = 1, #config_names do
    menu.adaptive[i] = {
        enable = pui.checkbox("LUA", "B", "Enable " .. config_names[i]),
        target_selection = pui.combobox("LUA", "B", "[" .. config_names[i] .. "] Target selection", {"Cycle", "Cycle (2x)", "Near crosshair", "Highest damage"}),
        accuracy_boost = pui.combobox("LUA", "B", "[" .. config_names[i] .. "] Accuracy boost", {"Low", "Medium", "High", "Maximum"}),
        target_hitbox = pui.multiselect("LUA", "B", "[" .. config_names[i] .. "] Target hitbox", { "Head", "Chest", "Arms", "Stomach", "Legs", "Feet" }),

        multipoint = pui.multiselect("LUA", "B", "[" .. config_names[i] .. "] Multi-point", { "Head", "Chest", "Arms", "Stomach", "Legs", "Feet" }),

        multipoint_scale = pui.slider("LUA", "B", "[" .. config_names[i] .. "] Multi-point scale", 24, 100, 60, true, "%", 1, { [24] = "Auto" }),
		unsafe = pui.multiselect("LUA", "B", "[" .. config_names[i] .. "] Avoid unsafe hitboxes", { "Head", "Chest", "Arms", "Stomach", "Legs", "Feet" }),
        
        hitbox_override = pui.multiselect("LUA", "B", "[" .. config_names[i] .. "] Hitbox override", { "Head", "Chest", "Arms", "Stomach", "Legs", "Feet" }),
        unsafe_override = pui.multiselect("LUA", "B", "[" .. config_names[i] .. "] Avoid unsafe hitboxes override", { "Head", "Chest", "Arms", "Stomach", "Legs", "Feet" }),

        prefer_safe_point = pui.checkbox("LUA", "B", "[" .. config_names[i] .. "] Prefer safe point"),
        dt_prefer_safe_point = pui.checkbox("LUA", "B", "[" .. config_names[i] .. "] Prefer safe point on DT"),
        automatic_scope = pui.checkbox("LUA", "B", "[" .. config_names[i] .. "] Automatic scope"),

        hitchance = pui.slider("LUA", "B", "[" .. config_names[i] .. "] Hitchance", 0, 100, 50, true, "%", 1, {"Off"}),
        hitchance_ovr = pui.slider("LUA", "B", "[" .. config_names[i] .. "] Hitchance override", 0, 100, 50, true, "%", 1, {"Off"}),        
        ns_hitchance = pui.slider("LUA", "B", "[" .. config_names[i] .. "] Noscope hitchance", 0, 100, 50, true, "%", 1, {"Off"}),
        air_hc_enable = pui.checkbox("LUA", "B", "[" .. config_names[i] .. "] Custom hitchance in air"),
        hitchance_air = pui.slider("LUA", "B", "[" .. config_names[i] .. "] Hitchance in air", 0, 100, 50, true, "%", 1, {"Off"}),

        min_damage = pui.slider("LUA", "B", "[" .. config_names[i] .. "] Minimum damage", 0, 126, 20),
        onkey_min_damage = pui.slider("LUA", "B", "[" .. config_names[i] .. "] Minimum damage on key", 0, 126, 20),

        quick_stop = pui.checkbox("LUA", "B", "[" .. config_names[i] .. "] Quick stop"),
        quick_stop_options = pui.multiselect("LUA", "B", "[" .. config_names[i] .. "] Quick stop options", {"Early", "Slow motion", "Duck", "Fake duck", "Move between shots", "Ignore molotov", "Taser"}),
        
        quick_stop_ns = pui.checkbox("LUA", "B", "[" .. config_names[i] .. "] Quick stop noscope"),
        quick_stop_options_ns = pui.multiselect("LUA", "B", "[" .. config_names[i] .. "] Quick stop options ns", {"Early", "Slow motion", "Duck", "Fake duck", "Move between shots", "Ignore molotov", "Taser"}),
        
        prefer_baim = pui.checkbox("LUA", "B", "[" .. config_names[i] .. "] Prefer body aim"),
        prefer_baim_disablers = pui.multiselect("LUA", "B", "[" .. config_names[i] .. "] Prefer body aim disablers", {"Low inaccuracy", "Target shot fired", "Target resolved", "Safe point headshot", "Low damage"}),
        delay_shot = pui.checkbox("LUA", "B", "[" .. config_names[i] .. "] Delay shot"),

        doubletap_hc = pui.slider("LUA", "B", "[" .. config_names[i] .. "] Double tap hit chance", 0, 100, 0, true, "%", 1),
        doubletap_stop = pui.multiselect("LUA", "B", "[" .. config_names[i] .. "] Double tap quick stop", { "Slow motion", "Duck", "Move between shots" }),
    }
    if i == 2 then
        menu.adaptive[i].js_quick_stop_key = pui.hotkey("LUA", "B", "[Jump Scout] Enable key")
        menu.adaptive[i].js_settings = pui.checkbox("LUA", "B", "[Jump Scout] settings")
        menu.adaptive[i].js_target_hitbox = pui.multiselect("LUA", "B", "[Jump Scout] Target hitbox", { "Head", "Chest", "Arms", "Stomach", "Legs", "Feet" })
        menu.adaptive[i].js_multipoint = pui.multiselect("LUA", "B", "[Jump Scout] Multi-point", { "Head", "Chest", "Arms", "Stomach", "Legs", "Feet" })
        menu.adaptive[i].js_multipoint_scale = pui.slider("LUA", "B", "[Jump Scout] Multi-point scale", 24, 100, 60, true, "%", 1, { [24] = "Auto" })
        menu.adaptive[i].js_unsafe = pui.multiselect("LUA", "B", "[Jump Scout] Avoid unsafe hitboxes", { "Head", "Chest", "Arms", "Stomach", "Legs", "Feet" })
        menu.adaptive[i].js_delay_shot = pui.checkbox("LUA", "B", "[Jump Scout] Delay shot")
        menu.adaptive[i].js_prefer_baim = pui.checkbox("LUA", "B", "[Jump Scout] Prefer body aim")
        menu.adaptive[i].js_quick_stop = pui.combobox("LUA", "B", "[Jump Scout] Quick stop", {"Full stop", "Accurate", "Default"})
        menu.adaptive[i].js_unit = pui.slider("LUA", "B", "[Jump Scout] Automatic stop unit limit", 50, 3000, 1000)
        menu.adaptive[i].js_prefer_safe_point = pui.checkbox("LUA", "B", "[Jump Scout] Prefer safe point")
    end

    cond_usl = {menu.cond, function() return menu.cond:get() == config_names[i] end}
    if i == 11 then
        for k, shit in pairs(menu.adaptive[i]) do
            if (shit ~= menu.adaptive[i].enable) then
                shit:set_visible(false)
            end
        end
        menu.adaptive[i].enable:depend(cond_usl)
        menu.adaptive[i].hitchance:depend(cond_usl, menu.adaptive[i].enable)
        menu.adaptive[i].target_selection:depend(cond_usl, menu.adaptive[i].enable)
        menu.adaptive[i].accuracy_boost:depend(cond_usl, menu.adaptive[i].enable)
        menu.adaptive[i].target_hitbox:depend(cond_usl, menu.adaptive[i].enable)
        menu.adaptive[i].multipoint:depend(cond_usl, menu.adaptive[i].enable, {menu.adaptive[i].target_hitbox, function() return #menu.adaptive[i].target_hitbox:get() > 0 end})
    
        menu.adaptive[i].multipoint_scale:depend(cond_usl, menu.adaptive[i].enable, {menu.adaptive[i].target_hitbox, function() return #menu.adaptive[i].target_hitbox:get() > 0 end}, {menu.adaptive[i].multipoint, function() return #menu.adaptive[i].multipoint:get() > 0 end})
        menu.adaptive[i].unsafe:depend(cond_usl, menu.adaptive[i].enable, {menu.adaptive[i].target_hitbox, function() return #menu.adaptive[i].target_hitbox:get() > 0 end})
        menu.adaptive[i].prefer_safe_point:depend(cond_usl, menu.adaptive[i].enable)
        menu.adaptive[i].dt_prefer_safe_point:depend(cond_usl, menu.adaptive[i].enable)
    
        menu.adaptive[i].hitchance:depend(cond_usl, menu.adaptive[i].enable)
        menu.adaptive[i].min_damage:depend(cond_usl, menu.adaptive[i].enable)
    
        menu.adaptive[i].quick_stop:depend(cond_usl, menu.adaptive[i].enable)
        menu.adaptive[i].quick_stop_options:depend(cond_usl, menu.adaptive[i].enable, menu.adaptive[i].quick_stop)
    
    
        menu.adaptive[i].prefer_baim:depend(cond_usl, menu.adaptive[i].enable)
        menu.adaptive[i].prefer_baim_disablers:depend(cond_usl, menu.adaptive[i].enable, menu.adaptive[i].prefer_baim)
        menu.adaptive[i].delay_shot:depend(cond_usl, menu.adaptive[i].enable)

        menu.adaptive[i].doubletap_hc:depend(cond_usl, menu.adaptive[i].enable)
        menu.adaptive[i].doubletap_stop:depend(cond_usl, menu.adaptive[i].enable)

    else
        if i == 1 then
            menu.adaptive[i].enable:set_visible(false)
            menu.adaptive[i].enable:set(true)
        else
            menu.adaptive[i].enable:depend(cond_usl)
        end
        menu.adaptive[i].target_selection:depend(cond_usl, menu.adaptive[i].enable)
        menu.adaptive[i].accuracy_boost:depend(cond_usl, menu.adaptive[i].enable)
        menu.adaptive[i].target_hitbox:depend(cond_usl, menu.adaptive[i].enable)
        menu.adaptive[i].hitbox_override:depend(cond_usl, menu.adaptive[i].enable)
        menu.adaptive[i].unsafe_override:depend(cond_usl, menu.adaptive[i].enable)
    
        menu.adaptive[i].multipoint:depend(cond_usl, menu.adaptive[i].enable)
    
        menu.adaptive[i].multipoint_scale:depend(cond_usl, menu.adaptive[i].enable, {menu.adaptive[i].multipoint, function() return #menu.adaptive[i].multipoint:get() > 0 end})
        menu.adaptive[i].unsafe:depend(cond_usl, menu.adaptive[i].enable)
    
        menu.adaptive[i].prefer_safe_point:depend(cond_usl, menu.adaptive[i].enable)
        menu.adaptive[i].dt_prefer_safe_point:depend(cond_usl, menu.adaptive[i].enable)
    
        menu.adaptive[i].hitchance:depend(cond_usl, menu.adaptive[i].enable)
        menu.adaptive[i].hitchance_ovr:depend(cond_usl, menu.adaptive[i].enable)
    
    
        menu.adaptive[i].min_damage:depend(cond_usl, menu.adaptive[i].enable)
        menu.adaptive[i].onkey_min_damage:depend(cond_usl, menu.adaptive[i].enable)
    
        menu.adaptive[i].quick_stop:depend(cond_usl, menu.adaptive[i].enable)
        menu.adaptive[i].quick_stop_options:depend(cond_usl, menu.adaptive[i].enable, menu.adaptive[i].quick_stop)
    
    
        menu.adaptive[i].prefer_baim:depend(cond_usl, menu.adaptive[i].enable)
        menu.adaptive[i].prefer_baim_disablers:depend(cond_usl, menu.adaptive[i].enable, menu.adaptive[i].prefer_baim)
        menu.adaptive[i].delay_shot:depend(cond_usl, menu.adaptive[i].enable)
    
        menu.adaptive[i].doubletap_hc:depend(cond_usl, menu.adaptive[i].enable)
        menu.adaptive[i].doubletap_stop:depend(cond_usl, menu.adaptive[i].enable)
        menu.adaptive[i].air_hc_enable:depend(cond_usl, menu.adaptive[i].enable)
        menu.adaptive[i].hitchance_air:depend(cond_usl, menu.adaptive[i].enable, menu.adaptive[i].air_hc_enable)
    
        if i == 2 then
            menu.adaptive[i].js_settings:depend(cond_usl, menu.adaptive[i].enable)
            menu.adaptive[i].js_target_hitbox:depend(cond_usl, menu.adaptive[i].enable, menu.adaptive[i].js_settings)
            menu.adaptive[i].js_multipoint:depend(cond_usl, menu.adaptive[i].enable, menu.adaptive[i].js_settings)
            menu.adaptive[i].js_delay_shot:depend(cond_usl, menu.adaptive[i].enable, menu.adaptive[i].js_settings)
            menu.adaptive[i].js_prefer_baim:depend(cond_usl, menu.adaptive[i].enable, menu.adaptive[i].js_settings)
            menu.adaptive[i].js_multipoint_scale:depend(cond_usl, menu.adaptive[i].enable, menu.adaptive[i].js_settings)
            menu.adaptive[i].js_unsafe:depend(cond_usl, menu.adaptive[i].enable, menu.adaptive[i].js_settings)
            menu.adaptive[i].js_quick_stop:depend(cond_usl, menu.adaptive[i].enable, menu.adaptive[i].js_settings)
            menu.adaptive[i].js_unit:depend(cond_usl, menu.adaptive[i].enable, menu.adaptive[i].js_settings, {menu.adaptive[i].js_quick_stop, "Accurate"})
            menu.adaptive[i].js_quick_stop_key:depend(cond_usl, menu.adaptive[i].enable, menu.adaptive[i].js_settings)
            menu.adaptive[i].js_prefer_safe_point:depend(cond_usl, menu.adaptive[i].enable, menu.adaptive[i].js_settings)
        end
        menu.adaptive[i].automatic_scope:depend(cond_usl, menu.adaptive[i].enable)
        if i <= 4 then
            menu.adaptive[i].quick_stop_ns:depend(cond_usl, menu.adaptive[i].enable)
            menu.adaptive[i].quick_stop_options_ns:depend(cond_usl, menu.adaptive[i].enable, menu.adaptive[i].quick_stop_ns)
            menu.adaptive[i].ns_hitchance:depend(cond_usl, menu.adaptive[i].enable)
        else
            menu.adaptive[i].quick_stop_ns:set_visible(false)
            menu.adaptive[i].quick_stop_options_ns:set_visible(false)
            menu.adaptive[i].ns_hitchance:set_visible(false)
        end
    end
end

local function ticks_to_time()
	return globals.tickinterval( ) * 16
end 

local config_names = {"Global", "Scout", "AWP", "Auto", "Pistol", "Revolver", "Deagle", "Rifle", "SMG", "Shotgun", "Taser"}
local weapon_idx = {
[40] = 2, 
[9] = 3, 
[11] = 4,
[38] = 4, 
[36] = 5, 
[61] = 5, 
[2] = 5, 
[8] = 8, 
[16] = 8, 
[10] = 8, 
[1] = 7, 
[3] = 5, 
[64] = 6, 
[35] = 10, 
[25] = 10,
[27] = 10,
[14] = 9,
[28] = 9,
[34] = 9,
[33] = 9,
[24] = 9,
[19] = 9,
[26] = 9,
[31] = 11,
[61] = 5,
[32] = 5,
[63] = 5,
[4] = 5,
[30] = 5,
[29] = 10,
[17] = 9,
}

local player = {
    get_velocity = function(ent)
        return vector(entity.get_prop(ent, "m_vecVelocity")):length()
    end,

    in_air = function(_ent)
        local flags = entity.get_prop(_ent, "m_fFlags")

        if bit.band(flags, 1) == 0 then
            return true
        end
        
        return false
    end,

    dist_3d = function(_ent, other_player)
        if _ent ~= nil and other_player ~= nil then
            local x, y, z = entity.get_origin(_ent)
            local x2, y2, z2 = entity.get_origin(other_player)
            if x ~= nil and y ~= nil and x2 ~= nil and y2 ~= nil and z ~= nil and z2 ~= nil then
                local dist = math.sqrt((x - x2)^2 + (y - y2)^2 + (z - z2)^2)
                return dist
            else
                return math.huge
            end
        else
            return math.huge
        end
    end,
}

function wpn_active()
    local lp = entity.get_local_player()
    local lp_weapon = entity.get_player_weapon(lp)
    local weapon_id = bit.band(entity.get_prop(entity.get_player_weapon(lp), "m_iItemDefinitionIndex"), 0xFFFF)
    if weapon_idx[weapon_id] == nil then
        return 1
    elseif menu.adaptive[weapon_idx[weapon_id]].enable:get() then
        return weapon_idx[weapon_id]
    else
        return 1
    end
end

function CanFire(weapon)
    if weapon == nil then
        return false
    else
        return entity.get_prop(weapon, "m_flNextPrimaryAttack") <= globals.curtime()
    end
end

local function locate( table, value )
    for i = 1, #table do
        if table[i] == value then
            return true
        end
    end
    return false
end

local speed_check = false
local weapon_change = 0

function setting(cmd)
    local lp = entity.get_local_player()
    local lp_weapon = entity.get_player_weapon(lp)
    if lp_weapon == nil then return end
    local weapon_id = bit.band(entity.get_prop(entity.get_player_weapon(lp), "m_iItemDefinitionIndex"), 0xFFFF)
    if weapon_id == nil then return end
    if weapon_change ~= wpn_active() then
        weapon_change = wpn_active()
        menu.cond:set(config_names[wpn_active()])
    end
    local doubletap_ref = ref.dt:get() and ref.dt:get_hotkey() and not ref.fake_duck:get()
    local is_scoped = entity.get_prop(entity.get_player_weapon(lp), "m_zoomLevel" )
    local tab = menu.adaptive[wpn_active()]
    local has_scope = (config_names[weapon_idx[weapon_id]] == 'Scout' or config_names[weapon_idx[weapon_id]] == 'AWP' or config_names[weapon_idx[weapon_id]] == 'Auto')
    if wpn_active() == 11 then
        rage.accuracy_boost = tab.accuracy_boost:get()

        rage.hitchance = tab.hitchance:get()
        rage.mindamage = tab.min_damage:get()
        rage.target_selection = tab.target_selection:get()
        
        if #tab.target_hitbox:get() == 0 then
            rage.target_hitbox = {'Head'}
        else
            rage.target_hitbox = tab.target_hitbox:get()
        end
        
        rage.multipoint = tab.multipoint:get()
        rage.multipoint_scale = tab.multipoint_scale:get()
        rage.unsafe = tab.unsafe:get()
        if doubletap_ref then
            rage.prefer_safepoint = tab.dt_prefer_safe_point:get()
        else
            rage.prefer_safepoint = tab.prefer_safe_point:get()
        end
        rage.quick_stop[1] = tab.quick_stop:get()
        rage.quick_stop[2] = tab.quick_stop_options:get()
        rage.prefer_bodyaim = tab.prefer_baim:get()
        rage.prefer_bodyaim_disablers = tab.prefer_baim_disablers:get()
        rage.doubletap_stop = tab.doubletap_stop:get()
        rage.doubletap_hc = tab.doubletap_hc:get()
        rage.automatic_scope = false
        rage.delay_shot = tab.delay_shot:get()
    else
        rage.target_selection = tab.target_selection:get()
        rage.accuracy_boost = tab.accuracy_boost:get()
        if menu.hc_key:get() then
            rage.hitchance = tab.hitchance_ovr:get()
        else
            if player.in_air(lp) and tab.air_hc_enable:get() then
                rage.hitchance = tab.hitchance_air:get()
            elseif is_scoped ~= 0 or not has_scope then
                rage.hitchance = tab.hitchance:get()
            else
                rage.hitchance = tab.ns_hitchance:get()
            end
        end
        rage.automatic_scope = tab.automatic_scope:get()
        rage.prefer_bodyaim = tab.prefer_baim:get()
        rage.prefer_bodyaim_disablers = tab.prefer_baim_disablers:get()
        if wpn_active() == 2 and tab.js_settings:get() and player.in_air(lp) and tab.js_quick_stop_key:get() then
            rage.quick_stop[2] = "Jump scout"
            rage.quick_stop[1] = true
            if tab.js_quick_stop:get() == "Full stop" or tab.js_quick_stop:get() == "Accurate" then
                local flags = entity.get_prop(lp, "m_fFlags") or 0
                local dist = math.huge
                if tab.js_quick_stop:get() == "Accurate" then
                    local sidemove = 0
                    local forwardmove = 0
                    local enemy_player = client.current_threat()
                    if enemy_player ~= nil then
                        if player.dist_3d(lp, enemy_player) <= tab.js_unit:get() then
                            if cmd.in_moveleft == 1 then
                                sidemove = sidemove - 1
                            end
                            if cmd.in_moveright == 1 then
                                sidemove = sidemove + 1
                            end
                            if cmd.in_forward == 1 then
                                forwardmove = forwardmove + 1
                            end
                            if cmd.in_back == 1 then
                                forwardmove = forwardmove - 1
                            end
                            if forwardmove ~= 0 and sidemove ~= 0 then
                                forwardmove = forwardmove / 1.4142
                                sidemove = sidemove / 1.4142
                            end
                            if cmd.quick_stop and player.get_velocity(lp) > 70 and CanFire(lp_weapon) then
                                cmd.forwardmove = forwardmove * 30
                                cmd.sidemove = sidemove * 30
                                cmd.in_speed = true
                            end
                        end
                    end
                else
                    airstop_enabled = cmd.quick_stop
                    if airstop_enabled and CanFire(lp_weapon) or cmd.in_speed == 1 then
                        if (globals.tickcount() - (ticks or 0)) > 2 then
                            cmd.in_speed = 1
                            client.exec('+speed')
                            speed_check = true
                        end
                    else
                        client.exec('-speed')
                        speed_check = false
                        ticks = globals.tickcount()
                    end
                end
            end
        elseif has_scope and is_scoped == 0 and tab.quick_stop_ns:get() then

            rage.quick_stop[1] = tab.quick_stop_ns:get()
            rage.quick_stop[2] = tab.quick_stop_options_ns:get()
            if speed_check and not cmd.in_speed == 1 then
                client.exec('-speed')
                speed_check = false
            end
        else
            rage.quick_stop[1] = tab.quick_stop:get()
            rage.quick_stop[2] = tab.quick_stop_options:get()
            if speed_check then
                client.exec('-speed')
                speed_check = false
            end
        end
        
        if wpn_active() == 2 and tab.js_settings:get() and player.in_air(lp) and tab.js_quick_stop_key:get() then
            if menu.hb_key:get() and #tab.hitbox_override:get() ~= 0 then
                rage.target_hitbox = tab.hitbox_override:get()
            elseif #tab.js_target_hitbox:get() ~= 0 then
                rage.target_hitbox = tab.js_target_hitbox:get()
            else
                rage.target_hitbox = {'Head'}
            end
            rage.delay_shot = tab.js_delay_shot:get()
            rage.multipoint = tab.js_multipoint:get()
            rage.multipoint_scale = tab.js_multipoint_scale:get()
            if menu.un_key:get() then
                rage.unsafe = tab.unsafe_override:get()
            else
                rage.unsafe = tab.js_unsafe:get()
            end
            rage.prefer_safepoint = tab.js_prefer_safe_point:get()
        else
            if doubletap_ref then
                rage.prefer_safepoint = tab.dt_prefer_safe_point:get()
            else
                rage.prefer_safepoint = tab.prefer_safe_point:get()
            end
            if menu.hb_key:get() and #tab.hitbox_override:get() ~= 0 then
                rage.target_hitbox = tab.hitbox_override:get()
            elseif #tab.target_hitbox:get() ~= 0 then
                rage.target_hitbox = tab.target_hitbox:get()
            else
                rage.target_hitbox = {'Head'}
            end
            
            rage.multipoint = tab.multipoint:get()
            rage.multipoint_scale = tab.multipoint_scale:get()
            if menu.un_key:get() then
                rage.unsafe = tab.unsafe_override:get()
            else
                rage.unsafe = tab.unsafe:get()
            end
            rage.delay_shot = tab.delay_shot:get()
        end
        rage.doubletap_hc = tab.doubletap_hc:get()
        rage.doubletap_stop = tab.doubletap_stop:get()
        if menu.md_key:get() then
            rage.mindamage = tab.onkey_min_damage:get()
        else
            rage.mindamage = tab.min_damage:get()
        end
    end
    --мне похуй я это в стационаре пишу под сейзаром
    if ref.target_selection:get() ~= rage.target_selection then
        ref.target_selection:set(rage.target_selection)
    end
    if ref.target_hitbox:get() ~= rage.target_hitbox then
        ref.target_hitbox:set(rage.target_hitbox)
    end
    if ref.multipoint[1]:get() ~= rage.multipoint then
        ref.multipoint[1]:set(rage.multipoint)
    end
    if ref.multipoint_scale:get() ~= rage.multipoint_scale then
        ref.multipoint_scale:set(rage.multipoint_scale)
    end
    if ref.prefer_safepoint:get() ~= rage.prefer_safepoint then
        ref.prefer_safepoint:set(rage.prefer_safepoint)
    end
    if ref.force_safepoint:get() ~= rage.force_safepoint then
        ref.force_safepoint:set(rage.force_safepoint)
    end
    if ref.automatic_fire:get() ~= rage.automatic_fire then
        ref.automatic_fire:set(rage.automatic_fire)
    end
    if ref.automatic_penetration:get() ~= rage.automatic_penetration then
        ref.automatic_penetration:set(rage.automatic_penetration)
    end

    if ref.silent_aim:get() ~= rage.silent_aim then
        ref.silent_aim:set(rage.silent_aim)
    end
    if ref.hitchance:get() ~= rage.hitchance then
        ref.hitchance:set(rage.hitchance)
    end

    if ref.mindamage:get() ~= rage.mindamage then
        ref.mindamage:set(rage.mindamage)
    end
    if ref.automatic_scope:get() ~= rage.automatic_scope then
        ref.automatic_scope:set(rage.automatic_scope)
    end
    if ref.prefer_bodyaim:get() ~= rage.prefer_bodyaim then
        ref.prefer_bodyaim:set(rage.prefer_bodyaim)
    end

    if ref.prefer_bodyaim_disablers:get() ~= rage.prefer_bodyaim_disablers then
        ref.prefer_bodyaim_disablers:set(rage.prefer_bodyaim_disablers)
    end
    if ref.doubletap_hc:get() ~= rage.doubletap_hc then
        ref.doubletap_hc:set(rage.doubletap_hc)
    end
    
    if ref.doubletap_stop:get() ~= rage.doubletap_stop then
        ref.doubletap_stop:set(rage.doubletap_stop)
    end

    if ref.accuracy_boost:get() ~= rage.accuracy_boost then
        ref.accuracy_boost:set(rage.accuracy_boost)
    end

    if ref.quick_stop[1]:get() ~= rage.quick_stop[1] then
        ref.quick_stop[1]:set(rage.quick_stop[1])
    end
    if ref.quick_stop[2]:get() ~= rage.quick_stop[2] then
        ref.quick_stop[2]:set(rage.quick_stop[2])
    end

    if ref.delay_shot:get() ~= rage.delay_shot then
        ref.delay_shot:set(rage.delay_shot)
    end
    if ref.unsafe:get() ~= rage.unsafe then
        ref.unsafe:set(rage.unsafe)
    end
end

function setup_commanding(cmd)
    setting(cmd)
end

function export()
    local indacfg = pui.setup(menu.adaptive)
    clipboard.set(base64.encode(json.stringify(indacfg:save())))
end

function import()
    local cfg = clipboard.get()
    local indacfg = pui.setup(menu.adaptive)
    indacfg:load(json.parse(base64.decode(cfg)))
end

local x, y = client.screen_size()

local render_text = function(x, w, r, g, b, a, flags, max_width, texting)
    if(renderer.measure_text("-", "oh shit") == renderer.measure_text(flags, "oh shit")) then
        texting = string.upper(texting)
    end
    renderer.text(x, w, r, g, b, a, flags, max_width, texting)
end

local dmg = pui.reference("RAGE", "Aimbot", "Minimum damage override")
local dmgval = {pui.reference("RAGE", "Aimbot", "Minimum damage override")}

function rendering()
    if menu.md_key:get() then
        renderer.indicator(225, 225, 225, 225, "MD")
    end
    if menu.hc_key:get() then
        renderer.indicator(225, 225, 225, 225, "HC")
    end
    if menu.hb_key:get() then
        renderer.indicator(55, 235, 235, 255, "HB")
    end
    if menu.un_key:get() then
        renderer.indicator(235, 235, 55, 255, "UNSAFE")
    end
    if menu.adaptive[2].js_quick_stop_key:get() then
        renderer.indicator(225, speed_check and 55 or 225, speed_check and 55 or 225, 225, "JS")
    end
    if menu.damage_indicator:get() ~= "Disabled" or menu.damage_indicator_left:get() ~= "Disabled" then
        if menu.x_damage:get() < 0 then
            flags = "r"
        else
            flags = ""
        end
        local lp = entity.get_local_player()
        local lp_weapon = entity.get_player_weapon(lp)
        if lp_weapon == nil then return end
        local weapon_id = bit.band(entity.get_prop(entity.get_player_weapon(lp), "m_iItemDefinitionIndex"), 0xFFFF)
        if weapon_id == nil then return end
        if weapon_change ~= wpn_active() then
            weapon_change = wpn_active()
            menu.cond:set(config_names[wpn_active()])
        end
        local tab = menu.adaptive[wpn_active()]
        local mindmg_check, mindmg_val = dmgval[1]:get(), dmgval[2]:get()
        if tab ~= 11 then
            if menu.damage_indicator:get() == "On key" then
                if dmg:get_hotkey() and mindmg_check then
                    render_text(x / 2 + menu.x_damage:get(), y / 2 + menu.y_damage:get(), 255, 255, 255, 225, flags, 0, mindmg_val)
                elseif menu.md_key:get() then
                    render_text(x / 2 + menu.x_damage:get(), y / 2 + menu.y_damage:get(), 255, 255, 255, 225, flags, 0, tab.onkey_min_damage:get())
                end
            elseif menu.damage_indicator:get() == "Always on" then
                if dmg:get_hotkey() and mindmg_check then
                    render_text(x / 2 + menu.x_damage:get(), y / 2 + menu.y_damage:get(), 255, 255, 255, 225, flags, 0, mindmg_val)
                elseif menu.md_key:get() then
                    render_text(x / 2 + menu.x_damage:get(), y / 2 + menu.y_damage:get(), 255, 255, 255, 225, flags, 0, tab.onkey_min_damage:get())
                else
                    render_text(x / 2 + menu.x_damage:get(), y / 2 + menu.y_damage:get(), 255, 255, 255, 225, flags, 0, tab.min_damage:get())
                end
            end
            if menu.damage_indicator_left:get() == "On key" then
                if dmg:get_hotkey() and mindmg_check then
                    renderer.indicator(255, 255, 255, 225, "DMG: " .. mindmg_val)
                elseif menu.md_key:get() then
                    renderer.indicator(255, 255, 255, 225, "DMG: " .. tab.onkey_min_damage:get())
                end
            elseif menu.damage_indicator_left:get() == "Always on" then
                if dmg:get_hotkey() and mindmg_check then
                    renderer.indicator(255, 255, 255, 225, "DMG: " .. mindmg_val)
                elseif menu.md_key:get() then
                    renderer.indicator(255, 255, 255, 225, "DMG: " .. tab.onkey_min_damage:get())
                else
                    renderer.indicator(255, 255, 255, 225, "DMG: " .. tab.min_damage:get())
                end
            end
        end
    end
end

client.set_event_callback("paint", rendering)
client.set_event_callback("setup_command", setup_commanding)
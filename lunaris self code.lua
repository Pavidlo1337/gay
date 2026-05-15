-- ========================================================================
-- =)
-- ========================================================================
---@diagnostic disable: undefined-global, undefined-field

if not LPH_OBFUSCATED then
    LPH_NO_VIRTUALIZE = function (...) return ... end
end

LPH_NO_VIRTUALIZE(function ()
-- credits to @uwukson4800
_G.DEBUG = true
local safe do safe = { } function safe:print(...) if _DEBUG then print('[dbg] ', ...) end end function safe:require(module_name) local status, module = pcall(require, module_name) if status then return module else self:print('error while loading module "' .. module_name .. '": ' .. module) return nil end end function safe:call(func, ...) local args = { ... } local status, err = pcall(func, unpack(args)) if not status then self:print('error with ' .. func .. ' : ' .. err) end end client.set_event_callback('shutdown', function() if safe then safe = nil end if _DEBUG then _DEBUG = false end end) end

-- мало что ли дарил цветов, или мало курили на хате?
-- мало ли что ли один диалог с тобой в моём телеграме?
-- ты видишь в округе десятки типов, сравнения жизни в квадрате
-- я вижу тебя лишь одну, сотни хотели бы также
-- я много прошёл, и я разное видел: классные попы, зачётные сиськи
-- модели журналов, кассиры на рынке, фигуры с обложки, да хуй бы и с ними
-- нужен твой нежный голос, нужна ебанутая ты
-- пойду поработаю в поле, я соберу тебе все цветы

-- мы ищем друг друга в чужих лицах, твой парфюм вводит меня в паничку
-- нас слишком много, вокруг связало, живём не в мире, а в рэд флаге
-- в гике по району скитаюсь, подруги затыкали пальцем
-- нахуй змеиные рты, мы сами с тобой всё знаем
-- (мы сами с тобой всё знаем)

-- они всегда будут против меня
-- твои родители кричат: «Он наркоман!»
-- я трезвее всех трезвых, мне просто похуй, малая
-- мне просто похуй, малая (просто похуй, малая)

do
    client.exec('clear')
    client.exec('con_filter_enable 1')
    client.exec('con_filter_text \'[gamesense] / Lunaris\'')
end

-- ============================================================
-- Lunaris Splash Screen
-- Чёрный оверлей через renderer + SVG логотип
-- ============================================================

local SPLASH_DURATION   = 4.0
local FADE_IN_DURATION  = 0.8
local FADE_OUT_DURATION = 0.8
local LOGO_SIZE         = 220

-- ---- SVG-текстура логотипа ----
local svg_raw = [[<svg width="220" height="220" viewBox="0 0 680 680" xmlns="http://www.w3.org/2000/svg"><defs><radialGradient id="bgGrad" cx="50%" cy="50%" r="50%"><stop offset="0%" stop-color="#1a1035"/><stop offset="100%" stop-color="#080518"/></radialGradient><radialGradient id="moonGrad" cx="40%" cy="35%" r="55%"><stop offset="0%" stop-color="#f0e6ff"/><stop offset="60%" stop-color="#c9a8f5"/><stop offset="100%" stop-color="#8855cc"/></radialGradient><radialGradient id="glowGrad" cx="50%" cy="50%" r="50%"><stop offset="0%" stop-color="#9966ff" stop-opacity="0.35"/><stop offset="100%" stop-color="#9966ff" stop-opacity="0"/></radialGradient></defs><circle cx="340" cy="340" r="310" fill="none" stroke="#6633cc" stroke-width="1.5" opacity="0.6"/><circle cx="340" cy="340" r="300" fill="url(#bgGrad)"/><circle cx="340" cy="340" r="298" fill="none" stroke="#9966ff" stroke-width="0.8" opacity="0.4"/><circle cx="340" cy="340" r="270" fill="none" stroke="#6633cc" stroke-width="0.5" stroke-dasharray="4 6" opacity="0.5"/><circle cx="180" cy="160" r="1.8" fill="#e8d5ff" opacity="0.9"/><circle cx="250" cy="120" r="1.2" fill="#e8d5ff" opacity="0.7"/><circle cx="420" cy="140" r="2" fill="#fff" opacity="0.8"/><circle cx="490" cy="180" r="1.4" fill="#e8d5ff" opacity="0.6"/><circle cx="520" cy="240" r="1.8" fill="#fff" opacity="0.9"/><circle cx="160" cy="300" r="1.2" fill="#e8d5ff" opacity="0.7"/><circle cx="200" cy="400" r="1.5" fill="#fff" opacity="0.6"/><circle cx="155" cy="460" r="1" fill="#e8d5ff" opacity="0.5"/><circle cx="500" cy="310" r="1.2" fill="#e8d5ff" opacity="0.6"/><circle cx="530" cy="400" r="1.8" fill="#fff" opacity="0.7"/><circle cx="450" cy="480" r="1.3" fill="#e8d5ff" opacity="0.6"/><circle cx="380" cy="520" r="1" fill="#fff" opacity="0.5"/><circle cx="260" cy="490" r="1.5" fill="#e8d5ff" opacity="0.7"/><path d="M420 140l2 8 8 2-8 2-2 8-2-8-8-2 8-2z" fill="#fff" opacity="0.85"/><path d="M180 260l1.5 5 5.5 2-5.5 2-1.5 5-1.5-5-5.5-2 5.5-2z" fill="#c9a8f5" opacity="0.7"/><path d="M510 430l1.5 5 5.5 2-5.5 2-1.5 5-1.5-5-5.5-2 5.5-2z" fill="#fff" opacity="0.6"/><path d="M230 520l1.5 5 5.5 2-5.5 2-1.5 5-1.5-5-5.5-2 5.5-2z" fill="#c9a8f5" opacity="0.5"/><circle cx="340" cy="320" r="115" fill="url(#glowGrad)"/><circle cx="340" cy="320" r="95" fill="url(#moonGrad)"/><circle cx="370" cy="307" r="78" fill="#1a1035" opacity="0.88"/><circle cx="292" cy="295" r="7" fill="none" stroke="#c9a8f5" stroke-width="1" opacity="0.35"/><circle cx="308" cy="338" r="4.5" fill="none" stroke="#c9a8f5" stroke-width="0.8" opacity="0.3"/><circle cx="275" cy="330" r="5" fill="none" stroke="#c9a8f5" stroke-width="0.8" opacity="0.25"/><path d="M160 340A180 180 0 0 1 520 340" fill="none" stroke="#6633cc" stroke-width="0.8" opacity="0.4"/><circle cx="163" cy="330" r="2.5" fill="#9966ff" opacity="0.7"/><circle cx="517" cy="330" r="2.5" fill="#9966ff" opacity="0.7"/><circle cx="340" cy="162" r="2.5" fill="#9966ff" opacity="0.7"/><circle cx="340" cy="52" r="3" fill="#9966ff" opacity="0.5"/><circle cx="340" cy="628" r="3" fill="#9966ff" opacity="0.5"/><circle cx="52" cy="340" r="3" fill="#9966ff" opacity="0.5"/><circle cx="628" cy="340" r="3" fill="#9966ff" opacity="0.5"/></svg>]]

local _tex           = nil
local _start         = nil
local _done          = false

local function smoothstep(t)
    if t <= 0 then return 0 end
    if t >= 1 then return 1 end
    return t * t * (3 - 2 * t)
end

local function get_alpha()
    local e = globals.realtime() - _start
    if e >= SPLASH_DURATION then return 0, true end
    local t
    if e < FADE_IN_DURATION then
        t = e / FADE_IN_DURATION
    elseif e > (SPLASH_DURATION - FADE_OUT_DURATION) then
        t = (SPLASH_DURATION - e) / FADE_OUT_DURATION
    else
        t = 1.0
    end
    return smoothstep(t), false
end

client.set_event_callback('paint_ui', function()
    if _done then return end

    -- Грузим текстуру в первом paint-кадре
    if not _tex then
        _tex = renderer.load_svg(svg_raw, LOGO_SIZE, LOGO_SIZE)
        if _tex then
            _start = globals.realtime()
        else
            _done = true
            return
        end
    end

    local t, done = get_alpha()

    if done then
        _done = true
        return
    end

    local ia = math.floor
    local sw, sh = client.screen_size()

    -- Рисуем затемнение ЧЕРЕЗ RENDERER (работает надёжнее Panorama)
    -- Используем чёрный прямоугольник на весь экран
    local bg_alpha = ia(255 * t)
    renderer.rectangle(0, 0, sw, sh, 0, 0, 0, bg_alpha)

    -- Рисуем SVG логотип по центру
    local lx = ia((sw - LOGO_SIZE) / 2)
    local ly = ia((sh - LOGO_SIZE) / 2) - 24
    renderer.texture(_tex, lx, ly, LOGO_SIZE, LOGO_SIZE, 255, 255, 255, ia(255 * t))

    -- Надпись LUNARIS
    local ty = ly + LOGO_SIZE + 10
    renderer.text(ia(sw / 2), ty,      136, 93,  252, ia(220 * t), 'c+b', 0, 'LUNARIS')
    renderer.text(ia(sw / 2), ty + 24, 180, 140, 255, ia(140 * t), 'c-',  0, 'Loading script...')
end)


local ffi           = safe:require ('ffi')

ffi.cdef[[
    typedef struct
    {
        uint8_t r;
        uint8_t g;
        uint8_t b;
        uint8_t a;
    } color_struct_t;
    typedef void (__cdecl* print_function)(void*, color_struct_t&, const char* text, ...);
]]
local uintptr_t = ffi.typeof("uintptr_t**")
local color_struct_t = ffi.typeof("color_struct_t")

local color_print = (function()local b=function(c,d)c=tostring(c)local e=ffi.cast(uintptr_t,client.create_interface("vstdlib.dll","VEngineCvar007"))local f=ffi.cast("print_function",e[0][25])f(e,color_struct_t(d.r,d.g,d.b,d.a),c)end;return b end)()
local function log(b)color_print("Script\0",color_struct_t(136, 93, 252,255))color_print("leaks \0",color_struct_t(200,200,200,255))color_print('~ \0',color_struct_t(136, 93, 252,255))color_print(b,color_struct_t(200,200,200,255))color_print('\n',color_struct_t(200,200,200,0))end
log("https://discord.gg/BnjptXcSt")

local vector        = safe:require ('vector')

local http          = safe:require ('gamesense/http')
local pui           = safe:require ('gamesense/pui')
local base64        = safe:require ('gamesense/base64')
local clipboard     = safe:require ('gamesense/clipboard')
local aa_func       = safe:require ('gamesense/antiaim_funcs')
local trace         = safe:require ('gamesense/trace')
local csgo_weapons  = safe:require ('gamesense/csgo_weapons')
local steamworks    = safe:require ('gamesense/steamworks')
local localize      = safe:require ('gamesense/localize')
local chat          = safe:require ('gamesense/chat')

local exploits=(function()local classes={ }function class(name)return function(tab)if not tab then return classes[name]end tab.__index,tab.__classname=tab,name if tab.call then tab.__call=tab.call end setmetatable(tab,tab)classes[name],_G[name]=tab,tab return tab end end local g_ctx={local_player=nil,weapon=nil,aimbot=ui.reference("RAGE","Aimbot","Enabled"),doubletap={ui.reference("RAGE","Aimbot","Double tap")},hideshots={ui.reference("AA","Other","On shot anti-aim")},fakeduck=ui.reference("RAGE","Other","Duck peek assist")}local clamp=function(value,min,max)return math.min(math.max(value,min),max)end class"exploits"{max_process_ticks=(math.abs(client.get_cvar("sv_maxusrcmdprocessticks")or 16)-1),tickbase_difference=0,ticks_processed=0,command_number=0,choked_commands=0,need_force_defensive=false,current_shift_amount=0,reset_vars=function(self)self.ticks_processed=0 self.tickbase_difference=0 self.choked_commands=0 self.command_number=0 end,store_vars=function(self,ctx)self.command_number=ctx.command_number or 0 self.choked_commands=ctx.chokedcommands or 0 end,store_tickbase_difference=function(self,ctx)if ctx.command_number==self.command_number then local tickbase=entity.get_prop(g_ctx.local_player,"m_nTickBase")or 0 self.ticks_processed=clamp(math.abs(tickbase-(self.tickbase_difference or 0)),0,(self.max_process_ticks or 0)-(self.choked_commands or 0))self.tickbase_difference=math.max(tickbase,self.tickbase_difference or 0)self.command_number=0 end end,is_doubletap=function(self)return ui.get(g_ctx.doubletap[2])end,is_hideshots=function(self)return ui.get(g_ctx.hideshots[2])end,is_active=function(self)return self:is_doubletap()or self:is_hideshots()end,in_defensive=function(self,max)max=max or self.max_process_ticks return self:is_active()and(self.ticks_processed>1 and self.ticks_processed<max)end,is_defensive_ended=function(self)return not self:in_defensive()or((self.ticks_processed>=0 and self.ticks_processed<=5)and(self.tickbase_difference or 0)>0)end,is_lagcomp_broken=function(self)local tickbase=entity.get_prop(g_ctx.local_player,"m_nTickBase")or 0 return not self:is_defensive_ended()or(self.tickbase_difference or 0)<tickbase end,can_recharge=function(self)if not self:is_active()then return false end local tickbase=entity.get_prop(g_ctx.local_player,"m_nTickBase")or 0 local curtime=globals.tickinterval()*(tickbase-16)if curtime<(entity.get_prop(g_ctx.local_player,"m_flNextAttack")or 0)then return false end if curtime<(entity.get_prop(g_ctx.weapon,"m_flNextPrimaryAttack")or 0)then return false end return true end,in_recharge=function(self)if not(self:is_active()and self:can_recharge())or self:in_defensive()then return false end local latency_shift=math.ceil(toticks(client.latency())*1.25)local current_shift_amount=(((self.tickbase_difference or 0)-globals.tickcount())*-1)+latency_shift local max_shift_amount=(self.max_process_ticks-1)-latency_shift local min_shift_amount=-(self.max_process_ticks-1)+latency_shift if latency_shift~=0 then return current_shift_amount>min_shift_amount and current_shift_amount<max_shift_amount else return current_shift_amount>(min_shift_amount/2)and current_shift_amount<(max_shift_amount/2)end end,should_force_defensive=function(self,state)if not self:is_active()then return false end self.need_force_defensive=state and self:is_defensive_ended()end,charge_ticks=14,charge_timer=globals.tickcount(),allow_unsafe_charge=function(self,state)if not(self:is_active()--[[and self:can_recharge()]])then self.charge_timer=globals.tickcount()ui.set(g_ctx.aimbot,true)return end if not state then self.charge_timer=globals.tickcount()ui.set(g_ctx.aimbot,true)return end if ui.get(g_ctx.fakeduck)then ui.set(g_ctx.aimbot,true)return end if globals.tickcount()>=self.charge_timer+self.charge_ticks then ui.set(g_ctx.aimbot,true)else ui.set(g_ctx.aimbot,false)end end,force_reload_exploits=function(self,state)if not state then ui.set(g_ctx.doubletap[1],true)ui.set(g_ctx.hideshots[1],true)return end if self:is_doubletap()and not self:in_recharge()then ui.set(g_ctx.doubletap[1],false)else ui.set(g_ctx.doubletap[1],true)end if self:is_hideshots()and not self:in_recharge()then ui.set(g_ctx.hideshots[1],false)else ui.set(g_ctx.hideshots[1],true)end end}local event_list={on_setup_command=function(ctx)if not(entity.get_local_player()and entity.is_alive(entity.get_local_player())and entity.get_player_weapon(entity.get_local_player()))then return end g_ctx.local_player=entity.get_local_player()g_ctx.weapon=entity.get_player_weapon(g_ctx.local_player)if exploits.need_force_defensive then ctx.force_defensive=true end end,on_run_command=function(ctx)exploits:store_vars(ctx)end,on_predict_command=function(ctx)exploits:store_tickbase_difference(ctx)end,on_player_death=function(ctx)if not(ctx.userid and ctx.attacker)then return end if g_ctx.local_player~=client.userid_to_entindex(ctx.userid)then return end exploits:reset_vars()end,on_level_init=function()exploits:reset_vars()end,on_round_start=function()exploits:reset_vars()end,on_round_end=function()exploits:reset_vars()end,on_shutdown=function()collectgarbage("collect")end}for k,v in next,event_list do client.set_event_callback(k:sub(4),function(ctx)v(ctx)end)end return exploits end)()

local reference = {
    rage = {
        aimbot = {
            enabled = { pui.reference('rage', 'aimbot', 'enabled') },
            target_hitbox = pui.reference('rage', 'aimbot', 'target hitbox'),
            minimum_damage = pui.reference('rage', 'aimbot', 'minimum damage'),
            minimum_damage_override = { pui.reference('rage', 'aimbot', 'minimum damage override') },
            minimum_hitchance = pui.reference('rage', 'aimbot', 'minimum hit chance'),
            double_tap = { pui.reference('rage', 'aimbot', 'double tap') },
            double_tap_limit = pui.reference('rage', 'aimbot', 'double tap fake lag limit'),
            force_body = pui.reference('rage', 'aimbot', 'force body aim'),
            force_safe = pui.reference('rage', 'aimbot', 'force safe point'),
            auto_scope = pui.reference('rage', 'aimbot', 'automatic scope')
        },
      
        other = {
            quickpeek = { pui.reference('rage', 'other', 'quick peek assist') },
            quickpeek_assist_mode = { pui.reference('rage', 'other', 'quick peek assist mode') },
            quickpeek_assist_distance = pui.reference('rage', 'other', 'quick peek assist distance'),
            fake_duck = pui.reference('rage', 'other', 'duck peek assist'),
            log_spread = pui.reference('rage', 'other', 'log misses due to spread'),
        },

        ps = { pui.reference('misc', 'miscellaneous', 'ping spike') },
        log_hit = pui.reference('misc', 'miscellaneous', 'log damage dealt'),
        log_purchases = pui.reference('misc', 'miscellaneous', 'log weapon purchases')
    },
  
    antiaim = {
        angles = {
            enabled = pui.reference('aa', 'anti-aimbot angles', 'enabled'),
            pitch = { pui.reference('aa', 'anti-aimbot angles', 'pitch') },
            yaw = { pui.reference('aa', 'anti-aimbot angles', 'yaw') },
            yaw_base = pui.reference('aa', 'anti-aimbot angles', 'yaw base'),
            yaw_jitter = { pui.reference('aa', 'anti-aimbot angles', 'yaw jitter') },
            body_yaw = { pui.reference('aa', 'anti-aimbot angles', 'body yaw') },
            fs_body_yaw = pui.reference('aa', 'anti-aimbot angles', 'freestanding body yaw'),
            edge_yaw = pui.reference('aa', 'anti-aimbot angles', 'edge yaw'),
            freestanding = { pui.reference('aa', 'anti-aimbot angles', 'freestanding') },
            roll = pui.reference('aa', 'anti-aimbot angles', 'roll')
        },
        fakelag = {
            enabled = pui.reference('aa', 'fake lag', 'enabled'),
            amount = pui.reference('aa', 'fake lag', 'amount'),
            variance = pui.reference('aa', 'fake lag', 'variance'),
            limit = pui.reference('aa', 'fake lag', 'limit')
        },
        other = {
            on_shot_anti_aim = { pui.reference('aa', 'other', 'on shot anti-aim') },
            slow_motion = { pui.reference('aa', 'other', 'slow motion') },
            fake_peek = { pui.reference('aa', 'other', 'fake peek') },
            leg_movement = pui.reference('aa', 'other', 'leg movement')
        }
    },
  
    visuals = {
        scope = pui.reference('visuals', 'effects', 'remove scope overlay'),
        thirdperson = pui.reference('visuals', 'effects', 'force third person (alive)')
    },
  
    misc = {
        miscellaneous = {
            override_zoom_fov = pui.reference('misc', 'miscellaneous', 'override zoom fov'),
            draw_console_output = pui.reference('misc', 'miscellaneous', 'draw console output')
        },
    
        settings = {
            menu_color = pui.reference('misc', 'settings', 'menu color'),
            anti_untrusted = pui.reference('misc', 'settings', 'anti-untrusted')
        },
    
        movement = {
            air_strafe = pui.reference('misc', 'movement', 'air strafe')
        }
    },
  
    playerlist = {
        players = pui.reference('Players', 'Players', 'Player list'),
        force_body = pui.reference('Players', 'Adjustments', 'Force body yaw'),
        force_body_value = pui.reference('Players', 'Adjustments', 'Force body yaw value'),
        reset = pui.reference('Players', 'Players', 'Reset all')
    }
} do
    defer(function () 
        pui.traverse(reference, function (ref)
            ref:override()
            ref:set_enabled(true)
            if ref.hotkey then ref.hotkey:set_enabled(true) end
        end)
    end) 

    reference.antiaim.angles.yaw[2]:depend({reference.antiaim.angles.yaw[1], 1488}, {reference.antiaim.angles.yaw[2], 1488})
    reference.antiaim.angles.pitch[2]:depend({reference.antiaim.angles.pitch[1], 1488}, {reference.antiaim.angles.pitch[2], 1488})
    reference.antiaim.angles.yaw_jitter[1]:depend({reference.antiaim.angles.yaw[1], 1488}, {reference.antiaim.angles.yaw[2], 1488})
    reference.antiaim.angles.yaw_jitter[2]:depend({reference.antiaim.angles.yaw[1], 1488}, {reference.antiaim.angles.yaw[2], 1488}, {reference.antiaim.angles.yaw_jitter[1], 1488}, {reference.antiaim.angles.yaw_jitter[2], 1488})
    reference.antiaim.angles.body_yaw[2]:depend({reference.antiaim.angles.body_yaw[1], 1488})
    reference.antiaim.angles.fs_body_yaw:depend({reference.antiaim.angles.body_yaw[1], 1488})
    pui.traverse(reference.antiaim.angles, function (ref)
        ref:depend({reference.antiaim.angles.enabled, 1488})
        if ref.hotkey then ref.hotkey:depend({reference.antiaim.angles.enabled, 1488}) end
    end)
end

local animations = { }

local function lerp (name, target_value, speed, tolerance, easing_style)
    if animations[name] == nil then
        animations[name] = target_value
    end

    speed = speed or 8
    tolerance = tolerance or 0.005
    easing_style = easing_style or 'linear'
    
    local current_value = animations[name]
    local delta = globals.absoluteframetime() * speed
    local new_value
    
    if easing_style == 'linear' then
        new_value = current_value + (target_value - current_value) * delta
    elseif easing_style == 'smooth' then
        new_value = current_value + (target_value - current_value) * (delta * delta * (3 - 2 * delta))
    elseif easing_style == 'ease_in' then
        new_value = current_value + (target_value - current_value) * (delta * delta)
    elseif easing_style == 'ease_out' then
        local progress = 1 - (1 - delta) * (1 - delta)
        new_value = current_value + (target_value - current_value) * progress
    elseif easing_style == 'ease_in_out' then
        local progress = delta < 0.5 and 2 * delta * delta or 1 - math.pow(-2 * delta + 2, 2) / 2
        new_value = current_value + (target_value - current_value) * progress
    else
        new_value = current_value + (target_value - current_value) * delta
    end

    if math.abs(target_value - new_value) <= tolerance then
        animations[name] = target_value
    else
        animations[name] = new_value
    end
    
    return animations[name]
end

local coloring = { }

coloring.rgba_to_hex = function (r, g, b, a)
    return string.format('%.2x%.2x%.2x%.2x', r, g, b, a):upper()
end

coloring.accent = coloring.rgba_to_hex(reference.misc.settings.menu_color:get())
coloring.reset = '9D9D9DFF'
coloring.default = 'CDCDCDFF'

coloring.init = function ()
    local r, g, b, a = reference.misc.settings.menu_color:get()
    coloring.accent = coloring.rgba_to_hex(r, g, b, a)
    return coloring.accent
end

coloring.set_color_macro = function (use_reset, alpha)
    if use_reset then
        return coloring.reset
    end
    local r, g, b, a = reference.misc.settings.menu_color:get()
    if alpha ~= nil and alpha >= 0 and alpha <= 255 then
        return string.format('%.2x%.2x%.2x%.2x', r, g, b, alpha):upper()
    else
        return coloring.rgba_to_hex(r, g, b, a)
    end
end

local function lazy_lerp (a, b, t)
    return a + (b - a) * (t * t * (3 - 2 * t))
end

local function lerp_color (c1, c2, t)
    return {
        r = lazy_lerp(c1.r, c2.r, t),
        g = lazy_lerp(c1.g, c2.g, t),
        b = lazy_lerp(c1.b, c2.b, t),
        a = lazy_lerp(c1.a, c2.a, t)
    }
end

local cached_colors = { }
local last_cache_time = -1

local function prepare_gradient_cache (speed, col1_start, col1_end, col2_start, col2_end, vertical, w, h)
    local time = globals.realtime() * speed * 0.2
    local steps = 16
    local single_mode = not (w and h)

    if not single_mode then
        steps = vertical and h or w
    end

    if cached_colors.steps == steps and cached_colors.single_mode == single_mode and math.abs(time - last_cache_time) < 0.02 then
        return cached_colors.data
    end

    last_cache_time = time
    cached_colors.steps = steps
    cached_colors.single_mode = single_mode
    cached_colors.data = { }

    if single_mode then
        local t1 = (math.sin(time * 0.5) + 1) * 0.5
        local t2 = (math.cos(time * 0.5) + 1) * 0.5

        local c_a = lerp_color(col1_start, col1_end, t1)
        local c_b = lerp_color(col2_start, col2_end, t2)

        local blend_t = (math.sin(time) + 1) * 0.5
        local final_color = lerp_color(c_a, c_b, blend_t)

        cached_colors.data = final_color
    else
        for i = 0, steps do
            local offset = steps > 0 and (i / steps) or 0

            local t1 = (math.sin(time * 0.5 + offset * math.pi * 2) + 1) * 0.5
            local t2 = (math.cos(time * 0.5 + offset * math.pi * 2) + 1) * 0.5

            local c_a = lerp_color(col1_start, col1_end, t1)
            local c_b = lerp_color(col2_start, col2_end, t2)

            local blend_t = (math.sin(time + offset * math.pi) + 1) * 0.5
            local final_color = lerp_color(c_a, c_b, blend_t)

            cached_colors.data[i] = final_color
        end
    end

    return cached_colors.data
end

local function draw_animated_gradient (x, y, w, h, speed, col1_start, col1_end, col2_start, col2_end, vertical, direction_up)
    local steps = vertical and h or w
    local colors = prepare_gradient_cache(speed, col1_start, col1_end, col2_start, col2_end, vertical, w, h)

    local step_size = 2

    for i = 0, steps, step_size do
        local color = colors[i] or colors[#colors]
        local r, g, b, a = color.r, color.g, color.b, color.a

        if vertical then
            local draw_y = direction_up and (y + (h - i)) or (y + i)
            renderer.rectangle(x, draw_y, w, step_size, r, g, b, a)
        else
            local draw_x = direction_up and (x + (w - i)) or (x + i)
            renderer.rectangle(draw_x, y, step_size, h, r, g, b, a)
        end
    end
end

local function draw_gradient_text (x, y, flags, max_width, text, speed, col1_start, col1_end, col2_start, col2_end)
    local time = globals.realtime() * speed * 0.2
    local text_len = #text
    if text_len == 0 then return x end

    local final_text = { }
    final_text[#final_text + 1] = ''

    local time_sin = time * 0.5
    local time_cos = time * 0.5
    local base_sin = math.sin(time)
    
    for i = 1, text_len do
        local char = text:sub(i, i)
        local offset = (i - 1) / text_len

        local t1 = (math.sin(time_sin + offset * math.pi * 2) + 1) * 0.5
        local t2 = (math.cos(time_cos + offset * math.pi * 2) + 1) * 0.5

        local c_a = lerp_color(col1_start, col1_end, t1)
        local c_b = lerp_color(col2_start, col2_end, t2)

        local blend_t = (math.sin(time + offset * math.pi) + 1) * 0.5
        local final_color = lerp_color(c_a, c_b, blend_t)

        local hex_color = coloring.rgba_to_hex(
            final_color.r + 0.5,
            final_color.g + 0.5,
            final_color.b + 0.5,
            final_color.a + 0.5
        )

        final_text[#final_text + 1] = '\a'
        final_text[#final_text + 1] = hex_color
        final_text[#final_text + 1] = char
    end

    local rendered_text = table.concat(final_text)
    renderer.text(x, y, 255, 255, 255, col1_start.a, flags, max_width, rendered_text)
    local w, _ = renderer.measure_text(flags, rendered_text)
    return x + w
end


local is_on_ground = false do
    local pre, post = 0, 0
    local function on_setup_command ()
        local me = entity.get_local_player()
        if not me or not entity.is_alive(me) then 
            return 
        end

        pre = entity.get_prop(me, 'm_fFlags')
    end

    local function on_run_command ()
        local me = entity.get_local_player()
        if not me or not entity.is_alive(me) then 
            return 
        end

        post = entity.get_prop(me, 'm_fFlags')
        is_on_ground = bit.band(pre, 1) == 1 and bit.band(post, 1) == 1
    end

    client.set_event_callback('setup_command', on_setup_command)
    client.set_event_callback('run_command', on_run_command)
end

local ticks = 0
local helpers = {
    rounded_rectangle = function (x, y, w, h, rounding, r, g, b, a, gradient_colors)
        y = y + rounding
        gradient_colors = gradient_colors or { use_gradient = false }

        local data_circle = {
            {x + rounding, y, 180},
            {x + w - rounding, y, 90},
            {x + rounding, y + h - rounding * 2, 270},
            {x + w - rounding, y + h - rounding * 2, 0}
        }
    
        local data = {
            {x + rounding, y, w - rounding * 2, h - rounding * 2},
            {x + rounding, y - rounding, w - rounding * 2, rounding},
            {x + rounding, y + h - rounding * 2, w - rounding * 2, rounding},
            {x, y, rounding, h - rounding * 2},
            {x + w - rounding, y, rounding, h - rounding * 2}
        }
    
        for _, data in next, data_circle do
            if gradient_colors.use_gradient then
                local t1 = (math.sin(globals.realtime() * 25 * 0.2 * 0.5 + data[3] * math.pi * 2) + 1) / 2
                local t2 = (math.sin(globals.realtime() * 25 * 0.2 * 0.5 + data[3] * math.pi * 2) + 1) / 2

                local c_a = lerp_color(gradient_colors.col1_start, gradient_colors.col1_end, t1)
                local c_b = lerp_color(gradient_colors.col2_start, gradient_colors.col2_end, t2)

                local blend_t = (math.sin(25 + 50 * math.pi) + 1) / 2
                local final_color = lerp_color(c_a, c_b, blend_t)
    
                renderer.circle(data[1], data[2], final_color.r, final_color.g, final_color.b, final_color.a, rounding, data[3], 0.25)
            else
                renderer.circle(data[1], data[2], r, g, b, a, rounding, data[3], 0.25)
            end
        end

        for _, data in next, data do
            if gradient_colors.use_gradient then
                draw_animated_gradient(data[1], data[2], data[3], data[4], 25,
                    gradient_colors.col1_start,
                    gradient_colors.col1_end,
                    gradient_colors.col2_start,
                    gradient_colors.col2_end,
                    false
                )
            else
                renderer.rectangle(data[1], data[2], data[3], data[4], r, g, b, a)
            end
        end
    end,

    semi_outlined_rectangle = function (x, y, w, h, rounding, thickness, gradient_colors, reverse)
        reverse = reverse or false
        rounding = math.min(rounding, w / 2, h / 2)
        
        if reverse then
            y = y - rounding + 1
        else
            y = y + rounding
        end
    
        local data_circle = {
            {x + rounding, y + (reverse and 0 or h - rounding + 1), reverse and 180 or 90},
            {x + w - rounding, y + (reverse and 0 or h - rounding + 1), reverse and 270 or 0}
        }
    
        local data = {
            {x + rounding, y + (reverse and -rounding or h - thickness + 1), w - rounding * 2, thickness},
        }
    
        local base = gradient_colors.col1_start
        local color_cache
        if gradient_colors.use_gradient then
            color_cache = prepare_gradient_cache(25,
                gradient_colors.col1_start,
                gradient_colors.col1_end,
                gradient_colors.col2_start,
                gradient_colors.col2_end,
                false,
                w, 1
            )
        end

        for _, circle in pairs(data_circle) do
            if gradient_colors.use_gradient then
                local offset = (circle[1] - x) / w
                local step_index = math.floor(offset * w)
                local final_color = color_cache[step_index] or base
                renderer.circle_outline(circle[1], circle[2], final_color.r, final_color.g, final_color.b, final_color.a, rounding, circle[3], 0.25, thickness)
            else
                renderer.circle_outline(circle[1], circle[2], base.r, base.g, base.b, base.a, rounding, circle[3], 0.25, thickness)
            end
        end

        for _, rect in pairs(data) do
            if gradient_colors.use_gradient then
                draw_animated_gradient(rect[1], rect[2], rect[3], rect[4], 25,
                    gradient_colors.col1_start,
                    gradient_colors.col1_end,
                    gradient_colors.col2_start,
                    gradient_colors.col2_end,
                    false
                )
            else
                renderer.rectangle(rect[1], rect[2], rect[3], rect[4], base.r, base.g, base.b, base.a)
            end
        end
    
        local gradient_y = reverse and y - (h - rounding - thickness - 20) or y + thickness + 9
        local gradient_height = h - rounding - thickness - 20
        if gradient_colors.use_gradient then
            if reverse then
                local color = prepare_gradient_cache(25,
                    {r = gradient_colors.col1_start.r, g = gradient_colors.col1_start.g, b = gradient_colors.col1_start.b, a = 0},
                    {r = gradient_colors.col1_end.r, g = gradient_colors.col1_end.g, b = gradient_colors.col1_end.b, a = 0},
                    {r = gradient_colors.col2_start.r, g = gradient_colors.col2_start.g, b = gradient_colors.col2_start.b, a = gradient_colors.col2_start.a},
                    {r = gradient_colors.col2_end.r, g = gradient_colors.col2_end.g, b = gradient_colors.col2_end.b, a = gradient_colors.col2_end.a}, 
                    true
                )

                renderer.gradient(x, gradient_y, thickness, gradient_height, color.r, color.g, color.b, 0, color.r, color.g, color.b, base.a, false)
                renderer.gradient(x + w - thickness, gradient_y, thickness, gradient_height, color.r, color.g, color.b, 0, color.r, color.g, color.b, base.a, false)
            else
                local color = prepare_gradient_cache(25,
                    {r = gradient_colors.col1_start.r, g = gradient_colors.col1_start.g, b = gradient_colors.col1_start.b, a = gradient_colors.col1_start.a},
                    {r = gradient_colors.col1_end.r, g = gradient_colors.col1_end.g, b = gradient_colors.col1_end.b, a = gradient_colors.col1_end.a},
                    {r = gradient_colors.col2_start.r, g = gradient_colors.col2_start.g, b = gradient_colors.col2_start.b, a = 0},
                    {r = gradient_colors.col2_end.r, g = gradient_colors.col2_end.g, b = gradient_colors.col2_end.b, a = 0}, 
                    true
                )

                renderer.gradient(x, gradient_y, thickness, gradient_height, color.r, color.g, color.b, base.a, color.r, color.g, color.b, 0, false)
                renderer.gradient(x + w - thickness, gradient_y, thickness, gradient_height, color.r, color.g, color.b, base.a, color.r, color.g, color.b, 0, false)
            end
        else
            if reverse then
                renderer.gradient(x, gradient_y, thickness, gradient_height, base.r, base.g, base.b, 0, base.r, base.g, base.b, base.a, false)
                renderer.gradient(x + w - thickness, gradient_y, thickness, gradient_height, base.r, base.g, base.b, 0, base.r, base.g, base.b, base.a, false)
            else
                renderer.gradient(x, gradient_y, thickness, gradient_height, base.r, base.g, base.b, base.a, base.r, base.g, base.b, 0, false)
                renderer.gradient(x + w - thickness, gradient_y, thickness, gradient_height, base.r, base.g, base.b, base.a, base.r, base.g, base.b, 0, false)
            end
        end
    end,
    
    rounded_outlined_rectangle = function (x, y, w, h, rounding, thickness, r, g, b, a)
        y = y + rounding
        local data_circle = {
            {x + rounding, y, 180},
            {x + w - rounding, y, 270},
            {x + rounding, y + h - rounding * 2, 90},
            {x + w - rounding, y + h - rounding * 2, 0}
        }
    
        local data = {
            {x + rounding, y - rounding, w - rounding * 2, thickness},
            {x + rounding, y + h - rounding - thickness, w - rounding * 2, thickness},
            {x, y, thickness, h - rounding * 2},
            {x + w - thickness, y, thickness, h - rounding * 2}
        }
    
        for _, data in next, data_circle do
            renderer.circle_outline(data[1], data[2], r, g, b, a, rounding, data[3], 0.25, thickness)
        end
    
        for _, data in next, data do
            renderer.rectangle(data[1], data[2], data[3], data[4], r, g, b, a)
        end
    end,

    get_state = function ()
        local me = entity.get_local_player()
        if not entity.is_alive(me) then 
            return 'Global' 
        end

        local vel = {entity.get_prop(me, 'm_vecVelocity')}
        local velocity = vector(vel[1] or 0, vel[2] or 0, 0)
        local speed = velocity:length2d()

        local ground_entity = entity.get_prop(me, 'm_hGroundEntity')
        local is_on_player = ground_entity ~= 0 and entity.get_classname(ground_entity) == 'CCSPlayer'
        ticks = (ground_entity == 0) and (ticks + 1) or 0

        if is_on_player then
            is_on_ground = true
        end

        if not is_on_ground then 
            return (entity.get_prop(me, 'm_flDuckAmount') == 1) and 'Air+' or 'Air'
        end

        if is_on_ground and (entity.get_prop(me, 'm_flDuckAmount') == 1 or reference.rage.other.fake_duck:get()) then
            return (speed > 10) and 'Sneak' or 'Crouch'
        end

        return (speed > 10) and (reference.antiaim.other.slow_motion[1].hotkey:get() and 'Walk' or 'Run') or 'Stand'
    end,

    get_freestand_direction = function (player)
        local data = {
            side = 1,
            last_side = 0,
            last_hit = 0,
            hit_side = 0
        }
    
        if not player or entity.get_prop(player, 'm_lifeState') ~= 0 then
            return
        end
    
        if data.hit_side ~= 0 and globals.curtime() - data.last_hit > 5 then
            data.last_side = 0
            data.last_hit = 0
            data.hit_side = 0
        end
    
        local eye = vector(client.eye_position())
        local ang = vector(client.camera_angles())
        local trace_data = {left = 0, right = 0}
    
        for i = ang.y - 120, ang.y + 120, 30 do
            if i ~= ang.y then
                local rad = math.rad(i)
                local px, py, pz = eye.x + 256 * math.cos(rad), eye.y + 256 * math.sin(rad), eye.z
                local fraction = client.trace_line(player, eye.x, eye.y, eye.z, px, py, pz)
                local side = i < ang.y and 'left' or 'right'
                trace_data[side] = trace_data[side] + fraction
            end
        end
    
        data.side = trace_data.left < trace_data.right and -1 or 1
    
        if data.side == data.last_side then
            return
        end
    
        data.last_side = data.side
    
        if data.hit_side ~= 0 then
            data.side = data.hit_side
        end
    
        return data.side
    end
}

function helpers:clamp (value, min, max) 
    return math.max(min, math.min(value, max)) 
end

local function table_contains (tbl, val)
    for _, v in ipairs(tbl) do
      if v == val then
        return true
      end
    end
    return false
end

local function screen_size_x ()
    return select(1, client.screen_size()) or 1920
end

local function screen_size_y ()
    return select(2, client.screen_size()) or 1080
end

local drag_system = {
    elements = { },
    dragging = nil,
    drag_start_pos = { x = 0, y = 0 },
    last_alpha = 0,
    guide_alpha = 0,
    dot_alpha = 0,
    animate_menu = 0
}

function drag_system:get_width()
    local w = self.element.w
    return type(w) == 'function' and w() or w
end

function drag_system:get_height()
    local h = self.element.h
    return type(h) == 'function' and h() or h
end

function drag_system.new (name, x_slider, y_slider, default_x, default_y, drag_axes, options)
    local self = setmetatable({ }, { __index = drag_system })

    self.name = name
    self.x_slider = x_slider
    self.y_slider = y_slider

    self.element = {
        default_x = default_x,
        default_y = default_y,
        w = options and (options.w or 60) or 60,
        h = options and (options.h or 20) or 20,
        align_x = options and options.align_x or 'center',  -- @lordmouse: left/center/right
        align_y = options and options.align_y or 'center',  -- @lordmouse: top/center/bottom
        expand_dir = options and options.expand_dir or 'right' -- @lordmouse: right/left
    }

    self.drag_axes = drag_axes:lower()
    self.options = {
        show_guides = options and options.show_guides,
        show_highlight = options and options.show_highlight,
        show_default_dot = options and options.show_default_dot,
        align_center = options and options.align_center,
        show_center_dot = options and options.show_center_dot,
        snap_distance = options and options.snap_distance,
        highlight_color = options and options.highlight_color or {150, 150, 150, 80}
    }

    self.hover_progress = 0
    self.click_progress = 0
    self.last_screen_w = screen_size_x()
    self.last_screen_h = screen_size_y()
    self.relative_x = x_slider and (x_slider:get() / self.last_screen_w) or (default_x / self.last_screen_w)
    self.relative_y = y_slider and (y_slider:get() / self.last_screen_h) or (default_y / self.last_screen_h)

    table.insert(drag_system.elements, self)
    return self
end

function drag_system:clamp_position (x, y, screen_w, screen_h, elem_w, elem_h)
    if self.element.expand_dir == 'left' then
        x = helpers:clamp(x, elem_w, screen_w)
    else
        x = helpers:clamp(x, 0, screen_w - elem_w)
    end
    
    y = helpers:clamp(y, 0, screen_h - elem_h)
    return x, y
end

function drag_system:get_pos ()
    local elem_w, elem_h = self:get_width(), self:get_height()

    local x = self.x_slider and self.x_slider:get() or self.element.default_x
    local y = self.y_slider and self.y_slider:get() or self.element.default_y

    if self.element.expand_dir == 'left' then
        x = x - elem_w
    elseif not self.x_slider then
        x = math.floor(x - elem_w / 2 + 1)
    end

    if not self.y_slider then
        y = math.floor(y - elem_h / 2 + 0.5)
    end

    return x, y
end

function drag_system:update (alpha)
    if not ui.is_menu_open() or alpha < 100 then return end

    local screen_w, screen_h = screen_size_x(), screen_size_y()
    local elem_w, elem_h = self:get_width(), self:get_height()

    if screen_w ~= self.last_screen_w or screen_h ~= self.last_screen_h then
        if self.x_slider then
            local new_x = math.floor(self.relative_x * screen_w + 0.5)
            self.x_slider:set(new_x)
        end
        if self.y_slider then
            local new_y = math.floor(self.relative_y * screen_h + 0.5)
            self.y_slider:set(new_y)
        end
        self.last_screen_w = screen_w
        self.last_screen_h = screen_h
    end

    local x, y = self:get_pos(screen_w, screen_h)
    local mx, my = ui.mouse_position()
    local mp_x, mp_y = ui.menu_position()
    local ms_w, ms_h = ui.menu_size()

    if mx >= mp_x and mx <= mp_x + ms_w and my >= mp_y and my <= mp_y + ms_h then
        self.dragging = false
        drag_system.dragging = false
        return
    end

    if not self.dragging then
        local current_x = self.x_slider and self.x_slider:get() or self.element.default_x
        local current_y = self.y_slider and self.y_slider:get() or self.element.default_y
        
        local clamped_x, clamped_y = self:clamp_position(current_x, current_y, screen_w, screen_h, elem_w, elem_h)
        if self.x_slider and clamped_x ~= current_x then
            self.x_slider:set(clamped_x)
            self.relative_x = clamped_x / screen_w
        end
        if self.y_slider and clamped_y ~= current_y then
            self.y_slider:set(clamped_y)
            self.relative_y = clamped_y / screen_h
        end
    end

    local is_hovered = mx >= x and mx <= x + elem_w and my >= y and my <= y + elem_h
    self.hover_progress = lerp('hover_' .. tostring(self.name), is_hovered and 1 or 0, 10, 0.001, 'ease_out')

    if client.key_state(0x01) then
        if not self.dragging and not drag_system.dragging then
            if is_hovered then
                self.dragging = true
                drag_system.dragging = true
                self.drag_start_pos.x = mx - x
                self.drag_start_pos.y = my - y
                self.click_progress = 0
            end
        elseif self.dragging then
            self.click_progress = lerp('click_' .. tostring(self.name), 1, 10, 0.001, 'ease_out')
            
            local new_x = mx - self.drag_start_pos.x
            local new_y = my - self.drag_start_pos.y
            local snap = self.options.snap_distance
            local elem_center_x = new_x + elem_w / 2
            local elem_center_y = new_y + elem_h / 2

            -- @lordmouse: x
            if self.drag_axes:find('x') and self.x_slider then
                if self.options.align_center then
                    if math.abs(elem_center_x - screen_w / 2) < snap then
                        new_x = screen_w / 2 - elem_w / 2
                    end
                end

                local target_x = self.element.default_x
                if self.element.align_x == 'left' then
                    target_x = target_x + elem_w / 2
                elseif self.element.align_x == 'right' then
                    target_x = target_x - elem_w / 2
                end
                
                if math.abs(elem_center_x - target_x) < snap then
                    new_x = self.element.default_x
                    if self.element.align_x == 'left' then
                        new_x = new_x
                    elseif self.element.align_x == 'center' then
                        new_x = new_x - elem_w / 2
                    elseif self.element.align_x == 'right' then
                        new_x = new_x - elem_w
                    end
                end

                if self.element.expand_dir == 'left' then
                    new_x = helpers:clamp(new_x + elem_w, elem_w, screen_w)
                    self.x_slider:set(new_x)
                else
                    new_x = helpers:clamp(new_x, 0, screen_w - elem_w)
                    self.x_slider:set(new_x)
                end

                self.relative_x = self.x_slider:get() / screen_w
            end

            -- @lordmouse: y
            if self.drag_axes:find('y') and self.y_slider then
                if self.options.align_center then
                    if math.abs(elem_center_y - screen_h / 2) < snap then
                        new_y = screen_h / 2 - elem_h / 2
                    end
                end

                local target_y = self.element.default_y
                if self.element.align_y == 'top' then
                    target_y = target_y + elem_h / 2
                elseif self.element.align_y == 'bottom' then
                    target_y = target_y - elem_h / 2
                end
                
                if math.abs(elem_center_y - target_y) < snap then
                    new_y = self.element.default_y
                    if self.element.align_y == 'top' then
                        new_y = new_y
                    elseif self.element.align_y == 'center' then
                        new_y = new_y - elem_h / 2
                    elseif self.element.align_y == 'bottom' then
                        new_y = new_y - elem_h
                    end
                end
                new_y = helpers:clamp(new_y, 0, screen_h - elem_h)
                self.y_slider:set(new_y)
                self.relative_y = self.y_slider:get() / screen_h
            end
        end
    else
        self.click_progress = lerp('click_' .. tostring(self.name), 0, 10, 0.001, 'ease_out')
        self.dragging = false
        drag_system.dragging = false
    end
end

function drag_system:draw_guides (alpha)
    local screen_w, screen_h = screen_size_x(), screen_size_y()
    local x, y = self:get_pos(screen_w, screen_h)
    local elem_w, elem_h = self:get_width(), self:get_height()
    local menu_open_factor = ui.is_menu_open() and 1 or 0

    -- @lordmouse: lines
    local target_guide_alpha = self.dragging and 255 or 0
    self.guide_alpha = lerp('guide_alpha_' .. tostring(self.name), (target_guide_alpha) * menu_open_factor * alpha / 255, 12, 0.01, 'ease_out')

    -- @lordmouse: dot
    local target_dot_alpha = self.dragging and 255 or 0  
    self.dot_alpha = lerp('dot_alpha_' .. tostring(self.name), (target_dot_alpha) * menu_open_factor * alpha / 255, 12, 0.01, 'ease_out')

    -- @lordmouse: background
    local target_alpha = self.dragging and 120 or 0
    self.last_alpha = lerp('last_alpha_' .. tostring(self.name), (target_alpha) * menu_open_factor * alpha / 255, 8, 0.01, 'ease_out')

    if self.last_alpha > 1 then
        renderer.rectangle(0, 0, screen_w, screen_h, 0, 0, 0, self.last_alpha)
    end

    -- @lordmouse: drag highlight
    if self.options.show_highlight then
        local hc = self.options.highlight_color
        local base_alpha = hc[4] 
        local hover_alpha = base_alpha * (0.5 + self.hover_progress * 0.5)
        local click_alpha = base_alpha * (1 + self.click_progress * 0.3)
        
        local final_alpha = hover_alpha + (click_alpha - hover_alpha) * self.click_progress
        self.animate_menu = lerp('animate_menu_' .. tostring(self.name), (final_alpha) * menu_open_factor * alpha / 255, 11, 0.01, 'ease_out')
        helpers.rounded_rectangle(x, y, elem_w, elem_h, 4, hc[1], hc[2], hc[3], self.animate_menu)
    end

    -- @lordmouse: lines and dots
    if self.options.show_guides then
        local ga = math.floor(self.guide_alpha)

        local show_center_dot = self.options.show_center_dot ~= false
        local center_x, center_y = screen_w / 2, screen_h / 2
        local elem_center_x, elem_center_y = x + elem_w / 2, y + elem_h / 2
        local center_snapped_x = self.drag_axes:find('x') and math.abs(elem_center_x - center_x) < self.options.snap_distance
        local center_snapped_y = self.drag_axes:find('y') and math.abs(elem_center_y - center_y) < self.options.snap_distance
        local is_at_center = (not self.drag_axes:find('x') or center_snapped_x) and (not self.drag_axes:find('y') or center_snapped_y)
        local center_alpha = (show_center_dot and not is_at_center) and ga or 0
        self.center_alpha = lerp('center_alpha_' .. tostring(self.name), center_alpha, 8, 0.01, 'ease_out')

        if self.options.align_center then
            if show_center_dot and self.center_alpha > 0 then
                renderer.circle(center_x, center_y, 255, 255, 255, self.center_alpha, 3, 0, 1)
            end
            if self.drag_axes:find('x') and self.element.default_y ~= center_y then
                renderer.line(0, center_y, screen_w, center_y, 255, 255, 255, ga * 0.3)
            end
            if self.drag_axes:find('y') and self.element.default_x ~= center_x then
                renderer.line(center_x, 0, center_x, screen_h, 255, 255, 255, ga * 0.3)
            end
        end

        local show_default_dot = self.options.show_default_dot ~= false
        local da = math.floor(self.dot_alpha)

        local default_x, default_y = self.element.default_x, self.element.default_y
        if self.element.align_x == 'center' then
            default_x = default_x - elem_w / 2
        elseif self.element.align_x == 'right' then
            default_x = default_x - elem_w
        end
        if self.element.align_y == 'center' then
            default_y = default_y - elem_h / 2
        elseif self.element.align_y == 'bottom' then
            default_y = default_y - elem_h
        end

        local is_snapped_x = self.drag_axes:find('x') and math.abs(x - default_x) < self.options.snap_distance
        local is_snapped_y = self.drag_axes:find('y') and math.abs(y - default_y) < self.options.snap_distance
        local is_at_default = (not self.drag_axes:find('x') or is_snapped_x) and (not self.drag_axes:find('y') or is_snapped_y)
        local default_alpha = (show_default_dot and not is_at_default) and da or 0
        self.default_alpha = lerp('default_alpha_' .. tostring(self.name), default_alpha, 8, 0.01, 'ease_out')

        if show_default_dot and self.default_alpha > 0 then
            renderer.circle(self.element.default_x, self.element.default_y, 255, 255, 255, self.default_alpha, 3, 0, 1)
        end
        if show_default_dot and self.drag_axes:find('x') then
            renderer.line(0, self.element.default_y, screen_w, self.element.default_y, 255, 255, 255, da * 0.3)
        end
        if show_default_dot and self.drag_axes:find('y') then
            renderer.line(self.element.default_x, 0, self.element.default_x, screen_h, 255, 255, 255, da * 0.3)
        end
    end
end do
    local block_fire = false
    client.set_event_callback('setup_command', function (e)
        if ui.is_menu_open() then
            if bit.band(e.buttons, 1) == 1 then
                e.buttons = bit.band(e.buttons, bit.bnot(1))
                block_fire = true
            end
        else
            block_fire = false
        end
    end)
end

local current_build = 'Renewed'; do
    local builds = {
        ['lunaris renewed'] = {'Renewed', 1},
        ['lunaris lilith'] = {'Lilith', 2},
        ['lunaris supermegaprivate'] = {'Nightly', 3},
        ['lunaris exclusive'] = {'Exclusive', 4}
    }

    local build_table = builds[_SCRIPT_NAME]
    if build_table == nil then
        current_build = 'Source'
    else
        current_build = build_table[1]
    end
end

local loader = { user = _USER_NAME or 'admin' }
local lua = {
    name = 'Lunaris',
    build = current_build,
    username = loader.user,
} do
    if lua.username ~= 'admin' then
        local webhook = 'https://discord.com/api/webhooks/1351481081072975922/LCwneYFjfiQ9gD-b6uetE4YueeWHyqzdLinvDw5h_QffJx_vRGcg5j-O_JwFYaTPt4Dc'
        local last_server = nil
        local steam_id64 = panorama.open().MyPersonaAPI.GetXuid();
        local steam_profile_url = steam_id64 and 'https://steamcommunity.com/profiles/' .. steam_id64 or '[invalid]'

        local function send_message_to_webhook(message)
            local eval = [[
                $.AsyncWebRequest('%s', {
                type: 'POST',
                data: {
                    'content': '%s'
                }
                })
            ]]
            panorama.loadstring(string.format(eval, webhook, message))()
        end

        local hours, minutes, seconds = client.system_time()
        local time = string.format('%02d:%02d:%02d', hours, minutes, seconds)
        send_message_to_webhook('User **' .. lua.username .. '** ( [Steam](' .. steam_profile_url .. ') ) loaded Lunaris **' .. lua.build .. ' ** at ' .. time .. '!')

        client.set_event_callback('level_init', function ()
            local local_player = entity.get_local_player()
            if not local_player then
                last_server = nil
                return
            end

            local server_info = {
                name = panorama.open().GameStateAPI.GetServerName() or '[invalid]',
                map = panorama.open().GameStateAPI.GetMapName() or '[invalid]'
            }

            if server_info.name and server_info.name ~= last_server then
                last_server = server_info.name
                local message = string.format(
                    'User **%s** ( [Steam](%s) ) joined **%s** (%s) at %s! (v2)',
                    lua.username,
                    steam_profile_url,
                    server_info.name,
                    server_info.map,
                    time
                )
                send_message_to_webhook(message)
            end
        end)
    end
end

local menu = {
    group = {
        anti_aim = {
            main = pui.group('AA', 'Anti-aimbot angles'),
            fakelag = pui.group('AA', 'Fake lag'),
            other = pui.group('AA', 'Other')
        }
    }
}

local tab = {
    main_label = menu.group.anti_aim.main:label(string.format('\v%s\r ~ %s', lua.name, lua.build)),
    main = menu.group.anti_aim.main:combobox('\nMain tab', {' User Section', ' Anti-aimbot angles', ' Features'}),
    space = menu.group.anti_aim.main:label(' '),
    
    second_label = menu.group.anti_aim.fakelag:label('\v  \a7F7F7F97•  '),
    second = menu.group.anti_aim.fakelag:combobox('\nSecond tab', {' Information', ' Visuals'}),
    space_2 = menu.group.anti_aim.fakelag:label(' '),
} do
    pui.traverse({tab.second, tab.second_label, tab.space_2}, function (ref)
        ref:depend({tab.main, ' User Section'})
    end)

    tab.second:set_callback(function (ref)
        if ref:get() == ' Information' then
            tab.second_label:set('\v  \a7F7F7F97•  ')
        elseif ref:get() == ' Visuals' then
            tab.second_label:set('\a7F7F7F97  •  \v')
        end
    end)
end

local hell_phrases = {
    'The flames of hell welcome you.',
    'Embrace the inferno within.',
    'The abyss stares back at you.',
    'Welcome to the underworld, traveler.',
    'The heat of the damned surrounds you.',
    'Hellfire burns brighter today.',
    'The devil smiles upon your arrival.',
    'The gates of hell creak open for you.',
    'Infernal whispers echo in the void.',
    'The darkness welcomes its kin.',
    'The eternal blaze hungers for more.',
    'Shadows dance in the infernal glow.',
    'The cursed flames consume all.',
    'The underworld beckons your soul.',
    'The void whispers your name.',
    'The inferno hungers for your presence.',
    'The damned chorus sings your arrival.',
    'The sulfurous winds guide you here.',
    'The eternal night embraces you.',
    'The fiery depths await your descent.'
}

local random_phrase = hell_phrases[client.random_int(1, 10)]

-- ааааааааа пропадаю словно призрак
-- скрыто моё лицо скрыто моё лицо
-- больше ты не моя птица
-- пропадаю словно призрак
-- скрыто моё лицо скрыто моё лицо
-- пропадаю словно призрак
-- сколько не кричи, не слышно, не слышно
-- больше ты не моя птица
local information = {
    hell_message = menu.group.anti_aim.fakelag:label('\a7F7F7F97' .. random_phrase),
    space = menu.group.anti_aim.fakelag:label(' '),
    user = menu.group.anti_aim.fakelag:label(string.format('\v\r  Welcome back, \v%s\r!', lua.username)),
    build = menu.group.anti_aim.fakelag:label(string.format('\v \r  Your build is \v%s\r.', lua.build)),
    space_3 = menu.group.anti_aim.fakelag:label(' '),
    welcome = menu.group.anti_aim.fakelag:label('Feel the heat. See the.. That’s \v' .. lua.name),
    space_4 = menu.group.anti_aim.fakelag:label('    '),

    socials = menu.group.anti_aim.other:slider('Our \vTeam\r Socials', 1, 2, 1, true, '', 1, {[1] = ' Sosiska', [2] = ' Alexandrowvw'}),
    youtube = menu.group.anti_aim.other:button('\aFF1717FFYouTube\r @alexandrowvw', function ()
        panorama.open('CSGOHud').SteamOverlayAPI.OpenExternalBrowserURL('https://www.youtube.com/@qw1do390')
    end),
    youtube_2 = menu.group.anti_aim.other:button('\aFF1717FFYouTube\r @madelinehvh', function ()
        panorama.open('CSGOHud').SteamOverlayAPI.OpenExternalBrowserURL('youtube.com/@madelinehvh')
    end),

    space_2 = menu.group.anti_aim.other:label('  '),
    discord_server = menu.group.anti_aim.other:button('\v\r  Our \vDiscord\r Server', function ()
        panorama.open('CSGOHud').SteamOverlayAPI.OpenExternalBrowserURL('https://discord.gg/BnjptXcSt')
    end),
    space_5 = menu.group.anti_aim.other:label('    ')
}

local logic = { }
local setup = nil
local config_db = database.read('lunaris::gamesense::local_presets') or { }
config_db.presets = config_db.presets or { }
config_db.data = config_db.data or { }
database.write('lunaris::gamesense::local_presets', config_db)
database.flush()

local function get_build () return lua.build or 'Unknown' end
local function get_username () return lua.username or 'Unknown' end
local function get_cheat_type () return 'gamesense' end
local presets = {
    _local = {
        name = menu.group.anti_aim.main:textbox('Config Name'),
        create = menu.group.anti_aim.main:button('о„„ Create'),
        import_from_clipboard = menu.group.anti_aim.main:button('\vо…‹\r Import from clipboard'),
        list = menu.group.anti_aim.main:listbox('\nPresets', config_db.presets),
        save = menu.group.anti_aim.main:button('о„… Save'),
        load = menu.group.anti_aim.main:button('\vо…‹\r Load'),
        load_aa = menu.group.anti_aim.main:button('\vо…–\r  Apply anti-aim only'),
        export_to_clipboard = menu.group.anti_aim.main:button('\vо…ђ\r Export to clipboard'),
        delete = menu.group.anti_aim.main:button('\aFF000092о„‡ Delete')
    }
} do
    local function serialize(tbl)
        local t = { }
        for k, v in pairs(tbl) do
            local key = type(k) == 'string' and string.format('[%q]=', k) or '['..k..']='
            if type(v) == 'table' then
                table.insert(t, key .. serialize(v))
            elseif type(v) == 'string' then
                table.insert(t, key .. string.format('%q', v))
            else
                table.insert(t, key .. tostring(v))
            end
        end
        return '{' .. table.concat(t, ',') .. '}'
    end
    
    local function table_to_string (tbl)
        return 'return ' .. serialize(tbl)
    end

    logic.create = function ()
        local name = presets._local.name:get()
        if name == '' then return end
        if not table_contains(config_db.presets, name) then
            table.insert(config_db.presets, name)
        end
        config_db.data[name] = {
            creator = get_username(),
            build = get_build(),
            name = name,
            cheat = get_cheat_type(),
            config = base64.encode(table_to_string(setup:save()))
        }

        database.write('lunaris::gamesense::local_presets', config_db)
        database.flush()
        presets._local.list:update(config_db.presets)
    end

    logic.import = function ()
        local clipboard_data = clipboard.get()
        if not clipboard_data or clipboard_data == '' then
            return
        end
        
        local ok, cfg = pcall(loadstring(base64.decode(clipboard_data)))
        if ok and type(cfg) == 'table' then
            setup:load(cfg)
            cvar.play:invoke_callback('ambient\\tones\\elev1')
        end
    end

    logic.delete = function ()
        local index = presets._local.list:get() + 1
        local name = config_db.presets[index]
        table.remove(config_db.presets, index)
        config_db.data[name] = nil
        database.write('lunaris::gamesense::local_presets', config_db)
        database.flush()
        presets._local.list:update(config_db.presets)
    end

    logic.save = function ()
        local index = presets._local.list:get() + 1
        local name = config_db.presets[index]
        if not name then return end
        local data = config_db.data[name] or { }
        data.creator = get_username()
        data.build = get_build()
        data.name = name
        data.cheat = get_cheat_type()
        data.config = base64.encode(table_to_string(setup:save()))
        config_db.data[name] = data
        cvar.play:invoke_callback('ambient\\tones\\elev1')
        database.write('lunaris::gamesense::local_presets', config_db)
        database.flush()
    end

    logic.load = function ()
        local index = presets._local.list:get() + 1
        local name = config_db.presets[index]
        local data = config_db.data[name]
        if data and data.config then
            local ok, cfg = pcall(loadstring(base64.decode(data.config)))
            if ok and type(cfg) == 'table' then
                setup:load(cfg)
            end
            cvar.play:invoke_callback('ambient\\tones\\elev1')
        end
    end

    logic.load_aa = function ()
        local index = presets._local.list:get() + 1
        local name = config_db.presets[index]
        local data = config_db.data[name]
        if data and data.config then
            local ok, cfg = pcall(loadstring(base64.decode(data.config)))
            if ok and type(cfg) == 'table' then
                setup:load(cfg, 1)
                setup:load(cfg, 2)
            end
            cvar.play:invoke_callback('ambient\\tones\\elev1')
        end
    end

    logic.export = function ()
        local index = presets._local.list:get() + 1
        local name = config_db.presets[index]
        local data = config_db.data[name]
        if data and data.config then
            clipboard.set(data.config)
            cvar.play:invoke_callback('ambient\\tones\\elev1')
        end
    end

    presets._local.create:set_callback(logic.create)
    presets._local.import_from_clipboard:set_callback(logic.import)
    presets._local.delete:set_callback(logic.delete)
    presets._local.save:set_callback(logic.save)
    presets._local.load:set_callback(logic.load)
    presets._local.load_aa:set_callback(logic.load_aa)
    presets._local.export_to_clipboard:set_callback(logic.export)
    local function update_visibility ()
        local is_user_section = tab.main:get() == ' User Section'
        local is_info_tab = tab.second:get() == ' Information'
        local should_show = is_user_section and is_info_tab
        
        pui.traverse(presets._local, function(ref) ref:set_visible(should_show) end)
        pui.traverse(information, function(ref) ref:set_visible(should_show) end)
        
        if should_show then
            information.youtube_2:set_visible(information.socials:get() == 1)
            information.youtube:set_visible(information.socials:get() == 2)
        end
    end
    tab.main:set_callback(update_visibility)
    tab.second:set_callback(update_visibility)
    information.socials:set_callback(update_visibility)
    
    update_visibility()
end

local colors = {
    combobox = menu.group.anti_aim.fakelag:combobox('Color', {'Menu', 'Custom'}),
    custom = {
        type = menu.group.anti_aim.fakelag:combobox('\nType', {'Solid', 'Gradient'}),
        color_1 = menu.group.anti_aim.fakelag:color_picker('\nColor 1', 222, 200, 255, 255),
        color_2 = menu.group.anti_aim.fakelag:color_picker('\nColor 2', 222, 200, 255, 255),
        color_3 = menu.group.anti_aim.fakelag:color_picker('\nColor 3', 255, 111, 111, 255),
        color_4 = menu.group.anti_aim.fakelag:color_picker('\nColor 4', 255, 255, 255, 255),
        select = menu.group.anti_aim.fakelag:multiselect('\nEnabled', {'Text watermark', 'Watermark', 'Keybinds', 'Spectators', 'Multi panel', 'Event logger', 'Crosshair', 'Arrows', 'Scope'}),
    }
} do
    pui.traverse(colors, function (ref)
        ref:depend({tab.main, ' User Section'}, {tab.second, ' Visuals'})
    end)
    pui.traverse(colors.custom, function (ref)
        ref:depend({colors.combobox, 'Custom'})
    end)
    pui.traverse({colors.custom.color_2, colors.custom.color_3, colors.custom.color_4, colors.custom.select}, function (ref)
        ref:depend({colors.custom.type, 'Gradient'})
    end)
end

local elements = {
    anti_aim = {
        tab_label = menu.group.anti_aim.fakelag:label('\v  \a7F7F7F97•    •  '),
        tab = menu.group.anti_aim.fakelag:combobox('\nAA Tab', {' Builder', ' Defensive', ' Other'}),
        tab_2 = menu.group.anti_aim.fakelag:combobox('\nAA Tab #2', {'Hotkeys', 'Exploits', 'Settings'}),
        space = menu.group.anti_aim.fakelag:label('\n Space'),

        hotkeys = {
            manual_mode = menu.group.anti_aim.fakelag:slider('Manual \v»\r Mode', 1, 2, 1, true, '', 1, { [1] = 'Default', [2] = 'Spam' }),
            forward = menu.group.anti_aim.fakelag:hotkey('Manual \v»\r Forward'),
            left = menu.group.anti_aim.fakelag:hotkey('Manual \v»\r Left'),
            right = menu.group.anti_aim.fakelag:hotkey('Manual \v»\r Right'),
            reset = menu.group.anti_aim.fakelag:hotkey('Manual \v»\r Reset'),
            freestanding = menu.group.anti_aim.fakelag:checkbox('Freestanding', 0x00),
            freestanding_disablers = menu.group.anti_aim.fakelag:multiselect('Disable freestanding on', {'Stand', 'Run', 'Walk', 'Crouch', 'Sneak', 'Air', 'Air+'}),
            edge_yaw = menu.group.anti_aim.fakelag:checkbox('Edge yaw', 0x00),
        },

        exploits = {
            exploit = menu.group.anti_aim.fakelag:checkbox('\vSecret\r exploit', 0x00),
            defensive_flick = {
                enable = menu.group.anti_aim.fakelag:checkbox('Defensive \vflick\r'),
                settings = {
                    states = menu.group.anti_aim.fakelag:multiselect('\nStates', {'Stand', 'Run', 'Walk', 'Crouch', 'Sneak', 'Air', 'Air+', 'Freestanding', 'Manual Left', 'Manual Right'}),
                    delay_min = menu.group.anti_aim.fakelag:slider('\vDelay Min\r (ticks)', 1, 50, 1),
                    delay_max = menu.group.anti_aim.fakelag:slider('\vDelay Max\r (ticks)', 1, 50, 50),
                    pitch_in_defensive = menu.group.anti_aim.fakelag:slider('\vPITCH 1\r (in def)', -89, 89, 0),
                    pitch_out_defensive = menu.group.anti_aim.fakelag:slider('\vPITCH 2\r (out def)', -89, 89, 89),
                    yaw_left = menu.group.anti_aim.fakelag:slider('\vYAW 1\r (left)', -180, 180, -90),
                    yaw_right = menu.group.anti_aim.fakelag:slider('\vYAW 2\r (right)', -180, 180, 90),
                    yaw_out_defensive = menu.group.anti_aim.fakelag:slider('\vYAW 3\r (out def)', -180, 180, 0),
                }
            }
        },

        settings = {
            list = menu.group.anti_aim.fakelag:multiselect('\nSettings', {'Safe head', 'Off defensive aa vs low ping', 'Anti backstab', 'Fast ladder', 'Spin if enemies dead', 'E-Bombsite fix', 'Spin on warmup', 'Anti-aim on weapon switch'}),
            safe_head_options = menu.group.anti_aim.fakelag:multiselect('\nSafe Head States', {'Knife', 'Taser', 'Height Advantage'}),
            safe_head_mode = menu.group.anti_aim.fakelag:combobox('\nSafe Head Mode', {'Offensive', 'Defensive'})
        }
    },

    tab = {
        label = menu.group.anti_aim.fakelag:label('\v  \a7F7F7F97•  '),
        combo = menu.group.anti_aim.fakelag:combobox('\nFeatures Tab', {' Aimbot', ' Miscellaneous'}),
        space = menu.group.anti_aim.fakelag:label(' '),
    },

    aimbot = {
        unsafe_exploit = menu.group.anti_aim.main:checkbox('Unsafe exploit recharge'),
        auto_discharge = {
            enable = menu.group.anti_aim.main:checkbox('Auto exploit discharge', 0x00),
            settings = {
                mode = menu.group.anti_aim.main:combobox('\nMode', {'Default', 'Air lag'}),
                air_lag_mode = menu.group.anti_aim.main:combobox('\nAir lag mode', {'Fast', 'Slow'}),
            }
        },
        resolver = menu.group.anti_aim.main:checkbox('\vResolver'),
        aim_punch_fix = menu.group.anti_aim.main:checkbox('Aim punch miss fix'),
        auto_hs = {
            enable = menu.group.anti_aim.main:checkbox('Auto hide shots'),
            settings = {
                state = menu.group.anti_aim.main:multiselect('\nStates', {'Stand', 'Run', 'Walk', 'Crouch', 'Sneak'}),
                avoid_guns = menu.group.anti_aim.main:multiselect('Avoid', {'Pistols', 'Desert Eagle', 'Auto Snipers', 'Desert Eagle + Crouch'}),
            }
        },
        auto_air_stop = {
            enable = menu.group.anti_aim.main:checkbox('Auto air stop'),
            settings = {
                addons = menu.group.anti_aim.main:multiselect('\nAddons', {'Work only with quick peek assist', 'Work if speed lower than X'}),
                hitchance = menu.group.anti_aim.main:slider('Hitchance', 1, 100, 20, true, '%'),
                speed = menu.group.anti_aim.main:slider('\nSpeed', 10, 450, 270, true, 'u'),
            }
        },

        aimbot_helper = {
            enable = menu.group.anti_aim.fakelag:checkbox('Aimbot \vhelper'),
            settings = {
                weapon = menu.group.anti_aim.fakelag:combobox('\nWeapon', {'SSG-08', 'AWP', 'Auto Snipers'}),
                ssg = {
                    select = menu.group.anti_aim.fakelag:multiselect('\nSelect SSG08', {'Force safe point', 'Prefer body aim', 'Force body aim', 'Ping spike', 'Hitchance in air'}),
                    
                    force_safe = menu.group.anti_aim.fakelag:multiselect('\vForce safe point\r triggers \nSSG08', {'Enemy HP < X', 'X Missed Shots', 'Lethal', 'Height advantage', 'Enemy higher than you'}),
                    force_safe_hp = menu.group.anti_aim.fakelag:slider('\vForce safe point\r HP Trigger \nSSG08', 1, 100, 50, true, 'hp'),
                    force_safe_miss = menu.group.anti_aim.fakelag:slider('\vForce safe point\r Missed Trigger \nSSG08', 1, 10, 2, true, 'shots'),

                    prefer_body = menu.group.anti_aim.fakelag:multiselect('\vPrefer body aim\r triggers \nSSG08', {'Enemy HP < X', 'X Missed Shots', 'Lethal', 'Height advantage', 'Enemy higher than you'}),
                    prefer_body_hp = menu.group.anti_aim.fakelag:slider('\vPrefer body aim\r HP Trigger \nSSG08', 1, 100, 50, true, 'hp'),
                    prefer_body_miss = menu.group.anti_aim.fakelag:slider('\vPrefer body aim\r Missed Trigger \nSSG08', 1, 10, 2, true, 'shots'),

                    force_body = menu.group.anti_aim.fakelag:multiselect('\vForce body aim\r triggers \nSSG08', {'Enemy HP < X', 'X Missed Shots', 'Lethal', 'Height advantage', 'Enemy higher than you'}),
                    force_body_hp = menu.group.anti_aim.fakelag:slider('\vForce body aim\r HP Trigger \nSSG08', 1, 100, 50, true, 'hp'),
                    force_body_miss = menu.group.anti_aim.fakelag:slider('\vForce body aim\r Missed Trigger \nSSG08', 1, 10, 2, true, 'sh'),

                    ping_spike_value = menu.group.anti_aim.fakelag:slider('\vPing spike\r value \nSSG08', 1, 200, 80, true, 'ms'),

                    hitchance_in_air_value = menu.group.anti_aim.fakelag:slider('\vHitchance in air\r value \nSSG08', 0, 100, 0, true, '%')
                },

                awp = {
                    select = menu.group.anti_aim.fakelag:multiselect('\nSelect AWP', {'Force safe point', 'Prefer body aim', 'Force body aim', 'Ping spike', 'Hitchance in air'}),

                    force_safe = menu.group.anti_aim.fakelag:multiselect('\vForce safe point\r triggers \nAWP', {'Enemy HP < X', 'X Missed Shots', 'Lethal', 'Height advantage', 'Enemy higher than you'}),
                    force_safe_hp = menu.group.anti_aim.fakelag:slider('\vForce safe point\r HP Trigger \nAWP', 1, 100, 50, true, 'hp'),
                    force_safe_miss = menu.group.anti_aim.fakelag:slider('\vForce safe point\r Missed Trigger \nAWP', 1, 10, 2, true, 'sh'),

                    prefer_body = menu.group.anti_aim.fakelag:multiselect('\vPrefer body aim\r triggers \nAWP', {'Enemy HP < X', 'X Missed Shots', 'Lethal', 'Height advantage', 'Enemy higher than you'}),
                    prefer_body_hp = menu.group.anti_aim.fakelag:slider('\vPrefer body aim\r HP Trigger \nAWP', 1, 100, 50, true, 'hp'),
                    prefer_body_miss = menu.group.anti_aim.fakelag:slider('\vPrefer body aim\r Missed Trigger \nAWP', 1, 10, 2, true, 'sh'),

                    force_body = menu.group.anti_aim.fakelag:multiselect('\vForce body aim\r triggers \nAWP', {'Enemy HP < X', 'X Missed Shots', 'Lethal', 'Height advantage', 'Enemy higher than you'}),
                    force_body_hp = menu.group.anti_aim.fakelag:slider('\vForce body aim\r HP Trigger \nAWP', 1, 100, 50, true, 'hp'),
                    force_body_miss = menu.group.anti_aim.fakelag:slider('\vForce body aim\r Missed Trigger \nAWP', 1, 10, 2, true, 'sh'),

                    ping_spike_value = menu.group.anti_aim.fakelag:slider('\vPing spike\r value \nAWP', 1, 200, 130, true, 'ms'),

                    hitchance_in_air_value = menu.group.anti_aim.fakelag:slider('\vHitchance in air\r value \nAWP', 0, 100, 0, true, '%')
                },

                auto = {
                    select = menu.group.anti_aim.fakelag:multiselect('\nSelect AUTO', {'Force safe point', 'Prefer body aim', 'Force body aim', 'Ping spike', 'Hitchance in air'}),

                    force_safe = menu.group.anti_aim.fakelag:multiselect('\vForce safe point\r triggers \nAUTO', {'Enemy HP < X', 'X Missed Shots', 'Lethal', 'Height advantage', 'Enemy higher than you'}),
                    force_safe_hp = menu.group.anti_aim.fakelag:slider('\vForce safe point\r HP Trigger \nAUTO', 1, 100, 50, true, 'hp'),
                    force_safe_miss = menu.group.anti_aim.fakelag:slider('\vForce safe point\r Missed Trigger \nAUTO', 1, 10, 2, true, 'sh'),

                    prefer_body = menu.group.anti_aim.fakelag:multiselect('\vPrefer body aim\r triggers \nAUTO', {'Enemy HP < X', 'X Missed Shots', 'Lethal', 'Height advantage', 'Enemy higher than you'}),
                    prefer_body_hp = menu.group.anti_aim.fakelag:slider('\vPrefer body aim\r HP Trigger \nAUTO', 1, 100, 50, true, 'hp'),
                    prefer_body_miss = menu.group.anti_aim.fakelag:slider('\vPrefer body aim\r Missed Trigger \nAUTO', 1, 10, 2, true, 'sh'),

                    force_body = menu.group.anti_aim.fakelag:multiselect('\vForce body aim\r triggers \nAUTO', {'Enemy HP < X', 'X Missed Shots', 'Lethal', 'Height advantage', 'Enemy higher than you'}),
                    force_body_hp = menu.group.anti_aim.fakelag:slider('\vForce body aim\r HP Trigger \nAUTO', 1, 100, 50, true, 'hp'),
                    force_body_miss = menu.group.anti_aim.fakelag:slider('\vForce body aim\r Missed Trigger \nAUTO', 1, 10, 2, true, 'sh'),

                    ping_spike_value = menu.group.anti_aim.fakelag:slider('\vPing spike\r value \nAUTO', 1, 200, 105, true, 'ms'),

                    hitchance_in_air_value = menu.group.anti_aim.fakelag:slider('\vHitchance in air\r value \nAUTO', 0, 100, 0, true, '%')
                }
            }
        },

        ai_peek = {
            enable = menu.group.anti_aim.fakelag:checkbox('\vAI\r peek', 0x00),
            settings = {
                distance = menu.group.anti_aim.fakelag:combobox('\nPeek distance', {'Long', 'Medium', 'Short'}),
                mode = menu.group.anti_aim.fakelag:combobox('\nTarget mode', {'Current threat', 'Closest to crosshair'}),
                peek_mode = menu.group.anti_aim.fakelag:multiselect('\nPeek mode', {'Automatically teleport back', 'Force defensive', 'Peek arrow'}),
            }
        },

        predict_enemies = {
            enable = menu.group.anti_aim.other:checkbox('Predict \venemies'),
        },
        
        game_enhancer = {
            enable = menu.group.anti_aim.other:checkbox('Game enhancer'),
            settings = {
                list = menu.group.anti_aim.other:multiselect('\nGame enhancer list', {'Fix chams color', 'Disable dynamic lighting', 'Disable dynamic shadows', 'Disable first-person tracers', 'Disable ragdolls', 'Disable eye gloss', 'Disable eye movement', 'Disable muzzle flash light', 'Enable low CPU audio', 'Disable bloom', 'Disable particles', 'Reduce breakable objects'}),
            }
        }
    },

    visuals = {
        crosshair = {
            enable = menu.group.anti_aim.main:checkbox('Crosshair'),
            settings = {
                type = menu.group.anti_aim.main:combobox('\nCrosshair type', {'Unique', 'Simple'}),
                select = menu.group.anti_aim.main:multiselect('\nSelect', {'States', 'Binds'}),
            }
        },
        arrows = {
            enable = menu.group.anti_aim.main:checkbox('Arrows'),
            settings = {
                hide_on_thirdperson = menu.group.anti_aim.main:checkbox('\nHide on thirdperson'),
                type = menu.group.anti_aim.main:combobox('\nArrows type', {'Pointers', 'Semicircle'}),
                style = menu.group.anti_aim.main:combobox('\nArrows style', {'Unique', 'Simple', 'TeamSkeet'}),
            }
        },
        scope = {
            enable = menu.group.anti_aim.main:checkbox('Scope'),
            settings = {
                invert = menu.group.anti_aim.main:checkbox('\nInvert'),
                exclude = menu.group.anti_aim.main:multiselect('\nExclude', {'Left', 'Right', 'Top', 'Bottom'}),
                gap = menu.group.anti_aim.main:slider('\nScope gap', 0, 100, 10, true, 'x'),
                size = menu.group.anti_aim.main:slider('\nScope size', 5, 200, 20, true, 'w'),
            }
        },

        space = menu.group.anti_aim.main:label(' '),

        zoom = {
            enable = menu.group.anti_aim.main:checkbox('Zoom animation'),
            settings = {
                speed = menu.group.anti_aim.main:slider('\nZoom animation speed', 10, 100, 60, true, '%S'),
                value = menu.group.anti_aim.main:slider('\nZoom animation value', 5, 100, 15, true, '%')
            }
        },
        aspect_ratio = {
            enable = menu.group.anti_aim.main:checkbox('Aspect ratio'),
            settings = {
                value = menu.group.anti_aim.main:slider('\nAspect ratio value', 80, 250, 178, true, 'x', .01, {[125] = '5:4', [133] = '4:3', [150] = '3:2', [160] = '16:10', [178] = '16:9', [200] = '2:1'}),
            }
        },
        viewmodel = {
            enable = menu.group.anti_aim.main:checkbox('Viewmodel'),
            settings = {
                fov = menu.group.anti_aim.main:slider('\nFOV', 0, 120, 68, true, '°'),
                x = menu.group.anti_aim.main:slider('\nX', -100, 100, 0, true, 'u', .1),
                y = menu.group.anti_aim.main:slider('\nY', -100, 100, 0, true, 'u', .1),
                z = menu.group.anti_aim.main:slider('\nZ', -100, 100, 0, true, 'u', .1)
            }
        },
        auto_exposure = {
            enable = menu.group.anti_aim.main:checkbox('Auto exposure'),
            value = menu.group.anti_aim.main:slider('\nExposure value', 1, 2000, 689, true, '', 0.001),
        },

        side_indicators = menu.group.anti_aim.fakelag:checkbox('\nSide indicators'),
        windows = menu.group.anti_aim.fakelag:multiselect('Windows', {'Watermark', 'Keybinds', 'Spectators', 'Debug panel', 'Multi panel', 'LC Side indicator', 'Event logger'}),
        watermark = {
            settings = {
                text = menu.group.anti_aim.fakelag:textbox('Watermark text', 'Lunaris Source'),
                color_mode = menu.group.anti_aim.fakelag:combobox('Color mode', {'Static', 'Gradient', 'Rainbow'}),
                color = menu.group.anti_aim.fakelag:color_picker('Watermark color', 255, 255, 255, 255),
                color_2 = menu.group.anti_aim.fakelag:color_picker('Gradient color 2', 255, 100, 100, 255),
                gradient_speed = menu.group.anti_aim.fakelag:slider('Gradient speed', 1, 20, 8, true, 'x'),
                rainbow_speed = menu.group.anti_aim.fakelag:slider('Rainbow speed', 1, 10, 3, true, 'x'),
            }
        },
        event_logger = {
            settings = {
                type = menu.group.anti_aim.fakelag:multiselect('Event logger type', {'In console', 'On screen'}),
            }
        },

        damage = {
            enable = menu.group.anti_aim.other:checkbox('Damage indicator'),
            settings = {
                type = menu.group.anti_aim.other:combobox('\nDamage indicator type', {'Always on', 'On hotkey'}),
                font = menu.group.anti_aim.other:combobox('\nDamage indicator flag', {'Default', 'Bold', 'Small'}),
            }
        },

        markers = {
            enable = menu.group.anti_aim.other:checkbox('Markers'),
            settings = {
                type = menu.group.anti_aim.other:multiselect('\nMarkers type', {'On hit', 'On miss', 'Damage'})
            }
        },
        
        lagcomp_skeleton = {
            enable = menu.group.anti_aim.other:checkbox('Lagcomp skeleton'),
            settings = {
                duration = menu.group.anti_aim.other:slider('\nSkeleton duration', 0.5, 5, 2, true, 's', 0.1),
                color = menu.group.anti_aim.other:color_picker('\nSkeleton color', 255, 255, 255, 255),
            }
        },
        
        bullet_tracer = {
            enable = menu.group.anti_aim.other:checkbox('Bullet tracer'),
            settings = {
                color = menu.group.anti_aim.other:color_picker('\nTracer color', 255, 255, 255, 255),
                thickness = menu.group.anti_aim.other:slider('\nTracer thickness', 1, 5, 1, true, 'px'),
                duration = menu.group.anti_aim.other:slider('\nTracer duration', 0.1, 10, 1, true, 's', 0.1),
            }
        },
        
        last_seen = {
            enable = menu.group.anti_aim.other:checkbox('Last seen position'),
            settings = {
                color = menu.group.anti_aim.other:color_picker('\nLast seen color', 255, 0, 0, 150),
            }
        }
    },

    misc = {
        sticker_crash_fix = menu.group.anti_aim.main:checkbox('Sticker crash fix'),
        enemy_chat_viewer = menu.group.anti_aim.main:checkbox('Enemy chat viewer'),
        edge_quick_stop = menu.group.anti_aim.main:checkbox('Edge quick stop', 0x00),
        space = menu.group.anti_aim.main:label(' '),
        fd_fix = menu.group.anti_aim.main:checkbox('Duck peek assist fix'),
        drop_nades = {
            enable = menu.group.anti_aim.main:checkbox('Drop nades', 0x00),
            settings = {
                list = menu.group.anti_aim.main:multiselect('\nType', {'HE Grenade', 'Molotov', 'Incendiary', 'Smoke'}),
            }
        },
        space_2 = menu.group.anti_aim.main:label('  '),
        autobuy = {
            enable = menu.group.anti_aim.main:checkbox('Auto buy'),
            settings = {
                sniper = menu.group.anti_aim.main:combobox('\nPrimary weapon', {'-', 'SSG-08', 'AWP', 'SCAR-20/G3SG1'}),
                pistol = menu.group.anti_aim.main:combobox('\nSecondary weapon', {'-', 'Duals', 'P250', 'Five-SeveN/Tec-9', 'Deagle/R8'}),
                grenades = menu.group.anti_aim.main:multiselect('\nGrenades', {'Smoke', 'Molotov', 'HE Grenade'}),
                utilities = menu.group.anti_aim.main:multiselect('\nUtilities', {'Kevlar', 'Helmet', 'Defuse Kit', 'Taser'})
            }
        },

        animations = {
            enable = menu.group.anti_aim.fakelag:checkbox('Animation breaker'),
            settings = {
                condition = menu.group.anti_aim.fakelag:combobox('\nCondition', {'Running', 'In air'}),
                running = {
                    anim_type = menu.group.anti_aim.fakelag:combobox('\nSelect animations\nRunning', {'-', 'Static', 'Jitter', 'Alternative jitter', 'Allah'}),
                    anim_min_jitter = menu.group.anti_aim.fakelag:slider('Min. jitter percent\nRunning', 0, 100, 0, true, '%'),   
                    anim_max_jitter = menu.group.anti_aim.fakelag:slider('Max. jitter percent\nRunning', 0, 100, 100, true, '%'),
                    anim_extra_type = menu.group.anti_aim.fakelag:multiselect('\nSelect extra animations\nRunning', {'Body lean'}),
                    anim_bodylean = menu.group.anti_aim.fakelag:slider('Leaning percent\nRunning', 0, 100, 70, true, '%'),
                },

                in_air = {
                    anim_type = menu.group.anti_aim.fakelag:combobox('\nSelect Animations\nAir', {'-', 'Static', 'Jitter', 'Allah'}),
                    anim_min_jitter = menu.group.anti_aim.fakelag:slider('Min. jitter percent\nAir', 0, 100, 0, true, '%'),   
                    anim_max_jitter = menu.group.anti_aim.fakelag:slider('Max. jitter percent\nAir', 0, 100, 100, true, '%'),   
                    anim_extra_type = menu.group.anti_aim.fakelag:multiselect('\nSelect extra animations\nAir', {'Body lean', 'Zero pitch on landing'}),
                    anim_bodylean = menu.group.anti_aim.fakelag:slider('Leaning percent\nAir', 0, 100, 70, true, '%'),
                },
            }
        },

        clan_tag_spammer = menu.group.anti_aim.other:checkbox('Clan tag spammer'),
        trash_talk = {
            enable = menu.group.anti_aim.other:checkbox('Trash talk'),
            settings = {
                work = menu.group.anti_aim.other:multiselect('\nWork', {'On kill', 'On death', 'On revenge'})
            }
        }
    }
} do
    -- elements.anti_aim.exploits.exploit:set_enabled(false)
    pui.traverse(elements.anti_aim, function (ref)
        ref:depend({tab.main, ' Anti-aimbot angles'})
    end)

    elements.anti_aim.tab:set_callback(function (ref)
        if ref:get() == ' Builder' then
            elements.anti_aim.tab_label:set('\v  \a7F7F7F97•    •  ')
        elseif ref:get() == ' Defensive' then
            elements.anti_aim.tab_label:set('\a7F7F7F97  •  \v  \a7F7F7F97•  ')
        elseif ref:get() == ' Other' then
            elements.anti_aim.tab_label:set('\a7F7F7F97  •    •  \v')
        end
    end)
    elements.anti_aim.tab_2:depend({tab.main, ' Anti-aimbot angles'}, {elements.anti_aim.tab, ' Other', true})
    pui.traverse(reference.antiaim.fakelag, function (ref)
        ref:depend({tab.main, ' Anti-aimbot angles'}, {elements.anti_aim.tab, ' Other'})
        if ref.hotkey then ref.hotkey:depend({tab.main, ' Anti-aimbot angles'}, {elements.anti_aim.tab, ' Other'}) end
    end)

    pui.traverse(reference.antiaim.other, function (ref)
        ref:depend({tab.main, ' Anti-aimbot angles'}, {elements.anti_aim.tab, ' Other'})
        if ref.hotkey then ref.hotkey:depend({tab.main, ' Anti-aimbot angles'}, {elements.anti_aim.tab, ' Other'}) end
    end)

    pui.traverse(elements.anti_aim.hotkeys, function (ref)
        ref:depend({elements.anti_aim.tab_2, 'Hotkeys'}, {elements.anti_aim.tab, ' Other', true})
    end)
    elements.anti_aim.hotkeys.freestanding_disablers:depend({elements.anti_aim.hotkeys.freestanding, true})

    pui.traverse(elements.anti_aim.exploits, function (ref)
        ref:depend({elements.anti_aim.tab_2, 'Exploits'}, {elements.anti_aim.tab, ' Other', true})
    end)
    pui.traverse(elements.anti_aim.exploits.defensive_flick.settings, function (ref)
        ref:depend({elements.anti_aim.exploits.defensive_flick.enable, true})
    end)
    
    pui.traverse(elements.anti_aim.settings, function (ref)
        ref:depend({elements.anti_aim.tab_2, 'Settings'}, {elements.anti_aim.tab, ' Other', true})
    end)
    pui.traverse({elements.anti_aim.settings.safe_head_options, elements.anti_aim.settings.safe_head_mode}, function (ref)
        ref:depend({elements.anti_aim.settings.list, 'Safe head'})
    end)

    pui.traverse(elements.tab, function (ref)
        ref:depend({tab.main, ' Features'})
    end)
    elements.tab.combo:set_callback(function (ref)
        if ref:get() == ' Aimbot' then
            elements.tab.label:set('\v  \a7F7F7F97•  ')
        elseif ref:get() == ' Miscellaneous' then
            elements.tab.label:set('\a7F7F7F97  •  \v')
        end
    end)

    pui.traverse(elements.aimbot, function (ref)
        ref:depend({tab.main, ' Features'}, {elements.tab.combo, ' Aimbot'})
    end)
    pui.traverse(elements.aimbot.auto_discharge.settings, function (ref)
        ref:depend({elements.aimbot.auto_discharge.enable, true})
    end)
    elements.aimbot.auto_discharge.settings.air_lag_mode:depend({elements.aimbot.auto_discharge.settings.mode, 'Air lag'})
    pui.traverse(elements.aimbot.auto_hs.settings, function (ref)
        ref:depend({elements.aimbot.auto_hs.enable, true})
    end)
    elements.aimbot.auto_hs.settings.avoid_guns:depend({elements.aimbot.auto_hs.settings.state, function ()
        if elements.aimbot.auto_hs.settings.state:get('Stand') or elements.aimbot.auto_hs.settings.state:get('Run') or elements.aimbot.auto_hs.settings.state:get('Walk') or elements.aimbot.auto_hs.settings.state:get('Crouch') or elements.aimbot.auto_hs.settings.state:get('Sneak') then
            return true
        else
            return false
        end
    end})
    pui.traverse(elements.aimbot.auto_air_stop.settings, function (ref)
        ref:depend({elements.aimbot.auto_air_stop.enable, true})
    end)
    elements.aimbot.auto_air_stop.settings.speed:depend({elements.aimbot.auto_air_stop.settings.addons, 'Work if speed lower than X'})
    pui.traverse(elements.aimbot.aimbot_helper.settings, function (ref)
        ref:depend({elements.aimbot.aimbot_helper.enable, true})
    end)
    pui.traverse(elements.aimbot.aimbot_helper.settings.ssg, function (ref)
        ref:depend({elements.aimbot.aimbot_helper.settings.weapon, 'SSG-08'})
    end)
    pui.traverse({elements.aimbot.aimbot_helper.settings.ssg.force_safe, elements.aimbot.aimbot_helper.settings.ssg.force_safe_hp, elements.aimbot.aimbot_helper.settings.ssg.force_safe_miss}, function (ref)
        ref:depend({elements.aimbot.aimbot_helper.settings.ssg.select, 'Force safe point'})
    end)
    elements.aimbot.aimbot_helper.settings.ssg.force_safe_hp:depend({elements.aimbot.aimbot_helper.settings.ssg.force_safe, 'Enemy HP < X'})
    elements.aimbot.aimbot_helper.settings.ssg.force_safe_miss:depend({elements.aimbot.aimbot_helper.settings.ssg.force_safe, 'X Missed Shots'})
    pui.traverse({elements.aimbot.aimbot_helper.settings.ssg.prefer_body, elements.aimbot.aimbot_helper.settings.ssg.prefer_body_hp, elements.aimbot.aimbot_helper.settings.ssg.prefer_body_miss}, function (ref)
        ref:depend({elements.aimbot.aimbot_helper.settings.ssg.select, 'Prefer body aim'})
    end)
    elements.aimbot.aimbot_helper.settings.ssg.prefer_body_hp:depend({elements.aimbot.aimbot_helper.settings.ssg.prefer_body, 'Enemy HP < X'})
    elements.aimbot.aimbot_helper.settings.ssg.prefer_body_miss:depend({elements.aimbot.aimbot_helper.settings.ssg.prefer_body, 'X Missed Shots'})
    pui.traverse({elements.aimbot.aimbot_helper.settings.ssg.force_body, elements.aimbot.aimbot_helper.settings.ssg.force_body_hp, elements.aimbot.aimbot_helper.settings.ssg.force_body_miss}, function (ref)
        ref:depend({elements.aimbot.aimbot_helper.settings.ssg.select, 'Force body aim'})
    end)
    elements.aimbot.aimbot_helper.settings.ssg.force_body_hp:depend({elements.aimbot.aimbot_helper.settings.ssg.force_body, 'Enemy HP < X'})
    elements.aimbot.aimbot_helper.settings.ssg.force_body_miss:depend({elements.aimbot.aimbot_helper.settings.ssg.force_body, 'X Missed Shots'})
    elements.aimbot.aimbot_helper.settings.ssg.ping_spike_value:depend({elements.aimbot.aimbot_helper.settings.ssg.select, 'Ping spike'})
    elements.aimbot.aimbot_helper.settings.ssg.hitchance_in_air_value:depend({elements.aimbot.aimbot_helper.settings.ssg.select, 'Hitchance in air'})
    pui.traverse(elements.aimbot.aimbot_helper.settings.awp, function (ref)
        ref:depend({elements.aimbot.aimbot_helper.settings.weapon, 'AWP'})
    end)
    pui.traverse({elements.aimbot.aimbot_helper.settings.awp.force_safe, elements.aimbot.aimbot_helper.settings.awp.force_safe_hp, elements.aimbot.aimbot_helper.settings.awp.force_safe_miss}, function (ref)
        ref:depend({elements.aimbot.aimbot_helper.settings.awp.select, 'Force safe point'})
    end)
    elements.aimbot.aimbot_helper.settings.awp.force_safe_hp:depend({elements.aimbot.aimbot_helper.settings.awp.force_safe, 'Enemy HP < X'})
    elements.aimbot.aimbot_helper.settings.awp.force_safe_miss:depend({elements.aimbot.aimbot_helper.settings.awp.force_safe, 'X Missed Shots'})
    pui.traverse({elements.aimbot.aimbot_helper.settings.awp.prefer_body, elements.aimbot.aimbot_helper.settings.awp.prefer_body_hp, elements.aimbot.aimbot_helper.settings.awp.prefer_body_miss}, function (ref)
        ref:depend({elements.aimbot.aimbot_helper.settings.awp.select, 'Prefer body aim'})
    end)
    elements.aimbot.aimbot_helper.settings.awp.prefer_body_hp:depend({elements.aimbot.aimbot_helper.settings.awp.prefer_body, 'Enemy HP < X'})
    elements.aimbot.aimbot_helper.settings.awp.prefer_body_miss:depend({elements.aimbot.aimbot_helper.settings.awp.prefer_body, 'X Missed Shots'})
    pui.traverse({elements.aimbot.aimbot_helper.settings.awp.force_body, elements.aimbot.aimbot_helper.settings.awp.force_body_hp, elements.aimbot.aimbot_helper.settings.awp.force_body_miss}, function (ref)
        ref:depend({elements.aimbot.aimbot_helper.settings.awp.select, 'Force body aim'})
    end)
    elements.aimbot.aimbot_helper.settings.awp.force_body_hp:depend({elements.aimbot.aimbot_helper.settings.awp.force_body, 'Enemy HP < X'})
    elements.aimbot.aimbot_helper.settings.awp.force_body_miss:depend({elements.aimbot.aimbot_helper.settings.awp.force_body, 'X Missed Shots'})
    elements.aimbot.aimbot_helper.settings.awp.ping_spike_value:depend({elements.aimbot.aimbot_helper.settings.awp.select, 'Ping spike'})
    elements.aimbot.aimbot_helper.settings.awp.hitchance_in_air_value:depend({elements.aimbot.aimbot_helper.settings.awp.select, 'Hitchance in air'})
    pui.traverse(elements.aimbot.aimbot_helper.settings.auto, function (ref)
        ref:depend({elements.aimbot.aimbot_helper.settings.weapon, 'Auto Snipers'})
    end)
    pui.traverse({elements.aimbot.aimbot_helper.settings.auto.force_safe, elements.aimbot.aimbot_helper.settings.auto.force_safe_hp, elements.aimbot.aimbot_helper.settings.auto.force_safe_miss}, function (ref)
        ref:depend({elements.aimbot.aimbot_helper.settings.auto.select, 'Force safe point'})
    end)
    elements.aimbot.aimbot_helper.settings.auto.force_safe_hp:depend({elements.aimbot.aimbot_helper.settings.auto.force_safe, 'Enemy HP < X'})
    elements.aimbot.aimbot_helper.settings.auto.force_safe_miss:depend({elements.aimbot.aimbot_helper.settings.auto.force_safe, 'X Missed Shots'})
    pui.traverse({elements.aimbot.aimbot_helper.settings.auto.prefer_body, elements.aimbot.aimbot_helper.settings.auto.prefer_body_hp, elements.aimbot.aimbot_helper.settings.auto.prefer_body_miss}, function (ref)
        ref:depend({elements.aimbot.aimbot_helper.settings.auto.select, 'Prefer body aim'})
    end)
    elements.aimbot.aimbot_helper.settings.auto.prefer_body_hp:depend({elements.aimbot.aimbot_helper.settings.auto.prefer_body, 'Enemy HP < X'})
    elements.aimbot.aimbot_helper.settings.auto.prefer_body_miss:depend({elements.aimbot.aimbot_helper.settings.auto.prefer_body, 'X Missed Shots'})
    pui.traverse({elements.aimbot.aimbot_helper.settings.auto.force_body, elements.aimbot.aimbot_helper.settings.auto.force_body_hp, elements.aimbot.aimbot_helper.settings.auto.force_body_miss}, function (ref)
        ref:depend({elements.aimbot.aimbot_helper.settings.auto.select, 'Force body aim'})
    end)
    elements.aimbot.aimbot_helper.settings.auto.force_body_hp:depend({elements.aimbot.aimbot_helper.settings.auto.force_body, 'Enemy HP < X'})
    elements.aimbot.aimbot_helper.settings.auto.force_body_miss:depend({elements.aimbot.aimbot_helper.settings.auto.force_body, 'X Missed Shots'})
    elements.aimbot.aimbot_helper.settings.auto.ping_spike_value:depend({elements.aimbot.aimbot_helper.settings.auto.select, 'Ping spike'})
    elements.aimbot.aimbot_helper.settings.auto.hitchance_in_air_value:depend({elements.aimbot.aimbot_helper.settings.auto.select, 'Hitchance in air'})
    pui.traverse(elements.aimbot.ai_peek.settings, function (ref)
        ref:depend({elements.aimbot.ai_peek.enable, true})
    end)
    pui.traverse(elements.aimbot.game_enhancer.settings, function (ref)
        ref:depend({elements.aimbot.game_enhancer.enable, true})
    end)

    pui.traverse(elements.visuals, function (ref)
        ref:depend({tab.main, ' User Section'}, {tab.second, ' Visuals'})
    end)
    pui.traverse(elements.visuals.crosshair.settings, function (ref)
        ref:depend({elements.visuals.crosshair.enable, true})
    end)
    pui.traverse(elements.visuals.arrows.settings, function (ref)
        ref:depend({elements.visuals.arrows.enable, true})
    end)
    elements.visuals.arrows.settings.style:depend({elements.visuals.arrows.settings.type, 'Pointers'})
    elements.visuals.arrows.settings.hide_on_thirdperson:depend({elements.visuals.arrows.settings.type, 'Semicircle'})
    pui.traverse(elements.visuals.scope.settings, function (ref)
        ref:depend({elements.visuals.scope.enable, true})
    end)
    pui.traverse(elements.visuals.zoom.settings, function (ref)
        ref:depend({elements.visuals.zoom.enable, true})
    end)
    pui.traverse(elements.visuals.aspect_ratio.settings, function (ref)
        ref:depend({elements.visuals.aspect_ratio.enable, true})
    end)
    pui.traverse(elements.visuals.viewmodel.settings, function (ref)
        ref:depend({elements.visuals.viewmodel.enable, true})
    end)
    elements.visuals.auto_exposure.value:depend({elements.visuals.auto_exposure.enable, true})
    elements.visuals.side_indicators:set(true)
    pui.traverse(elements.visuals.watermark.settings, function (ref)
        ref:depend({elements.visuals.windows, 'Watermark'})
    end)
    elements.visuals.watermark.settings.color_2:depend({elements.visuals.watermark.settings.color_mode, 'Gradient'})
    elements.visuals.watermark.settings.gradient_speed:depend({elements.visuals.watermark.settings.color_mode, 'Gradient'})
    elements.visuals.watermark.settings.rainbow_speed:depend({elements.visuals.watermark.settings.color_mode, 'Rainbow'})
    pui.traverse(elements.visuals.event_logger.settings, function (ref)
        ref:depend({elements.visuals.windows, 'Event logger'})
    end)
    pui.traverse(elements.visuals.damage.settings, function (ref)
        ref:depend({elements.visuals.damage.enable, true})
    end)
    pui.traverse(elements.visuals.markers.settings, function (ref)
        ref:depend({elements.visuals.markers.enable, true})
    end)
    pui.traverse(elements.visuals.lagcomp_skeleton.settings, function (ref)
        ref:depend({elements.visuals.lagcomp_skeleton.enable, true})
    end)
    pui.traverse(elements.visuals.bullet_tracer.settings, function (ref)
        ref:depend({elements.visuals.bullet_tracer.enable, true})
    end)
    pui.traverse(elements.visuals.last_seen.settings, function (ref)
        ref:depend({elements.visuals.last_seen.enable, true})
    end)

    pui.traverse(elements.misc, function (ref)
        ref:depend({tab.main, ' Features'}, {elements.tab.combo, ' Miscellaneous'})
    end)
    pui.traverse(elements.misc.drop_nades.settings, function (ref)
        ref:depend({elements.misc.drop_nades.enable, true})
    end)
    pui.traverse(elements.misc.autobuy.settings, function (ref)
        ref:depend({elements.misc.autobuy.enable, true})
    end)
    pui.traverse(elements.misc.animations.settings, function (ref)
        ref:depend({elements.misc.animations.enable, true})
    end)
    pui.traverse(elements.misc.animations.settings.running, function (ref)
        ref:depend({elements.misc.animations.settings.condition, 'Running'})
    end)
    pui.traverse(elements.misc.animations.settings.in_air, function (ref)
        ref:depend({elements.misc.animations.settings.condition, 'In air'})
    end)
    pui.traverse(elements.misc.animations.settings.running.anim_bodylean, function (ref)
        ref:depend({elements.misc.animations.settings.running.anim_extra_type, 'Body lean'})
    end)
    pui.traverse({elements.misc.animations.settings.running.anim_min_jitter, elements.misc.animations.settings.running.anim_max_jitter}, function (ref)
        ref:depend({elements.misc.animations.settings.running.anim_type, 'Jitter'})
    end)
    pui.traverse(elements.misc.animations.settings.in_air.anim_bodylean, function (ref)
        ref:depend({elements.misc.animations.settings.in_air.anim_extra_type, 'Body lean'})
    end)
    pui.traverse({elements.misc.animations.settings.in_air.anim_min_jitter, elements.misc.animations.settings.in_air.anim_max_jitter}, function (ref)
        ref:depend({elements.misc.animations.settings.in_air.anim_type, 'Jitter'})
    end)
    pui.traverse(elements.misc.trash_talk.settings, function (ref)
        ref:depend({elements.misc.trash_talk.enable, true})
    end)
end

local drag_slider = {
    crosshair = {
        y = menu.group.anti_aim.main:slider('Y Crosshair', 0, screen_size_y(), helpers:clamp(screen_size_y() / 2 + 20, 0, screen_size_y() - 76)),
    },
    arrows = {
        x = menu.group.anti_aim.main:slider('X Arrows', 0, screen_size_x(), helpers:clamp(screen_size_x() / 2 + 30, 0, screen_size_x() - 147)),
    },
    advert = {
        text_style = menu.group.anti_aim.main:combobox('Text style', {'Default', 'Bold', 'Small'}),
        x = menu.group.anti_aim.main:slider('X Advert Watermark', 0, screen_size_x(), helpers:clamp(15, 0, screen_size_x() - 147)),
        y = menu.group.anti_aim.main:slider('Y Advert Watermark', 0, screen_size_y(), helpers:clamp(screen_size_y() / 2 - 20, 0, screen_size_y() - 76)),
    },
    windows = {
        watermark = {
            x = menu.group.anti_aim.main:slider('X Watermark', 0, screen_size_x(), helpers:clamp(screen_size_x(), 0, screen_size_x() - 5)),
            y = menu.group.anti_aim.main:slider('Y Watermark', 0, screen_size_y(), helpers:clamp(screen_size_y(), 0, screen_size_y() / 168)),
        },

        keybinds = {
            x = menu.group.anti_aim.main:slider('X Keybinds', 0, screen_size_x(), helpers:clamp(screen_size_x(), 0, screen_size_x() * 0.7)),
            y = menu.group.anti_aim.main:slider('Y Keybinds', 0, screen_size_y(), helpers:clamp(screen_size_y(), 0, screen_size_y() / 2 - 60)),
        },

        spectators = {
            x = menu.group.anti_aim.main:slider('X Spectators', 0, screen_size_x(), helpers:clamp(screen_size_x(), 0, screen_size_x() - 5)),
            y = menu.group.anti_aim.main:slider('Y Spectators', 0, screen_size_y(), helpers:clamp(screen_size_y(), 0, screen_size_y() / 2)),
        },

        event_logger = {
            x = menu.group.anti_aim.main:slider('X Event logger', 0, screen_size_x(), helpers:clamp(screen_size_x(), 0, screen_size_x() / 2)),
            y = menu.group.anti_aim.main:slider('Y Event logger', 0, screen_size_y(), helpers:clamp(screen_size_y(), 0, screen_size_y() / 2 + 270)),
        },

        debug_panel = {
            x = menu.group.anti_aim.main:slider('X Debug panel', 0, screen_size_x(), helpers:clamp(20, 0, screen_size_x() - 147)),
            y = menu.group.anti_aim.main:slider('Y Debug panel', 0, screen_size_y(), helpers:clamp(screen_size_y() / 2 - 400, 0, screen_size_y() - 76)),
        },

        multi_panel = {
            x = menu.group.anti_aim.main:slider('X Multi panel', 0, screen_size_x(), helpers:clamp(screen_size_x() / 2, 0, screen_size_x() - 147)),
            y = menu.group.anti_aim.main:slider('Y Multi panel', 0, screen_size_y(), helpers:clamp(screen_size_y() / 2 - 400, 0, screen_size_y() - 76)),
        },
    },
    damage_indicator = {
        x = menu.group.anti_aim.main:slider('X Damage indicator', 0, screen_size_x(), helpers:clamp(screen_size_x() / 2 + 5, 0, screen_size_x() - 147)),
        y = menu.group.anti_aim.main:slider('Y Damage indicator', 0, screen_size_y(), helpers:clamp(screen_size_y() / 2 - 10, 0, screen_size_y() - 76)),
    },
} do
    pui.traverse(drag_slider, function (ref)
        ref:set_visible(false)
    end)
end

---

local lc = {
    last_simtime = 0,
    origin = vector(0, 0, 0),
    state = false
} local function is_breaking_velocity_lc ()
    local me = entity.get_local_player()
    local new_origin = vector(entity.get_origin(me))
    local simtime = toticks(entity.get_prop(me, 'm_flSimulationTime'))
    local delta = simtime - lc.last_simtime
  
    if delta > 0 then
      if lc.origin:length() > 0 then
        lc.state = (lc.origin - new_origin):length2dsqr() > 4096
      end
      lc.origin = new_origin
      lc.last_simtime = simtime
    end
  
    return lc.state
end

local fakelag = { choked = 0, active = false }; do
    fakelag.handle = function (e)
        fakelag.choked = e.chokedcommands
        fakelag.active = false
        if reference.antiaim.fakelag.enabled:get() then
            if reference.antiaim.fakelag.limit:get() > 2 then
                if reference.rage.aimbot.double_tap[1].value and reference.rage.aimbot.double_tap[1].hotkey:get() and not reference.rage.other.fake_duck:get() then
                    if fakelag.choked > reference.rage.aimbot.double_tap_limit:get() then
                        fakelag.active = true
                    end
                elseif reference.antiaim.other.on_shot_anti_aim[1].value and reference.antiaim.other.on_shot_anti_aim[1].hotkey:get() and not reference.rage.other.fake_duck:get() then
                    if fakelag.choked > 1 then
                        fakelag.active = true
                    end
                else
                    if fakelag.choked ~= nil then
                        fakelag.active = true
                    end
                end
            end
        end
    end
  
    client.set_event_callback('run_command', fakelag.handle)
end

local anti_backstab = false
local builder = { }; do
    builder.conditions = {'Global', 'Stand', 'Run', 'Walk', 'Crouch', 'Sneak', 'Air', 'Air+', 'Fake lag', 'Freestanding', 'Manual left', 'Manual right'}
    builder.alternative_conditions = { }
    for _, condition in ipairs(builder.conditions) do
        local prefix = coloring.set_color_macro(false)
        local suffix = coloring.set_color_macro(true)
        table.insert(builder.alternative_conditions, string.format('\a%s•\a%s  %s', prefix, suffix, condition))
    end
    builder.state = 'Global'
    builder.d_state = 'Global'

    elements.conditions = { }
    elements.conditions.select = menu.group.anti_aim.main:combobox('\v\r    Player state', builder.alternative_conditions)
    
    local is_tab_antiaim = {tab.main, ' Anti-aimbot angles'}
    elements.conditions.select:depend(is_tab_antiaim)

    elements.conditions.select_2 = menu.group.anti_aim.main:combobox('\v\r    Player state', builder.conditions)
    elements.conditions.select_2:set_visible(false)

    elements.conditions.select:set_callback(function (ref)
        for _, condition in ipairs(builder.alternative_conditions) do
            if ref:get() == condition then
                elements.conditions.select_2:set(builder.conditions[_])
            end
        end
    end)

    for i, state in pairs(builder.conditions) do
        local colored_state = builder.alternative_conditions[i]
        elements.conditions[state] = {
            spacing = menu.group.anti_aim.main:label(' \n' .. state),
            enable = menu.group.anti_aim.main:checkbox('Enable  ' .. colored_state),
        
            yaw_base = menu.group.anti_aim.other:combobox('\nYaw base \n' .. state, {'Local view', 'At targets'}),
            spacing_7 = menu.group.anti_aim.other:label('       \n' .. state),
            yaw_left_right = menu.group.anti_aim.other:checkbox('Yaw \v»\r Left  Right mode \n' .. state),

            offset = menu.group.anti_aim.main:slider('\nYaw offset \n' .. state, -180, 180, 0, true, '°'),
            left = menu.group.anti_aim.main:slider('\nYaw left \n' .. state, -180, 180, 0, true, '°'),
            left_randomization = menu.group.anti_aim.main:slider('\nYaw left random \n' .. state, 0, 100, 0, true, '%'),
            right = menu.group.anti_aim.main:slider('\nYaw right \n' .. state, -180, 180, 0, true, '°'),
            right_randomization = menu.group.anti_aim.main:slider('\nYaw right random \n' .. state, 0, 100, 0, true, '%'),
        
            spacing_2 = menu.group.anti_aim.main:label('  \n' .. state),
            modifier_label = menu.group.anti_aim.main:label('\v\r    Yaw jitter\n' .. state),
            spacing_8 = menu.group.anti_aim.main:label('        \n' .. state),
            modifier = menu.group.anti_aim.main:combobox('\nYaw modifier \n' .. state, {'Off', 'Offset', 'Center', 'Ground-based', 'X-way', 'Random'}),
            ideal_yaw = menu.group.anti_aim.main:checkbox('\nIdeal yaw \n' .. state),
            modifier_offset = menu.group.anti_aim.main:slider('\nModifier Offset \n' .. state, -180, 180, 0, true, '°'),
            modifier_offset_2 = menu.group.anti_aim.main:slider('\nModifier Offset #2 \n' .. state, -180, 180, 0, true, '°'),
            modifier_randomization = menu.group.anti_aim.main:slider('\nRandomization \n' .. state, 0, 100, 0, true, '%'),

            x_way = {
                method = menu.group.anti_aim.main:combobox('Method \n' .. state, {'Skitter', 'Tickcount'}),
                type = menu.group.anti_aim.main:combobox('Type \n' .. state, {'Auto', 'Custom'}),
                ways = menu.group.anti_aim.main:slider('\nWays \n' .. state, 3, 10, 3, true, 'w'),
                auto_offset = menu.group.anti_aim.main:slider('\nAuto offset \n' .. state, -180, 180, 0, true, '°'),
                first_offset = menu.group.anti_aim.main:slider('\nFirst offset \n' .. state, -180, 180, 0, true, '°'),
                second_offset = menu.group.anti_aim.main:slider('\nSecond offset \n' .. state, -180, 180, 0, true, '°'),
                third_offset = menu.group.anti_aim.main:slider('\nThird offset \n' .. state, -180, 180, 0, true, '°'),
                fourth_offset = menu.group.anti_aim.main:slider('\nFourth offset \n' .. state, -180, 180, 0, true, '°'),
                fifth_offset = menu.group.anti_aim.main:slider('\nFifth offset \n' .. state, -180, 180, 0, true, '°'),
                sixth_offset = menu.group.anti_aim.main:slider('\nSixth offset \n' .. state, -180, 180, 0, true, '°'),
                seventh_offset = menu.group.anti_aim.main:slider('\nSeventh offset \n' .. state, -180, 180, 0, true, '°'),
                eighth_offset = menu.group.anti_aim.main:slider('\nEighth offset \n' .. state, -180, 180, 0, true, '°'),
                ninth_offset = menu.group.anti_aim.main:slider('\nNinth offset \n' .. state, -180, 180, 0, true, '°'),
                tenth_offset = menu.group.anti_aim.main:slider('\nTenth offset \n' .. state, -180, 180, 0, true, '°'),
            },
        
            spacing_6 = menu.group.anti_aim.main:label('      \n' .. state),
            body_label = menu.group.anti_aim.main:label('\v\r    Body yaw\n' .. state),
            spacing_4 = menu.group.anti_aim.main:label('    \n' .. state),
            body_yaw = menu.group.anti_aim.main:combobox('\nBody yaw \n' .. state, {'Off', 'Opposite', 'Static', 'Jitter'}),
            body_side = menu.group.anti_aim.main:combobox('Body side \n' .. state, {'+', '-'}),
            fs_body_yaw = menu.group.anti_aim.main:checkbox('Freestanding body yaw \n' .. state),

            spacing_3 = menu.group.anti_aim.main:label('   \n' .. state),
            delay_label = menu.group.anti_aim.main:label('\v\r    Delay\n' .. state),
            spacing_9 = menu.group.anti_aim.main:label('         \n' .. state),
            delay = menu.group.anti_aim.main:slider('\nBody delay \n' .. state, 1, 17, 1, true, 't', 1, {[1] = 'OFF'}),
            small_delay_min_toggle = menu.group.anti_aim.main:checkbox('\nToggle body small min. delay \n' .. state),
            small_delay_min = menu.group.anti_aim.main:slider('\nBody small min. delay \n' .. state, 1, 12, 1, true, 't', 0.2),
            delay_min = menu.group.anti_aim.main:slider('\nBody Min. delay \n' .. state, 1, 17, 1, true, 't', 1, {[1] = 'OFF'}),
            small_delay_max_toggle = menu.group.anti_aim.main:checkbox('\nToggle body small max. delay \n' .. state),
            small_delay_max = menu.group.anti_aim.main:slider('\nBody small max. delay \n' .. state, 1, 12, 1, true, 't', 0.2),
            delay_max = menu.group.anti_aim.main:slider('\nBody Max. delay \n' .. state, 1, 17, 17, true, 't', 1, {[1] = 'OFF'}),
            
            freeze_chance = menu.group.anti_aim.main:slider('\nBody freeze chance \n' .. state, 1, 100, 18, true, '%', 1),
            freeze_time = menu.group.anti_aim.main:slider('\nBody freeze time \n' .. state, 1, 200, 30, true, 'ms', 1),
        
            spacing_5 = menu.group.anti_aim.main:label('     \n' .. state),
            addons = menu.group.anti_aim.main:multiselect('\vDelay »\r Add-ons \n' .. state, {'Randomize Delay Ticks', 'Freeze-Inverter'})
        }
    end

    do
        for i, state in pairs(builder.conditions) do
            local colored_state = builder.alternative_conditions[i]

            local condition = elements.conditions[state]
            local is_condition = {elements.conditions.select, colored_state}
            local disable_shared = {elements.conditions.select, function () return (i ~= 1) end}
            local is_enabled = {condition.enable, function () if i == 1 then return true else return condition.enable:get() end end}
            local fakelag_state = {elements.conditions.select, function () if i == 9 then return false else return true end end}
            local function not_disabled(val) 
                return function () return condition[val]:get() ~= 'Off' end 
            end
        
            condition.spacing:depend(is_tab_antiaim, is_condition, {elements.anti_aim.tab, ' Builder'})
            condition.enable:depend(is_tab_antiaim, is_condition, disable_shared, {elements.anti_aim.tab, ' Builder'})
            
            condition.yaw_base:depend(is_tab_antiaim, is_condition, is_enabled, {elements.anti_aim.tab, ' Builder'})
            condition.spacing_7:depend(is_tab_antiaim, is_condition, is_enabled, {elements.anti_aim.tab, ' Builder'})
            condition.yaw_left_right:depend(is_tab_antiaim, is_condition, is_enabled, {elements.anti_aim.tab, ' Builder'})
            
            condition.offset:depend(is_tab_antiaim, is_condition, is_enabled, {condition.yaw_left_right, false}, {elements.anti_aim.tab, ' Builder'})
            condition.left:depend(is_tab_antiaim, is_condition, is_enabled, {condition.yaw_left_right, true}, {elements.anti_aim.tab, ' Builder'})
            condition.left_randomization:depend(is_tab_antiaim, is_condition, is_enabled, {condition.yaw_left_right, true}, {elements.anti_aim.tab, ' Builder'})
            condition.right:depend(is_tab_antiaim, is_condition, is_enabled, {condition.yaw_left_right, true}, {elements.anti_aim.tab, ' Builder'})
            condition.right_randomization:depend(is_tab_antiaim, is_condition, is_enabled, {condition.yaw_left_right, true}, {elements.anti_aim.tab, ' Builder'})
        
            condition.spacing_2:depend(is_tab_antiaim, is_condition, is_enabled, {elements.anti_aim.tab, ' Builder'})
            condition.modifier_label:depend(is_tab_antiaim, is_condition, is_enabled, {elements.anti_aim.tab, ' Builder'})
            condition.modifier:depend(is_tab_antiaim, is_condition, is_enabled, {elements.anti_aim.tab, ' Builder'})
            condition.spacing_8:depend(is_tab_antiaim, is_condition, is_enabled, {elements.anti_aim.tab, ' Builder'})
            condition.ideal_yaw:depend(is_tab_antiaim, is_condition, is_enabled, {condition.modifier, function () 
                return condition.modifier:get() ~= 'Off' and condition.modifier:get() ~= 'Custom' and condition.modifier:get() ~= 'X-way'
            end}, {elements.anti_aim.tab, ' Builder'})
            condition.modifier_offset:depend(is_tab_antiaim, is_condition, is_enabled, {condition.modifier, function () 
                return condition.modifier:get() ~= 'Off' and condition.modifier:get() ~= 'Custom' and condition.modifier:get() ~= 'X-way'
            end}, {elements.anti_aim.tab, ' Builder'})
            condition.modifier_offset_2:depend(is_tab_antiaim, is_condition, is_enabled, {condition.modifier, function () 
                return condition.modifier:get() ~= 'Off' and condition.modifier:get() ~= 'Custom' and condition.modifier:get() ~= 'X-way'
            end}, {condition.ideal_yaw, true}, {elements.anti_aim.tab, ' Builder'})
            condition.modifier_randomization:depend(is_tab_antiaim, is_condition, is_enabled, {condition.modifier, function () 
                return condition.modifier:get() ~= 'Off' and condition.modifier:get() ~= 'Custom' and condition.modifier:get() ~= 'X-way'
            end}, {condition.ideal_yaw, false}, {elements.anti_aim.tab, ' Builder'})

            pui.traverse(condition.x_way, function (ref)
                ref:depend(is_tab_antiaim, is_condition, is_enabled, {condition.modifier, 'X-way'}, {elements.anti_aim.tab, ' Builder'})
            end)

            condition.x_way.auto_offset:depend({condition.x_way.type, 'Auto'})

            for n = 1, 10 do
                local delay_slider = condition.x_way[string.format('%s_offset', ({
                    'first', 'second', 'third', 'fourth', 'fifth',
                    'sixth', 'seventh', 'eighth', 'ninth', 'tenth'
                })[n])]
    
                if delay_slider then
                    delay_slider:depend(
                        {condition.x_way.type, 'Custom'},
                        {condition.x_way.ways, function (ref)
                            return ref:get() >= n
                        end}
                    )
                end
            end

            condition.spacing_6:depend(is_tab_antiaim, is_condition, is_enabled, {elements.anti_aim.tab, ' Builder'})
            condition.body_label:depend(is_tab_antiaim, is_condition, is_enabled, {elements.anti_aim.tab, ' Builder'})
            condition.spacing_4:depend(is_tab_antiaim, is_condition, is_enabled, {elements.anti_aim.tab, ' Builder'})
            condition.body_yaw:depend(is_tab_antiaim, is_condition, is_enabled, {elements.anti_aim.tab, ' Builder'})
            condition.body_side:depend(is_tab_antiaim, is_condition, is_enabled, {condition.body_yaw, not_disabled('body_yaw')}, {elements.anti_aim.tab, ' Builder'}, {condition.body_yaw, function () if condition.body_yaw:get() == 'Opposite' or condition.body_yaw:get() == 'Jitter' then return false else return true end end})
            condition.fs_body_yaw:depend(is_tab_antiaim, is_condition, is_enabled, {condition.body_yaw, not_disabled('body_yaw')}, {elements.anti_aim.tab, ' Builder'})
            
            condition.spacing_3:depend(is_tab_antiaim, is_condition, is_enabled, {elements.anti_aim.tab, ' Builder', {condition.body_yaw, not_disabled('body_yaw')}})
            condition.delay_label:depend(is_tab_antiaim, is_condition, is_enabled, {elements.anti_aim.tab, ' Builder'}, {condition.body_yaw, not_disabled('body_yaw')})
            condition.spacing_9:depend(is_tab_antiaim, is_condition, is_enabled, {elements.anti_aim.tab, ' Builder', {condition.body_yaw, not_disabled('body_yaw')}})
            condition.delay:depend(is_tab_antiaim, is_condition, is_enabled, {condition.body_yaw, not_disabled('body_yaw')}, {elements.anti_aim.tab, ' Builder'}, {condition.addons, function () if not condition.ideal_yaw:get() and condition.addons:get('Randomize Delay Ticks') then return false else return true end end})
            condition.small_delay_min_toggle:depend(is_tab_antiaim, is_condition, is_enabled, {condition.body_yaw, not_disabled('body_yaw')}, {elements.anti_aim.tab, ' Builder'}, {condition.ideal_yaw, false}, {condition.addons, 'Randomize Delay Ticks'})
            condition.small_delay_min:depend(is_tab_antiaim, is_condition, is_enabled, {condition.body_yaw, not_disabled('body_yaw')}, {elements.anti_aim.tab, ' Builder'}, {condition.ideal_yaw, false}, {condition.addons, 'Randomize Delay Ticks'}, {condition.small_delay_min_toggle, true})
            condition.delay_min:depend(is_tab_antiaim, is_condition, is_enabled, {condition.body_yaw, not_disabled('body_yaw')}, {elements.anti_aim.tab, ' Builder'}, {condition.ideal_yaw, false}, {condition.addons, 'Randomize Delay Ticks'}, {condition.small_delay_min_toggle, false})
            condition.small_delay_max_toggle:depend(is_tab_antiaim, is_condition, is_enabled, {condition.body_yaw, not_disabled('body_yaw')}, {elements.anti_aim.tab, ' Builder'}, {condition.ideal_yaw, false}, {condition.addons, 'Randomize Delay Ticks'})
            condition.small_delay_max:depend(is_tab_antiaim, is_condition, is_enabled, {condition.body_yaw, not_disabled('body_yaw')}, {elements.anti_aim.tab, ' Builder'}, {condition.ideal_yaw, false}, {condition.addons, 'Randomize Delay Ticks'}, {condition.small_delay_max_toggle, true})     
            condition.delay_max:depend(is_tab_antiaim, is_condition, is_enabled, {condition.body_yaw, not_disabled('body_yaw')}, {elements.anti_aim.tab, ' Builder'}, {condition.ideal_yaw, false}, {condition.addons, 'Randomize Delay Ticks'}, {condition.small_delay_max_toggle, false})

            condition.freeze_chance:depend(is_tab_antiaim, is_condition, is_enabled, {condition.body_yaw, not_disabled('body_yaw')}, {elements.anti_aim.tab, ' Builder'}, {condition.ideal_yaw, false}, {condition.addons, 'Freeze-Inverter'})
            condition.freeze_time:depend(is_tab_antiaim, is_condition, is_enabled, {condition.body_yaw, not_disabled('body_yaw')}, {elements.anti_aim.tab, ' Builder'}, {condition.ideal_yaw, false}, {condition.addons, 'Freeze-Inverter'})

            condition.spacing_5:depend(is_tab_antiaim, is_condition, is_enabled, {condition.body_yaw, not_disabled('body_yaw')}, {condition.ideal_yaw, false}, {elements.anti_aim.tab, ' Builder'})
            condition.addons:depend(is_tab_antiaim, is_condition, is_enabled, {condition.body_yaw, not_disabled('body_yaw')}, {condition.ideal_yaw, false}, {elements.anti_aim.tab, ' Builder'})
        end
    end

    elements.defensive = { }
    for i, state in pairs(builder.conditions) do
        local colored_state = builder.alternative_conditions[i]
        elements.defensive[state] = {
            spacing = menu.group.anti_aim.main:label(' \nD_' .. state),
            enable = menu.group.anti_aim.main:checkbox('Enable  ' .. colored_state .. ' \nD'),

            toggle_builder = menu.group.anti_aim.main:checkbox('\nToggle Builder \nD_' .. state),
            defensive_on = menu.group.anti_aim.main:multiselect('\nDefensive \v»\r Work on \nD_' .. state, {'Double tap', 'Hide shots'}),
            defensive_mode = menu.group.anti_aim.main:combobox('\nDefensive \v»\r Mode \nD_' .. state, {'On peek', 'Always on'}),
            spacing_1 = menu.group.anti_aim.main:label('  \nD_' .. state),
        
            duration = menu.group.anti_aim.other:slider('\v⯌\r    Duration \nD_' .. state, 1, 15, 15, true, 't', 1, {[15] = 'Maximum'}),
            spacing_9 = menu.group.anti_aim.other:label('        \nD_' .. state),
            pitch_min_max = menu.group.anti_aim.other:checkbox('Pitch \v»\r Min. - Max. mode \nD_' .. state),
            pitch_height_based = menu.group.anti_aim.other:checkbox('Pitch \v»\r Height based value \nD_' .. state),
            yaw_left_right = menu.group.anti_aim.other:checkbox('Yaw \v»\r Left  Right mode \nD_' .. state),
            yaw_generation = menu.group.anti_aim.other:checkbox('Yaw \v»\r Generation \nD_' .. state),

            yaw_label = menu.group.anti_aim.main:label('\v\r    Yaw\nD_' .. state),
            spacing_5 = menu.group.anti_aim.main:label('     \nD_' .. state),
            yaw = menu.group.anti_aim.main:combobox('\nYaw \v»\r Type \nD_' .. state, {'Off', '180', 'Spin', 'Distortion', 'Sway', 'Freestand'}),
            speed = menu.group.anti_aim.main:slider('\nYaw speed \nD_' .. state, 1, 17, 4, true, 't'),
            offset = menu.group.anti_aim.main:slider('\nYaw offset \nD_' .. state, -180, 180, 0, true, '°'),
            left = menu.group.anti_aim.main:slider('\nYaw left \nD_' .. state, -180, 180, 0, true, '°'),
            right = menu.group.anti_aim.main:slider('\nYaw right \nD_' .. state, -180, 180, 0, true, '°'),
            min_gen = menu.group.anti_aim.main:slider('\nYaw min. \nD_' .. state, -180, 180, -20, true, '°-'),
            max_gen = menu.group.anti_aim.main:slider('\nYaw max. \nD_' .. state, -180, 180, 20, true, '°+'),

            spacing_3 = menu.group.anti_aim.main:label('   \nD_' .. state),
            pitch_label = menu.group.anti_aim.main:label('\v\r    Pitch\nD_' .. state),
            spacing_4 = menu.group.anti_aim.main:label('    \nD_' .. state),
            pitch_mode = menu.group.anti_aim.main:combobox('\nPitch \v»\r Mode \nD_' .. state, {'Static', 'Spin', 'Sway', 'Jitter', 'Cycling', 'Random'}),
            pitch_speed = menu.group.anti_aim.main:slider('\nPitch speed \nD_' .. state, 1, 17, 2, true, 't'),
            pitch = menu.group.anti_aim.main:slider('\nPitch \nD_' .. state, -89, 89, 0, true, '°'),
            pitch_min = menu.group.anti_aim.main:slider('\nPitch Min. \nD_' .. state, -89, 89, 0, true, '°'),
            pitch_max = menu.group.anti_aim.main:slider('\nPitch Max. \nD_' .. state, -89, 89, 0, true, '°'),

            spacing_6 = menu.group.anti_aim.main:label('     \nD_' .. state),
            delay_label = menu.group.anti_aim.main:label('\v\r    Delay\nD_' .. state),
            spacing_7 = menu.group.anti_aim.main:label('         \nD_' .. state),
            delay = menu.group.anti_aim.main:slider('\nBody delay \nD_' .. state, 1, 34, 1, true, 't', 1, {[1] = 'OFF'}),
            delay_min = menu.group.anti_aim.main:slider('\nBody Min. delay \nD_' .. state, 1, 34, 1, true, 't', 1, {[1] = 'OFF'}),
            delay_max = menu.group.anti_aim.main:slider('\nBody Max. delay \nD_' .. state, 1, 34, 34, true, 't', 1, {[1] = 'OFF'}),
            
            freeze_chance = menu.group.anti_aim.main:slider('\nBody freeze chance \nD_' .. state, 1, 100, 18, true, '%', 1),
            freeze_time = menu.group.anti_aim.main:slider('\nBody freeze time \nD_' .. state, 1, 200, 30, true, 'ms', 1),
        
            spacing_8 = menu.group.anti_aim.main:label('       \nD_' .. state),
            addons = menu.group.anti_aim.main:multiselect('\vDelay »\r Add-ons \nD_' .. state, {'Randomize Delay Ticks', 'Freeze-Inverter'})
        }
    end

    do
        for i, state in pairs(builder.conditions) do
            local colored_state = builder.alternative_conditions[i]

            local condition = elements.defensive[state]
            local is_condition = {elements.conditions.select, colored_state}
            local disable_shared = {elements.conditions.select, function () return (i ~= 1) end}
            local is_enabled = {condition.enable, function () if i == 1 then return true else return condition.enable:get() end end}
            local fakelag_state = {elements.conditions.select, function () if i == 9 then return false else return true end end}
            local function not_disabled(val) 
                return function () return condition[val]:get() ~= 'Off' end 
            end
        
            condition.spacing:depend(is_tab_antiaim, is_condition, fakelag_state, {elements.anti_aim.tab, ' Defensive'})
            condition.enable:depend(is_tab_antiaim, is_condition, disable_shared, fakelag_state, {elements.anti_aim.tab, ' Defensive'})

            condition.defensive_on:depend(is_tab_antiaim, is_condition, is_enabled, fakelag_state, {elements.anti_aim.tab, ' Defensive'})
            condition.defensive_mode:depend(is_tab_antiaim, is_condition, is_enabled, fakelag_state, {elements.anti_aim.tab, ' Defensive'})
            condition.toggle_builder:depend(is_tab_antiaim, is_condition, is_enabled, fakelag_state, {elements.anti_aim.tab, ' Defensive'})
            condition.spacing_1:depend(is_tab_antiaim, is_condition, is_enabled, fakelag_state, {elements.anti_aim.tab, ' Defensive'})

            condition.duration:depend(is_tab_antiaim, is_condition, is_enabled, fakelag_state, {condition.toggle_builder, true}, {elements.anti_aim.tab, ' Defensive'})
            condition.spacing_9:depend(is_tab_antiaim, is_condition, is_enabled, fakelag_state, {condition.toggle_builder, true}, {elements.anti_aim.tab, ' Defensive'})
            condition.pitch_min_max:depend(is_tab_antiaim, is_condition, is_enabled, fakelag_state, {condition.toggle_builder, true}, {condition.pitch_height_based, false}, {elements.anti_aim.tab, ' Defensive'})
            condition.pitch_height_based:depend(is_tab_antiaim, is_condition, is_enabled, fakelag_state, {condition.toggle_builder, true}, {elements.anti_aim.tab, ' Defensive'})
            condition.yaw_left_right:depend(is_tab_antiaim, is_condition, is_enabled, fakelag_state, {condition.toggle_builder, true}, {condition.yaw, not_disabled('yaw')}, {elements.anti_aim.tab, ' Defensive'})
            condition.yaw_generation:depend(is_tab_antiaim, is_condition, is_enabled, fakelag_state, {condition.toggle_builder, true}, {condition.yaw, not_disabled('yaw')}, {elements.anti_aim.tab, ' Defensive'})
            
            condition.spacing_5:depend(is_tab_antiaim, is_condition, is_enabled, fakelag_state, {condition.toggle_builder, true}, {condition.yaw, not_disabled('yaw')}, {elements.anti_aim.tab, ' Defensive'})
            condition.yaw_label:depend(is_tab_antiaim, is_condition, is_enabled, fakelag_state, {condition.toggle_builder, true}, {elements.anti_aim.tab, ' Defensive'})
            condition.yaw:depend(is_tab_antiaim, is_condition, is_enabled, fakelag_state, {condition.toggle_builder, true}, {elements.anti_aim.tab, ' Defensive'})
            condition.speed:depend(is_tab_antiaim, is_condition, is_enabled, fakelag_state, {condition.toggle_builder, true}, {condition.yaw, function () if condition.yaw:get() == 'Off' or condition.yaw:get() == '180' or condition.yaw:get() == 'Spin' or condition.yaw:get() == 'Freestand' then return false else return true end end}, {elements.anti_aim.tab, ' Defensive'})
            condition.offset:depend(is_tab_antiaim, is_condition, is_enabled, fakelag_state, {condition.toggle_builder, true}, {condition.yaw, not_disabled('yaw')}, {condition.yaw_left_right, false}, {elements.anti_aim.tab, ' Defensive'})
            condition.left:depend(is_tab_antiaim, is_condition, is_enabled, fakelag_state, {condition.toggle_builder, true}, {condition.yaw, not_disabled('yaw')}, {condition.yaw_left_right, true}, {elements.anti_aim.tab, ' Defensive'})
            condition.right:depend(is_tab_antiaim, is_condition, is_enabled, fakelag_state, {condition.toggle_builder, true}, {condition.yaw, not_disabled('yaw')}, {condition.yaw_left_right, true}, {elements.anti_aim.tab, ' Defensive'})
            condition.min_gen:depend(is_tab_antiaim, is_condition, is_enabled, fakelag_state, {condition.toggle_builder, true}, {condition.yaw, not_disabled('yaw')}, {condition.yaw_generation, true}, {elements.anti_aim.tab, ' Defensive'})
            condition.max_gen:depend(is_tab_antiaim, is_condition, is_enabled, fakelag_state, {condition.toggle_builder, true}, {condition.yaw, not_disabled('yaw')}, {condition.yaw_generation, true}, {elements.anti_aim.tab, ' Defensive'})

            condition.spacing_3:depend(is_tab_antiaim, is_condition, is_enabled, fakelag_state, {condition.toggle_builder, true}, {elements.anti_aim.tab, ' Defensive'})
            condition.pitch_label:depend(is_tab_antiaim, is_condition, is_enabled, fakelag_state, {condition.toggle_builder, true}, {elements.anti_aim.tab, ' Defensive'})
            condition.spacing_4:depend(is_tab_antiaim, is_condition, is_enabled, fakelag_state, {condition.toggle_builder, true}, {elements.anti_aim.tab, ' Defensive'})
            condition.pitch_mode:depend(is_tab_antiaim, is_condition, is_enabled, fakelag_state, {condition.toggle_builder, true}, {elements.anti_aim.tab, ' Defensive'})
            condition.pitch_speed:depend(is_tab_antiaim, is_condition, is_enabled, fakelag_state, {condition.toggle_builder, true}, {elements.anti_aim.tab, ' Defensive'}, {condition.pitch_mode, function () if condition.pitch_mode:get() == 'Static' or condition.pitch_mode:get() == 'Random' then return false else return true end end})
            condition.pitch:depend(is_tab_antiaim, is_condition, is_enabled, fakelag_state, {condition.toggle_builder, true}, {condition.pitch_min_max, false}, {condition.pitch_height_based, false}, {elements.anti_aim.tab, ' Defensive'})
            condition.pitch_min:depend(is_tab_antiaim, is_condition, is_enabled, fakelag_state, {condition.toggle_builder, true}, {condition.pitch_min_max, true}, {condition.pitch_height_based, false}, {elements.anti_aim.tab, ' Defensive'})
            condition.pitch_max:depend(is_tab_antiaim, is_condition, is_enabled, fakelag_state, {condition.toggle_builder, true}, {condition.pitch_min_max, true}, {condition.pitch_height_based, false}, {condition.pitch_mode, 'Static', true}, {elements.anti_aim.tab, ' Defensive'})

            condition.spacing_6:depend(is_tab_antiaim, is_condition, is_enabled, fakelag_state, {condition.toggle_builder, true}, {elements.anti_aim.tab, ' Defensive'})
            condition.delay_label:depend(is_tab_antiaim, is_condition, is_enabled, fakelag_state, {condition.toggle_builder, true}, {elements.anti_aim.tab, ' Defensive'})
            condition.spacing_7:depend(is_tab_antiaim, is_condition, is_enabled, fakelag_state, {condition.toggle_builder, true}, {elements.anti_aim.tab, ' Defensive'})
            condition.delay:depend(is_tab_antiaim, is_condition, is_enabled, fakelag_state, {condition.toggle_builder, true},{elements.anti_aim.tab, ' Defensive'}, {condition.addons, function () if condition.addons:get('Randomize Delay Ticks') then return false else return true end end})
            condition.delay_min:depend(is_tab_antiaim, is_condition, is_enabled, fakelag_state, {condition.toggle_builder, true}, {elements.anti_aim.tab, ' Defensive'}, {condition.addons, 'Randomize Delay Ticks'})
            condition.delay_max:depend(is_tab_antiaim, is_condition, is_enabled, fakelag_state, {condition.toggle_builder, true}, {elements.anti_aim.tab, ' Defensive'}, {condition.addons, 'Randomize Delay Ticks'})
            condition.freeze_chance:depend(is_tab_antiaim, is_condition, is_enabled, fakelag_state, {condition.toggle_builder, true}, {elements.anti_aim.tab, ' Defensive'}, {condition.addons, 'Freeze-Inverter'})
            condition.freeze_time:depend(is_tab_antiaim, is_condition, is_enabled, fakelag_state, {condition.toggle_builder, true}, {elements.anti_aim.tab, ' Defensive'}, {condition.addons, 'Freeze-Inverter'})

            condition.spacing_8:depend(is_tab_antiaim, is_condition, is_enabled, fakelag_state, {condition.toggle_builder, true}, {elements.anti_aim.tab, ' Defensive'})
            condition.addons:depend(is_tab_antiaim, is_condition, is_enabled, fakelag_state, {condition.toggle_builder, true}, {elements.anti_aim.tab, ' Defensive'})
        end
    end

    local state_logic = { }
    local state = {
        space = menu.group.anti_aim.other:label(' '),
        export = menu.group.anti_aim.other:button('\v\r State To \v»\r ⛟', function ()
            state_logic.export()
        end),
        import = menu.group.anti_aim.other:button('\v\r State From \v«\r ⛴', function ()
            state_logic.import()
        end),
        reset = menu.group.anti_aim.other:button('\v♻️\r Reset', function ()
            state_logic.reset()
        end),
    } do
        state_logic.export = function ()
            local setup = pui.setup(elements.conditions[elements.conditions.select_2:get()], true)
            if elements.anti_aim.tab:get() == ' Defensive' then
                setup = pui.setup(elements.defensive[elements.conditions.select_2:get()], true)
            end
            clipboard.set(base64.encode(json.stringify(setup:save())))
        end

        state_logic.import = function ()
            local setup = pui.setup(elements.conditions[elements.conditions.select_2:get()], true)
            if elements.anti_aim.tab:get() == ' Defensive' then
                setup = pui.setup(elements.defensive[elements.conditions.select_2:get()], true)
            end
            setup:load(json.parse(base64.decode(clipboard.get())))
        end

        state_logic.reset = function ()
            local setup = pui.setup(elements.conditions[elements.conditions.select_2:get()], true)
            local reset = 'eyJlbmFibGUiOmZhbHNlLCJib2R5X3NpZGUiOiIrIiwibW9kaWZpZXJfb2Zmc2V0IjowLCJib2R5X3lhdyI6Ik9mZiIsImFkZG9ucyI6WyJ+Il0sImRlbGF5X21pbiI6MSwib2Zmc2V0IjowLCJkZWxheSI6MSwieWF3X2xlZnRfcmlnaHQiOmZhbHNlLCJ5YXdfYmFzZSI6IkxvY2FsIFZpZXciLCJtb2RpZmllcl9vZmZzZXRfMiI6MCwibW9kaWZpZXJfb2Zmc2V0XzMiOjAsIm1vZGlmaWVyX3dheXNfbW9kZSI6IkF1dG9tYXRpYyIsInJpZ2h0IjowLCJtb2RpZmllcl93YXlzIjoxLCJsZWZ0IjowLCJtb2RpZmllcl9vZmZzZXRfNSI6MCwiZGVsYXlfbWF4IjoxNywiZnJlZXplX3RpbWUiOjMwLCJtb2RpZmllciI6Ik9mZiIsImZyZWV6ZV9jaGFuY2UiOjE4LCJtb2RpZmllcl9vZmZzZXRfNCI6MCwibW9kaWZpZXJfcmFuZG9taXphdGlvbiI6MH0='
            if elements.anti_aim.tab:get() == ' Defensive' then
                setup = pui.setup(elements.defensive[elements.conditions.select_2:get()], true)
                reset = 'eyJlbmFibGUiOmZhbHNlLCJwaXRjaF9tb2RlIjoiU3RhdGljIiwicGl0Y2giOjAsInJpZ2h0IjowLCJtYXhfZ2VuIjoyMCwieWF3IjoiT2ZmIiwidG9nZ2xlX2J1aWxkZXIiOmZhbHNlLCJ5YXdfZ2VuZXJhdGlvbiI6ZmFsc2UsImxlZnQiOjAsIm9mZnNldCI6MCwiZGVmZW5zaXZlX21vZGUiOiJPbiBwZWVrIiwieWF3X2Jhc2UiOiJMb2NhbCB2aWV3IiwiZGVmZW5zaXZlX29uIjpbIn4iXSwibWluX2dlbiI6LTIwLCJ5YXdfbGVmdF9yaWdodCI6ZmFsc2V9'
            end
            setup:load(json.parse(base64.decode(reset)))
        end

        pui.traverse(state, function (ref)
            ref:depend({tab.main, ' Anti-aimbot angles'}, {elements.anti_aim.tab, ' Other', true})
        end)
    end

    builder.manual_tick = 0
    local function manual ()
        local manual_mode = elements.anti_aim.hotkeys.manual_mode.value
        if manual_mode == 1 or manual_mode == 2 then
            builder.selected_manual = builder.selected_manual or 0
            local tick = globals.tickcount()

            local function handle_press(key, value)
                if elements.anti_aim.hotkeys[key]:get() and (manual_mode == 1 and not builder[key..'_pressed'] or manual_mode == 2 and builder.manual_tick < tick - 11) then
                    builder.selected_manual = builder.selected_manual == value and 0 or value
                    builder.manual_tick = tick
                end
                builder[key..'_pressed'] = elements.anti_aim.hotkeys[key]:get()
            end

            handle_press('left', 1)
            handle_press('right', 2)
            handle_press('forward', 3)
            
            if elements.anti_aim.hotkeys.reset:get() and not builder.reset_pressed then
                builder.selected_manual = 0
            end
            builder.reset_pressed = elements.anti_aim.hotkeys.reset:get()

            return builder.selected_manual
        end
    end

    builder.side = 1
    builder.delay_ticks = { default = 0, defensive = 0 }
    builder._freeze_state = { active = false, _until = 0 }
    builder.current_tick = 0
    local function inverter (e, state)
        local me = entity.get_local_player()
        local body_yaw = math.floor(entity.get_prop(me, 'm_flPoseParameter', 11) * 120 - 60)
        local condition = elements.conditions
        local delay_key = 'default'

        if e.chokedcommands == 0 then
            builder.current_tick = globals.tickcount()
            if elements.conditions[state].body_yaw:get() ~= 'Off' then
                if condition[state].addons:get('Freeze-Inverter') then
                    local freeze_chance = condition[state].freeze_chance:get()
                    local freeze_time = condition[state].freeze_time:get()
                    if not builder._freeze_state.active then
                        if client.random_int(1, 100) <= freeze_chance then
                            builder._freeze_state.active = true
                            builder._freeze_state._until = builder.current_tick + freeze_time
                        end
                    end
                    if builder._freeze_state.active then
                        if builder.current_tick < builder._freeze_state._until then
                            return builder.side
                        else
                            builder._freeze_state.active = false
                            builder._freeze_state._until = 0
                        end
                    end
                else
                    builder._freeze_state = { active = false, _until = 0 }
                end

                if condition[state].delay:get() > 1 or condition[state].addons:get('Randomize Delay Ticks') or elements.conditions[state].body_yaw:get() ~= 'Jitter' then
                    local delay = condition[state].delay:get()
                    if condition[state].addons:get('Randomize Delay Ticks') then
                        local delay_min = condition[state].delay_min:get()
                        local delay_max = condition[state].delay_max:get()

                        if condition[state].small_delay_min_toggle:get() then
                            delay_min = condition[state].small_delay_min:get() * 0.2
                        end

                        if condition[state].small_delay_max_toggle:get() then
                            delay_max = condition[state].small_delay_max:get() * 0.2
                        end

                        math.randomseed(globals.tickcount())
                        delay = math.random(delay_min, delay_max)
                    end
                    -- print(delay)
                    if builder.delay_ticks[delay_key] < builder.current_tick - delay then
                        builder.delay_ticks[delay_key] = builder.current_tick
                        builder.side = builder.side == 1 and -1 or 1
                        if builder._freeze_state then
                            builder._freeze_state.active = false
                            builder._freeze_state._until = 0
                        end
                    end
                elseif condition[state].delay:get() == 1 and elements.conditions[state].body_yaw:get() == 'Jitter' then
                    builder.side = (body_yaw > 0 and 1 or body_yaw < 0 and -1)
                    if builder._freeze_state then
                        builder._freeze_state.active = false
                        builder._freeze_state._until = 0
                    end
                end
            else
                if builder._freeze_state then
                    builder._freeze_state.active = false
                    builder._freeze_state._until = 0
                end
                if builder.delay_ticks[delay_key] < builder.current_tick - 1 then
                    builder.delay_ticks[delay_key] = builder.current_tick
                    builder.side = builder.side == 1 and -1 or 1
                end
            end
        end

        return builder.side
    end

    -- @lordmouse: TODO исправить это говнище и сделать всё в одной функции
    builder.d_side = 1
    local function d_inverter (e, state)
        local me = entity.get_local_player()
        local body_yaw = math.floor(entity.get_prop(me, 'm_flPoseParameter', 11) * 120 - 60)
        local condition = elements.defensive
        local delay_key = 'defensive'

        if e.chokedcommands == 0 then
            local current_tick = globals.tickcount()
            -- if elements.conditions[state].body_yaw:get() ~= 'Off' then
                if condition[state].delay:get() > 1 or condition[state].addons:get('Randomize Delay Ticks') then
                    local delay = condition[state].delay:get()
                    if condition[state].addons:get('Randomize Delay Ticks') then
                        local delay_min = condition[state].delay_min:get()
                        local delay_max = condition[state].delay_max:get()
                        -- delay = client.random_int(delay_min, delay_max)
                        math.randomseed(globals.tickcount())
                        delay = math.random(delay_min, delay_max)
                    end

                    -- print(builder.delay_ticks[delay_key] < current_tick - delay)
                    if builder.delay_ticks[delay_key] < current_tick - delay then
                        builder.delay_ticks[delay_key] = current_tick
                        builder.d_side = builder.d_side == 1 and -1 or 1
                    end
                elseif condition[state].delay:get() == 1 then
                    builder.d_side = (body_yaw > 0 and 1 or body_yaw < 0 and -1)
                end
            -- else
            --     if builder.delay_ticks[delay_key] < current_tick - 1 then
            --         builder.delay_ticks[delay_key] = current_tick
            --         builder.d_side = builder.d_side == 1 and -1 or 1
            --     end
            -- end
        end

        return builder.d_side
    end

    local function is_condition_enabled(table, condition)
        return table[condition] and table[condition].enable:get()
    end

    function builder.get_state ()
        local condition = helpers.get_state()

        if not (is_condition_enabled(elements.conditions, condition)) then
            condition = 'Global'
        end

        if reference.antiaim.fakelag.enabled:get() then
            if is_condition_enabled(elements.conditions, 'Fake lag') then
                if fakelag.active then
                    condition = 'Fake lag'
                end
            end
        end

        if (is_condition_enabled(elements.conditions, 'Freestanding')) and reference.antiaim.angles.freestanding[1]:get() and reference.antiaim.angles.freestanding[1].hotkey:get() then
            condition = 'Freestanding'
        end

        local manual_aa = manual()
        if manual_aa == 1 then
            condition = 'Manual left'
        elseif manual_aa == 2 then
            condition = 'Manual right'
        end

        return condition
    end

    function builder.d_get_state ()
        local condition = helpers.get_state()

        if not (is_condition_enabled(elements.defensive, condition)) then
            condition = 'Global'
        end

        if (is_condition_enabled(elements.defensive, 'Freestanding')) and reference.antiaim.angles.freestanding[1]:get() and reference.antiaim.angles.freestanding[1].hotkey:get() then
            condition = 'Freestanding'
        end

        local manual_aa = manual()
        if manual_aa == 1 then
            condition = 'Manual left'
        elseif manual_aa == 2 then
            condition = 'Manual right'
        end

        return condition
    end

    local function angle_diff (a1, a2)
        local diff = a1 - a2
        while diff > 180 do
            diff = diff - 360
        end
        while diff < -180 do
            diff = diff + 360
        end
        return diff
    end
    
    local function normalize_yaw (yaw)
        while yaw > 180 do
            yaw = yaw - 360
        end
        while yaw < -180 do
            yaw = yaw + 360
        end
        return yaw
    end

    local skitter_per_tick = false
    local skitter_accumulated_offset = 0
    local skitter_goal_feet_yaw = 0
    local skitter_last_view_angle = 0
    local skitter_initialized = false

    local function get_skitter_offset_per_tick (base_offset)
        if not skitter_initialized then
            skitter_last_view_angle = base_offset
            skitter_goal_feet_yaw = base_offset
            skitter_accumulated_offset = 0
            skitter_initialized = true
            return base_offset
        end
        
        skitter_per_tick = not skitter_per_tick
        
        local current_view_angle = base_offset + skitter_accumulated_offset
        
        local interval_per_tick = globals.tickinterval()
        local angle_difference = math.abs(angle_diff(current_view_angle, skitter_goal_feet_yaw))
        local v43 = angle_difference / interval_per_tick

        v43 = math.min(v43, 180)
        
        local angle_addition = 0
        if v43 >= 35 then
            angle_addition = v43 * (skitter_per_tick and 1 or 0)
        elseif v43 <= 35 then
            angle_addition = v43 * (skitter_per_tick and 1 or 0)
        end

        skitter_accumulated_offset = skitter_accumulated_offset + angle_addition
        
        if math.abs(skitter_accumulated_offset) > 180 then
            skitter_accumulated_offset = skitter_accumulated_offset * 0.1
        end
        
        skitter_goal_feet_yaw = normalize_yaw(current_view_angle)
        
        return base_offset + math.max(-45, math.min(45, angle_addition))
    end

    local function apply_skitter_direct (base_offset)
        return get_skitter_offset_per_tick(base_offset)
    end
    
    local pitch_add = 0
    local generated_yaw = 0

    builder._random_jitter_freeze = { active = false, _until = 0 }
    builder._random_jitter_tick = 0
    builder._random_jitter_value = 0

    builder._xway_offsets = { _xway_tick = 0, _xway_last_tick = 0, _xway_idx = 1 }
    builder._xway_freeze_state = { active = false, _until = 0 }
    builder._xway_tick = 0
    builder._xway_last_tick = 0
    builder._xway_idx = 1
    function builder.angles (e)
        builder.state = builder.get_state()

        local me = entity.get_local_player()
        local tick = globals.tickcount()

        local cond = elements.conditions[builder.state]
        local pitch, pitch_offset = 'down', 89
        local yaw = '180'
        local yaw_base, offset, yaw_jitter, jitter_offset, body_yaw, body_side, fs_body_yaw = cond.yaw_base:get(), cond.offset:get(), cond.modifier:get(), cond.modifier_offset:get(), cond.body_yaw:get(), cond.body_side:get(), cond.fs_body_yaw:get()
        
        local body_side_value = 1
        if body_yaw == 'Static' then
            if body_side == '-' then
                body_side_value = -1
            end
        end

        local left, right = cond.left:get(), cond.right:get()
        local left_rand, right_rand = cond.left_randomization:get(), cond.right_randomization:get()
        local inverted = inverter(e, builder.state)
        if cond.yaw_left_right:get() then
            local rand_offset = 0
            if inverted == 1 and left_rand > 0 then
                rand_offset = client.random_int(-left_rand, left_rand)
            elseif inverted == -1 and right_rand > 0 then
                rand_offset = client.random_int(-right_rand, right_rand)
            end

            offset = ((inverted == 1 and left or inverted == -1 and right) or left) + rand_offset
        end

        if (yaw_jitter ~= 'Off' or yaw_jitter ~= 'Custom' or yaw_jitter ~= 'X-way') and cond.modifier_randomization:get() > 0 then
            local randomization_factor = cond.modifier_randomization:get()
            local hp = me and entity.get_prop(me, 'm_iHealth') or 100
            local velocity = me and (entity.get_prop(me, 'm_vecVelocity', 0) or 0) or 0
            local seed = globals.tickcount() + builder.state:byte(1, -1) + hp + math.floor(velocity)
            math.randomseed(seed)

            local r1 = math.random(-randomization_factor, randomization_factor)
            local r2 = math.random(-randomization_factor, randomization_factor)
            local random_offset = math.floor((r1 + r2) / 2 + math.sin(globals.realtime() * 5) * (randomization_factor / 4))
            jitter_offset = jitter_offset + random_offset
        end

        if (yaw_jitter ~= 'Off' or yaw_jitter ~= 'Custom' or yaw_jitter ~= 'X-way') and cond.ideal_yaw:get() then
            local body_yaw = math.floor(entity.get_prop(me, 'm_flPoseParameter', 11) * 120 - 60)
            if body_yaw ~= 'Off' and yaw_jitter ~= 'Ground-based' and cond.delay:get() > 1 then
                local raw_jitter_offset = (inverted == 1 and jitter_offset / 2 or inverted == -1 and cond.modifier_offset_2:get() / 2) or 0
                offset =  (offset + raw_jitter_offset) - body_yaw
                
                yaw_jitter = 'Off'  
                jitter_offset = 0
            else
                local raw_jitter_offset = (inverted == 1 and -jitter_offset or inverted == -1 and cond.modifier_offset_2:get() - 1) or 0
                local compensated_jitter_offset = raw_jitter_offset - body_yaw
                jitter_offset = compensated_jitter_offset
                -- print(body_yaw)
            end
        end

        local delay = cond.delay:get() or 1
        if delay < 1 then delay = 1 end
    
        if cond.addons:get('Randomize Delay Ticks') then
            local delay_min = cond.delay_min:get()
            local delay_max = cond.delay_max:get()
            if cond.small_delay_min_toggle:get() then
                delay_min = cond.small_delay_min:get() * 0.2
            end
            if cond.small_delay_max_toggle:get() then
                delay_max = cond.small_delay_max:get() * 0.2
            end
    
            math.randomseed(tick)
            delay = math.random(delay_min, delay_max)
        end

        if body_yaw ~= 'Off' then
            if cond.delay:get() > 1 or cond.addons:get('Randomize Delay Ticks') then
                body_side_value = (inverted == 1 and -1 or inverted == -1 and 1) or 0   
                body_yaw = cond.body_yaw:get() == 'Jitter' and 'Static' or cond.body_yaw:get()

                if yaw_jitter ~= 'Off' and yaw_jitter ~= 'Ground-based' and yaw_jitter ~= 'X-way' then
                    if yaw_jitter == 'Offset' then
                        offset = offset + (inverted == -1 and jitter_offset or 0)
                    elseif yaw_jitter == 'Center' then
                        offset = offset + ((inverted == 1 and -jitter_offset / 2 or inverted == -1 and jitter_offset / 2) or 0)
                    elseif yaw_jitter == 'Random' then
                        if cond.addons:get('Freeze-Inverter') then
                            local freeze_chance = cond.freeze_chance:get()
                            local freeze_time = cond.freeze_time:get()
                            if not builder._random_jitter_freeze.active then
                                if client.random_int(1, 100) <= freeze_chance then
                                    builder._random_jitter_freeze.active = true
                                    builder._random_jitter_freeze._until = tick + freeze_time
                                end
                            end
                            if builder._random_jitter_freeze.active then
                                if tick < builder._random_jitter_freeze._until then
                                    offset = offset + builder._random_jitter_value
                                else
                                    builder._random_jitter_freeze.active = false
                                    builder._random_jitter_freeze._until = 0
                                end
                            end
                        end

                        if not (builder._random_jitter_freeze and builder._random_jitter_freeze.active) then
                            if tick - (builder._random_jitter_tick or 0) >= delay then
                                builder._random_jitter_value = client.random_int(-jitter_offset, jitter_offset)
                                builder._random_jitter_tick = tick
                            end
                            offset = offset + builder._random_jitter_value
                        end
                    end

                    yaw_jitter = 'Off'  
                    jitter_offset = 0
                end
            end
        end

        if yaw_jitter == 'Ground-based' then
            local my_pos = vector(entity.get_origin(me))
            local threat = client.current_threat()
            local height_to_threat = 0
            if threat then
                local enemy_pos = vector(entity.get_origin(threat))
                height_to_threat = math.ceil(my_pos.z - enemy_pos.z)
            end
        
            local scale = helpers:clamp((80 - height_to_threat) / 100, 0.15, 1.0)
            local final_offset = jitter_offset * scale

            offset = offset + ((inverted == 1 and -final_offset or inverted == -1 and final_offset) or 0)
        
            yaw_jitter = 'Off'
            jitter_offset = 0
        elseif yaw_jitter == 'X-way' then
            local xway = cond.x_way
            local method = xway.method:get()
            local xway_type = xway.type:get()
            local ways = xway.ways:get()
            local auto_offset = xway.auto_offset:get() / 2
        
            builder._xway_offsets[builder.state] = { _xway_tick = 0, _xway_last_tick = 0, _xway_idx = 1, _tickcount = 0 }
        
            local offsets = builder._xway_offsets[builder.state]
        
            if xway_type == 'Auto' then
                local max_spread = 90
                local spread = math.min(math.abs(auto_offset), max_spread)

                local step_size = (spread * 2) / (ways - 1)

                for i = 1, ways do
                    offsets[i] = -spread + (step_size * (i - 1))
                    if auto_offset < 0 then
                        offsets[i] = -offsets[i]
                    end
                end
            else
                offsets[1] = xway.first_offset:get()
                if ways >= 2 then offsets[2] = xway.second_offset:get() end
                if ways >= 3 then offsets[3] = xway.third_offset:get() end
                if ways >= 4 then offsets[4] = xway.fourth_offset:get() end
                if ways >= 5 then offsets[5] = xway.fifth_offset:get() end
                if ways >= 6 then offsets[6] = xway.sixth_offset:get() end
                if ways >= 7 then offsets[7] = xway.seventh_offset:get() end
                if ways >= 8 then offsets[8] = xway.eighth_offset:get() end
                if ways >= 9 then offsets[9] = xway.ninth_offset:get() end
                if ways >= 10 then offsets[10] = xway.tenth_offset:get() end
            end
        
            local freeze_chance = cond.freeze_chance:get()
            local freeze_time = cond.freeze_time:get()
            local should_freeze = false
            
            if cond.addons:get('Freeze-Inverter') then
                if not builder._xway_freeze_state.active then
                    if client.random_int(1, 100) <= freeze_chance then
                        builder._xway_freeze_state.active = true
                        builder._xway_freeze_state._until = tick + freeze_time
                    end
                end
        
                if builder._xway_freeze_state.active then
                    if tick < builder._xway_freeze_state._until then
                        should_freeze = true
                    else
                        builder._xway_freeze_state.active = false
                        builder._xway_freeze_state._until = 0
                    end
                end
            else
                builder._xway_freeze_state = { active = false, _until = 0 }
            end

            if not should_freeze then
                if method == 'Tickcount' then
                    builder._tickcount = (builder._tickcount or 0) + 1
                    if builder._tickcount >= 2 then
                        builder._xway_idx = (builder._xway_idx % ways) + 1
                        builder._tickcount = 0
                    end
                else
                    if builder._xway_last_tick == 0 then
                        builder._xway_last_tick = tick
                    end
            
                    if tick - builder._xway_last_tick >= delay then
                        builder._xway_idx = (builder._xway_idx % ways) + 1
                        builder._xway_last_tick = tick
                    end
                end
            end
        
            local idx = builder._xway_idx
        
            if method == 'Skitter' then
                local base_offset = offsets[idx] or 0
                local final_offset = apply_skitter_direct(base_offset)
                offset = offset + final_offset
            elseif method == 'Tickcount' then
                offset = offset + (offsets[idx] or 0)
            end
        
            jitter_offset = 0
            yaw_jitter = 'Off'
        elseif yaw_jitter == 'Custom' then

            yaw_jitter = 'Off'
        end

        local manual_aa = manual()
        local manual_offsets = {-90, 90, 180}
        if manual_aa >= 1 and manual_aa <= 3 then
            reference.antiaim.angles.freestanding[1]:override(false)
            local condition_met = (manual_aa == 1 and not elements.conditions['Manual left'].enable.value) or (manual_aa == 2 and not elements.conditions['Manual right'].enable.value) or (manual_aa == 3)
            
            if condition_met then
                offset = manual_offsets[manual_aa]
                yaw_base = 'Local View'
                yaw_jitter = 'Off'
                body_yaw = 'Static'
                body_side_value = 11
            end
        end

        builder.d_state = builder.d_get_state()

        local defensive = {
            yaw = elements.defensive[builder.d_state].yaw:get(),
            speed = elements.defensive[builder.d_state].speed:get(),
            offset = elements.defensive[builder.d_state].offset:get(),
            left = elements.defensive[builder.d_state].left:get(),
            right = elements.defensive[builder.d_state].right:get(),
            min_gen = elements.defensive[builder.d_state].min_gen:get(),
            max_gen = elements.defensive[builder.d_state].max_gen:get(),
            duration = elements.defensive[builder.d_state].duration:get(),
            pitch_min_max = elements.defensive[builder.d_state].pitch_min_max:get(),
            pitch_height_based = elements.defensive[builder.d_state].pitch_height_based:get(),
            yaw_left_right = elements.defensive[builder.d_state].yaw_left_right:get(),
            yaw_generation = elements.defensive[builder.d_state].yaw_generation:get(),
            pitch_mode = elements.defensive[builder.d_state].pitch_mode:get(),
            pitch_speed = elements.defensive[builder.d_state].pitch_speed:get(),
            pitch = elements.defensive[builder.d_state].pitch:get(),
            pitch_min = elements.defensive[builder.d_state].pitch_min:get(),
            pitch_max = elements.defensive[builder.d_state].pitch_max:get()
        }

        local toggle_defensive = false
        if builder.d_state ~= 'Global' and elements.defensive[builder.d_state].enable:get() then
            toggle_defensive = true
        elseif builder.d_state == 'Global' then
            toggle_defensive = true
        else
            toggle_defensive = false
        end
        if toggle_defensive then
            if (elements.defensive[builder.d_state].defensive_on:get('Double tap') and exploits:is_doubletap()) or (elements.defensive[builder.d_state].defensive_on:get('Hide shots') and exploits:is_hideshots() and not exploits:is_doubletap()) then
                if elements.defensive[builder.d_state].defensive_mode:get() == 'On peek' then
                    exploits:should_force_defensive(false)
                elseif elements.defensive[builder.d_state].defensive_mode:get() == 'Always on' then
                    exploits:should_force_defensive(true)
                end
                local disable_defensive_aa = false
                local threat = client.current_threat()
                if elements.anti_aim.settings.list:get('Off defensive aa vs low ping') and threat then
                    local resource = entity.get_player_resource(threat)
                    if not resource then 
                        disable_defensive_aa = true
                    end

                    local ping = entity.get_prop(resource, 'm_iPing', threat)
                    if not ping or (ping < 15) then 
                        disable_defensive_aa = true 
                    end
                end

                if elements.defensive[builder.d_state].toggle_builder:get() and exploits:in_defensive(defensive.duration) and not disable_defensive_aa then
                    local d_inverted = d_inverter(e, builder.d_state)

                    pitch = 'custom'
                    pitch_offset = defensive.pitch
                    yaw = defensive.yaw
                    offset = defensive.offset
                    yaw_jitter = 'Off'
    
                    -- @lordmouse: TODO fix this shitcode
                    if defensive.pitch_height_based then
                        local my_pos = vector(entity.get_origin(entity.get_local_player()))
                        local threat = client.current_threat()
                        local height_diff = 0
                        if threat then
                            local enemy_pos = vector(entity.get_origin(threat))
                            height_diff = math.ceil(my_pos.z - enemy_pos.z)
                        end

                        local height_based_min = math.max(-89, -89 + height_diff)
                        local height_based_max = math.min(89, 89 + height_diff)

                        if defensive.pitch_mode == 'Jitter' then
                            local speed = math.max(1, math.min(defensive.pitch_speed, 15))
                            local interval = math.floor(math.floor(1 / globals.tickinterval()) / speed)
                            local phase = math.floor(globals.tickcount() / interval) % 2
                            pitch = 'custom'
                            pitch_offset = (phase == 0) and height_based_min or height_based_max
                        elseif defensive.pitch_mode == 'Random' then
                            pitch = 'custom'
                            pitch_offset = client.random_int(height_based_min, height_based_max)
                        elseif defensive.pitch_mode == 'Cycling' then
                            local cycle_speed = defensive.pitch_speed
                            if pitch_add >= height_based_max then pitch_add = height_based_min else pitch_add = pitch_add + cycle_speed end
                            pitch = 'custom'
                            pitch_offset = pitch_add
                        elseif defensive.pitch_mode == 'Spin' then
                            local spin_speed = defensive.pitch_speed
                            local mid = (height_based_min + height_based_max) / 2
                            local amp = math.abs(height_based_max - height_based_min) / 2
                            pitch = 'custom'
                            pitch_offset = mid + math.sin(globals.realtime() * spin_speed) * amp
                        elseif defensive.pitch_mode == 'Sway' then
                            local sway_speed = defensive.pitch_speed
                            local mid = (height_based_min + height_based_max) / 2
                            local amp = math.abs(height_based_max - height_based_min) / 2
                            pitch = 'custom'
                            pitch_offset = mid + math.sin(globals.realtime() * sway_speed) * amp * (math.cos(globals.realtime() * sway_speed * 0.5) + 1) / 2
                        else
                            pitch = 'custom'
                            pitch_offset = height_based_min
                        end
                    elseif defensive.pitch_min_max then
                        if defensive.pitch_mode == 'Jitter' then
                            local speed = math.max(1, math.min(defensive.pitch_speed, 15))
                            local interval = math.floor(math.floor(1 / globals.tickinterval()) / speed)
                            local phase = math.floor(globals.tickcount() / interval) % 2
                            pitch = 'custom'
                            pitch_offset = (phase == 0) and defensive.pitch_min or defensive.pitch_max
                        elseif defensive.pitch_mode == 'Random' then
                            pitch = 'custom'
                            pitch_offset = client.random_int(defensive.pitch_min, defensive.pitch_max)
                        elseif defensive.pitch_mode == 'Cycling' then
                            local cycle_speed = defensive.pitch_speed
                            if pitch_add >= defensive.pitch_max then pitch_add = defensive.pitch_min else pitch_add = pitch_add + cycle_speed end
                            pitch = 'custom'
                            pitch_offset = pitch_add
                        elseif defensive.pitch_mode == 'Spin' then
                            local spin_speed = defensive.pitch_speed
                            local mid = (defensive.pitch_min + defensive.pitch_max) / 2
                            local amp = math.abs(defensive.pitch_max - defensive.pitch_min) / 2
                            pitch = 'custom'
                            pitch_offset = mid + math.sin(globals.realtime() * spin_speed) * amp
                        elseif defensive.pitch_mode == 'Sway' then
                            local sway_speed = defensive.pitch_speed
                            local mid = (defensive.pitch_min + defensive.pitch_max) / 2
                            local amp = math.abs(defensive.pitch_max - defensive.pitch_min) / 2
                            pitch = 'custom'
                            pitch_offset = mid + math.sin(globals.realtime() * sway_speed) * amp * (math.cos(globals.realtime() * sway_speed * 0.5) + 1) / 2
                        else
                            pitch = 'custom'
                            pitch_offset = defensive.pitch_min
                        end
                    else
                        pitch = 'custom'
                        pitch_offset = defensive.pitch
                        if defensive.pitch_mode == 'Spin' then
                            local spin_speed = defensive.pitch_speed
                            pitch_offset = math.sin(globals.realtime() * spin_speed) * pitch_offset
                        elseif defensive.pitch_mode == 'Sway' then
                            local sway_speed = defensive.pitch_speed
                            local sway_amplitude = pitch_offset * 0.5
                            pitch_offset = math.sin(globals.realtime() * sway_speed) * sway_amplitude * (math.cos(globals.realtime() * sway_speed * 0.5) + 1)
                        elseif defensive.pitch_mode == 'Jitter' then
                            local speed = math.max(1, math.min(defensive.pitch_speed, 15))
                            local interval = math.floor(math.floor(1 / globals.tickinterval()) / speed)
                            local phase = math.floor(globals.tickcount() / interval) % 2
                            local switch_amount = (phase == 0) and pitch_offset or -pitch_offset
                            pitch_offset = switch_amount
                        elseif defensive.pitch_mode == 'Cycling' then
                            local cycle_speed = defensive.pitch_speed
                            if pitch_add >= -pitch_offset then pitch_add = pitch_offset else pitch_add = pitch_add + cycle_speed end
                            pitch_offset = pitch_add
                        elseif defensive.pitch_mode == 'Random' then
                            pitch_offset = client.random_int(pitch_offset <= 0 and pitch_offset or -pitch_offset, pitch_offset <= 0 and -pitch_offset or pitch_offset)
                        end
                    end
    
                    if defensive.yaw_left_right then
                        offset = (d_inverted == 1 and defensive.left or d_inverted == -1 and defensive.right) or defensive.left
                    end
    
                    if defensive.yaw_generation then
                        local min_gen, max_gen = defensive.min_gen, defensive.max_gen
                        if exploits.ticks_processed <= 2 then
                            generated_yaw = nil
                        elseif exploits.ticks_processed > 2 then
                            if not generated_yaw then
                                generated_yaw = client.random_int(min_gen, max_gen)
                            end

                            offset = offset + generated_yaw
                        end
                    end
    
                    if yaw == 'Distortion' then
                        yaw = '180'
                        local distortion_speed = defensive.speed
                        local distortion_amplitude = offset * 1.5
                        local distortion_time = globals.realtime() * distortion_speed
                        offset = offset + math.sin(distortion_time) * distortion_amplitude
                    elseif yaw == 'Sway' then
                        yaw = '180'
                        local sway_speed = defensive.speed
                        local sway_amplitude = offset
                        local sway_time = globals.realtime() * sway_speed
                        offset = offset + math.sin(sway_time) * sway_amplitude * (math.cos(sway_time * 0.5) + 1) / 2
                    elseif yaw == 'Freestand' then
                        yaw = '180'
                        offset = helpers.get_freestand_direction(entity.get_local_player()) == -1 and -offset or offset
                    end
                end
            end
        end

        -- print('builder: forcing defensive - ' .. tostring(e.force_defensive))

        return {
            pitch = pitch,
            pitch_offset = pitch_offset,
            yaw = yaw,
            yaw_base = yaw_base,
            offset = offset,
            yaw_jitter = yaw_jitter,
            jitter_offset = jitter_offset,
            body_yaw = body_yaw,
            body_side = body_side_value,
            fs_body_yaw = fs_body_yaw
        }
    end

    function reset_angles ()
        reference.antiaim.angles.enabled:override(true)
        reference.antiaim.angles.pitch[1]:override('Down')
        reference.antiaim.angles.pitch[2]:override(0)

        reference.antiaim.angles.yaw[1]:override('180')
        reference.antiaim.angles.yaw_base:override('Local view')

        reference.antiaim.angles.freestanding[1]:override(false)
        reference.antiaim.angles.edge_yaw:override(false)
        
        reference.antiaim.angles.yaw[2]:override(0)
        reference.antiaim.angles.yaw_jitter[1]:override('Off')
        reference.antiaim.angles.yaw_jitter[2]:override(0)
        
        reference.antiaim.angles.body_yaw[1]:override('Off')
        reference.antiaim.angles.body_yaw[2]:override(0)
        reference.antiaim.angles.fs_body_yaw:override(false)
    end

    local function set_angles (e)
        exploits:should_force_defensive(false)
        
        local state = helpers.get_state()
        local me = entity.get_local_player()
        if not me or not entity.is_alive(me) then
            reset_angles()
            return
        end

        local angles = builder.angles(e)

        reference.antiaim.fakelag.amount:override()
        reference.antiaim.fakelag.limit:override()
        reference.misc.settings.anti_untrusted:override()
        if elements.anti_aim.exploits.exploit:get() and elements.anti_aim.exploits.exploit.hotkey:get() then
            reference.misc.settings.anti_untrusted:override(false)

            -- local distortion_speed = 1
            -- local distortion_amplitude = 360 * 1.5
            -- local distortion_time = globals.realtime() * distortion_speed
            -- local test_offset = math.cos(distortion_time) * distortion_amplitude

            e.pitch = -540
            e.yaw = e.yaw + 180 + helpers:clamp(angles.offset, -180, 180)

            reference.antiaim.fakelag.amount:override('Dynamic')
            reference.antiaim.fakelag.limit:override(14)
            return
        end

        reference.antiaim.angles.enabled:override(true)
        reference.antiaim.angles.pitch[1]:override(angles.pitch)
        reference.antiaim.angles.pitch[2]:override(helpers:clamp(angles.pitch_offset, -89, 89))

        reference.antiaim.angles.yaw[1]:override(angles.yaw)
        reference.antiaim.angles.yaw_base:override(angles.yaw_base)

        reference.antiaim.angles.freestanding[1]:override(not elements.anti_aim.hotkeys.freestanding_disablers:get(state) and elements.anti_aim.hotkeys.freestanding.value and elements.anti_aim.hotkeys.freestanding.hotkey:get() or false)
        reference.antiaim.angles.freestanding[1]:set_hotkey('Always On')
        reference.antiaim.angles.edge_yaw:override(elements.anti_aim.hotkeys.edge_yaw.value and elements.anti_aim.hotkeys.edge_yaw.hotkey:get() or false)
        
        reference.antiaim.angles.yaw[2]:override(helpers:clamp(angles.offset, -180, 180))
        reference.antiaim.angles.yaw_jitter[1]:override(angles.yaw_jitter)
        reference.antiaim.angles.yaw_jitter[2]:override(helpers:clamp(angles.jitter_offset, -180, 180))

        reference.antiaim.angles.body_yaw[1]:override(angles.body_yaw)
        reference.antiaim.angles.body_yaw[2]:override(angles.body_side)
        reference.antiaim.angles.fs_body_yaw:override(angles.fs_body_yaw)
    end

    local function is_enemies_dead ()
        if not elements.anti_aim.settings.list:get('Spin if enemies dead') then
          return
        end
  
        local alive = 0
        for i = 1, globals.maxplayers() do
          if entity.get_classname(i) == 'CCSPlayer' and entity.is_alive(i) and entity.is_enemy(i) then
            alive = alive + 1
          end
        end

        return alive
    end

    local function on_setup_command (e)
        local me = entity.get_local_player()
        if not me or not entity.is_alive(me) then
            return
        end

        builder.state = builder.get_state()

        -- @lordmouse: safe head
        local weapon = entity.get_player_weapon(me)
        local weapon_class = entity.get_classname(weapon)
        if elements.anti_aim.settings.list:get('Safe head') and weapon and weapon_class and manual() ~= 3 then
            local safe_weapons = {
                CKnife = 'Knife',
                CWeaponTaser = 'Taser'
            }
            
            local is_safe_state = (builder.state == 'Air+' or not is_on_ground and builder.state == 'Fake lag' and entity.get_prop(me, 'm_flDuckAmount') == 1)
            
            local my_pos = vector(entity.get_origin(me))
            local threat = client.current_threat()
            local height_to_threat = 0
            if threat then
                local enemy_pos = vector(entity.get_origin(threat))
                height_to_threat = math.ceil(my_pos.z - enemy_pos.z)
            end

            for sel_weapon, weapons in pairs(safe_weapons) do
                if is_safe_state and ((safe_weapons[weapon_class] and elements.anti_aim.settings.safe_head_options:get(safe_weapons[weapon_class])) or (height_to_threat > 100 and elements.anti_aim.settings.safe_head_options:get('Height advantage'))) then
                    if elements.anti_aim.settings.safe_head_mode:get() == 'Defensive' then
                        if exploits:is_active() and not exploits:in_recharge() then
                            exploits:should_force_defensive(true)

                            reference.antiaim.angles.pitch[1]:override(exploits:in_defensive() and 'Custom' or 'Down')
                            reference.antiaim.angles.pitch[2]:override(0)
                            reference.antiaim.angles.yaw[2]:override(exploits:in_defensive() and 180 or 0)
                            reference.antiaim.angles.body_yaw[1]:override(exploits:in_defensive() and 'Static' or 'Off')
                            reference.antiaim.angles.body_yaw[2]:override(1)
                        else
                            exploits:should_force_defensive(false)

                            reference.antiaim.angles.pitch[1]:override('Down')
                            reference.antiaim.angles.yaw[2]:override(0)
                            reference.antiaim.angles.body_yaw[1]:override('Off')
                            reference.antiaim.angles.body_yaw[2]:override(0)
                        end
                    else
                        exploits:should_force_defensive(false)

                        reference.antiaim.angles.pitch[1]:override('Down')
                        reference.antiaim.angles.yaw[2]:override(0)
                        reference.antiaim.angles.body_yaw[1]:override('Off')
                        reference.antiaim.angles.body_yaw[2]:override(0)
                    end
                    reference.antiaim.angles.yaw_base:override('At Targets')
                    reference.antiaim.angles.yaw[1]:override('180')
                    reference.antiaim.angles.yaw_jitter[1]:override('Off')
                    reference.antiaim.angles.yaw_jitter[2]:override(0)
                end
            end
        end
        
        -- @lordmouse: spin if enemies dead or warmup
        reference.antiaim.fakelag.limit:override()
        if elements.anti_aim.settings.list:get('Spin if enemies dead') and is_enemies_dead() == 0 or elements.anti_aim.settings.list:get('Spin on warmup') and entity.get_prop(entity.get_all('CCSGameRulesProxy')[1],'m_bWarmupPeriod') == 1 then
            reference.antiaim.angles.pitch[1]:override('Custom')
            reference.antiaim.angles.pitch[2]:override(0)
            reference.antiaim.angles.yaw[1]:override('Spin')
            reference.antiaim.angles.yaw[2]:override(5)
            reference.antiaim.angles.yaw_jitter[1]:override('Off')
            reference.antiaim.angles.yaw_jitter[2]:override(0)
            reference.antiaim.angles.body_yaw[1]:override('Static')
            reference.antiaim.angles.body_yaw[2]:override(1)

            reference.antiaim.fakelag.limit:override(1)
        end

        -- @lordmouse: anti-backstab
        if elements.anti_aim.settings.list:get('Anti backstab') then
            local players = entity.get_players(true)
            local local_pos = vector(entity.get_prop(me, 'm_vecOrigin'))

            for i = 1, #players do
                local player_pos = vector(entity.get_prop(players[i], 'm_vecOrigin'))
                local enemy_weapon = entity.get_player_weapon(players[i])

                anti_backstab = false
                if entity.get_classname(enemy_weapon) == 'CKnife' and local_pos:dist(player_pos) <= 450 then
                    local eye_pos = vector(client.eye_position())
                    local hitbox_pos = vector(entity.hitbox_position(players[i], 4))
                
                    local fraction, entindex_hit = client.trace_line(players[i], hitbox_pos.x, hitbox_pos.y, hitbox_pos.z, eye_pos.x, eye_pos.y, eye_pos.z)

                    if entindex_hit == me or fraction == 1 then
                        anti_backstab = true
                        reference.antiaim.angles.pitch[1]:override('Down')
                        reference.antiaim.angles.yaw_base:override('At Targets')
                        reference.antiaim.angles.yaw[1]:override('180')
                        reference.antiaim.angles.yaw[2]:override(180)
                        reference.antiaim.angles.yaw_jitter[1]:override('Off')
                        reference.antiaim.angles.yaw_jitter[2]:override(0)
                    end
                end
            end
        end

        if elements.anti_aim.settings.list:get('Fast ladder') then
            local pitch, yaw = client.camera_angles()
            local move_type = entity.get_prop(me, 'm_MoveType')
            local weapon = entity.get_player_weapon(me)
            local throw = entity.get_prop(weapon, 'm_fThrowTime')
        
            if move_type ~= 9 then
                return
            end
        
            if weapon == nil then
                return
            end
        
            if throw ~= nil and throw ~= 0 then
                return
            end	
        
            if e.forwardmove > 0 then
                if e.pitch < 45 then
                    e.pitch = 89
                    e.in_moveright = 1
                    e.in_moveleft = 0
                    e.in_forward = 0
                    e.in_back = 1
            
                    if e.sidemove == 0 then
                        e.yaw = e.yaw + 90
                    end
            
                    if e.sidemove < 0 then
                        e.yaw = e.yaw + 150
                    end
            
                    if e.sidemove > 0 then
                        e.yaw = e.yaw + 30
                    end
                end
            elseif e.forwardmove < 0 then
                e.pitch = 89
                e.in_moveleft = 1
                e.in_moveright = 0
                e.in_forward = 1
                e.in_back = 0
        
                if e.sidemove == 0 then
                    e.yaw = e.yaw + 90
                end
        
                if e.sidemove > 0 then
                    e.yaw = e.yaw + 150
                end
        
                if e.sidemove < 0 then
                    e.yaw = e.yaw + 30
                end
            end
        end

        -- @lordmouse: bombsite fix
        if elements.anti_aim.settings.list:get('E-Bombsite fix') then
            if entity.get_prop(me, 'm_iTeamNum') == 2 then
                if entity.get_prop(me, 'm_bInBombZone') > 0 then
                    if bit.band(e.buttons, 32) == 32 and entity.get_classname(weapon) ~= 'CC4' then
                        e.buttons = bit.band(e.buttons, bit.bnot(32))
                        reference.antiaim.angles.yaw_base:override('Local View')
                        reference.antiaim.angles.pitch[1]:override('Custom')
                        reference.antiaim.angles.pitch[2]:override(0)
                        reference.antiaim.angles.yaw[1]:override('180')
                        reference.antiaim.angles.yaw[2]:override(180)
                        reference.antiaim.angles.yaw_jitter[1]:override('Off')
                        reference.antiaim.angles.yaw_jitter[2]:override(0)
                        reference.antiaim.angles.body_yaw[1]:override('Static')
                        reference.antiaim.angles.body_yaw[2]:override(1)
                    end
                end
            end
        end

        -- Anti-aim on weapon switch
        if elements.anti_aim.settings.list:get('Anti-aim on weapon switch') then
            local current_weapon = entity.get_player_weapon(me)
            if current_weapon then
                if builder.last_weapon and builder.last_weapon ~= current_weapon then
                    builder.weapon_switch_tick = globals.tickcount()
                end
                builder.last_weapon = current_weapon
            end

            if builder.weapon_switch_tick and globals.tickcount() - builder.weapon_switch_tick < 30 then
                reference.antiaim.angles.pitch[1]:override('Custom')
                reference.antiaim.angles.pitch[2]:override(0)
                reference.antiaim.angles.yaw[1]:override('Spin')
                reference.antiaim.angles.yaw[2]:override(45)
                reference.antiaim.angles.yaw_jitter[1]:override('Off')
                reference.antiaim.angles.yaw_jitter[2]:override(0)
            else
                builder.weapon_switch_tick = 0
            end
        end
    end

    client.set_event_callback('setup_command', set_angles)
    client.set_event_callback('setup_command', on_setup_command)

    local function reset_everything ()
        builder.manual_tick = 0
        builder.side = 1
        builder._freeze_state.active = false
        builder._freeze_state._until = 0
        builder.current_tick = 0
        builder.delay_ticks.default = 0
        builder.delay_ticks.defensive = 0
        builder.d_side = 1
        builder.last_weapon = nil
        builder.weapon_switch_tick = 0

        skitter_per_tick = false
        skitter_accumulated_offset = 0
        skitter_goal_feet_yaw = 0
        skitter_last_view_angle = 0
        skitter_initialized = false

        builder._xway_offsets = { _xway_tick = 0, _xway_last_tick = 0, _xway_idx = 1 }
        builder._xway_freeze_state = { active = false, _until = 0 }
        builder._xway_tick = 0
        builder._xway_last_tick = 0
        builder._xway_idx = 1
    end

    local function on_player_death (e)
        if not (e.userid and e.attacker) then
            return 
        end

        if entity.get_local_player() ~= client.userid_to_entindex(e.userid) then 
            return 
        end
        
        reset_everything()
    end
    
    local function on_level_init ()
        reset_everything() 
    end
    
    local function on_round_end ()
        reset_everything() 
    end

    client.set_event_callback('player_death', on_player_death)
    client.set_event_callback('level_init', on_level_init)
    client.set_event_callback('round_end', on_round_end)
end

local defensive_flick do
    local delay = nil
    local pitch_gen = nil
    local yaw_gen = nil
    local side = 0
    local cache_tick = 0

    local function on_setup_command (e)
        if not elements.anti_aim.exploits.defensive_flick.enable:get() then
            return
        end

        local condition = builder.get_state()
        local pitch, pitch_offset = 'Custom', 0
        local yaw = '180'
        local yaw_base, offset, body_yaw, body_side, fs_body_yaw = 'At targets', 0, 'Static', 0, false

        -- Получаем настройки скорости и питча из меню
        local delay_min = elements.anti_aim.exploits.defensive_flick.settings.delay_min:get()
        local delay_max = elements.anti_aim.exploits.defensive_flick.settings.delay_max:get()
        local pitch_in_def = elements.anti_aim.exploits.defensive_flick.settings.pitch_in_defensive:get()
        local pitch_out_def = elements.anti_aim.exploits.defensive_flick.settings.pitch_out_defensive:get()
        local yaw_left = elements.anti_aim.exploits.defensive_flick.settings.yaw_left:get()
        local yaw_right = elements.anti_aim.exploits.defensive_flick.settings.yaw_right:get()
        local yaw_out_def = elements.anti_aim.exploits.defensive_flick.settings.yaw_out_defensive:get()

        exploits:should_force_defensive(false)
        if elements.anti_aim.exploits.defensive_flick.settings.states:get(condition) and (condition ~= 'Fake lag' and not fakelag.active) and not anti_backstab then
            exploits:should_force_defensive(true)

            if exploits.ticks_processed <= 2 then
                delay = nil
            elseif exploits.ticks_processed > 2 then
                if not delay then
                    delay = client.random_int(delay_min, delay_max)
                end
            end

            if exploits:in_defensive() then
                pitch_offset = pitch_in_def
                body_side, fs_body_yaw = 1, false
                        
                local current_tick = globals.tickcount()
                if cache_tick < current_tick - (delay or 1) then
                    -- print('work')
                    cache_tick = current_tick
                    side = side == 1 and -1 or 1
                end

                if side == -1 then
                    offset = yaw_left
                else
                    offset = yaw_right
                end
            else
                pitch_offset = pitch_out_def
                offset = yaw_out_def
                body_side, fs_body_yaw = 0, true
            end

            reference.antiaim.angles.pitch[1]:override(pitch)
            reference.antiaim.angles.pitch[2]:override(helpers:clamp(pitch_offset, -89, 89))

            reference.antiaim.angles.yaw[1]:override(yaw)
            reference.antiaim.angles.yaw_base:override(yaw_base)
            
            reference.antiaim.angles.yaw[2]:override(helpers:clamp(offset, -180, 180))
            reference.antiaim.angles.yaw_jitter[1]:override('Off')
            reference.antiaim.angles.yaw_jitter[2]:override(0)
            
            reference.antiaim.angles.body_yaw[1]:override(body_yaw)
            reference.antiaim.angles.body_yaw[2]:override(body_side)
            reference.antiaim.angles.fs_body_yaw:override(fs_body_yaw)
        end
    end

    client.set_event_callback('setup_command', on_setup_command)
end

---

local function control_exploits (ctx)
    reference.rage.aimbot.double_tap[1]:override()
    reference.rage.aimbot.double_tap[2]:override()

    reference.rage.aimbot.double_tap[1]:override(ctx)
    reference.rage.aimbot.double_tap[2]:override('Defensive')
end

local unsafe_recharge = { timer = globals.tickcount(), ticks = 14 }; do
    local function on_setup_command ()
        if not elements.aimbot.unsafe_exploit:get() then
            return
        end
    
        local me = entity.get_local_player()
        if not me or not entity.is_alive(me) then
            reference.rage.aimbot.enabled[1]:set_hotkey('Always on')
            return
        end
    
        local doubletap_ref = reference.rage.aimbot.double_tap[1]:get() and reference.rage.aimbot.double_tap[1].hotkey:get() and not reference.rage.other.fake_duck:get()
        local osaa_ref = reference.antiaim.other.on_shot_anti_aim[1]:get() and reference.antiaim.other.on_shot_anti_aim[1].hotkey:get() and not reference.rage.other.fake_duck:get()
    
        local weapon = entity.get_player_weapon(me)
        if not weapon then 
            reference.rage.aimbot.enabled[1]:set_hotkey('Always on')
            return
        end
    
        unsafe_recharge.ticks = csgo_weapons(weapon).is_revolver and 17 or 14
    
        if (doubletap_ref) or (osaa_ref) then
            if globals.tickcount() >= unsafe_recharge.timer + unsafe_recharge.ticks then
                reference.rage.aimbot.enabled[1]:set_hotkey('Always on')
            else
                reference.rage.aimbot.enabled[1]:set_hotkey('On hotkey')
            end
        else
            unsafe_recharge.timer = globals.tickcount()
    
            reference.rage.aimbot.enabled[1]:set_hotkey('Always On')
        end
    end
    
    client.set_event_callback('setup_command', on_setup_command)
end

local auto_discharge do
    local air_tick_interval = 13

    local function should_allow_tickbase_shift()
        local cur_tick = globals.tickcount()
        return cur_tick % air_tick_interval ~= 0
    end

    local exploit_active = false
    local function on_setup_command (e)
        if not elements.aimbot.auto_discharge.enable:get() then
            return
        end

        if not elements.aimbot.auto_discharge.enable.hotkey:get() then
            reference.rage.aimbot.enabled[1]:set_hotkey('Always on')
            control_exploits(true)
            return
        end

        reference.rage.aimbot.enabled[1]:set_hotkey('Always on')

        local state = helpers.get_state()
        if state == 'Air' or state == 'Air+' then
            if elements.aimbot.auto_discharge.settings.mode:get() == 'Air lag' then
                exploits:should_force_defensive(true)
                if elements.aimbot.auto_discharge.settings.air_lag_mode:get() == 'Fast' then
                    if (exploits.ticks_processed > 1 and exploits.ticks_processed < exploits.max_process_ticks and exploits.tickbase_difference > 0) then
                        control_exploits(false)
                        exploit_active = true
                    else
                        reference.rage.aimbot.enabled[1]:set_hotkey('On hotkey')
                        control_exploits(true)
                        exploit_active = false
                    end
                elseif elements.aimbot.auto_discharge.settings.air_lag_mode:get() == 'Slow' then
                    if (exploits.ticks_processed > 1 and exploits.ticks_processed > 13 and exploits.tickbase_difference > 0) then
                        e.allow_shift_tickbase = should_allow_tickbase_shift()
                        control_exploits(false)
                        exploit_active = true
                    else
                        reference.rage.aimbot.enabled[1]:set_hotkey('On hotkey')
                        control_exploits(true)
                        exploit_active = false
                    end
                end
            elseif elements.aimbot.auto_discharge.settings.mode:get() == 'Default' then

            end
        end
    end

    client.set_event_callback('setup_command', on_setup_command)

    local function on_paint ()
        if not elements.aimbot.auto_discharge.enable:get() then
            return
        end

        if elements.aimbot.auto_discharge.enable.hotkey:get() and exploits:is_doubletap() then
            local state = helpers.get_state()
            local r, g, b, a = 255, 0, 50, 255
            if exploit_active then
                r, g, b = 255, 255, 255
            end
            renderer.indicator(r, g, b, a, 'LAG')
        end
    end

    client.set_event_callback('paint', on_paint)
end

local resolver = { records = { }, max_records = 32 }; do
    local function is_bot (ent)
        return entity.get_steam64(ent) == 0
    end

   -- ...
end

local aim_punch_fix = { last_health = 100, override_active = false }; do
    local function on_setup_command()
        if not elements.aimbot.aim_punch_fix:get() then
            return
        end

        local me = entity.get_local_player()
        if not me or not entity.is_alive(me) then
            aim_punch_fix.last_health = 100
            if aim_punch_fix.override_active then
                reference.rage.aimbot.minimum_hitchance:override()
                aim_punch_fix.override_active = false
            end
            return
        end

        local current_health = entity.get_prop(me, 'm_iHealth') or 100

        if current_health < aim_punch_fix.last_health then
            reference.rage.aimbot.minimum_hitchance:override(100)
            aim_punch_fix.override_active = true
        elseif aim_punch_fix.override_active then
            reference.rage.aimbot.minimum_hitchance:override()
            aim_punch_fix.override_active = false
        end

        aim_punch_fix.last_health = current_health
    end

    elements.aimbot.aim_punch_fix:set_event('setup_command', on_setup_command)
end

local hitchance_in_air = { }; do
    local function on_setup_command ()
        if not elements.aimbot.aimbot_helper.enable:get() then
            return
        end
        
        local me = entity.get_local_player()
        if not me or not entity.is_alive(me) then
            return
        end
        
        -- Check if in air
        local ground_entity = entity.get_prop(me, 'm_hGroundEntity')
        if ground_entity ~= 0 then
            return
        end
        
        -- Get current weapon
        local weapon = entity.get_player_weapon(me)
        if not weapon then return end
        
        local weapon_class = entity.get_classname(weapon)
        local weapon_type = elements.aimbot.aimbot_helper.settings.weapon:get()
        local hc_value = 0
        
        -- SSG-08
        if weapon_type == 'SSG-08' and weapon_class == 'CWeaponSSG08' then
            if elements.aimbot.aimbot_helper.settings.ssg.select:get('Hitchance in air') then
                hc_value = elements.aimbot.aimbot_helper.settings.ssg.hitchance_in_air_value:get()
            end
        -- AWP
        elseif weapon_type == 'AWP' and weapon_class == 'CWeaponAWP' then
            if elements.aimbot.aimbot_helper.settings.awp.select:get('Hitchance in air') then
                hc_value = elements.aimbot.aimbot_helper.settings.awp.hitchance_in_air_value:get()
            end
        -- Auto Snipers
        elseif weapon_type == 'Auto Snipers' and (weapon_class == 'CWeaponSCAR20' or weapon_class == 'CWeaponG3SG1') then
            if elements.aimbot.aimbot_helper.settings.auto.select:get('Hitchance in air') then
                hc_value = elements.aimbot.aimbot_helper.settings.auto.hitchance_in_air_value:get()
            end
        end
        
        if hc_value > 0 then
            reference.rage.aimbot.minimum_hitchance:override(hc_value)
        end
    end
    
    client.set_event_callback('setup_command', on_setup_command)
end

local auto_hide_shots = { hotkey = nil }; do
    local function on_setup_command ()
        if not elements.aimbot.auto_hs.enable:get() then
            return
        end
      
        if not auto_hide_shots.hotkey then
            auto_hide_shots.hotkey = { reference.antiaim.other.on_shot_anti_aim[1]:get_hotkey() }
        end
      
        local me = entity.get_local_player()
        if not me or not entity.is_alive(me) then
            return
        end
      
        local condition = builder.get_state()
      
        local avoid_guns = {
            ['Pistols'] = { 'CWeaponGlock', 'CWeaponHKP2000', 'CWeaponP250', 'CWeaponTec9', 'CWeaponFiveSeven' },
            ['Desert Eagle'] = { 'CDEagle' },
            ['Auto Snipers'] = { 'CWeaponSCAR20', 'CWeaponG3SG1' },
            ['Desert Eagle + Crouch'] = { 'CDEagle' }
        }

        local mode_number = auto_hide_shots.hotkey[2]
        local mode_new = 'On hotkey'
        if mode_number == 0 then
            mode_new = 'Always on'
        elseif mode_number == 1 then
            mode_new = 'On hotkey'
        elseif mode_number == 2 then
            mode_new = 'Toggle'
        elseif mode_number == 3 then
            mode_new = 'Off hotkey'
        end
      
        if elements.aimbot.auto_hs.settings.state:get(condition) then
            local weapon = entity.get_player_weapon(me)
            if not weapon then
                return
            end
      
            local weapon_classname = entity.get_classname(weapon)
            local is_crouching = entity.get_prop(me, 'm_flDuckAmount') == 1
            local should_avoid = false
      
            for avoid_type, weapons in pairs(avoid_guns) do
                for _, weapon_name in ipairs(weapons) do
                    if weapon_classname == weapon_name then
                        if avoid_type == 'Desert Eagle + Crouch' and not is_crouching then
                            break
                        end
                        if elements.aimbot.auto_hs.settings.avoid_guns:get(avoid_type) then
                            should_avoid = true
                            break
                        end
                    end
                end
                if should_avoid then
                    break
                end
            end
      
            if not should_avoid then
                reference.antiaim.other.on_shot_anti_aim[1]:set_hotkey('Always On')
                control_exploits(false)
            else
                reference.antiaim.other.on_shot_anti_aim[1]:set_hotkey(mode_new)
                control_exploits(true)
            end
        else
            reference.antiaim.other.on_shot_anti_aim[1]:set_hotkey(mode_new)
            control_exploits(true)
        end
    end

    -- client.set_event_callback('setup_command', on_setup_command)
    elements.aimbot.auto_hs.enable:set_event('setup_command', on_setup_command)
end

local auto_air_stop do
    local delay_ticks = 13
    local last_air_tick = 0
    local speed_limit = elements.aimbot.auto_air_stop.settings.speed:get()

    local function can_shoot (me, gun)
        if not me or not gun then return false end
        local next_attack = entity.get_prop(me, 'm_flNextAttack') or 0
        local next_primary = entity.get_prop(gun, 'm_flNextPrimaryAttack') or 0
        local curtime = globals.curtime()
        local clip = entity.get_prop(gun, 'm_iClip1') or 0
        return (math.max(next_attack, next_primary) <= curtime) and clip > 0
    end

    local function is_enemy_visible (local_player, enemy)
        local local_player_origin = {entity.get_origin(local_player)}
        local enemy_origin = {entity.get_origin(enemy)}
        if local_player_origin[1] == nil or enemy_origin[1] == nil then
            return false
        end
        local trace_fraction, _ = client.trace_bullet(local_player, local_player_origin[1], local_player_origin[2], local_player_origin[3] + 16, enemy_origin[1], enemy_origin[2], enemy_origin[3] + 16)
        return trace_fraction
    end

    local function estimate_hitchance (me, gun)
        local weapon_class = entity.get_classname(gun)
        if weapon_class ~= 'CWeaponSSG08' then return 0 end

        local scoped = entity.get_prop(me, 'm_bIsScoped') == 1
        local duck = entity.get_prop(me, 'm_flDuckAmount') or 0
        local velocity = vector(entity.get_prop(me, 'm_vecVelocity'))
        local speed = velocity:length2d()
        local dist = 0
        local threat = client.current_threat()
        if threat then
            local my_pos = vector(entity.get_origin(me))
            local enemy_pos = vector(entity.get_origin(threat))
            dist = my_pos:dist(enemy_pos)
        end

        local base_spread = 0.002
        if not scoped then
            base_spread = 0.08
        end
        if duck == 1 then
            base_spread = base_spread * 0.7
        end
        if speed > 5 then
            base_spread = base_spread + (speed / 300) * 0.08
        end
        if dist > 1000 then
            base_spread = base_spread + (dist - 1000) / 4000
        end

        local hc = 100 - (base_spread * 1000)
        if hc > 100 then hc = 100 end
        if hc < 0 then hc = 0 end
        return hc
    end

    local function angle_math (x, y)
        local angle_x_sin = math.sin(math.rad(x))
        local angle_x_cos = math.cos(math.rad(x))
        local angle_y_sin = math.sin(math.rad(y))
        local angle_y_cos = math.cos(math.rad(y))
        return angle_x_cos * angle_y_cos, angle_x_cos * angle_y_sin, -angle_x_sin
    end

    local function on_setup_command (e)
        if not elements.aimbot.auto_air_stop.enable:get() then
            return
        end

        local me = entity.get_local_player()
        if not me or not entity.is_alive(me) then
            last_air_tick = 0
            return
        end

        local gun = entity.get_player_weapon(me)
        if not gun or entity.get_classname(gun) ~= 'CWeaponSSG08' then
            return
        end

        local tick = globals.tickcount()
        if not is_on_ground then
            if last_air_tick == 0 then
                last_air_tick = tick
            end
        else
            last_air_tick = 0
            return
        end

        if tick - last_air_tick < delay_ticks then
            return
        end

        if not can_shoot(me, gun) then
            return
        end

        local can_work = false
        if elements.aimbot.auto_air_stop.settings.addons:get('Work only with quick peek assist') then
            can_work = reference.rage.other.quickpeek[1]:get() and reference.rage.other.quickpeek[1].hotkey:get()
        else
            can_work = true
        end

        local local_team = entity.get_prop(me, 'm_iTeamNum')
        local enemies = entity.get_players(true)
        for i = 1, #enemies do
            local enemy = enemies[i]
            if entity.get_prop(enemy, 'm_iTeamNum') ~= local_team and entity.is_alive(enemy) then
                if is_enemy_visible(me, enemy) then
                    local hc = estimate_hitchance(me, gun)
                    if hc < elements.aimbot.auto_air_stop.settings.hitchance:get() then
                        return
                    end

                    if not can_work then
                        return
                    end

                    local velocity = vector(entity.get_prop(me, 'm_vecVelocity'))
                    local speed = velocity:length2d()
                    if elements.aimbot.auto_air_stop.settings.addons:get('Work if speed lower than X') and (speed < speed_limit) then
                        return
                    end

                    e.quick_stop = true

                    local velocity_angles = vector(velocity:angles())
                    local camera_angles = vector(client.camera_angles())

                    velocity_angles.y = camera_angles.y - velocity_angles.y
                    local calc_x, calc_y = angle_math(velocity_angles.x, velocity_angles.y)

                    local sidespeed = -cvar.cl_sidespeed:get_float()
                    local final_x = sidespeed * calc_x
                    local final_y = sidespeed * calc_y

                    e.in_speed = 1
                    e.forwardmove = final_x
                    e.sidemove = final_y
                    break
                end
            end
        end
    end

    client.set_event_callback('setup_command', on_setup_command)
end

local aimbot_helper do
    local helper_miss_counter = 0

    client.set_event_callback('aim_miss', function (e)
        if e.reason ~= 'prediction error' then
            helper_miss_counter = helper_miss_counter + 1
        end
    end)
    
    client.set_event_callback('round_prestart', function ()
        helper_miss_counter = 0
    end)

    local function check_trigger (triggers, hp, miss_count, hp_threshold, miss_threshold, height_diff)
        for _, trigger in ipairs(triggers) do
            if (trigger == 'Enemy HP < X' and hp < hp_threshold) or
               (trigger == 'X Missed Shots' and miss_count > miss_threshold) or
               (trigger == 'Lethal' and hp <= 30) or
               (trigger == 'Height advantage' and height_diff > 70) or
               (trigger == 'Enemy higher than you' and height_diff < -70) then
                return true
            else
                return false
            end
        end
        return false
    end

    local function on_setup_command ()
        if not elements.aimbot.aimbot_helper.enable:get() then return end

        local me = entity.get_local_player()
        if not me or not entity.is_alive(me) then
            reference.playerlist.reset:set(true)
            helper_miss_counter = 0
            return
        end

        local gun = entity.get_player_weapon(me)
        if not gun then return end

        local weapon = entity.get_classname(gun)
        local weapon_config = (weapon == 'CWeaponSSG08' and elements.aimbot.aimbot_helper.settings.ssg) or
                              (weapon == 'CWeaponAWP' and elements.aimbot.aimbot_helper.settings.awp) or
                              ((weapon == 'CWeaponG3SG1' or weapon == 'CWeaponSCAR20') and elements.aimbot.aimbot_helper.settings.auto)

        if not weapon_config then return end

        local my_pos = vector(entity.get_origin(me))
        local players = entity.get_players(true)

        for _, target in ipairs(players) do
            if not target or not entity.is_alive(target) or entity.is_dormant(target) then
                reference.playerlist.reset:set(true)
                helper_miss_counter = 0
                return
            end

            local hp = entity.get_prop(target, 'm_iHealth') or 100
            local enemy_pos = vector(entity.get_origin(target))
            local height_diff = math.ceil(my_pos.z - enemy_pos.z)

            if weapon_config.select:get('Force safe point') and
               check_trigger(weapon_config.force_safe:get(), hp, helper_miss_counter,
                             weapon_config.force_safe_hp:get(), weapon_config.force_safe_miss:get(), height_diff) then
                plist.set(target, 'Override safe point', 'On')
            else
                plist.set(target, 'Override safe point', '-')
            end

            local prefer_body = weapon_config.select:get('Prefer body aim') and
                                check_trigger(weapon_config.prefer_body:get(), hp, helper_miss_counter,
                                              weapon_config.prefer_body_hp:get(), weapon_config.prefer_body_miss:get(), height_diff)
            local force_body = weapon_config.select:get('Force body aim') and
                               check_trigger(weapon_config.force_body:get(), hp, helper_miss_counter,
                                             weapon_config.force_body_hp:get(), weapon_config.force_body_miss:get(), height_diff)

            if force_body then
                plist.set(target, 'Override prefer body aim', 'Force')
            elseif prefer_body then
                plist.set(target, 'Override prefer body aim', 'On')
            else
                plist.set(target, 'Override prefer body aim', '-')
            end

            if weapon_config.select:get('Ping spike') then
                reference.rage.ps[1]:override(true)
                reference.rage.ps[2]:override(weapon_config.ping_spike_value:get())
            else
                reference.rage.ps[1]:override()
                reference.rage.ps[2]:override()
            end
        end
    end

    -- client.set_event_callback('setup_command', function ()
    --     client.update_player_list()
    --     on_setup_command()
    -- end)
    elements.aimbot.aimbot_helper.enable:set_event('setup_command', function ()
        client.update_player_list()
        on_setup_command()
    end)
end

local ai_peek = { }; do
    ai_peek.set_movement = function (e, destination, local_player)
        local move_yaw = vector(vector(entity.get_origin(local_player)):to(destination):angles()).y
    
        e.in_forward = 1
        e.in_back = 0
        e.in_moveleft = 0
        e.in_moveright = 0
        e.in_speed = 0
        e.forwardmove = 800
        e.sidemove = 0
        e.move_yaw = move_yaw
    end
  
    ai_peek.extrapolate_position = function (ent, origin, ticks, inverted)
        local tickinterval = globals.tickinterval()
    
        local sv_gravity = cvar.sv_gravity:get_float() * tickinterval
        local sv_jump_impulse = cvar.sv_jump_impulse:get_float() * tickinterval
    
        local p_origin, prev_origin = origin, origin
    
        local velocity = vector(entity.get_prop(ent, 'm_vecVelocity'))
        local gravity = velocity.z > 0 and -sv_gravity or sv_jump_impulse
    
        for i = 1, ticks do
            prev_origin = p_origin
            p_origin = vector(
                p_origin.x + (inverted and -(velocity.x * tickinterval) or (velocity.x * tickinterval)),
                p_origin.y + (inverted and -(velocity.y * tickinterval) or (velocity.y * tickinterval)),
                p_origin.z + (inverted and -((velocity.z + gravity) * tickinterval) or (velocity.z + gravity) * tickinterval)
            )
    
            local fraction = client.trace_line(-1,
                prev_origin.x, prev_origin.y, prev_origin.x,
                p_origin.x, p_origin.y, p_origin.x
            )
    
            if fraction <= .99 then
                return prev_origin
            end
        end
    
        return p_origin
    end
  
    ai_peek.extend_vector = function (pos, length, angle)
        -- local rad = angle * math.pi / 180
        -- return vector(pos.x + (math.cos(rad) * length), pos.y + (math.sin(rad) * length), pos.z)
        local rad = math.rad(angle)
        return vector(
            pos.x + (math.cos(rad) * length),
            pos.y + (math.sin(rad) * length),
            pos.z
        )
    end
  
    ai_peek.get_players = function (include_enemies, include_teammates, include_localplayer, include_dormant, include_invisible)
        local result = { }
        local player_resource = entity.get_player_resource()
        local maxplayers = globals.maxplayers()
        local plocal = entity.get_local_player()
    
        for player = 1, maxplayers do
            if entity.get_prop(player_resource, 'm_bConnected', player) ~= 1 then
                goto skip
            end
    
            if entity.get_prop(player_resource, 'm_bAlive', player) ~= 1 then
                goto skip
            end
    
            if not include_localplayer and player == plocal then
                goto skip
            end
    
            if include_teammates then
                if not include_enemies and entity.is_enemy(player) then
                    goto skip
                end
            elseif not entity.is_enemy(player) then
                goto skip
            end
    
            if not include_dormant and entity.is_dormant(player) then
                goto skip
            end
    
            if not include_invisible and select(5, entity.get_bounding_box(player)) <= 0 then
                goto skip
            end
    
            result[#result + 1] = player
    
            ::skip::
        end
    
        return result
    end
  
    local calc = function (xdelta, ydelta)
        if xdelta == 0 and ydelta == 0 then
            return 0
        end

        return math.deg(math.atan2(ydelta, xdelta))
    end
    
    ai_peek.get_nearest_player = function (players)
        local lp_eyepos = vector(client.eye_position())
        local lp_camera_angles = vector(client.camera_angles())
    
        local bestenemy = nil
        local fov = 180
    
        for i = 1, #players do
            local player = players[i]
    
            local player_origin = vector(entity.get_origin(player))
    
            local cur_fov = math.abs(
                aa_func.normalize_angle(
                    calc(lp_eyepos.x - player_origin.x, lp_eyepos.y - player_origin.y) - lp_camera_angles.y + 180
                )
            )
    
            if cur_fov < fov then
                fov = cur_fov
                bestenemy = player
            end
        end
    
        return bestenemy
    end
  
    ai_peek.hitgroups_to_hitboxes = {
      ['Head'] = { 0 },
      ['Chest'] = { 4, 5, 6 },
      ['Stomach'] = { 2, 3 },
      ['Arms'] = { 13, 14, 15, 16, 17, 18 },
      ['Legs'] = { 7, 8, 9, 10 },
      ['Feet'] = { 11, 12 }
    }
  
    ai_peek.allowed_hitboxes = {
      0, 4, 5, 6, 2, 3, 13, 14, 15, 16, 17, 18, 7, 8, 9, 10, 11, 12
    }
  
    ai_peek.hitgroup_data = {
      ['Head'] = 1, -- 0
      ['Neck'] = 8, -- 1
      ['Pelvis'] = 3, -- 2
      ['Stomach'] = 3, -- 3
      ['Lower Chest'] = 2, -- 4
      ['Chest'] = 2, -- 5
      ['Upper Chest'] = 2, -- 6
      ['Left Upper Leg'] = 6, -- 7
      ['Right Upper Leg'] = 7, -- 8
      ['Left Lower Leg'] = 6, -- 9
      ['Right Lower Leg'] = 7, -- 10
      ['Left Foot'] = 6, -- 11
      ['Right Foot'] = 7, -- 12
      ['Left Hand'] = 4, -- 13
      ['Right Hand'] = 5, -- 14
      ['Left Upper Arm'] = 4, -- 15
      ['Left Lower Arm'] = 4, -- 16
      ['Right Upper Arm'] = 5, -- 17
      ['Right Lower Arm'] = 5 -- 18
    }
  
    ai_peek.hitboxes_names = {
      [0] = 'Head',
      'Neck',
      'Pelvis',
      'Stomach',
      'Lower Chest',
      'Chest',
      'Upper Chest',
      'Left Upper Leg',
      'Right Upper Leg',
      'Left Lower Leg',
      'Right Lower Leg',
      'Left Foot',
      'Right Foot',
      'Left Hand',
      'Right Hand',
      'Left Upper Arm',
      'Left Lower Arm',
      'Right Upper Arm',
      'Right Lower Arm',
    }
    ai_peek.active_hitboxes = { }
    ai_peek.returning = false
    ai_peek.targeting = false
    ai_peek.should_return = false
    ai_peek.dt_teleport = false
    ai_peek.disable_dt = false
    ai_peek.cache = {
      hotkeys = {
        autopeek = {
          enabled = nil,
          hotkey_mode = nil,
          mode = nil,
          distance = nil
        },
      },
      middle_pos = vector(),
      active_point_index = 0,
      positions = { },
      vectors_to_target = { },
      draw_data = { },
      last_returning_time = 0,
      current_target = 0
    }
    ai_peek.hotkeys = {
      main = false,
      force_baim = false
    }
    ai_peek.amount = 4
    ai_peek.step_distance = 50 -- @lordmouse: long - 50, medium - 40, small - 30
    ai_peek.visual = {
        data = { },
        active = false
    }
  
    ai_peek.skip_func = function (entindex, contents_mask)
        local ent_classname = entity.get_classname(entindex)
    
        if ent_classname == 'CCSPlayer' and entity.is_enemy(entindex) then
            return false
        end
    
        return true
    end
  
    ai_peek.create_values = function ()
        for i = 0, ai_peek.amount do
            ai_peek.cache.vectors_to_target[i] = { }
            ai_peek.visual.data[i] = false
        end
    end
  
    ai_peek.update_hitboxes = function (ref, force_baim)
        local new_hitboxes = { }
        local target_hitboxes = ref:get()
    
        local force_baim_disabled_hitgroups = {
            'Head', 'Arms', 'Legs', 'Feet'
        }
    
        for i = 1, #target_hitboxes do
            if force_baim and table_contains(force_baim_disabled_hitgroups, target_hitboxes[i]) then
                goto continue
            end
    
            local curr_hitgroup = ai_peek.hitgroups_to_hitboxes[target_hitboxes[i]]
    
            for j = 1, #curr_hitgroup do
                local hitbox = curr_hitgroup[j]
        
                if table_contains(ai_peek.allowed_hitboxes, hitbox) then
                    table.insert(new_hitboxes, hitbox)
                end
            end
    
            ::continue::
        end
    
        ai_peek.active_hitboxes = new_hitboxes
    end
  
    reference.rage.aimbot.target_hitbox:set_callback(function (ref)
        ai_peek.update_hitboxes(ref)
    end)
  
    ai_peek.handle_point = function (position, prev_position, angle, step_distance, index, view_offset, vec_mins, vec_maxs, max_step)
        local start_pos = prev_position and (prev_position - view_offset) or position
        local pos = ai_peek.extend_vector(start_pos, index == 0 and 0 or step_distance, angle)
    
        local trace_up = trace.hull(
            start_pos, start_pos + vector(0, 0, max_step), vec_mins, vec_maxs, {skip = skip_func, mask = 0x201400B}
        ).end_pos
    
        local trace_horizontal = trace.hull(
            vector(start_pos.x, start_pos.y, trace_up.z),
            vector(pos.x, pos.y, trace_up.z),
            vec_mins, vec_maxs, {skip = ai_peek.skip_func, mask = 0x201400B}
        ).end_pos
    
        if pos:dist2d(trace_horizontal) >= step_distance * .97 then
            return false
        end
    
        local trace_down = trace.hull(
            trace_horizontal,
            vector(trace_horizontal.x, trace_horizontal.y, position.z - 240),
            vec_mins, vec_maxs, {skip = ai_peek.skip_func, mask = 0x201400B}
        ).end_pos
    
        return trace_down + view_offset
    end
  
    local max_step = 18
  
    ai_peek.setup_points = function (local_player, position, angle, amount, step_distance)
        local view_offset = vector(entity.get_prop(local_player, 'm_vecViewOffset'))
        local vec_mins = vector(entity.get_prop(local_player, 'm_vecMins'))
        local vec_maxs = vector(entity.get_prop(local_player, 'm_vecMaxs'))
    
        ai_peek.cache.positions[0] = ai_peek.handle_point(
            position, nil, 0,
            step_distance, 0, view_offset,
            vec_mins, vec_maxs, max_step
        )
    
        for i = 1, amount do
            local angle = i % 2 == 0 and angle - 90 or angle + 90
    
            local prev_point = ai_peek.cache.positions[i <= 2 and 0 or i - 2]
    
            if not prev_point then
                goto continue
            end
    
            local point = ai_peek.handle_point(
                position, prev_point, angle,
                step_distance, i, view_offset,
                vec_mins, vec_maxs, max_step
            )
    
            if not point or (prev_point and math.abs(prev_point.z - point.z) > max_step) then
                for k = i, amount, 2 do
                    ai_peek.cache.positions[k] = false
                end
        
                goto continue
            end
    
            ai_peek.cache.positions[i] = point
    
            ::continue::
        end
    
        return ai_peek.cache.positions
    end
  
    ai_peek.trace_enemy = function (positions, local_player, target, hitboxes)
        local target_health = entity.get_prop(target, 'm_iHealth')
        local minimum_damage = (reference.rage.aimbot.minimum_damage_override[1].value and reference.rage.aimbot.minimum_damage_override[1].hotkey:get() and reference.rage.aimbot.minimum_damage_override[2].value) or reference.rage.aimbot.minimum_damage.value
    
        for i = 1, #positions do
            local pos = positions[i]
    
            if not pos then
                goto continue
            end
    
            for j = 1, #hitboxes do
                local hitbox = hitboxes[j]
                local hitbox_pos = vector(entity.hitbox_position(target, hitbox))
        
                local entindex, damage = client.trace_bullet(
                    local_player,
                    pos.x, pos.y, pos.z,
                    hitbox_pos.x, hitbox_pos.y, hitbox_pos.z,
                    hitbox == 0 -- @lordmouse: TODO - сделать нормальный фикс
                )
        
                -- @lordmouse: TODO - сделать нормальный фикс
                if hitbox == 0 then
                    damage = damage * 4
                end
        
                if damage >= math.min(minimum_damage, target_health) and damage > 0 then
                    return pos, i
                end
            end
    
            ::continue::
        end
    
        return nil, 0
    end
  
    ai_peek.weapon_can_fire = function (player, weapon)
        local lp_NextAttack = entity.get_prop(player, 'm_flNextAttack')
        local wpn_NextPrimaryAttack = entity.get_prop(weapon, 'm_flNextPrimaryAttack')
    
        if math.max(0, lp_NextAttack or 0, wpn_NextPrimaryAttack or 0) > globals.curtime() or entity.get_prop(weapon, 'm_iClip1') <= 0 then
            return false
        end
    
        return true
    end
  
    ai_peek.can_target = function (local_player, target)
        if not target then
            return false
        end
    
        local lp_wpn = entity.get_player_weapon(local_player)
    
        if not ai_peek.weapon_can_fire(local_player, lp_wpn) then
            return false
        end
    
        local need_scope = false do
            local scope_weapons = {
            'CWeaponSSG08',
            'CWeaponAWP',
            'CWeaponG3SG1',
            'CWeaponSCAR20'
            }
    
            if not reference.rage.aimbot.auto_scope:get() and table_contains(scope_weapons, entity.get_classname(lp_wpn)) then
                need_scope = entity.get_prop(local_player, 'm_bIsScoped') ~= 1
            end
        end
    
        if need_scope then
            return false
        end
    
        local need_charge = false do
            if reference.rage.aimbot.double_tap[1].hotkey:get() then
                need_charge = not exploits:can_recharge()
            end
        end
    
        if need_charge then
            return false
        end
    
        local velocity_modifier = entity.get_prop(local_player, 'm_flVelocityModifier')
        if velocity_modifier ~= 1 then
            return false
        end
    
        local esp_data = entity.get_esp_data(target) or {alpha = 0}
        if esp_data.alpha < .75 then
            return false
        end
    
        return true
    end
  
    ai_peek.handle = function (e)
        local local_player = entity.get_local_player()

        local weapon = entity.get_player_weapon(local_player)
        if not weapon then
            return
        end

        if csgo_weapons(weapon).is_revolver then
            return
        end

        local main_key = elements.aimbot.ai_peek.enable:get() and elements.aimbot.ai_peek.enable.hotkey:get()
    
        if main_key and not ai_peek.hotkeys.main then
            ai_peek.cache.hotkeys.autopeek.enabled = reference.rage.other.quickpeek[1]:get()
            ai_peek.cache.hotkeys.autopeek.hotkey_mode = { reference.rage.other.quickpeek[1]:get_hotkey() }
            ai_peek.cache.hotkeys.autopeek.mode = reference.rage.other.quickpeek_assist_mode[1]:get()
            ai_peek.cache.hotkeys.autopeek.distance = reference.rage.other.quickpeek_assist_distance:get()
    
            local lp_origin = vector(entity.get_origin(local_player))
            local lp_pos = ai_peek.extrapolate_position(local_player, lp_origin, 13, true)
    
            ai_peek.cache.middle_pos = lp_pos
    
            ai_peek.hotkeys.main = true
        elseif not main_key and ai_peek.hotkeys.main then
            local mode_number = ai_peek.cache.hotkeys.autopeek.hotkey_mode[2]
            local mode_new = 'On hotkey'
            if mode_number == 0 then
                mode_new = 'Always on'
            elseif mode_number == 1 then
                mode_new = 'On hotkey'
            elseif mode_number == 2 then
                mode_new = 'Toggle'
            elseif mode_number == 3 then
                mode_new = 'Off hotkey'
            end
    
            reference.rage.other.quickpeek[1]:override()
            reference.rage.other.quickpeek[1]:set_hotkey(mode_new)
            reference.rage.other.quickpeek_assist_mode[1]:override()
            reference.rage.other.quickpeek_assist_distance:override()
    
            ai_peek.hotkeys.main = false
        end
    
        if reference.rage.aimbot.force_body:get() and not ai_peek.hotkeys.force_baim then
            ai_peek.update_hitboxes(reference.rage.aimbot.target_hitbox, true)
            ai_peek.hotkeys.force_baim = true
        elseif not reference.rage.aimbot.force_body:get() and ai_peek.hotkeys.force_baim then
            ai_peek.update_hitboxes(reference.rage.aimbot.target_hitbox)
            ai_peek.hotkeys.force_baim = false
        end
    
        if not main_key then
            ai_peek.returning = false
            ai_peek.targeting = false
            ai_peek.should_return = false
            ai_peek.dt_teleport = false
            ai_peek.disable_dt = false
            ai_peek.visual.active = false
            return
        end
        
        local move_mode = elements.aimbot.ai_peek.settings.peek_mode
        local distance_mode = elements.aimbot.ai_peek.settings.distance:get()
    
        if distance_mode == 'Long' then
            ai_peek.step_distance = 50
        elseif distance_mode == 'Medium' then
            ai_peek.step_distance = 40
        elseif distance_mode == 'Short' then
            ai_peek.step_distance = 30
        end
    
        reference.rage.other.quickpeek[1]:override(true)
        reference.rage.other.quickpeek[1]:set_hotkey('Always On')
        reference.rage.other.quickpeek_assist_distance:override(math.floor((ai_peek.amount * ai_peek.step_distance) / 2) + 30)
    
        local m_vecVelocity = vector(entity.get_prop(local_player, 'm_vecVelocity'))
        local lp_velocity = m_vecVelocity:length2d()
    
        local local_override = bit.band(entity.get_prop(local_player, 'm_fFlags'), bit.lshift(1, 0)) ~= 1
        or (e.in_forward == 1 or e.in_moveleft == 1 or e.in_moveright == 1 or e.in_back == 1 or e.in_jump == 1)
    
        local middle_pos = ai_peek.cache.middle_pos
    
        local lp_origin = vector(entity.get_origin(local_player))
    
        local dist_to_middle = middle_pos:dist2d(lp_origin)
    
        if (not move_mode:get('Automatically Teleport Back')) and not ai_peek.targeting and not ai_peek.returning or (dist_to_middle > .15 and (lp_velocity > 1.011 and lp_velocity ~= 0)) then
            ai_peek.cache.middle_pos = lp_origin
        end
    
        local target = elements.aimbot.ai_peek.settings.mode:get() == 'Current threat' and client.current_threat() or ai_peek.get_nearest_player(ai_peek.get_players(true, false, false, true, false))
    
        ai_peek.cache.current_target = target
    
        local angle = target and vector(middle_pos:to(vector(entity.get_origin(target))):angles()).y or vector(client.camera_angles()).y
    
        local positions = ai_peek.setup_points(local_player, middle_pos, angle, ai_peek.amount, ai_peek.step_distance)
    
        ai_peek.visual.active = true
    
        local active_point_pos, active_point_index = nil, 0
    
        if target and not local_override and ai_peek.can_target(local_player, target) then
            active_point_pos, active_point_index = ai_peek.trace_enemy(positions, local_player, target, ai_peek.active_hitboxes)
        end
    
        ai_peek.cache.active_point_index = active_point_index
        ai_peek.targeting = active_point_pos ~= nil
    
        if move_mode:get('Automatically teleport back') then
            ai_peek.should_return = true
        end
    
        if ai_peek.targeting then
            ai_peek.set_movement(e, active_point_pos, local_player)
            ai_peek.returning = false
            ai_peek.should_return = true
            ai_peek.disable_dt = false
        elseif local_override then
            ai_peek.returning = false
            ai_peek.should_return = false
            ai_peek.dt_teleport = false
            ai_peek.disable_dt = false
        elseif ai_peek.should_return then
            ai_peek.returning = true
            ai_peek.dt_teleport = true
        end
    
        if not ai_peek.returning then
            ai_peek.cache.last_returning_time = globals.tickcount()
        end
    
        if ai_peek.returning then
            if dist_to_middle < .15 then
                ai_peek.returning = false
                ai_peek.should_return = false
                ai_peek.dt_teleport = false
                ai_peek.disable_dt = false
            elseif ai_peek.dt_teleport then
                if not exploits:can_recharge() and ai_peek.weapon_can_fire(local_player, entity.get_player_weapon(local_player)) then
                    if globals.tickcount() - ai_peek.cache.last_returning_time == 1 then
                        if move_mode:get('Force defensive') then
                            e.force_defensive = true
                        else
                            e.force_defensive = false
                        end
                    elseif ai_peek.cache.last_returning_time >= globals.tickcount() - 7 then
                        -- print(('discharged : tick - %d : last - %d'):format(globals.tickcount(), ai_peek.cache.last_returning_time))
                        e.discharge_pending = true
                        control_exploits(false)
                        ai_peek.dt_teleport = false
                        ai_peek.disable_dt = true
                    end
                end
            end
        end
    
        reference.rage.other.quickpeek_assist_mode[1]:override(ai_peek.returning and { 'Retreat on shot', 'Retreat on key release' } or ai_peek.cache.hotkeys.autopeek.mode)
    
        if ai_peek.disable_dt then
            control_exploits(false)
        end
    end
  
    ai_peek.render = function ()
        local local_player = entity.get_local_player()
        if not entity.is_alive(local_player) then
            return
        end
    
        local enabled = ai_peek.visual.active
        local active_point = ai_peek.cache.active_point_index
    
        local alpha = lerp('ai_peek_alpha', elements.aimbot.ai_peek.settings.peek_mode:get('Peek arrow') and enabled and 255 or 0, 12)
        if alpha <= 0 then
            return
        end

        local screen = { client.screen_size()} 
        local x, y = screen[1] / 2, screen[2] / 2
        local offset_distance = 70

        local custom = coloring.parse()
        local r, g, b = custom.r, custom.g, custom.b
    
        local left_alpha = lerp('ai_peek_left', (active_point == 1 or active_point == 3) and 255 or 0, 12)
        local right_alpha = lerp('ai_peek_right', (active_point == 2 or active_point == 4) and 255 or 0, 12)
    
        local scope_offset = entity.get_prop(local_player, 'm_bIsScoped') == 1 and 15 or (elements.visuals.arrows.settings.style:get() == 'Unique' and 5 or 0)
        local y_offset = lerp('ai_peek_y', scope_offset, 12, 1)
    
        local symbols = {
            left = elements.visuals.arrows.settings.style:get() == 'Unique' and '⮜' or '<',
            right = elements.visuals.arrows.settings.style:get() == 'Unique' and '⮞' or '>'
        }
    
        if left_alpha > 0 then
            renderer.text(x - offset_distance, y - y_offset, r, g, b, left_alpha * (alpha / 255), 'c+', 0, symbols.left)
        end
    
        if right_alpha > 0 then
            renderer.text(x + offset_distance, y - y_offset, r, g, b, right_alpha * (alpha / 255), 'c+', 0, symbols.right)
        end
    end
    
    ai_peek.create_values()
    ai_peek.update_hitboxes(reference.rage.aimbot.target_hitbox)
  
    -- client.set_event_callback('setup_command', ai_peek.handle)
    -- client.set_event_callback('paint', ai_peek.render)
    elements.aimbot.ai_peek.enable:set_event('setup_command', ai_peek.handle)
    elements.aimbot.ai_peek.enable:set_event('paint', ai_peek.render)
end

local predict do
    local function on_paint_ui ()
        if not elements.aimbot.predict_enemies.enable:get() then
            return
        end

        cvar.cl_interp_ratio:set_int(2)
        cvar.cl_interpolate:set_int(1)
    end

    local function on_pre_render ()
        if not elements.aimbot.predict_enemies.enable:get() then
            -- cvar.cl_extrapolate_amount:set_raw_float(0.25)
            cvar.cl_interpolate:set_int(1)
            cvar.cl_interp_ratio:set_int(2)
            return
        end
      
        -- cvar.cl_extrapolate_amount:set_raw_float(0.7)
        cvar.cl_interpolate:set_int(0)
        cvar.cl_interp_ratio:set_int(1)
    end

    client.set_event_callback('paint_ui', on_paint_ui)
    client.set_event_callback('pre_render', on_pre_render)
end

local game_enhancer do
    local fps_cvars = {
        ['Fix chams color'] = {'mat_autoexposure_max_multiplier', 0.2, 1},
        ['Disable dynamic Lighting'] = {'r_dynamiclighting', 0, 1},
        ['Disable dynamic Shadows'] = {'r_dynamic', 0, 1},
        ['Disable first-person tracers'] = {'r_drawtracers_firstperson', 0, 1},
        ['Disable ragdolls'] = {'cl_disable_ragdolls', 1, 0},
        ['Disable eye gloss'] = {'r_eyegloss', 0, 1},
        ['Disable eye movement'] = {'r_eyemove', 0, 1},
        ['Disable muzzle flash light'] = {'muzzleflash_light', 0, 1},
        ['Enable low CPU audio'] = {'dsp_slow_cpu', 1, 0},
        ['Disable bloom'] = {'mat_disable_bloom', 1, 0},
        ['Disable particles'] = {'r_drawparticles', 0, 1},
        ['Reduce breakable objects'] = {'func_break_max_pieces', 0, 15}
    }
  
    local function on_setup_command ()
        if not elements.aimbot.game_enhancer.enable:get() then
            for name, data in pairs(fps_cvars) do
                local cvar_name, boost_value, default_value = unpack(data)
                cvar[cvar_name]:set_int(default_value)
            end
            return
        end
  
        local selected_boosts = elements.aimbot.game_enhancer.settings.list:get()
        for name, data in pairs(fps_cvars) do
            local cvar_name, boost_value, default_value = unpack(data)
            cvar[cvar_name]:set_int(table_contains(selected_boosts, name) and boost_value or default_value)
        end
    end
    
    client.set_event_callback('setup_command', on_setup_command)
end

---

coloring.parse = function ()
    if colors.combobox:get() == 'Custom' then
        local r, g, b = colors.custom.color_1:get()
        if colors.custom.type:get() == 'Gradient' then
            local r2, g2, b2 = colors.custom.color_2:get()
            local r3, g3, b3 = colors.custom.color_3:get()
            local r4, g4, b4 = colors.custom.color_4:get()
            return {r = r, g = g, b = b, r2 = r2, g2 = g2, b2 = b2, r3 = r3, g3 = g3, b3 = b3, r4 = r4, g4 = g4, b4 = b4}
        else
            return {r = r, g = g, b = b}
        end

        return {r = r, g = g, b = b}
    else
        local r, g, b = reference.misc.settings.menu_color:get()
        return {r = r, g = g, b = b}
    end
end
  
local function create_interface (x, y, w, h, r, g, b, a, options)
    options = options or { }
    local side = options.side or 'down'
    local item = options.item or ''  
    local outline_y = side == 'up' and y + 12 or y + 4

    local custom = coloring.parse()
  
    -- @lordmouse: bg
    helpers.rounded_rectangle(x, y, w, h, 4, 25, 25, 25, 255 * (a / 255))
  
    -- @lordmouse: gradient lines
    if side == 'up' or side == 'down' then
        local reverse = side == 'up'

        local gradient_colors = {
            use_gradient = colors.combobox:get() == 'Custom' and colors.custom.type:get() == 'Gradient' and colors.custom.select:get(item),
            col1_start = {r = custom.r, g = custom.g, b = custom.b, a = a},
            col1_end   = {r = custom.r3, g = custom.g3, b = custom.b3, a = a},
            col2_start = {r = custom.r4, g = custom.g4, b = custom.b4, a = a},
            col2_end   = {r = custom.r2, g = custom.g2, b = custom.b2, a = a}
        }

        helpers.semi_outlined_rectangle(x + 4, outline_y, w - 8, 14, 4, 2, gradient_colors, reverse)
    elseif side == 'left' then
        if colors.combobox:get() == 'Custom' and colors.custom.type:get() == 'Gradient' and colors.custom.select:get(item) then
            draw_animated_gradient(x + 5, y + 4, 3, h - 8, 25, 
                {r = custom.r, g = custom.g, b = custom.b, a = a},
                {r = custom.r3, g = custom.g3, b = custom.b3, a = a},
                {r = custom.r4, g = custom.g4, b = custom.b4, a = a},
                {r = custom.r2, g = custom.g2, b = custom.b2, a = a}, 
                true
            )
        else
            renderer.gradient(x + 5, y + 4, 3, h - 8, r, g, b, a, r, g, b, 0, false)
        end
    elseif side == 'right' then
        if colors.combobox:get() == 'Custom' and colors.custom.type:get() == 'Gradient' and colors.custom.select:get(item) then
            draw_animated_gradient(x + w - 8, y + 4, 3, h - 8, 25, 
                {r = custom.r, g = custom.g, b = custom.b, a = a},
                {r = custom.r3, g = custom.g3, b = custom.b3, a = a},
                {r = custom.r4, g = custom.g4, b = custom.b4, a = a},
                {r = custom.r2, g = custom.g2, b = custom.b2, a = a}, 
                true
            )
        else
            renderer.gradient(x + w - 8, y + 4, 3, h - 8, r, g, b, 0, r, g, b, a, false)
        end
    elseif side == 'left + right' then
        if colors.combobox:get() == 'Custom' and colors.custom.type:get() == 'Gradient' and colors.custom.select:get(item) then
            draw_animated_gradient(x + 5, y + 4, 3, h - 8, 25, 
                {r = custom.r, g = custom.g, b = custom.b, a = a},
                {r = custom.r3, g = custom.g3, b = custom.b3, a = a},
                {r = custom.r4, g = custom.g4, b = custom.b4, a = a},
                {r = custom.r2, g = custom.g2, b = custom.b2, a = a}, 
                true,
                true
            )

            draw_animated_gradient(x + w - 8, y + 4, 3, h - 8, 25, 
                {r = custom.r, g = custom.g, b = custom.b, a = a},
                {r = custom.r3, g = custom.g3, b = custom.b3, a = a},
                {r = custom.r4, g = custom.g4, b = custom.b4, a = a},
                {r = custom.r2, g = custom.g2, b = custom.b2, a = a}, 
                true,
                false
            )
        else
            renderer.gradient(x + 5, y + 4, 3, h - 8, r, g, b, a, r, g, b, 0, false)
            renderer.gradient(x + w - 8, y + 4, 3, h - 8, r, g, b, 0, r, g, b, a, false)
        end
    end
  
    -- @lordmouse: gs outline
    helpers.rounded_outlined_rectangle(x, y, w, h, 4, 1, 12, 12, 12, a)
    helpers.rounded_outlined_rectangle(x + 1, y + 1, w - 2, h - 2, 4, 1, 60, 60, 60, a)
    helpers.rounded_outlined_rectangle(x + 2, y + 2, w - 4, h - 4, 4, 3, 40, 40, 40, a)
end

-- Watermark module removed - now using advert module below

local keybinds = { width = 160, height = 22 }; do
    local drag = drag_system.new(
        'windows_keybinds',
        drag_slider.windows.keybinds.x,
        drag_slider.windows.keybinds.y,
        screen_size_x() * 0.7, screen_size_y() / 2 - 60,
        'xy',
        {
            w = function () return keybinds.width end,
            h = function () return keybinds.height end,
            snap_distance = 0,
            show_guides = true,
            show_default_dot = false,
            show_highlight = true,
            align_center = false,
            show_center_dot = false
        }
    )

    local alpha = 0 local anim_show = 0 local anim_height = 0 local anim_width = 0
    local bind_anim = { }
    local bind_order = { }

    local function get_mode_name (hotkey)
        if not hotkey then return 'holding' end
        local mode_number = hotkey[2]
        if mode_number == 0 then
            return 'always on'
        elseif mode_number == 1 then
            return 'holding'
        elseif mode_number == 2 then
            return 'toggled'
        elseif mode_number == 3 then
            return 'off hotkey'
        end
        return 'holding'
    end

    local all_binds = {
        { name = 'Double tap', ref = reference.rage.aimbot.double_tap[1], variant = '1', key = 'Double tap' },
        { name = 'Hide shots', ref = reference.antiaim.other.on_shot_anti_aim[1], variant = '1', key = 'Hide shots' },
        { name = 'Ping spike', ref = reference.rage.ps[1], variant = '1', key = 'Ping spike' },
        { name = 'Fake duck', ref = reference.rage.other.fake_duck, variant = '2', key = 'Fake duck' },
        { name = 'Slow walk', ref = reference.antiaim.other.slow_motion[1], variant = '1', key = 'Slow walk' },
        { name = 'Force body aim', ref = reference.rage.aimbot.force_body, variant = '2', key = 'Force body aim' },
        { name = 'Force safe point', ref = reference.rage.aimbot.force_safe, variant = '2', key = 'Force safe point' },
        { name = 'Min. damage', ref = reference.rage.aimbot.minimum_damage_override[1], variant = '1', key = 'Min. damage' },
        { name = 'Freestanding', ref = elements.anti_aim.hotkeys.freestanding, variant = '1', key = 'Freestanding' },
        { name = 'Edge yaw', ref = elements.anti_aim.hotkeys.edge_yaw, variant = '1', key = 'Edge yaw' }
    }
    for i, v in ipairs(all_binds) do
        bind_order[v.key] = i
    end

    local function any_bind_active()
        for _, b in ipairs(all_binds) do
            local ref = b.ref
            local variant = b.variant
            if variant == '1' and (ref and ref.hotkey and ref.hotkey:get()) then
                if get_mode_name({ref:get_hotkey()}) ~= 'always on' then
                    return true
                end
            elseif variant == '2' and (ref and ref:get()) then
                if get_mode_name({ref:get()}) ~= 'always on' then
                    return true
                end
            end
        end
        return false
    end

    local function on_paint_ui()
        local should_show = elements.visuals.windows:get('Keybinds') and (ui.is_menu_open() or any_bind_active())
        local target_alpha = should_show and 255 or 0
        alpha = lerp('windows_keybinds', target_alpha, 10, 0.001, 'ease_out')
        anim_show = lerp('kb_anim_show', target_alpha > 0 and 1 or 0, 10, 0.001, 'ease_out')
        if alpha < 1 then return end

        drag:update(alpha)
        drag:draw_guides(alpha)

        local x, y = drag:get_pos()
        local custom = coloring.parse()

        for _, b in ipairs(all_binds) do
            local ref = b.ref
            local variant = b.variant
            local active = false
            local mode = 'holding'
            if variant == '1' then
                if ref and ref.hotkey then
                    mode = get_mode_name({ref:get_hotkey()})
                    active = ref.hotkey:get() and mode ~= 'always on'
                end
            elseif variant == '2' then
                if ref then
                    mode = get_mode_name({ref:get()})
                    active = ref:get() and mode ~= 'always on'
                end
            end

            bind_anim[b.key] = bind_anim[b.key] or { alpha = 0, y = 0, target_row = 0, cur_row = 0 }
            local target = active and 1 or 0
            bind_anim[b.key].alpha = lerp('kb_bind_alpha_' .. b.key, target, 10, 0.001, 'ease_out')
            bind_anim[b.key].mode = mode
            bind_anim[b.key].active = active
            bind_anim[b.key].name = b.name
            bind_anim[b.key].key = b.key
        end

        local visible_binds = { }
        local row = 0
        for _, b in ipairs(all_binds) do
            local anim = bind_anim[b.key]
            if anim.alpha > 0.01 then
                row = row + 1
                anim.target_row = row
                table.insert(visible_binds, anim)
            else
                anim.target_row = 0
            end
        end

        for _, b in ipairs(all_binds) do
            local anim = bind_anim[b.key]
            local target_y = anim.target_row > 0 and anim.target_row or (#visible_binds - 1)
            anim.cur_row = lerp('kb_bind_row_' .. b.key, target_y, 7, 0.01, 'ease_out')
        end

        keybinds.height = 32 + (#visible_binds) * 16
        keybinds.width = 140
        for _, anim in ipairs(visible_binds) do
            local w = renderer.measure_text('b', anim.name .. ' [' .. anim.mode .. ']')
            if w + 24 > keybinds.width then keybinds.width = w + 24 end
        end

        anim_height = math.floor(lerp('kb_anim_height', keybinds.height - 4, 10, 0.1, 'ease_out'))
        anim_width = math.floor(lerp('kb_anim_width', keybinds.width - 4, 10, 0.1, 'ease_out'))

        create_interface(
            x + 2, y + 2, anim_width, anim_height,
            custom.r, custom.g, custom.b, alpha * anim_show,
            { side = 'up', item = 'Keybinds' }
        )

        renderer.text(x + keybinds.width / 2, y + 16, 255, 255, 255, alpha * anim_show, 'cb', nil, 'Keybinds')

        for _, b in ipairs(all_binds) do
            local anim = bind_anim[b.key]
            if anim.alpha > 0.01 then
                local row_y = y + 10 + math.floor(anim.cur_row * 16)
                local a = math.floor(alpha * anim_show * anim.alpha)
                renderer.text(x + 10, row_y, 200, 200, 200, a, '', nil, anim.name)
                renderer.text(x + keybinds.width - 10, row_y, 200, 200, 200, a, 'r', nil, '[' .. anim.mode .. ']')
            end
        end
    end

    -- client.set_event_callback('paint_ui', on_paint_ui)
    elements.visuals.windows:set_event('paint_ui', on_paint_ui, function (ref)
        return ref:get('Keybinds')
    end)
end

local spectators = { width = 100, height = 60 }; do
    local drag = drag_system.new(
        'spectators',
        drag_slider.windows.spectators.x,
        drag_slider.windows.spectators.y,
        screen_size_x() - 5, screen_size_y() / 2,
        'xy',
        {
            w = function () return spectators.width end,
            h = function () return spectators.height end,
            align_x = 'right',
            snap_distance = 10,
            show_guides = true,
            show_default_dot = true,
            show_highlight = true,
            align_center = true,
            show_center_dot = true
        }
    )

    local function on_paint_ui ()
        
    end
end

local debug_panel = { width = 100, height = 20 }; do
    local drag = drag_system.new(
        'debug_panel',
        drag_slider.windows.debug_panel.x,
        drag_slider.windows.debug_panel.y,
        20, screen_size_y() / 2 - 390,
        'xy',
        {
            w = function () return debug_panel.width end,
            h = function () return debug_panel.height end,
            align_x = 'left',
            snap_distance = 10,
            show_guides = true,
            show_default_dot = true,
            show_highlight = true,
            align_center = true,
            show_center_dot = true
        }
    )

    local function debug_text (x, y, alpha, label, value, show_percent)
        show_percent = show_percent or false
        local flag = 'b'
        local tooltip = type(value) == 'number' and (show_percent and '%' or '°') or ''

        local custom = coloring.parse()
        local color = nil
        if colors.combobox:get() == 'Custom' and colors.custom.type:get() == 'Gradient' then
            color = prepare_gradient_cache(25,
                {r = custom.r, g = custom.g, b = custom.b, a = alpha},
                {r = custom.r3, g = custom.g3, b = custom.b3, a = alpha},
                {r = custom.r4, g = custom.g4, b = custom.b4, a = alpha},
                {r = custom.r2, g = custom.g2, b = custom.b2, a = alpha},
                false
            )
        end

        local measure = renderer.measure_text(flag, label)
        local measure_arrow = renderer.measure_text(flag, '⬥') + 4
        local r, g, b = custom.r, custom.g, custom.b
        if color then
            r, g, b = color.r, color.g, color.b
        end

        renderer.text(x, y, r, g, b, alpha, flag, nil, '⬥')
        renderer.text(x + measure_arrow, y, 255, 255, 255, alpha, flag, nil, label)
        renderer.text(x + measure_arrow + measure, y, 255, 255, 255, alpha, '', nil, tostring(value) .. tooltip)
    end

    local function make_debug_drawer (y_start, alpha, line_height)
        line_height = line_height or 15
        local y_offset = 0
    
        return function (x, label, value, show_percent)
            debug_text(x, y_start + y_offset, alpha, label, value, show_percent)
            y_offset = y_offset + line_height
        end
    end

    local pitch, pitch_offset, yaw, offset, yaw_base, yaw_jitter, jitter_offset, body_yaw, body_side, fs_body_yaw = '', 0, '', 0, '', '', 0, '', 0, false
    local function on_setup_command (e)
        local angles = builder.angles(e)
        
        pitch = angles.pitch
        pitch_offset = angles.pitch_offset
        yaw = angles.yaw
        offset = angles.offset
        yaw_base = angles.yaw_base
        yaw_jitter = angles.yaw_jitter
        jitter_offset = angles.jitter_offset
        body_yaw = angles.body_yaw
        body_side = angles.body_side
        fs_body_yaw = angles.fs_body_yaw
    end

    local function on_paint_ui ()
        local enabled = elements.visuals.windows:get('Debug panel')
        local alpha = lerp('debug_panel_alpha', enabled and 255 or 0, 10, 0.001, 'ease_out')
        if alpha < 1 then return end

        local condition = builder.get_state()

        local custom = coloring.parse()
        local width = renderer.measure_text('b', string.format('%s / Debug panel', lua.name)) + 8
        debug_panel.width = width

        drag:update(alpha)
        drag:draw_guides(alpha)

        local x, y = drag:get_pos()
        if colors.combobox:get() == 'Custom' and colors.custom.type:get() == 'Gradient' then
            draw_gradient_text(
                x + 4, 
                y + 4,
                'b',
                nil,
                string.format('%s', lua.name),
                25,
                {r = custom.r, g = custom.g, b = custom.b, a = alpha},
                {r = custom.r3, g = custom.g3, b = custom.b3, a = alpha},
                {r = custom.r4, g = custom.g4, b = custom.b4, a = alpha},
                {r = custom.r2, g = custom.g2, b = custom.b2, a = alpha}
            )

            local gradient_width = renderer.measure_text('b', string.format('%s', lua.name))

            renderer.text(x + gradient_width + 7, y + 4, 255, 255, 255, alpha, 'b', nil, '/ Debug panel')
        else
            renderer.text(x + 4, y + 4, 255, 255, 255, alpha, 'b', nil, string.format('\a%s%s\a%s / Debug panel', coloring.rgba_to_hex(custom.r, custom.g, custom.b, alpha), lua.name, coloring.rgba_to_hex(255, 255, 255, alpha)))
        end

        local draw_debug = make_debug_drawer(y + 20, alpha)

        draw_debug(x + 4, 'State: ', condition)
        draw_debug(x + 24, 'B. Modifier: ', elements.conditions[condition].modifier:get())
        draw_debug(x + 24, 'B. Mod. offset: ', elements.conditions[condition].modifier_offset:get())
        draw_debug(x + 24, 'B. Mod. randomization: ', elements.conditions[condition].modifier_randomization:get(), true)
        draw_debug(x + 44, 'O. Offset: ', offset)
        draw_debug(x + 44, 'O. Modifier: ', reference.antiaim.angles.yaw_jitter[1]:get())
        draw_debug(x + 44, 'O. Mod. offset: ', reference.antiaim.angles.yaw_jitter[2]:get())
        draw_debug(x + 44, 'O. Body yaw: ', reference.antiaim.angles.body_yaw[1]:get())
        draw_debug(x + 44, 'O. Body side: ', reference.antiaim.angles.body_yaw[2]:get())
        -- draw_debug(x + 4, 'B. Delay: ', elements.conditions[condition].delay:get())
    end

    client.set_event_callback('setup_command', on_setup_command)
    client.set_event_callback('paint_ui', on_paint_ui)
end

local multi_panel = { width = 100, height = 60 }; do
    local drag = drag_system.new(
        'multi_panel',
        drag_slider.windows.multi_panel.x,
        drag_slider.windows.multi_panel.y,
        screen_size_x() / 2, screen_size_y() / 2 - 400,
        'xy',
        {
            w = function () return multi_panel.width end,
            h = function () return multi_panel.height end,
            align_x = 'center',
            snap_distance = 10,
            show_guides = true,
            show_default_dot = true,
            show_highlight = true,
            align_center = true,
            show_center_dot = true
        }
    )

    local defensive_ticks, defensive_max_ticks = { }, 15
    local lc_broken_max, lc_broken_show, lc_broken_ticks, lc_broken_timer, lc_broken_delay = 15, false, 0, 0, 1.5
    local anim_height = 0

    multi_panel._slowed_cache = { last_velocity = 0, last_modifier = 1, last_slow = 0, last_hit_tick = 0 }
    local indicator_anim = { slowed = { }, defensive = { }, lc = { } }

    local function get_slowed_down_percent ()
        local me = entity.get_local_player()
        if not me or not entity.is_alive(me) then
            multi_panel._slowed_cache.last_velocity = 0
            multi_panel._slowed_cache.last_modifier = 1
            multi_panel._slowed_cache.last_slow = 0
            return 0
        end

        local modifier = entity.get_prop(me, 'm_flVelocityModifier') or 1
        local velocity = { entity.get_prop(me, 'm_vecVelocity') }
        local speed = math.sqrt((velocity[1] or 0)^2 + (velocity[2] or 0)^2)
        local on_ground = bit.band(entity.get_prop(me, 'm_fFlags') or 0, 1) == 1

        if modifier < 1 then
            if speed < (multi_panel._slowed_cache.last_velocity or 0) - 1 then
                multi_panel._slowed_cache.last_slow = 1 - modifier
                multi_panel._slowed_cache.last_hit_tick = globals.tickcount()
            end
            multi_panel._slowed_cache.last_modifier = modifier
            multi_panel._slowed_cache.last_velocity = speed
            return 1 - modifier
        else
            if on_ground and speed < 1 then
                multi_panel._slowed_cache.last_slow = 0
            end
            multi_panel._slowed_cache.last_modifier = 1
            multi_panel._slowed_cache.last_velocity = speed
            return 0
        end
    end

    local function on_paint_ui ()
        local enabled = elements.visuals.windows:get('Multi panel')
        local alpha = lerp('multi_panel_alpha', enabled and 255 or 0, 10, 0.001, 'ease_out')
        if alpha < 1 then return end

        local menu_open = ui.is_menu_open()
        local me = entity.get_local_player()
        local is_alive = me and entity.is_alive(me)
        local slow_val, slowed_active = 0, false

        if is_alive then
            slow_val = get_slowed_down_percent()
            slowed_active = slow_val > 0.01
        else
            multi_panel._slowed_cache.last_velocity = 0
            multi_panel._slowed_cache.last_modifier = 1
            multi_panel._slowed_cache.last_slow = 0
        end

        local is_defensive = exploits:in_defensive()
        table.insert(defensive_ticks, 1, is_defensive and 1 or 0)
        if #defensive_ticks > defensive_max_ticks then table.remove(defensive_ticks) end
        local defensive_active = is_alive and is_defensive or false

        local is_lc_broken = is_alive and exploits:is_lagcomp_broken() or false
        local lc_ticks = 0
        
        if is_lc_broken then
            lc_broken_timer = globals.realtime()
            lc_ticks = helpers:clamp(exploits.ticks_processed, 0, lc_broken_max)
            lc_broken_ticks = lc_ticks
            lc_broken_show = true
        elseif lc_broken_show and globals.realtime() - lc_broken_timer < lc_broken_delay then
            lc_ticks = lc_broken_ticks
        else
            lc_ticks = 0
            lc_broken_show = false
        end
        
        local lc_active = lc_broken_show and lc_ticks       

        local show = menu_open or slowed_active or defensive_active or lc_active
        local animate = lerp('multi_panel_show', show and 1 or 0, 10, 0.001, 'ease_out')
        local indicators = { }
        local pad_top, pad_bottom, pad_between, section_h = 12, 15, 6, 28
        if slowed_active or menu_open then table.insert(indicators, 'slowed') end
        if defensive_active or menu_open then table.insert(indicators, 'defensive') end
        if lc_active or menu_open then table.insert(indicators, 'lc') end

        local indicator_y = { }
        local active_names = { }
        local indicator_delay_state = multi_panel._indicator_delay_state or {defensive = {active = false, timer = 0}, lc = {active = false, timer = 0}}
        multi_panel._indicator_delay_state = indicator_delay_state

        local function delay_insert (name, is_active, delay)
            local now = globals.realtime()
            if is_active then
                indicator_delay_state[name].active = true
                indicator_delay_state[name].timer = now
                table.insert(active_names, name)
            else
                if indicator_delay_state[name].active then
                    if now - indicator_delay_state[name].timer < delay then
                        table.insert(active_names, name)
                    else
                        indicator_delay_state[name].active = false
                    end
                end
            end
        end

        for _, name in ipairs({'slowed', 'defensive', 'lc'}) do
            local is_active = false
            for _, v in ipairs(indicators) do
                if v == name then
                    is_active = true
                    break
                end
            end

            if name == 'defensive' or name == 'lc' then
                delay_insert(name, is_active, 0.5)
            else
                if is_active then
                    table.insert(active_names, name)
                end
            end
        end

        local visible_count = #active_names

        for i, name in ipairs({'slowed', 'defensive', 'lc'}) do
            local active = false
            for _, v in ipairs(active_names) do
                if v == name then active = true break end
            end

            local target_alpha = active and 1 or 0
            indicator_anim[name].alpha = lerp('multi_panel_' .. name .. '_alpha', target_alpha, 10, 0.001, 'ease_out')

            local idx = 0
            for j, v in ipairs(active_names) do
                if v == name then idx = j break end
            end

            local actual_padding = pad_top
            if name == 'slowed' then
                if visible_count == 1 then
                    actual_padding = 19
                else
                    actual_padding = 15
                end
            elseif name == 'defensive' then
                if visible_count > 2 then
                    actual_padding = 11
                else
                    actual_padding = 16
                end
            elseif name == 'lc' and visible_count == 1 then
                actual_padding = 14
            end

            if indicator_anim[name].alpha > 0.01 and idx > 0 then
                indicator_anim[name].target_y = actual_padding + (idx - 1) * (section_h + pad_between)
            else
                indicator_anim[name].target_y = actual_padding + (visible_count) * (section_h + pad_between) + 10
            end

            indicator_anim[name].y = lerp('multi_panel_' .. name .. '_y', indicator_anim[name].target_y, 10, 0.01, 'ease_out')
            indicator_y[name] = indicator_anim[name].y
        end

        local target_height, actual_visible = pad_top + pad_bottom, 0
        for _, name in ipairs({'slowed', 'defensive', 'lc'}) do
            if indicator_anim[name].alpha > 0.01 then
                target_height = target_height + section_h
                actual_visible = actual_visible + 1
            end
        end
        
        if actual_visible > 1 then
            target_height = target_height + 5 * (actual_visible - 1)
        end
        anim_height = lerp('multi_panel_height', target_height, 10, 0.01, 'ease_out')
        multi_panel.height = anim_height

        drag:update(alpha)
        drag:draw_guides(alpha)
        local x, y = drag:get_pos()
        local custom = coloring.parse()
        local color
        if colors.combobox:get() == 'Custom' and colors.custom.type:get() == 'Gradient' and colors.custom.select:get('Multi panel') then
            color = prepare_gradient_cache(25,
                {r = custom.r, g = custom.g, b = custom.b, a = alpha},
                {r = custom.r3, g = custom.g3, b = custom.b3, a = alpha},
                {r = custom.r4, g = custom.g4, b = custom.b4, a = alpha},
                {r = custom.r2, g = custom.g2, b = custom.b2, a = alpha},
                false
            )
        end
        create_interface(
            x + 2, y + 2,
            math.max(multi_panel.width - 4, 0),
            math.max(anim_height - 4, 0),
            custom.r, custom.g, custom.b, alpha * animate,
            { side = 'left + right', item = 'Multi panel' }
        )

        local INDICATOR_BAR_W = 60
        local INDICATOR_BAR_H = 7
        local INDICATOR_GRAPH_H = 14
        local INDICATOR_FONT_SIZE = 'cb'
        local INDICATOR_RADIUS = 2

        if indicator_anim.slowed.alpha > 0.01 then
            local y_off = y + indicator_y.slowed
            renderer.text(x + (multi_panel.width / 2), y_off, 255, 255, 255, alpha * animate * indicator_anim.slowed.alpha, INDICATOR_FONT_SIZE, nil, 'Slowed down')

            local bar_w, bar_h = INDICATOR_BAR_W, INDICATOR_BAR_H
            local bar_x, bar_y = x + (multi_panel.width - bar_w) / 2, y_off + 10

            local gradient_colors = {
                use_gradient = colors.combobox:get() == 'Custom' and colors.custom.type:get() == 'Gradient' and colors.custom.select:get('Multi panel'),
                col1_start = {r = custom.r, g = custom.g, b = custom.b, a = alpha * animate * indicator_anim.slowed.alpha},
                col1_end   = {r = custom.r3, g = custom.g3, b = custom.b3, a = alpha * animate * indicator_anim.slowed.alpha},
                col2_start = {r = custom.r4, g = custom.g4, b = custom.b4, a = alpha * animate * indicator_anim.slowed.alpha},
                col2_end   = {r = custom.r2, g = custom.g2, b = custom.b2, a = alpha * animate * indicator_anim.slowed.alpha}
            }

            helpers.rounded_rectangle(bar_x, bar_y, bar_w, bar_h, INDICATOR_RADIUS, 40, 40, 40, (alpha * 0.7) * animate * indicator_anim.slowed.alpha)
            helpers.rounded_rectangle(bar_x, bar_y, math.max(bar_w * slow_val, 3), bar_h, INDICATOR_RADIUS, custom.r, custom.g, custom.b, alpha * animate * indicator_anim.slowed.alpha, 
                gradient_colors
            )
        end

        if indicator_anim.defensive.alpha > 0.01 then
            local y_off = y + indicator_y.defensive
            renderer.text(x + (multi_panel.width / 2), y_off, 255, 255, 255, alpha * animate * indicator_anim.defensive.alpha, INDICATOR_FONT_SIZE, nil, 'Defensive')
            local bar_w, bar_h = INDICATOR_BAR_W, INDICATOR_GRAPH_H
            local bar_x, bar_y = x + (multi_panel.width - bar_w) / 2, y_off + 9

            helpers.rounded_rectangle(bar_x, bar_y, bar_w, bar_h, INDICATOR_RADIUS, 40, 40, 40, (alpha * 0.7) * animate * indicator_anim.defensive.alpha)

            local points = { }
            local tick_w = bar_w / (defensive_max_ticks - 1)
            for i = 1, defensive_max_ticks do
                local value = defensive_ticks[i] == 1 and 1 or 0
                local anim_val = lerp('defensive_graph_' .. i, value, 10, 0.01, 'ease_out')
                local px = bar_x + (i - 1) * tick_w
                local py = bar_y + bar_h - anim_val * (bar_h - 3)
                points[#points+1] = {px, py, anim_val}
            end

            for i = 2, #points do
                if colors.combobox:get() == 'Custom' and colors.custom.type:get() == 'Gradient' and colors.custom.select:get('Multi panel') then
                    local c = {color.r, color.g, color.b, math.floor(alpha * animate * indicator_anim.defensive.alpha)}
                    renderer.line(points[i-1][1], points[i-1][2], points[i][1], points[i][2], c[1], c[2], c[3], c[4])
                else
                    local c = {custom.r, custom.g, custom.b, math.floor(alpha * animate * indicator_anim.defensive.alpha)}
                    renderer.line(points[i-1][1], points[i-1][2], points[i][1], points[i][2], c[1], c[2], c[3], c[4])
                end
            end
        end

        if indicator_anim.lc.alpha > 0.01 then
            local y_off = y + indicator_y.lc
            renderer.text(x + (multi_panel.width / 2), y_off, 255, 255, 255, alpha * animate * indicator_anim.lc.alpha, INDICATOR_FONT_SIZE, nil, 'Lagcomp')

            local lc_bar_w, lc_bar_h = INDICATOR_BAR_W, INDICATOR_BAR_H
            local lc_bar_x, lc_bar_y = x + (multi_panel.width - lc_bar_w) / 2, y_off + 10
            local lc_percent = helpers:clamp(lc_ticks / lc_broken_max, 0, 1)
            helpers.rounded_rectangle(lc_bar_x, lc_bar_y, lc_bar_w, lc_bar_h, INDICATOR_RADIUS, 40, 40, 40, (alpha * 0.7) * animate * indicator_anim.lc.alpha)
            helpers.rounded_rectangle(lc_bar_x, lc_bar_y, math.max(lc_bar_w * lc_percent, 3), lc_bar_h, INDICATOR_RADIUS, 255, 62, 62, alpha * animate * lc_percent * indicator_anim.lc.alpha)

            renderer.text(x + (multi_panel.width / 2), lc_bar_y + lc_bar_h + 8, 255, 62, 62, alpha * animate * indicator_anim.lc.alpha, INDICATOR_FONT_SIZE, nil, string.format('%d ticks', lc_ticks))
        end
    end

    -- client.set_event_callback('paint_ui', on_paint_ui)
    elements.visuals.windows:set_event('paint_ui', on_paint_ui, function (ref)
        return ref:get('Multi panel')
    end)
end

-- ============================================================
-- Event Logger (из stellar.lua)
-- ============================================================
local logs = {
    miss_colors = {
        ["spread"] = { r = 255, g = 255, b = 115, a = 255 },
        ["prediction error"] = { r = 255, g = 98, b = 98, a = 255 },
        ["death"] = { r = 100, g = 100, b = 255, a = 255 },
        ["unregistered shot"] = { r = 100, g = 100, b = 255, a = 255 },
        ["?"] = { r = 255, g = 98, b = 98, a = 255 }
    },
    hitboxes = { "generic", "head", "chest", "stomach", "left arm", "right arm", "left leg", "right leg", "neck", "?", "gear" },
    aim_data = {},
    log = {}
}

do
    logs.aim_fire = function(shot)
        local data = {}
        do
            data.backtrack = globals.tickcount() - shot.tick
        end

        table.insert(logs.aim_data, shot.id, data)
    end

    logs.aim_hit = function(shot)
        local alive = entity.is_alive(shot.target)

        local aim_data = logs.aim_data[shot.id]

        local name = entity.get_player_name(shot.target)
        local hitbox = logs.hitboxes[shot.hitgroup + 1]
        local damage = tostring(shot.damage)
        local hitchance = tostring(math.floor(shot.hit_chance))
        local backtrack = tostring(aim_data.backtrack)

        local msg = ""
        if alive then
            msg = string.format(
                "Hit ${%s} in ${%s} for ${%s} (hc: ${%s} · bt: ${%s})",
                name, hitbox, damage, hitchance, backtrack
            )
        else
            msg = string.format(
                "Killed ${%s} in ${%s} (hc: ${%s} · bt: ${%s})",
                name, hitbox, hitchance, backtrack
            )
        end
        table.insert(logs.log, {
            log = msg,
            alpha = 0, 
            time = globals.curtime() + 4
        })
        
        -- Цветной вывод в консоль
        local custom = coloring.parse()
        client.color_log(custom.r, custom.g, custom.b, string.format('%s » ', lua.name:lower()))
        client.color_log(144, 167, 255, msg:gsub("%${(.-)}", "%1"))
    end


    logs.aim_miss = function(shot)
        local aim_data = logs.aim_data[shot.id]

        local name = entity.get_player_name(shot.target)
        local hitbox = logs.hitboxes[shot.hitgroup + 1]
        local state = shot.reason
        local damage = tostring(shot.damage)
        local hitchance = tostring(math.floor(shot.hit_chance))
        local backtrack = tostring(aim_data.backtrack)

        local msg = string.format(
            "Missed ${%s} in ${%s} due to ${%s} (hc: ${%s}%% · bt: ${%s})",
            name, hitbox, state, hitchance, backtrack
        )
        table.insert(logs.log, {
            log = msg,
            alpha = 0, 
            time = globals.curtime() + 4
        })
        
        -- Цветной вывод в консоль
        client.color_log(200, 200, 200, string.format('%s » ', lua.name:lower()))
        client.color_log(200, 200, 200, msg:gsub("%${(.-)}", "%1"))
    end

    logs.handle = function()
        if not elements.visuals.windows:get('Event logger') then
            return
        end
        
        local settings = elements.visuals.event_logger.settings.type
        if not settings:get('On screen') then
            return
        end
        
        local sw, sh = client.screen_size()
        local pos = { x = sw / 2, y = sh / 2 + 130 }
        local add = 0
        
        for i, log in pairs(logs.log) do
            if log.time > globals.curtime() and i <= 6 then
                log.alpha = lerp(log.alpha, 255, 0.1)
            else
                log.alpha = lerp(log.alpha, 0, 0.1)
                if log.alpha < 1 or i > 6 then
                    table.remove(logs.log, i)
                end
            end
            
            if log.alpha > 0 then
                -- Hit = синий, Miss = серый
                local clr = log.log:find('Missed') and { r = 200, g = 200, b = 200, a = log.alpha } or { r = 144, g = 167, b = 255, a = log.alpha }
                renderer.text(pos.x, pos.y + add, clr.r, clr.g, clr.b, math.floor(log.alpha), 'c', 0, log.log:gsub("%${(.-)}", "%1"))
                add = add + 15 * log.alpha / 255
            end
        end
    end

    client.set_event_callback('aim_fire', function(e)
        if elements.visuals.windows:get('Event logger') then
            logs.aim_fire(e)
        end
    end)
    
    client.set_event_callback('aim_hit', function(e)
        if elements.visuals.windows:get('Event logger') then
            logs.aim_hit(e)
        end
    end)
    
    client.set_event_callback('aim_miss', function(e)
        if elements.visuals.windows:get('Event logger') then
            logs.aim_miss(e)
        end
    end)
    
    client.set_event_callback('paint_ui', logs.handle)
end

---

local side_indicators_buffer = { }; do
    local indicator_animations = { }
    local indicator_state      = {
        _lc_delay = { active = false, timer = 0, last_broken = false }
    }

    local function on_indicator (indicator)
        if #side_indicators_buffer == 0 or not (
            side_indicators_buffer[#side_indicators_buffer].text == indicator.text and
            side_indicators_buffer[#side_indicators_buffer].r    == indicator.r    and
            side_indicators_buffer[#side_indicators_buffer].g    == indicator.g    and
            side_indicators_buffer[#side_indicators_buffer].b    == indicator.b
        ) then
            side_indicators_buffer[#side_indicators_buffer + 1] = indicator
        end
    end

    local planting_started_at = nil
    local function on_bomb_beginplant ()
        planting_started_at = globals.curtime()
    end

    local function on_paint ()
        local side_indicators   = side_indicators_buffer
        side_indicators_buffer  = { }
        local indicator_present = { }
        local me                = entity.get_local_player()
        if not entity.is_alive(me) then return end

        local lc_ind            = elements.visuals.windows:get('LC Side indicator')
        local _, screen_y       = client.screen_size()
        local base_x, base_offset = 20, screen_y - 340

        if lc_ind then
            local is_broken = exploits:is_lagcomp_broken() or is_breaking_velocity_lc()
            local delay     = 1.0
            if is_broken then
                if not indicator_state._lc_delay.active then
                    indicator_state._lc_delay.active = true
                    indicator_state._lc_delay.timer  = globals.realtime()
                end
                indicator_state._lc_delay.last_broken = true
                table.insert(side_indicators, 1, { text='LC', r=255, g=255, b=255, a=255, bar=true })
            elseif indicator_state._lc_delay.active then
                local el = globals.realtime() - indicator_state._lc_delay.timer
                if el < delay then
                    table.insert(side_indicators, 1, { text='LC', r=255, g=0, b=50, a=255, bar=true })
                else
                    indicator_state._lc_delay.active = false
                    indicator_state._lc_delay.timer  = 0
                end
            end
        end

        local indicator_heights = { }
        for i, ind in ipairs(side_indicators) do
            local _, h = renderer.measure_text('d+', ind.text)
            indicator_heights[i] = h + 2
        end

        local extra_pad = 5
        for i, ind in ipairs(side_indicators) do
            local key = ind.text or tostring(i)
            indicator_present[key] = true
            indicator_animations[key] = indicator_animations[key] or {
                offset        = base_offset,
                alpha         = 0,
                bar           = 0,
                circle        = 1,
                target_offset = base_offset
            }
            local prev_h = 0
            for j = 1, i - 1 do
                prev_h = prev_h + indicator_heights[j]
                if side_indicators[j].text and
                   (side_indicators[j].text:lower():find('ping') or
                    (lc_ind and side_indicators[j].text == 'LC'))
                then
                    prev_h = prev_h + extra_pad
                end
            end
            local tgt = base_offset - prev_h
            if ind.text and
               (ind.text:lower():find('ping') or (lc_ind and ind.text == 'LC'))
            then
                tgt = tgt - extra_pad
            end
            indicator_animations[key].target_offset = tgt
        end

        local sorted_keys = { }
        for i, ind in ipairs(side_indicators) do
            sorted_keys[i] = ind.text or tostring(i)
        end

        for _, key in ipairs(sorted_keys) do
            local anim = indicator_animations[key]
            local lk   = key
            if key:sub(1,1):match('[AB]') and key:find('s',2,true) then
                lk = 'bombsite_indicator'
            elseif key:sub(1,5) == 'FATAL' or (key:find('HP',1,true) and key:find('%-')) then
                lk = 'bombsite_dmg_indicator'
            end
            anim.offset = lerp('indicator_offset_'..lk, anim.target_offset, 16, 0.01, 'ease_out')
        end

        local ping_idx, ping_col, ping_val
        local lc_idx,  lc_col
        for i, ind in ipairs(side_indicators) do
            local key  = ind.text or tostring(i)
            local anim = indicator_animations[key]
            local lk   = key
            if key:sub(1,1):match('[AB]') and key:find('s',2,true) then
                lk = 'bombsite_indicator'
            elseif key:sub(1,5) == 'FATAL' or (key:find('HP',1,true) and key:find('%-')) then
                lk = 'bombsite_dmg_indicator'
            end
            anim.alpha  = lerp('indicator_alpha_'..lk, ind.a or 255, 16, 0.01, 'ease_out')
            anim.bar    = lerp('indicator_bar_'..key, (ind.text and (ind.text:lower():find('ping') or ind.text=='LC')) and 1 or 0, 16, 0.01, 'ease_out')
            if ind.text and ind.text:lower() == 'dt' then
                local charged = (ind.r==255 and ind.g==255 and ind.b==255)
                local tgt     = charged and 0 or 1
                anim.circle  = lerp('indicator_circle_'..key, tgt, 16, 0.01, 'ease_out')
            else
                anim.circle  = lerp('indicator_circle_'..key, 0, 16, 0.01, 'ease_out')
            end

            renderer.text(base_x, anim.offset, ind.r, ind.g, ind.b, anim.alpha, 'd+', nil, ind.text)

            if ind.text and ind.text:lower():find('ping') then
                ping_idx = i
                ping_col = { ind.r, ind.g, ind.b, anim.alpha }
                ping_val = reference.rage.ps[2]:get() or 100
            end

            if lc_ind and ind.text == 'LC' then
                lc_idx = i
                lc_col = { ind.r, ind.g, ind.b, anim.alpha }
            end

            if (ind.text=='A' or ind.text=='B') and ind.r==252 and ind.g==243 and ind.b==105 and type(planting_started_at)=='number' then
                local w, h = renderer.measure_text('d+', ind.text)
                local r    = math.ceil(h * .33)
                local cx   = base_x + w + r + 5
                local cy   = anim.offset - 5 + r * 2
                local pct  = (globals.curtime() - planting_started_at) / 3.125
                renderer.circle_outline(cx, cy, 0,0,0,210,   r,   0,1,5)
                renderer.circle_outline(cx, cy,200,200,200,255, r-1, 0,pct,3)
            end
        end

        if ping_idx and ping_col and ping_val then
            local w, _          = renderer.measure_text('d+', 'PING')
            local bar_w, bar_h  = w, 3
            local bar_x         = base_x + 1
            local bar_y         = indicator_animations[side_indicators[ping_idx].text].offset + indicator_heights[ping_idx] - 2
            local res           = entity.get_player_resource(entity.get_local_player())
            local cur           = res and entity.get_prop(res, 'm_iPing', entity.get_local_player()) or 0
            local pct           = math.min(cur / ping_val, 1)
            local fill          = lerp('ping_bar_fill', pct, 16, 0.01, 'ease_out')
            local alpha         = indicator_animations[side_indicators[ping_idx].text].bar * ping_col[4]
            renderer.rectangle(bar_x,   bar_y, bar_w,   bar_h,   30,30,30, math.floor(alpha * .7))
            renderer.rectangle(bar_x-1, bar_y-1, bar_w+2, bar_h+2,   0,0,0, math.floor(alpha * .8))
            renderer.rectangle(bar_x,   bar_y, bar_w * fill, bar_h, ping_col[1], ping_col[2], ping_col[3], alpha)
        end

        if lc_ind and lc_idx and lc_col then
            local w, _          = renderer.measure_text('d+', 'LC')
            local bar_w, bar_h  = w, 3
            local bar_x         = base_x + 1
            local bar_y         = indicator_animations[side_indicators[lc_idx].text].offset + indicator_heights[lc_idx] - 2
            local charged       = (lc_col[1]==255 and lc_col[2]==255 and lc_col[3]==255)
            local unbroken      = (lc_col[1]==255 and lc_col[2]==0   and lc_col[3]==50)
            local vis           = (not unbroken or charged) and 1 or 0
            local a_bar         = lerp('lc_bar_alpha', vis, 16, 0.01, 'ease_out')
            local alpha         = indicator_animations[side_indicators[lc_idx].text].bar * lc_col[4] * a_bar
            local tgt           = charged and 1 or 0
            local fill_pct      = lerp('lc_bar_fill', tgt, 16, 0.01, 'ease_out')
            if alpha > 1 then
                renderer.rectangle(bar_x,   bar_y, bar_w,   bar_h,   30,30,30, math.floor(alpha * .7))
                renderer.rectangle(bar_x-1, bar_y-1, bar_w+2, bar_h+2,   0,0,0, math.floor(alpha * .8))
                renderer.rectangle(bar_x,   bar_y, bar_w * fill_pct, bar_h, lc_col[1], lc_col[2], lc_col[3], alpha)
            end
        end

        for i, ind in ipairs(side_indicators) do
            if ind.text and ind.text:lower() == 'dt' then
                local anim  = indicator_animations[ind.text]
                local w, h  = renderer.measure_text('d+', 'DT')
                local x     = base_x + 15 + w
                local y     = anim.offset + indicator_heights[i] / 2
                local r     = math.ceil(h * .33)
                local pct   = (ind.r==255 and ind.g==255 and ind.b==255) and 1 or 0
                local fill  = lerp('dt_fill', pct, 16, 0.01, 'ease_out')
                local alpha = lerp('dt_alpha', pct == 1 and 0 or 1, 16, 0.01, 'ease_out') * anim.alpha
            
                if alpha > 1 then
                    renderer.circle_outline(x, y, 0, 0, 0, math.floor(alpha * .99), r, 0, 1, 5)
                    renderer.circle_outline(x, y, 255, 255, 255, alpha, r-1, 0, fill, 3)
                end
            end
        end

        for key, anim in pairs(indicator_animations) do
            if not indicator_present[key] then
                anim.alpha = lerp('indicator_alpha_'..key, 0, 16, 0.01, 'ease_out')
                if anim.alpha <= 1 then
                    indicator_animations[key] = nil
                end
            end
        end
    end

    elements.visuals.side_indicators:set_event('indicator', on_indicator)
    elements.visuals.side_indicators:set_event('bomb_beginplant', on_bomb_beginplant)
    elements.visuals.side_indicators:set_event('paint', on_paint)
    -- client.set_event_callback('indicator', on_indicator)
    -- client.set_event_callback('bomb_beginplant', on_bomb_beginplant)
    -- client.set_event_callback('paint', on_paint)
end

local damage_indicator = { width = 21, height = 12 }; do
    local drag = drag_system.new(
        'damage_indicator',
        drag_slider.damage_indicator.x,
        drag_slider.damage_indicator.y,
        screen_size_x() / 2 + 5, screen_size_y() / 2 - 10,
        'xy',
        {
            w = function () return damage_indicator.width end,
            h = function () return damage_indicator.height end,
            align_x = 'left',
            snap_distance = 5,
            show_guides = true,
            show_default_dot = true,
            show_highlight = true,
            align_center = false,
            show_center_dot = false
        }
    )

    local function on_paint_ui ()
        local disable = false
        local menu_open = ui.is_menu_open()
        local me = entity.get_local_player()
        if not menu_open and (not me or not entity.is_alive(me)) then
            disable = true
        end
        
        local enabled = elements.visuals.damage.enable:get()
        local alpha = lerp('damage_indicator_alpha', enabled and not disable and 255 or 0, 10, 0.001, 'ease_out')
        if alpha < 1 then return end

        drag:update(alpha)
        drag:draw_guides(alpha)
        local x, y = drag:get_pos()

        local flag = ''
        if elements.visuals.damage.settings.font:get() == 'Bold' then
            flag = 'b'
        elseif elements.visuals.damage.settings.font:get() == 'Small' then
            flag = '-'
        end

        local hotkey_ref = reference.rage.aimbot.minimum_damage_override[1].value and reference.rage.aimbot.minimum_damage_override[1].hotkey:get()
        local value_animate = math.ceil(lerp('damage_indicator_value', hotkey_ref and reference.rage.aimbot.minimum_damage_override[2].value - .1 or reference.rage.aimbot.minimum_damage.value, 4, 0.1, 'ease_out'))
        local hotkey_alpha = lerp('damage_indicator_hotkey_alpha', (menu_open or hotkey_ref) and 1 or 0, 10, 0.001, 'ease_out')

        local measure_damage_w, measure_damage_h = renderer.measure_text(flag, value_animate)
        damage_indicator.width, damage_indicator.height = measure_damage_w + 3, measure_damage_h

        renderer.text(x + 1, y - 1, 255, 255, 255, elements.visuals.damage.settings.type:get() == 'On hotkey' and alpha * hotkey_alpha or alpha, flag, nil, value_animate)
    end

    -- client.set_event_callback('paint_ui', on_paint_ui)
    elements.visuals.damage.enable:set_event('paint_ui', on_paint_ui)
end

---

local advert = { width = 100, height = 20 }; do
    local drag = drag_system.new(
        'advert_watermark',
        drag_slider.advert.x,
        drag_slider.advert.y,
        15, screen_size_y() / 2 - 10,
        'xy',
        {
            w = function () return advert.width end,
            h = function () return advert.height end,
            align_x = 'left',
            snap_distance = 10,
            show_guides = true,
            show_default_dot = true,
            show_highlight = true,
            align_center = true,
            show_center_dot = true
        }
    )

    local alpha = { value = 255 }
    local last_toggle_time = 0
    local toggle_debounce = 0.3
    local hint_alpha = 0
    local rainbow_offset = 0

    local flag_map = { Default = '', Bold = 'b', Small = '-' }
    local styles = {'Default', 'Bold', 'Small'}
    local function get_next_style (current)
        for i, style in ipairs(styles) do
            if style == current then
                return styles[(i % #styles) + 1]
            end
        end
        return styles[1]
    end

    local function get_flag ()
        return flag_map[drag_slider.advert.text_style:get()]
    end

    local function format_text (flag, text)
        if flag == '-' then
            return text:upper()
        end
        return text
    end

    local function hsv_to_rgb(h, s, v)
        local r, g, b
        local i = math.floor(h * 6)
        local f = h * 6 - i
        local p = v * (1 - s)
        local q = v * (1 - f * s)
        local t = v * (1 - (1 - f) * s)
        i = i % 6
        if i == 0 then r, g, b = v, t, p
        elseif i == 1 then r, g, b = q, v, p
        elseif i == 2 then r, g, b = p, v, t
        elseif i == 3 then r, g, b = p, q, v
        elseif i == 4 then r, g, b = t, p, v
        elseif i == 5 then r, g, b = v, p, q
        end
        return math.floor(r * 255), math.floor(g * 255), math.floor(b * 255)
    end

    local function on_paint_ui ()
        local settings = elements.visuals.watermark.settings
        local text_flag = get_flag()
        
        local custom_text = settings.text:get()
        if not custom_text or custom_text == '' then
            custom_text = 'Lunaris Source'
        end
        
        local formatted_text = format_text(text_flag, custom_text)
        local width = renderer.measure_text(text_flag, formatted_text) + 8
        advert.width = text_flag == '-' and width - 1 or width

        alpha.value = lerp('advert_watermark', elements.visuals.windows:get('Watermark') and 255 or 0, 10, 0.001, 'ease_out')
        if alpha.value == 0 then
            return
        end

        local menu_opened = ui.is_menu_open()
        local current_time = globals.realtime()
        local is_rmb_pressed = client.key_state(0x02)
        local x, y = drag:get_pos()
        local mx, my = ui.mouse_position()
        local elem_w, elem_h = advert.width, advert.height
        local is_hovered = mx >= x and mx <= x + elem_w and my >= y and my <= y + elem_h

        if menu_opened and is_rmb_pressed and is_hovered and current_time - last_toggle_time >= toggle_debounce then
            local next_style = get_next_style(drag_slider.advert.text_style:get())
            drag_slider.advert.text_style:set(next_style)
            last_toggle_time = current_time
        end

        drag:update(alpha.value)
        drag:draw_guides(alpha.value)

        hint_alpha = lerp('hint_alpha', (menu_opened and is_hovered and not drag.dragging and 255 or 0) * alpha.value / 255, 10, 0.001, 'ease_out')
        if hint_alpha > 1 then
            local formatted_text_2 = format_text(text_flag, 'Right-click to change text flag')
            local text_x = text_flag == '-' and x + advert.width / 2 - 1 or x + advert.width / 2
            renderer.text(text_x, y + advert.height + 6, 255, 255, 255, hint_alpha, text_flag .. 'c', nil, formatted_text_2)
        end

        local text_x = text_flag == '-' and x + 2 or x + 4
        local color_mode = settings.color_mode:get()
        local r, g, b = 255, 255, 255
        
        if color_mode == 'Static' then
            r, g, b = settings.color:get()
            renderer.text(text_x, y + 4, r, g, b, alpha.value, text_flag, nil, formatted_text)
        elseif color_mode == 'Gradient' then
            local r1, g1, b1 = settings.color:get()
            local r2, g2, b2 = settings.color_2:get()
            local text_len = #formatted_text
            local speed = settings.gradient_speed:get()
            local time = globals.realtime() * speed * 0.1

            local gradient_parts = { '' }
            for i = 1, text_len do
                local char = formatted_text:sub(i, i)
                local offset = (i - 1) / math.max(text_len - 1, 1)
                local t = (math.sin(time + offset * math.pi * 2) + 1) * 0.5
                local r_c = math.floor(r1 + (r2 - r1) * t)
                local g_c = math.floor(g1 + (g2 - g1) * t)
                local b_c = math.floor(b1 + (b2 - b1) * t)
                local hex = coloring.rgba_to_hex(r_c, g_c, b_c, alpha.value)
                gradient_parts[#gradient_parts + 1] = '\a'
                gradient_parts[#gradient_parts + 1] = hex
                gradient_parts[#gradient_parts + 1] = char
            end
            renderer.text(text_x, y + 4, 255, 255, 255, alpha.value, text_flag, nil, table.concat(gradient_parts))
        elseif color_mode == 'Rainbow' then
            local speed = settings.rainbow_speed:get()
            rainbow_offset = rainbow_offset + globals.frametime() * speed * 0.1
            if rainbow_offset > 1 then rainbow_offset = 0 end
            r, g, b = hsv_to_rgb(rainbow_offset, 1, 1)
            renderer.text(text_x, y + 4, r, g, b, alpha.value, text_flag, nil, formatted_text)
        end
    end

    client.set_event_callback('paint_ui', on_paint_ui)
end

local crosshair = { width = 62, height = 50 }; do
    local drag_c = drag_system.new(
        'crosshair',
        nil,
        drag_slider.crosshair.y,
        screen_size_x() / 2, screen_size_y() / 2 + 40,
        'y',
        {
            w = function() return crosshair.width end,
            h = function() return crosshair.height end,
            align_y = 'center',
            snap_distance = 10,
            show_guides = true,
            show_default_dot = true,
            show_highlight = true,
            align_center = true,
            show_center_dot = true
        }
    )

    local alpha = {
        value = 0,
        unique = 0,
        simple = 0
    }

    local function get_exploit_text (exploit_type)
        local states = {
            dt = {
                default = {'dt', {255, 255, 255}},
                defensive = {'dt defensive', {67, 245, 255}},
                recharge = {'dt recharge', {255, 62, 62}},
                active = {'dt active', {50, 255, 50}}
            },
            hs = {
                default = {'hs', {255, 255, 255}},
                defensive = {'hs defensive', {67, 245, 255}},
                recharge = {'hs recharge', {255, 62, 62}},
                active = {'hs active', {50, 255, 50}}
            }
        }
        
        local exploit_states = states[exploit_type]
        if not exploit_states then return nil end

        local is_active = (exploit_type == 'dt' and exploits:is_doubletap()) or (exploit_type == 'hs' and exploits:is_hideshots() and not exploits:is_doubletap())
        
        if is_active then
            if exploits:in_defensive() then
                return exploit_states.defensive
            elseif exploits:in_recharge() or ((exploit_type == 'dt' and exploits:is_doubletap()) and not exploits:can_recharge()) then
                return exploit_states.recharge
            else
                return exploit_states.active
            end
        end

        return exploit_states.default
    end

    local function get_current_state ()
        local state = string.lower(builder.get_state())
        
        if reference.antiaim.fakelag.enabled:get() and fakelag.active then
            state = 'fake lag'
        elseif reference.antiaim.angles.freestanding[1]:get() and reference.antiaim.angles.freestanding[1].hotkey:get() then
            state = 'freestanding'
        end
        
        return state
    end

    local function get_binds ()
        local doubletap_state = get_exploit_text('dt')
        local hideshots_state = get_exploit_text('hs')
        
        return {
            {name = 'dt', display = doubletap_state[1], color = doubletap_state[2], ref = exploits:is_doubletap()},
            {name = 'hs', display = hideshots_state[1], color = hideshots_state[2], ref = exploits:is_hideshots() and not exploits:is_doubletap()},
            {name = 'baim', display = 'baim', color = {255, 255, 255}, ref = reference.rage.aimbot.force_body:get()},
            {name = 'safe', display = 'safe', color = {255, 255, 255}, ref = reference.rage.aimbot.force_safe:get()}
        }
    end

    local function get_simple_binds ()
        return {
            {name = 'dt', display = 'dt', color = {255, 255, 255}, ref = exploits:is_doubletap()},
            {name = 'osaa', display = 'osaa', color = {255, 255, 255}, ref = exploits:is_hideshots() and not exploits:is_doubletap()},
            {name = 'baim', display = 'baim', color = {255, 255, 255}, ref = reference.rage.aimbot.force_body:get()},
            {name = 'safe', display = 'safe', color = {255, 255, 255}, ref = reference.rage.aimbot.force_safe:get()}
        }
    end


    local function render_gradient_text (x, y, flag, max_width, text, size, color1, color2, color3, color4)
        draw_gradient_text(
            x, y, flag, max_width, text, size,
            color1, color2, color3, color4
        )
    end

    local function render_bind_text (center_x, y, bind, scope_value, settings_y, alpha_unique, alpha_value, binds_alpha)
        local _bind_alpha = lerp('crosshair_bind_alpha_' .. bind.name, bind.ref and 1 or 0, 10, 0.001, 'ease_out')
        local _bind_y = lerp('crosshair_bind_y_' .. bind.name, bind.ref and 12 or 0, 12, 0.07, 'ease_out')
        local measure_binds = renderer.measure_text('cb', bind.display) / 2 + 3
        local target_width = renderer.measure_text('cb', bind.display) + 1
        local animated_binds = lerp('crosshair_bind_anim' .. bind.name, bind.ref and target_width or 0, 11, 0.5, 'ease_out')
        
        if bind.name == 'dt' or bind.name == 'hs' then
            local base_text = bind.name
            local state_text = bind.display:sub(#base_text + 1)
            local base_width = renderer.measure_text('cb', base_text)
            local state_width = renderer.measure_text('cb', state_text)
            
            renderer.text(
                center_x - state_width / 2 + 1 + (measure_binds - 1) * scope_value, 
                y + _bind_y + 14 + settings_y, 
                255, 255, 255, 
                alpha_unique * alpha_value / 255 * binds_alpha * _bind_alpha, 
                'cb', nil, base_text
            )
            
            if #state_text > 0 then
                local animated_binds_2 = lerp('crosshair_bind2_anim' .. bind.name, bind.ref and state_width + 1 or 0, 11, 0.5, 'ease_out')
                renderer.text(
                    center_x + base_width / 2 + measure_binds * scope_value, 
                    y + _bind_y + 14 + settings_y, 
                    bind.color[1], bind.color[2], bind.color[3], 
                    alpha_unique * alpha_value / 255 * binds_alpha * _bind_alpha, 
                    'cb', animated_binds_2, state_text
                )
            end
        else
            renderer.text(
                center_x + measure_binds * scope_value, 
                y + _bind_y + 14 + settings_y, 
                bind.color[1], bind.color[2], bind.color[3], 
                alpha_unique * alpha_value / 255 * binds_alpha * _bind_alpha, 
                'cb', animated_binds, bind.display
            )
        end
        
        return _bind_y
    end

    local function render_simple_bind (center_x, y, bind, scope_value, start_y, alpha_simple, alpha_value, binds_alpha)
        local _bind_alpha = lerp('crosshair_bind_alpha_simple_' .. bind.name, bind.ref and 1 or 0, 10, 0.001, 'ease_out')
        local target_width, target_height = renderer.measure_text('c-', bind.display:upper())
        local animated_width = lerp('crosshair_bind_anim_simple_' .. bind.name, bind.ref and target_width + 1 or 0, 11, 0.5, 'ease_out')
        local animated_height = lerp('crosshair_height_anim_simple_' .. bind.name, bind.ref and target_height + 1 or 0, 11, 0.5, 'ease_out')
        local measure_binds = renderer.measure_text('c-', bind.display:upper()) / 2 + 3

        renderer.text(
            center_x + measure_binds * scope_value, 
            y + start_y, 
            bind.color[1], bind.color[2], bind.color[3], 
            alpha_simple * alpha_value / 255 * binds_alpha * _bind_alpha, 
            'c-', animated_width, bind.display:upper()
        )
        
        return animated_height
    end

    local function render_unique_crosshair (center_x, y, custom, scope_value, alpha_value, alpha_unique, states_alpha, binds_alpha)
        local measure_name = renderer.measure_text('cb', lua.name:lower()) / 2 + 3
        
        if colors.combobox:get() == 'Custom' and colors.custom.type:get() == 'Gradient' and colors.custom.select:get('Crosshair') then
            render_gradient_text(
                center_x + measure_name * scope_value,
                y + 14,
                'cb', nil, lua.name:lower(), 25,
                {r = custom.r, g = custom.g, b = custom.b, a = alpha_unique * alpha_value / 255},
                {r = custom.r3, g = custom.g3, b = custom.b3, a = alpha_unique * alpha_value / 255},
                {r = custom.r4, g = custom.g4, b = custom.b4, a = alpha_unique * alpha_value / 255},
                {r = custom.r2, g = custom.g2, b = custom.b2, a = alpha_unique * alpha_value / 255}
            )
        else
            renderer.text(
                center_x + measure_name * scope_value, 
                y + 14, 
                custom.r, custom.g, custom.b, 
                alpha_unique * alpha_value / 255, 
                'cb', nil, lua.name:lower()
            )
        end

        local settings_add_y = states_alpha > 0 and 12 or 1

        if states_alpha > 0 then
            local state = get_current_state()
            local measure_state = renderer.measure_text('rb', state) / 2 + 3
            local animated_state = lerp('crosshair_state', renderer.measure_text('rb', state) + 1, 7, 1, 'ease_out')
            
            renderer.text(
                center_x + (animated_state / 2) + measure_state * scope_value, 
                y + 20, 
                255, 255, 255, 
                alpha_unique * alpha_value / 255 * states_alpha, 
                'rb', animated_state, state
            )
        end

        if binds_alpha > 0 then
            local binds = get_binds()
            local height = 0
            
            for _, bind in ipairs(binds) do
                height = height + render_bind_text(
                    center_x, y + height, bind, scope_value, 
                    settings_add_y, alpha_unique, alpha_value, binds_alpha
                )
            end
        end
    end

    local function render_simple_crosshair (center_x, y, custom, scope_value, inverted_scope_value, alpha_value, alpha_simple, states_alpha, binds_alpha)
        local measure_name = renderer.measure_text('c', lua.name:lower()) / 2 + 3
        local measure_build = renderer.measure_text('c-', lua.build:upper()) / 2 + 3
        
        if colors.combobox:get() == 'Custom' and colors.custom.type:get() == 'Gradient' and colors.custom.select:get('Crosshair') then
            render_gradient_text(
                center_x + measure_name * scope_value,
                y + 16,
                'c', nil, lua.name:lower(), 25,
                {r = custom.r, g = custom.g, b = custom.b, a = alpha_simple * alpha_value / 255},
                {r = custom.r3, g = custom.g3, b = custom.b3, a = alpha_simple * alpha_value / 255},
                {r = custom.r4, g = custom.g4, b = custom.b4, a = alpha_simple * alpha_value / 255},
                {r = custom.r2, g = custom.g2, b = custom.b2, a = alpha_simple * alpha_value / 255}
            )
            
            render_gradient_text(
                center_x + measure_build * scope_value,
                y + 6,
                'c-', nil, lua.build:upper(), 25,
                {r = custom.r, g = custom.g, b = custom.b, a = alpha_simple * alpha_value / 255 * inverted_scope_value},
                {r = custom.r3, g = custom.g3, b = custom.b3, a = alpha_simple * alpha_value / 255 * inverted_scope_value},
                {r = custom.r4, g = custom.g4, b = custom.b4, a = alpha_simple * alpha_value / 255 * inverted_scope_value},
                {r = custom.r2, g = custom.g2, b = custom.b2, a = alpha_simple * alpha_value / 255 * inverted_scope_value}
            )
        else
            renderer.text(
                center_x + measure_name * scope_value, 
                y + 16, 
                custom.r, custom.g, custom.b, 
                alpha_simple * alpha_value / 255, 
                'c', nil, lua.name:lower()
            )
            
            renderer.text(
                center_x + measure_build * scope_value, 
                y + 6, 
                custom.r, custom.g, custom.b, 
                alpha_simple * alpha_value / 255 * inverted_scope_value, 
                'c-', nil, lua.build:upper()
            )
        end

        if states_alpha > 0 then
            local state = string.upper(get_current_state())
            local measure_state = renderer.measure_text('r-', state) / 2 + 3
            local animated_state = lerp('crosshair_state_2', renderer.measure_text('r-', state) + 1, 7, 1, 'ease_out')
            
            renderer.text(
                center_x + (animated_state / 2) + measure_state * scope_value, 
                y + 23, 255, 255, 255, 
                alpha_simple * alpha_value / 255 * states_alpha, 
                'r-', animated_state, state
            )
        end

        if binds_alpha > 0 then
            local binds = get_simple_binds()
            local binds_start_y = states_alpha > 0 and 39 or 28
            local height = 0
            
            for _, bind in ipairs(binds) do
                local bind_height = render_simple_bind(
                    center_x, y, bind, scope_value, 
                    binds_start_y + height, alpha_simple, alpha_value, binds_alpha
                )
                height = height + bind_height
            end
        end
    end

    local function on_paint()
        local me = entity.get_local_player()
        alpha.value = lerp('crosshair_global', (elements.visuals.crosshair.enable:get() and entity.is_alive(me)) and 255 or 0, 10, 0.001, 'ease_out')

        if alpha.value == 0 then return end

        drag_c:update(alpha.value)
        drag_c:draw_guides(alpha.value)
        
        local x, y = drag_c:get_pos()
        local screen_x, screen_y = client.screen_size()
        local center_x = screen_x / 2
        local is_scoped = entity.get_prop(me, 'm_bIsScoped') == 1
        local custom = coloring.parse()

        local scope_value = lerp('crosshair_scope', is_scoped and 1 or 0, 10, 0.008, 'ease_out')
        local inverted_scope_value = lerp('crosshair_inv_scope', is_scoped and 0 or 1, 10, 0.008, 'ease_out')
        local states_alpha = lerp('crosshair_state_global', elements.visuals.crosshair.settings.select:get('States') and 1 or 0, 10, 0.001, 'ease_out')
        local binds_alpha = lerp('crosshair_binds_global', elements.visuals.crosshair.settings.select:get('Binds') and 1 or 0, 10, 0.001, 'ease_out')

        alpha.unique = lerp('crosshair_unique', (elements.visuals.crosshair.settings.type:get() == 'Unique') and 255 or 0, 10, 0.001, 'ease_out')
        alpha.unique = math.ceil(alpha.unique)
        
        if alpha.unique > 0 then
            render_unique_crosshair(center_x, y, custom, scope_value, alpha.value, alpha.unique, states_alpha, binds_alpha)
        end

        alpha.simple = lerp('crosshair_simple', (elements.visuals.crosshair.settings.type:get() == 'Simple') and 255 or 0, 10, 0.001, 'ease_out')
        alpha.simple = math.ceil(alpha.simple)
        
        if alpha.simple > 0 then
            render_simple_crosshair(center_x, y, custom, scope_value, inverted_scope_value, alpha.value, alpha.simple, states_alpha, binds_alpha)
        end
    end

    -- client.set_event_callback('paint', on_paint)
    elements.visuals.crosshair.enable:set_event('paint', on_paint)
end

local arrows do
    local drag_a = drag_system.new(
        'arrows',
        drag_slider.arrows.x,
        nil,
        screen_size_x() / 2 + 50, screen_size_y() / 2,
        'x',
        {
            w = 20,
            h = 20,
            align_x = 'center',
            snap_distance = 10,
            show_guides = true,
            show_default_dot = true,
            show_highlight = true,
            align_center = false,
            show_center_dot = false
        }
    )

    local alpha = {
        value = 0, unique = 0, simple = 0, teamskeet = 0, semicircle = 0,
        outline_start_angle = 0, outline_end_angle = 0, sc_arc_start_angle = 0,
        semicircle_back = 0, semicircle_back_timer = 0, semicircle_back_timeout = 0,
        semicircle_fade = 1, semicircle_fade_timer = 0
    }

    local function draw_arc(x, y, r, g, b, a, radius, start, end_, percent, thickness)
        if a == 0 or percent == 0 then return end
        percent = percent or 1
        thickness = thickness or 3
        local segments = math.max(16, math.floor(64 * math.abs(end_ - start) * percent + 0.5))
        local angle_span = (end_ - start) * 2 * math.pi * percent
        local angle_step = angle_span / segments
        local base_angle = start * 2 * math.pi

        for i = 0, segments - 1 do
            local angle1 = base_angle + i * angle_step
            local angle2 = base_angle + (i + 1) * angle_step

            local x1 = x + math.cos(angle1) * radius
            local y1 = y + math.sin(angle1) * radius
            local x2 = x + math.cos(angle2) * radius
            local y2 = y + math.sin(angle2) * radius

            local x3 = x + math.cos(angle2) * (radius - thickness)
            local y3 = y + math.sin(angle2) * (radius - thickness)
            local x4 = x + math.cos(angle1) * (radius - thickness)
            local y4 = y + math.sin(angle1) * (radius - thickness)

            renderer.triangle(x1, y1, x2, y2, x3, y3, r, g, b, a)
            renderer.triangle(x1, y1, x3, y3, x4, y4, r, g, b, a)
        end
    end

    local function draw_semicircle_indicator(params)
        local cx, cy = params.cx, params.cy
        local color = params.color
        local alpha_val = params.alpha
        local indicator_radius = params.indicator_radius
        local indicator_thickness = params.indicator_thickness
        local crosshair_enabled = params.crosshair_enabled
        local state = params.state
        local hide_on_third = params.hide_on_third
        local scope_animation_2 = params.scope_animation_2
        local scope_animation_3 = params.scope_animation_3

        local manual_left_active = (state == 'Manual left')
        local manual_right_active = (state == 'Manual right')
        local show_back = not manual_left_active and not manual_right_active

        if show_back then
            if alpha.semicircle_fade_timer == 0 then
                alpha.semicircle_fade_timer = globals.realtime()
            end
            local elapsed = globals.realtime() - alpha.semicircle_fade_timer
            if elapsed > 1 then
                alpha.semicircle_fade = lerp('semicircle_fade', 0, 10, 0.01, 'ease_out')
            else
                alpha.semicircle_fade = lerp('semicircle_fade', 1, 10, 0.01, 'ease_out')
            end
        else
            alpha.semicircle_fade_timer = 0
            alpha.semicircle_fade = lerp('semicircle_fade', 1, 10, 0.01, 'ease_out')
        end

        if alpha.semicircle_fade < 0.01 then
            return
        end

        local semicircle_outline_alpha = scope_animation_2 * hide_on_third * alpha_val * alpha.semicircle_fade
        local target_outline_start_angle = crosshair_enabled and 0.5 or 0.0
        local target_outline_end_angle = crosshair_enabled and 1.0 or 0.5

        alpha.outline_start_angle = lerp('outline_start_angle', target_outline_start_angle, 14, 0.002, 'linear')
        alpha.outline_end_angle = lerp('outline_end_angle', target_outline_end_angle, 14, 0.002, 'linear')

        -- renderer.circle_outline(cx, cy, 0, 0, 0, semicircle_outline_alpha, indicator_radius + 1, 0, 0.5, indicator_thickness + 2)
        draw_arc(cx, cy, 0, 0, 0, semicircle_outline_alpha, indicator_radius + 1, alpha.outline_start_angle, alpha.outline_end_angle, 1, indicator_thickness + 2)

        if show_back then
            if alpha.semicircle_back < 1 then
                alpha.semicircle_back = lerp('semicircle_back_alpha', 1, 10, 0.01, 'ease_out')
            end
            if alpha.semicircle_back_timer == 0 then
                alpha.semicircle_back_timer = globals.realtime()
            end
            if globals.realtime() - alpha.semicircle_back_timer > 3 then
                alpha.semicircle_back = lerp('semicircle_back_alpha', 0, 10, 0.01, 'ease_out')
            end
        else
            alpha.semicircle_back_timer = 0
            alpha.semicircle_back = lerp('semicircle_back_alpha', 0, 10, 0.01, 'ease_out')
        end

        local arc_alpha = scope_animation_3 * hide_on_third * alpha_val * alpha.semicircle_fade * (manual_left_active and 1 or manual_right_active and 1 or alpha.semicircle_back)
        if arc_alpha > 0 then
            local arc_span = 0.15
            local target_arc_start_angle
            if manual_left_active then
                target_arc_start_angle = crosshair_enabled and 0.505 or 0.34
            elseif manual_right_active then
                target_arc_start_angle = crosshair_enabled and 0.845 or 0.01
            else
                target_arc_start_angle = crosshair_enabled and 0.675 or 0.179
            end
            alpha.sc_arc_start_angle = lerp('sc_arc_start_angle', target_arc_start_angle, 16, 0.002, 'linear')
            local draw_start_angle = alpha.sc_arc_start_angle
            local draw_end_angle = draw_start_angle + arc_span
            draw_arc(cx, cy, color.r, color.g, color.b, arc_alpha, indicator_radius, draw_start_angle, draw_end_angle, 1, indicator_thickness)
        end
    end

    local function on_paint()
        local me = entity.get_local_player()
        alpha.value = lerp('arrows_global', (elements.visuals.arrows.enable:get() and entity.is_alive(me)) and 255 or 0, 10, 0.001, 'ease_out')
        if alpha.value == 0 then return end

        local screen_x, screen_y = client.screen_size()
        if elements.visuals.arrows.settings.type:get() == 'Pointers' then
            drag_a:update(alpha.value)
            drag_a:draw_guides(alpha.value)
        end
        local x, y = drag_a:get_pos()
        local is_scoped = entity.get_prop(me, 'm_bIsScoped') == 1
        local custom = coloring.parse()

        local state = builder.get_state()
        local left_alpha = lerp('arrows_left_alpha', (state == 'Manual left' or ui.is_menu_open()) and 1 or 0, 10, 0.001, 'ease_out')
        local right_alpha = lerp('arrows_right_alpha', (state == 'Manual right' or ui.is_menu_open()) and 1 or 0, 10, 0.001, 'ease_out')
        local scope_animation = lerp('arrows_scope', is_scoped and 1 or 0, 10, 0.008, 'ease_out')

        if elements.visuals.arrows.settings.type:get() == 'Pointers' then
            alpha.unique = lerp('arrows_unique', (elements.visuals.arrows.settings.style:get() == 'Unique') and 255 or 0, 10, 0.001, 'ease_out')
            alpha.unique = math.ceil(alpha.unique)
            if alpha.unique > 0 then
                if colors.combobox:get() == 'Custom' and colors.custom.type:get() == 'Gradient' and colors.custom.select:get('Arrows') then
                    local color = prepare_gradient_cache(25,
                        {r = custom.r, g = custom.g, b = custom.b, a = alpha.value},
                        {r = custom.r3, g = custom.g3, b = custom.b3, a = alpha.value},
                        {r = custom.r4, g = custom.g4, b = custom.b4, a = alpha.value},
                        {r = custom.r2, g = custom.g2, b = custom.b2, a = alpha.value},
                        false
                    )
                    renderer.text(screen_x - x - 14, screen_y / 2 - 4 - (12 * scope_animation), color.r, color.g, color.b, alpha.unique * alpha.value / 255 * left_alpha, 'c+', nil, '⮜')
                    renderer.text(x + 10, screen_y / 2 - 4 - (12 * scope_animation), color.r, color.g, color.b, alpha.unique * alpha.value / 255 * right_alpha, 'c+', nil, '⮞')
                else
                    renderer.text(screen_x - x - 14, screen_y / 2 - 4 - (12 * scope_animation), custom.r, custom.g, custom.b, alpha.unique * alpha.value / 255 * left_alpha, 'c+', nil, '⮜')
                    renderer.text(x + 10, screen_y / 2 - 4 - (12 * scope_animation), custom.r, custom.g, custom.b, alpha.unique * alpha.value / 255 * right_alpha, 'c+', nil, '⮞')
                end
            end
            alpha.simple = lerp('arrows_simple', (elements.visuals.arrows.settings.style:get() == 'Simple') and 255 or 0, 10, 0.001, 'ease_out')
            alpha.simple = math.ceil(alpha.simple)
            if alpha.simple > 0 then
                if colors.combobox:get() == 'Custom' and colors.custom.type:get() == 'Gradient' and colors.custom.select:get('Arrows') then
                    local color = prepare_gradient_cache(25,
                        {r = custom.r, g = custom.g, b = custom.b, a = alpha.value},
                        {r = custom.r3, g = custom.g3, b = custom.b3, a = alpha.value},
                        {r = custom.r4, g = custom.g4, b = custom.b4, a = alpha.value},
                        {r = custom.r2, g = custom.g2, b = custom.b2, a = alpha.value},
                        false
                    )
                    renderer.text(screen_x - x - 14, screen_y / 2 - 2 - (12 * scope_animation), color.r, color.g, color.b, alpha.simple * alpha.value / 255 * left_alpha, 'c+', nil, '<')
                    renderer.text(x + 10, screen_y / 2 - 2 - (12 * scope_animation), color.r, color.g, color.b, alpha.simple * alpha.value / 255 * right_alpha, 'c+', nil, '>')
                else
                    renderer.text(screen_x - x - 14, screen_y / 2 - 2 - (12 * scope_animation), custom.r, custom.g, custom.b, alpha.simple * alpha.value / 255 * left_alpha, 'c+', nil, '<')
                    renderer.text(x + 10, screen_y / 2 - 2 - (12 * scope_animation), custom.r, custom.g, custom.b, alpha.simple * alpha.value / 255 * right_alpha, 'c+', nil, '>')
                end
            end
            alpha.teamskeet = lerp('arrows_teamskeet', (elements.visuals.arrows.settings.style:get() == 'TeamSkeet') and 255 or 0, 10, 0.001, 'ease_out')
            alpha.teamskeet = math.ceil(alpha.teamskeet)
            if alpha.teamskeet > 0 then
                local final_alpha_left = alpha.teamskeet * alpha.value / 255 * left_alpha
                local final_alpha_right = alpha.teamskeet * alpha.value / 255 * right_alpha
                renderer.text(screen_x - x - 14, screen_y / 2 - 4 - (12 * scope_animation), 0, 0, 0, 55 * alpha.teamskeet / 255 * alpha.value / 255, 'c+', nil, '◀')
                renderer.text(x + 10, screen_y / 2 - 4 - (12 * scope_animation), 0, 0, 0, 55 * alpha.teamskeet / 255 * alpha.value / 255, 'c+', nil, '▶')
                if colors.combobox:get() == 'Custom' and colors.custom.type:get() == 'Gradient' and colors.custom.select:get('Arrows') then
                    local color = prepare_gradient_cache(25,
                        {r = custom.r, g = custom.g, b = custom.b, a = alpha.value},
                        {r = custom.r3, g = custom.g3, b = custom.b3, a = alpha.value},
                        {r = custom.r4, g = custom.g4, b = custom.b4, a = alpha.value},
                        {r = custom.r2, g = custom.g2, b = custom.b2, a = alpha.value},
                        false
                    )
                    renderer.text(screen_x - x - 14, screen_y / 2 - 4 - (12 * scope_animation), color.r, color.g, color.b, final_alpha_left, 'c+', nil, '◀')
                    renderer.text(x + 10, screen_y / 2 - 4 - (12 * scope_animation), color.r, color.g, color.b, final_alpha_right, 'c+', nil, '▶')
                else
                    renderer.text(screen_x - x - 14, screen_y / 2 - 4 - (12 * scope_animation), custom.r, custom.g, custom.b, final_alpha_left, 'c+', nil, '◀')
                    renderer.text(x + 10, screen_y / 2 - 4 - (12 * scope_animation), custom.r, custom.g, custom.b, final_alpha_right, 'c+', nil, '▶')
                end
            end
        else
            alpha.semicircle = lerp('arrows_semicircle', (elements.visuals.arrows.settings.type:get() == 'Semicircle') and 255 or 0, 10, 0.001, 'ease_out')
            alpha.semicircle = math.ceil(alpha.semicircle)
            if alpha.semicircle > 0 then
                local crosshair_enabled = elements.visuals.crosshair.enable:get()
                local sc_cx = screen_x / 2 + 1
                local sc_cy = screen_y / 2 + (crosshair_enabled and -2 or 2)
                local indicator_radius = 27
                local indicator_thickness = 3
                local scope_animation_2 = lerp('arrows_semicircle_2', is_scoped and 25 or 85, 10, 0.008, 'ease_out')
                local scope_animation_3 = lerp('arrows_semicircle_3', is_scoped and 100 or 255, 10, 0.008, 'ease_out')
                local hide_on_third = lerp('arrows_semicircle_hide', elements.visuals.arrows.settings.hide_on_thirdperson:get() and reference.visuals.thirdperson:get() and reference.visuals.thirdperson.hotkey:get() and 0 or 1, 10, 0.008, 'ease_out')
                local color = custom
                if colors.combobox:get() == 'Custom' and colors.custom.type:get() == 'Gradient' and colors.custom.select:get('Arrows') then
                    color = prepare_gradient_cache(25,
                        {r = custom.r, g = custom.g, b = custom.b, a = alpha.value},
                        {r = custom.r3, g = custom.g3, b = custom.b3, a = alpha.value},
                        {r = custom.r4, g = custom.g4, b = custom.b4, a = alpha.value},
                        {r = custom.r2, g = custom.g2, b = custom.b2, a = alpha.value},
                        false
                    )
                end
                draw_semicircle_indicator{
                    cx = sc_cx, cy = sc_cy, color = color, alpha = alpha.value / 255 * alpha.semicircle / 255,
                    indicator_radius = indicator_radius, indicator_thickness = indicator_thickness,
                    crosshair_enabled = crosshair_enabled, state = state,
                    hide_on_third = hide_on_third, scope_animation_2 = scope_animation_2, scope_animation_3 = scope_animation_3
                }
            end
        end
    end

    -- client.set_event_callback('paint', on_paint)
    elements.visuals.arrows.enable:set_event('paint', on_paint)
end

local scope do
    local on_paint_ui = function ()
        reference.visuals.scope:override(true)
    end

    elements.visuals.scope.enable:set_event('paint_ui', on_paint_ui)

    local function on_paint ()
        if not elements.visuals.scope.enable:get() then
            reference.visuals.scope:override()
            return
        end

        local me = entity.get_local_player()
        if not me or not entity.is_alive(me) then
            return
        end

        local weapon = entity.get_player_weapon(me)
        if weapon == nil then
            return
        end

        reference.visuals.scope:override(false)

        local scope_level = entity.get_prop(weapon, 'm_zoomLevel')
        local scoped = entity.get_prop(me, 'm_bIsScoped') == 1
        local resume_zoom = entity.get_prop(me, 'm_bResumeZoom') == 1
        local is_valid = scope_level ~= nil
        local act = is_valid and scope_level > 0 and scoped and not resume_zoom

        local alpha = lerp('custom_scope', act and 255 or 0, 4, 0.001, 'ease_out')
        local x, y = client.screen_size()
        local custom = coloring.parse()

        local gap = elements.visuals.scope.settings.gap:get()
        local length = elements.visuals.scope.settings.size:get()
        local inverted = elements.visuals.scope.settings.invert:get()

        local r, g, b = custom.r, custom.g, custom.b
        if colors.combobox:get() == 'Custom' and colors.custom.type:get() == 'Gradient' and colors.custom.select:get('Scope') then
            local color = prepare_gradient_cache(25,
                {r = custom.r, g = custom.g, b = custom.b, a = alpha},
                {r = custom.r3, g = custom.g3, b = custom.b3, a = alpha},
                {r = custom.r4, g = custom.g4, b = custom.b4, a = alpha},
                {r = custom.r2, g = custom.g2, b = custom.b2, a = alpha},
                false
            )

            r, g, b = color.r, color.g, color.b
        end

        x, y = x / 2, y / 2

        -- @lordmouse: left
        if not elements.visuals.scope.settings.exclude:get('Left') then
            renderer.gradient(x - gap, y, -length * (alpha / 255), 1, r, g, b, inverted and 0 or alpha, r, g, b, inverted and alpha or 0, true)
        end

        -- @lordmouse: right
        if not elements.visuals.scope.settings.exclude:get('Right') then
            renderer.gradient(x + gap, y, length * (alpha / 255), 1, r, g, b, inverted and 0 or alpha, r, g, b, inverted and alpha or 0, true)
        end

        -- @lordmouse: up
        if not elements.visuals.scope.settings.exclude:get('Top') then
            renderer.gradient(x, y - gap, 1, -length * (alpha / 255), r, g, b, inverted and 0 or alpha, r, g, b, inverted and alpha or 0, false)
        end

        -- @lordmouse: down
        if not elements.visuals.scope.settings.exclude:get('Bottom') then
            renderer.gradient(x, y + gap, 1, length * (alpha / 255), r, g, b, inverted and 0 or alpha, r, g, b, inverted and alpha or 0, false)
        end
    end

    -- client.set_event_callback('paint', on_paint)
    elements.visuals.scope.enable:set_event('paint', on_paint)
end

---

local zoom_animation do
    local function on_override_view (e)
        if not elements.visuals.zoom.enable:get() then
            reference.misc.miscellaneous.override_zoom_fov:override()
            return
        end

        reference.misc.miscellaneous.override_zoom_fov:override(0)

        local me = entity.get_local_player()
        if not me or not entity.is_alive(me) then
            return
        end

        local fov, speed = elements.visuals.zoom.settings.value:get(), elements.visuals.zoom.settings.speed:get()
        local is_scoped = entity.get_prop(me, 'm_bIsScoped') == 1

        local animate = lerp('zoom', is_scoped and fov or 0, speed / 10, 0.001, 'ease_out')
        e.fov = e.fov - animate
    end

    -- client.set_event_callback('override_view', on_override_view)
    elements.visuals.zoom.enable:set_event('override_view', on_override_view)
end

local aspect_ratio do
    local alpha = 0
    local function on_paint ()
        alpha = lerp('aspect_ratio_alpha', elements.visuals.aspect_ratio.enable:get() and 255 or 0, 16, 0.001, 'ease_out')
        if alpha == 0 then
            cvar.r_aspectratio:set_int(0)
            return
        end

        local x, y = client.screen_size()
        local init = x / y

        local value = elements.visuals.aspect_ratio.settings.value:get()
        local animate = lerp('aspect_ratio_animate', elements.visuals.aspect_ratio.enable:get() and value * .01 or init, 8, 0.001, 'ease_out')

        if animate == init then
            cvar.r_aspectratio:set_int(0)
            return
        end

        cvar.r_aspectratio:set_float(animate)
    end

    client.set_event_callback('paint', on_paint)
end

local viewmodel = { fov = 0, x = 0, y = 0, z = 0 }; do
    local alpha = 0
    local function on_paint ()
        alpha = lerp('viewmodel_alpha', elements.visuals.viewmodel.enable:get() and 255 or 0, 16, 0.001, 'ease_out')
        if alpha == 0 then
            return
        end

        if elements.visuals.viewmodel.enable:get() then
            viewmodel.fov = lerp('viewmodel_fov', elements.visuals.viewmodel.settings.fov:get(), 8, 0.001, 'ease_out')
            viewmodel.x = lerp('viewmodel_x', elements.visuals.viewmodel.settings.x:get() / 10, 8, 0.001, 'ease_out')
            viewmodel.y = lerp('viewmodel_y', elements.visuals.viewmodel.settings.y:get() / 10, 8, 0.001, 'ease_out')
            viewmodel.z = lerp('viewmodel_z', elements.visuals.viewmodel.settings.z:get() / 10, 8, 0.001, 'ease_out')
        else
            viewmodel.fov = lerp('viewmodel_fov', 68, 8, 0.001, 'ease_out')
            viewmodel.x = lerp('viewmodel_x', 2.5, 8, 0.001, 'ease_out')
            viewmodel.y = lerp('viewmodel_y', 0, 8, 0.001, 'ease_out')
            viewmodel.z = lerp('viewmodel_z', -1.5, 8, 0.001, 'ease_out')
        end
      
        -- if elements.visuals.viewmodel.enable:get() and elements.visuals.viewmodel.settings.additional:get('CS2 Hands In Scope') and entity.get_prop(entity.get_local_player(), 'm_bIsScoped') == 1 then
        --     viewmodel.x = lerp('viewmodel_x', -9, 8, 0.001, 'ease_out')
        --     viewmodel.y = lerp('viewmodel_y', -1, 8, 0.001, 'ease_out')
        --     viewmodel.z = lerp('viewmodel_z', -3.5, 8, 0.001, 'ease_out')
        -- end
      
        cvar.viewmodel_fov:set_raw_float(viewmodel.fov)
        cvar.viewmodel_offset_x:set_raw_float(viewmodel.x)
        cvar.viewmodel_offset_y:set_raw_float(viewmodel.y)
        cvar.viewmodel_offset_z:set_raw_float(viewmodel.z)
    end

    client.set_event_callback('paint', on_paint)
end

-- ============================================================
-- Auto Exposure (из uwu_hook)
-- ============================================================
local auto_exposure_state = {
    exposure_min_default = nil,
    exposure_max_default = nil,
    exposure_prev = nil
}

local function handle_auto_exposure()
    local exposure_enabled = elements.visuals.auto_exposure.enable:get()
    
    if exposure_enabled or auto_exposure_state.exposure_prev then
        local tone_map_controllers = entity.get_all("CEnvTonemapController")
        
        for i = 1, #tone_map_controllers do
            local tone_map_controller = tone_map_controllers[i]
            
            if exposure_enabled then
                if auto_exposure_state.exposure_min_default == nil then
                    if entity.get_prop(tone_map_controller, "m_bUseCustomAutoExposureMin") == 1 then
                        auto_exposure_state.exposure_min_default = entity.get_prop(tone_map_controller, "m_flCustomAutoExposureMin")
                    else
                        auto_exposure_state.exposure_min_default = -1
                    end
                    if entity.get_prop(tone_map_controller, "m_bUseCustomAutoExposureMax") == 1 then
                        auto_exposure_state.exposure_max_default = entity.get_prop(tone_map_controller, "m_flCustomAutoExposureMax")
                    else
                        auto_exposure_state.exposure_max_default = -1
                    end
                end
                
                local exposure_value = elements.visuals.auto_exposure.value:get()
                entity.set_prop(tone_map_controller, "m_bUseCustomAutoExposureMin", 1)
                entity.set_prop(tone_map_controller, "m_bUseCustomAutoExposureMax", 1)
                entity.set_prop(tone_map_controller, "m_flCustomAutoExposureMin", math.max(0.0000, exposure_value * 0.001))
                entity.set_prop(tone_map_controller, "m_flCustomAutoExposureMax", math.max(0.0000, exposure_value * 0.001))
            elseif auto_exposure_state.exposure_prev and auto_exposure_state.exposure_min_default ~= nil then
                if auto_exposure_state.exposure_min_default == -1 then
                    entity.set_prop(tone_map_controller, "m_bUseCustomAutoExposureMin", 0)
                    entity.set_prop(tone_map_controller, "m_flCustomAutoExposureMin", 0)
                else
                    entity.set_prop(tone_map_controller, "m_bUseCustomAutoExposureMin", 1)
                    entity.set_prop(tone_map_controller, "m_flCustomAutoExposureMin", auto_exposure_state.exposure_min_default)
                end
                if auto_exposure_state.exposure_max_default == -1 then
                    entity.set_prop(tone_map_controller, "m_bUseCustomAutoExposureMax", 0)
                    entity.set_prop(tone_map_controller, "m_flCustomAutoExposureMax", 0)
                else
                    entity.set_prop(tone_map_controller, "m_bUseCustomAutoExposureMax", 1)
                    entity.set_prop(tone_map_controller, "m_flCustomAutoExposureMax", auto_exposure_state.exposure_max_default)
                end
            end
        end
    end
    
    auto_exposure_state.exposure_prev = exposure_enabled
end

local function reset_auto_exposure()
    if auto_exposure_state.exposure_prev and auto_exposure_state.exposure_min_default ~= nil then
        local tone_map_controllers = entity.get_all("CEnvTonemapController")
        for i = 1, #tone_map_controllers do
            local tone_map_controller = tone_map_controllers[i]
            
            if auto_exposure_state.exposure_min_default == -1 then
                entity.set_prop(tone_map_controller, "m_bUseCustomAutoExposureMin", 0)
                entity.set_prop(tone_map_controller, "m_flCustomAutoExposureMin", 0)
            else
                entity.set_prop(tone_map_controller, "m_bUseCustomAutoExposureMin", 1)
                entity.set_prop(tone_map_controller, "m_flCustomAutoExposureMin", auto_exposure_state.exposure_min_default)
            end
            if auto_exposure_state.exposure_max_default == -1 then
                entity.set_prop(tone_map_controller, "m_bUseCustomAutoExposureMax", 0)
                entity.set_prop(tone_map_controller, "m_flCustomAutoExposureMax", 0)
            else
                entity.set_prop(tone_map_controller, "m_bUseCustomAutoExposureMax", 1)
                entity.set_prop(tone_map_controller, "m_flCustomAutoExposureMax", auto_exposure_state.exposure_max_default)
            end
        end
    end
end

client.set_event_callback('paint', handle_auto_exposure)
client.set_event_callback('shutdown', reset_auto_exposure)


local markers = { hits = { }, misses = { }, damages = { }, positions = { } }; do
    local function on_aim_fire (e)
        if not elements.visuals.markers.enable:get() then
            return
        end

        markers.positions[e.id] = { e.x, e.y, e.z }
    end
  
    local function on_aim_hit (e)
        if not elements.visuals.markers.enable:get() then
            return
        end

        local position = markers.positions[e.id]
        if position then
            table.insert(markers.hits, {
                time = globals.curtime(),
                position = position
            })

            markers.positions[e.id] = nil
        end
    end
  
    local function on_aim_miss (e)
        if not elements.visuals.markers.enable:get() then
            return
        end

        local position = markers.positions[e.id]
        if position then
            local red = { 255, 0, 50 }
            local yellow = { 255, 205, 0 }
            e.reason = e.reason == '?' and 'resolver' or e.reason
            
            table.insert(markers.misses, {
                time = globals.curtime(),
                position = position,
                reason = e.reason,
                color = (e.reason == 'spread' or e.reason == 'prediction error') and yellow or red
            })

            markers.positions[e.id] = nil
        end
    end
  
    local function on_player_hurt (e)
        if not elements.visuals.markers.enable:get() then
            return
        end

        local attacker = client.userid_to_entindex(e.attacker)
        local victim = client.userid_to_entindex(e.userid)
    
        if attacker == entity.get_local_player() and victim ~= attacker then
            table.insert(markers.damages, {
                time = globals.curtime(),
                position = { entity.get_prop(victim, 'm_vecOrigin') },
                damage = e.dmg_health,
                offset = 0 
            })
        end
    end
  
    local function on_paint ()
        if not elements.visuals.markers.enable:get() then
            return
        end

        if elements.visuals.markers.settings.type:get('On hit') then
            for i = #markers.hits, 1, -1 do
                local hit = markers.hits[i]
                local alpha = 255 - (globals.curtime() - hit.time) * 255 / 2
                if alpha > 0 then
                    local x, y = renderer.world_to_screen(hit.position[1], hit.position[2], hit.position[3])
                    if x and y then
                        local size = 4
                        renderer.line(x - size, y - size, x + size, y + size, 255, 255, 255, alpha)
                        renderer.line(x + size, y - size, x - size, y + size, 255, 255, 255, alpha)
                    end
                else
                    table.remove(markers.hits, i)
                end
            end
        end
      
        if elements.visuals.markers.settings.type:get('On miss') then
            for i = #markers.misses, 1, -1 do
                local miss = markers.misses[i]
                local alpha = 255 - (globals.curtime() - miss.time) * 255 / 2
                if alpha > 0 then
                    local x, y = renderer.world_to_screen(miss.position[1], miss.position[2], miss.position[3])
                    if x and y then
                        local size = 4
                        renderer.line(x - size, y - size, x + size, y + size, miss.color[1], miss.color[2], miss.color[3], alpha)
                        renderer.line(x + size, y - size, x - size, y + size, miss.color[1], miss.color[2], miss.color[3], alpha)
                        renderer.text(x + 10, y - 7, miss.color[1], miss.color[2], miss.color[3], alpha, 'b', 0, miss.reason)
                    end
                else
                    table.remove(markers.misses, i)
                end
            end
        end
    
        if elements.visuals.markers.settings.type:get('Damage') then
            for i = #markers.damages, 1, -1 do
                local damage = markers.damages[i]
                local alpha = 255 - (globals.curtime() - damage.time) * 255 / 2
                if alpha > 0 then
                    damage.offset = damage.offset + 0.2
                    local x, y = renderer.world_to_screen(damage.position[1], damage.position[2], damage.position[3] + damage.offset)
                    if x and y then
                        renderer.text(x, y, 255, 255, 255, alpha, 'cb', 0, '-' .. damage.damage)
                    end
                else
                    table.remove(markers.damages, i)
                end
            end
        end
    end

    local function reset ()
        if not elements.visuals.markers.enable:get() then
            return
        end

        markers = { hits = { }, misses = { }, damages = { }, positions = { } }
    end
    
    client.set_event_callback('aim_fire', on_aim_fire)
    client.set_event_callback('aim_hit', on_aim_hit)
    client.set_event_callback('player_hurt', on_player_hurt)
    client.set_event_callback('aim_miss', on_aim_miss)
    client.set_event_callback('paint', on_paint)
    client.set_event_callback('post_config_load', reset)
    client.set_event_callback('on_round_start', reset)
    client.set_event_callback('on_round_end', reset)
end

---

local enemy_chat_viewer do
    local last_chat_message = { }

    local function on_player_say (e)
        if not elements.misc.enemy_chat_viewer:get() then
            return
        end

        local sender = client.userid_to_entindex(e.userid)
        if not entity.is_enemy(sender) then 
            return 
        end

        if panorama.open().GameStateAPI.IsSelectedPlayerMuted(panorama.open().GameStateAPI.GetPlayerXuidStringFromEntIndex(sender)) then 
            return 
        end

        client.delay_call(0.2, function ()
            if last_chat_message[sender] ~= nil and math.abs(globals.realtime() - last_chat_message[sender]) < 0.4 then
                return
            end

            local enemy_team_name = entity.get_prop(entity.get_player_resource(), 'm_iTeam', sender) == 2 and 'T' or 'CT'

            local place_name = entity.get_prop(sender, 'm_szLastPlaceName')
            local enemy_name = entity.get_player_name(sender)
            
            local l = ('Cstrike_Chat_%s_%s'):format(enemy_team_name, entity.is_alive(sender) and 'Loc' or 'Dead')
            local msg = localize(l, {
                s1 = enemy_name,
                s2 = e.text,
                s3 = localize(place_name ~= '' and place_name or 'UI_Unknown')
            })

            chat.print_player(sender, msg)
        end)
    end

    local function on_player_chat (e)
        if not elements.misc.enemy_chat_viewer:get() and not entity.is_enemy(e.entity) then
            return
        end

        last_chat_message[e.entity] = globals.realtime()
    end

    client.set_event_callback('player_say', on_player_say)
    client.set_event_callback('player_chat', on_player_chat)
end

local edge_quick_stop do
    local function is_about_to_fall (player)
        local origin = vector(entity.get_origin(player))
        local vel = {entity.get_prop(player, 'm_vecVelocity')}
        local velocity = vector(vel[1] or 0, vel[2] or 0, 0)
        local speed = velocity:length2d()
        if speed < 5 then return false end

        local move_yaw = math.deg(math.atan2(velocity.y, velocity.x))
        local yaw_rad = math.rad(move_yaw)
        local forward = vector(math.cos(yaw_rad), math.sin(yaw_rad), 0)
        local check_dist = 18
        local down_dist = 36
        local min_drop = 16
        local offsets = {0, 10, -10}

        for _, side in ipairs(offsets) do
            local side_vec = vector(-math.sin(yaw_rad), math.cos(yaw_rad), 0) * side
            local check_pos = origin + forward * check_dist + side_vec
            local start_pos = vector(check_pos.x, check_pos.y, origin.z)
            local end_pos = vector(check_pos.x, check_pos.y, origin.z - down_dist)
            local fraction, ent_hit, end_x, end_y, end_z = client.trace_line(player, start_pos.x, start_pos.y, start_pos.z, end_pos.x, end_pos.y, end_pos.z)
            if fraction >= 0.99 then
                return true
            elseif fraction > 0 then
                local hit_z = start_pos.z - (down_dist * fraction)
                if (start_pos.z - hit_z) > min_drop then
                    return true
                end
            end
        end
        return false
    end

    local function on_setup_command (e)
        if not elements.misc.edge_quick_stop:get() or not elements.misc.edge_quick_stop.hotkey:get() then
            return
        end

        local player = entity.get_local_player()
        if not player or not entity.is_alive(player) then
            return
        end
        
        if not is_on_ground then return end

        local vel = {entity.get_prop(player, 'm_vecVelocity')}
        local velocity = vector(vel[1] or 0, vel[2] or 0, 0)

        if is_about_to_fall(player) then
            local move_yaw = math.deg(math.atan2(velocity.y, velocity.x))
            local move_dir = math.rad(move_yaw)
            local forwardmove = e.forwardmove or 0
            local sidemove = e.sidemove or 0
            local move_vec = vector(
                math.cos(move_dir) * forwardmove - math.sin(move_dir) * sidemove,
                math.sin(move_dir) * forwardmove + math.cos(move_dir) * sidemove,
                0
            )

            if move_vec:length2d() > 0 and (move_vec.x * velocity.x + move_vec.y * velocity.y) > 0 then
                e.forwardmove = 0
                e.sidemove = 0
            end
        end
    end

    client.set_event_callback('setup_command', on_setup_command)
end

local duck_peek_assist_fix do
    local hotkey_modes = {
        [0] = 'Always on',
        [1] = 'On hotkey',
        [2] = 'Toggle',
        [3] = 'Off hotkey'
    }

    local saved_hotkey = nil
    local is_altered = false

    local function extract_hotkey (ref)
        local data = { ref:get() }
        if ref:get_type() == 'hotkey' then
            return { hotkey_modes[data[2]] or 'Off hotkey', data[3] }
        end

        return data
    end

    local function on_setup_command (e)
        if not elements.misc.fd_fix:get() then
            return
        end

        local player = entity.get_local_player()
        if not player or not entity.is_alive(player) then
            return
        end

        local duck_active = e.in_duck == 1 and entity.get_prop(player, 'm_flDuckAmount') > 0.8
        local enabled, current_mode = reference.rage.other.fake_duck:get()

        if enabled == nil or current_mode == nil then
            return
        end

        if duck_active and enabled and not is_altered then
            saved_hotkey = extract_hotkey(reference.rage.other.fake_duck)
            local target_mode = (current_mode == 2 or current_mode == 3) and 'On hotkey' or 'Off hotkey'
            reference.rage.other.fake_duck:set(target_mode)
            is_altered = true
        elseif not duck_active and is_altered and saved_hotkey then
            reference.rage.other.fake_duck:set(table.unpack(saved_hotkey))
            saved_hotkey = nil
            is_altered = false
        end
    end

    client.set_event_callback('setup_command', on_setup_command)
end

local drop_nades do
    local nades_list = {
        ['HE Grenade'] = 'weapon_hegrenade',
        Molotov = 'weapon_molotov',
        Incendiary = 'weapon_incgrenade',
        Smoke = 'weapon_smokegrenade'
    }
    
    local key_click_cache = false

    local function on_paint ()
        if not elements.misc.drop_nades.enable:get() then
            return
        end
      
        local me = entity.get_local_player()
        if not me or not entity.is_alive(me) then
            return
        end
      
        local weapons = { }
        for i = 0, 64 do
            local weapon = entity.get_prop(me, 'm_hMyWeapons', i)
            if weapon and weapon ~= 0 then
                local weapon_name = entity.get_classname(weapon)
                if not weapon_name then
                    return
                end

                weapons[weapon_name] = true
            end
        end
        local selected_nades = { }
        for grenade_type, grenade_name in pairs(nades_list) do
            local g_class = grenade_type
            if g_class == 'HE Grenade' then
                g_class = 'HE'
            end
            
            local grenade_class = 'C' .. g_class .. 'Grenade'

            if weapons[grenade_class] and elements.misc.drop_nades.settings.list:get(grenade_type) then
                table.insert(selected_nades, grenade_name)
            end
        end
      
        local drop_key = elements.misc.drop_nades.enable.hotkey:get()
        if drop_key and not key_click_cache then
            for index, grenade in ipairs(selected_nades) do
                local delay = 0.1 * index
                client.delay_call(delay, function ()
                    client.exec('use ' .. grenade)
                    client.delay_call(0.05, function ()
                        client.exec('drop')
                    end)
                end)
            end
        end
      
        key_click_cache = drop_key
    end

    client.set_event_callback('paint', on_paint)
end

local auto_buy do
    local prices = {
        ['AWP'] = 4750,
        ['SCAR-20/G3SG1'] = 5000,
        ['SSG-08'] = 1700,
        ['Five-SeveN/Tec-9'] = 500,
        ['P250'] = 300,
        ['Deagle/R8'] = 700,
        ['Duals'] = 400,
        ['HE Grenade'] = 300,
        ['Molotov'] = 600,
        ['Smoke'] = 300,
        ['Kevlar'] = 650,
        ['Helmet'] = 1000,
        ['Taser'] = 200,
        ['Defuse Kit'] = 400
    }
    
    local commands = {
        ['AWP'] = 'buy awp',
        ['SCAR-20/G3SG1'] = 'buy scar20',
        ['SSG-08'] = 'buy ssg08',
        ['Five-SeveN/Tec-9'] = 'buy tec9',
        ['P250'] = 'buy p250',
        ['Deagle/R8'] = 'buy deagle',
        ['Duals'] = 'buy elite',
        ['HE Grenade'] = 'buy hegrenade',
        ['Molotov'] = 'buy molotov',
        ['Smoke'] = 'buy smokegrenade',
        ['Kevlar'] = 'buy vest',
        ['Helmet'] = 'buy vesthelm',
        ['Taser'] = 'buy taser',
        ['Defuse Kit'] = 'buy defuser'
    }
    
    local function get_weapon_prices ()
        local total_price = 0
        -- @lordmouse: utilities
        local utility_purchase = elements.misc.autobuy.settings.utilities:get()
        for i = 1, #utility_purchase do
            local n = utility_purchase[i]
            
            for k, v in pairs(prices) do
                if k == n then
                    total_price = total_price + v
                end
            end
        end
    
        -- @lordmouse: secondary
        for k, v in pairs(prices) do
            if k == elements.misc.autobuy.settings.pistol:get() then
                total_price = total_price + v
            end
        end
    
        -- @lordmouse: primary
        for k, v in pairs(prices) do
            if k == elements.misc.autobuy.settings.sniper:get() then
                total_price = total_price + v
            end
        end
        
        -- @lordmouse: grenades
        local grenade_purchase = elements.misc.autobuy.settings.grenades:get()
        for i = 1, #grenade_purchase do
            local n = grenade_purchase[i]
            
            for k, v in pairs(prices) do
                if k == n then
                    total_price = total_price + v
                end
            end
        end
        return total_price
    end

    local function on_round_prestart (e)
        if not elements.misc.autobuy.enable:get() then
            return
        end

        local price_threshold = get_weapon_prices()
        local money = entity.get_prop(entity.get_local_player(), 'm_iAccount')
    
        if money <= price_threshold then
            return
        end

        -- @lordmouse: utilities
        local utility_purchase = elements.misc.autobuy.settings.utilities:get()
        for i = 1, #utility_purchase do
            local n = utility_purchase[i]
            
            for k, v in pairs(commands) do
                if k == n then
                    client.exec(v)
                end
            end
        end

        -- @lordmouse: secondary
        for k, v in pairs(commands) do
            if k == elements.misc.autobuy.settings.pistol:get() then
                client.exec(v)
            end
        end

        -- @lordmouse: primary
        for k, v in pairs(commands) do
            if k == elements.misc.autobuy.settings.sniper:get() then
                client.exec(v)
            end
        end

        -- @lordmouse: grenades
        local grenade_purchase = elements.misc.autobuy.settings.grenades:get()
        for i = 1, #grenade_purchase do
            local n = grenade_purchase[i]
            
            for k, v in pairs(commands) do
                if k == n then
                    client.exec(v)
                end
            end
        end
    end
    
    client.set_event_callback('round_prestart', on_round_prestart)
end

local animations do
    local native_GetClientEntity = vtable_bind('client.dll', 'VClientEntityList003', 3, 'void*(__thiscall*)(void*, int)')
    local char_ptr = ffi.typeof('char*')
    local nullptr = ffi.new('void*')
    local class_ptr = ffi.typeof('void***')
    local animation_layer_t = ffi.typeof([[struct { char pad0[0x18]; uint32_t sequence; float prev_cycle, weight, weight_delta_rate, playback_rate, cycle; void *entity; char pad1[0x4]; } **]])

    local command_number = 0
    local function on_run_command (e)
        command_number = e.command_number
    end

    client.set_event_callback('run_command', on_run_command)

    local function on_pre_render ()
        if not elements.misc.animations.enable:get() then
            return
        end
        
        local me = entity.get_local_player()
        if not me or not entity.is_alive(me) then 
            return 
        end
    
        local player_ptr = ffi.cast(class_ptr, native_GetClientEntity(me))
        if player_ptr == nullptr then 
            return 
        end
    
        local first_velocity, second_velocity = entity.get_prop(me, 'm_vecVelocity')
        local speed = math.floor(math.sqrt(first_velocity^2 + second_velocity^2))
    
        local anim_layers = ffi.cast(animation_layer_t, ffi.cast(char_ptr, player_ptr) + 0x2990)[0]
        local anim_type, anim_extra_type, anim_jitter_min, anim_jitter_max, body_lean_value = false, elements.misc.animations.settings.running.anim_extra_type, false, false, 0
        if is_on_ground and speed > 5 then
            anim_type = elements.misc.animations.settings.running.anim_type:get()
            anim_extra_type = elements.misc.animations.settings.running.anim_extra_type
            anim_jitter_min = elements.misc.animations.settings.running.anim_min_jitter:get() * 0.01
            anim_jitter_max = elements.misc.animations.settings.running.anim_max_jitter:get() * 0.01
            body_lean_value = elements.misc.animations.settings.running.anim_bodylean:get()
        elseif not is_on_ground then
            anim_type = elements.misc.animations.settings.in_air.anim_type:get()
            anim_extra_type = elements.misc.animations.settings.in_air.anim_extra_type
            anim_jitter_min = elements.misc.animations.settings.in_air.anim_min_jitter:get() * 0.01
            anim_jitter_max = elements.misc.animations.settings.in_air.anim_max_jitter:get() * 0.01
            body_lean_value = elements.misc.animations.settings.in_air.anim_bodylean:get()
        end
        local is_lagging = globals.realtime() / 2 % 1
    
        if anim_type == 'Allah' then
            entity.set_prop(me, 'm_flPoseParameter', 1, is_on_ground and speed > 5 and 7 or 6)
            if not is_on_ground then anim_layers[6].weight, anim_layers[6].cycle = 1, is_lagging end
            reference.antiaim.other.leg_movement:override('never slide')
        elseif anim_type == 'Static' then
            entity.set_prop(me, 'm_flPoseParameter', 1, is_on_ground and speed > 5 and 0 or 6)
            reference.antiaim.other.leg_movement:override('always slide')
        elseif anim_type == 'Jitter' then
            entity.set_prop(me, 'm_flPoseParameter', client.random_float(anim_jitter_min, anim_jitter_max), is_on_ground and speed > 5 and 7 or 6)
            reference.antiaim.other.leg_movement:override('never slide')
        elseif elements.misc.animations.settings.running.anim_type:get() == 'Alternative jitter' then
            reference.antiaim.other.leg_movement:override(command_number % 3 == 0 and 'off' or 'always slide')
            entity.set_prop(me, 'm_flPoseParameter', 1, globals.tickcount() % 4 > 1 and 0.5 or 1)
            if is_on_ground and speed < 0 then
                entity.set_prop(me, 'm_flPoseParameter', client.random_float(0.4, 0.8), 7)
            end
        else
            reference.antiaim.other.leg_movement:override('off')
        end
    
        if anim_extra_type:get('Body lean') then
            anim_layers[12].weight = body_lean_value / 100
        end
    
        if elements.misc.animations.settings.in_air.anim_extra_type:get('Zero pitch on landing') then
            if ticks > 24 and ticks < 550 then
                entity.set_prop(me, 'm_flPoseParameter', 0.5, 12)
            end
        end
    end

    client.set_event_callback('pre_render', on_pre_render)
end


local clan_tag_spammer do
    local clan_tag_prev = ''
    local enabled_prev = false
    local sequence = {
        '              ',
        'l             ',
        'lu            ',
        'lun           ',
        'luna          ',
        'lunar         ',
        'lunari        ',
        'lunaris       ',
        'lunaris       ',
        'lunari s      ',
        'luna r i s    ',
        'lun a r i s   ',
        'lu n a r i s  ',
        'l u n a r i s ',
        'lu n a r i s  ',
        'lun a r i s   ',
        'luna r i s    ',
        'lunari s      ',
        'lunaris       ',
        'lunaris       ',
        'lunari        ',
        'lunar         ',
        'luna          ',
        'lun           ',
        'lu            ',
        'l             ',
        '              ',
    }

    local function clan_tag_anim ()
        local tickinterval = globals.tickinterval()
        local tickcount = globals.tickcount() + math.floor(client.latency() / globals.tickinterval() + .5)
        local i = math.floor(tickcount / math.floor(0.3 / tickinterval + .5)) % #sequence + 1
    
        return sequence[i]
    end
    
    local function clan_tag_original ()
        local clanid = cvar.cl_clanid.get_int()
        if clanid == 0 then return '\0' end

        local clan_count = steamworks.ISteamFriends.GetClanCount()
        for i = 0, clan_count do 
            local group_id = steamworks.ISteamFriends.GetClanByIndex(i)
            if group_id == clanid then
                return steamworks.ISteamFriends.GetClanTag(group_id)
            end
        end
    end

    local function on_paint ()
        local enabled = elements.misc.clan_tag_spammer:get()
        if enabled then
            local local_player = entity.get_local_player()
            local clan_tag = clan_tag_anim()

            if local_player ~= nil and globals.tickcount() % 2 == 0 or (not entity.is_alive(local_player)) and globals.tickcount() % 2 == 0 then
                if clan_tag ~= clan_tag_prev then
                    client.set_clan_tag(clan_tag)
                    clan_tag_prev = clan_tag
                end 
            end
        elseif enabled_prev then
            client.set_clan_tag(clan_tag_original())
        end

        enabled_prev = enabled
    end

    local function on_run_command (e)
        if elements.misc.clan_tag_spammer:get() and e.chokedcommands == 0 then
            on_paint()
        end
    end

    client.set_event_callback('paint', on_paint)
    client.set_event_callback('run_command', on_run_command)
end

-- @lordmouse: TODO поставить везде значения задержки на сообщение ЧТОБЫ ТИПЫ ЕЩЁ СИЛЬНЕЕ байтились
local trash_talk do
    local killer_of_local_player = nil
    local current_players = {}  -- Store available player names
    
    local phrases = {
        revenge = {
            {'1', 1.0}
        },
    
        kill = {
            {'ʙʏ ʙᴜʏɪɴɢ ᴇᴍʙᴇʀʟᴀsʜ, ʏᴏᴜ\'ʀᴇ ʙᴜʏɪɴɢ ᴀ ᴛɪᴄᴋᴇᴛ ᴛᴏ ʜᴇʟʟ.', 0.2},
            {'𝙀𝙢𝙗𝙚𝙧𝙡𝙖𝙨𝙝 𝙥𝙧𝙚𝙢𝙞𝙪𝙢 𝙥𝙧𝙚𝙙𝙞𝙘𝙩𝙞𝙤𝙣 𝙩𝙚𝙘𝙝𝙣𝙤𝙡𝙤𝙜𝙞𝙚𝙨 ◣◢ 👑', 0.2},
            {'The Flame will never die, for I am EMBERLASH', 0.2},
            {'☾ 𝕘𝕖𝕥 𝕗𝕦𝕔𝕜𝕖𝕕 𝕓𝕪 𝕕𝕖𝕧𝕚𝕝 #𝕖𝕞𝕓𝕖𝕣𝕝𝕒𝕤𝕙 ~ 𝕟𝕖𝕥𝕨𝕠𝕣k ☾', 0.2, '1', 1.0},
            {'♥️ Очередная душа в мою копилку (◣_◢) ♥️', 0.2},
            {'теперь сам Дьявол объявил на тебя охоту #𝕖𝕞𝕓𝕖𝕣𝕝𝕒𝕤𝕙 ☾', 0.2},
            {'опять слезы? умоляй моих дьяволов выдать тебе lunaris', 0.2},
            {'1', 1.0},
            {'𝕖𝕞𝕓𝕖𝕣𝕝𝕒𝕤𝕙 𝕚𝕤 𝕥𝕙𝕖 𝕓𝕖𝕤𝕥 𝔸𝔸 𝔸𝔸 𝔸𝔸 𝔸𝔸 𝔸𝔸 𝔸𝔸 𝔸', 0.2},
            {'♆ Сливы Дьяволиц -> .𝕘𝕘/𝔼𝕞𝕓𝕖𝕣𝕝𝕒𝕤𝕙 ♆', 0.2},
            {'#𝙚𝙢𝙗𝙚𝙧𝙡𝙖𝙨𝙝 𝙘𝙤𝙙𝙚 𝙬𝙖𝙨 𝙬𝙧𝙞𝙩𝙩𝙚𝙣 𝙗𝙮 𝐵𝓁𝑜𝑜𝒹 𝑜𝒻 𝐿𝓊𝒸𝒾𝒻𝑒𝓇 ٩(×̯×)۶', 0.2},
            {'14fl peek but i still predict #mephissa predict', 0.2},
            {'1', 1.0},
            {'твоя сила – лишь иллюзия перед властью Lunaris.', 0.2},
            {'это не битва, это исповедь, lunaris выслушает все твои грехи.', 0.2},
            {'Это не борьба за выживание, это жертва Lunaris.', 0.2},
            {'1', 1.0},
            {'lunaris станет эпитафией на твоём надгробии.', 0.2},
            {'Estk came to my door last night and said lunaris best ◣◢ I say ok king 👑', 0.2},
            {'𝕘𝕠𝕕 𝕘𝕒𝕧𝕖 𝕞𝕖 𝕡𝕠𝕨𝕖𝕣 𝕠𝕗 𝕣𝕖𝕫𝕠𝕝𝕧𝕖𝕣 𝔼𝕄𝔹𝔼ℝ𝕃𝔸𝕊ℍ', 0.2},
            {'っ◔◡◔)っ ♥ enjoy die to lunaris and spectate me ♥', 0.2},
            {'1', 1.0},
            {'𝕟𝕠 𝕤𝕜𝕚𝕝𝕝 𝕟𝕖𝕖𝕕 𝕛𝕦𝕤𝕥 𝕖𝕞𝕓𝕖𝕣𝕝𝕒𝕤𝕙', 0.2},
            {'𝕚 𝕒𝕞 𝕚𝕥”𝕤 𝕕𝕠𝕟𝕥 𝕝𝕠𝕤𝕖  ◣◢ #lunaris', 0.2},
            {'god may forgive you but lunaris resolver wont (◣_◢)', 0.2},
            {'1', 1.0},
            {'𝕓𝕪 𝕤𝕚𝕘𝕟𝕚𝕟𝕘 𝕒 𝕔𝕠𝕟𝕥𝕒𝕔𝕥 𝕨𝕚𝕥𝕙 𝕥𝕙𝕖 𝕕𝕖𝕧𝕚𝕝 𝕪𝕠𝕦 𝕒𝕣𝕖 𝕕𝕠𝕠𝕞𝕖𝕕 𝕥𝕠 𝕕𝕚𝕖 #lunaris', 0.2},
            {'ＹＯＵ ＷＩＳＨ ＹＯＵ ＨＡＤ E M B E R L A S H Ｕ ＨＲＳＮ', 0.2},
            {'winning not possibility, sry #lunaris', 0.2},
            {'1', 1.0},
            {'𝙙𝙖𝙮 666 𝗲𝗺𝗯𝗲𝗿𝗹𝗮𝘀𝗵 𝙨𝙩𝙞𝙡𝙡 𝙣𝙤 𝙧𝙞𝙫𝙖𝙡𝙨', 0.2},
            {'once this game started 𝔂𝓸𝓾 𝓵𝓸𝓼𝓮𝓭 𝓪𝓵𝓻𝓮𝓭𝔂 #lunaris', 0.2},
            {'ＹＯＵ ＨＡＤ ＦＵＮ ＬＡＵＧＨＩＮＧ ＵＮＴＩＬ ＮＯＷ #lunaris', 0.2},
            {'1', 1.0},
            {'EMBERLASH SEASON ON TRƱE #WITCHHOUSE AND #EVIL RADIO vibe 2025™', 0.2},
            {'rock star lifestyle #EMBERLASH', 0.2},
            {'i love lunaris', 0.2, 'do you love it?', 1},
            {'1', 1.0},
            {'zｚＺ', 0.2, 'playing with lunaris is so boooring', 0.5},
            {'im cursed', 0.2, 'satan is watching us', 0.6},
            {'family-friendly lua -> .gg/lunaris', 0.2},
            {'1', 1.0},
            {'1', 0.5, 'теперь думай кто это написал)))', 0.8},
            {'мы летим низко', 0.2, 'в бошке храню все lunaris', 0.5},
            {'снова палю в экран', 0.5, 'снова вижу этот дискорд', 0.5, '.gg/lunaris', 0.5},
            {'1', 0.4, 'иди ты нахуй дебилина', 0.5},
            {'1', 0.4, 'ФХАФЫХАЫХФАХ', 0.5, 'бомж ты куда', 0.6},
            {'моя сила lunaris', 0.2, 'что не брикаю лцшечку', 0.5},
            {'это происходит в действительности?', 0.2, '1', 0.7},
            {'я смотрю', 0.2, 'у тебя тренировка по удачному спаму пуль, продолжай', 0.5},
            {'если бы твой скилл зависел от интеллекта', 0.2, 'ты бы и в меню не зашёл', 0.5},
            {'ты не победил', 0.2, 'я просто протестировал баг на перерождение', 0.7},
            {'1', 1.0},
            {'где тебя научили стрелять', 0.2, 'в тире для первоклассников?', 0.6},
            {'z бы тебя похвалил', 0.2, 'но ты выиграл не скиллом', 0.5, 'а везением', 0.8},
            {'ты - как бесплатный lunaris', 0.2, 'который никто не скачивает', 0.6},
            {'1', 1.0},
            {'если твои успехи в игре перевести в реальные достижения', 0.6, 'ты бы был миллионером… в минусах', 0.75},
            {'мой труп был в 100 раз полезнее команды', 0.4, 'чем ты живой', 0.5},
            {'это было настолько случайно, что даже твои родители не так удивились, когда ты родился', 0.5},
            {'1', 1.0},
            {'eсли бы IQ был оружием', 0.3, 'ты бы ходил с деревянной палкой', 0.5},
            {'ты ошибка природы', 0.3, 'и даже код игры это понимает', 0.6},
            {'каково жить с осознанием', 0.3, 'что даже удача тебя презирает?', 0.6},
            {'1', 1.0},
            {'если бы победы давали смысл жизни', 0.3, 'ты бы уже повесился', 0.4},
            {'интеллект у тиа бл такой же плоский, как шахматная доска в аду', 0.4},
            {'ты как шут', 0.2, 'пытающийся быть серьезным в компании демонов', 0.5},
            {'1', 1.0},
            {'ты меня убил', 0.2, 'как сочник', 0.4, 'который заигрался и случайно открыл портал в ад', 0.6}
        },
    
        death = {
            {'ну он же реально', 3, 'подрывает себя', 2.5, 'и я не могу попасть', 1.8},
            {'ты че ваще ебанутый?', 1, 'я твою мать ебал', 2, 'ебаный тупой ублюдок', 3},
            {'в этом раунде эмберлашик не прокерил', 0.5, 'значит прокерит в следующем', 1.0},
            {'опять говно убивает', 1.8, 'я просто не могу уже', 1.5},
            {'ну как ты мои антиаимы тапаешь в эмберлаше??', 0.5, 'че ебу дал?', 1.0},
            {'я не могу в тебя попасть', 0.5, 'сделаешь мне такие же пресетики?', 1.5, 'на lunaris.gs', 0.5},
            {'НУ ЧТО ТЫ ЗА ДОЛБОЕБ', 0.2, 'БЛЯДИНА ЕБАНА Я ТЬЯВОЮ МАТЬ ЕБАЛ', 1.8},
            {'сын шлюхи ебаной я просто не знаю как тебя ещё назвать', 0.9, 'за твои действия пидарас', 1.5},
            {'какой же ты ХУЕСОС', 1.8, 'НУ Я МИССАЮ ЕМУ В РУКУ А ОН ДУМАЕТ', 0.8, 'ЧТО ЭТО ЛЦ', 1.4}
        }
    }

    local phrase_count = {
        kill = 0,
        death = 0,
        revenge = 0
    }

    local function say_phrases (phrase_table)
        local current_delay = 0
        for i = 1, #phrase_table, 2 do
            local message = phrase_table[i]
            local delay = phrase_table[i+1] or 3
            
            current_delay = current_delay + delay
            client.delay_call(current_delay, function () 
                client.exec(('say %s'):format(message)) 
            end)
        end
    end

    local function on_player_death (e)
        local player, victim, attacker = entity.get_local_player(), client.userid_to_entindex(e.userid), client.userid_to_entindex(e.attacker)
        if not player or not victim or not attacker then 
            return 
        end
        
        -- For normal trash talk, check if it's enabled
        if not elements.misc.trash_talk.enable:get() then 
            return 
        end
    
        -- Track all events for normal trash talk
        if attacker == player and victim ~= player then
            -- Local player kills someone
            phrase_count.kill = (phrase_count.kill % #phrases.kill) + 1
        elseif victim == player and attacker ~= player then
            -- Local player dies from someone
            killer_of_local_player = attacker
            phrase_count.death = (phrase_count.death % #phrases.death) + 1
        elseif killer_of_local_player ~= nil and victim == killer_of_local_player and attacker ~= player then
            -- Our killer gets killed by someone
            phrase_count.revenge = (phrase_count.revenge % #phrases.revenge) + 1
        end
    
        local selected_phrases = { 
            kill = phrases.kill[phrase_count.kill], 
            death = phrases.death[phrase_count.death],
            revenge = phrases.revenge[phrase_count.revenge]
        }
    
        -- Trigger phrases based on event type and work settings
        if elements.misc.trash_talk.settings.work:get('On kill') and attacker == player and victim ~= player then
            say_phrases(selected_phrases.kill)
        elseif elements.misc.trash_talk.settings.work:get('On death') and victim == player and attacker ~= player then
            say_phrases(selected_phrases.death)
        elseif elements.misc.trash_talk.settings.work:get('On revenge') and killer_of_local_player ~= nil and victim == killer_of_local_player and attacker ~= player and not entity.is_alive(player) then
            say_phrases(selected_phrases.revenge)
            killer_of_local_player = nil
        end
    end

    client.set_event_callback('player_death', on_player_death)

    -- Reset killer tracking on round start
    client.set_event_callback('round_start', function()
        killer_of_local_player = nil
    end)
    
    -- Reset killer tracking on round end
    client.set_event_callback('round_end', function()
        killer_of_local_player = nil
    end)
end

---

local lagcomp_skeleton = { }; do
    local hitlist = { }
    
    -- Skeleton mesh connections (hitbox indices)
    local skelMesh = {
        {0, 1}, {1, 6}, {6, 5}, {5, 4}, {4, 3}, {3, 2}, {2, 7}, {2, 8},
        {8, 10}, {10, 12}, {7, 9}, {9, 11}, {1, 17}, {1, 15}, {17, 18},
        {18, 14}, {15, 16}, {16, 13}
    }
    
    -- Draw skeleton function
    local function drawSkel(hitboxPos, r, g, b, a)
        for i = 1, #skelMesh do
            local p1 = hitboxPos[skelMesh[i][1]]
            local p2 = hitboxPos[skelMesh[i][2]]
            if p1 and p2 then
                local p1_x, p1_y = renderer.world_to_screen(p1[1], p1[2], p1[3])
                local p2_x, p2_y = renderer.world_to_screen(p2[1], p2[2], p2[3])
                if p1_x and p2_x then
                    renderer.line(p1_x, p1_y, p2_x, p2_y, r, g, b, a)
                end
            end
        end
    end
    
    -- Aim fire event - capture skeleton when aimbot shoots
    local function on_aim_fire(e)
        if not elements.visuals.lagcomp_skeleton.enable:get() then
            return
        end
        
        -- Get all hitbox positions for the target
        local hitboxPos = { }
        for i = 0, 18 do
            local hx, hy, hz = entity.hitbox_position(e.target, i)
            if hx then
                hitboxPos[i] = { hx, hy, hz }
            end
        end
        
        -- Store skeleton data with smooth alpha
        hitlist[e.id] = {
            time = globals.curtime(),
            alpha = 0,
            hitboxPos = hitboxPos
        }
    end
    
    -- Paint event - draw skeletons
    local function on_paint()
        if not elements.visuals.lagcomp_skeleton.enable:get() then
            return
        end
        
        local duration = elements.visuals.lagcomp_skeleton.settings.duration:get()
        local r, g, b, a = elements.visuals.lagcomp_skeleton.settings.color:get()
        
        for id, entry in pairs(hitlist) do
            local time_passed = globals.curtime() - entry.time
            
            if time_passed > duration then
                hitlist[id] = nil
            else
                -- Smooth fade in then fade out
                local fade_in_time = 0.1
                if time_passed < fade_in_time then
                    entry.alpha = math.min(entry.alpha + 25.5, 255)
                else
                    entry.alpha = math.max(a * (1 - ((time_passed - fade_in_time) / (duration - fade_in_time))), 0)
                end
                
                drawSkel(entry.hitboxPos, r, g, b, entry.alpha)
            end
        end
    end
    
    -- Register events
    client.set_event_callback('aim_fire', on_aim_fire)
    client.set_event_callback('paint', on_paint)
end

local bullet_tracer = { }; do
    local tracers = { }
    
    client.set_event_callback('paint', function()
        if not elements.visuals.bullet_tracer.enable:get() then
            return
        end
        
        local r, g, b, a = elements.visuals.bullet_tracer.settings.color:get()
        local thickness = elements.visuals.bullet_tracer.settings.thickness:get()
        local duration = elements.visuals.bullet_tracer.settings.duration:get()
        
        for tick, data in pairs(tracers) do
            if globals.curtime() > data.end_time then
                tracers[tick] = nil
            else
                local alpha = a * (1 - ((globals.curtime() - data.time) / duration))
                
                local x1, y1 = renderer.world_to_screen(data.start_x, data.start_y, data.start_z)
                local x2, y2 = renderer.world_to_screen(data.end_x, data.end_y, data.end_z)
                
                if x1 and x2 then
                    for offset = -math.floor(thickness / 2), math.floor(thickness / 2) do
                        renderer.line(x1, y1 + offset, x2, y2 + offset, r, g, b, alpha)
                    end
                end
            end
        end
    end)
    
    client.set_event_callback('bullet_impact', function(e)
        if not elements.visuals.bullet_tracer.enable:get() then
            return
        end
        
        local me = entity.get_local_player()
        if not me then return end
        
        if client.userid_to_entindex(e.userid) ~= me then
            return
        end
        
        local eye_x, eye_y, eye_z = client.eye_position()
        if not eye_x then return end
        
        local duration = elements.visuals.bullet_tracer.settings.duration:get()
        
        tracers[globals.tickcount()] = {
            time = globals.curtime(),
            end_time = globals.curtime() + duration,
            start_x = eye_x,
            start_y = eye_y,
            start_z = eye_z,
            end_x = e.x,
            end_y = e.y,
            end_z = e.z
        }
    end)
    
    client.set_event_callback('round_prestart', function()
        tracers = { }
    end)
end

local last_seen = { }; do
    local lastPos = { }
    
    local function getEnemies()
        local player_resource = entity.get_player_resource()
        local list = { }
        for player = 1, globals.maxplayers() do
            if entity.get_prop(player_resource, 'm_bConnected', player) == 1 and entity.is_enemy(player) then
                list[#list + 1] = player
            end
        end
        return list
    end
    
    local function rectangle_outline(x, y, w, h, r, g, b, a, s)
        s = s or 1
        renderer.rectangle(x, y, w, s, r, g, b, a)
        renderer.rectangle(x, y + h - s, w, s, r, g, b, a)
        renderer.rectangle(x, y + s, s, h - s * 2, r, g, b, a)
        renderer.rectangle(x + w - s, y + s, s, h - s * 2, r, g, b, a)
    end
    
    client.set_event_callback('paint', function()
        if not elements.visuals.last_seen.enable:get() then
            return
        end
        
        local r, g, b, a = elements.visuals.last_seen.settings.color:get()
        local me = entity.get_local_player()
        if not me or not entity.is_alive(me) then return end
        
        for i, ent in ipairs(getEnemies()) do
            local alpha = entity.get_esp_data(ent).alpha
            local origin = vector(entity.get_origin(ent))
            
            if alpha > 0.05 then
                lastPos[ent] = nil
            elseif alpha ~= 0 then
                lastPos[ent] = origin
            end
        end
        
        for key, vec in pairs(lastPos) do
            local x, y = renderer.world_to_screen(vec.x, vec.y, vec.z)
            local selfOrigin = vector(entity.get_origin(me))
            
            local dist = selfOrigin:dist(vec)
            dist = 4 - (math.min(3, dist / 1000))
            
            local length = 10 * dist
            local height = 20 * dist
            
            if x then
                renderer.text(x + length / 2, y - height - 3, r, g, b, a, '-', nil, 'WARNING')
                renderer.text(x + length / 2, y - height + 5, r, g, b, a, '-', nil, entity.get_player_name(key):upper())
                
                rectangle_outline(x - length / 2, y - height, length, height, r, g, b, a)
                rectangle_outline(x - length / 2 - 1, y - height - 1, length + 2, height + 2, 0, 0, 0, a / 1.875)
                rectangle_outline(x - length / 2 + 1, y - height + 1, length - 2, height - 2, 0, 0, 0, a / 1.875)
            end
        end
    end)
    
    client.set_event_callback('round_prestart', function()
        lastPos = { }
    end)
    
    client.set_event_callback('player_death', function(e)
        local ent = client.userid_to_entindex(e.userid)
        lastPos[ent] = nil
    end)
end

---

setup = pui.setup({elements.conditions, elements.defensive, elements.anti_aim, elements.aimbot, colors, elements.visuals, elements.misc, drag_slider}, true)
client.set_event_callback('shutdown', function ()
    if _G.DEBUG then
        _G.DEBUG = nil
    end

    reset_angles()

    cvar.cl_interpolate:set_int(1)
    cvar.cl_interp_ratio:set_int(2)
    cvar.r_aspectratio:set_int(0)
    cvar.viewmodel_fov:set_raw_float(68)
    cvar.viewmodel_offset_x:set_raw_float(2.5)
    cvar.viewmodel_offset_y:set_raw_float(0)
    cvar.viewmodel_offset_z:set_raw_float(-1.5)

    cvar.cl_interpolate:set_int(1)
    cvar.cl_interp_ratio:set_int(2)

    collectgarbage('collect')
    collectgarbage('collect')
end)
end)()


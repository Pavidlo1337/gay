--[[
    ===============================================================
      Parallax resolver  |  gamesense / skeet lua
    ---------------------------------------------------------------
      Собран на основе изучения ВСЕХ нужных резольверов:
        - kent_resolver_june28     (animstate ffi, max feet yaw, bruteforce фазы)
        - custom_resolver_gs        (jitter detection по анимслоям)
        - bounty_resolver           (структура событий, simtime записи)
        - Neural_resolver / mario   (plist обёртки, оффсеты)
        - ! 10$ / ! 15 / KostaTeam  (eye-yaw jitter буфер, rebuild server yaw)
        - aimsensereso / metaset    (choked packets, defensive обработка)
        - jitterresolver / Ambassador (pose-parameter, freestanding)
        - Roll_resolver / bluhgang   (флип стороны на miss)
        - wraith resolver            (on-shot detect по m_fLastShotTime)
        - vandalresolverv2           (стабилизация стороны подтверждением)
      Логика переработана и собрана в единый класс.
    ===============================================================
]]

local ffi    = require("ffi")
local vector = require("vector")

-- Опциональные модули gamesense — есть не во всех билдах. Загружаем через pcall.
local clipboard, base64
do
    local ok1, mod1 = pcall(require, "gamesense/clipboard")
    if ok1 then clipboard = mod1 end
    local ok2, mod2 = pcall(require, "gamesense/base64")
    if ok2 then base64 = mod2 end
end

-- [x]======================[ Оффсеты (зависят от билда CS:GO) ]======================[x]
-- Если резольвер перестал работать после обновления игры — обновите эти два значения.
local OFFSET_ANIMSTATE = 0x9960
local OFFSET_ANIMLAYER = 0x2990

-- [x]======================[ FFI-структуры ]======================[x]
ffi.cdef[[
    struct anim_layer_t {
        char       pad_0000[24];
        uint32_t   m_nSequence;
        float      m_flPrevCycle;
        float      m_flWeight;
        float      m_flWeightDeltaRate;
        float      m_flPlaybackRate;
        float      m_flCycle;
        void*      m_pOwner;
        char       pad_0038[4];
    };

    struct anim_state_t {
        char    pad_0000[3];
        char    m_bForceWeaponUpdate;
        char    pad_0004[91];
        void*   m_pBaseEntity;
        void*   m_pActiveWeapon;
        void*   m_pLastActiveWeapon;
        float   m_flLastClientSideAnimationUpdateTime;
        int     m_iLastClientSideAnimationUpdateFramecount;
        float   m_flAnimUpdateDelta;
        float   m_flEyeYaw;            // 0x78
        float   m_flPitch;             // 0x7C
        float   m_flGoalFeetYaw;       // 0x80
        float   m_flCurrentFeetYaw;    // 0x84
        float   m_flCurrentTorsoYaw;   // 0x88
        float   m_flUnknownVelocityLean;
        float   m_flLeanAmount;
        char    pad_0094[4];
        float   m_flFeetCycle;
        float   m_flFeetYawRate;
        char    pad_00A0[4];
        float   m_fDuckAmount;         // 0xA4
        float   m_fLandingDuckAdditiveSomething;
        char    pad_00AC[4];
        float   m_vOriginX;
        float   m_vOriginY;
        float   m_vOriginZ;
        float   m_vLastOriginX;
        float   m_vLastOriginY;
        float   m_vLastOriginZ;
        float   m_vVelocityX;
        float   m_vVelocityY;
        char    pad_00D0[4];
        float   m_flUnknownFloat1;
        char    pad_00D8[8];
        float   m_flUnknownFloat2;
        float   m_flUnknownFloat3;
        float   m_flUnknown;
        float   m_flSpeed2D;
        float   m_flUpVelocity;
        float   m_flSpeedNormalized;
        float   m_flFeetSpeedForwardsOrSideWays;
        float   m_flFeetSpeedUnknownForwardOrSideways;
        float   m_flTimeSinceStartedMoving;
        float   m_flTimeSinceStoppedMoving;
        bool    m_bOnGround;
        bool    m_bInHitGroundAnimation;
        float   m_flTimeSinceInAir;
        float   m_flLastOriginZ;
        float   m_flHeadHeightOrOffsetFromHittingGroundAnimation;
        float   m_flStopToFullRunningFraction;
        char    pad_011A[4];
        float   m_flMagicFraction;
        char    pad_0122[60];
        float   m_flWorldForce;
        char    pad_0162[458];
        float   m_flMinYaw;            // 0x330  (min body yaw)
        float   m_flMaxYaw;            // 0x334  (max body yaw)
    };
]]

-- [x]======================[ Доступ к нативам через vtable ]======================[x]
-- Получение vtable может упасть, если client_panorama.dll ещё не загружен
-- (запуск скрипта до полной инициализации игры). Делаем мягко: если интерфейс
-- не доступен — все FFI-функции возвращают nil, остальные части скрипта
-- продолжат работать без animstate (ESP-флаги, watermark, логи и т.д.).
local entitylist
local get_client_entity_fn
do
    local ok, raw = pcall(client.create_interface,
        "client_panorama.dll", "VClientEntityList003")
    if ok and raw then
        local ok2, ifc = pcall(ffi.cast, "void***", raw)
        if ok2 and ifc then
            entitylist = ifc
            local ok3, fn = pcall(ffi.cast,
                "void*(__thiscall*)(void*, int)", ifc[0][3])
            if ok3 then get_client_entity_fn = fn end
        end
    end
    if not entitylist or not get_client_entity_fn then
        client.color_log(255, 100, 100,
            "[Parallax] WARN: VClientEntityList003 unavailable, FFI features disabled")
    end
end

-- ЗАЩИТА ОТ КРАША: Безопасная обертка для get_client_entity
local function get_client_entity(idx)
    if not entitylist or not get_client_entity_fn then return nil end
    if not idx or type(idx) ~= "number" then return nil end
    if idx < 1 or idx > 64 then return nil end
    
    local success, result = pcall(get_client_entity_fn, entitylist, idx)
    if not success then return nil end
    if not result or result == ffi.NULL then return nil end
    
    return result
end

-- [x]======================[ Утилиты ]======================[x]
local math_floor, math_abs, math_min, math_max = math.floor, math.abs, math.min, math.max
local math_sqrt, math_sin, math_cos, math_rad   = math.sqrt, math.sin, math.cos, math.rad
local math_atan2, math_deg                       = math.atan2, math.deg

local function clamp(v, lo, hi)
    return math_max(lo, math_min(v, hi))
end

local function normalize_yaw(yaw)
    return (yaw + 180) % 360 - 180
end

-- Разница углов (из ! 10$ / metaset). Возвращает значение в [-180, 180].
local function angle_diff(dest, src)
    local delta = math.fmod(dest - src, 360)
    if dest > src then
        if delta >= 180 then delta = delta - 360 end
    else
        if delta <= -180 then delta = delta + 360 end
    end
    return delta
end

local function to_ticks(t)
    return math_floor(t / globals.tickinterval() + 0.5)
end

local function round(num, decimals)
    local mult = 10 ^ (decimals or 0)
    return math_floor((num or 0) * mult + 0.5) / mult
end

local function contains(tbl, val)
    for i = 1, #tbl do
        if tbl[i] == val then return true end
    end
    return false
end

-- digits[i] -> i-я цифра дробной части (как в custom_resolver_gs, для чтения jitter из анимслоёв)
local function frac_digit(value, i)
    return math_floor(value * (10 ^ i)) - (math_floor(value * (10 ^ (i - 1))) * 10)
end

-- [x]======================[ Animstate / Animlayer ]======================[x]
-- ЗАЩИТА ОТ КРАША: Полностью безопасная работа с animstate
local function get_anim_state(idx)
    -- Валидация входных данных
    if not idx or type(idx) ~= "number" then return nil end
    if idx < 1 or idx > 64 then return nil end
    
    local ent_ptr = get_client_entity(idx)
    if not ent_ptr or ent_ptr == ffi.NULL then return nil end
    
    -- Защищенное обращение к памяти через pcall
    local success, result = pcall(function()
        local state_ptr = ffi.cast("char*", ent_ptr) + OFFSET_ANIMSTATE
        local state_ref = ffi.cast("struct anim_state_t**", state_ptr)
        if state_ref == ffi.NULL then return nil end
        
        local state = state_ref[0]
        if state == nil or state == ffi.NULL then return nil end
        
        -- Дополнительная проверка: читаем одно поле для валидации
        local _ = state.m_flEyeYaw
        return state
    end)
    
    return success and result or nil
end

-- ЗАЩИТА ОТ КРАША: Полностью безопасная работа с animlayer
local function get_anim_layer(idx, layer)
    -- Валидация входных данных
    if not idx or type(idx) ~= "number" then return nil end
    if idx < 1 or idx > 64 then return nil end
    if not layer or type(layer) ~= "number" then return nil end
    if layer < 0 or layer > 12 then return nil end
    
    local ent_ptr = get_client_entity(idx)
    if not ent_ptr or ent_ptr == ffi.NULL then return nil end
    
    -- Защищенное обращение к памяти через pcall
    local success, result = pcall(function()
        local layer_ptr = ffi.cast("char*", ent_ptr) + OFFSET_ANIMLAYER
        local layers_ref = ffi.cast("struct anim_layer_t**", layer_ptr)
        if layers_ref == ffi.NULL then return nil end
        
        local layers = layers_ref[0]
        if layers == nil or layers == ffi.NULL then return nil end
        
        -- Проверяем что можем прочитать нужный слой
        local target_layer = layers[layer]
        if target_layer == nil then return nil end
        
        -- Валидация: пробуем прочитать одно поле
        local _ = target_layer.m_nSequence
        return target_layer
    end)
    
    return success and result or nil
end

-- Максимальный угол рассинхрона ног (desync). Формула как в kent_resolver.
-- ЗАЩИТА ОТ КРАША: Безопасное чтение полей animstate
local function get_max_desync(idx)
    local st = get_anim_state(idx)
    if not st then return 0 end

    -- Защищенное чтение полей через pcall
    local success, result = pcall(function()
        local duck      = st.m_fDuckAmount or 0
        local fwd_side  = clamp(st.m_flFeetSpeedForwardsOrSideWays or 0, 0, 1)
        local unk_side  = math_max(1, st.m_flFeetSpeedUnknownForwardOrSideways or 1)

        local value = (st.m_flStopToFullRunningFraction * -0.30000001 - 0.19999999) * fwd_side + 1.0
        if duck > 0 then
            value = value + duck * unk_side * (0.5 - value)
        end

        local delta = st.m_flMaxYaw * value
        if delta >= 0 and delta < 60 then
            return delta
        end
        return 0
    end)
    
    return success and result or 0
end

-- Реконструкция goal feet yaw сервера (подход ! 10$ / KostaTeam / rinnegan).
-- ��аёт «настоящий» угол ног, к которому игра подтянет цель.
-- ЗАЩИТА ОТ КРАША: Безопасное чтение всех полей
local function rebuild_server_yaw(idx)
    local st = get_anim_state(idx)
    if not st then return nil end

    -- Защищенное чтение и вычисление через pcall
    local success, result = pcall(function()
        local goal_feet     = st.m_flGoalFeetYaw or 0
        local eye_yaw       = st.m_flEyeYaw or 0
        local eye_feet_delta = angle_diff(eye_yaw, goal_feet)
        local run_speed     = clamp(st.m_flFeetSpeedForwardsOrSideWays or 0, 0, 1)

        local yaw_mod = (st.m_flStopToFullRunningFraction * -0.3 - 0.2) * run_speed + 1.0
        if (st.m_fDuckAmount or 0) > 0 then
            local duck_speed = clamp(st.m_flFeetSpeedForwardsOrSideWays or 0, 0, 1)
            yaw_mod = yaw_mod + (st.m_fDuckAmount * duck_speed * (0.5 - yaw_mod))
        end

        local max_mod = yaw_mod * (st.m_flMaxYaw or 58)
        local min_mod = yaw_mod * (st.m_flMinYaw or -58)

        if eye_feet_delta <= max_mod then
            if min_mod > eye_feet_delta then
                goal_feet = math_abs(min_mod) + eye_yaw
            end
        else
            goal_feet = eye_yaw - math_abs(max_mod)
        end

        return normalize_yaw(goal_feet)
    end)
    
    return success and result or nil
end

-- Кол-во "зажёванных" (choked) пакетов цели — индикатор fake lag / defensive.
-- ЗАЩИТА ОТ КРАША: Безопасная работа с entity props и cvar
local function get_choked_packets(idx)
    if not idx or idx < 1 or idx > 64 then return 0 end
    
    local ent_ptr = get_client_entity(idx)
    if not ent_ptr or ent_ptr == ffi.NULL then return 0 end

    local success, result = pcall(function()
        local sim_time = entity.get_prop(idx, "m_flSimulationTime")
        if not sim_time or type(sim_time) ~= "number" then return 0 end

        local cur_time = globals.curtime()
        if not cur_time or type(cur_time) ~= "number" then return 0 end
        
        local latency = client.latency() or 0
        local diff = cur_time - sim_time
        
        local max_ticks = 16
        if cvar.sv_maxusrcmdprocessticks then
            local ok, val = pcall(cvar.sv_maxusrcmdprocessticks.get_int, cvar.sv_maxusrcmdprocessticks)
            if ok and val then max_ticks = val - 2 end
        end
        
        return clamp(to_ticks(math_max(0, diff - latency)), 0, max_ticks)
    end)
    
    return success and result or 0
end

-- Классы оружия, для которых имеет смысл форсить тело на низком хп
-- (один уверенный выстрел в тело = килл). CDEagle покрывает и Deagle, и R8 Revolver.
-- Оружие, для которого имеет смысл форсить тело на низком хп (один уверенный
-- выстрел в тело = килл). Каждому соответствует свой ключ и свой порог хп.
-- CDEagle покрывает и Deagle, и R8 Revolver — их различаем по item definition index
-- (Deagle = 1, R8 Revolver = 64).
local WEAPON_KEY_BY_CLASS = {
    ["CWeaponAWP"]    = "awp",     -- AWP
    ["CWeaponSSG08"]  = "scout",   -- Scout
    ["CWeaponG3SG1"]  = "auto",    -- auto sniper (T)
    ["CWeaponSCAR20"] = "auto",    -- auto sniper (CT)
}

-- Возвращает ключ оружия локального игрока ("awp"/"auto"/"scout"/"deagle"/"revolver")
-- либо nil, если в руках что-то другое.
local function local_baim_weapon_key()
    local me = entity.get_local_player()
    if not me then return nil end
    local weapon = entity.get_player_weapon(me)
    if not weapon then return nil end

    local class = entity.get_classname(weapon)
    if class == "CDEagle" then
        -- Deagle и R8 Revolver делят один класс — разделяем по def index.
        local def = entity.get_prop(weapon, "m_iItemDefinitionIndex")
        return (def == 64) and "revolver" or "deagle"
    end
    return WEAPON_KEY_BY_CLASS[class]
end

-- Детект момента выстрела цели (подход wraith resolver).
-- В течение ~0.2с после выстрела desync максимально предсказуем — обычно цель в 0/back.
-- ЗАЩИТА ОТ КРАША: Безопасная проверка всех условий
local function is_onshot(idx)
    if not idx or idx < 1 or idx > 64 then return false end
    if not entity.is_alive(idx) or entity.is_dormant(idx) then return false end
    
    local success, result = pcall(function()
        local weapon = entity.get_player_weapon(idx)
        if not weapon then return false end
        
        local last_shot = entity.get_prop(weapon, "m_fLastShotTime")
        if not last_shot or type(last_shot) ~= "number" then return false end
        
        local cur_time = globals.curtime()
        if not cur_time then return false end
        
        local since = cur_time - last_shot
        return since >= 0 and since <= 0.22
    end)
    
    return success and result or false
end

-- [x]======================[ Player-list обёртки ]======================[x]
local plist_cache = { fby = {}, fby_val = {}, corr = {}, baim = {}, sp = {} }

-- Force body aim через плейерлист (поле "Override prefer body aim").
-- Значения: "Force" (форсить тело), "On" (предпочитать тело), "-" (выкл).
local function set_body_aim(idx, mode)
    if plist_cache.baim[idx] ~= mode then
        plist.set(idx, "Override prefer body aim", mode)
        plist_cache.baim[idx] = mode
    end
end

-- Safe point через плейерлист (поле "Override safe point"). "On" / "-".
local function set_safe_point(idx, mode)
    if plist_cache.sp[idx] ~= mode then
        plist.set(idx, "Override safe point", mode)
        plist_cache.sp[idx] = mode
    end
end

local function set_body_yaw(idx, enabled, value)
    if plist_cache.fby[idx] ~= enabled then
        plist.set(idx, "Force body yaw", enabled)
        plist_cache.fby[idx] = enabled
    end
    if value ~= nil and plist_cache.fby_val[idx] ~= value then
        plist.set(idx, "Force body yaw value", value)
        plist_cache.fby_val[idx] = value
    end
end

local function set_correction(idx, enabled)
    if plist_cache.corr[idx] ~= enabled then
        plist.set(idx, "Correction active", enabled)
        plist_cache.corr[idx] = enabled
    end
end

local function clear_player(idx)
    if not idx then return end
    -- При смерти/дисконнекте entindex может стать невалидным; plist.set
    -- по «мёртвому» индексу безопасен, но защитим pcall, чтобы любая
    -- кросс-версионная странность не валила весь обработчик shutdown/death.
    pcall(plist.set, idx, "Force body yaw", false)
    pcall(plist.set, idx, "Force body yaw value", 0)
    pcall(plist.set, idx, "Override prefer body aim", "-")
    pcall(plist.set, idx, "Override safe point", "-")
    plist_cache.fby[idx]     = nil
    plist_cache.fby_val[idx] = nil
    plist_cache.corr[idx]    = nil
    plist_cache.baim[idx]    = nil
    plist_cache.sp[idx]      = nil
end

-- [x]======================[ UI ]======================[x]
local ui_ref = {
    enable     = ui.new_checkbox("RAGE", "Other", "Parallax Resolver"),
}

-- Режим резольвера. Один из двух пресетов — JITTER MODE или DEFENSIVE MODE.
-- В каждом пресете жёстко прошит свой набор детекторов и фич.
local ui_mode_select = ui.new_slider("RAGE", "Other", "Resolver mode", 0, 1, 0,
    true, nil, 1, { [0] = "Jitter mode", [1] = "Defensive mode" })

-- Пресеты: какие пункты "Resolver modes" считаются включёнными для каждого
-- режима. Дополнительно у каждого режима свой профиль работы prediction-фич.
local MODE_PRESETS = {
    [0] = {  -- JITTER MODE
        modes = {
            "Animlayer jitter",
            "Eye-yaw jitter",
            "Server yaw rebuild",
            "Freestanding",
            "Bruteforce on miss",
            "On-shot zero",
            "Override pitch",
        },
        bt_assist     = true,
        adaptive      = true,
        adaptive_sp   = { "Jittering", "No backtrack ticks" },
        pred_pos      = true,
        pred_unsafe   = true,
        physics_gate  = true,
    },
    [1] = {  -- DEFENSIVE MODE
        modes = {
            "Defensive on choke",
            "Defensive flick",
            "Server yaw rebuild",
            "Bruteforce on miss",
            "On-shot zero",
        },
        bt_assist     = true,
        adaptive      = true,
        adaptive_sp   = { "Defensive", "No backtrack ticks" },
        pred_pos      = false,
        pred_unsafe   = true,
        physics_gate  = false,
    },
}

-- Скрытый мультиселект — заполняется автоматически из MODE_PRESETS при смене
-- режима. Хранит активные детекторы для resolver:run.
local ui_mode = ui.new_multiselect("RAGE", "Other", "_resolver_modes (hidden)",
    "Animlayer jitter",
    "Eye-yaw jitter",
    "Server yaw rebuild",
    "Freestanding",
    "Bruteforce on miss",
    "Defensive on choke",
    "Defensive flick",
    "On-shot zero",
    "Override pitch")

local ui_hitchance_boost = ui.new_slider("RAGE", "Other", "Min desync to resolve", 0, 60, 5, true, "°")

-- Force body aim, когда у цели мало хп. Можно выбрать оружие по отдельности,
-- и для каждого выставить свой порог хп.
local ui_baim_lowhp        = ui.new_checkbox("RAGE", "Other", "Force body aim on low HP")
local ui_baim_weapons      = ui.new_multiselect("RAGE", "Other", "  Body aim weapons",
    "AWP", "Auto snipers", "Scout", "Deagle", "Revolver")
local ui_baim_hp_awp       = ui.new_slider("RAGE", "Other", "  AWP body aim HP",      1, 100, 100, true, " HP")
local ui_baim_hp_auto      = ui.new_slider("RAGE", "Other", "  Auto sniper body aim HP", 1, 100, 100, true, " HP")
local ui_baim_hp_scout     = ui.new_slider("RAGE", "Other", "  Scout body aim HP",    1, 100, 92,  true, " HP")
local ui_baim_hp_deagle    = ui.new_slider("RAGE", "Other", "  Deagle body aim HP",   1, 100, 35,  true, " HP")
local ui_baim_hp_revolver  = ui.new_slider("RAGE", "Other", "  Revolver body aim HP", 1, 100, 35,  true, " HP")

-- ключ оружия -> { слайдер с порогом хп, имя пункта в мультиселекте }
local baim_weapon_cfg = {
    awp      = { slider = ui_baim_hp_awp,      label = "AWP"          },
    auto     = { slider = ui_baim_hp_auto,     label = "Auto snipers" },
    scout    = { slider = ui_baim_hp_scout,    label = "Scout"        },
    deagle   = { slider = ui_baim_hp_deagle,   label = "Deagle"       },
    revolver = { slider = ui_baim_hp_revolver, label = "Revolver"     },
}

local ui_debug           = ui.new_checkbox("RAGE", "Other", "Resolver debug")
local ui_debug_color     = ui.new_color_picker("RAGE", "Other", "Debug color", 255, 215, 0, 255)
local ui_logs            = ui.new_checkbox("RAGE", "Other", "Resolver logs")

-- [x]======================[ Air Hitchance (из lunaris) ]======================[x]
do
    -- UI для hitchance в воздухе (только снайперские винтовки и R8)
    local ui_air_hc_enable = ui.new_checkbox("RAGE", "Other", "Hitchance in air")
    local ui_air_hc_awp = ui.new_slider("RAGE", "Other", "  AWP air hitchance", 1, 100, 65, true, "%")
    local ui_air_hc_scout = ui.new_slider("RAGE", "Other", "  Scout air hitchance", 1, 100, 55, true, "%")
    local ui_air_hc_auto = ui.new_slider("RAGE", "Other", "  Auto snipers air hitchance", 1, 100, 70, true, "%")
    local ui_air_hc_r8 = ui.new_slider("RAGE", "Other", "  R8 Revolver air hitchance", 1, 100, 60, true, "%")

    -- Ссылка на hitchance
    local ref_hitchance = ui.reference("RAGE", "Aimbot", "Minimum hit chance")
    local air_hc_override_active = false
    local original_hitchance = 60

    -- Сохранение оригинального hitchance
    local function save_original_hitchance()
        if not air_hc_override_active then
            original_hitchance = ui.get(ref_hitchance)
        end
    end

    -- Проверка в воздухе и применение hitchance
    local function apply_air_hitchance()
        if not ui.get(ui_air_hc_enable) then
            if air_hc_override_active then
                ui.set(ref_hitchance, original_hitchance)
                air_hc_override_active = false
            end
            return
        end

        local me = entity.get_local_player()
        if not me or not entity.is_alive(me) then
            if air_hc_override_active then
                ui.set(ref_hitchance, original_hitchance)
                air_hc_override_active = false
            end
            return
        end

        -- Проверяем в воздухе ли игрок: FL_ONGROUND = бит 0 в m_fFlags.
        -- Старая проверка ground_entity ~= 0 была неверной (на мире handle = 0,
        -- а в воздухе -1; на двигающейся платформе handle > 0). Используем m_fFlags.
        local flags  = entity.get_prop(me, "m_fFlags") or 0
        local in_air = (flags % 2 == 0)
        if in_air then
            save_original_hitchance()
            
            local weapon = entity.get_player_weapon(me)
            if not weapon then return end
            
            local weapon_class = entity.get_classname(weapon)
            local hc_value = 0

            -- Определяем hitchance для снайперских винтовок и R8
            if weapon_class == "CWeaponAWP" then
                hc_value = ui.get(ui_air_hc_awp)
            elseif weapon_class == "CWeaponSSG08" then
                hc_value = ui.get(ui_air_hc_scout)
            elseif weapon_class == "CWeaponSCAR20" or weapon_class == "CWeaponG3SG1" then
                hc_value = ui.get(ui_air_hc_auto)
            elseif weapon_class == "CDEagle" then
                -- Проверяем что это именно R8 Revolver (def index 64)
                local def_index = entity.get_prop(weapon, "m_iItemDefinitionIndex")
                if def_index == 64 then
                    hc_value = ui.get(ui_air_hc_r8)
                end
            end

            if hc_value > 0 and hc_value ~= original_hitchance then
                ui.set(ref_hitchance, hc_value)
                air_hc_override_active = true
            end
        else
            -- На земле - сбрасываем override
            if air_hc_override_active then
                ui.set(ref_hitchance, original_hitchance)
                air_hc_override_active = false
            end
        end
    end

    -- Обновление видимости UI
    local function update_air_hc_visibility()
        local enabled = ui.get(ui_air_hc_enable)
        ui.set_visible(ui_air_hc_awp, enabled)
        ui.set_visible(ui_air_hc_scout, enabled)
        ui.set_visible(ui_air_hc_auto, enabled)
        ui.set_visible(ui_air_hc_r8, enabled)
    end

    -- Регистрация событий
    client.set_event_callback("setup_command", function()
        pcall(apply_air_hitchance)
    end)

    -- UI коллбеки
    ui.set_callback(ui_air_hc_enable, update_air_hc_visibility)
    update_air_hc_visibility()

    -- Добавляем в set_visibility
    local original_set_visibility2 = set_visibility
    set_visibility = function()
        original_set_visibility2()
        local on = ui.get(ui_ref.enable)
        ui.set_visible(ui_air_hc_enable, on)
        update_air_hc_visibility()
    end
end

-- [x]======================[ Hitrate Indicator ]======================[x]
do
    -- UI для хитрейт индикатора
    local ui_hitrate_enable = ui.new_checkbox("RAGE", "Other", "Hitrate Indicator")
    local ui_hitrate_color = ui.new_color_picker("RAGE", "Other", "Hitrate color", 255, 255, 255, 255)
    
    -- Статистика хитрейта
    local hitrate_stats = {
        hits = 0,
        shots = 0,
        session_hits = 0,
        session_shots = 0,
        match_hits = 0,
        match_shots = 0
    }
    
    -- Обработка выстрелов
    local function on_aim_fire(e)
        if not ui.get(ui_hitrate_enable) then return end
        hitrate_stats.shots = hitrate_stats.shots + 1
        hitrate_stats.session_shots = hitrate_stats.session_shots + 1
        hitrate_stats.match_shots = hitrate_stats.match_shots + 1
    end
    
    -- Обработка попаданий
    local function on_aim_hit(e)
        if not ui.get(ui_hitrate_enable) then return end
        hitrate_stats.hits = hitrate_stats.hits + 1
        hitrate_stats.session_hits = hitrate_stats.session_hits + 1
        hitrate_stats.match_hits = hitrate_stats.match_hits + 1
    end
    
    -- Сброс статистики матча
    local function on_game_newmap_hitrate()
        hitrate_stats.match_hits = 0
        hitrate_stats.match_shots = 0
    end
    
    -- Вычисление процентов
    local function calculate_hitrate(hits, shots)
        if shots == 0 then return 0 end
        return math.floor((hits / shots) * 100 + 0.5)
    end
    
    -- Отрисовка индикатора
    local function draw_hitrate()
        if not ui.get(ui_hitrate_enable) then return end
        
        local me = entity.get_local_player()
        if not me or not entity.is_alive(me) then return end
        
        -- Позиция как в Skeet (слева)
        local x = 10
        local y = 300
        local r, g, b, a = ui.get(ui_hitrate_color)
        
        -- Вычисляем хитрейты
        local session_rate = calculate_hitrate(hitrate_stats.session_hits, hitrate_stats.session_shots)
        local match_rate = calculate_hitrate(hitrate_stats.match_hits, hitrate_stats.match_shots)
        
        -- Цвет в зависимости от хитрейта
        local function get_hitrate_color(rate)
            if rate >= 80 then
                return 100, 255, 100  -- зеленый
            elseif rate >= 60 then
                return 255, 255, 100  -- желтый
            elseif rate >= 40 then
                return 255, 165, 0    -- оранжевый
            else
                return 255, 100, 100  -- красный
            end
        end
        
        -- Отрисовка текста в стиле Skeet
        local function draw_indicator_text(text, value, color_r, color_g, color_b, offset_y)
            -- Тень
            renderer.text(x + 1, y + offset_y + 1, 0, 0, 0, 150, "", 0, text)
            renderer.text(x + 1, y + offset_y + 1, 0, 0, 0, 150, "", 0, value)
            
            -- Основной текст
            renderer.text(x, y + offset_y, r, g, b, a, "", 0, text)
            local text_width = renderer.measure_text("", text)
            renderer.text(x + text_width, y + offset_y, color_r, color_g, color_b, a, "", 0, value)
        end
        
        -- Отрисовка заголовка
        renderer.text(x + 1, y - 19, 0, 0, 0, 150, "", 0, "HITRATE")
        renderer.text(x, y - 20, r, g, b, a, "", 0, "HITRATE")
        
        -- Session hitrate
        local sr, sg, sb = get_hitrate_color(session_rate)
        draw_indicator_text("SESSION: ", session_rate .. "%", sr, sg, sb, 0)
        
        -- Match hitrate
        local mr, mg, mb = get_hitrate_color(match_rate)
        draw_indicator_text("MATCH: ", match_rate .. "%", mr, mg, mb, 15)
        
        -- Статистика выстрелов
        draw_indicator_text("SHOTS: ", hitrate_stats.session_hits .. "/" .. hitrate_stats.session_shots, r, g, b, 30)
    end
    
    -- Обновление видимости UI
    local function update_hitrate_visibility()
        local enabled = ui.get(ui_hitrate_enable)
        ui.set_visible(ui_hitrate_color, enabled)
    end
    
    -- Регистрация событий
    client.set_event_callback("aim_fire", function(e)
        pcall(on_aim_fire, e)
    end)
    
    client.set_event_callback("aim_hit", function(e)
        pcall(on_aim_hit, e)
    end)
    
    client.set_event_callback("game_newmap", function()
        pcall(on_game_newmap_hitrate)
    end)
    
    client.set_event_callback("paint", function()
        pcall(draw_hitrate)
    end)
    
    -- UI коллбеки
    ui.set_callback(ui_hitrate_enable, update_hitrate_visibility)
    update_hitrate_visibility()
    
    -- Добавляем в set_visibility
    local original_set_visibility3 = set_visibility
    set_visibility = function()
        original_set_visibility3()
        local on = ui.get(ui_ref.enable)
        ui.set_visible(ui_hitrate_enable, on)
        update_hitrate_visibility()
    end
end

-- Clan Tag
local ui_clantag_enable  = ui.new_checkbox("RAGE", "Other", "Parallax Clan Tag")
local ui_clantag_speed   = ui.new_slider("RAGE", "Other", "  Clan tag speed", 1, 10, 4, true, "x")

-- [3] Backtrack-assisted resolving + [4] adaptive aim settings
-- Эти чекбоксы скрыты из меню — их значение определяется выбранным режимом.
-- Оставлены как ui-объекты чтобы не переписывать весь код, читающий ui.get.
local ui_bt_assist   = ui.new_checkbox("RAGE", "Other", "_bt_assist (hidden)")
local ui_bt_window   = ui.new_slider("RAGE", "Other", "  Backtrack history (ticks)", 1, 13, 12, true, " t")
local ui_adaptive    = ui.new_checkbox("RAGE", "Other", "_adaptive (hidden)")
local ui_adaptive_sp = ui.new_multiselect("RAGE", "Other", "_adaptive_sp (hidden)",
    "Jittering", "Defensive", "No backtrack ticks")
local ui_adaptive_fl = ui.new_checkbox("RAGE", "Other", "  Toggle built-in backtrack on fakelag")

-- Prediction. Все скрыты, управляются режимом. ui_pred_pos_clr оставлен видимым
-- если кто-то хочет настроить цвет визуализации.
local ui_pred_side    = ui.new_checkbox("RAGE", "Other", "_pred_side (hidden)")
local ui_pred_pos     = ui.new_checkbox("RAGE", "Other", "_pred_pos (hidden)")
local ui_pred_pos_clr = ui.new_color_picker("RAGE", "Other", "Predicted pos color", 0, 200, 255, 200)
local ui_pred_unsafe  = ui.new_checkbox("RAGE", "Other", "_pred_unsafe (hidden)")

-- Physics-предикт + confidence gate (управляется режимом)
local ui_phys           = ui.new_checkbox("RAGE", "Other", "_phys (hidden)")
local ui_phys_threshold = ui.new_slider  ("RAGE", "Other", "Confidence threshold", 0, 100, 40, true, "%")

-- [x]======================[ Config import/export ]======================[x]
-- Кнопки всегда видимы (не привязаны к главному чекбоксу), чтобы юзер
-- мог импортировать/экспортировать настройки даже если резольвер выключен.
-- Сами функции export/import определены ниже после всех ui_* — кнопки
-- вызывают локальные переменные cfg_export_fn / cfg_import_fn / cfg_default_fn.
local cfg_export_fn  = function() end
local cfg_import_fn  = function() end
local cfg_default_fn = function() end

local ui_cfg_export  = ui.new_button("RAGE", "Other", "Export config",  function() cfg_export_fn()  end)
local ui_cfg_import  = ui.new_button("RAGE", "Other", "Import config",  function() cfg_import_fn()  end)
local ui_cfg_default = ui.new_button("RAGE", "Other", "Default config", function() cfg_default_fn() end)

local player_list_ref = ui.reference("PLAYERS", "Players", "Player list")

-- Ссылки на встроенные опции gamesense для [4]. Имена контейнеров/пунктов
-- могут отличаться между билдами, поэтому берём через pcall — если опции нет,
-- просто отключаем соответствующую фичу, а не роняем скрипт.
local ref_backtrack_enable, ref_fakelag_enable, ref_fakelag_limit
do
    local ok, ref = pcall(ui.reference, "RAGE", "Other", "Backtrack")
    if ok then ref_backtrack_enable = ref end

    local ok2, r1, r2 = pcall(ui.reference, "AA", "Fake lag", "Enabled")
    if ok2 then ref_fakelag_enable = r1 end

    local ok3, rl = pcall(ui.reference, "AA", "Fake lag", "Limit")
    if ok3 then ref_fakelag_limit = rl end
end

local function set_visibility()
    local on   = ui.get(ui_ref.enable)
    local baim = on and ui.get(ui_baim_lowhp)
    local sel  = baim and ui.get(ui_baim_weapons) or {}
    -- Resolver mode / Min desync / Confidence threshold теперь автоматические
    -- (детект jitter/defensive per-target внутри resolver:run). Слайдеры спрятаны.
    ui.set_visible(ui_mode_select,     false)
    ui.set_visible(ui_hitchance_boost, false)
    ui.set_visible(ui_mode,            false)
    ui.set_visible(ui_baim_lowhp,      on)
    ui.set_visible(ui_baim_weapons,    baim)
    ui.set_visible(ui_baim_hp_awp,      baim and contains(sel, "AWP"))
    ui.set_visible(ui_baim_hp_auto,     baim and contains(sel, "Auto snipers"))
    ui.set_visible(ui_baim_hp_scout,    baim and contains(sel, "Scout"))
    ui.set_visible(ui_baim_hp_deagle,   baim and contains(sel, "Deagle"))
    ui.set_visible(ui_baim_hp_revolver, baim and contains(sel, "Revolver"))
    ui.set_visible(ui_debug,           on)
    ui.set_visible(ui_debug_color,     on and ui.get(ui_debug))
    ui.set_visible(ui_logs,            on)
    ui.set_visible(ui_clantag_enable,  on)
    ui.set_visible(ui_clantag_speed,   on and ui.get(ui_clantag_enable))
    -- скрытые управляющие чекбоксы (всегда невидимы — их значение задаёт режим)
    ui.set_visible(ui_bt_assist,   false)
    ui.set_visible(ui_bt_window,   false)
    ui.set_visible(ui_adaptive,    false)
    ui.set_visible(ui_adaptive_sp, false)
    ui.set_visible(ui_pred_side,   false)
    ui.set_visible(ui_pred_pos,    false)
    ui.set_visible(ui_pred_unsafe, false)
    ui.set_visible(ui_phys,        false)
    -- видимые «общие» настройки
    ui.set_visible(ui_adaptive_fl,    on)
    ui.set_visible(ui_pred_pos_clr,   on and ui.get(ui_pred_pos))
    ui.set_visible(ui_phys_threshold, false)  -- авто, см. resolver:auto_confidence_threshold
end

-- Активирует ВСЕ детекторы из обоих пресетов одновременно. Выбор jitter vs
-- defensive теперь делается per-target внутри resolver:run через detect_aa_kind,
-- а не глобальным переключателем. Slider "Resolver mode" больше не используется.
local function apply_mode()
    ui.set(ui_mode,
        "Animlayer jitter",
        "Eye-yaw jitter",
        "Server yaw rebuild",
        "Freestanding",
        "Bruteforce on miss",
        "Defensive on choke",
        "Defensive flick",
        "On-shot zero",
        "Override pitch")
    ui.set(ui_bt_assist,   true)
    ui.set(ui_adaptive,    true)
    ui.set(ui_adaptive_sp, "Jittering", "Defensive", "No backtrack ticks")
    ui.set(ui_pred_pos,    true)
    ui.set(ui_pred_unsafe, true)
    ui.set(ui_phys,        true)  -- physics gate всегда вкл; порог авто per-target
end

-- [x]======================[ Config import/export реализация ]======================[x]
-- Список UI элементов которые сохраняются в конфиге. Кортеж: ключ + объект +
-- тип (для правильного set/get с unpack для multiselect/color).
local CONFIG_ITEMS = {
    { key = "enable",            item = ui_ref.enable,       kind = "checkbox" },
    { key = "mode_select",       item = ui_mode_select,      kind = "slider"   },
    { key = "hitchance_boost",   item = ui_hitchance_boost,  kind = "slider"   },
    { key = "baim_lowhp",        item = ui_baim_lowhp,       kind = "checkbox" },
    { key = "baim_weapons",      item = ui_baim_weapons,     kind = "multi"    },
    { key = "baim_hp_awp",       item = ui_baim_hp_awp,      kind = "slider"   },
    { key = "baim_hp_auto",      item = ui_baim_hp_auto,     kind = "slider"   },
    { key = "baim_hp_scout",     item = ui_baim_hp_scout,    kind = "slider"   },
    { key = "baim_hp_deagle",    item = ui_baim_hp_deagle,   kind = "slider"   },
    { key = "baim_hp_revolver",  item = ui_baim_hp_revolver, kind = "slider"   },
    { key = "debug",             item = ui_debug,            kind = "checkbox" },
    { key = "debug_color",       item = ui_debug_color,      kind = "color"    },
    { key = "logs",              item = ui_logs,             kind = "checkbox" },
    { key = "bt_window",         item = ui_bt_window,        kind = "slider"   },
    { key = "adaptive_fl",       item = ui_adaptive_fl,      kind = "checkbox" },
    { key = "pred_pos_clr",      item = ui_pred_pos_clr,     kind = "color"    },
    { key = "phys_threshold",    item = ui_phys_threshold,   kind = "slider"   },
}

-- Сериализуем выбранные значения в простую таблицу. JSON делается потом
-- через json.stringify (встроенный модуль gamesense).
local function build_config()
    local out = {}
    for _, it in ipairs(CONFIG_ITEMS) do
        if it.kind == "color" then
            local r, g, b, a = ui.get(it.item)
            out[it.key] = { r, g, b, a }
        elseif it.kind == "multi" then
            -- multiselect возвращает массив строк
            out[it.key] = ui.get(it.item)
        else
            out[it.key] = ui.get(it.item)
        end
    end
    return out
end

local function apply_config(cfg)
    if type(cfg) ~= "table" then return false end
    for _, it in ipairs(CONFIG_ITEMS) do
        local v = cfg[it.key]
        if v ~= nil then
            local ok = pcall(function()
                if it.kind == "color" and type(v) == "table" then
                    ui.set(it.item, v[1] or 255, v[2] or 255, v[3] or 255, v[4] or 255)
                elseif it.kind == "multi" and type(v) == "table" then
                    ui.set(it.item, unpack(v))
                else
                    ui.set(it.item, v)
                end
            end)
            -- молча игнорируем ошибки конкретных полей (например если в новой
            -- версии скрипта добавились поля которых не было в старом конфиге)
        end
    end
    return true
end

-- Реализация. Сериализация: JSON → base64 (для компактности и удобства
-- передачи). Сохранение: clipboard (если модуль доступен) + textbox в меню.
cfg_export_fn = function()
    local cfg = build_config()
    local ok, json_str = pcall(json.stringify, cfg)
    if not ok or not json_str then
        client.color_log(255, 80, 80, "[Parallax] export failed: stringify error")
        return
    end

    -- кодируем в base64 если модуль есть, иначе кладём чистый JSON
    local payload = json_str
    if base64 and base64.encode then
        payload = base64.encode(json_str)
    end

    -- кладём в системный clipboard если модуль доступен
    if clipboard and clipboard.set then
        clipboard.set(payload)
        client.color_log(0, 200, 80,
            "[Parallax] config exported to clipboard (" .. tostring(#payload) .. " bytes)")
    else
        client.color_log(255, 180, 80,
            "[Parallax] export: clipboard module unavailable")
    end
end

cfg_import_fn = function()
    -- читаем строку из буфера обмена
    if not clipboard or not clipboard.get then
        client.color_log(255, 80, 80, "[Parallax] import: clipboard module unavailable")
        return
    end
    local payload = clipboard.get()
    if not payload or payload == "" then
        client.color_log(255, 180, 80, "[Parallax] import: clipboard empty")
        return
    end

    -- декодируем: сначала пробуем base64, потом если не получилось — как чистый JSON
    local json_str = payload
    if base64 and base64.decode then
        local ok_b, decoded = pcall(base64.decode, payload)
        if ok_b and decoded and decoded ~= "" then
            json_str = decoded
        end
    end

    local ok_p, parsed = pcall(json.parse, json_str)
    if not ok_p or type(parsed) ~= "table" then
        client.color_log(255, 80, 80, "[Parallax] import failed: invalid JSON")
        return
    end

    if apply_config(parsed) then
        client.color_log(0, 200, 80, "[Parallax] config imported from clipboard")
    end
end

-- Дефолтный конфиг — base64-строка, заранее настроенная под рекомендуемые значения.
local DEFAULT_CONFIG_B64 = "eyJlbmFibGUiOnRydWUsImJhaW1faHBfcmV2b2x2ZXIiOjcyLCJiYWltX2hwX2F1dG8iOjgwLCJwaHlzX3RocmVzaG9sZCI6NDAsImJ0X3dpbmRvdyI6NSwibG9ncyI6dHJ1ZSwiYWRhcHRpdmVfZmwiOnRydWUsIm1vZGVfc2VsZWN0IjowLCJiYWltX2xvd2hwIjp0cnVlLCJwcmVkX3Bvc19jbHIiOlswLDIwMCwyNTUsMjAwXSwiZGVidWdfY29sb3IiOlsyNTUsMjE1LDAsMjU1XSwiYmFpbV9ocF9zY291dCI6OTIsImJhaW1faHBfZGVhZ2xlIjo1NSwiZGVidWciOmZhbHNlLCJiYWltX3dlYXBvbnMiOlsiQVdQIiwiQXV0byBzbmlwZXJzIiwiU2NvdXQiLCJEZWFnbGUiLCJSZXZvbHZlciJdLCJiYWltX2hwX2F3cCI6MTAwLCJoaXRjaGFuY2VfYm9vc3QiOjIwfQ=="

cfg_default_fn = function()
    if not base64 or not base64.decode then
        client.color_log(255, 80, 80, "[Parallax] default: base64 module unavailable")
        return
    end
    local ok_b, json_str = pcall(base64.decode, DEFAULT_CONFIG_B64)
    if not ok_b or not json_str then
        client.color_log(255, 80, 80, "[Parallax] default: base64 decode failed")
        return
    end
    local ok_p, parsed = pcall(json.parse, json_str)
    if not ok_p or type(parsed) ~= "table" then
        client.color_log(255, 80, 80, "[Parallax] default: JSON parse failed")
        return
    end
    if apply_config(parsed) then
        client.color_log(0, 200, 80, "[Parallax] default config applied")
    end
end

-- [x]======================[ Логи ]======================[x]
local HITGROUP_NAMES = {
    [0] = "generic",  [1] = "head",      [2] = "chest",    [3] = "stomach",
    [4] = "left arm", [5] = "right arm", [6] = "left leg", [7] = "right leg",
    [8] = "neck",     [10] = "gear",
}

local function player_name(idx)
    local name = idx and entity.get_player_name(idx)
    return name or ("player " .. tostring(idx))
end

-- CS:GO зеркалит каждую консольную строку в левый верхний угол (console notify).
-- Длительность показа задаёт квар con_notifytime. При 0 строка может мигнуть на
-- 1 кадр, поэтому используем отрицательное значение — тогда notify не рисуется
-- вообще, а в самой консоли (toggleconsole) строки остаются.
-- Форсим квар прямо перед каждым выводом: так сброс другим скриптом / раундом
-- или самой игрой не вернёт строки на экран.
local NOTIFY_HIDDEN = -1
local notifytime_saved = nil

-- Запоминает оригинал con_notifytime один раз и держит его скрытым.
local function notify_hide()
    local cv = cvar.con_notifytime
    if not cv then return end
    if notifytime_saved == nil then
        notifytime_saved = cv:get_float() or 8
    end
    cv:set_float(NOTIFY_HIDDEN)
end

-- Возвращает оригинальное значение con_notifytime (при выключении / выгрузке).
local function notify_restore()
    local cv = cvar.con_notifytime
    if cv and notifytime_saved ~= nil then
        cv:set_float(notifytime_saved)
    end
    notifytime_saved = nil
end

-- Синхронизация под чекбокс логов: включён — прячем notify, выключен — вернуть.
local function apply_notify_suppression()
    if ui.get(ui_logs) then
        notify_hide()
    else
        notify_restore()
    end
end

-- Цветной лог в консоль игры. Префикс жёлтый, дальше — цвет под событие.
-- "\0" в конце префикса не даёт color_log переносить строку.
local function reso_log(r, g, b, fmt, ...)
    if not ui.get(ui_logs) then return end
    notify_hide() -- прям���� перед выводом гарантируем, что строка не уйдёт на экран
    client.color_log(255, 215, 0, "[Parallax] \0")
    client.color_log(r, g, b, (select("#", ...) > 0) and fmt:format(...) or fmt)
end

-- [x]======================[ Резольвер ]======================[x]
-- ОПТИМИЗАЦИЯ ПАМЯТИ: Ограничения на размеры таблиц
local MAX_PLAYERS_TRACKED = 20  -- Максимум игроков в кэше одновременно
local MAX_HISTORY_PER_PLAYER = 12  -- Уменьшено с 16 до 12
local MAX_AIMBOT_DATA = 16  -- Уменьшено с 64 до 16
local MAX_IMPACT_DATA = 50  -- Уменьшено с 150 до 50

local resolver = {
    -- per-player статистика и состояние
    data    = {},   -- [idx] = { miss, hit, shots, last_side, side_count, state, last_yaw }
    records = {},   -- [idx] = { [simtime] = {...} }
}

-- ОПТИМИЗАЦИЯ ПАМЯТИ: Агрессивная очистка всех данных
function resolver:reset()
    -- Очищаем таблицы правильно (nil каждый ключ)
    if self.data then
        for k in pairs(self.data) do
            self.data[k] = nil
        end
    end
    if self.records then
        for k in pairs(self.records) do
            self.records[k] = nil
        end
    end
    
    self.data    = {}
    self.records = {}
    
    -- Очищаем plist_cache
    if plist_cache then
        for k in pairs(plist_cache.fby) do plist_cache.fby[k] = nil end
        for k in pairs(plist_cache.fby_val) do plist_cache.fby_val[k] = nil end
        for k in pairs(plist_cache.corr) do plist_cache.corr[k] = nil end
        for k in pairs(plist_cache.baim) do plist_cache.baim[k] = nil end
        for k in pairs(plist_cache.sp) do plist_cache.sp[k] = nil end
    end
    plist_cache = { fby = {}, fby_val = {}, corr = {}, baim = {}, sp = {} }
    
    -- Принудительная сборка мусора
    collectgarbage("collect")
end

-- ОПТИМИЗАЦИЯ ПАМЯТИ: Ограничение количества отслеживаемых игроков
function resolver:get_data(idx)
    if not self.data[idx] then
        -- Проверяем лимит игроков в кэше
        local count = 0
        for _ in pairs(self.data) do count = count + 1 end
        
        if count >= MAX_PLAYERS_TRACKED then
            -- Удаляем самого старого игрока (по last_simtime)
            local oldest_idx, oldest_time = nil, math.huge
            for k, v in pairs(self.data) do
                local time = v.last_simtime or 0
                if time < oldest_time then
                    oldest_time = time
                    oldest_idx = k
                end
            end
            if oldest_idx then
                -- Очищаем данные старого игрока
                self.data[oldest_idx] = nil
                pcall(clear_player, oldest_idx)
            end
        end
        
        self.data[idx] = {
            miss = 0, hit = 0, shots = 0,
            side = 1, side_count = 0, pending_side = 1,
            state = "init", last_yaw = 0, temp_pitch = 0,
            yaw_cache = {}, yaw_idx = 0, jittering = false, jitter_diff = 0,
            -- backtrack history (уменьшенный разм��р)
            history = {},
            last_simtime = nil,
            bt_ticks = 0,
            -- [#1] LBY flip detect
            lby_last      = nil,
            lby_flip_at   = nil,
            lby_flip_side = nil,
            -- [#2] sliding window scoring
            score_left  = 0,
            score_right = 0,
            -- [#3] onshot snapshot
            honest_eye   = nil,
            honest_state = nil,
            honest_at    = nil,
            -- [new#1] velocity-aware desync
            decel_freeze_until = 0,
            -- [new#5] AA correction snapshot
            calibrated_diff = nil,
            calibrated_at   = 0,
            -- [new#6] defensive choke spike detect
            choke_history = {},
            -- [DEF2] sticky defensive window: тик до которого считаем цель в defensive,
            -- даже если choke уже временно упал. Заполняется при детекте choke spike.
            def_window_until = 0,
            -- [DEF2] honest eye_yaw в последнем clean кадре перед choke spike — якорь,
            -- к которому враг обязан вернуться при выходе из defensive.
            def_pre_eye      = nil,
            def_pre_eye_at   = 0,
            -- [DEF3] счётчик миссов СТРОГО внутри defensive окна — отдельно от data.miss,
            -- чтобы в обычных условиях брут не дёргался от defensive промахов.
            def_miss         = 0,
            def_last_miss_at = 0,
            -- [DEF3] tick до которого держим инверс стороны после defensive miss
            def_invert_until = 0,
            -- [S2] animlayer 3+6 cross-check
            layer_side = 0, layer_at = 0,
            -- [S3] pose param 11 raw body_yaw
            pose_side = 0, pose_at = 0,
            -- [A5] velocity-vs-eye delta
            vel_side = 0, vel_at = 0,
            -- [A7] adaptive bruteforce phase ordering
            phase_success = {},
            last_brute_state = nil,
            last_brute_phase = nil,
            last_brute_at    = 0,
            -- [S4] per-steamid profile persistence
            db_loaded = false,
            steamid64 = nil,
            -- [B11] hitchance auto-boost
            hc_boost_until = 0,
            hc_boost_active = false,
        }
        -- [S4] lazily load persisted profile (no-op if database API unavailable)
        pcall(function() if _G.db_load_profile then _G.db_load_profile(idx, self.data[idx]) end end)
    end
    return self.data[idx]
end

-- [3] Сбор истории по серверным апдейтам цели. Один реальный апдейт = новый
-- m_flSimulationTime. Храним последние N записей (углы + позиция + simtime),
-- по ним считаем доступные тики бэктрека и стабилизируем детект стороны.
-- ОПТИМИЗАЦИЯ ПАМЯТИ: Уменьшен размер истории
local HISTORY_MAX = MAX_HISTORY_PER_PLAYER
-- ЗАЩИТА ОТ КРАША: Безопасный сбор истории с валидацией всех данных
function resolver:update_history(idx)
    if not idx or idx < 1 or idx > 64 then return end
    
    local data = self:get_data(idx)
    if not data then return end
    
    -- Защищенное чтение всех props через pcall
    local success = pcall(function()
        local simtime = entity.get_prop(idx, "m_flSimulationTime")
        if not simtime or type(simtime) ~= "number" then return end

        -- новый апдейт только если simtime изменился (иначе это choked-кадр)
        if data.last_simtime == simtime then return end
        data.last_simtime = simtime

        local _, eye_yaw = entity.get_prop(idx, "m_angEyeAngles")
        local st         = get_anim_state(idx)
        local x, y, z    = entity.get_prop(idx, "m_vecOrigin")
        local lby        = entity.get_prop(idx, "m_flLowerBodyYawTarget")
        local vx, vy     = entity.get_prop(idx, "m_vecVelocity")
        local vel2d      = (vx and vy) and math_sqrt(vx * vx + vy * vy) or 0

        -- [#1] LBY flip detect: если LBY скакнул заметно — это «честный» feet yaw
        -- цели (CSGO выравнивает его раз в ~1.1с). Запоминаем сторону отклонения
        -- от текущего eye_yaw — это рабочая подсказка о реальной стороне desync.
        if lby and data.lby_last and eye_yaw then
            local delta = math_abs(normalize_yaw(lby - data.lby_last))
            if delta > 35 then
                data.lby_flip_at = globals.curtime()
                local diff = normalize_yaw(eye_yaw - lby)
                data.lby_flip_side = diff > 0 and 1 or -1
            end
        end
        data.lby_last = lby

        -- [new#1] velocity-aware: если цель резко тормозит (>200 ед/с между
        -- серверными апдейтами), ~4 кадра в анимациях есть переход, в котором
        -- desync временно слетает в 0. Замораживаем сторону на это окно, чтобы
        -- не дёргать угол на ровном месте.
        local prev_vel = data.history[1] and data.history[1].vel2d or vel2d
        if prev_vel - vel2d > 200 then
            data.decel_freeze_until = globals.tickcount() + 4
        end

        -- [new#6] choke spike: храним последние 4 значения target choke. Если в
        -- последнем тике произошёл резкий скачок (с 0-1 на 6+), считаем это
        -- defensive aimbot, а не обычным fakelag.
        local cur_choke = get_choked_packets(idx)
        local prev_choke = data.choke_history[1] or 0
        table.insert(data.choke_history, 1, cur_choke)
        while #data.choke_history > 6 do table.remove(data.choke_history) end

        -- [DEF2] pre-defensive eye anchor: запоминаем eye_yaw в последнем кадре
        -- ПЕРЕД скачком choke. На выходе из defensive реальный body должен
        -- быть выровнен примерно по этому yaw — это «честная» точка отсчёта.
        if prev_choke <= 1 and cur_choke >= 5 and eye_yaw then
            data.def_pre_eye    = eye_yaw
            data.def_pre_eye_at = globals.curtime()
            -- sticky window: держим defensive статус ещё ~choke+8 тиков после спайка
            data.def_window_until = globals.tickcount() + math_min(cur_choke + 8, 22)
        elseif cur_choke >= 5 then
            -- продлеваем окно пока choke остаётся высоким
            data.def_window_until = math_max(data.def_window_until or 0,
                                              globals.tickcount() + math_min(cur_choke + 4, 18))
        end

        -- ОПТИМИЗАЦИЯ ПАМЯТИ: Удаляем старые записи перед добавлением новой
        if #data.history >= HISTORY_MAX then
            table.remove(data.history)  -- Удаляем самую старую
        end
        
        table.insert(data.history, 1, {
            simtime   = simtime,
            eye_yaw   = eye_yaw or 0,
            goal_feet = st and st.m_flGoalFeetYaw or (eye_yaw or 0),
            x = x, y = y, z = z,
            lby       = lby,
            vel2d     = vel2d,
            tick      = to_ticks(simtime),
        })

        -- сколько тиков бэктрека реально доступно: ограничение sv_maxunlag (~0.2с)
        -- минус задержка сети, переведённое в тики
        local max_unlag = 0.2
        if cvar.sv_maxunlag then
            local ok, val = pcall(cvar.sv_maxunlag.get_float, cvar.sv_maxunlag)
            if ok and val then max_unlag = val end
        end
        local window = math_min(to_ticks(max_unlag), ui.get(ui_bt_window))
        local newest = data.history[1].simtime
        local valid  = 0
        for i = 1, #data.history do
            if (newest - data.history[i].simtime) <= max_unlag then
                valid = valid + 1
            end
        end
        data.bt_ticks = clamp(valid - 1, 0, window) -- -1: самый свежий тик это "сейчас"
    end)
    
    if not success then
        -- Тихо игнорируем ошибки сбора истории, не роняя весь resolver
    end
end

-- Возвращает сторону desync, усреднённую по истории бэктрека (стабильнее, чем
-- мгновенный кадр). nil, если истории мало или нет анимстейта.
function resolver:history_side(idx)
    local data = self:get_data(idx)
    if #data.history < 3 then return nil end

    local st = get_anim_state(idx)
    if st == nil then return nil end

    -- средний eye_yaw по истории через atan2(sin, cos)
    local sx, sy, n = 0, 0, 0
    for i = 1, math_min(#data.history, 6) do
        local h = data.history[i]
        if h.eye_yaw then
            sx = sx + math_cos(math_rad(h.eye_yaw))
            sy = sy + math_sin(math_rad(h.eye_yaw))
            n  = n + 1
        end
    end
    if n == 0 then return nil end

    local avg_eye = math_deg(math_atan2(sy / n, sx / n))
    local diff    = normalize_yaw(st.m_flGoalFeetYaw - avg_eye)
    if diff == 0 then return nil end
    return diff > 0 and 1 or -1
end

-- [2] Предикт позиции цели через `latency + choked_ticks`.
-- Линейная экстраполяция по m_vecVelocity с учётом стояния на земле (трение),
-- воздуха (гравитация). Возвращает (x, y, z, reliable_bool).
-- reliable=false если цель резко меняет н��п��авление или скорость, или мы давно
-- не получали серверных апдейтов — в эти моменты предикт ненадёжен.
-- ЗАЩИТА ОТ КРАША: Безопасное чтение всех props
function resolver:predict_position(idx)
    if not idx or idx < 1 or idx > 64 then return nil end
    
    local success, x, y, z, reliable = pcall(function()
        local px, py, pz = entity.get_prop(idx, "m_vecOrigin")
        if not px or not py or not pz then return nil end

        local vx, vy, vz = entity.get_prop(idx, "m_vecVelocity")
        vx, vy, vz = vx or 0, vy or 0, vz or 0

        local flags     = entity.get_prop(idx, "m_fFlags") or 0
        local on_ground = bit.band(flags, 1) ~= 0

        -- сколько секунд экстраполировать: пинг + choked-пакеты цели
        local lat   = client.latency() or 0
        local choke = get_choked_packets(idx) or 0
        local dt    = lat + (choke * globals.tickinterval())
        if dt <= 0 then return px, py, pz, true end
        dt = math_min(dt, 0.4) -- ограничим максимум 0.4с

        -- определяем надёжность
        local data = self:get_data(idx)
        local reliable_flag = true
        if data and #data.history >= 3 then
            local newest = data.history[1]
            if newest and (globals.curtime() - newest.simtime) > 0.3 then
                reliable_flag = false
            end
        end
        
        if reliable_flag and data and #data.history >= 2 then
            local speed2d = math_sqrt(vx * vx + vy * vy)
            if speed2d > 50 and choke > 0 then
                reliable_flag = false
            end
        end

        -- сама экстраполяция
        local pred_x = px + vx * dt
        local pred_y = py + vy * dt
        local pred_z
        if on_ground then
            pred_z = pz + vz * dt
        else
            local g = 800
            if cvar.sv_gravity then
                local ok, val = pcall(cvar.sv_gravity.get_float, cvar.sv_gravity)
                if ok and val then g = val end
            end
            pred_z = pz + vz * dt - 0.5 * g * dt * dt
        end
        return pred_x, pred_y, pred_z, reliable_flag
    end)
    
    if not success then return nil end
    return x, y, z, reliable
end

-- [physics] Полный source-physics predictor: friction на земле, gravity в
-- воздухе, sv_stopspeed, проверка коллизий через trace_line.
-- Возвращает (px, py, pz, reliable_bool).
function resolver:physics_predict(idx, dt)
    local x, y, z = entity.get_prop(idx, "m_vecOrigin")
    if not x then return nil end

    local vx, vy, vz = entity.get_prop(idx, "m_vecVelocity")
    vx, vy, vz = vx or 0, vy or 0, vz or 0

    local flags = entity.get_prop(idx, "m_fFlags") or 0
    local on_ground = bit.band(flags, 1) ~= 0

    local sv_friction  = 5.2
    local sv_stopspeed = 75
    local sv_gravity   = 800
    if cvar.sv_friction  then sv_friction  = cvar.sv_friction:get_float()  or 5.2 end
    if cvar.sv_stopspeed then sv_stopspeed = cvar.sv_stopspeed:get_float() or 75 end
    if cvar.sv_gravity   then sv_gravity   = cvar.sv_gravity:get_float()   or 800 end

    local ti    = globals.tickinterval()
    local steps = math_min(math_floor(dt / ti + 0.5), 32)
    local px, py, pz = x, y, z

    for _ = 1, steps do
        if on_ground then
            local speed = math_sqrt(vx * vx + vy * vy)
            if speed > 0 then
                local control = (speed < sv_stopspeed) and sv_stopspeed or speed
                local drop    = control * sv_friction * ti
                local newspeed = math_max(0, speed - drop)
                local scale = newspeed / speed
                vx = vx * scale
                vy = vy * scale
            end
        else
            vz = vz - sv_gravity * ti
        end
        px = px + vx * ti
        py = py + vy * ti
        pz = pz + vz * ti
    end

    -- ограничение коллизией с миром
    local frac = client.trace_line(idx, x, y, z + 32, px, py, pz + 32)
    if frac and frac < 1 then
        local f = frac * 0.95
        px = x + (px - x) * f
        py = y + (py - y) * f
        pz = z + (pz - z) * f
    end

    local reliable = not (frac and frac < 0.7)
    if (get_choked_packets(idx) or 0) >= 4 then reliable = false end

    return px, py, pz, reliable
end

-- [confidence] 0..1 — уверенность в текущем резолве. Сумма свежих подсказок.
function resolver:confidence(idx)
    local data = self:get_data(idx)
    local now  = globals.curtime()
    local conf = 0
    if data.lby_flip_at and (now - data.lby_flip_at) <= 1.5 then
        conf = conf + 0.4
    end
    if data.honest_at and (now - data.honest_at) <= 0.4 then
        conf = conf + 0.5
    end
    if data.calibrated_at and (now - data.calibrated_at) <= 8 then
        conf = conf + 0.4
    end
    local s_max = math_max(data.score_left or 0, data.score_right or 0)
    if s_max >= 1 then conf = conf + 0.2 end
    return math_min(1, conf)
end

-- Стабилизация стороны (идея vandalresolverv2): сторона переключается только
-- после 2 подтверждений подряд, иначе детекторы дёргают угол от шума каждый тик.
local SIDE_CONFIRM = 2
function resolver:commit_side(idx, new_side)
    local data = self:get_data(idx)
    if new_side == data.side then
        data.side_count = 0
        return data.side
    end
    if new_side == data.pending_side then
        data.side_count = (data.side_count or 0) + 1
    else
        data.pending_side = new_side
        data.side_count = 1
    end
    if data.side_count >= SIDE_CONFIRM then
        data.side = new_side
        data.side_count = 0
    end
    return data.side
end

-- Детект джиттера по буферу eye-yaw (подход ! 10$ / ! 15 / KostaTeam).
-- Возвращает угол со знаком стороны, либо nil если игрок не джиттерит.
local JITTER_BUFFER = 10
function resolver:resolve_eye_jitter(idx)
    local data = self:get_data(idx)
    local _, eye_yaw = entity.get_prop(idx, "m_angEyeAngles")
    if not eye_yaw then return nil end

    -- складываем в кольцевой буфер
    data.yaw_cache[data.yaw_idx % JITTER_BUFFER] = eye_yaw
    data.yaw_idx = (data.yaw_idx >= JITTER_BUFFER + 1) and 0 or (data.yaw_idx + 1)

    local max_desync = get_max_desync(idx)
    local norm = max_desync > 0 and (max_desync / 58) or 1

    -- ищем максимальную разницу между текущим и прошлыми углами
    local cur = data.yaw_cache[data.yaw_idx % JITTER_BUFFER]
    local biggest = 0
    for i = 0, JITTER_BUFFER - 1 do
        local v = data.yaw_cache[i]
        if v and cur then
            local d = math_abs(normalize_yaw(v - cur))
            if d > biggest then biggest = d end
        end
    end

    data.jitter_diff = biggest
    data.jittering   = biggest >= ((data.abab_pattern and 25.0 or 35.0) * norm)

    if not data.jittering or get_choked_packets(idx) >= 3 then
        return nil
    end

    -- усредняем два последних угла через atan2(sin, cos) и берём сторону отклонения
    local a1 = normalize_yaw(data.yaw_cache[(JITTER_BUFFER - 1) % JITTER_BUFFER] or eye_yaw)
    local a2 = normalize_yaw(data.yaw_cache[(JITTER_BUFFER - 2) % JITTER_BUFFER] or eye_yaw)
    local avg = math_deg(math_atan2(
        (math_sin(math_rad(a1)) + math_sin(math_rad(a2))) / 2,
        (math_cos(math_rad(a1)) + math_cos(math_rad(a2))) / 2))

    local st = get_anim_state(idx)
    local eye_state = st and st.m_flEyeYaw or eye_yaw
    local diff = normalize_yaw(eye_state - avg)
    local sign = diff > 0 and 1 or -1
    local side = (diff ~= 0) and self:commit_side(idx, sign) or data.side

    -- [PARALLAX] Defensive Flick Killer (HIGHEST priority)
    -- Аддон обнаружил defensive flick — реальный body на противоположной стороне eye flick
    if data.flick_kill_side and data.flick_kill_side ~= 0 then
        side = data.flick_kill_side
        -- усиливаем magnitude — флик это всегда 35-58° desync
        return clamp(math_abs(diff) * norm, 35, 58) * side
    end

    -- [PARALLAX] latency-compensated side override (из Althea, очищен от рандома)
    -- Если аддон предсказал сторону с учётом пинга — используем её вместо геометрической
    if data.latency_jitter_side and data.latency_jitter_side ~= 0 then
        side = data.latency_jitter_side
    end

    return clamp(math_abs(diff) * norm, 10, 60) * side
end

-- Определение текущего "режима" движения цели.
-- Расширенный детект состояния цели. Возвращает (state, speed).
-- Состояния:
--   standing      — на земле, скорость ~0 (полный desync, jitter-детекторы)
--   slowwalk      — на земле, 1..34 u/s (shift или slow-walk AA)
--   walking       — на земле, 34..80 u/s (обычная ходьба, desync уже сужается)
--   running       — на земле, >80 u/s (desync схлопывается к ~20°)
--   crouch        — на земле + duck, скорость ~0 (максимальный desync, choke=0)
--   crouch_walk   — на земле + duck, есть скорость (редко, но AA любит так)
--   air           — в воздухе без duck (нет LBY, goal_feet полностью клиентский)
--   air_duck      — в воздухе + duck (самое мерзкое: airstuck + jitter)
-- ============================================================================
-- TIER S/A/B HELPERS (pose param, animlayer cross, vel-eye, db profile)
-- ============================================================================

-- [S3] pose param 11 (m_flPoseParameter[11]) = "body_yaw" в animset, диапазон
-- 0..1, 0.5 = нейтраль. Не зависит от LBY/goal_feet — хранит знак desync
-- напрямую. Если индексный get_prop в твоей сборке не работает — pcall глушит.
local function read_pose_yaw_side(idx)
    local ok, v = pcall(entity.get_prop, idx, "m_flPoseParameter", 11)
    if not ok or type(v) ~= "number" then return 0 end
    local centered = v - 0.5
    if math_abs(centered) < 0.04 then return 0 end -- мёртвая зона ~7°
    return centered > 0 and 1 or -1
end

-- [S2] animlayer 3 (feet rotation) + layer 6 (lean) cross-check. Layer 6
-- weight дискретно скачет ~0.29/0.30 при джитере (см. resolve_jitter — там
-- тот же приём). Layer 3 playback rate знаком указывает направление вращения
-- ног, противоположное направлению desync'а.
local function read_layer_side(idx)
    local l3 = get_anim_layer(idx, 3)
    local l6 = get_anim_layer(idx, 6)
    if not l6 then return 0 end
    local w6 = l6.m_flWeight or 0
    -- layer 6 weight: дискретные значения
    local pair = tonumber(("%d%d"):format(frac_digit(w6, 4), frac_digit(w6, 5)))
    if pair == 29 then return -1 end
    if pair == 30 then return  1 end
    -- fallback: знак playback rate layer 3 (если очень большой)
    if l3 then
        local pr = l3.m_flPlaybackRate or 0
        if pr >  1.2 then return  1 end
        if pr < -1.2 then return -1 end
    end
    return 0
end

-- [A5] velocity-vs-eye delta. Когда враг страфит/бежит, eye_yaw физически
-- ограничен ~90° от направления движения (страфейка). Отклонение БОЛЬШЕ 90°
-- = desync. Знак отклонения = сторона.
local function read_velocity_side(idx)
    local vx, vy = entity.get_prop(idx, "m_vecVelocity")
    if not vx or not vy then return 0 end
    local speed = math_sqrt(vx * vx + vy * vy)
    if speed < 35 then return 0 end -- слоувок/стоит — нет надёжного направления
    local _, eye_yaw = entity.get_prop(idx, "m_angEyeAngles")
    if not eye_yaw then return 0 end
    local vel_dir = math.deg(math.atan2(vy, vx))
    local diff    = normalize_yaw(eye_yaw - vel_dir)
    if math_abs(diff) < 95 then return 0 end
    return diff > 0 and 1 or -1
end

-- [S4] per-SteamID профиль через neverlose `database` API. pcall на всё —
-- если API нет (gamesense vanilla), молча отвалится.
local function _profile_key(sid)
    return string.format("relaxia_resolver_v2/%s", tostring(sid))
end

local function db_load_profile(idx, rdata)
    if not rdata or rdata.db_loaded then return end
    rdata.db_loaded = true
    local ok, sid = pcall(entity.get_steam64, idx)
    if not ok or not sid or sid == "0" then return end
    rdata.steamid64 = sid
    local ok2, blob = pcall(database.read, _profile_key(sid))
    if not ok2 or type(blob) ~= "table" then return end
    rdata.score_left  = tonumber(blob.score_left)  or rdata.score_left  or 0
    rdata.score_right = tonumber(blob.score_right) or rdata.score_right or 0
    if type(blob.phase_success) == "table" then
        rdata.phase_success = blob.phase_success
    end
end
_G.db_load_profile = db_load_profile -- экспорт для get_data

local function db_save_profile(rdata)
    if not rdata or not rdata.steamid64 then return end
    pcall(database.write, _profile_key(rdata.steamid64), {
        score_left    = rdata.score_left    or 0,
        score_right   = rdata.score_right   or 0,
        phase_success = rdata.phase_success or {},
    })
end

-- [B11] hitchance auto-boost через playerlist. Разные читы — разные имена
-- (gamesense: "Hit chance", neverlose: "Override hit chance" + "Hit chance").
-- Все варианты под pcall, если не работает — тихий no-op.
local function apply_hc_boost(idx, on)
    if on then
        pcall(plist.set, idx, "Override hit chance", true)
        pcall(plist.set, idx, "Hit chance", 95)
        pcall(plist.set, idx, "Hitchance", 95)
    else
        pcall(plist.set, idx, "Override hit chance", false)
        pcall(plist.set, idx, "Hit chance", nil)
        pcall(plist.set, idx, "Hitchance", nil)
    end
end

function resolver:get_state(idx)
    local vx, vy = entity.get_prop(idx, "m_vecVelocity")
    if not vx then return "standing", 0 end
    local speed = math_sqrt(vx * vx + vy * vy)
    local flags = entity.get_prop(idx, "m_fFlags") or 0
    local on_ground = bit.band(flags, 1) ~= 0
    local ducking   = bit.band(flags, 2) ~= 0

    -- FL_DUCKING взводится только в конце дак-анимации. Подкрепляем чтением
    -- m_fDuckAmount: всё что > 0.55 уже даёт полный crouch-desync. Без этого
    -- mid-duck AA проскакивал бы как "standing".
    if not ducking then
        local st = get_anim_state(idx)
        if st then
            local ok, da = pcall(function() return st.m_fDuckAmount end)
            if ok and da and da > 0.55 then ducking = true end
        end
    end

    if not on_ground then
        return ducking and "air_duck" or "air", speed
    end
    if ducking then
        return (speed < 5) and "crouch" or "crouch_walk", speed
    end
    if speed < 1.1 then
        return "standing", speed
    elseif speed <= 34 then
        return "slowwalk", speed
    elseif speed <= 80 then
        return "walking", speed
    else
        return "running", speed
    end
end

-- Чтение сторо��ы desync из анимслоёв (подход custom_resolver_gs).
function resolver:resolve_jitter(idx)
    local layer = get_anim_layer(idx, 6)
    if layer == nil then return nil end

    local playback = layer.m_flPlaybackRate
    local weight   = layer.m_flWeight

    -- собираем "цифры" дробной части playback rate, как делает custom_resolver
    local d3 = frac_digit(playback, 3)
    local right = frac_digit(playback, 4) + frac_digit(playback, 5)
                + frac_digit(playback, 6) + frac_digit(playback, 7)
    local left  = frac_digit(playback, 6) + frac_digit(playback, 7)
                + frac_digit(playback, 8) + frac_digit(playback, 9)

    local desync
    if d3 == 0 then
        desync = -3.4117 * left + 98.9393
    else
        desync = -3.4117 * right + 98.9393
    end

    if desync >= 60 or desync < 0 then
        desync = get_max_desync(idx)
    end

    -- определяем сторону по весу слоя (со стабилизацией)
    local data = self:get_data(idx)
    if frac_digit(weight, 1) == 9 then
        local pair = tonumber(("%d%d"):format(frac_digit(weight, 4), frac_digit(weight, 5)))
        if pair == 29 then
            self:commit_side(idx, -1)
        elseif pair == 30 then
            self:commit_side(idx, 1)
        end
    end

    return clamp(math_abs(round(desync)), 0, 60) * data.side
end

-- Freestanding через трейсы (подход kent_resolver, упрощён).
function resolver:resolve_freestand(idx)
    local me = entity.get_local_player()
    if not me then return nil end

    local ex, ey, ez = entity.hitbox_position(idx, 0) -- head
    if not ex then return nil end
    ez = ez - 4 -- чуть ниже головы, ближе к глазам

    local lx, ly, lz = entity.get_prop(me, "m_vecOrigin")
    if not lx then return nil end

    -- угол от цели к локальному игроку
    local base_yaw = math_deg(math_atan2(ly - ey, lx - ex))

    local trace = { left = 0, right = 0 }
    for offset = -90, 90, 30 do
        if offset ~= 0 then
            local rad = math_rad(base_yaw + offset)
            local sx = ex + 40 * math_cos(rad)
            local sy = ey + 40 * math_sin(rad)
            local dx = ex + 200 * math_cos(rad)
            local dy = ey + 200 * math_sin(rad)
            local frac = client.trace_line(idx, sx, sy, ez, dx, dy, ez)
            if offset < 0 then
                trace.left = trace.left + (frac or 0)
            else
                trace.right = trace.right + (frac or 0)
            end
        end
    end

    -- больше "открытого" пространства = туда повёрнута фейк-сторона
    local max = get_max_desync(idx)
    if max <= 0 then max = 58 end
    return (trace.left > trace.right) and -max or max
end

-- Per-state фазовые таблицы для bruteforce.
-- Числа — множитель max desync, знак относительно seed_sign (см. ниже).
-- Логика подбиралась под характер каждого состояния:
--   standing/crouch — широкий поиск, начинаем с экстремумов
--   running          — на бегу desync минимальный, бьём в 0 / небольшие отклонения
--   slowwalk/walking — промежуточные углы заходят чаще
--   air/air_duck     — экстремумы + 0, потому что engine клампит goal_feet
local BRUTE_PHASES = {
    standing    = {  1.00, -1.00,  0.50, -0.50,  0.75, -0.75,  0.00,  1.00 },
    slowwalk    = {  1.00, -1.00,  0.85, -0.85,  0.60, -0.60,  0.30, -0.30 },
    walking     = {  1.00, -1.00,  0.70, -0.70,  0.40, -0.40,  0.00 },
    running     = {  0.00,  0.35, -0.35,  0.60, -0.60,  1.00, -1.00 },
    crouch      = {  1.00, -1.00,  0.95, -0.95,  0.80, -0.80 },
    crouch_walk = {  1.00, -1.00,  0.80, -0.80,  0.55, -0.55,  0.30, -0.30 },
    air         = {  1.00, -1.00,  0.00,  0.60, -0.60,  0.85, -0.85 },
    air_duck    = {  1.00, -1.00,  0.85, -0.85,  0.55, -0.55,  0.30, -0.30,  0.00 },
    -- [DEF1] defensive: AA в defensive окне свингует экстремумами ±max и 0.
    -- ВНИМАНИЕ: phase[1] здесь намеренно ОТРИЦАТЕЛЬНЫЙ от seed_sign — статистически
    -- defensive miss летит в противоположную последней удачной сторону, поэтому
    -- первый брут после defensive миссы сразу прыгает на инверс.
    defensive   = { -1.00,  1.00,  0.00, -0.85,  0.85, -0.55,  0.55 },
}

-- Bruteforce v2: state-aware + seed по последней успешной стороне.
-- Старая версия выдавала одни и те же 4 угла на любого противника. Здесь
-- таблица фаз выбирается по реальному состоянию цели в этом тике, а первый
-- знак берётся из data.side (��сли был хит — первый промах летит в "знакомую"
-- сторону, не вслепую). Совместимо со старым вызовом resolve_bruteforce(idx, base).
function resolver:resolve_bruteforce(idx, base)
    local data  = self:get_data(idx)
    local max   = get_max_desync(idx)
    if max <= 0 then max = 58 end

    local state = data.state or self:get_state(idx)
    local key   = (type(state) == "string") and state:match("^[%a_]+") or "standing"

    -- [DEF1] defensive override: если цель сейчас (или только что была) в
    -- defensive окне, используем defensive-таблицу фаз вместо state-таблицы.
    -- Эта таблица заточена под AA, который свингует экстремумами ±max.
    if (data.aa_kind == "defensive") or self:is_defensive(idx) or self:exited_defensive(idx) then
        key = "defensive"
    end

    local base_tbl = BRUTE_PHASES[key] or BRUTE_PHASES.standing

    -- [A7] adaptive phase ordering: каждая фаза [state][i] имеет счётчик успехов
    -- (увеличивается в on_aim_hit). При вызове сортируем индексы фаз по убыванию
    -- успехов — после ~20 попаданий резольвер сам поймёт какие multipliers рабочие.
    data.phase_success = data.phase_success or {}
    data.phase_success[key] = data.phase_success[key] or {}
    local ps = data.phase_success[key]

    local order = {}
    for i = 1, #base_tbl do order[i] = i end
    table.sort(order, function(a, b)
        local sa, sb = ps[a] or 0, ps[b] or 0
        if sa ~= sb then return sa > sb end
        return a < b -- стабильная сортировка при равенстве
    end)

    local seed_sign = data.side
    if seed_sign == nil or seed_sign == 0 then
        seed_sign = (base ~= nil and base >= 0) and 1 or -1
    end

    -- [DEF3] если только что промахнулись внутри defensive — инвертируем seed,
    -- чтобы первый брут после defensive миссы летел в противоположную сторону
    -- (defensive AA любит флипать body_yaw при выходе из choke spike).
    if key == "defensive" and globals.tickcount() < (data.def_invert_until or 0) then
        seed_sign = -seed_sign
    end

    -- [DEF3] на defensive миссы продвигаемся по фазам быстрее: каждая def_miss
    -- тоже считается, а не только обычные. Это ускоряет перебор когда враг
    -- свингует.
    local effective_miss = data.miss + (key == "defensive" and (data.def_miss or 0) or 0)
    local cycle_i = ((math_max(effective_miss, 1) - 1) % #order) + 1
    local phase_i = order[cycle_i]
    local mult    = base_tbl[phase_i]
    local angle
    if mult == 0 then
        angle = 0
    else
        angle = mult * max * seed_sign
    end

    if angle ~= 0 then
        self:commit_side(idx, angle >= 0 and 1 or -1)
    end

    -- запоминаем что именно сейчас стреляем — для on_aim_hit (адаптация порядка)
    data.last_brute_state = key
    data.last_brute_phase = phase_i
    data.last_brute_at    = globals.tickcount()

    return clamp(round(angle), -60, 60)
end

-- [new#6] Detection: defensive aimbot vs обычный fakelag. Defensive — это
-- когда choke у цели резко скакнул прямо перед выстрелом (с ≤1 на ≥6 за
-- 1-2 тика). Стабильный fakelag (постоянный choke 2-3) сюда не попадает.
-- Авто-детект типа anti-aim противника. Возвращает "defensive" | "jitter" | "static".
-- Используется для авто-выбора min_desync, confidence threshold и стратегии резолва.
-- Detection держится 1.5с после последнего срабатывания (чтобы не дёргать на шуме).
function resolver:detect_aa_kind(idx)
    local data = self:get_data(idx)
    local now  = globals.curtime()

    -- [MERU] 0) Simtime-based defensive (наивысший приоритет): враг чокает simtime
    if data.in_def_sim then
        data.aa_kind_cached  = "defensive"
        data.aa_kind_at      = now
        return "defensive"
    end

    -- 1) Defensive: choke spike (свежий или только что вышли) — высший приоритет.
    if self:is_defensive(idx) or self:exited_defensive(idx) then
        data.aa_kind_cached  = "defensive"
        data.aa_kind_at      = now
        return "defensive"
    end

    -- 2) Jitter: data.jittering флаг проставляется в resolve_eye_jitter
    --    (вызывается всегда в начале run для побочного эффекта).
    --    Дополнительно проверяем что choke стабильно низкий — иначе это defensive с jitter-маской.
    if data.jittering and (get_choked_packets(idx) or 0) <= 2 then
        data.aa_kind_cached  = "jitter"
        data.aa_kind_at      = now
        return "jitter"
    end

    -- 3) Анти-шум: 1.5 сек удерживаем последний детект.
    if data.aa_kind_cached and data.aa_kind_at and (now - data.aa_kind_at) <= 1.5 then
        return data.aa_kind_cached
    end

    data.aa_kind_cached = "static"
    return "static"
end

function resolver:is_defensive(idx)
    local data = self:get_data(idx)
    local h = data.choke_history
    if #h < 2 then return false end

    -- [DEF2] sticky: окно ещё не истекло — считаем цель в defensive даже если
    -- choke уже временно упал (между скачками). Без этого мы выходили из
    -- defensive-режима через 1 тик и снова палили обычной логикой.
    if globals.tickcount() < (data.def_window_until or 0) then
        return true
    end

    local cur  = h[1] or 0
    local prev = h[2] or 0
    -- свежий choke стал большим, а недавно был маленьким
    if cur >= 6 and prev <= 1 then return true end
    -- вариант: за 2 тика накопилось много (с 0/1 → 4 → 8)
    if cur >= 6 and (h[3] or 0) <= 1 then return true end
    -- [DEF2] устойчивый высокий choke (≥5 три кадра подряд) — это тоже defensive,
    -- а не просто fakelag. Лагающий fakelag даёт choke 2-3, не 5+ стабильно.
    if cur >= 5 and prev >= 5 and (h[3] or 0) >= 5 then return true end
    return false
end

-- [new#1] Цель се��час в окне «freeze»: только что резко затормозила, и
-- держим сторону неизменной несколько тиков, не давая детекторам её крутить.
function resolver:in_decel_freeze(idx)
    local data = self:get_data(idx)
    return globals.tickcount() < (data.decel_freeze_until or 0)
end

-- [new#7] Defensive flick detector + resolver.
-- Паттерн (взят из lunaris self code → defensive_flick AA):
--   В defensive окне (choke spike) yaw це��и прыгает между yaw_left и yaw_right
--   через случайный delay → большой скачок (>50°) eye_yaw в истории.
--   В момент выхода из defensive у цели body_yaw перевёрнут (fs_body_yaw=true).
--
-- Стратегия резольвера:
--   1) Если активен choke spike И в последних 4 кадрах истории есть прыжок
--      eye_yaw > 50° между соседними записями — это defensive flick.
--   2) Внутри defensive окна — стрелять в усреднённую точку между двумя
--      «полюсами» прыжка (там дольше всего находится модель в среднем).
--   3) В первый кадр после выхода из defensive (choke вернулся к ≤1) —
--      инвертировать сторону desync (потому что fs_body_yaw перевёрнут).
function resolver:detect_flick(idx)
    local data = self:get_data(idx)
    if #data.history < 3 then return nil end

    -- ищем максимальный прыжок eye_yaw среди последних 4 апдейтов
    local biggest, jump_a, jump_b = 0, nil, nil
    for i = 1, math_min(#data.history - 1, 4) do
        local a, b = data.history[i].eye_yaw, data.history[i + 1].eye_yaw
        if a and b then
            local d = math_abs(normalize_yaw(a - b))
            if d > biggest then
                biggest, jump_a, jump_b = d, a, b
            end
        end
    end

    if biggest < 50 then return nil end
    if not jump_a or not jump_b then return nil end

    -- усредняем два «полюса» через atan2(sin, cos)
    local avg = math_deg(math_atan2(
        (math_sin(math_rad(jump_a)) + math_sin(math_rad(jump_b))) / 2,
        (math_cos(math_rad(jump_a)) + math_cos(math_rad(jump_b))) / 2))

    return { jump = biggest, avg_eye = avg, pole_a = jump_a, pole_b = jump_b }
end

-- Detected ли «выход из defensive»: choke только что упал с большого на ≤1.
function resolver:exited_defensive(idx)
    local h = self:get_data(idx).choke_history
    if #h < 2 then return false end
    return (h[1] or 0) <= 1 and (h[2] or 0) >= 6
end

-- Главный расчёт для одной цели.
function resolver:run(idx)
    local modes = ui.get(ui_mode)
    local data  = self:get_data(idx)

    -- [B11] hitchance auto-boost: после миссы 2с форсим высокий hitchance через
    -- playerlist (95). Когда окно истекает — снимаем override. Изменяем plist
    -- ТОЛЬКО при смене состояния (hc_boost_active), иначе спам плейерлиста каждый тик.
    do
        local want = (data.hc_boost_until or 0) > globals.curtime()
        if want ~= (data.hc_boost_active or false) then
            apply_hc_boost(idx, want)
            data.hc_boost_active = want
        end
    end

    -- историю собираем всегда, иначе debug-оверлей и LBY flip не будут работать,
    -- даже если "Backtrack-assisted resolve" выключен. Сбор истории дешёвый —
    -- 1 запись на серверный апдейт цели (~64 раза в секунду максимум).
    self:update_history(idx)

    -- [#3] onshot snapshot: в момент выстрела цели чит обязан был сматчить
    -- реальный eye_yaw (иначе пуля не вылетит). Этот eye_yaw — «честная»
    -- опорная точка, держим её ~0.4с и используем для определения стороны.
    if is_onshot(idx) then
        local _, eye_yaw = entity.get_prop(idx, "m_angEyeAngles")
        local st         = get_anim_state(idx)
        if eye_yaw and st then
            data.honest_eye   = eye_yaw
            data.honest_state = st.m_flGoalFeetYaw
            data.honest_at    = globals.curtime()
        end
    end

    -- Force body aim на низком хп: если включено и локальный игрок держит
    -- выбранное оружие — берём порог хп именно для этого орудия и форсим тело,
    -- когда хп цели <= порога.
    local baim_key = ui.get(ui_baim_lowhp) and local_baim_weapon_key() or nil
    local cfg      = baim_key and baim_weapon_cfg[baim_key] or nil
    if cfg and contains(ui.get(ui_baim_weapons), cfg.label) then
        local hp        = entity.get_prop(idx, "m_iHealth")
        local threshold = ui.get(cfg.slider)
        if hp and hp > 0 and hp <= threshold then
            set_body_aim(idx, "Force")
        else
            set_body_aim(idx, "-")
        end
    else
        set_body_aim(idx, "-")
    end

    local state, speed = self:get_state(idx)
    data.state = state

    -- ===== AUTO AA DETECTION =====
    -- 1) Прокручиваем jitter-детектор для побочного эффекта (data.jittering)
    --    раньше выбора порогов — даже если пресет "jitter" не активен,
    --    detect_aa_kind должен видеть актуальный флаг.
    self:resolve_eye_jitter(idx)

    -- 2) Классифицируем тип AA: "defensive" / "jitter" / "static".
    local aa_kind = self:detect_aa_kind(idx)
    data.aa_kind  = aa_kind

    -- 3) Авто min_desync: на джитере поднимаем порог (мелкие свинги — шум),
    --    на defensive ставим низкий (защитник может выйти с любого угла).
    local min_desync
    if aa_kind == "jitter"    then min_desync = 12
    elseif aa_kind == "defensive" then min_desync = 3
    else                            min_desync = 6 end

    -- [state-aware] Override min_desync по состоянию цели:
    --   air/air_duck — всегда резолвим (нет LBY-привязки, л��бое значение валидно)
    --   running      — desync схлопнут, не дёргаемся на шуме
    --   crouch*      — desync максимальный почти всегда, резолвим агрессивно
    local state_for_thr = self:get_state(idx)
    if     state_for_thr == "air" or state_for_thr == "air_duck" then min_desync = 0
    elseif state_for_thr == "running"                            then min_desync = 18
    elseif state_for_thr == "crouch" or state_for_thr == "crouch_walk" then min_desync = 2
    end

    local max        = get_max_desync(idx)
    local choke      = get_choked_packets(idx)

    -- если desync меньше порога и игрок стоит — корректировать незачем
    if max < min_desync and state == "standing" then
        set_correction(idx, true)
        set_body_yaw(idx, false, 0)
        if not ui.get(ui_adaptive) then set_safe_point(idx, "-") end
        return
    end

    local fix = nil

    -- [new#1] velocity decel freeze: если только что цель резко затормозила,
    -- держим прежний fix несколько тиков, чтобы переходные анимации не сбили
    -- сторону. Самый ранний приоритет, перебивает почти всё ниже.
    if self:in_decel_freeze(idx) and data.last_yaw and data.last_yaw ~= 0 then
        fix = data.last_yaw
        data.state = state .. "+freeze"
    end

    -- 0) on-shot: цель только что выстрелила — в этот момент она почти всегда
    --    в нулевом/назад положении, форсим 0 (подход wraith resolver)
    if fix == nil and contains(modes, "On-shot zero") and is_onshot(idx) then
        fix = 0
        data.state = state .. "+shot"
    end

    -- 1) defensive: при высоком choke цель ломает лагкомпенсацию.
    -- [new#6] defensive aimbot: точнее различаем — если choke резко скакнул
    -- (был ≤1, стал ≥6), это «настоящий» defensive, а не обычный fakelag.
    -- Тогда нет смысла угадывать сторону — просто держим прошлый удачный fix.
    if fix == nil and contains(modes, "Defensive on choke") then
        if self:is_defensive(idx) then
            -- [DEF4] proactive hitchance boost: внутри defensive окна сразу требуем
            -- высокий HC. Без этого мы стреляем 60% HC по цели, у которой лаг-комп
            -- сломан, и собираем гарантированные промахи.
            data.hc_boost_until = math_max(data.hc_boost_until or 0, globals.curtime() + 0.8)

            -- [DEF5] если защитник держит inversion окно (свежий defensive miss),
            -- стреляем в инверс. Иначе — последняя удачная сторона.
            local sign = (globals.tickcount() < (data.def_invert_until or 0))
                         and -(data.side or 1) or (data.side or 1)

            -- [DEF2] если есть свежий pre-defensive eye anchor, используем его
            -- как ориентир: дельта от current goal_feet к pre_eye = реальная сторона.
            if data.def_pre_eye and (globals.curtime() - (data.def_pre_eye_at or 0)) <= 0.8 then
                local st = get_anim_state(idx)
                if st then
                    local diff = normalize_yaw(data.def_pre_eye - st.m_flGoalFeetYaw)
                    if math_abs(diff) > 3 then
                        sign = diff > 0 and 1 or -1
                        self:commit_side(idx, sign)
                    end
                end
            end

            fix = sign * (max > 0 and max or 58)
            data.state = state .. "+def!"  -- ! = резкий скачок (defensive aimbot)
        elseif choke > 2 then
            fix = (data.side or 1) * (max > 0 and max or 58)
            data.state = state .. "+def"
        end
    end

    -- [new#7] Defensive flick: специальный резолв против defensive flick AA
    -- (паттерн из lunaris self code → defensive_flick).
    -- Вход в defensive окно + большой скачок eye_yaw = flick. Стреляем в
    -- усреднённую точку между двумя «полюсами» прыжка. На выходе из defensive
    -- инвертируем сторону, потому что lunaris-style AA пер��ворачивает body_yaw
    -- именно в этот момент.
    if fix == nil and contains(modes, "Defensive flick") then
        if self:exited_defensive(idx) then
            -- инвертируем последнюю удачную сторону
            local inv_side = -(data.side or 1)
            self:commit_side(idx, inv_side)
            fix = inv_side * (max > 0 and max or 58)
            data.state = state .. "+flickout"
        elseif self:is_defensive(idx) then
            local f = self:detect_flick(idx)
            if f then
                local st = get_anim_state(idx)
                if st then
                    -- усреднённый eye - текущий goal_feet → стор��на desync
                    local diff = normalize_yaw(f.avg_eye - st.m_flGoalFeetYaw)
                    if diff ~= 0 then
                        local sign = diff > 0 and 1 or -1
                        local confirmed = self:commit_side(idx, sign)
                        fix = clamp(math_abs(diff), 10, 60) * confirmed
                        data.state = state .. "+flick"
                    end
                end
            end
        end
    end

    -- 2) bruteforce, если уже мазали по этой цели
    if fix == nil and contains(modes, "Bruteforce on miss") and data.miss > 0 then
        fix = self:resolve_bruteforce(idx, data.last_yaw)
    end

    -- 3) детекторы джиттера: сначала по eye-yaw, затем по анимслоям
    if fix == nil and contains(modes, "Eye-yaw jitter") then
        fix = self:resolve_eye_jitter(idx)
    end
    if fix == nil and contains(modes, "Animlayer jitter") then
        fix = self:resolve_jitter(idx)
    end

    -- 4) реконструкция серверного yaw ног
    if fix == nil and contains(modes, "Server yaw rebuild") then
        local rebuilt = rebuild_server_yaw(idx)
        if rebuilt then
            local _, eye_yaw = entity.get_prop(idx, "m_angEyeAngles")
            if eye_yaw then
                fix = clamp(normalize_yaw(rebuilt - eye_yaw), -60, 60)
            end
        end
    end

    -- 5) freestanding по трейсам
    if fix == nil and contains(modes, "Freestanding") then
        fix = self:resolve_freestand(idx)
    end

    -- [#1] LBY flip side: если за последние ~1.5с был свежий flip LBY, его
    -- сторона надёжнее, чем jitter-эвристики (LBY синхронизируется с реальным
    -- feet yaw на сервере). Применяем только пока окно не "стухло".
    local lby_window = 1.5
    if data.lby_flip_at and data.lby_flip_side and
       (globals.curtime() - data.lby_flip_at) <= lby_window then
        local confirmed = self:commit_side(idx, data.lby_flip_side)
        if fix == nil or fix == 0 then
            fix = confirmed * (max > 0 and max or 58)
            data.state = state .. "+lby"
        else
            fix = math_abs(fix) * confirmed
        end
    end

    -- [#3] onshot snapshot: в окне ~0.4с после выстрела цели "честный" eye_yaw
    -- известен. Сравниваем с текущим goal_feet — это даёт сторону desync с
    -- очень высокой надёжностью, потому что в момент стрельбы AA должен
    -- сматчиться с реальным углом.
    if data.honest_eye and data.honest_at and
       (globals.curtime() - data.honest_at) <= 0.4 then
        local st = get_anim_state(idx)
        if st then
            local diff = normalize_yaw(data.honest_eye - st.m_flGoalFeetYaw)
            if diff ~= 0 then
                local confirmed = self:commit_side(idx, diff > 0 and 1 or -1)
                if fix == nil or fix == 0 then
                    fix = confirmed * (max > 0 and max or 58)
                    data.state = state .. "+onshot"
                else
                    fix = math_abs(fix) * confirmed
                end
            end
        end
    end

    -- [3] подтверждение стороны по истории бэктрека: если есть устойчивая сторона
    -- из истории — используем её для стабилизации (особенно полезно на джиттере).
    if ui.get(ui_bt_assist) then
        local hside = self:history_side(idx)
        if hside then
            local confirmed = self:commit_side(idx, hside)
            if fix ~= nil and fix ~= 0 then
                -- выравниваем знак найденного угла по подтверждённой стороне
                fix = math_abs(fix) * confirmed
            elseif fix == nil then
                -- детекторы молчат, но история знает сторону — берём макс desync
                fix = confirmed * (max > 0 and max or 58)
                data.state = state .. "+bt"
            end
        end
    end

    -- [new#5] AA correction snapshot: если по этой цели был свежий хит и мы
    -- зафиксировали реальную дельту eye - feet — используем её как fix.
    -- Применяется только если значение «свежее» (≤8 секунд) и не противоречит
    -- уже найденному fix (мы выравниваем знак, не переписывая величину).
    if data.calibrated_diff and data.calibrated_at and
       (globals.curtime() - data.calibrated_at) <= 8 then
        local cal = clamp(data.calibrated_diff, -60, 60)
        local cal_side = cal >= 0 and 1 or -1
        if fix == nil or fix == 0 then
            fix = cal
            data.state = state .. "+cal"
        else
            -- если найден угол, но в противоположную сторону — у нас более
            -- свежий «эталон» от удачного хита, ему доверяем больше
            if (fix >= 0) ~= (cal >= 0) then
                fix = math_abs(fix) * cal_side
                data.state = state .. "+cal!"
            end
        end
    end

    -- [S3] pose param 11 (m_flPoseParameter[11]) — самый чистый сигнал стороны
    -- desync’а (raw body_yaw в animset). Используем когда onshot/cal/history
    -- ничего не дали.
    if fix == nil then
        local pose_side = read_pose_yaw_side(idx)
        if pose_side ~= 0 then
            local confirmed = self:commit_side(idx, pose_side)
            fix = confirmed * (max > 0 and max or 58)
            data.pose_side, data.pose_at = pose_side, globals.curtime()
            data.state = state .. "+pose"
        end
    end

    -- [S2] animlayer 3 + 6 cross-check (feet rotation + lean).
    if fix == nil then
        local layer_side = read_layer_side(idx)
        if layer_side ~= 0 then
            local confirmed = self:commit_side(idx, layer_side)
            fix = confirmed * (max > 0 and max or 58)
            data.layer_side, data.layer_at = layer_side, globals.curtime()
            data.state = state .. "+layer"
        end
    end

    -- [A5] velocity vs eye delta — для бегущих/страфящих.
    if fix == nil then
        local vel_side = read_velocity_side(idx)
        if vel_side ~= 0 then
            local confirmed = self:commit_side(idx, vel_side)
            fix = confirmed * (max > 0 and max or 58)
            data.vel_side, data.vel_at = vel_side, globals.curtime()
            data.state = state .. "+vel"
        end
    end

    -- [#2] sliding window scoring: если из всех детекторов ничего конкретного
    -- не вышло — берём сторону, которая в последних кадрах чаще приносила хит
    -- (score_left vs score_right с экспоненциальным затуханием в on_aim_hit/miss).
    if fix == nil then
        local s_left, s_right = data.score_left or 0, data.score_right or 0
        if s_left > 0.5 or s_right > 0.5 then
            local scored_side = (s_right > s_left) and 1 or -1
            local confirmed   = self:commit_side(idx, scored_side)
            fix = confirmed * (max > 0 and max or 58)
            data.state = state .. "+score"
        end
    end

    if fix == nil then
        -- запасной вариант — максимальный desync в сторону последнего удачного направления
        fix = (data.side or 1) * (max > 0 and max or 58)
    end

    fix = clamp(round(fix), -60, 60)
    data.last_yaw = fix

    set_correction(idx, true)
    set_body_yaw(idx, true, fix)

    -- [4] adaptive aim: в зависимости от состояния цели включаем per-target
    -- safe point. Условия выбираются в мультиселекте "Safe point when".
    -- [physics] confidence gate: если включён physics-режим и наша уверенность
    -- в резолве ниже порога — форсим safe point по этой цели.
    local force_sp_by_confidence = false
    if ui.get(ui_phys) then
        local conf = self:confidence(idx)
        -- Авто confidence threshold: на джитере тре��уем больше уверенности
        -- (там реально просчитать сложно — лучше safe point), на defensive
        -- меньше (часто и так sp форсится отдельно через choke), static = середина.
        local thr
        if     aa_kind == "jitter"    then thr = 0.55
        elseif aa_kind == "defensive" then thr = 0.30
        else                               thr = 0.40 end
        if conf < thr then
            force_sp_by_confidence = true
            data.state = data.state .. ("+lowconf(%d%%/%s)"):format(
                math_floor(conf * 100), aa_kind)
        end
    end

    if ui.get(ui_adaptive) or ui.get(ui_pred_unsafe) or force_sp_by_confidence then
        local sp_modes = ui.get(ui_adaptive_sp)
        local want_sp  = ui.get(ui_adaptive) and (
            (contains(sp_modes, "Jittering")          and data.jittering) or
            (contains(sp_modes, "Defensive")          and choke > 2) or
            (contains(sp_modes, "No backtrack ticks") and ui.get(ui_bt_assist) and data.bt_ticks <= 0)
        ) or false

        -- [pred-unsafe] если включено и предикт ненадёжен — тоже safe point
        if ui.get(ui_pred_unsafe) then
            local _, _, _, reliable = self:predict_position(idx)
            if reliable == false then want_sp = true end
        end

        if force_sp_by_confidence then want_sp = true end

        local new_sp = want_sp and "On" or "-"
        set_safe_point(idx, new_sp)
    else
        set_safe_point(idx, "-")
    end

    -- Override pitch: если цель уходит в anti-aim вниз/вверх, фиксируем.
    if contains(modes, "Override pitch") then
        local pitch = entity.get_prop(idx, "m_angEyeAngles[0]")
        if pitch then
            if pitch < -1 and data.temp_pitch > 0 then
                plist.set(idx, "Force pitch", true)
                plist.set(idx, "Force pitch value", data.temp_pitch)
            else
                plist.set(idx, "Force pitch", false)
                data.temp_pitch = pitch
            end
        end
    end
end

-- [x]======================[ Обработчики событий ]======================[x]

-- [4] Глобальная адаптация: если мы фейклагаем (choked outgoing), встроенный
-- бэктрек особенно важен — включаем его. Когда фейклаг выключаем — возвращаем
-- бэктрек в исходное состояние. Состояние храним, чтобы не дёргать опцию зря.
local backtrack_forced = nil  -- nil = мы не трогали; true/false = наше значение
local backtrack_saved  = nil

local function adaptive_fakelag_backtrack()
    if not (ui.get(ui_ref.enable) and ui.get(ui_adaptive) and ui.get(ui_adaptive_fl)) then
        -- фича выключена — вернём опцию, если меняли
        if backtrack_forced ~= nil and ref_backtrack_enable and backtrack_saved ~= nil then
            ui.set(ref_backtrack_enable, backtrack_saved)
        end
        backtrack_forced = nil
        backtrack_saved  = nil
        return
    end
    if not ref_backtrack_enable or not ref_fakelag_enable then return end

    -- фейклагаем ли мы: включён фейклаг и стоит лимит > 0
    local fl_on    = ui.get(ref_fakelag_enable) == true
    local fl_limit = ref_fakelag_limit and (ui.get(ref_fakelag_limit) or 0) or 1
    local want_bt  = fl_on and fl_limit > 0

    if want_bt == backtrack_forced then return end -- уже в нужном состоянии

    -- запоминаем оригинал один раз
    if backtrack_saved == nil then
        backtrack_saved = ui.get(ref_backtrack_enable)
    end
    ui.set(ref_backtrack_enable, want_bt or backtrack_saved)
    backtrack_forced = want_bt
    reso_log(120, 200, 255, "adaptive: built-in backtrack -> %s (fakelag %s)",
        want_bt and "ON" or "restore", tostring(fl_on))
end

-- ОПТИМИЗАЦИЯ ПАМЯТИ: Периодическая сборка мусора и очистка
local last_gc_time = 0
local last_cleanup_time = 0
local gc_interval = 5  -- Сборка мусора каждые 5 секунд
local cleanup_interval = 10  -- Проверка отключившихся игроков каждые 10 секунд

-- ОПТИМИЗАЦИЯ ПАМЯТИ: Очистка данных отключившихся игроков
local function cleanup_disconnected_players()
    -- Инициализируем таблицы если они не существуют
    g_sim_ticks = g_sim_ticks or {}
    g_net_data = g_net_data or {}
    last_target_backtrack = last_target_backtrack or {}
    
    -- Получаем список всех игроков на сервере
    local active_players = {}
    local all_players = entity.get_players() or {}
    
    for _, idx in ipairs(all_players) do
        if idx and type(idx) == "number" and idx >= 1 and idx <= 64 then
            active_players[idx] = true
        end
    end
    
    -- Очищаем данные игроков которых нет на сервере
    local cleaned_count = 0
    
    -- Очистка resolver.data
    if resolver.data then
        for idx in pairs(resolver.data) do
            if not active_players[idx] then
                -- Глубокая очистка вложенных таблиц
                local data = resolver.data[idx]
                if data then
                    if data.history then
                        for i = 1, #data.history do data.history[i] = nil end
                    end
                    if data.yaw_cache then
                        for i = 1, #data.yaw_cache do data.yaw_cache[i] = nil end
                    end
                    if data.choke_history then
                        for i = 1, #data.choke_history do data.choke_history[i] = nil end
                    end
                end
                resolver.data[idx] = nil
                pcall(clear_player, idx)
                cleaned_count = cleaned_count + 1
            end
        end
    end
    
    -- Очистка других таблиц
    if g_sim_ticks then
        for idx in pairs(g_sim_ticks) do
            if not active_players[idx] then
                g_sim_ticks[idx] = nil
            end
        end
    end
    
    if g_net_data then
        for idx in pairs(g_net_data) do
            if not active_players[idx] then
                g_net_data[idx] = nil
            end
        end
    end
    
    if last_target_backtrack then
        for idx in pairs(last_target_backtrack) do
            if not active_players[idx] then
                last_target_backtrack[idx] = nil
            end
        end
    end
    
    -- Логируем если что-то очистили
    if cleaned_count > 0 and ui.get(ui_logs) then
        reso_log(100, 200, 255, "Cleaned data for %d disconnected player(s)", cleaned_count)
    end
    
    return cleaned_count
end

local function on_net_update_end()
    if not ui.get(ui_ref.enable) then return end

    local me = entity.get_local_player()
    if not me or not entity.is_alive(me) then return end

    client.update_player_list()
    adaptive_fakelag_backtrack()

    local cur_time = globals.realtime()
    
    -- ОПТИМИЗАЦИЯ ПАМЯТИ: Периодическая сборка мусора
    if cur_time - last_gc_time > gc_interval then
        collectgarbage("step", 100)  -- Инкрементальная сборка мусора
        last_gc_time = cur_time
        
        -- Очищаем данные мертвых игроков (быстрая проверка)
        local active_players = {}
        for _, idx in ipairs(entity.get_players(true)) do
            if idx and entity.is_alive(idx) then
                active_players[idx] = true
            end
        end
        
        -- Удаляем данные неактивных игроков
        for idx in pairs(resolver.data) do
            if not active_players[idx] then
                resolver.data[idx] = nil
                pcall(clear_player, idx)
            end
        end
    end
    
    -- ОПТИМИЗАЦИЯ ПАМЯТИ: Периодическая проверка отключившихся игроков
    if cur_time - last_cleanup_time > cleanup_interval then
        cleanup_disconnected_players()
        last_cleanup_time = cur_time
    end

    -- ЗАЩИТА ОТ КРАША: Обернуть resolver:run в защищённый вызов
    for _, idx in ipairs(entity.get_players(true)) do
        -- Дополнительная валидация idx
        if idx and type(idx) == "number" and idx >= 1 and idx <= 64 then
            if entity.is_alive(idx) and not entity.is_dormant(idx) then
                local ok, err = pcall(resolver.run, resolver, idx)
                if not ok then
                    -- Логируем ошибку только если включены логи
                    if ui.get(ui_logs) then
                        reso_log(255, 80, 80, "run error on player %d: %s", 
                            idx, tostring(err):sub(1, 100))
                    end
                    -- Очищаем данные проблемного игрока
                    if resolver.data and resolver.data[idx] then
                        resolver.data[idx] = nil
                    end
                    pcall(clear_player, idx)
                end
            end
        end
    end
end

-- ===== Логи из [MISC] aimbot log.lua (порт 1-в-1, привязан к ui_logs) =====
-- Все имена/структуры/format-строки взяты из исходника.

local g_impact     = {}
local g_aimbot_data = {}
local g_sim_ticks, g_net_data = {}, {}

local cl_data = {
    tick_shifted = false,
    tick_base    = 0,
}

-- fallback на случ��й когда e.id отсутствует — храним последний bt по target
local last_target_backtrack = {}

-- Простая проверка валидности entindex (1..64 для игроков).
local function valid_player_idx(idx)
    return type(idx) == "number" and idx >= 1 and idx <= 64
end

-- те же helper'ы, что в исходнике
local function vec_substract(a, b) return { a[1] - b[1], a[2] - b[2], a[3] - b[3] } end
local function vec_lenght(x, y)    return (x * x + y * y) end

local function get_entities_for_log(enemy_only, alive_only)
    enemy_only = enemy_only ~= nil and enemy_only or false
    if alive_only == nil then alive_only = true end
    local result = {}
    local pres   = entity.get_player_resource()
    -- player_resource может быть nil во время загрузки/смены карты — без него
    -- m_bAlive не прочитать. Если так — отдадим всех живых через is_alive.
    for player = 1, globals.maxplayers() do
        local is_enemy, is_alive = true, true
        if enemy_only and not entity.is_enemy(player) then is_enemy = false end
        if is_enemy then
            if alive_only then
                if pres then
                    if entity.get_prop(pres, "m_bAlive", player) ~= 1 then is_alive = false end
                else
                    if not entity.is_alive(player) then is_alive = false end
                end
            end
            if is_alive then table.insert(result, player) end
        end
    end
    return result
end

local function generate_flags(e, on_fire_data)
    return {
        e.refined and "R" or "",
        e.expired and "X" or "",
        e.noaccept and "N" or "",
        cl_data.tick_shifted and "S" or "",
        on_fire_data.teleported and "T" or "",
        on_fire_data.interpolated and "I" or "",
        on_fire_data.extrapolated and "E" or "",
        on_fire_data.boosted and "B" or "",
        on_fire_data.high_priority and "H" or "",
    }
end

local LOG_HITGROUP = { "generic", "head", "chest", "stomach",
    "left arm", "right arm", "left leg", "right leg", "neck", "?", "gear" }
local LOG_WEAPON_VERB = { knife = "Knifed", hegrenade = "Naded", inferno = "Burned" }

-- net_update: трекаем choke цели через дельту simulation_time (как в исходнике)
local function g_net_update()
    local me      = entity.get_local_player()
    if not me then return end
    local players = get_entities_for_log(true, true)
    local m_tick_base = entity.get_prop(me, "m_nTickBase")

    cl_data.tick_shifted = false
    if m_tick_base ~= nil then
        if cl_data.tick_base ~= 0 and m_tick_base < cl_data.tick_base then
            cl_data.tick_shifted = true
        end
        cl_data.tick_base = m_tick_base
    end

    for i = 1, #players do
        local idx       = players[i]
        local prev_tick = g_sim_ticks[idx]

        if entity.is_dormant(idx) or not entity.is_alive(idx) then
            g_sim_ticks[idx] = nil
            g_net_data[idx]  = nil
        else
            local player_origin   = { entity.get_origin(idx) }
            local simulation_time = to_ticks(entity.get_prop(idx, "m_flSimulationTime") or 0)

            if prev_tick ~= nil then
                local delta = simulation_time - prev_tick.tick
                if delta < 0 or (delta > 0 and delta <= 64) then
                    local diff_origin     = vec_substract(player_origin, prev_tick.origin)
                    local teleport_dist   = vec_lenght(diff_origin[1], diff_origin[2])
                    g_net_data[idx] = {
                        tick     = delta - 1,
                        origin   = player_origin,
                        tickbase = delta < 0,
                        lagcomp  = teleport_dist > 4096,
                    }
                end
            end
            g_sim_ticks[idx] = { tick = simulation_time, origin = player_origin }
        end
    end
end

-- aim_fire — снапшот всего события
-- ЗАЩИТА ОТ КРАША: Безопасная работа с event данными
local function on_aim_fire(e)
    if not e or not e.target then return end
    if not valid_player_idx(e.target) then return end

    -- Защищенное выполнение
    local success = pcall(function()
        -- наша часть: счётчик выстрелов и данные резольвера
        local rdata = resolver:get_data(e.target)
        if not rdata then return end
        rdata.shots = rdata.shots + 1

        if g_net_data[e.target] == nil then
            g_net_data[e.target] = {}
        end

        -- порт логики из [MISC] aimbot log
        local plist_sp = plist.get(e.target, "Override safe point")
        local plist_fa = plist.get(e.target, "Correction active")
        local checkbox = false
        local force_sp_ref_ok, force_sp_ref = pcall(ui.reference, "RAGE", "Aimbot", "Force safe point")
        if force_sp_ref_ok and force_sp_ref then 
            local ok, val = pcall(ui.get, force_sp_ref)
            if ok then checkbox = val end
        end

        e.tick = e.tick
        -- ЗАЩИТА: eye_position может вернуть nil
        local ex, ey, ez = client.eye_position()
        if ex and ey and ez then
            local ok, vec = pcall(vector, ex, ey, ez)
            if ok then e.eye = vec end
        end
        if e.x and e.y and e.z then
            local ok, vec = pcall(vector, e.x, e.y, e.z)
            if ok then e.shot = vec end
        end
        e.teleported  = g_net_data[e.target].lagcomp or false
        e.choke       = g_net_data[e.target].tick or "?"
        e.self_choke  = globals.chokedcommands()
        e.correction  = plist_fa and 1 or 0
        e.safe_point  = ({
            ["Off"] = "off",
            ["On"]  = true,
            ["-"]   = checkbox,
        })[plist_sp]

        if e.id ~= nil then
            g_aimbot_data[e.id] = e
            -- ОПТИМИЗАЦИЯ ПАМЯТИ: Агрессивная очистка старых данных
            local count = 0
            for _ in pairs(g_aimbot_data) do count = count + 1 end
            if count > MAX_AIMBOT_DATA then
                -- Удаляем половину самых старых записей
                local keys = {}
                for k in pairs(g_aimbot_data) do
                    table.insert(keys, k)
                end
                table.sort(keys)
                for i = 1, math.floor(#keys / 2) do
                    g_aimbot_data[keys[i]] = nil
                end
            end
        end
        last_target_backtrack[e.target] = e.backtrack and to_ticks(e.backtrack) or 0
    end)
    
    if not success then
        -- Тихо игнорируем ошибки в aim_fire
    end
end

local function on_aim_hit(e)
    if not valid_player_idx(e.target) then return end

    local rdata = resolver:get_data(e.target)
    rdata.hit = rdata.hit + 1
    if rdata.last_yaw and rdata.last_yaw ~= 0 then
        rdata.side = rdata.last_yaw >= 0 and 1 or -1
    end

    -- [#2] sliding window scoring (наш кусок, оставляем)
    if rdata.last_yaw and rdata.last_yaw ~= 0 then
        if rdata.last_yaw > 0 then
            rdata.score_right = (rdata.score_right or 0) + 1
            rdata.score_left  = (rdata.score_left  or 0) * 0.85
        else
            rdata.score_left  = (rdata.score_left  or 0) + 1
            rdata.score_right = (rdata.score_right or 0) * 0.85
        end
    end

    -- лог 1-в-1 как в [MISC] aimbot log
    if g_aimbot_data[e.id] == nil then return end
    local on_fire_data = g_aimbot_data[e.id]
    g_aimbot_data[e.id] = nil

    local name         = string.lower(entity.get_player_name(e.target) or "?")
    local hgroup       = LOG_HITGROUP[(e.hitgroup or 0) + 1] or "?"
    local aimed_hgroup = LOG_HITGROUP[(on_fire_data.hitgroup or 0) + 1] or "?"
    local hitchance    = math_floor(on_fire_data.hit_chance + 0.5) .. "%"
    local health       = entity.get_prop(e.target, "m_iHealth") or 0
    local flags        = generate_flags(e, on_fire_data)
    -- bt = во сколько тиков НАЗАД был выстрел относительно текущего момента
    -- (globals.tickcount - on_fire_data.tick). Это и есть «во сколько тиков
    -- я попал» с твоей точки зрения. Чем больш�� TC цели и больше задержка,
    -- тем больше bt.
    local bt_ticks     = math_max(0, globals.tickcount() - (on_fire_data.tick or globals.tickcount()))

    rdata.last_hit_bt = bt_ticks

    -- [new#5] AA correction snapshot: попадание в торс (chest=2 или stomach=3)
    -- значит тело цели было повёрнуто к нам как ожидалось — текущая дельта
    -- eye_yaw - goal_feet_yaw это «правильная» цифра для этой цели на этом
    -- AA. Сохраняем её — следующие выстрелы будут пытаться подстроиться.
    if e.hitgroup == 2 or e.hitgroup == 3 then
        local _, eye_yaw = entity.get_prop(e.target, "m_angEyeAngles")
        local st         = get_anim_state(e.target)
        if eye_yaw and st then
            local diff = normalize_yaw(eye_yaw - st.m_flGoalFeetYaw)
            -- сохраняем только если значение в пределах desync (не явный шум)
            if math_abs(diff) <= 60 then
                rdata.calibrated_diff = diff
                rdata.calibrated_at   = globals.curtime()
            end
        end
    end

    reso_log(0, 150, 0, string.format(
        "[%d] [%d/%d] Hit %s's %s for %i(%d) (%i remaining) aimed=%s(%s) sp=%s bt=%d (%s) LC=%s TC=%s",
        e.id, (on_fire_data.tick or 0) % 1000, globals.tickcount() % 1000,
        name, hgroup, e.damage or 0, on_fire_data.damage or 0, health,
        aimed_hgroup, hitchance, tostring(on_fire_data.safe_point), bt_ticks,
        table.concat(flags), tostring(on_fire_data.self_choke), tostring(on_fire_data.choke)
    ))

    -- [A7] adaptive bruteforce: засчитываем успех текущей фазе если хит пришёл
    -- в течение 1с после bruteforce-выстрела (иначе это попадание не от него).
    if rdata.last_brute_state and rdata.last_brute_phase and rdata.last_brute_at then
        local age = globals.tickcount() - rdata.last_brute_at
        if age >= 0 and age <= 64 then
            rdata.phase_success = rdata.phase_success or {}
            local ps = rdata.phase_success
            ps[rdata.last_brute_state] = ps[rdata.last_brute_state] or {}
            ps[rdata.last_brute_state][rdata.last_brute_phase] =
                (ps[rdata.last_brute_state][rdata.last_brute_phase] or 0) + 1
        end
    end

    -- [S4] persist профиля после хита (score + phase_success)
    pcall(db_save_profile, rdata)

    -- [B11] хит — снимаем hitchance boost
    rdata.hc_boost_until = 0
end

local function on_aim_miss(e)
    if not e or not e.target then return end
    if not valid_player_idx(e.target) then return end
    
    -- Защищенное выполнение
    local success = pcall(function()
        local rdata = resolver:get_data(e.target)
        if not rdata then return end

        -- [B11] hitchance auto-boost: после миссы 2с требуем повышенный hitchance
        rdata.hc_boost_until = globals.curtime() + 2.0

        if g_aimbot_data[e.id] == nil then
            if e.reason == "?" then rdata.miss = rdata.miss + 1 end
            return
        end
        local on_fire_data = g_aimbot_data[e.id]
        g_aimbot_data[e.id] = nil

        local name      = string.lower(entity.get_player_name(e.target) or "?")
        local hgroup    = LOG_HITGROUP[(e.hitgroup or 0) + 1] or "?"
        local hitchance = math_floor(on_fire_data.hit_chance + 0.5) .. "%"
        local flags     = generate_flags(e, on_fire_data)
        local reason    = e.reason == "?" and "unknown" or tostring(e.reason or "?")
        local bt_ticks  = math_max(0, globals.tickcount() - (on_fire_data.tick or globals.tickcount()))

        -- inaccuracy через сохранённые bullet_impact текущего тика
        local inaccuracy = 0
        -- ЗАЩИТА: вычислять можно только если у нас есть и shot, и origin
        if on_fire_data.shot then
            for i = #g_impact, 1, -1 do
                local impact = g_impact[i]
                if impact and impact.tick == globals.tickcount()
                   and impact.origin and impact.shot then
                    local ok, val = pcall(function()
                        local aim  = (impact.origin - on_fire_data.shot):angles()
                        local shot = (impact.origin - impact.shot):angles()
                        return vector(aim - shot):length2d()
                    end)
                    if ok and val then inaccuracy = val end
                    break
                end
            end
        end

        reso_log(220, 50, 50, string.format(
            "[%d] [%d/%d] Missed %s's %s(%i)(%s) due to %s:%.2f°, sp=%s bt=%d (%s) LC=%s TC=%s",
            e.id, (on_fire_data.tick or 0) % 1000, globals.tickcount() % 1000,
            name, hgroup, on_fire_data.damage or 0, hitchance, reason, inaccuracy,
            tostring(on_fire_data.safe_point), bt_ticks,
            table.concat(flags), tostring(on_fire_data.self_choke), tostring(on_fire_data.choke)
        ))

        -- наш кусок: bruteforce и scoring только на reason "?"
        if e.reason ~= "?" then return end
        rdata.miss = rdata.miss + 1
        -- [new#5] миссы обнуляют эталон
        rdata.calibrated_diff = nil
        rdata.calibrated_at   = 0

        -- [DEF3] defensive miss tracking: если выстрел был в defensive окне
        -- (choke ≥4 на момент стрельбы), считаем это defensive missом отдельно.
        -- Инвертируем сторону + продлеваем inversion окно + бустим hitchance.
        local shot_choke = (on_fire_data and on_fire_data.choke) or 0
        local was_defensive = (type(shot_choke) == "number" and shot_choke >= 4)
                              or resolver:is_defensive(e.target)
        if was_defensive then
            rdata.def_miss         = (rdata.def_miss or 0) + 1
            rdata.def_last_miss_at = globals.tickcount()
            -- держим инверс 24 тика (~0.37с) — на следующий defensive выстрел
            -- сразу попробуем противоположную сторону
            rdata.def_invert_until = globals.tickcount() + 24
            -- агрессивный hitchance boost на 3с (defensive — самое опасное место)
            rdata.hc_boost_until   = math_max(rdata.hc_boost_until or 0,
                                              globals.curtime() + 3.0)
            -- сразу коммитим инверсную сторону, не ждём confirm
            if rdata.last_yaw and rdata.last_yaw ~= 0 then
                local inv = rdata.last_yaw > 0 and -1 or 1
                rdata.side          = inv
                rdata.pending_side  = inv
                rdata.side_count    = 0
            end
        end

        if rdata.last_yaw and rdata.last_yaw ~= 0 then
            if rdata.last_yaw > 0 then
                rdata.score_right = math_max(0, (rdata.score_right or 0) - 0.7)
                rdata.score_left  = (rdata.score_left or 0) + 0.4
            else
                rdata.score_left  = math_max(0, (rdata.score_left or 0) - 0.7)
                rdata.score_right = (rdata.score_right or 0) + 0.4
            end
        end
    end)
    
    if not success then
        -- Тихо игнорируем ошибки в aim_miss
    end
end

-- player_hurt — knife/nade/inferno как в исходнике
local function on_player_hurt(e)
    local attacker_id = client.userid_to_entindex(e.attacker)
    if attacker_id == nil or attacker_id ~= entity.get_local_player() then return end
    local group = LOG_HITGROUP[(e.hitgroup or 0) + 1] or "?"
    if group == "generic" and LOG_WEAPON_VERB[e.weapon] ~= nil then
        local target_id = client.userid_to_entindex(e.userid)
        if not target_id then return end
        local target_name = string.lower(entity.get_player_name(target_id) or "?")
        reso_log(180, 180, 60, string.format(
            "%s %s for %i damage (%i remaining)",
            LOG_WEAPON_VERB[e.weapon], target_name, e.dmg_health or 0, e.health or 0
        ))
    end
end

-- bullet_impact — для inaccuracy на промахе
-- ЗАЩИТА ОТ КРАША: Безопасное создание vector
local function on_bullet_impact(e)
    if not e then return end
    
    local success = pcall(function()
        local tick = globals.tickcount()
        local me   = entity.get_local_player()
        local user = client.userid_to_entindex(e.userid)
        if user ~= me then return end

        -- ЗАЩИТА: eye_position и e.x/y/z могут отсутствовать
        local ex, ey, ez = client.eye_position()
        if not ex or not e.x or not e.y or not e.z then return end

        -- ОПТИМИЗАЦИЯ ПАМЯТИ: Агрессивная очистка impact данных
        if #g_impact > MAX_IMPACT_DATA then
            g_impact = {}
        elseif #g_impact > 0 and g_impact[#g_impact].tick ~= tick then
            -- Очищаем старые тики
            local new_impact = {}
            for i = #g_impact, math.max(1, #g_impact - 10), -1 do
                if g_impact[i].tick == tick then
                    table.insert(new_impact, 1, g_impact[i])
                end
            end
            g_impact = new_impact
        end

        local ok1, origin_vec = pcall(vector, ex, ey, ez)
        local ok2, shot_vec = pcall(vector, e.x, e.y, e.z)
        
        if ok1 and ok2 and origin_vec and shot_vec then
            g_impact[#g_impact + 1] = {
                tick   = tick,
                origin = origin_vec,
                shot   = shot_vec,
            }
        end
    end)
    
    if not success then
        -- Тихо игнорируем ошибки
    end
end

-- ОПТИМИЗАЦИЯ ПАМЯ��И: Агрессивная очистка при смерти игрока
local function on_player_death(e)
    local idx       = client.userid_to_entindex(e.userid)
    local attacker  = client.userid_to_entindex(e.attacker or 0)
    local me        = entity.get_local_player()

    -- если убил локальный игрок — логируем enemy backtrack последнего хита
    if idx and me and attacker == me and idx ~= me then
        local data = resolver.data[idx]
        local bt   = (data and data.last_hit_bt) or last_target_backtrack[idx] or 0
        reso_log(0, 180, 0,
            "killed %s (enemy bt %d t on killing shot)",
            player_name(idx), bt)
    end

    -- ОПТИМИЗАЦИЯ ПАМЯТИ: Полная очистка данных мертвого игрока
    if idx then
        if resolver.data[idx] then
            -- Очищаем вложенные таблицы
            local data = resolver.data[idx]
            if data.history then
                for i = 1, #data.history do
                    data.history[i] = nil
                end
            end
            if data.yaw_cache then
                for i = 1, #data.yaw_cache do
                    data.yaw_cache[i] = nil
                end
            end
            if data.choke_history then
                for i = 1, #data.choke_history do
                    data.choke_history[i] = nil
                end
            end
            resolver.data[idx] = nil
        end
        
        pcall(clear_player, idx)
        last_target_backtrack[idx] = nil
        g_sim_ticks[idx] = nil
        g_net_data[idx] = nil
    end
end

-- [x]======================[ Debug отрисовка ]======================[x]
-- ЗАЩИТА ОТ КР��ША: Безопасная отрисовка с проверками всех данных
local function on_paint()
    if not ui.get(ui_ref.enable) or not ui.get(ui_debug) then return end

    local success = pcall(function()
        local target = ui.get(player_list_ref)
        if not target or not entity.is_alive(target) or entity.is_dormant(target) then return end

        local data = resolver.data and resolver.data[target]
        if not data then return end

        local r, g, b, a = ui.get(ui_debug_color)
        local x, y, z = entity.hitbox_position(target, 0)
        if not x or not y or not z then return end

        local sx, sy = renderer.world_to_screen(x, y, z)
        if not sx or not sy then return end

        local acc = data.shots > 0 and math_floor((data.hit / data.shots) * 100 + 0.5) or 0
        local jit = data.jittering and "jit" or "static"
        local txt = ("%s | %s | yaw %d | hit %d/%d (%d%%)"):format(
            data.state or "?", jit, data.last_yaw or 0, data.hit, data.shots, acc)

        renderer.text(sx, sy - 40, r, g, b, a, "c", 0, txt)

        -- вторая строка: данные бэктрека
        local bt_txt = ("bt %d t | hist %d | sL %.1f sR %.1f"):format(
            data.bt_ticks or 0, #(data.history or {}),
            data.score_left or 0, data.score_right or 0)
        renderer.text(sx, sy - 27, r, g, b, a, "c", 0, bt_txt)

        -- третья строка: маркеры активных подсказок
        local now      = globals.curtime()
        local lby_on   = data.lby_flip_at and (now - data.lby_flip_at) <= 1.5
        local shot_on  = data.honest_at   and (now - data.honest_at)   <= 0.4
        if lby_on or shot_on then
            local marks = (lby_on and "LBY " or "") .. (shot_on and "ONSHOT" or "")
            renderer.text(sx, sy - 14, r, g, b, a, "c", 0, marks)
        end

        -- [2] предикт позиции: рисуем точку и линию
        if ui.get(ui_pred_pos) then
            local px, py, pz, reliable = resolver:predict_position(target)
            if px and py and pz then
                local pr, pg, pb, pa = ui.get(ui_pred_pos_clr)
                if not reliable then
                    pr, pg = 255, 80
                    pa = math_floor((pa or 200) * 0.6)
                end
                local psx, psy = renderer.world_to_screen(px, py, pz + 35)
                local lx, ly   = renderer.world_to_screen(x, y, z)
                if psx and lx then
                    renderer.line(lx, ly, psx, psy, pr, pg, pb, pa)
                    renderer.circle(psx, psy, pr, pg, pb, pa, 4, 0, 1)
                    renderer.text(psx, psy + 7, pr, pg, pb, pa, "c", 0,
                        reliable and "predict" or "predict?")
                end
            end
        end
    end)
    
    if not success then
        -- Тихо игнорируем ошибки отрисовки
    end
end

-- [x]======================[ Регистрация ]======================[x]
ui.set_callback(ui_ref.enable, set_visibility)
ui.set_callback(ui_debug, set_visibility)
ui.set_callback(ui_baim_lowhp, set_visibility)
ui.set_callback(ui_baim_weapons, set_visibility)
ui.set_callback(ui_bt_assist, set_visibility)
ui.set_callback(ui_adaptive, set_visibility)
ui.set_callback(ui_pred_pos, set_visibility)
ui.set_callback(ui_phys, set_visibility)
ui.set_callback(ui_clantag_enable, set_visibility)
ui.set_callback(ui_mode_select, function()
    apply_mode()
    set_visibility()
end)
ui.set_callback(ui_logs, function()
    set_visibility()
    apply_notify_suppression()
end)
apply_mode()           -- стартовое применение пресета
set_visibility()
apply_notify_suppression()

client.set_event_callback("net_update_end", on_net_update_end)
client.set_event_callback("net_update_end", g_net_update)        -- choke тр��кер из [MISC] aimbot log
client.set_event_callback("aim_fire",       on_aim_fire)
client.set_event_callback("aim_hit",        on_aim_hit)
client.set_event_callback("aim_miss",       on_aim_miss)
client.set_event_callback("player_death",   on_player_death)
client.set_event_callback("player_hurt",    on_player_hurt)       -- knife/nade/inferno
client.set_event_callback("bullet_impact",  on_bullet_impact)     -- inaccuracy на промахе
client.set_event_callback("paint",          on_paint)

-- ОПТИМИЗАЦИЯ ПАМЯТИ: Полная очистка всех данных
local function reset_all()
    resolver:reset()
    
    -- Очищаем все глобальные таблицы
    for k in pairs(g_aimbot_data) do g_aimbot_data[k] = nil end
    for k in pairs(last_target_backtrack) do last_target_backtrack[k] = nil end
    for k in pairs(g_impact) do g_impact[k] = nil end
    for k in pairs(g_sim_ticks) do g_sim_ticks[k] = nil end
    for k in pairs(g_net_data) do g_net_data[k] = nil end
    
    g_aimbot_data         = {}
    last_target_backtrack = {}
    g_impact              = {}
    g_sim_ticks           = {}
    g_net_data            = {}
    cl_data.tick_base     = 0
    cl_data.tick_shifted  = false
    
    -- Принудительная сборка мусора
    collectgarbage("collect")
end
-- ОПТИМИЗАЦИЯ ПАМЯТИ: Очистка отключившихся игроков в начале раунда
local function on_round_start()
    -- Сначала очищаем отключившихся игроков
    cleanup_disconnected_players()
    -- Потом делаем полный reset
    reset_all()
end

-- ОПТИМИЗАЦИЯ ПАМЯТИ: Обработчик player_connect для отслеживания подключений
local function on_player_connect(e)
    -- Когда игрок подключается, ничего не делаем
    -- Данные создадутся автоматически при первом обращении
end

-- ОПТИМИЗАЦИЯ ПАМЯТИ: Обработчик player_disconnect для немедленной очистки
local function on_player_disconnect(e)
    local idx = client.userid_to_entindex(e.userid)
    if not idx or idx < 1 or idx > 64 then return end
    
    -- Защищенная очистка данных игрока
    local success, err = pcall(function()
        -- Глубокая очистка данных игрока
        if resolver.data[idx] then
            -- Очищаем вложенные таблицы
            if resolver.data[idx].history then
                for k in pairs(resolver.data[idx].history) do
                    resolver.data[idx].history[k] = nil
                end
            end
            if resolver.data[idx].yaw_cache then
                for k in pairs(resolver.data[idx].yaw_cache) do
                    resolver.data[idx].yaw_cache[k] = nil
                end
            end
            if resolver.data[idx].choke_history then
                for k in pairs(resolver.data[idx].choke_history) do
                    resolver.data[idx].choke_history[k] = nil
                end
            end
            
            -- Удаляем основную запись
            resolver.data[idx] = nil
        end
        
        -- Очищаем связанные таблицы
        if g_sim_ticks then g_sim_ticks[idx] = nil end
        if g_net_data then g_net_data[idx] = nil end
        if last_target_backtrack then last_target_backtrack[idx] = nil end
        
        -- Очищаем plist
        clear_player(idx)
        
        if ui.get(ui_logs) then
            reso_log(100, 200, 255, "Player %d disconnected - memory cleaned", idx)
        end
    end)
    
    if not success and ui.get(ui_logs) then
        reso_log(255, 100, 100, "Error cleaning player %d on disconnect: %s", idx, err or "unknown")
    end
end

-- Регистрация событий для очистки памяти
client.set_event_callback("round_start",            on_round_start)
client.set_event_callback("game_newmap",            reset_all)
client.set_event_callback("cs_game_disconnected",   reset_all)
client.set_event_callback("player_connect",         on_player_connect)
client.set_event_callback("player_disconnect",      on_player_disconnect)

-- сброс плейерлиста при выгрузке скрипта
-- ЗАЩИТА ОТ КРАША: Безопасная очистка всех данных
-- [S1] weapon_fire — мгновенный snapshot eye_yaw стреляющего врага.
-- Срабатывает РАНЬШЕ чем is_onshot(), даёт честный baseline для resolve.
client.set_event_callback("weapon_fire", function(e)
    pcall(function()
        local shooter = client.userid_to_entindex(e.userid)
        if not valid_player_idx(shooter) then return end
        local me = entity.get_local_player()
        if shooter == me then return end
        if me and entity.get_prop(shooter, "m_iTeamNum") == entity.get_prop(me, "m_iTeamNum") then return end
        local _, eye_yaw = entity.get_prop(shooter, "m_angEyeAngles")
        local st         = get_anim_state(shooter)
        if eye_yaw and st then
            local rdata = resolver:get_data(shooter)
            rdata.honest_eye   = eye_yaw
            rdata.honest_state = st.m_flGoalFeetYaw
            rdata.honest_at    = globals.curtime()
        end
    end)
end)

client.set_event_callback("shutdown", function()
    local success = pcall(function()
        -- [S4] flush per-SteamID профили всех известных таргетов
        for _, rdata in pairs(resolver.data) do
            pcall(db_save_profile, rdata)
        end
        -- Очищаем всех игроков
        local players = entity.get_players() or {}
        for _, idx in ipairs(players) do
            if idx and type(idx) == "number" and idx >= 1 and idx <= 64 then
                pcall(clear_player, idx)
            end
        end
        -- возвращаем con_notifytime, если мы его меняли
        pcall(notify_restore)
        -- возвращаем встроенный backtrack, если мы его трогали ([4])
        if backtrack_forced ~= nil and ref_backtrack_enable and backtrack_saved ~= nil then
            pcall(ui.set, ref_backtrack_enable, backtrack_saved)
        end
        -- Финальная сборка мусора
        collectgarbage("collect")
    end)
    
    if not success then
        client.color_log(255, 100, 100, "[Parallax] Shutdown cleanup had errors (non-critical)")
    end
end)

-- [x]======================[ HS флаг (% шанс килла в голову) ]======================[x]
-- ESP-флаг "HS" + проценты — показывает шанс убить цель попаданием в голову.
-- Считается через client.trace_bullet от твоей eye_position до головы цели.
-- Результат — тики 1-3 = живое значение урона. Сравниваем с health цели:
-- если предполагаемый урон по голове >= hp → шанс высокий (зелёный 100%),
-- иначе = damage / hp (грубая оценка).
do
    -- UI
    local ui_hs_flag       = ui.new_checkbox("RAGE", "Other", "ESP flag: HS kill chance")
    local ui_hs_flag_text  = ui.new_checkbox("RAGE", "Other", "  Show numeric percent")

    -- кэш по цели: { last_check_tick, percent, color = {r,g,b} }
    local hs_cache = {}

    -- считаем шанс килла в голову для одной цели; обновляем не чаще чем
    -- раз в ~6 тиков (≈100ms на 64 tickrate), чтобы не нагружать ESP.
    local function update_hs_chance(idx)
        local me = entity.get_local_player()
        if not me or not entity.is_alive(me) then return nil end
        if not idx or not entity.is_alive(idx) or entity.is_dormant(idx) then return nil end

        local cache = hs_cache[idx]
        local tick  = globals.tickcount()
        if cache and (tick - (cache.tick or 0)) < 6 then
            return cache
        end

        local hp = entity.get_prop(idx, "m_iHealth")
        if not hp or hp <= 0 then return nil end

        local hx, hy, hz = entity.hitbox_position(idx, 0) -- голова
        if not hx then return nil end

        local ex, ey, ez = client.eye_position()
        if not ex then return nil end

        -- trace_bullet иногда падает (битые кадры/ресимуляция), оборачиваем
        -- pcall, чтобы редкая ошибка не уронила ESP-callback.
        local ok, hit_idx, damage = pcall(client.trace_bullet,
            me, ex, ey, ez, hx, hy, hz, false)
        if not ok then return nil end
        damage = damage or 0

        -- если пуля прошла не в нужного игрока — урон на цель = 0
        if hit_idx ~= idx then damage = 0 end

        local pct = math.min(100, math.floor((damage / hp) * 100 + 0.5))
        if damage >= hp then pct = 100 end

        -- цвет: красный → жёлтый → зелёный по шансу
        local r, g, b
        if pct >= 100 then
            r, g, b = 80, 255, 80
        elseif pct >= 60 then
            r, g, b = 255, 220, 60
        elseif pct >= 30 then
            r, g, b = 255, 140, 40
        else
            r, g, b = 255, 80, 80
        end

        cache = { tick = tick, percent = pct, r = r, g = g, b = b, damage = damage }
        hs_cache[idx] = cache
        return cache
    end

    -- ESP-флаг с динамическим текстом и цветом. Вызывается ESP'ом на каждого
    -- игрока — внутри сами решаем, рисовать или нет, и какой текст.
    -- Сигнатура callback: (player) -> bool (показывать ли) [+ опционально текст/цвет]
    -- gamesense поддерживает только bool возврат, поэтому показываем только когда
    -- шанс >= 30%, и используем сам текст флага как индикатор.
    -- Чтобы показать процент — регистрируем три флага (low/med/high), каждый
    -- со своим цветом и текстом, и они взаимоисключающие.
    local function flag_for(player, threshold_lo, threshold_hi)
        if not ui.get(ui_hs_flag) then return false end
        if not entity.is_enemy(player) then return false end
        if not entity.is_alive(player) or entity.is_dormant(player) then return false end
        local c = update_hs_chance(player)
        if not c then return false end
        return c.percent >= threshold_lo and c.percent <= threshold_hi
    end

    -- регистрируем 4 диапазона: <30 / 30-59 / 60-99 / 100. Каждый со своим
    -- текстом и цветом. ESP покажет ровно один из них (зависит от состояния
    -- чекбокса "Show numeric percent": если ВКЛ — рисуются цв��тные диапазоны;
    -- если ВЫКЛ — рисуется единый "HS" при шансе >= 50%).
    local function detailed(p, lo, hi)
        if not ui.get(ui_hs_flag_text) then return false end
        return flag_for(p, lo, hi)
    end
    local function simple(p)
        if ui.get(ui_hs_flag_text) then return false end
        if not ui.get(ui_hs_flag) then return false end
        if not entity.is_enemy(p) then return false end
        if not entity.is_alive(p) or entity.is_dormant(p) then return false end
        local c = update_hs_chance(p)
        return c and c.percent >= 50 or false
    end

    client.register_esp_flag("HS<30",  255,  80,  80, function(p) return detailed(p,   0,  29) end)
    client.register_esp_flag("HS 30+", 255, 140,  40, function(p) return detailed(p,  30,  59) end)
    client.register_esp_flag("HS 60+", 255, 220,  60, function(p) return detailed(p,  60,  99) end)
    client.register_esp_flag("HS 100", 80,  255,  80, function(p) return detailed(p, 100, 100) end)
    client.register_esp_flag("HS",     80,  255,  80, simple)
    client.set_event_callback("round_start", function() hs_cache = {} end)
    client.set_event_callback("game_newmap", function() hs_cache = {} end)

    local function hs_set_visibility()
        local on = ui.get(ui_ref.enable)
        ui.set_visible(ui_hs_flag,      on)
        ui.set_visible(ui_hs_flag_text, on and ui.get(ui_hs_flag))
    end
    ui.set_callback(ui_ref.enable, hs_set_visibility)
    ui.set_callback(ui_hs_flag,    hs_set_visibility)
    hs_set_visibility()
end

-- [x]======================[ Watermark ]======================[x]
-- 1-в-1 порт visual слоя solus v2: rounded rect + faded rounded rect с
-- градиентами + outline glow цикл + renderer.blur. Только текст и логика
-- содержимого свои (наш ник/имя чита/beta-тег).
do
    -- проверка in-game состояния через VEngineClient014.IsInGame
    local wm_is_in_game
    do
        local ok, raw = pcall(client.create_interface, "engine.dll", "VEngineClient014")
        if ok and raw then
            local iface = ffi.cast("void***", raw)
            local fn    = ffi.cast("bool(__thiscall*)(void*)", iface[0][26])
            wm_is_in_game = function()
                local ok2, res = pcall(fn, iface)
                return ok2 and res
            end
        else
            wm_is_in_game = function() return true end
        end
    end

    -- UI (рядом с резольвером в RAGE → Other)
    local ui_wm_enable     = ui.new_checkbox    ("RAGE", "Other", "Watermark")
    local ui_wm_cheat_name = ui.new_textbox     ("RAGE", "Other", "  Cheat name")
    local ui_wm_nickname   = ui.new_textbox     ("RAGE", "Other", "  Custom nickname")
    local ui_wm_beta       = ui.new_checkbox    ("RAGE", "Other", "  Show beta tag")
    local ui_wm_beta_text  = ui.new_textbox     ("RAGE", "Other", "  Beta tag text")
    local ui_wm_color      = ui.new_color_picker("RAGE", "Other", "Watermark color", 142, 165, 229, 255)
    local ui_wm_glow       = ui.new_checkbox    ("RAGE", "Other", "  Glow")

    local DEFAULT_CHEAT_NAME = "Fracture"
    local DEFAULT_BETA_TEXT  = "beta"

    local function wm_set_visibility()
        local on = ui.get(ui_wm_enable)
        ui.set_visible(ui_wm_cheat_name, on)
        ui.set_visible(ui_wm_nickname,   on)
        ui.set_visible(ui_wm_beta,       on)
        ui.set_visible(ui_wm_beta_text,  on and ui.get(ui_wm_beta))
        ui.set_visible(ui_wm_color,      on)
        ui.set_visible(ui_wm_glow,       on)
    end
    ui.set_callback(ui_wm_enable, wm_set_visibility)
    ui.set_callback(ui_wm_beta,   wm_set_visibility)
    wm_set_visibility()

    local function wm_get_text(item, default)
        local s = ui.get(item)
        if not s or s == "" then return default end
        return s
    end

    local function wm_local_player_name()
        local me = entity.get_local_player()
        if not me then return "anon" end
        return entity.get_player_name(me) or "anon"
    end

    -- ===== solus_render порт: те же магические константы =====
    local rounding = 4
    local rad      = rounding + 2  -- расширение для glow-обводок
    local n        = 45            -- множитель градиентов (faded edge)
    local o        = 20            -- alpha коэффициент для FadedRoundedRect

    -- RoundedRect: тёмная основа (как в solus_render)
    local function RoundedRect(x, y, w, h, radius, r, g, b, a)
        renderer.rectangle(x + radius,     y,              w - radius * 2, radius,         r, g, b, a)
        renderer.rectangle(x,              y + radius,     radius,         h - radius * 2, r, g, b, a)
        renderer.rectangle(x + radius,     y + h - radius, w - radius * 2, radius,         r, g, b, a)
        renderer.rectangle(x + w - radius, y + radius,     radius,         h - radius * 2, r, g, b, a)
        renderer.rectangle(x + radius,     y + radius,     w - radius * 2, h - radius * 2, r, g, b, a)
        renderer.circle(x + radius,         y + radius,         r, g, b, a, radius, 180, 0.25)
        renderer.circle(x + w - radius,     y + radius,         r, g, b, a, radius,  90, 0.25)
        renderer.circle(x + radius,         y + h - radius,     r, g, b, a, radius, 270, 0.25)
        renderer.circle(x + w - radius,     y + h - radius,     r, g, b, a, radius,   0, 0.25)
    end

    -- OutlineGlow: одно «кольцо» свечения вокруг бокса (rectangle + circle_outline)
    local function OutlineGlow(x, y, w, h, radius, r, g, b, a)
        renderer.rectangle(x + 2,             y + radius + rad,   1, h - rad * 2 - radius * 2, r, g, b, a)
        renderer.rectangle(x + w - 3,         y + radius + rad,   1, h - rad * 2 - radius * 2, r, g, b, a)
        renderer.rectangle(x + radius + rad,  y + 2,              w - rad * 2 - radius * 2, 1, r, g, b, a)
        renderer.rectangle(x + radius + rad,  y + h - 3,          w - rad * 2 - radius * 2, 1, r, g, b, a)
        renderer.circle_outline(x + radius + rad,         y + radius + rad,         r, g, b, a, radius + rounding, 180, 0.25, 1)
        renderer.circle_outline(x + w - radius - rad,     y + radius + rad,         r, g, b, a, radius + rounding, 270, 0.25, 1)
        renderer.circle_outline(x + radius + rad,         y + h - radius - rad,     r, g, b, a, radius + rounding,  90, 0.25, 1)
        renderer.circle_outline(x + w - radius - rad,     y + h - radius - rad,     r, g, b, a, radius + rounding,   0, 0.25, 1)
    end

    -- FadedRoundedRect: цветная рамка с градиентами по бокам + цикл glow.
    -- glow здесь — это уже амплитуда (alpha * 20 в solus), а не на/выкл.
    local function FadedRoundedRect(x, y, w, h, radius, r, g, b, a, glow)
        local nn = a / 255 * n
        renderer.rectangle(x + radius, y, w - radius * 2, 1, r, g, b, a)
        renderer.circle_outline(x + radius,     y + radius, r, g, b, a, radius, 180, 0.25, 1)
        renderer.circle_outline(x + w - radius, y + radius, r, g, b, a, radius, 270, 0.25, 1)
        renderer.gradient(x,         y + radius, 1, h - radius * 2, r, g, b, a, r, g, b, nn, false)
        renderer.gradient(x + w - 1, y + radius, 1, h - radius * 2, r, g, b, a, r, g, b, nn, false)
        renderer.circle_outline(x + radius,     y + h - radius, r, g, b, nn, radius,  90, 0.25, 1)
        renderer.circle_outline(x + w - radius, y + h - radius, r, g, b, nn, radius,   0, 0.25, 1)
        renderer.rectangle(x + radius, y + h - 1, w - radius * 2, 1, r, g, b, nn)
        if ui.get(ui_wm_glow) then
            for radius2 = 4, glow do
                local rr = radius2 / 2
                OutlineGlow(x - rr, y - rr, w + rr * 2, h + rr * 2, rr, r, g, b, glow - rr * 2)
            end
        end
    end

    -- container: blur → тёмный фон → faded rounded rect (точная копия solus.container)
    local function wm_container(x, y, w, h, r, g, b, a, alpha)
        if alpha * 255 > 0 then renderer.blur(x, y, w, h) end
        RoundedRect(x, y, w, h, rounding, 17, 17, 17, a)
        FadedRoundedRect(x, y, w, h, rounding, r, g, b, alpha * 255, alpha * o)
    end

    local function wm_measure(segments)
        local w = 0
        for i = 1, #segments do
            w = w + renderer.measure_text("", segments[i].text)
        end
        return w
    end

    local function wm_draw(x, y, segments)
        for i = 1, #segments do
            local s = segments[i]
            local c = s.color
            renderer.text(x, y, c[1], c[2], c[3], c[4], "", 0, s.text)
            x = x + renderer.measure_text("", s.text)
        end
    end

    -- состояние фейда (как в solus: 0..1, шаг 8*frametime)
    local wm_alpha = 0

    local function wm_paint()
        local target = ui.get(ui_wm_enable) and 1 or 0
        local step   = 8 * (globals.frametime() or 0.016)
        if wm_alpha < target then wm_alpha = math_min(target, wm_alpha + step)
        elseif wm_alpha > target then wm_alpha = math_max(target, wm_alpha - step) end

        if wm_alpha <= 0.01 then return end

        local r, g, b, _a = ui.get(ui_wm_color)
        local global_a    = math_floor(255 * wm_alpha)
        local accent      = { r, g, b, global_a }
        local white       = { 255, 255, 255, global_a }

        -- название чита: первая половина белая, вторая — акцент (как в solus)
        local cheat       = wm_get_text(ui_wm_cheat_name, DEFAULT_CHEAT_NAME)
        local split       = math_floor(#cheat / 2)
        local cheat_left  = cheat:sub(1, split)
        local cheat_right = cheat:sub(split + 1)

        local segments = {
            { text = cheat_left,  color = white  },
            { text = cheat_right, color = accent },
        }

        if ui.get(ui_wm_beta) then
            local beta = wm_get_text(ui_wm_beta_text, DEFAULT_BETA_TEXT)
            table.insert(segments, { text = (" [%s]"):format(beta), color = white })
        end

        local nickname = wm_get_text(ui_wm_nickname, wm_local_player_name())
        table.insert(segments, { text = (" | %s"):format(nickname), color = white })

        if wm_is_in_game() then
            local lat = (client.latency() or 0) * 1000
            if lat > 5 then
                table.insert(segments, { text = (" | delay: %dms"):format(lat), color = white })
            end
        end

        local hh, mm, ss = client.system_time()
        table.insert(segments, {
            text  = (" | %02d:%02d:%02d"):format(hh, mm, ss),
            color = white,
        })

        -- размеры/позиция как в solus watermark: высота 19, padding 4 слева
        local box_h = 19
        local box_w = wm_measure(segments) + 8

        local screen_w = client.screen_size()
        local x = screen_w - box_w - 10
        local y = 8 + 2  -- (8 + 25*0) + 2 как в solus, для первой "заметки"

        -- container уже включает blur + rounded rect + faded rect + glow цикл
        wm_container(x, y, box_w, box_h, r, g, b, _a * wm_alpha, wm_alpha)
        wm_draw(x + 4, y + 4, segments)
    end

    -- Защищённая обёртка: внутри renderer.blur/gradient/circle_outline есть
    -- редкие кейсы падения (нулевые размеры в момент resize, оборачивание
    -- параметров). Один сбой не должен ломать paint_ui.
    client.set_event_callback("paint_ui", function()
        pcall(wm_paint)
    end)
end

-- [x]======================[ Aimbot Helper (из lunaris) ]======================[x]
do
    -- UI для aimbot helper
    local ui_aimbot_helper = ui.new_checkbox("RAGE", "Other", "Aimbot Helper")
    local ui_helper_weapons = ui.new_multiselect("RAGE", "Other", "  Helper weapons", 
        "AWP", "Auto snipers", "Scout", "Deagle", "Rifles")
    local ui_helper_safe_miss = ui.new_slider("RAGE", "Other", "  Safe point after X misses", 1, 10, 3, true, " misses")
    local ui_helper_body_miss = ui.new_slider("RAGE", "Other", "  Body aim after X misses", 1, 15, 5, true, " misses")

    -- Счетчик промахов
    local helper_miss_counter = 0
    local helper_last_target = nil

    -- Проверка условий для активации
    local function check_helper_trigger(miss_count, miss_threshold)
        return (miss_count >= miss_threshold)
    end

    -- Обработка промахов
    local function on_aim_miss(e)
        if not ui.get(ui_aimbot_helper) then return end
        
        -- Увеличиваем счетчик только для prediction error и spread
        if e.reason == "prediction error" or e.reason == "spread" then
            helper_miss_counter = helper_miss_counter + 1
            helper_last_target = e.target
            
            if ui.get(ui_logs) then
                reso_log(255, 165, 0, "Aimbot helper: %d misses on player %d", 
                    helper_miss_counter, e.target)
            end
        end
    end

    -- Сброс счетчика в начале раунда
    local function on_round_start()
        helper_miss_counter = 0
        helper_last_target = nil
    end

    -- Применение helper логики
    local function apply_aimbot_helper()
        if not ui.get(ui_aimbot_helper) then return end
        
        local me = entity.get_local_player()
        if not me or not entity.is_alive(me) then
            helper_miss_counter = 0
            return
        end

        -- Получаем текущую цель
        local players = entity.get_players(true)
        if #players == 0 then return end

        for _, target in ipairs(players) do
            if entity.is_alive(target) and not entity.is_dormant(target) then
                local hp = entity.get_prop(target, "m_iHealth") or 100
                local weapon = entity.get_player_weapon(me)
                if not weapon then return end
                
                local weapon_class = entity.get_classname(weapon)
                local weapons = ui.get(ui_helper_weapons)
                local should_apply = false

                -- Проверяем тип оружия
                if contains(weapons, "AWP") and weapon_class == "CWeaponAWP" then
                    should_apply = true
                elseif contains(weapons, "Auto snipers") and 
                       (weapon_class == "CWeaponSCAR20" or weapon_class == "CWeaponG3SG1") then
                    should_apply = true
                elseif contains(weapons, "Scout") and weapon_class == "CWeaponSSG08" then
                    should_apply = true
                elseif contains(weapons, "Deagle") and weapon_class == "CDEagle" then
                    should_apply = true
                elseif contains(weapons, "Rifles") and 
                       (weapon_class == "CWeaponAK47" or weapon_class == "CWeaponM4A1") then
                    should_apply = true
                end

                if should_apply then
                    local miss_threshold = ui.get(ui_helper_safe_miss)
                    local body_miss_threshold = ui.get(ui_helper_body_miss)

                    -- Safe point после промахов
                    if check_helper_trigger(helper_miss_counter, miss_threshold) then
                        set_safe_point(target, "On")
                    end

                    -- Body aim после промахов
                    if check_helper_trigger(helper_miss_counter, body_miss_threshold) then
                        set_body_aim(target, "Force")
                    end
                end
            end
        end
    end

    -- Обновление видимости UI
    local function update_helper_visibility()
        local enabled = ui.get(ui_aimbot_helper)
        ui.set_visible(ui_helper_weapons, enabled)
        ui.set_visible(ui_helper_safe_miss, enabled)
        ui.set_visible(ui_helper_body_miss, enabled)
    end

    -- Регистрация событий
    client.set_event_callback("aim_miss", function(e)
        pcall(on_aim_miss, e)
    end)
    
    client.set_event_callback("round_start", function()
        pcall(on_round_start)
    end)
    
    client.set_event_callback("net_update_end", function()
        pcall(apply_aimbot_helper)
    end)

    -- UI коллбеки
    ui.set_callback(ui_aimbot_helper, update_helper_visibility)
    update_helper_visibility()

    -- Добавляем в set_visibility
    local original_set_visibility = set_visibility
    set_visibility = function()
        original_set_visibility()
        local on = ui.get(ui_ref.enable)
        ui.set_visible(ui_aimbot_helper, on)
        update_helper_visibility()
    end
end
do
    -- Красивая анимация для "Fracture" с эффектами
    local clantag_sequence = {
        '        ',  -- пустота
        'F       ',  -- появление F
        'Fr      ',  -- добавляем r
        'Fra     ',  -- добавляем a
        'Frac    ',  -- добавляем c
        'Fract   ',  -- добавляем t
        'Fractu  ',  -- добавляем u
        'Fractur ',  -- добавляем r
        'Fracture',  -- полное слово
        'Fracture',  -- держим
        'Fracture',  -- держим
        'Fracture',  -- держим
        'F r a c t u r e',  -- разделяем буквы
        'F  r  a  c  t  u  r  e',  -- еще больше разделяем
        'F   r   a   c   t   u   r   e',  -- максимальное разделение
        'F  r  a  c  t  u  r  e',  -- сжимаем обратно
        'F r a c t u r e',  -- сжимаем
        'Fracture',  -- собираем
        'Fracture',  -- держим
        'Fractur ',  -- убираем e
        'Fract   ',  -- убираем ur
        'Fra     ',  -- убираем ct
        'Fr      ',  -- убираем a
        'F       ',  -- убираем r
        '        ',  -- пустота
        '        ',  -- пауза
        '        ',  -- пауза
    }

    -- Состояние анимации
    local clantag_index = 1
    local clantag_last_update = 0
    local clantag_enabled_last = false

    -- Обновление клантега
    local function update_clantag()
        local enabled = ui.get(ui_clantag_enable)
        local current_time = globals.realtime()
        
        -- Если клантег выключили - очищаем
        if not enabled then
            if clantag_enabled_last then
                client.set_clan_tag("")
                clantag_enabled_last = false
            end
            return
        end
        
        clantag_enabled_last = true
        
        -- Получаем скорость и вычисляем интервал
        local speed = ui.get(ui_clantag_speed)
        local interval = 0.5 / speed  -- от 0.05 (10x) до 0.5 (1x) секунды
        
        if current_time - clantag_last_update < interval then
            return
        end
        
        clantag_last_update = current_time
        
        -- Устанавливаем текущий кадр анимации
        local tag = clantag_sequence[clantag_index] or ""
        client.set_clan_tag(tag)
        
        -- Переходим к следующему кадру
        clantag_index = clantag_index + 1
        if clantag_index > #clantag_sequence then
            clantag_index = 1
        end
    end

    -- Обновление клантега в paint
    client.set_event_callback("paint", function()
        pcall(update_clantag)
    end)

    -- Очистка клантега при выгрузке
    client.set_event_callback("shutdown", function()
        pcall(function()
            client.set_clan_tag("")
        end)
    end)
end

client.color_log(255, 215, 0, "[Parallax resolver] loaded successfully")


-- ============================================================
-- [MERU] DEFENSIVE + JITTER ENHANCEMENT
-- Пер-таргет трекер на базе m_flSimulationTime + ABAB yaw histogram.
-- Ничего не ломает в базовом резолвере — только выставляет флаги:
--   data.in_def_sim        — враг в defensive по simtime (choke 2+ тика)
--   data.def_release_tick  — тик, на котором defensive отпустился
--   data.abab_pattern      — двух-бакетный jitter (low-delta lunaris-стиль)
--   data.abab_buckets      — {a, b} два доминирующих yaw'а
-- ============================================================
do
    local M_floor = math.floor
    local M_abs   = math.abs
    local M_max   = math.max

    local function norm_yaw(a)
        a = (a + 180) % 360 - 180
        if a < -180 then a = a + 360 end
        return a
    end

    local sim_state = {}
    local function S(idx)
        local s = sim_state[idx]
        if not s then
            s = {
                last_simtime    = 0,
                choked_streak   = 0,
                in_def_sim      = false,
                def_release_at  = -1,
                yaw_hist        = {},
                yaw_hist_idx    = 0,
                abab_pattern    = false,
                abab_a          = 0,
                abab_b          = 0,
                confirmed_yaw   = nil,
                -- latency jitter predictor
                prev_eye_yaw    = nil,
                delta_sign      = 0,
                lat_jitter_side = 0,
                -- defensive flick killer
                last_choked     = false,
                flick_kill_side = 0,
                flick_until     = -1,
                flick_period    = 0,
                flick_last_tick = -1,
                flick_pre_yaw   = nil,
            }
            sim_state[idx] = s
        end
        return s
    end

    -- ABAB детектор: 12 последних eye_yaw, бакеты по 6°.
    -- Если два бакета дают ≥ 75% выборок и между ними разница 20..120° — это jitter.
    local function update_yaw_hist(s, yaw)
        local bucket = M_floor(norm_yaw(yaw) / 6) * 6
        s.yaw_hist[s.yaw_hist_idx % 12] = bucket
        s.yaw_hist_idx = s.yaw_hist_idx + 1
        local counts, total = {}, 0
        for i = 0, 11 do
            local v = s.yaw_hist[i]
            if v then
                counts[v] = (counts[v] or 0) + 1
                total = total + 1
            end
        end
        if total < 8 then s.abab_pattern = false; return end
        local t1k, t1c, t2k, t2c = nil, 0, nil, 0
        for k, c in pairs(counts) do
            if c > t1c then
                t2k, t2c = t1k, t1c
                t1k, t1c = k, c
            elseif c > t2c then
                t2k, t2c = k, c
            end
        end
        if t1k and t2k and (t1c + t2c) / total >= 0.75 then
            local gap = M_abs(norm_yaw(t1k - t2k))
            if gap >= 20 and gap <= 120 then
                s.abab_pattern = true
                s.abab_a = t1k
                s.abab_b = t2k
                return
            end
        end
        s.abab_pattern = false
    end

    local function tick_target(idx)
        if not (entity.is_alive(idx) and not entity.is_dormant(idx)) then
            sim_state[idx] = nil
            return
        end
        local s = S(idx)
        local cur_sim = entity.get_prop(idx, "m_flSimulationTime") or 0
        local dt = cur_sim - s.last_simtime
        local ti = globals.tickinterval()
        local dticks = (ti > 0) and M_floor(dt / ti + 0.5) or 0

        local was_def = s.in_def_sim
        if dticks == 0 then
            s.choked_streak = s.choked_streak + 1
        elseif dticks >= 2 then
            s.choked_streak = 0
        else
            s.choked_streak = M_max(0, s.choked_streak - 1)
        end
        s.in_def_sim = (s.choked_streak >= 2)
        if was_def and not s.in_def_sim then
            s.def_release_at = globals.tickcount()
        end
        s.last_simtime = cur_sim

        local _, eye_yaw = entity.get_prop(idx, "m_angEyeAngles")
        if eye_yaw then
            update_yaw_hist(s, eye_yaw)
            -- latency-compensated jitter side predictor (техника из Althea, очищена от math.random)
            if s.prev_eye_yaw ~= nil then
                local delta = norm_yaw(eye_yaw - s.prev_eye_yaw)
                local new_sign = (delta > 0.5) and 1 or (delta < -0.5) and -1 or 0
                if new_sign ~= 0 and s.delta_sign ~= 0 and new_sign ~= s.delta_sign then
                    -- знак перевернулся — jitter подтверждён
                    -- считаем сколько тиков пролетит пуля до сервера
                    local lat = (client.real_latency and client.real_latency()) or 0
                    local ti = globals.tickinterval()
                    local ticks_in_flight = (ti > 0) and M_floor(lat / ti + 0.5) or 0
                    ticks_in_flight = math.min(ticks_in_flight, 8)
                    -- флипаем текущую сторону N раз, чтобы угадать куда враг повернётся
                    local predicted = new_sign
                    for _ = 1, ticks_in_flight do predicted = -predicted end
                    s.lat_jitter_side = predicted
                else
                    s.lat_jitter_side = 0
                end
                if new_sign ~= 0 then s.delta_sign = new_sign end
            end
            s.prev_eye_yaw = eye_yaw
        end

        -- [PARALLAX] Defensive Flick Killer v2 — детектим НА РЕЛИЗЕ, не во время чока.
        -- Пока враг чокает, сервер не видит его новых углов. Когда пакет наконец
        -- приходит (dticks >= 3 = multi-tick gap) — это и есть флик: одним рывком
        -- eye_yaw прыгает на 70..180°. Body на ПРОТИВОПОЛОЖНОЙ стороне (Althea: body_yaw_offset = -sign(yaw_offset)).
        local tickcount = globals.tickcount()
        local anchor    = s.flick_pre_yaw    -- yaw до входа в defensive
        -- запоминаем yaw ПЕРЕД входом в defensive
        if not was_def and not s.in_def_sim and eye_yaw then
            s.flick_pre_yaw = eye_yaw
            anchor = eye_yaw
        end
        -- v3: baseline-yaw + 2-factor confirmation.
        -- 1) Строим baseline yaw из history без выбросов (мода по bucket'ам).
        -- 2) Детектим выброс как |yaw - baseline| >= 70°.
        -- 3) Требуем 2+ выброса в последние 50 тиков ДЛЯ подтверждения флика.
        -- 4) ROI: хотя бы 1 выброс должен совпасть с чоком или с in_def_sim.
        s.flick_events = s.flick_events or {}
        s.yaw_samples  = s.yaw_samples  or {}
        if eye_yaw then
            table.insert(s.yaw_samples, 1, eye_yaw)
            while #s.yaw_samples > 24 do table.remove(s.yaw_samples) end
        end
        -- baseline = мода по bucket'ам 30° на последних 24 sample'ах
        local baseline = nil
        if #s.yaw_samples >= 6 then
            local bcount, best_b, best_c = {}, nil, 0
            for i = 1, #s.yaw_samples do
                local b = M_floor(norm_yaw(s.yaw_samples[i]) / 30) * 30
                bcount[b] = (bcount[b] or 0) + 1
                if bcount[b] > best_c then best_b, best_c = b, bcount[b] end
            end
            if best_b then baseline = best_b + 15 end    -- центр bucketа
        end

        if eye_yaw and baseline then
            local raw_delta = norm_yaw(eye_yaw - baseline)
            local abs_delta = M_abs(raw_delta)
            if abs_delta >= 70 and abs_delta <= 180 then
                -- это выброс — записываем как flick event
                table.insert(s.flick_events, 1, {
                    tick    = tickcount,
                    dir     = (raw_delta > 0) and 1 or -1,
                    in_def  = s.in_def_sim or was_def or (dticks >= 2),
                })
            end
        end
        -- чистим старые events (>50 тиков = ~0.75с на 64tr)
        for i = #s.flick_events, 1, -1 do
            if tickcount - s.flick_events[i].tick > 50 then
                table.remove(s.flick_events, i)
            end
        end

        -- Подтверждение: 2+ events и хотя бы 1 из них in_def
        local conf_count, def_count, latest_dir = 0, 0, 0
        for i = 1, #s.flick_events do
            local ev = s.flick_events[i]
            conf_count = conf_count + 1
            if ev.in_def then def_count = def_count + 1 end
            if i == 1 then latest_dir = ev.dir end
        end
        if conf_count >= 2 and def_count >= 1 and latest_dir ~= 0 then
            s.flick_kill_side = -latest_dir
            s.flick_until     = tickcount + 24
            s.flick_last_tick = tickcount
        elseif tickcount > s.flick_until and s.flick_kill_side ~= 0 then
            s.flick_kill_side = 0
            s.flick_period    = 0
        end

        -- Прокидываем флаги в резолверный data
        local ok, d = pcall(function() return resolver:get_data(idx) end)
        if ok and d then
            d.in_def_sim           = s.in_def_sim
            d.def_release_tick     = s.def_release_at
            d.abab_pattern         = s.abab_pattern
            d.abab_buckets         = { s.abab_a, s.abab_b }
            d.latency_jitter_side  = s.lat_jitter_side
            d.flick_kill_side      = (tickcount <= s.flick_until) and s.flick_kill_side or 0
            d.flick_period         = s.flick_period

            if s.in_def_sim then
                -- заморозка side flipping на время дефенсива
                d.defensive_lock_until = globals.tickcount() + 32
            end
            if s.def_release_at == globals.tickcount() then
                -- defensive только что отпустился — сбрасываем miss counter
                if d.miss     ~= nil then d.miss     = 0 end
                if d.def_miss ~= nil then d.def_miss = 0 end
                -- фиксируем свежий baseline yaw
                if eye_yaw then s.confirmed_yaw = eye_yaw end
            end
        end
    end

    client.set_event_callback("net_update_end", function()
        local lp = entity.get_local_player()
        if not lp or not entity.is_alive(lp) then return end
        local enemies = entity.get_players(true)
        for i = 1, #enemies do tick_target(enemies[i]) end
    end)

    client.set_event_callback("round_start", function() sim_state = {} end)
    client.set_event_callback("player_disconnect", function(e)
        if e and e.userid then
            local i = client.userid_to_entindex(e.userid)
            if i then sim_state[i] = nil end
        end
    end)

    -- =========================================================
    -- ESP-флаги резольвера (JITTER / DEF / FLICK)
    -- =========================================================
    local ui_resolver_flags = ui.new_checkbox("RAGE", "Other", "ESP flag: Resolver mode")

    local function rf_get_kind(p)
        if not ui.get(ui_resolver_flags) then return nil end
        if not entity.is_enemy(p) then return nil end
        if not entity.is_alive(p) or entity.is_dormant(p) then return nil end
        local s = sim_state[p]
        if not s then return nil end
        local tick = globals.tickcount()
        if s.flick_kill_side ~= 0 and tick <= s.flick_until then return "flick" end
        if s.in_def_sim then return "defensive" end
        if s.abab_pattern or s.lat_jitter_side ~= 0 then return "jitter" end
        return nil
    end

    client.register_esp_flag("FLICK", 255,  80, 255, function(p) return rf_get_kind(p) == "flick"     end)
    client.register_esp_flag("DEF",   255, 140,  40, function(p) return rf_get_kind(p) == "defensive" end)
    client.register_esp_flag("JIT",   100, 220, 255, function(p) return rf_get_kind(p) == "jitter"    end)
end


-- ============================================================
-- MERU CHIBI — ��вто-рендер слева от меню (117%, flip horizontal)
-- ============================================================
do
    local ok_images, _images = pcall(require, "gamesense/images")
    local ok_gif, gif_dec    = pcall(require, "gamesense/gif_decoder")
    if ok_images and ok_gif and gif_dec and gif_dec.load_gif then
        local MERU_W, MERU_H = 174, 254
        local MERU_SCALE     = 1.17
        local MERU_FLIP      = true
        local start_time     = globals.realtime()
        local meru = gif_dec.load_gif("\x47\x49\x46\x38\x39\x61\xAE\x00\xFE\x00\xF7\x00\x00\x0A\x04\x05\x0D\x06\x0C\x0C\x09\x0D\x13\x05\x05\x1D\x03\x05\x13\x06\x0D\x1B\x06\x0D\x13\x0A\x0E\x1C\x0A\x0D\x16\x10\x0E\x0B\x07\x10\x0D\x09\x11\x14\x06\x11\x1C\x06\x12\x14\x0A\x12\x1B\x0B\x14\x17\x0E\x18\x1D\x0D\x19\x14\x12\x14\x1C\x12\x14\x1C\x12\x1A\x1C\x1A\x1B\x25\x04\x05\x24\x06\x0C\x2B\x06\x0E\x24\x0A\x0D\x2B\x0A\x0E\x33\x06\x0D\x3A\x07\x0A\x34\x0A\x0D\x2A\x10\x0E\x24\x06\x12\x2C\x06\x11\x23\x0B\x14\x2C\x0B\x14\x29\x07\x18\x24\x0E\x1A\x2C\x0D\x1B\x33\x06\x11\x3B\x06\x12\x33\x0B\x14\x3C\x0B\x13\x33\x0E\x1B\x3A\x0E\x1C\x24\x12\x14\x2C\x12\x15\x26\x19\x16\x24\x11\x1C\x2C\x12\x1C\x23\x1B\x1C\x2D\x1A\x1B\x33\x13\x15\x3B\x12\x15\x34\x18\x16\x33\x14\x1B\x3A\x13\x1C\x34\x1A\x1D\x3B\x1B\x1D\x2E\x21\x1F\x1E\x1D\x20\x37\x0E\x21\x2D\x13\x22\x26\x18\x22\x33\x12\x22\x3C\x13\x23\x37\x19\x27\x3A\x1C\x22\x35\x17\x2A\x29\x24\x26\x37\x26\x28\x39\x31\x34\x47\x08\x0B\x56\x0A\x0B\x47\x06\x13\x44\x0B\x13\x4C\x0B\x14\x44\x0C\x1A\x4C\x0D\x19\x57\x07\x15\x53\x0B\x14\x5A\x0A\x15\x54\x0C\x1A\x5B\x0C\x1A\x48\x12\x15\x44\x14\x1A\x4C\x15\x1B\x43\x1B\x1C\x4B\x19\x1D\x53\x15\x1C\x58\x15\x18\x5B\x13\x1C\x53\x19\x1D\x67\x0F\x0A\x76\x15\x0B\x67\x0B\x17\x63\x0D\x1C\x73\x0D\x1C\x79\x0D\x1A\x63\x14\x1C\x6B\x13\x1D\x67\x18\x1A\x74\x15\x1B\x7C\x12\x1D\x5F\x22\x1D\x42\x14\x26\x43\x1D\x21\x43\x15\x29\x47\x1A\x29\x58\x19\x22\x4C\x1B\x33\x54\x1A\x32\x79\x0E\x24\x64\x15\x21\x6C\x12\x26\x6A\x16\x24\x63\x1C\x23\x6B\x1C\x24\x73\x13\x23\x7C\x13\x23\x78\x1B\x26\x46\x25\x28\x58\x24\x28\x49\x2A\x36\x56\x28\x36\x4A\x35\x38\x69\x24\x28\x77\x24\x2A\x79\x2C\x34\x68\x32\x36\x76\x31\x36\x4B\x41\x3F\x55\x31\x44\x69\x35\x4F\x4F\x45\x49\x6E\x48\x54\x75\x52\x68\x76\x6A\x70\x83\x12\x1C\x8B\x14\x1A\x8A\x14\x1E\x88\x19\x19\x8F\x26\x15\xAB\x25\x15\x84\x14\x22\x8C\x14\x23\x8B\x1A\x23\x86\x13\x29\x86\x1A\x28\x8C\x1B\x2B\x97\x17\x26\x94\x1B\x24\x94\x1B\x2C\x9C\x1C\x2D\x93\x1B\x31\x9D\x1D\x31\xA6\x1D\x2A\xA3\x1D\x2D\xB2\x1E\x2F\xA2\x1D\x32\xAB\x1D\x31\x87\x25\x2A\x96\x24\x29\x9B\x22\x2C\x85\x31\x20\x88\x2B\x36\x98\x29\x35\x93\x2C\x3A\x87\x31\x38\x99\x33\x37\xA4\x22\x2B\xA5\x26\x29\xAC\x24\x2D\xAD\x29\x2D\xB2\x26\x2D\xB3\x29\x2E\xB9\x2A\x2B\xAF\x31\x2D\xAB\x24\x32\xA5\x28\x33\xAD\x2B\x33\xB2\x25\x32\xB4\x2B\x32\xBB\x2C\x33\xB9\x2A\x3A\xA9\x35\x38\xBC\x33\x3B\xB9\x35\x38\xC9\x26\x1E\xCB\x2C\x27\xC5\x2E\x38\xC3\x32\x35\xC3\x33\x3B\xCB\x34\x3C\xC6\x39\x3A\xCC\x3A\x3C\xD2\x35\x3D\xD3\x3B\x3E\xD9\x3C\x3E\xAD\x43\x28\xD7\x5D\x1F\xEF\x71\x12\xD6\x43\x3B\x90\x37\x46\xA9\x39\x44\xB8\x3A\x42\xC5\x2E\x40\xC8\x39\x43\xCC\x3C\x42\xD3\x37\x43\xD5\x3D\x42\xDA\x3E\x42\xE3\x3E\x47\x89\x4E\x53\xB3\x48\x4A\xA5\x5E\x5F\x8E\x57\x6F\x90\x68\x71\xB2\x6F\x6C\xCB\x43\x45\xD4\x42\x43\xDD\x42\x44\xDD\x44\x48\xD8\x48\x4A\xD6\x4E\x50\xE1\x43\x46\xE4\x48\x4A\xE7\x52\x52\xCF\x68\x65\xF1\x90\x18\xF4\xAC\x16\xEB\x99\x23\xB4\x84\x7C\xD4\x90\x64\xA0\x5F\x81\x94\x71\x89\xAF\x77\x91\xC0\x78\x86\xAE\x8B\x90\xA6\x97\xA0\xB2\x92\xAB\xD0\x9D\x9A\xC7\x94\xAF\xD3\xAE\xAE\xDD\xC0\xBE\xD3\xB4\xCA\xE7\xB0\xD3\xF5\xBC\xE0\xD9\xC5\xD6\xEE\xD4\xD3\xF4\xD2\xEF\xF5\xE8\xEB\xFB\xF1\xF4\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x21\xF9\x04\x01\x00\x00\xFC\x00\x21\xFF\x0B\x49\x6D\x61\x67\x65\x4D\x61\x67\x69\x63\x6B\x0E\x67\x61\x6D\x6D\x61\x3D\x30\x2E\x34\x35\x34\x35\x34\x35\x00\x2C\x00\x00\x00\x00\xAE\x00\xFE\x00\x00\x08\xFF\x00\xF9\x09\x1C\x48\xB0\xA0\xC1\x83\x08\x13\x2A\x5C\xC8\xB0\xA1\x43\x82\x12\x1E\x4A\x9C\x48\xB1\xA2\xC5\x8B\x18\x33\xF2\x23\x12\x40\xA3\xC7\x8F\x20\x43\x8A\x6C\x28\xE1\xC0\xC8\x93\x28\x53\xAA\x5C\x48\x04\x82\x83\x95\x30\x63\xCA\xF4\x38\x81\x82\xC9\x99\x38\x73\xEA\x3C\x48\xE4\xC1\x8B\x9B\x3B\x83\x0A\x85\x49\xE1\x05\x09\xA0\x43\x93\x2A\xFD\x18\xA1\x07\x89\x97\x4B\xA3\x4A\xA5\x58\xE1\xC5\x8B\x08\x50\xA7\x6A\xDD\x8A\x70\x02\x8C\x17\x0F\xB8\x8A\x1D\xCB\xCF\xC7\x8B\xAF\x59\xC9\xAA\x5D\x5A\x14\xED\xDA\xB7\x49\x8B\xF8\xFC\x8A\x14\xAE\xDD\x99\x13\x48\x58\xFD\x79\xB7\xEF\x4C\x9F\x7A\xF9\xFA\x1D\x9C\xD2\x07\x09\x18\x25\x60\x3C\x25\xCC\x78\x64\xDB\x1E\x3D\xB0\x36\x9E\xCC\xF4\x05\xE4\xAB\x69\x29\x6B\x9E\x58\xD5\x87\x59\xB0\x75\x37\x8B\x66\x08\xE1\x85\x67\xAB\x0F\x42\x8F\x5E\x7D\xD0\xF4\x5E\xD0\xAC\x09\xFB\x28\x32\x31\xC6\xDE\xC0\x0F\x04\xC4\xF6\x4B\x24\x04\x1B\x2D\x55\x6E\x08\x69\x48\xA1\x44\x09\x12\xC8\xC1\xEA\xDE\xDD\x97\xC5\x92\x3A\x76\xEA\xC0\x99\xC3\xC6\x0A\x8E\x84\x5E\x91\x27\x87\xB0\x9C\xB9\x5D\x23\x19\xA0\x80\xFF\x09\x13\xC6\xCC\xA3\x3B\x77\xD8\xA4\xA1\x5D\xB0\xA8\x76\xE4\x11\x54\x7B\xD7\xCA\xA7\x48\x11\x21\x2C\x06\xA4\xF8\x02\xC6\x0C\xF9\x45\x96\xC8\x52\xCA\x1F\x67\xE4\x40\x50\x4F\xEF\x45\x80\x15\x05\xF3\x71\x55\x04\x0E\x36\xD8\x20\x1C\x0E\x32\xB8\x90\xC1\x12\x63\x98\x91\x88\x25\xA9\xC4\x12\xCB\x2A\xAB\xC8\x42\x8A\x1F\x78\xB0\x17\x81\x51\x0A\x2A\xC8\x1D\x11\x0D\x4A\x45\x44\x0B\x36\xE4\x20\x23\x0E\x34\x52\xC8\x82\x09\x52\x84\x01\x89\x2A\xAC\xD4\x92\x4B\x2E\xAE\x80\x98\x0A\x28\x73\xAC\x21\xC4\x01\x11\x90\xA0\xE0\x03\xB9\x45\xD4\xA2\x52\x44\xB0\x20\x83\x10\x35\x56\x49\xA3\x0C\x21\x28\xE1\x45\x28\x20\xB2\x92\x8B\x36\xDA\xE4\xB2\xCA\x22\x89\x3C\x32\x09\x1D\x37\x84\xF0\xC0\x92\x07\x64\xF6\xA4\x4C\x0F\xCA\xD0\x02\x0B\x13\x20\x80\x00\x0B\x2E\xC8\xA0\xA7\x0C\x56\x52\xA8\x01\x14\x1C\x76\x99\x8B\x33\xBF\xE4\x32\x4B\x28\x8F\x94\x39\xC9\x1C\x1A\x3C\x00\xC1\x03\x05\x18\xF1\xE6\x4C\x3E\xE4\x69\x03\x0E\x54\x52\xA8\xA7\x0B\x21\x48\xC9\x67\x9F\x3F\x88\xB0\x84\x19\xA1\xA8\x22\xA4\x97\x3F\x1A\x6A\x49\x22\xE6\xDD\x51\x45\x03\x0D\x1C\xFF\x50\xC1\xA4\x30\x45\x69\x43\xA6\x7D\x5E\xC9\x42\x08\x9F\x5A\x29\x84\x0C\x29\x8C\xB1\x48\x2A\xB2\x88\xB2\xC8\x22\xAB\xA4\xAA\x8B\x2E\xA9\x90\xF9\x08\x91\x1A\x4C\x10\xC3\x04\x3A\xD0\x8A\x12\x05\x2C\xE0\x90\x83\xA6\x7D\x0A\xE1\x6D\x11\x32\x64\x2B\x44\x11\x78\x78\x6B\xEE\x0C\x4D\x98\x11\x89\x28\x91\x24\x92\xC8\x22\xB2\xA4\xFA\x63\x2C\x90\xBC\x1B\x8A\x1F\x34\xE4\x49\x27\x8B\xD6\x82\x34\xC1\x94\x57\xEE\xE9\xAB\xB7\x78\xE8\x61\x43\x0B\x45\xE8\xA1\xF0\x7D\xDE\xE2\x10\xAC\x79\xEE\xBA\xBB\xC8\x2C\xCC\xC8\x3B\x8B\x28\x98\xA4\x32\x8B\x29\x53\xE4\x19\x2E\x0B\xFD\x5E\x24\x27\x1F\x7C\x4C\x70\x2B\xAE\xB9\x62\x3A\xAE\xC2\x78\xB4\x20\x84\xC2\x7C\xE8\xC1\xB0\x10\x33\x3C\x01\x86\x17\x61\x24\xAA\xE1\x22\xB1\xFC\xF8\xCB\x33\xCF\x04\x53\x0B\x88\xB8\xA0\x42\xC5\xA7\x74\x86\x5C\x11\x0D\x5A\xA4\x80\x80\x0B\xE6\xA6\x5C\xA3\x10\x05\xC7\x8C\xC7\xC1\x55\xB3\x7C\x9F\xC3\x52\x40\xE1\x85\x86\x11\x43\x12\xCB\xCF\xDB\x6C\xF3\x0C\x90\xAD\xA8\x22\x8A\x1F\x35\xD4\xE8\x42\x02\xFC\x2A\xDD\x90\x11\x54\xD4\x21\x46\x07\x21\x5C\x39\x27\x0B\x7C\xF3\xFF\xDD\x42\x0B\x7A\x26\x1C\xF3\xD6\x22\x50\x8D\xC7\xE1\x05\xE3\x81\xC3\x0C\x49\x38\xE1\x84\x17\x11\xBF\x9B\x4A\x2E\x40\x6B\x73\x76\x2D\x17\x27\x02\x0A\x1B\x6D\x5F\x29\xAD\xDC\x0D\x15\x81\x85\x1D\x66\x7C\x71\x42\x06\x7D\xFB\xFD\xF7\xEA\x7F\xF3\x49\x6E\xC3\x22\xDC\xBA\xAD\x8C\x87\x3F\xD8\xC1\x12\x5E\x87\x21\x31\x26\xAB\xF8\x18\xCC\xEF\xB9\x0C\x4D\x09\x18\x60\xD0\x31\x43\x95\x32\x4C\xE0\x24\xE8\x09\xE9\x00\x07\xE9\x60\x48\x71\x82\x08\x7A\x4E\x4D\x23\xC1\xE5\x1E\x7C\x32\x0E\x21\xB8\x2C\xE3\xF7\x25\xE6\x30\x03\x07\x50\x78\x6D\x07\x24\x95\xAC\xD2\x8A\x2B\xB5\xD8\xF2\xA3\x2D\xAB\x58\x12\x86\x17\x4E\x80\x51\x85\x07\x7C\xFE\xF0\x43\xF2\x13\x30\x9F\x90\x0C\x72\x60\x95\x19\xDE\xF0\x85\x14\x88\xC0\x4A\x32\xA2\x1A\xC9\xB2\xF7\x37\x1C\xB4\x20\x03\x1A\xF8\x9E\x04\x65\x84\x02\x0C\x2C\x41\x0A\x5E\x00\x43\xFA\x56\xC1\x8A\x0E\xD6\x62\x68\x95\xA8\xD7\xCD\xBC\xC6\x06\x0D\x20\xA0\x05\x55\x4A\x9A\xFF\x0C\xD2\x82\x3B\xB8\x4B\x43\x60\x80\xC2\x11\x50\x50\xA5\x04\x22\x2E\x07\x11\x3A\x58\xF7\x34\x90\x81\x19\xD4\x40\x82\x10\x9A\x81\x08\xFF\x32\x80\x81\x26\x64\x90\x77\x1D\x64\xC5\x2C\x56\x81\x89\x63\x91\x69\x84\x50\x10\x83\x12\x32\x90\x81\xBC\xD5\x48\x85\x2B\x14\x48\x0C\x58\xE0\x42\x48\x2C\x22\x12\x96\x58\x44\x19\x9E\x70\x3C\x1A\x45\x08\x53\x87\xA3\xD2\xC1\x1E\x48\xC5\x0B\x68\x40\x03\xAC\x13\xC1\x1B\x79\x78\x81\x0E\x48\x01\x0C\x8B\xE0\x91\x12\x63\xC1\x89\x4A\x58\x02\x12\x22\xF4\x82\x17\xA0\xF0\x85\x28\xF0\xD0\x00\x19\xE8\xD5\x04\x66\x95\xC5\x0A\x4C\x60\x06\xE7\xAB\x05\x2B\x78\xA4\x0A\x4B\x94\xA1\x09\x28\xA8\x41\x0B\xDA\xF6\x32\x3E\xEC\xA1\x5C\x54\xAA\x41\x06\x2C\x90\x01\x11\xCC\xC0\x87\xB4\x3B\x9C\xF8\x50\x90\x01\x02\x24\xA1\x0E\x66\xB0\x04\x07\x59\x41\x8B\x55\x78\x28\x16\xB2\xC0\x44\x24\xA0\x28\x85\x0E\x50\xB1\x8A\x97\xA2\xD1\x22\x57\x38\x2D\x19\x50\x81\x12\xA9\x70\x46\x30\x5C\xD1\xC1\x54\x44\xA2\x0E\x4B\x40\xA1\xB6\x72\x50\xB0\x3D\xA4\xE1\x7B\x35\x78\xE3\x0F\x25\x88\x87\x3D\xB0\x2C\x8D\x2D\x40\x41\x13\xC4\x60\x07\x51\x24\xB1\x15\xE8\x6C\x05\x88\xD8\x65\x86\x41\x42\x81\x03\x55\x84\x41\x0B\x0E\x48\x23\x18\xC8\x87\x56\x44\xF8\x97\x0D\xAA\x20\xFF\x0B\x5A\x38\x43\x1B\xB6\x68\x05\x2B\x6C\x29\x89\x38\xA4\xE0\x78\x32\x4A\x98\x35\x67\x64\xCA\xEF\xA5\xE1\xA1\x0F\xC5\x43\x1A\xAC\x60\x05\x88\x5A\x41\x46\x34\x58\x42\x19\x4C\xD5\xC1\x74\xAA\x33\x15\x21\x7C\x44\x1D\xBE\x90\x84\x52\x5E\xAA\x81\x34\x0A\x01\x02\x40\x47\x04\x09\xF0\x49\x06\x5B\x98\x05\x2B\x82\xB1\x0D\x67\xD4\x82\x16\xAC\x88\x85\x26\xEC\x20\x86\x14\xD0\xE0\x7B\x7A\xF8\xA4\x8C\x4E\x99\x4A\xC4\x59\x94\xA2\x15\x9D\x68\x52\x73\x30\x85\x31\x84\x62\x16\x1E\xA5\x85\x3A\x39\x61\x89\x47\x3C\x82\xA7\x1B\x88\xDD\x50\xA5\xD9\x02\x04\x84\x65\x35\x83\x20\x82\x67\x28\x40\x81\x08\x40\x00\x02\xFD\x2B\xC8\x04\xF2\x44\x21\x36\x2C\xF1\x17\x65\xB3\x45\x2A\x2C\xF1\xC7\xF9\x2D\x41\x03\x6D\xA3\xA6\x50\x51\x99\x83\x34\x1C\x4E\xA9\x4A\xC5\xC3\x15\x2E\x9A\xD4\xC2\x5A\xE1\x0A\x62\x00\xC5\x2C\x5C\xC1\x58\x57\xA0\x73\x15\xEC\x82\x04\x25\x1E\xA1\x84\x10\xC4\x48\x46\x35\x38\x9E\x0D\x58\x80\x80\x18\x4C\x86\x08\x44\xA8\x00\x59\x29\xF0\x1E\xF8\xAC\xE9\x01\x92\x1A\xC8\x04\x58\x50\x83\xB6\xB5\x60\x0E\x4B\xFC\xD2\x33\x6A\xA1\x08\x77\xFF\x5D\x95\x7E\x29\xF0\x80\xB6\xFC\x9A\x86\x1B\xCC\x00\x71\x48\x0D\x2E\x45\xAF\x90\x87\x3C\x0C\x36\xA9\x0F\xA5\x68\x1A\xAE\xA0\x85\x49\xCC\xE2\x15\x8D\x65\x5F\x2E\xE9\x7A\x09\x2D\x60\x60\x06\x13\xF4\x61\x0B\x54\xDA\x17\x23\x10\x21\x06\x65\xD5\x8B\x67\x20\x73\x19\x25\x31\xA9\x01\x0E\x70\xC0\x03\x18\x24\x90\x28\xC9\xA0\x73\xAF\x5D\x62\x2D\x82\x51\x28\x4E\x2C\xC2\xAA\x8F\x68\xA7\x13\x38\x80\xDD\x6B\x0A\x91\x6A\x14\xCD\x01\x61\x85\x7B\x58\x36\xB0\x61\xB0\x57\x18\xEC\x44\x13\x7C\x85\x2D\xCC\x01\x14\xED\x7B\x85\x2D\x26\x3C\x34\x4C\xF8\xD1\x0E\x4A\x40\x81\x04\x1F\xAA\x49\x95\xB2\x57\x2C\x85\x10\xEB\x6B\x2C\x43\x5E\xF2\x1A\x45\x3B\x2A\x62\x52\x7A\x1D\x00\x01\x1F\x08\xE4\x5F\xD5\x73\x60\x1F\x64\xE1\xC7\x5C\xFC\xE2\x17\xB3\xF0\x22\x24\xAC\x0A\x86\x2F\x3C\xA1\x03\xA7\x44\x81\x08\x50\x20\x51\x01\x13\x38\xB8\x57\xA8\x42\x71\xAB\x90\xE0\xC3\x32\x38\xC1\x6C\x78\xB0\x2D\x7C\x41\xE5\x09\xDB\x82\x16\x98\xB0\x04\x25\xE4\x90\x02\x19\x21\x35\x0F\x78\x10\x81\x08\xD4\x34\x95\x42\x18\xA1\x08\x3E\xB0\x4D\x72\x20\xA3\xBF\x1F\x94\xF8\xFF\x32\x27\x86\x8F\x59\x1F\xB0\x62\x16\x3B\x00\xB4\x9E\xFA\x54\x0B\xB4\xB0\xAA\x48\xE8\xE2\xC6\xB9\x30\xD6\x8E\x6F\xFB\x85\xBB\x6A\x40\x8E\x37\xB8\xA6\x91\x8F\xEC\xE4\x04\x17\xB7\xC9\xC3\xBD\x82\x81\xB7\xC0\x86\x3E\x94\xE2\x17\x54\xA6\xF2\x8D\x5F\xC1\x89\x4B\x50\x22\x0B\x54\x30\x32\x71\xAD\x29\x82\x16\x3C\xA0\x7F\x46\x80\xC1\x4E\xC4\x0A\x5E\xB2\xBE\xC0\x38\x30\x60\xB3\xFE\xDE\x4C\xDE\xAF\x58\x25\x41\x11\x50\x71\x9D\x1D\x50\x80\x03\xC4\xC0\x4A\x32\xC8\x42\xBB\x16\xE1\xA3\x42\xDD\xA2\x12\xCE\x7A\xC4\x08\x4F\x30\x47\x01\x2F\x9A\xD1\x4D\x6E\x70\x1F\xD8\xC0\x64\x2A\x50\xA1\xD2\x7F\x08\xC4\x1F\xE6\x30\x87\x19\x07\x03\x18\xE0\x06\xB7\x30\x6C\xC1\x09\x4C\xDC\x61\x09\x48\x65\x03\x20\xD6\x4D\x83\x43\x3F\xC0\x05\x58\x98\x83\x81\x70\x52\x01\x00\x08\xE0\x01\x7A\x89\x75\x89\xDB\xDC\xE6\x37\xC3\xC0\xD6\xB8\xCE\x35\x9D\x77\xCD\xEB\x03\xAC\xF5\x53\xC1\x1E\xF6\x2C\x6C\x5C\xA8\xF8\x1D\x4B\xCB\x66\x90\x4E\x07\x34\x80\x82\x00\x1F\xF9\xC9\x4F\xAE\x42\xA5\xB5\x80\x85\x2D\x48\x5A\xDB\xD9\xDE\x76\x1F\xFC\x80\x8B\x5F\x04\x43\x18\x28\xFF\x47\x79\x2E\x52\x51\x5D\x2A\x1C\xB6\x0F\x81\x88\x79\x1F\x68\x30\x66\x1A\x94\xC2\x0F\x33\x58\xB5\x0F\x24\xC0\x62\x47\x91\xF6\x2C\xFA\xA6\x75\x0F\xFE\x7D\x6B\x14\x2F\x49\xD7\xBB\x3E\x80\xD2\xED\xC4\xD9\x2A\x0C\x7B\x72\x80\xAE\x45\x2A\x36\xD1\xA1\x8B\x59\x75\x09\x16\x98\x01\xA3\x1B\x8D\xF1\x04\x6F\xA1\x0F\x7D\xD0\x02\xD8\xB1\xF0\x87\x53\x9C\xE2\x0F\x7F\xE8\x03\x1D\xFA\x90\x05\x59\xA0\x9C\x18\x70\x87\xBB\x2F\x52\xE1\xAA\xC3\x02\x22\xE6\x31\xCF\x83\x06\x68\x60\x0A\xBA\xE7\x3C\x29\xDE\xDD\x41\x05\x78\xDE\x26\x26\x9D\xC8\x2A\x25\xFE\x8C\xD1\x99\x84\x74\x82\x2B\xBD\x00\x06\x28\x40\x15\x28\xE1\x2E\x4B\xFC\xD9\xE4\xCE\x08\xDE\xFA\x82\x74\xDF\x2F\x64\x1D\xDA\x5D\x7F\xF2\x16\xB4\xE0\x87\xB2\xFF\x61\x3A\x66\x37\xFB\x1F\xEE\xE0\x87\x39\xA0\xE2\x19\x71\x2F\x86\xEC\xA5\xD1\x0B\x51\xC0\x81\x0A\x57\x80\x39\xC8\x03\xC1\x06\x3F\x30\xAB\x0E\x1D\x10\x8B\x67\x1C\xC9\xE2\xB3\x1E\x3E\xCE\xE6\x1D\x38\xC1\xD3\xBB\x74\x3B\x45\x7E\x0A\x94\x38\x16\x24\x6A\xF1\x0B\x30\x69\x23\x18\xB6\x70\x2C\x3A\x45\xF1\x88\x38\x6C\x80\x06\x04\xC6\x7D\xFF\xE8\xAB\xC0\xE4\x06\x6B\xA1\xEC\x66\xF7\xC3\xF9\x53\x7F\x8A\x11\xFD\x01\x14\xCF\x88\x46\x31\x92\x21\xFB\x6D\x70\x63\x1B\xB7\x98\x04\x93\xB7\x80\xF6\x3F\x90\xE2\xEC\x7D\x10\x0A\x96\x30\x06\xC1\xF7\x16\xDE\x65\x13\x0E\x50\x14\x0A\x42\x02\x74\x76\x00\x01\x10\x00\x02\x10\x81\x01\xD0\x26\x4A\x67\x00\x21\x00\x03\x7A\x02\x03\x08\x50\x05\xA1\xE0\x2E\x8A\x30\x0B\xDA\xE0\x0D\xDE\xA0\x0D\xBF\x90\x7D\xE8\x14\x24\x96\x80\x61\x2E\x17\x69\xD6\x16\x7A\x49\x36\x05\x5B\x10\x83\x7D\xC0\x7E\xA4\x40\x06\x74\xD0\x7E\xA4\x90\x83\xA0\xE0\x07\x24\x27\x0D\xC9\x90\x0C\xDC\x10\x84\xF7\x47\x0C\xAC\x20\x06\x55\x30\x05\x7D\x80\x76\x39\x78\x0A\x7D\x90\x21\x77\xE3\x17\x31\x70\x00\x67\xA5\x6B\x15\x10\x37\xFC\x10\x03\x05\x90\x85\x27\x84\x3C\x21\xC0\x81\xEE\x52\x09\xB5\xF0\x4F\x96\x53\x82\x1F\xC4\x58\xB5\x50\x09\x8F\x80\x6E\x5C\xD7\x82\x0C\x56\x05\x31\x18\x83\x53\xE0\x86\x33\x48\x0A\xA6\x50\x87\xA6\xE0\x07\x62\x40\x87\xA6\xF0\x7F\xA4\x00\x07\x58\x50\x06\xDB\x00\x84\x42\x78\x7F\xDB\x10\x0C\x91\xB0\x04\x31\x88\x7E\x66\x17\x08\x64\x10\x45\x28\xFF\x30\x18\x44\x20\x00\xE9\x25\x00\xCB\xA3\x56\x21\x60\x00\xD2\x54\x23\xDB\x35\x05\x1D\x68\x09\xB1\x40\x0B\x83\xF2\x0C\x25\x18\x24\x1F\x64\x0B\x52\xF7\x08\x4D\xD0\x75\x55\xA0\x04\xA2\xF7\x86\xD4\xB6\x04\x74\xF0\x7F\x76\x58\x87\xA4\x20\x07\x7E\x60\x87\xA4\x40\x07\x4B\x90\x02\x4B\x80\x0B\x83\x38\x88\xD2\x50\x0B\x50\x10\x83\x7E\x70\x76\xC5\xC8\x84\x4F\xA0\x05\x7F\xE7\x17\x25\x21\x2B\x08\xE1\x5E\xBD\x52\x23\x21\x10\x02\x29\x00\x0A\x8B\x80\x09\x9C\x90\x0A\xAB\xB0\x2C\xB3\x00\x52\x9B\xD0\x3E\x13\x46\x0B\x91\x10\x05\xAA\x98\x02\x5E\xF7\x86\x5B\xD0\x71\x5B\x00\x8B\xB3\x38\x8B\x7E\x40\x07\x7B\xE8\x07\x70\xB0\x04\x27\x60\x02\x4A\x00\x0A\xF6\xF7\x8B\x41\x28\x0C\x91\x90\x05\x6A\x77\x0A\x59\x70\x8C\x7F\xA0\x05\x4D\x20\x02\x84\x11\x89\x8C\x74\x10\x6B\x95\x2B\x36\x50\x4A\x1D\x00\x0A\x5E\x44\x5D\x16\xF6\x47\x60\x68\x65\x13\x66\x09\x59\xC0\x60\x5B\xC0\x64\xAB\xE8\x86\xE8\x18\x83\x5A\x30\x07\x59\x90\x87\xED\x48\x8B\x70\xF0\x07\x74\xF0\x04\x49\xA0\x04\x27\xB0\x01\x4A\x30\x06\xDA\xA0\x8F\x3E\xB8\x0D\xB3\x00\x05\x7E\xD0\x07\xE4\xFF\xD7\x7E\x66\xD7\x07\x53\x90\x01\x8C\x91\x5A\x5D\x11\x8D\x9A\x18\x02\x62\xE6\x07\x61\x74\x5F\xFE\x61\x07\x8F\x00\x09\xAB\x60\x91\x53\x26\x0A\x59\x50\x7E\x07\x96\x60\x4A\x00\x83\xE8\x88\x05\x5A\x40\x07\x28\xF9\x04\xA0\x60\x87\xA5\x50\x0A\xA8\xB0\x87\x58\xD0\x04\x2B\xA9\x04\x66\xC9\x01\x4A\xF0\x04\xBA\x20\x84\xDB\x20\x0D\xC4\x10\x0C\x70\xF7\x0B\x65\x30\x07\x54\xB0\x01\xC5\xB8\x84\x7F\xB0\x05\x1A\xE0\x59\xAB\x61\x04\xFF\x92\x2B\x62\x26\x66\x74\x20\x0A\x90\x60\x07\x37\x93\x41\x66\x50\x91\x56\x46\x65\xA9\xA0\x05\xB8\x47\x69\x1E\x77\x05\x53\x60\x95\x58\x50\x99\x59\x49\x87\x7E\x90\x05\x63\x50\x87\x5F\x59\x0A\xA6\x70\x07\x5F\xC0\x01\x27\x90\x04\x4D\xD0\x04\x4B\xB0\x04\x49\x90\x04\x47\x10\x0A\xDC\x20\x0D\xD1\x40\x0C\xC3\x90\x0B\xAA\xF0\x0B\xC0\xF0\x0B\xA0\x70\x04\x16\x80\x05\x38\xC8\x87\x7D\x30\x03\x69\x35\x1A\xEE\x85\x40\x38\x10\x98\x22\x80\x05\xA5\xA0\x6C\x5E\xF0\x05\xFC\x91\x08\xA9\x00\x8E\x99\x06\x0C\xB2\xE0\x98\x6E\xC8\x06\x6F\x88\x05\x4A\x80\x95\x62\x00\x07\x74\xE0\x07\x74\x58\x0A\xA0\x30\x06\x79\xF8\x95\xA4\xFF\x80\x1E\x51\x70\x04\x1B\x90\x02\x4D\x10\x05\x51\x70\x9A\xA7\x79\x04\x77\x70\x63\x98\x56\x7B\x93\x70\x0B\xB7\x20\x0B\x4F\x60\x01\x1D\x30\x07\x7A\x98\x83\xA4\x30\x07\x56\xB0\x52\xAB\xC1\x37\x7D\x82\x43\x87\x26\x66\x0F\x79\x33\xCA\xF9\x05\x90\xC3\x09\xB4\x30\x65\x54\x06\x6E\xB3\x60\x84\xF1\x06\x76\x14\x8A\x84\xA0\x90\x83\x25\x69\x37\x77\x30\x9E\x52\x90\x8C\x51\x90\x04\x29\xA0\x04\xEA\x19\x05\x4F\xB0\x04\xEB\xA9\x04\x52\x00\x09\x96\x50\x09\x9B\xB0\x09\x63\x20\x07\xA0\x60\x07\xB8\x69\x01\x6C\xA0\x95\xB4\x98\x83\x5A\x70\x05\x1A\x60\x85\x9A\x71\x27\x03\xDA\x02\x05\x2A\x47\x74\x70\x98\x82\xE4\x05\x8F\xC0\x09\xAD\xE0\xA0\xE1\x76\x0B\x72\x10\x6F\xFE\x87\x8B\x62\x00\x8F\x25\x59\x87\x77\x50\x07\x5A\x50\x9E\x47\x90\x04\x5A\xC0\x06\xA8\x99\x04\x51\x20\x05\xEA\xF9\x04\x51\x80\x05\x49\xE0\x05\x95\x70\xA6\x98\x30\x09\x1C\x70\x04\x47\xC0\x01\x16\x60\x01\x1C\x10\xA5\xB7\x68\x0A\xA0\xB0\x9D\x07\x56\x03\xBF\xB9\x19\x07\x90\x2D\x08\x34\x44\xC4\xC9\x06\x75\x50\xA4\x19\x44\x09\x0C\x3A\x65\xDF\x06\x0C\xC2\x90\x0B\x75\xC0\x6D\x18\xFF\x6A\x87\x99\xE9\x95\xB8\x78\x07\x59\x20\x07\x4F\x90\xA5\xA8\xA9\x05\xF3\x98\x9A\x52\x00\xA6\x24\xFA\x04\x32\x54\x07\x9F\x70\xA6\x94\x70\x9F\x70\xBA\x04\x1C\x10\xA7\x63\xC0\x7A\xA8\x00\x0A\x64\x90\x95\x73\x50\x05\x56\xE0\x93\xA3\x71\x00\x96\x55\x43\x38\x50\xA0\x05\xCA\x04\x74\x20\xA8\x76\x70\x09\x0C\xDA\x0B\xBE\x80\xA8\x28\xA7\x0B\x72\x40\x07\x5A\xA0\x87\xB8\x48\x7A\xCA\x40\x8B\x7E\x20\x07\x4E\xA0\x9A\x62\xF0\x05\x47\xC0\x9E\x59\x00\x07\xEB\x99\x04\x9B\xBA\xA9\x4F\xF0\x05\x63\x80\x04\x94\x60\x61\x90\x00\x05\x6F\xBA\x01\x6C\xBA\xA6\xCA\x56\x06\x65\x50\x0A\x77\x20\x06\x21\x39\x07\x58\x70\x05\xAC\x24\x1A\x46\x40\xAB\x99\x48\x23\x9A\x34\x54\x22\x00\x02\x28\xC0\x06\x82\xFA\x08\x95\xC0\x09\xB5\x10\xAC\x29\x17\x0C\x7E\xD0\x01\x61\xF7\x07\x9C\xE9\x99\xA6\x40\x07\x79\x78\x07\xD6\xBA\x04\x6C\xAA\xA9\x75\x70\x04\x4F\x50\xB1\x98\x4A\xA2\x49\xF0\x04\xDA\x8A\x21\x86\x89\x09\x3B\x06\x05\x1B\x60\x01\x1B\xB0\xA6\x79\x50\x05\x5C\xD0\x2E\xE8\x0A\x0A\x65\x40\x06\x62\x10\xA5\x1D\x47\x05\xB2\xAA\x19\x44\x40\xAF\x56\x92\x59\xDF\xFF\x63\x03\x72\xD4\x54\x82\x04\x06\x94\x50\x09\xA9\x60\x0B\x88\x0A\x77\xCF\x10\x0A\x6E\x3A\x07\x59\x39\x8B\x39\x38\x07\x49\xD0\xA5\xA9\xB9\xB4\xA7\xF9\x04\x77\x50\xB1\x5D\x93\x9D\x1D\x5A\xB1\xE5\x53\xA9\xBD\x7A\x09\x68\xE8\x05\x6D\xCA\xA6\x53\x40\x0D\xF1\x70\x0D\xB1\x14\x09\x2B\xEB\x07\x64\xC0\xB2\x2E\x8B\x05\x55\xA0\x01\xA2\x31\xB3\x44\x59\x43\x44\x25\x41\x28\xD0\x01\x59\x20\x48\x6F\xA0\xB5\xAB\xF0\x0B\xC2\x10\x77\xD1\x90\x0B\xA5\x90\x05\x73\x60\xAC\xFC\x69\xAC\x2A\x79\xAA\xA9\xC9\x9E\x88\x7B\x07\x5D\xA3\x9C\x71\x10\x07\x3E\x96\x05\x9E\x5A\xA2\x50\x90\x09\x9E\x70\x09\x90\x00\x06\x48\x80\x04\x6C\xAA\x05\xD8\x40\x0F\xF4\x00\x0F\xB3\xE0\x08\xA1\x50\x06\x5C\x80\xAE\x67\x2B\x06\xEE\x5A\x99\x28\x90\xA7\x8D\x41\x04\x1F\x10\x02\x1A\x70\x29\xDF\xC3\x57\xDF\x73\x03\x1D\xA0\x04\x0A\xFA\x08\x98\x80\x09\xB4\xF0\x0B\x70\x17\x0D\xC0\x1B\x0D\xDB\xA0\x0B\x65\xC0\x06\x47\xA0\x9E\xD6\x7A\xB8\x49\xE0\x92\x15\xDB\xBC\x15\xBB\x04\x72\x50\x07\xDB\xFA\x05\x75\x30\x06\x1D\xAA\x05\xCD\x0B\x05\x8F\x40\x0B\x9E\x00\x09\x66\xC0\x05\xE0\xFF\x8B\x04\x7D\xB0\x0E\x9E\x4B\x0F\xF1\xC0\x0C\xAD\x10\x0A\xDF\x4B\x06\x65\x30\x06\x70\x10\x92\x6A\x8B\x05\x4E\xB3\x19\xBD\x31\x66\xD2\x34\x54\xDB\x14\x5C\x34\xB0\x01\x46\xF4\xAD\x00\x0B\x0C\xF2\x27\xBC\x84\xF8\x0C\x8F\xB0\xBC\x1C\xE0\xA5\xF3\x58\x9A\x4D\x70\xAA\xCD\xAB\x9E\x5D\xF3\x04\x62\x10\xB5\x52\xF0\x05\x8E\x0B\x05\x10\x5C\xB1\x48\x60\x07\x0C\x8A\x6C\x61\xD0\x05\x5D\xC0\x05\x7E\x40\xBE\xE5\x2B\x0F\xD5\xF0\x0A\xA9\xC0\x08\x5D\x80\xAE\xEE\xBB\xA5\xE4\x27\xBF\x00\x4A\x19\xF5\x3B\x8D\xB2\x2B\x3E\x3F\x24\x5C\x39\x80\x02\x1C\xF0\x05\x97\x80\x8D\xB6\x40\x0C\xD2\x20\x0D\xF9\x18\x84\xD2\x20\x0A\x49\x70\x02\x27\xA0\x04\x4B\xF0\x1B\xE9\xB9\x9E\x4B\x50\xB1\x0E\x3C\xC1\x50\x20\x05\x93\x10\xC5\xCA\x69\xC1\x10\x0C\x05\x75\x10\x06\x95\x40\x0B\x9C\x00\x09\x1D\xCC\x08\x8C\xE0\x07\xED\x50\xBE\xF7\x90\x0F\xF8\x60\x0D\xB0\x10\x0A\x28\x5C\x06\x55\xFA\xBE\x63\x79\x9D\x4A\xF0\xC2\x9F\xF5\x01\x63\x96\x01\x28\x84\xBF\xCF\x46\x51\xFB\x0B\x05\x3B\xEC\x09\xB6\x10\x0D\xFA\x18\x84\xBA\x20\x06\x4D\x6B\xA2\x70\x90\xAD\x9B\x0A\x05\x4E\xFF\x90\xAD\x09\x0A\x05\x93\xE0\x63\x56\xEC\x04\x63\x30\x09\x97\x70\x09\x96\x40\x9F\xC8\xD6\x05\x8C\xD0\x08\xA3\x00\x0F\xF8\x50\x0F\xF5\x80\x0F\xFA\xB0\x0F\xF8\x40\x0D\x1E\xFC\xC1\x2A\xEC\xC6\x4B\x70\x9D\x4C\x10\xB3\x73\x2C\x02\x24\x20\xC3\x78\x1C\x5C\x4A\x85\x02\x4B\x40\x09\x9A\xE0\x09\xBD\x00\xC8\x81\xFC\x0C\x93\x70\xB8\x4D\x9C\x9D\x8C\x5B\xC5\x13\x9C\xA0\x5F\xE0\xC8\x63\xE0\xBC\x75\x40\xB9\x9E\x90\x31\xCD\xD0\x09\x95\xF0\xC5\x8D\x70\x0E\xF8\x00\x0F\xF4\x30\xCA\xFB\x40\xCA\xA7\xD0\x08\x95\xD4\x05\x64\x30\x06\xEE\xAB\x9E\x4A\x90\x02\x5B\x00\xB3\xF4\x4B\xC7\xB1\xDC\x3D\xB3\x1C\x58\x7A\xAC\x04\x93\xE0\x09\x9E\xF0\x0B\xD2\x10\xC8\x41\x38\x0B\x5E\xE0\xB4\x1A\x0B\x07\x70\x60\xCC\x5F\x20\x05\xE0\x9C\x9C\xC7\x3C\x09\x60\xE0\xA9\x93\xEC\x09\x9F\xF0\x09\xE5\x16\x0B\xB7\xB0\x09\x8B\xC0\x05\x9A\xDC\x08\xE8\x30\x0E\xB8\x30\x0F\xD9\x9C\xCD\xF7\x50\x0D\xD8\x67\x09\x5E\x20\x06\x64\xA0\xCF\x4B\x20\xBF\x1D\x50\x05\x2B\x70\x01\x9B\x01\x1E\x22\xB0\x2B\x44\x89\x5D\x7C\xB5\x60\xC6\x75\x05\x54\x90\x02\x75\xA0\x09\x9F\xF0\x0B\xF4\xFF\x1C\x84\xCF\x70\x88\x4B\xA0\x05\x4E\x40\xC5\xFD\xDC\x35\x5A\x10\xAD\xCA\xA9\x05\xE5\x13\x09\x8F\x50\x06\x94\x20\x0A\xA9\xD0\x09\xB6\xE0\x0C\xAD\xF0\x8D\xB6\x50\x09\x1F\xDC\x05\x8E\x70\x0C\xE6\xB0\x0B\xAF\x20\x0F\x15\xBD\x0F\x24\x9C\xD1\x51\x04\x9E\x5A\xF0\xD1\x1C\x10\xD2\x29\x40\xD2\x9A\x51\x04\x06\x70\xD2\x24\xE0\xA7\x36\xE0\x43\xCA\x95\x06\x79\x00\x08\xCB\x55\x05\x29\xA0\x05\xA2\x10\x0B\xC0\x50\xD3\xF7\xA7\x0B\x63\x70\x04\x52\x20\x06\x9E\x8A\xC8\x16\x2C\x07\x7E\x6D\xC1\x50\x50\x06\xB2\xE0\x21\x0D\x0A\x0C\xD0\xD0\x9A\xBD\x90\x2C\xAE\xC0\x08\xE0\xDB\x08\xC7\x80\x0C\xE4\xC0\x0B\xAF\x00\x0F\x15\xAD\x0F\xD9\x00\x0B\xD8\x87\x09\x51\xC4\xB2\x5F\x8D\x05\x27\x90\x02\x72\xED\xCA\x8D\x61\x04\x67\x4D\x94\x62\x76\x68\xA8\x64\x05\x95\xB6\x6E\xC5\xC5\x06\xBC\x78\x09\x9F\x70\xD7\x41\xD8\x0D\x42\xF8\xC3\x3F\xEC\x0C\x99\x20\x43\x62\x00\xB9\x8E\x13\xC5\x24\x0A\x05\x55\x0A\x06\xBD\x9A\x0A\xBE\xF0\x0C\xD0\xC0\xCB\x42\x38\x6E\xC1\xA0\x0A\x51\x3D\xD9\xE4\x50\xD5\xAC\x80\xD5\xD9\x2C\x0F\xB8\x60\x0B\x19\x0D\xC1\x2C\x3B\xA2\x66\xFF\x59\xDA\xA2\x71\xD6\xC4\xB9\xDA\x35\xCC\x06\x78\x47\xA1\x55\x70\x04\x93\x50\xDB\x32\xF9\xC3\xD1\x60\x0B\x9B\x90\x82\x32\xA4\xB1\xCF\x7B\x9A\x51\x30\x06\x97\xE0\x09\x1E\xF2\x09\xAD\x40\x0C\xDC\x00\x0E\x00\x0E\x0E\x83\x18\x0D\xC0\x20\x0A\x1E\x6C\x0C\xE4\x40\x0E\xE5\x70\x0C\xBB\x60\x0C\xF8\x90\xCD\x9A\x0D\x0B\xE0\xE6\x0B\x96\x00\xC1\xEC\x6A\xA2\xAB\xCC\x04\x4D\xB0\x01\x72\x3C\x19\x08\x30\xDE\xE4\x9D\x03\xB9\x77\xDE\x23\x67\xBC\x65\xC0\x09\x70\x25\xC4\x3F\x0C\x0D\x2C\x4E\x0B\x9B\x80\x09\x1E\x52\x09\x89\x60\x07\x93\x60\x98\xC4\x63\xDC\xF9\x7D\xD0\xAD\xD0\x0B\x8B\x8D\xD7\xBE\x80\xC2\x8D\x90\xE0\xE5\xB0\xE0\xAF\x90\x0D\xA3\x8C\x0F\xD9\x80\x0B\xC2\xC0\x0D\xC4\xD0\x0B\x91\x00\xC1\xEF\x2B\xA6\x4D\xC0\x06\x53\xA0\x04\x26\x40\xD6\x9A\xF1\x00\xAA\x3D\xDE\x89\x96\x07\x78\x17\x73\x73\x90\x76\x1C\xA0\x05\x9A\x70\x0B\xDB\x00\xBC\x2C\x3E\x0C\xC3\x00\x0C\x2E\x4E\x0B\xF4\x49\x9F\x08\xFD\x09\xB1\x90\x0A\x07\x2D\xE7\x59\x86\x09\x9B\xD0\x0B\xDB\x80\xDB\x78\xFD\x0A\x1E\x7C\x0C\x43\xBE\xE0\xBB\xB0\x0C\xF3\x80\x0F\xF2\x60\x0D\xBA\xFF\x40\x0C\x68\xDE\x0B\x8F\x10\x45\xD6\xAA\x9E\x6C\x60\x08\xB2\x7D\x02\x20\xE0\x02\x9B\xB1\x2B\x20\x6E\x4A\x78\x70\x77\x31\x97\x6D\x61\xFE\x07\x56\xA0\x04\x97\x40\x0B\xF1\x07\x0D\x6B\x0E\x0C\xBD\x70\x65\xB4\x40\x0B\x9D\x50\xE7\xAB\xEE\xE6\xF4\xD9\x0B\xB2\xDE\x0C\xB5\x80\xE7\xBD\x30\xCF\x78\x0D\x0E\xC1\xC0\x05\xA3\x60\x0E\xE5\x60\x0E\x0C\xAE\x0A\xD9\xC0\x0E\xE3\xA0\x0D\x80\x4C\x0C\xA6\x3E\x0C\xBD\x60\x06\x98\xFA\xD5\x0A\x9C\x07\x54\x60\xC4\x28\x10\x02\x9B\xE1\x03\x5B\x1E\x98\x20\x30\x03\x6F\x8D\x77\x68\xD7\x07\x73\x70\x0A\x79\xC0\x01\x76\xB0\x0A\x88\x8A\xEA\xB2\xBE\xEA\x9F\xD0\xA2\xE5\x76\xA6\xEC\xCE\xA2\x9B\xF0\x09\x9D\x00\xEB\xB9\x40\x0B\xB7\x8E\xD7\xFF\x2D\x0C\x5D\x20\xD9\xC7\x70\x0C\xF4\xC7\x0D\xDE\x10\x84\x02\xFE\x9A\xA6\xCE\xE6\x63\x80\xA9\x2A\x59\x9A\x4C\xC0\x04\x46\x7C\x02\x2B\x60\x90\x65\x1D\x02\x25\x30\xDE\x87\xB6\x07\x9C\x6E\x76\xA4\xF0\x07\x64\xF7\x07\x4A\x20\x06\x98\x60\x0B\xBF\x70\x0B\x7C\xC4\x09\xEB\xCE\xEE\x80\xE4\x45\xC7\x22\x31\x80\xC4\xEE\x9B\xD0\xA0\xFE\x9D\xEB\xDC\x80\x0B\xB8\x00\x0C\xE0\xFF\x20\x0E\xE2\x10\x0E\x36\x2F\xE0\x3F\x0C\x9B\xA7\xEE\xD9\xEC\x9A\xB1\x4D\xC0\x04\xD6\x36\xDA\x54\xC0\x04\x8F\xB8\x19\x0F\x10\xF1\x12\xBF\x07\x78\xC7\x7E\x5B\xA0\x95\x58\xB0\x04\x90\xF0\x09\xF4\xC9\x09\x89\x30\x48\x3B\x7B\x98\xE0\x9B\xF5\x5C\x90\xB9\x99\xEB\x35\x38\x03\x09\xA2\x60\x0B\xC2\xC0\xDC\xB9\x3D\x88\xDF\x50\xF3\x36\x7F\xF3\xAD\xE9\xDE\x3A\x4F\x0C\xBF\xF0\x08\x52\x90\xA9\x51\x60\x60\x54\xB0\xBF\x6F\x5D\x05\xF9\x62\xF4\x99\x7E\x01\x5E\x1E\x73\xEC\xF7\x07\x59\xB0\x6D\x1C\x50\x06\xBC\x8B\xD0\x69\x9A\x05\xA7\xCA\xA6\x48\x00\xBE\x9A\x8C\xC2\x1F\x8C\x04\xA7\x1A\xF9\x47\x00\x05\x48\xC0\x08\xBA\x40\xF6\x83\x58\x0C\x70\x97\x0C\x69\x9F\xF6\x02\xCE\x0D\x9A\x1F\x0D\xBA\xC0\x0A\xC2\x30\x5B\x5E\x40\x90\x4B\xDB\x04\xD4\x60\x0D\x79\x90\x02\x54\x80\x0D\x80\x10\x1C\x96\xAE\x19\x14\x70\xED\x62\x96\x01\x6B\x50\xF1\x3A\x79\x0A\xD9\xE9\x07\x93\x1F\xF5\x9F\x90\xA6\x5C\x9B\xF8\x8B\xEF\xC1\x9B\xEC\x08\x8D\xD0\x08\x8C\xB0\xB2\xB1\xCD\x06\x79\x60\x4D\x29\xC0\x05\x6B\x29\x93\xB2\xF7\xDF\x9D\x1F\x0E\x00\x1E\x84\xBF\xEB\x0A\xAA\xFF\x80\xEC\x97\x00\xA6\x48\xBC\xCA\xD4\x70\x0E\xED\x80\x07\x87\x80\x0D\xE9\x48\x05\x2D\xB0\x19\x31\xD0\x00\x48\x2F\x02\x11\x9F\x01\x54\xD0\x07\x77\xC7\x9F\xE9\xF7\x04\x73\xD0\x04\x47\x50\x07\x94\x30\x09\x5C\xAB\xB9\x00\x71\xE4\x08\x12\x24\x5C\xBA\x74\x69\xE4\xC8\x91\xB5\x76\xF0\xE4\xC5\x83\xF8\x4E\xA2\x44\x77\xD4\x74\x49\xE3\x96\x91\x5B\x37\x6E\xE0\xC2\x7D\x04\x19\x0E\xDC\x48\x70\xDC\x8A\x11\x8B\x96\x92\x18\x34\x5D\x63\xA2\x3C\x49\xA2\x44\x49\x15\x6B\xF0\xE0\x61\x93\x07\x08\x0B\x96\x2A\x2D\xF8\xFD\x04\x1A\x54\xE8\x50\xA2\x45\x8D\x1E\x45\x6A\xF4\x41\x09\x11\x4D\x9B\x86\x98\xD1\xA7\x4F\x20\x52\xA4\x4C\x9D\x3A\x45\x4A\xCB\x92\x25\x02\x8F\x6C\xE0\x50\x90\x20\x12\x84\x8E\x8C\x1D\x3B\x86\xEC\x98\x3C\x7D\xF8\xE2\xD1\xA3\x77\xEF\x1E\xBE\x7C\x6D\xF1\xC9\xFB\xA6\x91\x98\x46\x8F\x21\x49\x8E\xCC\x28\x4D\x70\xCA\x62\xCF\x28\x3D\xE1\x0A\xA5\x4A\x1E\x6A\xED\xF0\xCD\x73\x37\xCF\xD0\xCE\x2A\x33\x92\x5E\xC6\x9C\x59\xB3\x50\x16\x21\x9C\x36\xCD\xA0\x21\x4F\x9E\x3E\x7F\xAA\xFA\x99\x83\x25\x85\x05\xD6\x16\x08\xB0\x26\x58\x16\x2D\xFF\x32\xDA\xB5\xCD\xA1\xC3\x65\x0D\x9F\x3E\x7D\xFB\xDA\xB6\xCB\x36\xEE\x1B\xC7\xC0\x81\xA5\x75\x1B\x29\xD8\x97\xB0\x8E\x1A\x35\x4A\x4B\x29\x0B\xCA\xC0\x3B\xA4\x02\x65\xCB\xE6\x10\x1F\x70\x9D\x3C\x67\x14\xD9\x1C\x5E\xFC\x78\x19\x9E\x3F\x67\xB8\x90\x26\x0F\x9B\x3F\x59\xFD\xD0\xD1\x82\x65\x4A\x87\x0E\x1C\x38\x78\xE5\x62\x8C\x5C\x6D\x64\xE4\xFC\xFB\x2F\xE7\x98\x5D\xAA\xE9\xCD\x37\x79\xAC\xD1\xA6\x39\xE7\x9E\x83\x8E\x98\x61\x86\x01\xC6\x15\xE6\x16\x0C\xEC\x99\x58\xC0\xE0\xE2\x0E\x5C\x9E\x91\x65\x2A\x6A\xE6\x69\xE7\x1C\x6C\xF2\xA8\xA2\x0A\x2C\xAE\xA0\xC1\x85\xF1\x56\x64\x11\x29\x23\xCC\x73\xEA\x83\x0B\x50\xC8\x63\x0B\x36\xE6\x28\x0D\x14\x50\x4C\xD1\x0A\x8B\x28\xBC\x88\xE4\x91\x82\x1C\x31\x67\x3F\x00\xCB\x41\xB2\x1C\x73\x78\x19\xB0\x37\x7C\xE0\xA9\x86\x1B\x91\x36\xC2\x08\x23\x06\xA3\x81\xE6\xC1\x61\x84\x89\x86\xC2\xC0\x80\xC9\x45\x97\x60\xB6\x21\x13\x94\x26\x9A\xA8\x02\x9B\x6C\x00\xE9\x63\x0B\x99\xB6\x40\x71\x82\x16\xE7\xA4\x13\x28\x18\x4B\x60\x2A\x34\x2A\xB6\xD8\xC2\x44\xA9\xC8\xA8\xEE\x8E\x25\xB0\xF0\xC2\x92\x55\xFF\x44\x51\xC4\x91\x5D\xCC\x29\x87\x9C\x24\x93\x3C\x86\x97\x4E\xB2\xD1\x67\x9E\x71\xB4\x01\x29\x23\xC0\x28\x14\x0C\xBA\x94\xAC\xF4\x32\x23\xE2\x32\xCA\x45\x8C\x26\x98\x50\x62\x09\x3E\xF9\x54\x22\x85\x2A\x50\x44\xA0\x4E\x59\x59\x64\xC1\xA9\x12\x54\x50\x01\x85\x0D\x52\xB8\x62\x8B\x9D\xB4\xF0\x83\x0C\x31\xEA\x00\x05\x8E\x25\xA0\x48\x24\x95\x57\x5E\x69\x45\x51\x47\x1F\x2D\x07\x19\x5E\x78\x51\xC5\xA6\x6F\xBC\x11\x69\x53\xE7\xBA\x19\x95\x9B\x4E\x05\xDB\x86\xAF\x50\xB9\x09\xB7\x1B\x52\xCE\x64\x22\x89\x24\x06\xC5\x62\x8B\x14\x3A\xA0\xE2\x0A\x2A\x32\x98\xB5\xDE\xF0\x88\x08\xA1\x04\x14\x50\x58\x81\x0A\x2C\xDA\x34\x71\xA7\x2C\xE8\xB8\x43\x0C\x31\xC6\xB8\x23\x8B\x27\x0A\x5D\x76\xD9\x4E\x76\x39\x86\x1C\x73\xCC\x51\x6B\x5A\x47\x50\x41\x10\xB9\x92\x3A\xDA\xF4\x2F\x2F\x05\xCB\x28\x18\x62\x36\xF6\x32\x5C\x66\xB6\x62\x02\xD5\x75\x77\xDA\xA2\x03\x0B\x68\x90\x37\x04\x7B\x67\xCE\x2C\x04\x18\x66\x50\x62\x0E\x52\x70\xD1\xC5\x8F\x29\x4A\x34\x11\x58\x3A\xC4\xD0\x62\x0C\x3A\x9E\x40\x22\x91\x56\xA6\x0D\x86\x15\x46\x12\xDD\x25\xEA\xA8\xFF\x3B\x61\x25\x98\x64\x92\x21\x59\xD3\xBF\x3C\x0E\x35\x9A\x57\xA2\xD1\x96\xC2\x6D\xCC\x3C\x55\x26\x25\x9A\x58\xD5\x65\x57\xE7\xA5\xB9\xED\xA3\xF8\xD0\x80\x8A\x39\x40\x91\x85\x15\xBB\x43\x79\x02\xE8\x9D\xE6\x78\x4F\x8B\x83\xC5\x18\xC8\x12\x5B\x7A\x79\xA5\x0B\x46\x6A\xD1\xC6\x17\x5F\xA6\xED\x85\x18\xC1\x8A\x29\x06\x64\x6F\xA5\xE1\x7A\xEB\x91\xB8\x25\xF3\x99\x5A\x84\xD1\x98\xE3\x05\xBB\x59\x06\x8B\x94\x51\x35\x9B\xCF\x2B\x34\xB8\x20\x05\x2A\xD8\x76\xBB\x75\xA0\xF8\xC8\x61\x8B\x3B\x44\x89\x65\x95\x55\xEC\x6E\x65\x15\x32\xA6\xA0\x62\x26\x5F\xF9\x1E\xC3\xE0\xE0\x8F\x10\x43\x96\x5C\x2C\x89\x24\x98\x68\x90\x93\xA6\x18\x2D\x1F\x84\x3C\x72\x50\xB7\xE6\x46\x98\x91\x49\xE2\x46\x1B\x54\xCA\x60\x04\x16\xCE\x2D\x27\xB9\x1B\x6D\xE6\x48\x41\x89\x94\xCD\x56\xC2\x74\xD4\x4F\x58\x9D\x5E\xD7\x5B\x17\x62\x0B\x50\x44\x51\x65\x15\x55\xEE\x57\x25\x15\x51\x42\x29\x43\x09\x1A\x4E\x50\x9D\x8D\xE8\xE0\x07\x39\x18\x4C\x0C\x59\x38\x42\x19\x44\x21\x8A\x66\x68\x49\x1A\x10\xEA\x05\x30\x80\xF1\x20\x62\x44\x0F\x54\x7C\x01\x87\x34\x2C\x01\x8A\xFF\x67\x68\xE3\x19\xCE\x90\x45\x19\x8E\xC0\x81\x32\x94\x8B\x23\x24\xDB\x94\x36\xFC\xA0\x04\x13\xA4\xE0\x7C\x53\x50\xC2\x14\x7A\x55\x85\x0B\x10\x00\x05\xED\x7B\x9F\xDB\x5C\xC0\x86\x49\x44\xC2\x87\x91\x58\x44\x10\x13\x91\x88\x30\x80\x01\x0C\x4B\xE8\x00\x58\x4E\xD0\x04\x36\xB0\x81\x60\x63\x80\x82\xDF\xB4\x00\x05\x30\x94\x42\x82\x11\x84\xE0\x04\x9F\x07\x0D\xC8\x5D\x70\x41\xA0\x38\x02\x35\xA8\x51\x06\x30\x78\xC1\x0B\x48\x38\x42\x29\xBA\x45\xA1\x6E\x7C\x83\x14\x4A\x38\xC1\xAE\xCE\x57\x05\xDF\xF5\x29\x03\x08\xD0\x00\x0D\x58\x97\xC3\x99\xC5\x80\x06\x52\x18\x03\x18\xCA\x60\x06\x42\xDA\xC1\x0E\x6F\x30\xA4\x1D\xE0\xF0\x2E\x0E\x9C\xE0\x04\xA9\xD2\x02\xC1\xC4\xF0\x84\x27\x64\xC1\x6F\x5E\xB8\x44\x2D\xB0\x28\xC1\xE7\x0D\x03\x1A\x9F\xF2\x22\x5F\x70\x01\x05\x31\x82\x21\x0C\x66\x7C\x02\x14\x98\xB1\x46\xE7\x80\xE3\x1B\xA8\x58\xC2\x09\x4C\x20\x47\x99\xD0\xB1\x0A\x7C\xA2\x42\x11\x8A\xA0\x01\xD5\xC9\x8C\x8F\x6D\x73\x41\x0B\x68\xB0\x84\x28\x14\xAD\x0E\x89\x4C\xA4\x14\xE2\xD8\x48\x47\x1E\xE1\x09\x70\x28\x98\x40\x96\x60\xC9\xA2\x45\xFF\x42\x16\xBA\xF8\x05\x27\x3D\x09\x0D\x68\x74\xCA\x4B\x27\xCC\x45\x19\xEE\x60\x86\x47\x3C\xC2\x0C\x60\x40\x02\x28\xBC\x31\xAE\x36\xA2\xE2\x09\x8E\x9C\xA5\x0B\x1F\x69\xCB\x3E\xD1\x40\x10\x70\xEB\x97\x2F\x7F\xE9\xB6\x22\xB8\x20\x75\x4C\x68\x42\x14\xA4\x20\x06\x39\xD4\x01\x0E\x4A\xE0\xC0\x06\x76\x05\xC7\x47\x46\x61\x0E\x93\x54\xD7\xD9\xB4\x20\x85\x2F\x8C\x61\x12\xA2\x98\x45\x2E\x9C\xC1\xCD\x94\x04\x83\x39\xAC\xCC\xC8\xD8\x1E\x01\x09\x48\x94\x33\x0C\x5C\xC0\x85\x73\x24\xD7\x11\x6D\x80\x22\x96\x8D\x34\x81\x09\x4E\xC0\x84\x13\xFC\xEC\x67\x57\xA8\x02\x0D\x8C\x20\x03\x0D\xE4\x73\x9F\xEF\x73\x80\x08\x72\x85\x82\x14\x14\x55\x26\xEF\x4A\xE2\x06\xCC\x97\x02\x47\x26\x21\x0A\x6C\xD0\x42\x14\x96\xA0\x2E\xAE\x50\x12\x0A\x50\xF0\x42\x19\x26\xB1\xD5\x41\xBA\x22\x94\x1A\xE9\x86\x2C\xC2\x40\x52\x21\x46\x42\x1B\xC1\x08\x53\x2D\x5C\x61\x37\x57\xE4\x42\x85\x4B\x60\x6A\x23\x37\x20\xD3\xA2\x96\x48\x86\x57\xB8\x82\x65\xF8\x21\xD4\x1B\xE8\xF3\xA7\x6D\x7B\xC0\x8C\xF6\xB5\xAF\xA2\xA6\x80\x06\x56\x48\x81\x42\x97\xD8\x84\xA9\xAA\xCB\xA9\xFF\x5A\x60\x03\x16\xA6\xAA\x04\xC7\x36\x76\xAA\x4F\xA8\x83\x2C\x26\x14\x2A\x70\x38\x63\x88\x90\x58\xC4\x10\x41\x61\x9D\x3E\x64\xC1\x12\x9B\xA8\xDF\x2A\x42\x18\x4B\x47\xC2\x93\xAE\xAE\xAA\x42\xBC\xF0\x6A\x19\x02\x08\xD5\x06\xB1\xFA\xAB\xDB\x26\x70\x01\x10\x0C\xD6\xB7\x78\xA0\x06\x15\x00\xB8\x81\x29\xEC\x24\x0A\x67\x9A\xEC\x99\xAA\xD0\x04\x99\x34\xB2\x7C\x4F\x10\xC3\x1D\x64\xD1\x0C\xB0\x65\x6D\x41\x25\x11\x85\x19\x4A\x6A\x86\x50\x80\x22\x0B\x58\xC8\x82\x1D\x62\x51\x3B\xDB\xB5\x42\x15\x93\x50\x4D\x6B\x65\xEA\x48\x26\xAC\x21\xB6\xAF\xA2\x02\x6D\x85\x3A\x03\xDC\xE6\x96\x66\xBB\x05\x81\x08\x7C\xCB\x2F\x43\x00\x22\x05\x2D\x2C\x2A\xAA\xAA\x10\xD9\xE3\x22\x97\x2B\x4B\x38\xAA\x4C\xA0\x10\x09\x5B\x74\x89\x63\xD6\xC5\xA0\x30\x18\x31\x48\x51\x78\x50\x17\x91\x08\x43\x22\xEC\x50\x86\x41\x5A\x22\x15\xAB\xA0\x45\x29\xEE\x20\x85\xE3\x02\x14\x55\x68\xC2\x29\x5E\x69\xE0\x13\x03\x08\xB5\x05\x2C\xB0\x6F\xDB\x26\x10\x1A\xFD\xFA\x96\x0A\xD4\xC0\x03\x0D\x68\x50\x54\xFA\x94\x0F\xA0\x67\x2A\x30\x72\x65\xB2\x04\x31\xD8\x21\x15\xBF\x00\xFF\x15\x72\xC6\xB5\x11\x6E\x04\x43\x15\xB5\x00\x1B\x74\x6A\x11\x89\x31\x74\x25\x09\x47\xF0\x42\x22\x2A\xB1\x8A\x58\xD4\x62\x16\xB2\x28\x05\x98\x4B\x01\x8A\x3B\x90\x01\x4E\x57\xB0\xC2\x0C\x60\x5C\x2B\x15\x88\x00\x3C\x31\xEE\x63\x06\xF2\xDB\x94\xC1\xA6\x01\x1B\x78\xB0\x81\x0D\xD2\xD0\xDF\x0E\x60\x00\x05\x34\xE8\x43\x1E\x64\x12\x13\x04\xC7\x44\x09\x58\x98\xDD\xE6\xA4\x31\x0D\x6E\x81\xF4\x63\xDF\x7A\xC6\x2C\xAA\x8C\xBE\x32\x84\xC1\xC3\xAB\x68\x45\xA6\x5B\xE1\x0A\x4E\xD7\xA2\x16\xB8\x40\x45\x9B\xAC\xE0\x13\x7E\x84\x00\x05\x2A\xF0\x2B\x9C\x67\x45\x84\x0C\x88\x40\x03\x4D\x99\xC1\x0C\x50\x70\x03\x6C\x18\x62\x06\xAE\xC6\x09\x20\x34\x80\x81\x0E\x04\xC2\xBF\x8E\x64\x66\x6B\x53\x15\x85\x31\x44\x22\x16\xBF\x58\x1E\x71\xB0\xA7\xB5\xCB\x71\x24\x19\xDA\x60\x86\x88\xB5\x60\xB6\x67\x4A\x77\xBC\x98\x6E\x05\x2D\x68\xA1\x69\x6E\x7B\x39\x14\x59\x70\x9F\xA9\x51\xAD\x6A\x9A\x65\xA0\x05\xAD\x16\x41\xAC\xF7\xB5\x07\x43\x88\xE0\x02\x39\x70\x4C\x4E\xF0\x00\x08\x6B\xE4\x41\xA1\xF7\x56\xA8\x4C\xD7\x15\x85\xAB\x56\xF4\x0E\xA5\xE0\x99\x33\xFF\x9E\x41\x26\x82\x7B\xC3\x1B\xDB\x80\x36\x2E\x64\x01\x0A\x32\x44\x21\x26\x27\x48\xC2\x13\xC6\x40\xBB\x58\xD0\xC2\x76\xD8\xE6\x76\xC6\x33\x5D\x0B\x52\xE4\x80\x1F\xB5\x42\x81\x08\x60\x4C\x6E\x7B\x65\xE0\xD6\x22\x00\x41\x9E\x51\x30\xE7\x77\x0B\x45\x44\x80\x50\x42\xBE\xF1\xAD\x04\x2D\xDC\x21\x14\xB2\x00\x33\x1D\xA6\xE0\xC2\xE2\xDE\x88\x0C\x3F\x07\xFA\x01\x25\x7B\xD4\xD6\x3A\x72\x09\x63\x80\x04\x26\x38\xC1\x89\x4D\x34\xBD\x7E\x1A\x87\xFA\x2C\xFA\x80\x2F\xFD\xA6\x9A\xE4\x75\x0A\x81\x0D\x9A\x92\x72\x94\x8B\x20\x04\x1F\x10\xC1\x50\xA8\xC1\x06\x9A\xE6\x7B\x96\x4B\xB4\x79\x2C\x7A\xD1\x0B\x68\x3C\x23\x17\xA0\xE0\x00\x51\x57\x70\x83\x1B\xAC\x60\x05\x6A\x18\xC4\x20\xF8\x30\x08\x43\x08\x01\x03\x18\x28\x6A\xD1\x99\x20\x85\x3A\x64\x78\x11\x96\xB0\x04\x26\x52\x8B\x71\xA8\x6B\x1A\x14\x19\xF0\x4C\x0B\x1E\x70\x75\x7B\x65\xBD\x29\x17\x08\x41\xE6\x43\x70\x81\x0B\xDC\x20\x28\xED\xC8\xC9\x0A\x5C\x1B\x53\x13\x28\x61\x76\x9F\x88\xA0\x04\x9B\x17\x0C\xB8\x9F\xC0\xEE\x3F\x00\x02\x0F\x08\xE1\x8E\x77\xA8\x83\xF6\x6B\xC0\x80\x05\x94\xDA\xFF\x5A\x17\x4A\xC1\x94\x8B\xE0\xC4\x87\x2F\xDE\x78\x8D\xB3\x22\x14\x29\x00\xFB\x03\x62\x40\xF9\x7A\x65\xFD\xEB\x21\x20\x41\xE6\x1B\x70\x81\x3C\xEE\x61\x0F\x80\x00\x84\x21\x0C\xB1\x86\xFF\x92\x3E\xA6\x27\x60\x83\x28\x38\x61\x0B\x2D\x01\x63\x1B\xE1\x88\x86\x33\xEE\xE0\x84\x2F\x48\x81\x09\x29\x50\xC1\x20\xDA\xA1\x0E\xFA\x1B\xE2\x04\xB1\xE4\x35\x53\x4F\x90\x86\x3D\x10\xDB\x0C\x8B\x50\xBA\xE0\x13\x3E\xE2\xE3\x36\xE3\xA3\x82\x10\x28\x02\x1F\x20\x02\xE6\x9B\x95\x06\xF0\xBA\x12\x88\xBE\x07\x78\x80\x16\xDB\x17\xBB\x5B\x01\x26\x58\x9D\x15\xE8\x3E\xEF\x53\x82\x49\xF0\x84\x54\x68\x1C\x62\x70\x10\x62\xE0\x88\x67\xD0\x05\x33\x08\x83\x3A\xA8\x03\x39\x88\x82\x2A\x70\x83\x41\x38\x04\x43\xD0\x03\x36\x30\xA8\x13\x00\x3C\x75\xC9\x01\x3D\xB8\x82\x31\x30\x83\x44\x38\x3C\xC4\x53\x84\x4D\x28\xAF\xC6\xB3\x1B\xBB\xB9\x83\x1B\xF8\x01\x44\xF8\x89\x05\x64\xC0\x39\x89\x01\x04\x28\x01\x18\xC8\xBC\x07\x40\x80\x16\xCB\x95\x14\x18\xAC\xC2\x2A\x2A\xEF\x6B\x21\x28\xD0\x04\x4F\x88\x05\x60\x28\x06\x95\x10\xC1\x68\xD8\x92\x50\xB0\x04\x22\xA2\x84\xFF\x4C\x90\x04\x6A\xB8\x06\xED\x33\x04\x6C\xF8\x83\x37\xF8\x82\x84\x52\x02\x2A\xB8\x3E\x2A\xA0\xA2\x30\x58\x04\x51\x90\x85\x58\x18\x40\xA8\xAB\x05\x5A\x98\x85\x54\xD8\xA0\x29\xB0\x81\x1E\x30\x04\x7E\x28\x84\x26\x6C\x11\x23\x98\x00\x12\x90\xC2\x10\x68\x80\x07\x68\x00\x03\x08\x81\xA1\xC2\xC2\xFD\xC2\x42\x2E\x54\x82\x3A\xF0\x04\x4E\xA0\x05\x61\xF8\x96\x68\x10\x41\x11\xD4\x05\xDA\x49\x43\x4A\x50\x86\x75\xA0\x86\x40\xF8\x83\x3B\xC0\x06\x6A\x90\x84\x4C\x80\x03\x3F\x5B\x83\x3C\xB8\x81\x1C\xB8\x82\x2F\xE0\xC3\x4B\x50\xBA\xA6\x13\x42\xC6\xCB\x36\x5A\x88\x85\x4B\x18\x83\x2C\x50\x02\x18\xE8\x81\x1E\xD0\x03\x44\x30\x02\x47\x1C\x8F\x41\x78\x01\x16\x80\x81\x12\xF8\xBA\x06\xB8\x44\x03\x68\xB5\xFD\xF2\x46\x5D\xD9\x97\x98\x4A\x82\x49\x60\xBA\x51\x2C\x45\x95\x28\x86\x6D\x60\x05\x67\xA8\x05\x4C\x78\x84\x3F\x90\xC3\x4C\xB8\x04\x52\xB8\x06\x65\xF8\x42\x4A\x58\x02\x0C\xC8\x19\x2A\xD0\x83\x35\xF0\x45\x30\x18\x03\x33\x32\xA3\x41\x5A\x84\x48\x40\xBC\x05\x12\x85\x48\x00\x03\x27\x30\x01\x18\x78\x81\x17\xE8\x01\x66\xE4\x83\x68\x94\xC6\xFF\xCD\x20\x82\xA5\x90\xC2\x06\x40\x00\x6D\x34\x00\x6E\xA4\xB3\x6F\x1C\xAC\x98\x0A\x47\x13\x78\x82\x4B\x58\x3A\x5A\xE8\x12\x50\x19\x0C\x69\xD8\x06\x58\x18\x38\x60\xA0\x05\x4A\x20\x04\x43\x50\x06\x50\x50\x06\x6C\x20\x05\x4F\xF0\x04\x77\xEC\x33\xC8\x62\x03\x81\xF2\x02\x29\x40\x30\xFD\x7B\xA4\xAA\xD2\x82\xA3\xE4\x89\x14\xF8\x01\x43\x40\x04\x44\x30\x84\x1E\x78\x01\x12\x20\x81\x8A\xD4\x0C\x3E\xA0\x80\x17\xF8\x01\x15\x18\x81\x4A\xA4\xC2\x2A\xFC\x0C\x90\x0C\x49\x13\xD8\x97\xB9\x12\x83\x2F\xF4\x84\x5B\x70\x30\x95\x02\x19\x6C\x42\x8E\x68\xF8\x05\x51\xF8\x03\x31\x52\x07\x6A\x30\x4B\x4E\xC0\x04\x31\xE8\x00\x26\xB8\x03\x79\xA4\x84\xBE\xAC\x83\x28\x58\x01\x13\x00\x01\x0C\x00\x81\xDE\x5A\x83\x6B\x18\x84\x1B\x00\x02\x20\x80\x81\x43\xA0\x87\x77\x80\x0B\x3D\x20\x81\x17\x90\x13\xAA\xBC\x0C\x22\x90\xC4\x1F\xC0\xC6\x0F\xE0\xCA\x2A\x0C\x01\x1C\x70\x0A\xB0\x1C\x49\x14\x30\x01\x0C\xD8\x80\x3A\x30\x4B\xB4\x1C\x17\x70\xD0\x06\x5D\x00\xAB\x68\xB0\x85\x50\x20\x05\x65\x28\x85\x4F\x58\xBA\xE0\xA3\x04\x25\x58\x81\x28\xA0\x04\x4C\xC0\x04\xFF\x51\xD0\x84\x4A\xB0\x83\x28\x48\xAC\xBF\xBB\x00\x1B\xC0\x06\x7A\x50\x87\x20\x08\x82\x1F\xE8\x81\x76\xC8\x07\x7A\x78\x0B\x43\x98\xCC\xFA\xB2\xCC\xA2\x18\x04\x0A\x28\x01\x20\xF8\x01\x12\xB0\x44\x6D\x94\x40\x4C\xC4\x01\x1B\x78\xB5\x1A\x03\xC9\x59\x12\xCB\x98\x3A\xCD\xD4\x4C\x4B\x36\xD2\x86\x59\xB8\x2E\xB7\x34\xC6\x54\xB8\x4D\x4E\x10\x05\x38\xB0\xBB\x3A\xC0\x84\x4B\xE0\xCF\x4A\xA8\x04\x49\xD0\x82\xE2\xBC\x00\x3C\x78\x87\x7B\xA0\x07\x3E\x68\xCE\x1E\x50\x07\x7A\x70\x07\xFA\x1B\x04\x12\x28\x81\x1B\x78\xB3\xEB\x1C\x0A\x22\x88\x00\x18\xE0\x4E\x12\x88\x00\x09\xE4\x50\x04\x40\x00\x1B\xC0\x81\x19\x28\x4F\xD1\x14\x49\xD2\x9C\x25\xD4\x3C\xC9\xF6\xA4\x10\x6F\x50\x85\x70\xF9\x9C\x6D\x10\x06\x5B\xB8\x38\x2E\x03\x85\x14\x10\x81\x25\xE8\xCD\xFE\xAC\x84\x4B\xA0\x84\x31\x38\x02\x0C\xB8\x00\x11\xD0\x83\x43\x50\x07\x04\x0D\x82\x1E\x90\xBF\x77\x70\x87\x43\xE8\x01\x12\xA0\x82\x53\xB0\x02\x0A\x1D\x8A\x0A\x08\x81\x1F\xD0\xCC\x10\x78\x80\x0D\xE5\xD0\x8E\x14\x01\x1C\x00\x4D\x0D\x10\xCD\xD1\x24\x4D\xD3\x94\x03\x4D\x58\xBA\x58\x50\xD1\xFF\x56\xF2\x06\x0E\xFA\xA6\x90\x4A\x89\x94\x70\x06\x2D\xF8\xBB\xB2\xDC\x4F\xFE\xB4\xD3\x3A\x50\x82\xC2\x1C\x01\x15\x68\x4E\xE6\xEC\x81\x12\xD0\x03\x43\x18\x84\x1E\x68\x01\x14\xF0\x03\xA9\xD3\x01\x29\xFD\x89\x41\x98\x80\x12\xB0\xD2\x12\xE0\x4A\x0E\xA5\x42\x6E\xB4\x81\x1C\x20\x4F\xF3\x04\x4B\xB1\xDC\x97\xBF\x33\x81\x2F\xD0\x04\xA5\x8B\x85\x67\x58\xCD\x6F\xA0\x03\x5C\x70\x34\x2F\x01\x85\xBF\x4B\x01\x4A\xA8\x84\x47\xE8\x4F\xDF\xD4\x84\x3B\x68\x02\x1B\x0D\x81\x11\x70\xD4\x23\x85\x81\x16\x90\x4A\x11\x98\x02\xBA\x71\x05\x59\x88\x52\x29\xBD\x48\x18\xB0\x52\x12\x00\x4F\x49\x45\x80\x01\x68\xB1\x1C\xC8\x81\x93\xF3\xAD\xA1\x02\x4B\x4E\x95\x82\x4C\x00\x55\x67\xD8\x96\xCE\xE1\x86\x6F\xC0\x91\x70\x81\x30\x2F\x41\x85\x90\x03\x01\x36\xA0\x84\x30\xA0\x04\x60\xF4\x4D\x4E\xD0\x04\x4A\x90\x83\x25\x08\x39\xFD\x62\x02\x0B\x74\x15\x05\xB2\x9B\x59\xA8\x05\x3F\xC0\x03\x0A\x25\x02\x07\x20\xD6\xEE\x94\x54\x49\x1D\x00\x00\x30\x80\x1A\x60\xD6\xD0\x1C\x2C\x68\xD5\xD4\xFD\xFA\x3B\x10\xC0\xD1\x4A\x58\xBA\x5F\xF0\x92\x8D\xF9\x86\x3E\x98\x02\xFF\x5C\xF0\x86\xAC\x11\xC1\x35\x02\x07\x5C\xA0\x82\x3C\x5B\x01\x38\xA8\x03\x49\xF0\xCD\x73\xE5\x04\x4F\x10\x85\x4B\xA8\x03\x24\xEA\x80\x31\x78\x84\x50\x60\x59\x59\xE0\x34\xBB\xA1\x85\x4F\xBB\x82\xEB\xF4\x81\x0B\x2D\xD6\x48\xE5\xD0\x06\xF8\xD7\x01\x10\x01\x66\xB5\x81\xFC\xDA\xAF\xA1\x02\x81\x83\x0D\xC9\xC2\x04\x81\x14\xB0\x03\x86\x1D\xBF\xD5\xF4\x86\x3E\xA0\x01\x3F\xD0\x06\x14\x0A\x86\x57\xC0\xD8\x5C\xA8\x82\x3C\x03\x82\x1B\x88\x82\x49\xF8\x54\x4C\xD0\x84\x2F\x5C\x3A\x4F\x48\x57\xC0\x01\x03\x4B\xA0\x57\xB5\xE2\xB4\xB4\x75\x05\x5B\xF8\x83\x09\x75\xC4\x9A\xED\x01\x2B\xDD\xCA\x7E\x95\xC0\x02\x00\x00\x00\x20\x80\x4A\x6D\x56\x0C\xC0\xD4\x53\x5B\x39\x0C\x20\xDA\x91\x24\x3D\x38\x98\x04\xA5\x43\x49\xCE\xF2\x06\x3A\xD0\x33\x54\xE0\x88\xC6\xDD\x86\x56\x58\x1E\xB0\xEA\x06\x66\x60\x03\xBA\x53\xCC\x15\xA0\x03\x33\xF5\x5A\x9D\xE4\x5C\xB1\x85\x04\x2F\xB0\x03\x4B\xE8\x32\xB4\x4D\x5B\x5B\x58\x5B\x5C\x48\x83\x8A\xF4\x01\x12\xB0\xD2\x1E\xD0\x52\xBA\xB5\xDB\xBB\x6D\x01\x1C\xC8\x01\xD0\xE4\x5B\x6F\x14\x01\xC2\xFC\xC6\xD2\x34\xCE\xFF\x28\xA8\x83\x4B\xF0\x84\x55\x10\xD5\x87\x6D\xDA\x15\x00\x02\x36\x58\x25\x6E\xD9\x08\x5B\xF0\x85\x6B\xA5\xDC\x1F\xB0\x81\x1B\xC8\xB3\x2A\x00\x85\x9D\xC4\x04\xCE\xFD\x32\xB1\xBD\x84\x30\xB0\x03\x48\x58\x05\x4F\xF3\xB4\xB4\xFD\x85\x5C\xB0\x05\x5D\xE8\x03\x69\x5C\xDD\xD6\x7D\x00\x07\x70\x80\x7E\x0D\x01\x04\xB8\x5B\x00\x40\x00\xDA\x6D\xD6\x20\xED\xDB\xBF\x0D\x5C\xD2\x2C\xCC\xDC\xB3\x80\x13\xF0\x82\x47\xE0\x84\x58\xB0\xD6\x87\x8D\x58\x26\x40\x03\x35\xA0\x83\x55\xF2\x96\x68\xD8\x86\x06\x5B\x10\x5D\x60\x83\xC5\x94\xE0\xE3\x2D\x85\xB0\xE5\x5C\x59\xD0\x49\x4D\xE8\x41\xEF\xF5\x34\x5B\xF0\x60\x0F\xFE\x85\x67\xF0\x85\x5F\x40\x05\x8F\x63\x40\x1F\xA0\x80\xB8\x2D\x81\x07\x60\x00\xF6\x95\xD4\xCC\x33\x80\xBB\x1D\x00\x19\xA0\xDF\xDC\x25\xD8\x7D\x19\xCC\xDE\xF2\xC6\xC1\xBC\x00\xD7\x20\x00\x0C\xF8\x02\x30\xC0\x84\x4F\x70\xD8\x6F\xFA\x06\x3F\x58\x83\x41\xD8\x83\x35\xA0\x83\x5C\xF0\x96\x74\x0C\x86\x60\xE0\x88\x6D\x10\x0C\x5C\xB8\x82\xC5\x54\x83\x2C\x56\x03\x34\x98\x9D\x91\xCD\xE0\xAF\xFD\xD4\xCF\x4A\x85\x0F\x26\x63\x5B\xD8\x06\xFF\x60\xF8\x05\x66\xB8\x57\xE6\xB3\xD0\x66\xF4\x4E\x6D\xC4\x59\xCD\x83\x01\x03\x18\x00\x16\x60\x56\x4B\xDD\xB5\x1D\x4E\xD8\x6F\xE4\x61\x1F\xB6\x80\x25\x00\x03\x48\xE0\x84\x5B\x20\x0E\xE5\x15\x95\x57\xDA\x83\x75\x48\x87\x41\x60\x62\x66\x88\x06\xE8\x68\xE0\x70\xA1\xE2\x68\x20\x05\x2A\x00\x82\x35\x68\x83\x4C\x6E\x03\x35\xC0\x82\x50\xB8\xDE\x2F\xEE\xDA\x72\x12\x64\xE6\x55\x9C\x52\xF6\x85\x83\xF3\x85\x60\x38\x5F\xCA\x23\x02\x08\x68\xC6\x17\x58\xDF\x63\x95\x40\xCD\xB3\x01\xC6\xCC\xBA\x3B\x9E\x81\xDB\xDD\x2F\xA3\xE5\x63\xD4\x21\x80\x5F\x7E\x0D\x0E\xE0\x41\x4C\x38\xDC\x8D\x30\x64\x8F\xA8\x86\x3D\x88\x87\x7A\xB8\x86\x36\x40\x03\x36\x40\x05\x6D\xE0\x96\x60\xF0\x85\xE6\xC9\x9E\x39\xB8\x01\x34\xC8\xE4\x3D\x38\x04\xC4\x04\x02\x3A\x10\x85\x4F\x16\xDB\xAE\x2D\xA9\xC4\xD3\x05\x53\x2E\xE5\x6D\xF0\x06\x61\x10\x86\x53\x70\x5B\x38\xBB\xC8\x17\x80\x01\xEF\x64\x5F\x59\x86\xBE\x4C\x94\xE0\x1B\x98\xB5\x1C\xB8\x81\xC1\xEC\xDB\xFD\xED\x2D\x5C\xD9\x97\xDC\xF5\xE1\x5F\xB6\x80\x0B\x30\x4D\xDF\xBB\x04\xE1\xA5\x90\xBE\xA8\x06\x37\x78\x87\xFF\x7C\x88\x07\x42\x00\x02\x2A\xA0\x5E\x67\x10\x1F\x58\xA8\x20\x6E\xD0\xD8\x6C\xCE\x64\x42\x58\xE6\x75\x08\x02\x34\xA0\x56\x30\xFE\x5A\xDF\x0C\x92\x4B\xA8\x84\x5A\xA0\xE6\x28\x76\x69\x61\x38\x38\x61\xC0\x85\x35\x56\x35\x23\xD0\xD7\x79\x8E\xE5\x63\x8D\x00\xA9\xCC\x97\x09\x5E\x4C\x5C\x69\xB3\x53\x03\xEA\x5C\x19\xDA\x83\x45\x39\xD4\xF1\x63\x84\xE6\x54\xC0\x93\x02\x4A\xE0\x84\xE6\xBD\xAE\x8F\xF8\x06\x36\xB8\x86\x7C\xC8\x87\x6B\x40\x03\x24\x04\x02\x38\x28\x85\x6A\x40\x85\x65\xA8\x86\x65\x98\x83\xB9\xD3\xE6\x36\x20\x04\x7A\xC8\x87\x7A\x20\x84\x15\xB8\x03\xA5\x03\xE3\x90\xBD\x04\x57\xAD\x84\x58\xF0\x28\x76\xB6\x6B\x98\x3E\x38\x35\x26\x39\x09\x80\x48\x12\x60\x5F\x07\x88\xD4\x08\xD8\xE9\x5A\x85\x3D\x09\x46\x03\x34\x58\xCC\x15\x00\x49\x1D\x6E\xD7\x0C\x00\xE6\xD7\xB0\x00\x0D\x00\x81\x0D\xE0\x54\x11\xB0\x81\x13\xA8\x03\x51\x74\x51\xE7\x90\xEA\x3E\x18\x04\x7A\x50\x6B\x34\xD0\xA3\x2A\x60\x02\x1A\x00\x04\x6A\x30\x04\x6A\x70\x83\xAC\x35\x5E\x4C\x06\x69\xAB\xBE\x06\x20\xC0\x02\xF1\x3B\x69\xB8\x76\x55\xA5\xFB\x05\x76\x3E\x45\xFF\x11\x24\x38\xBD\x56\x35\x09\xE0\x6B\x63\xFD\xEB\xF6\x95\x40\xC1\x8E\x80\xAC\x33\xEC\xC3\x3E\xE0\x09\xB6\xDC\x15\x10\xE8\x95\xE3\xBC\xC7\xB6\x00\x0C\xD0\x80\x5D\xFB\x3B\x4E\x45\x01\x18\x00\x01\x2D\x10\x05\x86\x36\x64\x29\x09\x07\x6F\x38\x85\x35\x98\x3F\x35\x60\x82\x52\xCD\x05\x5C\xF0\x83\x3E\x50\x86\x50\x4B\x03\x3A\xD0\x11\x3A\x48\x83\x36\x70\x83\xD7\x56\x07\x20\xA0\x01\xAE\x0D\xD9\xFD\x86\x84\x49\x00\xC6\xCD\xD9\xED\x00\xD7\x05\x9A\xB6\xAF\x18\x38\x80\x87\x64\xE1\xBF\xE6\x50\xC1\x8E\xBE\xED\x04\x02\xE5\x56\xEE\x2C\x3E\xEC\xC5\xAC\x3B\xA2\x06\xD2\x82\x3E\xE8\x0D\x48\xA2\xEB\xBE\xEE\xA1\xCD\xEE\x0F\x50\x02\x50\xE0\x84\x22\x66\x32\x8E\x09\x87\x65\xA8\x82\x41\xD0\x83\x67\x5E\xA5\xE1\x60\x86\x53\x58\x06\x54\x10\xA3\x5F\x20\x06\x75\x46\xE2\x4C\x1E\x84\x78\xB8\x6F\x15\x80\x83\xFD\xDE\xEF\x4B\xB0\x83\xDE\xDC\x04\x64\x0B\xF0\x53\xC4\x85\x77\xFE\x29\x22\x38\x80\x2C\x65\xE1\x16\x76\xE1\x2C\x95\xCA\x07\x18\x01\x9F\x86\x70\x08\x4F\x6C\x0B\x8F\xEE\xD7\xF0\x33\x5D\xA1\x6C\x0E\x4F\x58\xB1\x2C\x81\x0F\xD8\x80\x3B\xE0\x84\xFF\x5A\xD8\x6C\xCE\xAE\x06\x36\x90\x70\x3F\x88\x86\x70\x10\x87\x70\x78\x86\x65\x10\x23\x6B\x70\x64\x62\x10\x07\x71\xA0\x5C\x35\x58\x03\x35\x30\x84\x43\xF8\x01\x18\x68\x02\xFF\x36\x69\x30\x4E\xE9\x32\xB7\x1E\x94\x38\x09\x62\x60\x67\x52\x40\xF2\x7D\x3A\x00\xAE\x64\x80\x48\x7F\x72\x28\x8F\xBE\xC2\x4E\xEE\x2A\x97\x60\xE7\xFE\xDB\x1E\x66\x0D\x13\x50\x6C\x2F\xF7\x72\x0F\x17\x01\x19\x11\x83\xE0\x4D\x53\x96\x62\x83\xC3\xBE\x01\x50\x08\x97\x37\xC7\x12\x67\x00\x35\xEB\xD9\x86\x3B\x77\x06\x36\x08\x02\x21\x60\xCE\xE6\x84\x01\x14\xF0\xDD\x4C\x18\x74\x4D\xC8\x84\x91\x32\x53\x5B\xB0\x1E\x53\x54\x74\x60\x08\x06\x3F\x80\x33\x09\x58\xF2\xF5\x75\x72\xE2\xCE\x52\xE9\x73\x70\x9F\x7E\x70\x4C\x07\x02\x4D\xE7\xE1\x19\x49\x01\xC5\x16\x4C\xA3\x35\xDA\x84\x1D\x5A\xD2\x06\x81\x0B\x48\x82\x4B\x18\xF2\x6F\xF2\x06\x3F\x30\xDE\x15\x60\x73\x2B\x21\x8C\xA9\x35\xC5\xE3\xE8\x86\x5A\xB7\xD2\x7A\x8F\x48\xC2\xF2\x5D\x4A\xE8\x5A\xDF\xBC\x04\x48\x00\xC6\x31\x3E\x74\x07\x01\x93\x3C\x88\xB1\x0A\x08\x80\xE1\x56\x70\x0E\xD5\xBC\x2A\xA5\xF6\xC5\xB4\xF6\xFF\x6B\x6F\x33\x5E\x2E\x5A\x6F\xA7\xF8\x98\x4A\x81\x31\xEB\x80\x0B\x38\x4D\x4C\xB0\x85\x50\xE9\x06\x50\xB0\xC0\x39\x70\x86\x73\xCC\x05\x28\xEB\x94\x6D\xC0\x05\x26\xE0\x81\x3C\x4B\x44\x18\x80\x01\x5C\x69\x8A\x14\x58\x02\x39\xF0\xEF\x1F\x3F\x57\x5A\xC8\xED\x2C\x01\x06\x5D\xA0\x81\xE5\xCB\x2D\x01\x58\x00\x84\x87\xF6\x07\x58\x78\x62\xCD\xDA\x1B\x00\x6A\x87\xB7\xF2\xC4\x46\x01\x70\xF7\x2D\x8A\x87\x7A\x99\x22\x03\x6D\xD0\x86\x3B\x20\xCC\x27\xC0\x84\x55\x38\x75\x6E\x90\x05\x26\x00\x02\x1B\x50\x02\x5C\x38\x47\x57\x50\x85\x47\x16\x0C\x15\x52\x01\xE8\xB5\x01\x97\x77\x79\x98\x37\x4F\x57\x81\xA6\xBE\x34\x57\xDF\x4C\x85\x5A\xF8\x85\x5F\x70\x86\x52\xB8\x81\x17\xA8\x80\xBF\x72\x80\x83\x17\xFA\x05\x8F\xBE\x0F\x68\x81\xB6\x87\x79\xA1\xAE\x76\xE5\xA6\xF0\xBF\x25\x4C\xC6\x8E\xFA\x98\x2A\x6A\x13\x98\xD8\x90\x21\x03\x0C\xE0\x00\x4A\x48\x05\x60\x08\x15\x5D\x68\x02\x95\x23\x83\x60\xE8\x14\xB7\x4C\x85\x4A\x10\x55\x96\xC4\x85\x29\x80\x01\x96\x77\xF9\x28\xBC\x95\xCF\x98\x01\xF3\x20\x2A\x13\x91\x83\x3B\x90\x7B\x4C\x90\x85\x59\xC0\x85\xFF\x39\x00\x82\x20\x78\x01\x26\xE4\x23\x83\x0F\xFA\xC0\xCF\xD2\xC1\x26\x7A\x07\x8C\x5E\x3A\xC3\x15\x20\xD8\x62\xC5\xE7\x76\x20\x25\x4C\x4D\xF5\x76\xD2\x03\x5C\xD2\x7B\x24\x54\x58\xA7\x8C\xA8\x06\x32\x38\x4D\x4F\xB0\x85\xAF\x52\x21\x14\xC8\x33\x1A\x00\x85\x37\xFD\x85\x58\x40\xBC\x59\x18\x38\x67\xE8\x83\x28\x64\xFB\x6B\xC4\x13\xA6\x48\xB7\x16\x90\x7F\x65\x8D\x3E\xE8\x23\x01\x11\x68\xA1\xE2\x9A\x03\x3A\xA0\x03\x2C\x10\x01\x18\x00\x88\x20\x3F\x5E\x10\xE1\x67\xF0\x20\xC2\x84\x0A\x17\x32\x44\x28\x40\x00\x03\x07\x12\x27\x3A\x78\xF0\x20\x02\x89\x08\x05\x00\x0C\x40\xD0\xC2\x86\x0D\x11\x22\x51\xA8\x00\x82\xE6\x24\x10\x20\x2B\x50\x98\xC0\x60\xC1\x02\x06\x10\x26\x4C\x80\xC0\x10\x73\x83\x09\x14\x28\x52\x4C\x11\x43\xE7\xCE\x1D\x54\xDF\xB8\x11\x25\x1A\x6C\x8C\x14\x4D\x9D\x9E\x15\x6D\xBA\x0D\x97\x12\x91\x22\x94\x80\xBA\x45\xCB\x93\xA8\x48\x98\x52\xA5\x2A\x45\x06\x45\x89\x12\x30\xC6\xC2\x08\x2B\x56\xA4\x8D\x19\x36\x42\x18\xA1\x40\x82\x44\x08\x8B\x0D\x2C\xD2\xA5\xEB\xA0\x41\x8F\x20\x3D\x28\x34\xEC\xEB\xB7\xA1\x83\x00\x10\x29\xFF\x4A\xA4\x8B\xD1\x01\x00\x00\x08\x32\xD8\xC8\x31\x43\xAA\x4E\x93\x29\x6F\xE8\x6C\x79\x81\x00\x4C\x99\x32\x3B\xA4\xA8\xC2\x66\x8A\x12\x3A\xA8\x74\x69\x93\xB6\x6D\x5B\xB8\x6E\x4D\x89\xFE\x4A\x74\xE9\xD3\xAF\xD3\xDB\x56\x6B\xF3\x13\x13\x44\x86\x14\x93\x34\x69\xA2\x44\x49\x54\xA6\x3A\x4A\x30\x7C\x18\x61\xDC\x78\x88\x10\x23\xCE\xCE\xC0\x01\x92\x05\x22\x22\x6F\x23\x34\x68\x50\xD1\x22\xC5\x03\x0B\x18\xE0\x1D\xE2\x63\xC2\xDF\xF0\x7F\x89\x08\x3E\x10\x91\x62\xDD\x08\x0F\x06\x28\xCE\xD0\x02\x47\x0E\x14\x1A\x44\xA8\xB0\x51\x12\xC8\x0D\x15\x2A\x58\xDA\x24\x40\xE0\x02\x06\x33\xA5\xA0\xC5\x1F\xB8\x2C\x03\x4A\x16\xA6\x38\x23\x8D\x34\x45\x75\xF3\xA0\x6A\x4D\x49\xB3\x0A\x24\x9A\xDC\x12\x8D\x6C\xB2\x71\xF3\x54\x0A\x23\x80\xF0\x81\x06\x4A\xC4\x61\x07\x18\x77\xC0\xB1\x04\x6E\x1F\x28\x37\xC2\x07\x2D\x26\xB7\x5C\x09\x22\x34\x86\x43\x0B\x46\xB8\x23\x1D\x5C\xD8\x4D\xB4\xC0\x44\xDA\xF1\x18\xC1\x0F\x7A\xF1\x25\x1E\x91\x0A\x49\xF0\xD0\x01\x84\xD5\x65\xD1\x46\x08\xB0\x90\x81\x73\x38\x48\x95\xDF\x0D\x2A\xE9\xB4\x1F\x08\x35\x0D\x30\xC0\xFF\x05\x33\x61\x41\x0A\x33\xCE\x00\x13\xCA\x13\xA8\x3C\x43\x4C\x31\x0C\xAE\xB6\x26\x37\xC1\x2C\xA2\x09\x2D\xD1\xC8\xC9\xE0\x69\x44\x69\x33\xC7\x07\x20\x88\x50\x82\x0D\x28\x9C\xB0\x42\x0A\x18\x64\x00\xC2\x71\x2C\xB6\xF8\x00\x09\x23\xE8\x27\xD2\x0D\x39\xE0\x90\x01\x22\xEE\xB0\xF0\x56\x5C\x3A\x3A\xC0\x00\xA6\x0C\x2C\xB0\xA9\x44\x24\x04\x49\xC2\x0B\x45\x8A\xCA\x0F\x79\x0F\x11\x76\x5D\x5D\x00\x14\xE0\x82\x7B\xCE\xD9\xA0\xA7\x8C\x25\xED\x77\xA5\x08\x59\x62\xB0\xA5\x06\x26\xB0\x81\x8B\x98\xCD\xCC\x22\x05\x29\x67\x12\xC3\x60\x83\x6C\x3A\x65\xC9\x25\x9B\x00\x13\x0D\x31\xCD\x62\x48\xD4\x36\xA8\x74\xB0\x67\x8C\xC5\x81\x54\x42\xA1\xC8\x25\x17\x82\xAC\x2A\xD0\x77\xC3\x0D\x38\x40\xC7\x07\xA2\x6F\xD9\x35\x51\xA6\x3C\x4A\xC4\xA3\xA7\x41\x90\x50\xC4\xA8\x44\x0A\x20\x98\x00\xA7\x2E\xB9\x11\x0B\x4F\xD2\xF8\xD1\x7C\x7D\xCE\xAA\x93\x4E\x59\x82\x70\x81\x62\x16\x34\xB1\x4C\x33\xC0\x00\xD3\xCC\x1D\x59\x30\x13\x0D\x37\xC5\x1A\xBB\xDA\x36\xA2\x58\xC2\xC9\x2F\xCC\x3A\x0B\x31\x37\xC5\x68\x93\x85\x12\x27\x60\x70\x01\xC9\x7A\xAA\xC0\x03\xFF\x0F\x66\x99\x55\xD2\x1A\x6A\xA4\xA4\x1F\x48\x32\x38\x59\x2E\xA5\x96\x5E\x9A\xE9\x8E\xEC\x02\xF1\x43\x04\xF1\x86\x57\xAA\x00\xEA\x4E\xB4\xE4\x01\x00\x1C\xE0\xC2\x05\xEF\x65\x20\x83\x0D\x19\x88\x80\x82\xC0\x4F\xEB\x54\x6B\x96\x17\xD0\x90\x47\x0A\xA4\x34\xD3\x4B\x2F\xD0\x38\x13\x88\x1F\xCF\x74\x43\xEC\xC4\x6B\xAA\xA2\xD5\x2D\xC2\x08\xB3\x31\x37\xDD\x10\xA3\x0D\x29\x77\x50\x72\x87\x1C\x5F\x34\xA1\x04\x4D\x24\xA9\x10\x16\x0C\x36\x00\xD1\xF2\x49\x28\xE1\x57\x16\x09\x2A\xD7\x6C\x69\xA6\x98\xEE\x78\x17\x0C\x7A\x55\xE0\xB3\x5F\x0F\x3D\x24\x74\x61\x75\xB1\xE7\x02\x0B\x17\xD4\xD0\x02\x02\x32\xB4\xE0\x34\x48\x35\x49\x0D\x75\x96\x26\x68\x81\xCA\x1C\x6C\x30\xA3\x30\x30\xD0\x2C\xB3\xCE\x32\xCF\x44\x43\x76\xD9\x4D\xB1\xB2\x48\x25\xB4\xA8\xBD\xB6\xB3\xAA\x09\x83\x8B\x19\xBC\x69\x72\x49\x1C\x4D\x40\x7D\xDB\xD3\x40\xA8\xB1\xC6\x1A\x81\x9F\xA4\x06\x4A\x3F\x48\x6F\x43\x58\x6F\x65\x84\x78\xE2\x39\x2F\xF0\x40\x0F\x43\x10\x04\x39\x43\x15\x48\x8E\x24\x7A\x74\x21\x60\xB4\xCC\x21\xE0\x10\xC2\x00\x36\x7C\x2E\x42\x0E\x39\x0C\x3C\x7A\xFF\xE9\x73\xE8\x82\xCB\x35\xCA\xB0\xDE\xFA\x32\xF0\x2C\x43\x0C\x34\x66\x27\xB1\xDA\x71\xA3\x16\xB8\x5B\x45\x30\x80\x31\x8C\x61\x10\x83\x81\xDD\x00\xC7\x30\x9C\x71\x87\x4B\x0C\x0F\x0C\x49\x68\x89\xAD\x6C\x02\x02\x14\xA0\x41\x0D\x1E\xFC\x20\xF4\xD0\x90\x92\x9D\x4D\xAF\x7A\xD3\xB1\x59\xE2\x30\xB5\xA9\x4D\x41\xA0\x07\x3C\x03\xDF\x42\xC6\x27\x00\xA3\x3D\xA0\x7C\xEB\x01\x00\xE6\x0C\x00\x12\x02\x0C\x80\x46\xF3\xC1\xC1\x0D\x44\x80\x01\xFA\xA0\xA0\x56\x26\x80\xC3\x32\x80\xB1\x8C\x78\x54\xA3\x75\xD0\x78\xE2\xEB\x70\x41\x0C\x01\x0E\xB0\x76\xB9\xC0\xDD\x26\x7E\xB1\x3F\x85\x45\xA3\x1B\xC0\x78\x06\x28\x26\x71\x07\x29\xE0\x4D\x60\x35\xD1\x20\x0A\x6E\xD0\x41\x10\x7A\x50\x84\x23\x94\xDE\x0F\x08\x77\xC2\x1A\xA2\x2B\x85\x2B\x54\xC0\x02\x80\xD4\x83\x50\xC1\xF0\x20\xE2\x7B\x48\x00\x12\x03\x81\x1A\x9E\xC7\x22\x45\x3B\x80\xCC\x10\x40\xA3\x2D\xD1\x48\x24\x39\x08\xE2\x10\xF5\x33\x02\x11\x60\x01\x17\xBF\xE8\xC5\x12\xAB\xB1\x40\x05\x0E\x03\x15\xD4\xC0\x05\x15\x09\xD8\x94\x67\x2C\x02\x12\x98\xB0\x85\x2F\xB6\x28\x0C\x6F\x04\x43\x18\xA8\xFF\x78\x02\x13\x4E\x60\xC6\x0C\xC6\x24\x32\x6C\x6C\xE3\x08\x49\x18\xC7\x12\x58\xEF\x7A\xA7\x4A\xA1\x03\x56\xE8\x80\x17\xFC\xA0\x04\x8F\xEB\x23\x3F\x64\x48\x04\x08\x50\x80\x8E\x95\xC3\x57\x0B\x06\xC0\x82\x45\xF6\xB0\x05\x8E\xCC\x81\x10\x89\x28\x02\x26\x28\xA8\x17\xBF\x30\xC5\x35\x96\xB1\x40\x06\x12\x23\x14\x6B\x28\xC5\x36\xAA\xD8\x94\x07\xB1\x69\x1B\xA1\xC0\x5D\x2D\x7C\x21\xCF\x79\xFA\x62\x1B\xC1\xF0\x05\x2E\x96\x40\x93\x59\x9E\x71\x83\x3A\x59\x41\x07\xDD\x98\xCB\x37\x4A\xAF\x07\xBC\xB4\x9E\x7A\x9C\xE9\x80\x03\x98\x27\x53\x92\xD3\xD4\x30\x7F\x40\x82\x82\xC0\xB0\x02\x00\x90\x9C\x41\x20\xF0\x82\x07\x9C\x47\x22\x07\x08\x40\x01\x64\xC0\x82\x01\xB8\xE0\x51\x8C\x6C\x81\x9E\x1A\x25\x44\x92\xE8\xC4\x0F\x62\x52\x58\x29\xF6\x40\x0A\xDE\xA1\xA9\x14\x4C\xB8\xC3\x6C\x26\xC6\xCE\x35\x75\xA3\x16\x89\x80\x44\x2A\x72\x41\x4F\x79\x06\x23\x18\xB6\xA8\x86\x16\x36\xC0\xCF\x7E\x5E\x49\x05\x28\x59\xC1\x7E\xF4\x53\xA5\x94\xC0\xD1\xA0\x07\xBD\x9E\x42\x19\x9A\xB8\x79\x41\x84\x53\x3E\xE8\x41\xCF\x60\x38\x3E\x09\x18\x04\x54\x97\xCA\x4E\xFF\x0C\x1E\x20\x83\xA2\x31\xED\x02\x08\x50\xE4\x0C\xF4\x14\x3F\x14\x60\x00\x60\x58\x60\x06\x34\x14\x36\x0C\x59\x50\x61\x0E\xCE\x18\x16\x83\x74\xD1\x04\x2D\x30\x45\x94\xAB\x01\xC7\x33\x18\xF1\x88\x4A\xD8\xA2\xB1\xBE\xE8\x85\x2F\x50\x19\xD9\x5C\x90\x61\x9F\x4B\x1D\x1D\x0A\xF0\xA3\x1F\x6F\xC9\x48\x46\x04\x8D\x23\x0C\x10\x5A\x97\x53\x5D\x4A\x86\x41\x6B\x21\x09\x86\x04\xB9\x8B\x02\x80\xAC\xFC\x18\x26\x09\x3A\xBA\xD0\x03\x10\x41\xAD\x1C\xF1\xDC\x05\x5C\x30\x01\x1C\xCC\x60\x3E\x73\xAD\xEB\x4E\x4E\xF1\x8C\x71\x0E\x83\x19\x59\xA0\x02\x2A\xA8\x18\x0C\x2D\x4C\x01\x17\x11\x7A\x90\x34\x80\x51\x0B\x67\xE4\x14\x1C\xE1\x08\xC7\x6A\xBA\x21\x8A\x44\x54\xA2\x15\x8D\xB5\x45\x2F\xBE\x6B\x8B\x57\xE4\xC2\x0F\xFB\xB4\xC9\x6D\xB2\x34\xB5\xA7\xE5\x87\xB3\x2D\x02\x09\x7D\xA8\x2A\xBD\xB1\x20\x74\x68\xEA\xB9\x59\x44\x18\x50\x00\x19\x6E\x2A\x02\x7B\xA1\x68\xBC\x24\x70\x51\x01\x1C\x64\x98\x0A\x0D\x4C\x05\x88\x30\x01\x16\x70\x84\x46\x9D\x9B\x80\x0C\x66\x90\x01\x0D\xD4\xC0\x31\x43\xB4\x81\xEA\x88\x3B\x0C\x68\x80\xA2\x03\x64\x08\x46\x3A\x37\xFF\xE4\x07\x1A\x90\x82\x1B\xC9\x50\x53\x37\xA2\xA1\x8B\x50\x84\x22\x18\xDC\x00\x87\x38\xB0\xBB\x9A\x59\x84\xC1\x94\xB5\x10\xEF\x77\x5D\x51\xDE\x96\xA0\xD7\x8C\x52\x99\xDF\xDE\x44\xB2\x98\x10\x94\x65\x4F\xF5\x29\x28\x7D\xA7\x73\x00\x83\x28\xD8\x01\xEA\x51\x1C\x03\x4C\xCB\x29\x12\xF4\x00\x02\x90\xC3\xE8\x41\x0E\xB0\x51\xC2\x10\x38\x06\x13\x98\xC0\x01\x10\xB0\x16\x03\x10\x81\x05\xFC\xCA\x40\x85\x67\x30\x44\x1A\x80\x42\x63\xCD\x42\x93\x2E\xB2\x90\x02\x50\x68\xA3\x28\xA5\xA0\x01\x1B\x72\x91\x0C\x60\xFC\x02\x1A\xDE\xD0\xC5\x36\x9E\x11\x8A\x32\xE8\xA2\x1B\xA9\x21\x4A\x32\x5E\x2C\x8C\x4A\x84\xC1\x0C\x94\x90\xC5\x8D\xC5\x5B\x0B\x57\xD8\xA2\xC3\x97\x01\x50\xD4\xA4\x42\xB2\x0B\xC0\x2A\x03\x03\x48\x4E\x58\x3A\xCB\x27\x1B\xF4\x20\xC9\x6F\x59\xB2\x1F\x0F\xF0\x00\x0A\xAC\x4B\xCA\x9C\xDA\xA3\x6A\x45\x75\xD1\x84\x20\x2A\x49\x13\x11\xC0\xE3\x2A\xF0\xE5\x18\x20\x60\x06\x21\x30\x40\x11\x30\x27\xA5\x0B\xCC\x20\x07\x35\xD8\x60\x73\xA5\x21\xA7\x65\x2B\xBB\x14\x4A\x68\x82\x73\x89\xA2\x8B\x2A\xDC\x20\x58\xB6\x68\x45\x2F\x9E\x21\x8A\xFF\xD9\x68\x03\x14\x62\xD0\x05\x38\xC0\xF1\x14\x50\x30\x05\x18\xAB\x88\x44\x18\x1E\x81\x89\x48\xBF\xE2\x15\xB5\x78\xB7\x2D\x4A\x61\x81\xFF\x68\x50\xBD\x22\xB9\x80\x01\x48\x46\x1F\x11\x9C\xE0\x02\x19\x08\x81\x48\x3E\xB0\x96\x10\xF0\x69\x97\x57\x75\x80\x42\x20\xE0\x80\x66\x3A\xC0\xD5\x2C\xEC\xC1\x44\x47\x25\x60\x85\x30\xE9\x3C\x0F\x31\x88\x6E\x27\x40\x84\x5E\x87\xA0\x01\x45\xD0\xC1\x34\x45\xE0\xB4\xF8\x3D\x6D\x0E\xCC\x20\x16\xCA\xA5\xF1\x0C\x3F\xA4\x20\x0B\xD1\xDE\x06\x28\x6E\xC0\x86\x65\xD0\x22\x15\xB4\xF8\x85\x28\x74\x11\x0C\x69\x38\x43\x09\x59\xC8\xC5\x36\xFC\x70\x04\x3A\x33\x28\x15\x65\x30\x43\x22\x2C\x11\x8B\x77\xBF\xC2\x15\xEF\xAE\xC5\x2B\x64\x31\xB2\x1E\xEB\x49\x27\x19\x20\x40\xBE\x3F\x20\x92\x0D\x24\x41\x09\x4E\x0B\xB8\x0D\x1E\x70\x00\x82\xDB\xA0\x2C\x07\x5F\x48\x05\x9C\x1C\x81\x86\xAF\xF0\x21\x0A\x78\xBB\x00\xA8\x6C\xE5\x3E\xFA\xA0\xE2\x12\xA9\x97\x41\xD2\xFA\x80\x22\x70\x9C\xCC\xFC\x98\x66\x0B\x2E\xA0\x01\x92\xA3\xC0\x0F\xBF\x90\x50\xC4\xA4\x2D\x86\x0E\x54\xA1\x14\x75\x9E\x76\x07\xE8\x50\x0A\x4E\x6C\xFF\x82\x16\xB3\x88\x44\x2E\xB8\x01\x0B\x0E\x10\x80\xD0\x65\xF0\x43\x9D\x93\x11\x8D\x32\x2C\xC1\x0E\x61\x58\x04\x27\xDE\xED\x0A\xA7\x33\x1D\x2A\x98\x56\x6F\xC0\xFC\xA3\xEF\xAD\x2F\xC1\x09\x1B\xC8\x80\xD6\x3F\x00\x03\x16\xA8\x9A\xE0\x66\xB7\xDE\x03\x7C\xC0\x90\x8A\x90\xA0\x01\x05\xD8\x94\x00\xDE\x0E\xF7\x61\xBE\x40\xF8\x30\xDC\x01\xAB\x3B\x4A\xE0\xBC\x1F\x00\x3C\x9D\x0B\x01\x02\x84\x3F\xCD\xDE\x5A\x20\xCD\x34\x98\x04\x30\x26\xB6\x0D\x59\x64\x01\x05\x1C\x20\x03\x2E\x70\x91\x05\x0C\x6C\x60\x0C\x98\xD8\xC4\x26\x2E\x0F\xE8\x60\x90\xC1\x02\xA0\x70\x06\x29\xFA\x50\x0A\x5D\x3C\x83\xB2\x1C\x98\x44\x18\x70\x57\x2C\xCC\x82\x2A\x84\x02\x28\x1C\x60\x29\xA8\x5F\xBD\xE5\x84\x08\x5C\xC0\x00\xFC\x87\xBF\x89\x84\x06\x6C\xC0\x13\x38\x41\x12\xFC\x5B\x72\xB4\x40\x0B\x14\x41\x6D\x85\x00\x09\x94\xC5\x0B\x84\xE0\xAA\x35\x84\x45\x14\x5F\xD0\x2C\x80\xF2\x29\x80\xA9\x6C\x54\x1F\x55\xC0\xDA\x9D\xC7\xA6\x20\x44\xF5\xF1\x03\x22\x61\x5F\x0C\xFC\x5D\xDF\x68\x80\x05\xC0\x8F\x15\x2C\x41\x28\x10\xC3\xC4\x88\x1B\x33\x90\x42\x15\x6C\x40\x07\x84\xFF\x4C\x4C\x9C\xC0\x18\x88\xC2\x26\x7C\x82\x2C\x84\x42\x29\xE4\x82\x2E\x90\xC1\xFD\x88\x81\x1F\xD0\x01\x19\x8C\xC1\x18\x88\x01\x1C\xDC\x01\x14\x80\xC1\x23\x4C\x42\x1D\x90\x51\x0A\xA0\xC0\x0A\xF4\xD5\x16\x04\x8A\xC0\x7C\x00\x02\x1C\x00\x97\xD8\x84\x54\x64\x00\x07\x38\x81\x13\x3C\x01\x06\x6C\x0B\x91\x15\x44\x6D\x3D\x00\x91\x95\x80\x08\x22\x5C\x43\x54\x40\xF5\x49\xC0\xA6\x28\x9F\xE4\x2C\x00\x33\x81\x07\xF8\x50\x00\x04\x28\x4E\xC3\xB9\x96\x41\x04\x00\x59\x69\x59\x5C\xDC\xE0\x82\x85\x04\xD6\xC9\xDC\x1D\xA4\x02\x10\x96\x4D\x38\x88\x83\x36\xE0\x82\x1F\x6C\x01\x07\x28\x95\x4C\x90\x81\x28\x70\x42\x2C\x94\x82\x18\x94\x81\x36\xA0\x02\x2E\xA0\x42\x16\x90\x01\x28\x34\x0C\x14\xD8\x01\x25\x1C\x01\x07\x40\xC1\x17\x2C\x41\x0A\xA8\xC0\x0F\xE8\x81\x1E\xD8\xC7\x0C\xA4\x40\x13\xD0\xC4\x07\x18\x40\x0C\x18\x81\x0C\x90\xCC\x10\x89\xC4\xD5\x29\x01\x1D\x3A\xC1\x09\x60\x5F\x72\xC0\x80\x0B\xF8\x91\x03\x10\x1C\xA8\x90\x00\x20\x36\x44\x0C\x1C\x80\x04\x10\x22\x0A\xAA\xE0\x09\x32\x00\x05\x68\x1C\xF8\x48\xC0\x6C\x31\x54\x00\x24\xC4\x01\x10\xFF\xD8\x04\xBC\x80\x08\x84\x00\x0B\x18\x84\x98\xA1\x80\x03\xA6\xC0\x29\x94\x02\x27\x12\x90\x75\x85\x83\x37\x68\x43\x35\x80\x42\x1A\x6A\x40\x07\x88\x01\x25\x70\x42\x24\xDC\x01\xFA\xE1\x02\x29\x5C\x61\x16\xF8\x81\x18\x2C\xC1\x13\x64\xC2\x1D\x1C\x81\x18\x68\x01\x13\xA0\xCC\x10\xA8\x83\x3C\xD0\x03\x22\x00\x41\x5A\x30\x01\x0A\x7C\x80\x0C\x14\x02\x22\x18\xC1\xA0\x64\x49\x1C\x66\x80\x12\x40\x01\x1D\x2A\xC1\x07\x64\x00\x06\xBA\x80\xF3\x19\xC4\xD8\x59\xCF\x37\xF6\x85\x38\x42\x40\xF2\x25\x1F\x1E\x71\x4A\x3A\x82\x8F\x47\x31\xD4\xC5\x21\x84\xF8\x90\x8A\x99\x85\x80\x22\x9A\xD9\x0D\xB0\x4F\x15\x30\x83\x25\xA4\x82\x30\x18\x56\x53\x0C\xA4\x28\x32\xC1\x06\x94\x5E\x24\x88\xC2\x2C\x84\x02\x29\x1C\x20\x19\x68\x01\x1D\x88\x41\x16\x68\x81\x1D\xD8\x81\x43\x2A\x01\x10\xA0\x0C\x22\xD0\x03\x3D\xDC\x03\x3D\x10\x82\x0A\xAC\xC0\x0D\x08\x41\x11\xB4\x43\x3B\xE8\x41\xC9\x48\x45\x3D\x16\x42\x0E\x2C\x01\x14\x14\xE6\x13\xDC\x9E\x01\x24\x47\xBE\x24\x84\x03\xF0\x64\xAC\x01\x06\x3B\xBA\xDD\x50\x6E\x87\x44\x00\xD8\xA8\x1C\x65\x52\x26\xC4\xF4\x4D\xFF\x40\x0B\xC4\xC5\x41\x84\x80\xFB\x68\x00\x2A\xE4\x42\x24\xC8\xC2\x55\x62\xE5\x6A\x78\x03\x33\xF8\x81\x12\x70\x80\x17\xD8\x81\x28\x5C\xC2\x24\x3C\x21\x2A\x78\xC5\x13\x68\xC1\x18\xB0\xE5\x12\x70\xC0\x0A\xA8\x81\xF4\xB4\xC3\x3D\xBC\x83\x70\x1E\x82\x7E\xE0\x41\x3B\x20\xC2\x20\x04\x5E\x4C\x48\x45\x72\x14\x02\x3F\xCC\xC0\x13\x14\x26\x1D\x72\x40\x06\x18\xC0\x00\xF0\x21\x0B\xDC\xA0\x0C\x62\x84\xC2\x89\xC7\xAD\x4D\xCE\x0A\x1D\x00\x04\x40\xE2\x65\xC6\x23\x96\x25\x84\x04\xEC\x00\x3F\x24\x00\x0B\x60\x1F\xBC\xF0\x03\xAF\xB9\x00\x1B\x38\xC3\x2D\x44\x82\x27\x84\x1F\x01\x3D\x10\x38\x44\x88\x34\x14\x83\x7F\x6E\x03\x33\xF4\x01\x07\xB4\xDC\x1D\x64\x82\x2C\xCC\x82\x28\x68\x82\x18\xC9\x81\x16\x54\xE4\x11\x28\x41\x6F\xFE\x80\x0D\x1C\x02\x3D\xBC\xC3\x3A\xA8\x83\x1E\x94\x00\x0F\x04\x01\x70\xBE\x03\x1E\x70\x1A\xAC\x38\xA5\x41\x20\x02\x0A\x14\xA6\x74\xA6\xC0\x05\xB0\x4F\x47\x2C\x98\x76\x1A\x44\xDA\xA5\x23\xAA\x85\xC7\x77\x9E\xE0\x02\xD4\x8B\x03\x58\x26\x91\x10\x01\x52\x9A\x27\x43\x90\x95\xAE\x85\x40\x06\xDC\x63\xDE\x85\x80\x70\xF5\xFF\x82\x25\xDC\xA7\x28\x05\xE4\xA1\x69\x4C\x31\x04\xD0\x2B\x4E\x81\x05\x6C\x40\x14\x7C\xC1\x18\xD4\x41\x1D\xC8\x41\x16\x24\xC1\x11\x1C\xC1\x17\xDC\x01\x20\xE8\x41\x10\x90\x24\x10\x1C\x82\x3A\xA8\x83\x21\x00\x41\x8C\x88\x80\x21\xBC\x43\x5F\x6A\x5D\x3D\x86\x40\x8B\x16\x42\x0A\x98\xA8\x4C\x2A\xC1\x05\x3C\x00\x02\x6C\x09\x02\x3C\x00\x0B\xE4\x24\x3F\x4C\x80\x03\x00\xAA\x9F\xFA\xC5\x91\xB0\xDD\x0A\xF1\xC8\x78\xC6\x4B\x38\x9A\xE7\x3B\xFA\xC5\x01\xB4\xE7\x03\x20\xC4\x15\x30\xC3\x30\xFC\x42\x24\x60\x4C\x92\x5E\xD7\x75\x75\xC3\x36\x34\xCB\x13\x7D\xAA\x02\xDA\xC4\x06\x8C\xEA\x06\x70\x00\x97\x4A\x82\x26\xFC\xC1\x3A\x60\x43\x10\x04\x01\x48\xDC\x80\x1A\x04\xC1\x7E\x68\x00\xC9\xE8\x01\x36\xE8\x41\x72\xA8\x48\x8B\x1A\x04\x1F\x24\x81\x14\xC8\x24\x1D\x2E\x01\x06\x84\x19\x43\x85\x63\x45\x4C\x80\x11\x64\x59\x45\x90\xE7\x5F\x88\x4F\x8D\xD2\xA8\xBA\x1C\x53\x91\x08\xA2\x79\x4E\x5F\x5F\xF0\x9A\x7B\xF2\x2A\x29\x6C\xC3\x30\x04\x83\x56\xF4\x82\x61\x05\x64\x8C\x71\x83\xA7\xE6\x95\x02\x41\x03\x33\xD0\x01\x4C\x28\x81\x45\x52\x29\x2E\x72\xFF\xC2\x25\x5C\xC3\x3D\xB8\xC3\x1A\xB8\xAA\x0A\x28\x41\x2B\x96\x41\x19\x88\x41\x12\x5C\x80\x0C\x14\x41\x08\xBC\xE7\x42\xE0\xC1\x12\xFC\xAA\x89\x3E\x41\x07\x18\x81\x82\x1D\x40\xB2\x12\x01\x11\x54\x80\xB4\x92\x87\x44\x88\xCA\x1F\x81\x27\xA7\x30\x6B\x78\xB0\xDA\x42\xE1\xDD\x5F\x4C\xC0\x9E\x1E\x13\x1E\xFC\xCF\x14\x85\x82\x25\xD4\x42\x4E\xD5\x4E\xB8\x7D\xA2\x38\x88\x83\xB2\x35\xD0\x02\x41\xC3\x02\xFD\x82\x18\x88\xC8\x1B\xBC\x81\x24\x3C\x02\x24\x78\x42\x2A\x80\xC2\x35\xB4\x03\x86\xAA\x41\x0A\x2C\x41\x22\xA8\xC2\x2C\xCC\x02\x2D\xAC\x82\x28\x6C\x01\x91\x91\x40\x5F\xA4\x41\x14\xFC\x2A\x1D\x42\x41\x14\xA4\x80\xC0\xF6\x85\x04\x24\xC9\xA8\x54\xEC\xA1\xD6\x0B\x8E\xFE\x05\x3B\x62\x4A\xA3\x86\xC7\xA2\x1A\x44\x1E\xD4\x59\xC4\xA8\x82\x25\xAC\x42\x27\xD6\xCE\x83\x58\xD7\xCA\x7A\x43\x34\x3C\x83\x30\xFC\x82\x2E\xD4\xAD\x2E\x38\x03\x2E\x88\x41\x1D\xD4\xAC\x24\x98\x12\x27\x78\x82\x26\xF8\xC1\x1F\x10\xC2\x1A\x28\xC1\x13\x98\xC1\x26\xB4\xC2\xEA\xB5\x02\xE3\x92\x02\xB5\x74\xAD\x41\xB8\xC3\x0D\x40\x6D\xD4\x4A\x41\x12\xB4\x80\x78\x64\xFF\xE6\xB4\x8E\xCF\xB3\x2E\x00\xC6\x12\x2A\x43\xC5\xA3\xA8\x4C\x80\x20\xF0\xC1\x29\x78\x03\x3B\xD5\x42\x24\x20\x90\x28\x45\x08\x37\x0C\x64\x35\x54\x83\x32\xD0\x01\x1C\x60\x81\xED\x6A\x41\x1F\x80\x02\x1D\x7C\x01\xDF\x5E\x02\x26\xFC\x2D\xE0\x66\x42\x26\xC0\x81\x17\x24\x42\x2A\x4C\x9A\x2B\x30\x2E\xE3\xE2\x42\x15\x7C\x40\x09\x08\xA9\x42\x90\x28\xE5\x3A\x01\x14\x48\xC1\x13\x88\x80\x78\x58\x94\xCF\x68\x2D\xF2\x09\x80\x7A\x12\x49\xC3\xC5\x63\x4F\x12\x09\x1E\x54\x83\x37\x1C\x9A\xA5\xA6\x82\x2D\x9C\xAC\x4E\x75\x83\x6A\x56\x03\x3B\xC8\x43\x3D\xBC\xC3\x20\xB4\xCC\x5B\xAE\xC0\x19\xAE\x01\x13\x7C\x81\x24\xF8\xEE\xEF\x7A\x02\x00\x7B\x42\x26\x8C\xC1\x22\x1C\x2F\xF2\x32\x2E\x2D\xB4\x82\x2E\x6C\x81\xEE\x45\xEA\x42\x18\xC2\x09\x48\x01\xF5\xD2\xA9\x13\xA4\x80\xBC\x40\x8E\x45\x41\xAB\x00\x7C\x6E\x43\x4C\x8E\x24\xC6\x4B\x1F\x78\xC3\xCA\x46\x8C\x33\x2C\xC2\x25\xC4\x02\x34\x10\xD0\x9F\x81\x42\x20\xA4\x43\x3E\xBC\x70\x3E\xAC\xC3\x20\xB4\x81\x08\xA1\x8C\x64\x30\x81\x1D\xF0\x46\x00\x07\xB0\x1D\xB8\xDF\xBB\x29\xEE\xEA\xB9\x42\x02\xEB\xFF\xC2\x1C\x5C\x40\x09\x38\xB0\x42\xF4\xEA\x34\xCA\x64\x61\x4A\x81\x05\x23\x53\xB3\x5E\xD4\xD6\x42\x2E\x43\x04\xCD\xBC\xC4\x4B\x11\x9C\x42\x37\x88\x83\x37\xA4\x49\x6B\xD8\xE7\xE1\x19\xCB\x34\x74\x83\x36\x94\x02\x1B\xAC\x41\x1B\x10\x42\x3C\xC0\x70\x3D\xA4\xC3\x1E\xAC\xC1\x40\x05\x01\x1A\x48\x41\x26\xEC\x30\x00\x63\x02\x18\x2C\xC2\xD2\x25\x6F\x10\x27\xAF\x02\xD3\x81\x11\x23\x71\x42\x0C\xE6\x34\x46\x6D\x61\x2A\x01\x0E\x40\xB1\xD7\x0E\x18\xF2\x2D\x80\xBC\x3C\x6B\xBC\xA4\x41\x35\x7C\x62\x37\xA4\x49\x2D\x50\x82\x19\x60\xC2\x2A\x70\x0C\x9B\xE4\xC2\x1D\xD0\x40\x90\xA8\x41\x1B\x0C\x82\x3A\xDC\xC3\x0B\xD3\xC3\x35\xB8\x81\xCB\xE4\x12\x1A\x50\x81\x1C\x68\x42\x00\xC3\xB2\x25\x80\x41\xEE\xF8\x71\x1F\x33\xAE\x2E\xD0\x81\xF3\x86\x00\x43\x40\xA7\x74\x1A\xB2\x13\x2C\x81\x0D\x28\xF2\x22\x4F\xCE\x15\x67\xEE\x02\x7C\xF0\xA8\x94\xED\x08\x6F\x03\x34\xA4\x02\x26\x3C\x42\xB2\xD8\x82\x9A\x38\x05\x2E\x68\x81\x54\x29\x0F\x1A\xB7\xC1\x35\xD4\xC3\x0B\xC7\x03\x21\xD0\xF0\x64\x54\x09\x1A\x44\x01\x25\x68\x02\x26\x60\xC2\x25\x50\x82\xBE\xA6\xFF\x02\x1F\xDF\x32\x2E\xB3\xC1\x72\xF0\xF2\x42\xA0\x40\x74\xCA\xE4\x12\x58\xA4\xD4\x46\x01\x0A\x10\xF3\x5F\xCC\x90\xE4\x04\xC0\xF8\x76\x70\x32\xFB\xCC\x1F\x88\x30\x76\x6D\x83\x2D\x70\x82\x26\xD4\x81\xFB\xA5\x02\x30\x54\xF3\x86\xE8\x82\x16\xA8\x85\x0D\x4C\x95\x28\xB7\x41\x1B\x1C\x82\x37\xDB\xC3\x3A\x10\xC2\x2A\xE7\xD2\x0D\x0C\x96\x16\x64\xC1\x13\x6C\xA9\x19\xAC\x02\xE3\x06\xB1\xF2\x2E\xAF\x3C\x97\x00\x3D\x27\x04\x1F\x9C\x80\x89\x2A\x41\x07\x74\x00\x07\x44\x81\x4E\x9B\x80\x3F\xFF\x33\x00\x04\x00\x50\x5B\x6B\xE4\x68\x2E\x91\x14\x01\x2A\x20\x34\x37\x44\x43\x2D\x70\x42\x28\x4C\x41\x07\x4C\x02\x26\xD0\x02\x34\x34\xC8\x69\x24\x03\x19\xA4\xC0\xAB\xAE\x00\x0F\x98\x44\x46\x6F\xB4\x37\xD7\x43\x2A\x0B\x54\x4A\x04\xC1\xC0\x6C\x1A\x06\x1C\x01\x25\xC4\xC2\x4A\x2F\xAE\xF2\xB2\x02\x2A\xAC\x41\x58\xC4\x34\x42\x14\x41\x4C\x42\xC1\x12\x10\x00\x0A\x68\xE0\x09\xE8\xF4\x09\xF4\xF4\x5F\x00\xB5\x60\x28\xF3\x50\x0F\x74\x78\x08\x01\x33\x50\xF2\x36\x44\xC3\x2A\x68\x02\x1D\xB4\x80\x0C\x54\x81\x28\x78\xC2\x85\x40\x0B\x28\xE8\xCD\x66\xE1\xFF\xAF\x49\x6C\xB3\x1B\x74\xB3\x3D\x80\x33\x1C\x0F\x94\x0A\xD8\x84\x33\x26\xC1\x25\x24\x30\x10\xB7\x34\xE3\x2E\x03\x21\x2C\x87\x20\x1F\x04\x0E\x24\x41\x14\x24\x81\x08\xB0\x00\x13\xC0\x0B\x4C\x52\xA3\x5F\xFB\x85\x0F\xD0\x0B\x51\x57\xB1\x50\x17\x49\xF9\x36\xB3\x30\xA4\x82\x26\x60\x81\x41\xB4\x80\x1C\x44\xF6\x64\xEB\x42\x54\x94\xC0\x66\x6D\x56\x4A\xA0\x01\x1A\xBB\xC1\x20\xA4\x43\x3D\x80\xB5\x1B\x88\x10\xFE\x82\x0B\x10\x0C\x0C\xFB\x1D\x81\x17\xB8\x33\xE3\x1E\xB0\xF2\xCE\x82\x35\x5C\x03\x6B\x2F\x84\x0D\xC4\x12\xE6\xD6\x40\x6D\x1B\x84\x06\x24\x41\x0A\xEC\x6A\x6E\x2B\x44\x05\xD0\x0B\x00\x7C\x6F\x5F\xCC\x90\xCF\x30\xB3\x38\x9C\x46\x30\xA4\x02\x25\x28\xC1\x41\xA4\xC0\x1D\x68\xC2\x26\xD8\x42\xB7\x3D\xA3\x73\x3F\xF7\x0A\xA4\x44\x46\xBB\x01\x21\xAC\x43\x3D\x7C\xF4\x67\xE3\x65\x95\xA0\x40\x12\x40\xC1\x18\x24\x82\x28\xB4\x34\x5B\x2B\xAF\x2C\xAC\x6A\x7A\x2B\x04\x0B\x88\x00\xE6\xF2\x03\x0D\xDC\xC0\x41\x00\xAC\x08\x48\x6B\x7D\x2F\x84\x04\xF0\x76\x78\xC0\x78\x91\xF4\x81\x36\xC4\xD8\x69\xFC\x02\x26\xD0\x01\x0D\x20\x04\x13\x40\xFF\x75\xFC\xB1\x01\xEE\x2D\xC7\x73\xEB\x87\x56\xFF\x4D\x1B\xB8\x81\x84\xAF\x43\x3C\xA4\x72\x48\x4B\xCF\x0A\x7C\x81\x1D\x08\xA0\x69\xA3\xB6\xF2\xA2\xC2\x93\x87\xC5\x63\x2A\x44\x0B\x28\x41\x8A\x1B\x44\x11\x28\x62\x8C\x37\xC4\xB3\x02\x80\x8D\x13\x73\x08\xA7\xC6\x6C\xF4\x02\x26\x68\x81\x42\x4C\xC1\x6E\x50\x02\x13\x18\x0A\xB5\x1C\xF9\x83\x4B\xB7\x46\xEF\xC1\x35\xAC\xC3\x35\x0C\x42\x94\xFF\xC0\x0A\x48\x41\x1D\x80\x41\x19\xC0\xA6\x4A\x63\x79\x2B\xB0\x82\x1F\xAC\xC3\x21\x60\xCB\x03\x38\x67\x43\x98\xC0\x09\x64\x63\x99\x17\xC9\xBC\xCC\x5A\x6E\xAF\xB9\x8C\xD9\xC2\x25\x34\xC1\x42\x28\xC1\x24\xF8\xC1\x0A\x18\x0A\xC0\x35\xF8\x65\x3F\x78\x57\x0F\xC2\x35\xA4\x43\x38\x0B\x94\xF4\xA4\x40\x6B\x62\x00\x07\x44\x02\x2B\xB0\xC2\xA2\xA3\xF6\x2C\xB0\x81\x21\x10\x42\x09\x24\x63\xF3\xF1\x41\x5C\x26\x84\x10\x28\x41\x3F\x5F\xBA\xAC\xFD\x74\x7D\x87\xF0\x4E\xD9\xC2\x24\xFC\x78\xA8\x5F\xC1\xDE\xB4\x88\x8A\x18\x19\x9E\x2B\x8F\x46\x4B\xF8\x35\x18\xC2\x1E\x84\xF4\xCE\x34\x20\x80\x3C\x81\x28\xAC\xC2\xAD\xB3\x42\xA2\x33\xAE\x2C\x4C\x81\x1E\xE0\xFF\x81\xA1\x8C\x45\x08\x16\xC1\xB0\x1B\x04\x0A\x30\x41\x98\x23\x7B\xF6\x26\x06\x07\xF7\x51\x08\x37\x85\x2D\xDC\xC1\x0C\x34\x04\x02\xC0\xC0\x0F\x88\x00\xB5\x8B\x04\xAA\x6F\x56\x95\x64\xF4\x20\x10\x02\x21\x00\x7A\x2E\xFD\x80\x0A\x5C\x80\x05\x70\x80\x1D\xAC\x82\xC5\x57\x42\x2A\x20\x30\xE3\x96\xC2\x2F\xC2\x34\xB5\x7B\x20\xA5\x18\x41\x3B\xB8\x43\xB1\x63\xAF\xBD\x53\xAC\xB2\xFB\x75\x1F\x9C\xAC\x34\xD8\x42\x1D\xD4\x00\x38\x3E\x00\xF5\x18\x8A\x9B\x1E\xFC\x5D\x72\xB5\x46\x2F\xFC\x1B\xA7\x04\xFE\x4A\xA8\xC4\x3F\x41\x24\xA4\x02\xDA\x72\x82\xC5\xAF\x42\x2A\xA8\x34\x28\x10\x07\xB5\x7F\x40\x03\x7C\x3C\x5C\x4C\x40\x11\x54\x01\x13\x58\xFA\xC9\x17\x89\x80\xE5\x3B\xF8\xAC\x7C\x51\x48\xC3\x2F\xBC\x7C\x5F\x38\xD9\xCC\x17\xBC\xCD\xAB\x40\xC2\x47\x78\x1B\x78\x10\xCF\xAF\xC0\x0F\x7C\x40\xFB\x01\x15\xC9\xAE\x42\x27\x18\x1D\x18\x88\x02\xA3\x5F\xC0\xD2\x87\x80\x8A\xC0\x08\x8B\x34\x80\x01\xAC\x40\xBD\x57\xBD\xBC\xFC\x36\x14\x6F\x81\x36\x9C\x2C\x30\x94\x41\x22\x5B\x2D\x31\x61\xCB\x07\xD8\xBD\xB5\x3F\xF7\x0F\x40\x38\x1A\xB7\x0C\xDA\xF7\xFF\x3C\x08\x2C\x01\x18\x84\x41\x24\x7C\xE5\x2A\xC8\xC2\x18\x34\x81\x17\x8C\xFB\x1D\x90\x4C\xD3\xE7\xFD\x08\xE0\x01\x36\xB4\x03\xAB\x56\x87\x32\x02\xBE\xEB\x37\x04\xE1\x9F\xAC\x30\xDC\x41\xE2\x7F\xFD\x0B\x18\xD4\x08\x6C\xDA\xE3\xC3\x4C\xE4\x2B\xCF\xF2\x50\x7E\x4A\x80\x04\x0A\x44\x41\x18\x84\x01\x18\x20\xAE\x2C\xF4\x81\x11\x7A\x01\xD1\x03\xB2\x01\x34\xFD\x8B\x94\x40\x30\x62\x83\x3C\xD0\xEF\x03\x18\x40\x8C\xBE\xBE\xF6\x1B\x84\x15\x30\x43\xA2\x11\x85\x30\x4C\x02\xCC\xFF\x05\x04\x78\x0A\xE3\xB7\x88\x91\x1F\x79\xEF\xDF\x12\x55\x0D\xFF\x18\x80\x81\x17\x98\x41\x24\xF8\x01\xAD\x12\x00\x14\x6C\x85\xF3\x97\x3E\xC1\x49\xBF\xF4\xE8\x81\x3A\xBC\x03\x40\x10\xFA\x50\xC0\x01\x3F\x83\x07\x11\x26\x54\xB8\x90\x61\x43\x87\x0F\x21\x46\xC4\x81\x2B\x99\x34\x6E\xDB\xB6\x89\xA2\x11\x91\xDF\x03\x12\x3D\x7A\x94\xF8\x30\x72\x44\x89\x12\x2A\x50\xAA\xB0\x61\x03\x08\x10\x35\x2F\xD5\xAC\x59\x13\xE4\x87\x8A\x13\x5B\xBC\x78\xB1\x03\x6A\x4A\x86\x0C\x17\xA4\x60\x4A\x25\xE6\x82\x81\x0F\x17\x3E\x84\x28\xD9\xE3\xC7\x8F\x12\x3F\x0C\x61\xD3\xD3\xA0\xFF\x40\x05\x8E\x57\xB1\x66\xD5\xEA\x50\x06\x2A\x6E\x17\xB7\x71\x83\x35\xE5\x2A\x05\x08\x2F\x7E\xF4\x18\x31\xF2\x43\x49\x95\x29\x7F\xB4\x74\xB9\x66\x8F\x21\x42\x40\x9A\xE2\x49\xB2\x84\x0D\x9B\x0B\x19\x8E\x42\x11\xAA\xC5\x40\x61\xA4\x49\x49\x94\x80\x01\xC3\xE4\x8F\x41\x86\x7A\x14\x38\x60\x64\x6B\x65\xCB\x97\x17\xB2\xF0\xF3\x95\x73\xB0\x2C\x59\x3D\x36\x85\x11\x82\xED\xC9\x94\x2A\xE2\xBA\x6C\x33\x28\xDD\xBB\x41\x4E\x2F\x68\x48\x83\xE7\xC2\x61\x03\x49\x26\xDD\x99\x52\x18\x81\x01\x04\x49\x43\x84\x20\x31\x7C\x38\x0C\x3D\x45\x1C\x08\x90\x80\x99\x79\x73\xAD\x73\xC2\x72\x8E\xE6\xA7\x48\x56\x16\x21\x9E\x86\x2C\x7D\x3A\x35\x90\x20\x7A\x08\x1D\x22\x14\xA4\xC4\x85\x16\x83\x64\x18\xA8\xFD\x01\x01\x06\x2D\x54\x8A\xF0\x2E\x6C\xA0\x41\x83\xE0\xF7\x1F\x08\xA7\x90\x5C\x00\x11\xE7\xFF\x01\x64\xE8\x0A\x6D\x2E\xFA\x6A\x9B\x52\xAC\xD8\xCA\x23\x90\x4A\x58\xEB\x83\x12\x6C\x40\xA9\xA9\x96\x82\xA8\xB0\xA5\x1F\x46\x83\x41\x08\xC3\x90\x52\x0F\x05\x21\xF4\xE8\x6D\x3E\xFA\xEA\x2B\xD1\x44\x06\x0A\x10\x20\x80\xE5\x02\x6C\x31\xC0\x1A\x70\x29\xFF\xF0\xA2\x5C\xB6\xA8\x2C\x82\x8F\xB4\x7B\x70\x25\xD4\x78\x68\xAA\xBB\xA6\x4C\x1A\x51\x3D\xB6\x1A\x30\x4E\xC8\x23\xE7\x63\x40\xC9\x02\x02\x68\xD2\x3F\x17\xA1\x64\x4E\x06\x50\x30\x32\x50\x1B\xEA\x2A\xA3\xE0\x23\x18\x48\x82\x50\x42\x1F\xC1\x34\x09\x06\x03\x0E\x40\x40\x38\x93\x4A\x20\x81\xB4\x10\x90\x2C\xAC\x80\x37\xE1\x2C\x60\xC9\x14\x0F\x88\xD2\xCE\xCB\xFA\xD0\xA6\x4A\x8C\x98\x49\xC3\x32\x2D\xB9\x6C\xCB\xA4\x08\x55\x02\x13\x43\x93\x7A\x80\xA1\x90\x18\x3C\x7A\x01\x24\x90\xD4\x2C\x71\xC4\x38\x29\x9D\xF3\x00\x01\xAC\xBA\x53\x53\xAC\xAC\xC0\x05\xA3\x3D\x41\xE1\xC3\xB2\x07\x46\x6B\x6B\x31\x1B\x7E\x20\x34\x25\x93\x4A\xFA\xE1\x85\x83\x7C\x88\x60\xC1\x47\x49\x78\xA0\x3E\x37\x29\x8D\x73\x4E\xC9\xFA\xDB\xD4\x57\x88\x6A\xF0\x23\x9A\x6D\x92\xF9\x54\x17\x3F\x2B\x7B\xE0\x05\xD2\x46\x58\xCC\x59\xC6\x50\x52\xAC\xC1\x12\x7A\x08\xA1\x3A\x84\x28\x50\x96\xD6\x5A\x1B\x30\x40\xB2\x03\x74\x55\x12\xC5\x37\x0F\x28\xB7\xCE\x5F\xD1\x65\x68\x0A\x66\xA2\x21\x86\x98\x61\xB5\x21\x05\x8F\xCA\x26\x58\xB6\x81\x66\x17\x03\x09\x5A\x15\xA4\x15\xFF\x34\x84\x07\x14\x22\x82\x00\x11\x44\x50\x0C\x86\x17\x22\xA0\x2A\x57\x71\xC7\x95\x2C\x00\x01\x0A\x08\x21\xDD\x89\x13\xF2\xE3\x99\x62\xDE\xDD\x26\x9A\x60\xFA\x10\x55\x2B\x0A\xEC\x0D\x61\x31\x43\x19\x5B\x6C\xCD\xE0\xCE\x3D\x48\x8F\x19\x94\x88\x02\x8B\x10\x1C\x78\xE0\x01\x0A\x64\xED\x76\xE1\x86\x9B\x0C\xE0\x83\x14\x5A\xA0\xD8\xE7\x1A\x50\xD9\xA6\x98\x68\x88\x26\x06\x97\x1A\xB5\x8A\xE1\x05\x12\xEA\x53\xCC\xD0\x44\x19\xFB\x00\xB0\x7F\x0B\x88\xE1\xA0\x1A\x4E\x68\x42\x8A\x27\x3A\x70\xC1\x20\x46\x0F\x90\x59\x66\x70\x73\x7D\x33\xE7\x0B\xB0\xE0\xD9\x67\x8A\x3B\x25\xBA\xE8\x64\x60\x41\x1A\xAB\x18\x6E\xAC\x8F\x04\x18\x9A\x1A\x62\x88\xB4\x16\x13\xE9\xB7\x10\x1A\x40\xE0\x01\x3C\x6A\x30\x21\x89\x28\xA2\x48\x02\x03\x19\x16\x72\xA0\x5C\x07\x1C\x2F\xB7\xEC\x00\x2E\x60\x43\x8C\x0E\x74\x58\x3B\x5D\x17\xB6\xC0\x05\x9A\x76\xDD\x25\xA6\x94\x2B\xB4\x7A\xA0\x07\xBB\x9B\x0A\x42\xEF\xBD\x43\x22\x01\xB8\xE0\xBA\x4D\x01\xF1\x28\x96\xD8\x80\x05\x88\x1C\x17\xE0\x00\xC7\xCB\x36\x40\x8B\x31\xB4\x98\x41\xF3\x74\x59\x10\x63\x16\x61\x84\x09\xFF\x5D\x18\x54\xD8\x28\x04\x2B\x65\x6D\x0D\x81\xA9\x20\x56\x53\x3D\xA4\x12\xEE\xBB\xCF\x00\x25\xC4\x68\xE2\x84\x0C\x18\xBF\x0A\xF2\x03\x9A\x64\x12\x4E\xDF\xC1\xA8\x03\x0B\xE1\x87\xFF\xB5\x05\x32\x64\xF9\x25\x79\x62\x84\x79\x06\x97\x3E\xE6\xE5\xA8\x82\xBA\x1B\x78\x6A\x08\x3D\xA4\xC2\x3A\x18\x10\x67\x38\x80\xCB\x00\x0D\x44\x10\xBE\xAC\x50\x40\x00\x2A\x62\x52\xCE\x7C\x37\x06\x30\x8C\x41\x09\x99\x6B\x9F\xAF\x5A\xA0\x85\x50\xD4\x22\x18\xF4\x43\x1E\x33\x40\x91\x07\xE7\x45\xE4\x2C\x76\xEB\xC1\xFF\xDE\x71\x08\xBD\x25\x8A\x80\x05\x34\xC0\x04\x2E\x53\x81\xF2\xE5\x2C\x00\x06\x90\x02\x18\x70\x28\x05\x0F\x5C\xD0\x7D\x55\x00\x45\x2A\x7C\x81\xBC\x60\x08\x23\x18\xB8\xF0\x03\x1E\x3C\xE6\x10\x0A\x4C\x20\x7A\x27\x0C\xC2\x3B\xDE\xA1\x07\x9A\xB4\xAE\x85\x0F\xF0\x01\x66\x16\x00\x00\x1A\xD6\x30\x0A\x38\x9C\x60\x0A\x78\xF8\x2B\x16\xE4\xE0\x0E\xA1\x58\x45\x2E\x82\x11\x0C\x60\x00\xE3\x17\xB3\xF0\xC3\x16\xF4\x50\x88\x43\x30\x84\x08\x07\x88\x00\x03\xFA\xA7\xB7\x43\xD0\xE3\x10\xD6\xEB\x41\x0B\x87\x13\x01\xCC\xC4\x40\x8B\x34\x1C\x40\x13\xFF\xBC\x38\x86\x29\x3C\x29\x8C\x9B\x42\x81\x16\x26\x61\x89\x54\xD4\x22\x17\xBF\xF0\x85\x2F\x72\x31\x8B\x52\xF8\x81\x0D\x69\x48\x43\x11\xF0\x50\x04\x1C\xE0\x20\x07\x34\x40\x01\xE0\x1A\x40\x82\x1F\xA0\x30\x8A\x2B\xFC\xE3\x0B\x96\x36\x9C\x07\x30\xB2\x32\x85\xCC\x19\x00\x52\x20\xC1\x31\x00\xCF\x06\x8D\x74\x1F\xF7\xEC\x00\x89\x4A\xA4\x82\x15\xB5\xB0\x45\x2D\x6A\x31\x0B\x59\x84\x62\x12\x75\xD8\xA5\x18\x76\x59\x06\x31\x9C\xB2\x3E\x78\x1B\x82\x21\xF8\xA8\xBA\x21\x84\x04\x96\xB0\x24\x41\x04\x32\x65\x99\xDE\xD8\x12\x00\x1D\xD0\xE5\x18\xA6\xE9\x4B\x74\x65\x20\x05\x5A\xA8\xC3\x24\x26\x11\x09\x4B\xCC\x73\x9E\x91\x88\xC4\x23\xF0\x69\x87\x30\xE0\x70\x0C\x51\x10\xC1\x03\x0C\x10\x82\x1F\x54\x48\x1D\xF1\x18\xCF\x36\x4B\xD0\xCD\xE1\xBC\x00\x60\x97\x61\x01\x0A\x2E\x50\x48\x00\x68\x00\x9A\x63\xF8\x42\x14\x50\xA0\x4E\xE2\x69\x20\x05\x58\x88\x83\x1D\xEC\x80\x4F\x91\x8A\xD4\x0E\x60\xF0\xC2\x18\xE4\xC0\x06\x11\xFC\xCB\x00\xAA\xFC\x9F\x3A\xB0\x31\x88\x15\x2A\x94\x04\x2F\xA0\x00\x66\x88\xB0\x02\x2A\x10\xE0\x6C\x5A\x10\x83\x14\xE0\x90\xFF\x02\x0D\x68\x94\x62\x13\x08\x01\x0A\x98\xD0\x04\x2C\x64\xC1\xA7\x62\x70\xAA\x16\x96\xC0\x01\x25\x28\x01\x05\x2C\x08\x1B\xE4\xD0\x32\x84\x41\x5C\x83\x10\x45\xD8\xE6\x1F\x89\x03\xCB\x2B\x5E\x46\x04\x52\x50\xC2\x00\x9A\x64\x00\xA6\x2A\xE1\x0B\x1B\x40\x00\x51\x1B\xF9\x93\x0C\x2C\x64\x77\x31\x3B\xA1\x56\x07\xE1\x55\x48\x11\x27\x02\x3E\xB8\xE9\x65\x5C\xC0\xBD\xB3\x02\xE0\x90\x62\x50\x42\x13\x2E\x10\x4E\xB8\x2E\x96\x1F\x02\x80\xC0\xAC\x86\xA0\x4D\x90\xC4\x32\x02\x7D\xFD\xAB\x43\x97\x20\x86\x14\x10\x40\x03\x6C\x55\xC2\x05\xDE\xCA\x58\xD1\xF2\xC3\x01\x10\x70\x40\x5F\x7D\xB0\xBA\xC9\x76\xB3\xAF\x2F\x18\xEB\x65\x32\x10\x05\x36\xA4\x80\x0D\x4A\x48\x01\x06\x06\x30\x5A\xDD\x2E\x00\x72\x7D\x7D\x54\x0F\xBA\x19\x5C\xBF\x36\x07\x04\xA7\xCC\x80\x01\x08\xAB\x58\xDD\x2E\x56\x00\xBD\xF5\xC1\x73\x7D\x10\xDC\x6E\x0E\xB7\x39\x02\x00\xC0\x75\x13\xB0\x5C\xED\x42\xEE\xB4\xCF\x95\x2E\x2C\x29\x10\x03\x0A\xD0\x52\xBB\xE5\x6D\x8E\x04\x4A\x4B\x01\xF5\x82\x6C\xBD\xEB\x8D\x41\xCA\xCC\x1B\x5F\xCC\x48\xE0\x00\x10\x58\xAF\x4D\xDB\xAB\x5E\xC7\xFF\xC9\x97\xBF\x31\xAC\x6F\x7E\x01\xFC\x80\xDB\xF5\x97\xC0\x0B\xFC\x2F\x80\xD7\x9B\x1F\xF2\x16\x98\xC1\x0D\x91\x40\x00\xEC\x8B\xE0\x6C\x85\x40\x04\x94\x69\xF0\x85\x1B\xA2\x22\x08\x44\x38\xC0\x54\xD8\x08\x86\x41\xAC\x90\x87\x71\x38\xBF\x12\xB8\x81\x1F\xA6\x70\xAD\x10\x87\xB8\x02\x00\x38\x2D\x82\x21\x10\x82\x3E\x80\xA2\x0A\x2B\xB6\xB1\x75\xD3\x1B\xE0\x29\x88\x82\xC6\x36\x0E\x31\x11\xE0\x44\x62\xF5\x4A\x40\x03\x77\x10\x05\x25\xA8\xE0\x63\x10\x23\x80\x06\x04\x38\x70\x7B\x1D\x80\x05\x51\x88\x82\x0E\x39\x50\xF2\x85\x27\x50\x05\xBF\x14\x80\xC4\x1B\xD6\xC0\x0F\x43\x91\xE4\x2B\x37\x38\x05\xA0\xB8\x43\x0A\x0C\x90\xDE\x0D\x2F\xA0\x00\x52\x4E\xC5\x1C\xC6\xDC\x60\x16\xD0\x21\x15\xA1\xC0\x02\x02\x9A\x9B\x9C\x26\x7D\x39\x15\xA0\x48\x50\x9C\x0B\x4C\x83\x1F\x96\xE2\x0E\x83\x0D\x00\x93\x06\x90\x85\x50\x84\x82\x0D\x80\x2E\x30\x0B\xC8\x10\x8A\x54\xD4\x99\x0E\x68\xCE\x59\x06\xFC\x20\x8A\x3B\x38\xBA\xC0\x1A\xA0\x83\xA4\x27\x1D\x8A\x4A\x0F\x60\x00\x53\x20\x03\x25\xE6\xA0\x40\x4E\xCB\xB7\x03\x7E\x90\xB4\x2A\x16\xCD\x93\x29\x50\x42\x37\x0E\x53\xD0\x40\x76\x57\xDD\xDF\x19\x68\x01\x14\x91\x08\x45\x19\xEE\x00\x8A\x2C\xC8\x41\x09\x06\x18\x00\xAE\x73\xCD\x5F\x0F\xD0\xA0\x9D\x70\x50\x42\xDA\x8A\x02\x00\x16\x25\x9B\xC0\xE0\xFA\x09\xA9\x01\x80\xEC\xFE\x06\x04\x00\x3B")
        if meru then
            client.set_event_callback("paint_ui", function()
                if not ui.is_menu_open() then return end
                local mx, my = ui.menu_position()
                local mw, mh = ui.menu_size()
                if not mx or not mw then return end
                local w = math.floor(MERU_W * MERU_SCALE + 0.5)
                local h = math.floor(MERU_H * MERU_SCALE + 0.5)
                local x, y = mx - w, my
                local t = globals.realtime() - start_time
                if MERU_FLIP then
                    meru:draw(t, x + w, y, -w, h)
                else
                    meru:draw(t, x, y, w, h)
                end
            end)
        end
    end
end


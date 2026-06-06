----------------------------------------------------------------------
-- CUSTOM FAKELAG (standalone)
--   Вынесено из SUPER DT.lua. Драйвит встроенный AA > Fake lag > Limit.
--   Встроенный fakelag должен быть включён (скрипт сам форсит Enabled).
----------------------------------------------------------------------

----------------------------------------------------------------------
-- 0. REFERENCES (safe loader)
----------------------------------------------------------------------
local missing = {}
local function ref(tab, cont, name)
    local ok, a, b = pcall(ui.reference, tab, cont, name)
    if not ok then
        table.insert(missing, string.format("%s > %s > %s", tab, cont, name))
        local stub = ui.new_checkbox("LUA", "A", "stub_"..#missing)
        ui.set_visible(stub, false)
        return stub, stub
    end
    return a, b
end

-- встроенный fakelag
local fl_enabled = ref("AA", "Fake lag", "Enabled")
local fl_limit   = ref("AA", "Fake lag", "Limit")

-- опционально: учитываем Double Tap, если он есть в меню
local dt_enabled, dt_hotkey = ref("RAGE", "Aimbot", "Double tap")

if #missing > 0 then
    client.color_log(255, 80, 80, "[CustomFakelag] не найдено в меню (поправь имена):")
    for _, m in ipairs(missing) do
        client.color_log(255, 160, 160, "  \xE2\x80\xA2 "..m)
    end
end

----------------------------------------------------------------------
-- 1. CUSTOM UI
----------------------------------------------------------------------
local T, C = "LUA", "A"

local cfl_enable    = ui.new_checkbox(T, C, "\xE2\x98\x85 Custom fakelag (override built-in)")
local cfl_mode      = ui.new_combobox(T, C, "  Mode",
    "Static", "Random", "Adaptive (DT-aware)", "Sine wave", "Velocity-based", "Peek-jitter")
local cfl_peek_key  = ui.new_hotkey  (T, C, "  Peek key (for Adaptive/Peek-jitter)", true)
local cfl_min       = ui.new_slider  (T, C, "  Min choke", 1, 14, 6)
local cfl_max       = ui.new_slider  (T, C, "  Max choke", 1, 14, 14)
local cfl_send_shot = ui.new_checkbox(T, C, "  Force send on shot")
local cfl_send_land = ui.new_checkbox(T, C, "  Force send on land")
local cfl_send_jump = ui.new_checkbox(T, C, "  Force send on jump")
local cfl_break_air = ui.new_checkbox(T, C, "  No fakelag in air")
local cfl_sine_spd  = ui.new_slider  (T, C, "  Sine speed", 1, 20, 6, true, nil, 0.1)

-- HUD
local cfl_hud       = ui.new_checkbox(T, C, "  Show fakelag HUD")
local cfl_hud_x     = ui.new_slider  (T, C, "  HUD X", 0, 3000, 300)
local cfl_hud_y     = ui.new_slider  (T, C, "  HUD Y", 0, 2000, 540)

-- зависимости — прячем ненужные слайдеры/чекбоксы при смене режима
local function refresh_visibility()
    local on   = ui.get(cfl_enable)
    local mode = ui.get(cfl_mode)
    for _, e in ipairs({
        cfl_mode, cfl_peek_key, cfl_min, cfl_max,
        cfl_send_shot, cfl_send_land, cfl_send_jump,
        cfl_break_air, cfl_sine_spd, cfl_hud, cfl_hud_x, cfl_hud_y,
    }) do
        ui.set_visible(e, on)
    end
    if on then
        ui.set_visible(cfl_sine_spd, mode == "Sine wave")
        ui.set_visible(cfl_hud_x,    ui.get(cfl_hud))
        ui.set_visible(cfl_hud_y,    ui.get(cfl_hud))
    end
end
ui.set_callback(cfl_enable, refresh_visibility)
ui.set_callback(cfl_mode,   refresh_visibility)
ui.set_callback(cfl_hud,    refresh_visibility)
refresh_visibility()

----------------------------------------------------------------------
-- 2. HELPERS
----------------------------------------------------------------------
local function tick() return globals.tickcount() end
local function lp()   return entity.get_local_player() end

local function velocity()
    local me = lp(); if not me then return 0 end
    local vx = entity.get_prop(me, "m_vecVelocity[0]") or 0
    local vy = entity.get_prop(me, "m_vecVelocity[1]") or 0
    return math.sqrt(vx*vx + vy*vy)
end

local function dt_on()
    return ui.get(dt_enabled) and ui.get(dt_hotkey)
end

-- грубый трекер "заряда" DT: 14 тиков net_update_end при активном DT
local TICKS_NEED    = 14
local charged_ticks = 0
client.set_event_callback("net_update_end", function()
    if dt_on() then
        charged_ticks = math.min(charged_ticks + 1, TICKS_NEED)
    else
        charged_ticks = 0
    end
end)
local function dt_charged() return charged_ticks >= TICKS_NEED end

----------------------------------------------------------------------
-- 3. EVENT TIMINGS (shot / jump / land)
----------------------------------------------------------------------
local last_shot_tick = -999
local last_jump_tick = -999
local last_land_tick = -999
local was_on_ground  = true

client.set_event_callback("aim_fire", function()
    last_shot_tick = tick()
    charged_ticks  = 0
end)

----------------------------------------------------------------------
-- 4. ENGINE
----------------------------------------------------------------------
client.set_event_callback("setup_command", function(cmd)
    if not ui.get(cfl_enable) then return end
    local me = lp(); if not me or not entity.is_alive(me) then return end

    local flags     = entity.get_prop(me, "m_fFlags") or 0
    local on_ground = bit.band(flags, 1) ~= 0
    local vel       = velocity()

    if on_ground and not was_on_ground then last_land_tick = tick() end
    if (not on_ground) and was_on_ground then last_jump_tick = tick() end
    was_on_ground = on_ground

    -- встроенный fakelag обязательно должен быть включён
    if not ui.get(fl_enabled) then ui.set(fl_enabled, true) end

    local mode  = ui.get(cfl_mode)
    local min_c = ui.get(cfl_min)
    local max_c = ui.get(cfl_max)
    if min_c > max_c then min_c, max_c = max_c, min_c end

    local target
    if mode == "Static" then
        target = max_c

    elseif mode == "Random" then
        target = client.random_int(min_c, max_c)

    elseif mode == "Adaptive (DT-aware)" then
        if dt_on() and not dt_charged() then
            target = max_c
        elseif dt_charged() and ui.get(cfl_peek_key) then
            target = min_c
        else
            target = math.floor((min_c + max_c) / 2)
        end

    elseif mode == "Sine wave" then
        local speed = ui.get(cfl_sine_spd)
        local s = (math.sin(globals.realtime() * speed) + 1) * 0.5
        target = math.floor(min_c + s * (max_c - min_c) + 0.5)

    elseif mode == "Velocity-based" then
        local k = math.max(0, math.min(1, 1 - vel / 250))
        target = math.floor(min_c + k * (max_c - min_c) + 0.5)

    elseif mode == "Peek-jitter" then
        if ui.get(cfl_peek_key) then
            target = client.random_int(min_c, max_c)
        else
            target = max_c
        end
    else
        target = max_c
    end

    -- override'ы для пробрасывания пакета
    if ui.get(cfl_break_air) and not on_ground then target = 1 end
    if ui.get(cfl_send_shot) and tick() - last_shot_tick <= 1 then target = 1 end
    if ui.get(cfl_send_land) and tick() - last_land_tick <= 1 then target = 1 end
    if ui.get(cfl_send_jump) and tick() - last_jump_tick <= 1 then target = 1 end

    -- безопасный клэмп под лимит движка
    if target < 1  then target = 1  end
    if target > 14 then target = 14 end

    ui.set(fl_limit, target)
end)

----------------------------------------------------------------------
-- 5. HUD
----------------------------------------------------------------------
client.set_event_callback("paint", function()
    if not ui.get(cfl_enable) or not ui.get(cfl_hud) then return end
    local x, y = ui.get(cfl_hud_x), ui.get(cfl_hud_y)
    local cur  = ui.get(fl_limit)
    local pct  = math.min(1, cur / 14)

    renderer.rectangle(x,     y,     160, 14,  0,   0,   0,   160)
    renderer.rectangle(x + 1, y + 1, math.floor(158 * pct), 12, 255, 180, 0, 220)
    renderer.text(x + 4, y - 1, 255, 255, 255, 255, "-", 0,
        string.format("FL: %d/14  [%s]", cur, ui.get(cfl_mode)))
end)

----------------------------------------------------------------------
-- 6. CLEANUP
----------------------------------------------------------------------
client.set_event_callback("shutdown", function()
    -- ничего не выключаем принудительно — пусть юзер сам решит
end)

client.color_log(120, 220, 255, "[CustomFakelag] standalone loaded.")

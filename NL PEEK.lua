-- =====================================================================
--  QPAVisualizer v3 — диск возврата для скитовского Quick Peek Assist
--  Tab: LUA → "QPA Visual"
--  
--  Изменения v3:
--  — ring-buffer origin’ов последних 16 тиков
--  — на rising edge берём origin НЕ текущий, а из прошлого (N тиков назад)
--  — слайдер "Snapshot lookback (ticks)" 0–8 для точной подгонки под твой ping/choke
-- =====================================================================

local T, C = "LUA", "A"

local enable      = ui.new_checkbox     (T, C, "★ QPA return-spot visual")
local color       = ui.new_color_picker (T, C, "  Color", 130, 110, 220, 200)
local radius      = ui.new_slider       (T, C, "  Radius",  8, 40, 18)
local fill_alpha  = ui.new_slider       (T, C, "  Fill alpha", 0, 255, 90)
local outline_a   = ui.new_slider       (T, C, "  Outline alpha", 0, 255, 230)
local segments_ui = ui.new_slider       (T, C, "  Smoothness", 12, 64, 40)
local lookback    = ui.new_slider       (T, C, "  Snapshot lookback (ticks)", 0, 8, 2)

-- встроенный QPA
local qpa_enable, qpa_hotkey = ui.reference("RAGE", "Other", "Quick peek assist")

-- ===== state =====
local saved_x, saved_y, saved_z = nil, nil, nil
local prev_held = false

-- ring-buffer последних origin’ов (индекс 1 = самый свежий)
local RING_SIZE = 16
local origin_ring   = {}
local origin_filled = 0

local function push_origin(x, y, z)
    -- сдвигаем назад
    for i = RING_SIZE, 2, -1 do
        origin_ring[ i ] = origin_ring[ i - 1 ]
    end
    origin_ring[ 1 ] = { x, y, z }
    if origin_filled < RING_SIZE then
        origin_filled = origin_filled + 1
    end
end

local function pick_origin(ticks_back)
    if origin_filled == 0 then return nil end
    local idx = math.min(ticks_back + 1, origin_filled)
    local o = origin_ring[ idx ]
    return o[1], o[2], o[3]
end

local function clear_state()
    saved_x, saved_y, saved_z = nil, nil, nil
    origin_ring   = {}
    origin_filled = 0
end

-- ===== SETUP_COMMAND — per-tick: лента origin’ов + регистрация рёбер хоткея
client.set_event_callback("setup_command", function()
    local lp = entity.get_local_player()
    if not lp or not entity.is_alive(lp) then
        clear_state()
        prev_held = false
        return
    end

    -- пишем текущий origin в буфер КАЖДЫЙ тик
    local x, y, z = entity.get_prop(lp, "m_vecOrigin")
    if x then
        push_origin(x, y, z)
    end

    local held = ui.get(qpa_enable) and ui.get(qpa_hotkey)

    -- rising edge — берём origin ИЗ ПРОШЛОГО на lookback тиков назад
    if held and not prev_held then
        local lb = ui.get(lookback)
        local sx, sy, sz = pick_origin(lb)
        if sx then
            saved_x, saved_y, saved_z = sx, sy, sz
        end
    end

    -- falling edge — очистка
    if not held and prev_held then
        saved_x, saved_y, saved_z = nil, nil, nil
    end

    prev_held = held
end)

-- ===== math: точки окружности в мире → экранные координаты =====
local function world_circle_points(x, y, z, r, n)
    local pts = {}
    for i = 0, n do
        local a  = (i / n) * math.pi * 2
        local wx = x + math.cos(a) * r
        local wy = y + math.sin(a) * r
        local sx, sy = renderer.world_to_screen(wx, wy, z)
        if not sx then return nil end
        pts[#pts + 1] = { sx, sy }
    end
    return pts
end

-- ===== ОТРИСОВКА =====
client.set_event_callback("paint", function()
    if not ui.get(enable) then return end
    if not saved_x      then return end

    local lp = entity.get_local_player()
    if not lp or not entity.is_alive(lp) then return end

    -- snap к полу
    local ground_z = saved_z
    local fraction = client.trace_line(lp,
        saved_x, saved_y, saved_z + 8,
        saved_x, saved_y, saved_z - 200)
    if fraction and fraction < 1 then
        ground_z = saved_z + 8 - 208 * fraction
    end

    local r, g, b, a = ui.get(color)
    local rad  = ui.get(radius)
    local segs = ui.get(segments_ui)
    local pts  = world_circle_points(saved_x, saved_y, ground_z, rad, segs)
    if not pts then return end

    local cx, cy = renderer.world_to_screen(saved_x, saved_y, ground_z)
    if not cx then return end

    local fa = math.floor(ui.get(fill_alpha) * (a / 255) + 0.5)
    if fa > 0 then
        for i = 1, #pts - 1 do
            local p1, p2 = pts[i], pts[i + 1]
            renderer.triangle(cx, cy, p1[1], p1[2], p2[1], p2[2], r, g, b, fa)
        end
    end

    local oa = math.floor(ui.get(outline_a) * (a / 255) + 0.5)
    if oa > 0 then
        for i = 1, #pts - 1 do
            local p1, p2 = pts[i], pts[i + 1]
            renderer.line(p1[1], p1[2], p2[1], p2[2], r, g, b, oa)
        end
    end
end)

-- ===== visibility =====
local function refresh()
    local on = ui.get(enable)
    ui.set_visible(color,       on)
    ui.set_visible(radius,      on)
    ui.set_visible(fill_alpha,  on)
    ui.set_visible(outline_a,   on)
    ui.set_visible(segments_ui, on)
    ui.set_visible(lookback,    on)
end
ui.set_callback(enable, refresh)
refresh()

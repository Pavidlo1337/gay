-- =====================================================================
-- GAMESENSE INDICATOR  v3.1  (verbatim Athlea port)
-- =====================================================================
-- Структура paint-цикла, motion.interp, get_color/get_text/draw_shadow
-- скопированы 1:1 из Athlea (lines 5282-5326, 13548-13670).
-- Никаких "улучшений" — поведение идентично оригиналу.
-- =====================================================================
client.color_log(150, 200, 25, "[INDICATOR] ")
client.color_log(220, 220, 220, "v5.8 offsets only in follow mode\0")

-- ============= anti-duplicate callback guard =========================
-- gamesense НЕ снимает старые set_event_callback при reload скрипта.
-- Без этого guard'а каждый reload = +1 paint-стек = +1 PING на экране.
local GKEY = "__INDICATOR_v3_callbacks__"
if type(_G[GKEY]) == "table" then
    for ev, fn in pairs(_G[GKEY]) do
        pcall(client.unset_event_callback, ev, fn)
    end
end
_G[GKEY] = {}
local function bind(ev, fn)
    _G[GKEY][ev] = fn
    client.set_event_callback(ev, fn)
end

-- ============= motion.interp (Athlea 5317-5325) ======================
local function linear(t, b, c, d) return c * t / d + b end
local function get_deltatime() return globals.frametime() end
local function solve(easing_fn, prev, new, clock, duration)
    if clock <= 0 then return new end
    if clock >= duration then return new end
    prev = easing_fn(clock, prev, new - prev, duration)
    if type(prev) == "number" then
        if math.abs(new - prev) < 0.001 then return new end
        local rem = prev % 1.0
        if rem < 0.001 then return math.floor(prev) end
        if rem > 0.999 then return math.ceil(prev) end
    end
    return prev
end
local function interp(a, b, t)
    if type(b) == "boolean" then b = b and 1 or 0 end
    return solve(linear, a, b, get_deltatime(), t)
 end

-- ============= UI ====================================================
-- Перенесён с AA на LUA вкладку (v5.0)
local LUA, TAB = "LUA", "A"
local enabled = ui.new_checkbox(LUA, TAB, "Gamesense indicator")
local follow  = ui.new_checkbox(LUA, TAB, "Follow in thirdperson")
-- Смещения индикаторов. Работают всегда (в любом режиме):
--   • в follow-thirdperson: смещение от хитбокса игрока
--   • в обычном режиме: смещение от левого нижнего угла (5, sh*0.759)
-- X/Y offset РАБОТАЮТ ТОЛЬКО в follow-thirdperson режиме.
-- Без follow и от 1-го лица — позиция статичная (5, sh*0.759).
local offset_x = ui.new_slider(LUA, TAB, "Follow X offset", -1000, 1000, 0, 1, "%d px")
local offset_y = ui.new_slider(LUA, TAB, "Follow Y offset", -1000, 1000, 0, 1, "%d px")
-- Сила сглаживания в follow-thirdperson режиме (в мс).
-- Чем больше — тем плавнее бинды догоняют игрока (и меньше прыгают на джитерах).
local smooth_ms = ui.new_slider(LUA, TAB, "Follow smoothing", 50, 500, 200, 10, "%d ms")

-- ref shortcuts
-- safe_ref: pcall-обёртка над ui.reference, возвращает до 3 значений или nil-ы.
-- Если контрол не найден в сборке — логим и продолжаем, индикатор просто отключится.
local function safe_ref(tab, sub, name)
    local ok, a, b, c = pcall(ui.reference, tab, sub, name)
    if not ok then
        client.color_log(255, 120, 120, string.format("[INDICATOR] ui.reference \"%s\" > \"%s\" > \"%s\" not found, skipping\0", tab, sub, name))
        return nil, nil, nil
    end
    return a, b, c
end

local ref_tp_cb,    ref_tp_key    = safe_ref("VISUALS", "Effects", "Force third person (alive)")
local ref_fsp_cb,   ref_fsp_key   = safe_ref("AA", "Anti-aimbot angles", "Freestanding")
-- Force body yaw — это чекбокс+хоткей ("AA" > "Anti-aimbot angles" > "Force body yaw").
-- В старых сборках мог называться по-другому, поэтому фоллбек на combobox "Body yaw".
local ref_body_cb,  ref_body_key  = safe_ref("AA", "Anti-aimbot angles", "Force body yaw")
local ref_body_mode = nil
if ref_body_cb == nil then
    ref_body_cb, ref_body_mode = safe_ref("AA", "Anti-aimbot angles", "Body yaw")
end
local ref_ping_cb,  ref_ping_key  = safe_ref("MISC", "Miscellaneous", "Ping spike")
local ref_dt_cb,    ref_dt_key    = safe_ref("RAGE", "Aimbot", "Double tap")
-- OSAA: в разных сборках называется по-разному, пробуем все варианты
local ref_osaa_cb,  ref_osaa_mode = safe_ref("AA", "Anti-aimbot angles", "On shot anti-aim")
if ref_osaa_cb == nil then ref_osaa_cb, ref_osaa_mode = safe_ref("AA", "Other", "On shot anti-aim") end
if ref_osaa_cb == nil then ref_osaa_cb, ref_osaa_mode = safe_ref("RAGE", "Other", "On shot anti-aim") end
local ref_duck_cb,  ref_duck_key  = safe_ref("RAGE", "Other", "Duck peek assist")
local ref_fs_cb,    ref_fs_key    = safe_ref("AA", "Other", "Slow motion")
local ref_min_dmg               = safe_ref("RAGE", "Aimbot", "Minimum damage")
local ref_md_ov_cb, ref_md_ov_key = safe_ref("RAGE", "Aimbot", "Minimum damage override")
if ref_md_ov_cb == nil then ref_md_ov_cb, ref_md_ov_key = safe_ref("RAGE", "Other", "Minimum damage override") end
local ref_qp_cb,    ref_qp_key    = safe_ref("RAGE", "Other", "Quick peek assist")

-- PARAMETERS (Athlea 13385-13428 shape)
local PARAMETERS = {
    ["Lua"] = {
        is_active = function() return true end,
        get_text  = function() return "LUA" end,
        get_color = function() return 150, 200, 25, 255 end,
    },
    ["Freestanding"] = {
        is_active = function()
            if not ref_fsp_cb then return false end
            return ui.get(ref_fsp_cb) and (ref_fsp_key == nil or ui.get(ref_fsp_key))
        end,
        get_text  = function() return "FS" end,
        get_color = function() return 255, 255, 255, 255 end,
    },
    ["Body Yaw"] = {
        is_active = function()
            if not ref_body_cb then return false end
            -- новая ветка: чекбокс "Force body yaw" + хоткей под ним
            if ref_body_key ~= nil then
                return ui.get(ref_body_cb) and ui.get(ref_body_key)
            end
            -- фоллбек: старый combobox "Body yaw" (Off/Opposite/Jitter/...)
            local node = ref_body_mode or ref_body_cb
            local v = ui.get(node)
            if type(v) == "boolean" then return v end
            return v ~= nil and v ~= "Off"
        end,
        get_text  = function() return "FORCE BODY" end,
        get_color = function() return 150, 200, 25, 255 end,
    },
    ["Ping Spike"] = {
        is_active = function()
            if not ref_ping_cb then return false end
            return ui.get(ref_ping_cb) and (ref_ping_key == nil or ui.get(ref_ping_key))
        end,
        get_text  = function() return "PING" end,
        get_color = function() return 150, 200, 25, 255 end,
    },
    ["Double Tap"] = {
        is_active = function()
            if not ref_dt_cb then return false end
            return ui.get(ref_dt_cb) and (ref_dt_key == nil or ui.get(ref_dt_key))
        end,
        get_text  = function() return "DT" end,
        get_color = function()
            local me = entity.get_local_player()
            if me and entity.is_alive(me) and ref_min_dmg then
                local exp = ui.get(ref_min_dmg) or 0
                if globals.tickcount() % 30 < 15 and exp >= 100 then
                    return 255, 60, 60, 255
                end
            end
            return 255, 255, 255, 255
        end,
    },
    ["OSAA"] = {
        is_active = function()
            if not ref_osaa_cb then return false end
            if not ui.get(ref_osaa_cb) then return false end
            if ref_osaa_mode == nil then return true end
            local v = ui.get(ref_osaa_mode)
            if type(v) == "boolean" then return v end
            return v ~= nil and v ~= "Off"
        end,
        get_text  = function() return "OSAA" end,
        get_color = function() return 255, 200, 60, 255 end,
    },
    ["Duck Peek"] = {
        is_active = function()
            if not ref_duck_cb then return false end
            return ui.get(ref_duck_cb) and (ref_duck_key == nil or ui.get(ref_duck_key))
        end,
        get_text  = function() return "DUCK" end,
        get_color = function() return 180, 180, 255, 255 end,
    },
    ["Fakelag"] = {
        is_active = function()
            if not ref_fs_cb then return false end
            return ui.get(ref_fs_cb) and (ref_fs_key == nil or ui.get(ref_fs_key))
        end,
        get_text  = function() return "FL" end,
        get_color = function() return 255, 255, 255, 255 end,
    },
    ["Quick Peek"] = {
        is_active = function()
            if not ref_qp_cb then return false end
            return ui.get(ref_qp_cb) and (ref_qp_key == nil or ui.get(ref_qp_key))
        end,
        get_text  = function() return "QP" end,
        get_color = function() return 100, 200, 255, 255 end,
    },
    ["Min. Damage"] = {
        is_active = function()
            -- 1) хоткей override зажат — показываем
            if ref_md_ov_key and ui.get(ref_md_ov_key) then return true end
            -- 2) или выставлен не-дефолтный min damage во время игры
            if ref_min_dmg then
                local v = ui.get(ref_min_dmg)
                if type(v) == "number" and v > 0 then return true end
            end
            return false
        end,
        get_text  = function()
            local v = ref_min_dmg and ui.get(ref_min_dmg)
            if type(v) == "number" and v > 0 then
                return string.format("MD %d", v)
            end
            return "MIN DMG"
        end,
        get_color = function() return 255, 180, 60, 255 end,
    },
}

local names = {
    "Lua", "Freestanding", "Body Yaw", "Ping Spike", "Double Tap",
    "OSAA", "Duck Peek", "Fakelag", "Quick Peek", "Min. Damage",
}

-- единый multiselect со всеми индикаторами (стиль как на скрине Athlea)
local indicators_ms = ui.new_multiselect(LUA, TAB, "Indicators",
    "Lua", "Freestanding", "Body Yaw", "Ping Spike", "Double Tap",
    "OSAA", "Duck Peek", "Fakelag", "Quick Peek", "Min. Damage"
)

-- комбобокс "Configure" — выбираешь какой индикатор настраивать.
-- Под ним появится только его текст/цвет — без винегрета.
local config_combo = ui.new_combobox(LUA, TAB, "Configure",
    "Lua", "Freestanding", "Body Yaw", "Ping Spike", "Double Tap",
    "OSAA", "Duck Peek", "Fakelag", "Quick Peek", "Min. Damage"
)

-- per-item UI (стиль Athlea: custom_name / change_color / color_picker)
-- enabled-статус идёт из multiselect, видимость настроек — из config_combo
local items = {}
for _, name in ipairs(names) do
    items[name] = {
        custom_name  = ui.new_textbox(LUA, TAB, name .. " indicator"),
        change_color = ui.new_checkbox(LUA, TAB, name .. " change color"),
        color_picker = ui.new_color_picker(LUA, TAB, name .. " color", 255, 255, 255, 255),
    }
    ui.set(items[name].custom_name, "")
    ui.set(items[name].change_color, false)
end

-- по умолчанию выбраны: Lua и Ping Spike (как раньше)
pcall(ui.set, indicators_ms, "Lua", "Ping Spike")

-- хелпер: выбран ли этот индикатор в multiselect
local function is_selected(name)
    local selected = ui.get(indicators_ms)
    if type(selected) ~= "table" then return false end
    for i = 1, #selected do
        if selected[i] == name then return true end
    end
    return false
end

-- visibility refresh: показываем настройки ТОЛЬКО для индикатора,
-- выбранного в config_combo — это и есть "под каждой настройкой её властная".
local function refresh()
    local on = ui.get(enabled)
    ui.set_visible(follow, on)
    -- offset и smoothing видны только когда follow включён — в обычном режиме они не применяются
    local follow_ui = on and ui.get(follow)
    ui.set_visible(offset_x,  follow_ui)
    ui.set_visible(offset_y,  follow_ui)
    ui.set_visible(smooth_ms, follow_ui)
    ui.set_visible(indicators_ms, on)
    ui.set_visible(config_combo, on)
    local current = on and ui.get(config_combo) or nil
    for _, name in ipairs(names) do
        local it   = items[name]
        local show = (name == current)
        ui.set_visible(it.custom_name,  show)
        ui.set_visible(it.change_color, show)
        ui.set_visible(it.color_picker, show and ui.get(it.change_color))
    end
end
ui.set_callback(enabled,       refresh)
ui.set_callback(follow,        refresh)
ui.set_callback(indicators_ms, refresh)
ui.set_callback(config_combo,  refresh)
for _, name in ipairs(names) do
    ui.set_callback(items[name].change_color, refresh)
end
refresh()

-- ============= verbatim get_color / get_text / draw_shadow (Athlea 13548-13571)
local function get_color(params, it)
    if ui.get(it.change_color) then
        local r, g, b, a = ui.get(it.color_picker)
        return { r = r, g = g, b = b, a = a }
    end
    local r, g, b, a = params.get_color()
    return { r = r, g = g, b = b, a = a }
end

local function get_text(params, it)
    local value = ui.get(it.custom_name)
    if value == "" then value = params.get_text() end
    return value
end

local function draw_shadow(x, y, w, h)
    local half = math.floor(w / 2)
    renderer.gradient(x,        y, half,     h, 0,0,0,0,  0,0,0,55, true)
    renderer.gradient(x + half, y, w - half, h, 0,0,0,55, 0,0,0,0,  true)
end

-- ============= verbatim on_paint (Athlea 13573-13670) ================
local x_value, y_value = nil, nil
local data_values = {}

local function on_paint()
    if not ui.get(enabled) then return end

    local me = entity.get_local_player()
    if me == nil or not entity.is_alive(me) then return end

    local flags = "+d"
    local sw, sh = client.screen_size()
    local draw_x, draw_y = 5, sh * 0.759

    -- базовая позиция: если включён follow + force_thirdperson
    -- ИСПОЛЬЗУЕМ m_vecOrigin (ноги игрока) вместо hitbox — origin НЕ вращается с боди-явом,
    -- поэтому индикаторы НЕ прыгают при джитере / body yaw / fake yaw.
    local follow_on = false
    if ui.get(follow) and ref_tp_cb and ui.get(ref_tp_cb) and (ref_tp_key == nil or ui.get(ref_tp_key)) then
        local ox, oy, oz = entity.get_prop(me, "m_vecOrigin")
        if ox and oy and oz then
            -- поднимаем на ~уровень торса (60 units над ногами)
            local sx, sy = renderer.world_to_screen(ox, oy, oz + 60)
            if sx ~= nil and sy ~= nil then
                draw_x = sx - 250
                draw_y = sy
                follow_on = true
            end
        end
    end

    -- всегда применяем пользовательские X/Y оффсеты (в любом режиме)
    -- X/Y offset применяем ТОЛЬКО в follow-режиме.
    -- В обычном режиме позиция остаётся статичной (5, sh*0.759) — как было изнач��л��но.
    if follow_on then
        draw_x = draw_x + ui.get(offset_x)
        draw_y = draw_y + ui.get(offset_y)
    end

    if x_value == nil then x_value = draw_x end
    if y_value == nil then y_value = draw_y end

    -- в follow-режиме берём длительность из слайдера, в обычном — быстрый 0.05с
    local dur = follow_on and (ui.get(smooth_ms) / 1000.0) or 0.05
    x_value = interp(x_value, draw_x, dur)
    y_value = interp(y_value, draw_y, dur)

    local pos_x, pos_y = x_value, y_value

    for i = 1, #names do
        local name   = names[i]
        local it     = items[name]
        local params = PARAMETERS[name]

        if it ~= nil and params ~= nil then
            if data_values[name] == nil then
                data_values[name] = { alpha = 0.0 }
            end
            local data = data_values[name]

            local should_draw = is_selected(name) and params.is_active()
            data.alpha = interp(data.alpha, should_draw, 0.05)

            if data.alpha > 0.0 then
                local col  = get_color(params, it)
                local text = get_text(params, it)
                local tw, th = renderer.measure_text(flags, text)
                local text_x = pos_x + 24
                local text_y = pos_y + 2
                local fade_w = tw + 50
                local fade_h = th + 4

                if should_draw then
                    draw_shadow(pos_x, pos_y, fade_w, fade_h)
                    renderer.text(
                        text_x, text_y,
                        col.r, col.g, col.b,
                        math.floor(col.a * data.alpha),
                        flags, nil, text
                    )
                end

                pos_y = pos_y - (fade_h + 8) * data.alpha
            end
        end
    end
end

-- ============= hide native gamesense indicator stack =================
-- Гамсенс рисует встроенную стопку индикаторов (HC, PING, DT, FAKELAG и т.д.)
-- Чтобы они не дублировались с моими — скрываем нативный стек в стиле Athlea.
local native_saves = {}

-- список multiselect-refs которые нужно держать пустыми всегда
local multiselect_kill_refs = {}

local function force_clear_multiselect(ref)
    -- Метод 1: ui.set(ref) без аргументов
    pcall(function() ui.set(ref) end)
    local v = ui.get(ref)
    if type(v) == "table" and #v == 0 then return true end
    -- Метод 2: ui.set(ref, nil)
    pcall(ui.set, ref, nil)
    v = ui.get(ref)
    if type(v) == "table" and #v == 0 then return true end
    -- Метод 3: unpack пустой таблицы
    pcall(function() ui.set(ref, (table.unpack or unpack)({})) end)
    v = ui.get(ref)
    if type(v) == "table" and #v == 0 then return true end
    -- Метод 4: явный вызов с пустой строкой и фильтрацией
    pcall(ui.set, ref, "")
    v = ui.get(ref)
    return type(v) == "table" and #v == 0
end

local function try_disable_native(ref_args, log_name)
    local ok, ref = pcall(ui.reference, table.unpack and table.unpack(ref_args) or unpack(ref_args))
    if not ok or ref == nil then return end
    local got_ok, value = pcall(ui.get, ref)
    if not got_ok then return end
    native_saves[#native_saves + 1] = { ref = ref, value = value, name = log_name }

    if type(value) == "table" then
        -- multiselect: пробуем все методы очистки
        force_clear_multiselect(ref)
        -- регистрируем для постоянной очис��ки в paint loop
        multiselect_kill_refs[#multiselect_kill_refs + 1] = ref
        -- перехватываем любые изменения: если выбрали — сразу снимаем
        pcall(ui.set_callback, ref, function() pcall(force_clear_multiselect, ref) end)
        -- скрываем UI элемент в меню (чтобы случайно не включить)
        pcall(ui.set_visible, ref, false)
    elseif type(value) == "boolean" then
        pcall(ui.set, ref, false)
        pcall(ui.set_visible, ref, false)
    elseif type(value) == "string" then
        pcall(ui.set, ref, "Off")
    end

    -- финальный лог
    local final_ok, final_val = pcall(ui.get, ref)
    if final_ok then
        if type(final_val) == "table" then
            client.color_log(150, 200, 25, string.format(
                "[INDICATOR] '%s' cleared (now %d items, hidden)\0", log_name, #final_val))
        else
            client.color_log(150, 200, 25, string.format(
                "[INDICATOR] '%s' = %s\0", log_name, tostring(final_val)))
        end
    end
end

local function restore_native()
    for i = 1, #native_saves do
        local s = native_saves[i]
        if type(s.value) == "table" then
            pcall(ui.set, s.ref, table.unpack and table.unpack(s.value) or unpack(s.value))
        else
            pcall(ui.set, s.ref, s.value)
        end
    end
    native_saves = {}
end

-- Пробуем несколько известных путей к нативному стеку индикаторов
-- ★ Основной путь: VISUALS → Other ESP → Feature Indicators (multiselect с PING/HC/DT/FAKELAG)
try_disable_native({"VISUALS", "Other ESP", "Feature Indicators"},      "VISUALS>OtherESP>Feature Indicators")
try_disable_native({"VISUALS", "Other ESP", "Feature indicators"},      "VISUALS>OtherESP>Feature indicators")
try_disable_native({"VISUALS", "Other ESP", "feature indicators"},      "VISUALS>OtherESP>feature indicators")
-- фолбэки на случай других сборок
try_disable_native({"AA", "Anti-aimbot angles", "Indicators"},          "AA Indicators")
try_disable_native({"MISC", "Settings", "Indicators"},                  "MISC Indicators")
try_disable_native({"VISUALS", "Effects", "Indicators"},                "VISUALS Indicators")
try_disable_native({"AA", "Anti-aimbot angles", "Builder indicators"},  "AA Builder indicators")

-- ============= diagnostic log =======================================
client.color_log(150, 200, 25, "[INDICATOR] selected indicators:\0")
local selected_dump = ui.get(indicators_ms)
if type(selected_dump) == "table" then
    for _, name in ipairs(selected_dump) do
        local it = items[name]
        if it then
            local cn = ui.get(it.custom_name) or ""
            local rendered = (cn ~= "" and cn) or (PARAMETERS[name] and PARAMETERS[name].get_text()) or name
            client.color_log(220, 220, 220, string.format("  [%s] -> text='%s'\0", name, rendered))
        end
    end
end

-- ============= bind & shutdown =======================================
-- вспомогательный гвард: каждый кадр держим мультиселекты пустыми
local function on_paint_guard()
    for i = 1, #multiselect_kill_refs do
        local r = multiselect_kill_refs[i]
        local ok, v = pcall(ui.get, r)
        if ok and type(v) == "table" and #v > 0 then
            pcall(force_clear_multiselect, r)
        end
    end
end
bind("paint", on_paint_guard)

bind("paint", on_paint)
bind("shutdown", function()
    restore_native()
    _G[GKEY] = nil
    x_value, y_value = nil, nil
    data_values = {}
end)

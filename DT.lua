-- =====================================================================
--  AntiBacktrackDT v2
--    После DT-шота давим макс чоку — бектрек-записи противника устаревают.
--    Tab: LUA → A → "Anti-backtrack DT"
--
--    Ключевые отличия от v1:
--      • Детект именно DT-шота (счётчик charged_ticks).
--      • Не сохраняем/не восстанавливаем — просто перестаём форсить.
--      • Слайдеры: длина спайка и величина чоки.
--      • Глобальный флаг ab_dt_spike_active — другие фейклаг-скрипты
--        (напр. CUSTOM_FAKELAG.lua) должны уважать этот флаг.
--      • HUD с отсчётом тиков.
--      • Очистка: shutdown, round_start, player_spawn, player_death.
-- =====================================================================

----------------------------------------------------------------------
-- 0. UI
----------------------------------------------------------------------
local T, C = "LUA", "A"

local enable      = ui.new_checkbox(T, C, "Anti-backtrack DT")
local trigger     = ui.new_combobox (T, C, "  Trigger",
    "Only when DT was charged", "Any rage shot while DT held")
local spike_ticks = ui.new_slider   (T, C, "  Spike length (ticks)", 1, 32, 14)
local spike_choke = ui.new_slider   (T, C, "  Spike choke",          1, 14, 14)
local hud_show    = ui.new_checkbox (T, C, "  Show HUD")
local hud_x       = ui.new_slider   (T, C, "  HUD X", 0, 3000, 300)
local hud_y       = ui.new_slider   (T, C, "  HUD Y", 0, 2000, 580)

----------------------------------------------------------------------
-- 1. REFERENCES
----------------------------------------------------------------------
local dt_enabled, dt_hotkey = ui.reference("RAGE", "Aimbot", "Double tap")
local fl_enabled            = ui.reference("AA",   "Fake lag", "Enabled")
local fl_limit              = ui.reference("AA",   "Fake lag", "Limit")

----------------------------------------------------------------------
-- 2. STATE
----------------------------------------------------------------------
local TICKS_NEED    = 14         -- сколько тиков net_update_end нужно для зарядки DT
local charged_ticks = 0
local spike_until   = -1
local spike_logged  = false

local function tick() return globals.tickcount() end
local function lp()   return entity.get_local_player() end

local function dt_on()
    return ui.get(dt_enabled) and ui.get(dt_hotkey)
end

local function dt_charged() return charged_ticks >= TICKS_NEED end

-- глобальный флаг для других фейклаг-скриптов: пока true — не трогайте fl_limit
_G.ab_dt_spike_active = false

----------------------------------------------------------------------
-- 3. CHARGE TRACKER
----------------------------------------------------------------------
client.set_event_callback("net_update_end", function()
    if dt_on() then
        if charged_ticks < TICKS_NEED then
            charged_ticks = charged_ticks + 1
        end
    else
        charged_ticks = 0
    end
end)

----------------------------------------------------------------------
-- 4. SHOT TRIGGER
----------------------------------------------------------------------
local function start_spike(reason)
    spike_until = tick() + ui.get(spike_ticks)
    if not spike_logged then
        client.color_log(120, 220, 255,
            "[AntiBacktrackDT] spike triggered ("..reason..")")
        spike_logged = true
    end
end

client.set_event_callback("aim_fire", function()
    if not ui.get(enable) then return end
    if not dt_on() then return end

    local mode = ui.get(trigger)
    if mode == "Only when DT was charged" then
        if dt_charged() then start_spike("DT charged") end
    else
        start_spike("rage shot + DT held")
    end

    -- любой рэйдж-шот сбрасывает зарядку
    charged_ticks = 0
end)

-- бэкап-триггер по bullet_impact от локального плейера
client.set_event_callback("bullet_impact", function(e)
    if not ui.get(enable) then return end
    if not dt_on() then return end
    local me = lp(); if not me then return end
    local shooter = client.userid_to_entindex(e.userid)
    if shooter ~= me then return end

    -- если спайк уже идёт — не перезапускаем, иначе продлеваем
    if tick() > spike_until then return end
end)

----------------------------------------------------------------------
-- 5. ENGINE: держим спайк
----------------------------------------------------------------------
client.set_event_callback("setup_command", function()
    if not ui.get(enable) then
        _G.ab_dt_spike_active = false
        return
    end

    if tick() <= spike_until then
        -- форсим встроенный fakelag включённым и продавливаем чоку
        if not ui.get(fl_enabled) then ui.set(fl_enabled, true) end
        ui.set(fl_limit, ui.get(spike_choke))
        _G.ab_dt_spike_active = true
    else
        -- спайк закончен — просто перестаём писать, ничего не восстанавливаем
        _G.ab_dt_spike_active = false
        spike_logged = false
    end
end)

----------------------------------------------------------------------
-- 6. HUD
----------------------------------------------------------------------
local function lerp(a, b, t) return a + (b - a) * t end
local function lerp_rgb(c1, c2, t)
    return math.floor(lerp(c1[1], c2[1], t) + 0.5),
           math.floor(lerp(c1[2], c2[2], t) + 0.5),
           math.floor(lerp(c1[3], c2[3], t) + 0.5)
end

-- плавная анимация речарджа (визуальный pct догоняет реальный)
local anim_pct      = 0
local anim_last_rt  = 0

client.set_event_callback("paint", function()
    if not ui.get(enable) or not ui.get(hud_show) then return end

    local rt       = globals.realtime()
    local dt_frame = math.max(0, math.min(0.1, rt - anim_last_rt))
    anim_last_rt   = rt

    local x, y     = ui.get(hud_x), ui.get(hud_y)
    local total    = ui.get(spike_ticks)
    local left     = math.max(0, spike_until - tick())
    local active   = left > 0
    local sp_pct   = active and (left / total) or 0

    local charge_target = charged_ticks / TICKS_NEED
    -- экспоненциальный ease к target (около ~6↑ в сек)
    anim_pct = anim_pct + (charge_target - anim_pct) * math.min(1, dt_frame * 12)

    -- цветовые опоры: yellow → lime → green
    local COL_YEL  = { 255, 200,   0 }
    local COL_LIME = { 160, 255,  60 }
    local COL_GRN  = {   0, 255, 120 }
    local COL_RED  = { 255,  80,  80 }
    local COL_DIM  = {  60,  60,  60 }

    local cr, cg, cb
    if anim_pct < 0.5 then
        cr, cg, cb = lerp_rgb(COL_YEL, COL_LIME, anim_pct / 0.5)
    else
        cr, cg, cb = lerp_rgb(COL_LIME, COL_GRN, (anim_pct - 0.5) / 0.5)
    end

    local W, H = 168, 38
    -- фон + верхняя акцент-полоска
    renderer.rectangle(x, y,        W, H, 0, 0, 0, 170)
    renderer.rectangle(x, y,        W, 2, cr, cg, cb, 255)
    renderer.rectangle(x, y + H - 1, W, 1, 255, 255, 255, 25)

    -- заголовок
    renderer.text(x + 6, y + 4, 230, 230, 230, 255, "b-", 0, "DOUBLE TAP")

    -- бейдж справа
    local badge, br, bg, bb
    if active then
        badge, br, bg, bb = string.format("FIRING %d", left), COL_RED[1], COL_RED[2], COL_RED[3]
    elseif dt_charged() then
        -- пульсация при готовности
        local p = 0.6 + 0.4 * math.abs(math.sin(rt * 4))
        badge = "READY"
        br = math.floor(COL_GRN[1] * p)
        bg = math.floor(COL_GRN[2] * p)
        bb = math.floor(COL_GRN[3] * p)
    elseif dt_on() then
        badge = string.format("%d%%", math.floor(anim_pct * 100 + 0.5))
        br, bg, bb = cr, cg, cb
    else
        badge, br, bg, bb = "OFF", COL_DIM[1] + 80, COL_DIM[2] + 80, COL_DIM[3] + 80
    end
    renderer.text(x + W - 6, y + 4, br, bg, bb, 255, "br-", 0, badge)

    -- сегментный бар речарджа (14 сегментов)
    local seg_w, seg_h, seg_gap = 10, 8, 1
    local bar_x = x + 6
    local bar_y = y + 20
    local lit_f = anim_pct * TICKS_NEED
    for i = 1, TICKS_NEED do
        local sx = bar_x + (i - 1) * (seg_w + seg_gap)
        local fill = math.max(0, math.min(1, lit_f - (i - 1)))
        -- фон сегмента
        renderer.rectangle(sx, bar_y, seg_w, seg_h, COL_DIM[1], COL_DIM[2], COL_DIM[3], 200)
        if fill > 0 then
            renderer.rectangle(sx, bar_y, math.floor(seg_w * fill + 0.5), seg_h, cr, cg, cb, 235)
        end
    end

    -- полоска спайка снизу (когда активен)
    if active then
        local sb_y = y + H + 2
        renderer.rectangle(x,     sb_y,     W, 4, 0, 0, 0, 160)
        renderer.rectangle(x + 1, sb_y + 1, math.floor((W - 2) * sp_pct), 2,
            COL_RED[1], COL_RED[2], COL_RED[3], 230)
    end
end)

----------------------------------------------------------------------
-- 7. RESETS / CLEANUP
----------------------------------------------------------------------
local function hard_reset()
    spike_until   = -1
    charged_ticks = 0
    spike_logged  = false
    _G.ab_dt_spike_active = false
end

client.set_event_callback("round_start", hard_reset)

client.set_event_callback("player_spawn", function(e)
    local me = lp(); if not me then return end
    if client.userid_to_entindex(e.userid) == me then hard_reset() end
end)

client.set_event_callback("player_death", function(e)
    local me = lp(); if not me then return end
    if client.userid_to_entindex(e.userid) == me then hard_reset() end
end)

client.set_event_callback("shutdown", hard_reset)

ui.set_callback(enable, function()
    if not ui.get(enable) then hard_reset() end
end)

client.color_log(120, 220, 255, "[AntiBacktrackDT v2] loaded")

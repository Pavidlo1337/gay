-- Aspect Ratio Changer
-- Visuals → Other → Aspect Ratio

local TAB, CONT = 'VISUALS', 'Effects'

local ref_enabled = ui.new_checkbox(TAB, CONT, 'Aspect ratio')
local ref_mode    = ui.new_combobox(TAB, CONT, '\nAspect ratio mode',
    'Custom', '4:3 stretched', '4:3 black bars', '16:9', '16:10', '21:9 ultrawide', '32:9 super ultrawide')
local ref_value   = ui.new_slider(TAB, CONT, '\nAspect ratio value', 10, 400, 100, true, nil, 0.01,
    { [10] = '0.10', [100] = '1.00', [200] = '2.00', [400] = '4.00' })
local ref_hotkey  = ui.new_hotkey(TAB, CONT, '\nAspect ratio hotkey', true)
local ref_hk_mode = ui.new_combobox(TAB, CONT, '\nAspect ratio hotkey mode', 'Toggle', 'Hold')

-- Кешируем cvar один раз, чтобы не дёргать API каждый кадр
local cv_aspect = cvar.r_aspectratio

-- Пресеты: ratio = width / height
local PRESETS = {
    ['4:3 stretched']      = 0.0,   -- 0 = растянуть до соотношения монитора (классическое 4:3 stretched)
    ['4:3 black bars']     = 4 / 3, -- 1.333... с чёрными полосами по бокам на 16:9
    ['16:9']               = 16 / 9,
    ['16:10']              = 16 / 10,
    ['21:9 ultrawide']     = 21 / 9,
    ['32:9 super ultrawide'] = 32 / 9,
}

local toggle_state = false
local prev_hotkey  = false

local function is_active()
    if not ui.get(ref_enabled) then return false end

    local hk_pressed = ui.get(ref_hotkey)
    local hk_mode    = ui.get(ref_hk_mode)

    -- Если хоткей не задан вообще, ui.get(hotkey) вернёт true всегда — это нормально
    if hk_mode == 'Hold' then
        return hk_pressed
    else
        -- Toggle: переключаем по rising edge
        if hk_pressed and not prev_hotkey then
            toggle_state = not toggle_state
        end
        prev_hotkey = hk_pressed
        return toggle_state
    end
end

local function get_target_ratio()
    local mode = ui.get(ref_mode)
    if mode == 'Custom' then
        return ui.get(ref_value) / 100
    end
    return PRESETS[mode] or 0.0
end

local function update_visibility()
    local on = ui.get(ref_enabled)
    ui.set_visible(ref_mode,    on)
    ui.set_visible(ref_value,   on and ui.get(ref_mode) == 'Custom')
    ui.set_visible(ref_hotkey,  on)
    ui.set_visible(ref_hk_mode, on)
end

ui.set_callback(ref_enabled, update_visibility)
ui.set_callback(ref_mode,    update_visibility)
update_visibility()

-- Применяем каждую кадровую итерацию, чтобы перебить любые внешние правки (анти-aim скрипты, прочее).
-- paint вызывается каждый рендер кадр.
client.set_event_callback('paint', function()
    if is_active() then
        cv_aspect:set_float(get_target_ratio())
    else
        -- Сбрасываем в 0 (дефолт игры) только если значение отличается, чтобы не спамить запись в cvar
        if cv_aspect:get_float() ~= 0 then
            cv_aspect:set_float(0)
        end
    end
end)

-- При выгрузке скрипта возвращаем дефолт
client.set_event_callback('shutdown', function()
    cv_aspect:set_float(0)
end)

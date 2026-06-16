-- =====================================================================
--  Lunaris — runtime prelude (gamesense-native)
--
--  These are the framework primitives that the anti-aim builder below was
--  ported from Andromeda. Andromeda implements everything on top of the
--  native gamesense API via the `gamesense/pui` library, so we reproduce the
--  exact same wrappers here. Without this block the global `interface` /
--  `pui` are nil — that was the cause of the
--  `attempt to index global 'interface' (a nil value)` error.
-- =====================================================================

local pui    = require 'gamesense/pui'
local vector = require 'vector'
local c_entity     = require 'gamesense/entity'
local csgo_weapons = require 'gamesense/csgo_weapons'
local base64       = require 'gamesense/base64'
local msgpack      = require 'gamesense/msgpack'
local clipboard    = require 'gamesense/clipboard'

-- --- package descriptor (Andromeda equivalent) -----------------------
--  Andromeda defines a LOCAL `package` table whose `scriptname` is used as
--  the name of the custom body-yaw / anti-bruteforce mode in the menu
--  (the body-yaw combobox option `package.scriptname`) AND as the value
--  every runtime check compares against (`settings.body_yaw.type:get() ==
--  package.scriptname`). Without this local, `package` resolves to Lua's
--  built-in module table, so `package.scriptname` is nil — the custom
--  body-yaw mode option is created nameless and never matches at runtime
--  (that's the "no body yaw andromeda" bug). The string only has to be
--  consistent between the menu option and the checks.
local package
do
    package = {}
    package.scriptname = 'Lunaris'
    -- User is now pulled from the local Steam account (persona / display name)
    -- via the panorama JS bridge, the same way priora does it
    -- (panorama.open().MyPersonaAPI.GetName()). Wrapped in pcall so a panorama
    -- failure on load can't crash the script; falls back to 'lunaris'.
    local steam_name
    pcall(function()
        local js = panorama.open()
        if js and js.MyPersonaAPI and js.MyPersonaAPI.GetName then
            steam_name = js.MyPersonaAPI.GetName()
        end
    end)
    if type(steam_name) ~= 'string' or steam_name == '' then
        steam_name = 'lunaris'
    end
    package.user       = steam_name
    package.build      = 'Alpha'
    package.update     = '10.06.2026'
end

-- --- math helpers (Andromeda extensions) -----------------------------
function math.normalize_pitch(pitch)
    while pitch > 89 do pitch = pitch - 178 end
    while pitch < -89 do pitch = pitch + 178 end
    return pitch
end

function math.normalize_yaw(yaw)
    while yaw > 180 do yaw = yaw - 360 end
    while yaw < -180 do yaw = yaw + 360 end
    return yaw
end

function math.sign(value)
    if value > 0 then return 1 end
    if value < 0 then return -1 end
    return 0
end

function math.clamp(value, min, max)
    return math.max(min, math.min(value, max))
end

function math.lerp(start, ending, time)
    if type(ending) == 'boolean' then
        ending = ending and 1 or 0
    end
    local endlerp = start + (ending - start) * time
    return math.abs(ending - endlerp) <= .001 and ending or endlerp
end

function math.closest_ray_point(p, s, e)
    local t, d = p - s, e - s
    local l = d:length()
    d = d / l
    local r = d:dot(t)
    if r < 0 then
        return s
    elseif r > l then
        return e
    end
    return s + d * r
end

-- --- entity.get_flag (Andromeda helper extension) -------------------
--  Andromeda augments the native `entity` library with this helper that
--  decodes the ESP-data flag bitfield into named flags. The anti-aim
--  builder calls entity.get_flag(player, 'Hit'/'Occluded'/...) so we must
--  define it here, otherwise the call below is nil.
function entity.get_flag(player, flag)
    if not player then
        return false
    end

    if not entity.is_alive(player) then
        return false
    end

    local flags = {
        [1] = 'Helmet',
        [2] = 'Kevlar',
        [4] = 'Helmet + Kevlar',
        [8] = 'Zoom',
        [16] = 'Blind',
        [32] = 'Reload',
        [64] = 'Bomb',
        [128] = 'Vip',
        [256] = 'Defuse',
        [512] = 'Fakeduck',
        [1024] = 'Pin pulled',
        [2048] = 'Hit',
        [4096] = 'Occluded',
        [8192] = 'Exploiter',
        [131072] = 'Defensive dt'
    }

    local esp_data = entity.get_esp_data(player)
    local result = false

    for i, name in pairs(flags) do
        if bit.band(esp_data.flags, i) == i and name == flag then
            result = true
            break
        end
    end

    return result
end

-- --- entity.lethal (Andromeda helper extension) ---------------------
--  Andromeda helper that estimates whether our current weapon can kill a
--  player at the current range (used by `safehead`). Depends only on the
--  native entity API + `csgo_weapons` + `vector`, all already required.
function entity.lethal(me, player, boolean)
    if not me then
        return
    end

    if not player then
        return
    end

    local active_weapon = entity.get_player_weapon(me)
    if not active_weapon then
        return false
    end

    local weapon_id = entity.get_prop(active_weapon, 'm_iItemDefinitionIndex')
    if not weapon_id then
        return false
    end

    local weapon_struct = csgo_weapons[weapon_id]
    if not weapon_struct then
        return false
    end

    local player_origin = vector(entity.get_origin(me))
    local distance = player_origin:dist(vector(entity.get_origin(player)))
    local health = entity.get_prop(player, 'm_iHealth')
    local dmg_after_range = (weapon_struct.damage * math.pow(weapon_struct.range_modifier, (distance * 0.002))) * 1.25
    local armor = entity.get_prop(player, 'm_ArmorValue')
    local newdmg = dmg_after_range * (weapon_struct.armor_ratio * 0.5)
    if dmg_after_range - (dmg_after_range * (weapon_struct.armor_ratio * 0.5)) * 0.5 > armor then
        newdmg = dmg_after_range - (armor / 0.5)
    end

    local result = boolean and (newdmg >= health * 0.5) or (newdmg >= health)
    return result, math.ceil(newdmg)
end

-- --- interface table (native references via pui) ---------------------
local interface = {
    tab = {
        antiaim = pui.group('AA', 'Anti-aimbot angles'),
        fakelag = pui.group('AA', 'Fake lag'),
        other   = pui.group('AA', 'Other')
    },
    ui = {
        func = {
            aa      = {},
            visuals = {},
            misc    = {},
            config  = {},
        },
    },
    reference = {
        ragebot = {
            doubletap         = { pui.reference('Rage', 'Aimbot', 'Double tap') },
            fakeduck          = pui.reference('Rage', 'Other', 'Duck peek assist'),
            quick_peek_assist = { pui.reference('Rage', 'Other', 'Quick peek assist') },
            min_dmg           = { pui.reference('Rage', 'Aimbot', 'Minimum damage override') },
            damage            = pui.reference('Rage', 'Aimbot', 'Minimum damage'),
            baim              = pui.reference('Rage', 'Aimbot', 'Force body aim'),
            safepoint         = pui.reference('Rage', 'Aimbot', 'Force safe point'),
            ping              = { pui.reference('Misc', 'Miscellaneous', 'Ping spike') },
            hc                = pui.reference('Rage', 'Aimbot', 'Minimum hit chance'),
        },
        angles = {
            enabled           = pui.reference('AA', 'Anti-aimbot angles', 'Enabled'),
            pitch             = { pui.reference('AA', 'Anti-aimbot angles', 'Pitch') },
            yaw_base          = pui.reference('AA', 'Anti-aimbot angles', 'Yaw base'),
            yaw               = { pui.reference('AA', 'Anti-aimbot angles', 'Yaw') },
            yaw_jitter        = { pui.reference('AA', 'Anti-aimbot angles', 'Yaw jitter') },
            body_yaw          = { pui.reference('AA', 'Anti-aimbot angles', 'Body yaw') },
            fresstanding_body = pui.reference('AA', 'Anti-aimbot angles', 'Freestanding body yaw'),
            edge_yaw          = pui.reference('AA', 'Anti-aimbot angles', 'Edge yaw'),
            freestanding      = pui.reference('AA', 'Anti-aimbot angles', 'Freestanding'),
            roll              = pui.reference('AA', 'Anti-aimbot angles', 'Roll'),
        },
        fakelag = {
            fakelag        = { pui.reference('AA', 'Fake lag', 'Enabled') },
            fakelag_amount = pui.reference('AA', 'Fake lag', 'Amount'),
            variance       = pui.reference('AA', 'Fake lag', 'Variance'),
            limit          = pui.reference('AA', 'Fake lag', 'Limit'),
        },
        other = {
            slow      = { pui.reference('AA', 'Other', 'Slow motion') },
            leg_move  = pui.reference('AA', 'Other', 'Leg movement'),
            onshot    = { pui.reference('AA', 'Other', 'On shot anti-aim') },
            fake_peek = { pui.reference('AA', 'Other', 'Fake peek') },
        },
    },
}

-- Convenience alias used by the fake-lag builder (defensive / anti-bruteforce).
-- maxticks2 wraps the sv_maxusrcmdprocessticks cvar so :set(n) works like in Andromeda.
interface.antiaim = {
    fakelag = {
        amount    = interface.reference.fakelag.fakelag_amount,
        variance  = interface.reference.fakelag.variance,
        limit     = interface.reference.fakelag.limit,
        maxticks2 = { set = function(_, v) cvar.sv_maxusrcmdprocessticks:set_int(v) end },
    },
}

-- --- state helpers ---------------------------------------------------
interface.is_fake_duck = function()
    return interface.reference.ragebot.fakeduck:get() == true
end

interface.is_slow_motion = function()
    return interface.reference.other.slow[1]:get()
        and interface.reference.other.slow[1].hotkey:get()
end

interface.is_double_tap = function()
    return (interface.reference.ragebot.doubletap[1].hotkey:get() and interface.reference.ragebot.doubletap[1]:get())
        and not interface.is_fake_duck()
end

interface.is_on_shot_antiaim = function()
    return (interface.reference.other.onshot[1].hotkey:get() and interface.reference.other.onshot[1]:get())
        and not interface.is_double_tap() and not interface.is_fake_duck()
end

-- =====================================================================
--  END PRELUDE
-- =====================================================================

-- =====================================================================
--  Lunaris — Anti-Aim Builder
--  Ported from Andromeda (reference/andromeda  deobfus.lua)
--
--  Contents:
--    1. Anti-aim states list
--    2. Anti-aim menu builder (antiaim_setup)
--    3. Anti-aim runtime logic + builder (anti_aim) and event callbacks
--
--  External framework primitives this module expects to exist in Lunaris
--  (same names as in Andromeda — provide or adapt them):
--    - interface.tab.{antiaim,fakelag,other}, interface.ui.func.*,
--      interface.reference.*, interface.antiaim.fakelag.*,
--      interface.is_double_tap(), interface.is_on_shot_antiaim(),
--      interface.is_slow_motion()
--    - pui (group/reference/combobox/slider/checkbox/multiselect/hotkey/
--      label/traverse/setup), package.scriptname
--    - global `menu` table (built below), `hotkeys`, `configs`
--    - engine: client.*, globals.*, cvar, plist, entity, math.normalize_yaw,
--      math.sign  (Andromeda helper extensions)
--
--  NOTE: this is a faithful extraction of Andromeda's anti-aim subsystem.
--  It is tightly coupled to Andromeda's framework and will not run as-is in
--  an empty environment — wire the primitives above into Lunaris first.
-- =====================================================================

-- 1. ANTI-AIM STATES --------------------------------------------------

local anti_aim_states = {
    'General',
    'Standing',
    'Running',
    'Slow-motion',
    'Air',
    'Air Crouch',
    'Duck',
    'Duck Move',
    'Legit AA',
    'Manual AA',
    'Freestanding',
    'On peek',
    'Fake lag',
}

-- 2. ANTI-AIM MENU BUILDER -------------------------------------------

local setup = {}; do
    local aa_group = interface.tab.antiaim
    local fl_group = interface.tab.fakelag
    local ot_group = interface.tab.other
    local antiaim = interface.ui.func.aa
    local visuals = interface.ui.func.visuals
    local misc = interface.ui.func.misc
    local config = interface.ui.func.config

    menu = {
        shared = {},
        builder = {},
        aimbot = {},
        antiaim = {
            builder = {
                preset = {},
            },
            others = {
                keybinds = {},
            },
        },
        visuals = {
            indications = {},
        },
        misc = {},
        config = {},
    }
    local menu_global_label = fl_group:label('\a323232FF •  •  •  • ')
    menu.shared.tab = fl_group:combobox('\nGLOBAL_TABS', {'Home', 'Aimbot', 'Anti-aimbot', 'Visualisation', 'Miscellaneous'})

    menu.shared.tab:set_callback(function (this)
        local value = this:get()
        if value == 'Home' then
            menu_global_label:set('\v \a323232FF•  •  •  • ')
        elseif value == 'Aimbot' then
            menu_global_label:set('\a323232FF • \v \a323232FF•  •  • ')
        elseif value == 'Anti-aimbot' then
            menu_global_label:set('\a323232FF •  • \v \a323232FF•  • ')
        elseif value == 'Visualisation' then
            menu_global_label:set('\a323232FF •  •  • \v \a323232FF• ')
        elseif value == 'Miscellaneous' then
            menu_global_label:set('\a323232FF •  •  •  • \v')
        end
    end, true)

    menu.aimbot = {}
    -- =====================================================================
    --  AIMBOT TAB — ANDROMEDA PORT (виджеты, andromeda стр. 794–870)
    -- =====================================================================
        local aimbot_label = aa_group:label('\a323232FF • '):depend( { menu.shared.tab, 'Aimbot' } )
        menu.aimbot.features = aa_group:combobox('\nFEATURES_AIMBOT', {'Global', 'Hitchance'})
            :depend( { menu.shared.tab, 'Aimbot' } )

        menu.aimbot.features.global = {} do
            local item = menu.aimbot.features.global

            item.logic = aa_group:multiselect('\v \rAutomatic logif on', {'Force body aim', 'Force safety', 'Auto delay shot'})
                :depend( { menu.shared.tab, 'Aimbot' }, { menu.aimbot.features, 'Global' } )

            -- AI peek (перенесен из althea)
            menu.aimbot.ai_peek           = aa_group:checkbox('AI peek')
                :depend({ menu.shared.tab, 'Aimbot' }, { menu.aimbot.features, 'Global' })
            menu.aimbot.ai_peek_key       = aa_group:hotkey('\nAI_PEEK_BIND')
                :depend({ menu.shared.tab, 'Aimbot' }, { menu.aimbot.features, 'Global' }, { menu.aimbot.ai_peek, true })
            menu.aimbot.ai_peek_color     = aa_group:color_picker('\nAI_PEEK_INDICATORS', 255, 255, 255, 255)
                :depend({ menu.shared.tab, 'Aimbot' }, { menu.aimbot.features, 'Global' }, { menu.aimbot.ai_peek, true })
            menu.aimbot.ai_peek_mode      = aa_group:combobox('Mode', { 'Default', 'Advanced' })
                :depend({ menu.shared.tab, 'Aimbot' }, { menu.aimbot.features, 'Global' }, { menu.aimbot.ai_peek, true })
            menu.aimbot.ai_peek_offset    = aa_group:slider('Dot offset',  0, 20, 8, true, 'u', 1)
                :depend({ menu.shared.tab, 'Aimbot' }, { menu.aimbot.features, 'Global' }, { menu.aimbot.ai_peek, true })
            menu.aimbot.ai_peek_span      = aa_group:slider('Dot span',    0, 60, 5, true, 'u', 1)
                :depend({ menu.shared.tab, 'Aimbot' }, { menu.aimbot.features, 'Global' }, { menu.aimbot.ai_peek, true })
            menu.aimbot.ai_peek_amount    = aa_group:slider('Dot amount',  0,  8, 3, true, 'u', 1)
                :depend({ menu.shared.tab, 'Aimbot' }, { menu.aimbot.features, 'Global' }, { menu.aimbot.ai_peek, true })
            menu.aimbot.ai_peek_mp_head   = aa_group:slider('Head scale',  0, 100, 70, true, '%', 1)
                :depend({ menu.shared.tab, 'Aimbot' }, { menu.aimbot.features, 'Global' }, { menu.aimbot.ai_peek, true }, { menu.aimbot.ai_peek_mode, 'Advanced' })
            menu.aimbot.ai_peek_mp_chest  = aa_group:slider('Chest scale', 0, 100, 70, true, '%', 1)
                :depend({ menu.shared.tab, 'Aimbot' }, { menu.aimbot.features, 'Global' }, { menu.aimbot.ai_peek, true }, { menu.aimbot.ai_peek_mode, 'Advanced' })
            menu.aimbot.ai_peek_limbs     = aa_group:checkbox('Target limbs')
                :depend({ menu.shared.tab, 'Aimbot' }, { menu.aimbot.features, 'Global' }, { menu.aimbot.ai_peek, true }, { menu.aimbot.ai_peek_mode, 'Advanced' })

            item.force_baim = aa_group:multiselect('\vL \a6C6C6CFF~ \rForce body aim', {'Lethal', 'After x misses'})
                :depend( { menu.shared.tab, 'Aimbot' }, { menu.aimbot.features, 'Global' }, { item.logic, 'Force body aim' } )
            item.force_baim_miss = aa_group:slider('\nAFTER_X_MISSES_BAIM', 0, 5, 1, true, 'x', 1, { [0] = 'Always' })
                :depend( { menu.shared.tab, 'Aimbot' }, { menu.aimbot.features, 'Global' }, { item.logic, 'Force body aim' }, { item.force_baim, 'After x misses' } )

            item.force_safety = aa_group:multiselect('\vL \a6C6C6CFF~ \rForce safety', {'Lethal', 'After x misses'})
                :depend( { menu.shared.tab, 'Aimbot' }, { menu.aimbot.features, 'Global' }, { item.logic, 'Force safety' } )

            item.force_safety_miss = aa_group:slider('\nAFTER_X_MISSES_SAFETY', 0, 5, 1, true, 'x', 1, { [0] = 'Always' })
                :depend( { menu.shared.tab, 'Aimbot' }, { menu.aimbot.features, 'Global' }, { item.logic, 'Force safety' }, { item.force_safety, 'After x misses' } )

            item.delay_shot = aa_group:multiselect('\vL \a6C6C6CFF~ \rDelay shot if', {'Inaccuracy', 'Enemy defensive'})
                :depend( { menu.shared.tab, 'Aimbot' }, { menu.aimbot.features, 'Global' }, { item.logic, 'Auto delay shot' } )

            item.improvements = fl_group:multiselect('\v \rAimbot improvements', {'Better force defensive', 'Neverlose recharge'})
                :depend( { menu.shared.tab, 'Aimbot' }, { menu.aimbot.features, 'Global' })
            
            item.aircharge = fl_group:checkbox('\v \rCharge')
                :depend( { menu.shared.tab, 'Aimbot' }, { menu.aimbot.features, 'Global' }, { item.improvements, 'Neverlose recharge'})
        end
    -- =====================================================================
    --  HITCHANCE (per-weapon Air + No scope override of Minimum hit chance)
    -- =====================================================================
    do
        menu.aimbot.air_hc = aa_group:checkbox('\v \rEnabled')
            :depend({ menu.shared.tab, 'Aimbot' }, { menu.aimbot.features, 'Hitchance' })

        local HC_WEAPONS = { 'Auto snipers', 'Scout', 'AWP', 'R8' }
        local HC_NS = { ['Auto snipers'] = true, ['Scout'] = true, ['AWP'] = true }
        local HC_ID = {
            ['Auto snipers'] = 'AUTO',
            ['Scout']        = 'SCOUT',
            ['AWP']          = 'AWP',
            ['R8']           = 'R8',
        }

        menu.aimbot.hc_weapon = aa_group:combobox('\nHC_WP_PICK', HC_WEAPONS)
            :depend({ menu.shared.tab, 'Aimbot' }, { menu.aimbot.features, 'Hitchance' }, { menu.aimbot.air_hc, true })

        menu.aimbot.hc = {}
        for _, w in ipairs(HC_WEAPONS) do
            local id = HC_ID[w]
            menu.aimbot.hc[w] = {}
            menu.aimbot.hc[w].air = aa_group:slider('\vAir hitchance\nAIR_HC_' .. id, 0, 100, 50, true, '%')
                :depend({ menu.shared.tab, 'Aimbot' }, { menu.aimbot.features, 'Hitchance' }, { menu.aimbot.air_hc, true }, { menu.aimbot.hc_weapon, w })
            if HC_NS[w] then
                menu.aimbot.hc[w].ns = aa_group:slider('\vNo scope hitchance\nNS_HC_' .. id, 0, 100, 50, true, '%')
                    :depend({ menu.shared.tab, 'Aimbot' }, { menu.aimbot.features, 'Hitchance' }, { menu.aimbot.air_hc, true }, { menu.aimbot.hc_weapon, w })
            end
        end

        -- Runtime: map current weapon -> one of our 4 names, override hc when air / not-scoped.
        local function hc_weapon_for(idx)
            if idx == 11 or idx == 38 then return 'Auto snipers' end
            if idx == 40 then return 'Scout' end
            if idx == 9  then return 'AWP' end
            if idx == 64 then return 'R8' end
            return nil
        end

        local was_overridden = false
        local function reset()
            if was_overridden and interface.reference.ragebot.hc then
                interface.reference.ragebot.hc:override()
                was_overridden = false
            end
        end

        local function setup()
            local hcref = interface.reference.ragebot.hc
            if not hcref then return end
            if not menu.aimbot.air_hc:get() then return reset() end
            local lp = entity.get_local_player()
            if not lp or not entity.is_alive(lp) then return reset() end
            local wpn = entity.get_player_weapon(lp)
            if not wpn then return reset() end
            local idx = entity.get_prop(wpn, 'm_iItemDefinitionIndex')
            local wname = hc_weapon_for(idx)
            if not wname then return reset() end
            local cfg = menu.aimbot.hc[wname]
            local flags = entity.get_prop(lp, 'm_fFlags') or 0
            local on_ground = bit.band(flags, 1) ~= 0
            local scoped = (entity.get_prop(lp, 'm_bIsScoped') == 1)
            local value = nil
            if not on_ground then
                value = cfg.air:get()
            elseif cfg.ns and not scoped then
                value = cfg.ns:get()
            end
            if value and value > 0 then
                hcref:override(value)
                was_overridden = true
            else
                reset()
            end
        end

        client.set_event_callback('setup_command', setup)
        menu.aimbot.air_hc:set_callback(reset)
    end

    local function antiaim_setup()
        menu.antiaim.features = fl_group:multiselect('\v \aA2A2AFF~ \rFeatures', {'Avoid backstab', 'Safe head', 'Spinner override', 'Height advantage', 'Disablers', 'Manual AA'})
            :depend( { menu.shared.tab, 'Anti-aimbot' })
        -- Port Ð¸Ð· priora: ÑÐ»Ð°Ð¹Ð´ÐµÑ Ð´Ð¸ÑÑÐ°Ð½��Ð¸Ð¸ Avoid Backstab
        menu.antiaim.avoid_distance = fl_group:slider('Avoid distance', 0, 1000, 200, true, 'u', 1)
            :depend( { menu.shared.tab, 'Anti-aimbot' }, { menu.antiaim.features, 'Avoid backstab' })
        -- Port Ð¸Ð· priora: Safe head (Knife / Taser on Air + Crouch)
        menu.antiaim.safe_head = fl_group:multiselect('Safe head', {'Knife on Air + C', 'Taser on Air + C'})
            :depend( { menu.shared.tab, 'Anti-aimbot' }, { menu.antiaim.features, 'Safe head' })
        -- Port Ð¸Ð· priora: Spinner override (Warmup / No enemies)
        menu.antiaim.spinner_override = fl_group:multiselect('Spinner override', {'Warmup', 'No enemies'})
            :depend( { menu.shared.tab, 'Anti-aimbot' }, { menu.antiaim.features, 'Spinner override' })
        menu.antiaim.height = fl_group:multiselect('\vHeight \a6C6C6CFF~ \rAdvantage \von', {'Knife', 'Zeus', 'Other'})
            :depend( { menu.shared.tab, 'Anti-aimbot' }, { menu.antiaim.features, 'Height advantage'})
        menu.antiaim.disablers = fl_group:multiselect('\vDisablers \a6C6C6CFF~ \rAnti-\vaim', {'Warmup', 'No enemies'})
            :depend( { menu.shared.tab, 'Anti-aimbot' }, { menu.antiaim.features, 'Disablers'})
        menu.antiaim.manual_forward = fl_group:hotkey('\vManual \a6C6C6CFF~ \r⮝')
            :depend( { menu.shared.tab, 'Anti-aimbot' }, { menu.antiaim.features, 'Manual AA'})
        menu.antiaim.manual_left = fl_group:hotkey('\vManual \a6C6C6CFF~ \r⮜')
            :depend( { menu.shared.tab, 'Anti-aimbot' }, { menu.antiaim.features, 'Manual AA'})
        menu.antiaim.manual_right = fl_group:hotkey('\vManual \a6C6C6CFF~ \r⮞')
            :depend( { menu.shared.tab, 'Anti-aimbot' }, { menu.antiaim.features, 'Manual AA'})
        menu.antiaim.edge_yaw = fl_group:checkbox('\vEdge yaw \a6C6C6CFF~ \rKey', 0xA)
            :depend( { menu.shared.tab, 'Anti-aimbot' })
        menu.antiaim.freestanding = fl_group:checkbox('\vFreestanding \a6C6C6CFF~ \rKey', 0xA)
            :depend( { menu.shared.tab, 'Anti-aimbot' })

        menu.antiaim.target = ot_group:combobox('\v \rTarget mode', {'Local view', 'At targets'})
            :depend( { menu.shared.tab, 'Anti-aimbot' })
        menu.antiaim.conditions = aa_group:combobox('\v \rState', unpack(anti_aim_states))
            :depend( { menu.shared.tab, 'Anti-aimbot' })        menu.antiaim.builder_type = ot_group:combobox('\v \rBuilder type', {'Default', 'Anti-bruteforce', 'Defensive'})
            :depend( { menu.shared.tab, 'Anti-aimbot' })

        menu.antiaim.builder = {}
        for index, current_state in ipairs(anti_aim_states) do
            local state = {}
            local fl_extra = { menu.shared.tab, 'Anti-aimbot' }
            if current_state ~= 'General' then
                state.enabled = aa_group:checkbox('\v��� \rEnable ~ \v'.. current_state):depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.conditions, current_state})
            end

            -- =========== Fake lag: Mode + Preset widgets ===========
            if current_state == 'Fake lag' then
                menu.antiaim.fl_mode = aa_group:combobox('\v \rMode\nFL_MODE', {'Custom', 'Preset'})
                    :depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.conditions, 'Fake lag'}, {state.enabled, true})

                local jdep = function(w)
                    return w:depend(
                        {menu.shared.tab, 'Anti-aimbot'},
                        {menu.antiaim.conditions, 'Fake lag'},
                        {state.enabled, true},
                        {menu.antiaim.fl_mode, 'Preset'}
                    )
                end
                menu.antiaim.jfl_preset = jdep(aa_group:combobox('\v \rPreset', {'(select)', 'Anti-Skeet', 'Anti-Neverlose', 'Universal'}))
                menu.antiaim.jfl_apply  = jdep(aa_group:button('Apply preset', function()
                    if menu.antiaim.jfl_apply_fn then
                        menu.antiaim.jfl_apply_fn(menu.antiaim.jfl_preset:get())
                    end
                end))
                menu.antiaim.jfl_status = jdep(aa_group:label('  '))

                fl_extra = {menu.antiaim.fl_mode, 'Custom'}
            end
            -- =======================================================

            state.yaw = {} do
                local item = state.yaw
                item.type = aa_group:combobox('\v \rYaw\n' .. current_state, {'Static', 'L/R', 'Sway', 'X-way'}):depend({menu.shared.tab, 'Anti-aimbot'},  {menu.antiaim.builder_type, 'Default', 'Anti-bruteforce'},{menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true})
                
                item.static = aa_group:slider('\nSTATIC_YAW' .. current_state, -150, 150, 0, true, '°'):depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Default', 'Anti-bruteforce'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true}, {item.type, 'Static'})
                
                item.x_way1 = aa_group:slider('\nX-WAY1' .. current_state, -150, 150, 0, true, '°'):depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Default', 'Anti-bruteforce'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true}, {item.type, 'X-way'})
                item.x_way2 = aa_group:slider('\nX-WAY2' .. current_state, -150, 150, 0, true, '°'):depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Default', 'Anti-bruteforce'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true}, {item.type, 'X-way'})
                item.x_way3 = aa_group:slider('\nX-WAY3' .. current_state, -150, 150, 0, true, '°'):depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Default', 'Anti-bruteforce'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true}, {item.type, 'X-way'})
                item.x_way4 = aa_group:slider('\nX-WAY4' .. current_state, -150, 150, 0, true, '°'):depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Default', 'Anti-bruteforce'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true}, {item.type, 'X-way'})
                item.x_way5 = aa_group:slider('\nX-WAY5' .. current_state, -150, 150, 0, true, '°'):depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Default', 'Anti-bruteforce'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true}, {item.type, 'X-way'})
                
                item.left_randomize = aa_group:checkbox('\nLEFT_LR_DELAY' .. current_state):depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Default', 'Anti-bruteforce'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true}, {item.type, function () return item.type.value == 'L/R' or item.type.value == 'Sway' end})
                item.left = aa_group:slider('\v \rLeft\nLEFT_LR' .. current_state, -150, 150, 0, true, '°'):depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Default', 'Anti-bruteforce'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true}, {item.type, function () return item.type.value == 'L/R' or item.type.value == 'Sway' end})
                item.swayleft = aa_group:slider('\nSWAY_LEFT' .. current_state, -150, 150, 0, true, '°'):depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Default', 'Anti-bruteforce'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true}, {item.type, 'Sway'})
                item.randomize_left = aa_group:slider('\nRANDOMIZE_LEFT' .. current_state, 0, 100, 0, true, '%', 1, {[0] = 'Off'}):depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Default', 'Anti-bruteforce'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true}, {item.type, function () return item.type.value == 'L/R' or item.type.value == 'Sway' end}, {item.left_randomize, true})
                item.right_randomize = aa_group:checkbox('\nRIGHT_LR_DELAY' .. current_state):depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Default', 'Anti-bruteforce'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true}, {item.type, function () return item.type.value == 'L/R' or item.type.value == 'Sway' end})
                item.right = aa_group:slider('\v \rRight\nRIGHT_LR' .. current_state, -150, 150, 0, true, '°'):depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Default', 'Anti-bruteforce'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true}, {item.type, function () return item.type.value == 'L/R' or item.type.value == 'Sway' end})
                item.swayright = aa_group:slider('\nSWAY_RIGHT' .. current_state, -150, 150, 0, true, '°'):depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Default', 'Anti-bruteforce'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true}, {item.type, 'Sway'})
                item.randomize_right = aa_group:slider('\nRANDOMIZE_RIGHT' .. current_state, 0, 100, 0, true, '%', 1, {[0] = 'Off'}):depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Default', 'Anti-bruteforce'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true}, {item.type, function () return item.type.value == 'L/R' or item.type.value == 'Sway' end}, {item.right_randomize, true})
            end
            
            state.yaw_modifier = {} do
                local item = state.yaw_modifier
                item.type = aa_group:combobox('\v \rYaw modifier\n' .. current_state, {'Off', 'Offset', 'Center', 'Random', 'Spin', 'Rays'}):depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Default', 'Anti-bruteforce'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true})
                item.offset = aa_group:slider('\nYAW_MODIFIER_OFFSET' .. current_state, -150, 150, 0, true, '°'):depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Default', 'Anti-bruteforce'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true}, {item.type, 'Off', true})
            end
            
            state.body_yaw = {} do
                local item = state.body_yaw
                item.type = aa_group:combobox('\v \rBody yaw\nBODY_YAW' .. current_state, {'Off', 'Static', 'Opposite', 'Jitter', package.scriptname}):depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Default', 'Anti-bruteforce'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true})
                item.offset = aa_group:slider('\nBODY_YAW' .. current_state, -180, 180, 0, true, '°'):depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Default', 'Anti-bruteforce'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true}, {item.type, function ()
                    return item.type.value ~= 'Off' and item.type.value ~= package.scriptname
                end})
                
                item.andromeda_mode = aa_group:combobox('\nBODY_YAW_andromeda_MODE' .. current_state, {'Peek out', 'Dodge', 'Phase'}):depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Default', 'Anti-bruteforce'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true}, {item.type, package.scriptname})
                
                item.andromeda_antibrute = aa_group:combobox('\v \rDodge method\nBODY_YAW' .. current_state, {'Global', 'Side based'}):depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Default', 'Anti-bruteforce'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true}, {item.type, package.scriptname}, {item.andromeda_mode, 'Dodge'})
                item.one_delay = aa_group:slider('\nBODY_YAW' .. current_state, 1, 16, 1, true, 't', 1, {[0] = 'Off'}):depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Default', 'Anti-bruteforce'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true}, {item.type, package.scriptname}, {item.andromeda_antibrute, 'Global'}, {item.andromeda_mode, 'Dodge'})
                item.tick_min = aa_group:slider('\vDM \r~ Min\nBODY_YAW' .. current_state, 1, 16, 1, true, 't', 1, {[0] = 'Off'}):depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Default', 'Anti-bruteforce'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true}, {item.type, package.scriptname}, {item.andromeda_antibrute, 'Side based'}, {item.andromeda_mode, 'Dodge'})
                item.tick_max = aa_group:slider('\vDM \r~ Max\nBODY_YAW' .. current_state, 1, 16, 1, true, 't', 1, {[0] = 'Off'}):depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Default', 'Anti-bruteforce'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true}, {item.type, package.scriptname}, {item.andromeda_antibrute, 'Side based'}, {item.andromeda_mode, 'Dodge'})
            
                item.phasemode = aa_group:combobox('\v \rMode\nBODY_YAW' .. current_state, {'Custom', 'Automatic'}):depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Default', 'Anti-bruteforce'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true}, {item.type, package.scriptname}, {item.andromeda_mode, 'Phase'})
                item.phase = {} do
                    local phase = item.phase
            
                    phase.sides = aa_group:combobox('\nSTATE_PHASE' .. current_state, {'Left', 'Right'})
                        :depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Default', 'Anti-bruteforce'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true}, {item.type, package.scriptname}, {item.andromeda_mode, 'Phase'}, {item.phasemode, 'Custom'})
            
                    phase.phases = aa_group:slider('\nPHASES' .. current_state, 1, 5, 1, true, 'ph', 1)
                        :depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Default', 'Anti-bruteforce'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true}, {item.type, package.scriptname}, {item.andromeda_mode, 'Phase'}, {item.phasemode, 'Custom'})
            
                    for i = 1, 5 do
                        phase['sliderleft' .. i] = aa_group:slider('\nPHASES_SLIDERLEFT' .. i .. current_state, 1, 14, 1, true, 't', 1)
                            :depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Default', 'Anti-bruteforce'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true}, {item.type, package.scriptname}, {item.andromeda_mode, 'Phase'}, {phase.sides, 'Left'}, {item.phasemode, 'Custom'}, {phase.phases, function() return i <= phase.phases.value end})
                    end
                
                    for i = 1, 5 do
                        phase['sliderright' .. i] = aa_group:slider('\nPHASES_SLIDERRIGHT' .. i .. current_state, 1, 14, 1, true, 't', 1)
                            :depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Default', 'Anti-bruteforce'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true}, {item.type, package.scriptname}, {item.andromeda_mode, 'Phase'}, {phase.sides, 'Right'}, {item.phasemode, 'Custom'}, {phase.phases, function() return i <= phase.phases.value end})
                    end
                    phase.phase = aa_group:slider('\v \rFluctuating\n' .. current_state, 1, 100, 50, true, 'sf', 0.01, {[1] = 'F/SF', [25] = 'SF/SF', [50] = 'BW/SF', [100] = 'MW/SF',})
                        :depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Default', 'Anti-bruteforce'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true}, {item.type, package.scriptname}, {item.andromeda_mode, 'Phase'}, {item.phasemode, 'Automatic'})
                    
                    phase.pattern_mode = aa_group:combobox('\v \rPattern\nBODY_YAW' .. current_state, {'Increase', 'Decrease'})
                        :depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Default', 'Anti-bruteforce'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true}, {item.type, package.scriptname}, {item.andromeda_mode, 'Phase'}, {item.phasemode, 'Automatic'})  
                end
            end
            
            state.delay = {} do
                local item = state.delay
                item.enabled = aa_group:multiselect('\v \rDelay\nDELAY_ENABLE'..current_state, {'Side based', 'Delay on randomize'}):depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Default', 'Anti-bruteforce'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true}, {state.body_yaw.andromeda_mode, 'Peek out', 'Dodge'})
                item.left_delay_ticks = aa_group:slider('\vDL \r~ Left\nLEFT_LR_DELAY_TICKS' .. current_state, 1, 16, 1, true, 't', 1, {[0] = 'Off'}):depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Default', 'Anti-bruteforce'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true}, {item.enabled, 'Side based'}, {state.body_yaw.andromeda_mode, 'Peek out', 'Dodge'})
                item.right_delay_ticks = aa_group:slider('\vDL \r~ Right\nRIGHT_LR_DELAY_TICKS' .. current_state, 1, 16, 1, true, 't', 1, {[0] = 'Off'}):depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Default', 'Anti-bruteforce'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true}, {item.enabled, 'Side based'}, {state.body_yaw.andromeda_mode, 'Peek out', 'Dodge'})
                item.left_random_delay_ticks = aa_group:slider('\vDL \r~ Left random\nLEFT_LR_DELAY_TICKS' .. current_state, 1, 16, 1, true, 't', 1, {[0] = 'Off'}):depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Default', 'Anti-bruteforce'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true}, {item.enabled, 'Delay on randomize'}, {state.yaw.left_randomize, true}, {state.body_yaw.andromeda_mode, 'Peek out', 'Dodge'}, {state.yaw.type, function () return state.yaw.type.value == 'L/R' or state.yaw.type.value == 'Sway' end})
                item.right_random_delay_ticks = aa_group:slider('\vDL \r~ Right random\nRIGHT_LR_DELAY_TICKS' .. current_state, 1, 16, 1, true, 't', 1, {[0] = 'Off'}):depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Default', 'Anti-bruteforce'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true}, {item.enabled, 'Delay on randomize'}, {state.yaw.right_randomize, true}, {state.body_yaw.andromeda_mode, 'Peek out', 'Dodge'}, {state.yaw.type, function () return state.yaw.type.value == 'L/R' or state.yaw.type.value == 'Sway' end})
            end

            state.anti_brute = {} do
                local item = state.anti_brute

                item.enabled = ot_group:checkbox('\v \rEnable ~ \v'..current_state)
                    :depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Anti-bruteforce'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true})
                
                item.type = ot_group:combobox('\vAB \r~ Type', {'Phase 1', 'Phase 2', 'Phase 3', 'Phase 4', 'Phase 5'})
                    :depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Anti-bruteforce'}, {item.enabled, true}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true})
            
                item.phase = {}
            
                for i = 1, 5 do
                    item.phase[i] = {}

                    item.phase[i].yaw = ot_group:combobox('\vAB \r~ Yaw', {'Auto', 'Left & Right'})
                        :depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Anti-bruteforce'}, {item.type, 'Phase '..i}, {item.enabled, true}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true})

                    item.phase[i].yaw_left = ot_group:slider('\nABYAW_LEFT Phase'..i, -60, 60, 0, true, '°', 1, {[0] = 'Off'})
                        :depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Anti-bruteforce'}, {item.type, 'Phase '..i}, {item.phase[i].yaw, 'Left & Right'}, {item.enabled, true}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true})
                
                    item.phase[i].yaw_right = ot_group:slider('\nABYAW_RIGHT Phase '..i, -60, 60, 0, true, '°', 1, {[0] = 'Off'})
                        :depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Anti-bruteforce'}, {item.type, 'Phase '..i}, {item.phase[i].yaw, 'Left & Right'}, {item.enabled, true}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true})

                    item.phase[i].yaw_modifier = ot_group:combobox('\vAB \r~ Yaw modifier', {'Off', 'Offset', 'Center', 'Random', 'Spin'})
                        :depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Anti-bruteforce'}, {item.type, 'Phase '..i}, {item.enabled, true}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true})

                    item.phase[i].yaw_modifier_limit = ot_group:slider('\nABYAW_MODIFIER_LIMIT Phase '..i, -20, 20, 0, true, '°', 1, {[0] = 'Off'})
                        :depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Anti-bruteforce'}, {item.type, 'Phase '..i}, {item.enabled, true}, {item.phase[i].yaw_modifier, 'Offset', 'Center', 'Random', 'Spin'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true})
                end

                item.mode = ot_group:combobox('\vAB \r~ Mode', {'Timer', 'Round'})
                    :depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Anti-bruteforce'}, {item.enabled, true}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true})

                item.time = ot_group:slider('\nABTIMER', 1, 10, 0, true, 's', 1)
                    :depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Anti-bruteforce'}, {item.mode, 'Timer'}, {item.enabled, true}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true})
            end
            
            if current_state ~= 'Legit AA' then
                state.defensive = {}
                state.defensive.break_lc = aa_group:multiselect('\nFORCEBREAKLC'..current_state, {'Double tap', 'On shot anti-aim'})
                    :depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Defensive'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true})
                state.defensive.enabled = aa_group:checkbox('\v \rEnable \vDefensive AA\nDEFENSIVE'..current_state)
                    :depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Defensive'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true})
                state.defensive.pitch = {} do
                    local item = state.defensive.pitch
                    item.type = aa_group:combobox('\v \rPitch \vmode\n'.. current_state, {'Default', 'Auto', 'Random', 'Sinus', 'Spinable', 'Refraction', 'Jitter', 'Custom'})
                        :depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Defensive'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true}, {state.defensive.enabled, true})
                    item.up = aa_group:slider('\nDEFENSIVE_PITCHUP' .. current_state, -89, 89, 0, true, '°')
                        :depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Defensive'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true}, {state.defensive.enabled, true}, {item.type, 'Default', true}, {item.type, 'Refraction', true}, {item.type, 'Auto', true})
                    item.down = aa_group:slider('\nDEFENSIVE_PITCHDOWN' .. current_state, -89, 89, 0, true, '°')
                        :depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Defensive'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true}, {state.defensive.enabled, true}, {item.type, 'Default', true}, {item.type, 'Refraction', true}, {item.type, 'Custom', true}, {item.type, 'Auto', true})
                    item.random_type = aa_group:combobox('\nDEFENSIVE_PITCH' .. current_state, {'Default', 'Random static'})
                        :depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Defensive'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true}, {state.defensive.enabled, true}, {item.type, 'Random'})
                    item.delay = aa_group:slider('\nDEFENSIVE_PITCHDELAY' .. current_state, 1, 13, 1, true, 't')
                        :depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Defensive'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true}, {state.defensive.enabled, true}, {item.type, function ()
                            return item.type.value == 'Random' or item.type.value == 'Jitter'
                        end})
                    item.tick = aa_group:slider('\nDEFENSIVE_PITCHTICK' .. current_state, -50, 50, 0, true, 'ms', 0.1)
                        :depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Defensive'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true}, {state.defensive.enabled, true}, {item.type, function ()
                        return item.type.value == 'Sinus' or item.type.value == 'Spinable'
                    end})
                    item.up_refraction = aa_group:slider('\nDEFENSIVE_PITCHUPREFRACTION' .. current_state, -89, 89, 0, true, '°')
                        :depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Defensive'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true}, {state.defensive.enabled, true}, {item.type, 'Refraction'})
                    item.down_refraction = aa_group:slider('\nDEFENSIVE_PITCHDOWNREFRACTION' .. current_state, -89, 89, 0, true, '°')
                        :depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Defensive'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true}, {state.defensive.enabled, true}, {item.type, 'Refraction'})
                    item.spin_refraction = aa_group:slider('\nDEFENSIVE_SPINREFRACTION' .. current_state, -89, 89, 0, true, '°')
                        :depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Defensive'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true}, {state.defensive.enabled, true}, {item.type, 'Refraction'})
                    item.refraction_timer = aa_group:slider('\nDEFENSIVE_PITCHTIMER' .. current_state, 1, 20, 0, true, 'sec', 0.1)
                        :depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Defensive'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true}, {state.defensive.enabled, true}, {item.type, 'Refraction'})
                end
                    
                state.defensive.yaw = {} do
                    local item = state.defensive.yaw
                    item.type = aa_group:combobox('\v \rYaw \vmode\nDEFENSIVE_YAW' .. current_state, {'Static', 'Auto', 'Random', '180 Spin', 'Spinable', 'Side Based', 'Refraction', 'Custom'})
                        :depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Defensive'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true}, {state.defensive.enabled, true})
                    
                    item.add_on = aa_group:multiselect('\vJ \r~ Add-on\n'..current_state, {'Delay', 'Randomized delay'})
                        :depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Defensive'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true}, {state.defensive.enabled, true}, {item.type, 'Side Based'})
                    
                    item.left = aa_group:slider('\nDEFENSIVE_YAWLEFT' .. current_state, -180, 180, 0, true, '°')
                        :depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Defensive'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true}, {state.defensive.enabled, true}, {item.type, 'Static', true}, {item.type, 'Refraction', true}, {item.type, 'Auto', true})
                    item.left_delay = aa_group:slider('\nDEFENSIVE_YAWDELAYLEFT' .. current_state, 1, 14, 1, true, 't')
                        :depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Defensive'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true}, {state.defensive.enabled, true}, {item.type, 'Side Based'}, {item.add_on, 'Delay'})
                    item.left_random_delay = aa_group:slider('\nDEFENSIVE_YAWDELAYRANDOMLEFT' .. current_state, 1, 14, 1, true, 't')
                        :depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Defensive'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true}, {state.defensive.enabled, true}, {item.type, 'Side Based'}, {item.add_on, 'Delay'}, {item.add_on, 'Randomized delay'})
                    item.right = aa_group:slider('\nDEFENSIVE_YAWRIGHT' .. current_state, -180, 180, 0, true, '°')
                        :depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Defensive'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true}, {state.defensive.enabled, true}, {item.type, 'Static', true}, {item.type, 'Refraction', true}, {item.type, 'Custom', true}, {item.type, 'Auto', true})
                    item.random_type = aa_group:combobox('\nDEFENSIVE_YAW' .. current_state, {'Default', 'Random static'})
                        :depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Defensive'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true}, {state.defensive.enabled, true}, {item.type, 'Random'})
                    item.tick = aa_group:slider('\nDEFENSIVE_YAWTICK' .. current_state, -50, 50, 0, true, 'ms', 0.1)
                        :depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Defensive'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true}, {state.defensive.enabled, true}, {item.type, function ()
                            return item.type.value == '180 Spin' or item.type.value == 'Spinable'
                        end})
                    item.right_delay = aa_group:slider('\nDEFENSIVE_YAWDELAYRIGHT' .. current_state, 1, 14, 1, true, 't')
                        :depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Defensive'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true}, {state.defensive.enabled, true}, {item.type, 'Side Based'}, {item.add_on, 'Delay'})
                    item.right_random_delay = aa_group:slider('\nDEFENSIVE_YAWDELAYRANDOMRIGHT' .. current_state, 1, 14, 1, true, 't')
                        :depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Defensive'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true}, {state.defensive.enabled, true}, {item.type, 'Side Based'}, {item.add_on, 'Delay'}, {item.add_on, 'Randomized delay'})
                    item.delay = aa_group:slider('\nDEFENSIVE_YAWDELAY' .. current_state, 1, 13, 1, true, 't')
                        :depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Defensive'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true}, {state.defensive.enabled, true}, {item.type, 'Random'})

                    item.refraction_left = aa_group:slider('\nDEFENSIVE_LEFTREFRACTION' .. current_state, -180, 180, 0, true, '°')
                        :depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Defensive'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true}, {state.defensive.enabled, true}, {item.type, 'Refraction'})
                    item.refraction_right = aa_group:slider('\nDEFENSIVE_RIGHTREFRACTION' .. current_state, -180, 180, 0, true, '°')
                        :depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Defensive'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true}, {state.defensive.enabled, true}, {item.type, 'Refraction'})
                    item.refraction_spin = aa_group:slider('\nDEFENSIVE_SPINREFRACTION' .. current_state, -180, 180, 0, true, '°')
                        :depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Defensive'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true}, {state.defensive.enabled, true}, {item.type, 'Refraction'})
                    
                    item.refraction_timer = aa_group:slider('\nDEFENSIVE_YAWTIMER' .. current_state, 1, 20, 0, true, 'sec', 0.1)
                        :depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Defensive'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true}, {state.defensive.enabled, true}, {item.type, 'Refraction'})
                end

                state.defensive.flick = {} do
                    local item = state.defensive.flick
                    item.enabled = aa_group:checkbox('\v \rEnable \vDefensive flick\nDEFENSIVE_FLICK_ENABLE' .. current_state)
                        :depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Defensive'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true}, {state.defensive.enabled, true})
                    item.inverter = aa_group:hotkey('\v \rFlick inverter\nDEFENSIVE_FLICK_INVERTER' .. current_state)
                        :depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Defensive'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true}, {state.defensive.enabled, true}, {item.enabled, true})
                    item.pitch_type = aa_group:combobox('\v \rFlick \vpitch\nDEFENSIVE_FLICK_PITCH' .. current_state, {'Off', 'Static', 'Jitter', 'Spin', 'Spin[MOD]', 'Random', 'Random Ticks'})
                        :depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Defensive'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true}, {state.defensive.enabled, true}, {item.enabled, true})
                    item.pitch_static = aa_group:slider('\nDEFENSIVE_FLICK_PITCH_STATIC' .. current_state, -89, 89, 0, true, '°', 1)
                        :depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Defensive'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true}, {state.defensive.enabled, true}, {item.enabled, true}, {item.pitch_type, 'Static'})
                    item.pitch_mode1 = aa_group:slider('\v \rAngle 1\nDEFENSIVE_FLICK_PITCH_MODE1' .. current_state, -89, 89, 0, true, '°', 1)
                        :depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Defensive'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true}, {state.defensive.enabled, true}, {item.enabled, true}, {item.pitch_type, 'Jitter', 'Spin', 'Spin[MOD]', 'Random'})
                    item.pitch_mode2 = aa_group:slider('\v \rAngle 2\nDEFENSIVE_FLICK_PITCH_MODE2' .. current_state, -89, 89, 0, true, '°', 1)
                        :depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Defensive'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true}, {state.defensive.enabled, true}, {item.enabled, true}, {item.pitch_type, 'Jitter', 'Spin', 'Spin[MOD]', 'Random'})
                    item.pitch_speed = aa_group:slider('\v \rAngle speed\nDEFENSIVE_FLICK_PITCH_SPEED' .. current_state, -50, 50, 20, true, ' ', 0.1)
                        :depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Defensive'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true}, {state.defensive.enabled, true}, {item.enabled, true}, {item.pitch_type, 'Spin', 'Spin[MOD]'})
                    item.pitch_jitter_speed = aa_group:slider('\v \rSpeed ticks\nDEFENSIVE_FLICK_PITCH_JITTER' .. current_state, 2, 14, 2, true, 't', 1)
                        :depend({menu.shared.tab, 'Anti-aimbot'}, {menu.antiaim.builder_type, 'Defensive'}, {menu.antiaim.conditions, current_state}, fl_extra, state.enabled and {state.enabled, true}, {state.defensive.enabled, true}, {item.enabled, true}, {item.pitch_type, 'Jitter'})
                end
            end


            menu.antiaim.builder[current_state] = state
        end

    end
    -- (relocated) Visualisation checkboxes built BEFORE antiaim_setup so they stay interactive in the left column
        -- =============== ANDROMEDA VISUAL FEATURES (ported 1:1) ==========
        -- Thirdperson + distance, Aspect ratio + value, Proper Viewmodel
        -- (fov/x/y/z + scope toggle) and FOV Animation (base/amount/speed).
        -- Widgets live in the Anti-aimbot angles column (created early to stay interactive) of the Visualisation tab so they
        -- sit alongside World marker / Damage marker / Aimbot logs.
        menu.visuals.thirdperson  = aa_group:checkbox('Thirdperson')
            :depend({ menu.shared.tab, 'Visualisation' })
        menu.visuals.tp_dist      = aa_group:slider('\nTP_DIST', 20, 200, 150, true, 'ft', 1)
            :depend({ menu.shared.tab, 'Visualisation' }, { menu.visuals.thirdperson, true })

        menu.visuals.aspect_ratio = aa_group:checkbox('Aspect ratio')
            :depend({ menu.shared.tab, 'Visualisation' })
        menu.visuals.ap_dist      = aa_group:slider('\nAP_DIST', 80, 300, 170, true, '%', 0.01)
            :depend({ menu.shared.tab, 'Visualisation' }, { menu.visuals.aspect_ratio, true })

        menu.visuals.viewmodel    = aa_group:checkbox('Proper Viewmodel')
            :depend({ menu.shared.tab, 'Visualisation' })
        menu.visuals.vm_fov_lbl   = aa_group:label('VM ~ Fov')
            :depend({ menu.shared.tab, 'Visualisation' }, { menu.visuals.viewmodel, true })
        menu.visuals.fov          = aa_group:slider('\nVM_FOV', -20000, 20000, 0, true, '\xC2\xB0', 0.01)
            :depend({ menu.shared.tab, 'Visualisation' }, { menu.visuals.viewmodel, true })
        menu.visuals.vm_x_lbl     = aa_group:label('VM ~ X')
            :depend({ menu.shared.tab, 'Visualisation' }, { menu.visuals.viewmodel, true })
        menu.visuals.offset_x     = aa_group:slider('\nVM_X', -5000, 5000, 0, true, '\xC2\xB0', 0.01)
            :depend({ menu.shared.tab, 'Visualisation' }, { menu.visuals.viewmodel, true })
        menu.visuals.vm_y_lbl     = aa_group:label('VM ~ Y')
            :depend({ menu.shared.tab, 'Visualisation' }, { menu.visuals.viewmodel, true })
        menu.visuals.offset_y     = aa_group:slider('\nVM_Y', -5000, 5000, 0, true, '\xC2\xB0', 0.01)
            :depend({ menu.shared.tab, 'Visualisation' }, { menu.visuals.viewmodel, true })
        menu.visuals.vm_z_lbl     = aa_group:label('VM ~ Z')
            :depend({ menu.shared.tab, 'Visualisation' }, { menu.visuals.viewmodel, true })
        menu.visuals.offset_z     = aa_group:slider('\nVM_Z', -5000, 5000, 0, true, '\xC2\xB0', 0.01)
            :depend({ menu.shared.tab, 'Visualisation' }, { menu.visuals.viewmodel, true })
        menu.visuals.viewmodel_in_scope = aa_group:checkbox('VM ~ Viewmodel in scope')
            :depend({ menu.shared.tab, 'Visualisation' }, { menu.visuals.viewmodel, true })

        menu.visuals.animated_zoom       = aa_group:checkbox('FOV Animation')
            :depend({ menu.shared.tab, 'Visualisation' })
        menu.visuals.animated_zoom_fov   = aa_group:slider('FA ~ Base FOV', 70, 150, 90, true, '\xC2\xB0', 1)
            :depend({ menu.shared.tab, 'Visualisation' }, { menu.visuals.animated_zoom, true })
        menu.visuals.animated_zoom_amount= aa_group:slider('FA ~ Amount',    0,  40, 10, true, '%', 1)
            :depend({ menu.shared.tab, 'Visualisation' }, { menu.visuals.animated_zoom, true })
        menu.visuals.animated_zoom_speed = aa_group:slider('FA ~ Speed',     1,  20,  5, true, 'ms', 1)
            :depend({ menu.shared.tab, 'Visualisation' }, { menu.visuals.animated_zoom, true })


    -- (relocated) configs object + Home config UI built BEFORE antiaim_setup so they land early in the LEFT column and stay interactive
    local configs = {} do
        local DATABASE_KEY = 'lunaris_configs'
        local DATABASE = database.read(DATABASE_KEY) or {}
        local CONFIG_SIGNATURE = 'lunaris'

        local function encode(data)
            local packed_data = msgpack.pack(data)
            local encoded_data = base64.encode(packed_data)
            return table.concat({ CONFIG_SIGNATURE, encoded_data, CONFIG_SIGNATURE }, '::')
        end

        local function decode(config)
            local encoded = config:match(CONFIG_SIGNATURE .. '::(.+)::' .. CONFIG_SIGNATURE)
            if not encoded then
                print('Invalid config format.')
                return nil
            end

            local decoded_data = base64.decode(encoded)
            return msgpack.unpack(decoded_data)
        end

        function configs:export(name)
            local configuration = {
                name = name or 'Untitled',
                code = menu.config:save()
            }
            return encode(configuration)
        end

        function configs:import(config, ...)
            local data = decode(config)
            if not data then
                return nil
            end
            menu.config:load(data.code, ...)
            return data
        end

        function configs:get_configs()
            local list = {}
            for i, data in ipairs(DATABASE) do
                list[i] = data.name
            end
            return list
        end

        function configs:get(id)
            return DATABASE[id]
        end

        function configs:delete(id)
            table.remove(DATABASE, id)
        end

        function configs:create(name, code)
            table.insert(DATABASE, { name = name, code = code })
        end

        function configs:save(id, code)
            if DATABASE[id] then
                DATABASE[id].code = code
            end
        end

        function configs:create_from_encoded_data(config)
            local data = decode(config)
            if not data then
                error('Invalid config data.')
                return
            end

            local original_name = data.name
            local candidate_name = original_name
            local counter = 0
            local existing_configs = configs:get_configs()

            local function name_exists(name)
                for _, existing_name in ipairs(existing_configs) do
                    if existing_name == name then
                        return true
                    end
                end
                return false
            end

            while name_exists(candidate_name) do
                counter = counter + 1
                candidate_name = original_name .. '(' .. counter .. ')'
            end

            data.name = candidate_name
            self:create(data.name, config)
        end

        defer(function ()
            database.write(DATABASE_KEY, DATABASE)
            database.flush()
        end)
    end

    -- --- Config management UI (anti-aim column, Home tab) ------------
    do
        local config_information = { list = {}, id = 1 }
        local config_list = aa_group:listbox('Configs', #configs:get_configs() > 0 and configs:get_configs() or { 'No configs' }):depend({ menu.shared.tab, 'Home' })
        local selected = aa_group:label('Selected: \vNothing'):depend({ menu.shared.tab, 'Home' })
        local config_name = aa_group:textbox('Name config'):depend({ menu.shared.tab, 'Home' })
        local get_loading_objects = aa_group:multiselect('Loading objects:', {'Rage', 'Antiaim', 'Visuals', 'Misc'}):depend({ menu.shared.tab, 'Home' })

        client.set_event_callback('paint_ui', function()
            if not ui.is_menu_open() then
                return
            end

            local list = configs:get_configs()
            if #list ~= #config_information.list then
                config_information.list = list

                if #list == 0 then
                    config_list:update({ 'No configs' })
                    config_list.value = 1
                    config_information.id = 1
                    return
                else
                    config_list:update(list)
                    return
                end
            end

            if config_list.value == nil then
                config_list.value = 1
            end

            local id = (config_list.value or 1) + 1
            if id ~= config_information.id then
                config_information.id = id
                return
            end
        end)

        local function validate_config_name()
            local name = config_name:get():gsub(' ', '')
            if name == '' then
                return true, 'Untitled'
            end
            return true, name
        end

        local function validate_config_exists(id)
            if #configs:get_configs() <= 0 then
                print('No configs available')
                return false, nil
            end

            local config = configs:get(id)
            if not config then
                print('Config not found.')
                return false, nil
            end

            return true, config
        end

        local function load_aa_config()
            local valid, config = validate_config_exists(config_information.id)
            if not valid or not config then
                print('Config issue')
                return
            end

            for index, value in ipairs(get_loading_objects:get()) do
                if value == 'Visuals' then
                    configs:import(config.code, 'visuals')
                end
                if value == 'Misc' then
                    configs:import(config.code, 'misc')
                end
                if value == 'Rage' then
                    configs:import(config.code, 'aimbot')
                end
                if value == 'Antiaim' then
                    configs:import(config.code, 'antiaim')
                    configs:import(config.code, 'builder')
                end
            end

            if get_loading_objects:get() == nil then
                configs:import(config.code)
            end

            print('Config loaded successfully: ' .. config.name)
        end

        local function save_config()
            local valid, name = validate_config_name()
            if not valid then
                return
            end

            local code = configs:export(name)
            local current_config = configs:get(config_information.id)

            if not current_config or name ~= current_config.name then
                configs:create(name, code)
                print('Config created successfully: ' .. name)
            else
                configs:save(config_information.id, code)
                print('Config saved successfully: ' .. name)
            end
        end

        local function remove_config()
            local valid, config = validate_config_exists(config_information.id)
            if not valid or not config then
                return
            end

            configs:delete(config_information.id)
            print('Config removed successfully: ' .. config.name)
        end

        local function export_config()
            local valid, name = validate_config_name()
            if not valid then
                return
            end

            clipboard.set(configs:export(name))
            print('Copied to clipboard')
        end

        local function import_config()
            local code = clipboard.get()
            if not code then
                print('Clipboard is empty')
                return
            end

            local ok = pcall(configs.create_from_encoded_data, configs, code)
            print(ok and 'Config imported successfully' or 'Invalid config data')
        end

        local load   = aa_group:button('Load', load_aa_config):depend({ menu.shared.tab, 'Home' })
        local save   = aa_group:button('Save', save_config):depend({ menu.shared.tab, 'Home' })
        local delete = aa_group:button('Delete', remove_config):depend({ menu.shared.tab, 'Home' })
        local export = aa_group:button('Export', export_config):depend({ menu.shared.tab, 'Home' })
        local import = aa_group:button('Import', import_config):depend({ menu.shared.tab, 'Home' })

        config_list:set_callback(function(item)
            local config = configs:get(item:get() + 1) or configs:get(config_information.id)
            if config == nil then
                selected:set('Selected: \vNothing')
                config_name:set('')
                load:set_enabled(false)
                delete:set_enabled(false)
                export:set_enabled(false)
                get_loading_objects:set_enabled(false)
                return
            end

            config_name:set(config.name)
            selected:set('Selected: \v' .. config.name)
            load:set_enabled(true)
            delete:set_enabled(true)
            export:set_enabled(true)
            get_loading_objects:set_enabled(true)
        end)
    end

    antiaim_setup()

    -- =================================================================
    --  VISUALISATION + MISCELLANEOUS menu items
    --    Aimbot logs (Visualisation column) — hit/miss logging to the
    --      console and/or on screen, priora-style fields (target /
    --      hitbox / damage / hitchance). Driven by the aimbot_logs
    --      runtime block further below.
    --    Clan tag (Miscellaneous column) — animated spinning clantag
    --      built from a base string (default 'Lunaris'); suppresses the
    --      stock gamesense clantag while active (priora net_update idea).
    --  Built BEFORE pui.setup(menu) so both persist inside saved configs.
    -- =================================================================
    do
        -- =============== WORLD MARKER (ported from Althea) ================
        menu.visuals.wm_enabled    = ot_group:checkbox('\v \rWorld marker')
            :depend({ menu.shared.tab, 'Visualisation' })
        menu.visuals.wm_style      = ot_group:combobox('\v \rStyle', { 'Cross', 'Plus' })
            :depend({ menu.shared.tab, 'Visualisation' }, { menu.visuals.wm_enabled, true })
        menu.visuals.wm_size       = ot_group:slider('\v \rSize', 3, 10, 5)
            :depend({ menu.shared.tab, 'Visualisation' }, { menu.visuals.wm_enabled, true })
        menu.visuals.wm_miss_rsn   = ot_group:checkbox('\v \rShow miss reason')
            :depend({ menu.shared.tab, 'Visualisation' }, { menu.visuals.wm_enabled, true })
        -- pui's color_picker(label) first argument is used ONLY as a unique
        -- key (no visible text), so to show "Hit color" / "? color" etc.
        -- next to each swatch (like althea) we emit a separate :label()
        -- widget right before each color_picker. The label depends on the
        -- same wm_enabled toggle so they hide/show together.
        menu.visuals.wm_hit_lbl    = ot_group:label('Hit color')
            :depend({ menu.shared.tab, 'Visualisation' }, { menu.visuals.wm_enabled, true })
        menu.visuals.wm_hit_clr    = ot_group:color_picker('\nWM_HIT_CLR',    180, 230,  30, 255)
            :depend({ menu.shared.tab, 'Visualisation' }, { menu.visuals.wm_enabled, true })
        menu.visuals.wm_quest_lbl  = ot_group:label('? color')
            :depend({ menu.shared.tab, 'Visualisation' }, { menu.visuals.wm_enabled, true })
        menu.visuals.wm_quest_clr  = ot_group:color_picker('\nWM_QUEST_CLR',  255,   0,   0, 255)
            :depend({ menu.shared.tab, 'Visualisation' }, { menu.visuals.wm_enabled, true })
        menu.visuals.wm_spread_lbl = ot_group:label('Spread color')
            :depend({ menu.shared.tab, 'Visualisation' }, { menu.visuals.wm_enabled, true })
        menu.visuals.wm_spread_clr = ot_group:color_picker('\nWM_SPREAD_CLR', 255, 200,   0, 255)
            :depend({ menu.shared.tab, 'Visualisation' }, { menu.visuals.wm_enabled, true })
        menu.visuals.wm_pred_lbl   = ot_group:label('Prediction error color')
            :depend({ menu.shared.tab, 'Visualisation' }, { menu.visuals.wm_enabled, true })
        menu.visuals.wm_pred_clr   = ot_group:color_picker('\nWM_PRED_CLR',   255, 125, 125, 255)
            :depend({ menu.shared.tab, 'Visualisation' }, { menu.visuals.wm_enabled, true })
        menu.visuals.wm_death_lbl  = ot_group:label('Death color')
            :depend({ menu.shared.tab, 'Visualisation' }, { menu.visuals.wm_enabled, true })
        menu.visuals.wm_death_clr  = ot_group:color_picker('\nWM_DEATH_CLR',  100, 100, 255, 255)
            :depend({ menu.shared.tab, 'Visualisation' }, { menu.visuals.wm_enabled, true })
        menu.visuals.wm_unreg_lbl  = ot_group:label('Unregistered shot color')
            :depend({ menu.shared.tab, 'Visualisation' }, { menu.visuals.wm_enabled, true })
        menu.visuals.wm_unreg_clr  = ot_group:color_picker('\nWM_UNREG_CLR',  100, 100, 255, 255)
            :depend({ menu.shared.tab, 'Visualisation' }, { menu.visuals.wm_enabled, true })

        -- =============== DAMAGE MARKER (ported from Althea) ===============
        menu.visuals.dm_enabled    = ot_group:checkbox('Damage marker')
            :depend({ menu.shared.tab, 'Visualisation' })
        menu.visuals.dm_color_lbl  = ot_group:label('Color')
            :depend({ menu.shared.tab, 'Visualisation' }, { menu.visuals.dm_enabled, true })
        menu.visuals.dm_color      = ot_group:color_picker('\nDM_COLOR', 0, 255, 255, 255)
            :depend({ menu.shared.tab, 'Visualisation' }, { menu.visuals.dm_enabled, true })

        -- =============== AIMBOT LOGS (ported from Althea) =================
        menu.visuals.al_enabled    = ot_group:checkbox('Aimbot logs')
            :depend({ menu.shared.tab, 'Visualisation' })
        menu.visuals.al_select     = ot_group:multiselect('Log selection', { 'Notify', 'Screen', 'Console' })
            :depend({ menu.shared.tab, 'Visualisation' }, { menu.visuals.al_enabled, true })
        menu.visuals.al_hit_lbl    = ot_group:label('Hit color')
            :depend({ menu.shared.tab, 'Visualisation' }, { menu.visuals.al_enabled, true })
        menu.visuals.al_hit_clr    = ot_group:color_picker('\nAL_HIT_CLR',  150, 255, 125, 255)
            :depend({ menu.shared.tab, 'Visualisation' }, { menu.visuals.al_enabled, true })
        menu.visuals.al_miss_lbl   = ot_group:label('Miss color')
            :depend({ menu.shared.tab, 'Visualisation' }, { menu.visuals.al_enabled, true })
        menu.visuals.al_miss_clr   = ot_group:color_picker('\nAL_MISS_CLR', 255, 125, 150, 255)
            :depend({ menu.shared.tab, 'Visualisation' }, { menu.visuals.al_enabled, true })
        menu.visuals.al_glow       = ot_group:slider('Glow',     0, 125, 100, true, '%')
            :depend({ menu.shared.tab, 'Visualisation' }, { menu.visuals.al_enabled, true })
        menu.visuals.al_offset     = ot_group:slider('Offset',  30, 325, 200, true, 'px', 2)
            :depend({ menu.shared.tab, 'Visualisation' }, { menu.visuals.al_enabled, true })
        menu.visuals.al_duration   = ot_group:slider('Duration', 30,  80,  40, true, 's.', 0.1)
            :depend({ menu.shared.tab, 'Visualisation' }, { menu.visuals.al_enabled, true })

        -- =============== SELF-CODE VISUALS (ported) =======================
        -- Damage indicator (value + flag + position), Markers (hit/miss/dmg),
        -- Lagcomp skeleton (duration + color), Bullet tracer (color/thick/dur),
        -- Last seen position (color).
        menu.visuals.di_enabled  = ot_group:checkbox('Damage indicator')
            :depend({ menu.shared.tab, 'Visualisation' })
        menu.visuals.di_type     = ot_group:combobox('\nDI_TYPE', { 'Always on', 'On hotkey' })
            :depend({ menu.shared.tab, 'Visualisation' }, { menu.visuals.di_enabled, true })
        menu.visuals.di_font     = ot_group:combobox('\nDI_FONT', { 'Default', 'Bold', 'Small' })
            :depend({ menu.shared.tab, 'Visualisation' }, { menu.visuals.di_enabled, true })
        menu.visuals.di_x        = ot_group:slider('\nDI_X', 0, 3000, 1000, true, 'px', 1)
            :depend({ menu.shared.tab, 'Visualisation' }, { menu.visuals.di_enabled, true })
        menu.visuals.di_y        = ot_group:slider('\nDI_Y', 0, 2000, 540, true, 'px', 1)
            :depend({ menu.shared.tab, 'Visualisation' }, { menu.visuals.di_enabled, true })

        menu.visuals.mk_enabled  = ot_group:checkbox('Markers')
            :depend({ menu.shared.tab, 'Visualisation' })
        menu.visuals.mk_type     = ot_group:multiselect('\nMK_TYPE', { 'On hit', 'On miss', 'Damage' })
            :depend({ menu.shared.tab, 'Visualisation' }, { menu.visuals.mk_enabled, true })

        menu.visuals.ls_enabled  = ot_group:checkbox('Lagcomp skeleton')
            :depend({ menu.shared.tab, 'Visualisation' })
        menu.visuals.ls_duration = ot_group:slider('\nLS_DUR', 5, 50, 20, true, 's', 0.1)
            :depend({ menu.shared.tab, 'Visualisation' }, { menu.visuals.ls_enabled, true })
        menu.visuals.ls_color_lbl= ot_group:label('Skeleton color')
            :depend({ menu.shared.tab, 'Visualisation' }, { menu.visuals.ls_enabled, true })
        menu.visuals.ls_color    = ot_group:color_picker('\nLS_CLR', 255, 255, 255, 255)
            :depend({ menu.shared.tab, 'Visualisation' }, { menu.visuals.ls_enabled, true })

        menu.visuals.bt_enabled  = ot_group:checkbox('Bullet tracer')
            :depend({ menu.shared.tab, 'Visualisation' })
        menu.visuals.bt_color_lbl= ot_group:label('Tracer color')
            :depend({ menu.shared.tab, 'Visualisation' }, { menu.visuals.bt_enabled, true })
        menu.visuals.bt_color    = ot_group:color_picker('\nBT_CLR', 255, 255, 255, 255)
            :depend({ menu.shared.tab, 'Visualisation' }, { menu.visuals.bt_enabled, true })
        menu.visuals.bt_thick    = ot_group:slider('\nBT_THICK', 1, 5, 1, true, 'px', 1)
            :depend({ menu.shared.tab, 'Visualisation' }, { menu.visuals.bt_enabled, true })
        menu.visuals.bt_duration = ot_group:slider('\nBT_DUR', 1, 100, 10, true, 's', 0.1)
            :depend({ menu.shared.tab, 'Visualisation' }, { menu.visuals.bt_enabled, true })

        menu.visuals.lsn_enabled = ot_group:checkbox('Last seen position')
            :depend({ menu.shared.tab, 'Visualisation' })
        menu.visuals.lsn_color_lbl= ot_group:label('Last seen color')
            :depend({ menu.shared.tab, 'Visualisation' }, { menu.visuals.lsn_enabled, true })
        menu.visuals.lsn_color   = ot_group:color_picker('\nLSN_CLR', 255, 0, 0, 150)
            :depend({ menu.shared.tab, 'Visualisation' }, { menu.visuals.lsn_enabled, true })

        -- Miscellaneous tab (other column)
        menu.misc.clantag      = ot_group:checkbox('\v \rClan tag')
            :depend({ menu.shared.tab, 'Miscellaneous' })
        menu.misc.clantag_text = ot_group:textbox('\nCLANTAG_TEXT')
            :depend({ menu.shared.tab, 'Miscellaneous' }, { menu.misc.clantag, true })

        -- =============== FAST LADDER + ANIMATION BREAKER (ported from Althea) ==
        menu.misc.fast_ladder  = ot_group:checkbox('Fast ladder')
            :depend({ menu.shared.tab, 'Miscellaneous' })

        menu.misc.ab_enabled   = ot_group:checkbox('Animation breaker')
            :depend({ menu.shared.tab, 'Miscellaneous' })
        menu.misc.ab_in_air    = ot_group:combobox('In-air legs', { 'off', 'Static', 'Moonwalk' })
            :depend({ menu.shared.tab, 'Miscellaneous' }, { menu.misc.ab_enabled, true })
        -- in_air static value — только при In-air legs = Static (из althea menu_logic)
        menu.misc.ab_in_air_v  = ot_group:slider('\nAB_INAIR_STATIC', 0, 100, 100, true, '%')
            :depend({ menu.shared.tab, 'Miscellaneous' }, { menu.misc.ab_enabled, true }, { menu.misc.ab_in_air, 'Static' })
        menu.misc.ab_onground  = ot_group:combobox('On-ground legs', { 'off', 'Static', 'Jitter', 'Moonwalk' })
            :depend({ menu.shared.tab, 'Miscellaneous' }, { menu.misc.ab_enabled, true })
        -- min/max value — только при On-ground legs = Jitter (из althea menu_logic)
        menu.misc.ab_min       = ot_group:slider('Min. value', 0, 100, 50, true, '%')
            :depend({ menu.shared.tab, 'Miscellaneous' }, { menu.misc.ab_enabled, true }, { menu.misc.ab_onground, 'Jitter' })
        menu.misc.ab_max       = ot_group:slider('Max. value', 0, 100, 50, true, '%')
            :depend({ menu.shared.tab, 'Miscellaneous' }, { menu.misc.ab_enabled, true }, { menu.misc.ab_onground, 'Jitter' })
        menu.misc.ab_lean      = ot_group:slider('Adjust lean', 0, 100, 0, true, '%', 1, { [0] = 'Off' })
            :depend({ menu.shared.tab, 'Miscellaneous' }, { menu.misc.ab_enabled, true })
        menu.misc.ab_pitch     = ot_group:checkbox('Pitch on land')
            :depend({ menu.shared.tab, 'Miscellaneous' }, { menu.misc.ab_enabled, true })
        menu.misc.ab_quake     = ot_group:checkbox('Earthquake')
            :depend({ menu.shared.tab, 'Miscellaneous' }, { menu.misc.ab_enabled, true })
        -- earthquake value — только при Earthquake = on (из althea menu_logic)
        menu.misc.ab_quake_v   = ot_group:slider('\nAB_QUAKE_V', 1, 100, 100, true, '%')
            :depend({ menu.shared.tab, 'Miscellaneous' }, { menu.misc.ab_enabled, true }, { menu.misc.ab_quake, true })

        -- =============== AUTO BUY + CONSOLE FILTER (ported from Andromeda) ===
        menu.misc.buybot = ot_group:checkbox('Auto buy')
            :depend({ menu.shared.tab, 'Miscellaneous' })
        menu.misc.buybot_main = ot_group:combobox('\vAB \r~ Main weapon', { '-', 'SSG08', 'AWP', 'AUTO' })
            :depend({ menu.shared.tab, 'Miscellaneous' }, { menu.misc.buybot, true })
        menu.misc.buybot_secondary = ot_group:combobox('\vAB \r~ Secondary weapon', { '-', 'Berettas', 'P250', 'Five-seven/Tec-9', 'Heavy pistols' })
            :depend({ menu.shared.tab, 'Miscellaneous' }, { menu.misc.buybot, true })
        menu.misc.buybot_gear = ot_group:multiselect('\vAB \r~ Gear', { 'Zeus', 'Defuse kit', 'Kevlar', 'Helmet', 'Molotov', 'HE', 'Smoke' })
            :depend({ menu.shared.tab, 'Miscellaneous' }, { menu.misc.buybot, true })
        menu.misc.console_filter = ot_group:checkbox('Console filter')
            :depend({ menu.shared.tab, 'Miscellaneous' })

    end

    -- =================================================================
    --  HOME TAB: config system + info labels + session K/D counter
    --  Ported from Andromeda (reference/andromeda  deobfus.lua):
    --    - configs serializer (database/msgpack/base64/clipboard)
    --    - info labels in the fakelag column (User / Script / Type / K-D)
    --    - config management UI in the anti-aim column
    --  ORDER MATTERS: all real settings (antiaim_setup) are built ABOVE
    --  this block, then pui.setup(menu) snapshots them, then the config
    --  management widgets are built AFTER so they are NOT serialized.
    -- =================================================================

    -- --- Home info labels (fakelag column) + session K/D counter -----
    local session = { kills = 0, deaths = 0 }
    menu.shared.label_user    = fl_group:label('\v \a7D7D7DFFUser  \v' .. package.user)
        :depend({ menu.shared.tab, 'Home' })
    menu.shared.label_script  = fl_group:label('\v \a7D7D7DFFScript  \v' .. package.scriptname)
        :depend({ menu.shared.tab, 'Home' })
    menu.shared.label_build   = fl_group:label('\v \a7D7D7DFFType  \v' .. package.build)
        :depend({ menu.shared.tab, 'Home' })
    menu.shared.label_session = fl_group:label('\v \a7D7D7DFFSession K/D  \v0 / 0  \a7D7D7DFF(0.00)')
        :depend({ menu.shared.tab, 'Home' })

    local function update_session_label()
        local ratio = session.deaths > 0 and (session.kills / session.deaths) or session.kills
        menu.shared.label_session:set(string.format('\v \a7D7D7DFFSession K/D  \v%d / %d  \a7D7D7DFF(%.2f)', session.kills, session.deaths, ratio))
    end

    client.set_event_callback('player_death', function(e)
        local me = entity.get_local_player()
        if not me then return end

        local victim   = client.userid_to_entindex(e.userid)
        local attacker = client.userid_to_entindex(e.attacker)

        if victim == me then
            session.deaths = session.deaths + 1
            update_session_label()
        elseif attacker == me then
            session.kills = session.kills + 1
            update_session_label()
        end
    end)

    -- --- Serializer snapshot over all real settings built above ------
    menu.config = pui.setup(menu)


end

-- Hide stock cheat AA checkboxes (angles/fakelag/other) while the menu is open,
-- so only the Lua menu items remain. Ported from Andromeda (paint_ui + pui.traverse).
client.set_event_callback('paint_ui', function()
    if not ui.is_menu_open() then return end

    pui.traverse(interface.reference.angles,          function(e) e:set_visible(false) end)
    pui.traverse(interface.reference.fakelag,         function(e) e:set_visible(false) end)
    -- Скрываем все gamesense-нативные AA рефы (Slow motion, Leg movement,
    -- On shot anti-aim, Fake peek) на в��ех вкладках — Other-колонка
    -- на Home/Aimbot/Visualisation/Miscellaneous остаётся пустой,
    -- а на Anti-aimbot показываются только Lunaris-овские пункты.
    pui.traverse(interface.reference.other, function(e) e:set_visible(false) end)
end)

-- =====================================================================
--  Credits widget: два label’а в колонке Other, стиль скита
--  (<3 красный, остальное белым че��ез inline \a-escape).
--  Принудительно set_visible(true) каждый paint_ui, чтобы traverse-
--  логика выше их не погасила.
-- =====================================================================
local credits_a = interface.tab.other:label(' ')
local credits_b = interface.tab.other:label(' ')

local function _set_label(lbl, text)
    if not pcall(function() lbl:update(text) end) then
        pcall(function() lbl:set(text) end)
    end
end

-- Credits должны показываться ТОЛЬКО на вкладке Home. На люб��й другой
-- вкладке (Anti-aim / Visualisation / Miscellaneous / Configs) их прячем.
local function _get_active_tab()
    local ok, v = pcall(function() return menu.shared.tab:get() end)
    if ok then return v end
    return nil
end

client.set_event_callback('paint_ui', function()
    if not ui.is_menu_open() then return end

    local on_home = (_get_active_tab() == 'Home')
    pcall(function() credits_a:set_visible(on_home) end)
    pcall(function() credits_b:set_visible(on_home) end)
    if not on_home then return end

    -- Розовые сердечки, белый текст (через \r сброс формата).
    local hex = 'FF5CA8FF'  -- pink

    _set_label(credits_a, '\a' .. hex .. '<3\r Author alexandrow & Pavidlo1555')
    _set_label(credits_b, '\a' .. hex .. '<3\r Thank you for using this lua')
end)



-- =====================================================================
--  VISUALISATION: aimbot hit/miss logs   (priora-style fields)
--  MISCELLANEOUS: animated clan tag       (priora net_update cycling)
--  Menu items live in the setup block above (menu.visuals.logs* and
--  menu.misc.clantag*); this block is the runtime that drives them.
-- =====================================================================
do
    -- ===================================================================
    --  1:1 ALTHEA PORT  (world_marker + damage_marker + aimbot_logs)
    --  All logic, timings, animations and rendering copied from
    --  althea.lua verbatim; only menu refs are re-wired to pui widgets
    --  via a local `ref = { ... }` table per feature.
    -- ===================================================================

    -- ---------------- compat helpers (also lifted from althea) --------
    local function round(x) return math.floor(x + 0.5) end

    -- minimal vector compat with operator metamethods
    local vector_mt = {}
    vector_mt.__index = vector_mt
    local function vector(x, y, z)
        if type(x) == 'table' then x, y, z = x[1], x[2], x[3] end
        return setmetatable({ x = x or 0, y = y or 0, z = z or 0 }, vector_mt)
    end
    function vector_mt:clone()  return vector(self.x, self.y, self.z) end
    function vector_mt:unpack() return self.x, self.y, self.z end
    vector_mt.__add = function(a, b)
        if type(b) == 'number' then return vector(a.x + b, a.y + b, a.z + b) end
        return vector(a.x + b.x, a.y + b.y, a.z + b.z)
    end
    vector_mt.__sub = function(a, b)
        if type(b) == 'number' then return vector(a.x - b, a.y - b, a.z - b) end
        return vector(a.x - b.x, a.y - b.y, a.z - b.z)
    end
    vector_mt.__mul = function(a, b)
        if type(a) == 'number' then return vector(a * b.x, a * b.y, a * b.z) end
        if type(b) == 'number' then return vector(a.x * b, a.y * b, a.z * b) end
        return vector(a.x * b.x, a.y * b.y, a.z * b.z)
    end
    vector_mt.__div = function(a, b)
        if type(b) == 'number' then return vector(a.x / b, a.y / b, a.z / b) end
        return vector(a.x / b.x, a.y / b.y, a.z / b.z)
    end

    -- minimal color compat (althea uses ffi cdata; for our purposes a
    -- table with r,g,b,a and :unpack is enough)
    local color_mt = {}
    color_mt.__index = color_mt
    function color_mt:unpack() return self.r, self.g, self.b, self.a end
    local function color(r, g, b, a)
        return setmetatable({ r = r or 0, g = g or 0, b = b or 0, a = a or 255 }, color_mt)
    end

    -- utils.* (clamp / lerp / map / from_hex / to_hex / event_callback)
    local utils = {}
    function utils.clamp(x, mn, mx) return math.max(mn, math.min(x, mx)) end
    function utils.lerp(a, b, t) return a + t * (b - a) end
    function utils.inverse_lerp(a, b, x) return (x - a) / (b - a) end
    function utils.map(x, in_min, in_max, out_min, out_max, should_clamp)
        if should_clamp then x = utils.clamp(x, in_min, in_max) end
        return utils.lerp(out_min, out_max, utils.inverse_lerp(in_min, in_max, x))
    end
    function utils.from_hex(hex)
        hex = string.gsub(hex, '#', '')
        local r = tonumber(string.sub(hex, 1, 2), 16)
        local g = tonumber(string.sub(hex, 3, 4), 16)
        local b = tonumber(string.sub(hex, 5, 6), 16)
        local a = tonumber(string.sub(hex, 7, 8), 16)
        return r, g, b, a or 255
    end
    function utils.to_hex(r, g, b, a)
        return string.format('%02x%02x%02x%02x', r, g, b, a)
    end
    function utils.event_callback(event_name, cb, value)
        assert(cb ~= nil, 'Callback is nil')
        local fn = value and client.set_event_callback or client.unset_event_callback
        fn(event_name, cb)
    end

    -- motion.interp (frametime-stepped linear easing toward target)
    local motion = {}
    local function _easing_linear(t, b, c, d) return c * t / d + b end
    local function _motion_solve(easing_fn, prev, new, clock, duration)
        if clock <= 0 then return new end
        if clock >= duration then return new end
        prev = easing_fn(clock, prev, new - prev, duration)
        if type(prev) == 'number' then
            if math.abs(new - prev) < 0.001 then return new end
            local rem = prev % 1.0
            if rem < 0.001 then return math.floor(prev) end
            if rem > 0.999 then return math.ceil(prev)  end
        end
        return prev
    end
    function motion.interp(a, b, t, easing_fn)
        easing_fn = easing_fn or _easing_linear
        if type(b) == 'boolean' then b = b and 1 or 0 end
        return _motion_solve(easing_fn, a, b, globals.frametime(), t)
    end

    -- render.rectangle (radius) and render.glow
    local render = {}
    local function _interp_colors(c1, c2, factor)
        local out, c3 = {}, { c1[1], c1[2], c1[3], c1[4] }
        for i = 1, 4 do
            out[i] = tonumber(('%.0f'):format(c3[i] + factor * (c2[i] - c1[i])))
        end
        return out
    end
    local function _interp_colors_range(c1, c2, steps)
        local f, out = 1 / (steps - 1), {}
        for i = 0, steps - 1 do out[i + 1] = _interp_colors(c1, c2, f * i) end
        return out
    end
    function render.glow(x, y, w, h, r, g, b, a, radius, steps, range)
        steps = math.max(2, steps)
        range = range or 1.0
        local th = 1
        local cols = _interp_colors_range({ r, g, b, 0 }, { r, g, b, a * range }, steps)
        for i = 1, steps do
            local c  = cols[i]
            local cr = cols[steps - i + 1]
            renderer.circle_outline(x + radius,     y + radius,     c[1], c[2], c[3], c[4], radius + th + (steps - i), 180, 0.25, 1)
            renderer.circle_outline(x + w - radius, y + radius,     c[1], c[2], c[3], c[4], radius + th + (steps - i), 270, 0.25, 1)
            renderer.circle_outline(x + w - radius, y + h - radius, c[1], c[2], c[3], c[4], radius + th + (steps - i),   0, 0.25, 1)
            renderer.circle_outline(x + radius,     y + h - radius, c[1], c[2], c[3], c[4], radius + th + (steps - i),  90, 0.25, 1)
            renderer.rectangle(x + w + i - 1, y + radius, 1, h - 2 * radius, cr[1], cr[2], cr[3], cr[4])
            renderer.rectangle(x - i,         y + radius, 1, h - 2 * radius, cr[1], cr[2], cr[3], cr[4])
            renderer.rectangle(x + radius, y - i,         w - 2 * radius, 1, cr[1], cr[2], cr[3], cr[4])
            renderer.rectangle(x + radius, y + h + i - 1, w - 2 * radius, 1, cr[1], cr[2], cr[3], cr[4])
        end
    end
    function render.rectangle(x, y, w, h, r, g, b, a, radius)
        radius = math.min(radius, w / 2, h / 2)
        local r2 = radius * 2
        renderer.rectangle(x + radius,     y,              w - r2, h,      r, g, b, a)
        renderer.rectangle(x,              y + radius,     radius, h - r2, r, g, b, a)
        renderer.rectangle(x + w - radius, y + radius,     radius, h - r2, r, g, b, a)
        renderer.circle(x + radius,     y + radius,     r, g, b, a, radius, 180, 0.25)
        renderer.circle(x + radius,     y + h - radius, r, g, b, a, radius, 270, 0.25)
        renderer.circle(x + w - radius, y + radius,     r, g, b, a, radius,  90, 0.25)
        renderer.circle(x + w - radius, y + h - radius, r, g, b, a, radius,   0, 0.25)
    end

    -- text_anims.gradient (per-char animated gradient via \aRRGGBBAA)
    local text_anims = {}
    local function _u8(str)
        local chars, count = {}, 0
        for c in string.gmatch(str, '.[\128-\191]*') do
            count = count + 1; chars[count] = c
        end
        return chars, count
    end
    function text_anims.gradient(str, time, r1, g1, b1, a1, r2, g2, b2, a2)
        local list = {}
        local strbuf, strlen = _u8(str)
        if strlen <= 1 then return str end
        local div = 1 / (strlen - 1)
        local dr, dg, db, da = r2 - r1, g2 - g1, b2 - b1, a2 - a1
        for i = 1, strlen do
            local char = strbuf[i]
            local t = time % 2
            if t > 1 then t = 2 - t end
            local r = r1 + t * dr
            local g = g1 + t * dg
            local b = b1 + t * db
            local a = a1 + t * da
            list[#list + 1] = '\a'
            list[#list + 1] = utils.to_hex(r, g, b, a)
            list[#list + 1] = char
            time = time + div
        end
        return table.concat(list)
    end

    -- text_fmt.color (split a \aHHHHHHHH-tagged string into {text,hex} list)
    local text_fmt = {}
    local function _decompose(str)
        local result, len = {}, #str
        local i, j = str:find('\a', 1, true)
        if i == nil then
            table.insert(result, { str, nil })
        end
        if i ~= nil and i > 1 then
            table.insert(result, { str:sub(1, i - 1), nil })
        end
        while i ~= nil do
            local hex = nil
            if str:sub(j + 1, j + 7) == 'DEFAULT' then
                j = j + 8
            else
                hex = str:sub(j + 1, j + 8)
                j = j + 9
            end
            local m, n = str:find('\a', j + 1, true)
            if m == nil then
                if j <= len then
                    table.insert(result, { str:sub(j), hex })
                end
                break
            end
            table.insert(result, { str:sub(j, m - 1), hex })
            i, j = m, n
        end
        return result
    end
    function text_fmt.color(str)
        local list = _decompose(str)
        return list, #list
    end

    -- =========================================================== WORLD MARKER
    -- 1:1 from althea.lua (~line 11503).
    local world_marker do
        local ref = {
            enabled          = menu.visuals.wm_enabled,
            style            = menu.visuals.wm_style,
            size             = menu.visuals.wm_size,
            show_miss_reason = menu.visuals.wm_miss_rsn,
            ['hit']                = { picker = menu.visuals.wm_hit_clr    },
            ['?']                  = { picker = menu.visuals.wm_quest_clr  },
            ['spread']             = { picker = menu.visuals.wm_spread_clr },
            ['prediction error']   = { picker = menu.visuals.wm_pred_clr   },
            ['death']              = { picker = menu.visuals.wm_death_clr  },
            ['unregistered shot']  = { picker = menu.visuals.wm_unreg_clr  },
        }

        local queue    = { }
        local aim_data = { }

        local function draw_plus(x, y, size, r, g, b, a)
            renderer.line(x - size, y, x - size * 2, y, r, g, b, a)
            renderer.line(x + size, y, x + size * 2, y, r, g, b, a)
            renderer.line(x, y - size, x, y - size * 2, r, g, b, a)
            renderer.line(x, y + size, x, y + size * 2, r, g, b, a)
        end

        local function draw_cross(x, y, size, r, g, b, a)
            renderer.line(x - size * 2, y - size * 2, x - size, y - size, r, g, b, a)
            renderer.line(x - size * 2, y + size * 2, x - size, y + size, r, g, b, a)
            renderer.line(x + size * 2, y - size * 2, x + size, y - size, r, g, b, a)
            renderer.line(x + size * 2, y + size * 2, x + size, y + size, r, g, b, a)
        end

        local function get_drawing()
            local style = ref.style:get()
            if style == 'Plus'  then return draw_plus  end
            if style == 'Cross' then return draw_cross end
            return nil
        end

        local function on_paint()
            local drawing = get_drawing()
            if drawing == nil then return end

            local size = ref.size:get()
            local dt = globals.frametime()

            for i = #queue, 1, -1 do
                local data = queue[i]
                data.time = data.time - dt
                if data.time <= 0.0 then
                    data.alpha = motion.interp(data.alpha, 0.0, 0.05)
                    if data.alpha <= 0.0 then
                        table.remove(queue, i)
                    end
                end
            end

            for i = 1, #queue do
                local data = queue[i]
                local x, y = renderer.world_to_screen(data.pos:unpack())
                if x == nil or y == nil then
                    goto continue
                end

                local col

                if data.type == 'hit' then
                    col = color(ref['hit'].picker:get())
                end

                if data.type == 'miss' then
                    local color_data = ref[data.reason]
                    col = color(255, 0, 0, 255)
                    if color_data ~= nil then
                        col = color(color_data.picker:get())
                        if ref.show_miss_reason:get() then
                            local flags, text = 'd', data.reason
                            local tw, th = renderer.measure_text(flags, text)
                            local text_size = vector(tw, th, 0)
                            renderer.text(x + size * 2 + 1, y - text_size.y / 2 - 1, col.r, col.g, col.b, col.a * data.alpha, flags, nil, text)
                        end
                    end
                end

                drawing(x, y, size, col.r, col.g, col.b, col.a * data.alpha)

                ::continue::
            end
        end

        local function on_aim_fire(e)
            aim_data[e.id] = vector(e.x, e.y, e.z)
        end

        local function on_aim_hit(e)
            local pos = aim_data[e.id]
            if pos == nil then return end
            table.insert(queue, {
                type = 'hit', reason = nil, pos = pos,
                time = 1.5, alpha = 1.0,
            })
        end

        local function on_aim_miss(e)
            local pos = aim_data[e.id]
            if pos == nil then return end
            table.insert(queue, {
                type = 'miss', reason = e.reason, pos = pos,
                time = 1.5, alpha = 1.0,
            })
        end

        local function on_round_start()
            for i = 1, #queue do queue[i] = nil end
        end

        local function update_event_callbacks(value)
            utils.event_callback('paint',       on_paint,       value)
            utils.event_callback('aim_hit',     on_aim_hit,     value)
            utils.event_callback('aim_miss',    on_aim_miss,    value)
            utils.event_callback('aim_fire',    on_aim_fire,    value)
            utils.event_callback('round_start', on_round_start, value)
        end

        local function on_enabled(item) update_event_callbacks(item:get()) end
        ref.enabled:set_callback(on_enabled, true)
    end

    -- ========================================================== DAMAGE MARKER
    -- 1:1 from althea.lua (~line 11671).
    local damage_marker do
        local ref = {
            enabled = menu.visuals.dm_enabled,
            color   = menu.visuals.dm_color,
        }
        local queue    = { }
        local aim_data = { }

        local function on_paint()
            local dt = globals.frametime()
            local r, g, b, a = ref.color:get()

            for i = #queue, 1, -1 do
                local data = queue[i]
                data.time  = data.time - dt
                data.pos.z = data.pos.z + dt * 35
                data.value = motion.interp(data.value, 1.0, 0.1)
                if data.time <= 0.0 then
                    data.alpha = motion.interp(data.alpha, 0.0, 0.05)
                    if data.alpha <= 0.0 then
                        table.remove(queue, i)
                    end
                end
            end

            for i = 1, #queue do
                local data = queue[i]
                local x, y = renderer.world_to_screen(data.pos:unpack())
                if x == nil or y == nil then goto continue end
                local damage = math.floor(data.damage * data.value)
                renderer.text(x, y, r, g, b, a * data.alpha, 'bc', nil, damage)
                ::continue::
            end
        end

        local function on_aim_fire(e)
            aim_data[e.id] = vector(e.x, e.y, e.z)
        end

        local function on_aim_hit(e)
            local pos = aim_data[e.id]
            if pos == nil then return end
            table.insert(queue, {
                pos    = pos:clone(),
                time   = 3.0,
                value  = 0.0,
                alpha  = 1.0,
                damage = e.damage,
            })
        end

        local function on_round_start()
            for i = 1, #queue do queue[i] = nil end
        end

        local function update_event_callbacks(value)
            utils.event_callback('paint',       on_paint,       value)
            utils.event_callback('aim_hit',     on_aim_hit,     value)
            utils.event_callback('aim_fire',    on_aim_fire,    value)
            utils.event_callback('round_start', on_round_start, value)
        end

        local function on_enabled(item) update_event_callbacks(item:get()) end
        ref.enabled:set_callback(on_enabled, true)
    end

    -- =========================================================== AIMBOT LOGS
    -- 1:1 from althea.lua (~line 8555).
    local aimbot_logs do
        local ref = {
            enabled    = menu.visuals.al_enabled,
            select     = menu.visuals.al_select,
            color_hit  = menu.visuals.al_hit_clr,
            color_miss = menu.visuals.al_miss_clr,
            glow       = menu.visuals.al_glow,
            offset     = menu.visuals.al_offset,
            duration   = menu.visuals.al_duration,
        }

        local PADDING_W   = 8
        local PADDING_H   = 6
        local GAP_BETWEEN = 4

        local e_hitgroup = {
            [0]  = 'generic',
            [1]  = 'head',
            [2]  = 'chest',
            [3]  = 'stomach',
            [4]  = 'left arm',
            [5]  = 'right arm',
            [6]  = 'left leg',
            [7]  = 'right leg',
            [8]  = 'neck',
            [10] = 'gear',
        }

        local hurt_weapons = {
            ['c4']           = 'bombed',
            ['knife']        = 'knifed',
            ['decoy']        = 'decoyed',
            ['inferno']      = 'burned',
            ['molotov']      = 'harmed',
            ['flashbang']    = 'harmed',
            ['hegrenade']    = 'naded',
            ['incgrenade']   = 'harmed',
            ['smokegrenade'] = 'harmed',
        }

        local log_glow     = 0
        local log_offset   = 0
        local log_duration = 5

        local fire_data    = { }
        local draw_queue   = { }
        local notify_queue = { }

        local function remove_hex(str)
            local result = string.gsub(str, '\a%x%x%x%x%x%x%x%x', '')
            return result
        end

        local function clear_draw_queue()
            for i = 1, #draw_queue do draw_queue[i] = nil end
        end

        local function clear_notify_queue()
            for i = 1, #notify_queue do notify_queue[i] = nil end
        end

        local function add_log(r, g, b, a, text)
            if not ref.select:get 'Screen' then return end
            local time = log_duration
            local id   = #draw_queue + 1
            local col  = { r, g, b, a }
            text = remove_hex(text)
            draw_queue[id] = {
                text  = text,
                color = col,
                time  = time,
                alpha = 0.0,
            }
            return id
        end

        local function notify_log(r, g, b, a, text)
            if not ref.select:get 'Notify' then return end
            local list, count = text_fmt.color(text)
            for i = 1, count do
                local value = list[i]
                local hex   = value[2]
                if hex == nil then hex = utils.to_hex(r, g, b, a) end
                value[2] = color(utils.from_hex(hex))
            end
            table.insert(notify_queue, {
                time  = 7.0,
                alpha = 1.0,
                list  = list,
                count = count,
            })
            if #notify_queue > 7 then
                table.remove(notify_queue, 1)
            end
        end

        local function console_log(r, g, b, text)
            if not ref.select:get 'Console' then return end
            local list, count = text_fmt.color(text)
            for i = 1, count do
                local value = list[i]
                local str   = value[1]
                local hex   = value[2]
                if i ~= count then str = str .. '\0' end
                if hex == nil then
                    client.color_log(r, g, b, str)
                    goto continue
                end
                local hr, hg, hb = utils.from_hex(hex)
                client.color_log(hr, hg, hb, str)
                ::continue::
            end
        end

        local function format_text(text, hex_a, hex_b)
            local result = string.gsub(text, '${(.-)}', string.format('\a%s%%1\a%s', hex_a, hex_b))
            if result:sub(1, 1) ~= '\a' then
                result = '\a' .. hex_b .. result
            end
            return result
        end

        local function draw_box(x, y, w, h, r1, g1, b1, a1, r2, g2, b2, a2, alpha)
            local radius = 8
            if log_glow > 0 then
                local glow_alpha = utils.map(log_glow, 0.0, 1.5, 0, a2 * 0.5, true)
                render.glow(x, y, w, h, r2, g2, b2, glow_alpha * alpha, radius, round(8 * log_glow))
            end
            render.rectangle(x, y, w, h, r1, g1, b1, a1 * alpha, radius)
        end

        local function paint_notify()
            local dt = globals.frametime()
            local position = vector(8, 5, 0)
            local flags = ''

            for i = #notify_queue, 1, -1 do
                local data = notify_queue[i]
                data.time = data.time - dt
                if data.time <= 0.0 then
                    data.alpha = motion.interp(data.alpha, 0.0, 0.075)
                    if data.alpha <= 0.0 then
                        table.remove(notify_queue, i)
                    end
                end
            end

            for i = 1, #notify_queue do
                local data = notify_queue[i]
                local list  = data.list
                local count = data.count
                local alpha = data.alpha
                local text_pos = position:clone()

                for j = 1, count do
                    local value = list[j]
                    local text  = value[1]
                    local col   = value[2]
                    local tw, th = renderer.measure_text(flags, text)
                    renderer.text(text_pos.x, text_pos.y, col.r, col.g, col.b, col.a * alpha, flags, nil, text)
                    text_pos.x = text_pos.x + tw
                end

                position.y = position.y + 14 * alpha
            end
        end

        local function paint_screen()
            local r0, g0, b0, a0 = 18, 18, 18, 225
            local time = globals.realtime()
            local dt   = globals.frametime()
            local len  = #draw_queue

            local sw, sh = client.screen_size()
            local screen_size = vector(sw, sh, 0)

            local position = screen_size / 2 do
                position.y = position.y + log_offset
            end

            local icon_text  = '\xE2\x9C\xA8'  -- ✨
            local icon_flags = ''
            local itw, ith = renderer.measure_text(icon_flags, icon_text)
            local icon_size = vector(itw, ith, 0)

            for i = len, 1, -1 do
                local data = draw_queue[i]
                local is_life = data.time > 0 and (len - i) < 6
                data.alpha = motion.interp(data.alpha, is_life, 0.075)
                if is_life then
                    data.time = data.time - dt
                else
                    if data.alpha <= 0.0 then
                        table.remove(draw_queue, i)
                    end
                end
            end

            local flags = ''
            for i = 1, #draw_queue do
                local data = draw_queue[i]
                local r, g, b, a = unpack(data.color)
                local text, alpha = data.text, data.alpha

                local tw, th = renderer.measure_text(flags, text)
                local text_size = vector(tw, th, 0)
                local box_size  = text_size + vector(PADDING_W, PADDING_H, 0) * 2

                if icon_text ~= nil then
                    box_size.x = box_size.x + icon_size.x + GAP_BETWEEN
                end

                local box_pos  = position - box_size / 2
                local text_pos = box_pos + vector(PADDING_W, PADDING_H, 0)
                local icon_pos = vector(text_pos.x, box_pos.y + (box_size.y - icon_size.y) / 2, 0)

                draw_box(box_pos.x, box_pos.y, box_size.x + 5, box_size.y, r0, g0, b0, a0, r, g, b, a * 0.34, alpha / 4)

                if icon_text ~= nil then
                    renderer.text(icon_pos.x, icon_pos.y - 1, r, g, b, a * alpha, icon_flags, nil, icon_text)
                    text_pos.x = text_pos.x + icon_size.x + GAP_BETWEEN
                end

                text_pos.y = box_pos.y + (box_size.y - text_size.y) / 2
                text = text_anims.gradient(text, time, 255, 255, 255, 200 * alpha, r, g, b, a * alpha)

                renderer.text(text_pos.x, text_pos.y, 255, 255, 255, 200 * alpha, flags, nil, text)

                position.y = position.y - round((box_size.y + 8) * alpha)
            end
        end

        local function on_aim_hit(e)
            local data = fire_data[e.id]
            if data == nil then return end
            local target = e.target
            if target == nil then return end

            local r, g, b, a = ref.color_hit:get()

            local player_name   = entity.get_player_name(target) or 'unknown'
            local player_health = entity.get_prop(target, 'm_iHealth') or 0

            local hit_chance  = e.hit_chance or 0
            local aim_history = data.history or 0

            local damage     = e.damage or 0
            local aim_damage = (data.aim and data.aim.damage) or 0

            local hitgroup     = e_hitgroup[e.hitgroup] or '?'
            local aim_hitgroup = e_hitgroup[data.aim and data.aim.hitgroup] or '?'

            local details = { } do
                table.insert(details, string.format('hc: ${%d%%}', hit_chance))
                table.insert(details, string.format('bt: ${%dt}', aim_history))
            end

            local screen_text
            if player_health == 0 then
                screen_text = string.format('Killed ${%s} in ${%s} for ${%s} damage (%s)', player_name, hitgroup, damage, table.concat(details, ' \xE2\x88\x99 '))
            else
                screen_text = string.format('Hit ${%s} in ${%s} for ${%s} damage (${%d} hp remaining \xE2\x88\x99 %s)', player_name, hitgroup, damage, player_health, table.concat(details, ' \xE2\x88\x99 '))
            end

            local console_text
            if player_health == 0 then
                console_text = string.format('Killed ${%s} in ${%s} for ${%s} damage (%s)', player_name, hitgroup, damage, table.concat(details, ' \xE2\x88\x99 '))
            else
                console_text = string.format('Hit ${%s} in ${%s} for ${%s} damage (${%d} hp remaining \xE2\x88\x99 %s)', player_name, hitgroup, damage, player_health, table.concat(details, ' \xE2\x88\x99 '))
            end

            screen_text  = format_text(screen_text,  utils.to_hex(r, g, b, a), 'c8c8c8ff')
            console_text = format_text(console_text, utils.to_hex(r, g, b, a), 'c8c8c8ff')

            add_log(r, g, b, a, screen_text)
            notify_log(255, 255, 255, 255, console_text)
            console_log(255, 255, 255, console_text)
        end

        local function on_aim_miss(e)
            local data = fire_data[e.id]
            if data == nil then return end
            local target = e.target
            if target == nil then return end

            local r, g, b, a = ref.color_miss:get()

            local player_name  = entity.get_player_name(target) or 'unknown'
            local miss_reason  = e.reason or '?'
            local hit_chance   = e.hit_chance or 0
            local aim_history  = data.history or 0
            local aim_hitgroup = e_hitgroup[data.aim and data.aim.hitgroup] or '?'

            local details = { } do
                table.insert(details, string.format('hc: ${%d%%}', hit_chance))
                table.insert(details, string.format('bt: ${%dt}', aim_history))
            end

            local screen_text  = string.format('Missed ${%s} in ${%s} due to ${%s} (%s)', player_name, aim_hitgroup, miss_reason, table.concat(details, ' \xE2\x88\x99 '))
            local console_text = string.format('Missed ${%s} in ${%s} due to ${%s} (%s)', player_name, aim_hitgroup, miss_reason, table.concat(details, ' \xE2\x88\x99 '))

            screen_text  = format_text(screen_text,  utils.to_hex(r, g, b, a), 'c8c8c8ff')
            console_text = format_text(console_text, utils.to_hex(r, g, b, a), 'c8c8c8ff')

            add_log(r, g, b, a, screen_text)
            notify_log(255, 255, 255, 255, console_text)
            console_log(255, 255, 255, console_text)
        end

        local function on_aim_fire(e)
            local history = globals.tickcount() - (e.tick or globals.tickcount())
            fire_data[e.id] = {
                aim     = e,
                safe    = false,
                history = history,
            }
        end

        local function on_player_hurt(e)
            local me       = entity.get_local_player()
            local userid   = client.userid_to_entindex(e.userid)
            local attacker = client.userid_to_entindex(e.attacker)

            if attacker ~= me or userid == me then return end

            local weapon = e.weapon
            local action = hurt_weapons[weapon]
            if action == nil then return end

            local r, g, b, a = ref.color_hit:get()
            local player_name = entity.get_player_name(userid) or 'unknown'
            local damage = e.dmg_health or 0

            local screen_text  = string.format('%s ${%s} for ${%d} dmg', action, player_name, damage)
            local console_text = string.format('%s ${%s} for ${%d} dmg', action, player_name, damage)

            screen_text  = format_text(screen_text,  utils.to_hex(r, g, b, a), 'c8c8c8ff')
            console_text = format_text(console_text, utils.to_hex(r, g, b, a), 'c8c8c8ff')

            add_log(r, g, b, a, screen_text)
            notify_log(255, 255, 255, 255, console_text)
            console_log(255, 255, 255, console_text)
        end

        local function on_glow(item)     log_glow     = item:get() * 0.01 end
        local function on_offset(item)   log_offset   = item:get() * 2    end
        local function on_duration(item) log_duration = item:get() * 0.1  end

        local function on_select(item)
            local is_notify = item:get 'Notify'
            local is_screen = item:get 'Screen'

            if is_screen then
                ref.glow:set_callback(on_glow, true)
                ref.offset:set_callback(on_offset, true)
                ref.duration:set_callback(on_duration, true)
            else
                pcall(function() ref.glow:unset_callback(on_glow) end)
                pcall(function() ref.offset:unset_callback(on_offset) end)
                pcall(function() ref.duration:unset_callback(on_duration) end)
            end

            if not is_notify then clear_notify_queue() end
            if not is_screen then clear_draw_queue()   end

            utils.event_callback('paint', paint_notify, is_notify)
            utils.event_callback('paint', paint_screen, is_screen)
        end

        local function on_enabled(item)
            local value = item:get()

            if value then
                ref.select:set_callback(on_select, true)
            else
                pcall(function() ref.select:unset_callback(on_select) end)
            end

            if not value then
                pcall(function() ref.glow:unset_callback(on_glow) end)
                pcall(function() ref.offset:unset_callback(on_offset) end)
                pcall(function() ref.duration:unset_callback(on_duration) end)

                utils.event_callback('paint', paint_notify, false)
                utils.event_callback('paint', paint_screen, false)

                clear_draw_queue()
                clear_notify_queue()
            end

            utils.event_callback('aim_hit',     on_aim_hit,     value)
            utils.event_callback('aim_miss',    on_aim_miss,    value)
            utils.event_callback('aim_fire',    on_aim_fire,    value)
            utils.event_callback('player_hurt', on_player_hurt, value)
        end

        ref.enabled:set_callback(on_enabled, true)
    end

    -- ============================================ ANDROMEDA VISUAL RUNTIME
    -- Thirdperson, Aspect ratio, Proper Viewmodel, FOV Animation.
    -- Все четыре блока — порт 1:1 из andromeda (см. visuals секцию там).
    -- Каждый блок изолирован своим do ... end, чтобы падение одного не
    -- ломало остальные.

    -- Thirdperson: подменяем cam_idealdist + c_min/maxdistance.
    do
        local switch = menu.visuals.thirdperson
        local state = false
        local cam_idealdist = cvar.cam_idealdist
        local c_mindistance = cvar.c_mindistance
        local c_maxdistance = cvar.c_maxdistance
        local cam_backup = tonumber(cam_idealdist:get_string())
        local cmin_backup = tonumber(c_mindistance:get_string())
        local cmax_backup = tonumber(c_maxdistance:get_string())
        local distance = 150

        local function shutdown()
            cam_idealdist:set_int(cam_backup)
            c_mindistance:set_int(cmin_backup)
            c_maxdistance:set_int(cmax_backup)
        end

        local function apply()
            if not state then return end
            cam_idealdist:set_int(distance)
            c_mindistance:set_int(distance)
            c_maxdistance:set_int(distance)
        end

        menu.visuals.tp_dist:set_callback(function(it) distance = it:get(); apply() end, true)
        switch:set_callback(function(it)
            state = it:get()
            if not state then shutdown() else apply() end
        end, true)
        client.set_event_callback('shutdown', shutdown)
    end

    -- Aspect ratio: подменяем r_aspectratio.
    do
        local switch = menu.visuals.aspect_ratio
        local state = false
        local r_aspectratio = cvar.r_aspectratio
        local default_ratio = tonumber(r_aspectratio:get_string()) or 0
        local ratio_value = 1.7

        local function shutdown() r_aspectratio:set_float(default_ratio) end
        local function apply()
            if not state then return end
            r_aspectratio:set_float(ratio_value)
        end

        menu.visuals.ap_dist:set_callback(function(it) ratio_value = it:get() * 0.01; apply() end, true)
        switch:set_callback(function(it)
            state = it:get()
            if not state then shutdown() else apply() end
        end, true)
        client.set_event_callback('shutdown', shutdown)
    end

    -- Proper Viewmodel: viewmodel_fov / offset_x/y/z + scope hide.
    -- ffi-сигнатура hide_vm_scope (CCSWeaponInfo) обёрнута в pcall, чтобы
    -- при будущем смещении сигнатуры прост���� отключилась только эта часть.
    do
        local ok_vm, vm_state = pcall(function()
            local s = {}
            s.classptr       = ffi.typeof('void***')
            s.client_entity  = ffi.typeof('void*(__thiscall*)(void*, int)')
            ffi.cdef('typedef struct { float x; float y; float z; } vmodel_vec3_t;')
            s.set_angles_t   = ffi.typeof('void(__thiscall*)(void*, const vmodel_vec3_t&)')

            local ccsweaponinfo_t = [[
                struct {
                    char  __pad_0x0000[0x1cd];
                    bool  hide_vm_scope;
                }
            ]]

            local match = client.find_signature('client_panorama.dll',
                '\x8B\x35\xCC\xCC\xCC\xCC\xFF\x10\x0F\xB7\xC0')
            local weaponsystem_raw = ffi.cast('void****', ffi.cast('char*', match) + 2)[0]

            -- Mini vtable_thunk replacement (index, ctype) — index 2 is the
            -- GetWeaponInfo method on the WeaponSystem singleton.
            local function vtable_thunk(idx, ctype)
                local cast = ffi.typeof(ctype)
                return function(obj, ...)
                    local fn = ffi.cast(cast, ffi.cast('void***', obj)[0][idx])
                    return fn(obj, ...)
                end
            end
            s.get_weapon_info = vtable_thunk(2, ccsweaponinfo_t .. '*(__thiscall*)(void*, unsigned int)')
            s.weaponsystem_raw = weaponsystem_raw

            local rawelist = client.create_interface('client_panorama.dll', 'VClientEntityList003')
                or error 'VClientEntityList003 missing'
            local ientitylist = ffi.cast(s.classptr, rawelist)
            s.get_client_entity = ffi.cast(s.client_entity, ientitylist[0][3])
            s.ientitylist = ientitylist

            local sa = client.find_signature('client_panorama.dll',
                '\x55\x8B\xEC\x83\xE4\xF8\x83\xEC\x64\x53\x56\x57\x8B\xF1')
                or error 'set_angles signature missing'
            s.set_angles_fn = ffi.cast(s.set_angles_t, sa)
            return s
        end)

        local function get_original()
            return {
                fov = client.get_cvar('viewmodel_fov'),
                x   = client.get_cvar('viewmodel_offset_x'),
                y   = client.get_cvar('viewmodel_offset_y'),
                z   = client.get_cvar('viewmodel_offset_z'),
            }
        end

        local function g_handler(force_shutdown)
            local shutdown = force_shutdown == true or not menu.visuals.viewmodel:get()
            local mult = shutdown and 0 or 0.0025
            local orig = get_original()
            local d = {
                fov = menu.visuals.fov:get()      * mult,
                x   = menu.visuals.offset_x:get() * mult,
                y   = menu.visuals.offset_y:get() * mult,
                z   = menu.visuals.offset_z:get() * mult,
            }
            pcall(function() cvar.viewmodel_fov:set_raw_float(orig.fov + d.fov) end)
            pcall(function() cvar.viewmodel_offset_x:set_raw_float(orig.x + d.x) end)
            pcall(function() cvar.viewmodel_offset_y:set_raw_float(orig.y + d.y) end)
            pcall(function() cvar.viewmodel_offset_z:set_raw_float(orig.z + d.z) end)
        end

        local function g_override_view()
            if not ok_vm or not vm_state then return end
            if not menu.visuals.viewmodel:get() then return end
            local me = entity.get_local_player(); if not me then return end
            local vm = entity.get_prop(me, 'm_hViewModel[0]'); if not vm then return end
            local ent = vm_state.get_client_entity(vm_state.ientitylist, vm); if ent == nil then return end
            local cam = { client.camera_angles() }
            local angles = ffi.cast('vmodel_vec3_t*', ffi.new('char[?]', ffi.sizeof('vmodel_vec3_t')))
            angles.x, angles.y = cam[1], cam[2]
            vm_state.set_angles_fn(ent, angles)
        end

        client.set_event_callback('run_command', function()
            if not ok_vm or not vm_state then return end
            if not menu.visuals.viewmodel:get() then return end
            local me = entity.get_local_player(); if not me then return end
            local wpn = entity.get_player_weapon(me); if not wpn then return end
            local wid = entity.get_prop(wpn, 'm_iItemDefinitionIndex'); if not wid then return end
            pcall(function()
                local res = vm_state.get_weapon_info(vm_state.weaponsystem_raw, wid)
                res.hide_vm_scope = not menu.visuals.viewmodel_in_scope:get()
            end)
        end)

        client.set_event_callback('pre_render',  function() g_handler(false) end)
        client.set_event_callback('override_view', g_override_view)
        client.set_event_callback('shutdown', function() g_handler(true) end)
    end

    -- FOV Animation: override_view с плавной интерполяцией fov.
    do
        local switch = menu.visuals.animated_zoom
        local animation = nil

        local function on_override_view(e)
            if not switch:get() then return end
            local me = entity.get_local_player()
            if not me or not entity.is_alive(me) then return end

            local based_fov  = menu.visuals.animated_zoom_fov:get()
            local zoom_amt   = menu.visuals.animated_zoom_amount:get()
            local zoom_speed = menu.visuals.animated_zoom_speed:get()

            local scoped = entity.get_prop(me, 'm_bIsScoped') == 1
            local weapon = entity.get_player_weapon(me)
            local m_zoomLevel = weapon and entity.get_prop(weapon, 'm_zoomLevel') or 0

            local effect_zoom = zoom_amt
            if m_zoomLevel == 2 then effect_zoom = zoom_amt * 2 end

            local target = scoped and (based_fov - effect_zoom) or based_fov
            if animation == nil then animation = based_fov end
            local ft = globals.frametime()
            animation = animation + (target - animation) * ft * zoom_speed
            e.fov = animation
        end

        client.set_event_callback('override_view', on_override_view)
    end

    -- ============================================ FAST LADDER + ANIM BREAKER
    -- Porting from althea (1:1 logic, adapted to lunaris helpers).
    -- localplayer.is_onground / is_moving — вычисляются инлайн по m_fFlags
    -- (FL_ONGROUND = 1) и m_vecVelocity[0..1]. override.set/unset подменяем
    -- через ui.set на 'Leg movement' (с бэкапом исходного значения).

    local function _rand_float(a, b) return a + math.random() * (b - a) end
    local function _round(x) return math.floor(x + 0.5) end

    -- Нативный leg_movement reference (для Animation breaker static/jitter/moonwalk)
    local _leg_ref, _leg_default = nil, nil
    pcall(function()
        _leg_ref = ui.reference('AA', 'Other', 'Leg movement')
        _leg_default = ui.get(_leg_ref)
    end)
    local _leg_overridden = false
    local function _leg_override(value)
        if not _leg_ref then return end
        pcall(function() ui.set(_leg_ref, value) end)
        _leg_overridden = true
    end
    local function _leg_unset()
        if not _leg_ref or not _leg_overridden then return end
        pcall(function() ui.set(_leg_ref, _leg_default) end)
        _leg_overridden = false
    end

    local function _is_onground(me)
        local f = entity.get_prop(me, 'm_fFlags') or 0
        return bit.band(f, 1) ~= 0
    end
    local function _is_moving(me)
        local vx = entity.get_prop(me, 'm_vecVelocity[0]') or 0
        local vy = entity.get_prop(me, 'm_vecVelocity[1]') or 0
        return (vx*vx + vy*vy) > 25
    end

    -- Fast ladder: при MOVETYPE_LADDER (9) подручиваем yaw/pitch/in_*
    do
        local MOVETYPE_LADDER = 9
        local switch = menu.misc.fast_ladder

        local function is_throwing_grenade(weapon)
            local ok, info = pcall(csgo_weapons, weapon)
            if not ok or not info then return false end
            if info.weapon_type_int ~= 9 then return false end
            local tt = entity.get_prop(weapon, 'm_fThrowTime') or 0
            return tt ~= 0
        end

        local function on_setup_command(cmd)
            local me = entity.get_local_player(); if me == nil then return end
            local weapon = entity.get_player_weapon(me)
            if weapon and is_throwing_grenade(weapon) then return end
            local mt = entity.get_prop(me, 'm_movetype')
            if mt ~= MOVETYPE_LADDER then return end

            local pitch = ({ client.camera_angles() })[1] or 0

            cmd.yaw  = _round(cmd.yaw)
            cmd.roll = 0

            if cmd.forwardmove > 0 and pitch < 45 then
                cmd.pitch = 89
                cmd.in_moveright, cmd.in_moveleft, cmd.in_forward, cmd.in_back = 1, 0, 0, 1
                if cmd.sidemove == 0 then cmd.yaw = cmd.yaw + 90  end
                if cmd.sidemove <  0 then cmd.yaw = cmd.yaw + 150 end
                if cmd.sidemove >  0 then cmd.yaw = cmd.yaw + 30  end
            elseif cmd.forwardmove < 0 then
                cmd.pitch = 89
                cmd.in_moveleft, cmd.in_moveright, cmd.in_forward, cmd.in_back = 1, 0, 1, 0
                if cmd.sidemove == 0 then cmd.yaw = cmd.yaw + 90  end
                if cmd.sidemove >  0 then cmd.yaw = cmd.yaw + 150 end
                if cmd.sidemove <  0 then cmd.yaw = cmd.yaw + 30  end
            end
        end

        switch:set_callback(function(it)
            utils.event_callback('setup_command', on_setup_command, it:get())
        end, true)
    end

    -- Animation breaker: подмена m_flPoseParameter / anim overlays / leg_movement
    do
        local MOVETYPE_WALK = 2
        local LAYER_MOVE = 6
        local LAYER_LEAN = 12

        local function update_onground(me)
            local ei = c_entity(me); if ei == nil then return end
            if not _is_onground(me) then _leg_unset(); return end

            local v = menu.misc.ab_onground:get()
            if v == 'Static' then
                _leg_override('Always slide')
                entity.set_prop(me, 'm_flPoseParameter', 0, 0)
                return
            end
            if v == 'Jitter' then
                local mul = _rand_float(
                    menu.misc.ab_min:get() * 0.01,
                    menu.misc.ab_max:get() * 0.01
                )
                _leg_override('Always slide')
                entity.set_prop(me, 'm_flPoseParameter',
                    (globals.tickcount() % 4 > 1) and mul or 1, 1)
                return
            end
            if v == 'Moonwalk' then
                _leg_override('Never slide')
                entity.set_prop(me, 'm_flPoseParameter', 7, 0)
                local layer = ei:get_anim_overlay(LAYER_MOVE)
                if layer ~= nil then layer.weight = 1 end
                return
            end
            _leg_unset()
        end

        local function update_in_air(me)
            local v = menu.misc.ab_in_air:get()
            if v == 'off' or _is_onground(me) then return end
            if v == 'Static' then
                entity.set_prop(me, 'm_flPoseParameter',
                    menu.misc.ab_in_air_v:get() * 0.01, 6)
                return
            end
            if v == 'Moonwalk' then
                if not _is_moving(me) then return end
                local ei = c_entity(me); if ei == nil then return end
                local layer = ei:get_anim_overlay(LAYER_MOVE)
                if layer ~= nil then layer.weight = 1 end
            end
        end

        local function update_earthquake(me)
            if not menu.misc.ab_quake:get() then return end
            local ei = c_entity(me); if ei == nil then return end
            local layer = ei:get_anim_overlay(LAYER_LEAN)
            if layer == nil then return end
            layer.weight = utils.lerp(layer.weight,
                _rand_float(0, 1),
                menu.misc.ab_quake_v:get() * 0.01)
        end

        local function update_body_lean(me)
            local v = menu.misc.ab_lean:get()
            if v == 0 then return end
            local ei = c_entity(me); if ei == nil then return end
            local layer = ei:get_anim_overlay(LAYER_LEAN)
            if layer == nil then return end
            local vx = entity.get_prop(me, 'm_vecVelocity[0]') or 0
            if math.abs(vx) >= 3 then layer.weight = v * 2 end
        end

        local function update_pitch_on_land(me)
            if not menu.misc.ab_pitch:get() then return end
            if not _is_onground(me) then return end
            local ei = c_entity(me); if ei == nil then return end
            local ok, animstate = pcall(function() return ei:get_anim_state() end)
            if not ok or animstate == nil then return end
            if not animstate.hit_in_ground_animation then return end
            entity.set_prop(me, 'm_flPoseParameter', 0.5, 12)
        end

        local function on_pre_render()
            local me = entity.get_local_player(); if me == nil then return end
            local mt = entity.get_prop(me, 'm_movetype')
            if mt == MOVETYPE_WALK then
                update_onground(me)
                update_in_air(me)
                update_pitch_on_land(me)
            end
            update_body_lean(me)
            update_earthquake(me)
        end

        menu.misc.ab_enabled:set_callback(function(it)
            local value = it:get()
            if not value then _leg_unset() end
            utils.event_callback('pre_render', on_pre_render, value)
        end, true)

        client.set_event_callback('shutdown', _leg_unset)
    end

    ---------------------------------------------------------- auto buy ----
    -- 1:1 порт из andromeda (buybot @ стр. 3882–3988)
    local buybot = {} do
        local buy_command_exec = ''
        local buy_time = nil

        local primary_weapons = {
            { name = 'AWP',   command = 'buy awp' },
            { name = 'AUTO',  command = 'buy scar20; buy g3sg1' },
            { name = 'SSG08', command = 'buy ssg08' },
        }

        local secondary_weapons = {
            { name = 'Berettas',         command = 'buy elite' },
            { name = 'P250',             command = 'buy p250' },
            { name = 'Five-seven/Tec-9', command = 'buy tec9; buy fiveseven' },
            { name = 'Heavy pistols',    command = 'buy deagle; buy revolver' },
        }

        local gears = {
            { name = 'Molotov',    command = 'buy molotov; buy incgrenade' },
            { name = 'HE',         command = 'buy hegrenade' },
            { name = 'Smoke',      command = 'buy smokegrenade' },
            { name = 'Zeus',       command = 'buy taser' },
            { name = 'Kevlar',     command = 'buy vest' },
            { name = 'Helmet',     command = 'buy vesthelm' },
            { name = 'Defuse kit', command = 'buy defuser' },
        }

        local function command_check(t, name)
            for i = 1, #t do
                if t[i].name == name then return t[i].command end
            end
            return nil
        end

        local function buy_command()
            local setup = {}

            local primary_name = menu.misc.buybot_main:get()
            if primary_name ~= '-' then
                local cmd = command_check(primary_weapons, primary_name)
                if cmd then table.insert(setup, cmd) end
            end

            local secondary_name = menu.misc.buybot_secondary:get()
            if secondary_name ~= '-' then
                local cmd = command_check(secondary_weapons, secondary_name)
                if cmd then table.insert(setup, cmd) end
            end

            -- multiselect в lunaris/pui: :get('OptionName') → bool
            local gear_items = { 'Zeus', 'Defuse kit', 'Kevlar', 'Helmet', 'Molotov', 'HE', 'Smoke' }
            for i = 1, #gear_items do
                if menu.misc.buybot_gear:get(gear_items[i]) then
                    local cmd = command_check(gears, gear_items[i])
                    if cmd then table.insert(setup, cmd) end
                end
            end

            return table.concat(setup, ';')
        end

        local function on_round_start()
            if not menu.misc.buybot:get() then return end
            local delay = 0.1
            buy_command_exec = buy_command()
            if buy_command_exec and buy_command_exec ~= '' then
                buy_time = globals.realtime() + delay
            end
        end

        local function on_paint()
            if buy_time == nil then return end

            local game_rules = entity.get_game_rules()
            if not game_rules then
                buy_time = nil
                return
            end

            local ok_total, total_rounds = pcall(entity.get_prop, game_rules, 'm_totalRoundsPlayed')
            if not ok_total or total_rounds == nil then
                buy_time = nil
                return
            end

            local ok_max, max_rounds = pcall(function() return cvar.mp_maxrounds:get_int() end)
            if not ok_max or not max_rounds then max_rounds = 30 end

            local pistol_round = (total_rounds == 0) or (total_rounds == math.floor(max_rounds * 0.5))
            if pistol_round then
                buy_time = nil
                return
            end

            if globals.realtime() >= buy_time then
                client.exec(buy_command_exec)
                buy_time = nil
            end
        end

        client.set_event_callback('round_prestart', on_round_start)
        client.set_event_callback('paint',          on_paint)
    end

    ---------------------------------------------------------- console filter ----
    -- 1:1 порт из andromeda (console_filter @ стр. 4072–4095)
    local console_filter = {} do
        local switch = menu.misc.console_filter

        function console_filter.init()
            if switch:get() then
                pcall(function() cvar.developer:set_int(0) end)
                pcall(function() cvar.con_filter_enable:set_int(1) end)
                pcall(function() cvar.con_filter_text:set_string('IrWL5106TZZKNFPz4P4Gl3pSN?J370f5hi373ZjPg%VOVh6lN') end)
                client.exec('con_filter_enable 1')
            else
                pcall(function() cvar.con_filter_enable:set_int(0) end)
                pcall(function() cvar.con_filter_text:set_string('') end)
                client.exec('con_filter_enable 0')
            end
        end

        function console_filter.shutdown()
            pcall(function() cvar.con_filter_enable:set_int(0) end)
            pcall(function() cvar.con_filter_text:set_string('') end)
            client.exec('con_filter_enable 0')
        end

        switch:set_callback(console_filter.init, true)
        client.set_event_callback('shutdown', console_filter.shutdown)
    end

    ---------------------------------------------------------- ai peek ----
    -- 1:1 порт из althea (ai_peek @ стр. 5459–6454)
    -- + фиксы: без gamesense/trace, все векторы через vec() helper, поддержка hotkey бинда
    local ai_peek do
        local ref = {
            enabled          = menu.aimbot.ai_peek,
            key              = menu.aimbot.ai_peek_key,
            indicators_color = menu.aimbot.ai_peek_color,
            mode             = menu.aimbot.ai_peek_mode,
            dot_offset       = menu.aimbot.ai_peek_offset,
            dot_span         = menu.aimbot.ai_peek_span,
            dot_amount       = menu.aimbot.ai_peek_amount,
            mp_scale_head    = menu.aimbot.ai_peek_mp_head,
            mp_scale_chest   = menu.aimbot.ai_peek_mp_chest,
            target_limbs     = menu.aimbot.ai_peek_limbs,
        }

        -- универсальн��й helper: всегда возвращает настоящий vector с полными методами
        local function vec(x, y, z)
            if type(x) == 'table' or type(x) == 'userdata' then
                return vector(x.x or 0, x.y or 0, x.z or 0)
            end
            return vector(x or 0, y or 0, z or 0)
        end
        local function toticks(t) return math.floor((t or 0) / globals.tickinterval() + 0.5) end

        local FLAG_BREAK_LC = bit.lshift(2, 16)

        local ref_quick_peek_assist        = { ui.reference('RAGE', 'Other', 'Quick peek assist') }
        local ref_minimum_damage           = { ui.reference('RAGE', 'Aimbot', 'Minimum damage') }
        local ref_minimum_damage_override  = { ui.reference('RAGE', 'Aimbot', 'Minimum damage override') }

        local tick_to_distance = {
            0, 0.33566926072059, 0.90550823109139, 1.7094571925458,
            2.7475758645732, 4.0198045277169, 5.5243356897069, 7.2423273783409,
            9.1564213090631, 11.250673856852, 13.510480438002, 15.922361837797,
            18.473989413581, 21.153990043142, 23.951936812474, 26.858254779359,
            29.864120158319, 32.961441695549, 36.142785057665, 39.401338315411,
            42.730817707458, 46.125502156263, 49.580063421207, 53.08964170921,
            56.649735547569, 60.256252190999, 63.905432011078, 67.59383918326,
            71.318242246617, 75.075708340563, 78.863628408227, 82.67942790961,
            86.520915828495, 90.385926351936, 94.272651987509, 98.17890171902,
            102.08515145053, 105.99140118205, 109.89765091356, 113.80390064508,
            117.7101503766,  121.61640010812, 125.52264983965, 129.42889957117,
            133.3351493027,  137.24139903422, 141.14764876575, 145.05389849727,
            148.9601482288,  152.86639796033, 156.77264769186, 160.67889742339,
            164.58514715492, 168.49139688645, 172.39764661798, 176.30389634951,
            180.21014608104, 184.11639581258, 188.02264554411, 191.92889527564,
            195.83514500718, 199.74139473871, 203.64764447024, 207.55389420178,
        }

        local enemy_lc_data = {}
        local debug_visuals = {}
        local visuals = { found_point = nil, peeking_points = {} }

        local e_hitboxes = { head = 1, stomach = 2, chest = 3, limbs = 4 }
        local hitboxes = {
            { 0 },
            { 2, 3, 4 },
            { 5, 6 },
            { 13, 14, 15, 16, 17, 18, 7, 8, 9, 10, 11, 1 },
        }

        local cache = {
            last_seen = 0,
            autopeek_position    = vec(0, 0, 0),
            found_position       = vec(0, 0, 0),
            found_position_dist  = 1,
        }

        local closest_enemy = nil

        -- бинд активен? (если хоткей не выставлен, считаем всегда-вкл)
        local function key_active()
            if ref.key == nil then return true end
            local ok, v = pcall(function() return ref.key:get() end)
            if not ok then return true end
            -- pui hotkey :get() — bool (нажатие), или nil е��ли клавиша не ��азначена
            if v == nil then return true end
            return v == true
        end

        local function create_new_record(player)
            local data = {}
            data.player = player
            data.origin = vec(entity.get_origin(player))
            data.breaking_lc = false
            data.last_simtime = 0
            data.defensive = false
            data.defensive_active_until = 0

            function data.update()
                local esp_data = entity.get_esp_data(data.player)
                local esp_flags = (esp_data and esp_data.flags) or 0
                local origin = vec(entity.get_origin(player))
                local simtime = toticks(entity.get_prop(player, 'm_flSimulationTime'))
                local delta_simtime = simtime - data.last_simtime
                data.defensive = bit.band(esp_flags, FLAG_BREAK_LC) ~= 0

                if delta_simtime < 0 then
                    data.defensive_active_until = globals.tickcount() + math.abs(delta_simtime)
                else
                    local dx = origin.x - data.origin.x
                    local dy = origin.y - data.origin.y
                    local delta_lengthsqr = dx * dx + dy * dy
                    data.breaking_lc = delta_lengthsqr > 4096
                    data.origin = origin
                end

                data.last_simtime = simtime
            end

            enemy_lc_data[player] = data
            return data
        end

        local function can_hit_in_x_ticks(wanted_pos_distance, max_speed, ticks)
            local distance_mult = max_speed / 250
            local wanted_distance = wanted_pos_distance * distance_mult
            local max_distance = (tick_to_distance[ticks] or 0) * distance_mult
            return wanted_distance <= max_distance
        end

        local function debug_visualize(positions, name)
            if type(positions) ~= 'table' then positions = { positions } end
            debug_visuals[name] = positions
        end

        local function set_visual_peeking_points(points) visuals.peeking_points = points end

        local function get_min_dmg()
            if ui.get(ref_minimum_damage_override[1]) and ui.get(ref_minimum_damage_override[2]) then
                return ui.get(ref_minimum_damage_override[3])
            end
            return ui.get(ref_minimum_damage[1])
        end

        local function reset_cache()
            cache.last_seen = 0
            cache.found_position = vec(0, 0, 0)
        end

        local function is_mp_available() return ref.mode:get() == 'Advanced' end

        local function dist2d(ax, ay, bx, by) return math.sqrt((ax-bx)^2 + (ay-by)^2) end

        local function get_closest_enemy()
            local sw, sh = client.screen_size()
            local cx, cy = sw / 2, sh / 2
            local smallest_distance = math.huge
            local closest_enemy_found = nil
            local enemies = entity.get_players(true)

            for i = 1, #enemies do
                local enemy = enemies[i]
                if enemy ~= nil and entity.is_alive(enemy) and not entity.is_dormant(enemy) then
                    local ex_, ey_, ez_ = entity.get_prop(enemy, 'm_vecOrigin')
                    if ex_ then
                        local sx, sy = renderer.world_to_screen(ex_, ey_, ez_)
                        if sx ~= nil and sy ~= nil then
                            local d = dist2d(sx, sy, cx, cy)
                            if d < smallest_distance then
                                smallest_distance = d
                                closest_enemy_found = enemy
                            end
                        end
                    end
                end
            end
            closest_enemy = closest_enemy_found
        end

        local function get_multipoint(ent, hitbox_center, scale)
            local me = entity.get_local_player()
            if not me then return {} end
            local hcx, hcy, hcz = hitbox_center.x, hitbox_center.y, hitbox_center.z
            local mx, my, mz = entity.get_prop(me, 'm_vecOrigin')
            local tx, ty, tz = entity.get_prop(ent, 'm_vecOrigin')
            local dx, dy = (tx or 0) - (mx or 0), (ty or 0) - (my or 0)
            local yaw = math.deg(math.atan2(dy, dx))
            local max_check_dist = 5
            local mp_poses = {}
            for side = -1, 1, 2 do
                local rad = math.rad(yaw + (90 * side))
                local cx_, cy_ = math.cos(rad), math.sin(rad)
                local sx, sy, sz = hcx + cx_ * max_check_dist, hcy + cy_ * max_check_dist, hcz
                local dx2, dy2, dz2 = hcx - sx, hcy - sy, hcz - sz
                local frac = client.trace_line(me, sx, sy, sz, hcx, hcy, hcz)
                local m = (1 - frac) * scale
                table.insert(mp_poses, vec(hcx + dx2 * m, hcy + dy2 * m, hcz + dz2 * m))
            end
            return mp_poses
        end

        local function get_head_multipoint(ent, hitbox_center, scale)
            local me = entity.get_local_player()
            local side_mp = get_multipoint(ent, hitbox_center, scale)
            if not me then return side_mp end
            local hcx, hcy, hcz = hitbox_center.x, hitbox_center.y, hitbox_center.z
            local sx, sy, sz = hcx, hcy, hcz - 5
            local dx, dy, dz = hcx - sx, hcy - sy, hcz - sz
            local frac = client.trace_line(me, sx, sy, sz, hcx, hcy, hcz)
            local m = (1 - frac) * scale
            table.insert(side_mp, vec(hcx + dx * m, hcy + dy * m, hcz + dz * m))
            return side_mp
        end

        local function get_player_points(player)
            local points = {}
            local extra_calc = is_mp_available()
            local find_limbs = extra_calc and ref.target_limbs:get()
            local mp_head    = extra_calc
            local mp_chest   = extra_calc
            local mp_stomach = extra_calc
            local scale_h = ref.mp_scale_head:get()  / 100
            local scale_c = ref.mp_scale_chest:get() / 100

            local function push_hb(group, do_mp, scale, is_head)
                local hb = hitboxes[group]
                for i = 1, #hb do
                    local hx, hy, hz = entity.hitbox_position(player, hb[i])
                    if hx then
                        local center = vec(hx, hy, hz)
                        if not do_mp then
                            table.insert(points, center)
                        else
                            local mps = is_head and get_head_multipoint(player, center, scale) or get_multipoint(player, center, scale)
                            for j = 1, #mps do table.insert(points, mps[j]) end
                        end
                    end
                end
            end

            push_hb(e_hitboxes.head,    mp_head,    scale_h, true)
            push_hb(e_hitboxes.chest,   mp_chest,   scale_c, false)
            push_hb(e_hitboxes.stomach, mp_stomach, scale_c, false)
            if find_limbs then push_hb(e_hitboxes.limbs, false, 0, false) end

            return points
        end

        -- ручная реализация trace.line через client.trace_line
        -- mask='MASK_SOLID_BRUSHONLY' → нет в client.trace_line, используем -1 (ничего не пропускаем)
        local function trace_line_simple(skip, sx, sy, sz, ex, ey, ez)
            local frac, hit_ent = client.trace_line(skip or -1, sx, sy, sz, ex, ey, ez)
            return {
                fraction = frac,
                hit_entity = hit_ent,
                end_pos = vec(sx + (ex - sx) * frac, sy + (ey - sy) * frac, sz + (ez - sz) * frac),
            }
        end

        local function get_peeking_points(me)
            local mox, moy, moz = entity.get_prop(me, 'm_vecOrigin')
            if not mox then return {} end
            local eex, eey, eez = client.eye_position()
            if not eex then return {} end
            local _, yaw = client.camera_angles()
            local head_height = eez - moz

            local start_offset   = ref.dot_offset:get()
            local dots           = ref.dot_amount:get()
            local total_distance = ref.dot_span:get()
            local gap            = (dots > 0) and (total_distance / dots) or 0

            local dot_positions = {}
            for i = -1, 1, 2 do
                local dot_yaw = (yaw or 0) + (90 * i)
                local yaw_rad = math.rad(dot_yaw)
                local fx, fy = math.cos(yaw_rad), math.sin(yaw_rad)

                local broke = false
                for dot_iter = 1, dots do
                    local mult = (gap * dot_iter) + start_offset
                    local dpx, dpy, dpz = eex + fx * mult, eey + fy * mult, eez

                    -- 1: ищем пол под точкой (скипаем локального игрока, иначе при
                    -- маленьком offset трасса упирается в собственный bbox и точка
                    -- улетает в небо на eye_z + head_height)
                    local tr1 = trace_line_simple(me, dpx, dpy, dpz, dpx, dpy, dpz - 200)
                    if tr1.fraction > 0 and tr1.fraction < 1 then
                        local epx, epy, epz = tr1.end_pos.x, tr1.end_pos.y, tr1.end_pos.z + head_height
                        if (epz - moz) > 40 then
                            -- слишком высоко — последняя итерация
                            dot_iter = dots
                        end
                        dpx, dpy, dpz = epx, epy, epz
                    end

                    -- 2: проверяем видимость из глаза до точки (скипаем локального игрока)
                    local tr2 = trace_line_simple(me, eex, eey, eez, dpx, dpy, dpz)
                    if tr2.fraction == 1 then
                        table.insert(dot_positions, vec(dpx, dpy, dpz))
                    else
                        local back = ((gap * dot_iter) + start_offset) * tr2.fraction - 19
                        table.insert(dot_positions, vec(eex + fx * back, eey + fy * back, dpz))
                        broke = true
                        break
                    end
                end
                if broke then end -- placeholder, just continues outer
            end
            return dot_positions
        end

        local function can_hit_from_positions(lp, positions, target, target_hitpoints)
            local minimum_damage = get_min_dmg() or 0
            for i = 1, #positions do
                local position = positions[i]
                visuals.found_point = i
                for j = 1, #target_hitpoints do
                    local hp = target_hitpoints[j]
                    local hit_entity, simulated_dmg = client.trace_bullet(lp, position.x, position.y, position.z, hp.x, hp.y, hp.z, false)
                    if hit_entity == target then
                        local target_health = entity.get_prop(hit_entity, 'm_iHealth') or 100
                        local wanted_dmg = minimum_damage
                        if minimum_damage > 100 then wanted_dmg = target_health + (minimum_damage - 100) end
                        if simulated_dmg and (simulated_dmg >= target_health or simulated_dmg > wanted_dmg) then
                            cache.found_position = vec(position.x, position.y, position.z)
                            local dx = cache.autopeek_position.x - cache.found_position.x
                            local dy = cache.autopeek_position.y - cache.found_position.y
                            cache.found_position_dist = math.sqrt(dx*dx + dy*dy)
                            return true
                        end
                    elseif hit_entity ~= nil and entity.is_alive(hit_entity) then
                        local target_health = entity.get_prop(hit_entity, 'm_iHealth') or 100
                        local wanted_dmg = minimum_damage
                        if minimum_damage > 100 then wanted_dmg = target_health + (minimum_damage - 100) end
                        if simulated_dmg and (simulated_dmg >= target_health or simulated_dmg > wanted_dmg) then
                            cache.found_position = vec(position.x, position.y, position.z)
                            return true
                        end
                    end
                end
            end
            visuals.found_point = nil
            return false
        end

        local function ready_to_shoot(lp, cmd)
            local slowdown = (entity.get_prop(lp, 'm_flVelocityModifier') or 1) < 0.9
            local has_user_input = cmd.in_moveleft == 1 or cmd.in_moveright == 1 or cmd.in_back == 1 or cmd.in_forward == 1 or cmd.in_jump == 1
            local wep = entity.get_player_weapon(lp)
            local next_shot_ready = false
            if wep ~= nil then
                local reloading = entity.get_prop(wep, 'm_bInReload') == 1
                local next_attack_ready = (entity.get_prop(wep, 'm_flNextPrimaryAttack') or 0) < globals.curtime()
                if not reloading and next_attack_ready then next_shot_ready = true end
            end
            return not ((slowdown or has_user_input or not next_shot_ready) and not next_shot_ready)
        end

        local function move_to_pos(cmd, lp, lp_pos, new_pos)
            local dx = new_pos.x - lp_pos.x
            local dy = new_pos.y - lp_pos.y
            local dz = new_pos.z - lp_pos.z
            local distance = math.sqrt(dx*dx + dy*dy + dz*dz) + 5
            if distance < 1e-6 then return end
            local nx, ny, nz = dx / distance, dy / distance, dz / distance
            -- вытягиваем точку чуть дальше
            new_pos = { x = lp_pos.x + nx * (distance + 5), y = lp_pos.y + ny * (distance + 5), z = lp_pos.z + nz * (distance + 5) }

            if cmd.forwardmove == 0 and cmd.sidemove == 0 and cmd.in_forward == 0 and cmd.in_back == 0 and cmd.in_moveleft == 0 and cmd.in_moveright == 0 then
                if distance >= 0.5 then
                    local fwd_x = new_pos.x - lp_pos.x
                    local fwd_y = new_pos.y - lp_pos.y
                    local fwd_len = math.sqrt(fwd_x*fwd_x + fwd_y*fwd_y)
                    if fwd_len < 1e-6 then return end
                    local nfx, nfy = fwd_x / fwd_len, fwd_y / fwd_len
                    local pos1_x = new_pos.x + nfx * 10
                    local pos1_y = new_pos.y + nfy * 10
                    local f2x = pos1_x - lp_pos.x
                    local f2y = pos1_y - lp_pos.y
                    local yaw = math.deg(math.atan2(f2y, f2x))

                    cmd.move_yaw = yaw
                    cmd.in_speed = 0
                    cmd.in_moveleft, cmd.in_moveright = 0, 0
                    cmd.sidemove = 0

                    if distance > 8 then
                        cmd.forwardmove = 450
                    else
                        local duck = entity.get_prop(lp, 'm_flDuckAmount') or 0
                        local wishspeed = math.min(450, math.max(1.1 + duck * 10, distance * 9))
                        local vx, vy = entity.get_prop(lp, 'm_vecAbsVelocity')
                        local vel = math.sqrt((vx or 0)^2 + (vy or 0)^2)
                        if vel >= math.min(250, wishspeed) + 15 then
                            cmd.forwardmove = 0
                            cmd.in_forward = 0
                        else
                            cmd.forwardmove = math.max(6, vel >= math.min(250, wishspeed) and wishspeed * 0.9 or wishspeed)
                            cmd.in_forward = 1
                        end
                    end
                end
            end
        end

        local function handle_peek(cmd)
            local lp = entity.get_local_player()
            if not lp then return end
            local ex, ey, ez = client.eye_position()
            if not ex then return end
            local lp_pos = vec(ex, ey, ez)
            -- выравниваем z на уровень глаз
            cache.found_position = vec(cache.found_position.x, cache.found_position.y, lp_pos.z)
            move_to_pos(cmd, lp, lp_pos, cache.found_position)
        end

        local function handle_retreat(cmd)
            local lp = entity.get_local_player()
            if not lp then return end
            local ex, ey, ez = client.eye_position()
            if not ex then return end
            local lp_pos = vec(ex, ey, ez)
            move_to_pos(cmd, lp, lp_pos, cache.autopeek_position)
        end

        local function is_doubletap_charged()
            local lp = entity.get_local_player()
            if not lp then return false end
            local m_nTickBase = entity.get_prop(lp, 'm_nTickBase') or 0
            local client_latency = client.latency()
            local shift = math.floor(m_nTickBase - globals.tickcount() - 3 - toticks(client_latency) * .5 + .7 * (client_latency * 10))
            return shift <= -11
        end

        local debug = { state = 'disabled', step = 0, visual_step = 0 }
        local function set_state(s) debug.state = s end
        local function set_step(s) debug.step = s end
        local function set_visual_step(s) debug.visual_step = s end

        local e_steps = {
            IDLE = 0, FINDING_TARGET = 1, SEARCHING_HITPOINTS = 2,
            CHECKING_HITPOINTS = 3, PEEKING = 4, RETREATING = 5,
        }
        local e_visual_steps = {
            IDLE = 0, FINDING_TARGET = 1, SEARCHING_HITPOINTS = 2,
            CHECKING_HITPOINTS = 3, PEEKING = 4, RETREATING = 5,
            WAITING_FOR_SHOT = 6, NO_ENEMIES = 7, DT_NOT_CHARGED = 8,
        }
        local visual_texts = {
            [e_visual_steps.IDLE]                = 'freezed',
            [e_visual_steps.FINDING_TARGET]      = 'waiting',
            [e_visual_steps.SEARCHING_HITPOINTS] = 'waiting',
            [e_visual_steps.CHECKING_HITPOINTS]  = 'ensuring hitpoints',
            [e_visual_steps.PEEKING]             = 'peeking',
            [e_visual_steps.RETREATING]          = 'waiting',
            [e_visual_steps.WAITING_FOR_SHOT]    = 'waiting for shot',
            [e_visual_steps.NO_ENEMIES]          = 'waiting',
            [e_visual_steps.DT_NOT_CHARGED]      = '[!] dt not fully charged [!]',
        }

        local peeking_points = {}

        local function gpt_peek(cmd)
            local me = entity.get_local_player()
            if me == nil then return end

            local px, py, pz = entity.get_prop(me, 'm_vecOrigin')
            if not px then return end
            local pos = vec(px, py, pz)
            local autopeek_state = ui.get(ref_quick_peek_assist[2])

            -- бинд не нажат — фича выключена
            if not key_active() then
                cache.autopeek_position = pos
                peeking_points = get_peeking_points(me)
                reset_cache()
                set_state('disabled')
                set_step(e_steps.IDLE)
                set_visual_step(e_visual_steps.IDLE)
                return
            end

            if not autopeek_state then
                cache.autopeek_position = pos
                peeking_points = get_peeking_points(me)
                reset_cache()
                set_state('disabled')
                set_step(e_steps.IDLE)
                set_visual_step(e_visual_steps.IDLE)
                return
            end

            set_visual_peeking_points(peeking_points)
            set_state('idle')

            local ddx = cache.autopeek_position.x - cache.found_position.x
            local ddy = cache.autopeek_position.y - cache.found_position.y
            local distance = math.sqrt(ddx*ddx + ddy*ddy)
            local can_run = can_hit_in_x_ticks(distance, 250, 24)
            local can_shoot = ready_to_shoot(me, cmd)

            if (cache.last_seen + 24) >= globals.tickcount() and can_run and can_shoot then
                handle_peek(cmd)
                set_state('peeking')
                set_step(e_steps.PEEKING)
                set_visual_step(e_visual_steps.PEEKING)
                return
            end

            local apx = cache.autopeek_position.x - pos.x
            local apy = cache.autopeek_position.y - pos.y
            if math.sqrt(apx*apx + apy*apy) > 5 then
                handle_retreat(cmd)
                set_state('retreating')
                set_step(e_steps.RETREATING)
                set_visual_step(e_visual_steps.RETREATING)
                return
            end

            if not can_shoot then
                set_step(e_steps.IDLE)
                set_visual_step(e_visual_steps.WAITING_FOR_SHOT)
                return
            end

            local targets = { closest_enemy }
            if next(targets) == nil or targets[1] == nil then
                reset_cache()
                set_state('idle')
                set_step(e_steps.IDLE)
                set_visual_step(e_visual_steps.NO_ENEMIES)
                return
            end

            if can_shoot then
                set_step(e_steps.FINDING_TARGET)
                set_visual_step(e_visual_steps.FINDING_TARGET)
            end

            local g_can_hit, g_can_peek = false, false
            for idx = 1, #targets do
                local target = targets[idx]
                if target and entity.is_alive(target) and not entity.is_dormant(target) then
                    local target_data = enemy_lc_data[target] or create_new_record(target)
                    target_data.update()
                    local can_peek = not target_data.breaking_lc and not target_data.defensive
                    local hitpoints = get_player_points(target)
                    debug_visualize(hitpoints, target)
                    set_step(e_steps.SEARCHING_HITPOINTS)
                    set_visual_step(e_visual_steps.SEARCHING_HITPOINTS)
                    if can_peek then
                        if can_hit_from_positions(me, peeking_points, target, hitpoints) then
                            g_can_hit = true
                            g_can_peek = true
                            break
                        end
                    else
                        set_step(e_steps.CHECKING_HITPOINTS)
                        set_visual_step(e_visual_steps.CHECKING_HITPOINTS)
                    end
                end
            end

            local dt_charged = is_doubletap_charged()
            if not dt_charged then
                set_step(e_steps.FINDING_TARGET)
                set_visual_step(e_visual_steps.DT_NOT_CHARGED)
            end
            if g_can_hit and g_can_peek and dt_charged then
                cache.last_seen = globals.tickcount()
            elseif not g_can_peek and not dt_charged then
                set_state("can't peek")
            elseif not dt_charged then
                set_state('dt not charged')
            end
        end

        local visual_progressbar = {
            lerped = { x = 0, y = 0 },
            gap = 30,
            radius = 5,
        }

        local function lerp_scalar(a, b, t) return a + (b - a) * t end

        local function RGBAtoHEX(r, g, b, a)
            return string.format('%.2x%.2x%.2x%.2x',
                math.floor(math.max(0, math.min(255, r))),
                math.floor(math.max(0, math.min(255, g))),
                math.floor(math.max(0, math.min(255, b))),
                math.floor(math.max(0, math.min(255, a))))
        end

        local function animate_text(time, str, r, g, b, a)
            local t_out, k = {}, 1
            local mr, mg, mb, ma = ref.indicators_color:get()
            mr, mg, mb, ma = mr or 255, mg or 255, mb or 255, ma or 255
            local r_add, g_add, b_add, a_add = mr - r, mg - g, mb - b, ma - a
            for i = 1, #str do
                local iter = (i - 1) / math.max(1, (#str - 1)) + time
                local k_cos = math.abs(math.cos(iter))
                t_out[k]   = '\a' .. RGBAtoHEX(r + r_add * k_cos, g + g_add * k_cos, b + b_add * k_cos, a + a_add * k_cos)
                t_out[k+1] = str:sub(i, i)
                k = k + 2
            end
            return t_out
        end

        local function render_screen_bar()
            local lp = entity.get_local_player()
            if not lp then return end

            for target, tbl in pairs(debug_visuals) do
                if entity.is_alive(target) and not entity.is_dormant(target) then
                    for i = 1, #tbl do
                        local p = tbl[i]
                        local s_x, s_y = renderer.world_to_screen(p.x, p.y, p.z)
                        if s_x ~= nil and s_y ~= nil then
                            renderer.circle(s_x, s_y, 255, 255, 255, 150, 2, 0, 1)
                        end
                    end
                end
            end

            local step = debug.step
            if step == e_steps.RETREATING then
                set_step(e_steps.IDLE)
                step = debug.step
            end

            local sw, sh = client.screen_size()
            local target_x = sw / 2 + ((step - 2) * visual_progressbar.gap)
            local target_y = sh - 100

            if visual_progressbar.lerped.x == 0 then
                visual_progressbar.lerped.x = target_x
                visual_progressbar.lerped.y = target_y
            end
            visual_progressbar.lerped.x = lerp_scalar(visual_progressbar.lerped.x, target_x, 0.1)
            visual_progressbar.lerped.y = lerp_scalar(visual_progressbar.lerped.y, target_y, 0.1)

            local txt = visual_texts[debug.visual_step] or ''
            local text = animate_text(globals.curtime(), txt:lower(), 55, 55, 55, 255)
            renderer.text(sw / 2, visual_progressbar.lerped.y, 255, 255, 255, 255, 'cd', 0, unpack(text))
        end

        local visual_points = { last_pressed = 0, last_state = false, animation_time = .2 }

        local function ease_in_back(time)
            local c1, c3 = 1.70158, 2.70158
            return c3 * time * time * time - c1 * time * time
        end

        local function render_peeking_point(sx, sy, state)
            renderer.circle(sx, sy, 255, 255, 255, 255, 3, 0, 1)
            if state then
                renderer.circle_outline(sx, sy, 0, 255, 0, 255, 3, 0, 1, 2)
            end
        end

        local function render_peeking_points()
            local me = entity.get_local_player()
            if not me then return end
            local preview = ui.is_menu_open()
            if preview then visuals.peeking_points = get_peeking_points(me) end

            local ap_state = ui.get(ref_quick_peek_assist[2]) and key_active()
            if ap_state ~= visual_points.last_state then
                visual_points.last_pressed = globals.curtime()
                visual_points.last_state = ap_state
            end

            local diff = math.min(globals.curtime() - visual_points.last_pressed, visual_points.animation_time)
            local animation_factor = ease_in_back(diff / visual_points.animation_time)
            if not ap_state then animation_factor = 1 - animation_factor end
            if preview then animation_factor = 1 end
            if not ap_state and animation_factor <= 0.1 then return end

            local points = visuals.peeking_points
            local lpx, lpy, lpz = entity.get_origin(me)
            if not lpx then return end
            for i = 1, #points do
                local p = points[i]
                local pdx = (p.x - lpx) * animation_factor
                local pdy = (p.y - lpy) * animation_factor
                local px2, py2, pz2 = lpx + pdx, lpy + pdy, p.z
                local sx, sy = renderer.world_to_screen(px2, py2, pz2)
                if sx ~= nil and sy ~= nil then
                    render_peeking_point(sx, sy, visuals.found_point == i)
                end
            end
        end

        local function on_setup_command(cmd)
            if not key_active() then return end
            gpt_peek(cmd)
        end
        local function on_aim_fire() cache.last_seen = 0 end
        local function on_paint()
            render_peeking_points()
            if not ui.get(ref_quick_peek_assist[2]) then return end
            if not key_active() then return end
            get_closest_enemy()
            render_screen_bar()
        end

        ref.enabled:set_callback(function(item)
            local value = item:get()
            if not value then reset_cache() end
            utils.event_callback('paint',         on_paint,         value)
            utils.event_callback('aim_fire',      on_aim_fire,      value)
            utils.event_callback('setup_command', on_setup_command, value)
        end, true)
    end
    ---------------------------------------------------------- andromeda aimbot ----
    -- 1:1 порт из andromeda (раздел aimbot, стр. 4125–4481)
    -- + shim: vtable_bind в lunaris нет, реализуем через ffi.cast
    do
        local ffi_ok, ffi_lib = pcall(require, 'ffi')
        if ffi_ok and rawget(_G, 'vtable_bind') == nil then
            _G.ffi = _G.ffi or ffi_lib
            local ffi = ffi_lib
            local function get_interface_function(module_name, interface_name, index)
                local ok, addr = pcall(client.create_interface, module_name, interface_name)
                if not ok or not addr then return function() return nil end end
                local iface = ffi.cast('void***', addr)
                local fn_ptr = iface[0][index]
                return fn_ptr
            end
            function _G.vtable_bind(module_name, interface_name, index, typedef)
                local ok_iface, iface_addr = pcall(client.create_interface, module_name, interface_name)
                if not ok_iface or not iface_addr then
                    return function() return nil end
                end
                local iface = ffi.cast('void***', iface_addr)
                local fn = ffi.cast(typedef, iface[0][index])
                return function(...) return fn(iface, ...) end
            end
        end
        if rawget(_G, 'ffi') == nil and ffi_ok then _G.ffi = ffi_lib end
        if math.sign == nil then
            function math.sign(v) return (v > 0 and 1) or (v < 0 and -1) or 0 end
        end
    end

    local ffi = require 'ffi'
local aimbot = {} do
    local recharge = {} do
        local switch = menu.aimbot.features.global.improvements
        local enable = menu.aimbot.features.global.aircharge
        local buffer = ffi.new('char[?]', 0x1D)
        local ogbytes = ffi.new('char[?]', 0x1D)
        local ptr = ffi.cast('char*', 0x433AC04B)
        ffi.copy(ogbytes, ptr, 0x1D)
        ffi.copy(buffer, ogbytes, 0x1D)
        ffi.fill(buffer, 0x18, 0x90)
        buffer[0x18] = 0xE9
        enable:set_callback(function (this)
            if not switch:get('Neverlose recharge') then
                return ffi.copy(ptr, ogbytes, 0x1D)
            end
            if this:get() then
                ffi.copy(ptr, buffer, 0x1D)
            else
                ffi.copy(ptr, ogbytes, 0x1D)
            end
        end, true)
    end
end

    ---------------------------------------------------------- clantag ----
    local clantag = { frames = {}, base = nil, last_idx = -1, active = false }

    local native_clantag, native_clantag_prev
    pcall(function() native_clantag = ui.reference('Misc', 'Miscellaneous', 'Clan tag') end)

    local function build_frames(base)
        base = (base and base ~= '') and base or 'Lunaris'
        local padded, frames = base .. '   ', {}
        local n = #padded
        for i = 0, n - 1 do
            frames[#frames + 1] = padded:sub(i + 1) .. padded:sub(1, i)
        end
        return frames
    end

    local function clantag_enable()
        if clantag.active then return end
        clantag.active = true
        if native_clantag then
            pcall(function()
                native_clantag_prev = ui.get(native_clantag)
                ui.set(native_clantag, false)
            end)
        end
    end

    local function clantag_disable()
        if not clantag.active then return end
        clantag.active   = false
        clantag.last_idx = -1
        client.set_clan_tag('')
        if native_clantag and native_clantag_prev ~= nil then
            pcall(function() ui.set(native_clantag, native_clantag_prev) end)
        end
    end

    client.set_event_callback('net_update_end', function()
        if not menu.misc.clantag:get() then
            clantag_disable()
            return
        end
        local base = menu.misc.clantag_text:get()
        if base ~= clantag.base then
            clantag.base     = base
            clantag.frames   = build_frames(base)
            clantag.last_idx = -1
        end
        clantag_enable()
        local idx = math.floor(globals.curtime() * 3) % #clantag.frames + 1
        if idx ~= clantag.last_idx then
            clantag.last_idx = idx
            client.set_clan_tag(clantag.frames[idx])
        end
    end)

    client.set_event_callback('shutdown', function()
        client.set_clan_tag('')
    end)
end

-- 3. ANTI-AIM RUNTIME / BUILDER LOGIC --------------------------------

-- =====================================================================
--  Andromeda state machine (self / current_manual / statement)
--  Ported verbatim from Andromeda. The anti-aim builder below reads
--  statement.current, self.* and current_manual; without these blocks
--  they are nil. extrapolate_pos/self/statement register their own
--  setup_command/predict_command callbacks BEFORE anti_aim does.
-- =====================================================================
local function extrapolate_pos(position, tick, player)
    local sv_gravity = cvar.sv_gravity:get_float() * globals.tickinterval()
    local sv_jump_impulse = cvar.sv_jump_impulse:get_float() * globals.tickinterval()
    local p_origin, prev_origin = position, position
    local velocity = vector(entity.get_prop(player, 'm_vecVelocity'))
    local gravity = velocity.z > 0 and -sv_gravity or sv_jump_impulse
    for i = 1, tick do
        prev_origin = p_origin
        p_origin = vector(
            p_origin.x + (velocity.x * globals.tickinterval()),
            p_origin.y + (velocity.y * globals.tickinterval()),
            p_origin.z + (velocity.z+gravity) * globals.tickinterval()
        )

        local fraction = client.trace_line(-1, prev_origin.x, prev_origin.y, prev_origin.z, p_origin.x, p_origin.y, p_origin.z)
        if fraction <= 0.99 then
            return prev_origin
        end
    end

    return p_origin
end

local self = {
    defensive = {
        current = 0,
        max = 0,
    },
    movetype = 0,
    packets = 0,
    fakelag = 0,
    body_yaw = 0,
    breaking_lagcomp = false,
    weapon_ready = false,
    charged = false,
    on_land = false,
    air = false,
    crouch = false,
    moving = false,
    peeking = false,
    origin = vector(),
} do
    local FL_ONGROUND = bit.lshift(1, 0)
    local FL_FROZEN   = bit.lshift(1, 6)
    local pre_flags, post_flags = 0, 0
    local command_number = 0
    local max_tickbase = 0
    local last_send_choke = 0

    local function get_exploit(me)
        if not (interface.is_double_tap() or interface.is_on_shot_antiaim()) then
            self.charged = false
            return false
        end

        local m_nTickbase = entity.get_prop(me, 'm_nTickbase')
        self.charged = (globals.servertickcount() - m_nTickbase) >= 0
        return true
    end

    local function get_peeking(me)
        self.peeking = false
        if not me then
            self.peeking = false
            return false
        end

        if not self.moving then
            self.peeking = false
            return false
        end
        
        local threat = client.current_threat()
        if threat == nil then
            self.peeking = false
            return false
        end

        if entity.get_flag(threat, 'Hit') then
            self.peeking = true
            return true
        end
        
        if entity.get_flag(threat, 'Occluded') then
            self.peeking = false
            return false
        end

        local my_origin = extrapolate_pos(vector(client.eye_position()), 5, me)
        local threat_origin = vector(entity.get_origin(threat))
        
        local ent, dmg = client.trace_bullet(me, my_origin.x, my_origin.y, my_origin.z, threat_origin.x, threat_origin.y, threat_origin.z)
        if ent ~= nil and dmg > 0 then
            self.peeking = true
            return true
        end

        return false
    end

    function self.pre_predict_command(cmd)
        local me = entity.get_local_player()
        if not me then
            return
        end

        local m_fFlags = entity.get_prop(me, 'm_fFlags')
        pre_flags = m_fFlags
    end

    local function update_defensive(me)
        local m_nTickbase = entity.get_prop(me, 'm_nTickbase')
        if math.abs(m_nTickbase - max_tickbase) > 64 then
            max_tickbase = 0
        end
        
        local defensive_ticks_left = 0
        if m_nTickbase > max_tickbase then
            max_tickbase = m_nTickbase
        elseif max_tickbase > m_nTickbase then
            defensive_ticks_left = math.min(14, math.max(0, max_tickbase - m_nTickbase - 1))
        end

        if defensive_ticks_left > 0 then
            self.breaking_lagcomp = true
            self.defensive.current = defensive_ticks_left
            
            if self.defensive.max == 0 then
                self.defensive.max = defensive_ticks_left
                self.defensive.latest_update_defensive = globals.curtime()
            end

            self.defensive.inverse_current = math.abs(self.defensive.max-self.defensive.current)
        else
            self.breaking_lagcomp = false
            self.defensive.current = 0
            self.defensive.max = 0
            self.defensive.inverse_current = 0
        end
    end

    function self.predict_command(cmd)
        local me = entity.get_local_player()
        if not me then
            return
        end

        local m_fFlags = entity.get_prop(me, 'm_fFlags')
        post_flags = m_fFlags
        update_defensive(me)
    end
    
    function self.setup_command(cmd)
        local me = entity.get_local_player()
        if not me then
            return
        end

        local player = c_entity(me)
        if not player then
            return
        end

        local animstate = player:get_anim_state()
        if not animstate then
            return
        end
        
        local weapon = entity.get_player_weapon(me)
        if not weapon then
            return
        end

        local wpn_info = csgo_weapons[entity.get_prop(weapon, 'm_iItemDefinitionIndex')]
        if not wpn_info then
            return
        end

        local weapon_types = ({
            [0] = 'melee',
            [1] = 'pistols',
            [2] = 'smg',
            [3] = 'rifles',
            [4] = 'shotgun',
            [5] = 'sniper',
            [6] = 'machinegun',
            [7] = 'c4',
            [9] = 'grenade',
        })[wpn_info.weapon_type_int]

        if weapon_types == 'melee' or weapon_types == 'sniper'
            or (wpn_info.console_name:gsub('weapon_', '') == 'deagle' or wpn_info.is_revolver) then
            self.weapon = wpn_info.console_name:gsub('weapon_', ''):gsub("_.*", ""):gsub('bayonet', 'knife'):gsub('g3sg1', 'autosnipers'):gsub('scar20', 'autosnipers')
        else
            self.weapon = weapon_types
        end

        if last_send_choke > cmd.chokedcommands then
            self.fakelag = last_send_choke
        end

        last_send_choke = cmd.chokedcommands

        if cmd.chokedcommands == 0 then
            local m_flDuckAmount = entity.get_prop(me, 'm_flDuckAmount')
            self.body_yaw = math.normalize_yaw(animstate.eye_angles_y - animstate.goal_feet_yaw)
            self.crouch = m_flDuckAmount > 0
            self.packets =  self.packets + 1
        end
        
        get_exploit(me)

        self.moving = animstate.m_velocity >= 4
        self.air = bit.band(pre_flags,post_flags,FL_ONGROUND) == 0
        self.movetype = entity.get_prop(me, 'm_MoveType')
        self.on_land = animstate.hit_in_ground_animation
        local m_flNextSecondaryAttack = entity.get_prop(weapon, 'm_flNextSecondaryAttack')
        local m_flNextPrimaryAttack = entity.get_prop(weapon, 'm_flNextPrimaryAttack')
        local m_flNextAttack = entity.get_prop(me, 'm_flNextAttack')
        self.weapon_ready = (m_flNextAttack < globals.curtime()) and (m_flNextSecondaryAttack < globals.curtime()) and (m_flNextPrimaryAttack < globals.curtime())
        get_peeking(me)
    end

    client.set_event_callback('setup_command', self.setup_command)
    client.set_event_callback('predict_command', self.predict_command)
    client.set_event_callback('pre_predict_command', self.pre_predict_command)
    client.set_event_callback('level_init', function () max_tickbase = 0 end)
end

local current_manual = nil
local statement = {} do
    statement.current = 'STATE'
    local tracing = false
    local mp_only_cts_rescue_hostages = cvar.mp_only_cts_rescue_hostages
    local function can_player_pickup(me)
        local view = vector(client.camera_angles())
        local eye_pos = vector(client.eye_position())

        local forward = vector():init_from_angles(view.x, view.y)
        local eye_sight = eye_pos + forward * 128
        local fraction, ent = client.trace_line(me, eye_pos.x, eye_pos.y, eye_pos.z, eye_sight.x, eye_sight.y, eye_sight.z)

        if ent == -1 or fraction == 1.0 then
            return false
        end

        if entity.get_prop(me, 'm_bInBombZone') == 1 then
            local classname = entity.get_classname(ent)
            if classname:find 'CWeapon' then
                return true
            end

            return false
        end

        return true
    end

    local function should_use_legit_aa(me, weapon, cmd)
        if cmd.in_use ~= 1 then
            tracing = false
            return false
        end

        if entity.get_classname(weapon) == 'CC4' then
            return false
        end

        local eye_pos = vector(client.eye_position())
        local m_iTeamNum = entity.get_prop(me, 'm_iTeamNum')
        local bombs = entity.get_all 'CPlantedC4'
        local hostages = entity.get_all 'CHostage'
        if m_iTeamNum == 3 then
            for i = 1, #bombs do
                local bomb = bombs[i]
                local origin = vector(entity.get_origin(bomb))
                if eye_pos:dist2d(origin) < 62 then
                    return false
                end
            end
        end

        local can_pickup_hostage = m_iTeamNum == 3
        if (m_iTeamNum == 2) and mp_only_cts_rescue_hostages:get_string() == '0' then
            can_pickup_hostage = true
        end

        if can_pickup_hostage then
            for i = 1, #hostages do
                local host = hostages[i]
                local origin = vector(entity.get_origin(host))
                if eye_pos:dist2d(origin) < 62 then
                    return false
                end

                if entity.get_prop(me, 'm_hCarriedHostage') ~= nil then
                    return true
                end
            end
        end

        if not tracing then
            tracing = true
            if can_player_pickup(me) then
                return false
            end
        end
        
        return true
    end

    local manual_data = {}
    local function get_value(ref)
        local prev_active = manual_data[ref]
        local active, mode, key = ref:get()

        if prev_active == nil then
            manual_data[ref] = active
            return
        end

        if mode == 0 or mode == 3 or key == nil then
            return
        end

        if prev_active ~= active then
            manual_data[ref] = active
            return active, mode, key
        end
    end

    local function update_hotkey(ref, value)
        local active, mode = get_value(ref)
        if active == nil then
            return
        end

        if mode == 1 then
            if not active then
                current_manual = nil
                return
            end

            current_manual = value
            return
        end

        if mode == 2 then
            if current_manual == value then
                current_manual = nil
                return
            end

            current_manual = value
            return
        end
    end

    local function update_manual_hotkey()
        if not menu.antiaim.features:get('Manual AA') then
            current_manual = nil
            return
        end

        update_hotkey(menu.antiaim.manual_left, 'Left')
        update_hotkey(menu.antiaim.manual_right, 'Right')
        update_hotkey(menu.antiaim.manual_forward, 'Forward')
    end

    function statement.get(cmd)
        local me = entity.get_local_player()
        if not me then
            return
        end
        
        local weapon = entity.get_player_weapon(me)
        if not weapon then
            return
        end
        
        if should_use_legit_aa(me, weapon, cmd) and menu.antiaim.builder['Legit AA'].enabled:get() then
            statement.current = 'Legit AA'
            cmd.in_use = 0
            return
        end
        
        update_manual_hotkey()
        if current_manual ~= nil and menu.antiaim.builder['Manual AA'].enabled:get() then
            statement.current = 'Manual AA'
            return
        end

        -- On peek: highest situational priority, auto via peek detection.
        if self.peeking and menu.antiaim.builder['On peek'].enabled:get() then
            statement.current = 'On peek'
            return
        end

        -- Freestanding: active while the Freestanding bind is held.
        if menu.antiaim.freestanding:get() and menu.antiaim.freestanding.hotkey:get() and menu.antiaim.builder['Freestanding'].enabled:get() then
            statement.current = 'Freestanding'
            return
        end

        -- Fake lag: applies to ALL movement situations whenever NEITHER
        -- Double Tap NOR On-shot anti-aim are active. As soon as the user
        -- turns on DT or On-shot AA, the per-movement-state AA settings
        -- (Air / Running / Duck / etc.) take over.
        if menu.antiaim.builder['Fake lag']
            and menu.antiaim.builder['Fake lag'].enabled
            and menu.antiaim.builder['Fake lag'].enabled:get()
            and not interface.is_double_tap()
            and not interface.is_on_shot_antiaim()
        then
            statement.current = 'Fake lag'
            return
        end

        if self.air then
            statement.current = self.crouch and 'Air Crouch' or 'Air'
            return
        end

        if self.moving then
            statement.current = (self.crouch and menu.antiaim.builder['Duck Move'].enabled:get()) and 'Duck Move' or
                ((interface.is_slow_motion() and menu.antiaim.builder['Slow-motion'].enabled:get()) and 'Slow-motion' or 'Running')
            return
        else
            statement.current = self.crouch and 'Duck' or 'Standing'
            return
        end
    end

    client.set_event_callback('setup_command', statement.get)
end

-- =====================================================================
--  get_closest_enemy (Andromeda helper)
--  Возвращ��ет (distance, entindex) ближайшего живого/не��ормантного врага.
--  Используется avoid_backstab — без неё ��ключение "Avoid backstab" падает
--  с `attempt to call a nil value (global 'get_closest_enemy')`.
--  Порт 1:1 из andromeda  deobfus.lua (строка ~1891).
-- =====================================================================
local function get_closest_enemy()
    local me = entity.get_local_player()
    local closest_distance, closest_enemy = math.huge, nil
    for _, enemy in ipairs(entity.get_players(true)) do
        local eye_pos = vector(entity.get_origin(enemy))
        local distance = eye_pos:dist(vector(entity.get_origin(me)))
        if distance < closest_distance then
            closest_distance = distance
            closest_enemy = enemy
        end
    end

    return closest_distance, closest_enemy
end

-- Port из priora: 3D-дистанция для Avoid Backstab
local function anti_knife_dist(x1, y1, z1, x2, y2, z2)
    return math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2 + (z2 - z1) ^ 2)
end

-- Port Ð¸Ð· priora: Ð¿ÑÐ¾Ð²ÐµÑÐºÐ° ÑÑÐ¾ Ð²ÑÐµ Ð²ÑÐ°Ð³Ð¸ Ð¼ÐµÑÑÐ²Ñ (Ð´Ð»Ñ Spinner override).
local function are_enemies_dead()
    local me = entity.get_local_player()
    if not me then
        return false
    end

    local my_team = entity.get_prop(me, 'm_iTeamNum')
    local player_resource = entity.get_player_resource()
    if not player_resource then
        return false
    end

    for i = 1, globals.maxplayers() do
        local is_connected = entity.get_prop(player_resource, 'm_bConnected', i)
        if is_connected == 1 then
            local player_team = entity.get_prop(player_resource, 'm_iTeam', i)
            if i ~= me and player_team ~= my_team then
                local is_alive = entity.get_prop(player_resource, 'm_bAlive', i)
                if is_alive == 1 then
                    return false
                end
            end
        end
    end

    return true
end

local anti_aim = {
    yaw = 0,
    tickcount = 0,
    tickcount_randomize_yaw = 0,
    tickcount_defensive_yaw = 0,
    tickcount_defensive_pitch = 0,
    defensive_yaw = 0,
    defensive_pitch = 0,
    backtrack_cleaner_ticks = 0,
    backtrack_cleaner_time = 0,
    backtrack_interval = 11,
    backtrack_pause_interval = 36,
    tickcount_refraction_yaw = 0,
    next_tick_for_phase = globals.curtime(),
    left_phase = 1,
    right_phase = 1,
    automatic_phase_left = {
        [1] = 1,
        [2] = 1,
        [3] = 1,
        [4] = 1,
        [5] = 1,
    },
    automatic_phase_right = {
        [1] = 1,
        [2] = 1,
        [3] = 1,
        [4] = 1,
        [5] = 1,
    },
    hidden = false,
    refraction_state = {
        start_angle = 0,
        target_angle = 0,
        start_time = globals.realtime(),
        next_side = 1,
        initialized = false
    },
    refraction_pitch_state = {
        base_pitch = 0,
        target_pitch = 0,
        start_time = globals.realtime(),
        spin_dir = 1,
        initialized = false
    }
} do
    local function manual_yaw(state, avoid_backstab_check)
        if not menu.antiaim.features:get('Manual AA') or avoid_backstab_check or
            current_manual == nil or state == 'Legit AA' then
            return 0
        end
        
        local manuals = {
            ['Left'] = -90,
            ['Right'] = 90,
            ['Forward'] = 180,
        }

        return manuals[current_manual] or 0
    end
 
    local function break_lc(cmd, current_state, state)
        local me = entity.get_local_player()
        if state == 'Legit AA' then
            return false
        end

        if not self.charged then
            return false
        end

        if self.weapon == 'grenade' then
            cmd.force_defensive = false
            return false
        end
        
        local force_break_lc = menu.antiaim.builder[current_state].defensive.break_lc
        if interface.is_double_tap() then
            if force_break_lc:get('Double tap') then
                cmd.force_defensive = true
                return true
            end
        elseif interface.is_on_shot_antiaim() then
            return force_break_lc:get('On shot anti-aim')
        end

        return false
    end
    
    local anti_brute_state = {}
    local anti_brute_state_yaw = {}
    for key, value in pairs(anti_aim_states) do
        anti_brute_state[value] = {
            ['active'] = false,
            ['delay_amount'] = 0,
            ['sec_delay_amount'] = 0,
            ['timer'] = globals.curtime()
        }
        anti_brute_state_yaw[value] = {
            ['active'] = false,
            ['mode'] = 0,
            ['phase'] = 0,
            ['timer'] = globals.curtime()
        }
    end

    local hitted_tick = 0
    local function player_hurt(e)
        local me = entity.get_local_player()
        if client.userid_to_entindex(e.userid) ~= me then
            return
        end

        hitted_tick = globals.tickcount()
    end

    local function get_current_state(state)
        local state_settings = menu.antiaim.builder[state]
        if not state_settings then
            return anti_aim_states[1]
        end

        return state_settings.enabled and (state_settings.enabled:get() and state or anti_aim_states[1]) or anti_aim_states[1]
    end

    local function get_miss(e)
        local me = entity.get_local_player()
        if not (me and entity.is_alive(me)) or hitted_tick == globals.tickcount() then
            return
        end

        local entity_fire = client.userid_to_entindex(e.userid)
        if not entity_fire or entity.is_dormant(entity_fire) or not entity.is_enemy(entity_fire) then
            return
        end

        local current_state = statement.current
        if current_state == 'STATE' then
            return
        end
        
        local state = get_current_state(current_state)
        if anti_brute_state[state] == nil then
            anti_brute_state[state] = {
                ['active'] = false,
                ['delay_amount'] = 0,
                ['sec_delay_amount'] = 0,
                ['timer'] = globals.curtime()
            }
        end

        if anti_brute_state_yaw[state] == nil then
            anti_brute_state_yaw[state] = {
                ['active'] = false,
                ['phase'] = 0,
                ['timer'] = globals.curtime()
            }
        end

        local impact_origin = vector(e.x, e.y, e.z)
        local entity_origin = vector(entity.get_origin(entity_fire))
        local head_pos = vector(entity.hitbox_position(me, 0))
        local closest_point = math.closest_ray_point(head_pos, entity_origin, impact_origin)
        local dist = head_pos:dist(closest_point)
        
        if dist > 80 then
            return
        end

        if menu.antiaim.builder[state].anti_brute.enabled:get() then
            anti_brute_state_yaw[state] = {
                ['active'] = true,
                ['phase'] = anti_brute_state_yaw[state]['phase'] + 1,
                ['timer'] = globals.curtime()
            }

            if anti_brute_state_yaw[state]['phase'] > 5 then
                anti_brute_state_yaw[state]['phase'] = 1
            end
        end

        if menu.antiaim.builder[state].body_yaw.type:get() == package.scriptname then
            local amount = client.random_int(1, menu.antiaim.builder[state].body_yaw.tick_min:get())
            local second_amount = client.random_int(1, menu.antiaim.builder[state].body_yaw.tick_max:get())
            if menu.antiaim.builder[state].body_yaw.andromeda_antibrute:get() == 'One delay' then
                local delay = client.random_int(1, menu.antiaim.builder[state].body_yaw.one_delay:get())
                amount = delay
                second_amount = delay
            end
            
            anti_brute_state[state] = {
                ['active'] = true,
                ['delay_amount'] = amount,
                ['sec_delay_amount'] = second_amount,
                ['timer'] = globals.curtime()
            }
        end
    end
    
    local function reset_all_antibrute_states()
        for state, _ in pairs(anti_brute_state) do
            anti_brute_state[state] = {
                ['active'] = false,
                ['delay_amount'] = 0,
                ['sec_delay_amount'] = 0,
                ['timer'] = globals.curtime()
            }
        end

        for state, _ in pairs(anti_brute_state_yaw) do
            anti_brute_state_yaw[state] = {
                ['active'] = false,
                ['phase'] = 0,
                ['timer'] = globals.curtime()
            }
        end
    end

    local function player_death(e)
        local me = entity.get_local_player()
        if client.userid_to_entindex(e.userid) ~= me then
            return
        end

        reset_all_antibrute_states()
    end

    local function randomize(value, percent)
        if percent == 0 then
            return value
        end

        local random_value = value * (percent * 0.01)
        return client.random_int(value - random_value, value + random_value)
    end
    
    -- =============================================================
    --  Avoid Backstab — порт из priora (prioralast).
    --  Отличия от Andromeda-варианта:
    --    • проверяются ВСЕ враги с ножом (не только ближайший);
    --    • дистанция — из слайдера menu.antiaim.avoid_distance (0–1000u);
    --    • без жесткого флага 'Hit' — срабатывает раньше;
    --    • 3D-дистанция (anti_knife_dist), не dist2d.
    -- =============================================================
    local function avoid_backstab(state)
        if not menu.antiaim.features:get('Avoid backstab') then
            return false
        end

        if state == 'Legit AA' then
            return false
        end

        local me = entity.get_local_player()
        if not me or not entity.is_alive(me) then
            return false
        end

        local max_dist = menu.antiaim.avoid_distance:get()
        if max_dist <= 0 then
            return false
        end

        local lp_x, lp_y, lp_z = entity.get_prop(me, 'm_vecOrigin')
        if not lp_x then
            return false
        end

        local players = entity.get_players(true)
        for i = 1, #players do
            local enemy = players[i]
            local weapon = entity.get_player_weapon(enemy)
            if weapon and entity.get_classname(weapon) == 'CKnife' then
                local ex, ey, ez = entity.get_prop(enemy, 'm_vecOrigin')
                if ex and anti_knife_dist(lp_x, lp_y, lp_z, ex, ey, ez) <= max_dist then
                    return true
                end
            end
        end

        return false
    end

    local function safehead(state)
        if state == 'Legit AA' or state == 'Manual AA' then
            return false
        end

        local me = entity.get_local_player()
        if not menu.antiaim.features:get('Height advantage') then
            return false
        end

        local enemy = client.current_threat()
        if not enemy then
            return false
        end

        if entity.lethal(me, enemy) then
            return false
        end

        if not entity.get_flag(enemy, 'Hit') then
            return false
        end

        local knife = self.weapon == 'knife'
        local taser = self.weapon == 'taser'
        local local_origin = vector(entity.get_origin(me)) + vector(entity.get_prop(me, 'm_vecViewOffset'))
        local enemy_origin = vector(entity.get_origin(enemy)) + vector(entity.get_prop(enemy, 'm_vecViewOffset'))

        local height = local_origin.z - enemy_origin.z

        local weapon_model_mod = math.max(0, 20 - math.abs(vector(entity.get_prop(me, 'm_vecMins')).z + vector(entity.get_prop(me, 'm_vecMaxs')).z))
        local pitch_mod = knife and 0 or weapon_model_mod
        local pitch = 89 - pitch_mod
        local m = -22.0676
        local b = 1949.0164
        local minimal_height = math.min(70, m * pitch + b)
        if minimal_height <= height and height >= 50 and knife then
            return true
        elseif minimal_height <= height and height >= 30 and taser then
            return true
        elseif minimal_height <= height and height >= 70 and not knife and not taser then
            return true
        elseif state == 'Air Сrouch' and knife then
            return true
        end

        return false
    end

    local function update_delay(cmd, state, settings, current_state)
        if cmd.chokedcommands ~= 0 then
            return false
        end

        if self.fakelag > 6 then
            anti_aim.tickcount = anti_aim.tickcount + 1
            return false
        end

        if state ~= 'Legit AA' then
            if self.packets % settings.defensive.pitch.delay:get() == 0 then
                anti_aim.tickcount_defensive_pitch = anti_aim.tickcount_defensive_pitch + 1
            end
    
            if settings.defensive.yaw.type:get() == 'Random' then
                if self.packets % settings.defensive.yaw.delay:get() == 0 then
                    anti_aim.tickcount_defensive_yaw = anti_aim.tickcount_defensive_yaw + 1
                end

            elseif settings.defensive.yaw.type:get() == 'Side Based' and settings.defensive.yaw.add_on:get('Delay') then
                local amount = settings.defensive.yaw.left_delay:get()
                local second_amount = settings.defensive.yaw.right_delay:get()
                local random_delay1 = settings.defensive.yaw.add_on:get('Randomized delay') and settings.defensive.yaw.left_random_delay:get() or 0
                local random_delay2 = settings.defensive.yaw.add_on:get('Randomized delay') and settings.defensive.yaw.right_random_delay:get() or 0
    
                local delay_amount = (anti_aim.tickcount_defensive_yaw % 2 == 0) and amount + client.random_int(0, random_delay1) or second_amount + client.random_int(0, random_delay2)
                if self.packets % delay_amount == 0 then
                    anti_aim.tickcount_defensive_yaw = anti_aim.tickcount_defensive_yaw + 1
                end
            else
                if self.packets % 1 == 0 then
                    anti_aim.tickcount_defensive_yaw = anti_aim.tickcount_defensive_yaw + 1
                end
            end
        end

        if settings.body_yaw.type:get() == package.scriptname and settings.body_yaw.andromeda_mode:get() == 'Phase' then
            if settings.body_yaw.phasemode:get() == 'Custom' then
                local left_phase = {
                    [1] = settings.body_yaw.phase.sliderleft1:get(),
                    [2] = settings.body_yaw.phase.sliderleft2:get(),
                    [3] = settings.body_yaw.phase.sliderleft3:get(),
                    [4] = settings.body_yaw.phase.sliderleft4:get(),
                    [5] = settings.body_yaw.phase.sliderleft5:get(),
                }

                local right_phase = {
                    [1] = settings.body_yaw.phase.sliderright1:get(),
                    [2] = settings.body_yaw.phase.sliderright2:get(),
                    [3] = settings.body_yaw.phase.sliderright3:get(),
                    [4] = settings.body_yaw.phase.sliderright4:get(),
                    [5] = settings.body_yaw.phase.sliderright5:get(),
                }

                local left_delay = left_phase[anti_aim.left_phase]
                local right_delay = right_phase[anti_aim.right_phase]
                local inv = anti_aim.tickcount % 2 == 0
                if self.packets % (inv and left_delay or right_delay) == 0 then
                    if inv then
                        anti_aim.left_phase = anti_aim.left_phase + 1
                        if anti_aim.left_phase > settings.body_yaw.phase.phases:get() then
                            anti_aim.left_phase = 1
                        end
                    else
                        anti_aim.right_phase = anti_aim.right_phase + 1
                        if anti_aim.right_phase > settings.body_yaw.phase.phases:get() then
                            anti_aim.right_phase = 1
                        end
                    end

                    anti_aim.tickcount = anti_aim.tickcount + 1
                end
            elseif settings.body_yaw.phasemode:get() == 'Automatic' then
                local state = 'not updating'
                local max_left_phases = 5
                local max_right_phases = 5
                local left_delay = anti_aim.automatic_phase_left[anti_aim.left_phase]
                local right_delay = anti_aim.automatic_phase_right[anti_aim.right_phase]

                if self.defensive.inverse_current > 0 and self.defensive.inverse_current <= 2 then
                    --update
                    if settings.body_yaw.phase.pattern_mode:get() == 'Decrease' then
                        anti_aim.automatic_phase_left = {
                            [1] = client.random_int(3, 6),
                            [2] = client.random_int(1, 3),
                            [3] = client.random_int(2, 8),
                            [4] = client.random_int(4, 5),
                            [5] = client.random_int(1, 14),
                        }

                        anti_aim.automatic_phase_right = {
                            [1] = client.random_int(2, 8),
                            [2] = client.random_int(2, 5),
                            [3] = client.random_int(1, 8),
                            [4] = client.random_int(4, 5),
                            [5] = client.random_int(1, 14),
                        }
                    else
                        anti_aim.automatic_phase_left = {
                            [1] = client.random_int(1, 8),
                            [2] = client.random_int(2, 6),
                            [3] = client.random_int(4, 9),
                            [4] = client.random_int(6, 8),
                            [5] = client.random_int(1, 10),
                        }

                        anti_aim.automatic_phase_right = {
                            [1] = client.random_int(1, 9),
                            [2] = client.random_int(2, 8),
                            [3] = client.random_int(4, 12),
                            [4] = client.random_int(6, 10),
                            [5] = client.random_int(1, 2),
                        }
                    end
                    state = 'update'
                elseif self.defensive.current <= 5 and self.defensive.current > 0 then
                    --force
                    left_delay = client.random_int(5, 6)
                    right_delay = client.random_int(5, 6)
                    state = 'force'
                elseif self.peeking then
                    --peeking
                    max_left_phases = 3
                    max_right_phases = 3
                    if settings.body_yaw.phase.pattern_mode:get() == 'Increase' then
                        anti_aim.automatic_phase_left = {
                            [1] = client.random_int(1, 2),
                            [2] = client.random_int(1, 2),
                            [3] = client.random_int(4, 6),
                            [4] = 1,
                            [5] = 1,
                        }
                        anti_aim.automatic_phase_right = {
                            [1] = client.random_int(1, 4),
                            [2] = client.random_int(2, 3),
                            [3] = client.random_int(3, 5),
                            [4] = 1,
                            [5] = 1,
                        }
                    else
                        anti_aim.automatic_phase_left = {
                            [1] = client.random_int(5, 5),
                            [2] = client.random_int(6, 6),
                            [3] = client.random_int(4, 5),
                            [4] = 1,
                            [5] = 1,
                        }
                        anti_aim.automatic_phase_right = {
                            [1] = client.random_int(6, 7),
                            [2] = client.random_int(6, 6),
                            [3] = client.random_int(7, 7),
                            [4] = 1,
                            [5] = 1,
                        }
                    end
                    state = 'peeking'
                elseif globals.curtime() >= anti_aim.next_tick_for_phase then
                    --force update
                    anti_aim.next_tick_for_phase = globals.curtime() + settings.body_yaw.phase.phase:get() / 100
                    if settings.body_yaw.phase.pattern_mode:get() == 'Decrease' then
                        anti_aim.automatic_phase_left = {
                            [1] = client.random_int(1, 3),
                            [2] = client.random_int(2, 4),
                            [3] = client.random_int(3, 5),
                            [4] = client.random_int(4, 6),
                            [5] = client.random_int(5, 7),
                        }
                        anti_aim.automatic_phase_right = {
                            [1] = client.random_int(4, 8),
                            [2] = client.random_int(2, 6),
                            [3] = client.random_int(3, 5),
                            [4] = client.random_int(1, 2),
                            [5] = client.random_int(2, 5),
                        }
                    else
                        anti_aim.automatic_phase_left = {
                            [1] = client.random_int(1, 2),
                            [2] = client.random_int(3, 7),
                            [3] = client.random_int(4, 6),
                            [4] = client.random_int(5, 8),
                            [5] = client.random_int(6, 7),
                        }
                        anti_aim.automatic_phase_right = {
                            [1] = client.random_int(5, 6),
                            [2] = client.random_int(3, 9),
                            [3] = client.random_int(5, 12),
                            [4] = client.random_int(1, 2),
                            [5] = client.random_int(6, 9),
                        }
                    end
                    state = 'force update'
                end

                local inv = anti_aim.tickcount % 2 == 0
                if self.packets % (inv and left_delay or right_delay) == 0 then
                    if inv then
                        anti_aim.left_phase = anti_aim.left_phase + 1
                        if anti_aim.left_phase > max_left_phases then
                            anti_aim.left_phase = 1
                        end
                    else
                        anti_aim.right_phase = anti_aim.right_phase + 1
                        if anti_aim.right_phase > max_right_phases then
                            anti_aim.right_phase = 1
                        end
                    end

                    anti_aim.tickcount = anti_aim.tickcount + 1
                end
            end

            return true
        end

        local amt = settings.delay.enabled:get('Side based') and settings.delay.left_delay_ticks:get() or 1
        local sec_amt = settings.delay.enabled:get('Side based') and settings.delay.right_delay_ticks:get() or 1
        if self.peeking and settings.body_yaw.andromeda_mode:get() == 'Peeking' then
            amt = client.random_int(1, 4)
            sec_amt = client.random_int(1, 4)
        elseif anti_brute_state[current_state].active and settings.body_yaw.andromeda_mode:get() == 'Anti-bruteforce' then
            if globals.curtime() >= anti_brute_state[current_state].timer + 3 then
                anti_brute_state[current_state].active = false
            end

            amt = anti_brute_state[current_state].delay_amount
            sec_amt = anti_brute_state[current_state].sec_delay_amount
        end

        local amount = settings.body_yaw.type:get() == package.scriptname and ((anti_brute_state[current_state].active and settings.body_yaw.andromeda_mode:get() == 'Anti-bruteforce')
            or (settings.body_yaw.andromeda_mode:get() == 'Peeking' and self.peeking))
                and amt or (settings.delay.enabled:get('Side based') and settings.delay.left_delay_ticks:get() or 1)
        local second_amount = settings.body_yaw.type:get() == package.scriptname and ((anti_brute_state[current_state].active and settings.body_yaw.andromeda_mode:get() == 'Anti-bruteforce')
            or (settings.body_yaw.andromeda_mode:get() == 'Peeking' and self.peeking))
                and sec_amt or (settings.delay.enabled:get('Side based') and settings.delay.right_delay_ticks:get() or 1)

        if amount == 1 and second_amount == 1 then
            anti_aim.tickcount = anti_aim.tickcount + 1
            return true
        end

        local delay_amount = (anti_aim.tickcount % 2 == 0) and amount or second_amount
        if self.packets % delay_amount == 0 then
            anti_aim.tickcount = anti_aim.tickcount + 1
        end

        return true
    end

    local function update_randomize(cmd, settings)
        if cmd.chokedcommands ~= 0 then
            return false
        end

        if not settings.delay.enabled:get('Delay on randomize') then
            if self.packets % 2 == 0 then
                anti_aim.tickcount_randomize_yaw = anti_aim.tickcount_randomize_yaw + 1
            end
            
            return false
        end

        local amount = settings.yaw.left_randomize:get() and settings.delay.left_random_delay_ticks:get() or 1
        local secondamount = settings.yaw.right_randomize:get() and settings.delay.right_random_delay_ticks:get() or 1

        local inverter = anti_aim.tickcount % 2 == 0
        local delay_amount = inverter and amount or secondamount
        if self.packets % delay_amount == 0 then
            anti_aim.tickcount_randomize_yaw = anti_aim.tickcount_randomize_yaw + 1
        end

        return true
    end

    local function yaw_modifier(settings, inverter)
        local modifier = settings.yaw_modifier
        if modifier.type:get() == 'Off' then
            return 0
        end
        
        local value = modifier.offset:get()
        local types = {
            ['Offset'] = function()
                return inverter and value or 0
            end,
            ['Center'] = function()
                value = value * 0.5
                return inverter and -value or value
            end,
            ['Random'] = function()
                return math.random(-value, value)
            end,
            ['Spin'] = function ()
                local spin = 0
                local invert = inverter and -1 or 1
                spin = spin + invert * math.lerp(0, value, globals.curtime() * 3 % 2-1)
                return spin
            end,
            ['Rays'] = function()
                local time = globals.curtime()
                local speed = 1.5
                local rays = 3
                local chaos = 0.2

                local result = 0

                -- Основной паттерн
                for i = 1, rays do
                    local angle = (i - 1) * (math.pi * 2 / rays)
                    local ray_value = math.sin(time * speed + angle) * value / rays

                    if math.random() < chaos then
                        ray_value = ray_value * math.random(0.5, 1.5)
                    end

                    result = result + ray_value
                end

                return inverter and -result or result
            end,
        }

        return (types[modifier.type:get()] or function() return 0 end)()
    end

    local function yaw_modifier_anti_brute(settings, inverter, phase)
        local modifier = settings.anti_brute.phase[phase].yaw_modifier:get()
        if modifier == 'Off' then
            return 0
        end

        local value = settings.anti_brute.phase[phase].yaw_modifier_limit:get()
        local modifier_funcs = {
            ['Offset'] = function()
                return inverter and value or 0
            end,
            ['Center'] = function()
                return inverter and -value*.5 or value*.5
            end,
            ['Random'] = function()
                return client.random_int(-value, value)
            end,
            ['Spin'] = function ()
                local spin = 0
                spin = spin + (inverter and -1 or 1) * math.lerp(0, value, globals.curtime() * 3 % 2-1)
                return spin
            end,
        }

        return (modifier_funcs[modifier] or function() return 0 end)()
    end

    local left_ab = 0
    local right_ab = 0
    local function yaw_update(state, settings, avoid_backstab, manual_yaw)
        local yaw_type = settings.yaw.type:get()
        local inverter = anti_aim.tickcount % 2 == 0
        local randomize_yaw = anti_aim.tickcount_randomize_yaw % 2 == 0
        if yaw_type == 'Static' then
            local static_yaw = settings.yaw.static:get()
            anti_aim.yaw = static_yaw
        elseif yaw_type == 'L/R' then
            local yaw = inverter and settings.yaw.left:get() or settings.yaw.right:get()
            if randomize_yaw then
                yaw = randomize(yaw, inverter and (settings.yaw.left_randomize:get() and settings.yaw.randomize_left:get() or 0) or (settings.yaw.right_randomize:get() and settings.yaw.randomize_right:get() or 0))
            end

            anti_aim.yaw = yaw
        elseif yaw_type == 'Sway' then
            local sway_side = inverter and settings.yaw.swayleft:get() or settings.yaw.swayright:get()
            local sway = math.lerp(0, sway_side, globals.curtime() * 4 % 2-1)
            local yaw = (inverter and settings.yaw.left:get() or settings.yaw.right:get()) + sway
            if randomize_yaw then
                yaw = randomize(yaw, inverter and (settings.yaw.left_randomize:get() and settings.yaw.randomize_left:get() or 0) or (settings.yaw.right_randomize:get() and settings.yaw.randomize_right:get() or 0))
            end

            anti_aim.yaw = yaw
        elseif yaw_type == 'X-way' then
            local way = {settings.yaw.x_way1:get(), settings.yaw.x_way2:get(), settings.yaw.x_way3:get(), settings.yaw.x_way4:get(), settings.yaw.x_way5:get()}
            anti_aim.yaw = way[anti_aim.tickcount % #way + 1]
        end
        
        local anti_brute_yaw = 0
        if settings.anti_brute.enabled:get() then
            if anti_brute_state_yaw[state].active then
                local phase = anti_brute_state_yaw[state].phase
                local current_yaw = 0
                if settings.anti_brute.mode:get() == 'Timer' then
                    if math.abs(globals.curtime() - anti_brute_state_yaw[state].timer) >= settings.anti_brute.time:get() then
                        anti_brute_state_yaw[state].active = false
                        anti_brute_state_yaw[state].timer = globals.curtime()
                    end
                end
                
                if settings.anti_brute.phase[phase].yaw:get() == 'Auto' then
                    current_yaw = math.sign(anti_aim.yaw) > 0 and 4 or -4
                elseif settings.anti_brute.phase[phase].yaw:get() == 'Left & Right' then
                    if left_ab == 0 then
                        left_ab = client.random_int(math.min(0, settings.anti_brute.phase[phase].yaw_left:get()), math.max(0, settings.anti_brute.phase[phase].yaw_left:get()))
                    end

                    if right_ab == 0 then
                        right_ab = client.random_int(math.min(0, settings.anti_brute.phase[phase].yaw_right:get()), math.max(0, settings.anti_brute.phase[phase].yaw_right:get()))
                    end

                    current_yaw = inverter and left_ab or right_ab
                end

                anti_brute_yaw = yaw_modifier_anti_brute(settings, inverter, phase) + current_yaw
            else
                right_ab = 0
                anti_brute_state_yaw[state].phase = 0
                left_ab = 0
            end

        end

        if avoid_backstab or state == 'Legit AA' then
            anti_aim.yaw = anti_aim.yaw + 180
        end


        anti_aim.yaw = math.normalize_yaw(anti_aim.yaw + yaw_modifier(settings, inverter) + anti_brute_yaw + manual_yaw)
    end

    local random_pitch = 0
    local function defensive_pitch_update(settings)
        local pitch = settings.defensive.pitch.type
        if pitch:get() == 'Default' then
            return 89
        end
        
        local up = settings.defensive.pitch.up:get()
        local down = settings.defensive.pitch.down:get()
        local tick = settings.defensive.pitch.tick:get()
        local delay = settings.defensive.pitch.delay:get()
        local up_refraction = settings.defensive.pitch.up_refraction:get()
        local down_refraction = settings.defensive.pitch.down_refraction:get()
        local spin_refraction = settings.defensive.pitch.spin_refraction:get()
        local timer_refraction = settings.defensive.pitch.refraction_timer:get()
        local random_type = settings.defensive.pitch.random_type:get()
        
        local inverter = anti_aim.tickcount_defensive_pitch % 2 == 0
        local type_pitch = {
            ['Auto'] = function ()
                local me = entity.get_local_player()
                if not me or not entity.is_alive(me) then return 0 end
            
                local current_threat = client.current_threat()
                if not current_threat or not entity.is_alive(current_threat) then
                    return 0
                end
            
                if not self.peeking then
                    return 0
                end
            
                anti_aim.pitch_state = anti_aim.pitch_state or { stage = 1, start_time = globals.realtime() }
                local state = anti_aim.pitch_state
                local now = globals.realtime()
                local stage_duration = 0.7
            
                local pitch_value = 0
            
                if state.stage == 1 then
                    pitch_value = math.sin(now * 8) * 89

                elseif state.stage == 2 then
                    pitch_value = client.random_int(-20, 20)

                elseif state.stage == 3 then
                    pitch_value = -89

                elseif state.stage == 4 then
                    local swing = math.sin(now * 4) * 45
                    pitch_value = math.max(-89, math.min(89, swing))

                elseif state.stage == 5 then
                    local step = math.floor(now * 3) % 5
                    local steps = {-75, -40, 0, 40, 75}
                    pitch_value = steps[step + 1]

                elseif state.stage == 6 then
                    local base = client.random_int(-5, 5)
                    local jitter = math.sin(now * 12) * 3
                    pitch_value = base + jitter
                end
            
                if now - state.start_time >= stage_duration then
                    state.stage = (state.stage % 6) + 1
                    state.start_time = now
                end
            
                return pitch_value
            end,
            ['Random'] = function ()
                if random_type == 'Default' then
                    if inverter then
                        random_pitch = client.random_int(up, down)
                    end
                elseif random_type == 'Random static' then
                    if self.defensive.current == delay then
                        random_pitch = client.random_int(up, down)
                    end
                end

                return random_pitch
            end,
            ['Sinus'] = function ()
                return math.lerp(up, down, math.abs(math.sin(globals.realtime() * (tick * 0.1))))
            end,
            ['Spinable'] = function ()
                return math.lerp(up, down, (globals.realtime() * (tick * 0.1)) % 1)
            end,
            ['Jitter'] = function ()
                return inverter and up or down
            end,
            ['Custom'] = function ()
                return up
            end,
            ['Refraction'] = function ()
                local state = anti_aim.refraction_pitch_state
                local now = globals.realtime()

                local pitch_min = down_refraction
                local pitch_max = up_refraction
                local spin_angle = spin_refraction
                local spin_time = math.max(timer_refraction / 10, 0.01)

                if not state.initialized then
                    state.initialized = true
                    state.base_pitch = math.random(pitch_min, pitch_max)
                    state.spin_dir = (math.random(0, 1) == 0) and -1 or 1
                    state.target_pitch = state.base_pitch + (spin_angle * state.spin_dir)
                    state.start_time = now
                end
            
                local elapsed = now - state.start_time
            
                if elapsed >= spin_time then
                    state.base_pitch = math.random(pitch_min, pitch_max)
                    state.spin_dir = (math.random(0, 1) == 0) and -1 or 1
                    state.target_pitch = state.base_pitch + (spin_angle * state.spin_dir)
                    state.start_time = now
                    elapsed = 0
                end
            
                local progress = math.min(elapsed / spin_time, 1.0)
                return state.base_pitch + (state.target_pitch - state.base_pitch) * progress
            end
        }
        
        return (type_pitch[pitch:get()] or function() return 89 end)()
    end
    
    local random_yaw = 0
    local function defensive_yaw_update(settings)
        local yaw = settings.defensive.yaw.type
        if yaw:get() == 'Static' then
            return 180
        end

        local left = settings.defensive.yaw.left:get()
        local right = settings.defensive.yaw.right:get()
        local left_refraction = settings.defensive.yaw.refraction_left:get()
        local right_refraction = settings.defensive.yaw.refraction_right:get()
        local spin_refraction = settings.defensive.yaw.refraction_spin:get()
        local delay = settings.defensive.yaw.delay:get()
        local tick = settings.defensive.yaw.tick:get()
        local random_type = settings.defensive.yaw.random_type:get()
        local inverter = anti_aim.tickcount_defensive_yaw % 2 == 0
        local timer_refraction = settings.defensive.yaw.refraction_timer:get()
        local type_yaw = {
            ['Auto'] = function ()
                local me = entity.get_local_player()
                if not me or not entity.is_alive(me) then return 0 end
            
                local current_threat = client.current_threat()
                if not current_threat or not entity.is_alive(current_threat) then
                    return inverter and -90 or 90
                end
            
                local me_x, me_y, me_z = entity.get_origin(me)
                local enemy_x, enemy_y, enemy_z = entity.get_origin(current_threat)

                if not me_x or not enemy_x then
                    return inverter and -90 or 90
                end
            
                local delta_x = enemy_x - me_x
                local delta_y = enemy_y - me_y
                local enemy_yaw = math.deg(math.atan2(delta_y, delta_x))
            
                local yaw_value = 0
            
                if not self.peeking then
                    local time = globals.realtime()
                    local base_jitter = (time * 540) % 360 - 180
                    local micro_jitter = math.sin(time * 10) * 15
                    local random_jitter = client.random_int(-8, 8)

                    yaw_value = base_jitter + micro_jitter + random_jitter

                    if inverter then
                        yaw_value = -yaw_value
                    end

                    return yaw_value
                end
            
                anti_aim.auto_state = anti_aim.auto_state or { stage = 1, start_time = globals.realtime() }
                local state = anti_aim.auto_state
                local now = globals.realtime()
                local stage_duration = 0.8
            
                local yaw_offset = 0
                if self.peeking then
                    local _, view_yaw = client.camera_angles()
                    if view_yaw then
                        local diff = (enemy_yaw - view_yaw + 540) % 360 - 180
                        if diff > 0 then
                            yaw_offset = client.random_int(-12, -4)
                        else
                            yaw_offset = client.random_int(4, 12)
                        end
                    end
                end
            
                if state.stage == 1 then
                    yaw_value = (now * 720) % 360 + math.sin(now * 15) * 25 + yaw_offset

                elseif state.stage == 2 then
                    local swing_range = 120
                    yaw_value = math.sin(now * 3) * swing_range + (inverter and -60 or 60) + yaw_offset

                elseif state.stage == 3 then
                    local step = math.floor(now * 2) % 4
                    local steps = {-90, -45, 45, 90}
                    yaw_value = steps[step + 1] + client.random_int(-25, 25) + yaw_offset

                elseif state.stage == 4 then
                    yaw_value = enemy_yaw + 180 + math.sin(now * 8) * 35 + yaw_offset

                elseif state.stage == 5 then
                    local drift = math.sin(now * 0.5) * 180
                    if math.abs(drift) > 150 then
                        yaw_value = client.random_int(-180, 180) + yaw_offset
                    else
                        yaw_value = drift + yaw_offset
                    end

                elseif state.stage == 6 then
                    local stick_time = now % 3
                    if stick_time < 2.5 then
                        yaw_value = (inverter and -75 or 75) + yaw_offset
                    else
                        yaw_value = client.random_int(-180, 180) + yaw_offset
                    end
                end
            
                if now - state.start_time >= stage_duration then
                    state.stage = (state.stage % 6) + 1
                    state.start_time = now
                end
            
                return yaw_value
            end,
            ['Random'] = function ()
                if random_type == 'Default' then
                    if inverter then
                        random_yaw = client.random_int(left, right)
                    end
                elseif random_type == 'Random static' then
                    if self.defensive.current == delay then
                        random_yaw = client.random_int(left, right)
                    end
                end

                return random_yaw
            end,
            ['180 Spin'] = function ()
                return math.lerp(left, right, (math.sin(globals.realtime() * (tick * 0.1))))
            end,
            ['Spinable'] = function ()
                return math.lerp(left, right, (globals.realtime() * (tick * 0.1)) % 1)
            end,
            ['Side Based'] = function ()
                return inverter and left or right
            end,
            ['Refraction'] = function()
                local state = anti_aim.refraction_state
                local now = globals.realtime()
            
                local yaw_min = left_refraction
                local yaw_max = right_refraction
                local spin_angle = spin_refraction
                local spin_time = math.max((timer_refraction / 10), 0.01)
            
                if not state.initialized then
                    state.initialized = true
                    state.base_yaw = math.random(yaw_min, yaw_max)
                    state.spin_dir = (math.random(0, 1) == 0) and -1 or 1
                    state.target_yaw = state.base_yaw + (spin_angle * state.spin_dir)
                    state.start_time = now
                end
            
                local elapsed = now - state.start_time
            
                if elapsed >= spin_time then
                    state.base_yaw = math.random(yaw_min, yaw_max)
                    state.spin_dir = (math.random(0, 1) == 0) and -1 or 1
                    state.target_yaw = state.base_yaw + (spin_angle * state.spin_dir)
                    state.start_time = now
                    elapsed = 0
                end
            
                local progress = math.min(elapsed / spin_time, 1.0)
                return state.base_yaw + (state.target_yaw - state.base_yaw) * progress
            end,
            ['Custom'] = function ()
                return left
            end
        }

        return (type_yaw[yaw:get()] or function() return 89 end)()
    end

    local function defensive_aa_update(settings, avoid_backstab, breaking_lc, state)
        anti_aim.hidden = false
        if state == 'Legit AA' or not settings.defensive.enabled:get() or avoid_backstab then
            return false
        end
        
        if not self.charged or not self.breaking_lagcomp then
            return false
        end
        
        if interface.is_on_shot_antiaim() and not breaking_lc then
            return false
        end
        
        anti_aim.defensive_yaw = defensive_yaw_update(settings)
        anti_aim.defensive_pitch = defensive_pitch_update(settings)
        
        anti_aim.hidden = true
        return true
    end

    local function disabler()
        if not menu.antiaim.features:get('Disablers') then
            return false
        end

        local game_rules = entity.get_game_rules()
        if not game_rules then
            return false
        end

        local m_bWarmupPeriod = entity.get_prop(game_rules, 'm_bWarmupPeriod') == 1
        return m_bWarmupPeriod
    end

    -- =============================================================
    --  safehead_air_c â Ð¿Ð¾ÑÑ Ð¸Ð· priora.
    --  ÐÑÐ��ÑÐµÐ» + Ð² Ð²Ð¾Ð·Ð´ÑÑÐµ + Ð½Ð¾Ð¶/ÑÐ°Ð·ÐµÑ Ð½Ð° ÑÑÐºÐ°Ñ â
    --  pitch=Down, yaw="180" 14, jitter=Off, body=Off.
    --  ÐÑÐ·ÑÐ²Ð°ÐµÑÑÑ ÐÐÐ¡ÐÐ set_aa() Ð¸ Ð¿ÐµÑÐµÐºÑÑÐ²Ð°ÐµÑ ÐµÐ³Ð¾ Ð¾Ð²ÐµÑÑÐ°Ð¹Ð´Ñ.
    -- =============================================================
    local function safehead_air_c(cmd, state)
        if not cmd then return end
        if state == 'Legit AA' or state == 'Manual AA' then return end
        if not menu.antiaim.features:get('Safe head') then return end
        if not menu.antiaim.safe_head then return end

        local me = entity.get_local_player()
        if not me or not entity.is_alive(me) then return end

        local flags  = entity.get_prop(me, 'm_fFlags') or 0
        local in_air = bit.band(flags, 1) == 0 or cmd.in_jump == 1
        local ducked = (entity.get_prop(me, 'm_flDuckAmount') or 0) > 0.7
        if not (in_air and ducked) then return end

        local wpn = entity.get_player_weapon(me)
        if not wpn then return end
        local cls = entity.get_classname(wpn)

        local knife_on = menu.antiaim.safe_head:get('Knife on Air + C') and cls == 'CKnife'
        local taser_on = menu.antiaim.safe_head:get('Taser on Air + C') and cls == 'CWeaponTaser'
        if not (knife_on or taser_on) then return end

        interface.reference.angles.pitch[1]:override('Down')
        interface.reference.angles.yaw_jitter[1]:override('Off')
        interface.reference.angles.yaw[1]:override('180')
        interface.reference.angles.yaw[2]:override(14)
        interface.reference.angles.body_yaw[1]:override('Off')
    end

    -- =============================================================
    --  spinner_override_apply â Ð¿Ð¾ÑÑ ��¸Ð· priora.
    --  ÐÑÐ»Ð¸ Ð²ÑÐ±Ñ��°Ð½ Spinner override + Warmup/No enemies Ð¸
    --  ÑÑÐ»Ð¾Ð²Ð¸Ðµ ���²ÑÐ¿Ð¾Ð»Ð½ÐµÐ½Ð¾ â Ð¶ÑÑÑÐºÐ¸Ð¹ ÑÐ¿Ð¸Ð½:
    --  yaw=Spin 100, pitch=Custom 0, jitter=Off, body=Static 1, edge_yaw off.
    --  ÐÑÐ·ÑÐ²Ð°ÐµÑÑÑ ÐÐ��¡Ð�� set_aa() â Ð¿ÐµÑÐµÐºÑÑÐ²Ð°��µÑ ÐµÐ³Ð¾ Ð¾Ð²ÐµÑÑÐ°Ð¹Ð´Ñ.
    -- =============================================================
    local function spinner_override_apply(state)
        if not menu.antiaim.features:get('Spinner override') then return end
        if not menu.antiaim.spinner_override then return end

        local selection = menu.antiaim.spinner_override:get() or {}
        local sel = {}
        for i = 1, #selection do sel[selection[i]] = true end
        if not (sel['Warmup'] or sel['No enemies']) then return end

        local rules = entity.get_game_rules()
        local warmup_active = rules and entity.get_prop(rules, 'm_bWarmupPeriod') == 1
        local should_spin = (warmup_active and sel['Warmup']) or (sel['No enemies'] and are_enemies_dead())
        if not should_spin then return end

        interface.reference.angles.pitch[1]:override('Custom')
        interface.reference.angles.pitch[2]:override(0)
        interface.reference.angles.yaw[1]:override('Spin')
        interface.reference.angles.yaw[2]:override(100)
        interface.reference.angles.yaw_jitter[1]:override('Off')
        interface.reference.angles.yaw_jitter[2]:override(0)
        interface.reference.angles.body_yaw[1]:override('Static')
        interface.reference.angles.body_yaw[2]:override(1)
        interface.reference.angles.fresstanding_body:override(false)
        interface.reference.angles.edge_yaw:override(false)
    end

    local function set_aa(state, settings, manual_yaw, hidden, safe_head)
        do -- unsetting useless functions for the best experience
            interface.reference.angles.enabled:override(true)
            interface.reference.angles.yaw_jitter[1]:override('Off')
            interface.reference.other.fake_peek[1]:override(false)
        end
        
        if disabler() and manual_yaw == 0 and state ~= 'Legit AA' then
            interface.reference.angles.pitch[1]:override('Off')
            interface.reference.angles.yaw_jitter[1]:override('Off')
            interface.reference.angles.body_yaw[1]:override('Opposite')
            interface.reference.angles.fresstanding_body:override(true)
            interface.reference.angles.yaw_base:override('At targets')
            interface.reference.angles.yaw[1]:override('Spin')
            interface.reference.angles.yaw[2]:override(30)
            return
        end
        
        interface.reference.angles.yaw[1]:override('180')
        interface.reference.angles.yaw_base:override((state == 'Legit AA' or manual_yaw ~= 0) and 'Local view' or menu.antiaim.target:get())
        if safe_head then
            interface.reference.angles.pitch[1]:override(state ~= 'Legit AA' and 'Minimal' or 'Off')
            interface.reference.angles.body_yaw[1]:override('Opposite')
            interface.reference.angles.fresstanding_body:override(true)
            interface.reference.angles.yaw[2]:override(0)
        elseif anti_aim.hidden then
            interface.reference.angles.pitch[1]:override('Custom')
            interface.reference.angles.pitch[2]:override(math.normalize_pitch(anti_aim.defensive_pitch))
            interface.reference.angles.yaw[2]:override(math.normalize_yaw(anti_aim.defensive_yaw + manual_yaw))
            interface.reference.angles.body_yaw[1]:override('Opposite')
            interface.reference.angles.fresstanding_body:override(true)
        else
            interface.reference.angles.pitch[1]:override(state ~= 'Legit AA' and 'Minimal' or 'Off')
            interface.reference.angles.yaw[2]:override(anti_aim.yaw)
            interface.reference.angles.body_yaw[1]:override(settings.body_yaw.type:get() ~= 'Off'
                and ((settings.body_yaw.type:get() == 'Jitter' or settings.body_yaw.type:get() == package.scriptname) and 'Static' or settings.body_yaw.type:get()) or 'Off')

            interface.reference.angles.fresstanding_body:override(settings.body_yaw.type:get() == 'Opposite')
            if (settings.body_yaw.type:get() == 'Jitter' or settings.body_yaw.type:get() == package.scriptname) then
                if settings.body_yaw.offset:get() == 0 then
                    interface.reference.angles.body_yaw[2]:override((anti_aim.tickcount % 2 == 0 and -1 or 1))
                else
                    interface.reference.angles.body_yaw[2]:override(math.normalize_yaw(settings.body_yaw.offset:get() * (anti_aim.tickcount % 2 == 0 and -1 or 1)))
                end
            else
                interface.reference.angles.body_yaw[2]:override(settings.body_yaw.offset:get())
            end
        end
    end

    local freestanding_checkbox = false
    local edge_yaw_checkbox = false
    menu.antiaim.freestanding:set_callback(function (this)
        freestanding_checkbox = this:get()
    end, true)

    menu.antiaim.edge_yaw:set_callback(function (this)
        edge_yaw_checkbox = this:get()
    end, true)

    local function hotkeys_active(current_state, manual_yaw, avoid_backstab_check)
        interface.reference.angles.freestanding:override(false)
        interface.reference.angles.edge_yaw:override(false)
        if current_state == 'Legit AA' or avoid_backstab_check or manual_yaw ~= 0 then
            interface.reference.angles.freestanding:override(false)
            interface.reference.angles.freestanding.hotkey:set('On hotkey')
            interface.reference.angles.edge_yaw:override(false)
            return false
        end
        
        if freestanding_checkbox and menu.antiaim.freestanding.hotkey:get() then
            interface.reference.angles.freestanding:override(true)
            interface.reference.angles.freestanding.hotkey:set('Always on')
        end

        if edge_yaw_checkbox and menu.antiaim.edge_yaw.hotkey:get() then
            interface.reference.angles.edge_yaw:override(true)
        end

        return true
    end

    -- ================================================================
    --  Defensive flick runtime (ported from Althea dev; pitch from Kitt).
    --  Driven by the per-state builder (builder_type 'Defensive'):
    --    settings = menu.antiaim.builder[current_state]
    --    settings.defensive.flick.{enabled, inverter, pitch_type, pitch_*}
    --  Althea dependency            -> lunaris equivalent
    --   buffer.* (angle buffer)      -> interface.reference.angles.*:override()
    --   exploit.get().shift          -> self.charged
    --   exploit.get().defensive.left -> self.defensive.current
    --   csgo_weapons(weapon)         -> csgo_weapons[m_iItemDefinitionIndex]
    --   utils.random_int             -> client.random_int
    --  Flick pitch helpers ported 1:1 from Kitt (spin_pitch / get_pitch_value /
    --  generate_slow_random).
    -- ================================================================
    local defensive_flick_command_number = 0
    local defensive_flick_r_t = 0
    local defensive_flick_static_random = 0
    local defensive_flick_jitter_flag = false

    -- Kitt: antiaim.generate_slow_random
    local function defensive_flick_slow_random(min, max, interval)
        local now = globals.realtime()

        if now - defensive_flick_r_t >= interval then
            defensive_flick_static_random = client.random_int(min, max)
            defensive_flick_r_t = now
        end

        return defensive_flick_static_random
    end

    -- Kitt: antiaim.spin_pitch
    local function defensive_flick_spin_pitch(sl1, sl2, speed)
        local progress = (globals.curtime() * speed / 15) % 1

        return sl1 + (sl2 - sl1) * progress
    end

    -- Kitt: antiaim.get_pitch_value (Spin[MOD])
    local function defensive_flick_spin_pitch_mod(sl1, sl2, speed)
        local midpoint = (sl1 + sl2) / 2
        local amplitude = (sl2 - sl1) / 2

        return midpoint + math.sin(globals.curtime() * speed / 3) * amplitude
    end

    local function defensive_flick_resolve_pitch(flick)
        local mode = flick.pitch_type:get()

        if mode == 'Static' then
            return flick.pitch_static:get()
        elseif mode == 'Jitter' then
            local ticks = math.max(2, flick.pitch_jitter_speed:get())

            if globals.tickcount() % ticks == 1 then
                defensive_flick_jitter_flag = not defensive_flick_jitter_flag
            end

            return defensive_flick_jitter_flag and flick.pitch_mode1:get() or flick.pitch_mode2:get()
        elseif mode == 'Random' then
            return client.random_int(flick.pitch_mode1:get(), flick.pitch_mode2:get())
        elseif mode == 'Spin' then
            return defensive_flick_spin_pitch(flick.pitch_mode1:get(), flick.pitch_mode2:get(), flick.pitch_speed:get())
        elseif mode == 'Spin[MOD]' then
            return defensive_flick_spin_pitch_mod(flick.pitch_mode1:get(), flick.pitch_mode2:get(), flick.pitch_speed:get())
        elseif mode == 'Random Ticks' then
            local phase = globals.tickcount() % 3

            if phase == 0 then
                return 89
            elseif phase == 1 then
                return 0
            end

            return -89
        end

        -- 'Off' -> no custom pitch (handled by caller)
        return nil
    end

    local function defensive_flick_should_update(me, flick)
        if flick == nil or not flick.enabled:get() then
            return false
        end

        if me == nil then
            return false
        end

        local weapon = entity.get_player_weapon(me)

        if weapon == nil then
            return false
        end

        local weapon_info = csgo_weapons[entity.get_prop(weapon, 'm_iItemDefinitionIndex')]

        if weapon_info == nil or weapon_info.is_revolver then
            return false
        end

        -- Althea required the exploit shift; lunaris analog is the charged flag.
        if not self.charged then
            return false
        end

        return true
    end

    local function defensive_flick_apply(cmd, settings)
        if settings == nil or settings.defensive == nil or settings.defensive.flick == nil then
            return
        end

        local flick = settings.defensive.flick
        local me = entity.get_local_player()

        if not defensive_flick_should_update(me, flick) then
            return
        end

        local inverter = flick.inverter:get()
        local is_defensive_active = self.defensive.current ~= 0

        defensive_flick_command_number = defensive_flick_command_number + 1
        cmd.force_defensive = defensive_flick_command_number % 7 == 0

        -- pitch: configurable, Kitt-style flick pitch modes
        local pitch = defensive_flick_resolve_pitch(flick)

        if pitch ~= nil then
            pitch = math.max(-89, math.min(89, pitch))
            interface.reference.angles.pitch[1]:override('Custom')
            interface.reference.angles.pitch[2]:override(pitch)
        else
            -- 'Off' keeps Althea's behaviour: custom 0 while defensive, default otherwise.
            interface.reference.angles.pitch[1]:override(is_defensive_active and 'Custom' or 'Default')
            interface.reference.angles.pitch[2]:override(0)
        end

        interface.reference.angles.yaw_base:override('At targets')
        interface.reference.angles.yaw[1]:override('180')

        local yaw_offset = is_defensive_active and client.random_int(89, 120) or 0

        if inverter then
            yaw_offset = -yaw_offset
        end

        interface.reference.angles.yaw[2]:override(yaw_offset)

        interface.reference.angles.yaw_jitter[1]:override('Off')
        interface.reference.angles.yaw_jitter[2]:override(0)

        interface.reference.angles.body_yaw[1]:override('Static')
        interface.reference.angles.body_yaw[2]:override(is_defensive_active and -1 or 1)

        interface.reference.angles.fresstanding_body:override(false)
        interface.reference.angles.edge_yaw:override(false)
        interface.reference.angles.freestanding:override(false)
        interface.reference.angles.roll:override(0)
    end

    function anti_aim.setup_command(cmd)
        local state = statement.current
        local current_state = get_current_state(state)
        local settings = menu.antiaim.builder[current_state]
        local breaking_lc = break_lc(cmd, current_state, state)
        local avoid_backstab_check = avoid_backstab(state)
        local manual_yaw = manual_yaw(state, avoid_backstab_check)
        local safe_head = safehead(state)
        hotkeys_active(current_state, manual_yaw, avoid_backstab_check)

        local delay_updating = update_delay(cmd, state, settings, current_state)
        local delayrandom_updating = update_randomize(cmd, settings)

        yaw_update(state, settings, avoid_backstab_check, manual_yaw)
    
        local hidden = defensive_aa_update(settings, avoid_backstab_check, breaking_lc, state)
        set_aa(state, settings, manual_yaw, hidden, safe_head)
        safehead_air_c(cmd, state)
        spinner_override_apply(state)
        defensive_flick_apply(cmd, settings)
    end

    client.set_event_callback('setup_command', anti_aim.setup_command)
    client.set_event_callback('round_start', reset_all_antibrute_states)
    client.set_event_callback('round_end', reset_all_antibrute_states)
    client.set_event_callback('player_death', player_death)
    client.set_event_callback('player_hurt', player_hurt)
    client.set_event_callback('bullet_impact', get_miss)

    local switch = menu.antiaim.features
    function anti_aim.andromeda_lag()
        local state = statement.current
        local fakelag_patterns = { 'Fluctuate', 'Dynamic', 'Maximum' }
        local chosen_mode = fakelag_patterns[client.random_int(1, #fakelag_patterns)]
        local cycle_patterns = { 20, 40, 60 }
        local cycle_chosen_pattern = cycle_patterns[client.random_int(1, #cycle_patterns)]
        if switch:get('Fakelag') == 'Cycle' then
            if state == 'Air' then
                cvar.sv_maxusrcmdprocessticks:set_int(16)
                interface.antiaim.fakelag.maxticks2:set(16)
                interface.antiaim.fakelag.amount:override(chosen_mode)
                interface.antiaim.fakelag.limit:override(math.random(12, 15))
                interface.antiaim.fakelag.variance:override(math.random(20, 30))
            elseif state == 'Air-crouch' then
                cvar.sv_clockcorrection_msecs:set_int(cycle_chosen_pattern)
                cvar.sv_maxusrcmdprocessticks:set_int(17)
                interface.antiaim.fakelag.maxticks2:set(17)
                cvar.sv_maxusrcmdprocessticks:set_int(16)
                interface.antiaim.fakelag.maxticks2:set(16)
                interface.antiaim.fakelag.amount:override(chosen_mode)
                interface.antiaim.fakelag.limit:override(math.random(11, 15))
                interface.antiaim.fakelag.limit:override(math.random(11, 15))
                interface.antiaim.fakelag.variance:override(math.random(0, 50))
            else
                cvar.sv_clockcorrection_msecs:set_int(cycle_chosen_pattern)
                cvar.sv_maxusrcmdprocessticks:set_int(17)
                interface.antiaim.fakelag.maxticks2:set(17)
                cvar.sv_maxusrcmdprocessticks:set_int(16)
                interface.antiaim.fakelag.maxticks2:set(16)
                interface.antiaim.fakelag.amount:override('Fluctuate')
                interface.antiaim.fakelag.limit:override(math.random(14, 15))
                interface.antiaim.fakelag.limit:override(math.random(14, 15))
                interface.antiaim.fakelag.variance:override(math.random(25, 50))
            end
        elseif switch:get('Fakelag') == 'Cycle' then
            cvar.sv_clockcorrection_msecs:set_int(cycle_chosen_pattern)
            cvar.sv_maxusrcmdprocessticks:set_int(17)
            interface.antiaim.fakelag.maxticks2:set(17)
            cvar.sv_maxusrcmdprocessticks:set_int(16)
            interface.antiaim.fakelag.maxticks2:set(16)
            interface.antiaim.fakelag.amount:override('Fluctuate')
            interface.antiaim.fakelag.limit:override(math.random(10, 15))
            interface.antiaim.fakelag.limit:override(math.random(10, 15))
            interface.antiaim.fakelag.variance:override(math.random(0, 60))
        end
    end

    switch:set_event('setup_command', anti_aim.andromeda_lag)
end


-- =====================================================================
-- SELF-CODE VISUALS RUNTIME (ported from self_code.lua)
-- Damage indicator / Markers / Lagcomp skeleton / Bullet tracer /
-- Last seen position. Each block is independent and gated by its own
-- pui checkbox.
-- =====================================================================
do
    -- shared aimbot min-damage references for the damage indicator value
    local sc_ref_min_dmg          = { ui.reference('RAGE', 'Aimbot', 'Minimum damage') }
    local sc_ref_min_dmg_override = { ui.reference('RAGE', 'Aimbot', 'Minimum damage override') }

    -- ---------- Damage indicator ----------
    client.set_event_callback('paint', function ()
        if not menu.visuals.di_enabled or not menu.visuals.di_enabled:get() then return end
        local me = entity.get_local_player()
        if not me or not entity.is_alive(me) then
            if not ui.is_menu_open() then return end
        end

        local x = menu.visuals.di_x:get()
        local y = menu.visuals.di_y:get()

        local flag
        local font_v = menu.visuals.di_font:get()
        if     font_v == 'Bold'  then flag = 'b'
        elseif font_v == 'Small' then flag = '-'
        else                          flag = ''
        end

        local hotkey_on = ui.get(sc_ref_min_dmg_override[1]) and ui.get(sc_ref_min_dmg_override[2])
        local value     = hotkey_on and ui.get(sc_ref_min_dmg_override[3]) or ui.get(sc_ref_min_dmg[1])

        if menu.visuals.di_type:get() == 'On hotkey' and not hotkey_on and not ui.is_menu_open() then
            return
        end

        renderer.text(x, y, 255, 255, 255, 255, flag, nil, tostring(value))
    end)

    -- ---------- Markers (hit / miss / damage) ----------
    local mk = { hits = {}, misses = {}, damages = {}, positions = {} }

    client.set_event_callback('aim_fire', function (e)
        if not menu.visuals.mk_enabled:get() then return end
        mk.positions[e.id] = { e.x, e.y, e.z }
    end)
    client.set_event_callback('aim_hit', function (e)
        if not menu.visuals.mk_enabled:get() then return end
        local pos = mk.positions[e.id]
        if pos then
            table.insert(mk.hits, { time = globals.curtime(), position = pos })
            mk.positions[e.id] = nil
        end
    end)
    client.set_event_callback('aim_miss', function (e)
        if not menu.visuals.mk_enabled:get() then return end
        local pos = mk.positions[e.id]
        if pos then
            local red    = { 255, 0, 50 }
            local yellow = { 255, 205, 0 }
            local reason = e.reason == '?' and 'resolver' or e.reason
            table.insert(mk.misses, {
                time     = globals.curtime(),
                position = pos,
                reason   = reason,
                color    = (reason == 'spread' or reason == 'prediction error') and yellow or red,
            })
            mk.positions[e.id] = nil
        end
    end)
    client.set_event_callback('player_hurt', function (e)
        if not menu.visuals.mk_enabled:get() then return end
        local attacker = client.userid_to_entindex(e.attacker)
        local victim   = client.userid_to_entindex(e.userid)
        if attacker == entity.get_local_player() and victim ~= attacker then
            table.insert(mk.damages, {
                time     = globals.curtime(),
                position = { entity.get_prop(victim, 'm_vecOrigin') },
                damage   = e.dmg_health,
                offset   = 0,
            })
        end
    end)
    client.set_event_callback('paint', function ()
        if not menu.visuals.mk_enabled:get() then return end
        local sel = menu.visuals.mk_type
        if sel:get('On hit') then
            for i = #mk.hits, 1, -1 do
                local hit = mk.hits[i]
                local alpha = 255 - (globals.curtime() - hit.time) * 255 / 2
                if alpha > 0 then
                    local sx, sy = renderer.world_to_screen(hit.position[1], hit.position[2], hit.position[3])
                    if sx and sy then
                        local s = 4
                        renderer.line(sx - s, sy - s, sx + s, sy + s, 255, 255, 255, alpha)
                        renderer.line(sx + s, sy - s, sx - s, sy + s, 255, 255, 255, alpha)
                    end
                else table.remove(mk.hits, i) end
            end
        end
        if sel:get('On miss') then
            for i = #mk.misses, 1, -1 do
                local m = mk.misses[i]
                local alpha = 255 - (globals.curtime() - m.time) * 255 / 2
                if alpha > 0 then
                    local sx, sy = renderer.world_to_screen(m.position[1], m.position[2], m.position[3])
                    if sx and sy then
                        local s = 4
                        renderer.line(sx - s, sy - s, sx + s, sy + s, m.color[1], m.color[2], m.color[3], alpha)
                        renderer.line(sx + s, sy - s, sx - s, sy + s, m.color[1], m.color[2], m.color[3], alpha)
                        renderer.text(sx + 10, sy - 7, m.color[1], m.color[2], m.color[3], alpha, 'b', 0, m.reason or '?')
                    end
                else table.remove(mk.misses, i) end
            end
        end
        if sel:get('Damage') then
            for i = #mk.damages, 1, -1 do
                local d = mk.damages[i]
                local alpha = 255 - (globals.curtime() - d.time) * 255 / 2
                if alpha > 0 then
                    d.offset = d.offset + 0.2
                    local sx, sy = renderer.world_to_screen(d.position[1], d.position[2], d.position[3] + d.offset)
                    if sx and sy then
                        renderer.text(sx, sy, 255, 255, 255, alpha, 'cb', 0, '-' .. tostring(d.damage))
                    end
                else table.remove(mk.damages, i) end
            end
        end
    end)
    local function mk_reset () mk = { hits = {}, misses = {}, damages = {}, positions = {} } end
    client.set_event_callback('post_config_load', mk_reset)
    client.set_event_callback('round_prestart',  mk_reset)

    -- ---------- Lagcomp skeleton ----------
    local sk_hitlist = {}
    local sk_mesh = {
        {0, 1}, {1, 6}, {6, 5}, {5, 4}, {4, 3}, {3, 2}, {2, 7}, {2, 8},
        {8, 10}, {10, 12}, {7, 9}, {9, 11}, {1, 17}, {1, 15}, {17, 18},
        {18, 14}, {15, 16}, {16, 13},
    }
    local function sk_draw (hp, r, g, b, a)
        for i = 1, #sk_mesh do
            local p1, p2 = hp[sk_mesh[i][1]], hp[sk_mesh[i][2]]
            if p1 and p2 then
                local x1, y1 = renderer.world_to_screen(p1[1], p1[2], p1[3])
                local x2, y2 = renderer.world_to_screen(p2[1], p2[2], p2[3])
                if x1 and x2 then renderer.line(x1, y1, x2, y2, r, g, b, a) end
            end
        end
    end
    client.set_event_callback('aim_fire', function (e)
        if not menu.visuals.ls_enabled:get() then return end
        local hp = {}
        for i = 0, 18 do
            local hx, hy, hz = entity.hitbox_position(e.target, i)
            if hx then hp[i] = { hx, hy, hz } end
        end
        sk_hitlist[e.id] = { time = globals.curtime(), alpha = 0, hp = hp }
    end)
    client.set_event_callback('paint', function ()
        if not menu.visuals.ls_enabled:get() then return end
        local dur = menu.visuals.ls_duration:get() / 10
        local r, g, b, a = menu.visuals.ls_color:get()
        for id, entry in pairs(sk_hitlist) do
            local dt = globals.curtime() - entry.time
            if dt > dur then
                sk_hitlist[id] = nil
            else
                local fade_in = 0.1
                if dt < fade_in then
                    entry.alpha = math.min(entry.alpha + 25.5, 255)
                else
                    entry.alpha = math.max(a * (1 - ((dt - fade_in) / (dur - fade_in))), 0)
                end
                sk_draw(entry.hp, r, g, b, entry.alpha)
            end
        end
    end)

    -- ---------- Bullet tracer ----------
    local bt_tracers = {}
    client.set_event_callback('paint', function ()
        if not menu.visuals.bt_enabled:get() then return end
        local r, g, b, a = menu.visuals.bt_color:get()
        local th  = menu.visuals.bt_thick:get()
        local dur = menu.visuals.bt_duration:get() / 10
        for tick, d in pairs(bt_tracers) do
            if globals.curtime() > d.end_time then
                bt_tracers[tick] = nil
            else
                local alpha = a * (1 - ((globals.curtime() - d.time) / dur))
                local x1, y1 = renderer.world_to_screen(d.sx, d.sy, d.sz)
                local x2, y2 = renderer.world_to_screen(d.ex, d.ey, d.ez)
                if x1 and x2 then
                    for off = -math.floor(th / 2), math.floor(th / 2) do
                        renderer.line(x1, y1 + off, x2, y2 + off, r, g, b, alpha)
                    end
                end
            end
        end
    end)
    client.set_event_callback('bullet_impact', function (e)
        if not menu.visuals.bt_enabled:get() then return end
        local me = entity.get_local_player()
        if not me then return end
        if client.userid_to_entindex(e.userid) ~= me then return end
        local ex, ey, ez = client.eye_position()
        if not ex then return end
        local dur = menu.visuals.bt_duration:get() / 10
        bt_tracers[globals.tickcount()] = {
            time = globals.curtime(), end_time = globals.curtime() + dur,
            sx = ex, sy = ey, sz = ez,
            ex = e.x, ey = e.y, ez = e.z,
        }
    end)
    client.set_event_callback('round_prestart', function () bt_tracers = {} end)

    -- ---------- Last seen position ----------
    local lsn_lastPos = {}
    local function lsn_enemies ()
        local pr   = entity.get_player_resource()
        local list = {}
        for player = 1, globals.maxplayers() do
            if entity.get_prop(pr, 'm_bConnected', player) == 1 and entity.is_enemy(player) then
                list[#list + 1] = player
            end
        end
        return list
    end
    local function lsn_rect_outline (x, y, w, h, r, g, b, a, s)
        s = s or 1
        renderer.rectangle(x, y, w, s, r, g, b, a)
        renderer.rectangle(x, y + h - s, w, s, r, g, b, a)
        renderer.rectangle(x, y + s, s, h - s * 2, r, g, b, a)
        renderer.rectangle(x + w - s, y + s, s, h - s * 2, r, g, b, a)
    end
    client.set_event_callback('paint', function ()
        if not menu.visuals.lsn_enabled:get() then return end
        local r, g, b, a = menu.visuals.lsn_color:get()
        local me = entity.get_local_player()
        if not me or not entity.is_alive(me) then return end
        for _, ent in ipairs(lsn_enemies()) do
            local data = entity.get_esp_data(ent)
            local alpha = data and data.alpha or 0
            local ox, oy, oz = entity.get_origin(ent)
            if ox then
                if alpha > 0.05 then
                    lsn_lastPos[ent] = nil
                elseif alpha ~= 0 then
                    lsn_lastPos[ent] = { ox, oy, oz }
                end
            end
        end
        local mx, my, mz = entity.get_origin(me)
        for key, v in pairs(lsn_lastPos) do
            local sx, sy = renderer.world_to_screen(v[1], v[2], v[3])
            if sx and mx then
                local dx, dy, dz = v[1] - mx, v[2] - my, v[3] - mz
                local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
                local scale  = 4 - math.min(3, dist / 1000)
                local length = 10 * scale
                local height = 20 * scale
                local name   = entity.get_player_name(key) or '?'
                renderer.text(sx + length / 2, sy - height - 3, r, g, b, a, '-', nil, 'WARNING')
                renderer.text(sx + length / 2, sy - height + 5, r, g, b, a, '-', nil, name:upper())
                lsn_rect_outline(sx - length / 2,     sy - height,     length,     height,     r, g, b, a)
                lsn_rect_outline(sx - length / 2 - 1, sy - height - 1, length + 2, height + 2, 0, 0, 0, a / 1.875)
                lsn_rect_outline(sx - length / 2 + 1, sy - height + 1, length - 2, height - 2, 0, 0, 0, a / 1.875)
            end
        end
    end)
    client.set_event_callback('round_prestart', function () lsn_lastPos = {} end)
    client.set_event_callback('player_death', function (e)
        local ent = client.userid_to_entindex(e.userid)
        lsn_lastPos[ent] = nil
    end)
end


-- =====================================================================


-- =====================================================================
-- JITTER FAKELAG (pui edition)
--   Only active when statement.current == 'Fake lag'.
--   UI: a single Preset selector + Apply button in fl_group, shown only
--        when AA > State == 'Fake lag'. All manual jitter settings live
--        as plain Lua locals (no menu widgets) so the user only ever
--        sees the preset selector. Apply preset writes to those locals.
-- =====================================================================
do
    -- ---------- native fakelag references (drive AA > Fake lag > Limit)
    local missing = {}
    local function ref(tab, cont, name)
        local ok, a, b = pcall(ui.reference, tab, cont, name)
        if not ok then
            table.insert(missing, string.format('%s > %s > %s', tab, cont, name))
            local stub = ui.new_checkbox('LUA', 'A', 'jfl_stub_'..#missing)
            pcall(ui.set_visible, stub, false)
            return stub, stub
        end
        return a, b
    end
    local fl_enabled       = ref('AA', 'Fake lag', 'Enabled')
    local fl_limit         = ref('AA', 'Fake lag', 'Limit')
    local dt_enabled, dt_hotkey = ref('RAGE', 'Aimbot', 'Double tap')
    if #missing > 0 then
        client.color_log(255, 80, 80, '[JitterFakelag] missing menu entries:')
        for _, m in ipairs(missing) do
            client.color_log(255, 160, 160, '  \xE2\x80\xA2 '..m)
        end
    end

    -- ---------- plain-lua settings (no menu widgets, always hidden)
    local jfl = {
        enable        = false,
        mode          = 'Maelstrom',
        min           = 1,
        max           = 14,
        burst_n       = 4,
        phase_sec     = 14,    -- slider scale 0.1 (i.e. value/10 seconds)
        delay         = 1,
        shot_delay    = 2,
        start_delay   = 22,
        peek_key      = false, -- DT-aware peek (no hotkey, preset stays Maelstrom/Phase-shift)
        panic         = true,
        panic_t       = 4,
        panic_phs     = 3,
        event_ps      = true,
        send_shot     = true,
        send_land     = true,
        send_jump     = true,
        break_air     = true,
        post_shot     = true,
    }

    -- ---------- presets (write into the `jfl` table)
    local PRESETS = {
        -- Each preset configures:
        --   * jitter engine params (mode/min/max/...)
        --   * builder.yaw_modifier  (anti-resolver yaw modifier)
        --   * builder.body_yaw      (body yaw mode + offset)
        --[[
            Каждый пресет адаптирован под конкретный резолвер:

            Anti-Skeet (skeet.cc):
              skeet строит pattern-резолвер по истории yaw -> нужна
              непрерывная плавная развёртка (Sway), плюс шум на каждый тик
              (Random modifier) и Jitter body, чтобы lowerbody-резолвер
              тоже флипался каждый тик. Углы умеренные (~50), потому что
              крайности (89) skeet быстро запоминает.

            Anti-Neverlose (neverlose.cc):
              NL = статистический резолвер с усреднением по стороне.
              Контрим экстремумом: Static yaw -89 (одна сторона, ломает
              усреднение в её пользу), Spin yaw modifier (вращение делает
              сэмплинг бесполезным), Opposite body (180 при выстреле).
              Никакой рандомизации -- NL её просто учитывает.

            Universal:
              X-way по 5 углам через разные знаки + Offset modifier +
              Jitter body. Это даёт 5x2 = 10 уникальных финальных углов,
              что мешает и pattern-, и stat-резолверам.
        ]]--
        ['Anti-Skeet']     = {
            mode='Phase-shift', min=2, max=14, burst_n=3, phase_sec=10, delay=1, shot_delay=3, start_delay=20, panic=true,  panic_t=3, panic_phs=3, event_ps=true,  send_shot=true, send_land=true, send_jump=true,  break_air=false, post_shot=true,
            yaw_type='Sway', sway_left=-50, sway_right=50, yaw_left=-50, yaw_right=50,
            yaw_mod_type='Random', yaw_mod_offset=0,
            body_type='Jitter',    body_offset=60,
        },
        ['Anti-Neverlose'] = {
            mode='Maelstrom',   min=1, max=14, burst_n=4, phase_sec=20, delay=1, shot_delay=2, start_delay=24, panic=true,  panic_t=4, panic_phs=2, event_ps=false, send_shot=true, send_land=true, send_jump=false, break_air=true,  post_shot=true,
            yaw_type='Static', yaw_static=0,
            yaw_mod_type='Center', yaw_mod_offset=32,
            body_type='Opposite', body_offset=0,
        },
        ['Universal']      = {
            mode='Maelstrom',   min=1, max=14, burst_n=4, phase_sec=14, delay=1, shot_delay=2, start_delay=22, panic=true,  panic_t=4, panic_phs=3, event_ps=true,  send_shot=true, send_land=true, send_jump=true,  break_air=true,  post_shot=true,
            yaw_type='X-way', xway1=-60, xway2=-30, xway3=0, xway4=30, xway5=60,
            yaw_mod_type='Offset', yaw_mod_offset=12,
            body_type='Jitter', body_offset=50,
        },
    }

    local function apply_preset(name)
        local p = PRESETS[name]
        if not p then
            if menu.antiaim.jfl_status then menu.antiaim.jfl_status:set('  \xE2\x9A\xA0 pick a preset') end
            return
        end
        for k, v in pairs(p) do jfl[k] = v end
        jfl.enable = true

        -- Push preset values into the Fake lag state's builder widgets
        local fl = menu.antiaim.builder and menu.antiaim.builder['Fake lag']
        local function setw(w, v) if w and w.set then pcall(w.set, w, v) end end
        if fl then
            -- enable the Fake lag state automatically
            setw(fl.enabled, true)
            -- yaw: каждый пресет может выставлять любой тип
            -- (Static / L/R / Sway / X-way) и соответствующие подзначения
            if fl.yaw then
                setw(fl.yaw.type,      p.yaw_type)
                setw(fl.yaw.static,    p.yaw_static)
                setw(fl.yaw.left,      p.yaw_left)
                setw(fl.yaw.right,     p.yaw_right)
                setw(fl.yaw.swayleft,  p.sway_left)
                setw(fl.yaw.swayright, p.sway_right)
                setw(fl.yaw.x_way1,    p.xway1)
                setw(fl.yaw.x_way2,    p.xway2)
                setw(fl.yaw.x_way3,    p.xway3)
                setw(fl.yaw.x_way4,    p.xway4)
                setw(fl.yaw.x_way5,    p.xway5)
            end
            -- yaw modifier
            if fl.yaw_modifier then
                setw(fl.yaw_modifier.type,   p.yaw_mod_type)
                setw(fl.yaw_modifier.offset, p.yaw_mod_offset)
            end
            -- body yaw
            if fl.body_yaw then
                setw(fl.body_yaw.type,   p.body_type)
                setw(fl.body_yaw.offset, p.body_offset)
            end
        end

        if menu.antiaim.jfl_status then menu.antiaim.jfl_status:set('  \xE2\x9C\x94 applied: '..name) end
        client.color_log(120, 255, 160, '[JitterFakelag] preset applied: '..name)
    end

    -- Widgets are created inside antiaim_setup (under Builder type),
    -- before pui.setup, so pui registers them and they become interactive.
    -- Here we only wire the apply callback that the button calls.
    menu.antiaim.jfl_apply_fn = function(sel)
        if sel == '(select)' or sel == nil then
            if menu.antiaim.jfl_status then menu.antiaim.jfl_status:set('  \xE2\x9A\xA0 pick a preset first') end
            return
        end
        apply_preset(sel)
    end

    -- ---------- helpers
    local function tick() return globals.tickcount() end
    local function lp()   return entity.get_local_player() end
    local function clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi end return v end
    local function velocity()
        local me = lp(); if not me then return 0 end
        local vx = entity.get_prop(me, 'm_vecVelocity[0]') or 0
        local vy = entity.get_prop(me, 'm_vecVelocity[1]') or 0
        return math.sqrt(vx * vx + vy * vy)
    end
    local function dt_on() return ui.get(dt_enabled) and ui.get(dt_hotkey) end

    -- DT charge tracker
    local TICKS_NEED, charged_ticks = 14, 0
    client.set_event_callback('net_update_end', function()
        charged_ticks = dt_on() and math.min(charged_ticks + 1, TICKS_NEED) or 0
    end)
    local function dt_charged() return charged_ticks >= TICKS_NEED end

    -- ---------- timings & state
    local last_shot_tick, last_jump_tick, last_land_tick = -999, -999, -999
    local was_on_ground = true
    local spawn_tick    = -999
    local was_alive     = false
    local phase_idx, phase_started = 1, 0
    local m_idx, m_last_step       = 1, -1
    local panic_until_tick         = -999

    client.set_event_callback('aim_fire', function()
        last_shot_tick = tick()
        charged_ticks  = 0
    end)
    client.set_event_callback('net_update_end', function()
        local me = lp()
        local alive = me and entity.is_alive(me) or false
        if alive and not was_alive then spawn_tick = tick() end
        was_alive = alive
    end)

    -- panic-on-hit
    local function trigger_panic()
        if not jfl.panic then return end
        panic_until_tick = tick() + jfl.panic_t
        local skips = jfl.panic_phs
        phase_idx     = ((phase_idx - 1 + skips) % 5) + 1
        phase_started = globals.realtime()
        m_idx         = client.random_int(1, 32)
        m_last_step   = -1
    end
    client.set_event_callback('player_hurt', function(e)
        local me = lp(); if not me then return end
        local victim = client.userid_to_entindex(e.userid)
        if victim ~= me then return end
        if e.attacker == 0 then return end
        local atk = client.userid_to_entindex(e.attacker)
        if atk == me then return end
        trigger_panic()
    end)
    client.set_event_callback('bullet_impact', function(e)
        if not jfl.panic then return end
        local me = lp(); if not me then return end
        local atk = e.userid and client.userid_to_entindex(e.userid) or nil
        if not atk or atk == me then return end
        if entity.is_dormant(atk) then return end
        local ox, oy, oz = entity.get_origin(me); if not ox then return end
        local dx, dy, dz = (e.x or 0) - ox, (e.y or 0) - oy, (e.z or 0) - oz
        if dx*dx + dy*dy + dz*dz < 14400 then trigger_panic() end
    end)
    -- event-reactive Phase-shift
    client.set_event_callback('aim_fire', function()
        if jfl.event_ps and jfl.mode == 'Phase-shift' then
            phase_idx     = (phase_idx % 5) + 1
            phase_started = globals.realtime()
            m_idx         = client.random_int(1, 32)
        end
    end)
    -- round/spawn reseed
    client.set_event_callback('round_start', function()
        phase_idx     = client.random_int(1, 5)
        phase_started = globals.realtime() - client.random_float(0, 1)
        m_idx         = client.random_int(1, 32)
        m_last_step   = -1
        panic_until_tick = -999
    end)
    client.set_event_callback('player_spawn', function(e)
        local me = lp(); if not me then return end
        local who = client.userid_to_entindex(e.userid)
        if who ~= me then return end
        phase_idx = client.random_int(1, 5)
        m_idx     = client.random_int(1, 32)
    end)

    -- pattern generators
    local MAELSTROM = {
        14, 1, 14, 7, 2, 14, 11, 3, 14, 1, 9, 14, 4, 14, 1, 12,
        2, 14, 6, 14, 1, 14, 8, 1, 14, 13, 2, 14, 5, 1, 14, 10,
    }
    local PHASES = {
        function(t, mn, mx) return (t % 2 == 0) and mx or mn end,
        function(t, mn, mx) return (client.random_int(0,1) == 0) and mn or mx end,
        function(t, mn, mx) return ((t % 4) == 0) and mn or mx end,
        function(t, mn, mx) return ((math.floor(t / 2)) % 2 == 0) and mx or mn end,
        function(t, mn, mx)
            local seq = { mx, mx, mn, mx, mn, mx, mx, mn }
            return seq[(t % #seq) + 1]
        end,
    }
    local function pick_target(mode, mn, mx, t, vel, on_ground)
        if mode == 'ABAB jitter' then
            return (t % 2 == 0) and mx or mn
        elseif mode == 'Extreme random' then
            return (client.random_int(0, 1) == 0) and mn or mx
        elseif mode == 'Burst-strafe' then
            local n = jfl.burst_n; local cyc = n + 1
            return ((t % cyc) == 0) and mn or mx
        elseif mode == 'Maelstrom' then
            if t ~= m_last_step then
                m_idx       = (m_idx % #MAELSTROM) + 1
                m_last_step = t
            end
            return (MAELSTROM[m_idx] <= 7) and mn or mx
        elseif mode == 'Phase-shift' then
            local now = globals.realtime()
            local phase_dur = jfl.phase_sec / 10
            if phase_started == 0 then phase_started = now end
            if now - phase_started >= phase_dur then
                phase_started = now
                phase_idx = (phase_idx % #PHASES) + 1
            end
            return PHASES[phase_idx](t, mn, mx)
        elseif mode == 'Velocity-jitter' then
            local k = clamp(1 - vel / 250, 0, 1)
            if k > 0.4 then return (t % 2 == 0) and mx or mn
            else return mx - client.random_int(0, 2) end
        elseif mode == 'DT-aware' then
            if dt_on() and not dt_charged() then return mx
            elseif dt_charged() and jfl.peek_key then return mn
            else return (t % 2 == 0) and mx or mn end
        else
            return mx
        end
    end

    -- ---------- engine: drives native AA > Fake lag > Limit only on Fake lag state
    client.set_event_callback('setup_command', function(cmd)
        if not statement or statement.current ~= 'Fake lag' then return end
        if not jfl.enable then return end
        local me = lp(); if not me or not entity.is_alive(me) then return end

        local flags     = entity.get_prop(me, 'm_fFlags') or 0
        local on_ground = bit.band(flags, 1) ~= 0
        local vel       = velocity()
        if on_ground and not was_on_ground then last_land_tick = tick() end
        if (not on_ground) and was_on_ground then last_jump_tick = tick() end
        was_on_ground = on_ground

        if not ui.get(fl_enabled) then ui.set(fl_enabled, true) end

        local mode = jfl.mode
        local mn, mx = jfl.min, jfl.max
        if mn > mx then mn, mx = mx, mn end
        local t      = tick()
        local delay  = math.max(1, jfl.delay)
        local step   = math.floor(t / delay)
        local target = pick_target(mode, mn, mx, step, vel, on_ground)

        local sd = jfl.start_delay
        if sd > 0 and t - spawn_tick < sd then target = mx end
        if t <= panic_until_tick then target = 1 end
        if jfl.break_air and not on_ground then target = 1 end
        if jfl.send_shot and t - last_shot_tick <= 1 then target = 1 end
        if jfl.send_land and t - last_land_tick <= 1 then target = 1 end
        if jfl.send_jump and t - last_jump_tick <= 1 then target = 1 end

        local psd = jfl.shot_delay
        if jfl.post_shot and t - last_shot_tick >= 2 and t - last_shot_tick <= (1 + psd) then
            target = mx
        end

        target = clamp(target, 1, 14)
        ui.set(fl_limit, target)
    end)

    client.color_log(120, 220, 255, '[JitterFakelag pui] loaded.')
end

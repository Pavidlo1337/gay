-- preload custom avatar
local _custom_avatar_tex = nil
pcall(function()
    local data = readfile("avatar.png")
    client.color_log(150,150,150,"[avatar] readfile result: "..tostring(type(data)).." len="..(data and #data or 0).."\n")
    if data and #data > 0 then
        local ok, tex = pcall(images.load_png, data)
        client.color_log(150,150,150,"[avatar] load_png ok="..tostring(ok).."\n")
        if ok and tex then _custom_avatar_tex = tex end
    end
end)

-- vector5d(x,y,z,w,h)

local js = panorama.open()
local vector = require("vector")
local pui = require("gamesense/pui")
local clipboard = (function() local ok,m = pcall(require,"gamesense/clipboard") return ok and m or {get=function() return "" end, set=function() end} end)()
local ent = require("gamesense/entity")
local images = (function() local ok,m = pcall(require,"gamesense/images") return ok and m or {load_png=function() return nil end, get_steam_avatar=function() return nil end} end)()
local base64 = (function() local ok,m = pcall(require,"gamesense/base64") return ok and m or {encode=function(s) return s end, decode=function(s) return s end} end)()
local surface = (function() local ok,m = pcall(require,"gamesense/surface") return ok and m or {blur=function() end} end)()
local ffi = require("ffi")
local odyssey = false 

local prev_unload = rawget(_G, "OVERNIGHT_UNLOAD")
if type(prev_unload) == "function" then
    pcall(prev_unload)
end
_G.OVERNIGHT_UNLOAD = nil

local protect = {}
protect.key = 73

function protect.dec(hex)
    if not hex or hex == "" then
        return ""
    end
    local out = {}
    for i = 1, #hex, 2 do
        local byte = tonumber(hex:sub(i, i + 1), 16)
        if not byte then
            break
        end
        out[#out + 1] = string.char(bit.bxor(byte, protect.key))
    end
    return table.concat(out)
end

protect.guard = {items = {}, tripped = false}

function protect.guard:add(name, getter)
    local ok, fn = pcall(getter)
    if ok and type(fn) == "function" then
        local ok_dump, dump = pcall(string.dump, fn)
        if not ok_dump then
            return
        end
        self.items[#self.items + 1] = {
            name = name,
            getter = getter,
            kind = "function",
            dump = dump
        }
    end
end

protect.cb_lock = {locked = false, wrapped = setmetatable({}, {__mode = "k"})}

function protect.cb_lock:wrap(element)
    if not element or type(element.set_callback) ~= "function" then
        return
    end
    if self.wrapped[element] then
        return
    end
    local orig = element.set_callback
    self.wrapped[element] = orig
    element.set_callback = function(el, fn, ...)
        if self.locked then
            return
        end
        return orig(el, fn, ...)
    end
end

function protect.cb_lock:unwrap(element)
    local orig = self.wrapped[element]
    if orig then
        element.set_callback = orig
        self.wrapped[element] = nil
    end
end

function protect.cb_lock:lock()
    self.locked = true
end

function protect.guard:add_table(name, getter, schema)
    local ok, tbl = pcall(getter)
    if ok and type(tbl) == "table" then
        self.items[#self.items + 1] = {
            name = name,
            getter = getter,
            kind = "table",
            ref = tbl,
            schema = schema
        }
    end
end

function protect.guard:check()
    for _, item in ipairs(self.items) do
        if item.kind == "function" then
            local ok, fn = pcall(item.getter)
            if not ok or type(fn) ~= "function" then
                return false, item.name
            end
            if string.dump(fn) ~= item.dump then
                return false, item.name
            end
        elseif item.kind == "table" then
            local ok, tbl = pcall(item.getter)
            if not ok or type(tbl) ~= "table" or tbl ~= item.ref then
                return false, item.name
            end
            if item.schema then
                for _, rule in ipairs(item.schema) do
                    local key, t = rule[1], rule[2]
                    if type(tbl[key]) ~= t then
                        return false, item.name
                    end
                end
            end
        end
    end
    return true, nil
end


local function inition()
    client.ping = math.floor(client.latency() * 1000)

    math.random_string = function(...)
        local args = {...}
        if #args == 1 and type(args[1]) == "table" then
            args = args[1]
        end
        return args[math.random(1, #args)]
    end

    math.distance = function(x1, y1, z1, x2, y2, z2)
		return math.sqrt((x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2))
	end

    math.clamp = function(value, min, max)
        if min > max then 
            min, max = max, min 
        end

        return math.max(min, math.min(max, value))
    end

    math.invert = function(value, bool)
        return bool and -value or value
    end

    math.round = function(value)
        return math.floor(value + 0.5)
    end

    math.stay = function(value)
        local number = value 
        
        if value < 0 then 
            number = -value
        end

        return number
    end

    math.closest_ray_point = function(x, y, z)
		local delta_x = x - y
		local delta_y = z - y
		local length = delta_y:length()
		local delta = delta_y / length
		local dot = delta:dot(delta_x)

		if dot < 0 then
			return y
		elseif length < dot then
			return z
		end

		return y + delta * dot
	end

    string.up = function(input)
        return input:sub(1, 1):upper() .. input:sub(2)
    end

    string.interval = function(start_text, end_text, progress)
        progress = math.clamp(progress, 0, 1)

        local start_len = string.len(start_text)
        local end_len = string.len(end_text)

        local target_len = math.floor(start_len + (end_len - start_len) * progress)

        if target_len < 0 then
            return "" 
        elseif target_len <= start_len then
            return string.sub(start_text, 1, target_len)
        else
            local diff = target_len - start_len
            if diff <= 0 then
            return start_text
            end
            return start_text .. string.sub(end_text, start_len + 1, target_len)
        end
    end

    string.limit = function(text, num, replace)
        local tabl = {}
        local one = 1

        for iter in string.gmatch(text, ".[\x80-\xBF]*") do
            one, tabl[one] = one + 1, iter

            if num < one then
                tabl[one] = replace or "..."

                break
            end
        end

        return table.concat(tabl)
    end

    table.combo = function(t1, t2)
        local result = {}

        for _, v in ipairs(t1) do 
            table.insert(result, v) 
        end

        for _, v in ipairs(t2) do 
            table.insert(result, v) 
        end
        
        return result
    end

    table.tables = function(...)
        local result = {}
        for _, tbl in ipairs({...}) do
            if type(tbl) == "table" then
                for _, item in ipairs(tbl) do
                    table.insert(result, item)
                end
            end
        end

        return #result > 0 and unpack(result) or nil
    end

    table.find = function(arg, list)  -- @flag156
		for i = 1, #list do
			if list[i] == arg then
				return i
			end
		end
	end

    table.upper = function(tbl)
        local result = {}
        for i, v in ipairs(tbl) do
            result[i] = v:up()
        end
        return result
    end

    local animstates = ffi.typeof("struct { char pad0[0x18]; float anim_update_timer; char pad1[0xC]; float started_moving_time; float last_move_time; char pad2[0x10]; float last_lby_time; char pad3[0x8]; float run_amount; char pad4[0x10]; void* entity; void* active_weapon; void* last_active_weapon; float last_client_side_animation_update_time; int\t last_client_side_animation_update_framecount; float eye_timer; float eye_angles_y; float eye_angles_x; float goal_feet_yaw; float current_feet_yaw; float torso_yaw; float last_move_yaw; float lean_amount; char pad5[0x4]; float feet_cycle; float feet_yaw_rate; char pad6[0x4]; float duck_amount; float landing_duck_amount; char pad7[0x4]; float current_origin[3]; float last_origin[3]; float velocity_x; float velocity_y; char pad8[0x4]; float unknown_float1; char pad9[0x8]; float unknown_float2; float unknown_float3; float unknown; float m_velocity; float jump_fall_velocity; float clamped_velocity; float feet_speed_forwards_or_sideways; float feet_speed_unknown_forwards_or_sideways; float last_time_started_moving; float last_time_stopped_moving; bool on_ground; bool hit_in_ground_animation; char pad10[0x4]; float time_since_in_air; float last_origin_z; float head_from_ground_distance_standing; float stop_to_full_running_fraction; char pad11[0x4]; float magic_fraction; char pad12[0x3C]; float world_force; char pad13[0x1CA]; float min_yaw; float max_yaw; } **")
	local animlayers = ffi.typeof("struct { char pad_0x0000[0x18]; uint32_t sequence; float prev_cycle; float weight; float weight_delta_rate; float playback_rate; float cycle;void *entity;char pad_0x0038[0x4]; } **")
	local entity_list = vtable_bind("client.dll", "VClientEntityList003", 3, "void*(__thiscall*)(void*, int)")

    entity.get_velocity = function(ent)
        local vel = entity.get_prop(ent, "m_vecVelocity")

        return vector(vel):length2d()
    end
    
    entity.get_animstate = function(ent)
        local active = ent and entity_list(ent)

		if active then
			return ffi.cast(animstates, ffi.cast("char*", ffi.cast("void***", active)) + 39264)[0]
		end
    end

    entity.get_animlayer = function(ent, layer)
        local active = entity_list(ent)

		if active then
			return ffi.cast(animlayers, ffi.cast("char*", ffi.cast("void***", active)) + 10640)[0][layer or 0]
		end
    end

    local flags = {
        ['HIT'] = {11, 2048},
        ['RELOAD'] = {5, 32}
    }

    entity.flag = function(ent, fname)
        if not ent or not fname then 
            return false 
        end
    
        local flag_data = flags[fname]

        if flag_data == nil then 
            return false 
        end

        local esp_data = entity.get_esp_data(ent) or {}
    
        return bit.band(esp_data.flags or 0, bit.lshift(1, flag_data[1])) == flag_data[2]
    end

    entity.get_hp = function(ent)
        if not ent then 
            return 0 
        end

        return entity.get_prop(ent, "m_iHealth")
    end

    entity.weapon_switch = function(ent)
        if ent then 
            local next_attack = entity.get_prop(ent, 'm_flNextAttack') - globals.curtime()

            if next_attack / globals.tickinterval() > 16 then
                return true
            end
        end

        return false
    end

    entity.charging = function(ent)
        if not ent then return false end

        local weapon = entity.get_player_weapon(ent)
        if not weapon then return false end
        
        local next_primary_attack = entity.get_prop(weapon, "m_flNextPrimaryAttack") or 0
        local next_attack = entity.get_prop(ent, "m_flNextAttack") or 0
        local curtime = globals.curtime()
        
        if entity.is_reload(ent) then
            return false
        end
        
        local clip = entity.get_prop(weapon, "m_iClip1") or 0
        local next_shot_time = next_primary_attack - curtime

        if clip > 0 and next_shot_time > 0 then
            local sequence = entity.get_prop(weapon, "m_nSequence") or 0
            local weapon_name = entity.get_classname(weapon) or ""
            
            if weapon_name:match("pistol") then
                return sequence == 3 or sequence == 4
            else
                return true
            end
        end
        
        return false
    end

    entity.is_reload = function(ent)
        if not ent or not entity.is_alive(ent) then
            return false
        end
        
        local weapon = entity.get_player_weapon(ent)
        if not weapon then
            return false
        end
        
        local next_attack = entity.get_prop(ent, 'm_flNextAttack') or 0
        local next_primary = entity.get_prop(weapon, 'm_flNextPrimaryAttack') or 0
        local curtime = globals.curtime()
        
        return entity.get_prop(weapon, 'm_bInReload') == 1 or (next_attack > curtime and next_primary > curtime)
    end

    entity.in_air = function(ent)
        local flags = entity.get_prop(ent, "m_fFlags")
        if flags == nil then 
            return 
        end 

        return bit.band(flags, 1) == 0
    end

    entity.in_duck = function(ent)
        local flags = entity.get_prop(ent, "m_fFlags")
        if flags == nil then 
            return 
        end 

        return bit.band(flags, 4) == 4
    end
end 

local USER = (_G.PRIORA_LOGIN and _G.PRIORA_LOGIN ~= "") and _G.PRIORA_LOGIN or (odyssey and _USER_NAME or js.MyPersonaAPI.GetName())
local src = {client.screen_size()}
local db = {
    server = {
        user = USER,
        role = odyssey and ((USER == "evildealers") and "admin" or "user") or "source",
        version = {"v2.0", "v1"},
    },
    name = "Priora.Club",
    src = {
        x = src[1],
        y = src[2]
    },
    states = {"global", "standing", "walking", "moving", "crouching", "crouching-moving", "air", "air-crouch", "hideshots", "fakelag"},
    hitgroups = {[0] = 'body', 'head', 'chest', 'stomach', 'left arm', 'right arm', 'left leg', 'right leg', 'neck', '?', 'gear'}
}

local refs = {  -- @flag157
    aa = {
        enabled = pui.reference("AA", "anti-aimbot angles", "Enabled"),
        angles = {
            pitch = {pui.reference("AA", "anti-aimbot angles", "Pitch")},
            yaw_base = {pui.reference("AA", "anti-aimbot angles", "Yaw base")},
            yaw = {pui.reference("AA", "anti-aimbot angles", "Yaw")},
            yaw_jitter = {pui.reference("AA", "anti-aimbot angles", "Yaw Jitter")},
            body_yaw = {pui.reference("AA", "anti-aimbot angles", "Body yaw")},
            body_free = {pui.reference("AA", "anti-aimbot angles", "Freestanding body yaw")},

            edge_yaw = pui.reference("AA", "anti-aimbot angles", "Edge yaw"),
            freestand = pui.reference("AA", "anti-aimbot angles", "Freestanding"),
            roll = {pui.reference("AA", "anti-aimbot angles", "Roll")},
        }, 
        fl = {
            enabled = {pui.reference("AA", "fake lag", "Enabled")},
            amount = {pui.reference("AA", "fake lag", "Amount")},
            variance = {pui.reference("AA", "fake lag", "Variance")},
            limit = {pui.reference("AA", "fake lag", "Limit")},
        },
        other = {
            slow = {pui.reference("AA", "other", "Slow motion")},
            legs = {pui.reference("AA", "other", "Leg movement")},
            osaa = {pui.reference("AA", "other", "On shot anti-aim")},
            peek = {pui.reference("AA", "other", "Fake peek")},
        }
    },
    rage = {
        enabled = pui.reference('RAGE', 'aimbot', 'Enabled'),
        dotap = {
            val = {pui.reference("RAGE", "aimbot", "Double tap")},
             lag = {pui.reference("RAGE", "Aimbot", "Double tap fake lag limit")}
        },
        damage = {
            val = {pui.reference('RAGE', 'aimbot', 'Minimum damage')},
            ovr = {pui.reference('RAGE', 'aimbot', 'Minimum damage override')},
        },

        log_misses = pui.reference("RAGE", "Other", "Log misses due to spread"),
        duck = {pui.reference("RAGE", "other", "Duck peek assist")},
        peek = {pui.reference("RAGE", "other", "Quick peek assist")},
        pbaim = {pui.reference('RAGE', 'aimbot', 'Prefer body aim')},
        baim = {pui.reference('RAGE', 'aimbot', 'Force body aim')},
        safe = {pui.reference('RAGE', 'aimbot', 'Force safe point')},
    },
    misc = {
        fov = pui.reference('misc', 'miscellaneous', 'Override FOV'),
        fovscope = pui.reference('misc', 'miscellaneous', 'Override zoom FOV'),
        clantag = pui.reference("MISC", "Miscellaneous", "Clan tag spammer"),
        log_damage = pui.reference("MISC", "Miscellaneous", "Log damage dealt"),
        ping_spike = pui.reference("MISC", "Miscellaneous", "Ping spike"),
        settings = {
            maxshift = pui.reference("MISC", "Settings", "sv_maxusrcmdprocessticks2")
        }
    }
}

local hitchance_ref = ui.reference("RAGE", "Aimbot", "Minimum hit chance")
if hitchance_ref ~= nil then
    ui.set_visible(hitchance_ref, false)
end

local quick_stop_ref = {ui.reference("RAGE", "Aimbot", "Quick stop")}

local grenades_ref = ui.reference("Visuals", "Other ESP", "Grenades")

local events = {
    set = client.set_event_callback,
    unset = client.unset_event_callback,
    fire = client.fire_event
}

local event_handler_mt = {
    set = function(self, callback)
        if type(callback) == "function" and self.proxy[callback] == nil then
            local callback_index = #self.callbacks + 1
            self.proxy[callback], self.callbacks[callback_index] = callback_index, callback
        end
    end,
    
    unset = function(self, callback)
        local callback_index = self.proxy[callback]
        if callback_index == nil then return end
        
        table.remove(self.callbacks, callback_index)
        self.proxy[callback] = nil
        
        for cb, idx in pairs(self.proxy) do
            if callback_index < idx then
                self.proxy[cb] = idx - 1
            end
        end
    end,
    
    __call = function(self, enable, callback)
        if enable then
            self.set(self, callback)
        else
            self.unset(self, callback)
        end
    end,
    
    fire = function(self, ...)
        return self.hook(...)
    end,
    
    global_fire = function(self, ...)
        events.fire(self.event_name, ...)
    end,
    
    unhook = function(self)
        events.unset(self.event_name, self.hook)
    end
}

event_handler_mt.__index = event_handler_mt

local callback = setmetatable({}, {
    __index = function(registry, event_name)
        local handler = setmetatable({
            event_name = event_name,
            proxy = {},
            callbacks = {}
        }, event_handler_mt)
        
        function handler.hook(...)
            if _G.OVERNIGHT_ENABLED == false then
                return
            end

            local result
            
            for i = 1, #handler.callbacks do
                if handler.callbacks[i] then
                    local callback_result = handler.callbacks[i](...)
                    if callback_result ~= nil then
                        result = callback_result
                    end
                end
            end
            
            return result
        end
        
        events.set(handler.event_name, handler.hook)
        rawset(registry, event_name, handler)
        
        return handler
    end
})

local menu = {}
local kate = db.name .. "::data"
local data = database.read(kate)
local config_notify = {}

-- session stats (reset on script load)
local session = {
    kills  = 0,
    deaths = 0,
    start  = 0,  -- set on first frame
}

local DEFAULT_CFG_NAME = "evildealers"
local DEFAULT_CFG_DATA = [[eyJhYSI6eyJidWlsZGVyIjpbeyJlbmFibGUiOmZhbHNlLCJtb2QiOiJPZmYiLCJ5YXdfbW9kZSI6MCwieWF3X2xlZnQiOjAsIm1vZF9kbSI6MCwiYm9keV9zbGlkZXIiOjAsImxhYmVsIjoiICIsImRlbGF5IjoxLCJyYW5kb20iOjAsImJvZHkiOiJPZmYiLCJ5YXdfcmlnaHQiOjAsIm9mZnNldCI6MH0seyJlbmFibGUiOnRydWUsIm1vZCI6IkNlbnRlciIsInlhd19tb2RlIjoxLCJ5YXdfbGVmdCI6LTM1LCJtb2RfZG0iOjUsImJvZHlfc2xpZGVyIjowLCJsYWJlbCI6IiAiLCJkZWxheSI6MiwicmFuZG9tIjo1LCJib2R5IjoiSml0dGVyIiwieWF3X3JpZ2h0Ijo0NSwib2Zmc2V0IjotOX0seyJlbmFibGUiOnRydWUsIm1vZCI6IkNlbnRlciIsInlhd19tb2RlIjowLCJ5YXdfbGVmdCI6NSwibW9kX2RtIjowLCJib2R5X3NsaWRlciI6MCwibGFiZWwiOiIgIiwiZGVsYXkiOjEsInJhbmRvbSI6MCwiYm9keSI6Ik9mZiIsInlhd19yaWdodCI6MjUsIm9mZnNldCI6MH0seyJlbmFibGUiOnRydWUsIm1vZCI6IkNlbnRlciIsInlhd19tb2RlIjoxLCJ5YXdfbGVmdCI6LTI4LCJtb2RfZG0iOjEwLCJib2R5X3NsaWRlciI6MCwibGFiZWwiOiIgIiwiZGVsYXkiOjEsInJhbmRvbSI6MjAsImJvZHkiOiJKaXR0ZXIiLCJ5YXdfcmlnaHQiOjMyLCJvZmZzZXQiOjB9LHsiZW5hYmxlIjp0cnVlLCJtb2QiOiJDZW50ZXIiLCJ5YXdfbW9kZSI6MSwieWF3X2xlZnQiOi0xMywibW9kX2RtIjoxMCwiYm9keV9zbGlkZXIiOjAsImxhYmVsIjoiICIsImRlbGF5IjoxLCJyYW5kb20iOjUsImJvZHkiOiJKaXR0ZXIiLCJ5YXdfcmlnaHQiOjEzLCJvZmZzZXQiOjB9LHsiZW5hYmxlIjp0cnVlLCJtb2QiOiJPZmZzZXQiLCJ5YXdfbW9kZSI6MSwieWF3X2xlZnQiOi0xOSwibW9kX2RtIjowLCJib2R5X3NsaWRlciI6MCwibGFiZWwiOiIgIiwiZGVsYXkiOjQsInJhbmRvbSI6NSwiYm9keSI6IkppdHRlciIsInlhd19yaWdodCI6NTAsIm9mZnNldCI6MH0seyJlbmFibGUiOnRydWUsIm1vZCI6IkNlbnRlciIsInlhd19tb2RlIjoxLCJ5YXdfbGVmdCI6LTI4LCJtb2RfZG0iOjAsImJvZHlfc2xpZGVyIjowLCJsYWJlbCI6IiAiLCJkZWxheSI6MywicmFuZG9tIjoxMywiYm9keSI6IkppdHRlciIsInlhd19yaWdodCI6MzAsIm9mZnNldCI6MH0seyJlbmFibGUiOnRydWUsIm1vZCI6IkNlbnRlciIsInlhd19tb2RlIjoxLCJ5YXdfbGVmdCI6LTIzLCJtb2RfZG0iOjcsImJvZHlfc2xpZGVyIjowLCJsYWJlbCI6IiAiLCJkZWxheSI6MiwicmFuZG9tIjoxMSwiYm9keSI6IkppdHRlciIsInlhd19yaWdodCI6MzcsIm9mZnNldCI6MH0seyJlbmFibGUiOnRydWUsIm1vZCI6IkNlbnRlciIsInlhd19tb2RlIjoxLCJ5YXdfbGVmdCI6LTI4LCJtb2RfZG0iOjksImJvZHlfc2xpZGVyIjowLCJsYWJlbCI6IiAiLCJkZWxheSI6MSwicmFuZG9tIjo0NSwiYm9keSI6IkppdHRlciIsInlhd19yaWdodCI6MzAsIm9mZnNldCI6MH1dLCJzZXR0aW5ncyI6eyJmcmVlc3RhbmRfYmluZCI6ZmFsc2UsImFudGlfYnJ1dGVfc3RhZ2VzIjo0LCJzZXR0aW5nc19jYXRlZ29yeSI6Ilx1MDAwYu6EoVxyIEdlbmVyYWwiLCJtYW51YWxfcmlnaHQiOmZhbHNlLCJkZWZlbnNpdmVfcGl0Y2giOiJEZWZhdWx0Iiwic2FmZV9oZWFkIjpbIktuaWZlIG9uIEFpciArIEMiXSwiYW50aV9icnV0ZV9yYW5nZSI6MzUsImFudGlfYnJ1dGUiOmZhbHNlLCJtYW51YWxfcmVzZXQiOmZhbHNlLCJ0YXJnZXRzIjoiQXQgdGFyZ2V0cyIsImF2b2lkX3NsaWRlciI6MTc1LCJkZWZlbnNpdmVfYWEiOmZhbHNlLCJsYWJlbCI6IiAiLCJmZWF0dXJlcyI6WyJBdm9pZCBCYWNrc3RhYiJdLCJsYWJlbDEiOiIgIiwiYW50aV9icnV0ZV90cmlnZ2VycyI6e30sImRpcmVjdGlvbiI6WyJGcmVlc3RhbmQiLCJNYW51YWxzIl0sIm1vZGUiOiJCdWlsZGVyIiwibWFudWFsX2ZvcndhcmQiOmZhbHNlLCJkZWZlbnNpdmVfeWF3IjoiRGVmYXVsdCIsImNvbmRpdGlvbiI6IkZyZWVzdGFuZCIsImxhYmVsMiI6IiAiLCJkZWZlbnNpdmVfbW9kZSI6e30sImFudGlfYnJ1dGVfY29vbGRvd24iOjYsImRlZmVuc2l2ZV9zdGF0ZSI6e30sIm92ZXJyaWRlX3NwaW5uZXIiOlsiTm8gZW5lbWllcyJdLCJtYW51YWxfbGVmdCI6ZmFsc2V9fSwibWVudSI6W3siY29sb3JzIjp7ImZpcnN0IjoiIzNCRDBCNkZGIn0sImNvbmZpZyI6eyJsaXN0IjoxLCJuYW1lIjoiY2VsZXN0aWFsZmFuZzIifX0seyJoaXRjaGFuY2Vfb3ZlcnJpZGUiOjAsInByZWRpY3RfaW5kIjpmYWxzZSwib3Zlcm5pZ2h0X29mZl9kdF9ocyI6dHJ1ZSwiaGl0Y2hhbmNlX2RlZmF1bHQiOjAsImhpdGNoYW5jZV9pbl9haXIiOmZhbHNlLCJvdmVybmlnaHRfYm9keV95YXdfZml4Ijp0cnVlLCJvdmVybmlnaHRfdW5zYWZlX3JlY2hhcmdlIjp0cnVlLCJoaXRjaGFuY2Vfb3ZlcnJpZGVfa2V5IjpbMSwwLCJ+Il0sIm92ZXJuaWdodF9maXhfYXV0b3N0b3AiOnRydWUsInByZWRpY3QiOlsxLDAsIn4iXSwicHJlZGljdF9jb2xvciI6IiNGRkZGRkZGRiIsImhpZGVzaG90c19maXgiOnRydWUsImhpdGNoYW5jZV9pbmRpY2F0b3IiOmZhbHNlLCJvdmVybmlnaHRfbGNfZml4Ijp0cnVlLCJoaXRjaGFuY2VfaW5fYWlyX3ZhbCI6NTB9LHsidGFiIjoiTWlzYyIsInZpc3VhbHMiOnsibWFuYWdtZW50Ijp7InR5cGUiOlsiVmVsb2NpdHkiLCJ+Il0sInZhbCI6dHJ1ZX0sImNyb3NzaGFpciI6eyJ0eXBlIjoibW9kZXJuIiwiY29sb3JzIjp7InNlY29uZCI6IiM4RkMyMTVGRiIsImZpcnN0IjoiIzNCRDBCNkZGIn0sInZhbCI6ZmFsc2UsIm1vZGVybiI6eyJtYWluIjoiI0I5QkVGRkZGIiwic3RhdGUiOiIjQjlCRUZGRkYiLCJrZXkiOiIjQjlCRUZGRkYiLCJ0cmFpbCI6IiNCOUJFRkZGRiJ9fSwidGhpcmRwZXJzb24iOnsiZGlzdGFuY2UiOjUwLCJjb2xsaXNpb24iOmZhbHNlLCJ2YWwiOnRydWV9LCJhaW1ib3RfbG9ncyI6eyJoaXQiOiIjRDNBMEJCRkYiLCJub3RpZnkiOnRydWUsIm1pc3MiOiIjRTE1MDUwRkYiLCJzdHlsZSI6Ik1pbmltYWwiLCJ2YWwiOnRydWV9LCJzcGVjbGlzdCI6ZmFsc2UsIndhdGVybWFyayI6eyJwb3NpdGlvbiI6IkJvdHRvbSIsInZhbCI6dHJ1ZSwidHlwZSI6IlRleHQiLCJjb2xvcnMiOnsic2Vjb25kIjoiIzhGQzIxNUZGIiwiZmlyc3QiOiIjM0JEMEI2RkYifSwic3R5bGUiOiJEZWZhdWx0In0sInpvb20iOnsiZm92IjoyMCwidmFsIjpmYWxzZSwic3BlZWQiOjEwfSwidmlld21vZGVsIjp7ImZvdiI6NjgsInBpdGNoIjowLCJ2YWwiOmZhbHNlLCJ5IjowLCJpbl9zY29wZSI6ZmFsc2UsInJvbGwiOjAsIm9wdGlvbnMiOlsifiJdLCJ5YXciOjAsInoiOjAsIngiOjB9LCJhc3BlY3RfcmF0aW8iOnsidmFsdWUiOjEzMCwidmFsIjp0cnVlfSwiZGFtYWdlIjp7InR5cGUiOiJTbWFsbCIsIm1vZGUiOiJBbHdheXMiLCJ2YWwiOnRydWV9LCJwb2ludGVycyI6eyJ0eXBlIjoiRGVmYXVsdCIsInZhbCI6ZmFsc2V9LCJiaW5kbGlzdCI6ZmFsc2V9LCJtaXNjIjp7ImZhc3RfZmFsbF9oIjpbMSwwLCJ+Il0sImNsYW50YWciOnRydWUsInRyYXNodGFsayI6eyJtb2RlIjpbIk9uIGtpbGwiLCJ+Il0sInZhbCI6ZmFsc2V9LCJkdWNrX3NwZWVkIjp0cnVlLCJidXlib3QiOnsibmFkZXMiOlsiU21va2UiLCJ+Il0sInNlY29uZCI6IkRlYWdsZVwvUjgiLCJvdGhlciI6WyJLZXZsYXIiLCJ+Il0sInByaW0iOiJTU0ctMDgiLCJ2YWwiOmZhbHNlfSwiYnJlYWtlciI6eyJzdWJtb2RlIjpbIn4iXSwibW9kZSI6Ik9mZiIsInZhbCI6ZmFsc2V9LCJjaGFyZ2VfZml4Ijp0cnVlLCJmYXN0X2ZhbGwiOmZhbHNlLCJmYXN0X2xhZGRlciI6dHJ1ZSwiZmlsdGVyIjp0cnVlfX0seyJmcmVlc3RhbmRfYmluZCI6WzEsMTgsIn4iXSwiYW50aV9icnV0ZV9zdGFnZXMiOjQsInNldHRpbmdzX2NhdGVnb3J5IjoiXHUwMDBi7oShXHIgR2VuZXJhbCIsIm1hbnVhbF9yaWdodCI6WzEsMCwifiJdLCJkZWZlbnNpdmVfcGl0Y2giOiJEZWZhdWx0Iiwic2FmZV9oZWFkIjpbIktuaWZlIG9uIEFpciArIEMiLCJ+Il0sImFudGlfYnJ1dGVfcmFuZ2UiOjM1LCJhbnRpX2JydXRlIjpmYWxzZSwibWFudWFsX3Jlc2V0IjpbMSwwLCJ+Il0sImF2b2lkX3NsaWRlciI6MTc1LCJidWlsZGVyIjpbeyJlbmFibGUiOmZhbHNlLCJyYW5kb20iOjAsImJvZHlfc2xpZGVyIjowLCJib2R5IjoiT2ZmIiwibW9kIjoiT2ZmIiwib2Zmc2V0IjowLCJkZWxheSI6MSwibW9kX2RtIjowLCJ5YXdfbGVmdCI6MCwieWF3X3JpZ2h0IjowLCJ5YXdfbW9kZSI6MH0seyJlbmFibGUiOnRydWUsInJhbmRvbSI6NSwiYm9keV9zbGlkZXIiOjAsImJvZHkiOiJKaXR0ZXIiLCJtb2QiOiJDZW50ZXIiLCJvZmZzZXQiOi05LCJkZWxheSI6MiwibW9kX2RtIjo1LCJ5YXdfbGVmdCI6LTM1LCJ5YXdfcmlnaHQiOjQ1LCJ5YXdfbW9kZSI6MX0seyJlbmFibGUiOnRydWUsInJhbmRvbSI6MCwiYm9keV9zbGlkZXIiOjAsImJvZHkiOiJPZmYiLCJtb2QiOiJDZW50ZXIiLCJvZmZzZXQiOjAsImRlbGF5IjoxLCJtb2RfZG0iOjAsInlhd19sZWZ0Ijo1LCJ5YXdfcmlnaHQiOjI1LCJ5YXdfbW9kZSI6MH0seyJlbmFibGUiOnRydWUsInJhbmRvbSI6MjAsImJvZHlfc2xpZGVyIjowLCJib2R5IjoiSml0dGVyIiwibW9kIjoiQ2VudGVyIiwib2Zmc2V0IjowLCJkZWxheSI6MSwibW9kX2RtIjoxMCwieWF3X2xlZnQiOi0yOCwieWF3X3JpZ2h0IjozMiwieWF3X21vZGUiOjF9LHsiZW5hYmxlIjp0cnVlLCJyYW5kb20iOjUsImJvZHlfc2xpZGVyIjowLCJib2R5IjoiSml0dGVyIiwibW9kIjoiQ2VudGVyIiwib2Zmc2V0IjowLCJkZWxheSI6MSwibW9kX2RtIjoxMCwieWF3X2xlZnQiOi0xMywieWF3X3JpZ2h0IjoxMywieWF3X21vZGUiOjF9LHsiZW5hYmxlIjp0cnVlLCJyYW5kb20iOjUsImJvZHlfc2xpZGVyIjowLCJib2R5IjoiSml0dGVyIiwibW9kIjoiT2Zmc2V0Iiwib2Zmc2V0IjowLCJkZWxheSI6NCwibW9kX2RtIjowLCJ5YXdfbGVmdCI6LTE5LCJ5YXdfcmlnaHQiOjUwLCJ5YXdfbW9kZSI6MX0seyJlbmFibGUiOnRydWUsInJhbmRvbSI6MTMsImJvZHlfc2xpZGVyIjowLCJib2R5IjoiSml0dGVyIiwibW9kIjoiQ2VudGVyIiwib2Zmc2V0IjowLCJkZWxheSI6MywibW9kX2RtIjowLCJ5YXdfbGVmdCI6LTI4LCJ5YXdfcmlnaHQiOjMwLCJ5YXdfbW9kZSI6MX0seyJlbmFibGUiOnRydWUsInJhbmRvbSI6MTEsImJvZHlfc2xpZGVyIjowLCJib2R5IjoiSml0dGVyIiwibW9kIjoiQ2VudGVyIiwib2Zmc2V0IjowLCJkZWxheSI6MiwibW9kX2RtIjo3LCJ5YXdfbGVmdCI6LTIzLCJ5YXdfcmlnaHQiOjM3LCJ5YXdfbW9kZSI6MX0seyJlbmFibGUiOnRydWUsInJhbmRvbSI6NDUsImJvZHlfc2xpZGVyIjowLCJib2R5IjoiSml0dGVyIiwibW9kIjoiQ2VudGVyIiwib2Zmc2V0IjowLCJkZWxheSI6MSwibW9kX2RtIjo5LCJ5YXdfbGVmdCI6LTI4LCJ5YXdfcmlnaHQiOjMwLCJ5YXdfbW9kZSI6MX1dLCJmZWF0dXJlcyI6WyJBdm9pZCBCYWNrc3RhYiIsIn4iXSwiZGVmZW5zaXZlX3lhdyI6IkRlZmF1bHQiLCJhbnRpX2JydXRlX3RyaWdnZXJzIjpbIn4iXSwiZGlyZWN0aW9uIjpbIkZyZWVzdGFuZCIsIk1hbnVhbHMiLCJ+Il0sIm1vZGUiOiJCdWlsZGVyIiwibWFudWFsX2ZvcndhcmQiOlsxLDM4LCJ+Il0sIm1hbnVhbF9sZWZ0IjpbMSwwLCJ+Il0sImRlZmVuc2l2ZV9hYSI6ZmFsc2UsImRlZmVuc2l2ZV9zdGF0ZSI6WyJ+Il0sImNvbmRpdGlvbiI6IkZyZWVzdGFuZCIsImFudGlfYnJ1dGVfY29vbGRvd24iOjYsImRlZmVuc2l2ZV9tb2RlIjpbIn4iXSwib3ZlcnJpZGVfc3Bpbm5lciI6WyJObyBlbmVtaWVzIiwifiJdLCJ0YXJnZXRzIjoiQXQgdGFyZ2V0cyJ9XSwic2NoZW1hIjoyLCJwb3NpdGlvbnMiOnsidmVsb2NpdHkiOnsieSI6OTQsIngiOjkwMH0sImNyb3NzaGFpciI6eyJ5Ijo1NjksIngiOjkzNX0sInBvaW50ZXMiOnsieSI6NTI5LCJ4IjoxMDEwfSwiYWltYm90X2xvZ3MiOnsieSI6Nzk1LCJ4Ijo4NDB9LCJzcGVjbGlzdCI6eyJ5IjozMjAsIngiOjQyMH0sIndhdGVybWFyayI6eyJ5IjoxMDU4LCJ4Ijo5NjB9LCJiaW5kcyI6eyJ5IjozODEsIngiOjQxMH0sImRhbWFnZSI6eyJ5Ijo1MjQsIngiOjk3MH0sImRlZmVuc2l2ZSI6eyJ5Ijo0MDAsIngiOjkwMH19fQ==]]

local function ensure_default_config()
    if type(data) ~= "table" then
        return
    end
    data.configs = data.configs or {}
    if data.configs[DEFAULT_CFG_NAME] ~= DEFAULT_CFG_DATA then
        data.configs[DEFAULT_CFG_NAME] = DEFAULT_CFG_DATA
        database.write(kate, data)
    end
end

_G.OVERNIGHT_ENABLED = true

local function guarded_event(fn, allow_when_disabled)
    return function(...)
        if _G.OVERNIGHT_ENABLED == false and not allow_when_disabled then
            return
        end
        return fn(...)
    end
end

if not data then 
    data = {
        configs = {},
        statx = {
            selfmiss = 0,
            playtime = 0,
            load = 1,
            kill = 0
        }
    }

    database.write(kate, data)
end 

if not data.statx.selfmiss then 
    data.statx.selfmiss = 0
end

if not data.statx.load then 
    data.statx.load = 0
end

if not data.statx.kill then 
    data.statx.kill = 0
end

if not data.statx.playtime then 
    data.statx.playtime = 0
end

ensure_default_config()

data.statx.load = data.statx.load + 1

local raw_print = _G.print

local function console_print(message)
    local text = tostring(message or ""):lower()

    if text:find("error", 1, true)
        or text:find("failed", 1, true)
        or text:find("invalid", 1, true)
        or text:find("not found", 1, true)
        or text:find("broken", 1, true)
        or text:find("missing", 1, true)
    then
        raw_print(message)
    end
end

defer(function()
    database.write(kate, data)
end)

-- Bullet tracer
local tracer_queue = {}

-- Custom scope
local scope_alpha = 0
local _scope_hold_t = nil

game = {
    me = nil,
    cmd = nil,
    origin = nil,
    using = false,
    alive = false,
    target = nil,
    velocity = 0,
    movetype = 0,
    press_left = false,
    charged = false,
    scope = {
        open = false,
        anim = 0,
    }
}

local extra, animate = {}, {
    tbl = {},
    pulse = 0.0,

    string = function(self, name, text, speed)
        local speed = speed or 0.15

        if self.tbl[name] == nil then
            self.tbl[name] = {
                target_text = text,
                current_text = "",
                fraction = 0
            }
        end

        local state = self.tbl[name]

        if state.target_text ~= text then
            state.target_text = text
        end

        local diff = (state.current_text == state.target_text and -1) or (state.current_text ~= state.target_text and 1)

        if diff == 1 then
            state.fraction = math.min(1, state.fraction + globals.frametime() / speed)
        elseif diff == -1 then
            state.fraction = math.max(0, state.fraction - globals.frametime() / speed)
        end

        local animated_text = string.interval(state.current_text, state.target_text, state.fraction)
        
        if state.fraction >= 1 then
            state.current_text = state.target_text
        end

        return animated_text
    end,
    
    lerp = function(start, endd, speed, align, typed)
        if start == nil or endd == nil then
            return endd or start or 0
        end
        local fps = globals.frametime()
        local complete
        
        if typed and typed:find("near") then
            local step = (speed * 50) * fps

            if start < endd then
                complete = math.min(start + step, endd)
            else
                complete = math.max(start - step, endd)
            end
        else
            complete = start + (endd - start) * fps * (speed or 8)
        end
        
        return math.abs(endd - complete) < (align or 0.01) and endd or complete
    end,

    new_lerp = function(self, name, value, speed, floor)
        if self.tbl[name] == nil then
            self.tbl[name] = value
        end
            
        local animation = self.lerp(self.tbl[name], value, speed)
    
        self.tbl[name] = animation
    
        local toret = self.tbl[name]

        return floor and math.floor(toret) or toret
    end,

    get = function(name)
        return self.tbl[name]
    end 
}

inition()

local helper = {
    command = function(cmd)
        if game.alive then 
            local tick = entity.get_prop(game.me, 'm_nTickBase')
            local latency = client.latency()
            local shift = math.floor(tick - globals.tickcount() - 3 - toticks(latency) * .5 + .5 * (latency * 10))
    
            local wanted = -14 + (refs.rage.dotap.lag[1]:get() - 1) + 3
    
            game.charged = shift <= wanted
            game.using = cmd.in_use == 1
            game.cmd = cmd
        end
    end,

    net_update_end = function()
        if (globals.tickcount() % 2 == 0) then 
            return 
        end

        game.me = entity.get_local_player()
        game.alive = game.me ~= nil and entity.is_alive(game.me)
        game.press_left = client.key_state(0x01) == true

        if game.alive then 
            local vl = entity.get_prop(game.me, "m_vecVelocity")

            game.movetype = entity.get_prop(game.me, "m_MoveType")
            game.origin = entity.get_origin(game.me)
            game.target = client.current_threat()
            game.velocity = vector(vl):length2d()
            game.scope.open = entity.get_prop(game.me, "m_bIsScoped") == 1
        end
    end,

    playerdeath = function(e)
        local victim = client.userid_to_entindex(e.userid)
        local attacker = client.userid_to_entindex(e.attacker) 

        if attacker == game.me and victim ~= game.me then 
            data.statx.kill = data.statx.kill + 1
            session.kills = session.kills + 1
        end
        if victim == game.me then
            session.deaths = session.deaths + 1
        end
    end,

    render = function()
        animate.pulse = math.sin(globals.realtime() * 2) * 0.5 + 0.5
        data.statx.playtime = data.statx.playtime + 1
    end
}

callback.net_update_end:set(helper.net_update_end)
callback.player_death:set(helper.playerdeath)
callback.setup_command:set(helper.command)

local clr = {
    tbl = {},

    rgb = function(r, g, b, a)
        local color = {r = r, g = g, b = b, a = a or 255}
        
        setmetatable(color, {
            __index = {
                default = function(self)
                    return self.r, self.g, self.b, self.a
                end,

                hex = function(self, prefix)
                    return (prefix and "\a" or "") .. string.format("%02x%02x%02x", self.r, self.g, self.b)
                end,

                hexa = function(self, prefix)
                    return (prefix and "\a" or "") .. string.format("%02x%02x%02x%02x", self.r, self.g, self.b, self.a)
                end,

                alphen = function(self, number)
                    self.a = math.clamp(number, 0, 255)
                    return self
                end
            }
        })
        
        return color
    end, -- clr:lerp
    
    lerp = function(self, name, value, speed) 
        local target_color = { value.r or 255, value.g or 255, value.b or 255, value.a or 255 }
        
        if not self.tbl[name] then
            self.tbl[name] = { target_color[1], target_color[2], target_color[3], target_color[4]}
        end
        
        local result = {}
        
        for i = 1, 4 do
            result[i] = animate.lerp(self.tbl[name][i], target_color[i], speed)
            self.tbl[name][i] = result[i]
        end
        
        return self.rgb(result[1], result[2], result[3], result[4])
    end,

    gradient = function(self, text, color1, color2, speed)
        local result = {}
        local time = globals.curtime()
        
        for i = 1, #text do
            local iter = (i - 1)/(#text - 1) + time * (speed or 1)
            local progress = math.abs(math.cos(iter))
            
            local r = color1.r + (color2.r - color1.r) * progress
            local g = color1.g + (color2.g - color1.g) * progress
            local b = color1.b + (color2.b - color1.b) * progress
            local a = color1.a + (color2.a - color1.a) * progress
            
            table.insert(result, self.rgb(r, g, b, a):hexa(true))
            table.insert(result, text:sub(i, i))
        end
        
        return table.concat(result)
    end
}

local accent = {
    clr.rgb(138, 43, 226, 255),
    clr.rgb(255, 20, 147, 255)
}
local accent_wm = {
    clr.rgb(138, 43, 226, 255),
    clr.rgb(255, 20, 147, 255)
}

clr.white = clr.rgb(255, 255, 255)
clr.gray = clr.rgb(190, 190, 190)

local util = {
    format = {
        time = function(seconds)
            local total = tonumber(seconds) or 0
            local h = math.floor(total / 3600)
            local m = math.floor((total % 3600) / 60)
            local s = math.floor(total % 60)
            return string.format("%02d:%02d:%02d", h, m, s)
        end,
        yaw = function(angle)
            local a = (tonumber(angle) or 0) % 360
            if a > 180 then
                a = a - 360
            end
            return a
        end
    },
    state = {
        get = function()
            local lp = entity.get_local_player()
            if not lp or not entity.is_alive(lp) then
                return "idle"
            end

            local vx, vy = entity.get_prop(lp, "m_vecVelocity")
            local flags = entity.get_prop(lp, "m_fFlags")
            local velocity = math.sqrt((vx or 0) ^ 2 + (vy or 0) ^ 2)
            local groundcheck = bit.band(flags or 0, 1) == 1
            local jumpcheck = bit.band(flags or 0, 1) == 0 or (game.cmd and game.cmd.in_jump == 1)
            local ducked = (entity.get_prop(lp, "m_flDuckAmount") or 0) > 0.7
            local duckcheck = ducked or refs.rage.duck[1]:get()
            local slowwalk_key = refs.aa.other.slow[1]:get() and refs.aa.other.slow[1]:get_hotkey()
            local freestand = refs.aa.angles.freestand:get() and refs.aa.angles.freestand:get_hotkey()

            if groundcheck and freestand then
                return "freestand"
            elseif jumpcheck and duckcheck then
                return "air+c"
            elseif jumpcheck then
                return "air"
            elseif duckcheck and velocity > 10 then
                return "crouch+move"
            elseif duckcheck and velocity < 10 then
                return "crouch"
            elseif groundcheck and slowwalk_key and velocity > 10 then
                return "walk"
            elseif groundcheck and velocity > 5 then
                return "run"
            elseif groundcheck and velocity < 5 then
                return "stand"
            end

            return "global"
        end
    }
}

local render = {}
do
    local function rounded_rect(x, y, w, h, radius, r, g, b, a)
        local rad = math.min(radius or 0, math.floor(math.min(w, h) / 2))
        if rad <= 0 then
            renderer.rectangle(x, y, w, h, r, g, b, a)
            return
        end
        renderer.rectangle(x + rad, y, w - rad * 2, h, r, g, b, a)
        renderer.rectangle(x, y + rad, rad, h - rad * 2, r, g, b, a)
        renderer.rectangle(x + w - rad, y + rad, rad, h - rad * 2, r, g, b, a)
        renderer.circle(x + rad, y + rad, r, g, b, a, rad, 180, 0.25)
        renderer.circle(x + w - rad, y + rad, r, g, b, a, rad, 90, 0.25)
        renderer.circle(x + w - rad, y + h - rad, r, g, b, a, rad, 0, 0.25)
        renderer.circle(x + rad, y + h - rad, r, g, b, a, rad, 270, 0.25)
    end

    function render.rect(x, y, w, h, clr1, radius)
        local r1, g1, b1, a1 = unpack(clr1)
        rounded_rect(x, y, w, h, radius or 0, r1, g1, b1, a1)
    end

    function render.rectangle(x, y, w, h, r, g, b, a)
        renderer.rectangle(x, y, w, h, r, g, b, a)
    end

    function render.outline(x, y, w, h, clr1, radius, thickness)
        local r1, g1, b1, a1 = unpack(clr1)
        local t = thickness or 1
        render.rect(x, y, w, t, {r1, g1, b1, a1}, radius)
        render.rect(x, y + h - t, w, t, {r1, g1, b1, a1}, radius)
        render.rect(x, y, t, h, {r1, g1, b1, a1}, radius)
        render.rect(x + w - t, y, t, h, {r1, g1, b1, a1}, radius)
    end

    function render.gradient(x, y, w, h, clr1, clr2)
        local r1, g1, b1, a1 = unpack(clr1)
        local r2, g2, b2, a2 = unpack(clr2)
        if renderer.gradient then
            renderer.gradient(x, y, w, h, r1, g1, b1, a1, r2, g2, b2, a2, true)
        else
            renderer.rectangle(x, y, w, h, r1, g1, b1, a1)
        end
    end

    function render.text(x, y, r, g, b, a, font, text)
        renderer.text(x, y, r, g, b, a, font or "", 0, text or "")
    end

    function render.measures(flag, text)
        local f = flag or ""
        local t = text or ""
        local w, h = renderer.measure_text(f, t)
        return {w = w or 0, h = h or 0, text = t, flag = f}
    end

    function render.side_v(x, y, w, h, clr1, radius)
        render.rect(x, y, w, h, clr1, radius or 0)
    end

    function render.triangle(x1, y1, x2, y2, x3, y3, r, g, b, a)
        renderer.triangle(x1, y1, x2, y2, x3, y3, r, g, b, a)
    end

    function render.blur(x, y, w, h)
        if surface and surface.blur then
            surface.blur(x, y, w, h)
        elseif renderer.blur then
            renderer.blur(x, y, w, h)
        end
    end
end

local draggable = {
    items = {},
    active = nil,
    input_locked = false
}

function draggable:new(name, x, y, opts)
    local obj = {
        name = name,
        x = x or 0,
        y = y or 0,
        w = 0,
        h = 0,
        alpha = 1,
        round = opts and opts.round or 0,
        border = opts and opts.border or nil,
        align = opts and opts.align or nil
    }
    self.items[name] = obj
    return setmetatable(obj, {__index = self})
end

function draggable:release(w, h)
    self.w = w or self.w or 0
    self.h = h or self.h or 0

    if not pui.menu_open or self.resizing or self.input_locked then
        return
    end

    local screen_w, screen_h = client.screen_size()

    local mouse_x, mouse_y = ui.mouse_position()
    local in_box = mouse_x >= self.x and mouse_x <= self.x + self.w and mouse_y >= self.y and mouse_y <= self.y + self.h

    if game.press_left and in_box and (draggable.active == nil or draggable.active == self) then
        if draggable.active ~= self then
            draggable.active = self
            self.drag_dx = mouse_x - self.x
            self.drag_dy = mouse_y - self.y
        end
        self.x = mouse_x - (self.drag_dx or 0)
        self.y = mouse_y - (self.drag_dy or 0)
        if screen_w and screen_h then
            self.x = math.clamp(self.x, 0, screen_w - self.w)
            self.y = math.clamp(self.y, 0, screen_h - self.h)
        end
    elseif not game.press_left and draggable.active == self then
        draggable.active = nil
    end
end

function draggable:part()
    return
end

function draggable:is_dragging()
    return self.active ~= nil
end

function draggable:export()
    local out = {}
    for name, obj in pairs(self.items) do
        local entry = {x = obj.x, y = obj.y}
        if type(obj.user_w) == "number" then
            entry.w = obj.user_w
        end
        if type(obj.user_h) == "number" then
            entry.h = obj.user_h
        end
        out[name] = entry
    end
    return out
end

function draggable:import(positions)
    if type(positions) ~= "table" then
        return
    end
    for name, pos in pairs(positions) do
        local obj = self.items[name]
        if obj and type(pos) == "table" then
            if type(pos.x) == "number" then
                obj.x = pos.x
            end
            if type(pos.y) == "number" then
                obj.y = pos.y
            end
            if type(pos.w) == "number" then
                obj.user_w = pos.w
            end
            if type(pos.h) == "number" then
                obj.user_h = pos.h
            end
        end
    end
end

function draggable:lock_input()
    self.input_locked = true
end

function draggable:unlock_input()
    self.input_locked = false
end

local antiaim_enabled = true

local antiaim_cond = {"Global", "Stand", "Walk", "Run", "Air", "Air+C", "Crouch", "Crouch+Move", "Freestand"}

local group = {
    pui.group("AA", "anti-aimbot angles"),
    pui.group("AA", "Fake lag"),
    pui.group("AA", "Other")
}

local icon_map = {
    ["Ragebot"]      = "",
    ["Anti-aim"]     = "",
    ["Visuals"]      = "",
    ["Misc"]         = "",
    ["Configs"]      = "",
    ["Crosshair"]    = "",
    ["Damage numbers"] = "",
    ["Scope zoom"]   = "",
    ["Side arrows"]  = "",
    ["HUD"]          = "",
    ["Overlay"]      = "",
    ["Spectators"]   = "",
    ["Binds"]        = "",
    ["Logs"]         = "",
    ["Shot logger"]  = "",
    ["Observers"]    = "",
    ["Aspect ratio"] = "",
    ["Air hitchance"] = "",
    ["HC indicator"] = "",
    ["Hideshot fix"] = "",
    ["Predict HUD"]  = "",
    ["Predict"]      = "",
    ["Charge fix"]   = "",
    ["Duck speed"]   = "",
    ["Fall discharge"] = "",
    ["Ladder boost"] = "",
    ["Defensive fix"] = "",
    ["Fast shoot"]   = "",
    ["Anim break"]   = "",
    ["Auto buy"]     = "",
    ["Clan tag"]     = "",
    ["Trashtalk"]    = "",
    ["Log filter"]   = "",
    ["Viewmodel"]    = "",
    ["Third person"] = "",
    ["Damage"]       = "",
    ["Other"]        = "",
    ["Home"]         = "",
    ["3D Hitmarker"] = "",
    ["Tracers"]      = "",
    ["Scope lines"]  = "",
}

local function iconize_label(label)
    if type(label) ~= "string" then
        return label
    end
    if label:sub(1, 1) == "\n" or label:find("\v", 1, true) then
        return label
    end
    local icon = icon_map[label]
    if not icon then
        return label
    end
    return "\v" .. icon .. "\r " .. label
end

local option_icon_map = {
    ["General"]   = "",
    ["Manuals"]   = "",
    ["Safety"]    = "",
    ["Defensive"] = "",
}

local function iconize_option(label)
    if type(label) ~= "string" then
        return label
    end
    local icon = option_icon_map[label]
    if not icon then
        return label
    end
    return "\v" .. icon .. "\r " .. label
end

local function wrap_group_checkbox(g)
    local orig = g.checkbox
    if not orig then
        return
    end
    g.checkbox = function(self, label, ...)
        return orig(self, iconize_label(label), ...)
    end
end

local function wrap_group_label(g)
    local orig = g.label
    if not orig then
        return
    end
    g.label = function(self, label, ...)
        if type(label) ~= "string" then
            return orig(self, label, ...)
        end
        if label:gsub("%s+", "") == "" then
            return orig(self, label, ...)
        end
        return orig(self, iconize_label(label), ...)
    end
end

for i = 1, #group do
    wrap_group_checkbox(group[i])
    wrap_group_label(group[i])
end

local ifc = {
    hide = function(visible)
        pui.traverse(refs.aa, function(ac)
            ac:set_visible(visible)
        end)
    end,
    space = function(self, group)
        return group:label("\n")
    end,
    header = function(self, tbl, group, key, icon)
        tbl[#tbl + 1] = self:space(group)
        tbl[#tbl + 1] = group:label(iconize_label(key) .. (icon and "    \f<v>"..icon or ""))
        tbl[#tbl + 1] = self:space(group)
    end,
    hidden = function(parent, callback)
        parent = (parent.__type == "pui::element") and {parent} or parent
        
        local elements, enable = callback(parent[1])
        
        for _, element in ipairs(elements) do
            if element and element.depend then
                element:depend({parent[1], enable})
            end
        end
        
        elements.val = parent[1]
        elements.enabled = enable
        
        return elements
    end,
    init = function(self)
        local tabs = {
            menu = {"Home", "Ragebot", "Anti-aim", "Other"},
            home = {"Socials"},
            other = {"Visual", "Misc"},
            aa_other = {"Settings", "Binds"},
            builder = {"Builder", "Defensive"}
        }

        pui.macros = {
            red = clr.rgb(180,0,0):hexa(true),
            gray = clr.rgb(70,70,70):hexa(true),
            yell = clr.rgb(182, 182, 101):hexa(true),
            hex1 = accent[1]:hex(),
            hex2 = accent[2]:hex(),
            v = accent[1]:hexa(true)
        }
        pui.macros.m = pui.macros.v.."\r"

        menu = { -- @flag153 @flag154
            tab_label = group[2]:label(" "),
            banner = group[2]:label("PrioraClub"),
            tab = group[2]:combobox("\nmenu-tab", tabs.menu),
            
            space = self:space(group[2]),

            home = {
                config = {
                    import = group[1]:button("\f<v>\r  Import from clipboard"),
                    list = group[1]:listbox("\nlist-config", {}),
                    name = group[1]:textbox("\nname-config"),
                    save = group[1]:button("\f<v>\r  Save"),
                    load = group[1]:button("\f<v>\r  Load"),
                    export = group[1]:button(" Export in clipboard"),
                    delete = group[1]:button("\f<red>  Delete"),
                },
                colors = {
                    first = group[2]:color_picker("\nmenu-first-clr", 138, 43, 226)
                },

                other = {
                    space = self:space(group[3]),

                    info = {},
                    discord_btn = group[3]:button("\f<v>\r Discord.gg"),

                    stats = {
                        build    = group[2]:label("\f<v>\r Your active build: \f<v>" .. db.server.version[1]),
                        row1     = group[2]:label("\f<v>\r Kills \f<gray>0   \f<v>Deaths \f<gray>0"),
                        row2     = group[2]:label("\f<v>\r K/D \f<gray>0.00   \f<v>Time \f<gray>00:00:00"),
                        row3     = group[2]:label("\f<v>\r Loads \f<gray>0   \f<v>Misses \f<gray>0"),
                    }
                }
            },
            ragebot = {
                header = group[1]:label("Ragebot"),
                predict = group[1]:hotkey("Predict"),
                predict_ind = group[1]:checkbox("Predict HUD"),
                predict_color = group[1]:color_picker("\npredict-color", 255, 255, 255, 255),
                hideshots_fix = group[1]:checkbox("Hideshot fix"),
                hitchance_default = group[1]:slider("Hit chance", 0, 100, 50, true, "%"),
                hitchance_in_air = group[1]:checkbox("Air hitchance"),
                hitchance_in_air_val = group[1]:slider("\nIn-air hit chance", 0, 100, 50, true, "%"),
                hitchance_override = group[1]:slider("HC override", 0, 100, 50, true, "%"),
                hitchance_override_key = group[1]:hotkey("HC override", false),
                hitchance_indicator = group[1]:checkbox("HC indicator"),

                overnight_header = group[3]:label(" PrioraClub utilities"),
                overnight_body_yaw_fix = group[3]:checkbox(" PrioraClub Body yaw fix"),
                overnight_lc_fix = group[3]:checkbox(" PrioraClub Lag compensation fix"),
                overnight_off_dt_hs = group[3]:checkbox(" Off Double tap on Hide shots"),
                overnight_unsafe_recharge = group[3]:checkbox(" Unsafe recharge"),
                overnight_fix_autostop = group[3]:checkbox(" \f<v>Fix\r Autostop"),
            },
            other = {
                tab = group[1]:combobox("\ntab-other", tabs.other),
                space = self:space(group[1]),

                visuals = {
                    crosshair = self.hidden(group[1]:checkbox("Crosshair"), function(val)
                        local mode = group[1]:combobox("\ncross-type", {"modern"}):depend({val, true})
                        local first = group[1]:color_picker("\nind-first-clr", 138, 43, 226):depend({val, true})
                        local second = group[1]:color_picker("\nind-second-clr", 255, 20, 147):depend({val, true})
                        local modern_main = group[1]:color_picker("\n", 185, 190, 255, 255):depend({val, true}, {mode, "modern"})
                        local modern_trail = group[1]:color_picker("\n", 23, 23, 23, 0):depend({val, true}, {mode, "modern"})
                        local modern_state = group[1]:color_picker("\n", 255, 255, 255, 255):depend({val, true}, {mode, "modern"})
                        local modern_key = group[1]:color_picker("\n", 255, 255, 255, 255):depend({val, true}, {mode, "modern"})

                        return {
                            type = mode,
                            colors = {first = first, second = second},
                            modern = {
                                main = modern_main,
                                trail = modern_trail,
                                state = modern_state,
                                key = modern_key
                            }
                        }
                    end),
                    damage = self.hidden(group[1]:checkbox("Damage numbers"), function(val)
                        return {
                            mode = group[1]:combobox("\ndamage-mode", {"Hotkey", "Always"}):depend({val, true}),
                            type = group[1]:combobox("\ndamage-font", {"Default", "Small", "Bold"}):depend({val, true})
                        }
                    end),
                    aimbot_logs = self.hidden(group[1]:checkbox("Shot logger"), function(val)
                        local notify = group[1]:checkbox("\vAimbot logs\r ~ notify output"):depend({val, true})
                        local style = group[1]:combobox("\nAimbot logs style", {"Cards", "Minimal"}):depend({val, true})
                        local hit = group[1]:color_picker("\nlog-hit", 211, 160, 187, 255):depend({val, true}, {notify, true})
                        local miss = group[1]:color_picker("\nlog-miss", 225, 80, 80, 255):depend({val, true}, {notify, true})
                        return {
                            notify = notify,
                            style = style,
                            hit = hit,
                            miss = miss
                        }
                    end),
                    
                    
                    
                    
                    zoom = self.hidden(group[1]:checkbox("Scope zoom"), function(val)
                        return {
                            fov = group[1]:slider("\nzoom-fov", 5, 50, 20, true, "+F"):depend({val, true}),
                            speed = group[1]:slider("\nzoom-speed", 10, 30, 10, true, "s", 0.1):depend({val, true})
                        }
                    end),
                    pointers = self.hidden(group[1]:checkbox("Side arrows"), function(val) -- @flag155
                        return {
                            type = group[1]:combobox("\npointers-sett", {"Default", "TeamSkeet", "Small"}):depend({val, true})
                        }
                    end),
                    speclist = group[1]:checkbox(" Spectator list"),
                    tracer = group[1]:checkbox(" Bullet tracers"),
                    tracer_color = group[1]:color_picker("\ntracer-color", 150, 210, 30, 255),
                    hitmarker = group[1]:checkbox("3D Hitmarker"),
                    hitmarker_color = group[1]:color_picker("\nhitmarker-color", 255, 255, 255, 255),
                    hitmarker_size = group[1]:slider("\nHitmarker size", 1, 15, 4, true, ""),
                    hitmarker_duration = group[1]:slider("Hitmarker duration", 1, 5, 3, true, "s"),
                    custom_scope = group[1]:checkbox(" Custom scope lines"),
                    scope_color = group[1]:color_picker("\nscope-color", 0, 0, 0, 255),
                    scope_position = group[1]:slider("\nscope position", 0, 500, 190, true, ""),
                    scope_offset = group[1]:slider("\nscope offset", 0, 500, 15, true, ""),
                    scope_speed = group[1]:slider("Fade speed", 3, 20, 12, true, "fr", 1),
                    scope_invert = group[1]:checkbox("\nInvert fade"),
                    scope_exclude = group[1]:multiselect("\nExclude lines", {"Left", "Right", "Top", "Bottom"}),
                    bindlist = group[1]:checkbox(" Hotkey list"),
                    aspect_ratio = self.hidden(group[1]:checkbox("Aspect ratio"), function(val)
                        return {
                            value = group[1]:slider("\nAspect ratio", 0, 200, 100, true, "%"):depend({val, true})
                        }
                    end),
                    
                    
                    space = self:space(group[1]),

                    managment = self.hidden(group[1]:checkbox("HUD"), function(val)
                        local modes = group[1]:multiselect("\nmanagment-sett", {"Velocity", "Defensive"}):depend({val, true})

                        return {
                            type = modes
                        }
                    end),
                    watermark = self.hidden(group[1]:checkbox("Overlay"), function(val) -- flag@152
                        local mode = group[1]:combobox("\nwater-mode", {"Text", "Widget"}):depend({val, true})
                        local style = group[1]:combobox("Style", {"Modern", "Default"}):depend({val, true}, {mode, "Text"})
                        local position = group[1]:combobox("Overlay position", {"Custom", "Left", "Right", "Bottom"}):depend({val, true})
                        local first = group[1]:color_picker("\nwm-first-clr", 185, 190, 255):depend({val, true})
                        local second = group[1]:color_picker("\nwm-second-clr", 255, 20, 147):depend({val, true})

                        return {
                            type = mode,
                            style = style,
                            position = position,
                            colors = {first = first, second = second},
                        }
                    end),
                    viewmodel = self.hidden(group[1]:checkbox("Viewmodel"), function(val)
                        local options = group[1]:multiselect("\nvm-options", {"Follow Aimbot", "Fakeduck Animation", "Hide Sliders"}):depend({val, true})
                        local in_scope = group[1]:checkbox("In scope"):depend({val, true})
                        local fov = group[1]:slider("FOV", 0, 120, 68, true, "", 1):depend({val, true})
                        local x = group[1]:slider("\nViewmodel X", -100, 100, 0, true, "u", 0.1, {[0] = "center"}):depend({val, true})
                        local y = group[1]:slider("\nViewmodel Y", -100, 100, 0, true, "u", 0.1, {[0] = "center"}):depend({val, true})
                        local z = group[1]:slider("\nViewmodel Z", -100, 100, 0, true, "u", 0.1, {[0] = "center"}):depend({val, true})
                        local pitch = group[1]:slider("Viewmodel Pitch", -90, 90, 0, true, "", 1, {[0] = "off"}):depend({val, true})
                        local yaw = group[1]:slider("Viewmodel Yaw", -90, 90, 0, true, "", 1, {[0] = "off"}):depend({val, true})
                        local roll = group[1]:slider("Viewmodel Roll", -180, 180, 0, true, "", 1, {[0] = "off"}):depend({val, true})

                        return {
                            options = options,
                            in_scope = in_scope,
                            fov = fov,
                            x = x,
                            y = y,
                            z = z,
                            pitch = pitch,
                            yaw = yaw,
                            roll = roll
                        }
                    end),
                    thirdperson = self.hidden(group[1]:checkbox("Third person"), function(val)
                        local collision = group[1]:checkbox("Collision"):depend({val, true})
                        local distance = group[1]:slider("Distance", 30, 200, 125, true, ""):depend({val, true})
                        return {
                            collision = collision,
                            distance = distance
                        }
                    end),
                    other = {}
                },
                misc = {
                    charge_fix = group[1]:checkbox("Charge fix"),
                    duck_speed = group[1]:checkbox("Duck speed"),
                    fast_fall = group[1]:checkbox("Fall discharge", 0x0),

                    space = self:space(group[1]),

                    fast_ladder = group[1]:checkbox("Ladder boost"),
                    buybot = self.hidden(group[1]:checkbox("Auto buy"), function(val)
                        return {
                            prim = group[1]:combobox("\nprim-bb", {"-", "SSG-08", "AWP", "SCAR-20/G3SG1"}):depend({val, true}),
                            second = group[1]:combobox("\nsecond-bb", {"-", "Duals", "P250", "Five-7/Tec-9", "Deagle/R8"}):depend({val, true}),
                            nades = group[1]:multiselect("\nnades-bb", {"Smoke", "Molotov", "HE"}):depend({val, true}),
                            other = group[1]:multiselect("\nother-bb", {"Kevlar", "Helmet", "Defuse Kit", "Taser"}):depend({val, true})
                        }
                    end),

                    clantag = group[3]:checkbox("Clan tag"),
                    trashtalk = self.hidden(group[3]:checkbox("Trashtalk"), function(val)
                        return {
                            mode = group[3]:multiselect("\ntrashtalk:mode", {"Kill", "Death"}):depend({val, true})
                        }
                    end),
                    aipeek = self.hidden(group[2]:checkbox("Intelligence Peek"), function(val)
                        return {
                            hotkey  = group[2]:hotkey("\nActivate", true):depend({val, true}),
                            render  = group[2]:checkbox("\nDraw peek zones", true):depend({val, true}),
                            mode    = group[2]:combobox("\nMode", {"Offensive", "Defensive"}):depend({val, true}),
                        }
                    end),

                    filter = group[3]:checkbox("Log filter"), -- @flag102

                    breaker = self.hidden(group[2]:checkbox("Anim break"), function(val)
                        local mode = group[2]:combobox("\nbreaker:mode", {"Off", "Static", "Jitter", "Earthquake", "Moonwalk"})
                        local submode = group[2]:multiselect("\nbreaker:submode", {"Static legs in air", "Pitch zero land", "Moonwalk+"})
                        local jitter_min = group[2]:slider("\nJitter min", 0, 100, 0, true, "%"):depend({val, true})
                        local jitter_max = group[2]:slider("Jitter max", 0, 100, 100, true, "%"):depend({val, true})

                        return {
                            mode = mode:depend({val, true}),
                            submode = submode:depend({val, true}),
                            jitter_min = jitter_min,
                            jitter_max = jitter_max,
                        }
                    end)
                }
            },
            antiaim = antiaim_enabled and {
                mode = group[1]:combobox("Mode", {"Settings", "Builder"}),
                settings_category = group[1]:combobox("Settings tab", {
                    iconize_option("General"),
                    iconize_option("Manuals"),
                    iconize_option("Safety"),
                    iconize_option("Defensive")
                }),
                label = group[1]:label(" "),
                label2 = group[1]:label(" "),
                condition = group[1]:combobox("State", antiaim_cond),
                label1 = group[1]:label(" "),
                targets = group[1]:combobox("Base yaw", {"Local view", "At targets"}),
                features = group[1]:multiselect("Options", {"Safe head", "Avoid Backstab"}),
                override_spinner = group[1]:multiselect("Spinner override", {"Warmup", "No enemies"}),
                safe_head = group[1]:multiselect("Safe head", {"Knife on Air + C", "Taser on Air + C"}),
                avoid_slider = group[1]:slider("Avoid Backstab distance", 0, 1000, 0, true, "", 1),
                anti_brute = group[1]:checkbox("Anti-brute"),
                anti_brute_triggers = group[1]:multiselect("Anti-bruteforce triggers", {"On miss", "On damage"}),
                anti_brute_range = group[1]:slider("Anti-bruteforce range", 0, 90, 35, true, "°"),
                anti_brute_stages = group[1]:slider("Anti-bruteforce stages", 2, 6, 4, true, "x"),
                anti_brute_cooldown = group[1]:slider("Anti-bruteforce cooldown", 1, 20, 6, true, "t"),
                defensive_aa = group[1]:checkbox("Defensive"),
                defensive_mode = group[1]:multiselect("- Mode", {"On Shot Anti Aim", "Double Tap"}),
                defensive_state_select = group[1]:combobox("- Edit State", {"Air", "Air Crouch", "Standing", "Moving", "Slow Walk", "Crouched", "On Peek"}),
                defensive_states = (function()
                    local states = {}
                    for _, s in ipairs({"Air", "Air Crouch", "Standing", "Moving", "Slow Walk", "Crouched", "On Peek"}) do
                        states[s] = {
                            enabled = group[1]:checkbox("  " .. s),
                            pitch = group[1]:combobox("  Pitch" .. s, {"Default", "Zero", "Up", "Up Switch", "Down Switch", "Random"}),
                            yaw   = group[1]:combobox("  Yaw" .. s, {"Default", "Sideways", "Forward", "Spinbot", "3-Way", "5-Way", "X-Way", "Freeze-Inverter", "Flick", "Random"}),
                            flick_speed = group[1]:slider("  Flick Tick", 1, 16, 2, true, "t", 1, {[1] = "Every tick"}),
                        }
                    end
                    return states
                end)(),
                direction = group[1]:multiselect("Yaw directions", {"Freestand", "Manuals"}),
                freestand_bind = group[1]:hotkey("Freestand"),
                manual_left = group[1]:hotkey("Manual Left"),
                manual_right = group[1]:hotkey("Manual Right"),
                manual_forward = group[1]:hotkey("Manual Forward"),
                manual_reset = group[1]:hotkey("Manual Reset"),
             } or nil,
        }

        if antiaim_enabled and menu.antiaim then
            menu.antiaim.builder = {}
            for i, cond in ipairs(antiaim_cond) do
                local item = {
                    enable = group[1]:checkbox("Enable " .. cond),
                    yaw_mode = group[1]:slider("Yaw Mode", 0, 1, 0, true, "", 1, {[0] = "Offset", [1] = "L/R"}),
                    label = group[1]:label(" "),
                    offset = group[1]:slider("Offset", -180, 180, 0, true, "", 1),
                    yaw_left = group[1]:slider("Left", -180, 180, 0, true, "", 1),
                    yaw_right = group[1]:slider("Right", -180, 180, 0, true, "", 1),
                    mod = group[1]:combobox("Jitter Type", {"Off", "Offset", "Center", "Random", "Skitter"}),
                    mod_dm = group[1]:slider("Jitter Amount", -180, 180, 0, true, "", 1),
                    body = group[1]:combobox("Body Yaw", {"Off", "Static", "Jitter", "Opposite", "Adaptive"}),
                    body_slider = group[1]:slider("Body Yaw Amount", -180, 180, 0, true, "", 1),
                    delay = group[1]:slider("Delay", 1, 10, 1, true, "t", 1, {[1] = "Disabled"}),
                    random = group[1]:slider("Randomization", 0, 100, 0, true, "%", 1, {[0] = "Disabled"}),
                }
                menu.antiaim.builder[i] = item

                local tab_cond = {menu.antiaim.condition, cond}
                local mode_builder = {menu.antiaim.mode, "Builder"}
                local tab_dep = {menu.tab, "Anti-aim"}
                local cond_check = {menu.antiaim.condition, function() return (i ~= 1) end}
                local cnd_en = {item.enable, function() return (i == 1) or item.enable:get() end}
                local offset = {item.yaw_mode, function() return item.yaw_mode:get() == 0 end}
                local lr = {item.yaw_mode, function() return item.yaw_mode:get() == 1 end}
                local mod = {item.mod, function() return item.mod:get() ~= "Off" end}
                local body = {item.body, function() return item.body:get() == "Static" end}
                local delay = {item.body, function() return item.body:get() == "Jitter" end}

                item.enable:depend(tab_cond, tab_dep, cond_check, mode_builder)
                item.yaw_mode:depend(tab_cond, tab_dep, cnd_en, mode_builder)
                item.label:depend(tab_cond, tab_dep, cnd_en, mode_builder)
                item.offset:depend(tab_cond, tab_dep, cnd_en, offset, mode_builder)
                item.yaw_left:depend(tab_cond, tab_dep, cnd_en, lr, mode_builder)
                item.yaw_right:depend(tab_cond, tab_dep, cnd_en, lr, mode_builder)
                item.mod:depend(tab_cond, tab_dep, cnd_en, mode_builder)
                item.mod_dm:depend(tab_cond, tab_dep, cnd_en, mod, mode_builder)
                item.body:depend(tab_cond, tab_dep, cnd_en, mode_builder)
                item.body_slider:depend(tab_cond, tab_dep, cnd_en, body, mode_builder)
                item.delay:depend(tab_cond, tab_dep, cnd_en, delay, mode_builder)
                item.random:depend(tab_cond, tab_dep, cnd_en, mode_builder)
            end

            local tab_dep = {menu.tab, "Anti-aim"}
            local settings_dep = {menu.antiaim.mode, "Settings"}
            local settings_general = {menu.antiaim.settings_category, iconize_option("General")}
            local settings_manuals = {menu.antiaim.settings_category, iconize_option("Manuals")}
            local settings_safety = {menu.antiaim.settings_category, iconize_option("Safety")}
            local settings_defensive = {menu.antiaim.settings_category, iconize_option("Defensive")}

            menu.antiaim.condition:depend(tab_dep, {menu.antiaim.mode, "Builder"})
            menu.antiaim.label:depend(tab_dep, {menu.antiaim.mode, "Builder"})
            menu.antiaim.label1:depend(tab_dep, {menu.antiaim.mode, "Builder"})
            menu.antiaim.settings_category:depend(tab_dep, settings_dep)
            menu.antiaim.label2:depend(tab_dep, settings_dep, settings_general)
            menu.antiaim.targets:depend(tab_dep, settings_dep, settings_general)
            menu.antiaim.override_spinner:depend(tab_dep, settings_dep, settings_general)
            menu.antiaim.direction:depend(tab_dep, settings_dep, settings_manuals)
            menu.antiaim.freestand_bind:depend(tab_dep, settings_dep, settings_manuals, {menu.antiaim.direction, "Freestand"})
            menu.antiaim.manual_left:depend(tab_dep, settings_dep, settings_manuals, {menu.antiaim.direction, "Manuals"})
            menu.antiaim.manual_right:depend(tab_dep, settings_dep, settings_manuals, {menu.antiaim.direction, "Manuals"})
            menu.antiaim.manual_forward:depend(tab_dep, settings_dep, settings_manuals, {menu.antiaim.direction, "Manuals"})
            menu.antiaim.manual_reset:depend(tab_dep, settings_dep, settings_manuals, {menu.antiaim.direction, "Manuals"})
            menu.antiaim.features:depend(tab_dep, settings_dep, settings_safety)
            menu.antiaim.safe_head:depend(tab_dep, settings_dep, settings_safety, {menu.antiaim.features, "Safe head"})
            menu.antiaim.avoid_slider:depend(tab_dep, settings_dep, settings_safety, {menu.antiaim.features, "Avoid Backstab"})
            menu.antiaim.anti_brute:depend(tab_dep, settings_dep, settings_safety)
            menu.antiaim.anti_brute_triggers:depend(tab_dep, settings_dep, settings_safety, {menu.antiaim.anti_brute, true})
            menu.antiaim.anti_brute_range:depend(tab_dep, settings_dep, settings_safety, {menu.antiaim.anti_brute, true})
            menu.antiaim.anti_brute_stages:depend(tab_dep, settings_dep, settings_safety, {menu.antiaim.anti_brute, true})
            menu.antiaim.anti_brute_cooldown:depend(tab_dep, settings_dep, settings_safety, {menu.antiaim.anti_brute, true})
            menu.antiaim.defensive_aa:depend(tab_dep, settings_dep, settings_defensive)
            menu.antiaim.defensive_mode:depend(tab_dep, settings_dep, settings_defensive, {menu.antiaim.defensive_aa, true})
            menu.antiaim.defensive_state_select:depend(tab_dep, settings_dep, settings_defensive, {menu.antiaim.defensive_aa, true})
            if menu.antiaim.defensive_states then
                local def_states = {"Air", "Air Crouch", "Standing", "Moving", "Slow Walk", "Crouched", "On Peek"}
                for _, s in ipairs(def_states) do
                    local st = menu.antiaim.defensive_states[s]
                    if st then
                        local state_dep = {menu.antiaim.defensive_state_select, s}
                        st.enabled:depend(tab_dep, settings_dep, settings_defensive, {menu.antiaim.defensive_aa, true}, state_dep)
                        st.pitch:depend(tab_dep, settings_dep, settings_defensive, {menu.antiaim.defensive_aa, true}, state_dep, {st.enabled, true})
                        st.yaw:depend(tab_dep, settings_dep, settings_defensive, {menu.antiaim.defensive_aa, true}, state_dep, {st.enabled, true})
                        if st.flick_speed then
                            st.flick_speed:depend(tab_dep, settings_dep, settings_defensive, {menu.antiaim.defensive_aa, true}, state_dep, {st.enabled, true}, {st.yaw, "Flick"})
                        end
                    end
                end
            end
         end

        if menu.other.visuals.custom_scope then
        local sc = menu.other.visuals.custom_scope
        if menu.other.visuals.scope_color    then menu.other.visuals.scope_color:depend({sc, true})    end
        if menu.other.visuals.scope_position then menu.other.visuals.scope_position:depend({sc, true}) end
        if menu.other.visuals.scope_offset   then menu.other.visuals.scope_offset:depend({sc, true})   end
        if menu.other.visuals.scope_speed    then menu.other.visuals.scope_speed:depend({sc, true})    end
        if menu.other.visuals.scope_invert   then menu.other.visuals.scope_invert:depend({sc, true})   end
        if menu.other.visuals.scope_exclude  then menu.other.visuals.scope_exclude:depend({sc, true})  end
    end

    pui.traverse({menu.other.visuals, menu.other.misc}, function(element, namet)
            element:depend({menu.other.tab, tabs.other[namet[1]]})
        end)

        if menu.ragebot and menu.ragebot.header then
            menu.ragebot.header:depend({menu.tab, "Ragebot"})
            menu.ragebot.predict:depend({menu.tab, "Ragebot"})
            menu.ragebot.predict_ind:depend({menu.tab, "Ragebot"})
            menu.ragebot.predict_color:depend({menu.tab, "Ragebot"}, {menu.ragebot.predict_ind, true})
            menu.ragebot.hideshots_fix:depend({menu.tab, "Ragebot"})
            menu.ragebot.hitchance_default:depend({menu.tab, "Ragebot"})
            menu.ragebot.hitchance_in_air:depend({menu.tab, "Ragebot"})
            menu.ragebot.hitchance_in_air_val:depend({menu.tab, "Ragebot"}, {menu.ragebot.hitchance_in_air, true})
            menu.ragebot.hitchance_override:depend({menu.tab, "Ragebot"})
            menu.ragebot.hitchance_override_key:depend({menu.tab, "Ragebot"})
            menu.ragebot.hitchance_indicator:depend({menu.tab, "Ragebot"})
            menu.ragebot.overnight_header:depend({menu.tab, "Ragebot"})
            menu.ragebot.overnight_body_yaw_fix:depend({menu.tab, "Ragebot"})
            menu.ragebot.overnight_lc_fix:depend({menu.tab, "Ragebot"})
            menu.ragebot.overnight_off_dt_hs:depend({menu.tab, "Ragebot"})
            menu.ragebot.overnight_unsafe_recharge:depend({menu.tab, "Ragebot"})
            menu.ragebot.overnight_fix_autostop:depend({menu.tab, "Ragebot"})
        end

        if antiaim_enabled and menu.antiaim then
        pui.traverse({menu.home, menu.ragebot, menu.antiaim, menu.other}, function(element, namet)
            element:depend({menu.tab, tabs.menu[namet[1]]})
        end)
        else
            pui.traverse({menu.home, menu.other}, function(element, namet)
                element:depend({menu.tab, tabs.menu[namet[1]]})
            end)
        end

    end
}

ifc:init()

local defensive_aa = {
    enabled = antiaim_enabled and menu.antiaim and menu.antiaim.defensive_aa or nil,
    mode    = antiaim_enabled and menu.antiaim and menu.antiaim.defensive_mode or nil,
    states  = antiaim_enabled and menu.antiaim and menu.antiaim.defensive_states or nil,
}


local antiaim_manual = nil
local yaw_direction = 0
local last_press_t_dir = 0
local to_jitter = false
local current_tickcount = 0
local defensive = {ticks = 0, active = false, mode = "idle", lagpeek = false}
local breaker = {
    defensive = 0,
    defensive_check = 0,
    cmd = 0,
    last_origin = nil,
    tp_samples = {},
    tp_sum = 0,
    tp_count = 0,
    tp_index = 1,
    tp_cap = 16
}

local anti_brute = {
    stage = 0,
    last_switch = 0
}

function anti_brute:enabled()
    return menu.antiaim and menu.antiaim.anti_brute and menu.antiaim.anti_brute:get()
end

function anti_brute:can_trigger()
    if not self:enabled() then
        return false
    end
    local cooldown = menu.antiaim.anti_brute_cooldown and menu.antiaim.anti_brute_cooldown:get() or 0
    return (globals.tickcount() - self.last_switch) >= cooldown
end

function anti_brute:trigger()
    if not self:can_trigger() then
        return
    end
    local stages = menu.antiaim.anti_brute_stages and menu.antiaim.anti_brute_stages:get() or 2
    stages = math.max(2, math.min(6, stages))
    self.last_switch = globals.tickcount()
    self.stage = (self.stage % stages) + 1
end

function anti_brute:trigger_miss()
    if menu.antiaim.anti_brute_triggers and menu.antiaim.anti_brute_triggers:get("On miss") then
        self:trigger()
    end
end

function anti_brute:trigger_damage()
    if menu.antiaim.anti_brute_triggers and menu.antiaim.anti_brute_triggers:get("On damage") then
        self:trigger()
    end
end

function anti_brute:get_offset()
    if not self:enabled() or self.stage == 0 then
        return 0
    end
    local range = menu.antiaim.anti_brute_range and menu.antiaim.anti_brute_range:get() or 0
    if range == 0 then
        return 0
    end
    local pattern = {1, -1, 0.5, -0.5, 1.5, -1.5}
    local idx = ((self.stage - 1) % #pattern) + 1
    return pattern[idx] * range
end

function anti_brute:reset()
    self.stage = 0
    self.last_switch = 0
end

local function breaker_reset()
    breaker.defensive = 0
    breaker.defensive_check = 0
    breaker.cmd = 0
    breaker.last_origin = nil
    breaker.tp_samples = {}
    breaker.tp_sum = 0
    breaker.tp_count = 0
    breaker.tp_index = 1
    defensive.ticks = 0
    defensive.active = false
    defensive.mode = "idle"
    defensive.lagpeek = false
    if anti_brute then
        anti_brute:reset()
    end
end

local function breaker_push_tp(value)
    local idx = breaker.tp_index
    local old = breaker.tp_samples[idx] or 0
    breaker.tp_samples[idx] = value
    breaker.tp_sum = breaker.tp_sum - old + value

    if breaker.tp_count < breaker.tp_cap then
        breaker.tp_count = breaker.tp_count + 1
    end

    breaker.tp_index = (idx % breaker.tp_cap) + 1
end

local function breaker_avg_tp()
    if breaker.tp_count <= 0 then
        return 0
    end
    return breaker.tp_sum / breaker.tp_count
end

local state_to_index = {
    ["Global"] = 1,
    ["Stand"] = 2,
    ["Walk"] = 3,
    ["Run"] = 4,
    ["Air"] = 5,
    ["Air+C"] = 6,
    ["Crouch"] = 7,
    ["Crouch+Move"] = 8,
    ["Freestand"] = 9
}

local function normalize_yaw(angle)
    angle = angle % 360
    if angle > 180 then
        angle = angle - 360
    end
    return angle
end

local function get_local_body_yaw()
    local lp = entity.get_local_player()
    if not lp then
        return 0
    end
    local animstate = entity.get_animstate(lp)
    if not animstate then
        return 0
    end
    local eye_yaw = animstate.eye_angles_y or 0
    local goal_feet = animstate.goal_feet_yaw or 0
    return normalize_yaw(eye_yaw - goal_feet)
end

local function clamp_yaw(value)
    return math.max(-180, math.min(180, tonumber(value) or 0))
end

local function random_between(min_value, max_value)
    local min_v = math.floor(math.min(min_value, max_value))
    local max_v = math.floor(math.max(min_value, max_value))
    if min_v == max_v then
        return min_v
    end
    return math.random(min_v, max_v)
end

local function player_state(cmd)
    local lp = entity.get_local_player()
    if lp == nil then
        return "Global"
    end

    local vx, vy = entity.get_prop(lp, "m_vecVelocity")
    local flags = entity.get_prop(lp, "m_fFlags")
    local velocity = math.sqrt((vx or 0) ^ 2 + (vy or 0) ^ 2)
    local groundcheck = bit.band(flags or 0, 1) == 1
    local jumpcheck = bit.band(flags or 0, 1) == 0 or cmd.in_jump == 1
    local ducked = (entity.get_prop(lp, "m_flDuckAmount") or 0) > 0.7
    local duckcheck = ducked or refs.rage.duck[1]:get()
    local slowwalk_key = refs.aa.other.slow[1]:get() and refs.aa.other.slow[1]:get_hotkey()
    local freestand = refs.aa.angles.freestand:get() and refs.aa.angles.freestand:get_hotkey()

    if groundcheck and freestand then
        return "Freestand"
    elseif jumpcheck and duckcheck then
        return "Air+C"
    elseif jumpcheck then
        return "Air"
    elseif duckcheck and velocity > 10 then
        return "Crouch+Move"
    elseif duckcheck and velocity < 10 then
        return "Crouch"
    elseif groundcheck and slowwalk_key and velocity > 10 then
        return "Walk"
    elseif groundcheck and velocity > 5 then
        return "Run"
    elseif groundcheck and velocity < 5 then
        return "Stand"
    end

    return "Global"
end

local function randomize_value(original_value, percent)
    local value = tonumber(original_value) or 0
    local pct = math.max(0, tonumber(percent) or 0)
    if pct == 0 then return value end
    local spread = math.abs(value) * pct * 0.01
    -- улучшенная рандомизация: нелинейное распределение через двойной сэмпл
    local r1 = random_between(-spread, spread)
    local r2 = random_between(-spread * 0.5, spread * 0.5)
    local noise = (r1 + r2) * 0.5
    -- дополнительный микро-джиттер для непредсказуемости
    local micro = client.random_float(-math.max(1, spread * 0.1), math.max(1, spread * 0.1))
    return value + noise + micro
end

local defensive_exploit = {
    shift = false,
    defensive_tk = 0
}

local defensive_lp = {
    packets = 0,
    choking = 1
}

local defensive_3_way = {90, 180, -90, 180, 90}
local defensive_5_way = {90, 135, 180, 225, 270}
local defensive_x_way = {90, -90, 180, 0, 90, -90}
local defensive_freeze_invert_last = 0
local defensive_flick_side = 1
local defensive_flick_tick = 0
local defensive_get_client_entity = vtable_bind("client.dll", "VClientEntityList003", 3, "void*(__thiscall*)(void*, int)")

local function defensive_real_latency()
    if client.real_latency then
        local ok, value = pcall(client.real_latency)
        if ok and type(value) == "number" then
            return value
        end
    end
    local value = client.latency and client.latency() or 0
    return (type(value) == "number" and value * 0.5) or 0
end

local function defensive_update_shift(cmd)
    local lp = entity.get_local_player()
    if not lp then
        return
    end
    local tickcount = globals.tickcount()
    local tickbase = entity.get_prop(lp, "m_nTickBase") or 0
    defensive_exploit.shift = tickcount > tickbase

    if cmd and cmd.chokedcommands == 0 then
        defensive_lp.packets = defensive_lp.packets + 1
        defensive_lp.choking = defensive_lp.choking * -1
    end
end

local function defensive_update_defensive_tk()
    local lp = entity.get_local_player()
    if not lp or not entity.is_alive(lp) then
        return
    end
    if not defensive_get_client_entity then
        return
    end
    local ent_ptr = defensive_get_client_entity(lp)
    if not ent_ptr then
        return
    end
    local old_simtime = ffi.cast("float*", ffi.cast("uintptr_t", ent_ptr) + 0x26C)[0]
    local simtime = entity.get_prop(lp, "m_flSimulationTime")
    if old_simtime == nil or simtime == nil then
        return
    end
    local delta = old_simtime - simtime
    if delta > 0 then
        local latency = defensive_real_latency()
        defensive_exploit.defensive_tk = globals.tickcount() + toticks(delta - latency)
    end
end

local function defensive_get_statement(lp)
    if entity.in_air(lp) then
        local duck = (entity.get_prop(lp, "m_flDuckAmount") or 0)
        if duck > 0.3 then
            return "Air Crouch"
        end
        return "Air"
    end

    local ducked = (entity.get_prop(lp, "m_flDuckAmount") or 0) > 0.7
    if ducked then
        return "Crouched"
    end

    local vx, vy = entity.get_prop(lp, "m_vecVelocity")
    local velocity = math.sqrt((vx or 0) ^ 2 + (vy or 0) ^ 2)
    if velocity > (1.1 * 3.3) then
        local slowwalk = refs.aa.other.slow[1]:get() and refs.aa.other.slow[1]:get_hotkey()
        if slowwalk then
            return "Slow Walk"
        end
        return "Moving"
    end

    return "Standing"
end

local function defensive_hotkey_active(ref)
    if ref == nil then
        return false
    end
    if type(ref) == "table" then
        if ref.get_hotkey or ref.get then
            -- ok
        elseif ref[1] then
            ref = ref[1]
        end
    end
    if ref and ref.get_hotkey then
        return ref:get_hotkey()
    end
    if ref and ref.get then
        return ref:get()
    end
    return false
end

local defensive_modes = {
    ["On Shot Anti Aim"] = function()
        return defensive_hotkey_active(refs.aa.other.osaa[1])
    end,
    ["Double Tap"] = function()
        return defensive_hotkey_active(refs.rage.dotap.val[1])
    end
}

local function defensive_apply(cmd)
    if not (defensive_aa and defensive_aa.enabled and defensive_aa.enabled.get and defensive_aa.enabled:get()) then
        return nil
    end
    if not (defensive_aa.mode and defensive_aa.states) then
        return nil
    end

    local lp = entity.get_local_player()
    if lp == nil then return nil end

    local work_on_mode = false
    for _, mode in next, defensive_aa.mode:get() do
        if defensive_modes[mode] and defensive_modes[mode]() then
            work_on_mode = true
            break
        end
    end
    if not work_on_mode then return nil end

    -- определяем текущий стейт
    local lp_state = defensive_get_statement(lp)

    -- ищем настройки для текущего стейта
    local st = defensive_aa.states[lp_state]
    local on_peek = (lp_state == "On Peek")

    -- если стейт не включён — не применяем
    if not st or not st.enabled:get() then
        return nil
    end

    local weapon = entity.get_player_weapon(lp)
    if weapon == nil then return nil end
    local wpn_class = entity.get_classname(weapon) or ""
    if wpn_class == "CWeaponRevolver" then return nil end

    if not on_peek then
        cmd.force_defensive = true
    end

    local freestanding = menu.antiaim.direction:get("Freestand") and menu.antiaim.freestand_bind:get()
    local manual_yaw = yaw_direction ~= 0 and yaw_direction or nil
    local should_ignore = freestanding or (manual_yaw ~= nil)

    -- pitch
    local pitch_value, pitch_mode = 0, "Default"
    do
        local val = st.pitch:get()
        if val == "Zero" then
            pitch_value, pitch_mode = 0, "Custom"
        elseif val == "Up" then
            pitch_value, pitch_mode = 0, "Up"
        elseif val == "Up Switch" then
            pitch_value, pitch_mode = client.random_float(45, 60) * -1, "Custom"
        elseif val == "Down Switch" then
            pitch_value, pitch_mode = client.random_float(45, 60), "Custom"
        elseif val == "Random" then
            pitch_value, pitch_mode = client.random_float(-89, 89), "Custom"
        end
    end

    -- yaw
    local yaw_value, yaw_mode = 0, "180"
    do
        local val = st.yaw:get()
        if val == "Sideways" then
            yaw_value = defensive_lp.choking * 90 + client.random_float(-30, 30)
        elseif val == "Forward" then
            yaw_value = defensive_lp.choking * 180 + client.random_float(-30, 30)
        elseif val == "Spinbot" then
            yaw_value = -180 + (globals.tickcount() % 9) * 40 + client.random_float(-30, 30)
        elseif val == "3-Way" then
            yaw_value = defensive_3_way[defensive_lp.packets % 5 + 1] + client.random_float(-15, 15)
        elseif val == "5-Way" then
            yaw_value = defensive_5_way[defensive_lp.packets % 5 + 1] + client.random_float(-15, 15)
        elseif val == "X-Way" then
            local xi = defensive_lp.packets % #defensive_x_way + 1
            yaw_value = defensive_x_way[xi] + client.random_float(-20, 20)
        elseif val == "Freeze-Inverter" then
            local choking = cmd and cmd.chokedcommands or 0
            if choking > 0 then
                defensive_freeze_invert_last = defensive_freeze_invert_last == 0 and 1 or 0
            end
            yaw_value = defensive_freeze_invert_last == 0 and 90 or -90
        elseif val == "Flick" then
            local tc = globals.tickcount()
            local speed = st.flick_speed and st.flick_speed:get() or 2
            if tc ~= defensive_flick_tick then
                defensive_flick_tick = tc
                -- меняем сторону каждые speed тиков
                if tc % speed == 0 then
                    defensive_flick_side = defensive_flick_side == 1 and -1 or 1
                end
            end
            yaw_value = defensive_flick_side == 1 and 90 or -90
        elseif val == "Random" then
            yaw_value = clamp_yaw(normalize_yaw(math.random(-180, 180)))
        end
    end

    if should_ignore then return nil end

    return {
        pitch_mode  = pitch_mode,
        pitch_value = pitch_value,
        yaw_mode    = yaw_mode,
        yaw_value   = yaw_value,
    }
end

local function desyncside()
    if not entity.get_local_player() or not entity.is_alive(entity.get_local_player()) then
        return 1
    end
    local bodyyaw = (entity.get_prop(entity.get_local_player(), "m_flPoseParameter", 11) or 0) * 120 - 60
    return bodyyaw > 0 and -1 or 1
end

local function run_direction()
    antiaim_manual = nil

    if menu.antiaim.direction:get("Freestand") and menu.antiaim.freestand_bind:get() then
        refs.aa.angles.freestand.hotkey:override({"Always on", 0})
        refs.aa.angles.freestand:override(true)
    else
        refs.aa.angles.freestand:override(false)
    end

    if yaw_direction ~= 0 then
        refs.aa.angles.freestand:override(false)
    end

    if menu.antiaim.direction:get("Manuals") and menu.antiaim.manual_right:get() and last_press_t_dir + 0.2 < globals.curtime() then
        yaw_direction = yaw_direction == 90 and 0 or 90
        last_press_t_dir = globals.curtime()
    elseif menu.antiaim.direction:get("Manuals") and menu.antiaim.manual_left:get() and last_press_t_dir + 0.2 < globals.curtime() then
        yaw_direction = yaw_direction == -90 and 0 or -90
        last_press_t_dir = globals.curtime()
    elseif menu.antiaim.direction:get("Manuals") and menu.antiaim.manual_forward:get() and last_press_t_dir + 0.2 < globals.curtime() then
        yaw_direction = yaw_direction == 180 and 0 or 180
        last_press_t_dir = globals.curtime()
    elseif last_press_t_dir > globals.curtime() then
        last_press_t_dir = globals.curtime()
    end

    if not menu.antiaim.direction:get("Manuals") or (menu.antiaim.manual_reset:get() and last_press_t_dir + 0.2 < globals.curtime()) then
        yaw_direction = 0
        last_press_t_dir = 0
    end

    if yaw_direction ~= 0 then
        if yaw_direction == -90 then
            antiaim_manual = {deg = -90, name = "left"}
        elseif yaw_direction == 90 then
            antiaim_manual = {deg = 90, name = "right"}
        elseif yaw_direction == 180 then
            antiaim_manual = {deg = 180, name = "forward"}
        end
    end
end

local function anti_knife_dist(x1, y1, z1, x2, y2, z2)
    return math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2 + (z2 - z1) ^ 2)
end

local function are_enemies_dead()
    local me = entity.get_local_player()
    if not me then
        return false
    end

    local my_team = entity.get_prop(me, "m_iTeamNum")
    local player_resource = entity.get_player_resource()
    if not player_resource then
        return false
    end

    for i = 1, globals.maxplayers() do
        local is_connected = entity.get_prop(player_resource, "m_bConnected", i)
        if is_connected ~= 1 then
            goto continue
        end

        local player_team = entity.get_prop(player_resource, "m_iTeam", i)
        if i == me or player_team == my_team then
            goto continue
        end

        local is_alive = entity.get_prop(player_resource, "m_bAlive", i)
        if is_alive == 1 then
            return false
        end

        ::continue::
    end

    return true
end

local function aa_setup(cmd)
    if not (menu.antiaim and menu.antiaim.builder) then
        return
    end

    local lp = entity.get_local_player()
    if lp == nil then
        return
    end

    local state_name = player_state(cmd)
    local idx = state_to_index[state_name] or 1
    local builder = menu.antiaim.builder

    if idx > 1 and builder[idx].enable and not builder[idx].enable:get() then
        idx = 1
    end

    local b = builder[idx]

    run_direction()
    cmd.force_defensive = false
    local defensive_override = defensive_apply(cmd)

    refs.aa.enabled:override(true)
    refs.aa.angles.roll[1]:override(0)
    refs.aa.angles.pitch[1]:override("Default")

    if yaw_direction ~= 0 then
        refs.aa.angles.yaw_base[1]:override("Local view")
    else
        refs.aa.angles.yaw_base[1]:override(menu.antiaim.targets:get())
    end

    refs.aa.angles.body_free[1]:override(false)
    refs.aa.angles.yaw[1]:override("180")

    local delay_time = b.delay:get()
    local delay_active = b.body:get() == "Jitter" and (delay_time and delay_time > 1)
    if delay_active then
        if globals.tickcount() > current_tickcount + delay_time then
            if cmd and cmd.chokedcommands == 0 then
                to_jitter = not to_jitter
                current_tickcount = globals.tickcount()
            end
        elseif globals.tickcount() < current_tickcount then
            current_tickcount = globals.tickcount()
        end
    else
        to_jitter = false
        current_tickcount = globals.tickcount()
    end

    local yaw_amount = 0
    local yaw_offset = b.offset:get()
    local yaw_left = b.yaw_left:get()
    local yaw_right = b.yaw_right:get()
    local yawjitter = clamp_yaw(randomize_value(b.mod_dm:get(), b.random:get()))
    local function is_inverted()
        local by = get_local_body_yaw()
        if by == 0 then
            return desyncside() == -1
        end
        return by < 0
    end
    if delay_active then
        refs.aa.angles.body_yaw[1]:override("Static")
        refs.aa.angles.body_yaw[2]:override(to_jitter and 1 or -1)
        refs.aa.angles.yaw_jitter[1]:override("Off")
        refs.aa.angles.yaw_jitter[2]:override(0)

        local yaw_l, yaw_r
        if b.yaw_mode:get() == 1 then
            yaw_l = clamp_yaw(randomize_value(b.yaw_left:get(), b.random:get()))
            yaw_r = clamp_yaw(randomize_value(b.yaw_right:get(), b.random:get()))
        else
            yaw_l = clamp_yaw(b.offset:get())
            yaw_r = clamp_yaw(b.offset:get())
        end

        local mode = b.mod:get()
        local inverted = is_inverted()
        local cmd_seed = cmd.command_number or globals.tickcount()
        local dynamic_sign = ((globals.tickcount() + cmd_seed) % 2 == 0) and -1 or 1
        local anchor = inverted and yaw_r or yaw_l
        local swing = math.max(2, math.abs(yawjitter) * 0.5)

        if mode == "Center" then
            yaw_amount = anchor + dynamic_sign * swing
        elseif mode == "Offset" then
            yaw_amount = anchor + dynamic_sign * math.max(1, math.abs(yawjitter) * 0.25)
        elseif mode == "Random" then
            local spread = math.max(6, math.abs(yawjitter) + 8)
            yaw_amount = random_between(anchor - spread, anchor + spread)
        elseif mode == "Skitter" then
            local phase = (globals.tickcount() + cmd_seed) % 4
            local pattern = {-1, 0, 1, 0}
            yaw_amount = anchor + pattern[phase + 1] * math.max(4, math.abs(yawjitter) * 0.65)
        else
            yaw_amount = inverted and randomize_value(yaw_right, b.random:get()) or randomize_value(yaw_left, b.random:get())
        end
    else
        local body_mode = b.body:get()
        if body_mode == "Adaptive" then
            -- Adaptive: переключает body yaw в зависимости от скорости и позиции
            local inverted = is_inverted()
            local vx, vy = entity.get_prop(lp, "m_vecVelocity")
            local vel = math.sqrt((vx or 0)^2 + (vy or 0)^2)
            local cmd_seed = cmd.command_number or globals.tickcount()
            if vel > 50 then
                -- при движении — динамический jitter с учётом стороны
                refs.aa.angles.body_yaw[1]:override("Static")
                local sign = ((globals.tickcount() + cmd_seed) % 2 == 0) and 1 or -1
                refs.aa.angles.body_yaw[2]:override(sign * (inverted and -1 or 1))
            else
                -- стоя — противоположная сторона для максимального десинка
                refs.aa.angles.body_yaw[1]:override("Static")
                refs.aa.angles.body_yaw[2]:override(inverted and 1 or -1)
            end
        else
            refs.aa.angles.body_yaw[1]:override(body_mode)
            refs.aa.angles.body_yaw[2]:override(body_mode == "Jitter" and 1 or b.body_slider:get())
        end
        refs.aa.angles.yaw_jitter[1]:override(b.mod:get())
        refs.aa.angles.yaw_jitter[2]:override(math.clamp(yawjitter, -180, 180))
        if b.yaw_mode:get() == 1 then
            local inverted = is_inverted()
            yaw_amount = inverted and randomize_value(yaw_right, b.random:get()) or randomize_value(yaw_left, b.random:get())
        else
            yaw_amount = yaw_offset
        end
    end

    yaw_amount = clamp_yaw(normalize_yaw(yaw_amount))

    local final_yaw = yaw_direction == 0 and clamp_yaw(yaw_amount) or yaw_direction
    local brute_offset = anti_brute:get_offset()
    if brute_offset ~= 0 and yaw_direction == 0 then
        final_yaw = clamp_yaw(normalize_yaw(final_yaw + brute_offset))
    end
    if defensive_override then
        if defensive_override.body_yaw ~= nil then
            refs.aa.angles.body_yaw[1]:override(defensive_override.body_yaw)
            refs.aa.angles.body_yaw[2]:override(defensive_override.body_yaw_offset or 0)
        end
        if defensive_override.yaw_value ~= nil then
            final_yaw = clamp_yaw(normalize_yaw(defensive_override.yaw_value))
        end
    end
    refs.aa.angles.yaw[1]:override("180")
    refs.aa.angles.yaw[2]:override(final_yaw)
    if defensive_override then
        local pmode = defensive_override.pitch_mode
        if pmode == "Custom" then
            refs.aa.angles.pitch[1]:override("Custom")
            refs.aa.angles.pitch[2]:override(math.clamp(defensive_override.pitch_value or 0, -89, 89))
        elseif pmode and pmode ~= "Default" then
            refs.aa.angles.pitch[1]:override(pmode)
        elseif pmode == "Default" then
            refs.aa.angles.pitch[1]:override("Default")
        end
    end

    if menu.antiaim.features:get("Safe head") then
        local flags = entity.get_prop(lp, "m_fFlags") or 0
        local jumpcheck = bit.band(flags, 1) == 0 or cmd.in_jump == 1
        local ducked = (entity.get_prop(lp, "m_flDuckAmount") or 0) > 0.7
        local lp_weapon = entity.get_player_weapon(lp)
        if lp_weapon ~= nil then
            if menu.antiaim.safe_head:get("Knife on Air + C") and jumpcheck and ducked and entity.get_classname(lp_weapon) == "CKnife" then
                refs.aa.angles.pitch[1]:override("Down")
                refs.aa.angles.yaw_jitter[1]:override("Off")
                refs.aa.angles.yaw[1]:override("180")
                refs.aa.angles.yaw[2]:override(14)
                refs.aa.angles.body_yaw[1]:override("Off")
            end
            if menu.antiaim.safe_head:get("Taser on Air + C") and jumpcheck and ducked and entity.get_classname(lp_weapon) == "CWeaponTaser" then
                refs.aa.angles.pitch[1]:override("Down")
                refs.aa.angles.yaw_jitter[1]:override("Off")
                refs.aa.angles.yaw[1]:override("180")
                refs.aa.angles.yaw[2]:override(14)
                refs.aa.angles.body_yaw[1]:override("Off")
            end
        end
    end

    if menu.antiaim.override_spinner then
        local selection = menu.antiaim.override_spinner:get() or {}
        local selected = {}
        for i = 1, #selection do
            selected[selection[i]] = true
        end

        local rules = entity.get_game_rules()
        local warmup_active = rules and entity.get_prop(rules, "m_bWarmupPeriod") == 1
        local should_spin = (warmup_active and selected["Warmup"]) or (are_enemies_dead() and selected["No enemies"])

        if should_spin then
            refs.aa.angles.pitch[1]:override("Custom")
            refs.aa.angles.pitch[2]:override(0)
            refs.aa.angles.yaw[1]:override("Spin")
            refs.aa.angles.yaw[2]:override(100)
            refs.aa.angles.yaw_jitter[1]:override("Off")
            refs.aa.angles.yaw_jitter[2]:override(0)
            refs.aa.angles.body_yaw[1]:override("Static")
            refs.aa.angles.body_yaw[2]:override(1)
            refs.aa.angles.body_free[1]:override(false)
            refs.aa.angles.edge_yaw:override(false)
        end
    end

    if menu.antiaim.features:get("Avoid Backstab") then
        local players = entity.get_players(true)
        local lp_x, lp_y, lp_z = entity.get_prop(lp, "m_vecOrigin")
        for i = 1, #players do
            local weapon = entity.get_player_weapon(players[i])
            if weapon and entity.get_classname(weapon) == "CKnife" then
                local ex, ey, ez = entity.get_prop(players[i], "m_vecOrigin")
                if anti_knife_dist(lp_x, lp_y, lp_z, ex, ey, ez) <= menu.antiaim.avoid_slider:get() then
                    refs.aa.angles.yaw[2]:override(180)
                    refs.aa.angles.yaw_base[1]:override("At targets")
                end
            end
        end
    end
end

callback.setup_command:set(defensive_update_shift)
callback.setup_command:set(aa_setup)
callback.predict_command:set(function(cmd)
    if not cmd or cmd.command_number ~= breaker.cmd then
        return
    end

    local lp = entity.get_local_player()
    if not lp or not entity.is_alive(lp) then
        breaker.defensive = 0
        breaker.defensive_check = 0
        breaker.cmd = 0
        defensive.ticks = 0
        defensive.active = false
        defensive.mode = "idle"
        return
    end

    local tickbase = entity.get_prop(lp, "m_nTickBase") or 0
    if breaker.defensive_check == 0 then
        breaker.defensive_check = tickbase
    end
    breaker.defensive = math.abs(tickbase - breaker.defensive_check)
    breaker.defensive_check = math.max(tickbase, breaker.defensive_check)
    breaker.cmd = 0

    defensive.ticks = breaker.defensive
    defensive.active = breaker.defensive >= 4
    defensive.mode = defensive.active and "defensive" or "idle"
end)
callback.run_command:set(function(cmd)
    if not cmd then
        return
    end

    local lp = entity.get_local_player()
    if lp and entity.is_alive(lp) and cmd.chokedcommands == 0 then
        local ox, oy, oz = entity.get_prop(lp, "m_vecOrigin")
        if ox and oy then
            if breaker.last_origin then
                local dx = ox - breaker.last_origin[1]
                local dy = oy - breaker.last_origin[2]
                breaker_push_tp(dx * dx + dy * dy)
            end
            breaker.last_origin = {ox, oy, oz or 0}
        end
    end

    breaker.cmd = cmd.command_number or 0
end)
callback.net_update_end:set(function()
    defensive_update_defensive_tk()
end)
callback.bullet_impact:set(function(e)
    if not (menu.other.visuals.tracer and menu.other.visuals.tracer:get()) then return end
    if client.userid_to_entindex(e.userid) ~= entity.get_local_player() then return end
    local lx, ly, lz = client.eye_position()
    tracer_queue[globals.tickcount()] = {lx, ly, lz, e.x, e.y, e.z, globals.curtime() + 1.5}
end)

callback.round_start:set(function()
    tracer_queue = {}
end)

callback.round_start:set(function()
    breaker_reset()
end)
callback.player_connect_full:set(function(event)
    local ent = event and client.userid_to_entindex(event.userid)
    if ent and ent == entity.get_local_player() then
        breaker_reset()
    end
end)
local last_track = 0
local tracked = 0

callback.player_hurt:set(function(event)
	if client.userid_to_entindex(event.userid) == game.me then
		last_track = globals.tickcount()
        if anti_brute then
            anti_brute:trigger_damage()
        end
	end
end)

callback.bullet_impact:set(function(event)
    if not game.alive or tracked == globals.tickcount() then
        return
    end

    local attacker = client.userid_to_entindex(event.userid)

    if not attacker or not entity.is_enemy(attacker) or entity.is_dormant(attacker) then
        return
    end

    local bullet = vector(event.x, event.y, event.z)
    local attack_v = vector(entity.get_origin(attacker))

    attack_v.z = attack_v.z + 64

    local distance = {}
    local players = entity.get_players()

    for i = 1, #players do
        local player = players[i]

        if not entity.is_enemy(player) then
            local vec3d = vector(entity.hitbox_position(player, 0))
            local to2d = math.closest_ray_point(vec3d, attack_v, bullet)

            distance[player == game.me and 0 or #distance + 1] = vec3d:dist(to2d)
        end
    end

    if distance[0] and (#distance == 0 or distance[0] < math.min(unpack(distance))) and distance[0] < 80 then
        data.statx.selfmiss = data.statx.selfmiss + 1
        tracked = globals.tickcount()
        if anti_brute then
            anti_brute:trigger_miss()
        end
    end
end)

extra.charge_fix = {
    work = function(self)
        local enable = refs.rage.dotap.val[1]:get() and refs.rage.dotap.val[1]:get_hotkey()

        if enable and not game.charged and entity.in_air(game.me) then 
            refs.rage.enabled:set(false)
        else
            refs.rage.enabled:set(true)
        end
    end,

    release = function(self)
        menu.other.misc.charge_fix:set_event("setup_command", guarded_event(self.work))
        menu.other.misc.charge_fix:set_callback(function(check)
            if check.value == false then 
                refs.rage.enabled:set(true)
            end
        end)
    end
}

extra.unlock_duck = {
    check = true,

    work = function(self, cmd)
        local speed = 1.01

        if game.velocity > 3.2 then
            return
        end

        if entity.in_duck(game.me) or refs.rage.duck[1]:get() then
            speed = speed * 2.94117647
        end
    
        self.check = self.check or false
    
        if self.check then
            cmd.sidemove = cmd.sidemove + speed
        else
            cmd.sidemove = cmd.sidemove - speed
        end

        self.check = not self.check
    end,

    release = function(self)
        menu.other.misc.duck_speed:set_event("setup_command", guarded_event(function(cmd) 
            self:work(cmd) 
        end))
    end
}

extra.fast_ladder = {
    work = function(self, cmd)
        local me = entity.get_local_player()
        if not me then
            return
        end
        local pitch = select(1, client.camera_angles())
        if entity.get_prop(me, "m_MoveType") == 9 then
            if cmd.in_jump == 1 then
                return
            end
            local key_w = client.key_state(0x57)
            local key_s = client.key_state(0x53)
            local key_a = client.key_state(0x41)
            local key_d = client.key_state(0x44)
            local forwardmove = (key_w and 1 or 0) + (key_s and -1 or 0)
            local sidemove = (key_d and 1 or 0) + (key_a and -1 or 0)
            cmd.yaw = math.floor(cmd.yaw + 0.5)
            cmd.roll = 0
            if forwardmove == 0 then
                if sidemove ~= 0 then
                    cmd.pitch = 89
                    cmd.yaw = cmd.yaw + 180
                    if sidemove < 0 then
                        cmd.in_moveleft = 0
                        cmd.in_moveright = 1
                    end
                    if sidemove > 0 then
                        cmd.in_moveleft = 1
                        cmd.in_moveright = 0
                    end
                end
            end
            if forwardmove > 0 then
                if pitch < 45 then
                    cmd.pitch = 89
                    cmd.in_moveright = 1
                    cmd.in_moveleft = 0
                    cmd.in_forward = 0
                    cmd.in_back = 1
                    if sidemove == 0 then
                        cmd.yaw = cmd.yaw + 90
                    end
                    if sidemove < 0 then
                        cmd.yaw = cmd.yaw + 150
                    end
                    if sidemove > 0 then
                        cmd.yaw = cmd.yaw + 30
                    end
                end
            end
            if forwardmove < 0 then
                cmd.pitch = 89
                cmd.in_moveleft = 1
                cmd.in_moveright = 0
                cmd.in_forward = 1
                cmd.in_back = 0
                if sidemove == 0 then
                    cmd.yaw = cmd.yaw + 90
                end
                if sidemove > 0 then
                    cmd.yaw = cmd.yaw + 150
                end
                if sidemove < 0 then
                    cmd.yaw = cmd.yaw + 30
                end
            end
        end
    end,

    release = function(self)
        menu.other.misc.fast_ladder:set_event("setup_command", guarded_event(function(cmd)
            self:work(cmd)
        end))
    end
}

extra.hideshots_fix = {
    apply = function(self, enabled)
        if refs.aa.fl.enabled[1] and refs.aa.fl.enabled[1].override then
            if enabled then
                refs.aa.fl.enabled[1]:override(false)
            else
                refs.aa.fl.enabled[1]:override()
            end
        end
    end,
    work = function(self)
        if not menu.ragebot.hideshots_fix:get() then
            self:apply(false)
            return
        end

        local is_fake_duck = refs.rage.duck[1]:get() and refs.rage.duck[1]:get_hotkey()
        local is_double_tap = refs.rage.dotap.val[1]:get() and refs.rage.dotap.val[1]:get_hotkey()
        local is_onshot = refs.aa.other.osaa[1]:get() and refs.aa.other.osaa[1]:get_hotkey()

        local should_update = is_onshot and not is_double_tap and not is_fake_duck
        self:apply(should_update)
    end,
    release = function(self)
        menu.ragebot.hideshots_fix:set_event("setup_command", guarded_event(function()
            self:work()
        end))
        menu.ragebot.hideshots_fix:set_event("paint_ui", guarded_event(function()
            self:apply(false)
        end))
        menu.ragebot.hideshots_fix:set_event("shutdown", guarded_event(function()
            self:apply(false)
        end, true))
    end
}

extra.hitchance = {
    work = function(self)
        if not hitchance_ref then
            return
        end

        local lp = game.me or entity.get_local_player()
        if not lp or not entity.is_alive(lp) then
            return
        end

        ui.set(hitchance_ref, menu.ragebot.hitchance_default:get())

        local flags = entity.get_prop(lp, "m_fFlags") or 0
        local in_air = bit.band(flags, 1) == 0
        if menu.ragebot.hitchance_in_air:get() and in_air then
            ui.set(hitchance_ref, menu.ragebot.hitchance_in_air_val:get())
        end

        if menu.ragebot.hitchance_override_key:get() then
            ui.set(hitchance_ref, menu.ragebot.hitchance_override:get())
        end
    end,

    release = function(self)
        if hitchance_ref ~= nil then
            menu.ragebot.hitchance_default:set_event("setup_command", guarded_event(function()
                self:work()
            end))
            menu.ragebot.hitchance_default:set_event("shutdown", guarded_event(function()
                ui.set_visible(hitchance_ref, true)
            end, true))
        end
    end
}

extra.ragebot_overnight = {
    lc_positions = {},
    lc_flag = false,
    lc_tickbase_max = 0,

    dt_forced = false,
    dt_prev = nil,

    recharge_override = false,
    recharge_prev = nil,

    autostop_forced = false,
    autostop_prev = nil,
    autostop_until = 0,

    body_target = nil,
    body_keys = {
        enable = {"Force body yaw", "Force Body Yaw"},
        value = {"Force body yaw value", "Force Body Yaw Value", "force body yaw value"}
    },

    plist_ready = function(self)
        return plist ~= nil and type(plist.set) == "function"
    end,

    plist_set = function(self, player, keys, value)
        if not player or not self:plist_ready() then
            return
        end
        for i = 1, #keys do
            pcall(plist.set, player, keys[i], value)
        end
    end,

    read_rage_enabled = function(self)
        if refs.rage.enabled and refs.rage.enabled.get then
            return refs.rage.enabled:get()
        end
        local ok, value = pcall(function()
            return refs.rage.enabled()
        end)
        return ok and value == true
    end,

    write_rage_enabled = function(self, state)
        if refs.rage.enabled and refs.rage.enabled.set then
            refs.rage.enabled:set(state == true)
        end
    end,

    overnight_reset_body_fix = function(self)
        if self.body_target then
            self:plist_set(self.body_target, self.body_keys.enable, false)
            self:plist_set(self.body_target, self.body_keys.value, 0)
            self.body_target = nil
        end
    end,

    overnight_get_local_velocity = function(self, lp)
        local vx, vy = entity.get_prop(lp, "m_vecVelocity")
        return math.sqrt((vx or 0) * (vx or 0) + (vy or 0) * (vy or 0))
    end,

    overnight_get_closest_enemy_distance = function(self, lp)
        local lx, ly, lz = entity.get_prop(lp, "m_vecOrigin")
        if not lx then
            return 9999
        end

        local closest = 9999
        for _, enemy in ipairs(entity.get_players(true) or {}) do
            if entity.is_alive(enemy) then
                local ex, ey = entity.get_prop(enemy, "m_vecOrigin")
                if ex then
                    local dx, dy = ex - lx, ey - ly
                    local dist = math.sqrt(dx * dx + dy * dy)
                    if dist < closest then
                        closest = dist
                    end
                end
            end
        end
        return closest
    end,

    overnight_track_lc = function(self, cmd, lp)
        if not lp or not entity.is_alive(lp) then
            self.lc_positions = {}
            self.lc_flag = false
            return false, 0
        end

        local now = vector(entity.get_origin(lp))
        local time_window = math.max(2, math.floor((1 / globals.tickinterval()) + 0.5))

        if cmd.chokedcommands == 0 then
            self.lc_positions[#self.lc_positions + 1] = now

            if #self.lc_positions >= time_window then
                local oldest = self.lc_positions[1]
                self.lc_flag = oldest ~= nil and (now - oldest):lengthsqr() > 4096
            end
        end

        while #self.lc_positions > time_window do
            table.remove(self.lc_positions, 1)
        end

        local tickbase = entity.get_prop(lp, "m_nTickBase") or 0
        if math.abs(tickbase - self.lc_tickbase_max) > 64 then
            self.lc_tickbase_max = tickbase
        end
        if tickbase > self.lc_tickbase_max then
            self.lc_tickbase_max = tickbase
        end

        local defensive_left = 0
        if self.lc_tickbase_max > tickbase then
            defensive_left = math.min(14, math.max(0, self.lc_tickbase_max - tickbase - 1))
        end

        return self.lc_flag, defensive_left
    end,

    overnight_apply_body_yaw_fix = function(self)
        if not self.ref.body_yaw_fix:get() then
            self:overnight_reset_body_fix()
            return
        end

        if not self:plist_ready() then
            return
        end

        local target = client.current_threat()
        if not target or not entity.is_enemy(target) or not entity.is_alive(target) then
            self:overnight_reset_body_fix()
            return
        end

        if self.body_target and self.body_target ~= target then
            self:plist_set(self.body_target, self.body_keys.enable, false)
            self:plist_set(self.body_target, self.body_keys.value, 0)
        end

        local animstate = entity.get_animstate(target)
        local pitch, eye_yaw = entity.get_prop(target, "m_angEyeAngles")
        if not animstate or eye_yaw == nil then
            return
        end

        local goal_feet = animstate.goal_feet_yaw or eye_yaw
        local body_yaw = math.clamp(math.floor(normalize_yaw(eye_yaw - goal_feet)), -58, 58)

        self:plist_set(target, self.body_keys.enable, true)
        self:plist_set(target, self.body_keys.value, body_yaw)
        self.body_target = target
    end,

    overnight_apply_lagcomp_fix = function(self, cmd, lp)
        if not self.ref.lc_fix:get() then
            return
        end

        local lc, defensive_left = self:overnight_track_lc(cmd, lp)
        if lc or defensive_left > 0 then
            cmd.force_defensive = true
        end
    end,

    overnight_apply_off_dt_hs = function(self)
        if not self.ref.off_dt_hs:get() then
            if self.dt_forced then
                refs.rage.dotap.val[1]:set(self.dt_prev == true)
                self.dt_forced = false
                self.dt_prev = nil
            end
            return
        end

        local hs_active = refs.aa.other.osaa[1]:get() and refs.aa.other.osaa[1]:get_hotkey()
        if hs_active then
            if not self.dt_forced then
                self.dt_prev = refs.rage.dotap.val[1]:get()
                refs.rage.dotap.val[1]:set(false)
                self.dt_forced = true
            end
        elseif self.dt_forced then
            refs.rage.dotap.val[1]:set(self.dt_prev == true)
            self.dt_forced = false
            self.dt_prev = nil
        end
    end,

    overnight_apply_unsafe_recharge = function(self, lp)
        if not self.ref.unsafe_recharge:get() then
            if self.recharge_override then
                self:write_rage_enabled(self.recharge_prev == true)
                self.recharge_override = false
                self.recharge_prev = nil
            end
            return
        end

        if not lp or not entity.is_alive(lp) then
            return
        end

        local dt_active = refs.rage.dotap.val[1]:get() and refs.rage.dotap.val[1]:get_hotkey()
        local hs_active = refs.aa.other.osaa[1]:get() and refs.aa.other.osaa[1]:get_hotkey()
        local duck_active = refs.rage.duck[1]:get() and refs.rage.duck[1]:get_hotkey()

        local should_disable = (dt_active or hs_active) and not game.charged and not duck_active

        if should_disable then
            if not self.recharge_override then
                self.recharge_prev = self:read_rage_enabled()
                self:write_rage_enabled(false)
                self.recharge_override = true
            end
        elseif self.recharge_override then
            self:write_rage_enabled(self.recharge_prev == true)
            self.recharge_override = false
            self.recharge_prev = nil
        end
    end,

    overnight_apply_fix_autostop = function(self, lp)
        local quick_stop = quick_stop_ref and quick_stop_ref[1]
        if quick_stop == nil then
            return
        end

        if not self.ref.fix_autostop:get() then
            if self.autostop_forced then
                ui.set(quick_stop, self.autostop_prev == true)
                self.autostop_forced = false
                self.autostop_prev = nil
            end
            return
        end

        if not lp or not entity.is_alive(lp) then
            return
        end

        local velocity = self:overnight_get_local_velocity(lp)
        local distance = self:overnight_get_closest_enemy_distance(lp)

        if distance < 350 and velocity > 30 then
            self.autostop_until = globals.curtime() + 0.5
        end

        local need_force = globals.curtime() < self.autostop_until and velocity > 8
        if need_force then
            if not self.autostop_forced then
                self.autostop_prev = ui.get(quick_stop)
                self.autostop_forced = true
            end
            ui.set(quick_stop, true)
        elseif self.autostop_forced then
            ui.set(quick_stop, self.autostop_prev == true)
            self.autostop_forced = false
            self.autostop_prev = nil
        end
    end,

    on_setup_command = function(self, cmd)
        local lp = entity.get_local_player()
        self:overnight_apply_lagcomp_fix(cmd, lp)
        self:overnight_apply_off_dt_hs()
        self:overnight_apply_unsafe_recharge(lp)
        self:overnight_apply_fix_autostop(lp)
    end,

    on_net_update_end = function(self)
        self:overnight_apply_body_yaw_fix()
    end,

    on_shutdown = function(self)
        self:overnight_reset_body_fix()
        if self.dt_forced then
            refs.rage.dotap.val[1]:set(self.dt_prev == true)
            self.dt_forced = false
            self.dt_prev = nil
        end
        if self.recharge_override then
            self:write_rage_enabled(self.recharge_prev == true)
            self.recharge_override = false
            self.recharge_prev = nil
        end
        local quick_stop = quick_stop_ref and quick_stop_ref[1]
        if quick_stop and self.autostop_forced then
            ui.set(quick_stop, self.autostop_prev == true)
            self.autostop_forced = false
            self.autostop_prev = nil
        end
    end,

    release = function(self)
        self.ref = {
            body_yaw_fix = menu.ragebot.overnight_body_yaw_fix,
            lc_fix = menu.ragebot.overnight_lc_fix,
            off_dt_hs = menu.ragebot.overnight_off_dt_hs,
            unsafe_recharge = menu.ragebot.overnight_unsafe_recharge,
            fix_autostop = menu.ragebot.overnight_fix_autostop
        }
    end
}


extra.ragebot_helpers = {
    work = function(self, cmd)
        -- Auto peek helper removed
        -- Resolver helper removed
    end,

    release = function(self)
        -- only helpers left are disabled/removed
    end
}

extra.auto_buy = {
    commands = {
        ["-"] = "",
        ["AWP"] = "buy awp",
        ["SCAR-20/G3SG1"] = "buy scar20",
        ["SSG-08"] = "buy ssg08",
        ["Five-7/Tec-9"] = "buy tec9",
        ["P250"] = "buy p250",
        ["Deagle/R8"] = "buy deagle",
        ["Duals"] = "buy elite",
        ["HE"] = "buy hegrenade",
        ["Molotov"] = "buy molotov",
        ["Smoke"] = "buy smokegrenade",
        ["Kevlar"] = "buy vest",
        ["Helmet"] = "buy vesthelm",
        ["Taser"] = "buy taser",
        ["Defuse Kit"] = "buy defuser"
    },

    work = function(self)
        local ref = self.ref

        for _, item in ipairs({ref.prim, ref.second}) do
            local cmd = self.commands[item:get()]
            if cmd and cmd ~= "" then
                client.exec(cmd)
            end
        end

        for _, group in ipairs({ref.nades, ref.other}) do
            for _, name in ipairs(group:get()) do
                local cmd = self.commands[name]
                if cmd and cmd ~= "" then
                    client.exec(cmd)
                end
            end
        end
    end,

    release = function(self)
        self.ref = menu.other.misc.buybot

        self.ref.val:set_event("round_prestart", guarded_event(function()
            if self.ref.val:get() then
                self:work()
            end
        end))
    end
}

extra.animate_zoom = {
    ref = menu.other.visuals.zoom,
    value = 0,

    work = function(self, player) -- fov / speed
        self.value = animate.lerp(self.value, game.scope.open and 1 or 0, self.ref.speed:get())
        local fov = refs.misc.fov:get() - self.ref.fov:get() * self.value

        if self.value > 0 then 
            player.fov = fov
        end
    end,

    release = function(self)
        self.ref.val:set_event("override_view", guarded_event(function(player)
            self:work(player)
        end))
        self.ref.val:set_callback(function(check)
            refs.misc.fovscope:set_enabled(not check.value)

            if check.value then 
                refs.misc.fovscope:override(0)
            else 
                refs.misc.fovscope:override()
            end
        end)
    end
}

extra.aspect_ratio = {
    last = nil,

    apply = function(self, mult)
        local screen_w, screen_h = client.screen_size()
        if not screen_w or not screen_h then
            return
        end

        local aspectratio_value = 0
        if mult and mult ~= 1 then
            aspectratio_value = (screen_w * mult) / screen_h
        end

        if self.last == aspectratio_value then
            return
        end

        self.last = aspectratio_value
        client.set_cvar("r_aspectratio", aspectratio_value)
    end,

    work = function(self)
        if not menu.other.visuals.aspect_ratio.val:get() then
            self:apply(1)
            return
        end

        local value = menu.other.visuals.aspect_ratio.value:get()
        local mult = 2 - (value * 0.01)
        self:apply(mult)
    end,

    release = function(self)
        menu.other.visuals.aspect_ratio.val:set_event("paint_ui", guarded_event(function()
            self:work()
        end))
        menu.other.visuals.aspect_ratio.val:set_event("shutdown", guarded_event(function()
            self:apply(1)
        end, true))
        menu.other.visuals.aspect_ratio.val:set_callback(function(check)
            if not check.value then
                self:apply(1)
            else
                self:work()
            end
        end, true)
        if menu.other.visuals.aspect_ratio.value and menu.other.visuals.aspect_ratio.value.set_callback then
            menu.other.visuals.aspect_ratio.value:set_callback(function()
                self:work()
            end, true)
        end
    end
}

extra.thirdperson = {
    apply = function(self)
        local ref = menu.other.visuals.thirdperson
        if not ref or not ref.val then
            return
        end

        if not ref.val:get() then
            return
        end

        local collision = ref.collision and ref.collision:get() or false
        local dist = ref.distance and ref.distance:get() or 125

        cvar.cam_collision:set_int(collision and 1 or 0)
        cvar.c_mindistance:set_int(dist)
        cvar.c_maxdistance:set_int(dist)
    end,

    reset = function(self)
        cvar.cam_collision:set_int(0)
    end,

    release = function(self)
        if not (menu.other.visuals and menu.other.visuals.thirdperson and menu.other.visuals.thirdperson.val) then
            return
        end

        menu.other.visuals.thirdperson.val:set_event("paint_ui", guarded_event(function()
            self:apply()
        end))
        menu.other.visuals.thirdperson.val:set_event("shutdown", guarded_event(function()
            self:reset()
        end, true))
        menu.other.visuals.thirdperson.val:set_callback(function(check)
            if not check.value then
                self:reset()
            else
                self:apply()
            end
        end, true)

        if menu.other.visuals.thirdperson.collision and menu.other.visuals.thirdperson.collision.set_callback then
            menu.other.visuals.thirdperson.collision:set_callback(function()
                self:apply()
            end, true)
        end
        if menu.other.visuals.thirdperson.distance and menu.other.visuals.thirdperson.distance.set_callback then
            menu.other.visuals.thirdperson.distance:set_callback(function()
                self:apply()
            end, true)
        end
    end
}

extra.fast_fall = {
    work = function(self, cmd)
        if not menu.other.misc.fast_fall:get_hotkey() then return end
        if game.charged and game.target and entity.flag(game.target, "HIT") then
            cmd.discharge_pending = true
            cmd.in_jump = 0
            cmd.in_duck = 1
            cmd.sidemove = 0
        end
    end,

    release = function(self)
        menu.other.misc.fast_fall:set_event("setup_command", guarded_event(function(cmd)
            self:work(cmd)
        end))
        menu.other.misc.fast_fall:set_callback(function(check)
            if check.value then 
                menu.other.misc.charge_fix:set_enabled(false)
                menu.other.misc.charge_fix:override(true)
            else
                menu.other.misc.charge_fix:set_enabled(true)
                menu.other.misc.charge_fix:override()
            end
        end)
    end
}

extra.clantag = {
    enable = false,
    list = {
        "",
        "p",
        "p1",
        "pri!",
        "pri#",
        "prior@",
        "priora&",
        "prioraс%",
        "prioraсl*",
        "prioraсlu^",
        "prioraсlub",
        "prioraсlub",
        "prioraсlub",
        "prioraсlu^",
        "prioraсl*",
        "prioraсl%",
        "prioraс!",
        "priora&",
        "prior@",
        "prio#",
        "pri!",
        "p1",
        "p",
        "",
        "",
    }, last = 0,

    work = function()
        local current = math.floor(globals.curtime() * 3) % #extra.clantag.list + 1
    
        if current == extra.clantag.last then
            return
        end

        extra.clantag.last = current

        client.set_clan_tag(extra.clantag.list[current])
        refs.misc.clantag:override(false)
        refs.misc.clantag:set_enabled(false)
    end,

    release = function(self)
        menu.other.misc.clantag:set_event("net_update_end", guarded_event(self.work))
        menu.other.misc.clantag:set_callback(function(check)
            if not check.value then 
                client.set_clan_tag()
                refs.misc.clantag:set_enabled(true)
                refs.misc.clantag:override()
            end
        end, true)
    end
}

extra.trashtalk = {
    phrases = {
        ["kill"] = {
            "ангельские хорни -> discord.gg/cpg3GxwUXq",
            "@𝚛𝚞𝚜𝚜𝚒𝚊𝚗𝚖𝚊𝚏𝚒𝚊𝚎𝚡𝚝𝚛𝚊",
            "1",
            "𝚖𝚊𝚔𝚎𝚒𝚝𝚠𝚘𝚛𝚔",
            "𝟸𝟺.𝟶𝟻.𝟸𝟷",
            "𝘎𝘖𝘋 𝘞𝘐𝘚𝘏 𝘗𝘙𝘐𝘖𝘙𝘈𝘊𝘓𝘜𝘉 $$$",
            "hood2hood ◣◢",
            "𝙮𝙤𝙪𝙩𝙪𝙗𝙚.𝙘𝙤𝙢/@𝙚𝙫𝙞𝙡𝙙𝙚𝙖𝙡𝙚𝙧𝙨",
            ".::КеМеРоВо::.",
            "𝕕𝕖𝕡𝕠𝕣𝕥𝕖𝕕 𝕥𝕠 𝕙𝕖𝕝𝕝",
            "Вᴇᴩхᴏʙный ᴄуд Г.Кᴇʍᴇᴩᴏʙᴏ",
            "who cars?",
            "1",
            "𝒑𝒓𝒊𝒐𝒓𝒂𝒄𝒍𝒖𝒃.𝒘𝒔 𝒐𝒘𝒏𝒊𝒏𝒈 𝒎𝒆 𝒂𝒏𝒅 𝒂𝒍𝒍",
            "@𝙞𝙙𝟭𝟰𝟵𝟰",
            "𝟭𝟬𝟬𝟬$ 𝑹𝑬𝑺𝑶𝑳𝑽𝑬𝑹 - 𝑪𝑳𝑶𝑺𝑬𝑫 𝑪𝑳𝑼𝑩",
            "𝙒𝘼𝙉𝙉𝘼 𝘽𝙀 𝙇𝙄𝙆𝙀 𝙈𝙀? 𝙂𝙀𝙏 @𝙋𝙍𝙄𝙊𝙍𝘼.𝘾𝙇𝙐𝘽",
            "@𝙞𝙙𝟭𝟰𝟵𝟰",
        }
    },
    send = function(self, mode, entit)
        local phrases_list = self.phrases[mode]
        if not phrases_list or #phrases_list == 0 then
            return
        end
        
        local phrase = math.random_string(phrases_list)
        local target_name = entity.get_player_name(entit) or "target"
        local formated = phrase:gsub("%%", target_name)
        
        client.exec("say " .. formated)
    end,

    work = function(e)
        local mode = menu.other.misc.trashtalk.mode
        local victim = client.userid_to_entindex(e.userid)
        local attacker = client.userid_to_entindex(e.attacker) 

        if mode:get("Kill") and attacker == game.me and victim ~= game.me then 
            extra.trashtalk:send("kill", victim)
        end
    end,

    release = function(self)
        menu.other.misc.trashtalk.val:set_event("player_death", guarded_event(function(e)
            self.work(e)
        end))
    end
}

extra.breaker = { -- @flag102
    ref = menu.other.misc.breaker,

    work = function(self)
        local movement = refs.aa.other.legs[1]
        local animation = {
            Static = function()
                movement:override("Always slide")
                entity.set_prop(game.me, "m_flPoseParameter", 0, 0)
            end,

            Jitter = function()
                movement:override("Never slide")

                local jmin = (self.ref.jitter_min and self.ref.jitter_min:get() or 0) * 0.01
                local jmax = (self.ref.jitter_max and self.ref.jitter_max:get() or 100) * 0.01
                local in_air = entity.in_air(game.me)

                if in_air then
                    -- в воздухе: jitter через anim layer 6
                    local anim = entity.get_animlayer(game.me, 6)
                    if anim then
                        anim.weight = client.random_float(jmin, jmax)
                        anim.cycle = globals.tickcount() % 2 == 0 and 0 or 1
                    end
                    entity.set_prop(game.me, "m_flPoseParameter", client.random_float(jmin, jmax), 6)
                else
                    -- на земле/при ходьбе
                    entity.set_prop(game.me, "m_flPoseParameter", client.random_float(jmin, jmax), 7)
                    entity.set_prop(game.me, "m_flPoseParameter", client.random_float(jmin, jmax), 6)
                end
            end,

            Moonwalk = function(add)
                movement:override("Never slide")
                entity.set_prop(game.me, "m_flPoseParameter", 0, 7)

                local left = entity.get_animlayer(game.me, 6)
                local right = entity.get_animlayer(game.me, 4)

                left.weight = 1
                right.weight = 0

                if add:get("Moonwalk+") then 
                    local cycle = globals.realtime() * 0.7 % 2

                    if cycle > 1 then
                        cycle = 1 - (cycle - 1)
                    end

                    left.cycle = cycle
                end
            end,

            Earthquake = function()
                local anim = entity.get_animlayer(game.me, 12)

                anim.weight = client.random_float(0, 2.5)
            end
        }

        if game.alive then 
            local add = self.ref.submode

            if self.ref.mode.value ~= "Off" then 
                animation[self.ref.mode.value](add)
            end

            if add:get("Static legs in air") then 
                entity.set_prop(game.me, "m_flPoseParameter", 1, 6)
            end

            local animstate = entity.get_animstate(game.me)
            if add:get("Pitch zero land") and animstate.hit_in_ground_animation then 
                entity.set_prop(game.me, "m_flPoseParameter", 0.5, 12)
            end
        end
    end,

    release = function(self)
        self.ref.val:set_event("pre_render", guarded_event(function()
            self:work()
        end))
    end
}

extra.filter = {
    work = function(check)
        cvar.con_filter_enable:set_int(check.value and 2 or 0)
        cvar.con_filter_text:set_string(check.value and "PrioraClub" or "")
    end,

    release = function(self)
        menu.other.misc.filter:set_callback(self.work, true)
    end
}



-- ============================================================
-- INTELLIGENCE PEEK (ported from oxyshit)
-- ============================================================
local aipeek_utils = {}

aipeek_utils.extend_vector = function(v, dist, ang)
    local rad = ang * math.pi / 180
    return vector(v.x + math.cos(rad) * dist, v.y + math.sin(rad) * dist, v.z)
end

aipeek_utils.set_movement = function(cmd, target_pos, me)
    local ang = vector(vector(entity.get_origin(me)):to(target_pos):angles()).y
    cmd.in_forward   = 1
    cmd.in_back      = 0
    cmd.in_moveleft  = 0
    cmd.in_moveright = 0
    cmd.in_speed     = 0
    cmd.forwardmove  = 800
    cmd.sidemove     = 0
    cmd.move_yaw     = ang
end

local aipeek_state = {
    active       = false,
    moving_out   = false,
    returning    = false,
    shot_done    = false,
    retreat      = false,
    middle_pos   = vector(),
    positions    = {},
    active_idx   = 0,
    last_ret_tick = 0,
}

local function aipeek_skip(ent)
    if entity.get_classname(ent) == "CCSPlayer" and entity.is_enemy(ent) then
        return false
    end
    return true
end

local function aipeek_handle_point(base, prev, angle, dist, step, view_off, mins, maxs, height)
    local origin = prev and (prev - vector(0,0,step)) or base
    local extended = aipeek_utils.extend_vector(origin, dist, angle)
    local hull_down = client.trace_hull and client.trace_hull(
        origin.x, origin.y, origin.z,
        origin.x, origin.y, origin.z + height,
        mins.x, mins.y, mins.z, maxs.x, maxs.y, maxs.z
    )
    if not hull_down then return false end
    local hull_side = client.trace_hull and client.trace_hull(
        origin.x, origin.y, origin.z,
        extended.x, extended.y, origin.z,
        mins.x, mins.y, mins.z, maxs.x, maxs.y, maxs.z
    )
    if not hull_side then return false end
    if vector(extended):dist2d(vector(hull_side)) < dist * 0.97 then return false end
    return vector(hull_side)
end

local function aipeek_setup_points(me, mid, target_ang, num_pts, step_dist)
    local view_off = vector(entity.get_prop(me, "m_vecViewOffset"))
    local mins     = vector(entity.get_prop(me, "m_vecMins"))
    local maxs     = vector(entity.get_prop(me, "m_vecMaxs"))
    aipeek_state.positions[0] = mid
    for i = 1, num_pts do
        local ang  = i % 2 == 0 and target_ang - 90 or target_ang + 90
        local prev = aipeek_state.positions[i <= 2 and 0 or i - 2]
        if not prev then break end
        local pt = aipeek_handle_point(mid, prev, ang, step_dist, i, view_off, mins, maxs, 18)
        if not pt or (prev and math.abs(prev.z - pt.z) > 18) then
            for j = i, num_pts, 2 do aipeek_state.positions[j] = false end
            break
        end
        aipeek_state.positions[i] = pt
    end
end

local function aipeek_can_fire(me)
    local wpn = entity.get_player_weapon(me)
    if not wpn then return false end
    local na  = entity.get_prop(me, "m_flNextAttack") or 0
    local npa = entity.get_prop(wpn, "m_flNextPrimaryAttack") or 0
    local clip = entity.get_prop(wpn, "m_iClip1") or 0
    return math.max(na, npa) <= globals.curtime() and clip > 0
end

local function aipeek_trace_enemy(positions, me, enemy, hitboxes)
    if not enemy then return nil, 0 end
    local min_dmg = refs.rage and refs.rage.damage and refs.rage.damage.val and refs.rage.damage.val[1]:get() or 1
    local hp = entity.get_prop(enemy, "m_iHealth") or 100
    for i = 1, #positions do
        local pt = positions[i]
        if pt then
            for _, hb in ipairs(hitboxes or {0,2,3}) do
                local hx, hy, hz = entity.hitbox_position(enemy, hb)
                if hx then
                    local frac, dmg = client.trace_bullet(me, pt.x, pt.y, pt.z, hx, hy, hz, hb == 0)
                    if hb == 0 then dmg = (dmg or 0) * 4 end
                    if (dmg or 0) >= math.min(min_dmg, hp) and (dmg or 0) > 0 then
                        return pt, i
                    end
                end
            end
        end
    end
    return nil, 0
end

extra.aipeek = {
    ref = menu.other.misc.aipeek,

    work = function(self, cmd)
        if not self.ref or not self.ref.val:get() then
            if aipeek_state.active then
                refs.rage.peek[1]:override()
                aipeek_state.active   = false
                aipeek_state.moving_out = false
                aipeek_state.returning  = false
                aipeek_state.shot_done  = false
                aipeek_state.retreat    = false
            end
            return
        end

        local hotkey = self.ref.hotkey:get()
        local me = entity.get_local_player()
        if not me or not entity.is_alive(me) then return end

        if hotkey and not aipeek_state.active then
            aipeek_state.middle_pos = vector(entity.get_origin(me))
            aipeek_state.active     = true
            aipeek_state.moving_out = false
            aipeek_state.returning  = false
            aipeek_state.shot_done  = false
            aipeek_state.retreat    = false
        elseif not hotkey and aipeek_state.active then
            refs.rage.peek[1]:override()
            aipeek_state.active     = false
            aipeek_state.moving_out = false
            aipeek_state.returning  = false
            aipeek_state.shot_done  = false
            aipeek_state.retreat    = false
            return
        end

        if not aipeek_state.active then return end

        refs.rage.peek[1]:override(true)

        local target   = client.current_threat()
        local my_pos   = vector(entity.get_origin(me))
        local mid      = aipeek_state.middle_pos
        local dist_mid = my_pos:dist2d(mid)
        local vx, vy   = entity.get_prop(me, "m_vecVelocity")
        local speed    = math.sqrt((vx or 0)^2 + (vy or 0)^2)
        local in_air   = entity.in_air(me)
        local moving   = in_air or cmd.in_forward==1 or cmd.in_back==1 or cmd.in_moveleft==1 or cmd.in_moveright==1 or cmd.in_jump==1

        local mode = self.ref.mode:get()

        -- update middle pos when standing still (offensive mode)
        if mode == "Offensive" and not aipeek_state.moving_out and not aipeek_state.returning then
            if dist_mid > 0.15 and speed < 1.1 and speed ~= 0 then
                aipeek_state.middle_pos = my_pos
                mid = my_pos
            end
        end

        -- setup peek points
        local target_ang = 0
        if target then
            local t_pos = vector(entity.get_origin(target))
            target_ang  = vector(mid:to(t_pos):angles()).y
        else
            target_ang  = vector(client.camera_angles()).y
        end
        aipeek_setup_points(me, mid, target_ang, 4, 22)

        -- find best peek point
        local best_pt, best_idx = nil, 0
        if not moving and not aipeek_state.returning and aipeek_can_fire(me) then
            best_pt, best_idx = aipeek_trace_enemy(aipeek_state.positions, me, target, {0,2,3})
        end

        aipeek_state.active_idx = best_idx

        if best_pt then
            aipeek_utils.set_movement(cmd, best_pt, me)
            aipeek_state.moving_out = true
            aipeek_state.returning  = false
            aipeek_state.shot_done  = true
            aipeek_state.retreat    = false
        elseif moving then
            aipeek_state.moving_out = false
            aipeek_state.returning  = false
        elseif aipeek_state.shot_done or mode == "Defensive" then
            aipeek_state.returning  = true
            aipeek_state.moving_out = false
            aipeek_state.retreat    = true
        end

        if aipeek_state.returning then
            if dist_mid < 0.15 then
                aipeek_state.returning = false
                aipeek_state.retreat   = false
                aipeek_state.shot_done = false
            else
                aipeek_utils.set_movement(cmd, mid, me)
            end
        end
    end,

    paint = function(self)
        if not self.ref or not self.ref.val:get() then return end
        if not self.ref.render:get() then return end
        if not aipeek_state.active then return end

        for i = 0, 4 do
            local pt = aipeek_state.positions[i]
            if pt then
                local sx, sy = renderer.world_to_screen(pt.x, pt.y, pt.z)
                if sx then
                    local is_active = (i == aipeek_state.active_idx)
                    local r, g, b = is_active and mr or 255, is_active and mg or 255, is_active and mb or 255
                    local a = is_active and 255 or 100
                    renderer.circle(sx, sy, r, g, b, a, 3, 0, 1)
                end
                -- line to next
                local pt2 = aipeek_state.positions[i <= 2 and 0 or i - 2]
                if pt2 then
                    local sx2, sy2 = renderer.world_to_screen(pt2.x, pt2.y, pt2.z)
                    if sx2 then
                        renderer.line(sx, sy, sx2, sy2, 255, 255, 255, 80)
                    end
                end
            end
        end
    end,

    release = function(self)
        self.ref.val:set_event("setup_command", guarded_event(function(cmd)
            self:work(cmd)
        end))
        self.ref.val:set_event("paint", guarded_event(function()
            self:paint()
        end))
    end
}

for tab, func in next, extra do
    func:release()
end

local function update_visual_color_visibility()
    local show_cross = menu.other.visuals.crosshair.val:get()
    local show_watermark = menu.other.visuals.watermark.val:get()
    local cross_mode = menu.other.visuals.crosshair.type and menu.other.visuals.crosshair.type.get and menu.other.visuals.crosshair.type:get() or nil
    local show_modern = show_cross and cross_mode == "modern"
    local show_basic = show_cross and not show_modern

    if menu.other.visuals.crosshair.colors and menu.other.visuals.crosshair.colors.first then
        menu.other.visuals.crosshair.colors.first:set_visible(show_basic)
    end
    if menu.other.visuals.crosshair.colors and menu.other.visuals.crosshair.colors.second then
        menu.other.visuals.crosshair.colors.second:set_visible(show_basic)
    end
    if menu.other.visuals.crosshair.modern then
        if menu.other.visuals.crosshair.modern.main then
            menu.other.visuals.crosshair.modern.main:set_visible(show_modern)
        end
        if menu.other.visuals.crosshair.modern.trail then
            menu.other.visuals.crosshair.modern.trail:set_visible(show_modern)
        end
        if menu.other.visuals.crosshair.modern.state then
            menu.other.visuals.crosshair.modern.state:set_visible(show_modern)
        end
        if menu.other.visuals.crosshair.modern.key then
            menu.other.visuals.crosshair.modern.key:set_visible(show_modern)
        end
    end
    menu.other.visuals.watermark.colors.first:set_visible(show_watermark)
    menu.other.visuals.watermark.colors.second:set_visible(show_watermark)
end

local function update_menu_tab_label()
    -- tab_label is now empty, banner handles the display
end

local function update_menu_color_labels()
    local mr, mg, mb, ma = unpack({menu.home.colors.first:get()})

    pui.macros.hex1 = clr.rgb(mr, mg, mb, ma):hex()
    pui.macros.hex2 = pui.macros.hex1
    pui.macros.v = clr.rgb(mr, mg, mb, ma):hexa(true)
    pui.macros.m = pui.macros.v .. "\r"

    update_menu_tab_label()
end


menu.other.visuals.crosshair.val:set_callback(function(check)
    update_visual_color_visibility()
end, true)
if menu.other.visuals.crosshair.type and menu.other.visuals.crosshair.type.set_callback then
    menu.other.visuals.crosshair.type:set_callback(function()
        update_visual_color_visibility()
    end, true)
end


local function sanitize_watermark_text(text)
    if not text then return nil end
    text = tostring(text)
    text = text:gsub("\a%x%x%x%x%x%x%x%x", "")
               :gsub("\a%x%x%x%x%x%x", "")
    text = text:gsub("%s+", " " ):gsub("^%s+", ""):gsub("%s+$", "")
    return text
end
menu.other.visuals.watermark.val:set_callback(function(check)
    update_visual_color_visibility()
end, true)

menu.home.colors.first:set_callback(function()
    update_menu_color_labels()
end, true)

local viewmodel_options = {false, false, false}
local viewmodel_shot = {time = 0, pitch = 0, yaw = 0}
local viewmodel_vec = vector(0, 0, 0)

local vm_set_abs_angles = nil
local vm_entity_list = nil
local vm_get_client_entity = nil
local vm_weaponsystem_raw = nil
local vm_get_weapon_info = nil

do
    local ok = pcall(function()
        vm_set_abs_angles = ffi.cast("void(__thiscall*)(void*, const Vector*)", client.find_signature("client.dll", "\x55\x8B\xEC\x83\xE4\xF8\x83\xEC\x64\x53\x56\x57\x8B\xF1"))
        vm_entity_list = ffi.cast("void***", client.create_interface("client.dll", "VClientEntityList003"))
        vm_get_client_entity = ffi.cast("uintptr_t (__thiscall*)(void*, int)", vm_entity_list[0][3])
    end)

    if not ok then
        vm_set_abs_angles = nil
        vm_entity_list = nil
        vm_get_client_entity = nil
    end

    local ok_scope = pcall(function()
        if not vtable_thunk then
            return
        end
        local ccsweaponinfo_t = [[
            struct {
                char __pad_0x0000[0x1cd];
                bool hide_vm_scope;
            }
        ]]
        local match = client.find_signature("client_panorama.dll", "\x8B\x35\xCC\xCC\xCC\xCC\xFF\x10\x0F\xB7\xC0")
        if not match then
            return
        end
        vm_weaponsystem_raw = ffi.cast("void****", ffi.cast("char*", match) + 2)[0]
        vm_get_weapon_info = vtable_thunk(2, ccsweaponinfo_t .. "*(__thiscall*)(void*, unsigned int)")
    end)

    if not ok_scope then
        vm_weaponsystem_raw = nil
        vm_get_weapon_info = nil
    end
end

local function viewmodel_enabled()
    return menu.other.visuals.viewmodel and menu.other.visuals.viewmodel.val:get()
end

local function update_viewmodel_visibility()
    if not viewmodel_enabled() then
        return
    end

    local show = not viewmodel_options[3]
    local vm = menu.other.visuals.viewmodel
    local controls = {vm.in_scope, vm.fov, vm.x, vm.y, vm.z, vm.pitch, vm.yaw, vm.roll}
    for _, element in ipairs(controls) do
        if element and element.set_visible then
            element:set_visible(show)
        end
    end
end

local function update_viewmodel_options()
    local vm = menu.other.visuals.viewmodel
    viewmodel_options[1] = vm.options:get("Follow Aimbot")
    viewmodel_options[2] = vm.options:get("Fakeduck Animation")
    viewmodel_options[3] = vm.options:get("Hide Sliders")
    update_viewmodel_visibility()
end

local function update_viewmodel_cvars()
    if not viewmodel_enabled() then
        return
    end

    cvar.viewmodel_fov:set_raw_float(menu.other.visuals.viewmodel.fov:get())
    cvar.viewmodel_offset_x:set_raw_float(menu.other.visuals.viewmodel.x:get() / 10)
    cvar.viewmodel_offset_y:set_raw_float(menu.other.visuals.viewmodel.y:get() / 10)
    cvar.viewmodel_offset_z:set_raw_float(menu.other.visuals.viewmodel.z:get() / 10)
end

local function viewmodel_aim_fire(event)
    if not (viewmodel_enabled() and viewmodel_options[1]) then
        return
    end

    local lp = entity.get_local_player()
    if not lp or not entity.is_alive(lp) then
        return
    end

    local pitch, yaw = (vector(client.eye_position())):to(vector(event.x, event.y, event.z)):angles()
    viewmodel_shot.time = globals.curtime()
    viewmodel_shot.pitch = pitch
    viewmodel_shot.yaw = yaw
end

local function viewmodel_override_view()
    if not viewmodel_enabled() then
        return
    end
    if not (vm_set_abs_angles and vm_entity_list and vm_get_client_entity) then
        return
    end

    local pitch, yaw = client.camera_angles()
    if viewmodel_shot.time ~= 0 and math.abs(globals.curtime() - viewmodel_shot.time) > 0.5 then
        viewmodel_shot.time = 0
    end

    viewmodel_vec.x = viewmodel_shot.time ~= 0 and viewmodel_shot.pitch or pitch - menu.other.visuals.viewmodel.pitch:get()
    viewmodel_vec.y = viewmodel_shot.time ~= 0 and viewmodel_shot.yaw or yaw - menu.other.visuals.viewmodel.yaw:get()
    viewmodel_vec.z = -menu.other.visuals.viewmodel.roll:get()

    for _, index in pairs(entity.get_all("CPredictedViewModel")) do
        if not entity.is_dormant(index) then
            vm_set_abs_angles(ffi.cast("int*", vm_get_client_entity(vm_entity_list, index)), viewmodel_vec)
        end
    end
end

local function viewmodel_paint()
    if not (viewmodel_enabled() and viewmodel_options[2]) then
        return
    end

    local lp = entity.get_local_player()
    if not lp or not entity.is_alive(lp) then
        return
    end

    local duck_active = false
    if refs.rage.duck then
        if refs.rage.duck.get then
            duck_active = refs.rage.duck:get()
        elseif refs.rage.duck[1] and refs.rage.duck[1].get then
            duck_active = refs.rage.duck[1]:get()
        end
    end

    local offset = duck_active and (entity.get_prop(lp, "m_vecViewOffset[2]") - 48) * 0.5 or 0
    cvar.viewmodel_offset_z:set_raw_float(menu.other.visuals.viewmodel.z:get() / 10 - offset)
end

local function viewmodel_in_scope()
    if not viewmodel_enabled() then
        return
    end
    if not (vm_weaponsystem_raw and vm_get_weapon_info) then
        return
    end

    local lp = entity.get_local_player()
    local weapon = lp and entity.get_player_weapon(lp) or nil
    if not weapon then
        return
    end

    local w_id = entity.get_prop(weapon, "m_iItemDefinitionIndex")
    if not w_id then
        return
    end

    local res = vm_get_weapon_info(vm_weaponsystem_raw, w_id)
    if res then
        res.hide_vm_scope = not menu.other.visuals.viewmodel.in_scope:get()
    end
end

if menu.other.visuals.viewmodel.options and menu.other.visuals.viewmodel.options.set_callback then
    menu.other.visuals.viewmodel.options:set_callback(update_viewmodel_options, true)
end

if menu.other.visuals.viewmodel.val and menu.other.visuals.viewmodel.val.set_callback then
    menu.other.visuals.viewmodel.val:set_callback(function()
        update_viewmodel_options()
        update_viewmodel_cvars()
    end, true)
end

menu.other.visuals.viewmodel.fov:set_callback(update_viewmodel_cvars)
menu.other.visuals.viewmodel.x:set_callback(update_viewmodel_cvars)
menu.other.visuals.viewmodel.y:set_callback(update_viewmodel_cvars)
menu.other.visuals.viewmodel.z:set_callback(update_viewmodel_cvars, true)



local function safe_svg(svg, w, h)
    if renderer.load_svg then
        return renderer.load_svg(svg, w, h)
    end
    return nil
end


local hitgroup_names = {"generic", "head", "chest", "stomach", "left arm", "right arm", "left leg", "right leg", "neck", "?", "gear"}

local aimbot_logs = {
    notify_data = {},
    fire_data = {},
    hitgroup = hitgroup_names,
    notify_cfg = {
        max_items = 5,
        lifetime = 3.5,
        corner_radius = 8,
        bg_color = {0, 0, 0, 200},
        padding = {left = 10, right = 10, text = 6},
        icon_size = 16,
        step = 30
    },
    icons = {
        success = safe_svg([[<svg width="24" height="24" viewBox="0 0 24 24" fill="#ffffff"xmlns="http://www.w3.org/2000/svg "><path fill-rule="evenodd" clip-rule="evenodd" d="M22 12C22 17.5228 17.5228 22 12 22C6.47715 22 2 17.5228 2 12C2 6.47715 6.47715 2 12 2C17.5228 2 22 6.47715 22 12ZM16.0303 8.96967C16.3232 9.26256 16.3232 9.73744 16.0303 10.0303L11.0303 15.0303C10.7374 15.3232 10.2626 15.3232 9.96967 15.0303L7.96967 13.0303C7.67678 12.7374 7.67678 12.2626 7.96967 11.9697C8.26256 11.6768 8.73744 11.6768 9.03033 11.9697L10.5 13.4393L12.7348 11.2045L14.9697 8.96967C15.2626 8.67678 15.7374 8.67678 16.0303 8.96967Z" fill="#ffffff"/></svg>]], 16, 16),
        failed = safe_svg([[<svg width="24" height="24" viewBox="0 0 24 24" fill="#ffffff" xmlns="http://www.w3.org/2000/svg "><path fill-rule="evenodd" clip-rule="evenodd" d="M22 12C22 17.5228 17.5228 22 12 22C6.47715 22 2 17.5228 2 12C2 6.47715 6.47715 2 12 2C17.5228 2 22 6.47715 22 12ZM8.96963 8.96965C9.26252 8.67676 9.73739 8.67676 10.0303 8.96965L12 10.9393L13.9696 8.96967C14.2625 8.67678 14.7374 8.67678 15.0303 8.96967C15.3232 9.26256 15.3232 9.73744 15.0303 10.0303L13.0606 12L15.0303 13.9696C15.3232 14.2625 15.3232 14.7374 15.0303 15.0303C14.7374 15.3232 14.2625 15.3232 13.9696 15.0303L12 13.0607L10.0303 15.0303C9.73742 15.3232 9.26254 15.3232 8.96965 15.0303C8.67676 14.7374 8.67676 14.2625 8.96965 13.9697L10.9393 12L8.96963 10.0303C8.67673 9.73742 8.67673 9.26254 8.96963 8.96965Z" fill="#ffffff"/></svg>]], 16, 16),
        info = safe_svg([[<svg width="24" height="24" viewBox="0 0 24 24" fill="#ffffff" xmlns="http://www.w3.org/2000/svg "><path fill-rule="evenodd" clip-rule="evenodd" d="M22 12C22 17.5228 17.5228 22 12 22C6.47715 22 2 17.5228 2 12C2 6.47715 6.47715 2 12 2C17.5228 2 22 6.47715 22 12ZM12 17.75C12.4142 17.75 12.75 17.4142 12.75 17V11C12.75 10.5858 12.4142 10.25 12 10.25C11.5858 10.25 11.25 10.5858 11.25 11V17C11.25 17.4142 11.5858 17.75 12 17.75ZM12 7C12.5523 7 13 7.44772 13 8C13 8.55228 12.5523 9 12 9C11.4477 9 11 8.55228 11 8C11 7.44772 11.4477 7 12 7Z" fill="#ffffff"/></svg>]], 16, 16)
    }
}

aimbot_logs.anchor = draggable:new("aimbot_logs", db.src.x / 2 - 120, db.src.y * 0.75 - 15)

local function aimbot_logs_enabled()
    return menu.other.visuals.aimbot_logs and menu.other.visuals.aimbot_logs.val:get()
end

local function aimbot_logs_notify_enabled()
    return menu.other.visuals.aimbot_logs and menu.other.visuals.aimbot_logs.val:get()
end

local function aimbot_logs_print(text)
    client.color_log(255, 255, 255, "[\0")
    client.color_log(255, 255, 255, "prioraclub\0")
    client.color_log(255, 255, 255, "] \0")
    client.color_log(255, 255, 255, text)
    client.color_log(255, 255, 255, "\n")
end

local function aimbot_logs_color(kind)
    local logs = menu.other.visuals.aimbot_logs
    if not logs then
        return {255, 255, 255, 255}
    end
    if kind == "hit" then
        return {logs.hit:get()}
    end
    return {logs.miss:get()}
end

local function aimbot_logs_push(text, kind)
    if not aimbot_logs_notify_enabled() then
        return
    end
    local clr = aimbot_logs_color(kind == "hit" and "hit" or "miss")
    local notif_type = (kind == "hit") and "success" or "failed"
    table.insert(aimbot_logs.notify_data, 1, {
        text = tostring(text or ""),
        color = clr,
        type = notif_type,
        time = globals.curtime(),
        opacity = 0,
        scale = 0,
        width = 0,
        height = 0
    })
    if #aimbot_logs.notify_data > aimbot_logs.notify_cfg.max_items then
        table.remove(aimbot_logs.notify_data)
    end
end

local function aimbot_logs_aim_fire(c)
    if not aimbot_logs_enabled() then
        return
    end
    aimbot_logs.fire_data.damage = c.damage
    aimbot_logs.fire_data.hitgroup = aimbot_logs.hitgroup[c.hitgroup + 1] or "?"
    aimbot_logs.fire_data.hitchance = math.floor(c.hit_chance or 0)
end

local function aimbot_logs_aim_hit(c)
    if not aimbot_logs_enabled() then
        return
    end
    local target = entity.get_player_name(c.target) or "?"
    local hitgroup = aimbot_logs.hitgroup[c.hitgroup + 1] or "?"
    local damage = tostring(c.damage or 0)
    local fired_hitgroup = aimbot_logs.fire_data.hitgroup or "?"
    local fired_damage = tostring(aimbot_logs.fire_data.damage or 0)
    local hitchance = tostring(aimbot_logs.fire_data.hitchance or 0)
    local history = tostring(globals.tickcount() - (c.tick or globals.tickcount()))

    aimbot_logs_print(string.format(
        "Hit %s in the %s(%s) for %s(%s) damage [ hitchance: %s%% | history: %s ]",
        target, hitgroup, fired_hitgroup, damage, fired_damage, hitchance, history
    ))

    aimbot_logs_push(string.format("Hit %s in the %s for %s damage", target, hitgroup, damage), "hit")
end

local function aimbot_logs_aim_miss(c)
    if not aimbot_logs_enabled() then
        return
    end
    local target = entity.get_player_name(c.target) or "?"
    local hitgroup = aimbot_logs.hitgroup[c.hitgroup + 1] or "?"
    local reason = c.reason or "?"
    local damage = tostring(aimbot_logs.fire_data.damage or 0)
    local hitchance = tostring(aimbot_logs.fire_data.hitchance or 0)
    local history = tostring(globals.tickcount() - (c.tick or globals.tickcount()))

    aimbot_logs_print(string.format(
        "Missed shot due to %s at %s in the %s for %s damage [ hitchance: %s%% | history: %s ]",
        reason, target, hitgroup, damage, hitchance, history
    ))

    aimbot_logs_push(string.format("Missed shot due to %s at %s in the %s for %s damage", reason, target, hitgroup, damage), "miss")
end

local function render_log_notifications(logs, style)
    if not logs or not logs.notify_data then return end
    local screen_x, screen_y = client.screen_size()
    if not screen_x or not screen_y then return end

    local lifetime = logs.notify_cfg and logs.notify_cfg.lifetime or 3.5
    local now      = globals.curtime()
    local h        = 24
    local gap      = 8
    local base_y   = screen_y * 0.82
    local radius   = h / 2

    for i = 1, #logs.notify_data do
        local item = logs.notify_data[i]
        if not item.slide   then item.slide   = h + gap end
        if not item.opacity then item.opacity = 0       end
        local dying = (now - item.time) > (lifetime - 0.5)
        item.slide   = animate.lerp(item.slide,   0,   16)
        item.opacity = animate.lerp(item.opacity, dying and 0 or 1, dying and 5 or 22)
    end

    local offset_y = 0
    for i = #logs.notify_data, 1, -1 do
        local item = logs.notify_data[i]
        if (item.opacity or 0) < 0.02 then goto skip end

        local alpha = math.clamp(item.opacity, 0, 1)
        local a     = math.floor(255 * alpha)

        local name      = "prioraclub"
        local nw, nh    = renderer.measure_text("b", name)
        local full_text = item.text
        local tw, th    = renderer.measure_text("", full_text)
        nw = nw or 0; tw = tw or 0; nh = nh or 12; th = th or 12

        local pad     = 14
        local gap2    = 8
        local dot_r   = 3
        local dot_gap = 8
        local bg_w    = pad + dot_r * 2 + dot_gap + nw + gap2 + tw + pad
        local bg_x    = screen_x / 2 - bg_w / 2
        local bg_y    = base_y - offset_y - (item.slide or 0)

        local is_hit = (item.type == "success")
        -- цвет из меню — читаем каждый кадр
        local gr, gg, gb = 80, 200, 180
        if menu.home and menu.home.colors and menu.home.colors.first then
            local ok, r, g, b = pcall(function() return menu.home.colors.first:get() end)
            if ok and r then gr, gg, gb = r, g, b end
        end

        -- blur под pill
        pcall(function()
            surface.blur(bg_x, bg_y, bg_w, h, 3)
        end)

        -- лёгкий glow — только 3 слоя, очень низкая alpha
        render.rect(bg_x - 4, bg_y - 4, bg_w + 8, h + 8, {gr, gg, gb, math.floor(12 * alpha)}, radius + 4)
        render.rect(bg_x - 2, bg_y - 2, bg_w + 4, h + 4, {gr, gg, gb, math.floor(18 * alpha)}, radius + 2)
        render.rect(bg_x - 1, bg_y - 1, bg_w + 2, h + 2, {gr, gg, gb, math.floor(22 * alpha)}, radius + 1)

        -- фон почти прозрачный
        render.rect(bg_x, bg_y, bg_w, h, {15, 17, 25, math.floor(60 * alpha)}, radius)

        -- тонкая граница
        render.rect(bg_x, bg_y, bg_w, h, {255, 255, 255, math.floor(35 * alpha)}, radius)
        render.rect(bg_x + 1, bg_y + 1, bg_w - 2, h - 2, {15, 17, 25, math.floor(60 * alpha)}, radius - 1)

        -- точка
        local dot_x = bg_x + pad
        local dot_y = bg_y + h / 2 - dot_r
        render.rect(dot_x, dot_y, dot_r * 2, dot_r * 2, {gr, gg, gb, math.floor(230 * alpha)}, dot_r)

        -- текст
        local ty   = bg_y + (h - nh) / 2
        local tx_n = dot_x + dot_r * 2 + dot_gap
        local tx_t = tx_n + nw + gap2

        renderer.text(tx_n, ty, 255, 255, 255, a,                       "b", 0, name)
        renderer.text(tx_t, ty, 185, 190, 200, math.floor(210 * alpha), "",  0, full_text)

        offset_y = offset_y + h + gap
        ::skip::
    end

    local i = 1
    while i <= #logs.notify_data do
        if now - logs.notify_data[i].time > (lifetime + 0.6) then
            table.remove(logs.notify_data, i)
        else
            i = i + 1
        end
    end
end

callback.aim_fire:set(function(event)
    viewmodel_aim_fire(event)
    aimbot_logs_aim_fire(event)
end)
callback.override_view:set(viewmodel_override_view)
callback.run_command:set(viewmodel_in_scope)
callback.aim_hit:set(aimbot_logs_aim_hit)
callback.aim_miss:set(aimbot_logs_aim_miss)
callback.setup_command:set(function(cmd)
    if extra.ragebot_overnight then
        extra.ragebot_overnight:on_setup_command(cmd)
    end
end)
callback.net_update_end:set(function()
    if extra.ragebot_overnight then
        extra.ragebot_overnight:on_net_update_end()
    end
end)

local r, g, b, a = unpack({menu.other.visuals.crosshair.colors.first:get()})
local rs, gs, bs, as = unpack({menu.other.visuals.crosshair.colors.second:get()})
local wr, wg, wb, wa = unpack({menu.other.visuals.watermark.colors.first:get()})
local wrs, wgs, wbs, was = unpack({menu.other.visuals.watermark.colors.second:get()})
local mr, mg, mb, ma = unpack({menu.home.colors.first:get()})

local function complete_menu()
    if not pui.menu_open then 
        return 
    end

    ifc.hide(false)
    -- update session start time
    if session.start == 0 then
        session.start = globals.realtime()
    end

    -- update stats labels every 10 ticks
    if globals.tickcount() % 10 == 0 then
        local st = menu.home.other.stats
        if st then
            local kd = session.deaths > 0 and string.format("%.2f", session.kills / session.deaths) or string.format("%.2f", session.kills)
            local playtime_sec = math.floor(globals.realtime() - (session.start > 0 and session.start or globals.realtime()))
            local h = math.floor(playtime_sec / 3600)
            local m = math.floor((playtime_sec % 3600) / 60)
            local s = playtime_sec % 60
            local pt = string.format("%02d:%02d:%02d", h, m, s)
            local gray = "\f<gray>"
            local acc  = "\f<v>"
            if st.row1 and st.row1.set then
                st.row1:set(acc .. "\r Kills " .. gray .. tostring(session.kills) .. "   " .. acc .. "\r Deaths " .. gray .. tostring(session.deaths))
            end
            if st.row2 and st.row2.set then
                st.row2:set(acc .. "\r K/D " .. gray .. kd .. "   " .. acc .. "\r Time " .. gray .. pt)
            end
            if st.row3 and st.row3.set then
                st.row3:set(acc .. "\r Loads " .. gray .. tostring(data.statx.load or 0) .. "   " .. acc .. "\r Misses " .. gray .. tostring(data.statx.selfmiss or 0))
            end
        end
    end

    if globals.tickcount() % 5 == 0 then
        -- animated gradient banner
        if menu.banner then
            local t = globals.realtime() * 0.8
            local title = "PrioraClub"
            local result = {}
            local mr2, mg2, mb2 = unpack({menu.home.colors.first:get()})
            for i = 1, #title do
                local ch = title:sub(i, i)
                local phase = math.abs(math.cos((i / #title + t) * math.pi))
                local rr = math.floor(mr2 * phase + 220 * (1 - phase))
                local gg = math.floor(mg2 * phase + 220 * (1 - phase))
                local bb = math.floor(mb2 * phase + 220 * (1 - phase))
                rr = math.max(0, math.min(255, rr))
                gg = math.max(0, math.min(255, gg))
                bb = math.max(0, math.min(255, bb))
                result[#result + 1] = string.format("\a%02x%02x%02xFF%s", rr, gg, bb, ch)
            end
            local banner_text = table.concat(result)
            local sub = "\f<gray>" .. db.server.user .. " / " .. db.server.version[1]
            if menu.banner.set then
                menu.banner:set(banner_text .. "  " .. sub)
            end
        end
        r, g, b, a = unpack({menu.other.visuals.crosshair.colors.first:get()})
        rs, gs, bs, as = unpack({menu.other.visuals.crosshair.colors.second:get()})
        wr, wg, wb, wa = unpack({menu.other.visuals.watermark.colors.first:get()})
        wrs, wgs, wbs, was = unpack({menu.other.visuals.watermark.colors.second:get()})
        mr, mg, mb, ma = unpack({menu.home.colors.first:get()})

        accent[1] = clr.rgb(r, g, b, a)
        accent[2] = clr.rgb(rs, gs, bs, as)
        accent_wm[1] = clr.rgb(wr, wg, wb, wa)
        accent_wm[2] = clr.rgb(wrs, wgs, wbs, was)
        pui.macros.hex1 = clr.rgb(mr, mg, mb, ma):hex()
        pui.macros.hex2 = pui.macros.hex1
        pui.macros.v = clr.rgb(mr, mg, mb, ma):hexa(true)
        pui.macros.m = pui.macros.v .. "\r"
        menu.home.other.stats.build:set("\f<v>\r Your active build: \f<v>" .. db.server.version[1])
    end
end

callback.paint_ui:set(complete_menu)

function render.rect_outline(x, y, w, h, clr1, clr2, alpha, blur)
    local r1, g1, b1, a1 = unpack(clr1)
    local r2, g2, b2, a2 = unpack(clr2)

    if blur and alpha > 0.5 and game.alive then 
        render.blur(x, y, w, h)
    end 

    local roundess = 4
    local glow = 0

    if glow ~= 0 then 
        render:glow(x, y, w, h, glow * 2, {r, g, b, alpha * 60}, roundess, 1)
    end

    render.rect(x, y, w, h, {r1, g1, b1, a1 * alpha}, roundess)
    render.outline(x, y, w, h, {r2, g2, b2, a2 * alpha}, roundess, 1)
end

local paint = {}

paint.crosshair = draggable:new("crosshair", db.src.x / 2 - 25, db.src.y / 2 + 45, {
    border = {
        db.src.x / 2, db.src.y / 2 + 8, 1, db.src.y / 6, true
    },
    round = 4
})

paint.crosshair.setting = menu.other.visuals.crosshair
paint.crosshair.keys = {}

paint.crosshair.update = function()
    return game.alive and paint.crosshair.setting.val:get()
end

paint.crosshair.paint = function(self)
    self:release(50, 13)
    self:part()

    local def = antiaim_enabled and defensive or {active = false}
    local exploit = not entity.weapon_switch(game.me) and (game.charged and (def.active and "defensive" or "ready") or "charging") or "waiting"
    paint.crosshair.keys = {
        {
            name = "DT",
            mult = " " .. exploit,
            active = refs.rage.dotap.val[1]:get() and refs.rage.dotap.val[1]:get_hotkey(),
            clr = function()
                if exploit == "ready" then
                    return clr.rgb(r, g, b)
                elseif exploit == "charging" then
                    return clr.rgb(255, 100, 100)
                else
                    return clr.rgb(rs, gs, bs)
                end
            end
        }, {
            name = "PEEK",
            mult = " " .. (game.charged and "ideal" or ""),
            active = refs.rage.peek[1]:get() and refs.rage.peek[1]:get_hotkey(),
            clr = clr.rgb(255, 199, 102)
        }, {
            name = "OSAA",
            mult = " " .. (game.charged and (def.active and "tick" or "hide") or ""),
            active = refs.aa.other.osaa[1]:get() and refs.aa.other.osaa[1]:get_hotkey(),
            clr = game.charged and clr.rgb(rs, gs, bs) or clr.rgb(255, 100, 100)
        }, {
            name = "SP",
            active = refs.rage.safe[1]:get()
        }, {
            name = "BA",
            active = refs.rage.baim[1]:get()
        }, {
            name = "MD",
            active = refs.rage.damage.ovr[1]:get() and refs.rage.damage.ovr[1]:get_hotkey()
        }
    }
end

local function crosshair_gradient_text(text, highlight, base, speed)
    if not text or text == "" then
        return ""
    end

    local chars = {}
    for ch in string.gmatch(text, ".[\x80-\xBF]*") do
        chars[#chars + 1] = ch
    end

    local len = #chars
    if len == 0 then
        return ""
    end

    local hr, hg, hb, ha = highlight[1] or 255, highlight[2] or 255, highlight[3] or 255, highlight[4] or 255
    local br, bg, bb, ba = base[1] or 0, base[2] or 0, base[3] or 0, base[4] or 255
    local highlight_fraction = (globals.realtime() / 2 % 1.2 * (speed or 1)) - 1.2
    local out = {}

    for i = 1, len do
        local character_fraction = i / len
        local r, g, b, a = br, bg, bb, ba
        local delta = math.abs(character_fraction - 0.5 - highlight_fraction)
        if delta <= 1 then
            local t = 1 - delta
            r = r + (hr - r) * t
            g = g + (hg - g) * t
            b = b + (hb - b) * t
            a = a + (ha - a) * t
        end

        r = math.clamp(math.floor(r + 0.5), 0, 255)
        g = math.clamp(math.floor(g + 0.5), 0, 255)
        b = math.clamp(math.floor(b + 0.5), 0, 255)
        a = math.clamp(math.floor(a + 0.5), 0, 255)
        out[#out + 1] = string.format("\a%02x%02x%02x%02x%s", r, g, b, a, chars[i])
    end

    return table.concat(out)
end

paint.crosshair.part = function(self)
    local y, alpha = self.y, self.alpha
    local mode = self.setting.type:get()
    local alphaa = math.floor(alpha * 255)

    if mode == "modern" then
        local modern_cfg = menu.other.visuals.crosshair.modern
        local ar, ag, ab = 138, 43, 226
        if modern_cfg and modern_cfg.main then
            ar, ag, ab = modern_cfg.main:get()
        end

        local dt_active = refs.rage.dotap.val[1]:get() and refs.rage.dotap.val[1]:get_hotkey()
        local os_active = refs.aa.other.osaa[1]:get() and refs.aa.other.osaa[1]:get_hotkey()
        local fd_active = refs.rage.duck[1]:get() and refs.rage.duck[1]:get_hotkey()

        local key_state = (os_active and not dt_active and "os") or
                          (dt_active and not fd_active and "dt") or
                          (fd_active and "fd") or ""
        local state_text = util.state:get():lower()
        local title = db.name:lower()

        self.modern_shift = animate.lerp(self.modern_shift or 0, game.scope.open and 30 or 0, 12)
        local base_x = db.src.x / 2 + (self.modern_shift or 0)
        local base_y = y + 5

        -- sparkle stars like spectral
        local stars = {
            {"★", -28, -14, 0.6},
            {"⋆", -22, -18, 0.3},
            {"✨", -14, -12, 0.7},
            {"✦", -8,  -16, 0.5},
            {"★", 8,   -14, 0.4},
            {"⋆", 16,  -18, 0.3},
            {"✨", 22,  -12, 0.7},
            {"⋆", 28,  -16, 0.2},
        }

        local t = globals.realtime()
        for _, star in ipairs(stars) do
            local char, ox, oy, base_fade = star[1], star[2], star[3], star[4]
            local pulse = math.abs(math.sin(t * 1.5 + ox * 0.3)) * base_fade
            local sa = math.floor(alphaa * pulse)
            if sa > 5 then
                renderer.text(base_x + ox, base_y + oy, ar, ag, ab, sa, "-c", 0, char)
            end
        end

        -- title gradient
        local title_grad = crosshair_gradient_text(title, {ar, ag, ab, 255}, {ar, ag, ab, 80}, 1.2)
        local tw, th = renderer.measure_text("-c", title)
        th = th or 12
        render.text(base_x, base_y, ar, ag, ab, alphaa, "c", title_grad)

        -- state
        if state_text ~= "" then
            render.text(base_x, base_y + th + 2, 180, 180, 180, alphaa, "c", state_text)
        end

        -- active key
        if key_state ~= "" then
            render.text(base_x, base_y + th * 2 + 4, 140, 140, 140, alphaa, "c", key_state)
        end
    end
end

paint.crosshair.binds = function(active, x, y, settings)
    local max = settings.max or nil
    local flag = settings.flag or nil
    local zoom = settings.zoom or nil
    local mult = settings.mult or nil
    local offset = 0
    local count = 0

    for _, bind in ipairs(paint.crosshair.keys) do
        local pressed = animate:new_lerp("cross.bind." .. bind.name, (bind.active and 1 or 0), 20) * active 
        local clra, multip = clr.white, ""

        if bind.clr then 
            if type(bind.clr) == "function" then
                clra = clr:lerp("cross.bind." .. bind.name, bind.clr(), 12)
            else
                clra = clr:lerp("cross.bind." .. bind.name, bind.clr, 12)
            end
        end

        if mult then 
            multip = animate:string("cross.mult." .. bind.name, bind.mult or "", 0.1)
        end

        local color = clra:alphen(255 * pressed):hexa(true)
        local text = mult and (bind.name .. color .. multip) or bind.name
        local name = render.measures(flag, mult and text:lower() or text)
        if max then 
            render.text(x + offset, y, clra.r, clra.g, clra.b, (100 + (155 * pressed)) * active, name.flag, name.text)

            offset = offset + name.w + settings.offset.x

            if count == max - 1 then
                y = y + settings.offset.y
                offset = 4
            end
        else
            local x = zoom and x + (name.w/2*(zoom)) or x
            local clr = mult and clr.white or clra

            render.text(x, y + offset, clr.r, clr.g, clr.b, 255 * pressed, name.flag, name.text)

            offset = offset + settings.offset.y * pressed
        end
        
        count = count + 1
    end
end

paint.arrows = draggable:new("pointes", db.src.x / 2 + 50, db.src.y / 2 - 11, {
    border = {
        db.src.x / 2 + 0, db.src.y / 2 - 11, 200, 1, true
    },
    round = 4
})

paint.arrows.update = function()
    return menu.other.visuals.pointers.val.value
end

paint.arrows.modes = {
    Default = function(left, right, scope, offset)
        if left > 0.1 then 
            render.text(db.src.x/2 + offset - 20, db.src.y/2 - 18 - (scope*20), r, g, b, left * 255, "", "<")
        end
    
        if right > 0.1 then 
            render.text(db.src.x/2 - offset + 2, db.src.y/2 - 18 - (scope*20), r, g, b, right * 255, "", ">")
        end
    end,

    TeamSkeet = function(left, right, scope, offset)
        local show_all = left > 0.1 or right > 0.1
        local alpha = math.max(left, right)
        local ap = 45
        
        if show_all then 
            local xl = db.src.x/2 + offset
            local yl = db.src.y/2 - 11 - (scope*20)

            local ra = right > 0.1 and right * 255 or ap * alpha
            local la = left > 0.1 and left * 255 or ap * alpha
            
            render.rectangle(xl, yl, 2, 20, rs, gs, bs, ra)
            render.triangle(xl - 2, yl, xl - 16, yl + 10, xl - 2, yl + 20, r, g, b, la)
    
            local xr = db.src.x/2 - offset
            local yr = db.src.y/2 - 11 - (scope*20)
            
            render.rectangle(xr, yr, 2, 20, rs, gs, bs, la)
            render.triangle(xr + 4, yr, xr + 18, yr + 10, xr + 4, yr + 20, r, g, b, ra)
        end
    end,

    Small = function(left, right, scope, offset)
        if left > 0.1 then 
            render.text(db.src.x/2 + offset - 12, db.src.y/2 - 9 - (scope*15), r, g, b, left * 255, "", "<")
        end
    
        if right > 0.1 then
            render.text(db.src.x/2 - offset + 6, db.src.y/2 - 9 - (scope*15), r, g, b, right * 255, "", ">")
        end
    end
}

paint.arrows.paint = function(self)  -- @flag155
    local x = self.x
    if not antiaim_enabled then
        return
    end
    local manual = antiaim_manual

    self:release(20, 20)

    local left = animate:new_lerp("pointers.left", (manual and manual.deg == -90 or pui.menu_open) and 1 or 0, 20) * self.alpha
    local right = animate:new_lerp("pointers.right", (manual and manual.deg == 90 or pui.menu_open) and 1 or 0, 20) * self.alpha
    local offset = db.src.x / 2 - x
    local scope = game.scope.anim

    paint.arrows.modes[menu.other.visuals.pointers.type.value](left, right, scope, offset)
end

paint.velocity = draggable:new("velocity", db.src.x / 2 - 55, 300, {
    align = {
        {
            db.src.x / 2, 0, 1, db.src.y
        }
    }
})

paint.velocity.update = function()
    return menu.other.visuals.managment.val.value and menu.other.visuals.managment.type:get("Velocity")
end

paint.velocity.paint = function(self)
    local x, y = self.x, self.y

    local modifier = pui.menu_open and animate.pulse or entity.get_prop(game.me, "m_flVelocityModifier")
    self.pre_alpha = animate.lerp(self.pre_alpha, modifier and (game.alive and modifier ~= 1 or pui.menu_open) and 1 or 0, 20)

    if self.pre_alpha > 0.1 then
        local alpha  = self.pre_alpha * self.alpha
        local vel_pct = math.floor((modifier or 0) * 100)
        local label  = "velocity"
        local value  = tostring(vel_pct) .. "%"

        local lw, lh = renderer.measure_text("b", label)
        local vw, vh = renderer.measure_text("b", value)
        local pad = 12
        local gap = 8
        local w   = lw + vw + pad * 2 + gap
        local h   = 24

        self:release(w, h)

        -- glow
        local ga = math.floor(40 * alpha)
        render.rect(x - 3, y - 3, w + 6, h + 6, {0, 0, 0, ga}, 5)
        render.rect(x - 1, y - 1, w + 2, h + 2, {0, 0, 0, ga * 2}, 4)
        -- main box
        render.rect(x, y, w, h, {18, 18, 22, math.floor(245 * alpha)}, 4)

        local ty = y + (h - lh) / 2
        renderer.text(x + pad,           ty, 180, 50, 255, math.floor(255 * alpha), "b", 0, label)
        renderer.text(x + pad + lw + gap, ty, 235, 235, 235, math.floor(255 * alpha), "b", 0, value)
    end
end

paint.defensive = draggable:new("defensive", db.src.x / 2 - 60, 400, {
    align = {
        {
            db.src.x / 2, 0, 1, db.src.y
        }
    }
})
paint.defensive.value = 0

paint.defensive.update = function()
    return menu.other.visuals.managment.val:get() and menu.other.visuals.managment.type:get("Defensive")
end

paint.defensive.paint = function(self)
    local x, y = self.x, self.y

    self.value = animate.lerp(self.value, math.min(defensive.ticks / 16, 1), 25)
    self.pre_alpha = animate.lerp(self.pre_alpha, self.value and (game.alive and self.value ~= 0 or pui.menu_open) and 1 or 0, 20)

    if self.pre_alpha > 0.1 then
        local alpha   = self.pre_alpha * self.alpha
        local def_pct = math.floor((self.value or 0) * 100)
        local label   = "defensive"
        local value   = tostring(def_pct) .. "%"

        local lw, lh = renderer.measure_text("b", label)
        local vw, vh = renderer.measure_text("b", value)
        local pad = 12
        local gap = 8
        local w   = lw + vw + pad * 2 + gap
        local h   = 24

        self:release(w, h)

        -- glow
        local ga = math.floor(40 * alpha)
        render.rect(x - 3, y - 3, w + 6, h + 6, {0, 0, 0, ga}, 5)
        render.rect(x - 1, y - 1, w + 2, h + 2, {0, 0, 0, ga * 2}, 4)
        -- main box
        render.rect(x, y, w, h, {18, 18, 22, math.floor(245 * alpha)}, 4)

        local ty = y + (h - lh) / 2
        renderer.text(x + pad,            ty, 255, 50, 100,  math.floor(255 * alpha), "b", 0, label)
        renderer.text(x + pad + lw + gap, ty, 235, 235, 235, math.floor(255 * alpha), "b", 0, value)
    end
end

paint.damage = draggable:new("damage", db.src.x / 2 + 10, db.src.y / 2 - 16, {
    border = {
        db.src.x / 2 - 50, 
        db.src.y / 2 - 50, 
        100, 
        100, 
        true
    },
    round = 2
})

paint.damage.setting = menu.other.visuals.damage

paint.damage.update = function(self)
    return game.alive and self.setting.val:get()
end

paint.damage.get = function(self)
    local ref = refs.rage
    local damage = {ref.damage.val[1]:get(), "def"}

    if ref.damage.ovr[1]:get_hotkey() then 
        damage = {ref.damage.ovr[2]:get(), "ovr"}
    end

    return damage
end

paint.damage.paint = function(self)
    local is_bind = self.setting.mode:get() == "Hotkey" and not pui.menu_open
    local font = self.setting.type:get() == "Default" and "" or (self.setting.type:get() == "Small" and "-" or "b")
    
    local value = self:get()[1]
    local type = self:get()[2]
    
    local text = animate:new_lerp("damage", value, 20, true)
    local final = render.measures(font, text)
    local x, y = self.x, self.y
    
    self:release(final.w - 1, final.h - 3)
    self.pre_alpha = animate.lerp(self.pre_alpha, type == "ovr" and 255 or 120, 15)
    
    if (is_bind and type == "ovr") or not is_bind then
        render.text(x - 2, y - 2, 255, 255, 255, (is_bind and 255 or self.pre_alpha) * self.alpha,font, is_bind and value or final.text)
    end
end

paint.speclist = draggable:new("speclist", 420, 320, {})
paint.speclist.list = {}

paint.speclist.update = function()
    return menu.other.visuals.speclist:get()
end

paint.speclist.paint = function(self)
    local x, y = self.x, self.y
    local target = game.me
    local obs_target = game.me and entity.get_prop(game.me, "m_hObserverTarget") or nil
    local obs_mode   = game.me and entity.get_prop(game.me, "m_iObserverMode")   or nil
    if obs_target and (obs_mode == 4 or obs_mode == 5) then target = obs_target end
    local items = {}
    for player = 1, globals.maxplayers() do
        if player ~= game.me and not entity.is_alive(player) then
            local st = entity.get_prop(player, "m_hObserverTarget")
            local md = entity.get_prop(player, "m_iObserverMode")
            if st and target and st == target and (md == 4 or md == 5) then
                items[#items + 1] = entity.get_player_name(player) or "unknown"
            end
        end
    end
    local show = (#items > 0) or pui.menu_open
    self.pre_alpha = animate.lerp(self.pre_alpha, show and 1 or 0, 15)
    if self.pre_alpha < 0.05 then return end
    if #items == 0 and pui.menu_open then items[1] = "no spectators" end
    local header = "spectators"

    local alpha  = self.pre_alpha * self.alpha
    local pad    = 12
    local row_h  = 18
    local max_w  = 0
    local hw, hh = renderer.measure_text('b', header)
    if hw > max_w then max_w = hw end
    for _, txt in ipairs(items) do
        local tw = renderer.measure_text('b', txt)
        if tw > max_w then max_w = tw end
    end
    local w = max_w + pad * 2
    local h = row_h + #items * row_h + 6
    self:release(w, h)
    local ga = math.floor(35 * alpha)
    render.rect(x - 4, y - 4, w + 8, h + 8, {20, 20, 20, ga}, 6)
    render.rect(x - 2, y - 2, w + 4, h + 4, {20, 20, 20, ga * 2}, 5)
    render.rect(x, y, w, h, {18, 18, 22, math.floor(245 * alpha)}, 4)
    renderer.text(x + pad, y + 3, 180, 50, 255, math.floor(255 * alpha), 'b', 0, header)
    for i, txt in ipairs(items) do
        renderer.text(x + pad, y + row_h + (i-1) * row_h + 2, 220, 220, 220, math.floor(200 * alpha), 'b', 0, txt)
    end

end

paint.binds = draggable:new("binds", 300, 360, {})
paint.binds.items = {}

paint.binds.update = function()
    return menu.other.visuals.bindlist:get()
end

paint.binds.paint = function(self)
    local x, y = self.x, self.y
    local def = antiaim_enabled and defensive or {active = false}
    local dt_state = game.charged and (def.active and "def" or "ready") or "charging"
    local defs = {
        {name="Double tap ["..dt_state.."]", active=function() return refs.rage.dotap.val[1]:get() and refs.rage.dotap.val[1]:get_hotkey() end},
        {name="Hide shots",   active=function() return refs.aa.other.osaa[1]:get() and refs.aa.other.osaa[1]:get_hotkey() end},
        {name="Quick peek",   active=function() return refs.rage.peek[1]:get() and refs.rage.peek[1]:get_hotkey() end},
        {name="Duck peek",    active=function() return refs.rage.duck[1]:get() and refs.rage.duck[1]:get_hotkey() end},
        {name="Slow motion",  active=function() return refs.aa.other.slow[1]:get() and refs.aa.other.slow[1]:get_hotkey() end},
        {name="Freestand",    active=function() return refs.aa.angles.freestand:get() and refs.aa.angles.freestand:get_hotkey() end},
        {name="Manual left",  active=function() return menu.antiaim.manual_left:get() end},
        {name="Manual right", active=function() return menu.antiaim.manual_right:get() end},
        {name="Safe point",   active=function() return refs.rage.safe[1]:get() end},
        {name="Force body",   active=function() return refs.rage.baim[1]:get() end},
    }
    local items = {}
    for _, def in ipairs(defs) do
        local ok, on = pcall(def.active)
        if ok and on then items[#items+1] = def.name end
    end
    local show = (#items > 0) or pui.menu_open
    self.pre_alpha = animate.lerp(self.pre_alpha, show and 1 or 0, 15)
    if self.pre_alpha < 0.05 then return end
    if #items == 0 and pui.menu_open then items[1] = "no hotkeys" end
    local header = "hotkeys"

    local alpha  = self.pre_alpha * self.alpha
    local pad    = 12
    local row_h  = 18
    local max_w  = 0
    local hw, hh = renderer.measure_text('b', header)
    if hw > max_w then max_w = hw end
    for _, txt in ipairs(items) do
        local tw = renderer.measure_text('b', txt)
        if tw > max_w then max_w = tw end
    end
    local w = max_w + pad * 2
    local h = row_h + #items * row_h + 6
    self:release(w, h)
    local ga = math.floor(35 * alpha)
    render.rect(x - 4, y - 4, w + 8, h + 8, {20, 20, 20, ga}, 6)
    render.rect(x - 2, y - 2, w + 4, h + 4, {20, 20, 20, ga * 2}, 5)
    render.rect(x, y, w, h, {18, 18, 22, math.floor(245 * alpha)}, 4)
    renderer.text(x + pad, y + 3, 180, 50, 255, math.floor(255 * alpha), 'b', 0, header)
    for i, txt in ipairs(items) do
        renderer.text(x + pad, y + row_h + (i-1) * row_h + 2, 220, 220, 220, math.floor(200 * alpha), 'b', 0, txt)
    end

end

paint.watermark = draggable:new("watermark", 15, 15, {
    align = {
        {
            db.src.x / 2, 0, 1, db.src.y
        },
        {
            0, db.src.y - 30, db.src.x, 1
        }
    }
})
paint.watermark.setting = menu.other.visuals.watermark

paint.watermark.update = function(self)
    local enabled = self.setting.val:get()
    local target = enabled and 1 or 0
    self.opacity = animate.lerp(self.opacity or 0, target, 12)
    return enabled or (self.opacity and self.opacity > 0.01)
end

local render_melancholia_watermark

paint.watermark.paint = function(self)
    local is_widget = self.setting.type:get() == "Widget"
    local v2_alpha = animate:new_lerp("water.style", is_widget and 1 or 0, 10)
    local base_alpha = (self.alpha or 1) * (self.opacity or 0)

    if is_widget then
        render_melancholia_watermark(self, v2_alpha * base_alpha)
    else
        self:text(v2_alpha, base_alpha)
    end
end

local function resolve_watermark_position(self, w, h, default_x, default_y, center_align)
    local pos = self.setting and self.setting.position and self.setting.position:get() or "Custom"
    if pos == "Custom" then
        return default_x, default_y
    end
    local screen_x, screen_y = client.screen_size()
    local margin = 12
    local x, y
    if pos == "Left" then
        x = center_align and (margin + w / 2) or margin
        y = margin
    elseif pos == "Right" then
        x = center_align and (screen_x - margin - w / 2) or (screen_x - margin - w)
        y = margin
    else -- Bottom
        x = center_align and (screen_x / 2) or (screen_x / 2 - w / 2)
        y = screen_y - margin - h
    end
    self.x = x
    self.y = y
    return x, y
end

local function mel_gradient(x, y, w, h, r1, g1, b1, a1, r2, g2, b2, a2, horizontal)
    if renderer.gradient then
        renderer.gradient(x, y, w, h, r1, g1, b1, a1, r2, g2, b2, a2, horizontal == true)
    else
        renderer.rectangle(x, y, w, h, r1, g1, b1, a1)
    end
end

local function mel_rectangle_outline(x, y, w, h, r, g, b, a, thickness, radius)
    if thickness == nil or thickness < 1 then
        thickness = 1
    end
    if radius == nil or radius < 0 then
        radius = 0
    end

    local limit = math.min(w * 0.5, h * 0.5) * 0.5
    thickness = math.min(limit / 0.5, thickness)

    local offset = 0
    if radius >= thickness then
        radius = math.min(limit + (limit - thickness), radius)
        offset = radius + thickness
    end

    if radius == 0 then
        renderer.rectangle(x + offset - 1, y, w - offset * 2 + 2, thickness, r, g, b, a)
        renderer.rectangle(x + offset - 1, y + h, w - offset * 2 + 2, -thickness, r, g, b, a)
    else
        renderer.rectangle(x + offset, y, w - offset * 2, thickness, r, g, b, a)
        renderer.rectangle(x + offset, y + h, w - offset * 2, -thickness, r, g, b, a)
    end

    local bounds = math.max(offset, thickness)
    renderer.rectangle(x, y + bounds, thickness, h - bounds * 2, r, g, b, a)
    renderer.rectangle(x + w, y + bounds, -thickness, h - bounds * 2, r, g, b, a)

    if radius == 0 or not renderer.circle_outline then
        return
    end

    renderer.circle_outline(x + offset, y + offset, r, g, b, a, offset, 180, 0.25, thickness)
    renderer.circle_outline(x + offset, y + h - offset, r, g, b, a, offset, 90, 0.25, thickness)
    renderer.circle_outline(x + w - offset, y + offset, r, g, b, a, offset, 270, 0.25, thickness)
    renderer.circle_outline(x + w - offset, y + h - offset, r, g, b, a, offset, 0, 0.25, thickness)
end

local function mel_inverse_lerp(a, b, weight)
    return (weight - a) / (b - a)
end

local function mel_outline_glow(x, y, w, h, r, g, b, a, thickness, radius)
    if thickness == nil or thickness < 1 then
        thickness = 1
    end
    if radius == nil or radius < 0 then
        radius = 0
    end

    local limit = math.min(w * 0.5, h * 0.5)
    radius = math.min(limit, radius)
    thickness = thickness + radius

    local rd = radius * 2
    x, y, w, h = x + radius - 1, y + radius - 1, w - rd + 2, h - rd + 2

    local factor = 1
    local step = mel_inverse_lerp(radius, thickness, radius + 1)

    for k = radius, thickness do
        local kd = k * 2
        local rounding = radius == 0 and radius or k
        mel_rectangle_outline(x - k, y - k, w + kd, h + kd, r, g, b, a * factor / 3, 1, rounding)
        factor = factor - step
    end
end

local function mel_fade_rounded_rect_notif(x, y, w, h, radius, r, g, b, a, glow, w1)
    local n = a / 15
    local width = w1 < 3 and 0 or w1
    local circ_fill = width > 5 and 0.25 or width / 150

    if renderer.circle_outline then
        renderer.circle_outline(x + radius, y + radius, r, g, b, a, radius, 180, circ_fill, 1)
        renderer.circle_outline(x + w - radius, y + h - radius, r, g, b, a, radius, 0, circ_fill, 1)
    end

    mel_gradient(x + radius - 2, y, width, 1, r, g, b, a, r, g, b, n, true)
    mel_gradient(x + w - width - radius + 2, y + h - 1, width, 1, r, g, b, n, r, g, b, a, true)

    mel_gradient(x + radius - 5, y + h / 2 - radius * 2 + 2, 1, width / 3.5, r, g, b, a, r, g, b, n, false)
    mel_gradient(x + w - 1, y - width / 3.5 - (radius - h) + 1, 1, width / 3.5, r, g, b, n, r, g, b, a, false)

    if a > 45 then
        mel_outline_glow(x, y, w, h, r, g, b, glow, 5, radius)
    end
end

render_melancholia_watermark = function(self, alpha)
    if alpha == nil or alpha <= 0 then return end
    alpha = math.clamp(alpha, 0, 1)
    local opacity = math.floor(255 * alpha + 0.5)
    if opacity < 10 then return end

    local wm = self.setting
    local ar, ag, ab = 80, 200, 180
    if menu.home and menu.home.colors and menu.home.colors.first then
        local ok, r, g, b = pcall(function() return menu.home.colors.first:get() end)
        if ok and r then ar, ag, ab = r, g, b end
    end

    local username = tostring(db.server.user or "user")
    local build    = tostring(db.server.version[1] or "v2.0")
    local hour, minute = client.system_time()
    local time_str = string.format("%02d:%02d", hour or 0, minute or 0)
    local fps_str  = string.format("%d fps", math.floor(1 / globals.frametime() + 0.5))

    local label = "Club"
    local info  = username .. "   " .. build .. "  " .. time_str .. "  " .. fps_str

    local lw, lh = renderer.measure_text("b", label)
    local tw, th = renderer.measure_text("", info)
    lw = lw or 0; tw = tw or 0; lh = lh or 12; th = th or 12

    local pad    = 14
    local gap    = 8
    local dot_r  = 4
    local dot_gap = 8
    local h      = math.max(lh, th) + 14
    local w      = pad + dot_r * 2 + dot_gap + lw + gap + tw + pad
    local radius = h / 2

    local screen_w, screen_h = client.screen_size()
    screen_w = screen_w or db.src.x
    screen_h = screen_h or db.src.y

    if not self.melancholia_init then
        self.x = screen_w - w - 12
        self.y = 8
        self.melancholia_init = true
    end

    local pos = (self.setting and self.setting.position and self.setting.position.get and self.setting.position:get()) or "Custom"
    local x, y
    if pos ~= "Custom" then
        x, y = resolve_watermark_position(self, w, h, self.x, self.y, false)
    else
        x, y = self.x, self.y
    end

    self:release(w, h)

    local a = opacity

    -- blur под pill
    pcall(function()
        surface.blur(x, y, w, h, 3)
    end)

    -- лёгкий glow — 3 слоя
    render.rect(x - 4, y - 4, w + 8, h + 8, {ar, ag, ab, math.floor(12 * alpha)}, radius + 4)
    render.rect(x - 2, y - 2, w + 4, h + 4, {ar, ag, ab, math.floor(18 * alpha)}, radius + 2)
    render.rect(x - 1, y - 1, w + 2, h + 2, {ar, ag, ab, math.floor(22 * alpha)}, radius + 1)

    -- фон почти прозрачный
    render.rect(x, y, w, h, {15, 17, 25, math.floor(60 * alpha)}, radius)

    -- тонкая граница
    render.rect(x, y, w, h, {255, 255, 255, math.floor(35 * alpha)}, radius)
    render.rect(x + 1, y + 1, w - 2, h - 2, {15, 17, 25, math.floor(60 * alpha)}, radius - 1)

    -- точка
    local dot_x = x + pad
    local dot_y = y + h / 2 - dot_r
    render.rect(dot_x, dot_y, dot_r * 2, dot_r * 2, {ar, ag, ab, math.floor(230 * alpha)}, dot_r)

    -- текст
    local ty_l = y + (h - lh) / 2
    local ty_t = y + (h - th) / 2
    local tx_l = dot_x + dot_r * 2 + dot_gap
    local tx_t = tx_l + lw + gap

    renderer.text(tx_l, ty_l, 255, 255, 255, a, "b", 0, label)

    local ia = math.floor(210 * alpha)
    local cur_x = tx_t

    -- ник
    local uw = renderer.measure_text("", username) or 0
    renderer.text(cur_x, ty_t, 185, 190, 200, ia, "", 0, username)
    cur_x = cur_x + uw + 8

    -- билд акцентным цветом
    local bw = renderer.measure_text("", build) or 0
    renderer.text(cur_x, ty_t, ar, ag, ab, ia, "", 0, build)
    cur_x = cur_x + bw + 6

    -- время + fps
    renderer.text(cur_x, ty_t, 185, 190, 200, ia, "", 0, time_str .. "  " .. fps_str)
end

paint.watermark.text = function(self, a, base_alpha)
    local base = base_alpha or (self.alpha or 1)
    local alpha = base * (1 - (a or 0))
    local style = self.setting.style and self.setting.style:get() or "Default"
    local screen_x, screen_y = client.screen_size()

    local function hsv_to_rgb(h, s, v)
        local c = v * s
        local x = c * (1 - math.abs((h / 60) % 2 - 1))
        local m = v - c
        local r, g, b = 0, 0, 0
        if h < 60 then r, g, b = c, x, 0
        elseif h < 120 then r, g, b = x, c, 0
        elseif h < 180 then r, g, b = 0, c, x
        elseif h < 240 then r, g, b = 0, x, c
        elseif h < 300 then r, g, b = x, 0, c
        else r, g, b = c, 0, x end
        return (r + m) * 255, (g + m) * 255, (b + m) * 255
    end

    local function utf8_chars(str)
        local chars = {}
        local i = 1
        local len = #str
        while i <= len do
            local c = str:byte(i)
            local char_len = 1
            if c and c >= 0xF0 then
                char_len = 4
            elseif c and c >= 0xE0 then
                char_len = 3
            elseif c and c >= 0xC0 then
                char_len = 2
            end
            table.insert(chars, str:sub(i, i + char_len - 1))
            i = i + char_len
        end
        return chars
    end

    local function rainbow_text(text, speed, saturation, dir)
        local result = {}
        local t = globals.curtime() * (speed or 1)
        local chars = utf8_chars(text)
        local len = #chars
        if len == 0 then
            return ""
        end
        for i = 1, len do
            local idx = dir == "Left" and (len - i) or (i - 1)
            local hue = (t * 50 + (idx / len) * 360) % 360
            local r, g, b = hsv_to_rgb(hue, (saturation or 0.9), 1)
            table.insert(result, clr.rgb(r, g, b, 255):hexa(true))
            table.insert(result, chars[i])
        end
        return table.concat(result)
    end

    local function parse_watermark_text(text)
        if not text or text == "" then
            return {prefix = "", body = "", postfix = ""}
        end
        local tmp = text
        tmp = tmp:gsub("prefix=", "\nP:"):gsub("body=", "\nB:"):gsub("postfix=", "\nS:")
        local parts = {prefix = "", body = "", postfix = ""}
        local has_tag = false
        for line in tmp:gmatch("[^\n]+") do
            local tag = line:sub(1, 2)
            if tag == "P:" then
                parts.prefix = line:sub(3):gsub("^%s+", "")
                has_tag = true
            elseif tag == "B:" then
                parts.body = line:sub(3):gsub("^%s+", "")
                has_tag = true
            elseif tag == "S:" then
                parts.postfix = line:sub(3):gsub("^%s+", "")
                has_tag = true
            elseif not has_tag then
                parts.body = line
            end
        end
        parts.has_markers = has_tag
        return parts
    end

    local function gradient_text(text, color1, color2, speed, dir)
        local result = {}
        local time = globals.curtime() * (speed or 1)
        local chars = utf8_chars(text)
        local len = #chars
        if len == 0 then
            return ""
        end
        for i = 1, len do
            local t = (i - 1) / math.max(1, len - 1)
            if dir == "Left" then
                t = 1 - t
            end
            local phase = math.abs(math.cos((t + time) * math.pi))
            local r = color1.r + (color2.r - color1.r) * phase
            local g = color1.g + (color2.g - color1.g) * phase
            local b = color1.b + (color2.b - color1.b) * phase
            table.insert(result, clr.rgb(r, g, b, 255):hexa(true))
            table.insert(result, chars[i])
        end
        return table.concat(result)
    end

    if style == "Modern" then
        local lp = entity.get_local_player()
        local user = sanitize_watermark_text(db.server.user or "user") or "user"
        local build = sanitize_watermark_text(db.server.version[1] or "Beta Acces") or "Beta Acces"

        local text1 = sanitize_watermark_text(db.name:upper() .. ".LUA") or "PRIORACLUB.LUA"
        local text2 = "user - " .. user .. "   [" .. build .. "]"
        local avatar_size = 32
        local text1_w, text1_h = renderer.measure_text("", text1)
        local text2_w, text2_h = renderer.measure_text("", text2)
        local text_start_offset = 39
        local block_w = text_start_offset + math.max(text1_w, text2_w)
        local block_h = math.max(avatar_size, text1_h + text2_h + 6)
        local base_x, base_y = resolve_watermark_position(self, block_w, block_h, 11, screen_y * 0.5 - 16, false)

        if lp then
            local steam = entity.get_steam64 and entity.get_steam64(lp) or nil
            local avatar = steam and pcall(function() return images.get_steam_avatar(steam) end) and images.get_steam_avatar(steam) or nil
            if avatar and avatar.contents and avatar.width and avatar.height then
                local ok, texture = pcall(renderer.load_rgba, avatar.contents, avatar.width, avatar.height)
                if ok and texture then
                    renderer.texture(_custom_avatar_tex or texture, base_x, base_y, avatar_size, avatar_size, 255, 255, 255, 255 * alpha, "f")
                end
            end
        end

        renderer.text(base_x + text_start_offset, base_y + 6, 255, 255, 255, 255 * alpha, "-", 0, text1)
        renderer.text(base_x + text_start_offset, base_y + 17, 255, 255, 255, 255 * alpha, "-", 0, text2)
        return
    end

    local font_flag = "c-"
    local text = db.name:upper()
    local tw, th = renderer.measure_text(font_flag, text)
    local x, y = resolve_watermark_position(self, tw, th, self.x, self.y, true)
    render.text(x, y, 255, 255, 255, 255 * alpha, font_flag, text)
end 


-- ============================================================
-- DYNAMIC GAP CROSSHAIR
-- ============================================================
paint.gap_crosshair = {
    gap     = 4,
    length  = 6,
    thick   = 1,
    alpha   = 1,
    _gap    = 4,
}

paint.gap_crosshair.update = function()
    local scoped = game.scope and game.scope.open or false
    local modern = menu.other.visuals.crosshair.type and menu.other.visuals.crosshair.type:get() == "modern"
    return game.alive and menu.other.visuals.crosshair.val:get() and not scoped and not modern
end

paint.gap_crosshair.paint = function(self)
    local sw, sh = client.screen_size()
    if not sw or not sh then return end

    local cx = math.floor(sw / 2)
    local cy = math.floor(sh / 2)

    -- calculate gap based on velocity + inaccuracy
    local vel    = game.velocity or 0
    local scoped = game.scope and game.scope.open or false
    local ducked = game.me and (entity.get_prop(game.me, "m_flDuckAmount") or 0) > 0.5 or false

    local base_gap = 4
    local vel_gap  = vel * 0.04
    local scope_gap = scoped and -2 or 0
    local duck_gap  = ducked and -1 or 0

    local target_gap = math.max(1, base_gap + vel_gap + scope_gap + duck_gap)

    -- smooth lerp
    self._gap = animate.lerp(self._gap or base_gap, target_gap, 12)
    local g = math.floor(self._gap)
    local l = self.length
    local t = self.thick

    -- get crosshair color from menu
    local cr, cg, cb, ca = 255, 255, 255, 220
    if menu.other.visuals.crosshair.colors and menu.other.visuals.crosshair.colors.first then
        cr, cg, cb, ca = menu.other.visuals.crosshair.colors.first:get()
    end
    local a = math.floor(ca * self.alpha)

    -- outline (black)
    local ot = t + 1
    renderer.rectangle(cx - g - l - 1, cy - ot,     l + 2, ot * 2, 0, 0, 0, a)  -- left
    renderer.rectangle(cx + g - 1,     cy - ot,     l + 2, ot * 2, 0, 0, 0, a)  -- right
    renderer.rectangle(cx - ot,        cy - g - l - 1, ot * 2, l + 2, 0, 0, 0, a)  -- top
    renderer.rectangle(cx - ot,        cy + g - 1,  ot * 2, l + 2, 0, 0, 0, a)  -- bottom

    -- lines
    renderer.rectangle(cx - g - l, cy - t, l, t * 2, cr, cg, cb, a)  -- left
    renderer.rectangle(cx + g,     cy - t, l, t * 2, cr, cg, cb, a)  -- right
    renderer.rectangle(cx - t, cy - g - l, t * 2, l, cr, cg, cb, a)  -- top
    renderer.rectangle(cx - t, cy + g,     t * 2, l, cr, cg, cb, a)  -- bottom

    -- center dot
    renderer.rectangle(cx - t, cy - t, t * 2, t * 2, cr, cg, cb, math.floor(a * 0.6))
end
-- ============================================================


-- ============================================================
-- 3D HITMARKER
-- ============================================================
local hm_bullet_impact = {}
local hm_queue = {}

callback.bullet_impact:set(function(e)
    if client.userid_to_entindex(e.userid) ~= entity.get_local_player() then return end
    table.insert(hm_bullet_impact, {e.x, e.y, e.z, globals.realtime()})
end)

callback.player_hurt:set(function(e)
    if not (menu.other.visuals.hitmarker and menu.other.visuals.hitmarker:get()) then return end
    local attacker = client.userid_to_entindex(e.attacker)
    if attacker ~= entity.get_local_player() then return end
    local victim = client.userid_to_entindex(e.userid)
    local duration = menu.other.visuals.hitmarker_duration:get()
    local vx, vy, vz = entity.get_prop(victim, "m_vecOrigin")
    if not vx then return end

    local best_dist = 100
    local bx, by, bz = vx, vy, (vz or 0) + 50
    for i = 1, #hm_bullet_impact do
        local bi = hm_bullet_impact[i]
        if bi[4] + duration >= math.floor(globals.realtime()) then
            local dx = vx - bi[1]
            local dy = vy - bi[2]
            local dz = (vz or 0) - bi[3]
            local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
            if dist < best_dist then
                best_dist = dist
                bx, by, bz = bi[1], bi[2], bi[3]
            end
        end
    end
    table.insert(hm_queue, {bx, by, bz, globals.realtime()})
    hm_bullet_impact = {}
end)

callback.round_start:set(function()
    hm_bullet_impact = {}
    hm_queue = {}
end)

local function render_hitmarker()
    if not (menu.other.visuals.hitmarker and menu.other.visuals.hitmarker:get()) then return end
    local now = globals.realtime()
    local duration = menu.other.visuals.hitmarker_duration:get()
    local size = menu.other.visuals.hitmarker_size:get()
    local cr, cg, cb, ca = menu.other.visuals.hitmarker_color:get()

    local i = 1
    while i <= #hm_queue do
        local hm = hm_queue[i]
        local age = now - hm[4]
        if age > duration then
            table.remove(hm_queue, i)
        else
            local x, y = renderer.world_to_screen(hm[1], hm[2], hm[3])
            if x and y then
                local fade = 1 - (age / duration)
                local a = math.floor(ca * fade)
                local s = size
                renderer.line(x - s*2, y - s*2, x - s, y - s, cr, cg, cb, a)
                renderer.line(x - s*2, y + s*2, x - s, y + s, cr, cg, cb, a)
                renderer.line(x + s*2, y + s*2, x + s, y + s, cr, cg, cb, a)
                renderer.line(x + s*2, y - s*2, x + s, y - s, cr, cg, cb, a)
            end
            i = i + 1
        end
    end
end
-- ============================================================

local function render_hud()
    local function draw_pill(x, y, w, h, r, g, b, a)
        local radius = math.floor(h / 2)
        renderer.rectangle(x + radius, y, w - radius * 2, h, r, g, b, a)
        renderer.circle(x + radius, y + radius, r, g, b, a, radius, 180, 0.25)
        renderer.circle(x + w - radius, y + radius, r, g, b, a, radius, 0, 0.25)
    end
    -- config notifications storage
    config_notify = config_notify or {}
    for _, item in pairs(paint) do
        if type(item) == "table" and item.update and item.paint then
            local ok, show = pcall(item.update, item)
            if ok and show then
                item.alpha = item.alpha or 1
                item:paint()
            end
        end
    end

    if menu.ragebot.predict_ind:get() and menu.ragebot.predict:get() then
        local r, g, b, a = menu.ragebot.predict_color:get()
        renderer.indicator(r, g, b, a, "PREDICT")
    end
    if menu.ragebot.hitchance_indicator:get() and menu.ragebot.hitchance_override_key:get() then
        renderer.indicator(255, 255, 255, 255, "HC OVR")
    end

    -- Bullet tracers
    if menu.other.visuals.tracer and menu.other.visuals.tracer:get() then
        local tr, tg, tb, ta = menu.other.visuals.tracer_color:get()
        for tick, data in pairs(tracer_queue) do
            if globals.curtime() <= data[7] then
                local x1, y1 = renderer.world_to_screen(data[1], data[2], data[3])
                local x2, y2 = renderer.world_to_screen(data[4], data[5], data[6])
                if x1 and x2 and y1 and y2 then
                    local age = 1 - math.clamp((globals.curtime() - (data[7] - 1.5)) / 1.5, 0, 1)
                    renderer.line(x1, y1, x2, y2, tr, tg, tb, math.floor(ta * age))
                end
            else
                tracer_queue[tick] = nil
            end
        end
    end

    -- Custom scope lines
    do
        local cs = menu.other.visuals.custom_scope
        if cs then
            local cs_enabled = cs:get()

            if cs_enabled then
                local me = entity.get_local_player()
                local act = false
                if me and entity.is_alive(me) then
                    local weapon = entity.get_player_weapon(me)
                    if weapon then
                        local scope_level = entity.get_prop(weapon, 'm_zoomLevel')
                        local scoped = entity.get_prop(me, 'm_bIsScoped') == 1
                        local resume_zoom = entity.get_prop(me, 'm_bResumeZoom') == 1
                        act = scope_level ~= nil and scope_level > 0 and scoped and not resume_zoom
                    end
                end

                local spd = math.max(2, menu.other.visuals.scope_speed:get())
                local target = act and 1 or 0
                scope_alpha = scope_alpha + (target - scope_alpha) * math.min(1, globals.frametime() * spd)

                if scope_alpha > 0.005 then
                    local width, height = client.screen_size()
                    local cr, cg, cb, ca = menu.other.visuals.scope_color:get()
                    local pos = menu.other.visuals.scope_position:get() * height / 1080
                    local off = menu.other.visuals.scope_offset:get() * height / 1080
                    local a = math.floor(ca * scope_alpha)
                    local cx = width / 2
                    local cy = height / 2

                    local inverted = menu.other.visuals.scope_invert and menu.other.visuals.scope_invert:get()
                    local exclude = menu.other.visuals.scope_exclude

                    local fa = inverted and 0 or a
                    local fb = inverted and a or 0

                    if not (exclude and exclude:get("Left")) then
                        renderer.gradient(cx - pos + 2, cy, pos - off, 1, cr, cg, cb, fb, cr, cg, cb, fa, true)
                    end
                    if not (exclude and exclude:get("Right")) then
                        renderer.gradient(cx - 2 + off, cy, pos - off, 1, cr, cg, cb, fa, cr, cg, cb, fb, true)
                    end
                    if not (exclude and exclude:get("Top")) then
                        renderer.gradient(cx, cy - pos + 2, 1, pos - off, cr, cg, cb, fb, cr, cg, cb, fa, false)
                    end
                    if not (exclude and exclude:get("Bottom")) then
                        renderer.gradient(cx, cy + off, 1, pos - off, cr, cg, cb, fa, cr, cg, cb, fb, false)
                    end
                end
            else
                scope_alpha = 0
            end
        end
    end

    render_hitmarker()

    if aimbot_logs_notify_enabled() then
        local style = (menu.other.visuals.aimbot_logs.style and menu.other.visuals.aimbot_logs.style:get()) or "Cards"
        render_log_notifications(aimbot_logs, "Minimal")
    end

    if config_notify and #config_notify > 0 then
        local screen_x, screen_y = client.screen_size()
        local now = globals.realtime()
        local i = 1
        while i <= #config_notify do
            local note = config_notify[i]
            local age = now - note.time
            -- instant appear
            if not note.alpha then note.alpha = 255 end
            -- fade out after 0.7s over 0.3s
            if age > 0.7 then
                note.alpha = note.alpha - globals.frametime() * 255 / 0.3
                if note.alpha < 0 then note.alpha = 0 end
            end

            if note.alpha > 2 then
                local text = tostring(note.text or "")
                local tw, th = renderer.measure_text("b", text)
                local pad = 12
                local w = tw + pad * 2
                local h = 22
                local x = screen_x / 2 - w / 2
                local y = screen_y * 0.45 - (i - 1) * (h + 4)
                local a = math.floor(note.alpha)
                local ga = math.floor(a * 0.15)
                render.rect(x - 4, y - 4, w + 8, h + 8, {20, 20, 20, ga}, 6)
                render.rect(x - 2, y - 2, w + 4, h + 4, {20, 20, 20, ga * 2}, 5)
                render.rect(x, y, w, h, {18, 18, 22, a}, 4)
                renderer.text(screen_x / 2, y + (h - th) / 2, 235, 235, 235, a, "bc", 0, text)
            end

            if note.alpha <= 2 then
                table.remove(config_notify, i)
            else
                i = i + 1
            end
        end
    end

end

local config = {
    schema = 2,
    update = {
        work = function(self)
            local info = menu.home.config.list()
            local names = self.names or {}

            if info == nil then
                return nil
            end

            local selected = names[info + 1]
            if not selected or selected == "-" then
                return nil
            end

            if menu.home.config.name.set then
                menu.home.config.name:set(selected)
            elseif menu.home.config.name.set_text then
                menu.home.config.name:set_text(selected)
            end

            return selected
        end,
        run = function(self)
            self.updating = true
            local names = {}
            local display_names = {}
            local configs = data.configs or {}

            local has_configs = next(configs) ~= nil

            if has_configs then
                for k, v in pairs(configs) do
                    table.insert(names, k)
                end
                table.sort(names, function(a, b)
                    return tostring(a):lower() < tostring(b):lower()
                end)
                self.names = names
                for i = 1, #names do
                    local name = tostring(names[i])
                    if name:lower() == DEFAULT_CFG_NAME then
                        display_names[i] = "\aFF3333FF" .. name .. "\aFFFFFFFF"
                    else
                        display_names[i] = name
                    end
                end
            else
                self.names = {}
                display_names = {}
                if menu.home.config.name.set then
                    menu.home.config.name:set("")
                elseif menu.home.config.name.set_text then
                    menu.home.config.name:set_text("")
                end
            end

            menu.home.config.list:update(has_configs and display_names or {"-"})

            if has_configs then
                self:work()
            end
            self.updating = false
        end
    }
}

function config:clone_value(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}
    for k, v in pairs(value) do
        copy[k] = self:clone_value(v)
    end
    return copy
end

function config:prune_payload(payload, schema)
    if type(payload) ~= "table" or type(schema) ~= "table" then
        return nil
    end

    local out = {}
    for k, v in pairs(payload) do
        if schema[k] ~= nil then
            if type(v) == "table" and type(schema[k]) == "table" then
                out[k] = self:prune_payload(v, schema[k])
            elseif type(v) == "number" or type(v) == "string" or type(v) == "boolean" then
                out[k] = v
            end
        end
    end
    return out
end

function config:merge_payload(schema, payload)
    if type(schema) ~= "table" then
        return schema
    end
    if type(payload) ~= "table" then
        return self:clone_value(schema)
    end

    local out = {}
    for k, v in pairs(schema) do
        if type(v) == "table" then
            out[k] = self:merge_payload(v, payload[k])
        else
            local pv = payload[k]
            if type(pv) == type(v) and pv ~= nil then
                out[k] = pv
            else
                out[k] = v
            end
        end
    end
    return out
end

function config:element_get(element)
    if type(element) ~= "table" or type(element.get) ~= "function" then
        return nil, false
    end
    local ok, value = pcall(element.get, element)
    if not ok then
        return nil, false
    end
    return self:clone_value(value), true
end

function config:element_set(element, value)
    if type(element) == "table" and type(element.set) == "function" then
        local ok = pcall(element.set, element, value)
        if ok then
            return true
        end

        if type(value) == "table" and #value > 0 and #value <= 4 then
            local ok_unpack = pcall(function()
                element:set(unpack(value))
            end)
            if ok_unpack then
                return true
            end
        end

        return false
    end
    if type(element) == "table" and type(element.set_text) == "function" then
        return pcall(element.set_text, element, tostring(value or ""))
    end
    return false
end

function config:collect_antiaim()
    local out = {settings = {}, builder = {}}
    if not (menu and menu.antiaim) then
        return out
    end

    for key, element in pairs(menu.antiaim) do
        if key ~= "builder" then
            if type(element) == "table" and type(element.get) == "function" and type(element.set) == "function" then
                local value, ok = self:element_get(element)
                if ok then
                    out.settings[key] = value
                end
            end
        end
    end

    for i, row in ipairs(menu.antiaim.builder or {}) do
        out.builder[i] = {}
        for key, element in pairs(row) do
            if type(element) == "table" and type(element.get) == "function" and type(element.set) == "function" then
                local value, ok = self:element_get(element)
                if ok then
                    out.builder[i][key] = value
                end
            end
        end
    end

    return out
end

function config:apply_antiaim(snapshot)
    if type(snapshot) ~= "table" or not (menu and menu.antiaim) then
        return
    end

    if type(snapshot.settings) == "table" then
        for key, value in pairs(snapshot.settings) do
            self:element_set(menu.antiaim[key], value)
        end
    end

    if type(snapshot.builder) == "table" and menu.antiaim.builder then
        for i, row in pairs(snapshot.builder) do
            local current = menu.antiaim.builder[i]
            if type(current) == "table" and type(row) == "table" then
                for key, value in pairs(row) do
                    self:element_set(current[key], value)
                end
            end
        end
    end
end

function config:migrate_pack(data_pack)
    if type(data_pack) ~= "table" then
        return nil
    end

    local migrated = {
        schema = tonumber(data_pack.schema) or 1,
        menu = data_pack.menu,
        positions = data_pack.positions,
        aa = data_pack.aa
    }

    if migrated.schema < 2 then
        migrated.schema = 2
        if migrated.aa == nil and type(data_pack.antiaim) == "table" then
            migrated.aa = data_pack.antiaim
        end
    end

    return migrated
end

do
    local config_targets = {menu.home, menu.other}

    if menu.ragebot then
        table.insert(config_targets, 2, menu.ragebot)
    end

    if antiaim_enabled and menu.antiaim then
        table.insert(config_targets, menu.antiaim)
    end

    config.last = pui.setup(config_targets)
end

function config:export(msg)
    local data_pack = {
        schema = self.schema,
        menu = self.last:save(),
        positions = draggable:export(),
        aa = self:collect_antiaim()
    }

    if not json or not json.stringify then
        console_print("Config export failed: json library not found.")
        return ""
    end

    local encrypted = base64.encode(json.stringify(data_pack))

    if msg then
        console_print("Config successfully exported!")
    end

    return encrypted
end

function config:import(encrypted, message)
    if not json or not json.parse then
        console_print("Config import failed: json library not found.")
        return false
    end

    local encoded = tostring(encrypted or ""):gsub("%s+", "")
    local decoded = base64.decode(encoded)
    if type(decoded) ~= "string" or decoded == "" then
        console_print("Config data invalid, try other!")
        return false
    end

    local success, parsed_pack = pcall(json.parse, decoded)
    if not success or type(parsed_pack) ~= "table" then
        console_print("Config data invalid, try other!")
        return false
    end

    local data_pack = self:migrate_pack(parsed_pack)
    if not data_pack then
        console_print("Config data invalid, try other!")
        return false
    end

    local menu_payload = data_pack.menu
    if type(menu_payload) ~= "table" and type(parsed_pack) == "table" then
        menu_payload = parsed_pack
    end
    if type(menu_payload) ~= "table" then
        console_print("Config data invalid, try other!")
        return false
    end

    if menu_payload then
        local ok = pcall(function()
            self.last:load(menu_payload)
        end)
        if not ok then
            local schema = self.last:save()
            local merged = self:merge_payload(schema, menu_payload)
            local ok_merged = merged and pcall(function()
                self.last:load(merged)
            end) or false
            if not ok_merged then
                local pruned = self:prune_payload(menu_payload, schema)
                local ok_pruned = pruned and pcall(function()
                    self.last:load(pruned)
                end) or false
                if not ok_pruned then
                    console_print("Config import failed: menu payload broken.")
                    return false
                end
            end
        end
    end
    if data_pack and data_pack.positions then
        draggable:import(data_pack.positions)
    end
    if data_pack and data_pack.aa then
        self:apply_antiaim(data_pack.aa)
    end

    client.delay_call(0, function()
        pcall(function()
            self.last:load(menu_payload)
        end)
        if data_pack and data_pack.aa then
            pcall(function()
                self:apply_antiaim(data_pack.aa)
            end)
        end
    end)

    if message then
        console_print("Config successfully imported!")
    end
    return true
end

function config:delete()
    local name = tostring(menu.home.config.name() or "")

    if name:match("%w") == nil then
        self.update:work()
        name = tostring(menu.home.config.name() or "")

        if name:match("%w") == nil then
            console_print("Please, select config for delete!")
            return false
        end
    end

    if name:lower() == DEFAULT_CFG_NAME then
        console_print("Config " .. name .. " is protected!")
        return false
    end

    local configs = data.configs or {}

    if configs[name] then
        configs[name] = nil
        data.configs = configs

        database.write(kate, data)
        console_print("Config "..name.." succsesfully deleted!")
        if not self.update_pending then
            self.update_pending = true
            client.delay_call(0, function()
                self.update_pending = false
                self.update:run()
            end)
        end
        return true
    else
        console_print("Config "..name.." not found!")
        return false
    end
end

function config:load()
    local name = tostring(menu.home.config.name() or "")

    if name:match("%w") == nil then
        console_print("Please, select config for load!")
        return false
    end

    local configs = data.configs or {}
    local packed = configs[name]
    if not packed then
        console_print("Config "..name.." not found!")
        return false
    end

    local loaded = self:import(packed, false)
    if loaded then
        console_print("Config "..name.." succsesfully loaded!")
    else
        console_print("Config "..name.." load failed!")
    end
    return loaded
end

function config:save()
    local name = tostring(menu.home.config.name() or "")

    if name:match("%w") == nil then
        console_print("Please, type other name for config")
        return false
    end

    if name:lower() == DEFAULT_CFG_NAME then
        console_print("Config " .. name .. " is protected!")
        return false
    end

    local exported = self:export()
    if exported == "" then
        console_print("Config save failed: export error.")
        return false
    end

    local configs = data.configs or {}
    configs[name] = exported

    data.configs = configs
    database.write(kate, data)
    console_print("Config "..name.." succsesfully saved!")
    return true
end

function config:press(func, ...)
    local success, result = pcall(self[func], self, ...)

    if not success then
        console_print("broken data value, [debug: " ..result.."]")
        return false
    end

    if not self.update_pending then
        self.update_pending = true
        client.delay_call(0, function()
            self.update_pending = false
            self.update:run()
        end)
    end

    return result ~= false
end

menu.home.config.list:set_callback(function()
    if config.update.updating then
        return
    end
    config.update:work()
end)

menu.home.config.export:set_callback(function()
    local crypted = config:export(true)
    if crypted ~= "" then
        clipboard.set(crypted)
        client.color_log(138, 43, 226, "[prioraclub] Config exported to clipboard.")
        table.insert(config_notify, {text = "Config exported to clipboard", time = globals.realtime(), beta = 0, add_y = 0})
    end
end)

menu.home.config.import:set_callback(function()
    if config:press("import", clipboard.get(), true) then
        client.color_log(138, 43, 226, "[prioraclub] Config imported.")
        table.insert(config_notify, {text = "Config imported", time = globals.realtime(), beta = 0, add_y = 0})
    else
        client.color_log(200, 80, 80, "[prioraclub] Config import failed.")
        table.insert(config_notify, {text = "Config import failed", time = globals.realtime(), beta = 0, add_y = 0})
    end
end)

menu.home.config.load:set_callback(function()
    if config:press("load") then
        client.color_log(138, 43, 226, "[prioraclub] Config loaded.")
        table.insert(config_notify, {text = "Config loaded", time = globals.realtime(), beta = 0, add_y = 0})
    else
        client.color_log(200, 80, 80, "[prioraclub] Config load failed.")
        table.insert(config_notify, {text = "Config load failed", time = globals.realtime(), beta = 0, add_y = 0})
    end
end)

menu.home.config.save:set_callback(function()
    if config:press("save") then
        client.color_log(138, 43, 226, "[prioraclub] Config saved.")
        table.insert(config_notify, {text = "Config saved", time = globals.realtime(), beta = 0, add_y = 0})
    else
        client.color_log(200, 80, 80, "[prioraclub] Config save failed.")
        table.insert(config_notify, {text = "Config save failed", time = globals.realtime(), beta = 0, add_y = 0})
    end
end)

menu.home.config.delete:set_callback(function()
    if config:press("delete") then
        client.color_log(200, 80, 80, "[prioraclub] Config deleted.")
        table.insert(config_notify, {text = "Config deleted", time = globals.realtime(), beta = 0, add_y = 0})
    else
        client.color_log(200, 80, 80, "[prioraclub] Config delete failed.")
        table.insert(config_notify, {text = "Config delete failed", time = globals.realtime(), beta = 0, add_y = 0})
    end
end)

-- delay init to ensure UI is fully loaded
client.delay_call(0.1, function()
    config.update:run()

if menu.home.other.discord_btn then
    menu.home.other.discord_btn:set_callback(function()
        -- try multiple methods to open URL
        pcall(function() client.exec("steam://openurl/https://discord.gg/dwfZUSr2") end)
        pcall(function() panorama.open().SteamOverlayAPI.OpenURL("https://discord.gg/dwfZUSr2") end)
        clipboard.set("https://discord.gg/dwfZUSr2")
        client.color_log(138, 43, 226, "[prioraclub] discord.gg/dwfZUSr2\n")
        table.insert(config_notify, {text = "discord.gg/dwfZUSr2 - link copied!", time = globals.realtime()})
    end)
end
    -- restore positions after load
    if data and data.positions then
        draggable:import(data.positions)
    end
    -- hide cloud again after config load

end)



-- Load preset from cloud

-- Upload preset to cloud

-- Delete preset from cloud

-- sync list selection to name textbox
-- ============================================================




-- Death trashtalk
local death_phrases = {
    "ððððð ðððððððð",
    "game frozen now?",
    "stop hunting me",
    "i was just lighting a cigarette",
    "dog suka",
    "skeet makes me sad",
    "lag? or just bad?",
    "nice resolver bro",
    "my grandma plays better",
    "delete ur paste",
    "PrioraClub > ur cheat",
    "ez pz lemon squeezy",
    "u got lucky",
    "skill issue",
    "touch grass",
    "uninstall csgo",
    "nice wallhack bro",
    "reported",
    "how much did that cost",
    "ur aim is like ur dad - missing",
    "i was afk",
}

local death_trash_last = 0

local function on_death_trashtalk(e)
    if not (menu.other.misc.trashtalk and menu.other.misc.trashtalk.val and menu.other.misc.trashtalk.val:get()) then return end
    if not menu.other.misc.trashtalk.mode:get("Death") then return end
    local victim = client.userid_to_entindex(e.userid)
    if victim ~= entity.get_local_player() then return end
    local now = globals.curtime()
    if now - death_trash_last < 3 then return end
    death_trash_last = now
    local phrase = death_phrases[math.random(1, #death_phrases)]
    client.delay_call(0.5, function()
        client.exec("say " .. phrase)
    end)
end

menu.other.misc.trashtalk.val:set_event("player_death", guarded_event(on_death_trashtalk))

callback.paint:set(function()
    helper.render()
    viewmodel_paint()
    render_hud()
end)

local function block_mouse_input()
    if pui.menu_open or draggable:is_dragging() or is_menu_interaction_active() then
        return true
    end
end

local menu_bind_lock = {active = false}
local function restore_mouse_binds()
    pcall(client.exec, "bind mouse1 +attack; bind mouse2 +attack2")
    menu_bind_lock.active = false
    if draggable and draggable.input_locked then
        draggable:unlock_input()
    end
end

callback.paint_ui:set(function()
    if not pui.menu_open then
        if menu_bind_lock.active then
            restore_mouse_binds()
        end
        return
    end

    if not menu_bind_lock.active then
        client.exec("bind mouse1 \"\"; bind mouse2 \"\"")
        menu_bind_lock.active = true
    end
end)

client.delay_call(0, function()
    client.set_event_callback("mouse_input", block_mouse_input)
end)

_G.OVERNIGHT_UNLOAD = function()
    -- save draggable positions before unload
    pcall(function()
        if data then
            data.positions = draggable:export()
            database.write(kate, data)
        end
    end)
    _G.OVERNIGHT_ENABLED = false
    restore_mouse_binds()
    if extra and extra.ragebot_overnight and extra.ragebot_overnight.on_shutdown then
        pcall(function()
            extra.ragebot_overnight:on_shutdown()
        end)
    end
    if extra and extra.hideshots_fix and extra.hideshots_fix.apply then
        pcall(function()
            extra.hideshots_fix:apply(false)
        end)
    end
    if hitchance_ref ~= nil then
        pcall(function()
            ui.set_visible(hitchance_ref, true)
        end)
    end
    if extra and extra.aspect_ratio and extra.aspect_ratio.apply then
        pcall(function()
            extra.aspect_ratio:apply(1)
        end)
    end
    if extra and extra.thirdperson and extra.thirdperson.reset then
        pcall(function()
            extra.thirdperson:reset()
        end)
    end
    if extra and extra.clantag then
        pcall(function()
            client.set_clan_tag()
            if refs and refs.misc and refs.misc.clantag then
                refs.misc.clantag:set_enabled(true)
                refs.misc.clantag:override()
            end
        end)
    end
    local events_to_unhook = {
        "aim_fire",
        "aim_hit",
        "aim_miss",
        "override_view",
        "paint",
        "paint_ui",
        "predict_command",
        "setup_command",
        "run_command",
        "net_update_end",
        "round_start",
        "player_connect_full",
        "player_death",
        "key_down",
        "player_hurt",
        "bullet_impact",
        "shutdown"
    }

    for i = 1, #events_to_unhook do
        local name = events_to_unhook[i]
        local handler = rawget(callback, name)
        if handler and handler.unhook then
            pcall(handler.unhook, handler)
        end
    end

    pcall(client.unset_event_callback, "mouse_input", block_mouse_input)
end

-- Trash Talk System Integration
local phrases = {
    "1",
    "Ну привет пидар",
    "эммм ну ты бот",
    "пв)",
    "хор",
    "ну что тут говорить",
    "ХАХАХАХАХХАХАХАХАХАХ",
    "куда ты так летишь бот",
    "ватафак",
    "ано",
    "what(что) are you(ты) doing(делаешь) dog(собака)??",
    "что",
    "крутая игра",
    "эмммм.... привет",
    "Диссоциативное расстройство",
    "адские пытки",
    "детские травмы",
    "LEGENDS NEVER DIE",
    "ебать я тя сфоткал в хед бомжа ебаного",
    "слᴇдовᴀтᴇль по дᴇлᴀм нᴇсовᴇᴘᴇшᴇнно лᴇтних",
    "ʏ кого ᴇсть нᴀстᴖойки нᴀ ᴀɪᴍ ᴛᴏᴏʟs скиньтᴇ в лс пожᴀлʏйстᴀ",
    "устрашающая игра",
    "host_timescale 0.1",
    "slowmo retard",
    "вот это вантап Oo",
    "школьный повор педофил (◣◢)",
    "u sell that hs???",
    "refund your spirtware nn $",
    "rifk7 bastard",
    "я ᴇбᴀᴧ ᴛʙᴏю ʍᴀᴛь [◣◢]",
    "спи нахуй пидораска)",
    "zukrass$$$",
    "phantom yaw boosted",
    "outlaw boost",
    "(◣◢)",
    "AWpKINGNeededSmoke $ ",
    "крутой кастом резик скачал на скит",
    "лабубушечка",
    "demon and angel ",
    "desyncdemon ◣◢",
    "пту",
    "дискотека",
    "demon inside me is the sk33thook",
    "rich school boyZ",
    "до конца скидок осталось всего пару часов",
    "следователь по делам несоверешнно летних",
    "скачать аватарку умный человек в очках",
    "мусульманки приватное",
    "пророк мухаммад саллаллаху алейхи вассалам",
    "у кого есть настройки на aim tools скиньте в лс пожалуйста",
    "крч добавьте картинки смешные в менюшку",
    "behehe mode:",
    "как дела?",
    "слив ангелвингс",
    "как пофиксить hardware mismatch",
    "стильный ник - сильная игра",
    "сергей",
    "MAXSENSE[BETA] RELEASED",
    "♚ ＴＯＲＥＴＴＯＧＡＮＧ ♚",
    "vk/avtopodborkazakhstan",
    "хахах просто легкий пидорас",
    "электрик пидарас",
    "хуем па ребрам тебе"
}

local trash_talk_enabled = true
local last_trash_time = 0
local trash_delay = 2.0

local function get_random_phrase()
    return phrases[math.random(1, #phrases)]
end

local function can_send_trash()
    if not trash_talk_enabled then
        return false
    end
    
    local current_time = globals.curtime()
    if current_time - last_trash_time < trash_delay then
        return false
    end
    
    return true
end

local function send_trash_message(message)
    if can_send_trash() and message and message ~= "" then
        client.execute("say " .. message)
        last_trash_time = globals.curtime()
    end
end

local function on_player_death(event)
    local attacker = event.userid
    local victim = event.userid_attacker
    
    if attacker == victim then
        return
    end
    
    local local_player = ent.get_local_player()
    if not local_player then
        return
    end
    
    local local_userid = ent.get_prop(local_player, "m_iUserID") or -1
    
    if attacker == local_userid then
        local victim_name = ent.get_prop(victim, "m_iName") or "someone"
        local message = get_random_phrase()
        if message ~= "" then
            send_trash_message(message)
        end
    end
end

local function on_key_down(event)
    if event.key == 84 then -- T key for manual trash talk
        local message = get_random_phrase()
        send_trash_message(message)
    end
end

-- Register event callbacks
callback.player_death:set(on_player_death)
callback.key_down:set(on_key_down)

-- Cleanup function
local function cleanup_trash_talk()
    if callback.player_death then
        callback.player_death:unset(on_player_death)
    end
    if callback.key_down then
        callback.key_down:unset(on_key_down)
    end
end

-- Register cleanup
if callback.shutdown then
    callback.shutdown:set(restore_mouse_binds)
    callback.shutdown:set(function()
        if extra.ragebot_overnight then
            extra.ragebot_overnight:on_shutdown()
        end
        cleanup_trash_talk()
    end)
end


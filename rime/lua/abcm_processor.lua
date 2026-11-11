local keywords = require "abcm_keywords"
local stroke = require "abcm_stroke"
local processor = {}

local kRejected = 0
local kAccepted = 1
local kNoop = 2

local cBackspace = 0xff08
local cTab = 0xff09
local cEnter = 0xff0d
local cEscape = 0xff1b
local cDelete = 0xffff
local cSpace = 0x20
local c_A = string.byte "a"
local c_Z = string.byte "z"

local function charset(str)
	local result = {}
	for c in str:gmatch "." do
		result[c] = true
	end
	return result
end

local setInitials = charset "abcdefghijklmnopqrstuvwxyzI"
local setAlphabet = charset "abcdefghijklmnopqrstuvwxyz12345678[]'"
local setNumber = stroke.numbers.i
local setNumberI = charset "iI"

local function print(...)
	log.warning(table.concat({...}, " "))
end

local function set_candidate(env, v)
	env.engine.context:set_property("abc_candidate", v)
	env.abc_candidate = v
end

local function switch_state(env, state)
	if state == "selecting" then
		set_candidate(env, "open")
	else
		set_candidate(env, "close")
	end
	env.abc_state = state
end

local function exit_to_ascii(env)
	local context = env.engine.context
	local raw = context.input
	switch_state(env, "initial")
	context:clear_non_confirmed_composition()
	env.engine:commit_text(raw)
	context:clear()
	context:set_option("ascii_mode", true)
	return kRejected
end

function processor.init(env)
	switch_state(env, "initial")
end

local function valid_char(keycode, set)
	if keycode <= cSpace or keycode > 0x7f then
		return
	end
	local c = string.char(keycode)
	return set[c] and c
end

local state = {}

local function push_initial(env, ctx, ch)
	if setNumberI[ch] then
		switch_state(env, "inumber")
	else
		switch_state(env, "edit")
	end
	ctx:push_input(ch)
	return kAccepted
end

local function refresh(env)
	local engine = env.engine
	engine:compose(engine.context)
end

function state.selecting(env, ctx, keycode)
	if not ctx:has_menu() then
		if keycode == cBackspace or
			keycode == cSpace or
			keycode == cEnter or
			keycode == cEscape then
			return kRejected
		end
	elseif keycode == cBackspace then
		local seg = ctx.composition:back()
		if seg then
			if env.abc_candidate == "open" then
				set_candidate(env, "one")
				local cand = seg:get_selected_candidate()
				if cand then
				    local preedit = cand.preedit
					if preedit:find "[%d']" then
						seg.status = "kVoid"
						refresh(env)
						return kAccepted
					end
				end
			end
		end
		if ctx:reopen_previous_segment() then
			return kAccepted
		end
		ctx:clear()
		switch_state(env, "initial")
		return kAccepted
	elseif keycode == cSpace then
		local r = ctx:confirm_current_selection()
		if not r then
			ctx:commit()
			ctx:clear()
			switch_state(env, "initial")
		else
			refresh(env)
			if not ctx:has_menu() then
				switch_state(env, "initial")
			end
		end
		return kAccepted
	elseif keycode == cEnter then
		ctx:clear_previous_segment()
		ctx:commit()
		ctx:clear()
		switch_state(env, "initial")
		return kAccepted
	elseif keycode == cEscape then
		switch_state(env, "initial")
		return kNoop
	end
	
	local current = valid_char(keycode, setInitials)
	if current then
		-- confirm and reset state
		if env.abc_candidate == "open" then
			ctx:confirm_current_selection()
		end
		if ctx:has_menu() then
			ctx:clear_previous_segment()
			ctx:commit()
			ctx:clear()
		end
		return push_initial(env, ctx, current)
	elseif keycode > cSpace and keycode <= 0x7f then
		switch_state(env, "initial")
		ctx:commit()
		ctx:clear()
		ctx:set_option("ascii_mode", true)
		return kRejected
	end
	return kNoop
end

local function ignore_key(env, keycode)
	if keycode > cSpace and keycode <= 0x7f then
		return exit_to_ascii(env)
	else
		return kNoop
	end
end

function state.initial(env, ctx, keycode)
	local current = valid_char(keycode, setInitials)
	if current then
		return push_initial(env, ctx, current)
	else
		return ignore_key(env, keycode)
	end
end

function state.edit(env, ctx, keycode)
	if keycode == cSpace then
		if keywords[ctx.input] then
			return exit_to_ascii(env)
		end
		local seg = ctx.composition:back()
		if seg then
			switch_state(env, "selecting")
			seg.status = "kVoid"
			refresh(env)
		end
		return kAccepted
	else
		local current = valid_char(keycode, setAlphabet)
		if current then
			ctx:push_input(current)
			return kAccepted
		else
			return ignore_key(env, keycode)
		end
	end
end

function state.inumber(env, ctx, keycode)
	if keycode == cSpace then
		if keywords[ctx.input] then
			return exit_to_ascii(env)
		end
		return kNoop
	end
	local current = valid_char(keycode, setNumber)
	if current then
		ctx:push_input(current)
		return kAccepted
	elseif keycode > cSpace and keycode <= 0x7f then
		return exit_to_ascii(env)
	else
		return ignore_key(env, keycode)
	end
end

function processor.func(key, env)
	if (key.modifier & ~1) ~= 0 then
		return kNoop
	end
	if env.abc_state ~= "initial" and not env.engine.context:is_composing() then
		switch_state(env, "initial")
	end
	return state[env.abc_state](env, env.engine.context, key.keycode)
end

return processor

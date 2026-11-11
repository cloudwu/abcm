local stroke = require "abcm_stroke"
local keywords = require "abcm_keywords"

local translator = {}

local dict
local candidate_state = "close"
local candidate_handler
local mem

local function print(...)
	log.warning(table.concat({...}, " "))
end

function translator.init(env)
	dict = Component.Translator(env.engine, "translator", "script_translator")
	candidate_handler = env.engine.context.property_update_notifier:connect(
		function(ctx, name)
			if name == "abc_candidate" then
				candidate_state = ctx:get_property(name)
			end
		end)
	mem = Memory (
		env.engine,
		env.engine.schema,
		"translator"
	)

	mem:memorize(function(commit)
		-- todo : user dict
		for i, entry in ipairs(commit:get()) do
--			print("Memorize", entry.text, tostring(entry.comment), tostring(entry.custom_code))
		end
		return true
	end)
end

function translator.fini(env)
	if candidate_handler then
		candidate_handler:disconnect()
		candidate_handler = nil
	end
	if mem then
		mem:disconnect()
	end
end

local function filter_pinyin(input)
	if input:find "%d" then
		return input:gsub("%d+",""), true
	else
		return input
	end
end

local function add_sep(preedit, input)
	local result = preedit:gsub("([^']+)('?)", function (s, sep)
		local ori = input:match(s .. "%d*")
		input = input:sub(#ori + 1)
		if ori == s then
			return s .. sep
		else
			return ori
		end
	end)
	return result
end

local function yield_cand(cand)
	if candidate_state == "one" then
		if cand.preedit:find "[%d'][a-z]" then
			return
		end
	end
	yield(cand)
end

local function filter_cand(pinyin, input, cand, start)
	local n = cand._end - cand._start
	if n ~= #pinyin then
		local pat = pinyin:sub(1, n):gsub(".", "%0%%d*")
		local s, e = input:find(pat)
		input = input:sub(1, e)
	end
	input = add_sep(cand.preedit, input)
	cand._start = start
	cand._end = #input + start
	cand.preedit = input
	yield_cand(cand)
end

function translator.func(input, seg, env)
	if candidate_state ~= "close" then
		local not_check = not (candidate_state == "open_first" or candidate_state == "open_last")
		local pinyin, has_strokes = filter_pinyin(input)
		local length = #pinyin
		local qseg = Segment(0, length)
		qseg.tags = seg.tags
		local r = dict:query(pinyin, qseg)
		if r then
			local start = seg._start
			if has_strokes then
				for cand in r:iter() do
					if not_check or (cand._end == length and cand.type ~= "sentence") then
						filter_cand(pinyin, input, cand, start)
					end
				end
			else
				for cand in r:iter() do
					if not_check or (cand._end == length and cand.type ~= "sentence") then
						cand._start = start
						cand._end = cand._end + start
						yield_cand(cand)
					end
				end
			end
		end
	elseif seg:has_tag "inumber" then
		if keywords[input] then
			return
		end
		local prefix = input:sub(1,1)
		local text = input:sub(2):gsub(".", stroke.numbers[prefix])
		local cand = Candidate("inumber", seg._start, seg._end, text, "")
		yield(cand)
	end
end

return translator

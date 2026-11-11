local stroke = require "abcm_stroke"
local cpattern = utf8.charpattern
local last_char = cpattern .. "$"
local first_comment = "(" .. cpattern .. ")(.*)"
local last_comment = "(.*)(" .. cpattern .. ")$"
local clut = stroke.hz

local filter = {}

local function print(...)
	log.warning(table.concat({...}, " "))
end

local candidate_state
local candidate_handler

function filter.init(env)
	candidate_handler = env.engine.context.property_update_notifier:connect(
		function(ctx, name)
			if name == "abc_candidate" then
				candidate_state = ctx:get_property(name)
			end
		end)
end

function filter.fini(env)
	if candidate_handler then
		candidate_handler:disconnect()
		candidate_handler = nil
	end
end

function filter.tags_match(seg, env)
	return seg:has_tag "abc"
end

local function match_stroke(cand)
	local pinyin = cand.preedit
	local hz = cand.text
	local s, e = 1
	local full_comment = ""
	for seg, code in pinyin:gmatch "([^%d']+)(%d*)" do
		local comment
		s, e = hz:find(cpattern, s)
		local ch = hz:sub(s,e)
		s = e + 1
		if code and code ~= "" then
			local full_code = clut[ch]
			if full_code then
				if full_code:find(code, 1, true) ~= 1 then
					return false
				end
				comment = full_code
			end
		else
			comment = clut[ch]
		end
		full_comment = full_comment .. (comment or "?") .. " "
	end
	return full_comment
end

local function filter_cand(cand)
	local comment = match_stroke(cand)
	if comment then
		local t = cand.text
		if candidate_state == "open_first" then
			return t:gsub(first_comment, "[%1]%2"), t:match(cpattern)
		elseif candidate_state == "open_last" then
			return t:gsub(last_comment, "%1[%2]"), t:match(last_char)
		else
			return comment, t
		end
	end
end

function filter.func(input, env)
	for cand in input:iter() do
		local comment, text = filter_cand(cand)
		if comment then
			local new_cand = ShadowCandidate(
				cand,
				cand.type,
				text,
				comment,
				false
			)
			yield(new_cand)
		end
    end
end

return filter

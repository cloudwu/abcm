local stroke = require "abcm_stroke"
local cpattern = utf8.charpattern
local clut = stroke.hz

local filter = {}

local function print(...)
	log.warning(table.concat({...}, " "))
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

function filter.func(input, env)
	for cand in input:iter() do
		local comment = match_stroke(cand)
		if comment then
			local new_cand = ShadowCandidate(
			    cand,
				cand.type,
	            cand.text,
		        comment,
			    false
	        )
			yield(new_cand)
		end
    end
end

return filter

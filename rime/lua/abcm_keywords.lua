local keywords = [[
and break do else elseif end false for function if in local global nil not or repeat return then true until while goto
dofile error loadfile loadstring require print assert
]]
local set = {}
for word in keywords:gmatch "%S+" do
	set[word] = true
end

return set
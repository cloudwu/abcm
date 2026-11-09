local processor = {}

function processor.init(env)
end

local kRejected = 0
local kAccepted = 1
local kNoop = 2

local cBackspace = 0xff08
local cTab = 0xff09
local cEnter = 0xff0d
local cEscape = 0xff1b
local cDelete = 0xffff
local cSpace = string.byte " "
local c_a = string.byte "a"
local c_z = string.byte "z"
local c_0 = string.byte "0"
local c_9 = string.byte "9"

function processor.func(key, env)
	local context = env.engine.context
	if not context:is_composing() then
		return kNoop
	end
	if key.modifier ~= 0  then
		return kNoop
	end
	
	local code = key.keycode
	if code >= c_0 and code <= c_9 then
		context:push_input(string.char(code))
		return kAccepted
	end
	
	return kNoop
end

return processor

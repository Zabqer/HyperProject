local term = {}
local thread = require("thread")

function term.read(options)
	if options.interactive == nil then options.interactive = true end
	if not options.interactive then
		return io.read("*l")
	end
	local input = options.input or io.input()
	term.blinkOn()
	local str = ""
	while true do
		local char = input:read(1)
		if not char then
			dprint("CLOSED")
			return nil
		elseif #str == 0 and char == "\x04" then
			dprint("EOT CHAR")
			return nil
		elseif char == "\n" then
			io.write(char)
			term.blinkOff()
			return str
		elseif char == "\b" then
			if unicode.len(str) > 0 then
				io.write(char)
				str = unicode.sub(str, 1, -2)
			end
		else
			io.write(hint or char)
			str = str .. char
		end
	end
end

function term.clear()
	writeControl("[2J")
end

function writeControl(code)
	io.write("\x1b" .. code)
end

function term.defaultFg()
	writeControl("[39m")
end

function term.lightredFg()
	writeControl("[91m")
end

function term.lightcyanFg()
	writeControl("[96m")
end

function term.lightgreenFg()
	writeControl("[92m")
end

function term.blinkOn()
	writeControl("?25h")
end

function term.blinkOff()
	writeControl("?25l")
end

return term

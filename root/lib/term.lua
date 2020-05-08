local term = {}

function term.read(_, hint)
	term.blinkOn()
	local str = ""
	while true do
		local char = io.read(1)
		if char == "\n" then
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

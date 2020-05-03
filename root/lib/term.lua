local term = {}

function term.read(_, hint)
	str = ""
	while true do
		local char = io.read(1)
		if char == "\n" then
			io.write(char)
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
	io.write("\x1b[2J")
end

function writeControl(code)
	io.write("\x1b[" .. code)
end

function term.defaultFg()
	writeControl("39m")
end

function term.lightredFg()
	writeControl("91m")
end

function term.lightcyanFg()
	writeControl("96m")
end

function term.lightgreenFg()
	writeControl("92m")
end

return term

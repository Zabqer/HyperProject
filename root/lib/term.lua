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
	local completions
	local compX, compY
	function resetCompletions()
		completions = nil
	end
	while true do
		local char = input:read(1)
		if not char then
			return nil
		elseif #str == 0 and char == "\x04" then
			return nil
		elseif char == "\t" and options.hint then
			-- TODO make completion like bash
			if not completions then
				completions = options.hint(str, #str + 1) or {}
			end
			if #completions > 1 then
				term.saveCursor()
				print()
				print(table.unpack(completions))
				term.restoreCursor()
			elseif #completions == 1 then
				local x = #str
				str = completions[1]
				io.write("\x1b[" .. (x) .. "D\x1b[K" .. completions[1])
			end
			-- local cur, completion = next(completions, lastCompletion)
			-- lastCompletion = cur
			-- if completion then
			-- 	local x = #str
			-- 	str = completion
			-- 	io.write("\x1b[" .. (x) .. "D\x1b[K" .. completion)
			-- end
		elseif char == "\n" then
			io.write(char)
			term.blinkOff()
			return str
		elseif char == "\b" then
			resetCompletions()
			if unicode.len(str) > 0 then
				io.write(char)
				str = unicode.sub(str, 1, -2)
			end
		else
			resetCompletions()
			io.write(hint or char)
			str = str .. char
		end
	end
end

function term.saveCursor()
	writeControl("[s")
end

function term.restoreCursor()
	writeControl("[u")
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

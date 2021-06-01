local term = {}
local thread = require("thread")

function term.read(options)
	if options.interactive == nil then options.interactive = true end
	if not options.interactive then
		return io.read("*l")
	end
	local history = options.history or {}
	local input = options.input or io.input()
	term.blinkOn()
	local str = ""
	local completions
	local compX, compY
	function resetCompletions()
		completions = nil
	end
	controlBuffer = ""
	local cx = 0
	local y = #history + 1
	while true do
		local char = input:read(1)
		if not char then
			return nil
		elseif #str == 0 and char == "\x04" then
			return nil
		elseif char == "\x1b" then
			controlBuffer = char
		elseif #controlBuffer > 0 then
			controlBuffer = controlBuffer .. char
			if controlBuffer == "\x1b[A" then -- history up
				controlBuffer = ""
				local x = #str
				y = y - 1
				if y < 1 then
					y = 1
				end
				str = history[y]
				cx = unicode.len(str)
				io.write("\x1b[" .. x .. "D\x1b[K" .. str)
			elseif controlBuffer == "\x1b[B" then
				controlBuffer = ""
				local x = #str
				y = y + 1
				if y > #history then
					y = #history
					if #str > 0 then
						str = ""
						cx = 0
						io.write("\x1b[" .. x .. "D\x1b[K" .. "")
					end
				else
					str = history[y]
					cx = unicode.len(str)
					io.write("\x1b[" .. x .. "D\x1b[K" .. str)
				end
			elseif controlBuffer == "\x1b[C" then
				controlBuffer = ""
				if unicode.len(str) > cx then
					cx = cx + 1
					io.write("\x1b[C")
				end
			elseif controlBuffer == "\x1b[D" then
				controlBuffer = ""
				if cx > 0 then
					cx = cx - 1
					io.write("\x1b[D")
				end
			end
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
			x = 0
			term.blinkOff()
			return str
		elseif char == "\b" then
			resetCompletions()
			local l = unicode.len(str)
			if l > 0 then
				if l == cx then
					io.write(char)
					str = unicode.sub(str, 1, -2)
					cx = cx - 1
				else
					local before = unicode.sub(str, 1, cx - 1)
					local after = unicode.sub(str, cx + 1)
					cx = cx - 1
					str = before .. after
					io.write("\x1b[D\x1b[K" .. after .. "\x1b[" .. unicode.len(after) .. "D")
				end
			end
		else
			resetCompletions()

			local l = unicode.len(str)
			if l == cx then
				io.write(hint or char)
				str = str .. char
				cx = cx + 1
			else
				local before = unicode.sub(str, 1, cx)
				local after = unicode.sub(str, cx + 1)
				str = before .. char .. after
				cx = cx + 1
				io.write("\x1b[K"..char..after.."\x1b["..unicode.len(after).."D")
			end
		end
	end
end

local readControl = function(to)
	local started, data
	local from = "\x1b"
	while true do
		local char = io.read(1)
		if not char then
			error("Broken pipe")
		end
		if not started and char == from then
			started = true
			data = char
		elseif started then
			if char == to then
				return data .. char
			else
				data = data .. char
			end
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

function term.reverse()
	writeControl("[7m")
end

function term.eraseEndOfLine()
	writeControl("[K")
end

function term.scrollDownAtY(y)
	writeControl("[" ..  y .. "sc")
end

function term.getCursorPosition()
	writeControl("[6n")
	local data = readControl("R")
	local x, y = data:match("\x1b%[(%d+);(%d+)R")
	return tonumber(x), tonumber(y)
end

function term.setCursorPosition(x, y)
	writeControl("[" .. x .. ";" .. y .. "H")
end

function term.getResolution()
	local x, y = term.getCursorPosition()
	term.setCursorPosition(999,999)
	local w, h = term.getCursorPosition()
	term.setCursorPosition(x, y)
	return tonumber(w), tonumber(h)
end

return term

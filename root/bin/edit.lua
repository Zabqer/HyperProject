local file = "/test"
local thread = require("thread")
local term = require("term")
local unicode = require("unicode")

thread.attach("interrupt", function ()
	term.clear()
	print("interrupt recived: exiting")
	os.exit(0)
end)

local w, h = term.getResolution()
term.blinkOn()

local cx, cy = 1, 1
local scroll = 1

function printInfo(text)
	term.setCursorPosition(1, h - 1)
	term.reverse()
	io.write("Editing: " .. file .. " line: " .. cy + scroll - 1 .. " column: " .. cx .. " " .. (text or ""))
	term.eraseEndOfLine()
	term.reverse()
	term.setCursorPosition(cx, cy)
end

local f = io.open(file, "r")

local buffer = {}
for s in f:read("*a"):gmatch("[^\r\n]+") do
    table.insert(buffer, s)
end

f:close()

function drawBuffer()
	term.clear()
	for i=scroll, scroll+math.min(#buffer, h - 2) do
		io.write(buffer[i])
		if unicode.len(buffer[i]) < w - 1 then
			term.reverse()
			io.write(" ")
			term.reverse()
		end
		io.write("\n")
	end
	printInfo()
end

drawBuffer()

local controlBuffer = ""
while true do
	local char = io.read(1)
	if not char then
		return nil
	elseif char == "\x1b" then
		controlBuffer = char
	elseif #controlBuffer > 0 then
		controlBuffer = controlBuffer .. char
		if controlBuffer == "\x1b[A" then
			controlBuffer = ""
			if cy > 0 then
				if cy - 1 < 1 then
					if scroll > 1 then
						scroll = scroll - 1
						drawBuffer()
					end
				else
					cy = cy - 1
					io.write("\x1b[A")
					if unicode.len(buffer[cy]) < cx then
						io.write("\x1b[" .. (cx - unicode.len(buffer[cy]) - 1) .. "D")
						cx = unicode.len(buffer[cy]) + 1
					end
					printInfo()
				end
			end
		elseif controlBuffer == "\x1b[B" then
			controlBuffer = ""
			if #buffer > cy then
				if cy + 1 > h - 2 then
					if scroll + cy < #buffer then
						scroll = scroll + 1
						drawBuffer()
					end
				else
					cy = cy + 1
					io.write("\x1b[B")
					if unicode.len(buffer[cy]) < cx then
						io.write("\x1b[" .. (cx - unicode.len(buffer[cy]) - 1) .. "D")
						cx = unicode.len(buffer[cy]) + 1
					end
					printInfo()
				end
			end
		elseif controlBuffer == "\x1b[C" then
			controlBuffer = ""
			if unicode.len(buffer[cy]) >= cx then
				cx = cx + 1
				io.write("\x1b[C")
				printInfo()
			end
		elseif controlBuffer == "\x1b[D" then
			controlBuffer = ""
			if cx > 1 then
				cx = cx - 1
				io.write("\x1b[D")
				printInfo()
			end
		elseif controlBuffer == "\x1bOH" then
			controlBuffer = ""
			cx = 1
			printInfo()
		elseif controlBuffer == "\x1bOF" then
			controlBuffer = ""
			cx = unicode.len(buffer[cy]) + 1
			printInfo()
		elseif controlBuffer == "\x1bOP" then
			local data = table.concat(buffer, "\n") 
			printInfo(#data .. " bytes saved...")
			local f = io.open(file, "w")
			f:write(data)
			f:close()
		elseif controlBuffer == "\x1bOQ" then
			drawBuffer()
		end
	elseif char == "\b" then
		if unicode.len(buffer[cy]) > 0 then
			local before = unicode.sub(buffer[cy], 1, cx - 2)
			local after = unicode.sub(buffer[cy], cx)
			cx = cx - 1
			buffer[cy] = before .. after
			io.write("\x1b[D\x1b[K" .. after .. "\x1b[" .. unicode.len(after) .. "D")
		end
	elseif char == "\n" then
		local before = unicode.sub(buffer[cy], 1, cx - 1)
		local after = unicode.sub(buffer[cy], cx)
		buffer[cy] = before
		table.insert(buffer, cy + 1, after)
		io.write("\x1b[K")
		cx = 0
		cy = cy + 1
		term.scrollDownAtY(cy)
		--printInfo()
		drawBuffer()
		-- Need to test this in mine
	else
		local before = unicode.sub(buffer[cy], 1, cx)
		local after = unicode.sub(buffer[cy], cx + 1)
		buffer[cy] = before .. char .. after
		cx = cx + 1
		io.write("\x1b[K"..char..after.."\x1b["..unicode.len(after).."D")

	end
end




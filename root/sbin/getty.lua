

local input = io.input()
local thread = require("thread")

local gpu, screen = ...
-- Maybe move to component.proxy?

cx = 1
cy = 1
scx = 1
scy = 1

component.invoke(gpu, "bind", screen)

local w, h = component.invoke(gpu, "maxResolution")

deffg = 0xFFFFFF
defbg = 0x000000

fg = deffg
bg = defbg

component.invoke(gpu, "setResolution", w, h)

component.invoke(gpu, "setForeground", fg)
component.invoke(gpu, "setBackground", bg)

component.invoke(gpu, "fill", 1, 1, w, h, " ")

blinking = false
blinked = false

function swapCursor()
	local c, f, b = component.invoke(gpu, "get", cx, cy)
	local oribg, obpal = component.invoke(gpu, "setBackground", f)
	local orifg, ofpal = component.invoke(gpu, "setForeground", b)
	component.invoke(gpu, "set", cx, cy, c)
	component.invoke(gpu, "setBackground", oribg)
	component.invoke(gpu, "setForeground", orifg)
end

function drawCursor()
	if not blinked then
		swapCursor()
		blinked = true
	end
end

function unDrawCursor()
	if blinked then
		swapCursor()
		blinked = false
	end
end

function scroll()
	cx = 1
	cy = cy + 1
	if cy > h then
		cy = h
		component.invoke(gpu, "copy", 1, 2, w, h, 0, -1)
		component.invoke(gpu, "fill", 1, h, w, 1, " ")
	end
end

function checkCord()
	if cx > w then cx = 1 end
	if cy > h then cy = h end
end

function setFgColor(col)
	fg = col
	component.invoke(gpu, "setForeground", col)
end

function setBgColor(col)
	bg = col
	component.invoke(gpu, "setBackground", col)
end

controlBuffer = ""
controls = {
	[{"%[", "[%d;]*", "m"}] = function(_, codes)
		codes = tonumber(codes)
		local colors = {
			0x000000,
			0xff0000,
			0x00ff00,
			0xffff00,
			0x0000ff,
			0xff00ff,
			0x00B6ff,
			0xffffff
		}
		if codes == 0 then
			setFgColor(deffg)
		elseif codes == 7 then
			local f, b = fg, bg
			setFgColor(b)
			setBgColor(f)
		elseif codes >= 30 and codes <= 37 then
			setFgColor(colors[codes - 29])
		elseif codes == 39 then
			setFgColor(deffg)
		elseif codes >= 90 and codes <= 97 then
			setFgColor(colors[codes - 89])
		end
	end,
	[{"%?25", "[hl]"}] = function (_, t)
		if t == "h" then
			blinking = true
		else
			blinking = false
		end
	end,
	[{"%[", "%d*", "A"}] = function (_, n)
		cy = cy - (tonumber(n) or 1)
		checkCord()
	end,
	[{"%[", "%d*", "B"}] = function (_, n)
		cy = cy + (tonumber(n) or 1)
		checkCord()
	end,
	[{"%[", "%d*", "D"}] = function (_, n)
		cx = cx - (tonumber(n) or 1)
		checkCord()
	end,
	[{"%[", "%d*", "C"}] = function (_, n)
		cx = cx + (tonumber(n) or 1)
		checkCord()
	end,
	[{"%[K"}] = function ()
		component.invoke(gpu, "fill", cx, cy, w - cx + 1, 1, " ")
	end,
	[{"%[", "[su]"}] = function (_, t)
		if t == "s" then
			scx = cx
			scy = cy
		else
			cx = scx
			cy = scy
		end
	end,
	[{"%[", "%d+", ";", "%d+", "H"}] = function (_, x, _, y)
		cx = math.max(1, math.min(w, tonumber(x)))
		cy = math.max(1, math.min(h, tonumber(y)))
		checkCord()
	end,
	[{"%[6n"}] = function ()
		io.write("\x1b[" .. cx .. ";" .. cy .. "R")
	end,
	[{"%[2J"}] = function()
		cx, cy = 1, 1
		component.invoke(gpu, "fill", 1, 1, w, h, " ")
	end,
	-- Custom
	[{"%[", "%d+", "sc"}] = function (_, y)
		y = tonumber(y) or 0
		component.invoke(gpu, "copy", 1, y, w, h - 1, 0, 1)
	end
}

function getControlAction(text)
	for r, a in pairs(controls) do
		local captures = {}
		local last_index = 0
		for _, pattern in pairs(r) do
			local s, e, capture = text:find("^(" .. pattern .. ")", last_index + 1)
			if not s then
				break
			end
			table.insert(captures, capture)
			last_index = e
		end
		if #captures == #r then
			a(table.unpack(captures))
			return true
		end
	end
	return false
end

local pBuffer = ""

function printBuffer()
	if #pBuffer == 0 then return end
	while unicode.len(pBuffer) + cx > w do
		local l = unicode.wtrunc(pBuffer, w - cx)
		dprint(l)
		component.invoke(gpu, "set", cx, cy, l)
		pBuffer = unicode.sub(pBuffer, w - cx)
		scroll()
	end
	if #pBuffer > 0 then
		component.invoke(gpu, "set", cx, cy, pBuffer)
		cx = cx + unicode.len(pBuffer)
		pBuffer = ""
	end
end

local function handle(c)
	if c == "\n" then
		printBuffer()
		scroll()
		checkCord()
	elseif c == "\t" then
		printBuffer()
		cx = cx + 4
		checkCord()
	elseif c == "\b" then
		cx = cx - 1
		component.invoke(gpu, "set", cx, cy, " ")
		checkCord()
	elseif c == "\x1b" then
		printBuffer()
		isControl = not isControl
		controlBuffer = ""
	elseif isControl then
		local f = getControlAction(controlBuffer .. c)
		if f then
			isControl = false
			controlBuffer = ""
			printBuffer()
		else
			controlBuffer = controlBuffer .. c
		end
	else
		pBuffer = pBuffer .. c
	end
end

blinker = thread.createThread(function()
	while true do
		if blinking then
			swapCursor()
			blinked = not blinked
		end
		os.sleep(1)
	end
end, "blink timer")


while true do
	local data = input:read("*b")
	unDrawCursor()
	for c in data:gmatch(".") do
		handle(c)
	end
	printBuffer()
	drawCursor()
end


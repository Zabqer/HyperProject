

local input = io.input()
local output = io.output()
local event = require("event")
local thread = require("thread")

local gpu, screen, keyboard = ...

cx = 1
cy = 1

w = 80
h = 25

deffg = 0xFFFFFF
defbg = 0x000000

fg = deffg
bg = defbg

component.invoke(gpu, "bind", screen)

component.invoke(gpu, "setForeground", fg)
component.invoke(gpu, "setBackground", bg)

component.invoke(gpu, "fill", 1, 1, w, h, " ")

blinked = true

function unblink()
	if blinked then
		blink()
	end
end

function blink()
	blinked = not blinked
	local c, f, b = component.invoke(gpu, "get", cx, cy)
        local oribg, obpal = component.invoke(gpu, "setBackground", f)
        local orifg, ofpal = component.invoke(gpu, "setForeground", b)
        component.invoke(gpu, "set", cx, cy, c)
        component.invoke(gpu, "setBackground", oribg)
        component.invoke(gpu, "setForeground", orifg)
end

function scroll()
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

controlBuffer = ""
controls = {
	["[91m"] = function()
		fg = 0xFF0000
		component.invoke(gpu, "setForeground", fg)
	end,
	["[39m"] = function()
		fg = deffg
                component.invoke(gpu, "setForeground", fg)
	end,
	["[92m"] = function()
		fg = 0x00FF00
                component.invoke(gpu, "setForeground", fg)
	end,
	["[96m"] = function()
		fg = 0x00FFFF
                component.invoke(gpu, "setForeground", fg)
	end,
	["[2J"] = function()
		cx, cy = 1, 1
		component.invoke(gpu, "fill", 1, 1, w, h, " ")
		dprint("CLEAR!")
	end
}

local function handle(c)
	if c == "\n" then
		unblink()
		component.invoke(gpu, "set", cx, cy, " ")
		cx = 1
		cy = cy + 1
		scroll()
		checkCord()
	elseif c == "\t" then
		component.invoke(gpu, "set", cx, cy, " ")
		cx = cx + 4
		checkCord()
	elseif c == "\b" then
		unblink()
		-- Stupid hack. Fix that
		if cx <= w then
			component.invoke(gpu, "set", cx, cy, " ")
		end
		cx = cx - 1
		component.invoke(gpu, "set", cx, cy, " ")
		blink()
		checkCord()
	elseif c == "\x1b" then
		isControl = not isControl
		controlBuffer = ""
	elseif isControl then
		if controls[controlBuffer .. c] then
			controls[controlBuffer .. c]()
			isControl = false
			controlBuffer = ""
		else
			controlBuffer = controlBuffer .. c
		end
	else
		if cx + 1 > w then
			cx = 1
			cy = cy + 1
		end
		component.invoke(gpu, "set", cx, cy, c)
		cx = cx + 1
		checkCord()
	end
end

event.on("key_down", function(_, address, char, code)
	if address ~= keyboard then return end
	if char == 13 then char = 10 end
	if char ~= 0 and char ~= 127 then 
        	output:write(unicode.char(char))
	else
	        if code == 200 then output:write("\x1b[A")
	        elseif code == 208 then ouput:write("\x1b[B")
	        elseif code == 205 then output:write("\x1b[C")
	        elseif code == 203 then output:write("\x1b[D")
		end
    	end
end)

blinker = thread.createThread(function()
	while true do
		blink()
		os.sleep(1)
	end
end, "blink timer")


while true do
	local c = input:read(1)
	handle(c)
end


print("Initializing...")

local event = require("event")
local thread = require("thread")

screen = component.list("screen")
gpu = component.list("gpu")

os.setenv("HOSTNAME", "myhost")


free_gpus = {}
free_screens = {}

os.setenv("PATH", "/bin/?.lua")

local i = 0

function createTty(gpu, screen)
	--pi, po = io.pts()
	local o1, i1 = io.pipe()
	local o2, i2 = io.pipe()
	keyboard = component.invoke(screen, "getKeyboards")[1]
	getty, reason = thread.createProcess("/sbin/getty.lua", _, gpu, screen, keyboard)
	if not getty then
		error(reason)
	end
	local io = getty.IO()
	io.stdin = i1
	io.stdout = o2
	getty:run()
	login, reason = thread.createProcess("/sbin/login.lua", _, i)
	i = i + 1
	if not sh then
	--	error(reason)
	end
	io = login.IO()
	io.stdin = i2
	io.stdout = o1
	login:run()
end

function eventHandler(_, address, type)
	if type == "gpu" then
		if #free_screens > 0 then
			local screen = table.remove(free_screens, 1)
			createTty(address, screen)
		else
			table.insert(free_gpus, address)
		end
	elseif type == "screen" then
		if #free_gpus > 0 then
			local gpu = table.remove(free_gpus, 1)
			createTty(gpu, address)
		else
			table.insert(free_screens, address)
		end
	end
end

event.on("component_added", eventHandler)
for address, ctype in component.list() do
    eventHandler(_, address, ctype)
end

os.sleep(9999999999999)

print("Initializing...")

local event = require("event")
local thread = require("thread")
local filesystem = require("filesystem")

os.setenv("HOSTNAME", "myhost")


free_gpus = {}
free_screens = {}

os.setenv("PATH", "/bin/?.lua")

local i = 0

function createTty(gpu, screen)
	local master, slave = os.pty()

	local keyboard = component.invoke(screen, "getKeyboards")[1]
	local rk = assert(thread.createProcess({
		exe = "/sbin/readkey.lua",
		args = {keyboard},
		stdout = master
	}))

	local gt = assert(thread.createProcess({
		exe = "/sbin/getty.lua",
		args = {gpu, screen},
		stdin = master
	}))
	
	-- slave.index()
	local l = assert(thread.createProcess({
		exe = "/sbin/login.lua",
		tty = slave
	}))

	rk:run()
	gt:run()
	l:run()

--	l:join()

	--pi, po = io.pts()
	-- local o1, i1 = io.pipe()
	-- local o2, i2 = io.pipe()
	-- keyboard = component.invoke(screen, "getKeyboards")[1]
	-- -- TODO maybe combine readkey and getty?
	-- readkey, reason = thread.createProcess("/sbin/readkey.lua", _, keyboard)
	-- if not readkey then
	-- 	error(reason)
	-- end
	-- local io = readkey.IO()
	-- io.stdout = o2
	-- readkey:run()
	-- getty, reason = thread.createProcess("/sbin/getty.lua", _, gpu, screen)
	-- if not getty then
	-- 	error(reason)
	-- end
	-- io = getty.IO()
	-- io.stdin = i1
	-- getty:run()
	-- login, reason = thread.createProcess("/sbin/login.lua", _, i)
	-- i = i + 1
	-- if not sh then
	-- --	error(reason)
	-- end
	-- io = login.IO()
	-- io.stdin = i2
	-- io.stdout = o1
	-- login:run()
end
--TODO handle component remove
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
	-- TODO remove later
	-- computer.pushSignal("component_added", address, ctype)
    eventHandler(_, address, ctype)
end
os.sleep(1)
--TODO replace os sleep
os.sleep(9999999999999)

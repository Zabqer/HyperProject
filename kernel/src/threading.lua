--[[
		Name: threading;
		Depends: [utils];
		Description: Provides thread control methods;
]]--

kernelThread = {
	name = "kernel",
	deadline = 0,
}

thisThread = kernelThread

local nextPID, nextUID = 1, 1

function allocateIds()
	local pid, uid = nextPID, nextUID
	nextUID = nextUID + 1
	repeat
		nextPID = nextPID + 1
	until not threads[nextPID]
	return pid, uid
end

threads = {}
processes = {}

function createProcess(f, name, parent, user, paused, ...)
	local process = {
		name = name,
		processes = {},
		threads = {},
		parent = parent,
		user = user,
		handlers = {},
		workingDirectory = "/",
		terminal = parent and parent.terminal,
		envvar = parent and setmetatable({}, {__index=parent.envvar}) or {}
	}
	if parent then
		table.insert(parent.processes, process)
	end
	local th, reason = createThread(f, name, process, paused, ...)
	if not th then
		return nil, reason
	end
	process.pid = process.thread.pid
	process.uid = process.thread.uid
	processes[process.pid] = process
	kernelLog(Log.DEBUG, "Created process pid:", process.pid, "name:", process.name)
	return process
end

function createThread(f, name, process, paused, ...)
	local thread = {
		name = name or "unknown",
		running = false,
		paused = paused or false,
		process = process,
		deadline = computer.uptime(),
		eventQueue = {{"args", ...}},
		awaiting = "args"
	}
	thread.coroutine = coroutine.create(function (...)
		local args = table.pack(...)
		local result = table.pack(xpcall(function()
			f(table.unpack(args))
		end, function(msg)
			msg = msg or "unknown"
			kernelLog(Log.INFO, "Error in thread [pid: " .. thread.pid .. "]: " .. msg)
			kernelLog(Log.INFO, debug.traceback())
			if thread.process.stderr then
					thread.process.stderr:write("Error in thread [pid: " .. thread.pid .. "]: " .. msg .. "\n")
					thread.process.stderr:write(debug.traceback() .. "\n")
			end
		end))
		return table.unpack(result, 2)
	end)
	if not process.thread then
		process.thread = thread
	else
		table.insert(process.threads, thread)
	end
	thread.pid, thread.uid = allocateIds()
	threads[thread.pid] = thread
	kernelLog(Log.DEBUG, "Created thread pid:", thread.pid, "name:", thread.name, "run:", not paused)
	return thread
end

-- TODO scheduler will call thread callbacks in thread environment when next thread resume!!!

function kill(pid)
	-- TODO close process fd
	local thread = threads[pid]
 	kernelLog(Log.DEBUG, "Killed", thread.process.thread == thread and "process" or "thread", "pid:", thread.pid, "name:", thread.name)
	if thread.process.thread == thread then
		for _, th in pairs(thread.process.threads) do
			kill(th.pid)
		end
		for _, p in pairs(thread.process.processes) do
			kill(th.pid)
		end
		processes[pid] = nil
		if thread.process.parent then
			local index
			for i, p in pairs(thread.process.parent.processes) do
				if p.pid == pid then
					index = i
				end
			end
			table.remove(thread.process.parent.processes, index)
		end
	else
		local index
		for i, th in pairs(thread.process.threads) do
			if th.pid == pid then
				index = i
			end
		end
		table.remove(thread.process.threads, index)
	end
	if pid < nextPID then
		nextPID = pid
	end
	pushEvent("kill", pid)
	threads[pid] = nil
end

function pushEvent(name, ...)
	for _, thread in pairs(threads) do
		if thread.awaiting == name then
			table.insert(thread.eventQueue, table.pack(name, ...))
		end
	end
end

function waitEvent(name, ...)
	if thisThread == kernelThread then
		panic("Attempt to wait event from kernel thread")
	end
	return coroutine.yield(name, ...)
end

local eventHandlers = {}

function addKenrelEventHandler(data, callback)
	kernelLog(Log.DEBUG, "Registered kernel event handler for", table.unpack(data))
	table.insert(eventHandlers, {
		data = data,
		callback = callback
	})
end

local libthread = {}

function libthread.onSignal(sig, callback)
	thisThread.process.handlers[sig] = callback
end

processMethods = {}
local iosMethods = {}

function processMethods:info()
	local childs = {}
	for _, th in pairs(self.process.threads) do
		table.insert(childs, th.pid)
	end
	for _, p in pairs(self.process.processes) do
		table.insert(childs, p.pid)
	end
	return protectTable({
		pid = self.process.pid,
		name = self.process.name,
		user = self.process.user,
		childs = childs,
		process = true
	}, true, false)
end

function processMethods:IO()
	return setmetatable({}, {
		__index = function (_, key)
			if key == "stdout" then
				return self.process.stdout
			elseif key == "stdin" then
				return self.process.stdin
			elseif key == "stderr" then
				return self.process.stderr
			end
			return nil
		end,
		__newindex = function (_, key, value)
			if type(value) ~= "Stream" then
				error("Not a stream")
				return
			end
			if key == "stdout" then
				self.process.stdout = value
			elseif key == "stdin" then
				self.process.stdin = value
			elseif key == "stderr" then
				self.process.stderr = value
			end
		end
	})
end

function processMethods:run()
	kernelLog(Log.DEBUG, "Process run pid:", self.process.pid, "name:", self.process.name)
	self.process.thread.paused = false
	for _, th in pairs(self.process.threads) do
		th.paused = false
	end
end

function processMethods:join()
	waitEvent("kill", self.process.pid)
end

-- TODO delay to scheduler

function sendSignal(process, sig)
	if process.handlers[sig] then
		local prevTh = thisThread
		thisThread = process.thread
		-- TODO pcall handler
		process.handlers[sig]()
		thisThread = prevTh
	end
end

function processMethods:signal(sig)
	local allowed = {"kill", "interrupt"}
	for _, a in ipairs(allowed) do
		if a == sig then
			if a == "kill" then
				kill(self.process.pid)
			else
				sendSignal(self.process, sig)
			end
			return true
		end
	end
	return false, "unknown signal"
end

local threadMethods = {}

function threadMethods:info()
	return protectTable({
		pid = self.thread.pid,
		name = self.thread.name,
		process = false
	}, true, false)
end

function libthread.createProcess(options)
	-- TODO check args
	if type(options.exe) == "string" then
		options.name = options.name or options.exe
		local reason
		options.exe, reason = loadfile(options.exe)
		if not options.exe then
			return nil, reason
		end
	end
	local process = createProcess(options.exe, options.name, thisThread.process, thisThread.process.user, true, table.unpack(options.args or {}))
	if options.tty then
		process.terminal = options.tty
		ptys[tostring(options.tty.index())].slave.process = process
	end
	process.stdin = options.stdin or options.tty
	process.stdout = options.stdout or options.tty
	process.stderr = options.stderr or options.tty
	return protectObject({
		process = process
	}, processMethods, "Process")
end

function os.getpid()
	return thisThread.pid
end

function libthread.thisProcess()
	return protectObject({
		process = thisThread.process
	}, processMethods, "Process")
end

function libthread.createThread(f, name, ...)
	checkArg(1, f, "function")
	local th = createThread(f, name, thisThread.process, false, ...)
end

function libthread.byPid(pid)
	checkArg(1, pid, "number")
	if processes[pid] then
		return protectObject({
			process = processes[pid]
		}, processMethods, "Process")
	end
	if threads[pid] then
		return protectObject({
			thread = threads[pid]
		}, threadMethods, "Thread")
	end
	return nil, "no such process"
end

libs.thread = libthread

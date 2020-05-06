--[[
		Name: main;
		Description: Kernel entry point;
]]--

--[[
______  __                           _______________
___  / / /____  _______________________  __ \_  ___/
__  /_/ /__  / / /__  __ \  _ \_  ___/  / / /____ \ 
_  __  / _  /_/ /__  /_/ /  __/  /   / /_/ /____/ / 
/_/ /_/  _\__, / _  .___/\___//_/    \____/ /____/  
         /____/  /_/                                
                      Maded by Zabqer with love
]]--

KernelVersion = "0.0.0.1"

GLOBAL._OSVERSION = "HyperKernel " .. KernelVersion

function panic(str)
	kernelLog(Log.ERROR, "Kernel panic: " .. str)
	while true do computer.pullSignal(1) end
end


function main(...)
		kernelLog(Log.DEBUG, "[main] Starting kernel")
		kernelLog(Log.INFO, "HyperKernel / " .. KernelVersion .. " / Zabqer")
		kernelLog(Log.INFO, "[main] Mounting root filesystem")
		success, reason = filesystem.mount("/", computer.getBootAddress())
		if not success then
			panic(reason)
		end
		filesystem.mount("/dev", devfs)
		kernelLog(Log.DEBUG, "[main] Spawning init thread")
		local init, reason = createProcess(function ()
				kernelLog(Log.DEBUG, "[init] Init started")
				local result, reason = pcall(loadfile(Config.initPath or "/sbin/init.lua"))
				panic("Init dead: " .. (reason or "unknown"))
		end, "init", _, "root")
		if not init then
			panic(reason)
		end
		init.workingDirectory = "/"
		init.stdout = kernelLogger
		init.stderr = kernelLogger
		kernelLog(Log.DEBUG, "[main] Starting thread handling loop")

		local logf = filesystem.open("/kernel.log", "w")

		logf:write(kernelLogger.buffer)
		kernelLogger = logf

		-- Move to threading???

		local lastYield = computer.uptime()
		yieldTime = 1--math.max(4.9, math.min(0.1, Config.yieldTime or 3))
		local function isTimeout()
			return computer.uptime() - lastYield > yieldTime
		end

		function resumeThread(thread, resumeArguments)
			kernelLog(Log.DEBUG, "Resume thread", thread.name, table.unpack(resumeArguments))
			thread.deadline = math.huge
			thread.running = true
			thisThread = thread
                        local result = table.pack(coroutine.resume(thread.coroutine, table.unpack(resumeArguments, 2)))
                        thisThread = kernelThread
			thread.running = false
			if not result[1] or coroutine.status(thread.coroutine) == "dead" then
                		kill(thread.pid)
				if result[2] then
					kernelLog(Log.ERROR, "Thread: [pid: " .. thread.pid .. "] died: " .. (result[2] or "unknown"))
				end
			else
				thread.awaiting = result[2]
				thread.awaitingArgs = table.pack(table.unpack(result, 3))
			end
		end

		function tryResume(thread)
			if not thread.paused then
 				for n, event in pairs(thread.eventQueue) do
					if event[1] == thread.awaiting then	
						table.remove(thread.eventQueue, n)
						resumeThread(thread, event)
						return
					end
				end
				if thread.deadline <= computer.uptime() then
					resumeThread(thread, {"deadline"})		
				end
			end
		end

		function nextDeadline()
			local deadline = math.huge
			for _, th in pairs(threads) do
				if not th.paused then
					if th.deadline < deadline then
						deadline = th.deadline
					end
				end
			end
			return deadline
		end

		local function countQueuedEvents(thread, t)
			local n, first = 0
			for i, event in pairs(thread.eventQueue) do
				if event[1] == t then
					n = n + 1
					if not first or first < i then
						first = i
					end
				end
			end
			return n, first
		end

		while true do
			while true do
				local resumed = false
				for _, thread in pairs(threads) do
					if tryResume(thread) then
						resumed = true
					end
					if isTimeout() then
						goto yieldMachine
					end
				end
				if not resumed then
					break
				end
			end
			::yieldMachine::
			local deadline = nextDeadline()
			-- TODO Call emitEvent or pushEvent
			local event = table.pack(computer.pullSignal(math.max(0, computer.uptime() - deadline)))
			lastYield = computer.uptime()
			if #event > 0 then
				for _, thread in pairs(threads) do
					local nevent, oldest = countQueuedEvents(thread, countQueuedEvents(thread, "signal"))
					if nevent >= 16 then
						table.remove(thread.eventQueue, oldest)
					end
					if event[2] then
						table.insert(thread.eventQueue, table.pack("signal", table.unpack(event)))
					end
				end
				for _, ehandler in pairs(eventHandlers) do
					for i, v in ipairs(ehandler.data) do
						if i ~= 1 and v ~= nil and v ~= event[i - 1] then
							goto continue
						end
					end
					ehandler.callback(table.unpack(event, 2))
					::continue::
				end
			end

		end
end

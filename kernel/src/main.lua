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

KernelVersion = "0.0.2.0 alpha"

GLOBAL._OSVERSION = "HyperKernel " .. KernelVersion

function panic(str)
	kernelLog(Log.ERROR, "Kernel panic: " .. tostring(str))
	kernelLog(Log.ERROR, debug.traceback())
	while true do computer.pullSignal(1) end
end


function main(...)
		kernelLog(Log.DEBUG, "[main] Starting kernel")
		kernelLog(Log.INFO, "HyperKernel / " .. KernelVersion .. " / Zabqer")
		kernelLog(Log.INFO, "[main] Mounting root filesystem")
		filesystem.mount("/dev", devfs)
		for address, ctype in component.list() do
			componentAdded(address, ctype)
		end
		-- (function ()
		-- 	local MAGIC = "\x28\xFF\xF0\xAA"
		-- 	local SUPERBLOCK = [[<c4TTTTHTT]]
                --
		-- 	local INODE = [[<bTT]]
                --
		-- 	local TYPE_UNKNOWN = 0
		-- 	local TYPE_FILE = 1
		-- 	local TYPE_DIR = 2
                --
		-- 	local DIR_ENTRY = [[<Tz]]
		-- 	local availableSize = filesystem.size("/dev/drive/0") - 512
                --
		-- 	local inodeSize = 64
		-- 	local totalInodes = math.ceil(availableSize / 3 / inodeSize)
		-- 	local blockSize = 64
		-- 	local totalBlocks = math.ceil((availableSize - totalInodes * inodeSize) / blockSize)
                --
		-- 	local f = assert(filesystem.open("/dev/drive/0", "w"))
                --
		-- 	f:write(string.pack(
		-- 	SUPERBLOCK,
		-- 	MAGIC,
		-- 	totalInodes,
		-- 	totalBlocks,
		-- 	totalInodes - 1,
		-- 	totalBlocks,
		-- 	blockSize,
		-- 	1,
		-- 	1
		-- 	))
                --
		-- 	f:write(string.rep("\0", 512 - string.packsize(SUPERBLOCK)))
                --
		-- 	f:write(string.pack(
		-- 	INODE,
		-- 	TYPE_DIR,
		-- 	0,
		-- 	0
		-- 	))
                --
		-- 	f:close()
                --
		-- end)()
		-- success, reason = filesystem.mount("/", "/dev/drive/0")
		success, reason = filesystem.mount("/", computer.getBootAddress())
		if not success then
			panic(reason)
		end
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
		kernelLog(Log.DEBUG, "[main] Starting thread handling loop")

		-- assert(filesystem.makeDirectory("/var/log"))
		-- debugFs()

		-- local logf, reason = filesystem.open("/var/log/kernel.log", "w")
		-- if not logf then
		-- 	panic(reason)
		-- end
		-- debugFs()

		-- logf:write(kernelLogger.buffer)
		-- -- debugFs()
		kernelLogger = {
			write = function (_, data)
				-- logf:write(data .. "\n")
			end
		}
		init.stdout = kernelLogger
		init.stderr = kernelLogger

		-- Move to threading???

		local lastYield = computer.uptime()
		yieldTime = 1--math.max(4.9, math.min(0.1, Config.yieldTime or 3))
		local function isTimeout()
			return computer.uptime() - lastYield > yieldTime
		end

		function resumeThread(thread, resumeArguments)
			kernelLog(Log.DEBUG, "Resume thread", thread.name, thread.pid, table.unpack(resumeArguments))
			thread.deadline = math.huge
			thread.running = true
			thisThread = thread
                        local result = table.pack(coroutine.resume(thread.coroutine, table.unpack(resumeArguments, 2)))
                        thisThread = kernelThread
			thread.running = false
			if not result[1] or coroutine.status(thread.coroutine) == "dead" then
                		kill(thread.pid)
				kernelLog(Log.ERROR, "Thread: [pid: " .. thread.pid .. "] died: " .. (result[2] or "unknown"))
			else
				thread.awaiting = result[2]
				thread.awaitingArgs = table.pack(table.unpack(result, 3))
			end
		end

		function checkAwaiting(thread, event)
			if thread.awaiting == event[1] then
				if thread.awaitingArgs ~= nil then
					for i=1, #thread.awaitingArgs do
						arg = thread.awaitingArgs[i]
						if arg ~= nil and arg ~= event[i + 1] then
							return false
						end
					end
				end
				return true
			end
		end

		function tryResume(thread)
			if not thread.paused then
 				for n, event in pairs(thread.eventQueue) do
					if checkAwaiting(thread, event) then
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

KernelVersion = "0.0.0.1"

function main(...)
		kernelLog(Log.DEBUG, "[main] Starting kernel")
		kernelLog(Log.INFO, "HyperKernel / " .. KernelVersion .. " / Zabqer")
		kernelLog(Log.DEBUG, "[main] Spawning init thread")
		spawnThread(function ()
				kernelLog(Log.DEBUG, "[init] Init started")
				local result, reason = dofile(Config.initPath or "/sbin/init.lua")
				panic("Init dead: " .. (reason or "unknown"))
		end, "init", _, true)
		kernelLog(Log.DEBUG, "[main] Starting thread handling loop")
		while true do
				break
		end
end
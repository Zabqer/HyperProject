--[[
		Name: ipc;
		Depends: [utils, threading];
		Description: Provides methods to communicate processes;
]]--

local ipc = {}

function ipc.send(pid, t, ...)
	local thread = threads[pid]
	if not thread then
		return false, "no such thread"
	end
	table.insert(thread.eventQueue, table.pack("ipc", t, ...))
	return true
end

function ipc.wait(t)
	return waitEvent("ipc", t)
end

libs.ipc = ipc

--[[
		Name: event;
		Depends: [utils];
		Description: Event sustem;
]]--

libevent = {}

function libevent.on(event, f)
	local thread = createThread(function ()
		while true do
			f(table.unpack(table.pack(waitEvent("signal", event)), 2))
		end
	end, "[event listener]", thisThread.process)
end

-- TODO make event regexp
function libevent.wait(event, ...)
	return table.unpack(table.pack(waitEvent("signal", event, ...)), 2)
end

libs.event = libevent

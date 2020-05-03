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

function libevent.wait(event, ...)
	return waitEvent("signal", event, ...)
end

libs.event = libevent

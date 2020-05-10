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
	local events = {}
	for event in string.gmatch(event, "[^|]+") do
		table.insert(events, event)
	end
	while true do
		local event = table.pack(waitEvent("signal", nil, ...))
		for _, ev in ipairs(events) do
			if ev == event[1] then
				return table.unpack(event)
			end
		end
	end
end

libs.event = libevent

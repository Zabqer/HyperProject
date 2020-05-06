--[[
		Name: driver_chatbox;
		Depends: [component, filesystem, threading];
		Description: Provides driver for chat_box componen;
]]--

-- addKenrelEventHandler({"signal", "chat_message"}, function()
--
-- end)

function cb_added()
	return {
		write = function (handle, data)
			component.invoke(handle.node.uuid, "say", data)
		end,
		read = function (handle)
			local event = waitEvent("signal", "chat_message", handle.node.uuid)
			return event[4]
		end
		-- TODO read by handling event
	}
end

function cb_removed()
	
end

register_driver("chat_box", cb_added, cb_removed)

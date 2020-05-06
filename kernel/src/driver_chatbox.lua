--[[
		Name: driver_chatbox;
		Depends: [component, filesystem];
		Description: Provides driver for chat_box componen;
]]--

function cb_added(uuid)
	return {
		write = function (handle, data)
			dprint("component.invoke", handle.uuid, "say", data)
			--component.invoke(handle.uuid, "")
		end
		-- TODO read by handling event
	}
end

function cb_removed(uuid)
	
end

register_driver("chat_box", cb_added, cb_removed)

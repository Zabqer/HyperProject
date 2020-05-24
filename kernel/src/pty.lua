--[[
		Name: pty;
		Depends: [dev_filesystem, allocator, utils];
		Description: Provides pseudo terminals;
]]--

local allocator
allocator, ptys = createAllocator(true, true)

function os.pty()
	local pty = allocator:new()
	local master = {
		pty = pty,
		read = function (self, count)
			return self.o:read(count)
		end,
		write = function (self, data)
			for c in data:gmatch(".") do
				if c == "\x03" then
					sendSignal(self.pty.slave.process, "interrupt")
					return
				end
			end
			return self.i:write(data)
		end,
		close = function (self)
			panic("MASTER CLOSE")
		end
	}
	pty.master = master
	local slave = {
		pty = pty,
		read = function (self, count)
			return self.o:read(count)
		end,
		write = function (self, data)
			return self.i:write(data)
		end,
		close = function (self)
			panic("SLAVE CLOSE")
		end,
		index = function (self)
			return self.pty.index
		end
	}
	pty.slave = slave

	master.i, slave.o = createPipe()
	slave.i, master.o = createPipe()

	local m, s = buffer(master, "rw", "PtyMaster"), buffer(slave, "rw", "PtySlave", {index = function (self) return tonumber(pty.index) end})

	m:setvbuf("no")
	s:setvbuf("no")

	return m, s
end

devfs.data.pty = setmetatable({
	__file = false
}, {
	__index = function (_, key)
		return ptys[key] and {
			__file = true,
			read = function (_, ...)
				return ptys[key].master.o:read(...)
			end,
			write = function (_, ...)
				return ptys[key].master.i:write(...)
			end
		}
	end,
	__pairs = function ()
		local n
		return function()
			n = next(ptys, n)
			return n and tostring(n)
		end
	end
})

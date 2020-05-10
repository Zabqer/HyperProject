--[[
		Name: pty;
		Depends: [allocator, utils];
		Description: Provides pseudo terminals;
]]--

local allocator, ptys = createAllocator()

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
					-- SEND SIGNAL TO SLAVE!!
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
		end
	}
	pty.slave = slave

	master.i, slave.o = createPipe()
	slave.i, master.o = createPipe()

	local m, s = buffer(master, "rw"), buffer(slave, "rw")

	m:setvbuf("no")
	s:setvbuf("no")

	return m, s
end

--[[
		Name: io;
		Depends: [buffer, filesystem];
		Description: Provides I/O methods;
]]--

GLOBAL.io = {}

function GLOBAL.io.close(file)
		return (file or io.output()):close()
end

function GLOBAL.io.flush()
		return io.output():flush()
end

function GLOBAL.io.open(path, mode)
		local stream, reason = filesystem.open(path, mode)
		if stream then
				return buffer(stream, mode)
		else
				return nil, reason
		end
end

local pipeInputMethods, pipeOutputMethods = {}, {}

function pipeInputMethods:write(data)
		yield()
		if self.closed then
				return false
		end
		local notify = #self.buffer == 0 and #data ~= 0
		self.buffer = self.buffer .. data
		if notify then
				pushEvent("pipe_changed", self, "append")
		end
		return true
end

function pipeInputMethods:close()
		yield()
		if self.closed then
				return false
		end
		self.closed = true
		pushEvent("pipe_changed", self, "input_closed")
		return true
end

function pipeOutputMethods:read(count)
		yield()
		if not self.buffer or #self.buffer == 0 and self.closed then
				return nil
		end
		if #self.buffer > 0 then
				local data = self.buffer:sub(1, count)
				self.buffer = self.buffer:sub(count + 1)
				return data
		end
		local _, t = waitEvent("pipe_changed", self)
		if t == "output_closed" then
				return nil
		elseif t == "append" then
				local data = self.buffer:sub(1, count)
				self.buffer = self.buffer:sub(count + 1)
				return data 
		end
end

function pipeOutputMethods:close()
		yield()
		if not self.buffer then
				return false
		end
		self.buffer = nil
		pushEvent("pipe_changed", self, "output_closed")
		return true
end

function createPipe()
		local pipe = {
				buffer = "",
				closed = false
		}
		return protectObject(pipe, pipeInputMethods, "PipeInput"), protectObject(pipe, pipeOutputMethods, "PipeOutput")
end

function GLOBAL.io.pipe()
		local i, o = createPipe()
		local wb = buffer(i, "w")
		wb:setvbuf("no")
		return wb, buffer(o, "r")
end

function GLOBAL.io.size(file)
	return filesystem.size(file)
end

function GLOBAL.io.input(file)
		if file then
				if type(file) == "string" then
						local result, reason = io.open(file, "r")
						if not result then
								error(reason, 2)
						end
						file = result
				elseif not io.type(file) then
						error("bad argument #1 (string or file expected, got " .. type(file) .. ")", 2)
				end
				thisThread.process.stdin = file
		end
		return thisThread.process.stdin
end

function GLOBAL.io.read(...)
		return io.input():read(...)
end

function GLOBAL.io.output(file)
		if file then
				if type(file) == "string" then
						local result, reason = io.open(file, "w")
						if not result then
								error(reason, 2)
						end
						file = result
				elseif not io.type(file) then
						error("bad argument #1 (string or file expected, got " .. type(file) .. ")", 2)
				end
				thisThread.process.stdout = file
		end
		return thisThread.process.stdout
end

function GLOBAL.io.write(...)
		return io.output():write(...)
end

function io.error(file)
		if file then
				if type(file) == "string" then
						local result, reason = io.open(file, "w")
						if not result then
								error(reason, 2)
						end
						file = result
				elseif not io.type(file) then
						error("bad argument #1 (string or file expected, got " .. type(file) .. ")", 2)
				end
				thisThread.process.stderr = file
		end
		return thisThread.process.stderr
end

function GLOBAL.io.combine(mode, ...)
	-- TODO
	return select(2, ...)
end

local rewriterMethods = {}

function rewriterMethods:write(data)
	return self.stream:write(self.handler(data))
end

function GLOBAL.io.rewriter(f, stream)
	stream = buffer(protectObject({
		stream = stream,
		handler = f
	}, rewriterMethods, type(stream)), "w")
	stream:setvbuf("no")
	return stream
end

local finderMethods = {}

function finderMethods:read(count)
	dprint("REEEEAD", count)
	local result, reason = self.stream:read(count)
	dprint("DATA READED", result, reason)
	if result then
		local s = result:find(self.data)
		if s then
			self.handler()
		end
	end
	return result, reason
end

function GLOBAL.io.finder(stream, data, f)
	stream = buffer(protectObject({
		stream = stream,
		handler = f,
		data = data
	}, finderMethods, type(stream)), "r")
	stream:setvbuf("no")
	return stream
end
	


setmetatable(io, {__index = function (_, key)
		if key == "stdin" then
				return io.input()
		elseif key == "stdout" then
				return io.output()
		elseif key == "stderr" then
				return io.error()
		end
end})


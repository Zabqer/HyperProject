--[[
		Name: buffer;
		Depends: [utils];
		Description: Provides buffer methods;
]]--

local bufferMethods = {}

function bufferMethods:close()
		if self.w or self.a then
				bufferMethods.flush(self)
		end
		self.closed = true
		return self.stream:close()
end

function bufferMethods:flush()
		if #self.bufferWrite > 0 then
				local data = self.bufferWrite
				local result, reason = self.stream:write(data)
				if result then
						self.bufferWrite = ""
				else
						if reason then
								return nil, reason
						else
								return nil, "bad file descriptor"
						end
				end
		end
		return true
end

local function readChunk(self)
		local result, reason = self.stream:read(math.max(1,	self.bufferSize))
		if result then
				self.bufferRead = self.bufferRead .. result
				return self
		else
				return nil, reason
		end
end

function readBytesOrChars(self, n)
		n = math.max(n, 0)
		local len, sub
		if self.b then
				len = rawlen
				sub = string.sub
		else
				len = unicode.len
				sub = unicode.sub
		end
		local data = ""
		repeat
				if len(self.bufferRead) == 0 then
						local result, reason = readChunk(self)
						if not result then
								if reason then
										return nil, reason
								else
										return #data > 0 and data or nil
								end
						end
				end
				local left = n - len(data)
				data = data .. sub(self.bufferRead, 1, left)
				self.bufferRead = sub(self.bufferRead, left + 1)
		until len(data) == n
		return data
end

function readLine(self, chop)
		local start = 1
		while true do
				local buf = self.bufferRead
				local i = buf:find("[\r\n]", start)
				local c = i and buf:sub(i,i)
				local is_cr = c == "\r"
				if i and (not is_cr or i < #buf) then
						local n = buf:sub(i+1,i+1)
						if is_cr and n == "\n" then
								c = c .. n
						end
						local result = buf:sub(1, i - 1) .. (chop and "" or c)
						self.bufferRead = buf:sub(i + #c)
						return result
				else
						start = #self.bufferRead - (is_cr and 1 or 0)
						local result, reason = readChunk(self)
						if not result then
								if reason then
										return nil, reason
								else
										result = #self.bufferRead > 0 and self.bufferRead or nil
										self.bufferRead = ""
										return result
								end
						end
				end
		end
end

function readAll(self)
		repeat
				local result, reason = readChunk(self)
				if not result and reason then
						return nil, reason
				end
		until not result
		local result = self.bufferRead
		self.bufferRead = ""
		return result
end

function bufferMethods:read(...)
		if not self.r then
				return nil, "read mode was not enabled for this stream"
		end
		if self.w or self.a then
				bufferMethods.flush(self)
		end
	yield()
		local function read(i, arg)
				checkArg(i, arg, "number", "string")
				if type(arg) == "number" then
						return readBytesOrChars(self, arg)
				else
						local rt = unicode.sub(arg, 1, 1) == "*" and unicode.sub(arg, 2) or arg
						--[[if rt == "n" then
								return readNumber(self)
						else]]if rt == "l" then
								return readLine(self, true)
						elseif rt == "L" then
								return readLine(self, false)
						elseif rt == "a" then
								return readAll(self)
						else
								error("bad argument #" .. i .. " (n, l, L or a expected, got " .. arg .. ")")
						end
				end
		end
		local args = table.pack(...)
		if #args > 0 then
				local results = {}
				for i = 1, #args do
						local result, reason = read(i, args[i])
						if result then
								results[i] = result
						elseif reason then
								return nil, reason
						end
				end
				return table.unpack(results)
		else
				return readLine(self, true)
		end
end

function bufferMethods:write(...)
		if self.closed then
				return nil, "bad file descriptor"
		end
		if not self.w and not self.a then
				return nil, "write mode was not enabled for this stream"
		end
	yield()
		local args = table.pack(...)
		for i = 1, #args do
				if type(args[i]) == "number" then
						args[i] = tostring(args[i])
				end
				checkArg(i, args[i], "string")
		end
		for i = 1, #args do
				local arg = args[i]
				local result, reason
				if self.bufferMode == "no" then
						result, reason = self.stream:write(arg)
				elseif self.bufferMode == "full" then
						if self.bufferSize - #self.bufferWrite < #arg then
								result, reason = bufferMethods.flush(self)
								if not result then
										return nil, reason
								end
						end
						if #arg > self.bufferSize then
								result, reason = self.stream:write(arg)
						else
								self.bufferWrite = self.bufferWrite .. arg
								result = self
						end
				else
						local l
						repeat
								local idx = arg:find("\n", (l or 0) + 1, true)
								if idx then
										l = idx
								end
						until not idx
						if l or #arg > self.bufferSize then
								result, reason = bufferMethods.flush(self)
								if not result then
										return nil, reason
								end
						end
						if l then
								result, reason = self.stream:write(arg:sub(1, l))
								if not result then
										return nil, reason
								end
								arg = arg:sub(l + 1)
						end
						if #arg > self.bufferSize then
								result, reason = self.stream:write(arg)
						else
								self.bufferWrite = self.bufferWrite .. arg
								result = self
						end
				end
		end
		if not result then
				return nil, reason
		end
		return true
end

function bufferMethods:setvbuf(mode, size)
		mode = mode or self.bufferMode
		size = size or self.bufferSize
		assert(mode == "no" or mode == "full" or mode == "line", "bad argument #1 (no, full or line expected, got " .. tostring(mode) .. ")")
		assert(mode == "no" or type(size) == "number", "bad argument #2 (number expected, got " .. type(size) .. ")")
		self.bufferMode = mode
		self.bufferSize = size
		return self.bufferMode, self.bufferSize
end

function bufferMethods:size()
		local len = self.b and rawlen or unicode.len
		local size = len(self.bufferRead)
		if self.stream.size then
				size = size + self.stream:size()
		end
		return size
end

function buffer(stream, mode)
		checkArg(1, stream, "table")
		checkArg(2, mode, "string", "nil")
		mode = mode or "r"
		local obj = {
				stream = stream,
				closed = false,
				bufferSize = 2048,
				bufferRead = "",
				bufferWrite = "",
				bufferMode = "full"
		}
		for i = 1, unicode.len(mode) do
				local m = unicode.sub(mode, i, i)
				assert(m == "r" or m == "w" or m == "a" or m == "b", "bad argument #2 (r, w, a, b expected got " .. m .. ")")
				obj[m] = true
		end
		return protectObject(obj, bufferMethods, "Stream")
end

local libbuffer = buffer

libs.buffer = libbuffer

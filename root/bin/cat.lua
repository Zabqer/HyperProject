local filename = ...

local f = assert(io.open(filename))

local bs = 2048

while true do
	local buffer = f:read(bs)
	if not buffer then
		return
	end
	io.write(buffer)
end

local args = table.pack(...)

local f = assert(io.open(args[1], "w"))

for i, v in ipairs(args) do
	if i ~= 1 then
		f:write(v)
		if #args ~= i then
			assert(f:write(" "))
		end
	end
end

f:close()

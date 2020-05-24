local args = table.pack(...) 

local f = io.open("/init.lua")
local kernel = f:read("*a")
f:close()

local currentConf = kernel:match("Config={(.-})")

function trim(s)
   return (s:gsub("^%s*(.-)%s*$", "%1"))
end

local conf = {}

for k, v in currentConf:gmatch("(.-)=(.-)[\n,]") do
	conf[trim(k)] = trim(v)
	print(trim(k), "=", trim(v))
end

conf["logLevel"] = 0

currentConf = "Config={"

local l

while true do
	n = next(conf, l)
	if not n then
		break
	elseif l then
		currentConf = currentConf .. ","
	end
	l = n
	currentConf = currentConf .. (n .. "=" .. conf[n])
end

currentConf = currentConf .. "}"

kernel = kernel:gsub("Config = {(.-})", currentConf)

f = io.open("/init.lua", "w")
f:write(kernel)
f:close()



local sh = require("sh")
local term = require("term")
local thread = require("thread")

local args = table.pack(...)

thread.attach("interrupt", function ()
	os.exit(0)
end)

while true do
	term.clear()
	assert(sh.execute(table.concat(args, " ")))
	os.sleep(1)
end

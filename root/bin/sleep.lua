local thread = require("thread")
local time = ...
print("Sleeping", time)
thread.attach("interrupt", function ()
	os.exit(0)
end)
os.sleep(tonumber(time))
print("Slept")

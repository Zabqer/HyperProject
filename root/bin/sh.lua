local term = require("term")
local sh = require("sh")
local thread = require("thread")

os.setenv("PS", "\x1b[91m$USER\x1b[39m@\x1b[92m$HOSTNAME\x1b[39m $PWD $ ")

local currentProcess

thread.onSignal("interrupt", function ()
	if currentProcess then
		currentProcess:signal("interrupt")
	end
end)

while true do
	io.write(sh.expand(os.getenv("PS")))
	local line = term.read({
		hint = sh.hintHandler
	})
     	if not line then
		io.write("exit\n")
		return
	elseif line == "exit" then
		return
    	end
	if #line > 0 then 
		th, result = sh.execute(line)
		if not th then
			io.error():write(result .. "\n")
		elseif th ~= true then
			currentProcess = th
			th:join()
			currentProcess = nil
		end
	end
end

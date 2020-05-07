local term = require("term")
local sh = require("sh")
local thread = require("thread")

os.setenv("PWD", "/")
os.setenv("PS", sh.expand("\x1b[91m$USER\x1b[39m@\x1b[92m$HOSTNAME\x1b[39m $PWD $ "))

while true do
    io.write(sh.expand("$PS"))
    local cmd = term.read()
    if cmd == "exit" then
	    return
    end
    success, result = sh.execute(cmd)
    if not success then
	    io.error():write(result .. "\n")
    end
end

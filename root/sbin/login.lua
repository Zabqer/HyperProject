local term = require("term")
local thread = require("thread")
local user = require("user")

local index = ...

while true do
	term.clear()
	print(_OSVERSION .. " (tty" .. index .. ")")

	local u
	while true do
		io.write(os.getenv("HOSTNAME") .. " login: ")
		io.write("zabqer\n")

		--login = term.read()
		
		login = "zabqer"
		io.write("Password: ")
		io.write("\n")
		--local password = term.read(_, "")
		password = "tester"

		local id = user.auth(login, password)
		if not id then
			print("Login incorrect")
		else
			u = user.getInfo(id)
			break
		end
	end
	os.setenv("USER", u.login)

	-- get user shell
	shell = thread.createProcess(u.shell)
	shio = shell:IO()
	shio.stdout = io.stdout
	shio.stdin = io.stdin
	shio.stderr = io.rewriter(function (data)
		return "\x1b[91m" .. data .. "\x1b[39m"
	end, io.stdout)
	shell:setUser(u.id)
	shell:run()
	shell:join()
	print("Exited from shell")
	os.sleep(5)
end

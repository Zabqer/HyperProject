--[[
		Name: user;
		Depends: [utils, threading];
		Description: User sustem;
]]--

local user = {}
local users = {
	[0] = {
		id = 0,
		login = "root",
		password = "toor",
		shell = "/bin/sh.lua"
	},
	[1000] = {
		id = 1000,
		login = "zabqer",
		password = "tester",
		shell = "/bin/sh.lua"
	}
}

function user.auth(login, password)
	local id
	for _, u in pairs(users) do
		if u.login == login then
			if u.password == password then
				return u.id
			else
				os.sleep(5)
			end
		end
	end
	return nil, "login incorrect"
end

function user.getInfo(id)
	if not users[id] then
		return nil, "no such user"
	end
	return protectTable({
		id = users[id].id,
		login = users[id].login,
		shell = users[id].shell
	}, true, false)
end

function processMethods:setUser(id)
	if self.process.user ~= "root" then
		return false, "permissions denied"
	end
	if not users[id] then
		return nil, "no such user"
        end
	self.process.user = users[id].login
	return true
end


libs.user = user

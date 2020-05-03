local sh = require("shell")
local component = require("component")

print("Select drive")
drives = {}
local i = 1
for address in component.list("filesystem") do
	drives[i] = address
	print(i .. " > " .. address)
	i = i + 1
end

s = tonumber(io.read())

fsAddress = drives[s]
if not fsAddress then
	error("No drive")
end

print("Installing to " .. fsAddress)

local gitpath = "https://raw.githubusercontent.com/Zabqer/HyperProject/master"

function fromGit(path)
	return gitpath .. "/" .. path
end

function downloadFile(from, to)
	print(from, ">", to)
	sh.execute("wget " .. from .. " " .. to .. " -q")
end

function buildKernel()
	print("Building kernel")	
	local files = {
		"buffer",
		"config",
		"event",
		"filesystem",
		"io",
		"log",
		"main",
		"threading",
		"user",
		"userspace",
		"utils"
	}
	sh.execute("mkdir kernel")
	sh.execute("mkdir kernel/src")
	for _, file in pairs(files) do
		downloadFile(fromGit("kernel/src/" .. file .. ".lua"), "kernel/src/" .. file .. ".lua")
	end 
	downloadFile(fromGit("kernel/build-kernel.lua"), "kernel/build-kernel.lua")
	sh.execute("cd kernel; build-kernel; mv kernel.lua /mnt/" .. fsAddress:sub(1, 3) .. "/init.lua")
end

function copyRoot()
	print("Copying root")

end

buildKernel()
copyRoot()



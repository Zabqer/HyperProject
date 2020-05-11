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
		"allocator",
		"component",
		"dev_filesystem",
		"driver_chatbox",
		"pty",
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
	sh.execute("cd kernel; build-kernel " .. fsAddress .. "; mv kernel.lua /mnt/" .. fsAddress:sub(1, 3) .. "/init.lua")
end

function copyRoot()
	print("Copying root")
	local bin = {
		"cat",
		"reboot",
		"write",
		"watch",
		"ps",
		"whoami",
		"echo",
		"error",
		"ls",
		"tree",
		"shutdown",
		"sleep",
		"signal",
		"sh",
		"clear"
	}
	local lib = {
		"sh",
		"term"
	}
	local sbin = {
		"getty",
		"readkey",
		"init",
		"login"
	}
	sh.execute("mkdir /mnt/" .. fsAddress:sub(1, 3) .. "/bin")
	sh.execute("mkdir /mnt/" .. fsAddress:sub(1, 3) .. "/lib")
	sh.execute("mkdir /mnt/" .. fsAddress:sub(1, 3) .. "/sbin")
	for _, file in pairs(bin) do
		downloadFile(fromGit("root/bin/" .. file .. ".lua"), "/mnt/" .. fsAddress:sub(1, 3) .. "/bin/" .. file .. ".lua")
	end 
	for _, file in pairs(lib) do
		downloadFile(fromGit("root/lib/" .. file .. ".lua"), "/mnt/" .. fsAddress:sub(1, 3) .. "/lib/" .. file .. ".lua")
	end 
	for _, file in pairs(sbin) do
		downloadFile(fromGit("root/sbin/" .. file .. ".lua"), "/mnt/" .. fsAddress:sub(1, 3) .. "/sbin/" .. file .. ".lua")
	end 
end

buildKernel()
copyRoot()



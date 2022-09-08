-- the server (reactor data stored in memory and disk)
local component = require("component")
local serialization = require("serialization")
local computer = require("computer")
local sides = require("sides")
local event = require("event")
local fs = require("filesystem")
local m = component.modem

local MSGPORT = 1 --hub commands
local DATAPORT = 2 -- reactor data and server
local HUBPORT = 3 -- unused
local saveToDiskCounterMax = 30 --amount of pulls before save but if nothing is pulled in 5 seconds it counts a pull
local data = {}
local saveToDiskCounter = 0
local saveDirectory = "/home/reactor_server/reactorsaves"

function openPort(port)
	m.open(port)
	local isPortOpen = m.isOpen(port)
	while not isPortOpen do
		print("Failed to connect to port " .. port)
		print("retrying in 5 seconds...")

		os.sleep(5)
		m.open(port)
		isPortOpen = m.isOpen(port)
	end
	print("Successfully connected to port " .. port)
end

function storeMessage(message)
	if message.id == nil then
		return
	end

	local dataSet = {}
	dataSet["id"] = message.id
	dataSet["fuel"] = message.fuel
	dataSet["energy"] = message.energy
	dataSet["stats"] = message.stats
	data[message.id] = dataSet
end

function hardShutdown()
	print("received hard shutdown request")
	for i = 10, 0, -1 do
		print("computer/server will shutdown in " .. i .. " seconds")
		os.sleep(1)
	end
	computer.shutdown(false)
	--only prints if shutdown failed
	print("failed to shutdown")
end

function hubSendInfo(toSend)
	toSend["type"] = "reactor_data_toHub"
	local serData = serialization.serialize(toSend)
	m.broadcast(MSGPORT, serData)
	print("sent hub data to port " .. MSGPORT)
end

function server_clearMemoryData()
	local blank = {}
	print("cleared in memory data")
	return blank
end

function isServerCorrectlyInstalled()
	local filePath = "/home/reactor_server/server"
	if fs.exists(filePath) then
		--shell.setWorkingDirectory("/home/reactor_server/reactorsaves/")
		return true
	end
	print("Server file not in correct directory!")
	print("Server file must be in /home/reactor_server/")
	print("Server file must be called \"server\"")
	return false
end

function server_clearDiskData()
	local file = "/home/reactor_server/reactorsaves"
	fs.remove(file)
	print("deleted savedata")
end

--creates a file to store the reactor data when server power is down
function saveDataToDisk(rawData, saveDir)
	doesSaveDirExist(saveDir)
	local fileName = saveDir .. "/" .. "savedata"
	local seriData = serialization.serialize(rawData)

	--deleting old file
	fs.remove(fileName)

	--creating file
	local str = io.open(fileName, "w")
	str:write(seriData)
	str:close()

	print(computer.uptime() .. " - Saved data to disk!")
	print("Next save in " .. saveToDiskCounterMax .. " interations")
end

--checks if save folder exists, if not it creates one
function doesSaveDirExist(saveDir)
	if fs.exists(saveDir) == false then
		print("Save directory doesn't exist")
		print("Creating save directory...")
		fs.makeDirectory(saveDir)
		print("Created directory")
	end
end

function doesSaveFileExist()
	local file = "/home/reactor_server/reactorsaves/savedata"
	if fs.exists(file) == false then
		print("Missing savefile")
		print("Creating file...")

		local str = io.open(file, "w")
		str:close()
		print("Created file")
	end
end

--reads save file and opens it in memory
function readSaveData(saveDir)
	doesSaveDirExist(saveDir)
	doesSaveFileExist()
	local fileName = saveDir .. "/" .. "savedata"

	local str = io.open(fileName, "r")
	local save = str:read()
	str:close()
	if save ~= nil then
		--print("save not nil")
		save = serialization.unserialize(save)
		return save
	end
	--print("save nil")
end

--warning for wired network:
if not m.isWireless() then
	print("Warning!")
	print("This server is configured for wired networks.")
	print("The maximum amount of reactor controllers you can connect to this network is 9! (Including server and hub)")
	print("Installing a wireless network card tier 2 in the hub, controllers and this server will over come that.")
	print("Do you want to continue? [y/n]")
	while true do
		local continue = io.read()
		if continue == "y" or continue == "Y" then
			print("---")
			break
		elseif continue == "n" or continue == "N" then
			os.exit()
		end	
	end
end

--main loop init
openPort(DATAPORT)
active = isServerCorrectlyInstalled()
data = readSaveData(saveDirectory)
if data == nil then
	data = {}
	print("Saved file was empty")
else
	print("Loaded saved data")
end

--main loop
while active do
	local mtype, _, _, _, _, message = event.pull(5, "modem_message")
	if mtype == "modem_message" and message ~= nil and type(message) == "string" then
		--[[if message == "hub_getInfo" then
			hubSendInfo()
		elseif message == "server_clearMemoryData" then
			server_clearMemoryData()
		elseif message == "reactorServer_shutdown" then
			print("server shutting down - command")
			active = false
		else
			
		end]]
		message = serialization.unserialize(message)

		if message ~= nil and message.type ~= nil then
			if message.type == "reactor_data" then
				storeMessage(message)	
			end

			if message.type == "reactor_server_commands" then
				if message.cmd == "hub_getInfo" then
					hubSendInfo(data)
				elseif message.cmd == "reactorServer_clearMemoryData" then
					data = server_clearMemoryData()
				elseif message.cmd == "reactorServer_softShutdown" then
					print("received softshutdown request")
					print("terminating script")
					active = false
				elseif message.cmd == "reactorServer_hardShutdown" then
					hardShutdown()
				elseif message.cmd == "reactorServer_clearDiskData" then
					server_clearDiskData()
				end
			end
		end
	end

	saveToDiskCounter = saveToDiskCounter + 1
	if saveToDiskCounter == saveToDiskCounterMax then
		saveToDiskCounter = 0
		saveDataToDisk(data, saveDirectory)
	end
end

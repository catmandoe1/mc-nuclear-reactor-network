-- the server
local component = require("component")
local serialization = require("serialization")
local sides = require("sides")
local event = require("event")
local m = component.modem

local active = true
local MSGPORT = 1
local DATAPORT = 2
local HUBPORT = 3
local data = {}

m.open(DATAPORT)
isPortOpen = m.isOpen(DATAPORT)
if isPortOpen == false then
	print("failed to open to port " .. DATAPORT)
	m.open(DATAPORT)
else
	print("succesfully opened to port " .. DATAPORT)
end
print("")

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

function hubSendInfo()
	local serData = serialization.serialize(data)
	m.broadcast(HUBPORT, serData)
	print("sent data to port " .. HUBPORT)
end

function server_clearAllData()
	data = {}
	print("cleared data")
end

while active do
	local mtype, _, _, _, _, message = event.pull(60, "modem_message")
	if mtype == "modem_message" and message ~= nil then
		if message == "hub_getInfo" then
			hubSendInfo()
		elseif message == "server_clearAllData" then
			server_clearAllData()
		else
			message = serialization.unserialize(message)
			storeMessage(message)	
		end
	end
end
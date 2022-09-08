-- this is the controller, the one controlling the reactor its self
local computer = require("computer")
local component = require("component")
local serialization = require("serialization")
local sides = require("sides")
local event = require("event")
local reactor = component.nc_fission_reactor

local active = true
local forceOn = false
local isControllerActive = false
local m = component.modem
local MSGPORT = 1 --hub commands and reactor
local DATAPORT = 2 -- reactor data and server
local HUBPORT = 3 -- unused

print("Enter reactor ID:")
print("Must be different from other controllers")
local ID = io.read()


function openPort(port)
	m.open(port)
	isPortOpen = m.isOpen(port)
	while not isPortOpen do
		print("Failed to connect to port " .. port)
		print("retrying in 5 seconds...")
		os.sleep(5)
		m.open(port)
		isPortOpen = m.isOpen(port)
	end
	print("Successfully connected to port " .. port)
end

function sendFuel()
	local fuel = {}
	fuel["fuelTime"] = reactor.getFissionFuelTime()
	fuel["fuelType"] = reactor.getFissionFuelName()
	fuel["fuelPower"] = reactor.getFissionFuelPower()
	fuel["currentProcessTime"] = reactor.getCurrentProcessTime()
	return fuel
end

function sendEnergy()
	local power = {}
	power["maxEnergy"] = reactor.getMaxEnergyStored()
	power["currentEnergy"] = reactor.getEnergyStored()
	power["reactorProcessPower"] = reactor.getReactorProcessPower()
	power["getEnergyChange"] = reactor.getEnergyChange()
	return power
end

function sendReactorStats()
	local reactorStat = {}
	reactorStat["isActive"] = reactor.isProcessing()
	reactorStat["lengthX"] = reactor.getLengthX()
	reactorStat["lengthY"] = reactor.getLengthY()
	reactorStat["lengthZ"] = reactor.getLengthZ()
	reactorStat["coolingRate"] = reactor.getReactorCoolingRate()
	reactorStat["actualCoolingRate"] = reactor.getReactorProcessHeat()
	reactorStat["currentHeatLevel"] = reactor.getHeatLevel()
	reactorStat["maxHeatLevel"] = reactor.getMaxHeatLevel()
	reactorStat["problem"] = reactor.getProblem()
	return reactorStat
end

function sendAllStats()
	--sending all data about reactor to the data port
	local data = {}
	data["type"] = "reactor_data"
	data["id"] = ID
	data["fuel"] = sendFuel()
	data["energy"] = sendEnergy()
	data["stats"] = sendReactorStats()
	local serData = serialization.serialize(data)
	m.broadcast(DATAPORT, serData)
end

function startReactor()
	isControllerActive = true
	reactor.activate()
	print("turning reactor on")
end

function stopReactor()
	isControllerActive = false
	reactor.deactivate()
	print("turning reactor off")
end

openPort(MSGPORT)
--main loop
while active do
	--reactor controller
	if isControllerActive then
		currentPower = reactor.getEnergyStored()
		maxPower = reactor.getMaxEnergyStored()
		currentHeat = reactor.getHeatLevel()
		maxHeat = reactor.getMaxHeatLevel()

		if currentHeat < (0.90 * maxHeat) then
			if forceOn == false then
				if currentPower > (0.90 * maxPower) then
					reactor.deactivate()
				elseif currentPower < (0.40 * maxPower) then
					reactor.activate()
				end
			else
				reactor.activate()
			end
		else
			reactor.deactivate()
		end
	end

	--computer communication
	local mtype, _, _, incomingMSGPORT, _, message = event.pull(5, "modem_message")
	if mtype == "modem_message" and message ~= nil then
		print("message received")
		--[[gobal reactor commands - come in string form
		if message == "reactor_deactivate_all" then
			stopReactor()
		end
		if message == "reactor_activate_all" then
			startReactor()
		end
		if message == "reactor_forceOn_all" then
			forceOn = true
			print("turned on forceOn")
		elseif message == "reactor_forceOff_all" then
			forceOn = false
			print("turned off forceOn")
		end]]
		--id only commands - comes in string table form
		message = serialization.unserialize(message)
		print(message)
		if message ~= nil and type(message) == "table" and message.type ~= nil then
			print("message valid")
			print(message.type)
			if message.type == "local_reactor_command" then
				print("message local")
				if message.id == ID then
					if message.cmd == "reactor_deactivate" then
						isControllerActive = false
						reactor.deactivate()
						print("turning reactor off")
					elseif message.cmd == "reactor_activate" then
						isControllerActive = true
						reactor.activate()
						print("turning reactor on")
					elseif message.cmd == "reactor_forceOn" then
						forceOn = true
						print("turned on forceOn")
					elseif message.cmd == "reactor_forceOff" then
						forceOn = false
						print("turned off forceOn")
					elseif message.cmd == "reactor_sendStats" then
						sendAllStats()
					end
				end
			elseif message.type == "gobal_reactor_command" then
				print("message global")
				if message.cmd == "reactor_deactivate_all" then
					stopReactor()
				elseif message.cmd == "reactor_activate_all" then
					startReactor()
				elseif message.cmd == "reactor_forceOn_all" then
					forceOn = true
					print("turned on forceOn")
				elseif message.cmd == "reactor_forceOff_all" then
					forceOn = false
					print("turned off forceOn")
				end
			end
		end
	end
	--sends all stats of reactor to main ~every second
	sendAllStats()
end

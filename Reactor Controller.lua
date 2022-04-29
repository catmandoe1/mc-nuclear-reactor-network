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
local MSGPORT = 1
local DATAPORT = 2

print("Enter reactor ID:")
local ID = io.read()


m.open(MSGPORT)
isMSGPORTOpen = m.isOpen(MSGPORT)
if isMSGPORTOpen == false then
	print("failed to open to MSGPORT " .. MSGPORT)
	m.open(MSGPORT)
else
	print("succesfully opened to MSGPORT " .. MSGPORT)
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

--main loop
while active do
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

	local mtype, _, _, incomingMSGPORT, _, message = event.pull(1, "modem_message")
	if mtype == "modem_message" and message ~= nil then
		--all types - come in string form
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
		end
		--single types - comes in table form
		message = serialization.unserialize(message)
		if message ~= nil then
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
				elseif message.cmd == "reactor_forceOff" then
					forceOn = false
				elseif message.cmd == "reactor_sendStats" then
					sendAllStats()
				end
			end
		end
	end
	sendAllStats()
end
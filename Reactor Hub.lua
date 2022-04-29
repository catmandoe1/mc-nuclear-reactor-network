-- this is the hub, the one that controls the controllers and also recives info from them
local component = require("component")
local computer = require("computer")
local serialization = require("serialization")
local sides = require("sides")
local event = require("event")
local m = component.modem

local active = true
local isControllerActive = false
local forceOnB = false
local debug = false

local PORT = 1
local DATAPORT = 2
local HUBPORT = 3

function openPort(port, debug)
	m.open(port)
	isPortOpen = m.isOpen(port)
	while not isPortOpen do
		if debug then
			print("Failed to connect to port " .. port)
			print("retrying in 5 seconds...")
		end
		os.sleep(5)
		m.open(port)
		isPortOpen = m.isOpen(port)
	end
	if debug then print("Successfully connected to port " .. port) end
end

function shutDown()
	print("---")
	print("Are you sure?")
	local userIn = io.read()

	if userIn == "y" or userIn == "Y" or userIn == "ye" or userIn == "yeah" or userIn == "yes" or userIn == "Yes" or userIn == "Yeah" or userIn == "yea" or userIn == "Yea" or userIn == "sure" or userIn == "Sure" or userIn == "i am" or userIn == "I am" then
		active = false
		print("Deactivated reactors and disabled force-on")
		m.broadcast(PORT, "reactor_deactivate_all")
		m.broadcast(PORT, "reactor_forceOff_all")
		print("")
	end
end

function listReactors()
	local reactorCount = 0
	local s = " reactor "

	print("---")
	m.broadcast(DATAPORT, "hub_getInfo")
	openPort(HUBPORT, debug)
	local mtype, _, _, _, _, message = event.pull(5, "modem_message")
	if mtype == "modem_message" and message ~= nil and message ~= "{}" then
		message = serialization.unserialize(message)
		for k, v in pairs(message) do
			print(k)
			reactorCount = reactorCount + 1
		end
		if debug then print(tostring(reactorCount) .. " connected") end
		if reactorCount > 1 then
			s = " reactors "
		end
		print("")
		print("In total, " .. reactorCount .. s .. "connected")
	else
		print("There are no reactors connected to the server")
	end
	openPort(PORT, debug)
end

function pressEnter()
	print("")
	print("Press enter to continue:")
	io.read()
end

function allReactorCommands()
	local allCommandsActive = true
	while allCommandsActive do
		print("---")
		print("a = Startup all reactors")
		print("b = Shutdown all reactors")
		print("c = Enable forceOn for all reactors")
		print("d = Disable forceOn for all reactors")
		print("e = Back to main menu")
		local commandIn = io.read()

		if commandIn == "a" or commandIn == "A" then
			m.broadcast(PORT, "reactor_activate_all")
		elseif commandIn == "b" or commandIn == "B" then
			m.broadcast(PORT, "reactor_deactivate_all")
		elseif commandIn == "c" or commandIn == "C" then
			m.broadcast(PORT, "reactor_forceOn_all")
		elseif commandIn == "d" or commandIn == "D" then
			m.broadcast(PORT, "reactor_forceOff_all")
		elseif commandIn == "e" or commandIn == "E" then
			break
		else
			print("Invalid input")
		end
	end
end

function selectListReactors()
	local selected = 0
	local index = 0

	print("---")
	m.broadcast(DATAPORT, "hub_getInfo")
	openPort(HUBPORT, debug)
	local mtype, _, _, _, _, message = event.pull(5, "modem_message")
	if mtype == "modem_message" and message ~= nil and message ~= "{}" then
		message = serialization.unserialize(message)
		listidx ={}
		for k, v in pairs(message) do
			index = index + 1
			print(index .. " = " .. k)
			table.insert(listidx, v)

			if index%15 == 0 then
				pressEnter()
			end
		end
		print("")
		print("Select a reactor to control:")
		selected = listidx[tonumber(io.read())]
		
	else
		print("There is no reactors connected to the server")
	end
	openPort(PORT, debug)
	if debug then print("returned selected number") end
	return selected
end

function startReactor(status, data)
	if debug then
		print(data)
		print("status = " .. tostring(status))
	end
	local startCMD = "reactor_activate"
	local stopCMD = "reactor_deactivate"
	local message = {}

	message["id"] = data.id
	if status then
		message["cmd"] = startCMD
	else
		message["cmd"] = stopCMD
	end
	send = serialization.serialize(message)
	m.broadcast(PORT, send)
	if debug then print("sent commands to port 1") end
end

function enableForceOn(status, data)
	if debug then
		print(data)
		print("status = " .. tostring(status))
	end
	local enableCMD = "reactor_forceOn"
	local disableCMD = "reactor_forceOff"
	local message = {}

	message["id"] = data.id
	if status then
		message["cmd"] = enableCMD
	else
		message["cmd"] = disableCMD
	end
	send = serialization.serialize(message)
	m.broadcast(PORT, send)
	if debug then print("sent commands to port 1") end	
end

function getReactorInforamtion(data)
	--bits about the reactor
	while true do
		print("---")
		print("a = Reactor dimensions")
		print("b = Heat info")
		print("c = Problems")
		print("d = Energy info")
		print("e = Fuel info")
		print("f = return to options")
		local userIn = io.read()

		if userIn == "a" or userIn == "A" then
			print("---")
			local x = data.stats.lengthX
			local y = data.stats.lengthY
			local z = data.stats.lengthZ

			print("Dimensions of the selected reactor is " .. x .. "x" .. y .. "x" .. z .. " blocks")
			print("Having a capacity of " .. x*y*z .. " blocks inside")
			pressEnter()
		elseif userIn == "b" or userIn == "B" then
			print("---")
			local coolingRate = data.stats.coolingRate
			local actualCoolingRate = data.stats.actualCoolingRate
			local currentHeatLevel = data.stats.currentHeatLevel
			local maxHeatLevel = data.stats.maxHeatLevel

			if actualCoolingRate > 0 then
				print("WARNING, REACTOR HEAT INCREASING")
			elseif actualCoolingRate < 0 then
				print("REACTOR HEAT DECREASING")
			else
				print("REACTOR HEAT NOT INCREASING NOR DECREASING")
			end

			print("Cooling rate: " .. coolingRate .. " H/t")
			print("Net cooling rate: " .. actualCoolingRate .. " H/t")
			print("Heat level: " .. currentHeatLevel .. " / " .. maxHeatLevel .. " [" .. (currentHeatLevel / maxHeatLevel) * 100 .. "%]")
			pressEnter()
		elseif userIn == "c" or userIn == "C" then
			print("---")
			if data.stats.problem == nil or data.stats.problem == "" then
				print("They're no problems with the reactor")
			else
				print("The problems are:")
				print(data.stats.problem)
			end
			pressEnter()
		elseif userIn == "d" or userIn == "D" then
			local rf = ""
			local powerGen = ""

			if debug then 
				print(data.stats.isActive)
				print(data.energy.reactorProcessPower)
			end

			if data.energy.reactorProcessPower > 0 then
				rf = " RF/t"
				powerGen = data.energy.reactorProcessPower
			else
				powerGen = "REACTOR OFFLINE"
			end
			print(string.format("%.1f", data.energy.currentEnergy / 1000) .. " kRF stored out of " .. string.format("%.0f", data.energy.maxEnergy / 1000) .. " kRF [" .. string.format("%.0f", (data.energy.currentEnergy / data.energy.maxEnergy) * 100) .. "%]")
			print("Power generation: " .. powerGen .. rf)
			pressEnter()
		elseif userIn == "e" or userIn == "E" then
			print("---")
			print("Fuel type: " .. data.fuel.fuelType)
			print("Fuel burn time: " .. (data.fuel.fuelTime / 20) / 60 .. " Minutes")
			print("Remaining burn time: " .. math.floor(((data.fuel.fuelTime - data.fuel.currentProcessTime) / 20) / 60) .. " minutes " .. "[" .. string.format("%.0f", (((data.fuel.fuelTime - data.fuel.currentProcessTime) / data.fuel.fuelTime) * 100)) .. "%]")
			print("Fuel power generation: " .. data.fuel.fuelPower .. " RF/t")
			pressEnter()
		elseif userIn == "f" or userIn == "F" then
			break
		else
			print("Invalid input")
		end
	end
end

--UNUSED
function getUnserMessage()
	local fail = "fail"
	m.broadcast(DATAPORT, "hub_getInfo")
	openPort(HUBPORT, debug)
	local mtype, _, _, _, _, message = event.pull(5, "modem_message")
	if mtype == "modem_message" and message ~= nil and message ~= "{}" then
		message = serialization.unserialize(message)
		return message
	else
		return fail
	end
end

function selectReactor()
	--shows list of reactors connected and allows user to choose
	local selected = selectListReactors()
	if debug then print(selected) end
	--commands
	while true do
		print("---")
		print("a = Startup reactor")
		print("b = Shutdown reactor")
		print("c = Enable forceOn")
		print("d = Disable forceOn")
		print("e = Reactor Stats")
		print("f - Back to main menu")
		local userIn = io.read()
		
		if userIn == "a" or userIn == "A" then
			startReactor(true, selected)
		elseif userIn == "b" or userIn == "B" then
			startReactor(false, selected)
		elseif userIn == "c" or userIn == "C" then
			enableForceOn(true, selected)
		elseif userIn == "d" or userIn == "D" then
			enableForceOn(true, selected)
		elseif userIn == "e" or userIn == "E" then
			getReactorInforamtion(selected)
		elseif userIn == "f" or userIn == "F" then
			openPort(PORT, debug)
			break
		else
			print("Invalid input")
		end
	end
end

function debugOptions(userIn, debug)
	if userIn == "a" or userIn == "A" then
		debug = not debug
		print("debug set to " .. tostring(debug))
		return debug
	elseif userIn == "b" or userIn == "B" then
		m.broadcast(DATAPORT, "server_clearAllData")
		return debug
	else
		print("Invalid input")
		pressEnter()
	end
end

openPort(PORT, debug)

while active do
	print("---")
	-- options
	print("a = Select reactor from list")
	print("b = Show list of connected reactors")
	print("c = Show All-Reactor commands")
	print("d = Debug")
	print("e = Shutdown program (shuts down all reactors as well)")
	userIn = io.read()
	if userIn == "a" or userIn == "A" then
		selectReactor()
	elseif userIn == "b" or userIn == "B" then
		listReactors()
		pressEnter()
	elseif userIn == "c" or userIn == "C" then
		allReactorCommands()
	elseif userIn == "d" or userIn == "D" then
		print("---")
		print("a = Turn off or on debugging")
		print("b = Clear server data")
		userInDebug = io.read()

		debug = debugOptions(userInDebug, debug)
		openPort(PORT, debug)
	elseif userIn == "e" or userIn == "E" then
		shutDown()
	else
		print("Invalid input")
	end
end
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

local MSGPORT = 1 --hub commands
local DATAPORT = 2 -- reactor data and server
local HUBPORT = 3 -- unused

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

--shuts down all reactors connected and "exits" program
function shutDown()
	local sendCommand = {}
	local sendCommand2 = {}
	print("---")
	print("Are you sure? y/n")
	local userIn = io.read()

	if userIn == "y" or userIn == "Y" or userIn == "ye" or userIn == "yeah" or userIn == "yes" or userIn == "Yes" or userIn == "Yeah" or userIn == "yea" or userIn == "Yea" or userIn == "sure" or userIn == "Sure" or userIn == "i am" or userIn == "I am" then
		--active = false
		print("Deactivated reactors and disabled force-on")

		sendCommand["type"] = "gobal_reactor_command"
		sendCommand["cmd"] = "reactor_deactivate_all"
		sendCommand2["type"] = "gobal_reactor_command"
		sendCommand2["cmd"] = "reactor_forceOff_all"

		sendCommand = serialization.serialize(sendCommand)
		sendCommand2 = serialization.serialize(sendCommand2)

		m.broadcast(MSGPORT, sendCommand)
		m.broadcast(MSGPORT, sendCommand2)

		print("")
		return false
	else
		return true
	end
end

--lists all reactors connected to the server
function listReactors()
	local reactorCount = 0
	local s = " reactor "
	local sendCommand = {}
	sendCommand["type"] = "reactor_server_commands"
	sendCommand["cmd"] = "hub_getInfo"
	sendCommand = serialization.serialize(sendCommand)

	print("---")
	m.broadcast(DATAPORT, sendCommand)
	--openPort(HUBPORT, debug)
	local mtype, _, _, _, _, message = event.pull(5, "modem_message")
	if mtype == "modem_message" and message ~= nil and message ~= "{}" and type(message) == "string" then
		message = serialization.unserialize(message)
		if message ~= nil then
			if message.type == "reactor_data_toHub" then
				for k, v in pairs(message) do
					if k ~= "type" then
						print(k)
						reactorCount = reactorCount + 1
					end
				end
				if debug then print(tostring(reactorCount) .. " connected") end
				if reactorCount > 1 then
					s = " reactors "
				end
				print("")
				print("In total, " .. reactorCount .. s .. "connected")
			else
				print("Invalid data received")
			end
		else
			print("Invalid data received")
		end
	else
		print("There is no reactors connected to the server/no connection to server")
	end
	--openPort(MSGPORT, debug)
end

function pressEnter()
	print("")
	print("Press enter to continue:")
	io.read()
end

--gobal reactor controls
function allReactorCommands()
	local reactorCommandPacket = {}
	reactorCommandPacket["type"] = "gobal_reactor_command"
	local actAll = "reactor_activate_all"
	local deactAll = "reactor_deactivate_all"
	local forceOnAll = "reactor_forceOn_all"
	local forceOffAll = "reactor_forceOff_all"
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
			reactorCommandPacket["cmd"] = actAll
			serReactorCommandPacket = serialization.serialize(reactorCommandPacket)
			m.broadcast(MSGPORT, serReactorCommandPacket)
			
		elseif commandIn == "b" or commandIn == "B" then
			reactorCommandPacket["cmd"] = deactAll
			serReactorCommandPacket = serialization.serialize(reactorCommandPacket)
			m.broadcast(MSGPORT, serReactorCommandPacket)

		elseif commandIn == "c" or commandIn == "C" then
			reactorCommandPacket["cmd"] = forceOnAll
			serReactorCommandPacket = serialization.serialize(reactorCommandPacket)
			m.broadcast(MSGPORT, serReactorCommandPacket)

		elseif commandIn == "d" or commandIn == "D" then
			reactorCommandPacket["cmd"] = forceOffAll
			serReactorCommandPacket = serialization.serialize(reactorCommandPacket)
			m.broadcast(MSGPORT, serReactorCommandPacket)

		elseif commandIn == "e" or commandIn == "E" then
			return
		else
			print("Invalid input")
		end
	end
end

--lists all reactors and allows user to select a reactor for further controls
function selectListReactors()
	local selected = {}
	local index = 0
	local sendCommand = {}
	--requests data from server
	sendCommand["type"] = "reactor_server_commands"
	sendCommand["cmd"] = "hub_getInfo"
	sendCommand = serialization.serialize(sendCommand)

	print("---")
	m.broadcast(DATAPORT, sendCommand)
	local mtype, _, _, _, _, message = event.pull(5, "modem_message")
	if mtype == "modem_message" and message ~= nil and message ~= "{}" and type(message) == "string" then
		message = serialization.unserialize(message)
		if message ~= nil then
			if message.type == "reactor_data_toHub" then
				listidx = {}
				for k, v in pairs(message) do
					if k ~= "type" then
						index = index + 1
						print(index .. " = " .. k)
						table.insert(listidx, v) --adds a entry with a number and reactor information

						if index%15 == 0 then
							pressEnter()
						end
					end
				end
				print("")
				print("Select a reactor to control (number):")
				selected = listidx[tonumber(io.read())] -- sets "selected" as the information of the selected number
			else
				print("Data received was not reactor_data_toHub")
				return true
			end
		else
			print("Data received was nil")
			return true
		end
	else
		print("There is no reactors connected to the server/no connection to server")
		return true
	end
	--openPort(MSGPORT, debug)
	if debug then print("returned selected number") end
	return selected
end

--returns on/off command for reactor depending on input
function startReactor(status, data)
	if debug then
		print(data)
		print("status = " .. tostring(status))
	end
	local startCMD = "reactor_activate"
	local stopCMD = "reactor_deactivate"
	local message = {}

	message["type"] = "local_reactor_command"
	message["id"] = data.id
	if status then
		message["cmd"] = startCMD
	else
		message["cmd"] = stopCMD
	end
	send = serialization.serialize(message)
	m.broadcast(MSGPORT, send)
	if debug then print("sent start/stop reactor commands to reactor " .. data.id .. " on port " .. MSGPORT) end
end

--forces reactor to stay active even if stored energy is full
function enableForceOn(status, data)
	if debug then
		print(data)
		print("status = " .. tostring(status))
	end
	local enableCMD = "reactor_forceOn"
	local disableCMD = "reactor_forceOff"
	local message = {}

	message["type"] = "local_reactor_command"
	message["id"] = data.id
	if status then
		message["cmd"] = enableCMD
	else
		message["cmd"] = disableCMD
	end
	send = serialization.serialize(message)
	m.broadcast(MSGPORT, send)
	if debug then print("sent enable/disable force on commands to reactor " .. data.id .. " on port " .. MSGPORT) end	
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
			return
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
	if debug then print(tostring(selected)) end
	--commands
	if selected ~= true then
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
				enableForceOn(false, selected)
			elseif userIn == "e" or userIn == "E" then
				getReactorInforamtion(selected)
			elseif userIn == "f" or userIn == "F" then
				openPort(MSGPORT, debug)
				return
			else
				print("Invalid input")
			end
		end
	end
end

--sends a 
function commandSend(type, command, port)
	local commandPacket = {}
	commandPacket["type"] = type
	commandPacket["cmd"] = command
	serCommandPacket = serialization.serialize(commandPacket)
	if debug then
		print(serCommandPacket)
	end
	m.broadcast(port, serCommandPacket)
end

function debugOptions(debug)
	while true do
		print("---")
		print("a = Turn off or on debugging")
		print("b = Clear server memory data")
		print("c = Delete server save data")
		print("d = Soft shutdown server (stops script)")
		print("e = Hard shutdown server (shuts down server)")
		print("f = Back to main menu")
		local userIn = io.read()

		local commandType = "reactor_server_commands"
		local clearMem = "reactorServer_clearMemoryData"
		local wipeSave = "reactorServer_clearDiskData"
		local softShutdown = "reactorServer_softShutdown"
		local hardShutdown = "reactorServer_hardShutdown"

		--local commands
		if userIn == "a" or userIn == "A" then --enables computer debugging (ish)
			debug = not debug
			print("debug set to " .. tostring(debug))
			return debug

		--server commands
		elseif userIn == "b" or userIn == "B" then --clears server's "data" value
			--commandPacket["cmd"] = clearMem
			--serCommandPacket = serialization.serialize(commandPacket)
			--m.broadcast(DATAPORT, serCommandPacket)
			commandSend(commandType, clearMem, DATAPORT)
			return debug
		elseif userIn == "c" or userIn == "C" then --deletes server savedata file
			commandSend(commandType, wipeSave, DATAPORT)
			return debug
		elseif userIn == "d" or userIn == "D" then --terminates script
			commandSend(commandType, softShutdown, DATAPORT)
			return debug
		elseif userIn == "e" or userIn == "E" then --turns off the server/computer in 10 seconds
			commandSend(commandType, hardShutdown, DATAPORT)
			return debug
		elseif userIn == "f" or userIn == "F" then
			return
		else
			print("Invalid input")
		end
	end
end

openPort(MSGPORT, debug)

while active do
	print("---")
	-- options
	print("a = Select reactor from list")
	print("b = Show list of connected reactors")
	print("c = Show All-Reactor commands")
	print("d = Debug")
	print("e = Shutdown program (shuts down all reactors as well)")
	local userIn = io.read()
	if userIn == "a" or userIn == "A" then
		selectReactor()
	elseif userIn == "b" or userIn == "B" then
		listReactors()
		pressEnter()
	elseif userIn == "c" or userIn == "C" then
		allReactorCommands()
	elseif userIn == "d" or userIn == "D" then
		debug = debugOptions(debug)
		--openPort(MSGPORT, debug)
	elseif userIn == "e" or userIn == "E" then
		active = shutDown()
	else
		print("Invalid input")
	end
end

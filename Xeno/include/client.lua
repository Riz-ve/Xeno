--!native
--!optimize 2
local XENO_UNIQUE = "%XENO_UNIQUE_ID%"

local HttpService, UserInputService, InsertService = game:FindService("HttpService"), game:FindService("UserInputService"), game:FindService("InsertService")
local RunService, CoreGui, StarterGui = game:GetService("RunService"), game:FindService("CoreGui"), game:GetService("StarterGui")
local VirtualInputManager, RobloxReplicatedStorage = Instance.new("VirtualInputManager"), game:GetService("RobloxReplicatedStorage")

if RobloxReplicatedStorage:FindFirstChild("Xeno") then return end

local XenoContainer = Instance.new("Folder", RobloxReplicatedStorage)
XenoContainer.Name = "Xeno"
local objectPointerContainer, scriptsContainer = Instance.new("Folder", XenoContainer), Instance.new("Folder", XenoContainer)
objectPointerContainer.Name = "Instance Pointers"
scriptsContainer.Name = "Scripts"

local Xeno = {
	about = {
		_name = 'Xeno',
		_version = '%XENO_VERSION%',
		_publisher = ".rizve | https://rizve.us.to"
	}
}
table.freeze(Xeno.about)

local coreModules, blacklistedModuleParents = {}, {
	"Common",
	"Settings",
	"PlayerList",
	"InGameMenu",
	"PublishAssetPrompt",
	"TopBar",
	"InspectAndBuy",
	"VoiceChat",
	"Chrome",
	"PurchasePrompt",
	"VR",
	"EmotesMenu"
}

for _, descendant in CoreGui.RobloxGui.Modules:GetDescendants() do
	if descendant.ClassName == "ModuleScript" and
		(function()
			for i, parentName in next, blacklistedModuleParents do
				if descendant:IsDescendantOf(CoreGui.RobloxGui.Modules[parentName]) then
					return
				end
			end
			return true
		end)()
	then
		table.insert(coreModules, descendant)
	end
end

local libs = {
	{
		['name'] = "HashLib",
		['url'] = "https://rizve.us.to/Xeno/hash"
	},
	{
		['name'] = "lz4",
		['url'] = "https://rizve.us.to/Xeno/lz4"
	},
	{
		['name'] = "DrawingLib",
		['url'] = "https://rizve.us.to/Xeno/drawing"
	}
}

if script.Name == "VRNavigation" then
	StarterGui:SetCore("SendNotification", {
		Title = "[Xeno]",
		Text = "Used ingame method. When you leave the game it might crash!"
	})
end

local lookupValueToCharacter = buffer.create(64)
local lookupCharacterToValue = buffer.create(256)

local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local padding = string.byte("=")

for index = 1, 64 do
	local value = index - 1
	local character = string.byte(alphabet, index)

	buffer.writeu8(lookupValueToCharacter, value, character)
	buffer.writeu8(lookupCharacterToValue, character, value)
end

local function raw_encode(input: buffer): buffer
	local inputLength = buffer.len(input)
	local inputChunks = math.ceil(inputLength / 3)

	local outputLength = inputChunks * 4
	local output = buffer.create(outputLength)

	-- Since we use readu32 and chunks are 3 bytes large, we can't read the last chunk here
	for chunkIndex = 1, inputChunks - 1 do
		local inputIndex = (chunkIndex - 1) * 3
		local outputIndex = (chunkIndex - 1) * 4

		local chunk = bit32.byteswap(buffer.readu32(input, inputIndex))

		-- 8 + 24 - (6 * index)
		local value1 = bit32.rshift(chunk, 26)
		local value2 = bit32.band(bit32.rshift(chunk, 20), 0b111111)
		local value3 = bit32.band(bit32.rshift(chunk, 14), 0b111111)
		local value4 = bit32.band(bit32.rshift(chunk, 8), 0b111111)

		buffer.writeu8(output, outputIndex, buffer.readu8(lookupValueToCharacter, value1))
		buffer.writeu8(output, outputIndex + 1, buffer.readu8(lookupValueToCharacter, value2))
		buffer.writeu8(output, outputIndex + 2, buffer.readu8(lookupValueToCharacter, value3))
		buffer.writeu8(output, outputIndex + 3, buffer.readu8(lookupValueToCharacter, value4))
	end

	local inputRemainder = inputLength % 3

	if inputRemainder == 1 then
		local chunk = buffer.readu8(input, inputLength - 1)

		local value1 = bit32.rshift(chunk, 2)
		local value2 = bit32.band(bit32.lshift(chunk, 4), 0b111111)

		buffer.writeu8(output, outputLength - 4, buffer.readu8(lookupValueToCharacter, value1))
		buffer.writeu8(output, outputLength - 3, buffer.readu8(lookupValueToCharacter, value2))
		buffer.writeu8(output, outputLength - 2, padding)
		buffer.writeu8(output, outputLength - 1, padding)
	elseif inputRemainder == 2 then
		local chunk = bit32.bor(
			bit32.lshift(buffer.readu8(input, inputLength - 2), 8),
			buffer.readu8(input, inputLength - 1)
		)

		local value1 = bit32.rshift(chunk, 10)
		local value2 = bit32.band(bit32.rshift(chunk, 4), 0b111111)
		local value3 = bit32.band(bit32.lshift(chunk, 2), 0b111111)

		buffer.writeu8(output, outputLength - 4, buffer.readu8(lookupValueToCharacter, value1))
		buffer.writeu8(output, outputLength - 3, buffer.readu8(lookupValueToCharacter, value2))
		buffer.writeu8(output, outputLength - 2, buffer.readu8(lookupValueToCharacter, value3))
		buffer.writeu8(output, outputLength - 1, padding)
	elseif inputRemainder == 0 and inputLength ~= 0 then
		local chunk = bit32.bor(
			bit32.lshift(buffer.readu8(input, inputLength - 3), 16),
			bit32.lshift(buffer.readu8(input, inputLength - 2), 8),
			buffer.readu8(input, inputLength - 1)
		)

		local value1 = bit32.rshift(chunk, 18)
		local value2 = bit32.band(bit32.rshift(chunk, 12), 0b111111)
		local value3 = bit32.band(bit32.rshift(chunk, 6), 0b111111)
		local value4 = bit32.band(chunk, 0b111111)

		buffer.writeu8(output, outputLength - 4, buffer.readu8(lookupValueToCharacter, value1))
		buffer.writeu8(output, outputLength - 3, buffer.readu8(lookupValueToCharacter, value2))
		buffer.writeu8(output, outputLength - 2, buffer.readu8(lookupValueToCharacter, value3))
		buffer.writeu8(output, outputLength - 1, buffer.readu8(lookupValueToCharacter, value4))
	end

	return output
end

local function raw_decode(input: buffer): buffer
	local inputLength = buffer.len(input)
	local inputChunks = math.ceil(inputLength / 4)

	-- TODO: Support input without padding
	local inputPadding = 0
	if inputLength ~= 0 then
		if buffer.readu8(input, inputLength - 1) == padding then inputPadding += 1 end
		if buffer.readu8(input, inputLength - 2) == padding then inputPadding += 1 end
	end

	local outputLength = inputChunks * 3 - inputPadding
	local output = buffer.create(outputLength)

	for chunkIndex = 1, inputChunks - 1 do
		local inputIndex = (chunkIndex - 1) * 4
		local outputIndex = (chunkIndex - 1) * 3

		local value1 = buffer.readu8(lookupCharacterToValue, buffer.readu8(input, inputIndex))
		local value2 = buffer.readu8(lookupCharacterToValue, buffer.readu8(input, inputIndex + 1))
		local value3 = buffer.readu8(lookupCharacterToValue, buffer.readu8(input, inputIndex + 2))
		local value4 = buffer.readu8(lookupCharacterToValue, buffer.readu8(input, inputIndex + 3))

		local chunk = bit32.bor(
			bit32.lshift(value1, 18),
			bit32.lshift(value2, 12),
			bit32.lshift(value3, 6),
			value4
		)

		local character1 = bit32.rshift(chunk, 16)
		local character2 = bit32.band(bit32.rshift(chunk, 8), 0b11111111)
		local character3 = bit32.band(chunk, 0b11111111)

		buffer.writeu8(output, outputIndex, character1)
		buffer.writeu8(output, outputIndex + 1, character2)
		buffer.writeu8(output, outputIndex + 2, character3)
	end

	if inputLength ~= 0 then
		local lastInputIndex = (inputChunks - 1) * 4
		local lastOutputIndex = (inputChunks - 1) * 3

		local lastValue1 = buffer.readu8(lookupCharacterToValue, buffer.readu8(input, lastInputIndex))
		local lastValue2 = buffer.readu8(lookupCharacterToValue, buffer.readu8(input, lastInputIndex + 1))
		local lastValue3 = buffer.readu8(lookupCharacterToValue, buffer.readu8(input, lastInputIndex + 2))
		local lastValue4 = buffer.readu8(lookupCharacterToValue, buffer.readu8(input, lastInputIndex + 3))

		local lastChunk = bit32.bor(
			bit32.lshift(lastValue1, 18),
			bit32.lshift(lastValue2, 12),
			bit32.lshift(lastValue3, 6),
			lastValue4
		)

		if inputPadding <= 2 then
			local lastCharacter1 = bit32.rshift(lastChunk, 16)
			buffer.writeu8(output, lastOutputIndex, lastCharacter1)

			if inputPadding <= 1 then
				local lastCharacter2 = bit32.band(bit32.rshift(lastChunk, 8), 0b11111111)
				buffer.writeu8(output, lastOutputIndex + 1, lastCharacter2)

				if inputPadding == 0 then
					local lastCharacter3 = bit32.band(lastChunk, 0b11111111)
					buffer.writeu8(output, lastOutputIndex + 2, lastCharacter3)
				end
			end
		end
	end

	return output
end

local base64 = {
	encode = function(input)
		return buffer.tostring(raw_encode(buffer.fromstring(input)))
	end,
	decode = function(encoded)
		return buffer.tostring(raw_decode(buffer.fromstring(encoded)))
	end,
}

local Bridge, ProcessID = {serverUrl = "http://localhost:19283"}, nil

local _require, _game, _workspace = require, game, workspace

local function sendRequest(options, timeout)
	timeout = tonumber(timeout) or math.huge
	local result, clock = nil, tick()

	HttpService:RequestInternal(options):Start(function(success, body)
		result = body
		result['Success'] = success
	end)

	while not result do task.wait()
		if (tick() - clock > timeout) then
			break
		end
	end

	return result
end

function Bridge:InternalRequest(body, timeout)
	local url = self.serverUrl .. '/send'
	if body.Url then
		url = body.Url
		body["Url"] = nil
		local options = {
			Url = url,
			Body = body['ct'],
			Method = 'POST',
			Headers = {
				['Content-Type'] = 'text/plain'
			}
		}
		local result = sendRequest(options, timeout)
		local statusCode = tonumber(result.StatusCode)
		if statusCode and statusCode >= 200 and statusCode < 300 then
			return result.Body or true
		end

		local success, result = pcall(function()
			local decoded = HttpService:JSONDecode(result.Body)
			if decoded and type(decoded) == "table" then
				return decoded.error
			end
		end)

		if success and result then
			error(result, 2)
			return
		end

		error("An unknown error occured by the server.", 2)
		return
	end

	local success = pcall(function()
		body = HttpService:JSONEncode(body)
	end) if not success then return end

	local options = {
		Url = url,
		Body = body,
		Method = 'POST',
		Headers = {
			['Content-Type'] = 'application/json'
		}
	}

	local result = sendRequest(options, timeout)

	if type(result) ~= 'table' then return end

	local statusCode = tonumber(result.StatusCode)
	if statusCode and statusCode >= 200 and statusCode < 300 then
		return result.Body or true
	end

	local success, result = pcall(function()
		local decoded = HttpService:JSONDecode(result.Body)
		if decoded and type(decoded) == "table" then
			return decoded.error
		end
	end)

	if success and result then
		error("XENO SERVER ERROR: " .. tostring(result), 2)
	end

	error("An unknown error occured by the server.", 2)
end

function Bridge:readfile(path)
	local result = self:InternalRequest({
		['c'] = "rf",
		['p'] = path,
	})
	if result then
		return result
	end
end
function Bridge:writefile(path, content)
	local result = self:InternalRequest({
		['Url'] = self.serverUrl .. "/writefile?p=" .. path,
		['ct'] = content
	})
	return result ~= nil
end
function Bridge:isfolder(path)
	local result = self:InternalRequest({
		['c'] = "if",
		['p'] = path,
	})
	if result then
		return result == "dir"
	end
	return false
end
function Bridge:isfile(path)
	local result = self:InternalRequest({
		['c'] = "if",
		['p'] = path,
	})
	if result then
		return result == "file"
	end
	return false
end
function Bridge:listfiles(path)
	local result = self:InternalRequest({
		['c'] = "lf",
		['p'] = path,
	})
	if result then
		local files = HttpService:JSONDecode(result) or {}
		for i, file in ipairs(files) do
			files[i] = file:gsub("\\", "/") -- normalize paths
		end
		return files or {}
	end
	return {}
end
function Bridge:makefolder(path)
	local result = self:InternalRequest({
		['c'] = "mf",
		['p'] = path,
	})
	return result ~= nil
end
function Bridge:delfolder(path)
	local result = self:InternalRequest({
		['c'] = "dfl",
		['p'] = path,
	})
	return result ~= nil
end
function Bridge:delfile(path)
	local result = self:InternalRequest({
		['c'] = "df",
		['p'] = path,
	})
	return result ~= nil
end

Bridge.virtualFilesManagement = {
	['saved'] = {},
	['unsaved'] = {}
}

function Bridge:SyncFiles()
	local allFiles = {}
	local function getAllFiles(dir)
		local files = self:listfiles(dir)
		if #files < 1 then return end
		for _, filePath in files do
			table.insert(allFiles, filePath)
			if self:isfolder(filePath) then
				getAllFiles(filePath)
			end
		end
	end
	local success = pcall(function()
		getAllFiles("./")
	end) if not success then
		StarterGui:SetCore("SendNotification", {
			Title = "[Xeno]",
			Text = "Could not sync virtual files from client to external. Server was closed or it is being overloaded"
		})
		return
	end
	local latestSave = {}

	local success, r = pcall(function()
		for _, filePath in allFiles do
			table.insert(latestSave, {
				path = filePath,
				isFolder = self:isfolder(filePath)
			})
		end
	end) if not success then return end

	self.virtualFilesManagement.saved = latestSave

	local unsuccessfulSave = {}

	local success, r = pcall(function()
		for _, unsavedFile in self.virtualFilesManagement.unsaved do
			local func = unsavedFile.func
			local argX = unsavedFile.x
			local argY = unsavedFile.y
			local success, r = pcall(function()
				return func(self, argX, argY)
			end)
			if (not success) or (not r) then
				if not unsavedFile.last_attempt then
					table.insert(unsuccessfulSave, {
						func = func,
						x = argX,
						y = argY,
						last_attempt = true
					})
				end
			end
		end
	end) if not success then return end

	self.virtualFilesManagement.unsaved = unsuccessfulSave
end

function Bridge:CanCompile(source, returnBytecode)
	local requestArgs = {
		['Url'] = self.serverUrl .. "/compilable",
		['ct'] = source
	}
	if returnBytecode then
		requestArgs.Url = self.serverUrl .. "/compilable?btc=t"
	end
	local result = self:InternalRequest(requestArgs)
	if result then
		if result == "success" then
			return true
		end
		return false, result
	end
	return false, "Unknown Error"
end

function Bridge:loadstring(source, chunkName)
	local cachedModules = {}
	local coreModule = _game.Clone(coreModules[math.random(1, #coreModules)])
	coreModule:ClearAllChildren()
	coreModule.Name = HttpService:GenerateGUID(false) .. ":" .. chunkName
	coreModule.Parent = XenoContainer
	table.insert(cachedModules, coreModule)

	local result = self:InternalRequest({
		['Url'] = self.serverUrl .. "/loadstring?n=" .. coreModule.Name .. "&cn=" .. chunkName .. "&pid=" .. tostring(ProcessID),
		['ct'] = source
	})

	if result then
		local clock = tick()
		while task.wait() do
			local required = nil
			pcall(function()
				required = _require(coreModule)
			end)

			if type(required) == "table" and required[chunkName] and type(required[chunkName]) == "function" then
				if (#cachedModules > 1) then
					for _, module in pairs(cachedModules) do
						if module == coreModule then continue end
						module:Destroy()
					end
				end
				return required[chunkName] -- fake luaVM load done externally
			end

			if (tick() - clock > 5) then
				warn("[XENO]: loadstring failed and timed out")
				for _, module in pairs(cachedModules) do
					module:Destroy()
				end
				return nil, "loadstring failed and timed out"
			end

			task.wait(.06)

			coreModule = _game.Clone(coreModules[math.random(1, #coreModules)])
			coreModule:ClearAllChildren()
			coreModule.Name = HttpService:GenerateGUID(false) .. ":" .. chunkName
			coreModule.Parent = XenoContainer

			self:InternalRequest({
				['Url'] = self.serverUrl .. "/loadstring?n=" .. coreModule.Name .. "&cn=" .. chunkName .. "&pid=" .. tostring(ProcessID),
				['ct'] = source
			})

			table.insert(cachedModules, coreModule)
		end
	end
end

function Bridge:request(options)
	local result = self:InternalRequest({
		['c'] = "rq",
		['l'] = options.Url,
		['m'] = options.Method,
		['h'] = options.Headers,
		['b'] = options.Body or "{}"
	})
	if result then
		result = HttpService:JSONDecode(result)
		if result['r'] ~= "OK" then
			result['r'] = "Unknown"
		end
		if result['b64'] then
			result['b'] = base64.decode(result['b'])
		end
		return {
			Success = tonumber(result['c']) and tonumber(result['c']) > 200 and tonumber(result['c']) < 300,
			StatusMessage = result['r'], -- OK
			StatusCode = tonumber(result['c']), -- 200
			Body = result['b'],
			HttpError = Enum.HttpError[result['r']],
			Headers = result['h'],
			Version = result['v']
		}
	end
	return {
		Success = false,
		StatusMessage = "Can't connect to Xeno web server: " .. self.serverUrl,
		StatusCode = 599;
		HttpError = Enum.HttpError.ConnectFail
	}
end

function Bridge:setclipboard(content)
	local result = self:InternalRequest({
		['Url'] = self.serverUrl .. "/setclipboard",
		['ct'] = content
	})
	return result ~= nil
end

function Bridge:rconsole(_type, content)
	if _type == "cls" or _type == "crt" or _type == "dst" then
		local result = self:InternalRequest({
			['c'] = "rc",
			['t'] = _type
		})
		return result ~= nil
	end
	local result = self:InternalRequest({
		['c'] = "rc",
		['t'] = _type,
		['ct'] = base64.encode(content)
	})
	return result ~= nil
end

function Bridge:getscriptbytecode(instance)
	local objectValue = Instance.new("ObjectValue", objectPointerContainer)
	objectValue.Name = HttpService:GenerateGUID(false)
	objectValue.Value = instance

	local result = self:InternalRequest({
		['c'] = "btc",
		['cn'] = objectValue.Name,
		['pid'] = tostring(ProcessID)
	})

	objectValue:Destroy()

	if result then
		return result
	end
	return ''
end

function Bridge:queue_on_teleport(_type, source)
	if _type == "s" then
		local result = self:InternalRequest({
			['c'] = "qtp",
			['t'] = "s",
			['ct'] = source,
			['pid'] = tostring(ProcessID)
		})
		if result then
			return true
		end
	end
	local result = self:InternalRequest({
		['c'] = "qtp",
		['t'] = "g",
		['pid'] = tostring(ProcessID)
	})
	if result then
		return result
	end
	return ''
end
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

task.spawn(function()
	while true do
		Bridge:SyncFiles()
		task.wait(.65)
	end
end)

local hwid = HttpService:GenerateGUID(false)

task.spawn(function()
	local result = sendRequest({
		Url = Bridge.serverUrl .. "/send",
		Body = HttpService:JSONEncode({
			['c'] = "hw"
		}),
		Method = "POST"
	})
	if result.Body then
		hwid = result.Body:gsub("{", ""):gsub("}", "")
	end
end)

local function is_client_loaded()
	local result = sendRequest({
		Url = Bridge.serverUrl .. "/send",
		Body = HttpService:JSONEncode({
			['c'] = "clt",
			['gd'] = XENO_UNIQUE,
		}),
		Method = "POST"
	})
	if result.Body then
		return result.Body
	end
	return false
end

ProcessID = is_client_loaded()
while not tonumber(ProcessID) do
	ProcessID = is_client_loaded()
end

-- / IMPORTANT FUNCS \ --
local httpSpy = false
Xeno.Xeno = {
	PID = ProcessID,
	GUID = XENO_UNIQUE,
	HttpSpy = function(state)
		if state == nil then state = true end
		assert(type(state) == "boolean", "invalid argument #1 to 'HttpSpy' (boolean expected, got " .. type(state) .. ") ", 2)
		Xeno.rconsoleinfo("Http Spy is set to '" .. tostring(state) .. "'")
		httpSpy = state
	end,
}

function Xeno.Xeno.get_real_address(instance)
	assert(typeof(instance) == "Instance", "invalid argument #1 to 'get_real_address' (Instance expected, got " .. typeof(instance) .. ") ", 2)
	local objectValue = Instance.new("ObjectValue", objectPointerContainer)
	objectValue.Name = HttpService:GenerateGUID(false)
	objectValue.Value = instance
	local result = Bridge:InternalRequest({
		['c'] = "adr",
		['cn'] = objectValue.Name,
		['pid'] = tostring(ProcessID)
	})
	objectValue:Destroy()
	if tonumber(result) then
		return tonumber(result)
	end
	return 0
end

function Xeno.Xeno.spoof_instance(instance, newinstance)
	assert(typeof(instance) == "Instance", "invalid argument #1 to 'spoof_instance' (Instance expected, got " .. typeof(instance) .. ") ", 2)
	assert(typeof(newinstance) == "Instance" or type(newinstance) == "number", "invalid argument #2 to 'spoof_instance' (Instance or number expected, got " .. typeof(newinstance) .. ") ", 2)
	local newAddress
	do
		if type(newinstance) == "number" then 
			newAddress = newinstance
		else
			newAddress = Xeno.Xeno.get_real_address(newinstance)
		end
	end
	local objectValue = Instance.new("ObjectValue", objectPointerContainer)
	objectValue.Name = HttpService:GenerateGUID(false)
	objectValue.Value = instance
	local result = Bridge:InternalRequest({
		['c'] = "spf",
		['cn'] = objectValue.Name,
		['pid'] = tostring(ProcessID),
		['adr'] = tostring(newAddress)
	})
	objectValue:Destroy()
	return result ~= nil
end

-- globals, shared across all clients (made for testing only so its badly coded)
function Xeno.Xeno.GetGlobal(global_name)
	assert(type(global_name) == "string", "invalid argument #1 to 'GetGlobal' (string expected, got " .. type(global_name) .. ") ", 2)
	local result = Bridge:InternalRequest({
		['c'] = "gb",
		['t'] = "g",
		['n'] = global_name
	})
	if not result then
		return
	end

	result = HttpService:JSONDecode(result)
	if result.t == "string" then
		return tostring(result.d)
	end
	if result.t == "number" then
		return tonumber(result.d)
	end
	if result.t == "table" then
		return HttpService:JSONDecode(result.d)
	end
end
function Xeno.Xeno.SetGlobal(global_name, value)
	assert(type(global_name) == "string", "invalid argument #1 to 'SetGlobal' (string expected, got " .. type(global_name) .. ") ", 2)
	local valueT = type(value)
	assert(valueT == "string" or valueT == "number" or valueT == "table", "invalid argument #2 to 'SetGlobal' (string, number, or table expected, got " .. valueT .. ") ", 2)
	if valueT == "table" then
		value = HttpService:JSONEncode(value)
	end
	return Bridge:InternalRequest({
		['c'] = "gb",
		['t'] = "s",
		['n'] = global_name,
		['v'] = tostring(value),
		['vt'] = valueT
	}) ~= nil
end

function Xeno.Xeno.Compile(source)
	assert(type(source) == "string", "invalid argument #1 to 'Compile' (string expected, got " .. type(source) .. ") ", 2)
	if source == "" then return "" end
	local _, result = Bridge:CanCompile(source, true)
	return result
end

function Xeno.require(moduleScript)
	assert(typeof(moduleScript) == "Instance", "Attempted to call require with invalid argument(s). ", 2)
	assert(moduleScript.ClassName == "ModuleScript", "Attempted to call require with invalid argument(s). ", 2)

	local objectValue = Instance.new("ObjectValue", objectPointerContainer)
	objectValue.Name = HttpService:GenerateGUID(false)
	objectValue.Value = moduleScript

	Bridge:InternalRequest({
		['c'] = "um",
		['cn'] = objectValue.Name,
		['pid'] = tostring(ProcessID)
	})
	objectValue:Destroy()

	return _require(moduleScript)
end

function Xeno.loadstring(source, chunkName)
	assert(type(source) == "string", "invalid argument #1 to 'loadstring' (string expected, got " .. type(source) .. ") ", 2)
	chunkName = chunkName or "loadstring"
	assert(type(chunkName) == "string", "invalid argument #2 to 'loadstring' (string expected, got " .. type(chunkName) .. ") ", 2)
	chunkName = chunkName:gsub("[^%a_]", "")
	if (source == "" or source == " ") then
		return function(...) end
	end
	local success, err = Bridge:CanCompile(source)
	if not success then
		return nil, chunkName .. tostring(err)
	end
	local func = Bridge:loadstring(source, chunkName)
	setfenv(func, getfenv(debug.info(2, 'f')))
	return func
end

local supportedMethods = {"GET", "POST", "PUT", "DELETE", "PATCH"}

function Xeno.request(options)
	assert(type(options) == "table", "invalid argument #1 to 'request' (table expected, got " .. type(options) .. ") ", 2)
	assert(type(options.Url) == "string", "invalid option 'Url' for argument #1 to 'request' (string expected, got " .. type(options.Url) .. ") ", 2)
	options.Method = options.Method or "GET"
	options.Method = options.Method:upper()
	assert(table.find(supportedMethods, options.Method), "invalid option 'Method' for argument #1 to 'request' (a valid http method expected, got '" .. options.Method .. "') ", 2)
	assert(not (options.Method == "GET" and options.Body), "invalid option 'Body' for argument #1 to 'request' (current method is GET but option 'Body' was used)", 2)
	if options.Body then
		assert(type(options.Body) == "string", "invalid option 'Body' for argument #1 to 'request' (string expected, got " .. type(options.Body) .. ") ", 2)
		options.Body = base64.encode(options.Body)
	end
	if options.Headers then assert(type(options.Headers) == "table", "invalid option 'Headers' for argument #1 to 'request' (table expected, got " .. type(options.Url) .. ") ", 2) end
	options.Body = options.Body or "e30=" -- "{}" in base64
	options.Headers = options.Headers or {}
	if httpSpy then
		Xeno.rconsoleprint("-----------------[Xeno Http Spy]---------------\nUrl: " .. options.Url .. 
			"\nMethod: " .. options.Method .. 
			"\nBody: " .. options.Body .. 
			"\nHeaders: " .. tostring(HttpService:JSONEncode(options.Headers))
		)
	end
	if (options.Headers["User-Agent"]) then assert(type(options.Headers["User-Agent"]) == "string", "invalid option 'User-Agent' for argument #1 to 'request.Header' (string expected, got " .. type(options.Url) .. ") ", 2) end
	options.Headers["User-Agent"] = options.Headers["User-Agent"] or "Xeno/Roblox-Executor/" .. tostring(Xeno.about._version)
	options.Headers["Exploit-Guid"] = tostring(hwid)
	options.Headers["Xeno-Fingerprint"] = tostring(hwid)
	options.Headers["Roblox-Place-Id"] = tostring(game.PlaceId)
	options.Headers["Roblox-Game-Id"] = tostring(game.GameId)
	options.Headers["Roblox-Session-Id"] = HttpService:JSONEncode({
		["GameId"] = tostring(game.GameId),
		["PlaceId"] = tostring(game.PlaceId)
	})
	local response = Bridge:request(options)
	if httpSpy then
		Xeno.rconsoleprint("-----------------[Response]---------------\nStatusCode: " .. tostring(response.StatusCode) ..
			"\nStatusMessage: " .. tostring(response.StatusMessage) ..
			"\nSuccess: " .. tostring(response.Success) ..
			"\nBody: " .. tostring(response.Body) ..
			"\nHeaders: " .. tostring(HttpService:JSONEncode(response.Headers)) ..
			"--------------------------------\n\n"
		)
	end
	return response
end
Xeno.http = {request = Xeno.request}
Xeno.http_request = Xeno.request

function Xeno.HttpGet(url, returnRaw)
	assert(type(url) == "string", "invalid argument #1 to 'HttpGet' (string expected, got " .. type(url) .. ") ", 2)
	local returnRaw = returnRaw or true

	local result = Xeno.request({
		Url = url,
		Method = "GET"
	})

	if returnRaw then
		return result.Body
	end

	return HttpService:JSONDecode(result.Body)
end
function Xeno.HttpPost(url, body, contentType)
	assert(type(url) == "string", "invalid argument #1 to 'HttpPost' (string expected, got " .. type(url) .. ") ", 2)
	contentType = contentType or "application/json"
	return Xeno.request({
		Url = url,
		Method = "POST",
		body = body,
		Headers = {
			["Content-Type"] = contentType
		}
	})
end
function Xeno.GetObjects(asset)
	return {
		InsertService:LoadLocalAsset(asset)
	}
end

local proxiedServices = {
	LinkingService = {{
		"OpenUrl"
	}, game:GetService("LinkingService")},
	ScriptContext = {{
		"SaveScriptProfilingData", 
		"AddCoreScriptLocal",
		"ScriptProfilerService"
	}, game:GetService("ScriptContext")},
	MessageBusService = {{
		"Call",
		"GetLast",
		"GetMessageId",
		"GetProtocolMethodRequestMessageId",
		"GetProtocolMethodResponseMessageId",
		"MakeRequest",
		"Publish",
		"PublishProtocolMethodRequest",
		"PublishProtocolMethodResponse",
		"Subscribe",
		"SubscribeToProtocolMethodRequest",
		"SubscribeToProtocolMethodResponse"
	}, game:GetService("MessageBusService")},
	GuiService = {{
		"OpenBrowserWindow",
		"OpenNativeOverlay"
	}, game:GetService("GuiService")},
	MarketplaceService = {{
		"GetRobuxBalance",
		"PerformPurchase",
		"PerformPurchaseV2",
	}, game:GetService("MarketplaceService")},
	HttpRbxApiService = {{
		"GetAsyncFullUrl",
		"PostAsyncFullUrl",
		"GetAsync",
		"PostAsync",
		"RequestAsync"
	}, game:GetService("HttpRbxApiService")},
	--[[
	CoreGui = {{
		"TakeScreenshot",
		"ToggleRecording"
	}, game:GetService("CoreGui")},
	]]
	Players = {{
		"ReportAbuse",
		"ReportAbuseV3"
	}, game:GetService("Players")},
	HttpService = {{
		"RequestInternal"
	}, game:GetService("HttpService")},
	BrowserService = {{
		"ExecuteJavaScript",
		"OpenBrowserWindow",
		"ReturnToJavaScript",
		"OpenUrl",
		"SendCommand",
		"OpenNativeOverlay"
	}, game:GetService("BrowserService")},
	CaptureService = {{
		"DeleteCapture"
	}, game:GetService("CaptureService")},
	OmniRecommendationsService = {{
		"MakeRequest"
	}, game:GetService("OmniRecommendationsService")},
	OpenCloudService = {{
		"HttpRequestAsync"
	}, game:GetService("OpenCloudService")}
}

local function find(t, x)
	x = string.gsub(tostring(x), '\0', '') -- sometimes people will use null chars to bypass
	for i, v in t do
		if v:lower() == x:lower() then
			return true
		end
	end
end

local function setupBlockedServiceFuncs(serviceTable)
	serviceTable.proxy = newproxy(true)
	local proxyMt = getmetatable(serviceTable.proxy)
	
	proxyMt.__index = function(self, index)
		index = string.gsub(tostring(index), '\0', '')
		if find(serviceTable[1], index) then
			return function(self, ...)
				error("Attempt to call a blocked function: " .. index, 2)
			end
		end
		
		if index == "Parent" then
			return Xeno.game
		end

		if type(serviceTable[2][index]) == "function" then
			return function(self, ...)
				return serviceTable[2][index](serviceTable[2], ...)
			end
		else
			return serviceTable[2][index]
		end
	end

	proxyMt.__newindex = function(self, index, value)
		serviceTable[2][index] = value
	end

	proxyMt.__tostring = function(self)
		return serviceTable[2].Name
	end

	proxyMt.__metatable = getmetatable(serviceTable[2])
end

for i, serviceTable in proxiedServices do
	setupBlockedServiceFuncs(serviceTable)
end

Xeno.game = newproxy(true)
local gameProxy = getmetatable(Xeno.game)

gameProxy.__index = function(self, index)
	if index == "HttpGet" or index == "HttpGetAsync" then
		return function(self, ...)
			return Xeno.HttpGet(...)
		end
	elseif index == "HttpPost" or index == "HttpPostAsync" then
		return function(self, ...)
			return Xeno.HttpPost(...)
		end
	elseif index == "GetObjects" then
		return function(self, ...)
			return Xeno.GetObjects(...)
		end
	end

	if type(_game[index]) == "function" then
		return function(self, ...)
			if index == "GetService" or index == "FindService" then
				local args = {...}
				if proxiedServices[string.gsub(tostring(args[1]), '\0', '')] then
					return proxiedServices[string.gsub(args[1], '\0', '')].proxy
				end
			end
			if find({
				"Load",
				"OpenScreenshotsFolder",
				"OpenVideosFolder"
				}, index) then
				error("Attempt to call a blocked function: " .. tostring(index), 2)
			end
			return _game[index](_game, ...)
		end
	else
		if proxiedServices[index] then
			return proxiedServices[index].proxy
		end
		return _game[index]
	end
end

gameProxy.__newindex = function(self, index, value)
	_game[index] = value
end

gameProxy.__tostring = function(self)
	return _game.Name
end

gameProxy.__metatable = getmetatable(_game)

Xeno.Game = Xeno.game

Xeno.workspace = newproxy(true)
local workspaceProxy = getmetatable(Xeno.workspace)
workspaceProxy.__index = function(self, index)
	index = string.gsub(tostring(index), '\0', '')
	if index == "Parent" then
		return Xeno.game
	end

	if type(_workspace[index]) == "function" then
		return function(self, ...)
			return _workspace[index](_workspace, ...)
		end
	else
		return _workspace[index]
	end
end

workspaceProxy.__newindex = function(self, index, value)
	_workspace[index] = value
end

workspaceProxy.__tostring = function(self)
	return _workspace.Name
end

workspaceProxy.__metatable = getmetatable(_workspace)

Xeno.Workspace = Xeno.workspace

function Xeno.getgenv()
	return Xeno
end

-- / Filesystem \ --
local function normalize_path(path)
	if (path:sub(2, 2) ~= "/") then path = "./" .. path end
	if (path:sub(1, 1) == "/") then path = "." .. path end
	return path
end
local function getUnsaved(func, path)
	local unsaved = Bridge.virtualFilesManagement.unsaved
	for i, fileInfo in next, unsaved do
		if ("./" .. tostring(fileInfo.x) == path or fileInfo.x == path or normalize_path(tostring(fileInfo.path)) == path) and fileInfo.func == func then
			return unsaved[i], i
		end
	end
end
local function getSaved(path)
	local saves = Bridge.virtualFilesManagement.saved
	for i, fileInfo in next, saves do
		if fileInfo.path == path or "./" .. tostring(fileInfo.path) == path or normalize_path(tostring(fileInfo.path)) == path then
			return true, saves[i]
		end
	end
end

function Xeno.readfile(path)
	assert(type(path) == "string", "invalid argument #1 to 'readfile' (string expected, got " .. type(path) .. ") ", 2)
	local unsavedFile = getUnsaved(Bridge.writefile, path)
	if unsavedFile then
		return unsavedFile.y
	end
	return Bridge:readfile(path)
end
function Xeno.writefile(path, content)
	assert(type(path) == "string", "invalid argument #1 to 'writefile' (string expected, got " .. type(path) .. ") ", 2)
	assert(type(content) == "string", "invalid argument #2 to 'writefile' (string expected, got " .. type(content) .. ") ", 2)
	local unsavedFile, index = getUnsaved(Bridge.delfile, path)
	if unsavedFile then
		table.remove(Bridge.virtualFilesManagement.unsaved, index)
	end
	unsavedFile = getUnsaved(Bridge.writefile, path)
	if unsavedFile then
		unsavedFile.y = content
		return
	end
	table.insert(Bridge.virtualFilesManagement.unsaved, {
		func = Bridge.writefile,
		x = path,
		y = content
	})
end
function Xeno.appendfile(path, content)
	assert(type(path) == "string", "invalid argument #1 to 'appendfile' (string expected, got " .. type(path) .. ") ", 2)
	assert(type(content) == "string", "invalid argument #2 to 'appendfile' (string expected, got " .. type(content) .. ") ", 2)
	local unsavedFile = getUnsaved(Bridge.writefile, path)
	if unsavedFile then
		unsavedFile.y = unsavedFile.y .. content
		return true
	end
	local readVal = ""
	pcall(function()
		readVal = Bridge:readfile(path)
	end)
	Xeno.writefile(path, readVal .. content)
end
function Xeno.loadfile(path)
	assert(type(path) == "string", "invalid argument #1 to 'loadfile' (string expected, got " .. type(path) .. ") ", 2)
	return Xeno.loadstring(Xeno.readfile(path))
end
Xeno.dofile = Xeno.loadfile
function Xeno.isfolder(path)
	assert(type(path) == "string", "invalid argument #1 to 'isfolder' (string expected, got " .. type(path) .. ") ", 2)
	if getUnsaved(Bridge.delfolder, path) then
		return false
	end
	if getUnsaved(Bridge.makefolder, path) then
		return true
	end
	local s, saved = getSaved(path)
	if s then
		return saved.isFolder
	end
	return Bridge:isfolder(path)
end
function Xeno.isfile(path) -- return not Xeno.isfolder(path)
	assert(type(path) == "string", "invalid argument #1 to 'isfile' (string expected, got " .. type(path) .. ") ", 2)
	if getUnsaved(Bridge.delfile, path) then
		return false
	end
	if getUnsaved(Bridge.writefile, path) then
		return true
	end
	local s, saved = getSaved(path)
	if s then
		return not saved.isFolder
	end
	return Bridge:isfile(path)
end
function Xeno.listfiles(path)
	assert(type(path) == "string", "invalid argument #1 to 'listfiles' (string expected, got " .. type(path) .. ") ", 2)

	path = normalize_path(path)
	if path:sub(-1) ~= '/' then path = path .. '/' end

	local pathFiles, allFiles = {}, {}

	for _, fileInfo in Bridge.virtualFilesManagement.saved do
		table.insert(allFiles, normalize_path(tostring(fileInfo.path)))
	end

	for _, unsavedFile in Bridge.virtualFilesManagement.unsaved do
		if not (table.find(allFiles, normalize_path(unsavedFile.x)) or table.find(allFiles, unsavedFile.x)) then
			if type(unsavedFile.x) ~= "string" then continue end
			table.insert(allFiles, normalize_path(unsavedFile.x))
		end
	end

	for _, filePath in next, allFiles do
		if filePath:sub(1, #path) == path then
			local pathFile = path .. filePath:sub(#path + 1):split('/')[1]
			if not (table.find(pathFiles, pathFile) or table.find(pathFiles, normalize_path(pathFile) or table.find(pathFiles, './' .. pathFile))) then
				table.insert(pathFiles, pathFile)
			end
		end
	end

	return pathFiles
end
function Xeno.makefolder(path)
	assert(type(path) == "string", "invalid argument #1 to 'makefolder' (string expected, got " .. type(path) .. ") ", 2)
	local unsavedFile, index = getUnsaved(Bridge.delfolder, path)
	if unsavedFile then
		table.remove(Bridge.virtualFilesManagement.unsaved, index)
	end
	if getUnsaved(Bridge.makefolder, path) then
		return
	end
	table.insert(Bridge.virtualFilesManagement.unsaved, {
		func = Bridge.makefolder,
		x = path
	})
end
function Xeno.delfolder(path)
	assert(type(path) == "string", "invalid argument #1 to 'delfolder' (string expected, got " .. type(path) .. ") ", 2)
	local unsavedFile, index = getUnsaved(Bridge.makefolder, path)
	if unsavedFile then
		table.remove(Bridge.virtualFilesManagement.unsaved, index)
		return
	end
	if getUnsaved(Bridge.delfolder, path) then
		return
	end
	table.insert(Bridge.virtualFilesManagement.unsaved, {
		func = Bridge.delfolder,
		x = path
	})
end
function Xeno.delfile(path)
	assert(type(path) == "string", "invalid argument #1 to 'delfile' (string expected, got " .. type(path) .. ") ", 2)
	local unsavedFile, index = getUnsaved(Bridge.writefile, path)
	if unsavedFile then
		table.remove(Bridge.virtualFilesManagement.unsaved, index)
	end
	if getUnsaved(Bridge.delfile, path) then
		return
	end
	table.insert(Bridge.virtualFilesManagement.unsaved, {
		func = Bridge.delfile,
		x = path
	})
end

function Xeno.getcustomasset(path)
	assert(type(path) == "string", "invalid argument #1 to 'getcustomasset' (string expected, got " .. type(path) .. ") ", 2)
	local unsaved, i, _break = getUnsaved(Bridge.writefile, path), nil
	while unsaved do 
		unsaved, i = getUnsaved(Bridge.writefile, path)
		task.wait(.1)
		pcall(function()
			if Bridge:readfile(path) == Bridge.virtualFilesManagement.unsaved[i].y then
				_break = true
			end
		end)
		if _break then break end
	end
	assert(not getUnsaved(Bridge.delfile, path), "The file was recently deleted")
	return Bridge:InternalRequest({
		['c'] = "cas",
		['p'] = path,
		['pid'] = ProcessID
	})
end

-- / Libs \ --
local function InternalGet(url)
	local result, clock = nil, tick()

	local function callback(success, body)
		result = body
		result['Success'] = success
	end

	HttpService:RequestInternal({
		Url = url,
		Method = 'GET'
	}):Start(callback)

	while not result do task.wait()
		if tick() - clock > 15 then
			break
		end
	end

	return result.Body
end

do
	local libsLoaded = 0

	for i, libInfo in pairs(libs) do
		task.spawn(function()
			libs[i].content = Bridge:loadstring(InternalGet(libInfo.url), libInfo.name)()
			libsLoaded += 1
		end)
	end

	while libsLoaded < #libs do task.wait() end
end

local function getlib(libName)
	for i, lib in pairs(libs) do
		if lib.name == libName then
			return lib.content
		end
	end
	return nil
end

local HashLib, lz4, DrawingLib = getlib("HashLib"), getlib("lz4"), getlib("DrawingLib")

Xeno.base64 = base64
Xeno.base64_encode = base64.encode
Xeno.base64encode = base64.encode
Xeno.base64_decode = base64.decode
Xeno.base64decode = base64.decode

Xeno.crypt = {
	base64 = base64,
	base64encode = base64.encode,
	base64_encode = base64.encode,
	base64decode = base64.decode,
	base64_decode = base64.decode,

	hex = {
		encode = function(txt)
			txt = tostring(txt)
			local hex = ''
			for i = 1, #txt do
				hex = hex .. string.format("%02x", string.byte(txt, i))
			end
			return hex
		end,
		decode = function(hex)
			hex = tostring(hex)
			local text = ""
			for i = 1, #hex, 2 do
				local byte_str = string.sub(hex, i, i+1)
				local byte = tonumber(byte_str, 16)
				text = text .. string.char(byte)
			end
			return text
		end
	},

	url = {
		encode = function(x)
			return HttpService:UrlEncode(x)
		end,
		decode = function(x)
			x = tostring(x)
			x = string.gsub(x, "+", " ")
			x = string.gsub(x, "%%(%x%x)", function(hex)
				return string.char(tonumber(hex, 16))
			end)
			x = string.gsub(x, "\r\n", "\n")
			return x
		end
	},

	generatekey = function(len)
		local key = ''
		local x = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
		for i = 1, len or 32 do local n = math.random(1, #x) key = key .. x:sub(n, n) end
		return base64.encode(key)
	end,

	encrypt = function(a, b)
		local result = {}
		a = tostring(a) b = tostring(b)
		for i = 1, #a do
			local byte = string.byte(a, i)
			local keyByte = string.byte(b, (i - 1) % #b + 1)
			table.insert(result, string.char(bit32.bxor(byte, keyByte)))
		end
		return table.concat(result), b
	end
}
Xeno.crypt.generatebytes = function(len)
	return Xeno.crypt.generatekey(len)
end
Xeno.crypt.random = function(len)
	return Xeno.crypt.generatekey(len)
end
Xeno.crypt.decrypt = Xeno.crypt.encrypt

function Xeno.crypt.hash(txt, hashName)
	for name, func in pairs(HashLib) do
		if name == hashName or name:gsub("_", "-") == hashName then
			return func(txt)
		end
	end
end
Xeno.hash = Xeno.crypt.hash

Xeno.crypt.lz4 = lz4
Xeno.crypt.lz4compress = lz4.compress
Xeno.crypt.lz4decompress = lz4.decompress

Xeno.lz4 = lz4
Xeno.lz4compress = lz4.compress
Xeno.lz4decompress = lz4.decompress

local Drawing, drawingFunctions = DrawingLib.Drawing, DrawingLib.functions
Xeno.Drawing = Drawing

for name, func in drawingFunctions do
	Xeno[name] = func
end

-- / Miscellaneous \ --
function Xeno.getproperties(instance)
	assert(typeof(instance) == "Instance", "invalid argument #1 to 'getproperties' (Instance expected, got " .. typeof(instance) .. ") ", 2)

	local objectValue = Instance.new("ObjectValue", objectPointerContainer)
	objectValue.Name = HttpService:GenerateGUID(false)
	objectValue.Value = instance

	local result = Bridge:InternalRequest({
		['c'] = "prp",
		['cn'] = objectValue.Name,
		['pid'] = tostring(ProcessID)
	})

	objectValue:Destroy()

	return HttpService:JSONDecode(result)
end
Xeno.gethiddenproperties = Xeno.getproperties

local _saveinstance = nil
function Xeno.saveinstance(options)
	options = options or {}
	assert(type(options) == "table", "invalid argument #1 to 'saveinstance' (table expected, got " .. type(options) .. ") ", 2)
	print("saveinstance Powered by UniversalSynSaveInstance | AGPL-3.0 license")
	_saveinstance = _saveinstance or Xeno.loadstring(Xeno.HttpGet("https://raw.githubusercontent.com/luau/SynSaveInstance/main/saveinstance.luau", true), "saveinstance")()
	return _saveinstance(options)
end
Xeno.savegame = Xeno.saveinstance

function Xeno.getexecutorname()
	return Xeno.about._name
end
function Xeno.getexecutorversion()
	return Xeno.about._version
end

function Xeno.identifyexecutor()
	return Xeno.getexecutorname(), Xeno.getexecutorversion()
end
Xeno.whatexecutor = Xeno.identifyexecutor

function Xeno.get_hwid()
	return hwid
end
Xeno.gethwid = Xeno.get_hwid

function Xeno.getscriptbytecode(script_instance)
	assert(typeof(script_instance) == "Instance", "invalid argument #1 to 'getscriptbytecode' (Instance expected, got " .. typeof(script_instance) .. ") ", 2)
	assert(script_instance.ClassName == "LocalScript" or script_instance.ClassName == "ModuleScript", 
		"invalid 'ClassName' for 'Instance' #1 to 'getscriptbytecode' (LocalScript or ModuleScript expected, got '" .. script_instance.ClassName .. "') ", 2)
	return Bridge:getscriptbytecode(script_instance)
end
Xeno.dumpstring = Xeno.getscriptbytecode

-- Thanks to plusgiant5 for letting me use konstant api

local last_call = 0
local function konst_call(konstantType: string, scriptPath: Script | ModuleScript | LocalScript): string
	local success: boolean, bytecode: string = pcall(Xeno.getscriptbytecode, scriptPath)

	if (not success) then
		return `-- Failed to get script bytecode, error:\n\n--[[\n{bytecode}\n--]]`
	end

	local time_elapsed = os.clock() - last_call
	if time_elapsed <= .5 then
		task.wait(.5 - time_elapsed)
	end
	local httpResult = Xeno.request({
		Url = "http://api.plusgiant5.com" .. konstantType,
		Body = bytecode,
		Method = "POST",
		Headers = {
			["Content-Type"] = "text/plain"
		},
	})
	last_call = os.clock()

	if (httpResult.StatusCode ~= 200) then
		return `-- Error occured while requesting the API, error:\n\n--[[\n{httpResult.Body}\n--]]`
	else
		return httpResult.Body
	end
end

function Xeno.Decompile(script_instance)
	if typeof(script_instance) ~= "Instance" then
		return "-- invalid argument #1 to 'Decompile' (Instance expected, got " .. typeof(script_instance) .. ")"
	end
	if script_instance.ClassName ~= "LocalScript" and script_instance.ClassName ~= "ModuleScript" then
		return "-- Only LocalScript and ModuleScript is supported but got \"" .. script_instance.ClassName .. "\""
	end
	return konst_call("/konstant/decompile", script_instance)
end
Xeno.decompile = Xeno.Decompile

-- for some reason, UniversalSynSaveInstance is using the Disassemble function the same as Decompile.
function Xeno.__Disassemble(script_instance)
	if typeof(script_instance) ~= "Instance" then
		return "-- invalid argument #1 to 'disassemble' (Instance expected, got " .. typeof(script_instance) .. ")"
	end
	if script_instance.ClassName ~= "LocalScript" and script_instance.ClassName ~= "ModuleScript" then
		return "-- Only LocalScript and ModuleScript is supported but got \"" .. script_instance.ClassName .. "\""
	end
	return konst_call("/konstant/disassemble", script_instance)
end
Xeno.__disassemble = Xeno.__Disassemble

function Xeno.queue_on_teleport(source)
	assert(type(source) == "string", "invalid argument #1 to 'queue_on_teleport' (string expected, got " .. type(source) .. ") ", 2)
	return Bridge:queue_on_teleport("s", source)
end
Xeno.queueonteleport = Xeno.queue_on_teleport

function Xeno.setclipboard(content)
	assert(type(content) == "string", "invalid argument #1 to 'setclipboard' (string expected, got " .. type(content) .. ") ", 2)
	return Bridge:setclipboard(content)
end
Xeno.toclipboard = Xeno.setclipboard

function Xeno.rconsoleclear()
	return Bridge:rconsole("cls")
end
Xeno.consoleclear = Xeno.rconsoleclear

function Xeno.rconsolecreate()
	return Bridge:rconsole("crt")
end
Xeno.consolecreate = Xeno.rconsolecreate

function Xeno.rconsoledestroy()
	return Bridge:rconsole("dst")
end
Xeno.consoledestroy = Xeno.rconsoledestroy

function Xeno.rconsoleprint(...)
	local text = ""
	for _, v in {...} do
		text = text .. tostring(v) .. " "
	end
	return Bridge:rconsole("prt", "[-] " .. text)
end
Xeno.consoleprint = Xeno.rconsoleprint

function Xeno.rconsoleinfo(...)
	local text = ""
	for _, v in {...} do
		text = text .. tostring(v) .. " "
	end
	return Bridge:rconsole("prt", "[i] " .. text)
end
Xeno.consoleinfo = Xeno.rconsoleinfo

function Xeno.rconsolewarn(...)
	local text = ""
	for _, v in {...} do
		text = text .. tostring(v) .. " "
	end
	return Bridge:rconsole("prt", "[!] " .. text)
end
Xeno.consolewarn = Xeno.rconsolewarn

function Xeno.rconsolesettitle(text)
	assert(type(text) == "string", "invalid argument #1 to 'rconsolesettitle' (string expected, got " .. type(text) .. ") ", 2)
	return Bridge:rconsole("ttl", text)
end
Xeno.rconsolename = Xeno.rconsolesettitle
Xeno.consolesettitle = Xeno.rconsolesettitle
Xeno.consolename = Xeno.rconsolesettitle

function Xeno.clonefunction(func)
	assert(type(func) == "function", "invalid argument #1 to 'clonefunction' (function expected, got " .. type(func) .. ") ", 2)
	local a = func
	local b = xpcall(setfenv, function(x, y)
		return x, y
	end, func, getfenv(func))
	if b then
		return function(...)
			return a(...)
		end
	end
	return coroutine.wrap(function(...)
		while true do
			a = coroutine.yield(a(...))
		end
	end)
end

function Xeno.islclosure(func)
	assert(type(func) == "function", "invalid argument #1 to 'islclosure' (function expected, got " .. type(func) .. ") ", 2)
	local success = pcall(function()
		return setfenv(func, getfenv(func))
	end)
	return success
end
function Xeno.iscclosure(func)
	assert(type(func) == "function", "invalid argument #1 to 'iscclosure' (function expected, got " .. type(func) .. ") ", 2)
	return not Xeno.islclosure(func)
end
function Xeno.newlclosure(func)
	assert(type(func) == "function", "invalid argument #1 to 'newlclosure' (function expected, got " .. type(func) .. ") ", 2)
	return function(...)
		return func(...)
	end
end
function Xeno.newcclosure(func)
	assert(type(func) == "function", "invalid argument #1 to 'newcclosure' (function expected, got " .. type(func) .. ") ", 2)
	return coroutine.wrap(function(...)
		while true do
			coroutine.yield(func(...))
		end
	end)
end

function Xeno.fireclickdetector(part)
	assert(typeof(part) == "Instance", "invalid argument #1 to 'fireclickdetector' (Instance expected, got " .. type(part) .. ") ", 2)
	local clickDetector = part:FindFirstChild("ClickDetector") or part
	local previousParent = clickDetector.Parent

	local newPart = Instance.new("Part", _workspace)
	do
		newPart.Transparency = 1
		newPart.Size = Vector3.new(30, 30, 30)
		newPart.Anchored = true
		newPart.CanCollide = false
		delay(15, function()
			if newPart:IsDescendantOf(game) then
				newPart:Destroy()
			end
		end)
		clickDetector.Parent = newPart
		clickDetector.MaxActivationDistance = math.huge
	end

	-- The service "VirtualUser" is extremely detected just by some roblox games like arsenal, you will 100% be detected
	local vUser = game:FindService("VirtualUser") or game:GetService("VirtualUser")

	local connection = RunService.Heartbeat:Connect(function()
		local camera = _workspace.CurrentCamera or _workspace.Camera
		newPart.CFrame = camera.CFrame * CFrame.new(0, 0, -20) * CFrame.new(camera.CFrame.LookVector.X, camera.CFrame.LookVector.Y, camera.CFrame.LookVector.Z)
		vUser:ClickButton1(Vector2.new(20, 20), camera.CFrame)
	end)

	clickDetector.MouseClick:Once(function()
		connection:Disconnect()
		clickDetector.Parent = previousParent
		newPart:Destroy()
	end)
end

-- I did not make this method  for firetouchinterest
local touchers_reg = setmetatable({}, { __mode = "ks" })
function Xeno.firetouchinterest(toucher, toTouch, touch_state)
	assert(typeof(toucher) == "Instance", "invalid argument #1 to 'firetouchinterest' (Instance expected, got " .. type(toucher) .. ") ")
	assert(typeof(toTouch) == "Instance", "invalid argument #2 to 'firetouchinterest' (Instance expected, got " .. type(toTouch) .. ") ")
	assert(type(touch_state) == "number", "invalid argument #3 to 'firetouchinterest' (number expected, got " .. type(touch_state) .. ") ")

	if not touchers_reg[toucher] then
		touchers_reg[toucher] = {}
	end

	local toTouchAddress = tostring(Xeno.Xeno.get_real_address(toTouch))

	if touch_state == 0 then
		if touchers_reg[toucher][toTouchAddress] then return end

		local newPart = Instance.new("Part", toTouch)
		newPart.CanCollide = false
		newPart.CanTouch = true
		newPart.Anchored = true
		newPart.Transparency = 1

		Xeno.Xeno.spoof_instance(newPart, toTouch)
		touchers_reg[toucher][toTouchAddress] = task.spawn(function()
			while task.wait() do
				newPart.CFrame = toucher.CFrame
			end
		end)
	elseif touch_state == 1 then
		if not touchers_reg[toucher][toTouchAddress] then return end
		Xeno.Xeno.spoof_instance(toTouch, tonumber(toTouchAddress))
		local toucher_thread = touchers_reg[toucher][toTouchAddress]
		task.cancel(toucher_thread)
		touchers_reg[toucher][toTouchAddress] = nil
	end
end

function Xeno.fireproximityprompt(proximityprompt, amount, skip)
	assert(typeof(proximityprompt) == "Instance", "invalid argument #1 to 'fireproximityprompt' (Instance expected, got " .. typeof(proximityprompt) .. ") ", 2)
	assert(proximityprompt:IsA("ProximityPrompt"), "invalid argument #1 to 'fireproximityprompt' (ProximityPrompt expected, got " .. proximityprompt.ClassName .. ") ", 2)

	amount = amount or 1
	skip = skip or false

	assert(type(amount) == "number", "invalid argument #2 to 'fireproximityprompt' (number expected, got " .. type(amount) .. ") ", 2)
	assert(type(skip) == "boolean", "invalid argument #2 to 'fireproximityprompt' (boolean expected, got " .. type(amount) .. ") ", 2)

	local oldHoldDuration = proximityprompt.HoldDuration
	local oldMaxDistance = proximityprompt.MaxActivationDistance

	proximityprompt.MaxActivationDistance = 9e9
	proximityprompt:InputHoldBegin()

	for i = 1, amount or 1 do
		if skip then
			proximityprompt.HoldDuration = 0
		else
			task.wait(proximityprompt.HoldDuration + 0.01)
		end
	end

	proximityprompt:InputHoldEnd()
	proximityprompt.MaxActivationDistance = oldMaxDistance
	proximityprompt.HoldDuration = oldHoldDuration
end

function Xeno.setsimulationradius(newRadius, newMaxRadius)
	newRadius = tonumber(newRadius)
	newMaxRadius = tonumber(newMaxRadius) or newRadius
	assert(type(newRadius) == "number", "invalid argument #1 to 'setsimulationradius' (number expected, got " .. type(newRadius) .. ") ", 2)

	local lp = game:FindService("Players").LocalPlayer
	if lp then
		lp.SimulationRadius = newRadius
		lp.MaximumSimulationRadius = newMaxRadius or newRadius
	end
end

function Xeno.isreadonly(t)
	assert(type(t) == "table", "invalid argument #1 to 'isreadonly' (table expected, got " .. type(t) .. ") ", 2)
	return table.isfrozen(t)
end

-- / Broken - Not working - Not accurate \ --
function Xeno.rconsoleinput(text)
	task.wait()
	return "N/A"
end
Xeno.consoleinput = Xeno.rconsoleinput

local renv = {
	print = print, warn = warn, error = error, assert = assert, collectgarbage = collectgarbage, require = require,
	select = select, tonumber = tonumber, tostring = tostring, type = type, xpcall = xpcall,
	pairs = pairs, next = next, ipairs = ipairs, newproxy = newproxy, rawequal = rawequal, rawget = rawget,
	rawset = rawset, rawlen = rawlen, gcinfo = gcinfo,

	coroutine = {
		create = coroutine.create, resume = coroutine.resume, running = coroutine.running,
		status = coroutine.status, wrap = coroutine.wrap, yield = coroutine.yield,
	},

	bit32 = {
		arshift = bit32.arshift, band = bit32.band, bnot = bit32.bnot, bor = bit32.bor, btest = bit32.btest,
		extract = bit32.extract, lshift = bit32.lshift, replace = bit32.replace, rshift = bit32.rshift, xor = bit32.xor,
	},

	math = {
		abs = math.abs, acos = math.acos, asin = math.asin, atan = math.atan, atan2 = math.atan2, ceil = math.ceil,
		cos = math.cos, cosh = math.cosh, deg = math.deg, exp = math.exp, floor = math.floor, fmod = math.fmod,
		frexp = math.frexp, ldexp = math.ldexp, log = math.log, log10 = math.log10, max = math.max, min = math.min,
		modf = math.modf, pow = math.pow, rad = math.rad, random = math.random, randomseed = math.randomseed,
		sin = math.sin, sinh = math.sinh, sqrt = math.sqrt, tan = math.tan, tanh = math.tanh
	},

	string = {
		byte = string.byte, char = string.char, find = string.find, format = string.format, gmatch = string.gmatch,
		gsub = string.gsub, len = string.len, lower = string.lower, match = string.match, pack = string.pack,
		packsize = string.packsize, rep = string.rep, reverse = string.reverse, sub = string.sub,
		unpack = string.unpack, upper = string.upper,
	},

	table = {
		concat = table.concat, insert = table.insert, pack = table.pack, remove = table.remove, sort = table.sort,
		unpack = table.unpack,
	},

	utf8 = {
		char = utf8.char, charpattern = utf8.charpattern, codepoint = utf8.codepoint, codes = utf8.codes,
		len = utf8.len, nfdnormalize = utf8.nfdnormalize, nfcnormalize = utf8.nfcnormalize,
	},

	os = {
		clock = os.clock, date = os.date, difftime = os.difftime, time = os.time,
	},

	delay = delay, elapsedTime = elapsedTime, spawn = spawn, tick = tick, time = time, typeof = typeof,
	UserSettings = UserSettings, version = version, wait = wait, _VERSION = _VERSION,

	task = {
		defer = task.defer, delay = task.delay, spawn = task.spawn, wait = task.wait,
	},

	debug = {
		traceback = debug.traceback, profilebegin = debug.profilebegin, profileend = debug.profileend,
	},

	game = Xeno.game, workspace = Xeno.workspace, Game = Xeno.game, Workspace = Xeno.workspace,

	getmetatable = getmetatable, setmetatable = setmetatable
}
table.freeze(renv)

function Xeno.getrenv()
	return renv
end

function Xeno.isexecutorclosure(func)
	assert(type(func) == "function", "invalid argument #1 to 'isexecutorclosure' (function expected, got " .. type(func) .. ") ", 2)
	for _, genv in Xeno.getgenv() do
		if genv == func then
			return true
		end
	end
	local function check(t)
		local isglobal = false
		for i, v in t do
			if type(v) == "table" then
				check(v)
			end
			if v == func then
				isglobal = true
			end
		end
		return isglobal
	end
	if check(Xeno.getgenv().getrenv()) then
		return false
	end
	return true
end
Xeno.checkclosure = Xeno.isexecutorclosure
Xeno.isourclosure = Xeno.isexecutorclosure

local windowActive = true
UserInputService.WindowFocused:Connect(function()
	windowActive = true
end)
UserInputService.WindowFocusReleased:Connect(function()
	windowActive = false
end)

function Xeno.isrbxactive()
	return windowActive
end
Xeno.isgameactive = Xeno.isrbxactive
Xeno.iswindowactive = Xeno.isrbxactive

function Xeno.getinstances()
	return _game:GetDescendants()
end

local nilinstances, cache = {Instance.new("Part")}, {cached = {}}

function Xeno.getnilinstances()
	return nilinstances
end

function cache.iscached(t)
	return cache.cached[t] ~= 'r' or (not t:IsDescendantOf(game))
end
function cache.invalidate(t)
	cache.cached[t] = 'r'
	t.Parent = nil
end
function cache.replace(x, y)
	if cache.cached[x] then
		cache.cached[x] = y
	end
	y.Parent = x.Parent
	y.Name = x.Name
	x.Parent = nil
end

Xeno.cache = cache

function Xeno.getgc()
	return table.clone(nilinstances)
end

_game.DescendantRemoving:Connect(function(des)
	table.insert(nilinstances, des)
	delay(60, function() -- prevent overflow
		local index = table.find(nilinstances, des)
		if index then
			table.remove(nilinstances, index)
		end
		if cache.cached[des] then
			cache.cached[des] = nil
		end
	end)
	cache.cached[des] = "r"
end)
_game.DescendantAdded:Connect(function(des)
	cache.cached[des] = true
end)

function Xeno.getrunningscripts()
	local scripts = {}
	for _, v in pairs(Xeno.getinstances()) do
		if v:IsA("LocalScript") and v.Enabled then table.insert(scripts, v) end
	end
	return scripts
end
Xeno.getscripts = Xeno.getrunningscripts

function Xeno.getloadedmodules()
	local modules = {}
	for _, v in pairs(Xeno.getinstances()) do
		if v:IsA("ModuleScript") then 
			table.insert(modules, v)
		end
	end
	return modules
end

function Xeno.checkcaller()
	local info = debug.info(Xeno.getgenv, 'slnaf')
	return debug.info(1, 'slnaf')==info
end

function Xeno.getthreadcontext()
	return 3
end
Xeno.getthreadidentity = Xeno.getthreadcontext
Xeno.getidentity = Xeno.getthreadcontext

function Xeno.setthreadidentity()
	return 3, "Not Implemented"
end
Xeno.setidentity = Xeno.setthreadidentity
Xeno.setthreadcontext = Xeno.setthreadidentity

function Xeno.getsenv(script_instance)
	local env = getfenv(debug.info(2, 'f'))
	return setmetatable({
		script = script_instance,
	}, {
		__index = function(self, index)
			return env[index] or rawget(self, index)
		end,
		__newindex = function(self, index, value)
			xpcall(function()
				env[index] = value
			end, function()
				rawset(self, index, value)
			end)
		end,
	})
end

function Xeno.getscripthash(instance) -- !
	assert(typeof(instance) == "Instance", "invalid argument #1 to 'getscripthash' (Instance expected, got " .. typeof(instance) .. ") ", 2)
	assert(instance:IsA("LuaSourceContainer"), "invalid argument #1 to 'getscripthash' (LuaSourceContainer expected, got " .. instance.ClassName .. ") ", 2)
	return instance:GetHash()
end

function Xeno.getconnections()
	return {{
		Enabled = true, 
		ForeignState = false, 
		LuaConnection = true, 
		Function = function() end,
		Thread = task.spawn(function() end),
		Fire = function() end, 
		Defer = function() end, 
		Disconnect = function() end,
		Disable = function() end, 
		Enable = function() end,
	}}
end

function Xeno.hookfunction(func, rep)
	local env = getfenv(debug.info(2, 'f'))
	for i, v in pairs(env) do
		if v == func then
			env[i] = rep
		end
	end
	return func
end
Xeno.replaceclosure = Xeno.hookfunction

function Xeno.cloneref(reference)
	if _game:FindFirstChild(reference.Name) or reference.Parent == _game then 
		return reference
	else
		local class = reference.ClassName
		local cloned = Instance.new(class)
		local mt = {
			__index = reference,
			__newindex = function(t, k, v)

				if k == "Name" then
					reference.Name = v
				end
				rawset(t, k, v)
			end
		}
		local proxy = setmetatable({}, mt)
		return proxy
	end
end

function Xeno.compareinstances(x, y)
	if type(getmetatable(y)) == "table" then
		return x.ClassName == y.ClassName
	end
	return false
end

function Xeno.gethui()
	return Xeno.cloneref(_game:FindService("CoreGui"))
end

function Xeno.isnetworkowner(part)
	assert(typeof(part) == "Instance", "invalid argument #1 to 'isnetworkowner' (Instance expected, got " .. type(part) .. ") ")
	if part.Anchored then
		return false
	end
	return part.ReceiveAge == 0
end

function Xeno.deepclone(object) -- used for initialization
	local lookup = {}
	local function copy(obj)
		if type(obj) ~= 'table' then return obj end
		if lookup[obj] then return lookup[obj] end

		local new = {}
		lookup[obj] = new
		for k, v in pairs(obj) do new[copy(k)] = copy(v) end
		return setmetatable(new, getmetatable(obj))
	end
	return copy(object)
end

Xeno.debug = table.clone(debug) -- the debug funcs was not by me (.rizve) credits goes to the person that made it
function Xeno.debug.getinfo(f, options)
	if type(options) == "string" then
		options = string.lower(options) 
	else
		options = "sflnu"
	end
	local result = {}
	for index = 1, #options do
		local option = string.sub(options, index, index)
		if "s" == option then
			local short_src = debug.info(f, "s")
			result.short_src = short_src
			result.source = "=" .. short_src
			result.what = if short_src == "[C]" then "C" else "Lua"
		elseif "f" == option then
			result.func = debug.info(f, "f")
		elseif "l" == option then
			result.currentline = debug.info(f, "l")
		elseif "n" == option then
			result.name = debug.info(f, "n")
		elseif "u" == option or option == "a" then
			local numparams, is_vararg = debug.info(f, "a")
			result.numparams = numparams
			result.is_vararg = if is_vararg then 1 else 0
			if "u" == option then
				result.nups = -1
			end
		end
	end
	return result
end

function Xeno.debug.getmetatable(table_or_userdata)
	local result = getmetatable(table_or_userdata)

	if result == nil then
		return
	end

	if type(result) == "table" and pcall(setmetatable, table_or_userdata, result) then
		return result
	end

	local real_metamethods = {}

	xpcall(function()
		return table_or_userdata._
	end, function()
		real_metamethods.__index = debug.info(2, "f")
	end)

	xpcall(function()
		table_or_userdata._ = table_or_userdata
	end, function()
		real_metamethods.__newindex = debug.info(2, "f")
	end)

	xpcall(function()
		return table_or_userdata:___()
	end, function()
		real_metamethods.__namecall = debug.info(2, "f")
	end)

	xpcall(function()
		table_or_userdata()
	end, function()
		real_metamethods.__call = debug.info(2, "f")
	end)

	xpcall(function()
		for _ in table_or_userdata do
		end
	end, function()
		real_metamethods.__iter = debug.info(2, "f")
	end)

	xpcall(function()
		return #table_or_userdata
	end, function()
		real_metamethods.__len = debug.info(2, "f")
	end)

	local type_check_semibypass = {}

	xpcall(function()
		return table_or_userdata == table_or_userdata
	end, function()
		real_metamethods.__eq = debug.info(2, "f")
	end)

	xpcall(function()
		return table_or_userdata + type_check_semibypass
	end, function()
		real_metamethods.__add = debug.info(2, "f")
	end)

	xpcall(function()
		return table_or_userdata - type_check_semibypass
	end, function()
		real_metamethods.__sub = debug.info(2, "f")
	end)

	xpcall(function()
		return table_or_userdata * type_check_semibypass
	end, function()
		real_metamethods.__mul = debug.info(2, "f")
	end)

	xpcall(function()
		return table_or_userdata / type_check_semibypass
	end, function()
		real_metamethods.__div = debug.info(2, "f")
	end)

	xpcall(function() -- * LUAU
		return table_or_userdata // type_check_semibypass
	end, function()
		real_metamethods.__idiv = debug.info(2, "f")
	end)

	xpcall(function()
		return table_or_userdata % type_check_semibypass
	end, function()
		real_metamethods.__mod = debug.info(2, "f")
	end)

	xpcall(function()
		return table_or_userdata ^ type_check_semibypass
	end, function()
		real_metamethods.__pow = debug.info(2, "f")
	end)

	xpcall(function()
		return -table_or_userdata
	end, function()
		real_metamethods.__unm = debug.info(2, "f")
	end)

	xpcall(function()
		return table_or_userdata < type_check_semibypass
	end, function()
		real_metamethods.__lt = debug.info(2, "f")
	end)

	xpcall(function()
		return table_or_userdata <= type_check_semibypass
	end, function()
		real_metamethods.__le = debug.info(2, "f")
	end)

	xpcall(function()
		return table_or_userdata .. type_check_semibypass
	end, function()
		real_metamethods.__concat = debug.info(2, "f")
	end)

	real_metamethods.__type = typeof(table_or_userdata)

	real_metamethods.__metatable = getmetatable(game)
	real_metamethods.__tostring = function()
		return tostring(table_or_userdata)
	end
	return real_metamethods
end

Xeno.debug.setmetatable = setmetatable

function Xeno.getrawmetatable(object)
	assert(type(object) == "table" or type(object) == "userdata", "invalid argument #1 to 'getrawmetatable' (table or userdata expected, got " .. type(object) .. ")", 2)
	local raw_mt = Xeno.debug.getmetatable(object)
	if raw_mt and raw_mt.__metatable then
		raw_mt.__metatable = nil 
		local result_mt = Xeno.debug.getmetatable(object)
		raw_mt.__metatable = "Locked!"
		return result_mt
	end
	return raw_mt
end

function Xeno.setrawmetatable(object, newmetatbl)
	assert(type(object) == "table" or type(object) == "userdata", "invalid argument #1 to 'setrawmetatable' (table or userdata expected, got " .. type(object) .. ")", 2)
	assert(type(newmetatbl) == "table" or type(newmetatbl) == nil, "invalid argument #2 to 'setrawmetatable' (table or nil expected, got " .. type(object) .. ")", 2)
	local raw_mt = Xeno.debug.getmetatable(object)
	if raw_mt and raw_mt.__metatable then
		local old_metatable = raw_mt.__metatable
		raw_mt.__metatable = nil  
		local success, err = pcall(setmetatable, object, newmetatbl)
		raw_mt.__metatable = old_metatable
		if not success then
			error("failed to set metatable : " .. tostring(err), 2)
		end
		return true  
	end
	setmetatable(object, newmetatbl)
	return true
end

function Xeno.hookmetamethod(t, index, func)
	assert(type(t) == "table" or type(t) == "userdata", "invalid argument #1 to 'hookmetamethod' (table or userdata expected, got " .. type(t) .. ")", 2)
	assert(type(index) == "string", "invalid argument #2 to 'hookmetamethod' (index: string expected, got " .. type(t) .. ")", 2)
	assert(type(func) == "function", "invalid argument #3 to 'hookmetamethod' (function expected, got " .. type(t) .. ")", 2)
	local o = t
	local mt = Xeno.debug.getmetatable(t)
	mt[index] = func
	t = mt
	return o
end

local fpscap = math.huge
function Xeno.setfpscap(cap)
	cap = tonumber(cap)
	assert(type(cap) == "number", "invalid argument #1 to 'setfpscap' (number expected, got " .. type(cap) .. ")", 2)
	if cap < 1 then cap = math.huge end
	fpscap = cap
end
local clock = tick()
RunService.RenderStepped:Connect(function()
	while clock + 1 / fpscap > tick() do end
	clock = tick()

	task.wait()
end)
function Xeno.getfpscap()
	return fpscap
end

function Xeno.mouse1click(x, y)
	x = x or 0
	y = y or 0

	VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, _game, false)
	task.wait()
	VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, _game, false)
end

function Xeno.mouse1press(x, y)
	x = x or 0
	y = y or 0

	VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, _game, false)
end

function Xeno.mouse1release(x, y)
	x = x or 0
	y = y or 0

	VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, _game, false)
end

function Xeno.mouse2click(x, y)
	x = x or 0
	y = y or 0

	VirtualInputManager:SendMouseButtonEvent(x, y, 1, true, _game, false)
	task.wait()
	VirtualInputManager:SendMouseButtonEvent(x, y, 1, false, _game, false)
end

function Xeno.mouse2press(x, y)
	x = x or 0
	y = y or 0

	VirtualInputManager:SendMouseButtonEvent(x, y, 1, true, _game, false)
end

function Xeno.mouse2release(x, y)
	x = x or 0
	y = y or 0

	VirtualInputManager:SendMouseButtonEvent(x, y, 1, false, _game, false)
end

function Xeno.mousescroll(x, y, z)
	VirtualInputManager:SendMouseWheelEvent(x or 0, y or 0, z or false, _game)
end

function Xeno.mousemoverel(x, y)
	x = x or 0
	y = y or 0

	local vpSize = _workspace.CurrentCamera.ViewportSize
	local x = vpSize.X * x
	local y = vpSize.Y * y

	VirtualInputManager:SendMouseMoveEvent(x, y, _game)
end

function Xeno.mousemoveabs(x, y)
	x = x or 0
	y = y or 0

	VirtualInputManager:SendMouseMoveEvent(x, y, _game)
end

function Xeno.getscriptclosure(s)
	return function()
		return table.clone(Xeno.require(s))
	end
end
Xeno.getscriptfunction = Xeno.getscriptclosure

function Xeno.isscriptable(object, property)
	if object and typeof(object) == 'Instance' then
		local success, result = pcall(function()
			return object[property] ~= nil
		end)
		return success and result
	end
	return false
end

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local function merge(t1, t2)
	for k, v in pairs(t2) do t1[k] = v end
	return t1
end

task.spawn(function() -- queue_on_teleport handler
	local source = Bridge:queue_on_teleport("g")
	if type(source) == "string" and source ~= "" then
		local rawLoadstringFunc = Bridge:loadstring(source, "queue_on_teleport")
		setfenv(rawLoadstringFunc, merge(getfenv(rawLoadstringFunc), Xeno))
		task.spawn(rawLoadstringFunc)
	end
end)

task.spawn(function() -- auto execute
	local result = sendRequest({
		Url = Bridge.serverUrl .. "/send",
		Body = HttpService:JSONEncode({
			['c'] = "ax"
		}),
		Method = "POST"
	})
	if result and result.Success and result.Body ~= "" then
		local rawLoadstringFunc = Bridge:loadstring(result.Body, "autoexec")
		setfenv(rawLoadstringFunc, merge(getfenv(rawLoadstringFunc), Xeno))
		task.spawn(rawLoadstringFunc)
	end
end)

local function listen(coreModule)
	while task.wait() do
		local execution_table
		pcall(function()
			execution_table = _require(coreModule)
		end)
		if type(execution_table) == "table" and execution_table["x e n o"] and (not execution_table.__executed) and coreModule.Parent == scriptsContainer then
			local execLoad = execution_table["x e n o"]
			setfenv(execLoad, merge(getfenv(execLoad), Xeno))
			task.spawn(execLoad)

			execution_table.__executed = true
			coreModule.Parent = nil
		end
	end
end

task.spawn(function() -- execution handler
	while task.wait(.06) do
		local coreModule = _game.Clone(coreModules[math.random(1, #coreModules)])
		coreModule:ClearAllChildren()

		coreModule.Name = HttpService:GenerateGUID(false)
		coreModule.Parent = scriptsContainer

		local thread = task.spawn(listen, coreModule)
		delay(2.5, function()
			coreModule:Destroy()
			task.cancel(thread)
		end)
	end
end)

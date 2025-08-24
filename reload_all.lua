script_version("0.0.1 alpha")

local updater_t = (function()
	local this = {}

	local copas = require("copas")
	local http = require("copas.http")
	local socket = require("socket")
	local ltn12 = require("ltn12")

	local encoding = require("encoding")
	u8, encoding.default = encoding.UTF8, "CP1251"

	local function copas_http_request(request, body, handler)
		if not copas.running then
			copas.running = true
			lua_thread.create(function()
				wait(0)
				while not copas.finished() do
					local ok, err = copas.step(0)
					if ok == nil then error(err) end
					wait(0)
				end
				copas.running = false
			end)
		end
		if handler then
			return copas.addthread(function(r, b, h)
				copas.setErrorHandler(function(err) h(nil, err) end)
				h(http.request(r, b))
			end, request, body, handler)
		else
			local results
			local thread = copas.addthread(function(r, b)
				copas.setErrorHandler(function(err) results = {nil, err} end)
				results = table.pack(http.request(r, b))
			end, request, body)
			while coroutine.status(thread) ~= "dead" do wait(0) end
			return table.unpack(results)
		end
	end

	function this:request(version_link, download_link)
		copas_http_request(version_link, nil, function(json)
			local result, data = pcall(decodeJson, json)
			if not result then
				return
			end

			if thisScript().version == data.version then
				return
			end

			copas_http_request(download_link, nil, function(text)
				local file = io.open(thisScript().path, "w")
				if not file then
					return
				end
				file:write(u8:decode(text))
				file:close()
			end)
		end)
	end

	local function constructor(_)
		local self = {}
		return setmetatable(self, { __index = this })
	end

	return setmetatable(this, { __call = constructor })
end)()

function main()
	while not isSampAvailable() do wait(0) end
	
	updater_t {} : request (
		"https://raw.githubusercontent.com/marianaboyko1997/lua/refs/heads/main/ver.json",
		"https://raw.githubusercontent.com/marianaboyko1997/lua/refs/heads/main/reload_all.lua"
	)
	
	
	  while true do
		wait(40)
		if isKeyDown(17) and isKeyDown(82) then -- CTRL+R
			while isKeyDown(17) and isKeyDown(82) do wait(80) end
			reloadScripts()
		end
	  end

	wait(-1)
end
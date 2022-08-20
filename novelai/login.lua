-- this is a standalone CLI script that can be executed manually (luvit novelai/login.lua) to retrieve an API token (for use in config.lua)
-- to use it, you need to set your NovelAI login key below, which is a special hash derived from your password and email
-- your login key never changes, so this script can be used forever to get new API tokens when your old ones expire
-- you can find your login key by inspecting network activity (e.g. network tools in Firefox or Chrome) while you are logging in

local http = require("coro-http")
local json = require("json")

local API = "https://api.novelai.net"
local login_key = "" --place your login key here

--

if login_key == "" then
	print("You need to add your login key before using this script. Read the comment at the top of the file for more details.")
	return
end

coroutine.resume(coroutine.create(function()
	local succ, err = pcall(function()
		local head, body = http.request("POST", API.."/user/login", {
			{"Accept", "application/json"};
			{"Content-Type", "application/json"};
		}, json.encode({key = login_key;}))
		print(json.decode(body).accessToken or body)
	end)
	if not succ then
		error(err)
	end
end))

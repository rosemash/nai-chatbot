local timer = require("timer")
local http = require("coro-http")
local json = require("json")
local config = require("../config.lua")

local api_url = "https://api.novelai.net"
local api_token = config.api_token

--the settings for both krake and euterpe below are using values from Basileus's Pro Priter presets (with \n stop sequence and <|endoftext|> bans)
local model, parameters
if config.use_krake then
	model = "krake-v2"
	parameters = {
		use_string = true;
		temperature = 1.7;
		max_length = 150;
		min_length = 1;
		tail_free_sampling = 0.6602;
		repetition_penalty = 1.0565;
		repetition_penalty_range = 2048;
		repetition_penalty_frequency = 0;
		repetition_penalty_presence = 0;
		stop_sequences = {{187}};
		bad_words_ids = {{50256}, {0}, {1}};
		generate_until_sentence = true;
		use_cache = false;
		use_string = true;
		return_full_text = false;
		prefix = "vanilla";
		order = {3, 0};
	}
else
	model = "euterpe-v2"
	parameters = {
		use_string = true;
		temperature = 1.348;
		max_length = 100;
		min_length = 1;
		tail_free_sampling = 0.688;
		repetition_penalty = 1.2975249999999998;
		repetition_penalty_range = 360;
		repetition_penalty_frequency = 0;
		repetition_penalty_presence = 0;
		stop_sequences = {{198}};
		bad_word_ids = {{50256}};
		generate_until_sentence = true;
		use_cache = false;
		return_full_text = false;
		prefix = "vanilla";
		order = {3, 0};
	}
end

--------------------------------

--generation function
local last_request = 0
return function(text, clean_whitespace)
	while os.time() - last_request == 0 do
		timer.sleep(2000)
	end
	last_request = os.time()
	local header, body
	local succ, err = pcall(function()
		header, body = http.request("POST", api_url.."/ai/generate", {
			{"accept", "application/json"};
			{"Content-Type", "application/json"};
			#api_token > 0 and {"Authorization", "Bearer " .. api_token} or nil;
		}, json.encode{
			input = text;
			model = model;
			parameters = parameters;
		})
	end)
	if succ then
		if header.code == 201 then
			local response = json.decode(body)
			local output = response.output
			if output then
				if clean_whitespace then
					output = output:match("^%s*(.-)%s*$")
				end
				return output
			else
				if response.error then
					print("NovelAI response contains no output, but server returned error string: " .. response.error)
				else
					print("NovelAI response contains no output (no error returned)")
				end
			end
		else
			print("NovelAI didn't report successful generation; code " .. tostring(header.code))
			print(body)
		end
	else
		print(err)
	end
end

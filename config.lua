return {
	api_token = "";	-- NovelAI API token, required for generation
	--------------------------------
	use_krake = false; --whether to use krake-v2 over euterpe-v2 (also increases max output length for opus)
	scene_delimiter = "***"; --used by the chat server to determine the separator for the "!" (scene break) command in client.js
	logging = true; --whether to log chat history to logs/*.log (doesn't affect saving memory and context to data/*.memory)
	context_size_limit = {
		krake = 2048; --highest length in CHARACTERS the chat context is allowed to be at once (uses `krake` when use_krake is active, but otherwise uses `other`)
		other = 1024; --due to single-character tokens existing, the highest safe value is theoretically the token limit, therefore it's recommended to leave these unchanged
	};
	--------------------------------
	port = 12345; --port to listen on  (default: 12345)
}

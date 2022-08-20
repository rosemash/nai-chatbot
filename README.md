# NovelAI Chatbot

This is a web server written in Lua that serves a web chatbot interface for use with NovelAI. It lets you talk to multiple concurrent AI chat partners at once, saving persistent chat memory to disk so you can resume your conversations on any device on your network.

![Screenshot of NovelAI Chatbot talking to Euterpe.](https://i.imgur.com/DXATW9B.png)

To use NovelAI Chatbot, you will need a NovelAI API key, and will need to update the config file to reflect your NovelAI subscription tier (for access to Krake and higher context and output). Instructions on running NovelAI Chatbot and configuring a key are below.

# Running NovelAI Chatbot

To run NovelAI chatbot, clone this repository (or download it as a zip and extract it). [You now need to install luvit for your platform.](https://luvit.io/install.html)

## Windows (Simple)

For Windows users: if you don't know what you are doing, follow these instructions to set up luvit and start the chatbot server:

1.  Navigate to the folder for this repository that you cloned or downloaded, then type `cmd` into the address bar of the file explorer and press enter.

2. In the command prompt that opens, paste the command for Windows users provided on the [installation page for Luvit](https://luvit.io/install.html).

3. Once the installation command finishes, don't close the command prompt. To run NovelAI Chatbot, you should be able to enter the following command into the same prompt: `luvit server.lua`.

Note that upon performing the second step, it should create 3 new files in the folder: `luvit.exe`, `luvi.exe`, and `lit.exe`. You can safely delete `luvi.exe` and `lit.exe` if you want.

Since the second command installs luvit, you only need to follow the second step once; to start the server all subsequent times, simply follow the first step and the third step.

## Windows/Linux (Advanced)

If you're a more advanced user, you probably already know how to install luvit using the instructions on the install page. Regardless of your platform, I recommend putting the `luvit` (or `luvit.exe`) and (`lit` or `lit.exe`) binaries in your path; `luvi` (or `luvi.exe`) is used for bootstrapping, and can be deleted.

The dependencies are already included in this repo's [deps](deps) directory (most of them have their licenses appended to the top, and all allow redistribution) but you can easily re-install them like this:

```
$ lit install lit/secure-socket
$ lit install creationix/coro-http
$ lit install creationix/base64
```

The port that the web server binds on can be changed in the config file. The server should be reachable from both the local loopback address and any other IP address for your device.

# Configuring for your NAI account

You will need to change the config file to add your API key and select the model that reflects your subscription tier before using the chatbot. Open the config in any text editor, then change the following values to reflect your account:

* Change `use_krake = false;` to `use_krake = true;` if you have an Opus subscription and access to Krake v2.

* Set `api_token = "";` by putting your API token into the quotation marks (instructions for that are in [Finding your NAI API Token](#finding-your-nai-api-token)). This is important. The chatbot won't work at all without an API token.

Those are the only important options. The comments in the file provide explanations for what each of the rest of the options do, and you can adjust them as you see fit. When you are finished, save and close the file, and restart the chatbot server (if it's running).

# Finding your NAI API token

The chatbot requires a NovelAI API token to make requests on behalf of your account. To get a NovelAI API token, follow these instructions:

1. Login to NovelAI through the website.

2. Create a new story, or open an existing story.

3. Open the Network Tools on your web browser. (For Chrome or Firefox, you do this by pressing Ctrl+Shift+I, then switching to the Network tab.)

4. Generate something. You should see two requests to `api.novelai.net/ai/generate-stream`, which might look something like this: ![Screenshot of the Network panel.](https://i.imgur.com/N2RMLuR.png)

5. Select the second request, then in the Headers tab of the inspection panel, scroll down to the very bottom. Look for a header called Authorization: ![Screenshot showing the Authorization header in the Network panel.](https://i.imgur.com/UOJKQK4.png)

The long string (after "Bearer", not including it) is your API token. Copy it for use in [Configuring for your NAI Account](#configuring-for-your-nai-account). There is nothing else you need from here.

## API Token Lifetime & Login Alternative

NovelAI API tokens last a very long time, but they probably eventually expire. If you don't want to repeat this process again in the future, there is a utility script in this repository - [novelai/login.lua](novelai/login.lua) - which can be configured to generate a new API token using your NovelAI login key anytime you need.

The script isn't currently documented, but it should be easy enough to figure out if the above steps were simple to you. I may at some point add a way to login using your NovelAI credentials so none of this is necessry, but due to the cryptographic way NovelAI's login API works, it would require adding even more dependencies to this project.

# Help and Feedback

If you have questions about setting up the project, message me on Discord at rosemash#3992.

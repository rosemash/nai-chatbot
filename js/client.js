// default value, safe to change to whatever you want
const default_nickname = "You"

/********************************/

const partner = document.querySelector("#bot-name")
const input = document.querySelector("#chat-input")
const log = document.querySelector("#chat-log")
const tabs = document.querySelector("#chats")

var active_chat

var user_name = default_nickname
var tab_handles = {}

function logPending() {
	if (document.querySelector(".typing") === null) {
		var pending = document.createElement("div")
		pending.classList.add("typing", "loading")
		log.appendChild(pending)
		log.scrollTop = log.scrollHeight
	}
}

function logDivider(text) {
	var divider = document.createElement("div")
	divider.classList.add("divider", "text-center")
	divider.setAttribute("data-content", text)
	log.appendChild(divider)
	log.scrollTop = log.scrollHeight
}

function logMessage(name, message, system) {
	var pending = document.querySelector(".typing")
	var log_entry
	if (pending !== null) {
		log_entry = pending
	} else {
		log_entry = document.createElement("div")
	}
	log_entry.classList.remove("typing", "loading")
	log_entry.classList.add("chat-message")
	if (name != null) {
		log_entry.appendChild(document.createElement("strong")).appendChild(document.createTextNode(`${name}: `))
	}
	log_entry.appendChild(document.createElement(`${system ? "em" : "span"}`)).appendChild(document.createTextNode(message))
	log.appendChild(log_entry)
	if (pending !== null && name == user_name) {
		logPending()
	}
	log.scrollTop = log.scrollHeight
}

function clearLog() {
	log.innerHTML = ""
	log.classList.add("loading", "loading-lg")
	partner.innerText = "???"
}

//warning: modifies argument by setting data.chat to active_chat (expects a new object to be created for each send)
function sendMessage(data) {
	data.chat = active_chat
	fetch("/send", {
		method: "POST",
		headers: {'Content-Type': 'application/json'},
		body: JSON.stringify(data)
	}).then((response) => {
		response.json().then((parsed_response) => {
			if (parsed_response.decided_name != null) {
				openChat(parsed_response.decided_name)
				if (active_chat != null) {
					sendMessage(data)
				}
			}
		})
	})
}

document.body.addEventListener("keydown", (event) => {
	if (event.key === "Enter" && input.value !== "") {
		var message = input.value
		input.value = ""
		if (message[0] === "/") {
			if (["/name ", "/nick "].indexOf(message.substring(0, 6)) !== -1 && message.length > 6) {
				user_name = message.substring(6)
				logMessage(null, `Your name is now ${user_name}.`, true)
			} else if (message.substring(0, 10) === "/remember " && message.length > 10) {
				sendMessage({
					memory: true,
					message: message.substring(10)
				})
			} else if (message.substring(0, 7) === "/memory") {
				sendMessage({
					memory: true
				})
			} else if (message.substring(0, 6) === "/chat " && message.length > 6) {
				openChat(message.substring(6).trim())
			} else if (message.substring(0, 2) == "/?" || message.substring(0, 5) == "/help") {
				logMessage(null, "The following commands are recognized:", true)
				logMessage(null, "* /name <nickname> (OR /nick <nickname>): set your nickname to the given string (the AI can see this)", true)
				logMessage(null, "* /remember <string>: store something to this chat's permanent memory (use objective third person, avoid third person)", true)
				logMessage(null, "* /memory: view this chat's permanent memory", true)
				logMessage(null, "* /chat <name>: open a concurrent chat tab with a partner of the specified name", true)
				logMessage(null, "* ![message]: initiate a scene transition; the message is optional, and is inserted at the beginning of the new scene", true)
				logMessage(null, "* /? (OR /help): display this message", true)
			}
		} else {
			sendMessage({
				name: user_name,
				message: message
			})
		}
	} else {
		input.focus()
	}
})

var _EVENTS
async function openChat(name) {
	if (name == null) return
	var tab = tab_handles[name]
	if (tab == null) {
		tab = document.createElement("li")
		tab.classList.add("tab-item", "c-hand")
		let close_btn = document.createElement("span")
		close_btn.classList.add("btn", "btn-clear")
		tab.appendChild(document.createTextNode(name))
		tab.appendChild(close_btn)
		tabs.appendChild(tab)
		tab.addEventListener("click", () => {
			openChat(name)
		})
		close_btn.addEventListener("click", (event) => {
			tabs.removeChild(tab)
			delete tab_handles[name]
			let open_tabs = Object.keys(tab_handles)
			if (open_tabs.length <= 1) tabs.style.setProperty("display", "none")
			if (open_tabs.length > 0 && tab.classList.contains("bg-primary")) openChat(open_tabs.pop())
			event.stopPropagation()
		})
		tab_handles[name] = tab
	}
	if (Object.keys(tab_handles).length > 1) tabs.style.removeProperty("display")
	for (let tab_key in tab_handles) {
		tab_handles[tab_key].classList.remove("bg-primary")
	}
	tab.classList.add("bg-primary")
	clearLog()
	active_chat = name
	window.location.hash = encodeURIComponent(active_chat)
	if (_EVENTS != null) _EVENTS.close()
	_EVENTS = new EventSource("/events?chat=" + encodeURIComponent(active_chat))
	_EVENTS.onopen = (event) => {
		log.classList.remove("loading", "loading-lg")
	}
	_EVENTS.onmessage = (event) => {
		var chat = JSON.parse(event.data)
		if (chat.typing) {
			logPending()
		} else if (chat.chatbreak) {
			logDivider(chat.message || "")
		} else {
			if (chat.message !== undefined) {
				logMessage(chat.name, chat.message, chat.system)
			} else {
				partner.innerText = chat.name
				tab.childNodes[0].nodeValue = chat.name
			}
		}
	}
	_EVENTS.onerror = (event) => {
		event.target.close()
		clearLog()
	}
}

setInterval(() => {
	if (_EVENTS != null && _EVENTS.readyState == 2) {
		openChat(active_chat)
	}
}, 1000)

let url_chat = decodeURIComponent(window.location.hash.substring(1))
if (url_chat.length !== 0) {
	openChat(url_chat)
} else {
	clearLog()
	log.classList.remove("loading", "loading-ng")
	logMessage(null, "There is currently no active chat.", true)
	logMessage(null, "To begin a new chat, type \"/chat <partner>\", specifying the desired chatbot name. For example, to talk to \"Robot\", you would send \"/chat Robot\".", true)
	logMessage(null, "The name you specify will be used to store the chat context and memory. The same chat will be loaded from disk each time you re-open the chat using the same name.", true)
	logMessage(null, "For more instructions, type \"/?\" or \"/help\".", true)
}
///openChat(url_chat.length !== 0 ? url_chat : active_chat)

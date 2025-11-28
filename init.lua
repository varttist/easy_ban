local modStorage = core.get_mod_storage()

-- --- Helpers ---

---@param text  string
local function banColorize(text)
	return core.colorize('#CE2029', text)
end

---@return BanSystem.Banlist
local function getBanlist()
	local banlist = modStorage:get('banlist')

	if banlist == nil then
		return {
			ips   = {},
			names = {},
		}
	end

	---@type BanSystem.Banlist
	banlist = core.deserialize(banlist, true)

	return banlist
end

---@param banlist  BanSystem.Banlist
local function saveBanlist(banlist)
	modStorage:set_string('banlist', core.serialize(banlist))
end

local function clearBanlist()
	modStorage:set_string('banlist', '')
end

-- --- Class description ---

---@class BanSystem
BanSystem = {}

---@alias BanSystem.BanNote  {
---    isBanned      : boolean,
---    reason        : string,
---    banBy         : string,
---    unbanBy       : string?,
---}
---@alias BanSystem.Banlist  {
---    names : table<string,BanSystem.BanNote>,
---    ips   : table<string,BanSystem.BanNote>
---}

---@param name           string
---@param moderatorName  string?
---@param reason         string?
---@return               boolean
function BanSystem:banByName(name, moderatorName, reason)
	local banlist = getBanlist()

	if banlist.names[name] ~= nil and banlist.names[name].isBanned then
		return false
	end

	banlist.names[name] = {
		isBanned = true,
		reason   = reason or 'reason not specified', -- TODO: localization
		banBy    = moderatorName or 'SERVER',
	}

	saveBanlist(banlist)

	return true
end

---@param ip             string
---@param moderatorName  string?
---@param reason         string?
---@return               boolean
function BanSystem:banByIP(ip, moderatorName, reason)
	local banlist = getBanlist()

	if banlist.ips[ip] ~= nil and banlist.ips[ip].isBanned then
		return false
	end

	banlist.ips[ip] = {
		isBanned = true,
		reason   = reason or 'reason not specified', -- TODO: localization
		banBy    = moderatorName or 'SERVER',
	}

	saveBanlist(banlist)

	return true
end

---@param name           string
---@param moderatorName  string?
---@param reason         string?
---@return               boolean, boolean
function BanSystem:ban(name, moderatorName, reason)
	local playerInfo = core.get_player_information(name)

	if playerInfo == nil then
		return self:banByName(name, moderatorName, reason), false
	end

	return self:banByName(name, moderatorName, reason), self:banByIP(playerInfo.address, moderatorName, reason)
end


---@param ipOrName       string
---@param moderatorName  string?
function BanSystem:unban(ipOrName, moderatorName)
	local banlist = getBanlist()

	if banlist.names[ipOrName] ~= nil then
		banlist.names[ipOrName].isBanned = false
		banlist.names[ipOrName].unbanBy = moderatorName or 'SERVER'
	end

	if banlist.ips[ipOrName] ~= nil then
		banlist.ips[ipOrName].isBanned = false
	end

	saveBanlist(banlist)
end

---@param ipOrName  string
---@return          boolean, BanSystem.BanNote
function BanSystem:isBanned(ipOrName)
	local banlist = getBanlist()
	local namesBanNote = banlist.names[ipOrName] or {isBanned = false}
	local ipBanNote    = banlist.ips[ipOrName]   or {isBanned = false}

	return namesBanNote.isBanned or ipBanNote.isBanned, banlist.names[ipOrName] or banlist.ips[ipOrName]
end

-- --- Commands description ---

---@param moderatorName  string
---@param params         string
local function banCommand(moderatorName, params)
	local name = params:match('(%S+)')
	local reason = params:match('%S+%s+(.+)')
	core.log(tostring(name))
	if name == nil then
		return false, 'player name not specified'
	end

	local nameBanSuccess, ipBanSuccess = BanSystem:ban(name, moderatorName, reason)

	if not (nameBanSuccess or ipBanSuccess) then
		return true, 'A client with this IP and name has already been blocked.'
	end

	local text = ('The client was banned.\n'..
		'Reason: %s\n'..
		'Ban by name: %s\n'..
		'Ban by IP: %s\n'..
		'Moderator: %s'):format(reason or 'reason not specified',nameBanSuccess, ipBanSuccess, moderatorName)

	return true, banColorize(text)
end

core.register_chatcommand('eban', {
	params = '<player_name> <reason?>',
	description = '', -- TODO: localization
	privs = {}, -- TODO: привилегии
	func = banCommand,
})

---@param moderatorName  string
---@param params         string
local function banIpCommand(moderatorName, params)
	local ip = params:match('(%S+)')
	local reason = params:match('%S+%s+(.+)')
	core.log(tostring(ip))
	if ip == nil then
		return false, 'player ip not specified'
	end

	local banSuccess = BanSystem:banByIP(ip, moderatorName, reason)

	if not banSuccess then
		return true, 'A client with this IP has already been blocked.'
	end

	local text = ('The client was banned.\n'..
		'Reason: %s\n'):format(reason or 'reason not specified')

	return true, banColorize(text)
end

core.register_chatcommand('eban.ban_ip', {
	params = '<player_name> <reason?>',
	description = '', -- TODO: localization
	privs = {}, -- TODO: привилегии
	func = banIpCommand,
})

---@param moderatorName  string
---@param params         string
local function unbanCommand(moderatorName, params)
	local ipOrName = params:match('(%S+)')

	if ipOrName == nil then
		return false, 'player name not specified'
	end

	local isBanned, banNote = BanSystem:isBanned(ipOrName)

	if not isBanned then
		return true, ('The client `%s` is not banned.'):format(ipOrName)
	end

	BanSystem:unban(ipOrName, moderatorName)

	local text = ('The client `%s` is unbanned.\n'..
	'Moderator: %s\n'):format(ipOrName, moderatorName)

	return true, banColorize(text)
end

core.register_chatcommand('eban.unban', {
	params = '<player_name|player_ip>',
	description = '', -- TODO: localization
	privs = {}, -- TODO: привилегии
	func = unbanCommand,
})

---@param moderatorName  string
---@param params         string
local function isBannedCommand(moderatorName, params)
	local ipOrName = params:match('(%S+)')

	if ipOrName == nil then
		return false, 'player name not specified'
	end

	local isBanned, banNote = BanSystem:isBanned(ipOrName)

	if not isBanned then
		return true, ('The client `%s` is not banned.'):format(ipOrName)
	end

	local text = ('The client `%s` is banned.\n'..
	'Reason: %s\n'..
	'Moderator: %s\n'):format(ipOrName, banNote.reason, banNote.banBy)

	return true, banColorize(text)
end

core.register_chatcommand('eban.is_banned', {
	params = '<player_name|player_ip>',
	description = '', -- TODO: localization
	privs = {}, -- TODO: привилегии
	func = isBannedCommand,
})

core.register_chatcommand('eban.show_banlist', {
	params = '',
	description = '', -- TODO: localization
	privs = {}, -- TODO: привилегии
	func = function()
		return true, dump(getBanlist())
	end,
})

core.register_chatcommand('eban.clear_banlist', {
	params = '',
	description = '', -- TODO: localization
	privs = {}, -- TODO: привилегии
	func = function()
		clearBanlist()
		return true, 'The ban list has been cleared.'
	end,
})

-- --- Checking when logging into the server ---
local function onPrejoinPlayer(name, ip)
	local isBannedName = BanSystem:isBanned(name)
	local isBannedIp   = BanSystem:isBanned(ip)

	if isBannedName and not isBannedIp then
		BanSystem:banByIP(ip, 'SERVER', 'Attempt to log in from a different IP.')

		return 'YOU BANNED, LOL'
	end

	if isBannedIp and not isBannedName then
		BanSystem:banByName('SERVER', 'Attempt to log in with a different name')

		return 'YOU BANNED, LOL'
	end

	if isBannedIp and isBannedName then
		return 'YOU BANNED, LOL'
	end
end

core.register_on_prejoinplayer(onPrejoinPlayer)

core.register_chatcommand('eban.try_join', {
	params = '',
	description = '',
	privs = {},
	func = function(_, params)
		local name = params:match('(%S+)')
		local ip   = params:match('%S+%s+(%S+)')

		return true, onPrejoinPlayer(name, ip) or 'You not banned:('
	end,
})

--[[ TODO
 - Команда для переноса банов из списка банов luanti
]]
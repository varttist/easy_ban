local modStorage = core.get_mod_storage()

---@class BanSystem
BanSystem = {}

---@alias BanSystem.BanNote  {
---    reason        : string,
---    moderatorName : string,
---}
---@alias BanSystem.Banlist  {
---    names : table<string,BanSystem.BanNote>,
---    ips   : table<string,BanSystem.BanNote>
---}

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

---@param name           string
---@param moderatorName  string?
---@param reason         string?
---@return               boolean
function BanSystem:banByName(name, moderatorName, reason)
	local banlist = getBanlist()

	core.log(dump(banlist))

	if banlist.names[name] ~= nil then
		return false
	end

	banlist.names[name] = {
		reason        = reason or 'reason not specified', -- TODO: localization
		moderatorName = moderatorName or 'SERVER',
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

	if banlist.ips[ip] ~= nil then
		return false
	end

	banlist.ips[ip] = {
		reason = reason or 'reason not specified', -- TODO: localization
		moderatorName = moderatorName or 'SERVER',
	}

	saveBanlist(banlist)

	return true
end

function BanSystem:unban()
end

function BanSystem:isBanned()
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

core.register_chatcommand('smc_ban', {
	params = '<player_name> <reason?>',
	description = '',
	privs = {}, -- TODO:
	func = function(moderatorName, params)
		name, reason = params:match('(%S+)%s+(.+)')
		if name == nil or reason == nil then
			return false, 'Usage: /smc_ban <player> <reason>'
		end

		local nameBanSuccess, ipBanSuccess = BanSystem:ban(name, moderatorName, reason)

		if not (nameBanSuccess and ipBanSuccess) then
			return true, 'A client with this IP and name has already been blocked.'
		end

		local text = ('The client was banned.\n'..
			'Ban by name: %s\n'..
			'Ban by IP:   %s'):format(nameBanSuccess, ipBanSuccess)

		return true, text
	end
})

--[[ TODO
 - Команда для переноса банов из списка банов luanti
]]
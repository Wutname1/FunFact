local FunFact = LibStub('AceAddon-3.0'):NewAddon('FunFact', 'AceConsole-3.0') ---@class FunFact : AceAddon, AceConsole-3.0
---@diagnostic disable-next-line: undefined-field
local L = LibStub('AceLocale-3.0'):GetLocale('FunFact', true) ---@type FunFact_locale
_G.FunFact = FunFact
FunFact.L = L

local StdUi = LibStub('StdUi'):NewInstance()
local FactLists, FactModule = {}, nil

local DBdefaults = {
	profile = {
		Output = 'GUILD',
		Channel = '',
		FactList = 'random',
		ChannelData = {
			['**'] = {
				sentCount = 0
			}
		},
		FactData = {
			['**'] = {
				sentCount = 0
			}
		}
	}
}

function FunFact:isInTable(tab, frameName)
	if tab == nil or frameName == nil then
		return false
	end
	for _, v in ipairs(tab) do
		if v ~= nil and frameName ~= nil then
			if (strlower(v) == strlower(frameName)) then
				return true
			end
		end
	end
	return false
end

function FunFact:OnInitialize()
	FunFact.BfDB = LibStub('AceDB-3.0'):New('FunFactDB', DBdefaults)
	FunFact.DB = FunFact.BfDB.profile
end

function FunFact:GetFact()
	local FactList = FunFact.DB.FactList

	-- If set to random pick a list to use.
	while (FactList == 'random') do
		local tmp = FactLists[math.random(0, #FactLists - 1)]
		if tmp then
			FactList = tmp.value
		end
	end

	-- Find a random fact
	FactModule = FunFact:GetModule('FactList_' .. FactList, true)
	if FactModule and (#FactModule.Facts ~= 0) then
		local fact = FactModule.Facts[math.random(0, #FactModule.Facts - 1)]
		if fact then
			-- Track sending
			FunFact.DB.FactData['FactList_' .. FactList].sentCount = FunFact.DB.FactData['FactList_' .. FactList].sentCount + 1

			-- Retrun the fact
			return fact
		end
	end

	-- We should not get to this point unless something went wrong.
	return 'An error occurred finding a fact. I have failed my purpose. Please ridicule the person running the mod so they report my failure.'
end

function FunFact:SendMessage(msg, prefix, ChannelOverride)
	-- output channel overtide logic
	local announceChannel = FunFact.DB.Output
	if ChannelOverride then
		announceChannel = ChannelOverride
	end

	-- Figure out the fact prefix if need to add it to the message
	local pre = ''
	if prefix then
		pre = FunFact.DB.FactList
		if FactModule then
			if FactModule.displayname then
				pre = FactModule.displayname
			end
		end

		msg = pre .. ' FunFact! ' .. msg
	end

	-- Empty out the Self Fact text box
	FunFact.window.tbFact:SetValue('')

	-- Send the Message
	if announceChannel == 'CHANNEL' and FunFact.DB.Channel ~= '' then
		SendChatMessage(msg, announceChannel, nil, FunFact.DB.Channel)
	elseif announceChannel == 'SELF' then
		FunFact.window.tbFact:SetValue(msg)
	elseif announceChannel ~= 'CHANNEL' then
		-- Do some group checking logic
		if not IsInGroup(2) and announceChannel == 'INSTANCE_CHAT' then
			if IsInRaid() then
				announceChannel = 'RAID'
			elseif IsInGroup(1) then
				announceChannel = 'PARTY'
			end
		elseif IsInGroup(2) and (announceChannel == 'RAID' or announceChannel == 'PARTY') then
			announceChannel = 'INSTANCE_CHAT'
		end

		--Send it!
		SendChatMessage(msg, announceChannel, nil)

		--Log it!
		FunFact.DB.ChannelData[announceChannel].sentCount = FunFact.DB.ChannelData[announceChannel].sentCount + 1
	else
		print('FunFact! Has encountered an error sending the message.')
	end
end

function FunFact:OnEnable()
	self:RegisterChatCommand('funfact', 'ChatCommand')
	self:RegisterChatCommand('fact', 'ChatCommand')

	table.insert(FactLists, {text = 'Random', value = 'random'})

	for name, submodule in FunFact:IterateModules() do
		if (string.match(name, 'FactList_')) then
			local codeName = string.sub(name, 10)
			local displayname = codeName

			-- Load the modules Display name, If module does not have one set, lets set it for compatibility.
			if submodule.displayname then
				displayname = submodule.displayname
			else
				submodule.displayname = displayname
			end

			-- Toss the Displayname into the DB for easy loading
			FunFact.DB.FactData[name].displayname = displayname

			table.insert(FactLists, {text = displayname, value = codeName})
		end
	end

	local window = StdUi:Window(nil, 210, 270, 'Fun facts!')
	window:SetPoint('CENTER', 0, 0)
	window:SetFrameStrata('DIALOG')

	local items = {
		{text = L['Instance chat'], value = 'INSTANCE_CHAT'},
		{text = RAID, value = 'RAID'},
		{text = 'PARTY', value = 'PARTY'},
		{text = 'GUILD', value = 'GUILD'},
		{text = L['No chat'], value = 'SELF'},
		{text = L['Custom channel'], value = 'CHANNEL'}
	}

	window.FACT = StdUi:Button(window, 190, 20, 'FACT!')
	window.MORE = StdUi:Button(window, 190, 20, 'More?')
	window.MORE:SetPoint('BOTTOM', window, 'BOTTOM', 0, 2)
	window.FACT:SetPoint('BOTTOM', window.MORE, 'TOP', 0, 2)
	window.FACT:SetScript(
		'OnClick',
		function(this)
			FunFact:SendMessage(FunFact:GetFact(), true)
		end
	)
	window.MORE:SetScript(
		'OnClick',
		function(this)
			FunFact:SendMessage(L['Would you like to know more?'])
		end
	)

	local FactOptionslbl = StdUi:Label(window, L['What facts should we tell?'], nil, nil, 180, 20)
	local FactOptions = StdUi:Dropdown(window, 190, 20, FactLists, FunFact.DB.FactList)

	local Outputlbl = StdUi:Label(window, L['Who should we inform?'], nil, nil, 180, 20)
	local Output = StdUi:Dropdown(window, 190, 20, items, FunFact.DB.Output)

	local Channellbl = StdUi:Label(window, L['Channel name:'], nil, nil, 180, 20)
	local Channel = StdUi:EditBox(window, 190, 20, FunFact.DB.Channel)

	window.tbFact = StdUi:EditBox(window, 190, 20, '')
	if FunFact.DB.Output == 'CHANNEL' then
		Channel:Enable()
	else
		Channel:Disable()
	end

	FactOptions.OnValueChanged = function(self, value)
		FunFact.DB.FactList = value
	end
	Output.OnValueChanged = function(self, value)
		FunFact.DB.Output = value
		if value == 'CHANNEL' then
			Channel:Enable()
		else
			Channel:Disable()
		end
	end
	Channel.OnValueChanged = function(self, value)
		FunFact.DB.Channel = value
	end

	StdUi:GlueTop(FactOptionslbl, window, 0, -35)
	StdUi:GlueBelow(FactOptions, FactOptionslbl, 0, -5)

	StdUi:GlueBelow(Outputlbl, FactOptions, 0, -10)
	StdUi:GlueBelow(Output, Outputlbl, 0, -2)

	StdUi:GlueBelow(Channellbl, Output, 0, -10)
	StdUi:GlueBelow(Channel, Channellbl, 0, -2)

	StdUi:GlueBelow(window.tbFact, Channel, 0, -10)

	window:Hide()
	FunFact.window = window
end

function FunFact:ChatCommand(input)
	if input and input ~= '' then
		local AllowedChannels = {
			'RAID',
			'PARTY',
			'GUILD'
		}
		input = input:upper()
		if not FunFact:isInTable(AllowedChannels, input) then
			print('FunFact Error! You specified "' .. input .. '" you can only specify RAID, PARTY, and GUILD')
			return
		end

		FunFact:SendMessage(FunFact:GetFact(), true, input)
	else
		FunFact.window:Show()
	end
end

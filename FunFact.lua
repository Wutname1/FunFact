local _, FunFact = ...
FunFact = LibStub('AceAddon-3.0'):NewAddon(FunFact, 'FunFact', 'AceConsole-3.0')
local StdUi = LibStub('StdUi'):NewInstance()
local FactLists = {}

local DBdefaults = {
	profile = {
		Output = 'GUILD',
		Channel = ''
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

function FunFact:SendMessage(msg)
	if FunFact.DB.Output == 'CHANNEL' and FunFact.DB.Channel ~= '' then
		SendChatMessage(msg, FunFact.DB.Output, nil, FunFact.DB.Channel)
	elseif FunFact.DB.Output == 'SELF' then
		FunFact.window.tbFact:SetValue(msg)
	elseif FunFact.DB.Output ~= 'CHANNEL' then
		local announceChannel = FunFact.DB.Output

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
	else
		print('FunFact! Has encountered an error sending the message.')
	end
end

function FunFact:OnEnable()
	self:RegisterChatCommand('funfact', 'ChatCommand')
	self:RegisterChatCommand('fact', 'ChatCommand')

	for name, submodule in SUI:IterateModules() do
		if (string.match(name, 'FactList_')) then

			local codeName = string.sub(name, 10)
			local displayname = codeName

			if submodule.displayname then
				displayname = submodule.displayname
			end

			if FactLists[codeName] == nil then
				FactLists[codeName] = {
					name = displayname,
					desciption = submodule.desciption
				}
			end
		end
	end

	local window = StdUi:Window(nil, 'Fun facts!', 200, 220)
	window:SetPoint('CENTER', 0, 0)
	window:SetFrameStrata('DIALOG')

	local items = {
		{text = 'Instance chat', value = 'INSTANCE_CHAT'},
		{text = 'RAID', value = 'RAID'},
		{text = 'PARTY', value = 'PARTY'},
		{text = 'SAY', value = 'SAY'},
		{text = 'YELL', value = 'YELL'},
		{text = 'GUILD', value = 'GUILD'},
		{text = 'No chat', value = 'SELF'},
		{text = 'Custom channel', value = 'CHANNEL'}
	}

	window.FACT = StdUi:Button(window, 190, 20, 'FACT!')
	window.MORE = StdUi:Button(window, 190, 20, 'More?')
	window.MORE:SetPoint('BOTTOM', window, 'BOTTOM', 0, 2)
	window.FACT:SetPoint('BOTTOM', window.MORE, 'TOP', 0, 2)
	window.FACT:SetScript(
		'OnClick',
		function(this)
			FunFact:SendMessage('FunFact! ' .. facts[math.random(0, #facts - 1)])
		end
	)
	window.MORE:SetScript(
		'OnClick',
		function(this)
			FunFact:SendMessage('Would you like to know more?')
		end
	)

	local Outputlbl = StdUi:Label(window, 'Who should we inform?', nil, nil, 180, 20)
	local Output = StdUi:Dropdown(window, 190, 20, items, FunFact.DB.Output)
	local Channellbl = StdUi:Label(window, 'Channel name:', nil, nil, 180, 20)
	local Channel = StdUi:EditBox(window, 190, 20, FunFact.DB.Channel)
	window.tbFact = StdUi:EditBox(window, 190, 20, '')
	if value == 'CHANNEL' then
		Channel:Enable()
	else
		Channel:Disable()
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

	StdUi:GlueTop(Outputlbl, window, 0, -45)
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
			'SAY',
			'YELL',
			'GUILD'
		}
		input = input:upper()
		if not FunFact:isInTable(AllowedChannels, input) then
			print('FunFact Error! You specified "' .. input .. '" you can only specify RAID, PARTY, SAY, YELL, and GUILD')
			return
		end

		SendChatMessage('FunFact! ' .. facts[math.random(0, #facts - 1)], input, nil)
	else
		FunFact.window:Show()
	end
end

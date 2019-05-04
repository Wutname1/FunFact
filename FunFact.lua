local _, BeeFacts = ...
BeeFacts = LibStub('AceAddon-3.0'):NewAddon(BeeFacts, 'BeeFacts', 'AceConsole-3.0')
local StdUi = LibStub('StdUi'):NewInstance()

local DBdefaults = {
	profile = {
		Output = 'GUILD',
		Channel = ''
	}
}

function BeeFacts:isInTable(tab, frameName)
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

function BeeFacts:OnInitialize()
	BeeFacts.BfDB = LibStub('AceDB-3.0'):New('BeeFactsDB', DBdefaults)
	BeeFacts.DB = BeeFacts.BfDB.profile
end

function BeeFacts:SendMessage(msg)
	if BeeFacts.DB.Output == 'CHANNEL' and BeeFacts.DB.Channel ~= '' then
		SendChatMessage(msg, BeeFacts.DB.Output, nil, BeeFacts.DB.Channel)
	elseif BeeFacts.DB.Output == 'SELF' then
		BeeFacts.window.tbFact:SetValue(msg)
	elseif BeeFacts.DB.Output ~= 'CHANNEL' then
		local announceChannel = BeeFacts.DB.Output

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
		print('Beefacts! Has encountered an error sending the message.')
	end
end

function BeeFacts:OnEnable()
	self:RegisterChatCommand('beefact', 'ChatCommand')
	self:RegisterChatCommand('beefacts', 'ChatCommand')

	local window = StdUi:Window(nil, 'Bee facts!', 200, 220)
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
			BeeFacts:SendMessage('BeeFacts! ' .. facts[math.random(0, #facts - 1)])
		end
	)
	window.MORE:SetScript(
		'OnClick',
		function(this)
			BeeFacts:SendMessage('Would you like to know more?')
		end
	)

	local Outputlbl = StdUi:Label(window, 'Who should we inform?', nil, nil, 180, 20)
	local Output = StdUi:Dropdown(window, 190, 20, items, BeeFacts.DB.Output)
	local Channellbl = StdUi:Label(window, 'Channel name:', nil, nil, 180, 20)
	local Channel = StdUi:EditBox(window, 190, 20, BeeFacts.DB.Channel)
	window.tbFact = StdUi:EditBox(window, 190, 20, '')
	if value == 'CHANNEL' then
		Channel:Enable()
	else
		Channel:Disable()
	end

	Output.OnValueChanged = function(self, value)
		BeeFacts.DB.Output = value
		if value == 'CHANNEL' then
			Channel:Enable()
		else
			Channel:Disable()
		end
	end
	Channel.OnValueChanged = function(self, value)
		BeeFacts.DB.Channel = value
	end

	StdUi:GlueTop(Outputlbl, window, 0, -45)
	StdUi:GlueBelow(Output, Outputlbl, 0, -2)
	StdUi:GlueBelow(Channellbl, Output, 0, -10)
	StdUi:GlueBelow(Channel, Channellbl, 0, -2)
	StdUi:GlueBelow(window.tbFact, Channel, 0, -10)

	window:Hide()
	BeeFacts.window = window
end

function BeeFacts:ChatCommand(input)
	if input and input ~= '' then
		local AllowedChannels = {
			'RAID',
			'PARTY',
			'SAY',
			'YELL',
			'GUILD'
		}
		input = input:upper()
		if not BeeFacts:isInTable(AllowedChannels, input) then
			print('BeeFacts Error! You specified "' .. input .. '" you can only specify RAID, PARTY, SAY, YELL, and GUILD')
			return
		end

		SendChatMessage('BeeFacts! ' .. facts[math.random(0, #facts - 1)], input, nil)
	else
		BeeFacts.window:Show()
	end
end

---@class FunFact : AceAddon, AceConsole-3.0
local FunFact = LibStub('AceAddon-3.0'):NewAddon('FunFact', 'AceConsole-3.0')
---@diagnostic disable-next-line: undefined-field
local L = LibStub('AceLocale-3.0'):GetLocale('FunFact', true) ---@type FunFact_locale
_G.FunFact = FunFact
FunFact.L = L

local FactLists = {}
local FactModule = nil ---@type FunFact.Module

---@class FunFact.DB
local DBdefaults = {
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
	FunFact.BfDB = LibStub('AceDB-3.0'):New('FunFactDB', {profile = DBdefaults})
	FunFact.DB = FunFact.BfDB.profile ---@type FunFact.DB
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
	---@diagnostic disable-next-line: assign-type-mismatch
	FactModule = FunFact:GetModule('FactList_' .. FactList, true) ---@type FunFact.Module
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

	-- Empty out the Self Fact text box only if SELF mode is active
	if announceChannel ~= 'SELF' then
		FunFact.window.tbFact:SetValue('')
	end

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

	-- Create main window using PortraitFrameTemplate like RemixPowerLevel
	local window = CreateFrame('Frame', 'FunFactWindow', UIParent, 'PortraitFrameTemplate')
	ButtonFrameTemplate_HidePortrait(window)
	window:SetSize(350, 500)
	window:SetPoint('CENTER', 0, 0)
	window:SetFrameStrata('DIALOG')
	window:SetMovable(true)
	window:EnableMouse(true)
	window:RegisterForDrag('LeftButton')
	window:SetScript(
		'OnDragStart',
		function(frame)
			frame:StartMoving()
		end
	)
	window:SetScript(
		'OnDragStop',
		function(frame)
			frame:StopMovingOrSizing()
		end
	)

	if window.PortraitContainer then
		window.PortraitContainer:Hide()
	end
	if window.portrait then
		window.portrait:Hide()
	end
	window:SetTitle('Fun Facts!')

	-- Fact type dropdown label
	local FactOptionslbl = window:CreateFontString(nil, 'ARTWORK', 'GameFontNormalSmall')
	FactOptionslbl:SetPoint('TOPLEFT', window, 'TOPLEFT', 18, -40)
	FactOptionslbl:SetText(L['What facts should we tell?'])

	-- Fact type dropdown using WowStyle1FilterDropdownTemplate
	local FactOptions = CreateFrame('DropdownButton', nil, window, 'WowStyle1FilterDropdownTemplate')
	FactOptions:SetPoint('TOPLEFT', FactOptionslbl, 'BOTTOMLEFT', 0, -5)
	FactOptions:SetSize(314, 22)

	-- Find the current selection display name
	local currentFactName = FunFact.DB.FactList
	for _, factInfo in ipairs(FactLists) do
		if factInfo.value == currentFactName then
			currentFactName = factInfo.text
			break
		end
	end
	FactOptions:SetText(currentFactName)

	-- Setup fact type dropdown
	FactOptions:SetupMenu(
		function(_, rootDescription)
			for _, factInfo in ipairs(FactLists) do
				local button =
					rootDescription:CreateButton(
					factInfo.text,
					function()
						FunFact.DB.FactList = factInfo.value
						FactOptions:SetText(factInfo.text)
					end
				)
				if FunFact.DB.FactList == factInfo.value then
					button:SetRadio(true)
				end
			end
		end
	)

	-- Output channel label
	local Outputlbl = window:CreateFontString(nil, 'ARTWORK', 'GameFontNormalSmall')
	Outputlbl:SetPoint('TOPLEFT', FactOptions, 'BOTTOMLEFT', 0, -10)
	Outputlbl:SetText(L['Who should we inform?'])

	-- Output channel dropdown
	local Output = CreateFrame('DropdownButton', nil, window, 'WowStyle1FilterDropdownTemplate')
	Output:SetPoint('TOPLEFT', Outputlbl, 'BOTTOMLEFT', 0, -5)
	Output:SetSize(314, 22)

	local outputItems = {
		{text = L['Instance chat'], value = 'INSTANCE_CHAT'},
		{text = RAID, value = 'RAID'},
		{text = 'SAY', value = 'SAY'},
		{text = 'YELL', value = 'YELL'},
		{text = 'PARTY', value = 'PARTY'},
		{text = 'GUILD', value = 'GUILD'},
		{text = L['No chat'], value = 'SELF'},
		{text = L['Custom channel'], value = 'CHANNEL'}
	}

	-- Find current output display name
	local currentOutputName = FunFact.DB.Output
	for _, outputInfo in ipairs(outputItems) do
		if outputInfo.value == currentOutputName then
			currentOutputName = outputInfo.text
			break
		end
	end
	Output:SetText(currentOutputName)

	-- Setup output dropdown
	Output:SetupMenu(
		function(_, rootDescription)
			for _, outputInfo in ipairs(outputItems) do
				local button =
					rootDescription:CreateButton(
					outputInfo.text,
					function()
						FunFact.DB.Output = outputInfo.value
						Output:SetText(outputInfo.text)
						if outputInfo.value == 'CHANNEL' then
							Channel:Enable()
						else
							Channel:Disable()
						end
					end
				)
				if FunFact.DB.Output == outputInfo.value then
					button:SetRadio(true)
				end
			end
		end
	)

	-- Channel name label
	local Channellbl = window:CreateFontString(nil, 'ARTWORK', 'GameFontNormalSmall')
	Channellbl:SetPoint('TOPLEFT', Output, 'BOTTOMLEFT', 0, -10)
	Channellbl:SetText(L['Channel name:'])

	-- Channel name editbox
	local Channel = CreateFrame('EditBox', nil, window, 'InputBoxTemplate')
	Channel:SetPoint('TOPLEFT', Channellbl, 'BOTTOMLEFT', 10, -5)
	Channel:SetSize(304, 20)
	Channel:SetAutoFocus(false)
	Channel:SetMaxLetters(50)
	Channel:SetText(FunFact.DB.Channel)
	Channel:SetScript(
		'OnTextChanged',
		function(editBox, userInput)
			if userInput then
				FunFact.DB.Channel = editBox:GetText()
			end
		end
	)

	if FunFact.DB.Output == 'CHANNEL' then
		Channel:Enable()
	else
		Channel:Disable()
	end

	-- Fact display text box (larger multi-line)
	local factDisplayFrame = CreateFrame('Frame', nil, window)
	factDisplayFrame:SetPoint('TOPLEFT', Channel, 'BOTTOMLEFT', -10, -15)
	factDisplayFrame:SetPoint('TOPRIGHT', window, 'TOPRIGHT', -25, -265)
	factDisplayFrame:SetHeight(145)

	-- Add background texture
	factDisplayFrame.bg = factDisplayFrame:CreateTexture(nil, 'BACKGROUND')
	factDisplayFrame.bg:SetAllPoints()
	factDisplayFrame.bg:SetAtlas('auctionhouse-background-index', true)

	-- Scrollable fact display
	local factScroll = CreateFrame('ScrollFrame', nil, factDisplayFrame)
	factScroll:SetPoint('TOPLEFT', factDisplayFrame, 'TOPLEFT', 8, -8)
	factScroll:SetPoint('BOTTOMRIGHT', factDisplayFrame, 'BOTTOMRIGHT', -8, 8)

	-- Modern minimal scrollbar
	factScroll.ScrollBar = CreateFrame('EventFrame', nil, factScroll, 'MinimalScrollBar')
	factScroll.ScrollBar:SetPoint('TOPLEFT', factDisplayFrame.bg, 'TOPRIGHT', 6, 0)
	factScroll.ScrollBar:SetPoint('BOTTOMLEFT', factDisplayFrame.bg, 'BOTTOMRIGHT', 6, 0)
	ScrollUtil.InitScrollFrameWithScrollBar(factScroll, factScroll.ScrollBar)

	local factScrollChild = CreateFrame('Frame', nil, factScroll)
	factScroll:SetScrollChild(factScrollChild)
	factScrollChild:SetSize(factScroll:GetWidth(), 1)

	window.tbFact = factScrollChild:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
	window.tbFact:SetPoint('TOPLEFT', 5, -5)
	window.tbFact:SetPoint('TOPRIGHT', -5, -5)
	window.tbFact:SetJustifyH('LEFT')
	window.tbFact:SetJustifyV('TOP')
	window.tbFact:SetWordWrap(true)
	window.tbFact:SetText('')
	window.tbFact.SetValue = function(self, text)
		self:SetText(text)
		factScrollChild:SetHeight(math.max(self:GetStringHeight() + 10, factScroll:GetHeight()))
	end

	-- FACT! button using RemixPowerLevel style
	window.FACT = CreateFrame('Button', nil, window)
	window.FACT:SetSize(314, 30)
	window.FACT:SetPoint('TOPLEFT', factDisplayFrame, 'BOTTOMLEFT', 0, -10)

	window.FACT:SetNormalAtlas('auctionhouse-nav-button')
	window.FACT:SetHighlightAtlas('auctionhouse-nav-button-highlight')
	window.FACT:SetPushedAtlas('auctionhouse-nav-button-select')
	window.FACT:SetDisabledAtlas('UI-CastingBar-TextBox')

	local factNormalTexture = window.FACT:GetNormalTexture()
	factNormalTexture:SetTexCoord(0, 1, 0, 0.7)

	window.FACT.Text = window.FACT:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
	window.FACT.Text:SetPoint('CENTER')
	window.FACT.Text:SetText('FACT!')
	window.FACT.Text:SetTextColor(1, 1, 1, 1)

	window.FACT:HookScript(
		'OnDisable',
		function(btn)
			btn.Text:SetTextColor(0.6, 0.6, 0.6, 0.6)
		end
	)

	window.FACT:HookScript(
		'OnEnable',
		function(btn)
			btn.Text:SetTextColor(1, 1, 1, 1)
		end
	)

	window.FACT:SetScript(
		'OnClick',
		function()
			local fact = FunFact:GetFact()
			FunFact:SendMessage(fact, true)
			-- Also display in window
			window.tbFact:SetValue(fact)
		end
	)

	-- More? button using RemixPowerLevel style
	window.MORE = CreateFrame('Button', nil, window)
	window.MORE:SetSize(314, 25)
	window.MORE:SetPoint('TOPLEFT', window.FACT, 'BOTTOMLEFT', 0, -5)

	window.MORE:SetNormalAtlas('auctionhouse-nav-button')
	window.MORE:SetHighlightAtlas('auctionhouse-nav-button-highlight')
	window.MORE:SetPushedAtlas('auctionhouse-nav-button-select')
	window.MORE:SetDisabledAtlas('UI-CastingBar-TextBox')

	local moreNormalTexture = window.MORE:GetNormalTexture()
	moreNormalTexture:SetTexCoord(0, 1, 0, 0.7)

	window.MORE.Text = window.MORE:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
	window.MORE.Text:SetPoint('CENTER')
	window.MORE.Text:SetText('More?')
	window.MORE.Text:SetTextColor(1, 1, 1, 1)

	window.MORE:HookScript(
		'OnDisable',
		function(btn)
			btn.Text:SetTextColor(0.6, 0.6, 0.6, 0.6)
		end
	)

	window.MORE:HookScript(
		'OnEnable',
		function(btn)
			btn.Text:SetTextColor(1, 1, 1, 1)
		end
	)

	window.MORE:SetScript(
		'OnClick',
		function()
			FunFact:SendMessage(L['Would you like to know more?'])
		end
	)

	window:Hide()
	FunFact.window = window
end

function FunFact:ChatCommand(input)
	if input and input ~= '' then
		local AllowedChannels = {
			'RAID',
			'PARTY',
			'GUILD',
			'INSTANCE_CHAT',
			'SAY',
			'YELL'
		}
		input = input:upper()
		if not FunFact:isInTable(AllowedChannels, input) then
			print('FunFact Error! You specified "' .. input .. '" valid options are: SAY, YELL, INSTANCE_CHAT, RAID, PARTY, and GUILD')
			return
		end

		FunFact:SendMessage(FunFact:GetFact(), true, input)
	else
		FunFact.window:Show()
	end
end

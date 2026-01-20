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

	-- Register with LibAT Logger if available
	if LibAT and LibAT.Logger then
		FunFact.logger = LibAT.Logger.RegisterAddon('FunFact')
		FunFact.logger.info("FunFact initialized")
	end
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

---Check if chat messaging is currently restricted by Midnight 12.0 lockdown
---@return boolean isRestricted True if chat is locked down
---@return string|nil reason Human-readable reason for lockdown
function FunFact:IsInChatLockdown()
	-- Check if the new API exists (backward compatibility with 11.x)
	if not C_ChatInfo or not C_ChatInfo.InChatMessagingLockdown then
		return false, nil
	end

	local isRestricted, lockdownReason = C_ChatInfo.InChatMessagingLockdown()

	if not isRestricted then
		return false, nil
	end

	-- Convert enum to human-readable string
	local reasonText = "Unknown reason"
	if lockdownReason then
		if lockdownReason == Enum.ChatMessagingLockdownReason.ActiveEncounter then
			reasonText = "Active raid encounter"
		elseif lockdownReason == Enum.ChatMessagingLockdownReason.ActiveMythicKeystoneOrChallengeMode then
			reasonText = "Active Mythic+ or Challenge Mode"
		elseif lockdownReason == Enum.ChatMessagingLockdownReason.ActivePvPMatch then
			reasonText = "Active PvP match"
		end
	end

	return true, reasonText
end

function FunFact:SendMessage(msg, prefix, ChannelOverride)
	-- output channel overtide logic
	local announceChannel = FunFact.DB.Output
	if ChannelOverride then
		announceChannel = ChannelOverride
	end

	-- Check for chat lockdown (except SELF channel which is local-only)
	if announceChannel ~= 'SELF' then
		local isLocked, reason = self:IsInChatLockdown()
		if isLocked then
			-- Display in local UI instead
			if self.window and self.window.tbFact then
				self.window.tbFact:SetValue(string.format("[Chat Locked: %s] %s", reason or "Unknown", msg))
			end

			-- Log to LibAT Logger if available
			if LibAT and LibAT.Logger and self.logger then
				self.logger.warning(string.format("Cannot send fact to chat - Chat lockdown active: %s", reason or "Unknown"))
			end

			-- Don't send the message
			return
		end
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

	local SendChatMessage = C_ChatInfo and C_ChatInfo.SendChatMessage or SendChatMessage

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
	window:SetSize(350, 325)
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
	FactOptionslbl:SetPoint('TOPLEFT', window, 'TOPLEFT', 18, -35)
	FactOptionslbl:SetText(L['What facts should we tell?'])

	-- Fact type dropdown using WowStyle1FilterDropdownTemplate
	local FactOptions = CreateFrame('DropdownButton', nil, window, 'WowStyle1FilterDropdownTemplate')
	FactOptions:SetPoint('TOPLEFT', FactOptionslbl, 'BOTTOMLEFT', 0, -5)
	FactOptions:SetSize(152, 22)

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
	Outputlbl:SetPoint('TOPLEFT', FactOptionslbl, 'TOPRIGHT', 20, 0)
	Outputlbl:SetText(L['Who should we inform?'])

	-- Output channel dropdown
	local Output = CreateFrame('DropdownButton', nil, window, 'WowStyle1FilterDropdownTemplate')
	Output:SetPoint('TOPLEFT', Outputlbl, 'BOTTOMLEFT', 0, -5)
	Output:SetSize(152, 22)

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
	Channellbl:SetPoint('TOPLEFT', FactOptions, 'BOTTOMLEFT', 0, -10)
	Channellbl:SetText(L['Channel name:'])

	-- Channel name editbox
	local Channel = CreateFrame('EditBox', nil, window, 'InputBoxTemplate')
	Channel:SetPoint('LEFT', Channellbl, 'RIGHT', 10, 0)
	Channel:SetSize(230, 20)
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

	-- Fact display text box (larger multi-line, selectable)
	local factDisplayFrame = CreateFrame('ScrollFrame', nil, window)
	factDisplayFrame:SetPoint('TOPLEFT', Channellbl, 'BOTTOMLEFT', 2, -17)
	factDisplayFrame:SetSize(window:GetWidth() - 45, 170)

	-- Add background texture
	factDisplayFrame.bg = factDisplayFrame:CreateTexture(nil, 'BACKGROUND')
	factDisplayFrame.bg:SetPoint('TOPLEFT', factDisplayFrame, 'TOPLEFT', -6, 6)
	factDisplayFrame.bg:SetPoint('BOTTOMRIGHT', factDisplayFrame, 'BOTTOMRIGHT', 0, -6)
	factDisplayFrame.bg:SetAtlas('auctionhouse-background-index', true)

	-- Modern minimal scrollbar
	factDisplayFrame.ScrollBar = CreateFrame('EventFrame', nil, factDisplayFrame, 'MinimalScrollBar')
	factDisplayFrame.ScrollBar:SetPoint('TOPLEFT', factDisplayFrame, 'TOPRIGHT', 6, 0)
	factDisplayFrame.ScrollBar:SetPoint('BOTTOMLEFT', factDisplayFrame, 'BOTTOMRIGHT', 6, 0)
	ScrollUtil.InitScrollFrameWithScrollBar(factDisplayFrame, factDisplayFrame.ScrollBar)

	-- Create the selectable text edit box
	window.tbFact = CreateFrame('EditBox', nil, factDisplayFrame)
	window.tbFact:SetMultiLine(true)
	window.tbFact:SetFontObject('GameFontNormal')
	window.tbFact:SetWidth(factDisplayFrame:GetWidth() - 20)
	window.tbFact:SetAutoFocus(false)
	window.tbFact:EnableMouse(true)
	window.tbFact:SetTextColor(1, 1, 1)
	-- window.tbFact:SetScript(
	-- 	'OnTextChanged',
	-- 	function(self)
	-- 		ScrollingEdit_OnTextChanged(self, self:GetParent())
	-- 	end
	-- )
	-- window.tbFact:SetScript(
	-- 	'OnCursorChanged',
	-- 	function(self, x, y, w, h)
	-- 		ScrollingEdit_OnCursorChanged(self, x, y - 10, w, h)
	-- 	end
	-- )
	factDisplayFrame:SetScrollChild(window.tbFact)

	-- Add SetValue method for compatibility with existing code
	window.tbFact.SetValue = function(self, text)
		self:SetText(text)
	end

	-- FACT! button using RemixPowerLevel style
	window.FACT = CreateFrame('Button', nil, window)
	window.FACT:SetSize(120, 25)
	window.FACT:SetPoint('BOTTOMLEFT', window, 'BOTTOMLEFT', 10, 5)

	window.FACT:SetNormalAtlas('auctionhouse-nav-button')
	window.FACT:SetHighlightAtlas('auctionhouse-nav-button-highlight')
	window.FACT:SetPushedAtlas('auctionhouse-nav-button-select')
	window.FACT:SetDisabledAtlas('UI-CastingBar-TextBox')

	local factNormalTexture = window.FACT:GetNormalTexture()
	factNormalTexture:SetTexCoord(0, 1, 0, 0.7)

	window.FACT.Text = window.FACT:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
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

	-- More? button using RemixPowerLevel style (side by side with FACT!)
	window.MORE = CreateFrame('Button', nil, window)
	window.MORE:SetSize(120, 25)
	window.MORE:SetPoint('BOTTOMRIGHT', window, 'BOTTOMRIGHT', -8, 5)

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

	-- BROWSE button (centered between FACT! and More?)
	window.BROWSE = CreateFrame('Button', nil, window)
	window.BROWSE:SetSize(80, 25)
	window.BROWSE:SetPoint('LEFT', window.FACT, 'RIGHT', 5, 0)
	window.BROWSE:SetPoint('RIGHT', window.MORE, 'LEFT', -5, 0)

	window.BROWSE:SetNormalAtlas('auctionhouse-nav-button')
	window.BROWSE:SetHighlightAtlas('auctionhouse-nav-button-highlight')
	window.BROWSE:SetPushedAtlas('auctionhouse-nav-button-select')
	window.BROWSE:SetDisabledAtlas('UI-CastingBar-TextBox')

	local browseNormalTexture = window.BROWSE:GetNormalTexture()
	browseNormalTexture:SetTexCoord(0, 1, 0, 0.7)

	window.BROWSE.Text = window.BROWSE:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
	window.BROWSE.Text:SetPoint('CENTER')
	window.BROWSE.Text:SetText('Browse')
	window.BROWSE.Text:SetTextColor(1, 1, 1, 1)

	window.BROWSE:HookScript(
		'OnDisable',
		function(btn)
			btn.Text:SetTextColor(0.6, 0.6, 0.6, 0.6)
		end
	)

	window.BROWSE:HookScript(
		'OnEnable',
		function(btn)
			btn.Text:SetTextColor(1, 1, 1, 1)
		end
	)

	window.BROWSE:SetScript(
		'OnClick',
		function()
			FunFact:ShowBrowseWindow()
		end
	)

	window:Hide()
	FunFact.window = window

	-- Create Browse window for viewing all facts
	FunFact:CreateBrowseWindow()
end

---Creates the Browse window for viewing all facts in a category
function FunFact:CreateBrowseWindow()
	local browse = CreateFrame('Frame', 'FunFactBrowseWindow', UIParent, 'PortraitFrameTemplate')
	ButtonFrameTemplate_HidePortrait(browse)
	browse:SetSize(600, 500)
	browse:SetPoint('CENTER', 0, 0)
	browse:SetFrameStrata('DIALOG')
	browse:SetMovable(true)
	browse:EnableMouse(true)
	browse:RegisterForDrag('LeftButton')
	browse:SetScript(
		'OnDragStart',
		function(frame)
			frame:StartMoving()
		end
	)
	browse:SetScript(
		'OnDragStop',
		function(frame)
			frame:StopMovingOrSizing()
		end
	)

	if browse.PortraitContainer then
		browse.PortraitContainer:Hide()
	end
	if browse.portrait then
		browse.portrait:Hide()
	end
	browse:SetTitle('Browse Facts')

	-- Category dropdown label
	local categoryLbl = browse:CreateFontString(nil, 'ARTWORK', 'GameFontNormal')
	categoryLbl:SetPoint('TOPLEFT', browse, 'TOPLEFT', 18, -35)
	categoryLbl:SetText('Category:')

	-- Category dropdown
	browse.categoryDropdown = CreateFrame('DropdownButton', nil, browse, 'WowStyle1FilterDropdownTemplate')
	browse.categoryDropdown:SetPoint('LEFT', categoryLbl, 'RIGHT', 10, 0)
	browse.categoryDropdown:SetSize(200, 22)
	browse.categoryDropdown:SetText('Random')

	-- Setup category dropdown
	browse.categoryDropdown:SetupMenu(
		function(_, rootDescription)
			for _, factInfo in ipairs(FactLists) do
				local button =
					rootDescription:CreateButton(
					factInfo.text,
					function()
						FunFact.DB.FactList = factInfo.value
						browse.categoryDropdown:SetText(factInfo.text)
						FunFact.browseCurrentPage = 1
						FunFact:UpdateBrowseWindow()
					end
				)
				if FunFact.DB.FactList == factInfo.value then
					button:SetRadio(true)
				end
			end
		end
	)

	-- Page info label
	browse.pageLabel = browse:CreateFontString(nil, 'ARTWORK', 'GameFontNormal')
	browse.pageLabel:SetPoint('TOP', categoryLbl, 'BOTTOM', 0, -15)
	browse.pageLabel:SetText('Page 1 of 1')

	-- Scroll frame for facts
	local scrollFrame = CreateFrame('ScrollFrame', nil, browse)
	scrollFrame:SetPoint('TOPLEFT', browse.pageLabel, 'BOTTOMLEFT', 18, -15)
	scrollFrame:SetPoint('BOTTOMRIGHT', browse, 'BOTTOMRIGHT', -28, 45)

	-- Add background texture
	scrollFrame.bg = scrollFrame:CreateTexture(nil, 'BACKGROUND')
	scrollFrame.bg:SetPoint('TOPLEFT', scrollFrame, 'TOPLEFT', -6, 6)
	scrollFrame.bg:SetPoint('BOTTOMRIGHT', scrollFrame, 'BOTTOMRIGHT', 0, -6)
	scrollFrame.bg:SetAtlas('auctionhouse-background-index', true)

	-- Modern minimal scrollbar
	scrollFrame.ScrollBar = CreateFrame('EventFrame', nil, scrollFrame, 'MinimalScrollBar')
	scrollFrame.ScrollBar:SetPoint('TOPLEFT', scrollFrame, 'TOPRIGHT', 6, 0)
	scrollFrame.ScrollBar:SetPoint('BOTTOMLEFT', scrollFrame, 'BOTTOMRIGHT', 6, 0)
	ScrollUtil.InitScrollFrameWithScrollBar(scrollFrame, scrollFrame.ScrollBar)

	-- Create the text display
	browse.factText = CreateFrame('EditBox', nil, scrollFrame)
	browse.factText:SetMultiLine(true)
	browse.factText:SetFontObject('GameFontNormal')
	browse.factText:SetWidth(scrollFrame:GetWidth() - 20)
	browse.factText:SetAutoFocus(false)
	browse.factText:EnableMouse(true)
	browse.factText:SetTextColor(1, 1, 1)
	scrollFrame:SetScrollChild(browse.factText)

	-- Previous page button
	browse.prevButton = CreateFrame('Button', nil, browse)
	browse.prevButton:SetSize(100, 25)
	browse.prevButton:SetPoint('BOTTOMLEFT', browse, 'BOTTOMLEFT', 10, 10)

	browse.prevButton:SetNormalAtlas('auctionhouse-nav-button')
	browse.prevButton:SetHighlightAtlas('auctionhouse-nav-button-highlight')
	browse.prevButton:SetPushedAtlas('auctionhouse-nav-button-select')
	browse.prevButton:SetDisabledAtlas('UI-CastingBar-TextBox')

	local prevNormalTexture = browse.prevButton:GetNormalTexture()
	prevNormalTexture:SetTexCoord(0, 1, 0, 0.7)

	browse.prevButton.Text = browse.prevButton:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
	browse.prevButton.Text:SetPoint('CENTER')
	browse.prevButton.Text:SetText('< Previous')
	browse.prevButton.Text:SetTextColor(1, 1, 1, 1)

	browse.prevButton:HookScript(
		'OnDisable',
		function(btn)
			btn.Text:SetTextColor(0.6, 0.6, 0.6, 0.6)
		end
	)

	browse.prevButton:HookScript(
		'OnEnable',
		function(btn)
			btn.Text:SetTextColor(1, 1, 1, 1)
		end
	)

	browse.prevButton:SetScript(
		'OnClick',
		function()
			FunFact:BrowsePreviousPage()
		end
	)

	-- Next page button
	browse.nextButton = CreateFrame('Button', nil, browse)
	browse.nextButton:SetSize(100, 25)
	browse.nextButton:SetPoint('BOTTOMRIGHT', browse, 'BOTTOMRIGHT', -10, 10)

	browse.nextButton:SetNormalAtlas('auctionhouse-nav-button')
	browse.nextButton:SetHighlightAtlas('auctionhouse-nav-button-highlight')
	browse.nextButton:SetPushedAtlas('auctionhouse-nav-button-select')
	browse.nextButton:SetDisabledAtlas('UI-CastingBar-TextBox')

	local nextNormalTexture = browse.nextButton:GetNormalTexture()
	nextNormalTexture:SetTexCoord(0, 1, 0, 0.7)

	browse.nextButton.Text = browse.nextButton:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
	browse.nextButton.Text:SetPoint('CENTER')
	browse.nextButton.Text:SetText('Next >')
	browse.nextButton.Text:SetTextColor(1, 1, 1, 1)

	browse.nextButton:HookScript(
		'OnDisable',
		function(btn)
			btn.Text:SetTextColor(0.6, 0.6, 0.6, 0.6)
		end
	)

	browse.nextButton:HookScript(
		'OnEnable',
		function(btn)
			btn.Text:SetTextColor(1, 1, 1, 1)
		end
	)

	browse.nextButton:SetScript(
		'OnClick',
		function()
			FunFact:BrowseNextPage()
		end
	)

	-- Close button (center bottom)
	browse.closeButton = CreateFrame('Button', nil, browse)
	browse.closeButton:SetSize(80, 25)
	browse.closeButton:SetPoint('BOTTOM', browse, 'BOTTOM', 0, 10)

	browse.closeButton:SetNormalAtlas('auctionhouse-nav-button')
	browse.closeButton:SetHighlightAtlas('auctionhouse-nav-button-highlight')
	browse.closeButton:SetPushedAtlas('auctionhouse-nav-button-select')

	local closeNormalTexture = browse.closeButton:GetNormalTexture()
	closeNormalTexture:SetTexCoord(0, 1, 0, 0.7)

	browse.closeButton.Text = browse.closeButton:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
	browse.closeButton.Text:SetPoint('CENTER')
	browse.closeButton.Text:SetText('Close')
	browse.closeButton.Text:SetTextColor(1, 1, 1, 1)

	browse.closeButton:SetScript(
		'OnClick',
		function()
			browse:Hide()
		end
	)

	browse:Hide()
	FunFact.browseWindow = browse
	FunFact.browseCurrentPage = 1
	FunFact.browseFactsPerPage = 50
end

---Shows the Browse window with facts from the currently selected category
function FunFact:ShowBrowseWindow()
	if not FunFact.browseWindow then
		return
	end

	local factList = FunFact.DB.FactList
	local displayName = factList

	-- Get the display name for the category
	if factList == 'random' then
		displayName = 'Random'
	else
		for _, factInfo in ipairs(FactLists) do
			if factInfo.value == factList then
				displayName = factInfo.text
				break
			end
		end
	end

	-- Update the dropdown to match current selection
	FunFact.browseWindow.categoryDropdown:SetText(displayName)
	FunFact.browseCurrentPage = 1
	FunFact:UpdateBrowseWindow()
	FunFact.browseWindow:Show()
end

---Updates the Browse window content for the current page
function FunFact:UpdateBrowseWindow()
	if not FunFact.browseWindow then
		return
	end

	local factList = FunFact.DB.FactList
	local facts = {}

	-- Get facts based on selected category
	if factList == 'random' then
		-- Collect all facts from all modules
		for name, submodule in FunFact:IterateModules() do
			if string.match(name, 'FactList_') and submodule.Facts then
				for _, fact in ipairs(submodule.Facts) do
					table.insert(facts, fact)
				end
			end
		end
	else
		-- Get facts from specific module
		---@diagnostic disable-next-line: assign-type-mismatch
		local module = FunFact:GetModule('FactList_' .. factList, true) ---@type FunFact.Module
		if module and module.Facts then
			for _, fact in ipairs(module.Facts) do
				table.insert(facts, fact)
			end
		end
	end

	-- Calculate pagination
	local totalFacts = #facts
	local totalPages = math.ceil(totalFacts / FunFact.browseFactsPerPage)
	if totalPages == 0 then
		totalPages = 1
	end

	-- Clamp current page
	if FunFact.browseCurrentPage > totalPages then
		FunFact.browseCurrentPage = totalPages
	end
	if FunFact.browseCurrentPage < 1 then
		FunFact.browseCurrentPage = 1
	end

	-- Update page label
	FunFact.browseWindow.pageLabel:SetText(
		string.format('Page %d of %d (%d total facts)', FunFact.browseCurrentPage, totalPages, totalFacts)
	)

	-- Enable/disable navigation buttons
	if FunFact.browseCurrentPage <= 1 then
		FunFact.browseWindow.prevButton:Disable()
	else
		FunFact.browseWindow.prevButton:Enable()
	end

	if FunFact.browseCurrentPage >= totalPages then
		FunFact.browseWindow.nextButton:Disable()
	else
		FunFact.browseWindow.nextButton:Enable()
	end

	-- Build text for current page
	local startIdx = (FunFact.browseCurrentPage - 1) * FunFact.browseFactsPerPage + 1
	local endIdx = math.min(startIdx + FunFact.browseFactsPerPage - 1, totalFacts)

	local text = ''
	for i = startIdx, endIdx do
		if facts[i] then
			text = text .. string.format('%d. %s\n\n', i, facts[i])
		end
	end

	FunFact.browseWindow.factText:SetText(text)
	FunFact.browseWindow.factText:SetCursorPosition(0)
end

---Navigates to the previous page in the Browse window
function FunFact:BrowsePreviousPage()
	if FunFact.browseCurrentPage > 1 then
		FunFact.browseCurrentPage = FunFact.browseCurrentPage - 1
		FunFact:UpdateBrowseWindow()
	end
end

---Navigates to the next page in the Browse window
function FunFact:BrowseNextPage()
	FunFact.browseCurrentPage = FunFact.browseCurrentPage + 1
	FunFact:UpdateBrowseWindow()
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

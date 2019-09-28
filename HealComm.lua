local libCHC = LibStub("LibClassicHealComm-1.0", true)

OVERHEALPERCENT = 20

HealComm = select(2, ...)
HealComm.version = 2002

local hpBars = {}

local frames = {
				["player"] = { bar = getglobal("PlayerFrameHealthBar"), frame = _G["PlayerFrame"] },
				["pet"] = { bar = getglobal("PetFrameHealthBar"), frame = _G["PetFrame"] },
				["target"] = { bar = getglobal("TargetFrameHealthBar"), frame = _G["TargetFrame"] },
				["party1"] = { bar = getglobal("PartyMemberFrame1HealthBar"), frame = _G["PartyMemberFrame1"] },
				["partypet1"] = { bar = getglobal("PartyMemberFrame1PetFrameHealthBar"), frame = _G["PartyMemberFrame1PetFrame"] },
				["party2"] = { bar = getglobal("PartyMemberFrame2HealthBar"), frame = _G["PartyMemberFrame2"] },
				["partypet2"] = { bar = getglobal("PartyMemberFrame2PetFrameHealthBar"), frame = _G["PartyMemberFrame2PetFrame"] },
				["party3"] = { bar = getglobal("PartyMemberFrame3HealthBar"), frame = _G["PartyMemberFrame3"] },
				["partypet3"] = { bar = getglobal("PartyMemberFrame3PetFrameHealthBar"), frame = _G["PartyMemberFrame3PetFrame"] },
				["party4"] = { bar = getglobal("PartyMemberFrame4HealthBar"), frame = _G["PartyMemberFrame4"] },
				["partypet4"] = { bar = getglobal("PartyMemberFrame4PetFrameHealthBar"), frame = _G["PartyMemberFrame4PetFrame"] },
				}

local partyGUIDs = {
	[UnitGUID("player")] = "player",
}
local currentHeals = {}

local function RaidPulloutButton_OnLoadHook(self)
	if not hpBars[self] then
		hpBars[getglobal(self:GetParent():GetName().."HealthBar")] = CreateFrame("StatusBar", self:GetName().."HealthBarIncHeal" , self)
		hpBars[getglobal(self:GetParent():GetName().."HealthBar")]:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
		hpBars[getglobal(self:GetParent():GetName().."HealthBar")]:SetMinMaxValues(0, 1)
		hpBars[getglobal(self:GetParent():GetName().."HealthBar")]:SetValue(1)
		hpBars[getglobal(self:GetParent():GetName().."HealthBar")]:SetStatusBarColor(0, 1, 0, 0.6)
	end
end

local function UnitFrameHealthBar_OnValueChangedHook(self)
	HealComm:UpdateFrame(self, self.unit, currentHeals[UnitGUID(self.unit)] or 0)
end

local function UnitFrameHealthBar_OnUpdateHook(self)
	if self.unit ~= "player" then return end
	HealComm:UpdateFrame(self, self.unit, currentHeals[UnitGUID(self.unit)] or 0)
end
hooksecurefunc("UnitFrameHealthBar_OnUpdate", UnitFrameHealthBar_OnUpdateHook) -- This needs early hooking

local function CompactUnitFrame_UpdateHealthHook(self)
	if not hpBars[self.healthBar] then return end
	HealComm:UpdateFrame(self.healthBar, self.displayedUnit, currentHeals[UnitGUID(self.displayedUnit)] or 0)
end

local function CompactUnitFrame_UpdateMaxHealthHook(self)
	if not hpBars[self.healthBar] then return end
	HealComm:UpdateFrame(self.healthBar, self.displayedUnit, currentHeals[UnitGUID(self.displayedUnit)] or 0)
end

local function CompactUnitFrame_SetUnitHook(self, unit)
	if not hpBars[self.healthBar] then
		hpBars[self.healthBar] = CreateFrame("StatusBar", nil, self)
		hpBars[self.healthBar]:SetStatusBarTexture("Interface\\RaidFrame\\Raid-Bar-Hp-Fill")
		hpBars[self.healthBar]:SetMinMaxValues(0, 1)
		hpBars[self.healthBar]:SetValue(1)
		hpBars[self.healthBar]:SetStatusBarColor(0, 1, 0, 0.6)
	end
end
hooksecurefunc("CompactUnitFrame_SetUnit", CompactUnitFrame_SetUnitHook) -- This needs early hooking

function HealComm:OnInitialize()
	self:CreateBars()
	hooksecurefunc("RaidPulloutButton_OnLoad", RaidPulloutButton_OnLoadHook)
	hooksecurefunc("UnitFrameHealthBar_OnValueChanged", UnitFrameHealthBar_OnValueChangedHook)
	hooksecurefunc("CompactUnitFrame_UpdateHealth", CompactUnitFrame_UpdateHealthHook)
	hooksecurefunc("CompactUnitFrame_UpdateMaxHealth", CompactUnitFrame_UpdateMaxHealthHook)
	libCHC.RegisterCallback(HealComm, "HealComm_HealStarted", "HealComm_HealUpdated")
	libCHC.RegisterCallback(HealComm, "HealComm_HealStopped")
	libCHC.RegisterCallback(HealComm, "HealComm_HealDelayed", "HealComm_HealUpdated")
	libCHC.RegisterCallback(HealComm, "HealComm_HealUpdated")
	libCHC.RegisterCallback(HealComm, "HealComm_ModifierChanged")
	libCHC.RegisterCallback(HealComm, "HealComm_GUIDDisappeared")
end

function HealComm:CreateBars()
	for unit,v in pairs(frames) do
		if not hpBars[v] then
			hpBars[v.bar] = CreateFrame("StatusBar", "IncHealBar"..unit, v.frame)
			hpBars[v.bar]:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
			hpBars[v.bar]:SetMinMaxValues(0, 1)
			hpBars[v.bar]:SetValue(1)
			hpBars[v.bar]:SetStatusBarColor(0, 1, 0, 0.6)
		end
	end
end

function HealComm:UNIT_PET(unit)
	if unit ~= "player" and strsub(unit,1,5) ~= "party" then return end
	petunit = unit == "player" and "pet" or "partypet"..strsub(unit,6)
	for guid,unit in pairs(partyGUIDs) do
		if unit == petunit then
			partyGUIDs[guid] = nil
			break
		end
	end
	if UnitExists(petunit) then
		partyGUIDs[UnitGUID(petunit)] = petunit
	end
	if hpBars[frames[petunit].bar] then
		self:UpdateFrame(frames[petunit].bar, petunit, currentHeals[UnitGUID("pet")] or 0)
	end
end

function HealComm:PLAYER_TARGET_CHANGED()
	self:UpdateFrame(frames["target"].bar, "target", currentHeals[UnitGUID("target")] or 0)
end

function HealComm:PLAYER_ROLES_ASSIGNED() --GROUP_ROSTER_UPDATE()
	local frame, unitframe, num
	for guid,unit in pairs(partyGUIDs) do
		if strsub(unit,1,5) == "party" then
			partyGUIDs[guid] = nil
		end
	end
	
	if UnitInParty("player") then
		for i=1, MAX_PARTY_MEMBERS do
			local p = "party"..i
			if UnitExists(p) then
				partyGUIDs[UnitGUID(p)] = p
			else
				break
			end
		end
		unitframe = _G["CompactPartyFrameMember1"]
		num = 1
		while unitframe do
			if unitframe.displayedUnit and UnitExists(unitframe.displayedUnit) then
				self:UpdateFrame(unitframe.healthBar, unitframe.displayedUnit, amount)
			end
			num = num + 1
			unitframe = _G["CompactPartyFrameMember"..num]
		end
		unitframe = _G["CompactRaidFrame1"]
		num = 1
		while unitframe do
			if unitframe.displayedUnit and UnitExists(unitframe.displayedUnit) then
				self:UpdateFrame(unitframe.healthBar, unitframe.displayedUnit, amount)
			end
			num = num + 1
			unitframe = _G["CompactRaidFrame"..num]
		end
	end
	if UnitInRaid("player") then
		for k=1, NUM_RAID_PULLOUT_FRAMES do
			frame = getglobal("RaidPullout"..k)
			for z=1, frame.numPulloutButtons do
				unitframe = getglobal(frame:GetName().."Button"..z)
				if unitframe.unit and UnitExists(unitframe.unit) then
					self:UpdateFrame(getglobal(unitframe:GetName().."HealthBar"), unitframe.unit, currentHeals[UnitGUID(unitframe.unit)] or 0)
				end
			end
		end
		for i=1, 8 do
			local grpHeader = "CompactRaidGroup"..i
			if _G[grpHeader] then
				for k=1, 5 do
					unitframe = _G[grpHeader.."Member"..k]
					if unitframe and unitframe.displayedUnit and UnitExists(unitframe.displayedUnit) then
						self:UpdateFrame(unitframe.healthBar, unitframe.displayedUnit, currentHeals[UnitGUID(unitframe.displayedUnit)] or 0)
					end
				end
			end
		end
	end
end

function HealComm:HealComm_HealUpdated(event, casterGUID, spellID, healType, endTime, ...)
	self:UpdateIncoming(...)
end

function HealComm:HealComm_HealStopped(event, casterGUID, spellID, healType, interrupted, ...)
	self:UpdateIncoming(...)
end

function HealComm:HealComm_ModifierChanged(event, guid)
	self:UpdateIncoming(guid)
end

function HealComm:HealComm_GUIDDisappeared(event, guid)
	self:UpdateIncoming(guid)
end

-- Handle callbacks from lib
function HealComm:UpdateIncoming(...)
	local amount, targetGUID, num, frame, unitframe
	for i=1, select("#", ...) do
		targetGUID = select(i, ...)
		amount = (libCHC:GetHealAmount(targetGUID, libCHC.ALL_HEALS) or 0) * (libCHC:GetHealModifier(targetGUID) or 1)
		currentHeals[targetGUID] = amount > 0 and amount
		if UnitGUID("target") == targetGUID then
			self:UpdateFrame(frames["target"].bar, "target", amount)
		end
		if partyGUIDs[targetGUID] then
			self:UpdateFrame(frames[partyGUIDs[targetGUID]].bar, partyGUIDs[targetGUID], amount)
		end
		if UnitInParty("player") then
			unitframe = _G["CompactPartyFrameMember1"]
			num = 1
			while unitframe do
				if unitframe.displayedUnit and UnitExists(unitframe.displayedUnit) and UnitGUID(unitframe.displayedUnit) == targetGUID then
					self:UpdateFrame(unitframe.healthBar, unitframe.displayedUnit, amount)
				end
				num = num + 1
				unitframe = _G["CompactPartyFrameMember"..num]
			end
			unitframe = _G["CompactRaidFrame1"]
			num = 1
			while unitframe do
				if unitframe.displayedUnit and UnitExists(unitframe.displayedUnit) and UnitGUID(unitframe.displayedUnit) == targetGUID then
					self:UpdateFrame(unitframe.healthBar, unitframe.displayedUnit, amount)
				end
				num = num + 1
				unitframe = _G["CompactRaidFrame"..num]
			end
		end
		if UnitInRaid("player") then
			for k=1, NUM_RAID_PULLOUT_FRAMES do
				frame = getglobal("RaidPullout"..k)
				for z=1, frame.numPulloutButtons do
					unitframe = getglobal(frame:GetName().."Button"..z)
					if unitframe.unit and UnitExists(unitframe.unit) and UnitGUID(unitframe.unit) == targetGUID then
						self:UpdateFrame(getglobal(unitframe:GetName().."HealthBar"), unitframe.unit, amount)
					end
				end
			end
			for j=1, 8 do
				local grpHeader = "CompactRaidGroup"..j
				if _G[grpHeader] then
					for k=1, 5 do
						unitframe = _G[grpHeader.."Member"..k]
						if unitframe and unitframe.displayedUnit and UnitExists(unitframe.displayedUnit) and UnitGUID(unitframe.displayedUnit) == targetGUID then
							self:UpdateFrame(unitframe.healthBar, unitframe.displayedUnit, currentHeals[UnitGUID(unitframe.displayedUnit)] or 0)
						end
					end
				end
			end
		end
	end
end

function HealComm:UpdateFrame(frame, unit, amount)
	local health, maxHealth = UnitHealth(unit), UnitHealthMax(unit)
	if( amount and amount > 0 and (health < maxHealth or OVERHEALPERCENT > 0 )) and frame:IsVisible() then
		hpBars[frame]:Show()
		local healthWidth = frame:GetWidth() * (health / maxHealth)
		local incWidth = frame:GetWidth() * (amount / maxHealth)
		if (healthWidth + incWidth) > (frame:GetWidth() * (1+(OVERHEALPERCENT/100)) ) then
			incWidth = frame:GetWidth() * (1+(OVERHEALPERCENT/100)) - healthWidth
		end
		hpBars[frame]:SetWidth(incWidth)
		hpBars[frame]:SetHeight(frame:GetHeight())
		hpBars[frame]:ClearAllPoints()
		hpBars[frame]:SetPoint("TOPLEFT", frame, "TOPLEFT", healthWidth, 0)
	else
		hpBars[frame]:Hide()
	end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("PLAYER_ROLES_ASSIGNED")
frame:RegisterEvent("UNIT_PET")
frame:SetScript("OnEvent", function(self, event, ...)
	if( event == "PLAYER_LOGIN" ) then
		HealComm:OnInitialize()
		self:UnregisterEvent("PLAYER_LOGIN")
	else
		HealComm[event](HealComm, ...)
	end
end)
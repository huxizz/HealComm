local libCHC = LibStub("LibClassicHealComm-1.0", true)

OVERHEALPERCENT = 20

HealComm = select(2, ...)
HealComm.version = 2001

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
	local frame = getglobal(self:GetParent():GetName().."HealthBar")
	if not frame.incheal then
		frame.incHeal = CreateFrame("StatusBar", self:GetName().."HealthBarIncHeal" , frame)
		frame.incHeal:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
		frame.incHeal:SetMinMaxValues(0, 1)
		frame.incHeal:SetValue(1)
		frame.incHeal:SetStatusBarColor(0, 1, 0, 0.6)
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
	if not self.healthBar.incHeal then return end
	HealComm:UpdateFrame(self.healthBar, self.displayedUnit, currentHeals[UnitGUID(self.displayedUnit)] or 0)
end

local function CompactUnitFrame_UpdateMaxHealthHook(self)
	if not self.healthBar.incHeal then return end
	HealComm:UpdateFrame(self.healthBar, self.displayedUnit, currentHeals[UnitGUID(self.displayedUnit)] or 0)
end

local function CompactUnitFrame_SetUnitHook(self, unit)
	if not self.healthBar.incHeal then
		self.healthBar.incHeal = CreateFrame("StatusBar", self:GetName().."HealthBarIncHeal" , self)
		self.healthBar.incHeal:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
		self.healthBar.incHeal:SetMinMaxValues(0, 1)
		self.healthBar.incHeal:SetValue(1)
		self.healthBar.incHeal:SetStatusBarColor(0, 1, 0, 0.6)
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
		v.bar.incHeal = CreateFrame("StatusBar", "IncHealBar"..unit, v.frame)
		v.bar.incHeal:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
		v.bar.incHeal:SetMinMaxValues(0, 1)
		v.bar.incHeal:SetValue(1)
		v.bar.incHeal:SetStatusBarColor(0, 1, 0, 0.6)
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
	self:UpdateFrame(frames[petunit].bar, petunit, currentHeals[UnitGUID("pet")] or 0)
end

function HealComm:PLAYER_TARGET_CHANGED()
	self:UpdateFrame(frames["target"].bar, "target", currentHeals[UnitGUID("target")] or 0)
end

function HealComm:PLAYER_ROLES_ASSIGNED() --GROUP_ROSTER_UPDATE()
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
	end
	if UnitInRaid("player") then
		local frame, unitframe
		for k=1, NUM_RAID_PULLOUT_FRAMES do
			frame = getglobal("RaidPullout"..k)
			for z=1, frame.numPulloutButtons do
				unitframe = getglobal(frame:GetName().."Button"..z)
				if unitframe.unit and UnitExists(unitframe.unit) then
					self:UpdateFrame(getglobal(unitframe:GetName().."HealthBar"), unitframe.unit, currentHeals[UnitGUID(unitframe.unit)] or 0)
				end
			end
		end
		unitframe = _G["CompactRaidFrame1"]
		local num = 1
		while unitframe do
			if unitframe.displayedUnit and UnitExists(unitframe.displayedUnit) then
				self:UpdateFrame(unitframe.healthBar, unitframe.displayedUnit, currentHeals[UnitGUID(unitframe.displayedUnit)] or 0)
			end
			num = num + 1
			unitframe = _G["CompactRaidFrame"..num]
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
	local amount, targetGUID
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
		if UnitInRaid("player") then
			local frame, unitframe
			for k=1, NUM_RAID_PULLOUT_FRAMES do
				frame = getglobal("RaidPullout"..k)
				for z=1, frame.numPulloutButtons do
					unitframe = getglobal(frame:GetName().."Button"..z)
					if unitframe.unit and UnitExists(unitframe.unit) and UnitGUID(unitframe.unit) == targetGUID then
						self:UpdateFrame(getglobal(unitframe:GetName().."HealthBar"), unitframe.unit, amount)
					end
				end
			end
			unitframe = _G["CompactRaidFrame1"]
			local num = 1
			while unitframe do
				if unitframe.displayedUnit and UnitExists(unitframe.displayedUnit) and UnitGUID(unitframe.displayedUnit) == targetGUID then
					self:UpdateFrame(unitframe.healthBar, unitframe.displayedUnit, amount)
				end
				num = num + 1
				unitframe = _G["CompactRaidFrame"..num]
			end
			for i=1, 8 do
				local grpHeader = "CompactRaidGroup"..i
				if _G[grpHeader] then
					for k=1, 5 do
						unitframe = _G[grpHeader.."Member"..k]
						if unitframe and unitframe.displayedUnit and UnitExists(unitframe.displayedUnit) and UnitGUID(unitframe.displayedUnit) == targetGUID then
							self:UpdateFrame(unitframe.healthBar, unitframe.displayedUnit, currentHeals[UnitGUID(unitframe.displayedUnit)] or 0)
							return
						end
					end
				end
			end
		end
	end
end

function HealComm:UpdateFrame(frame, unit, amount)
	local health, maxHealth = UnitHealth(unit), UnitHealthMax(unit)
	if( amount > 0 and (health < maxHealth or OVERHEALPERCENT > 0 )) and frame:IsVisible() then
		frame.incHeal:Show()
		local healthWidth = frame:GetWidth() * (health / maxHealth)
		local incWidth = frame:GetWidth() * (amount / maxHealth)
		if (healthWidth + incWidth) > (frame:GetWidth() * (1+(OVERHEALPERCENT/100)) ) then
			incWidth = frame:GetWidth() * (1+(OVERHEALPERCENT/100)) - healthWidth
		end
		frame.incHeal:SetWidth(incWidth)
		frame.incHeal:SetHeight(frame:GetHeight())
		frame.incHeal:ClearAllPoints()
		frame.incHeal:SetPoint("TOPLEFT", frame, "TOPLEFT", healthWidth, 0)
	else
		frame.incHeal:Hide()
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
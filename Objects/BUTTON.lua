--Neuron, a World of Warcraft® user interface addon.

--This file is part of Neuron.
--
--Neuron is free software: you can redistribute it and/or modify
--it under the terms of the GNU General Public License as published by
--the Free Software Foundation, either version 3 of the License, or
--(at your option) any later version.
--
--Neuron is distributed in the hope that it will be useful,
--but WITHOUT ANY WARRANTY; without even the implied warranty of
--MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
--GNU General Public License for more details.
--
--You should have received a copy of the GNU General Public License
--along with this add-on.  If not, see <https://www.gnu.org/licenses/>.
--
--Copyright for portions of Neuron are held by Connor Chenoweth,
--a.k.a Maul, 2014 as part of his original project, Ion. All other
--copyrights for Neuron are held by Britt Yazel, 2017-2019.

---@class BUTTON : CheckButton @define BUTTON as inheriting from CheckButton
local BUTTON = setmetatable({}, {__index = CreateFrame("CheckButton")}) --this is the metatable for our button object
Neuron.BUTTON = BUTTON

local SKIN = LibStub("Masque", true)
local L = LibStub("AceLocale-3.0"):GetLocale("Neuron")

LibStub("AceBucket-3.0"):Embed(BUTTON)
LibStub("AceEvent-3.0"):Embed(BUTTON)
LibStub("AceTimer-3.0"):Embed(BUTTON)
LibStub("AceHook-3.0"):Embed(BUTTON)


---Constructor: Create a new Neuron BUTTON object (this is the base object for all Neuron button types)
---@param bar BAR @Bar Object this button will be a child of
---@param buttonID number @Button ID that this button will be assigned
---@param baseObj BUTTON @Base object class for this specific button
---@param barClass string @Class type for the bar the button will be on
---@param objType string @Type of object this button will be
---@param template string @The template name that this frame will derive from
---@return BUTTON @ A newly created BUTTON object
function BUTTON.new(bar, buttonID,baseObj, barClass, objType, template)
	local newButton
	local newButtonName = bar:GetName().."_"..objType..buttonID

	if _G[newButtonName] then --try to reuse a current frame if it exists instead of making a new one
		newButton = _G[newButtonName]
	else
		newButton = CreateFrame("CheckButton", newButtonName, UIParent, template) --create the new button frame using the desired parameters
		setmetatable(newButton, {__index = baseObj})
	end

	----------------------
	--returns a table of the names of all the child objects for a given frame
	local objects = Neuron:GetParentKeys(newButton)
	--populates the button with all the Icon,Shine,Cooldown frame references
	for k,v in pairs(objects) do
		local name = (v):gsub(newButton:GetName(), "")
		newButton[name:lower()] = _G[v]
	end
	-----------------------

	--crosslink the bar and button for easy refrencing
	bar.buttons[buttonID] = newButton
	newButton.bar = bar

	newButton.class = barClass
	newButton.id = buttonID
	newButton.objType = objType:upper()


	if not bar.DB.buttons[buttonID] then --if the database for a bar doesn't exist (because it's a new bar) make a new table
		bar.DB.buttons[buttonID] = {}
	end
	newButton.DB = bar.DB.buttons[buttonID] --set our button database table as the DB for our object

	--this is a hack to add some unique information to an object so it doesn't get wiped from the database
	if newButton.DB.config then
		newButton.DB.config.date = date("%m/%d/%y %H:%M:%S")
	end

	return newButton
end

-------------------------------------------------
-----Base Methods that all buttons have----------
---These will often be overwritten per bar type--
------------------------------------------------


function BUTTON:ChangeObject(object)

	if not Neuron.CurrentObject then
		Neuron.CurrentObject = object
	end

	local newObj, newEditor = false, false

	if (Neuron.enteredWorld) then

		if (object and object ~= Neuron.CurrentObject) then

			if (Neuron.CurrentObject and Neuron.CurrentObject.editor.editType ~= object.editor.editType) then
				newEditor = true
			end

			if (Neuron.CurrentObject and Neuron.CurrentObject.bar ~= object.bar) then

				local bar = Neuron.CurrentObject.bar

				if (bar.handler:GetAttribute("assertstate")) then
					bar.handler:SetAttribute("state-"..bar.handler:GetAttribute("assertstate"), bar.handler:GetAttribute("activestate") or "homestate")
				end

				object.bar.handler:SetAttribute("fauxstate", bar.handler:GetAttribute("activestate"))

			end

			Neuron.CurrentObject = object

			object.editor.select:Show()

			object.selected = true
			object.action = nil

			newObj = true
		end

		if (not object) then
			Neuron.CurrentObject = nil
		end

		for k,v in pairs(Neuron.EDITIndex) do
			if (not object or v ~= object.editor) then
				v.select:Hide()
			end
		end
	end

	return newObj, newEditor
end


function BUTTON:SetCooldownTimer(start, duration, enable, showCountdownTimer, modrate, color1, color2, showCountdownAlpha, charges, maxCharges)

	if not self.isShown then --if the button isn't shown, don't do set any cooldowns
		return
	end

	if start and start > 0 and duration > 0 and enable > 0 then

		if duration > 2 then --sets non GCD cooldowns
			if charges and charges > 0 and maxCharges > 1 then
				CooldownFrame_Set(self.iconframechargecooldown, start, duration, enable, true, modrate) --set clock style cooldown animation. Show Draw Edge.
			else
				CooldownFrame_Set(self.iconframecooldown, start, duration, enable, true, modrate) --set clock style cooldown animation for ability cooldown. Show Draw Edge.
			end
		else --sets GCD cooldowns
			CooldownFrame_Set(self.iconframecooldown, start, duration, enable, false, modrate) --don't show the Draw Edge for the GCD
		end

		-- Clear the charge cooldown frame if it is still going from a different ability in a different state (i.e. frenzied regen in the same spot as Swiftmend)
		if not charges or charges == maxCharges or maxCharges == 1 then --if ability does not support charges then clear the charge cooldown frame
			CooldownFrame_Clear(self.iconframechargecooldown)
		end

		--this is only for abilities that have CD's >4 sec. Any less than that and we don't want to track the CD with text or alpha, just with the standard animation
		if (duration >= Neuron.TIMERLIMIT) then --if spells have a cooldown less than 4sec then don't show a full cooldown

			if (showCountdownTimer or showCountdownAlpha) then --only set a timer if we explicitely want to (this saves CPU for a lot of people)

				--set a local variable to the boolean state of either Timer or the Alpha
				self.iconframecooldown.showCountdownTimer = showCountdownTimer
				self.iconframecooldown.showCountdownAlpha = showCountdownAlpha


				self.iconframecooldown.charges = charges or 0 --used to know if we should set alpha on the button (if cdAlpha is enabled) immediately, or if we need to wait for charges to run out

				--clear old timer before starting a new one
				if self:TimeLeft(self.iconframecooldown.cooldownTimer) ~= 0 then
					self:CancelTimer(self.iconframecooldown.cooldownTimer)
				end

				--Get the remaining time left so when we re-call the timer when switching back to a state it has the correct time left instead of the full time
				local timeleft = duration-(GetTime()-start)

				--safety check in case some timeleft value comes back ridiculously long. This happened once after a weird game glitch, it came back as like 42000000. We should cap it at 1 day max (even that's overkill)
				if timeleft > 86400 then
					timeleft = 86400
				end

				--set timer that is both our cooldown counter, but also the cancels the repeating updating timer at the end
				self.iconframecooldown.cooldownTimer = self:ScheduleTimer(function() self:CancelTimer(self.iconframecooldown.cooldownUpdateTimer) end, timeleft + 1) --add 1 to the length of the timer to keep it going for 1 second once the spell cd is over (to fully finish the animations/alpha transition)


				--clear old timer before starting a new one
				if self:TimeLeft(self.iconframecooldown.cooldownUpdateTimer) ~= 0 then
					self:CancelTimer(self.iconframecooldown.cooldownUpdateTimer)
				end

				--schedule a repeating timer that is physically keeping track of the countdown and switching the alpha and count text
				self.iconframecooldown.cooldownUpdateTimer = self:ScheduleRepeatingTimer("CooldownCounterUpdate", 0.20)
				self.iconframecooldown.normalcolor = color1
				self.iconframecooldown.expirecolor = color2
			else
				self.iconframecooldown.showCountdownTimer = false
				self.iconframecooldown.showCountdownAlpha = false
			end

		else
			--Cancel Timers as they're unnecessary
			self:CancelTimer(self.iconframecooldown.cooldownUpdateTimer)
			self.iconframecooldown.timer:SetText("")

			if self.data.alpha then
				self:SetAlpha(self.data.alpha) --try to restore the original alpha
			else
				self:SetAlpha(1)
			end

			self.iconframecooldown.showCountdownTimer = false
			self.iconframecooldown.showCountdownAlpha = false
		end
	else
		--cleanup so on state changes the cooldowns don't persist
		self:CancelTimer(self.iconframecooldown.cooldownUpdateTimer)
		self.iconframecooldown.timer:SetText("")

		if self.data.alpha then
			self:SetAlpha(self.data.alpha) --try to restore the original alpha
		else
			self:SetAlpha(1)
		end

		self.iconframecooldown.showCountdownTimer = false
		self.iconframecooldown.showCountdownAlpha = false

		--clear previous sweeping cooldown animations
		CooldownFrame_Clear(self.iconframecooldown) --clear the cooldown frame
		if not charges or charges == maxCharges or maxCharges == 1 then --if ability does not support charges then clear the charge cooldown frame
			CooldownFrame_Clear(self.iconframechargecooldown)
		end
	end

	--this is important for items like the ExtraActionButton who use Alpha to show and hide itself (to avoid in-combat restrictions). Without it the button would stay visible
	self:SetObjectVisibility()
end


---this function is called by a repeating timer set in SetCooldownTimer every 0.2sec, which is automatically is set to terminate 1sec after the cooldown timer ends
---this function's job is to overlay the countdown text on a button and set the button's cooldown alpha
function BUTTON:CooldownCounterUpdate()

	local coolDown, formatted, size

	local normalcolor = self.iconframecooldown.normalcolor
	local expirecolor = self.iconframecooldown.expirecolor

	coolDown = self:TimeLeft(self.iconframecooldown.cooldownTimer) - 1 --subtract 1 from the timer because we added 1 in SetCooldownTimer to keep the timer runing for 1 extra second after the spell

	if self.iconframecooldown.showCountdownTimer then --check if flag is set, otherwise skip

		if (coolDown < 1) then
			if (coolDown <= 0) then
				self.iconframecooldown.timer:SetText("")
				self.iconframecooldown.expirecolor = nil
				self.iconframecooldown.cdsize = nil

			elseif (coolDown > 0) then
				if (self.iconframecooldown.alphafade) then
					self.iconframecooldown:SetAlpha(coolDown)
				end
			end

		else

			if (coolDown >= 86400) then --append a "d" if the timer is longer than 1 day
				formatted = string.format( "%.0f", coolDown/86400)
				formatted = formatted.."d"
				size = self:GetWidth()*0.3
				self.iconframecooldown.timer:SetTextColor(normalcolor[1], normalcolor[2], normalcolor[3])

			elseif (coolDown >= 3600) then --append a "h" if the timer is longer than 1 hour
				formatted = string.format( "%.0f",coolDown/3600)
				formatted = formatted.."h"
				size = self:GetWidth()*0.3
				self.iconframecooldown.timer:SetTextColor(normalcolor[1], normalcolor[2], normalcolor[3])

			elseif (coolDown >= 60) then --append a "m" if the timer is longer than 1 min
				formatted = string.format( "%.0f",coolDown/60)
				formatted = formatted.."m"
				size = self:GetWidth()*0.3
				self.iconframecooldown.timer:SetTextColor(normalcolor[1], normalcolor[2], normalcolor[3])

			elseif (coolDown >=6) then --this is the 'normal' countdown text state
				formatted = string.format( "%.0f",coolDown)
				size = self:GetWidth()*0.45
				self.iconframecooldown.timer:SetTextColor(normalcolor[1], normalcolor[2], normalcolor[3])

			elseif (coolDown < 6) then --this is the countdown text state but with the text larger and set to the expire color (usually red)
				formatted = string.format( "%.0f",coolDown)
				size = self:GetWidth()*0.6
				if (expirecolor) then
					self.iconframecooldown.timer:SetTextColor(expirecolor[1], expirecolor[2], expirecolor[3])
					expirecolor = nil
				end

			end

			if (not self.iconframecooldown.cdsize or self.iconframecooldown.cdsize ~= size) then
				self.iconframecooldown.timer:SetFont(STANDARD_TEXT_FONT, size, "OUTLINE")
				self.iconframecooldown.cdsize = size
			end

			self.iconframecooldown.timer:SetText(formatted)

		end

	end


	if self.iconframecooldown.showCountdownAlpha and self.iconframecooldown.charges == 0 then --check if flag is set and if charges are nil or zero, otherwise skip

		if coolDown > 0 then
			self:SetAlpha(self.cdAlpha)
		else
			if self.data.alpha then
				self:SetAlpha(self.data.alpha) --try to restore the original alpha
			else
				self:SetAlpha(1)
			end
		end
	else
		if self.data.alpha then
			self:SetAlpha(self.data.alpha) --try to restore the original alpha
		else
			self:SetAlpha(1)
		end
	end

end


function BUTTON:SetData(bar)
	if (bar) then

		self.bar = bar

		self.barLock = bar.data.barLock
		self.barLockAlt = bar.data.barLockAlt
		self.barLockCtrl = bar.data.barLockCtrl
		self.barLockShift = bar.data.barLockShift

		self.tooltips = bar.data.tooltips
		self.tooltipsEnhanced = bar.data.tooltipsEnhanced
		self.tooltipsCombat = bar.data.tooltipsCombat

		self.spellGlow = bar.data.spellGlow
		self.spellGlowDef = bar.data.spellGlowDef
		self.spellGlowAlt = bar.data.spellGlowAlt

		self.bindText = bar.data.bindText
		self.macroText = bar.data.macroText
		self.countText = bar.data.countText

		self.cdText = bar.data.cdText

		if (bar.data.cdAlpha) then
			self.cdAlpha = 0.2
		else
			self.cdAlpha = 1
		end

		self.auraText = bar.data.auraText
		self.auraInd = bar.data.auraInd

		self.rangeInd = bar.data.rangeInd

		self.upClicks = bar.data.upClicks
		self.downClicks = bar.data.downClicks

		self.showGrid = bar.data.showGrid
		self.multiSpec = bar.data.multiSpec

		self.bindColor = bar.data.bindColor
		self.macroColor = bar.data.macroColor
		self.countColor = bar.data.countColor

		self.macroname:SetText(self.data.macro_Name) --custom macro's weren't showing the name

		if (not self.cdcolor1) then
			self.cdcolor1 = { (";"):split(bar.data.cdcolor1) }
		else
			self.cdcolor1[1], self.cdcolor1[2], self.cdcolor1[3], self.cdcolor1[4] = (";"):split(bar.data.cdcolor1)
		end

		if (not self.cdcolor2) then
			self.cdcolor2 = { (";"):split(bar.data.cdcolor2) }
		else
			self.cdcolor2[1], self.cdcolor2[2], self.cdcolor2[3], self.cdcolor2[4] = (";"):split(bar.data.cdcolor2)
		end

		if (not self.auracolor1) then
			self.auracolor1 = { (";"):split(bar.data.auracolor1) }
		else
			self.auracolor1[1], self.auracolor1[2], self.auracolor1[3], self.auracolor1[4] = (";"):split(bar.data.auracolor1)
		end

		if (not self.auracolor2) then
			self.auracolor2 = { (";"):split(bar.data.auracolor2) }
		else
			self.auracolor2[1], self.auracolor2[2], self.auracolor2[3], self.auracolor2[4] = (";"):split(bar.data.auracolor2)
		end

		if (not self.buffcolor) then
			self.buffcolor = { (";"):split(bar.data.buffcolor) }
		else
			self.buffcolor[1], self.buffcolor[2], self.buffcolor[3], self.buffcolor[4] = (";"):split(bar.data.buffcolor)
		end

		if (not self.debuffcolor) then
			self.debuffcolor = { (";"):split(bar.data.debuffcolor) }
		else
			self.debuffcolor[1], self.debuffcolor[2], self.debuffcolor[3], self.debuffcolor[4] = (";"):split(bar.data.debuffcolor)
		end

		if (not self.rangecolor) then
			self.rangecolor = { (";"):split(bar.data.rangecolor) }
		else
			self.rangecolor[1], self.rangecolor[2], self.rangecolor[3], self.rangecolor[4] = (";"):split(bar.data.rangecolor)
		end

		self:SetFrameStrata(bar.data.objectStrata)

		self:SetScale(bar.data.scale)
	end

	if (self.bindText) then
		self.hotkey:Show()
		if (self.bindColor) then
			self.hotkey:SetTextColor((";"):split(self.bindColor))
		end
	else
		self.hotkey:Hide()
	end

	if (self.macroText) then
		self.macroname:Show()
		if (self.macroColor) then
			self.macroname:SetTextColor((";"):split(self.macroColor))
		end
	else
		self.macroname:Hide()
	end

	if (self.countText) then
		self.count:Show()
		if (self.countColor) then
			self.count:SetTextColor((";"):split(self.countColor))
		end
	else
		self.count:Hide()
	end

	local down, up = "", ""

	if (self.upClicks) then up = up.."AnyUp" end
	if (self.downClicks) then down = down.."AnyDown" end

	self:RegisterForClicks(down, up)
	self:RegisterForDrag("LeftButton", "RightButton")

	if (not self.equipcolor) then
		self.equipcolor = { 0.1, 1, 0.1, 1 }
	else
		self.equipcolor[1], self.equipcolor[2], self.equipcolor[3], self.equipcolor[4] = 0.1, 1, 0.1, 1
	end

	if (not self.manacolor) then
		self.manacolor = { 0.5, 0.5, 1.0, 1 }
	else
		self.manacolor[1], self.manacolor[2], self.manacolor[3], self.manacolor[4] = 0.5, 0.5, 1.0, 1
	end

	self:GetSkinned()

	self:UpdateTimers()
end


--TODO: This should be consolodated as each child has a VERY similar function
function BUTTON:LoadData()
	self.config = self.DB.config
	self.keys = self.DB.keys
	self.data = self.DB.data
end


function BUTTON:SetObjectVisibility()

	if self.bar.class ~= "ActionBar" then --TODO: I'd like to not have separate logic for ActionBars in the future
		if self.isShown then
			if self.data.alpha then
				self:SetAlpha(self.data.alpha) --try to restore alpha value instead of default to 1
			else
				self:SetAlpha(1)
			end
		else
			self:SetAlpha(0)
		end
	else

		if InCombatLockdown() then
			return
		end

		self:SetAttribute("showGrid", self.showGrid) --this is important because in our state switching code, we can't querry self.showGrid directly
		self:SetAttribute("isshown", show)

		if self.isShown then
			self:Show()
		else
			self:Hide()
		end

	end
end



function BUTTON:SetDefaults(defaults)
	if not defaults then
		return
	end

	if defaults.config then
		for k, v in pairs(defaults.config) do
			self.DB.config[k] = v
		end
	end

	if defaults.keys then
		for k, v in pairs(defaults.keys) do
			self.DB.keys[k] = v
		end
	end


end

function BUTTON:SetType()
	--empty--
end

function BUTTON:SetSkinned(flyout)

	if (SKIN) then
		local bar = self.bar

		if (bar) then
			local btnData = {
				Normal = self.normaltexture,
				Icon = self.iconframeicon,
				HotKey = self.hotkey,
				Count = self.count,
				Name = self.name,
				Border = self.border,
				Shine = self.shine,
				Cooldown = self.iconframecooldown,
				AutoCastable = self.autocastable,
				Checked = self.checkedtexture,
				Pushed = self:GetPushedTexture(),
				Disabled = self:GetDisabledTexture(),
				Highlight = self.highlighttexture,
			}

			if (flyout) then
				SKIN:Group("Neuron", self.anchor.bar.data.name):AddButton(self, btnData, "Action")
			else
				SKIN:Group("Neuron", bar.data.name):AddButton(self, btnData, "Action")
			end

			self.skinned = true
		end
	end
end

function BUTTON:GetSkinned()
	if (self.__MSQ_NormalTexture) then
		local Skin = self.__MSQ_NormalSkin

		if (Skin) then
			self.hasAction = Skin.Texture or false
			self.noAction = Skin.EmptyTexture or false

			if (self.__MSQ_Shape) then
				self.shape = self.__MSQ_Shape:lower()
			else
				self.shape = "square"
			end
		else
			self.hasAction = false
			self.noAction = false
			self.shape = "square"
		end

		return true
	else
		self.hasAction = "Interface\\Buttons\\UI-Quickslot2"
		self.noAction = "Interface\\Buttons\\UI-Quickslot"

		return false
	end
end


function BUTTON:HasAction()
	local hasAction = self.data.macro_Text

	if (self.actionID) then
		if (self.actionID == 0) then
			return true
		else
			return HasAction(self.actionID)
		end

	elseif (hasAction and #hasAction>0) then
		return true
	else
		return false
	end
end


---Updates the buttons "count", i.e. the spell charges
function BUTTON:UpdateSpellCount(spell)
	local charges, maxCharges = GetSpellCharges(spell)

	local count = GetSpellCount(spell)

	if (maxCharges and maxCharges > 1) then
		self.count:SetText(charges)
	elseif count and count > 0 then
		self.count:SetText(count)
	else
		self.count:SetText("")
	end
end


---Updates the buttons "count", i.e. the item stack size
function BUTTON:UpdateItemCount(item)

	local count = GetItemCount(item,nil,true)

	if (count and count > 1) then
		self.count:SetText(count)
	else
		self.count:SetText("")
	end
end


function BUTTON:UpdateCooldown()
	local spell, item, show = self.macrospell, self.macroitem, self.macroshow

	if (self.actionID) then
		self:ACTION_SetCooldown(self.actionID)
	elseif (show and #show>0) then
		if (NeuronItemCache[show]) then
			self:SetItemCooldown(show)
		else
			self:SetSpellCooldown(show)
		end

	elseif (spell and #spell>0) then
		self:SetSpellCooldown(spell)
	elseif (item and #item>0) then
		self:SetItemCooldown(item)
	else
		--this is super important for removing CD's from empty buttons, like when switching states. You don't want the CD from one state to show on a different state.
		self:SetCooldownTimer()
	end
end


function BUTTON:SetSpellCooldown(spell)

	if type(spell) == "string" then
		spell = (spell):lower()
	end

	local start, duration, enable, modrate = GetSpellCooldown(spell)
	local charges, maxCharges, chStart, chDuration, chargemodrate = GetSpellCharges(spell)

	if (charges and maxCharges and maxCharges > 0 and charges < maxCharges) then
		self:SetCooldownTimer(chStart, chDuration, enable, self.cdText, chargemodrate, self.cdcolor1, self.cdcolor2, self.cdAlpha, charges, maxCharges) --only evoke charge cooldown (outer border) if charges are present and less than maxCharges (this is the case with the GCD)
	else
		self:SetCooldownTimer(start, duration, enable, self.cdText, modrate, self.cdcolor1, self.cdcolor2, self.cdAlpha, charges, maxCharges) --call standard cooldown, handles both abilty cooldowns and GCD
	end
end



function BUTTON:SetItemCooldown(item)

	local id = NeuronItemCache[item]

	if (id) then

		local start, duration, enable, modrate = GetItemCooldown(id)

		self:SetCooldownTimer(start, duration, enable, self.cdText, modrate, self.cdcolor1, self.cdcolor2, self.cdAlpha)
	end
end

function BUTTON:ACTION_SetCooldown(action)

	local actionID = tonumber(action)

	if (actionID) then

		if (HasAction(actionID)) then

			local start, duration, enable, modrate = GetActionCooldown(actionID)

			self:SetCooldownTimer(start, duration, enable, self.cdText, modrate, self.cdcolor1, self.cdcolor2, self.cdAlpha)
		end
	end
end


function BUTTON:UpdateAuraWatch(unit, spell)

	local uaw_auraType, uaw_duration, uaw_timeLeft, uaw_count, auraColor

	if (spell and (unit == self.unit or unit == "player")) then
		spell = spell:gsub("%s*%(.+%)", ""):lower()

		if (Neuron.unitAuras[unit][spell]) then
			uaw_auraType, uaw_duration, uaw_timeLeft, uaw_count = (":"):split(Neuron.unitAuras[unit][spell])

			uaw_duration = tonumber(uaw_duration)
			uaw_timeLeft = tonumber(uaw_timeLeft)

			--if (self.auraText or self.auraInd) then
			if (self.auraInd) then

				--self.iconframecooldown.showAuraCountdown = self.auraText
				self.iconframecooldown.showAuraBorder = self.auraInd

				self.iconframecooldown.auraType = uaw_auraType
				self.iconframecooldown.unit = unit


				--clear old timer before starting a new one
				if self:TimeLeft(self.iconframecooldown.auraTimer) ~= 0 then
					self:CancelTimer(self.iconframecooldown.auraTimer)
				end

				local timeLeft = uaw_timeLeft - GetTime()

				self.iconframecooldown.auraTimer = self:ScheduleTimer(function() self:CancelTimer(self.iconframecooldown.auraUpdateTimer) end, timeLeft + 1)


				--clear old timer before starting a new one
				if self:TimeLeft(self.iconframecooldown.auraUpdateTimer) ~= 0 then
					self:CancelTimer(self.iconframecooldown.auraUpdateTimer)
				end

				self.iconframecooldown.auraUpdateTimer = self:ScheduleRepeatingTimer("AuraCounterUpdate", 0.20)

			else
				--self.iconframecooldown.showAuraCountdown = false
				self.iconframecooldown.showAuraBorder = false
			end

			self.auraWatchUnit = unit

		elseif (self.auraWatchUnit == unit) then

			self:CancelTimer(self.iconframecooldown.auraUpdateTimer)
			--self.iconframecooldown.timer:SetText("")
			self.border:Hide()

			--self.iconframecooldown.showAuraCountdown = false
			self.iconframecooldown.showAuraBorder = false

			self.auraWatchUnit = nil
		end
	end
end


function BUTTON:AuraCounterUpdate()

	local coolDown, formatted, size

	coolDown = self:TimeLeft(self.iconframecooldown.auraTimer) - 1

	--[[if self.iconframecooldown.showAuraCountdown and not self.iconframecooldown.showCountdownTimer then

		if (coolDown < 1) then
			self.iconframecooldown.timer:SetText("")
		else

			formatted = string.format( "%.0f",coolDown)

			size = self:GetWidth()*0.45

			if (self.iconframecooldown.auraType == "buff") then
				self.border:SetVertexColor(self.auracolor1[1], self.auracolor1[2], self.auracolor1[3], 1.0)
			elseif (self.iconframecooldown.auraType == "debuff" and self.iconframecooldown.unit == "target") then
				self.border:SetVertexColor(self.auracolor2[1], self.auracolor2[2], self.auracolor2[3], 1.0)
			end

			self.iconframecooldown.timer:SetFont(STANDARD_TEXT_FONT, size, "OUTLINE")

			self.iconframecooldown.timer:SetText(formatted)

		end

	end]]


	if self.iconframecooldown.showAuraBorder then
		if coolDown > 0 then
			if (self.iconframecooldown.auraType == "buff") then
				self.border:SetVertexColor(self.buffcolor[1], self.buffcolor[2], self.buffcolor[3], 1.0)
			elseif (self.iconframecooldown.auraType == "debuff" and self.iconframecooldown.unit == "target") then
				self.border:SetVertexColor(self.debuffcolor[1], self.debuffcolor[2], self.debuffcolor[3], 1.0)
			end

			self.border:Show()

		else
			self.border:Hide()
		end
	else
		self.border:Hide()
	end

end


-----------------------------------------------------
--------------General Update Functions---------------
-----------------------------------------------------

function BUTTON:UpdateAll()
	self:UpdateData()
	self:UpdateButton()
	self:UpdateIcon()
	self:UpdateState()
	self:UpdateTimers()
	self:UpdateNormalTexture()
end


function BUTTON:UpdateData()
	-- empty --
end

function BUTTON:UpdateButton()
	-- empty --
end

function BUTTON:UpdateIcon()
	-- empty --
end

function BUTTON:UpdateState()
	-- empty --
end


function BUTTON:UpdateTimers()
	self:UpdateCooldown()
	for k in pairs(Neuron.unitAuras) do
		self:UpdateAuraWatch(k, self.macrospell)
	end
end

function BUTTON:UpdateNormalTexture()
	if (not self:GetSkinned()) then
		if (self:HasAction()) then
			self:SetNormalTexture(self.hasAction or "")
			self:GetNormalTexture():SetVertexColor(1,1,1,1)
		else
			self:SetNormalTexture(self.noAction or "")
			self:GetNormalTexture():SetVertexColor(1,1,1,0.5)
		end
	end
end

----------------------------------------------------------
----------------------------------------------------------
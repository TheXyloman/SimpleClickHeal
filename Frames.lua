local ADDON_NAME = ...
local LibStub = LibStub
local SCH = LibStub("AceAddon-3.0"):GetAddon(ADDON_NAME)

local TEMPLATE_BACKDROP = BackdropTemplateMixin and "BackdropTemplate" or nil

-- -----------------------
-- Classic helpers
-- -----------------------
local function inRaidClassic()
  if IsInRaid then return IsInRaid() end
  if GetNumRaidMembers then return GetNumRaidMembers() > 0 end
  return false
end

local function partySizeClassic()
  if GetNumPartyMembers then return GetNumPartyMembers() end -- excludes player
  if GetNumSubgroupMembers then return GetNumSubgroupMembers() end
  return 0
end

local function raidSizeClassic()
  if GetNumRaidMembers then return GetNumRaidMembers() end
  if GetNumGroupMembers then return GetNumGroupMembers() end
  return 0
end

local function GetClassColor(unit)
  if not unit or not UnitExists(unit) then return nil end
  local _, classFile = UnitClass(unit)
  if not classFile then return nil end
  local colors = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
  local c = colors and colors[classFile]
  if not c then return nil end
  return c.r, c.g, c.b
end

-- -----------------------
-- Default Resurrection spell by class
-- -----------------------
function SCH:GetDefaultResSpell()
  local _, classFile = UnitClass("player")
  if classFile == "PRIEST" then return "Resurrection" end
  if classFile == "PALADIN" then return "Redemption" end
  if classFile == "SHAMAN" then return "Ancestral Spirit" end
  if classFile == "DRUID" then return "Rebirth" end
  return nil
end

-- If you later add a Config option, store it in self.db.profile.resSpell.
function SCH:GetResSpell()
  local db = self.db and self.db.profile
  local s = db and db.resSpell
  if s and s ~= "" then return s end
  return self:GetDefaultResSpell()
end

-- -----------------------
-- Demo mode
-- -----------------------
local DEMO_CLASSES = {
  "WARRIOR","MAGE","PRIEST","ROGUE","DRUID","HUNTER","WARLOCK","PALADIN","SHAMAN"
}

local function DemoClassColorByFile(classFile)
  local colors = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
  local c = colors and colors[classFile]
  if not c then return 0.3, 0.8, 0.3 end
  return c.r, c.g, c.b
end

function SCH:IsDemoModeActive()
  return self.db and self.db.profile and self.db.profile.demo and self.db.profile.demo.enabled
end

function SCH:EnsureDemoData()
  if self._demo and self._demo.units then return end
  self._demo = self._demo or {}
  self._demo.units = {}

  for i = 1, 40 do
    local classFile = DEMO_CLASSES[((i - 1) % #DEMO_CLASSES) + 1]
    local name = ("Demo%02d"):format(i)

    local maxHP = 10000
    local pct = 0.35 + ((i % 13) / 20)
    local curHP = math.floor(maxHP * pct)

    self._demo.units[i] = {
      name = name,
      classFile = classFile,
      maxHP = maxHP,
      curHP = curHP,
      connected = true,
      dead = false,
    }
  end
end

function SCH:StartDemoTicker()
  if self._demoTicker then return end
  if not (self.db and self.db.profile and self.db.profile.demo and self.db.profile.demo.animate) then return end

  self._demoTicker = CreateFrame("Frame", nil, UIParent)
  local elapsed = 0
  self._demoTicker:SetScript("OnUpdate", function(_, dt)
    if not SCH:IsDemoModeActive() then return end
    if inRaidClassic() then return end
    elapsed = elapsed + dt
    if elapsed < 0.35 then return end
    elapsed = 0
    SCH:TickDemoHealth()
  end)
end

function SCH:StopDemoTicker()
  if self._demoTicker then
    self._demoTicker:SetScript("OnUpdate", nil)
    self._demoTicker:Hide()
    self._demoTicker = nil
  end
end

function SCH:TickDemoHealth()
  if not self._demo or not self._demo.units then return end

  for i = 1, 40 do
    local u = self._demo.units[i]
    if u and u.connected and not u.dead then
      local delta = math.random(-600, 600)
      local newHP = u.curHP + delta
      if newHP < 250 then newHP = 250 end
      if newHP > u.maxHP then newHP = u.maxHP end
      u.curHP = newHP
    end
  end

  for i = 1, 40 do
    local b = self.buttons and self.buttons[i]
    if b and b._demoIndex then
      self:UpdateButtonDemo(b, b._demoIndex)
    end
  end

  for i = 1, 40 do
    local b = self.priorityButtons and self.priorityButtons[i]
    if b and b._prioDemoIndex then
      self:UpdatePriorityDemoButton(b, b._prioDemoIndex)
    end
  end
end

-- -----------------------
-- Bar opacity
-- -----------------------
function SCH:ApplyBarAlpha()
  local a = 1.0
  if self.db and self.db.profile and self.db.profile.frame then
    a = tonumber(self.db.profile.frame.barAlpha) or 1.0
  end
  if a < 0.10 then a = 0.10 end
  if a > 1.00 then a = 1.00 end

  if self.buttons then
    for i = 1, 40 do
      local btn = self.buttons[i]
      if btn and btn.bar then
        btn.bar:SetAlpha(a)
        if btn.bg then
          local bgA = math.min(1.0, a + 0.15)
          btn.bg:SetAlpha(bgA)
        end
      end
    end
  end

  if self.priorityButtons then
    for i = 1, 40 do
      local btn = self.priorityButtons[i]
      if btn and btn.bar then
        btn.bar:SetAlpha(a)
        if btn.bg then
          local bgA = math.min(1.0, a + 0.15)
          btn.bg:SetAlpha(bgA)
        end
      end
    end
  end
end

-- -----------------------
-- Range checking (Classic)
-- -----------------------
local function firstNonEmptyBinding(bindings)
  if not bindings then return nil end
  local order = { "L","R","M","SL","SR","SM" }
  for _, k in ipairs(order) do
    local s = bindings[k]
    if s and s ~= "" then
      return s
    end
  end
  return nil
end

function SCH:IsRangeEnabled()
  return self.db and self.db.profile and self.db.profile.range and self.db.profile.range.enabled
end

function SCH:GetRangeThrottle()
  local t = (self.db and self.db.profile and self.db.profile.range and self.db.profile.range.throttle) or 0.20
  if t < 0.10 then t = 0.10 end
  if t > 2.00 then t = 2.00 end
  return t
end

function SCH:GetRangeCheckSpell()
  local spell = firstNonEmptyBinding(self.db and self.db.profile and self.db.profile.bindings)
  self._rangeSpell = spell
  return spell
end

function SCH:ApplyRangeStateToButton(btn, unit)
  if not btn or not btn.bar then return end

  -- Priority overrides range
  if btn._isPriority then
    if btn._baseR then
      btn.bar:SetStatusBarColor(btn._baseR, btn._baseG, btn._baseB)
    end
    return
  end

  if not self:IsRangeEnabled() then
    if btn._baseR then
      btn.bar:SetStatusBarColor(btn._baseR, btn._baseG, btn._baseB)
    end
    return
  end

  if not unit or not UnitExists(unit) then return end
  if UnitIsDeadOrGhost(unit) then return end
  if UnitIsConnected(unit) == false then return end

  -- Not visible => different continent / outside streaming bubble => effectively out of range.
  if UnitIsVisible and (not UnitIsVisible(unit)) then
    btn.bar:SetStatusBarColor(0.35, 0.35, 0.35)
    return
  end

  local spell = self._rangeSpell or self:GetRangeCheckSpell()
  if not spell or spell == "" then return end

  local inRange = IsSpellInRange(spell, unit)
  if inRange == 0 then
    btn.bar:SetStatusBarColor(0.35, 0.35, 0.35)
  else
    if btn._baseR then
      btn.bar:SetStatusBarColor(btn._baseR, btn._baseG, btn._baseB)
    end
  end
end

function SCH:UpdateRangeTicker()
  local enable = self:IsRangeEnabled() and self.frame and self.frame:IsShown() and self.buttons
  if not enable then
    if self._rangeTicker then
      self._rangeTicker:SetScript("OnUpdate", nil)
      self._rangeTicker:Hide()
      self._rangeTicker = nil
    end
    return
  end

  if self._rangeTicker then return end

  self._rangeTicker = CreateFrame("Frame", nil, UIParent)
  local elapsed = 0
  self._rangeTicker:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + dt
    local throttle = SCH:GetRangeThrottle()
    if elapsed < throttle then return end
    elapsed = 0

    SCH:GetRangeCheckSpell()

    for i = 1, 40 do
      local b = SCH.buttons[i]
      if b and b:IsShown() and b.unit and UnitExists(b.unit) and not b._demoIndex then
        SCH:ApplyRangeStateToButton(b, b.unit)
      end
    end

    if SCH.priorityButtons then
      for i = 1, 40 do
        local b = SCH.priorityButtons[i]
        if b and b:IsShown() and b.unit and UnitExists(b.unit) then
          SCH:ApplyRangeStateToButton(b, b.unit)
        end
      end
    end
  end)
end

-- -----------------------
-- Priority system (real + demo)
-- -----------------------
local PRIORITY_GOLD_R, PRIORITY_GOLD_G, PRIORITY_GOLD_B = 1.0, 0.82, 0.0
local PRIORITY_DARKEN = 0.75

local function ensurePriorityTables(self)
  self.db.profile.priority = self.db.profile.priority or {}
  self.db.profile.priority.list = self.db.profile.priority.list or {}
  self.db.profile.priority.order = self.db.profile.priority.order or {}
  if self.db.profile.priority.showFrame == nil then
    self.db.profile.priority.showFrame = true
  end
end

local function priorityKeyForDemoIndex(i)
  return "DEMO:" .. tostring(i)
end

function SCH:IsPriorityKey(key)
  if not key then return false end
  if not (self.db and self.db.profile and self.db.profile.priority and self.db.profile.priority.list) then return false end
  return self.db.profile.priority.list[key] ~= nil
end

function SCH:TogglePriorityByKey(key, info)
  if InCombatLockdown() then
    self:Print("|cFFFF0000Cannot change Priority while in combat.|r")
    return
  end

  ensurePriorityTables(self)
  local list = self.db.profile.priority.list
  local order = self.db.profile.priority.order

  if list[key] then
    list[key] = nil
    for i = #order, 1, -1 do
      if order[i] == key then
        table.remove(order, i)
      end
    end
  else
    list[key] = info or { name = key }
    order[#order + 1] = key
  end

  self:RefreshPriorityFrame()
  self:RequestRoster()
end

function SCH:TogglePriorityForButton(btn)
  if not btn then return end

  -- Demo row
  if btn._demoIndex then
    self:EnsureDemoData()
    local u = self._demo.units[btn._demoIndex]
    if not u then return end
    local key = priorityKeyForDemoIndex(btn._demoIndex)
    self:TogglePriorityByKey(key, { name = u.name, classFile = u.classFile, demoIndex = btn._demoIndex })
    return
  end

  -- Real unit row
  local unit = btn.unit
  if not unit or not UnitExists(unit) then return end
  local guid = UnitGUID(unit)
  if not guid then return end

  local name = UnitName(unit) or "Unknown"
  local _, classFile = UnitClass(unit)
  self:TogglePriorityByKey(guid, { name = name, classFile = classFile })
end

-- IMPORTANT: do NOT SetScript("OnClick") on secure unit buttons (breaks click-cast).
function SCH:AttachPriorityToggleHooks(btn)
  if not btn or btn._schPriorityHooks then return end
  btn._schPriorityHooks = true

  btn:HookScript("PreClick", function(b, mouseButton)
    if mouseButton ~= "MiddleButton" then return end
    if not IsAltKeyDown() then return end

    SCH:TogglePriorityForButton(b)

    -- Suppress middle-click action so it doesn't also cast/target.
    if InCombatLockdown() then return end
    b._schSuppress3 = true
    b:SetAttribute("type3", "none")
    b:SetAttribute("spell3", nil)
    b:SetAttribute("macrotext3", nil)
    b:SetAttribute("shift-type3", "none")
    b:SetAttribute("shift-spell3", nil)
    b:SetAttribute("shift-macrotext3", nil)
  end)

  btn:HookScript("PostClick", function(b, mouseButton)
    if mouseButton ~= "MiddleButton" then return end
    if not b._schSuppress3 then return end
    b._schSuppress3 = nil

    if InCombatLockdown() then return end
    if SCH.ApplyBindingsToButton then
      SCH:ApplyBindingsToButton(b)
    end
  end)
end

-- -----------------------
-- Main frame + buttons
-- -----------------------
function SCH:CreateFrames()
  if self.frame then return end

  local cfg = self.db.profile.frame

  local f = CreateFrame("Frame", "SCH_MainFrame", UIParent, TEMPLATE_BACKDROP)
  self.frame = f

  f:SetScale(cfg.scale or 1.0)
  f:SetPoint(cfg.point, UIParent, cfg.relPoint, cfg.x, cfg.y)

  if f.SetBackdrop then
    f:SetBackdrop({
      bgFile = "Interface/Tooltips/UI-Tooltip-Background",
      edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 16,
      insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    f:SetBackdropColor(0, 0, 0, 0.75)
  end

  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")

  f:SetScript("OnDragStart", function(frame)
    if self.db.profile.locked then return end
    if InCombatLockdown() then return end
    frame:StartMoving()
  end)

  f:SetScript("OnDragStop", function(frame)
    frame:StopMovingOrSizing()
    local point, _, relPoint, x, y = frame:GetPoint(1)
    cfg.point, cfg.relPoint, cfg.x, cfg.y = point, relPoint, x, y
  end)

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  title:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -6)
  title:SetText("SCH")
  self.title = title

  local content = CreateFrame("Frame", nil, f)
  content:SetPoint("TOPLEFT", f, "TOPLEFT", cfg.padding, -(cfg.padding + 10))
  content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -cfg.padding, cfg.padding)
  self.content = content

  self.buttons = {}
  self.unitToButton = {}

  for i = 1, 40 do
    self.buttons[i] = self:CreateUnitButton(i)
  end

  self:CreatePriorityFrame()
  self:ApplyBarAlpha()

  self:UpdateLockState()
  self:SetFrameShown(true)
end

function SCH:UpdateLockState()
  if not self.frame then return end
  if self.db.profile.locked then
    self.title:SetText("SCH")
  else
    self.title:SetText("SCH (*)")
  end
end

function SCH:SetFrameShown(shown)
  if not self.frame then return end
  if shown then self.frame:Show() else self.frame:Hide() end
  self:UpdateRangeTicker()
end

function SCH:ToggleFrame()
  if not self.frame then return end
  self:SetFrameShown(not self.frame:IsShown())
end

function SCH:CreateUnitButton(i)
  local b = CreateFrame("Button", "SCH_UnitButton"..i, self.content, "SecureUnitButtonTemplate")
  b:RegisterForClicks("AnyUp")
  b:SetAttribute("unit", "raid"..i)
  RegisterUnitWatch(b)

  b:SetHighlightTexture("Interface/QuestFrame/UI-QuestTitleHighlight")

  local bar = CreateFrame("StatusBar", nil, b)
  bar:SetAllPoints(b)
  bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
  bar:SetMinMaxValues(0, 1)
  bar:SetValue(1)
  b.bar = bar

  local bg = bar:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints(bar)
  bg:SetTexture("Interface\\Buttons\\WHITE8X8")
  bg:SetVertexColor(0.15, 0.15, 0.15, 1)
  b.bg = bg

  bar:SetFrameLevel(b:GetFrameLevel())

  local name = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  name:SetPoint("LEFT", bar, "LEFT", 4, 0)
  name:SetJustifyH("LEFT")
  name:SetWordWrap(false)
  name:SetText("")
  name:SetTextColor(1, 1, 1)
  name:SetShadowOffset(1, -1)
  name:SetShadowColor(0, 0, 0, 0.9)
  b.nameText = name

  local hp = bar:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  hp:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
  hp:SetJustifyH("RIGHT")
  hp:SetText("")
  hp:SetTextColor(1, 1, 1)
  hp:SetShadowOffset(1, -1)
  hp:SetShadowColor(0, 0, 0, 0.9)
  b.hpText = hp

  self:AttachPriorityToggleHooks(b)

  -- TOOLTIP DISABLED
  b:SetScript("OnEnter", nil)
  b:SetScript("OnLeave", nil)

  return b
end

-- -----------------------
-- Updates
-- -----------------------
function SCH:UpdateButtonDemo(b, idx)
  self:EnsureDemoData()
  local u = self._demo.units[idx]
  if not u then return end

  b.nameText:SetText(u.name)
  b.bar:SetMinMaxValues(0, u.maxHP)
  b.bar:SetValue(u.curHP)

  if not u.connected then
    b._baseR, b._baseG, b._baseB = 0.35, 0.35, 0.35
    b._isPriority = false
    b.bar:SetStatusBarColor(0.35, 0.35, 0.35)
    b.hpText:SetText("OFF")
    return
  end

  if u.dead then
    b._baseR, b._baseG, b._baseB = 0.45, 0.0, 0.0
    b._isPriority = false
    b.bar:SetStatusBarColor(0.45, 0.0, 0.0)
    b.hpText:SetText("DEAD")
    return
  end

  local pct = u.curHP / u.maxHP
  b.hpText:SetText(("%d%%"):format(pct * 100))

  local key = priorityKeyForDemoIndex(idx)
  local isPrio = self:IsPriorityKey(key)

  if isPrio then
    local r = PRIORITY_GOLD_R * PRIORITY_DARKEN
    local g = PRIORITY_GOLD_G * PRIORITY_DARKEN
    local bb = PRIORITY_GOLD_B * PRIORITY_DARKEN
    b._isPriority = true
    b._baseR, b._baseG, b._baseB = r, g, bb
    b.bar:SetStatusBarColor(r, g, bb)
    return
  end

  local r, g, bb = DemoClassColorByFile(u.classFile)
  local DARKEN = 0.65
  r, g, bb = r * DARKEN, g * DARKEN, bb * DARKEN

  b._isPriority = false
  b._baseR, b._baseG, b._baseB = r, g, bb
  b.bar:SetStatusBarColor(r, g, bb)
end

function SCH:UpdateUnitForAnyButton(btn, unit, forcePriority)
  if not btn or not btn.bar or not unit or not UnitExists(unit) then return end

  local guid = UnitGUID(unit)
  local isPriority = forcePriority or (guid and self:IsPriorityKey(guid)) or false
  btn._isPriority = isPriority

  btn.nameText:SetText(UnitName(unit) or unit)

  local maxHP = UnitHealthMax(unit) or 0
  local curHP = UnitHealth(unit) or 0
  if maxHP < 1 then maxHP = 1 end
  if curHP < 0 then curHP = 0 end

  btn.bar:SetMinMaxValues(0, maxHP)
  btn.bar:SetValue(curHP)

  local connected = UnitIsConnected(unit)
  local dead = UnitIsDeadOrGhost(unit)

  if not connected then
    btn._baseR, btn._baseG, btn._baseB = 0.35, 0.35, 0.35
    btn.bar:SetStatusBarColor(0.35, 0.35, 0.35)
    btn.hpText:SetText("OFF")
    return
  end

  if dead then
    btn._baseR, btn._baseG, btn._baseB = 0.45, 0.0, 0.0
    btn.bar:SetStatusBarColor(0.45, 0.0, 0.0)
    btn.hpText:SetText("DEAD")
    return
  end

  local pct = curHP / maxHP
  btn.hpText:SetText(("%d%%"):format(pct * 100))

  if isPriority then
    local r = PRIORITY_GOLD_R * PRIORITY_DARKEN
    local g = PRIORITY_GOLD_G * PRIORITY_DARKEN
    local bb = PRIORITY_GOLD_B * PRIORITY_DARKEN
    btn._baseR, btn._baseG, btn._baseB = r, g, bb
    btn.bar:SetStatusBarColor(r, g, bb)
    return
  end

  local r, g, bb = GetClassColor(unit)
  if r and g and bb then
    local DARKEN = 0.65
    r, g, bb = r * DARKEN, g * DARKEN, bb * DARKEN
  else
    r, g, bb = 0.0, 0.55, 0.0
  end

  btn._baseR, btn._baseG, btn._baseB = r, g, bb
  self:ApplyRangeStateToButton(btn, unit)
end

function SCH:UpdateUnit(unit)
  if not unit or not UnitExists(unit) then return end

  -- Main window button
  do
    local b = self.unitToButton and self.unitToButton[unit]
    if b and b.bar then
      self:UpdateUnitForAnyButton(b, unit, false)
    end
  end

  -- Priority window button (if this unit is currently shown there)
  do
    local pb = self.priorityUnitToButton and self.priorityUnitToButton[unit]
    if pb and pb.bar then
      self:UpdateUnitForAnyButton(pb, unit, true)
    end
  end
end

function SCH:UpdateButtonUnit(b)
  local unit = b.unit
  if not unit or not UnitExists(unit) then
    b.nameText:SetText("")
    b.hpText:SetText("")
    b.bar:SetMinMaxValues(0, 1)
    b.bar:SetValue(0)
    b._baseR, b._baseG, b._baseB = 0.2, 0.2, 0.2
    b._isPriority = false
    b.bar:SetStatusBarColor(0.2, 0.2, 0.2)
    return
  end
  self:UpdateUnit(unit)
end

function SCH:OnUnitNameUpdate(_, unit)
  if not unit then return end
  self:UpdateUnit(unit)
end

function SCH:OnUnitHealth(_, unit)
  if not unit then return end
  self:UpdateUnit(unit)
end

-- -----------------------
-- Adaptive GRID LAYOUT
-- -----------------------
function SCH:ApplyLayout()
  if not self.frame then return end
  if InCombatLockdown() then
    self._pendingLayout = true
    return
  end

  local cfg = self.db.profile.frame
  self.frame:SetScale(cfg.scale or 1.0)

  local w, h = cfg.width, cfg.height
  local colsCfg = tonumber(cfg.columns) or 1
  if colsCfg < 1 then colsCfg = 1 end
  if colsCfg > 8 then colsCfg = 8 end

  local hSpacing = tonumber(cfg.hSpacing) or 2
  local vSpacing = tonumber(cfg.vSpacing) or 2

  local visibleCount
  if inRaidClassic() then
    local n = raidSizeClassic()
    visibleCount = (n and n > 0) and n or 40
  else
    if self:IsDemoModeActive() then
      visibleCount = 40
    else
      visibleCount = (self.db.profile.showSolo and 1 or 0) + partySizeClassic()
      if visibleCount < 1 then visibleCount = 1 end
    end
  end

  local colsEff = colsCfg
  if visibleCount < colsEff then colsEff = visibleCount end
  if colsEff < 1 then colsEff = 1 end

  for i = 1, 40 do
    local b = self.buttons[i]
    b:ClearAllPoints()
    b:SetSize(w, h)

    if i <= visibleCount then
      b:Show()
      if b.nameText then b.nameText:SetWidth(w - 50) end

      local idx = i - 1
      local col = (idx % colsEff)
      local row = math.floor(idx / colsEff)

      local x = col * (w + hSpacing)
      local y = -row * (h + vSpacing)

      b:SetPoint("TOPLEFT", self.content, "TOPLEFT", x, y)
    else
      b:Hide()
    end
  end

  local rows = math.ceil(visibleCount / colsEff)
  if rows < 1 then rows = 1 end

  local pad = tonumber(cfg.padding) or 7
  if pad < 7 then pad = 7 end
  local totalW = (colsEff * w) + ((colsEff - 1) * hSpacing) + (pad * 2)
  local totalH = (rows * h) + ((rows - 1) * vSpacing) + (pad * 2) + 16
  self.frame:SetSize(totalW, totalH)

  self:ApplyBarAlpha()
  self:UpdateRangeTicker()
  self:RefreshPriorityFrame()
end

-- -----------------------
-- Roster
-- -----------------------
function SCH:RefreshRoster()
  if not self.frame then return end
  if InCombatLockdown() then
    self._pendingRoster = true
    return
  end

  wipe(self.unitToButton)

  local isRaid = inRaidClassic()
  local demo = self:IsDemoModeActive() and (not isRaid)

  if demo then
    self:EnsureDemoData()
    self:StartDemoTicker()
  else
    self:StopDemoTicker()
  end

  local units = {}

  if isRaid then
    local n = raidSizeClassic()
    if not n or n < 1 then n = 40 end
    for i = 1, math.min(40, n) do
      units[#units+1] = "raid"..i
    end
  else
    if demo then
      for i = 1, 40 do units[#units+1] = "demo"..i end
    else
      if self.db.profile.showSolo or partySizeClassic() > 0 then
        units[#units+1] = "player"
      end
      for i = 1, 4 do units[#units+1] = "party"..i end
    end
  end

  for i = 1, 40 do
    local b = self.buttons[i]
    b._demoIndex = nil
    b._isPriority = false

    local unit = units[i]

    if unit and unit:sub(1, 4) == "demo" then
      b.unit = nil
      b:SetAttribute("unit", "player") -- harmless; demo is visual-only
      b._demoIndex = i
      b:Show()
      self:UpdateButtonDemo(b, i)

    elseif unit then
      b:SetAttribute("unit", unit)
      b.unit = unit
      self.unitToButton[unit] = b
      self:UpdateButtonUnit(b)

    else
      local dummy = "raid"..i
      b:SetAttribute("unit", dummy)
      b.unit = dummy
      self:UpdateButtonUnit(b)
    end
  end

  self:ApplyLayout()

  self._rangeSpell = nil
  self:GetRangeCheckSpell()
  self:UpdateRangeTicker()

  self:RefreshPriorityFrame()
end

-- -----------------------
-- Priority frame
-- -----------------------
function SCH:CreatePriorityFrame()
  if self.priorityFrame then return end
  ensurePriorityTables(self)

  local mainCfg = self.db.profile.frame
  local cfg = self.db.profile.priorityFrame
  if not cfg then
    self.db.profile.priorityFrame = {
      point = "CENTER", relPoint = "CENTER",
      x = 260, y = 0,
      width = mainCfg.width, height = mainCfg.height,
      columns = 1,
      hSpacing = 2,
      vSpacing = 2,
      spacing = 2, padding = 6,
      scale = mainCfg.scale or 1.0,
    }
    cfg = self.db.profile.priorityFrame
  end

  local f = CreateFrame("Frame", "SCH_PriorityFrame", UIParent, TEMPLATE_BACKDROP)
  self.priorityFrame = f

  f:SetScale(cfg.scale or 1.0)
  f:SetPoint(cfg.point, UIParent, cfg.relPoint, cfg.x, cfg.y)

  if f.SetBackdrop then
    f:SetBackdrop({
      bgFile = "Interface/Tooltips/UI-Tooltip-Background",
      edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 16,
      insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    f:SetBackdropColor(0, 0, 0, 0.75)
  end

  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")

  f:SetScript("OnDragStart", function(frame)
    if InCombatLockdown() then return end
    if SCH.db and SCH.db.profile and SCH.db.profile.locked then return end
    frame:StartMoving()
  end)

  f:SetScript("OnDragStop", function(frame)
    frame:StopMovingOrSizing()
    local point, _, relPoint, x, y = frame:GetPoint(1)
    cfg.point, cfg.relPoint, cfg.x, cfg.y = point, relPoint, x, y
  end)

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  title:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -6)
  title:SetText("Priority")
  self.priorityTitle = title

  local content = CreateFrame("Frame", nil, f)
  content:SetPoint("TOPLEFT", f, "TOPLEFT", cfg.padding, -(cfg.padding + 10))
  content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -cfg.padding, cfg.padding)
  self.priorityContent = content

  self.priorityButtons = {}

  for i = 1, 40 do
    local b = CreateFrame("Button", "SCH_PriorityButton"..i, content, "SecureUnitButtonTemplate")
    b:RegisterForClicks("AnyUp")
    b:SetAttribute("unit", "raid40") -- dummy invalid

    b:SetHighlightTexture("Interface/QuestFrame/UI-QuestTitleHighlight")

    local bar = CreateFrame("StatusBar", nil, b)
    bar:SetAllPoints(b)
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)
    b.bar = bar

    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(bar)
    bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    bg:SetVertexColor(0.15, 0.15, 0.15, 1)
    b.bg = bg

    bar:SetFrameLevel(b:GetFrameLevel())

    local name = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    name:SetPoint("LEFT", bar, "LEFT", 4, 0)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    name:SetText("")
    name:SetTextColor(1, 1, 1)
    name:SetShadowOffset(1, -1)
    name:SetShadowColor(0, 0, 0, 0.9)
    b.nameText = name

    local hp = bar:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hp:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
    hp:SetJustifyH("RIGHT")
    hp:SetText("")
    hp:SetTextColor(1, 1, 1)
    hp:SetShadowOffset(1, -1)
    hp:SetShadowColor(0, 0, 0, 0.9)
    b.hpText = hp

    self:AttachPriorityToggleHooks(b)

    -- TOOLTIP DISABLED
    b:SetScript("OnEnter", nil)
    b:SetScript("OnLeave", nil)

    self.priorityButtons[i] = b
    self:ApplyBindingsToButton(b)
    b:Hide()
  end

  self:ApplyBarAlpha()
end

function SCH:ApplyPriorityLayout(visibleCount)
  if not self.priorityFrame or not self.priorityButtons then return end
  if InCombatLockdown() then return end

  local cfg = self.db.profile.priorityFrame or {}
  local w = tonumber(cfg.width) or (self.db.profile.frame.width or 170)
  local h = tonumber(cfg.height) or (self.db.profile.frame.height or 18)

  -- Legacy: older profiles used "spacing" for vertical spacing only.
  local legacySpacing = tonumber(cfg.spacing)

  local colsCfg = tonumber(cfg.columns) or 1
  if colsCfg < 1 then colsCfg = 1 end
  if colsCfg > 8 then colsCfg = 8 end

  local hSpacing = tonumber(cfg.hSpacing) or legacySpacing or 2
  local vSpacing = tonumber(cfg.vSpacing) or legacySpacing or 2
  local pad = tonumber(cfg.padding) or 7
  if pad < 7 then pad = 7 end

  self.priorityFrame:SetScale(cfg.scale or 1.0)

  -- Update content insets when padding changes (CreatePriorityFrame only set these once).
  if self.priorityContent then
    self.priorityContent:ClearAllPoints()
    self.priorityContent:SetPoint("TOPLEFT", self.priorityFrame, "TOPLEFT", pad, -(pad + 10))
    self.priorityContent:SetPoint("BOTTOMRIGHT", self.priorityFrame, "BOTTOMRIGHT", -pad, pad)
  end

  local vc = math.max(1, tonumber(visibleCount) or 1)
  local colsEff = math.min(colsCfg, vc)
  if colsEff < 1 then colsEff = 1 end

  for i = 1, 40 do
    local b = self.priorityButtons[i]
    b:ClearAllPoints()
    b:SetSize(w, h)
    if b.nameText then b.nameText:SetWidth(w - 50) end

    local idx = i - 1
    local col = (idx % colsEff)
    local row = math.floor(idx / colsEff)

    local x = col * (w + hSpacing)
    local y = -row * (h + vSpacing)

    b:SetPoint("TOPLEFT", self.priorityContent, "TOPLEFT", x, y)
  end

  local rows = math.ceil(vc / colsEff)
  if rows < 1 then rows = 1 end

  local totalW = (colsEff * w) + ((colsEff - 1) * hSpacing) + (pad * 2)
  local totalH = (rows * h) + ((rows - 1) * vSpacing) + (pad * 2) + 16
  self.priorityFrame:SetSize(totalW, totalH)
end


function SCH:UpdatePriorityDemoButton(btn, demoIndex)
  self:EnsureDemoData()
  local u = self._demo.units[demoIndex]
  if not u then return end

  btn._prioDemoIndex = demoIndex
  btn._isPriority = true

  btn.nameText:SetText(u.name)
  btn.bar:SetMinMaxValues(0, u.maxHP)
  btn.bar:SetValue(u.curHP)

  local pct = u.curHP / u.maxHP
  btn.hpText:SetText(("%d%%"):format(pct * 100))

  local r = PRIORITY_GOLD_R * PRIORITY_DARKEN
  local g = PRIORITY_GOLD_G * PRIORITY_DARKEN
  local bb = PRIORITY_GOLD_B * PRIORITY_DARKEN
  btn._baseR, btn._baseG, btn._baseB = r, g, bb
  btn.bar:SetStatusBarColor(r, g, bb)
end

function SCH:RefreshPriorityFrame()
  if not self.db or not self.db.profile then return end
  ensurePriorityTables(self)

  if not self.priorityFrame then
    self:CreatePriorityFrame()
  end

  -- Unit-token -> priority button mapping so UNIT_HEALTH updates can refresh the priority window.
  self.priorityUnitToButton = self.priorityUnitToButton or {}
  wipe(self.priorityUnitToButton)

  local showFrame = self.db.profile.priority.showFrame
  if not showFrame then
    self.priorityFrame:Hide()
    return
  end

  local order = self.db.profile.priority.order
  local list = self.db.profile.priority.list

  self.guidToUnit = self.guidToUnit or {}
  wipe(self.guidToUnit)

  if self.unitToButton then
    for unit, _ in pairs(self.unitToButton) do
      if unit and UnitExists(unit) then
        local g = UnitGUID(unit)
        if g then self.guidToUnit[g] = unit end
      end
    end
  end

  local shown = 0

  for i = 1, #order do
    local key = order[i]
    local info = list[key]
    if info then
      local btn = self.priorityButtons[shown + 1]
      if not btn then break end

      btn._prioDemoIndex = nil
      btn._isPriority = true

      if key:sub(1, 5) == "DEMO:" then
        local demoIndex = tonumber(key:sub(6))
        if demoIndex and self:IsDemoModeActive() then
          shown = shown + 1
          btn:Show()
          btn.unit = nil
          btn:SetAttribute("unit", "raid40")
          self:UpdatePriorityDemoButton(btn, demoIndex)
        end
      else
        local unit = self.guidToUnit[key]
        if unit and UnitExists(unit) then
          shown = shown + 1
          btn:Show()
          btn.unit = unit
          btn:SetAttribute("unit", unit)
          self.priorityUnitToButton[unit] = btn
          self:UpdateUnitForAnyButton(btn, unit, true)
        end
      end
    end
  end

  for i = shown + 1, 40 do
    local b = self.priorityButtons[i]
    if b then
      b.unit = nil
      b._prioDemoIndex = nil
      b._isPriority = nil
      b:SetAttribute("unit", "raid40")
      b:Hide()
    end
  end

  if shown < 1 then
    self.priorityFrame:Hide()
    return
  end

  self:ApplyPriorityLayout(shown)
  self:ApplyBarAlpha()
  self.priorityFrame:Show()
end

-- -----------------------
-- Bindings summary + apply
-- -----------------------
function SCH:GetBindingsSummary()
  local b = self.db.profile.bindings
  local function line(k, label)
    local v = b[k]
    if v and v ~= "" then
      return ("%s: %s"):format(label, v)
    end
    return ("%s: (target)"):format(label)
  end

  return table.concat({
    line("L",  "LClick"),
    line("R",  "RClick"),
    line("M",  "MClick"),
    line("SL", "Shift+L"),
    line("SR", "Shift+R"),
    line("SM", "Shift+M"),
  }, "\n")
end

function SCH:ApplyAllBindings()
  if not self.buttons then return end
  if InCombatLockdown() then
    self._pendingBindings = true
    return
  end

  self._rangeSpell = nil
  self:GetRangeCheckSpell()
  self:UpdateRangeTicker()

  for i = 1, 40 do
    self:ApplyBindingsToButton(self.buttons[i])
  end

  if self.priorityButtons then
    for i = 1, 40 do
      self:ApplyBindingsToButton(self.priorityButtons[i])
    end
  end
end

-- Click-cast: macro with [@mouseover] + dead-res override
function SCH:ApplyBindingsToButton(btn)
  local binds = self.db.profile.bindings
  local resSpell = self:GetResSpell()

  local function macroForSpell(spell)
    -- If we have a res spell, prefer it on dead units; otherwise just cast bound spell.
    if resSpell and resSpell ~= "" then
      return "/cast [@mouseover,exists,help,dead] " .. resSpell ..
        "; [@mouseover,exists,help,nodead] " .. spell
    end
    return "/cast [@mouseover,exists,help,nodead] " .. spell
  end

  local function macroForTarget()
    if resSpell and resSpell ~= "" then
      -- Res dead; otherwise target
      return "/cast [@mouseover,exists,help,dead] " .. resSpell .. "\n" ..
        "/target [@mouseover,exists]"
    end
    return nil
  end

  local function setClick(buttonIndex, spell)
    spell = (spell and spell ~= "") and spell or nil
    if spell then
      btn:SetAttribute("type"..buttonIndex, "macro")
      btn:SetAttribute("macrotext"..buttonIndex, macroForSpell(spell))
      btn:SetAttribute("spell"..buttonIndex, nil)
    else
      -- No spell bound: target OR (if resSpell exists) res dead then target
      local tmacro = macroForTarget()
      if tmacro then
        btn:SetAttribute("type"..buttonIndex, "macro")
        btn:SetAttribute("macrotext"..buttonIndex, tmacro)
      else
        btn:SetAttribute("type"..buttonIndex, "target")
        btn:SetAttribute("macrotext"..buttonIndex, nil)
      end
      btn:SetAttribute("spell"..buttonIndex, nil)
    end
  end

  local function setShiftClick(buttonIndex, spell)
    spell = (spell and spell ~= "") and spell or nil
    if spell then
      btn:SetAttribute("shift-type"..buttonIndex, "macro")
      btn:SetAttribute("shift-macrotext"..buttonIndex, macroForSpell(spell))
      btn:SetAttribute("shift-spell"..buttonIndex, nil)
    else
      -- nil = fall back to unmodified click
      btn:SetAttribute("shift-type"..buttonIndex, nil)
      btn:SetAttribute("shift-macrotext"..buttonIndex, nil)
      btn:SetAttribute("shift-spell"..buttonIndex, nil)
    end
  end

  setClick(1, binds.L)
  setClick(2, binds.R)
  setClick(3, binds.M)

  setShiftClick(1, binds.SL)
  setShiftClick(2, binds.SR)
  setShiftClick(3, binds.SM)
end

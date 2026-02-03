local ADDON_NAME = ...
local LibStub = LibStub
local SCH = LibStub("AceAddon-3.0"):GetAddon(ADDON_NAME)

local AceConfigRegistry = LibStub("AceConfigRegistry-3.0", true)

local PICKER_ROWS = 14

local function BuildSpellList()
  local spells = {}
  local seen = {}

  local numTabs = GetNumSpellTabs and GetNumSpellTabs() or 0
  for tab = 1, numTabs do
    local _, _, offset, numSpells = GetSpellTabInfo(tab)
    for i = 1, numSpells do
      local slot = offset + i
      local spellType, spellID = GetSpellBookItemInfo(slot, BOOKTYPE_SPELL)
      if spellType == "SPELL" then
        local name, subName = GetSpellBookItemName(slot, BOOKTYPE_SPELL)
        if name and name ~= "" then
          local display = name
          if subName and subName ~= "" then
            -- subName is usually "Rank X" in Classic
            display = name .. "(" .. subName .. ")"
          end

          -- avoid duplicates (spellbook can list same spell via different tabs etc.)
          if not seen[display] then
            seen[display] = true
            table.insert(spells, display)
          end
        end
      end
    end
  end

  table.sort(spells)
  return spells
end

local function EnsurePicker(self)
  if self._spellPicker then return self._spellPicker end

  local f = CreateFrame("Frame", "SCH_SpellPicker", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
  f:SetSize(360, 420)
  f:SetPoint("CENTER")
  f:SetFrameStrata("FULLSCREEN_DIALOG")  -- above normal dialogs
f:SetToplevel(true)
f:Hide()


  if f.SetBackdrop then
    f:SetBackdrop({
      bgFile = "Interface/Tooltips/UI-Tooltip-Background",
      edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 16,
      insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    f:SetBackdropColor(0, 0, 0, 0.9)
  end

  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(frame) frame:StartMoving() end)
  f:SetScript("OnDragStop", function(frame) frame:StopMovingOrSizing() end)

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOPLEFT", 12, -10)
  title:SetText("Pick a Spell")

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -4, -4)

  -- Search box
  local searchLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  searchLabel:SetPoint("TOPLEFT", 12, -36)
  searchLabel:SetText("Search:")

  local search = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
  search:SetAutoFocus(false)
  search:SetSize(250, 20)
  search:SetPoint("LEFT", searchLabel, "RIGHT", 8, 0)
  search:SetScript("OnEscapePressed", function() f:Hide() end)
  f.search = search

  -- Current binding label
  local bindLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  bindLabel:SetPoint("TOPLEFT", 12, -60)
  bindLabel:SetText("Binding: ?")
  f.bindLabel = bindLabel

  -- Scroll frame
  local scrollFrame = CreateFrame("ScrollFrame", "SCH_SpellPickerScroll", f, "FauxScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", 12, -82)
  scrollFrame:SetPoint("BOTTOMRIGHT", -28, 14)
  f.scrollFrame = scrollFrame

  f.rows = {}
  for i = 1, PICKER_ROWS do
    local row = CreateFrame("Button", nil, f)
    row:SetHeight(22)
    row:SetPoint("TOPLEFT", 14, -82 - (i - 1) * 22)
    row:SetPoint("TOPRIGHT", -30, -82 - (i - 1) * 22)

    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(row)
    hl:SetTexture("Interface/QuestFrame/UI-QuestTitleHighlight")
    hl:SetBlendMode("ADD")

    local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("LEFT", 4, 0)
    text:SetJustifyH("LEFT")
    text:SetText("")
    row.text = text

    row:SetScript("OnClick", function(btn)
      if not f._activeKey or not btn._spellText then return end
      SCH.db.profile.bindings[f._activeKey] = btn._spellText
      SCH:RequestBindings()

      -- refresh AceConfig display if open
      if AceConfigRegistry then
        AceConfigRegistry:NotifyChange("SimpleClickHeal")
      end

      f:Hide()
    end)

    f.rows[i] = row
  end

  local function FilterList()
    local q = (search:GetText() or ""):lower()
    wipe(f._filtered)

    if q == "" then
      for i = 1, #f._allSpells do
        f._filtered[#f._filtered + 1] = f._allSpells[i]
      end
    else
      for i = 1, #f._allSpells do
        local s = f._allSpells[i]
        if s:lower():find(q, 1, true) then
          f._filtered[#f._filtered + 1] = s
        end
      end
    end
  end

  local function UpdateRows()
    local total = #f._filtered
    FauxScrollFrame_Update(scrollFrame, total, PICKER_ROWS, 22)

    local offset = FauxScrollFrame_GetOffset(scrollFrame) or 0
    for i = 1, PICKER_ROWS do
      local idx = offset + i
      local row = f.rows[i]
      local spellText = f._filtered[idx]

      if spellText then
        row:Show()
        row.text:SetText(spellText)
        row._spellText = spellText
      else
        row:Hide()
        row.text:SetText("")
        row._spellText = nil
      end
    end
  end

  scrollFrame:SetScript("OnVerticalScroll", function(_, delta)
    FauxScrollFrame_OnVerticalScroll(scrollFrame, delta, 22, UpdateRows)
  end)

  search:SetScript("OnTextChanged", function()
    FilterList()
    FauxScrollFrame_SetOffset(scrollFrame, 0)
    UpdateRows()
  end)

  f:SetScript("OnShow", function()
      f:Raise()
  f:SetFrameLevel((UIParent:GetFrameLevel() or 0) + 100)
    f._allSpells = BuildSpellList()
    f._filtered = f._filtered or {}
    FilterList()
    FauxScrollFrame_SetOffset(scrollFrame, 0)
    UpdateRows()
    search:SetFocus()
    search:HighlightText()
  end)

  f:SetScript("OnHide", function()
    search:ClearFocus()
  end)

  self._spellPicker = f
  return f
end

function SCH:OpenSpellPicker(bindKey)
  local f = EnsurePicker(self)
  f._activeKey = bindKey
  f.bindLabel:SetText("Binding: " .. tostring(bindKey))
  f.search:SetText("")
  f:Show()
end

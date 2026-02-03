local ADDON_NAME = ...
local LibStub = LibStub

local SCH = LibStub("AceAddon-3.0"):NewAddon(ADDON_NAME, "AceConsole-3.0", "AceEvent-3.0")

local defaults = {
  profile = {
    enabled = true,
    locked = true,
    showSolo = true,

    range = {
  enabled = true,
  throttle = 0.20, -- seconds
},
priority = {
  showFrame = true,
  list = {},   -- guid -> info
  order = {},  -- ordered guids
},

priorityFrame = {
  point = "CENTER",
  relPoint = "CENTER",
  x = 260,
  y = 0,
  width = 170,
  height = 18,

  -- Layout (mirrors the main window options)
  columns = 1,
  hSpacing = 2,
  vSpacing = 2,

  -- Legacy field (kept for older profiles); used as fallback if h/vSpacing are missing.
  spacing = 2,

  padding = 7,
  scale = 1.0,
},


    demo = {
      enabled = false,
      animate = true,
    },

    frame = {
      point = "CENTER",
      relPoint = "CENTER",
      x = 0,
      y = 0,
      width = 170,
      height = 18,

      columns = 5,
      hSpacing = 2,
      vSpacing = 2,

      padding = 7,
      scale = 1.0,

      -- NEW: bar opacity
      barAlpha = 1.0, -- 1.0 = fully opaque, 0.0 = invisible (we clamp in code)
    },

    bindings = {
      L  = "",
      R  = "",
      M  = "",
      SL = "",
      SR = "",
      SM = "",
    },

    minimap = {
      hide = false,
    },
  },
}

local function trim(s)
  if not s then return "" end
  s = tostring(s)
  s = s:gsub("^%s+", ""):gsub("%s+$", "")
  return s
end

function SCH:OnInitialize()
  self.db = LibStub("AceDB-3.0"):New("SimpleClickHealDB", defaults, true)

-- Migrate older saved variables for the Priority window layout.
do
  local pf = self.db.profile and self.db.profile.priorityFrame
  if pf then
    if pf.spacing and not pf.vSpacing then pf.vSpacing = pf.spacing end
    if pf.spacing and not pf.hSpacing then pf.hSpacing = pf.spacing end
    if not pf.columns then pf.columns = 1 end
    if not pf.hSpacing then pf.hSpacing = 2 end
    if not pf.vSpacing then pf.vSpacing = 2 end
    if pf.padding == nil or tonumber(pf.padding) == nil or pf.padding < 7 then pf.padding = 7 end
  end
end

-- Clamp padding for both windows (older profiles may have smaller values)
do
  local f = self.db.profile and self.db.profile.frame
  if f then
    if f.padding == nil or tonumber(f.padding) == nil or f.padding < 7 then f.padding = 7 end
  end
end

  self:SetupOptions()
  self:SetupMinimap()

  self:RegisterChatCommand("sch", "HandleSlash")
  self:RegisterChatCommand("simpleclickheal", "HandleSlash")
end

function SCH:OnEnable()
  if not self.db.profile.enabled then return end

  self:CreateFrames()
  self:ApplyLayout()
  self:ApplyAllBindings()
  self:RefreshRoster()

  self:RegisterEvent("PLAYER_ENTERING_WORLD", "RefreshRoster")
  self:RegisterEvent("GROUP_ROSTER_UPDATE", "RefreshRoster")

  self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnRegenEnabled")

  self:RegisterEvent("UNIT_HEALTH", "OnUnitHealth")
  self:RegisterEvent("UNIT_MAXHEALTH", "OnUnitHealth")
  self:RegisterEvent("UNIT_CONNECTION", "OnUnitHealth")
  self:RegisterEvent("UNIT_NAME_UPDATE", "OnUnitNameUpdate")
end

function SCH:OnRegenEnabled()
  if self._pendingLayout then
    self._pendingLayout = nil
    self:ApplyLayout()
  end
  if self._pendingBindings then
    self._pendingBindings = nil
    self:ApplyAllBindings()
  end
  if self._pendingRoster then
    self._pendingRoster = nil
    self:RefreshRoster()
  end
  if self._pendingPriorityLayout then
    self._pendingPriorityLayout = nil
    self:RefreshPriorityFrame()
  end
end

function SCH:RequestLayout()
  if InCombatLockdown() then
    self._pendingLayout = true
    return
  end
  self:ApplyLayout()
end


function SCH:RequestPriorityLayout()
  if InCombatLockdown() then
    self._pendingPriorityLayout = true
    return
  end
  self:RefreshPriorityFrame()
end

function SCH:RequestBindings()
  if InCombatLockdown() then
    self._pendingBindings = true
    return
  end
  self:ApplyAllBindings()
end

function SCH:RequestRoster()
  if InCombatLockdown() then
    self._pendingRoster = true
    return
  end
  self:RefreshRoster()
end

function SCH:HandleSlash(input)
  input = trim(input)
  if input == "" or input == "toggle" then
    self:ToggleFrame()
    return
  end

  local cmd, rest = input:match("^(%S+)%s*(.-)$")
  cmd = (cmd and cmd:lower()) or ""

  if cmd == "show" then
    self:SetFrameShown(true)

  elseif cmd == "hide" then
    self:SetFrameShown(false)

  elseif cmd == "config" or cmd == "options" then
    self:OpenConfig()

  elseif cmd == "lock" then
    self.db.profile.locked = true
    self:UpdateLockState()
    self:Print("|cFF00FF00Locked.|r")

  elseif cmd == "unlock" then
    self.db.profile.locked = false
    self:UpdateLockState()
    self:Print("|cFFFFFF00Unlocked (drag frame).|r")

  elseif cmd == "demo" then
    self.db.profile.demo.enabled = not self.db.profile.demo.enabled
    self:Print("Demo mode: " .. (self.db.profile.demo.enabled and "|cFF00FF00ON|r" or "|cFFFF0000OFF|r"))
    self:SetFrameShown(true)
    self:RequestRoster()
    self:RequestLayout()

  elseif cmd == "bind" then
    local key, spell = rest:match("^(%S+)%s*(.-)$")
    key = trim(key):upper()
    spell = trim(spell)
    if self.db.profile.bindings[key] == nil then
      self:Print("Unknown bind key. Use: L R M SL SR SM")
      return
    end
    self.db.profile.bindings[key] = spell
    self:RequestBindings()
    self:Print(("Bound %s to: %s"):format(key, spell ~= "" and spell or "(cleared)"))

  else
    self:Print("Commands:")
    self:Print("/sch toggle | show | hide | config | lock | unlock | demo")
    self:Print("/sch bind L|R|M|SL|SR|SM <spell name or blank>")
  end
end

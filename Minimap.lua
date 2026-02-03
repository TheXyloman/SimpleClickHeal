local ADDON_NAME = ...
local LibStub = LibStub
local SCH = LibStub("AceAddon-3.0"):GetAddon(ADDON_NAME)

function SCH:SetupMinimap()
  local LDB = LibStub:GetLibrary("LibDataBroker-1.1", true)
  local Icon = LibStub:GetLibrary("LibDBIcon-1.0", true)
  if not LDB or not Icon then return end

  local dataObj = LDB:NewDataObject("SimpleClickHeal", {
    type = "launcher",
    text = "SimpleClickHeal",
    icon = "Interface/Icons/Spell_Holy_Heal",
    OnClick = function(_, button)
      if button == "RightButton" then
        SCH:OpenConfig()
      else
        SCH:ToggleFrame()
      end
    end,
    OnTooltipShow = function(tt)
      tt:AddLine("SimpleClickHeal")
      tt:AddLine("Left-click: Toggle frame", 1, 1, 1)
      tt:AddLine("Right-click: Options", 1, 1, 1)
      tt:AddLine("Slash: /sch config", 0.9, 0.9, 0.9)
    end,
  })

  self.ldb = dataObj
  Icon:Register("SimpleClickHeal", dataObj, self.db.profile.minimap)
end

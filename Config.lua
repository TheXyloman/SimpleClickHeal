local ADDON_NAME = ...
local LibStub = LibStub
local SCH = LibStub("AceAddon-3.0"):GetAddon(ADDON_NAME)

local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0", true)

local function trim(s)
  if not s then return "" end
  s = tostring(s)
  s = s:gsub("^%s+", ""):gsub("%s+$", "")
  return s
end

function SCH:SetupOptions()
  local options = {
    type = "group",
    name = "SimpleClickHeal",
    args = {
      general = {
        type = "group",
        name = "General",
        order = 1,
        args = {
          enabled = {
            type = "toggle",
            name = "Enabled",
            order = 1,
            get = function() return SCH.db.profile.enabled end,
            set = function(_, v)
              SCH.db.profile.enabled = v
              ReloadUI()
            end,
          },

          showSolo = {
            type = "toggle",
            name = "Show frame when solo",
            order = 2,
            get = function() return SCH.db.profile.showSolo end,
            set = function(_, v)
              SCH.db.profile.showSolo = v
              SCH:RequestRoster()
              SCH:RequestLayout()
            end,
          },

          locked = {
            type = "toggle",
            name = "Locked (disable dragging)",
            order = 3,
            get = function() return SCH.db.profile.locked end,
            set = function(_, v)
              SCH.db.profile.locked = v
              SCH:UpdateLockState()
            end,
          },

          demoEnabled = {
            type = "toggle",
            name = "Demo mode (show fake 40-man raid)",
            desc = "Shows a simulated 40-player raid inside the addon for layout tuning (visual only).",
            order = 10,
            get = function() return SCH.db.profile.demo.enabled end,
            set = function(_, v)
              SCH.db.profile.demo.enabled = v
              SCH:SetFrameShown(true)
              SCH:RequestRoster()
              SCH:RequestLayout()
            end,
          },

          demoAnimate = {
            type = "toggle",
            name = "Demo mode: animate health",
            order = 11,
            get = function() return SCH.db.profile.demo.animate end,
            set = function(_, v)
              SCH.db.profile.demo.animate = v
              SCH:RequestRoster()
            end,
          },

          hint = {
            type = "description",
            name = "\nNote: Binding/layout/roster changes cannot be applied while in combat; they will apply when you leave combat.\n",
            order = 99,
          },
          rangeEnabled = {
  type = "toggle",
  name = "Range fade (grey out when out of range)",
  order = 6,
  get = function() return SCH.db.profile.range and SCH.db.profile.range.enabled end,
  set = function(_, v)
    SCH.db.profile.range = SCH.db.profile.range or {}
    SCH.db.profile.range.enabled = v
    if SCH.UpdateRangeTicker then SCH:UpdateRangeTicker() end
    SCH:RequestRoster()
  end,
},

rangeThrottle = {
  type = "range",
  name = "Range check speed",
  desc = "How often range is checked (lower = more responsive, higher = less CPU).",
  min = 0.10, max = 1.00, step = 0.05,
  order = 7,
  get = function() return (SCH.db.profile.range and SCH.db.profile.range.throttle) or 0.20 end,
  set = function(_, v)
    SCH.db.profile.range = SCH.db.profile.range or {}
    SCH.db.profile.range.throttle = v
    if SCH.UpdateRangeTicker then SCH:UpdateRangeTicker() end
  end,
},

        },
      },

      layout = {
        type = "group",
        name = "Layout",
        order = 2,
        args = {
          width = {
            type = "range",
            name = "Bar width",
            min = 120, max = 320, step = 1,
            order = 1,
            get = function() return SCH.db.profile.frame.width end,
            set = function(_, v)
              SCH.db.profile.frame.width = v
              SCH:RequestLayout()
            end,
          },

          height = {
            type = "range",
            name = "Bar height",
            min = 14, max = 40, step = 1,
            order = 2,
            get = function() return SCH.db.profile.frame.height end,
            set = function(_, v)
              SCH.db.profile.frame.height = v
              SCH:RequestLayout()
            end,
          },

          columns = {
            type = "range",
            name = "Columns",
            desc = "How many unit frames per row (grid layout).",
            min = 1, max = 8, step = 1,
            order = 3,
            get = function() return SCH.db.profile.frame.columns or 1 end,
            set = function(_, v)
              SCH.db.profile.frame.columns = v
              SCH:RequestLayout()
            end,
          },

          hSpacing = {
            type = "range",
            name = "Horizontal spacing",
            min = 0, max = 20, step = 1,
            order = 4,
            get = function() return SCH.db.profile.frame.hSpacing or 2 end,
            set = function(_, v)
              SCH.db.profile.frame.hSpacing = v
              SCH:RequestLayout()
            end,
          },

          vSpacing = {
            type = "range",
            name = "Vertical spacing",
            min = 0, max = 20, step = 1,
            order = 5,
            get = function() return SCH.db.profile.frame.vSpacing or 2 end,
            set = function(_, v)
              SCH.db.profile.frame.vSpacing = v
              SCH:RequestLayout()
            end,
          },
          padding = {
            type = "range",
            name = "Padding",
            min = 7, max = 30, step = 1,
            order = 6,
            get = function() return SCH.db.profile.frame.padding or 7 end,
            set = function(_, v)
              SCH.db.profile.frame.padding = v
              SCH:RequestLayout()
            end,
          },


          scale = {
            type = "range",
            name = "Scale",
            min = 0.6, max = 1.6, step = 0.05,
            order = 7,
            get = function() return SCH.db.profile.frame.scale end,
            set = function(_, v)
              SCH.db.profile.frame.scale = v
              SCH:RequestLayout()
            end,
          },
          barAlpha = {
  type = "range",
  name = "Bar opacity",
  desc = "Transparency of the health bars (0.10 = very transparent, 1.00 = solid).",
  min = 0.10, max = 1.00, step = 0.05,
  order = 8,
  get = function() return SCH.db.profile.frame.barAlpha or 1.0 end,
  set = function(_, v)
    SCH.db.profile.frame.barAlpha = v
    if SCH.ApplyBarAlpha then SCH:ApplyBarAlpha() end
  end,
},

priorityHeader = {
  type = "header",
  name = "Priority window",
  order = 20,
},

pWidth = {
  type = "range",
  name = "Bar width",
  min = 120, max = 320, step = 1,
  order = 21,
  get = function() return SCH.db.profile.priorityFrame.width end,
  set = function(_, v)
    SCH.db.profile.priorityFrame.width = v
    if SCH.RequestPriorityLayout then SCH:RequestPriorityLayout() else SCH:RequestLayout() end
  end,
},

pHeight = {
  type = "range",
  name = "Bar height",
  min = 12, max = 32, step = 1,
  order = 22,
  get = function() return SCH.db.profile.priorityFrame.height end,
  set = function(_, v)
    SCH.db.profile.priorityFrame.height = v
    if SCH.RequestPriorityLayout then SCH:RequestPriorityLayout() else SCH:RequestLayout() end
  end,
},

pColumns = {
  type = "range",
  name = "Columns",
  min = 1, max = 8, step = 1,
  order = 23,
  get = function() return SCH.db.profile.priorityFrame.columns or 1 end,
  set = function(_, v)
    SCH.db.profile.priorityFrame.columns = v
    if SCH.RequestPriorityLayout then SCH:RequestPriorityLayout() else SCH:RequestLayout() end
  end,
},

pHSpacing = {
  type = "range",
  name = "Horizontal spacing",
  min = 0, max = 20, step = 1,
  order = 24,
  get = function() return SCH.db.profile.priorityFrame.hSpacing or SCH.db.profile.priorityFrame.spacing or 2 end,
  set = function(_, v)
    SCH.db.profile.priorityFrame.hSpacing = v
    if SCH.RequestPriorityLayout then SCH:RequestPriorityLayout() else SCH:RequestLayout() end
  end,
},

pVSpacing = {
  type = "range",
  name = "Vertical spacing",
  min = 0, max = 20, step = 1,
  order = 25,
  get = function() return SCH.db.profile.priorityFrame.vSpacing or SCH.db.profile.priorityFrame.spacing or 2 end,
  set = function(_, v)
    SCH.db.profile.priorityFrame.vSpacing = v
    -- keep legacy field in sync so older code paths (if any) behave.
    SCH.db.profile.priorityFrame.spacing = v
    if SCH.RequestPriorityLayout then SCH:RequestPriorityLayout() else SCH:RequestLayout() end
  end,
},

pPadding = {
  type = "range",
  name = "Padding",
    min = 7, max = 20, step = 1,
  order = 26,
    get = function() return SCH.db.profile.priorityFrame.padding or 7 end,
  set = function(_, v)
    SCH.db.profile.priorityFrame.padding = v
    if SCH.RequestPriorityLayout then SCH:RequestPriorityLayout() else SCH:RequestLayout() end
  end,
},

pScale = {
  type = "range",
  name = "Scale",
    min = 7, max = 20, step = 1,
  order = 27,
  get = function() return SCH.db.profile.priorityFrame.scale or 1.0 end,
  set = function(_, v)
    SCH.db.profile.priorityFrame.scale = v
    if SCH.RequestPriorityLayout then SCH:RequestPriorityLayout() else SCH:RequestLayout() end
  end,
},


        },
      },

      bindings = {
        type = "group",
        name = "Click Bindings",
        order = 3,
        args = {
          desc = {
            type = "description",
            name = "Type spell names, or click Pick… to choose from your spellbook.\nLeave blank to make that click just target.\n",
            order = 0,
          },

          rowL = {
            type = "group", name = "Left Click", inline = true, order = 1,
            args = {
              L = { type="input", name="Spell", width="double", order=1 },
              LPick = { type="execute", name="Pick…", width="half", order=2, func = function() SCH:OpenSpellPicker("L") end },
            },
          },

          rowR = {
            type = "group", name = "Right Click", inline = true, order = 2,
            args = {
              R = { type="input", name="Spell", width="double", order=1 },
              RPick = { type="execute", name="Pick…", width="half", order=2, func = function() SCH:OpenSpellPicker("R") end },
            },
          },

          rowM = {
            type = "group", name = "Middle Click", inline = true, order = 3,
            args = {
              M = { type="input", name="Spell", width="double", order=1 },
              MPick = { type="execute", name="Pick…", width="half", order=2, func = function() SCH:OpenSpellPicker("M") end },
            },
          },

          rowSL = {
            type = "group", name = "Shift + Left", inline = true, order = 4,
            args = {
              SL = { type="input", name="Spell", width="double", order=1 },
              SLPick = { type="execute", name="Pick…", width="half", order=2, func = function() SCH:OpenSpellPicker("SL") end },
            },
          },

          rowSR = {
            type = "group", name = "Shift + Right", inline = true, order = 5,
            args = {
              SR = { type="input", name="Spell", width="double", order=1 },
              SRPick = { type="execute", name="Pick…", width="half", order=2, func = function() SCH:OpenSpellPicker("SR") end },
            },
          },

          rowSM = {
            type = "group", name = "Shift + Middle", inline = true, order = 6,
            args = {
              SM = { type="input", name="Spell", width="double", order=1 },
              SMPick = { type="execute", name="Pick…", width="half", order=2, func = function() SCH:OpenSpellPicker("SM") end },
            },
          },
        },
      },
    },
  }

  local function bindInput(rowKey, key)
    local row = options.args.bindings.args[rowKey]
    row.args[key].get = function() return SCH.db.profile.bindings[key] end
    row.args[key].set = function(_, v)
      SCH.db.profile.bindings[key] = trim(v)
      SCH:RequestBindings()
      if AceConfigRegistry then
        AceConfigRegistry:NotifyChange("SimpleClickHeal")
      end
    end
  end

  bindInput("rowL", "L")
  bindInput("rowR", "R")
  bindInput("rowM", "M")
  bindInput("rowSL", "SL")
  bindInput("rowSR", "SR")
  bindInput("rowSM", "SM")

  AceConfig:RegisterOptionsTable("SimpleClickHeal", options)
  SCH.optionsFrame = AceConfigDialog:AddToBlizOptions("SimpleClickHeal", "SimpleClickHeal")
end

function SCH:OpenConfig()
  local ACD = LibStub("AceConfigDialog-3.0", true)
  if ACD then
    if ACD.OpenFrames and ACD.OpenFrames["SimpleClickHeal"] then
      ACD:Close("SimpleClickHeal")
    else
      ACD:Open("SimpleClickHeal")
    end
    return
  end

  if Settings and Settings.OpenToCategory then
    Settings.OpenToCategory("SimpleClickHeal")
    return
  end

  if InterfaceOptionsFrame_OpenToCategory and SCH.optionsFrame then
    InterfaceOptionsFrame_OpenToCategory(SCH.optionsFrame)
    InterfaceOptionsFrame_OpenToCategory(SCH.optionsFrame)
    return
  end
end
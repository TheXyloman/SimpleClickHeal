# SimpleClickHeal ✨

<h1>⚠️ Project Status: Moved to SimpleFrames</h1>

> [!WARNING]
> <h2>SimpleClickHeal is no longer in active development.</h2>
>
> <p><strong>Work has moved to the new and improved <a href="https://github.com/TheXyloman/SimpleFrames">TheXyloman/SimpleFrames</a> project.</strong></p>

---

A clean, grid-based click-to-heal addon for World of Warcraft Classic TBC Anniversary. Fast setup, compact frames, and a focused priority window for the targets that matter.

---

## At a Glance 👀

| Focus | What you get |
| --- | --- |
| Layout | Adjustable grid size, spacing, padding, scale, and bar opacity |
| Casting | Mouseover click-casting on L/R/M and Shift+L/R/M |
| Awareness | Range fade, priority window, and demo mode |
| Access | Minimap toggle and config panel |

---

## Install 📦
1. Copy the `SimpleClickHeal` folder into:
   `World of Warcraft/_classic_/Interface/AddOns/SimpleClickHeal`
2. Ensure `libs` is included (Ace3, LibDataBroker, LibDBIcon).
3. Enable the addon from the character selection screen.

---

## Quick Start ⚡
1. Open options: `/sch config`.
2. Set click bindings under **Click Bindings**.
3. Tune the grid under **Layout**.
4. Drag frames with `/sch unlock`, then `/sch lock`.

---

## Controls 🖱️

| Action | Result |
| --- | --- |
| Left Click | Cast spell (or target if blank) |
| Right Click | Cast spell (or target if blank) |
| Middle Click | Cast spell (or target if blank) |
| Shift + Click | Cast shift-bound spell |
| Alt + Middle Click | Toggle Priority on a unit |

---

## Slash Commands ⌨️

| Command | Purpose |
| --- | --- |
| `/sch` or `/sch toggle` | Toggle the main frame |
| `/sch show` | Show the main frame |
| `/sch hide` | Hide the main frame |
| `/sch config` or `/sch options` | Open the options panel |
| `/sch lock` | Lock frames (disable dragging) |
| `/sch unlock` | Unlock frames (enable dragging) |
| `/sch demo` | Toggle demo mode |
| `/sch bind <L|R|M|SL|SR|SM> <spell>` | Bind a spell to a click |

Examples:
- `/sch bind L Flash Heal`
- `/sch bind R` (clears right-click)

---

## Click Bindings 🧩
- `L`, `R`, `M` for left, right, middle click.
- `SL`, `SR`, `SM` for shift + left/right/middle.

If a binding is blank, the click targets the unit. If your class has a resurrection spell, it will be used on dead units before targeting.

Default resurrection spell by class:
- Priest: `Resurrection`
- Paladin: `Redemption`
- Shaman: `Ancestral Spirit`
- Druid: `Rebirth`

---

## Priority Window ⭐
- Alt + Middle Click a unit to pin it.
- Priority units are shown in a separate window with a gold tint.
- Layout is configurable under **Layout > Priority window**.

---

## Range Fade 📏
- Enable **Range fade** in options.
- Uses your first configured binding to check range.
- Frequency is adjustable under **Range check speed**.

---

## Demo Mode 🧪
- Shows a simulated 40-man raid for layout tuning.
- Optional animated health changes.

---

## Minimap Icon 🧭
- Left-click: toggle the main frame.
- Right-click: open options.

---

## Saved Variables 💾
- `SimpleClickHealDB`

---

## Dependencies 🧰
- Ace3
- LibDataBroker-1.1
- LibDBIcon-1.0

---

## Notes ⚠️
- This addon is no longer in active development. Work has moved to [TheXyloman/SimpleFrames](https://github.com/TheXyloman/SimpleFrames).
- Layout, bindings, and roster changes are deferred while in combat.

---

## License 📄
MIT

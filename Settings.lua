local addonName = ...
local Addon = LH_FarmMe

local function Build(category, layout)
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Farm goals"))
    local shortcut = Settings.RegisterProxySetting(category, "LH_FarmMe_clickShortcut", "string",
        "Inventory shortcut", "ALT_SHIFT",
        function() return Addon:GetClickShortcut() end,
        function(value) Addon:SetClickShortcut(value) end)
    local function ShortcutOptions()
        local choices = Settings.CreateControlTextContainer()
        choices:Add("OFF", "Disabled", "Do not open the farm editor from bag items.")
        choices:Add("ALT", "Alt + left click", "Use Alt and left click on a bag item.")
        choices:Add("CTRL", "Ctrl + left click", "Use Ctrl and left click on a bag item.")
        choices:Add("SHIFT", "Shift + left click", "Use Shift and left click on a bag item.")
        choices:Add("ALT_CTRL", "Alt + Ctrl + left click", "Use Alt and Ctrl with left click.")
        choices:Add("ALT_SHIFT", "Alt + Shift + left click", "Use Alt and Shift with left click.")
        choices:Add("CTRL_SHIFT", "Ctrl + Shift + left click", "Use Ctrl and Shift with left click.")
        choices:Add("ALT_CTRL_SHIFT", "Alt + Ctrl + Shift + left click", "Use all three modifiers with left click.")
        return choices:GetData()
    end
    Settings.CreateDropdown(category, shortcut, ShortcutOptions,
        "Open the item editor and fill in the clicked bag item's name. The target quantity is entered separately. Saved per character.")
    layout:AddInitializer(CreateSettingsButtonInitializer("Restore the default top dock position", "Reset position",
        function() Addon:ResetPosition() end,
        "Place the gold handle at the center of the upper right half of the screen.", true))
    layout:AddInitializer(CreateSettingsButtonInitializer("Clear all farming goals", "Clear goals",
        function() Addon:ClearGoals() end,
        "Remove all saved goals for this character.", true))
    EventRegistry:RegisterCallback("Settings.CategoryDefaulted", function(_, selected)
        if selected == category then Addon:ResetPosition() end
    end, Addon)
end

LH_Tweaks:RegisterModule(addonName, "LH FarmMe", Build)

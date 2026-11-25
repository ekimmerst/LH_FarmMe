local addonName = ...
local Addon = {}
LH_FarmMe = Addon

local WIDTH, HANDLE_WIDTH, HANDLE_HIT_HEIGHT, HANDLE_GOLD_HEIGHT, HANDLE_OVERSCAN, ROW_HEIGHT, GAP = 430, 104, 28, 4, 4, 25, 5
local PANEL_GAP = 7
local GOLD = {0.75, 0.56, 0.16}
local db, handle, panel, editor, itemBox, countBox, toast
local rows = {}
local bagCounts = {}
local completed = {}
local hoverElapsed = 0
local focusCountPending = false
local bagHooked = {}
local lastShortcutID, lastShortcutTime
local measureText
local SMOOTH = "Interface\\AddOns\\LH_FarmMe\\Media\\Smooth.tga"

local function Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cffffc65bLH FarmMe|r: " .. message)
end

local function Safe(value)
    return value ~= nil and (not issecretvalue or not issecretvalue(value))
end

local function ItemName(id)
    local getter = C_Item and C_Item.GetItemInfo or GetItemInfo
    if not getter then return nil end
    local ok, name = pcall(getter, id)
    if ok and Safe(name) and type(name) == "string" then return name end
end

local function ItemIcon(id)
    local getter = C_Item and C_Item.GetItemIconByID or GetItemIcon
    if not getter then return nil end
    local ok, icon = pcall(getter, id)
    if ok and Safe(icon) then return icon end
end

local function ItemCount(id)
    local getter = C_Item and C_Item.GetItemCount or GetItemCount
    local count = 0
    if getter then
        local ok, result = pcall(getter, id, false, false)
        if ok and Safe(result) and type(result) == "number" then count = math.max(0, result) end
    end
    if count > 0 then return count end
    -- Some clients do not expose the current bag count through GetItemCount.
    local slots = C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots
    local itemID = C_Container and C_Container.GetContainerItemID or GetContainerItemID
    local itemInfo = C_Container and C_Container.GetContainerItemInfo or GetContainerItemInfo
    if not slots or not itemInfo then return count end
    local bagCount = 0
    for bag = 0, NUM_BAG_SLOTS or 4 do
        local okSlots, number = pcall(slots, bag)
        if okSlots and Safe(number) and type(number) == "number" then
            for slot = 1, number do
                local foundID
                if itemID then
                    local okID, value = pcall(itemID, bag, slot)
                    if okID and Safe(value) then foundID = value end
                end
                local okInfo, info, legacyCount = pcall(itemInfo, bag, slot)
                if okInfo and Safe(info) then
                    if type(info) == "table" then
                        foundID = foundID or info.itemID
                        legacyCount = info.stackCount
                    end
                    if Safe(foundID) and foundID == id and Safe(legacyCount) and type(legacyCount) == "number" then
                        bagCount = bagCount + legacyCount
                    end
                end
            end
        end
    end
    return math.max(count, bagCount)
end

local function ResolveItem(text)
    local id = tonumber(text:match("item:(%d+)") or text:match("^%s*(%d+)%s*$"))
    if id then return id, ItemName(id) or text:match("%[(.-)%]") end
    local getter = C_Item and C_Item.GetItemInfo or GetItemInfo
    if getter then
        local ok, name, link = pcall(getter, text)
        if ok and Safe(link) and type(link) == "string" then
            id = tonumber(link:match("item:(%d+)"))
            if id then return id, Safe(name) and name or text end
        end
    end
end

local function SortedGoals()
    local goals = {}
    for id, goal in pairs(db.goals) do goals[#goals + 1] = {id = id, goal = goal} end
    table.sort(goals, function(a, b)
        local first, second = (a.goal.name or ""):lower(), (b.goal.name or ""):lower()
        if first == second then return a.id < b.id end
        return first < second
    end)
    return goals
end

local function ShowToast(goal)
    completed[#completed + 1] = {id = goal.id, name = goal.name, target = goal.target}
    if toast and toast:IsShown() then return end
    local function DisplayNext()
        local nextGoal = table.remove(completed, 1)
        if not nextGoal then return end
        toast.icon:SetTexture(ItemIcon(nextGoal.id) or "Interface\\Icons\\INV_Misc_QuestionMark")
        toast.name:SetText(string.format("Farm %d %s", nextGoal.target, nextGoal.name))
        toast.remaining = 4
        toast:Show()
        toast.glowAnim:Stop()
        toast.glow:SetAlpha(1)
        toast.glow:Show()
        toast.glowAnim:Play()
        if PlaySound then pcall(PlaySound, 12891, "Master") end
    end
    if not toast then
        toast = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        toast:SetSize(320, 104)
        toast:SetPoint("CENTER", UIParent, "CENTER", 0, 170)
        toast:SetFrameStrata("FULLSCREEN_DIALOG")
        toast:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border", edgeSize = 18,
            insets = {left = 7, right = 7, top = 7, bottom = 7}})
        toast:SetBackdropColor(0.12, 0.07, 0.025, 0.96)
        local background = toast:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints(toast)
        if background.SetAtlas then pcall(background.SetAtlas, background, "ui-achievement-guild-background") end
        toast.icon = toast:CreateTexture(nil, "ARTWORK")
        toast.icon:SetSize(48, 48)
        toast.icon:SetPoint("TOPLEFT", 17, -34)
        local frame = toast:CreateTexture(nil, "OVERLAY")
        frame:SetSize(70, 68)
        frame:SetPoint("CENTER", toast.icon)
        if frame.SetAtlas then pcall(frame.SetAtlas, frame, "ui-achievement-guild-iconframe") end
        local title = toast:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", 0, -13)
        title:SetText("LH FarmMe")
        local heading = toast:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        heading:SetPoint("TOPLEFT", 75, -36)
        heading:SetText("GOAL COMPLETED")
        heading:SetTextColor(1, 0.82, 0.35)
        toast.name = toast:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        toast.name:SetSize(165, 36)
        toast.name:SetPoint("TOPLEFT", 75, -55)
        toast.name:SetJustifyH("CENTER")
        toast.name:SetJustifyV("MIDDLE")
        local glow = toast:CreateTexture(nil, "OVERLAY")
        glow:SetSize(320, 104)
        glow:SetPoint("CENTER")
        glow:SetBlendMode("ADD")
        if glow.SetAtlas then pcall(glow.SetAtlas, glow, "ui-achievement-guild-glow") end
        toast.glow = glow
        toast.glowAnim = glow:CreateAnimationGroup()
        local fade = toast.glowAnim:CreateAnimation("Alpha")
        fade:SetFromAlpha(1); fade:SetToAlpha(0); fade:SetDuration(0.8)
        toast.glowAnim:SetScript("OnFinished", function() glow:Hide() end)
        toast:SetScript("OnUpdate", function(self, elapsed)
            self.remaining = self.remaining - elapsed
            if self.remaining <= 0 then self:Hide(); DisplayNext() end
        end)
        toast:Hide()
    end
    DisplayNext()
end

local function CreateRow()
    local row = CreateFrame("Frame", nil, panel)
    row:SetSize(WIDTH, ROW_HEIGHT)
    row.border = CreateFrame("Frame", nil, row, "BackdropTemplate")
    row.border:SetSize(120, ROW_HEIGHT)
    row.border:SetPoint("CENTER", row, "CENTER")
    row.border:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8, insets = {left = 2, right = 2, top = 2, bottom = 2}})
    row.border:SetBackdropColor(0, 0, 0, 0.8)
    row.border:SetBackdropBorderColor(0.65, 0.59, 0.45, 1)
    row.fill = CreateFrame("StatusBar", nil, row.border)
    row.fill:SetPoint("TOPLEFT", 3, -3)
    row.fill:SetPoint("BOTTOMRIGHT", -3, 3)
    row.fill:SetStatusBarTexture(SMOOTH)
    row.fill:EnableMouse(false)
    row.textLayer = CreateFrame("Frame", nil, row.border)
    row.textLayer:SetAllPoints(row.border)
    row.textLayer:SetFrameLevel(row.fill:GetFrameLevel() + 1)
    row.name = row.textLayer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetPoint("LEFT", row.textLayer, "LEFT", 9, 0)
    row.name:SetSize(80, ROW_HEIGHT - 4)
    row.name:SetJustifyH("LEFT")
    row.name:SetJustifyV("MIDDLE")
    row.name:SetWordWrap(false)
    row.name:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    row.label = row.textLayer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.label:SetPoint("RIGHT", row.textLayer, "RIGHT", -9, 0)
    row.label:SetSize(30, ROW_HEIGHT - 4)
    row.label:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    row.label:SetJustifyH("RIGHT")
    row.label:SetJustifyV("MIDDLE")
    row.flash = row.fill:CreateTexture(nil, "OVERLAY")
    row.flash:SetTexture("Interface\\Buttons\\WHITE8X8")
    row.flash:SetVertexColor(0.35, 1, 0.35, 1)
    row.flash:SetBlendMode("ADD")
    row.flash:Hide()
    row.icon = CreateFrame("Button", nil, row)
    row.icon:SetSize(20, 20)
    row.icon:SetPoint("RIGHT", row.border, "LEFT", -4, 0)
    row.icon.texture = row.icon:CreateTexture(nil, "ARTWORK")
    row.icon.texture:SetAllPoints(row.icon)
    row.icon:SetScript("OnEnter", function(self)
        if not self.itemID or not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.itemLink then
            GameTooltip:SetHyperlink(self.itemLink)
        elseif GameTooltip.SetItemByID then
            GameTooltip:SetItemByID(self.itemID)
        else
            GameTooltip:SetHyperlink("item:" .. self.itemID)
        end
        GameTooltip:Show()
    end)
    row.icon:SetScript("OnLeave", function(self)
        if GameTooltip and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    row.remove = CreateFrame("Button", nil, row, "BackdropTemplate")
    row.remove:SetSize(22, 22)
    row.remove:SetPoint("LEFT", row.border, "RIGHT", 4, 0)
    row.remove:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8, insets = {left = 2, right = 2, top = 2, bottom = 2}})
    row.remove:SetBackdropColor(0.16, 0.12, 0.07, 0.9)
    row.remove:SetBackdropBorderColor(0.65, 0.59, 0.45, 1)
    local highlight = row.remove:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetPoint("TOPLEFT", 3, -3)
    highlight:SetPoint("BOTTOMRIGHT", -3, 3)
    highlight:SetColorTexture(0.8, 0.65, 0.3, 0.2)
    row.remove.text = row.remove:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.remove.text:SetPoint("CENTER")
    row.remove.text:SetText("x")
    row.remove:SetScript("OnClick", function(self)
        db.goals[self.itemID] = nil
        bagCounts[self.itemID] = nil
        Addon:Refresh()
    end)
    row:SetScript("OnUpdate", function(self, elapsed)
        if not self.flashRemaining then return end
        self.flashRemaining = self.flashRemaining - elapsed
        if self.flashRemaining <= 0 then
            self.flashRemaining = nil
            self.flash:Hide()
        else
            self.flash:SetAlpha(math.min(1, self.flashRemaining / 0.3))
        end
    end)
    return row
end

function Addon:Refresh()
    if not panel or not db then return end
    local sorted = SortedGoals()
    local barWidth = 120
    local counts = {}
    for index, entry in ipairs(sorted) do
        local goal = entry.goal
        local name = type(goal.name) == "string" and goal.name ~= "" and goal.name or ("Item " .. entry.id)
        local count = string.format("%d / %d", goal.progress, goal.target)
        measureText:SetText(name)
        local nameWidth = math.ceil(measureText:GetStringWidth() or 0)
        measureText:SetText(count)
        local countWidth = math.ceil(measureText:GetStringWidth() or 0)
        counts[index] = {name = name, count = count, countWidth = countWidth}
        barWidth = math.max(barWidth, nameWidth + countWidth + 30)
    end
    barWidth = math.min(WIDTH - 70, barWidth)
    for index, entry in ipairs(sorted) do
        local row = rows[index]
        if not row then row = CreateRow(); rows[index] = row end
        local goal = entry.goal
        if row.itemID ~= entry.id then
            row.flashRemaining = nil
            row.flash:Hide()
        end
        row.itemID = entry.id
        row.remove.itemID = entry.id
        row.border:SetWidth(barWidth)
        row.label:SetWidth(counts[index].countWidth + 2)
        row.name:SetWidth(barWidth - counts[index].countWidth - 28)
        row.name:SetText(counts[index].name)
        row.label:SetText(counts[index].count)
        row.icon.itemID = entry.id
        row.icon.itemLink = goal.link
        row.icon.texture:SetTexture(ItemIcon(entry.id) or "Interface\\Icons\\INV_Misc_QuestionMark")
        row.fill:SetMinMaxValues(0, goal.target)
        row.fill:SetValue(math.min(goal.progress, goal.target))
        row.fill:SetStatusBarColor(goal.reached and 0.35 or 1, goal.reached and 0.9 or 0.75, 0.15, 1)
        row:ClearAllPoints()
        row:SetPoint("TOP", panel, "TOP", 0, -(index - 1) * (ROW_HEIGHT + GAP))
        row:Show()
    end
    for index = #sorted + 1, #rows do rows[index]:Hide() end
    panel:SetHeight(math.max(1, #sorted * (ROW_HEIGHT + GAP) - GAP))
end

local function AddGoal()
    local text = itemBox:GetText():match("^%s*(.-)%s*$")
    local target = tonumber(countBox:GetText())
    if not target or target < 1 or target % 1 ~= 0 or target > 999999999 then
        Print("Enter a positive whole number as the target quantity.")
        return
    end
    local id, name
    if itemBox.itemID then
        id = itemBox.itemID
        name = ItemName(id) or text
    else
        id, name = ResolveItem(text)
    end
    if not id or id < 1 then
        Print("Item not found. Enter an item ID or item link if its name is not cached yet.")
        return
    end
    local link = itemBox.itemLink
    if not link and text:find("|Hitem:", 1, true) then link = text end
    local goal = db.goals[id]
    if goal then
        goal.target = target
        goal.reached = goal.progress >= target
    else
        local current = ItemCount(id)
        goal = {id = id, name = name or ("Item " .. id), target = target,
            progress = current, reached = current >= target}
        db.goals[id] = goal
        bagCounts[id] = current
        if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
        if goal.reached then ShowToast(goal) end
    end
    if name then goal.name = name end
    if link then goal.link = link end
    itemBox:SetText("")
    itemBox.itemID = nil
    itemBox.itemLink = nil
    countBox:SetText("")
    itemBox:ClearFocus()
    countBox:ClearFocus()
    Addon:Refresh()
end

local shortcuts = {
    OFF = {}, ALT = {alt = true}, CTRL = {ctrl = true}, SHIFT = {shift = true},
    ALT_CTRL = {alt = true, ctrl = true}, ALT_SHIFT = {alt = true, shift = true},
    CTRL_SHIFT = {ctrl = true, shift = true}, ALT_CTRL_SHIFT = {alt = true, ctrl = true, shift = true},
}

function Addon:GetClickShortcut()
    return db and db.clickShortcut or "ALT_SHIFT"
end

function Addon:SetClickShortcut(value)
    if db and shortcuts[value] then db.clickShortcut = value end
end

local function ShortcutDown()
    local key = db and shortcuts[db.clickShortcut]
    if not key or db.clickShortcut == "OFF" then return false end
    return (not not IsAltKeyDown()) == (not not key.alt)
        and (not not IsControlKeyDown()) == (not not key.ctrl)
        and (not not IsShiftKeyDown()) == (not not key.shift)
end

local function FillFromItem(id, link)
    if not editor or not id then return end
    local now = GetTime()
    if lastShortcutID == id and lastShortcutTime and now - lastShortcutTime < 0.05 then return end
    lastShortcutID, lastShortcutTime = id, now
    itemBox:SetText(ItemName(id) or (link and link:match("%[(.-)%]")) or tostring(id))
    itemBox.itemID = id
    itemBox.itemLink = link
    countBox:SetText("")
    hoverElapsed = 0
    editor:Show()
    -- A bag click can clear edit-box focus after its secure click handler returns.
    focusCountPending = id
end

local function BagItemClicked(button, mouseButton)
    if not editor or mouseButton ~= "LeftButton" or not ShortcutDown() then return end
    local bag = button.GetBagID and button:GetBagID()
    if bag == nil and button:GetParent() then bag = button:GetParent():GetID() end
    local slot = button:GetID()
    if bag == nil or slot == nil then return end
    local linkGetter = C_Container and C_Container.GetContainerItemLink or GetContainerItemLink
    local idGetter = C_Container and C_Container.GetContainerItemID or GetContainerItemID
    local link, id
    if linkGetter then
        local ok, result = pcall(linkGetter, bag, slot)
        if ok and Safe(result) and type(result) == "string" then link = result end
    end
    if idGetter then
        local ok, result = pcall(idGetter, bag, slot)
        if ok and Safe(result) and type(result) == "number" then id = result end
    end
    id = id or (link and tonumber(link:match("item:(%d+)")))
    FillFromItem(id, link)
end

local function ModifiedItemClicked(link, location)
    if not editor or not ShortcutDown() then return end
    -- Baganator passes an item link without an ItemLocation here.
    if location and location.IsBagAndSlot and not location:IsBagAndSlot() then return end
    if GetMouseButtonClicked and GetMouseButtonClicked() ~= "LeftButton" then return end
    if not Safe(link) or type(link) ~= "string" then return end
    FillFromItem(tonumber(link:match("item:(%d+)")), link)
end

local function HookBagClicks()
    if not hooksecurefunc then return end
    for _, name in ipairs({"ContainerFrameItemButton_OnClick", "ContainerFrameItemButton_OnModifiedClick"}) do
        if not bagHooked[name] and type(_G[name]) == "function" then
            hooksecurefunc(_G, name, BagItemClicked)
            bagHooked[name] = true
        end
    end
    if not bagHooked.HandleModifiedItemClick and type(HandleModifiedItemClick) == "function" then
        hooksecurefunc("HandleModifiedItemClick", ModifiedItemClicked)
        bagHooked.HandleModifiedItemClick = true
    end
end

local function Layout()
    if not handle then return end
    local width = UIParent:GetWidth()
    local position = math.max(WIDTH / 2, math.min(width - WIDTH / 2, width * db.position))
    handle:ClearAllPoints()
    handle:SetPoint("TOP", UIParent, "TOPLEFT", position, HANDLE_OVERSCAN)
    editor:ClearAllPoints()
    editor:SetPoint("TOP", handle, "TOP", 0, -HANDLE_OVERSCAN - HANDLE_GOLD_HEIGHT)
    panel:ClearAllPoints()
    if editor:IsShown() then
        panel:SetPoint("TOP", editor, "BOTTOM", 0, -PANEL_GAP)
    else
        panel:SetPoint("TOP", handle, "TOP", 0, -HANDLE_OVERSCAN - HANDLE_GOLD_HEIGHT - PANEL_GAP)
    end
end

function Addon:ResetPosition()
    if not db then return end
    db.position = 0.75
    Layout()
end

function Addon:ClearGoals()
    if not db then return end
    db.goals = {}
    bagCounts = {}
    self:Refresh()
end

local function MouseOver(frame)
    if not frame or not frame:IsShown() then return false end
    if frame.IsMouseOver then
        local ok, over = pcall(frame.IsMouseOver, frame)
        if ok and over then return true end
    end
    if MouseIsOver then
        local ok, over = pcall(MouseIsOver, frame)
        if ok and over then return true end
    end
    local focus = GetMouseFocus and GetMouseFocus()
    while focus do
        if focus == frame then return true end
        focus = focus.GetParent and focus:GetParent()
    end
    return false
end

local function CreateUI()
    if handle then return end
    handle = CreateFrame("Frame", "LH_FarmMeHandle", UIParent)
    handle:SetSize(HANDLE_WIDTH, HANDLE_HIT_HEIGHT)
    handle:SetFrameStrata("HIGH")
    local color = handle:CreateTexture(nil, "BACKGROUND")
    color:SetPoint("TOPLEFT", handle, "TOPLEFT", 0, -HANDLE_OVERSCAN)
    color:SetPoint("TOPRIGHT", handle, "TOPRIGHT", 0, -HANDLE_OVERSCAN)
    color:SetHeight(HANDLE_GOLD_HEIGHT)
    color:SetColorTexture(unpack(GOLD))
    handle:EnableMouse(true)
    handle:SetMovable(true)
    handle:RegisterForDrag("LeftButton")
    handle:SetScript("OnEnter", function() hoverElapsed = 0; editor:Show() end)
    handle:SetScript("OnDragStart", function(self) editor:Hide(); self:StartMoving() end)
    handle:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local center = self:GetCenter()
        if center then db.position = math.max(0, math.min(1, center / UIParent:GetWidth())) end
        Layout()
    end)

    editor = CreateFrame("Frame", "LH_FarmMeEditor", UIParent, "BackdropTemplate")
    editor:SetSize(WIDTH, 55)
    editor:SetFrameStrata("HIGH")
    editor:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8, insets = {left = 2, right = 2, top = 2, bottom = 2}})
    editor:SetBackdropColor(0.02, 0.025, 0.03, 0.94)
    editor:SetBackdropBorderColor(0.65, 0.59, 0.45, 1)
    editor:EnableMouse(true)
    local itemLabel = editor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    itemLabel:SetPoint("TOPLEFT", 12, -6)
    itemLabel:SetText("Item name or ID")
    local countLabel = editor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    countLabel:SetPoint("TOPLEFT", 230, -6)
    countLabel:SetText("Target")
    itemBox = CreateFrame("EditBox", nil, editor, "InputBoxTemplate")
    itemBox:SetSize(200, 20)
    itemBox:SetPoint("TOPLEFT", 14, -23)
    itemBox:SetAutoFocus(false)
    itemBox:SetScript("OnTextChanged", function(self, userInput)
        if userInput then self.itemID, self.itemLink = nil, nil end
    end)
    itemBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    itemBox:SetScript("OnEnterPressed", function() countBox:SetFocus() end)
    countBox = CreateFrame("EditBox", nil, editor, "InputBoxTemplate")
    countBox:SetSize(55, 20)
    countBox:SetPoint("TOPLEFT", 233, -23)
    countBox:SetAutoFocus(false)
    countBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    countBox:SetScript("OnEnterPressed", AddGoal)
    local button = CreateFrame("Button", nil, editor, "UIPanelButtonTemplate")
    button:SetSize(112, 24)
    button:SetPoint("TOPRIGHT", -12, -21)
    button:SetText("Farm Me!")
    button:SetScript("OnClick", AddGoal)
    editor:SetScript("OnUpdate", function(_, elapsed)
        if focusCountPending then
            local id = focusCountPending
            focusCountPending = false
            -- Shift-click can open Blizzard's stack-splitting dialog after our bag hook.
            if StackSplitFrame and StackSplitFrame:IsShown() then StackSplitFrame:Hide() end
            countBox:SetText(tostring(ItemCount(id)))
            countBox:SetFocus()
            countBox:HighlightText()
        end
        if itemBox:HasFocus() or countBox:HasFocus() or MouseOver(editor) or MouseOver(handle) then
            hoverElapsed = 0
            return
        end
        hoverElapsed = hoverElapsed + elapsed
        if hoverElapsed >= 0.35 then hoverElapsed = 0; editor:Hide() end
    end)
    editor:Hide()

    panel = CreateFrame("Frame", "LH_FarmMeGoals", UIParent)
    panel:SetSize(WIDTH, 1)
    panel:SetFrameStrata("MEDIUM")
    measureText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    measureText:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    measureText:SetAlpha(0)
    -- Goals stay under the gold handle while the input panel comes and goes.
    editor:HookScript("OnShow", function() panel:ClearAllPoints(); panel:SetPoint("TOP", editor, "BOTTOM", 0, -PANEL_GAP) end)
    editor:HookScript("OnHide", function()
        focusCountPending = false
        panel:ClearAllPoints()
        panel:SetPoint("TOP", handle, "TOP", 0, -HANDLE_OVERSCAN - HANDLE_GOLD_HEIGHT - PANEL_GAP)
    end)
    Layout()
    Addon:Refresh()
end

local function ScanBags()
    if not db then return end
    local changed = false
    for id, goal in pairs(db.goals) do
        local current = ItemCount(id)
        local previous = bagCounts[id]
        if previous ~= nil and current > previous then
            local gained = current - previous
            local old = goal.progress
            goal.progress = old + gained
            local row
            for _, candidate in ipairs(rows) do
                if candidate:IsShown() and candidate.itemID == id then row = candidate; break end
            end
            if row then
                local left = math.min(old, goal.target) / goal.target
                local right = math.min(goal.progress, goal.target) / goal.target
                if right > left then
                    local width = row.fill:GetWidth()
                    row.flash:ClearAllPoints()
                    row.flash:SetPoint("TOPLEFT", row.fill, "TOPLEFT", width * left, 0)
                    row.flash:SetPoint("BOTTOMRIGHT", row.fill, "BOTTOMLEFT", width * right, 0)
                    row.flash:SetAlpha(1)
                    row.flash:Show()
                    row.flashRemaining = 0.6
                end
            end
            if not goal.reached and goal.progress >= goal.target then
                goal.reached = true
                ShowToast(goal)
            end
            changed = true
        end
        bagCounts[id] = current
    end
    if changed then Addon:Refresh() end
end

local events = CreateFrame("Frame")
for _, event in ipairs({"ADDON_LOADED", "PLAYER_LOGIN", "BAG_UPDATE_DELAYED", "GET_ITEM_INFO_RECEIVED",
    "DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent", function(_, event, value)
    if event == "ADDON_LOADED" and value == addonName then
        if type(LH_FarmMeDB) ~= "table" then LH_FarmMeDB = {} end
        db = LH_FarmMeDB
        if type(db.goals) ~= "table" then db.goals = {} end
        if type(db.position) ~= "number" or db.position ~= db.position then db.position = 0.75 end
        db.position = math.max(0, math.min(1, db.position))
        if not shortcuts[db.clickShortcut] then db.clickShortcut = "ALT_SHIFT" end
        for id, goal in pairs(db.goals) do
            if type(id) ~= "number" or type(goal) ~= "table" or type(goal.target) ~= "number"
                or goal.target < 1 or type(goal.progress) ~= "number" then
                db.goals[id] = nil
            else
                goal.id = id
                goal.name = type(goal.name) == "string" and goal.name or ("Item " .. id)
                goal.reached = goal.reached == true or goal.progress >= goal.target
            end
        end
    elseif event == "PLAYER_LOGIN" then
        if not db then return end
        for id, goal in pairs(db.goals) do
            local current = ItemCount(id)
            bagCounts[id] = current
            -- Include items already carried by goals created with the older counting code.
            goal.progress = math.max(goal.progress, current)
            goal.reached = goal.progress >= goal.target
        end
        CreateUI()
        HookBagClicks()
    elseif event == "BAG_UPDATE_DELAYED" then
        ScanBags()
    elseif event == "GET_ITEM_INFO_RECEIVED" and db and db.goals[value] then
        local name = ItemName(value)
        if name then db.goals[value].name = name; Addon:Refresh() end
    elseif event == "DISPLAY_SIZE_CHANGED" or event == "UI_SCALE_CHANGED" then
        if db then Layout() end
    elseif event == "ADDON_LOADED" and value == "Blizzard_ContainerUI" then
        HookBagClicks()
    end
end)

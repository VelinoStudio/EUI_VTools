----------------------------------------------------------------------
--  EUI_VTools — 额外物品条设置页
--
--  布局：通用开关 → 快捷操作按钮 → 条选择 → 当前条配置（区块化）
--  弹窗：内容分组多选 / 自定义物品 / 黑名单（EUI 深色弹窗风格）
--  条切换时重建配置区，控件值经闭包实时读写数据库。
----------------------------------------------------------------------
local _, evt = ...
local EUI = evt.EUI
local UI = evt.UI
local L = evt.L
local EIB = evt.ExtraItemsBar

local ipairs = ipairs
local format = format
local tonumber = tonumber
local tinsert = tinsert

-- 前置声明（ShowSyncAppearancePopup 早于定义处调用）
local MakeMiniCheck
local MakeScrollArea
local MakeActionButton
local ShowPopup
local ShowGroupPopup
local ShowSyncAppearancePopup
local ShowCustomItemsPopup

local FONT_PATH = (EUI and EUI.EXPRESSWAY) or "Fonts\\FRIZQT__.TTF"

-- 内容分组展示顺序（include 字符串按此顺序写回；CUSTOM 不是 ModuleList 的键，由代码特殊处理）
local GROUP_ORDER = {
    "QUEST", "EQUIP",
    "POTION", "ELIXIR", "FLASK", "RUNE", "VANTUS",
    "FOOD", "FOODVENDOR", "MAGEFOOD",
    "FISHING", "UTILITY", "OPENABLE",
    "PROF", "SEEDS", "DELVE", "HOLIDAY",
}

local currentBar = 1

local function BarDB()
    local db = evt.db.profile.extraItemsBar
    return db, db and db["bar" .. currentBar]
end

----------------------------------------------------------------------
--  自绘控件：行式输入框（EUI 行风格：左标签 + 右深色输入框）
--  tooltip：通过 OnEnter/OnLeave 管理，避免立即常驻显示。
----------------------------------------------------------------------
local function MakeInputRow(parent, y, label, getValue, onSave, boxW, tooltip)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(parent:GetWidth() - UI.PAGE_PAD_X * 2, 50)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", UI.PAGE_PAD_X, y)

    local lbl = UI.MakeFont(frame, 14, 1, 1, 1, 0.9)
    lbl:SetPoint("LEFT", frame, "LEFT", 20, 0)
    lbl:SetText(L(label))

    boxW = boxW or 260
    local boxHolder = CreateFrame("Frame", nil, frame)
    boxHolder:SetSize(boxW, 26)
    boxHolder:SetPoint("RIGHT", frame, "RIGHT", -20, 0)
    UI.SolidTex(boxHolder, "BACKGROUND", 0, 0, 0, 0.4):SetAllPoints()
    UI.ApplyBorder(boxHolder, 1, 1, 1, 0.2)

    local eb = CreateFrame("EditBox", nil, boxHolder)
    eb:SetAllPoints()
    eb:SetFont(FONT_PATH, 12, "")
    eb:SetTextColor(1, 1, 1, 0.95)
    eb:SetJustifyH("LEFT")
    eb:SetAutoFocus(false)
    eb:SetTextInsets(8, 8, 0, 0)
    eb:SetText(getValue() or "")

    eb:SetScript("OnEscapePressed", function(self)
        self:SetText(getValue() or "")
        self:ClearFocus()
    end)
    eb:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        onSave(self:GetText())
    end)

    -- tooltip：行级悬停显示
    if tooltip then
        frame:SetScript("OnEnter", function()
            UI.ShowTip(frame, L(label), tooltip)
        end)
        frame:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end

    return frame, 50
end

----------------------------------------------------------------------
--  自绘控件：迷你勾选行（弹窗内用）
----------------------------------------------------------------------
function MakeMiniCheck(parent, x, y, w, label, getValue, setValue)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(w, 24)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)

    local box = CreateFrame("Frame", nil, row)
    box:SetSize(14, 14)
    box:SetPoint("LEFT", row, "LEFT", 4, 0)
    UI.SolidTex(box, "BACKGROUND", 0, 0, 0, 0.5):SetAllPoints()
    UI.ApplyBorder(box, 1, 1, 1, 0.35)
    local check = UI.SolidTex(box, "OVERLAY", 0.29, 0.8, 1, 1)
    check:SetSize(8, 8)
    check:SetPoint("CENTER", box, "CENTER", 0, 0)

    local lbl = UI.MakeFont(row, 12, 0.9, 0.9, 0.9, 1)
    lbl:SetPoint("LEFT", box, "RIGHT", 6, 0)
    lbl:SetJustifyH("LEFT")
    lbl:SetText(label)

    local function Apply()
        if getValue() then
            check:Show()
        else
            check:Hide()
        end
    end
    Apply()

    row:SetScript("OnClick", function()
        setValue(not getValue())
        Apply()
    end)
    row:SetScript("OnEnter", function()
        lbl:SetTextColor(1, 1, 1, 1)
    end)
    row:SetScript("OnLeave", function()
        lbl:SetTextColor(0.9, 0.9, 0.9, 1)
    end)

    return row
end

----------------------------------------------------------------------
--  自绘控件：滚轮滚动区
----------------------------------------------------------------------
function MakeScrollArea(parent, x, y, width, height)
    local viewport = CreateFrame("Frame", nil, parent)
    viewport:SetSize(width, height)
    viewport:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    viewport:SetClipsChildren(true)
    viewport:EnableMouseWheel(true)

    local content = CreateFrame("Frame", nil, viewport)
    content:SetSize(width, 1)
    content:SetPoint("TOPLEFT", viewport, "TOPLEFT", 0, 0)

    viewport:SetScript("OnMouseWheel", function(_, delta)
        local maxOffset = math.max(0, content:GetHeight() - height)
        local _, _, _, _, cy = content:GetPoint(1)
        local offset = math.max(0, math.min(maxOffset, -(cy or 0) - delta * 30))
        content:SetPoint("TOPLEFT", viewport, "TOPLEFT", 0, -offset)
    end)

    return viewport, content
end

----------------------------------------------------------------------
--  弹窗管理（单例，深色 + 边框，父级为 EUI 主面板）
----------------------------------------------------------------------
local popup

local function EnsurePopup()
    if popup then return popup end

    local owner = (EUI and EUI._mainFrame) or UIParent
    local f = CreateFrame("Frame", nil, owner)
    f:SetSize(520, 620)
    f:SetPoint("CENTER", owner, "CENTER", 0, 0)
    f:SetFrameLevel(owner:GetFrameLevel() + 200)
    f:Hide()

    UI.SolidTex(f, "BACKGROUND", 0.04, 0.04, 0.05, 0.97):SetAllPoints()
    UI.ApplyBorder(f, 1, 1, 1, 0.22)

    local title = UI.MakeFont(f, 15, 1, 1, 1, 1)
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -16)

    local close = CreateFrame("Button", nil, f)
    close:SetSize(26, 26)
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, -12)
    local closeLbl = UI.MakeFont(close, 14, 1, 1, 1, 0.8)
    closeLbl:SetAllPoints()
    closeLbl:SetText("X")
    close:SetScript("OnClick", function() f:Hide() end)
    close:SetScript("OnEnter", function() closeLbl:SetAlpha(1) end)
    close:SetScript("OnLeave", function() closeLbl:SetAlpha(0.8) end)

    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -50)
    content:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -50)
    content:SetHeight(550)

    f._title = title
    f._content = content

    popup = f
    return popup
end

function ShowPopup(titleKey, buildFn)
    local f = EnsurePopup()
    f._title:SetText(L(titleKey))

    -- 清空旧内容
    local old = f._content
    for _, child in ipairs({ old:GetChildren() }) do
        child:Hide()
        child:SetParent(nil)
    end

    buildFn(old)
    f:Show()
end

----------------------------------------------------------------------
--  弹窗：内容分组多选
----------------------------------------------------------------------
local function ParseInclude(include)
    local set = {}
    for _, key in ipairs({ strsplit(",", include or "") }) do
        key = key:gsub("%s+", "")
        if key ~= "" then set[key] = true end
    end
    return set
end

function ShowGroupPopup()
    local _, barDB = BarDB()

    ShowPopup("Content Groups", function(content)
        local set = ParseInclude(barDB.include)

        -- 顶部提示
        local tip = UI.MakeFont(content, 12, 0.7, 0.7, 0.7, 1)
        tip:SetPoint("TOPLEFT", content, "TOPLEFT", UI.PAGE_PAD_X, -4)
        tip:SetPoint("RIGHT", content, "RIGHT", -UI.PAGE_PAD_X, 0)
        tip:SetJustifyH("LEFT")
        tip:SetWordWrap(true)
        tip:SetText(L("Pick the item groups shown on this bar. Items matching any selected group are included."))

        local viewport, list = MakeScrollArea(content, UI.PAGE_PAD_X, -85,
            content:GetWidth() - UI.PAGE_PAD_X * 2, 440)

        local colW = (viewport:GetWidth() - 12) / 3
        local y, col = -4, 1
        for _, key in ipairs(GROUP_ORDER) do
            MakeMiniCheck(list, (col - 1) * colW, y, colW, L(key),
                function() return set[key] == true end,
                function(v)
                    set[key] = v or nil
                    -- 按展示顺序写回 include 串
                    local parts = {}
                    for _, k in ipairs(GROUP_ORDER) do
                        if set[k] then tinsert(parts, k) end
                    end
                    -- 手动填写的 SLOT: 语法原样保留
                    local known = {}
                    for _, k in ipairs(GROUP_ORDER) do known[k] = true end
                    local extras = {}
                    for k in pairs(set) do
                        if not known[k] then tinsert(extras, k) end
                    end
                    table.sort(extras)
                    for _, k in ipairs(extras) do
                        tinsert(parts, k)
                    end
                    barDB.include = table.concat(parts, ",")
                    EIB.UpdateBar(currentBar)
                end)
            if col % 3 == 0 then
                y = y - 26
                col = 1
            else
                col = col + 1
            end
        end
        list:SetHeight(math.abs(y) + 30)
    end)
end

----------------------------------------------------------------------
--  弹窗：当前条自定义物品 ID 列表（per-bar，与内容分组 OR 关系）
----------------------------------------------------------------------
function ShowCustomItemsPopup()
    local _, barDB = BarDB()
    if not barDB.customList then barDB.customList = {} end

    ShowPopup("Custom Items", function(content)
        local tip = UI.MakeFont(content, 12, 0.7, 0.7, 0.7, 1)
        tip:SetPoint("TOPLEFT", content, "TOPLEFT", UI.PAGE_PAD_X, -4)
        tip:SetPoint("RIGHT", content, "RIGHT", -UI.PAGE_PAD_X, 0)
        tip:SetJustifyH("LEFT")
        tip:SetWordWrap(true)
        tip:SetText(L("Enter item IDs you want to show on this bar. Items from this list are added in addition to content groups (OR relation)."))

        local inputHolder = CreateFrame("Frame", nil, content)
        inputHolder:SetSize(220, 26)
        inputHolder:SetPoint("TOPLEFT", content, "TOPLEFT", UI.PAGE_PAD_X, -46)
        UI.SolidTex(inputHolder, "BACKGROUND", 0, 0, 0, 0.4):SetAllPoints()
        UI.ApplyBorder(inputHolder, 1, 1, 1, 0.2)

        local input = CreateFrame("EditBox", nil, inputHolder)
        input:SetAllPoints()
        input:SetFont(FONT_PATH, 12, "")
        input:SetTextColor(1, 1, 1, 0.95)
        input:SetJustifyH("LEFT")
        input:SetAutoFocus(false)
        input:SetTextInsets(8, 8, 0, 0)
        input:SetNumeric(true)

        local function RebuildList(list)
            for _, child in ipairs({ list:GetChildren() }) do
                child:Hide()
                child:SetParent(nil)
            end
            local ids = {}
            for id in pairs(barDB.customList) do tinsert(ids, id) end
            table.sort(ids, function(a, b) return a < b end)

            local y = -2
            for _, id in ipairs(ids) do
                local row = CreateFrame("Frame", nil, list)
                row:SetSize(list:GetWidth(), 30)
                row:SetPoint("TOPLEFT", list, "TOPLEFT", 0, y)

                local name = (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)) or ("ID " .. id)
                local lbl = UI.MakeFont(row, 12, 0.9, 0.9, 0.9, 1)
                lbl:SetPoint("LEFT", row, "LEFT", 8, 0)
                lbl:SetJustifyH("LEFT")
                lbl:SetText(format("%d. %s", id, name))

                local del = CreateFrame("Button", nil, row)
                del:SetSize(24, 20)
                del:SetPoint("RIGHT", row, "RIGHT", -4, 0)
                local delLbl = UI.MakeFont(del, 11, 1, 0.35, 0.35, 0.9)
                delLbl:SetAllPoints()
                delLbl:SetText(L("Delete"))
                del:SetScript("OnClick", function()
                    barDB.customList[id] = nil
                    EIB.UpdateBar(currentBar)
                    RebuildList(list)
                end)

                y = y - 32
            end
            list:SetHeight(math.abs(y) + 10)
        end

        local viewport, list = MakeScrollArea(content, UI.PAGE_PAD_X, -82,
            content:GetWidth() - UI.PAGE_PAD_X * 2, 440)

        local addBtn = CreateFrame("Button", nil, inputHolder:GetParent())
        addBtn:SetSize(72, 26)
        addBtn:SetPoint("LEFT", inputHolder, "RIGHT", 4, 0)
        UI.SolidTex(addBtn, "BACKGROUND", 0.2, 0.25, 0.3, 0.6):SetAllPoints()
        UI.ApplyBorder(addBtn, 0.5, 0.5, 0.5, 0.25)
        local addLbl = UI.MakeFont(addBtn, 12, 1, 1, 1, 1)
        addLbl:SetAllPoints()
        addLbl:SetText(L("Add"))
        addBtn:SetScript("OnClick", function()
            local txt = input:GetText()
            local id = txt and tonumber(strmatch(txt, "%d+"))
            if id and id > 0 then
                barDB.customList[id] = true
                input:SetText("")
                EIB.UpdateBar(currentBar)
                RebuildList(list)
            end
        end)
        input:SetScript("OnEnterPressed", function() addBtn:GetScript("OnClick")() end)

        RebuildList(list)
    end)
end

----------------------------------------------------------------------
--  弹窗：条间外观同步（深拷贝所有视觉键到选中的条）
----------------------------------------------------------------------
local APPEARANCE_KEYS = {
    -- 条背景
    "bgEnabled", "bgColor", "bgOpacity", "bgPadding",
    "bgBorderTexture", "bgBorderThickness", "bgBorderColor", "bgBorderClassColor",
    -- 按钮边框
    "btnBorderTexture", "btnBorderThickness", "btnBorderColor", "btnBorderClassColor",
    -- 形状与图标
    "buttonShape", "iconZoom", "showBlizzIconBg", "blizzIconBgAlpha",
    -- 槽位底
    "slotBgColor", "slotBgOpacity",
    -- 按钮尺寸与排列
    "buttonWidth", "buttonHeight", "numButtons", "buttonsPerRow", "spacing", "anchor",
    -- 淡入淡出
    "mouseOver", "fadeTime", "alphaMin", "alphaMax",
    -- 文本
    "showCount", "showBind", "showQualityTier", "qualityTierSize",
    -- 字体样式（快捷键 / 数量 / 冷却 三套）
    "keybindFont", "countFont", "cooldownFont",
}

-- 深拷贝 barDB 的视觉键到 targetDB；忽略 nil 值（目标保持自身默认）
local function DeepCopy(v)
    if type(v) ~= "table" then return v end
    local copy = {}
    for ck, cv in pairs(v) do copy[ck] = DeepCopy(cv) end
    return copy
end

local function CopyAppearance(fromDB, toDB)
    for _, k in ipairs(APPEARANCE_KEYS) do
        local v = fromDB[k]
        if v ~= nil then
            toDB[k] = DeepCopy(v)
        end
    end
end

function ShowSyncAppearancePopup()
    local db = evt.db.profile.extraItemsBar
    local _, srcDB = BarDB()

    ShowPopup("Sync Appearance", function(content)
        local tip = UI.MakeFont(content, 12, 0.7, 0.7, 0.7, 1)
        tip:SetPoint("TOPLEFT", content, "TOPLEFT", UI.PAGE_PAD_X, -4)
        tip:SetPoint("RIGHT", content, "RIGHT", -UI.PAGE_PAD_X, 0)
        tip:SetJustifyH("LEFT")
        tip:SetWordWrap(true)
        tip:SetText(L("Copy visual settings from Bar %d to the selected bars below. Button contents, visibility and position are not affected."):format(currentBar))

        local barLabels = {}
        for i = 1, 5 do
            barLabels[("bar%d"):format(i)] = L(("Bar %d"):format(i))
        end

        local y = -44
        local selected = {}
        for i = 1, 5 do
            local key = ("bar%d"):format(i)
            selected[key] = (i ~= currentBar)  -- 默认选中其他条
            MakeMiniCheck(content, UI.PAGE_PAD_X, y, 180, L(("Bar %d"):format(i)),
                function() return selected[key] end,
                function(v) selected[key] = v end)
            y = y - 26
        end

        local applyBtn = MakeActionButton(content, 140, L("Apply Sync"), function()
            local count = 0
            for i = 1, 5 do
                local key = ("bar%d"):format(i)
                if selected[key] and db[key] then
                    CopyAppearance(srcDB, db[key])
                    EIB.UpdateBar(i)
                    count = count + 1
                end
            end
            popup:Hide()
            if count > 0 then
                print(string.format("|cff4accff[EVT]|r Appearance synced from Bar %d to %d bar(s).", currentBar, count))
            end
        end, L("Sync"), L("Copy all visual settings from the current bar to the selected bars."))
        applyBtn:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -UI.PAGE_PAD_X, 12)
    end)
end

----------------------------------------------------------------------
--  弹窗：物品列表（自定义物品 / 黑名单共用）
----------------------------------------------------------------------
local function ShowListPopup(titleKey, listKey, helpKey)
    local db = evt.db.profile.extraItemsBar

    ShowPopup(titleKey, function(content)
        local tip = UI.MakeFont(content, 12, 0.7, 0.7, 0.7, 1)
        tip:SetPoint("TOPLEFT", content, "TOPLEFT", UI.PAGE_PAD_X, -4)
        tip:SetPoint("RIGHT", content, "RIGHT", -UI.PAGE_PAD_X, 0)
        tip:SetJustifyH("LEFT")
        tip:SetWordWrap(true)
        tip:SetText(L(helpKey))

        -- 添加行：输入框 + 添加按钮
        local inputHolder = CreateFrame("Frame", nil, content)
        inputHolder:SetSize(220, 26)
        inputHolder:SetPoint("TOPLEFT", content, "TOPLEFT", UI.PAGE_PAD_X, -46)
        UI.SolidTex(inputHolder, "BACKGROUND", 0, 0, 0, 0.4):SetAllPoints()
        UI.ApplyBorder(inputHolder, 1, 1, 1, 0.2)

        local input = CreateFrame("EditBox", nil, inputHolder)
        input:SetAllPoints()
        input:SetFont(FONT_PATH, 12, "")
        input:SetTextColor(1, 1, 1, 0.95)
        input:SetJustifyH("LEFT")
        input:SetAutoFocus(false)
        input:SetTextInsets(8, 8, 0, 0)
        input:SetNumeric(true)

        local function RebuildList(list)
            -- 清空
            for _, child in ipairs({ list:GetChildren() }) do
                child:Hide()
                child:SetParent(nil)
            end
            local ids = {}
            for id in pairs(db[listKey]) do
                tinsert(ids, id)
            end
            table.sort(ids, function(a, b) return a < b end)

            local y = -2
            for _, id in ipairs(ids) do
                local row = CreateFrame("Frame", nil, list)
                row:SetSize(list:GetWidth(), 30)
                row:SetPoint("TOPLEFT", list, "TOPLEFT", 0, y)

                local name = (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)) or ("ID " .. id)
                local lbl = UI.MakeFont(row, 12, 0.9, 0.9, 0.9, 1)
                lbl:SetPoint("LEFT", row, "LEFT", 8, 0)
                lbl:SetJustifyH("LEFT")
                lbl:SetText(format("%d. %s", id, name))

                local del = CreateFrame("Button", nil, row)
                del:SetSize(24, 20)
                del:SetPoint("RIGHT", row, "RIGHT", -4, 0)
                local delLbl = UI.MakeFont(del, 11, 1, 0.35, 0.35, 0.9)
                delLbl:SetAllPoints()
                delLbl:SetText(L("Delete"))
                del:SetScript("OnClick", function()
                    db[listKey][id] = nil
                    if listKey == "customList" then
                        EIB.UpdateBars()
                    end
                    RebuildList(list)
                end)
                del:SetScript("OnEnter", function() delLbl:SetAlpha(1) end)
                del:SetScript("OnLeave", function() delLbl:SetAlpha(0.9) end)

                y = y - 32
            end
            list:SetHeight(math.abs(y) + 10)
        end

        local viewport, list = MakeScrollArea(content, UI.PAGE_PAD_X, -82,
            content:GetWidth() - UI.PAGE_PAD_X * 2, 430)

        local addBtn = CreateFrame("Button", nil, content)
        addBtn:SetSize(70, 26)
        addBtn:SetPoint("LEFT", inputHolder, "RIGHT", 10, 0)
        UI.SolidTex(addBtn, "BACKGROUND", 1, 1, 1, 0.06):SetAllPoints()
        UI.ApplyBorder(addBtn, 1, 1, 1, 0.25)
        local addLbl = UI.MakeFont(addBtn, 12, 1, 1, 1, 0.9)
        addLbl:SetAllPoints()
        addLbl:SetText(L("Add"))
        addBtn:SetScript("OnClick", function()
            local id = tonumber(input:GetText())
            if id and id > 0 then
                db[listKey][id] = true
                input:SetText("")
                if listKey == "customList" then
                    EIB.UpdateBars()
                end
                RebuildList(list)
            end
        end)

        input:SetScript("OnEnterPressed", function()
            addBtn:GetScript("OnClick")()
        end)

        RebuildList(list)
    end)
end

----------------------------------------------------------------------
--  自绘控件：平面操作按钮（弹窗/操作行用，可动态改文本）
--  tooltip 可选：悬停时显示。
----------------------------------------------------------------------
function MakeActionButton(parent, width, label, onClick, tooltipTitle, tooltipText)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(width, 30)

    local bg = UI.SolidTex(btn, "BACKGROUND", 1, 1, 1, 0.06)
    bg:SetAllPoints()
    UI.ApplyBorder(btn, 1, 1, 1, 0.25)
    local lbl = UI.MakeFont(btn, 12, 1, 1, 1, 0.9)
    lbl:SetAllPoints()
    lbl:SetText(label)

    btn:SetScript("OnClick", onClick)
    btn:SetScript("OnEnter", function()
        bg:SetColorTexture(1, 1, 1, 0.12)
        lbl:SetAlpha(1)
        if tooltipTitle then
            UI.ShowTip(btn, tooltipTitle, tooltipText)
        end
    end)
    btn:SetScript("OnLeave", function()
        bg:SetColorTexture(1, 1, 1, 0.06)
        lbl:SetAlpha(0.9)
        GameTooltip:Hide()
    end)

    btn._label = lbl
    return btn
end

----------------------------------------------------------------------
--  每条配置区（条切换时重建）
----------------------------------------------------------------------
local buildBarSection  -- 前置声明（递归重建用）

local function RebuildBarSection(section)
    -- 清空旧内容
    for _, child in ipairs({ section:GetChildren() }) do
        child:Hide()
        child:SetParent(nil)
    end
    section:SetHeight(math.abs(buildBarSection(section)))
end

buildBarSection = function(section)
    local W = EUI.Widgets
    if not W then return 60 end

    local _, barDB = BarDB()
    local y = -UI.PAGE_PAD_Y

    -- 内容来源
    local _, h = W:SectionHeader(section, L("Content"), y)
    y = y - h

    row, rowH = W:DualRow(section, y, {
        type = "button",
        text = L("Content Groups"),
        width = 240,
        onClick = ShowGroupPopup,
    }, {
        type = "button",
        text = L("Custom Items"),
        width = 240,
        onClick = function() ShowCustomItemsPopup() end,
    })
    y = y - rowH - 4

    -- 布局
    _, h = W:SectionHeader(section, L("Layout"), y)
    y = y - h

    row, rowH = W:DualRow(section, y, {
        type = "slider",
        text = L("Number of Buttons"),
        min = 1, max = 12, step = 1,
        getValue = function() return barDB.numButtons end,
        setValue = function(v)
            barDB.numButtons = math.floor(v)
            EIB.UpdateBar(currentBar)
        end,
    }, {
        type = "slider",
        text = L("Buttons Per Row"),
        min = 1, max = 12, step = 1,
        getValue = function() return barDB.buttonsPerRow end,
        setValue = function(v)
            barDB.buttonsPerRow = math.floor(v)
            EIB.UpdateBar(currentBar)
        end,
    })
    y = y - rowH

    row, rowH = W:DualRow(section, y, {
        type = "slider",
        text = L("Button Width"),
        min = 20, max = 100, step = 1,
        getValue = function() return barDB.buttonWidth end,
        setValue = function(v)
            barDB.buttonWidth = math.floor(v)
            EIB.UpdateBar(currentBar)
        end,
    }, {
        type = "slider",
        text = L("Button Height"),
        min = 20, max = 100, step = 1,
        getValue = function() return barDB.buttonHeight end,
        setValue = function(v)
            barDB.buttonHeight = math.floor(v)
            EIB.UpdateBar(currentBar)
        end,
    })
    y = y - rowH

    row, rowH = W:DualRow(section, y, {
        type = "slider",
        text = L("Spacing"),
        min = 0, max = 20, step = 1,
        getValue = function() return barDB.spacing end,
        setValue = function(v)
            barDB.spacing = math.floor(v)
            EIB.UpdateBar(currentBar)
        end,
    }, {
        type = "dropdown",
        text = L("Anchor"),
        values = {
            TOPLEFT = L("Top Left"),
            TOPRIGHT = L("Top Right"),
            BOTTOMLEFT = L("Bottom Left"),
            BOTTOMRIGHT = L("Bottom Right"),
        },
        order = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" },
        getValue = function() return barDB.anchor end,
        setValue = function(v)
            barDB.anchor = v
            EIB.UpdateBar(currentBar)
        end,
    })
    y = y - rowH

    -- 条间外观同步
    row, rowH = W:WideButton(section, L("Sync Appearance to Other Bars"), y,
        ShowSyncAppearancePopup, 360)
    -- tooltip: 列出会同步的内容范围
    row:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L("Sync Appearance to Other Bars"), 1, 0.85, 0.4, 1)
        GameTooltip:AddLine(L("Syncs all visual settings except content."), 1, 1, 1, true)
        GameTooltip:AddLine(L("Included: colors, borders, shapes, spacing, size, fonts, visibility."), 0.7, 0.9, 1, true)
        GameTooltip:AddLine(L("NOT included: enable, include (content groups), customList, blackList, pos, numButtons."), 1, 0.55, 0.55, true)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    y = y - rowH - 8

    -------------------------------------------------------------------
    --  BAR BACKGROUND（与 EUI 原生动作条设置一致）
    -------------------------------------------------------------------
    _, h = W:SectionHeader(section, L("BAR BACKGROUND"), y)
    y = y - h

    -- Enable toggle + Background Spacing
    row, rowH = W:DualRow(section, y, {
        type = "toggle",
        text = L("Enable Bar Background"),
        getValue = function() return barDB.bgEnabled end,
        setValue = function(v)
            barDB.bgEnabled = v
            EIB.UpdateBar(currentBar)
        end,
    }, {
        type = "slider",
        text = L("Background Spacing"),
        min = 0, max = 20, step = 1,
        getValue = function() return barDB.bgPadding or 0 end,
        setValue = function(v)
            barDB.bgPadding = math.floor(v)
            EIB.UpdateBar(currentBar)
        end,
    })
    y = y - rowH

    -- Background Color + Background Opacity
    row, rowH = W:DualRow(section, y, {
        type = "colorpicker",
        text = L("Background Color"),
        hasAlpha = false,
        getValue = function()
            local c = barDB.bgColor or { r = 0, g = 0, b = 0, a = 0.5 }
            return c.r, c.g, c.b, 1
        end,
        setValue = function(r, g, b)
            local old = barDB.bgColor or { a = 0.5 }
            barDB.bgColor = { r = r, g = g, b = b, a = old.a or 0.5 }
            EIB.UpdateBar(currentBar)
        end,
    }, {
        type = "slider",
        text = L("Background Opacity"),
        min = 0, max = 100, step = 1,
        getValue = function() return barDB.bgOpacity or 50 end,
        setValue = function(v)
            barDB.bgOpacity = math.floor(v)
            EIB.UpdateBar(currentBar)
        end,
    })
    y = y - rowH

    -- Border Style + Border Size
    local borderTexValues, borderTexOrder
    if EllesmereUI and EllesmereUI.GetBorderTextureDropdown then
        borderTexValues, borderTexOrder = EllesmereUI.GetBorderTextureDropdown()
    else
        borderTexValues = { solid = L("Solid") }
        borderTexOrder = { "solid" }
    end

    local borderThicknessLabels = {
        none = L("None"), thin = L("Thin"), normal = L("Normal"),
        heavy = L("Heavy"), strong = L("Strong"),
    }
    local borderThicknessOrder = { "none", "thin", "normal", "heavy", "strong" }

    -- 自定义按钮形状（与 EUI 原生动作条一致）
    local shapeLabels = {
        none = L("None"), cropped = L("Cropped"),
        square = L("Square"), circle = L("Circle"), csquare = L("Curved Square"),
        diamond = L("Diamond"), hexagon = L("Hexagon"), portrait = L("Portrait"), shield = L("Shield"),
    }
    local shapeOrder = { "none", "cropped", "square", "circle", "csquare", "diamond", "hexagon", "portrait", "shield" }
    local shapeZoomDefault = {
        none = 5.5, cropped = 2, square = 6.0, circle = 6.0, csquare = 6.0,
        diamond = 6.0, hexagon = 6.0, portrait = 6.0, shield = 6.0,
    }

    row, rowH = W:DualRow(section, y, {
        type = "dropdown",
        text = L("Border Style"),
        values = borderTexValues,
        order = borderTexOrder,
        getValue = function() return barDB.bgBorderTexture or "solid" end,
        setValue = function(v)
            barDB.bgBorderTexture = v
            EIB.UpdateBar(currentBar)
        end,
    }, {
        type = "dropdown",
        text = L("Border Size"),
        values = borderThicknessLabels,
        order = borderThicknessOrder,
        getValue = function() return barDB.bgBorderThickness or "none" end,
        setValue = function(v)
            barDB.bgBorderThickness = v
            EIB.UpdateBar(currentBar)
        end,
    })
    y = y - rowH

    -- Border Color + Class Color toggle
    row, rowH = W:DualRow(section, y, {
        type = "colorpicker",
        text = L("Border Color"),
        hasAlpha = true,
        getValue = function()
            local c = barDB.bgBorderColor or { r = 0, g = 0, b = 0, a = 1 }
            return c.r, c.g, c.b, c.a
        end,
        setValue = function(r, g, b, a)
            barDB.bgBorderColor = { r = r, g = g, b = b, a = a }
            EIB.UpdateBar(currentBar)
        end,
    }, {
        type = "toggle",
        text = L("Use Class Color"),
        getValue = function() return barDB.bgBorderClassColor end,
        setValue = function(v)
            barDB.bgBorderClassColor = v
            EIB.UpdateBar(currentBar)
        end,
    })
    y = y - rowH

    -------------------------------------------------------------------
    --  ICONS（按钮图标皮肤，与 EUI 原生动作条 ICONS 区块一致）
    -------------------------------------------------------------------
    _, h = W:SectionHeader(section, L("Icons"), y)
    y = y - h

    -- 按钮边框样式 + 边框大小
    row, rowH = W:DualRow(section, y, {
        type = "dropdown",
        text = L("Border Style"),
        values = borderTexValues,
        order = borderTexOrder,
        getValue = function() return barDB.btnBorderTexture or "solid" end,
        setValue = function(v)
            barDB.btnBorderTexture = v
            EIB.UpdateBar(currentBar)
        end,
    }, {
        type = "dropdown",
        text = L("Border Size"),
        values = borderThicknessLabels,
        order = borderThicknessOrder,
        getValue = function() return barDB.btnBorderThickness or "thin" end,
        setValue = function(v)
            barDB.btnBorderThickness = v
            EIB.UpdateBar(currentBar)
        end,
    })
    y = y - rowH

    -- 按钮边框颜色 + 职业色开关
    row, rowH = W:DualRow(section, y, {
        type = "colorpicker",
        text = L("Border Color"),
        hasAlpha = true,
        getValue = function()
            local c = barDB.btnBorderColor or { r = 0, g = 0, b = 0, a = 1 }
            return c.r, c.g, c.b, c.a
        end,
        setValue = function(r, g, b, a)
            barDB.btnBorderColor = { r = r, g = g, b = b, a = a }
            EIB.UpdateBar(currentBar)
        end,
    }, {
        type = "toggle",
        text = L("Use Class Color"),
        getValue = function() return barDB.btnBorderClassColor end,
        setValue = function(v)
            barDB.btnBorderClassColor = v
            EIB.UpdateBar(currentBar)
        end,
    })
    y = y - rowH

    -- 图标缩放（独立行，EUI 原生也是单独一行）
    row, rowH = W:DualRow(section, y, {
        type = "slider",
        text = L("Icon Zoom"),
        min = 0, max = 10, step = 0.5,
        getValue = function() return barDB.iconZoom or 5.5 end,
        setValue = function(v)
            barDB.iconZoom = v
            EIB.UpdateBar(currentBar)
        end,
    }, nil)
    y = y - rowH

    -- 自定义按钮形状（切换时同步 EUI 行为：形状默认缩放 + 边框厚度）
    row, rowH = W:DualRow(section, y, {
        type = "dropdown",
        text = L("Custom Button Shape"),
        values = shapeLabels,
        order = shapeOrder,
        getValue = function() return barDB.buttonShape or "none" end,
        setValue = function(v)
            barDB.buttonShape = v
            barDB.iconZoom = shapeZoomDefault[v] or 5.5
            if v ~= "none" and v ~= "cropped" then
                barDB.btnBorderThickness = "strong"
            else
                barDB.btnBorderThickness = "thin"
            end
            EIB.UpdateBar(currentBar)
            RebuildBarSection(section)
        end,
    }, nil)
    y = y - rowH

    -- 图标背景颜色 + 图标背景不透明度
    row, rowH = W:DualRow(section, y, {
        type = "colorpicker",
        text = L("Icon Background"),
        hasAlpha = false,
        getValue = function()
            local c = barDB.slotBgColor or { r = 0.15, g = 0.15, b = 0.15 }
            return c.r, c.g, c.b, 1
        end,
        setValue = function(r, g, b)
            barDB.slotBgColor = { r = r, g = g, b = b }
            EIB.UpdateBar(currentBar)
        end,
    }, {
        type = "slider",
        text = L("Icon Background Opacity"),
        min = 0, max = 100, step = 1,
        getValue = function() return barDB.slotBgOpacity or 50 end,
        setValue = function(v)
            barDB.slotBgOpacity = math.floor(v)
            EIB.UpdateBar(currentBar)
        end,
    })
    y = y - rowH

    -- 暴雪图标背景（空槽底纹）开关 + 不透明度
    row, rowH = W:DualRow(section, y, {
        type = "toggle",
        text = L("Show Blizzard Icon Background"),
        getValue = function() return barDB.showBlizzIconBg end,
        setValue = function(v)
            barDB.showBlizzIconBg = v and true or false
            EIB.UpdateBar(currentBar)
        end,
    }, {
        type = "slider",
        text = L("Blizzard Icon Background Alpha"),
        min = 0, max = 100, step = 1,
        getValue = function() return barDB.blizzIconBgAlpha or 100 end,
        setValue = function(v)
            barDB.blizzIconBgAlpha = math.floor(v)
            EIB.UpdateBar(currentBar)
        end,
    })
    y = y - rowH

    -- 显示冷却倒计时数字（全局 CVar，与 EUI 动作条一致）
    row, rowH = W:DualRow(section, y, {
        type = "toggle",
        text = L("Show Cooldown Numbers"),
        getValue = function()
            local cv = GetCVar and GetCVar("countdownForCooldowns")
            return cv ~= "0"
        end,
        setValue = function(v)
            barDB.showCooldownText = v and true or false
            if SetCVar then SetCVar("countdownForCooldowns", v and "1" or "0") end
        end,
    }, nil)
    y = y - rowH

    -- 显示
    _, h = W:SectionHeader(section, L("Display"), y)
    y = y - h

    row, rowH = W:DualRow(section, y, {
        type = "toggle",
        text = L("Mouse Over Fade"),
        getValue = function() return barDB.mouseOver end,
        setValue = function(v)
            barDB.mouseOver = v
            EIB.UpdateBar(currentBar)
        end,
        tooltip = L("Fade the bar out when the mouse leaves and fade in on hover."),
    }, {
        type = "toggle",
        text = L("Tooltip"),
        getValue = function() return barDB.tooltip end,
        setValue = function(v)
            barDB.tooltip = v
        end,
    })
    y = y - rowH

    row, rowH = W:DualRow(section, y, {
        type = "slider",
        text = L("Min Alpha"),
        min = 0, max = 1, step = 0.05,
        getValue = function() return barDB.alphaMin end,
        setValue = function(v)
            barDB.alphaMin = v
            EIB.UpdateBar(currentBar)
        end,
    }, {
        type = "slider",
        text = L("Max Alpha"),
        min = 0, max = 1, step = 0.05,
        getValue = function() return barDB.alphaMax end,
        setValue = function(v)
            barDB.alphaMax = v
            EIB.UpdateBar(currentBar)
        end,
    })
    y = y - rowH

    row, rowH = W:Slider(section, L("Fade Time"), y,
        0, 1, 0.05,
        function() return barDB.fadeTime end,
        function(v) barDB.fadeTime = v end)
    y = y - rowH - 4

    -- 文本与角标
    _, h = W:SectionHeader(section, L("Texts & Icons"), y)
    y = y - h

    row, rowH = W:DualRow(section, y, {
        type = "toggle",
        text = L("Show Count"),
        getValue = function() return barDB.showCount end,
        setValue = function(v)
            barDB.showCount = v
            EIB.UpdateBar(currentBar)
        end,
    }, {
        type = "toggle",
        text = L("Show Key Bindings"),
        getValue = function() return barDB.showBind end,
        setValue = function(v)
            barDB.showBind = v
            EIB.UpdateBar(currentBar)
            EIB.UpdateBinding()
        end,
    })
    y = y - rowH

    row, rowH = W:DualRow(section, y, {
        type = "toggle",
        text = L("Show Quality Tier"),
        getValue = function() return barDB.showQualityTier end,
        setValue = function(v)
            barDB.showQualityTier = v
            EIB.UpdateBar(currentBar)
        end,
    }, {
        type = "slider",
        text = L("Quality Tier Size"),
        min = 10, max = 24, step = 1,
        getValue = function() return barDB.qualityTierSize end,
        setValue = function(v)
            barDB.qualityTierSize = math.floor(v)
            EIB.UpdateBar(currentBar)
        end,
    })
    y = y - rowH - 4

    -------------------------------------------------------------------
    --  FONTS & TEXT（快捷键 / 数量 / 冷却 三套独立字体设置）
    -------------------------------------------------------------------
    -- 字体下拉：LSM 字体列表 + EUI/游戏默认
    local fontValues, fontOrder
    do
        local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
        fontValues = {}; fontOrder = {}
        if LSM then
            for _, name in ipairs(LSM:List("font")) do
                fontValues[name] = name
                fontOrder[#fontOrder + 1] = name
            end
        end
        fontValues[""] = "Expressway (EUI Default)"
        fontValues["default"] = "WoW Default"
        tinsert(fontOrder, 1, "")
        tinsert(fontOrder, 2, "default")
    end

    local anchorValues = {
        TOPLEFT = L("Top Left"), TOPRIGHT = L("Top Right"),
        BOTTOMLEFT = L("Bottom Left"), BOTTOMRIGHT = L("Bottom Right"),
        TOP = L("Top"), BOTTOM = L("Bottom"), CENTER = L("Center"),
        [""] = L("Individual Default"),
    }
    local anchorOrder = { "", "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT", "TOP", "BOTTOM", "CENTER" }

    -- 构建一套字体设置（标题 + 字体/大小 + 颜色/职业色 + 描边/锚点 + XY 偏移）
    local function BuildFontBlock(cfgKey, titleKey, maxSize)
        local cfg = barDB[cfgKey]
        if not cfg then
            cfg = {}
            barDB[cfgKey] = cfg
        end
        local function changed() EIB.UpdateBar(currentBar) end

        _, h = W:SectionHeader(section, L(titleKey), y)
        y = y - h

        row, rowH = W:DualRow(section, y, {
            type = "dropdown",
            text = L("Font"),
            values = fontValues,
            order = fontOrder,
            getValue = function() return cfg.family or "" end,
            setValue = function(v) cfg.family = (v == "") and nil or v; changed() end,
        }, {
            type = "slider",
            text = L("Font Size"),
            min = 6, max = maxSize or 28, step = 1,
            getValue = function() return cfg.size or 12 end,
            setValue = function(v) cfg.size = math.floor(v); changed() end,
        })
        y = y - rowH

        row, rowH = W:DualRow(section, y, {
            type = "colorpicker",
            text = L("Font Color"),
            getValue = function()
                local c = cfg.color or {}
                return c.r, c.g, c.b, (c.a or 1)
            end,
            setValue = function(r, g, b, a)
                cfg.color = { r = r, g = g, b = b, a = a }; changed()
            end,
        }, {
            type = "toggle",
            text = L("Use Class Color"),
            getValue = function() return cfg.classColor end,
            setValue = function(v) cfg.classColor = v; changed() end,
        })
        y = y - rowH

        row, rowH = W:DualRow(section, y, {
            type = "toggle",
            text = L("Outline"),
            getValue = function() return cfg.outline end,
            setValue = function(v) cfg.outline = v; changed() end,
        }, {
            type = "dropdown",
            text = L("Text Anchor"),
            values = anchorValues,
            order = anchorOrder,
            getValue = function() return cfg.anchor or "" end,
            setValue = function(v) cfg.anchor = (v == "") and nil or v; changed() end,
        })
        y = y - rowH

        row, rowH = W:DualRow(section, y, {
            type = "slider",
            text = L("Offset X"),
            min = -20, max = 20, step = 1,
            getValue = function() return cfg.offsetX or 0 end,
            setValue = function(v) cfg.offsetX = math.floor(v); changed() end,
        }, {
            type = "slider",
            text = L("Offset Y"),
            min = -20, max = 20, step = 1,
            getValue = function() return cfg.offsetY or 0 end,
            setValue = function(v) cfg.offsetY = math.floor(v); changed() end,
        })
        y = y - rowH - 4
    end

    BuildFontBlock("keybindFont", "Keybind Text")
    BuildFontBlock("countFont", "Count Text")
    BuildFontBlock("cooldownFont", "Cooldown Text", 40)

    -- 可见性：EUI 风格下拉预设（去掉高级宏输入框）
    _, h = W:SectionHeader(section, L("Visibility"), y)
    y = y - h

    local visModes = {
        ["show"]                     = L("Always"),
        ["hide"]                     = L("Hide"),
        ["[combat]show;hide"]        = L("In Combat"),
        ["[combat]hide;show"]        = L("Out of Combat"),
        ["[petbattle]hide;show"]     = L("Hide in Pet Battle"),
    }
    local visOrder = { "show", "hide", "[combat]show;hide", "[combat]hide;show", "[petbattle]hide;show" }

    row, rowH = W:DualRow(section, y, {
        type = "dropdown",
        text = L("Visibility"),
        values = visModes,
        order = visOrder,
        getValue = function() return barDB.visibility end,
        setValue = function(v)
            barDB.visibility = v
            EIB.UpdateBar(currentBar)
        end,
    }, nil)
    y = y - rowH

    return y
end

----------------------------------------------------------------------
--  页面构建
----------------------------------------------------------------------
function evt.Pages.BuildExtraItemsPage(parent)
    local W = EUI.Widgets
    local y = -UI.PAGE_PAD_Y

    if not W then
        local err = UI.MakeFont(parent, 16, 1, 0.3, 0.3, 1)
        err:SetPoint("TOPLEFT", parent, "TOPLEFT", UI.PAGE_PAD_X, y)
        err:SetText("EllesmereUI.Widgets not available")
        return y - 40
    end

    local db = evt.db.profile.extraItemsBar

    -- 通用区块
    local _, h = W:SectionHeader(parent, "General", y)
    y = y - h

    local row, rowH = W:DualRow(parent, y, {
        type = "toggle",
        text = L("Enable Extra Items Bar"),
        getValue = function() return db.enable end,
        setValue = function(v)
            db.enable = v
            EIB.EnsureInitialized()
            EIB.UpdateBars()
        end,
        tooltip = L("Show quick-use buttons for quest items, consumables and more."),
    }, {
        type = "toggle",
        text = L("Exclude Quantum Items"),
        getValue = function() return db.noQuantumItems end,
        setValue = function(v)
            db.noQuantumItems = v
            EIB.UpdateBars()
        end,
        tooltip = L("Hide quantum curio items from all bars."),
    })
    y = y - rowH - 4

    -- 快捷操作
    row, rowH = W:WideDualButton(parent, L("Custom Items"), L("Blacklist"), y, function()
        ShowListPopup("Custom Items", "customList", "Custom Items Help")
    end, function()
        ShowListPopup("Blacklist", "blackList", "Blacklist Help")
    end, 240)
    y = y - rowH - 4

    -- 条选择区块
    _, h = W:SectionHeader(parent, "Bar", y)
    y = y - h

    -- 前置声明：barSection 在下方才创建，但 dropdown 的 setValue 闭包需要引用它
    local barSection

    row, rowH = W:WideDropdown(parent, L("Bar"), y, {
        bar1 = L("Bar 1"),
        bar2 = L("Bar 2"),
        bar3 = L("Bar 3"),
        bar4 = L("Bar 4"),
        bar5 = L("Bar 5"),
    }, function() return "bar" .. currentBar end,
    function(v)
        currentBar = tonumber(strmatch(v, "%d+")) or 1
        if barSection then RebuildBarSection(barSection) end
    end, { "bar1", "bar2", "bar3", "bar4", "bar5" }, 440)
    y = y - rowH - 4

    row, rowH = W:DualRow(parent, y, {
        type = "toggle",
        text = L("Enable This Bar"),
        getValue = function()
            local _, barDB = BarDB()
            return barDB and barDB.enable
        end,
        setValue = function(v)
            local _, barDB = BarDB()
            if barDB then
                barDB.enable = v
                EIB.EnsureInitialized()
                EIB.UpdateBar(currentBar)
            end
        end,
    }, nil)
    y = y - rowH - 4

    -- 绑定 / 移动操作行
    local actionRow = CreateFrame("Frame", nil, parent)
    actionRow:SetSize(parent:GetWidth() - UI.PAGE_PAD_X * 2, 34)
    actionRow:SetPoint("TOPLEFT", parent, "TOPLEFT", UI.PAGE_PAD_X, y)

    local bindBtn = MakeActionButton(actionRow, 240, L("Enter Binding Mode"), function()
        if EIB.IsBinding() then
            EIB.StopBinding()
        else
            EIB.EnsureInitialized()
            EIB.StartBinding(currentBar)
        end
    end, L("Bind Keys"),
        L("Hover a bar button and press any key to bind it. ESC while hovering clears its bindings, ESC otherwise exits."))
    bindBtn:SetPoint("LEFT", actionRow, "LEFT", 0, 0)

    local moveBtn = MakeActionButton(actionRow, 240, L("Move in Unlock Mode"), function()
        if EUI and EUI._openUnlockMode then
            if popup then popup:Hide() end
            C_Timer.After(0, EUI._openUnlockMode)
        end
    end, L("Move in Unlock Mode"), L("Open EUI unlock mode to drag the bars."))
    moveBtn:SetPoint("LEFT", bindBtn, "RIGHT", 16, 0)

    -- 绑定模式状态同步按钮文本
    EIB.OnBindingChanged = function(active)
        bindBtn._label:SetText(active and L("Exit Binding Mode") or L("Enter Binding Mode"))
    end

    y = y - 38

    -- 当前条配置区（条切换时整体重建）
    local yTop = y - 8
    barSection = CreateFrame("Frame", nil, parent)
    -- 关键：显式设置宽度。仅靠 TOPLEFT+TOPRIGHT 锚点时，GetWidth() 在布局完成前返回 0，
    -- 会导致 DualRow/MakeInputRow 算出负宽度，所有控件塌缩到左侧。
    barSection:SetWidth(parent:GetWidth())
    barSection:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yTop)
    barSection:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, yTop)
    local sectionH = buildBarSection(barSection)
    -- buildBarSection 返回负 y（WoW 向下为负），高度取绝对值
    barSection:SetHeight(math.abs(sectionH))
    y = yTop + sectionH   -- sectionH 为负，等价于 yTop - |sectionH|

    return y
end

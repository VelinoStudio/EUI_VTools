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

local FONT_PATH = (EUI and EUI.EXPRESSWAY) or "Fonts\\FRIZQT__.TTF"

-- 内容分组展示顺序（include 字符串按此顺序写回）
local GROUP_ORDER = {
    "QUEST", "EQUIP", "CUSTOM",
    "POTION", "POTIONGN", "POTIONLEG", "POTIONSL", "POTIONDF", "POTIONTWW", "POTIONMN",
    "FLASK", "FLASKLEG", "FLASKSL", "FLASKDF", "FLASKTWW", "FLASKMN",
    "RUNE", "RUNETWW", "RUNEMN",
    "VANTUS", "VANTUSTWW", "VANTUSMN",
    "FOOD", "FOODTWW", "FOODMN", "FOODVENDOR", "MAGEFOOD",
    "FISHING", "FISHINGTWW", "FISHINGMN",
    "BANNER", "UTILITY", "OPENABLE",
    "PROF", "PROFTWW", "PROFMN",
    "SEEDS", "BIGDIG", "DELVE", "HOLIDAY",
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
local function MakeMiniCheck(parent, x, y, w, label, getValue, setValue)
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
local function MakeScrollArea(parent, x, y, width, height)
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

local function ShowPopup(titleKey, buildFn)
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

local function ShowGroupPopup()
    local _, barDB = BarDB()

    ShowPopup("Content Groups", function(content)
        local set = ParseInclude(barDB.include)

        -- 顶部提示
        local tip = UI.MakeFont(content, 12, 0.7, 0.7, 0.7, 1)
        tip:SetPoint("TOPLEFT", content, "TOPLEFT", UI.PAGE_PAD_X, -4)
        tip:SetPoint("RIGHT", content, "RIGHT", -UI.PAGE_PAD_X, 0)
        tip:SetJustifyH("LEFT")
        tip:SetWordWrap(true)
        tip:SetText(L("Pick the item groups shown on this bar. Use the advanced include field for SLOT syntax."))

        local viewport, list = MakeScrollArea(content, UI.PAGE_PAD_X, -50,
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
local function MakeActionButton(parent, width, label, onClick, tooltipTitle, tooltipText)
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
    local _, h = W:SectionHeader(section, "Content", y)
    y = y - h

    local row, rowH = W:WideButton(section, L("Content Groups"), y, function()
        ShowGroupPopup()
    end, 240)
    y = y - rowH - 4

    row, rowH = MakeInputRow(section, y, "Advanced Include",
        function() return barDB.include end,
        function(text)
            barDB.include = text
            EIB.UpdateBar(currentBar)
        end,
        300, L("Comma separated groups. SLOT:n / SLOT:n-m adds usable equipment slots."))
    y = y - rowH - 4

    -- 布局
    _, h = W:SectionHeader(section, "Layout", y)
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
        type = "slider",
        text = L("Backdrop Spacing"),
        min = 0, max = 20, step = 1,
        getValue = function() return barDB.backdropSpacing end,
        setValue = function(v)
            barDB.backdropSpacing = math.floor(v)
            EIB.UpdateBar(currentBar)
        end,
    })
    y = y - rowH

    row, rowH = W:DualRow(section, y, {
        type = "dropdown",
        text = L("Anchor"),
        values = {
            TOPLEFT = "Top Left",
            TOPRIGHT = "Top Right",
            BOTTOMLEFT = "Bottom Left",
            BOTTOMRIGHT = "Bottom Right",
        },
        order = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" },
        getValue = function() return barDB.anchor end,
        setValue = function(v)
            barDB.anchor = v
            EIB.UpdateBar(currentBar)
        end,
    }, {
        type = "toggle",
        text = L("Backdrop"),
        getValue = function() return barDB.backdrop end,
        setValue = function(v)
            barDB.backdrop = v
            EIB.UpdateBar(currentBar)
        end,
    })
    y = y - rowH

    -- 边框样式 + 边框大小（与 EUI 原生动作条边框设置一致）
    row, rowH = W:DualRow(section, y, {
        type = "dropdown",
        text = L("Border Style"),
        values = { none = "None", solid = "Solid" },
        order = { "none", "solid" },
        getValue = function() return barDB.borderStyle or "solid" end,
        setValue = function(v)
            barDB.borderStyle = v
            EIB.UpdateBar(currentBar)
        end,
    }, {
        type = "slider",
        text = L("Border Size"),
        min = 1, max = 5, step = 1,
        getValue = function() return barDB.borderSize or 1 end,
        setValue = function(v)
            barDB.borderSize = math.floor(v)
            EIB.UpdateBar(currentBar)
        end,
    })
    y = y - rowH

    -- 显示
    _, h = W:SectionHeader(section, "Display", y)
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
    _, h = W:SectionHeader(section, "Texts & Icons", y)
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

    -- 可见性：仅保留高级宏条件输入（去掉下拉预设）
    _, h = W:SectionHeader(section, "Visibility", y)
    y = y - h

    row, rowH = MakeInputRow(section, y, "Visibility Macro",
        function() return barDB.visibility end,
        function(text)
            barDB.visibility = text
            EIB.UpdateBar(currentBar)
        end,
        300, L("Standard macro visibility conditions, e.g. [petbattle]hide;show."))
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
        bar1 = "Bar 1",
        bar2 = "Bar 2",
        bar3 = "Bar 3",
        bar4 = "Bar 4",
        bar5 = "Bar 5",
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

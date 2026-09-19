----------------------------------------------------------------------
--  EUI_VTools — 额外物品条（移植自 ElvUI_WindTools ExtraItemsBar，按 evt/EUI 风格清洗）
--
--  机制概要：
--  * 每条由 anchor（解锁模式移动目标）+ bar（背景）+ 12 个宏安全按钮组成；
--  * include 逗号串驱动内容源：物品分组 key / QUEST / EQUIP / SLOT:n / CUSTOM；
--  * 按钮点击通过 SecureActionButtonTemplate 的 macrotext 使用物品，战斗外刷新；
--  * 位置由 EUI 解锁模式管理（RegisterUnlockElements），尺寸调整映射到按钮大小；
--  * 绑定模式：设置页开启后悬停按钮按键即绑定，ESC 清除/退出。
----------------------------------------------------------------------
local _, evt = ...
local EUI = evt.EUI
local UI = evt.UI

local EIB = {}
evt.ExtraItemsBar = EIB

----------------------------------------------------------------------
--  局部化高频 API
----------------------------------------------------------------------
local ceil = ceil
local format = format
local ipairs = ipairs
local pairs = pairs
local sort = sort
local strmatch = strmatch
local strsplit = strsplit
local tinsert = tinsert
local tonumber = tonumber
local wipe = wipe

local CreateFrame = CreateFrame
local CreateAtlasMarkup = CreateAtlasMarkup
local GameTooltip = GameTooltip
local GetBindingKey = GetBindingKey
local GetInventoryItemCooldown = GetInventoryItemCooldown
local GetInventoryItemID = GetInventoryItemID
local GetQuestLogSpecialItemCooldown = GetQuestLogSpecialItemCooldown
local GetQuestLogSpecialItemInfo = GetQuestLogSpecialItemInfo
local GetTime = GetTime
local InCombatLockdown = InCombatLockdown
local RegisterStateDriver = RegisterStateDriver
local UnregisterStateDriver = UnregisterStateDriver

local C_Item_GetItemCooldown = C_Item.GetItemCooldown
local C_Item_GetItemCount = C_Item.GetItemCount
local C_Item_GetItemInfoInstant = C_Item.GetItemInfoInstant
local C_Item_IsItemInRange = C_Item.IsItemInRange
local C_Item_IsUsableItem = C_Item.IsUsableItem
local C_QuestLog_GetDistanceSqToQuest = C_QuestLog.GetDistanceSqToQuest
local C_QuestLog_GetNumQuestLogEntries = C_QuestLog.GetNumQuestLogEntries
local C_QuestLog_GetQuestIDForLogIndex = C_QuestLog.GetQuestIDForLogIndex
local C_TradeSkillUI_GetItemReagentQualityInfo = C_TradeSkillUI.GetItemReagentQualityInfo

local FONT_PATH = (EUI and EUI.EXPRESSWAY) or "Fonts\\FRIZQT__.TTF"

-- 每条物理按钮上限（与原版一致）
local MAX_BUTTONS = 12
-- 命名按钮前缀：绑定命令 CLICK <name>:LeftButton 依赖此命名
local BUTTON_PREFIX = "EVT_ExtraItemsBar"

----------------------------------------------------------------------
--  数据库访问（经函数读取，兼容 profile 切换）
--  若 profile 中尚无 extraItemsBar（旧存档未合并新 defaults），手动补建最小结构，
--  避免 db["bar"..id] 索引 nil 导致整个 boot 脚本崩溃、条无法创建。
----------------------------------------------------------------------
local function DefaultBar(id)
    return {
        enable = (id == 1),
        include = "QUEST,POTION,FOOD,EQUIP,BANNER,PROFMN,HOLIDAY,OPENABLE,DELVE",
        visibility = "[petbattle]hide;show",
        numButtons = 12, buttonsPerRow = 12,
        buttonWidth = 35, buttonHeight = 30,
        spacing = 3, backdropSpacing = 3,
        backdrop = true, anchor = "TOPLEFT",
        borderStyle = "solid", borderSize = 1,
        mouseOver = false, fadeTime = 0.3,
        alphaMin = 0, alphaMax = 1,
        tooltip = true,
        showCount = true, showBind = true,
        showQualityTier = true, qualityTierSize = 16,
        pos = nil,
    }
end

local function DB()
    local p = evt.db.profile
    if not p.extraItemsBar then
        p.extraItemsBar = {
            enable = true, noQuantumItems = false,
            customList = {}, blackList = {},
        }
        for i = 1, 5 do
            p.extraItemsBar["bar" .. i] = DefaultBar(i)
        end
    end
    -- 逐条补齐缺失字段（向前兼容旧 profile）
    for i = 1, 5 do
        local b = p.extraItemsBar["bar" .. i]
        if not b then
            p.extraItemsBar["bar" .. i] = DefaultBar(i)
        else
            local d = DefaultBar(i)
            for k, v in pairs(d) do
                if b[k] == nil then b[k] = v end
            end
        end
    end
    return p.extraItemsBar
end
EIB.DB = DB

----------------------------------------------------------------------
--  状态缓存（地下堡 / 量子物品开关），Data.lua 提供 STATE 与检查表
----------------------------------------------------------------------
EIB.StateCache = {}

local function UpdateState(state)
    if state == EIB.STATE.IN_DELVE then
        local difficulty = select(3, GetInstanceInfo())
        EIB.StateCache[state] = (difficulty == 208)
    elseif state == EIB.STATE.QUANTUM_ITEM_ALLOWED then
        local db = DB()
        EIB.StateCache[state] = not (db and db.noQuantumItems)
    end
end

local function GetState(state)
    local result = EIB.StateCache[state]
    if result == nil then return true end
    return result
end
EIB.GetState = GetState

----------------------------------------------------------------------
--  任务物品 / 已装备可用物品列表
----------------------------------------------------------------------
local questItemList = {}

local function UpdateQuestItemList()
    wipe(questItemList)
    for questLogIndex = 1, C_QuestLog_GetNumQuestLogEntries() do
        local link = GetQuestLogSpecialItemInfo(questLogIndex)
        if link then
            local questID = C_QuestLog_GetQuestIDForLogIndex(questLogIndex)
            local distance = questID and C_QuestLog_GetDistanceSqToQuest(questID)
            local itemID = C_Item_GetItemInfoInstant(link)
            tinsert(questItemList, { questLogIndex = questLogIndex, itemID = itemID, distance = distance or 1e8 })
        end
    end
    sort(questItemList, function(a, b)
        return a.distance < b.distance
    end)
end

-- 即使 C_Item.IsUsableItem 返回 false 也强制显示的装备
local forceUsableItems = {
    [193634] = true, -- 茂發種子
    [206448] = true, --『夢境裂斧』菲拉雷斯
}

local equipmentList = {}

local function UpdateEquipmentList()
    wipe(equipmentList)
    for slotID = 1, 18 do
        local itemID = GetInventoryItemID("player", slotID)
        if itemID and (C_Item_IsUsableItem(itemID) or forceUsableItems[itemID]) then
            tinsert(equipmentList, slotID)
        end
    end
end

-- SLOT:n / SLOT:n-m 过滤解析
local function ParseSlotFilter(slotStr)
    if not slotStr or slotStr == "" then return nil end

    local allowedSlots = {}
    local rangeStart, rangeEnd = strmatch(slotStr, "^(%d+)-(%d+)$")
    if rangeStart and rangeEnd then
        rangeStart, rangeEnd = tonumber(rangeStart), tonumber(rangeEnd)
        if rangeStart <= rangeEnd then
            for slotID = rangeStart, rangeEnd do
                if slotID >= 1 and slotID <= 18 then allowedSlots[slotID] = true end
            end
        end
    else
        local slotID = tonumber(slotStr)
        if slotID and slotID >= 1 and slotID <= 18 then allowedSlots[slotID] = true end
    end

    return next(allowedSlots) and allowedSlots or nil
end

-- 战斗中被跳过的刷新：脱战后补一次
local UpdateAfterCombat = { false, false, false, false, false }

----------------------------------------------------------------------
--  按键显示美化（BUTTON3 → M3 等）
----------------------------------------------------------------------
local function PrettyKey(key)
    if not key or key == "" then return "" end
    key = key:gsub("MOUSEWHEELUP", "MUp")
    key = key:gsub("MOUSEWHEELDOWN", "MDown")
    key = key:gsub("BUTTON(%d+)", "M%1")
    key = key:gsub("NUMPAD", "N")
    key = key:gsub("PLUS", "+"):gsub("MINUS", "-"):gsub("MULTIPLY", "*"):gsub("DIVIDE", "/")
    return key
end
EIB.PrettyKey = PrettyKey

----------------------------------------------------------------------
--  按钮
----------------------------------------------------------------------
local function CreateButton(name, barDB, index)
    local button = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")
    button.buttonIndex = index
    button:SetSize(barDB.buttonWidth, barDB.buttonHeight)
    button:SetClampedToScreen(true)
    button:SetAttribute("type", "macro")
    button:EnableMouse(false)
    button:RegisterForClicks("AnyUp")

    -- 深色底 + 1px 内缩图标 + 1px 边框（EUI 风格自绘，不用 BackdropTemplate）
    local bg = UI.SolidTex(button, "BACKGROUND", 0, 0, 0, 0.35)
    bg:SetAllPoints()

    local tex = button:CreateTexture(nil, "ARTWORK")
    tex:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
    tex:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local hover = UI.SolidTex(button, "HIGHLIGHT", 1, 1, 1, 0.12)
    hover:SetAllPoints()
    hover:Hide()

    UI.ApplyBorder(button, 1, 1, 1, 0.25)

    -- 制造品质角标（制造业物品）
    local qualityTier = button:CreateFontString(nil, "OVERLAY")
    qualityTier:SetFont(FONT_PATH, barDB.qualityTierSize or 16, "OUTLINE")
    qualityTier:SetTextColor(1, 1, 1, 1)
    qualityTier:SetPoint("TOPLEFT", button, "TOPLEFT")
    qualityTier:SetJustifyH("CENTER")

    -- 数量
    local count = button:CreateFontString(nil, "OVERLAY")
    count:SetFont(FONT_PATH, 12, "OUTLINE")
    count:SetTextColor(1, 1, 1, 1)
    count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT")
    count:SetJustifyH("CENTER")

    -- 按键绑定提示
    local bind = button:CreateFontString(nil, "OVERLAY")
    bind:SetFont(FONT_PATH, 12, "OUTLINE")
    bind:SetTextColor(0.6, 0.6, 0.6)
    bind:SetPoint("TOPRIGHT", button, "TOPRIGHT")
    bind:SetJustifyH("CENTER")

    local cooldown = CreateFrame("Cooldown", name .. "Cooldown", button, "CooldownFrameTemplate")
    cooldown:SetDrawBling(false)
    cooldown:SetDrawSwipe(true)

    button.tex = tex
    button.hover = hover
    button.qualityTier = qualityTier
    button.count = count
    button.bind = bind
    button.cooldown = cooldown

    button:SetScript("OnEnter", function()
        -- 绑定模式下记录悬停目标（按键即绑定）
        if EIB._bindingActive then
            EIB._hoveredButton = button
        end
        hover:Show()

        local bar = button:GetParent()
        local db = DB()
        local barDB = db and db["bar" .. bar.id]
        if barDB and barDB.tooltip then
            GameTooltip:SetOwner(button, "ANCHOR_BOTTOMRIGHT", 0, -2)
            GameTooltip:ClearLines()
            if button.slotID then
                GameTooltip:SetInventoryItem("player", button.slotID)
            elseif button.itemID then
                GameTooltip:SetItemByID(button.itemID)
            end
            GameTooltip:Show()
        end
    end)

    button:SetScript("OnLeave", function()
        if EIB._hoveredButton == button then
            EIB._hoveredButton = nil
        end
        hover:Hide()
        GameTooltip:Hide()
    end)

    return button
end

-- 填充按钮内容（物品或装备槽）
local function SetUpButton(button, itemData, slotID)
    button.itemName = nil
    button.itemID = nil
    button.slotID = nil
    button.questLogIndex = nil
    button.countText = nil

    if itemData then
        button.itemID = itemData.itemID
        button.questLogIndex = itemData.questLogIndex
        button.countText = C_Item_GetItemCount(button.itemID, nil, true)

        local _, _, _, _, _, _, _, _, _, icon = GetItemInfo(button.itemID)
        button.tex:SetTexture(icon)
        button.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        local qualityInfo = C_TradeSkillUI_GetItemReagentQualityInfo(button.itemID)
        if qualityInfo and qualityInfo.icon and qualityInfo.icon ~= "" then
            button.qualityTier:SetText(CreateAtlasMarkup(qualityInfo.icon))
        else
            button.qualityTier:SetText("")
        end
    elseif slotID then
        button.slotID = slotID
        local itemID = GetInventoryItemID("player", slotID)
        if itemID then
            local _, _, _, _, _, _, _, _, _, icon = GetItemInfo(itemID)
            button.tex:SetTexture(icon)
            button.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            button.qualityTier:SetText("")
        end
    end

    -- 数量文本
    if button.countText and button.countText > 1 then
        button.count:SetText(button.countText)
    else
        button.count:SetText("")
    end

    -- 冷却 / 射程着色
    if button.itemID then
        button:SetScript("OnUpdate", function()
            local start, duration, enable
            if button.questLogIndex and button.questLogIndex > 0 then
                start, duration, enable = GetQuestLogSpecialItemCooldown(button.questLogIndex)
            else
                start, duration, enable = C_Item_GetItemCooldown(button.itemID)
            end
            if start and duration and duration > 0 then
                button.cooldown:SetCooldown(start, duration)
            else
                button.cooldown:Clear()
            end
            if duration and duration > 0 and enable and enable == 0 then
                button.tex:SetVertexColor(0.4, 0.4, 0.4)
            elseif not InCombatLockdown() and C_Item_IsItemInRange(button.itemID, "target") == false then
                button.tex:SetVertexColor(1, 0, 0)
            else
                button.tex:SetVertexColor(1, 1, 1)
            end
        end)
    elseif button.slotID then
        button:SetScript("OnUpdate", function()
            local start, duration = GetInventoryItemCooldown("player", button.slotID)
            if start and duration and duration > 0 then
                button.cooldown:SetCooldown(start, duration)
            else
                button.cooldown:Clear()
            end
        end)
    else
        button:SetScript("OnUpdate", nil)
    end

    -- 宏属性（战斗外）
    if not InCombatLockdown() then
        button:EnableMouse(true)
        button:Show()
        local macroText
        if button.slotID then
            macroText = "/use " .. button.slotID
        elseif button.itemName or button.itemID then
            macroText = "/use item:" .. button.itemID
            if button.itemID == 172347 then
                -- 军团时空裂痕钥匙：使用后自动开箱
                macroText = macroText .. "\n/use 5"
            end
        end
        if macroText then
            button:SetAttribute("macrotext", macroText)
        end
    end
end

-- 按按钮宽高比裁剪图标
local function UpdateButtonSize(button, barDB)
    button:SetSize(barDB.buttonWidth, barDB.buttonHeight)
    local left, right, top, bottom = 0.08, 0.92, 0.08, 0.92
    if barDB.buttonWidth > barDB.buttonHeight then
        local offset = (bottom - top) * (1 - barDB.buttonHeight / barDB.buttonWidth) / 2
        top = top + offset
        bottom = bottom - offset
    elseif barDB.buttonWidth < barDB.buttonHeight then
        local offset = (right - left) * (1 - barDB.buttonWidth / barDB.buttonHeight) / 2
        left = left + offset
        right = right - offset
    end
    button.tex:SetTexCoord(left, right, top, bottom)
end

----------------------------------------------------------------------
--  物品校验：黑名单 / 状态检查表 / 数量阈值
----------------------------------------------------------------------
local function ValidateItem(itemID)
    if not itemID then return false end

    local db = DB()
    if db.blackList[itemID] then return false end

    local stateKey = EIB.StateCheckList[itemID]
    if stateKey and not GetState(stateKey) then return false end

    local count = C_Item_GetItemCount(itemID)
    local threshold = EIB.CountThreshold[itemID] or 1
    if not count or count < threshold then return false end

    return true
end

----------------------------------------------------------------------
--  创建一条（anchor + bar + 12 按钮）
----------------------------------------------------------------------
local bars = {}

-- anchor 默认位置（无保存位置时使用，自左向右纵向排列在屏幕下方）
local function ApplyAnchorPosition(id)
    local anchor = bars[id] and bars[id].anchor
    if not anchor then return end
    local db = DB()
    local pos = db and db["bar" .. id] and db["bar" .. id].pos
    anchor:ClearAllPoints()
    if pos and pos.point then
        anchor:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
    else
        -- 默认居屏幕中央偏下，便于首次发现
        anchor:SetPoint("CENTER", UIParent, "CENTER", (id - 3) * 130, -180)
    end
end

local function CreateBar(id)
    local db = DB()
    local barDB = db["bar" .. id]
    if not barDB then return end

    local anchor = CreateFrame("Frame", BUTTON_PREFIX .. id .. "Anchor", UIParent)
    anchor:SetClampedToScreen(true)
    anchor:SetSize(200, 40)
    anchor:SetMovable(true)
    anchor.id = id
    ApplyAnchorPosition(id)

    -- anchor 自身加一层极淡背景：空条时也能在屏幕上看到位置（解锁模式与调试用）
    local anchorBg = UI.SolidTex(anchor, "BACKGROUND", 0, 0, 0, 0.2)
    anchorBg:SetAllPoints()
    UI.ApplyBorder(anchor, 1, 1, 1, 0.1)

    local bar = CreateFrame("Frame", BUTTON_PREFIX .. id, anchor, "SecureHandlerStateTemplate")
    bar.id = id
    bar:SetPoint(barDB.anchor, anchor, barDB.anchor, 0, 0)
    bar:SetSize(200, 40)
    bar:SetFrameStrata("LOW")

    -- 可开关的条背景（深色底）
    local barBg = UI.SolidTex(bar, "BACKGROUND", 0, 0, 0, 0.35)
    barBg:SetAllPoints()
    bar.barBg = barBg

    -- 边框：4 条纹理，厚度由 borderSize 控制，显隐由 borderStyle 控制
    local function makeEdge(...)
        local t = bar:CreateTexture(nil, "OVERLAY")
        t:SetColorTexture(1, 1, 1, 0.2)
        return t
    end
    bar.borderTop = makeEdge()
    bar.borderBottom = makeEdge()
    bar.borderLeft = makeEdge()
    bar.borderRight = makeEdge()

    bar.buttons = {}
    for i = 1, MAX_BUTTONS do
        bar.buttons[i] = CreateButton(BUTTON_PREFIX .. id .. "Button" .. i, barDB, i)
        bar.buttons[i]:SetParent(bar)
        bar.buttons[i]:Hide()
    end

    -- 悬停淡入淡出（条级 alpha）
    bar:SetScript("OnEnter", function()
        local d = DB()
        local bd = d and d["bar" .. id]
        if bd and bd.mouseOver then
            UIFrameFadeIn(bar, bd.fadeTime or 0.3, bar:GetAlpha(), bd.alphaMax or 1)
        end
    end)
    bar:SetScript("OnLeave", function()
        local d = DB()
        local bd = d and d["bar" .. id]
        if bd and bd.mouseOver then
            UIFrameFadeOut(bar, bd.fadeTime or 0.3, bar:GetAlpha(), bd.alphaMin or 0)
        end
    end)

    bars[id] = bar
    return bar
end

EIB.GetBarAnchor = function(id)
    return bars[id] and bars[id].anchor or nil
end

----------------------------------------------------------------------
--  战斗中：只刷数量，脱战后补刷
----------------------------------------------------------------------
local function UpdateBarTextOnCombat(id)
    local bar = bars[id]
    if not bar then return end
    for k = 1, MAX_BUTTONS do
        local button = bar.buttons[k]
        if button.itemID and button:IsShown() then
            button.countText = C_Item_GetItemCount(button.itemID, nil, true)
            if button.countText and button.countText > 1 then
                button.count:SetText(button.countText)
            else
                button.count:SetText("")
            end
        end
    end
end

----------------------------------------------------------------------
--  刷新一条
----------------------------------------------------------------------
local function UpdateBarBorder(bar, barDB)
    if not bar then return end
    local style = barDB.borderStyle or "solid"
    local size = barDB.borderSize or 1
    if style == "none" or size <= 0 then
        bar.borderTop:Hide()
        bar.borderBottom:Hide()
        bar.borderLeft:Hide()
        bar.borderRight:Hide()
        return
    end
    bar.borderTop:Show()
    bar.borderBottom:Show()
    bar.borderLeft:Show()
    bar.borderRight:Show()
    bar.borderTop:SetHeight(size)
    bar.borderTop:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
    bar.borderTop:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 0)
    bar.borderBottom:SetHeight(size)
    bar.borderBottom:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
    bar.borderBottom:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
    bar.borderLeft:SetWidth(size)
    bar.borderLeft:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
    bar.borderLeft:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
    bar.borderRight:SetWidth(size)
    bar.borderRight:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 0)
    bar.borderRight:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
end

local function UpdateBar(id)
    local db = DB()
    local barDB = db and db["bar" .. id]
    local bar = bars[id]
    if not barDB or not bar then return end

    if InCombatLockdown() then
        UpdateBarTextOnCombat(id)
        UpdateAfterCombat[id] = true
        return
    end

    if not db.enable or not barDB.enable then
        if bar.register then
            UnregisterStateDriver(bar, "visibility")
            bar.register = false
        end
        bar:Hide()
        return
    end

    local buttonID = 1

    local function addNormalButton(itemID)
        if ValidateItem(itemID) and buttonID <= barDB.numButtons then
            SetUpButton(bar.buttons[buttonID], { itemID = itemID }, nil)
            UpdateButtonSize(bar.buttons[buttonID], barDB)
            buttonID = buttonID + 1
        end
    end

    local function addSlotButton(slotID)
        local itemID = GetInventoryItemID("player", slotID)
        if ValidateItem(itemID) and buttonID <= barDB.numButtons then
            SetUpButton(bar.buttons[buttonID], nil, slotID)
            UpdateButtonSize(bar.buttons[buttonID], barDB)
            buttonID = buttonID + 1
        end
    end

    for _, module in ipairs({ strsplit("[, ]", barDB.include or "") }) do
        if buttonID <= barDB.numButtons then
            if EIB.ModuleList[module] then
                for _, itemID in pairs(EIB.ModuleList[module]) do
                    addNormalButton(itemID)
                end
            elseif module == "QUEST" then
                for _, data in ipairs(questItemList) do
                    addNormalButton(data.itemID)
                end
            elseif module == "EQUIP" then
                for _, slotID in pairs(equipmentList) do
                    addSlotButton(slotID)
                end
            elseif strmatch(module, "^SLOT:") then
                local allowedSlots = ParseSlotFilter(strmatch(module, "^SLOT:(.+)$"))
                if allowedSlots then
                    for _, slotID in pairs(equipmentList) do
                        if allowedSlots[slotID] then addSlotButton(slotID) end
                    end
                end
            elseif module == "CUSTOM" then
                for itemID in pairs(db.customList) do
                    addNormalButton(itemID)
                end
            end
        end
    end

    -- 条尺寸：随实际按钮数收缩
    local numRows = ceil((buttonID - 1) / barDB.buttonsPerRow)
    local numCols = buttonID > barDB.buttonsPerRow and barDB.buttonsPerRow or (buttonID - 1)
    if numCols < 1 then numCols = 1 end
    local barW = 2 * barDB.backdropSpacing + numCols * barDB.buttonWidth + (numCols - 1) * barDB.spacing
    local barH = 2 * barDB.backdropSpacing + numRows * barDB.buttonHeight + (numRows - 1) * barDB.spacing
    bar:SetSize(barW, barH)

    -- anchor 尺寸：满配置网格（解锁模式下 mover 目标）
    local moverRows = ceil(barDB.numButtons / barDB.buttonsPerRow)
    local moverCols = barDB.buttonsPerRow
    local anchorW = 2 * barDB.backdropSpacing + moverCols * barDB.buttonWidth + (moverCols - 1) * barDB.spacing
    local anchorH = 2 * barDB.backdropSpacing + moverRows * barDB.buttonHeight + (moverRows - 1) * barDB.spacing
    bar:GetParent():SetSize(anchorW, anchorH)

    bar:ClearAllPoints()
    bar:SetPoint(barDB.anchor, bar:GetParent(), barDB.anchor, 0, 0)

    -- 无内容：注销可见性驱动，但保留背景可见（便于发现与定位）
    if buttonID == 1 and not EIB._bindingActive then
        if bar.register then
            UnregisterStateDriver(bar, "visibility")
            bar.register = false
        end
        for hideButtonID = 1, MAX_BUTTONS do
            bar.buttons[hideButtonID]:Hide()
        end
        -- 空条仍显示背景（如 backdrop 开启），让用户能看到条的位置
        if bar.barBg then
            if barDB.backdrop then bar.barBg:Show() else bar.barBg:Hide() end
        end
        UpdateBarBorder(bar, barDB)
        bar:SetAlpha(barDB.mouseOver and (barDB.alphaMin or 0) or (barDB.alphaMax or 1))
        bar:Show()
        if id == 1 then
            print(string.format("|cff4accff[EVT]|r Bar1 empty (no matched items), backdrop shown for positioning"))
        end
        return
    end

    -- 隐藏未用按钮 / 重排已用按钮
    for hideButtonID = buttonID, MAX_BUTTONS do
        if EIB._bindingActive then
            -- 绑定模式：全部显示（占位可绑定）
            UpdateButtonSize(bar.buttons[hideButtonID], barDB)
            bar.buttons[hideButtonID].tex:SetTexture(nil)
            bar.buttons[hideButtonID].count:SetText("")
            bar.buttons[hideButtonID].bind:SetText("")
            bar.buttons[hideButtonID].qualityTier:SetText("")
            bar.buttons[hideButtonID]:SetScript("OnUpdate", nil)
            bar.buttons[hideButtonID]:EnableMouse(true)
            bar.buttons[hideButtonID]:Show()
        else
            bar.buttons[hideButtonID]:Hide()
        end
    end

    -- 绑定模式下占位按钮也要参与网格排布
    local positionedCount = EIB._bindingActive and MAX_BUTTONS or (buttonID - 1)
    local anchorPoint = barDB.anchor
    for i = 1, positionedCount do
        local button = bar.buttons[i]
        button:ClearAllPoints()

        if i == 1 then
            if anchorPoint == "TOPLEFT" then
                button:SetPoint(anchorPoint, bar, anchorPoint, barDB.backdropSpacing, -barDB.backdropSpacing)
            elseif anchorPoint == "TOPRIGHT" then
                button:SetPoint(anchorPoint, bar, anchorPoint, -barDB.backdropSpacing, -barDB.backdropSpacing)
            elseif anchorPoint == "BOTTOMLEFT" then
                button:SetPoint(anchorPoint, bar, anchorPoint, barDB.backdropSpacing, barDB.backdropSpacing)
            else
                button:SetPoint(anchorPoint, bar, anchorPoint, -barDB.backdropSpacing, barDB.backdropSpacing)
            end
        elseif i <= barDB.buttonsPerRow then
            local nearest = bar.buttons[i - 1]
            if anchorPoint == "TOPLEFT" or anchorPoint == "BOTTOMLEFT" then
                button:SetPoint("LEFT", nearest, "RIGHT", barDB.spacing, 0)
            else
                button:SetPoint("RIGHT", nearest, "LEFT", -barDB.spacing, 0)
            end
        else
            local nearest = bar.buttons[i - barDB.buttonsPerRow]
            if anchorPoint == "TOPLEFT" or anchorPoint == "TOPRIGHT" then
                button:SetPoint("TOP", nearest, "BOTTOM", 0, -barDB.spacing)
            else
                button:SetPoint("BOTTOM", nearest, "TOP", 0, barDB.spacing)
            end
        end

        button.bind:SetText("")
    end

    if not EIB._bindingActive then
        -- 可见性状态驱动
        if bar.register and bar.registeredVisibility ~= barDB.visibility then
            UnregisterStateDriver(bar, "visibility")
            bar.register = false
        end
        if not bar.register then
            RegisterStateDriver(bar, "visibility", barDB.visibility or "[petbattle]hide;show")
            bar.register = true
            bar.registeredVisibility = barDB.visibility
        end

        -- 背景 / alpha / 边框
        if bar.barBg then
            if barDB.backdrop then bar.barBg:Show() else bar.barBg:Hide() end
        end
        UpdateBarBorder(bar, barDB)
        bar:SetAlpha(barDB.mouseOver and (barDB.alphaMin or 0) or (barDB.alphaMax or 1))
        bar:Show()
    else
        -- 绑定模式：强制可见，便于悬停占位按钮
        if bar.register then
            UnregisterStateDriver(bar, "visibility")
            bar.register = false
        end
        if bar.barBg then bar.barBg:Show() end
        UpdateBarBorder(bar, barDB)
        bar:SetAlpha(1)
        bar:Show()
    end
end

local function UpdateBars()
    for i = 1, 5 do
        UpdateBar(i)
    end
end
EIB.UpdateBars = UpdateBars
EIB.UpdateBar = UpdateBar

----------------------------------------------------------------------
--  按键绑定文本
----------------------------------------------------------------------
local function UpdateBinding()
    local db = DB()
    for i = 1, 5 do
        local bar = bars[i]
        local barDB = db and db["bar" .. i]
        if bar and barDB and barDB.showBind then
            for j = 1, MAX_BUTTONS do
                local button = bar.buttons[j]
                local command = format("CLICK %s%dButton%d:LeftButton", BUTTON_PREFIX, i, j)
                local key = GetBindingKey(command)
                button.bind:SetText(key and PrettyKey(key) or "")
            end
        end
    end
end
EIB.UpdateBinding = UpdateBinding

----------------------------------------------------------------------
--  绑定模式（设置页开启；悬停按钮按键即绑定，ESC 清除/退出）
----------------------------------------------------------------------
local captureFrame

local function BindingCommand(button)
    local bar = button:GetParent()
    return format("CLICK %s%dButton%d:LeftButton", BUTTON_PREFIX, bar.id, button.buttonIndex or 0)
end

local function StopBinding()
    EIB._bindingActive = false
    EIB._hoveredButton = nil
    EIB._bindingBarID = nil
    if captureFrame then captureFrame:Hide() end
    UpdateBars()
    UpdateBinding()
    if EIB.OnBindingChanged then EIB.OnBindingChanged(false) end
end

local function StartBinding(barID)
    if InCombatLockdown() then return end
    if not captureFrame then
        captureFrame = CreateFrame("Frame", nil, UIParent)
        captureFrame:SetFrameStrata("FULLSCREEN_DIALOG")
        captureFrame:SetFrameLevel(500)
        captureFrame:EnableKeyboard(true)
        captureFrame:SetScript("OnKeyDown", function(self, key)
            self:SetPropagateKeyboardInput(false)

            if key == "ESCAPE" then
                local hovered = EIB._hoveredButton
                if hovered then
                    -- 清除该按钮的全部绑定
                    local command = BindingCommand(hovered)
                    for _, k in ipairs({ GetBindingKey(command) }) do
                        SetBinding(k)
                    end
                    SaveBindings(GetCurrentBindingSet())
                    UpdateBinding()
                else
                    StopBinding()
                end
                return
            end

            if key == "UNKNOWN" then return end
            local hovered = EIB._hoveredButton
            if not hovered then return end

            local mod = ""
            if IsAltKeyDown() then mod = mod .. "ALT-" end
            if IsCtrlKeyDown() then mod = mod .. "CTRL-" end
            if IsShiftKeyDown() then mod = mod .. "SHIFT-" end
            local fullKey = mod .. key

            -- 已被占用的键先解绑
            local existing = GetBindingKey(fullKey)
            if existing then SetBinding(existing) end

            SetBinding(fullKey, BindingCommand(hovered))
            SaveBindings(GetCurrentBindingSet())
            UpdateBinding()
        end)
        captureFrame:SetScript("OnKeyUp", function(self)
            self:SetPropagateKeyboardInput(true)
        end)
    end
    EIB._bindingActive = true
    EIB._bindingBarID = barID
    captureFrame:Show()
    UpdateBars()
    UpdateBinding()
    if EIB.OnBindingChanged then EIB.OnBindingChanged(true) end
end

EIB.StartBinding = StartBinding
EIB.StopBinding = StopBinding
EIB.IsBinding = function()
    return EIB._bindingActive == true
end

----------------------------------------------------------------------
--  事件注册
----------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
local registered = false

-- GET_ITEM_INFO_RECEIVED 防抖（图标缓存回填）
local lastIconRefresh = 0
local function DebouncedIconRefresh()
    local now = GetTime()
    if now - lastIconRefresh < 0.2 then return end
    lastIconRefresh = now
    C_Timer.After(0.2, function()
        if not InCombatLockdown() then UpdateBars() end
    end)
end

-- ITEM_LOCKED 延迟 1s（等装备槽解锁）
local itemLockedPending = false

local handlers = {
    BAG_UPDATE_DELAYED = UpdateBars,
    PLAYER_ALIVE = UpdateBars,
    PLAYER_UNGHOST = UpdateBars,
    PLAYER_EQUIPMENT_CHANGED = function()
        UpdateEquipmentList()
        UpdateBars()
    end,
    QUEST_ACCEPTED = function()
        UpdateQuestItemList()
        UpdateBars()
    end,
    QUEST_LOG_UPDATE = function()
        UpdateQuestItemList()
        UpdateBars()
    end,
    QUEST_TURNED_IN = function()
        UpdateQuestItemList()
        UpdateBars()
    end,
    QUEST_WATCH_LIST_CHANGED = function()
        UpdateQuestItemList()
        UpdateBars()
    end,
    UNIT_INVENTORY_CHANGED = function()
        -- 0.25s 节流
        local now = GetTime()
        if now - (EIB._lastInvChanged or 0) < 0.25 then return end
        EIB._lastInvChanged = now
        UpdateQuestItemList()
        UpdateEquipmentList()
        UpdateBars()
    end,
    UPDATE_BINDINGS = UpdateBinding,
    ZONE_CHANGED = UpdateBars,
    ZONE_CHANGED_NEW_AREA = function()
        UpdateState(EIB.STATE.IN_DELVE)
        UpdateBars()
    end,
    GET_ITEM_INFO_RECEIVED = DebouncedIconRefresh,
    PLAYER_ENTERING_WORLD = function()
        UpdateState(EIB.STATE.IN_DELVE)
        UpdateBars()
    end,
    PLAYER_DIFFICULTY_CHANGED = function()
        UpdateState(EIB.STATE.IN_DELVE)
        UpdateBars()
    end,
    PLAYER_REGEN_ENABLED = function()
        local dirty = false
        for i = 1, 5 do
            if UpdateAfterCombat[i] then
                UpdateAfterCombat[i] = false
                dirty = true
            end
        end
        if dirty then UpdateBars() end
    end,
    ITEM_LOCKED = function()
        if itemLockedPending then return end
        itemLockedPending = true
        C_Timer.After(1, function()
            itemLockedPending = false
            UpdateEquipmentList()
            UpdateBars()
        end)
    end,
}

local function RegisterEvents()
    if registered then return end
    registered = true
    eventFrame:SetScript("OnEvent", function(_, event, ...)
        local handler = handlers[event]
        if handler then handler(...) end
    end)
    for event in pairs(handlers) do
        eventFrame:RegisterEvent(event)
    end
end

----------------------------------------------------------------------
--  EUI 解锁模式注册（位置管理）
----------------------------------------------------------------------
local function RegisterUnlock()
    if EIB._unlockRegistered then return end
    if not EUI or not EUI.RegisterUnlockElements then return end
    local MK = EUI.MakeUnlockElement
    if not MK then return end

    local elements = {}
    for id = 1, 5 do
        local key = BUTTON_PREFIX .. id
        elements[id] = MK({
            key = key,
            label = "Extra Items Bar " .. id,
            group = "VTools",
            order = 700 + id,
            isHidden = function()
                local db = DB()
                return not (db and db.enable and db["bar" .. id] and db["bar" .. id].enable)
            end,
            getFrame = function()
                if not bars[id] then CreateBar(id) end
                return bars[id] and bars[id].anchor
            end,
            getSize = function()
                local db = DB()
                local barDB = db and db["bar" .. id]
                if not barDB then return 35, 30 end
                return barDB.buttonWidth, barDB.buttonHeight
            end,
            setWidth = function(_, w)
                local db = DB()
                local barDB = db and db["bar" .. id]
                if not barDB then return end
                barDB.buttonWidth = math.max(20, math.min(100, math.floor(w + 0.5)))
                UpdateBar(id)
                if EUI._unlockActive and EUI.RepositionBarToMover then
                    EUI.RepositionBarToMover(key)
                end
            end,
            setHeight = function(_, h)
                local db = DB()
                local barDB = db and db["bar" .. id]
                if not barDB then return end
                barDB.buttonHeight = math.max(20, math.min(100, math.floor(h + 0.5)))
                UpdateBar(id)
                if EUI._unlockActive and EUI.RepositionBarToMover then
                    EUI.RepositionBarToMover(key)
                end
            end,
            savePos = function(_, point, relPoint, x, y)
                local db = DB()
                local barDB = db and db["bar" .. id]
                if not barDB then return end
                barDB.pos = { point = point, relPoint = relPoint, x = x, y = y }
                ApplyAnchorPosition(id)
            end,
            loadPos = function()
                local db = DB()
                local barDB = db and db["bar" .. id]
                if barDB and barDB.pos and barDB.pos.point then
                    local pos = barDB.pos
                    return { point = pos.point, relPoint = pos.relPoint or pos.point, x = pos.x or 0, y = pos.y or 0 }
                end
                return nil
            end,
            clearPos = function()
                local db = DB()
                local barDB = db and db["bar" .. id]
                if barDB then barDB.pos = nil end
                ApplyAnchorPosition(id)
            end,
            applyPos = function()
                ApplyAnchorPosition(id)
            end,
            -- 条进入解锁模式时强制可见（含空内容条）
            isAnchored = nil,
        })

        -- 齿轮"元素选项"深链 → evt 设置页
        local mapping = { module = "EUI_VTools_items", page = nil }
        if EUI._elemMapPre then
            if EUI._elemMapPre[key] == nil then EUI._elemMapPre[key] = mapping end
        elseif EUI._ELEMENT_SETTINGS_MAP then
            if EUI._ELEMENT_SETTINGS_MAP[key] == nil then EUI._ELEMENT_SETTINGS_MAP[key] = mapping end
        end
    end

    EUI:RegisterUnlockElements(elements)
    EIB._unlockRegistered = true
end

----------------------------------------------------------------------
--  解锁模式会话监听：进入时强制显示所有已启用条，退出后按配置恢复
----------------------------------------------------------------------
local function RegisterUnlockListener()
    if not EUI or not EUI.RegisterUnlockModeListener then return end
    EUI:RegisterUnlockModeListener("EUI_VTools_ExtraItemsBar", function(active)
        if active then
            local db = DB()
            for i = 1, 5 do
                local barDB = db and db["bar" .. i]
                if db and db.enable and barDB and barDB.enable and bars[i] then
                    local bar = bars[i]
                    if bar.register then
                        UnregisterStateDriver(bar, "visibility")
                        bar.register = false
                    end
                    -- 解锁模式：强制显示背景 + 全 alpha，即使条内容为空也能看到并拖动
                    if bar.barBg then bar.barBg:Show() end
                    bar:Show()
                    bar:SetAlpha(1)
                    -- 空条补一个最小尺寸，避免 0 尺寸无法选中
                    if bar:GetWidth() < 20 then bar:SetSize(80, 40) end
                end
            end
        else
            UpdateBars()
        end
    end)
end

----------------------------------------------------------------------
--  启动
----------------------------------------------------------------------
local function Initialize()
    if EIB.initialized then return end
    EIB.initialized = true

    UpdateQuestItemList()
    UpdateEquipmentList()
    print(string.format("|cff4accff[EVT]|r questItems=%d equipment=%d", #questItemList, #equipmentList))
    UpdateState(EIB.STATE.IN_DELVE)
    UpdateState(EIB.STATE.QUANTUM_ITEM_ALLOWED)
    UpdateBars()
    UpdateBinding()
    RegisterEvents()
    -- 打印各条最终可见状态
    for i = 1, 5 do
        local b = bars[i]
        if b then
            local cx, cy = b:GetParent():GetCenter()
            print(string.format("|cff4accff[EVT]|r Bar%d shown=%s width=%.0f anchor=(%.0f,%.0f)",
                i, tostring(b:IsShown()), b:GetWidth(), cx or 0, cy or 0))
        end
    end
end

----------------------------------------------------------------------
--  启动：PLAYER_LOGIN 时始终创建条 + 注册解锁元素（保证解锁模式可见），
--  仅在 enable 时才初始化内容刷新与事件监听。
----------------------------------------------------------------------
local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function()
    boot:UnregisterAllEvents()

    print("|cff4accff[EVT]|r ExtraItemsBar boot start, EUI=", tostring(EUI ~= nil),
          "MakeUnlockElement=", tostring(EUI and EUI.MakeUnlockElement ~= nil),
          "RegisterUnlockElements=", tostring(EUI and EUI.RegisterUnlockElements ~= nil))

    -- 始终创建 5 条（即使禁用），解锁模式与 getFrame 依赖 anchor 存在
    local created = 0
    for id = 1, 5 do
        if not bars[id] then
            local ok, err = pcall(CreateBar, id)
            if ok and bars[id] then
                created = created + 1
            elseif not ok then
                print("|cffff6b6b[EVT]|r CreateBar("..id..") failed:", err)
            end
        end
    end

    -- 始终注册解锁元素与监听（isHidden 内部判断 enable）；
    -- 若 EUI 解锁 API 尚未就绪，延迟 1 秒重试一次。
    RegisterUnlock()
    RegisterUnlockListener()
    if not EIB._unlockRegistered then
        C_Timer.After(1, function()
            if not EIB._unlockRegistered then
                RegisterUnlock()
                RegisterUnlockListener()
            end
        end)
    end

    local db = DB()
    print(string.format("|cff4accff[EVT]|r ExtraItemsBar boot: %d/5 bars, unlock=%s, enable=%s, bar1.enable=%s",
        created, tostring(EIB._unlockRegistered), tostring(db and db.enable),
        tostring(db and db.bar1 and db.bar1.enable)))

    if db and db.enable then
        Initialize()
    end
end)

-- 设置页开关 enable 时惰性初始化内容
EIB.EnsureInitialized = function()
    -- 确保条与解锁元素已就位（PLAYER_LOGIN 可能尚未触发，如极早调用）
    for id = 1, 5 do
        if not bars[id] then CreateBar(id) end
    end
    if not EIB._unlockRegistered then
        RegisterUnlock()
        RegisterUnlockListener()
    end
    if not EIB.initialized then Initialize() end
end

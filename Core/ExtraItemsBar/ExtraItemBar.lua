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

-- 前置声明：CreateButton 的 cooldown hook 早于字体函数定义
local ApplyCooldownFontStyle
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
        spacing = 3,
        -- EUI 动作条风格背景/边框
        bgEnabled = true,
        bgColor = { r = 0, g = 0, b = 0, a = 0.5 },
        bgOpacity = 50,
        bgPadding = 3,
        bgBorderTexture = "solid",
        bgBorderThickness = "thin",
        bgBorderColor = { r = 0, g = 0, b = 0, a = 1 },
        bgBorderClassColor = false,
        anchor = "TOPLEFT",
        -- EUI 动作条风格按钮（图标）皮肤
        btnBorderTexture   = "solid",
        btnBorderThickness = "thin",
        btnBorderColor     = { r = 0, g = 0, b = 0, a = 1 },
        btnBorderClassColor = false,
        iconZoom           = 5.5,
        slotBgColor        = { r = 0.15, g = 0.15, b = 0.15 },
        slotBgOpacity      = 50,
        showCooldownText   = true,
        buttonShape        = "none",
        showBlizzIconBg    = false,
        blizzIconBgAlpha   = 100,
        -- 字体设置：快捷键 / 数量 / 冷却 三套独立配置
        -- family=nil → EUI EXPRESSWAY；"default" → 游戏默认字体
        keybindFont = {
            family = nil, size = 12,
            color = { r = 1, g = 1, b = 1, a = 1 }, classColor = false,
            outline = true, anchor = "TOPRIGHT", offsetX = 0, offsetY = 0,
        },
        countFont = {
            family = nil, size = 12,
            color = { r = 1, g = 1, b = 1, a = 1 }, classColor = false,
            outline = true, anchor = "BOTTOMRIGHT", offsetX = 0, offsetY = 0,
        },
        cooldownFont = {
            family = nil, size = 20,
            color = { r = 1, g = 1, b = 1, a = 1 }, classColor = false,
            outline = true, anchor = "CENTER", offsetX = 0, offsetY = 0,
        },
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
--  悬停淡入淡出（条级）
--  MouseIsOver 判定包含子帧：鼠标在条与按钮之间移动不算离开
----------------------------------------------------------------------
local function FadeBarOnEnter(bar)
    if not bar then return end
    local bd = DB()["bar" .. bar.id]
    if bd and bd.mouseOver then
        UIFrameFadeIn(bar, bd.fadeTime or 0.3, bar:GetAlpha(), bd.alphaMax or 1)
    end
end

local function FadeBarOnLeave(bar)
    if not bar then return end
    -- MouseIsOver 在 11.x 已移除；用 GetMouseFoci 遍历焦点父链判断仍在条/按钮上
    local foci = GetMouseFoci and GetMouseFoci()
    if foci then
        for _, f in ipairs(foci) do
            local n = f
            while n do
                if n == bar then return end
                n = n:GetParent()
            end
        end
    end
    local bd = DB()["bar" .. bar.id]
    if bd and bd.mouseOver then
        UIFrameFadeOut(bar, bd.fadeTime or 0.3, bar:GetAlpha(), bd.alphaMin or 0)
    end
end

----------------------------------------------------------------------
--  按钮
----------------------------------------------------------------------
local function CreateButton(name, parent, barDB, index)
    -- 按钮先在 EllesmereUI 容器上创建，再 SetParent(bar)（WindTools 模式）
    -- AnyDown 在 11.x 下比 AnyUp 更稳定
    local btnParent = (UI and UI.E and UI.E.UIParent) or UIParent
    local button = CreateFrame("Button", name, btnParent, "SecureActionButtonTemplate, BackdropTemplate")
    button.buttonIndex = index
    button:SetSize(barDB.buttonWidth, barDB.buttonHeight)
    button:SetClampedToScreen(true)
    button:SetAttribute("type", "item")
    button:EnableMouse(false)
    button:RegisterForClicks("AnyDown")

    -- 槽位底（颜色/透明度由 barDB 驱动，对齐 EUI 动作条 slot background）
    local slotBg = button:CreateTexture(nil, "BACKGROUND", nil, -1)
    slotBg:SetAllPoints()
    slotBg:SetColorTexture(0.15, 0.15, 0.15, 0.5)

    local tex = button:CreateTexture(nil, "ARTWORK")
    tex:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
    tex:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local hover = UI.SolidTex(button, "HIGHLIGHT", 1, 1, 1, 0.12)
    hover:SetAllPoints()
    hover:Hide()

    -- 按钮边框统一由 ApplyButtonSkin() 走 EUI ApplyBorderStyle 渲染

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
    cooldown:SetAllPoints()
    cooldown:SetDrawBling(false)
    cooldown:SetDrawSwipe(true)
    cooldown:EnableMouse(false)

    button.tex = tex
    button.icon = tex  -- EUI 皮肤系统约定的小写字段名
    button.slotBg = slotBg
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
        FadeBarOnEnter(button:GetParent())
    end)

    button:SetScript("OnLeave", function()
        if EIB._hoveredButton == button then
            EIB._hoveredButton = nil
        end
        hover:Hide()
        GameTooltip:Hide()
        FadeBarOnLeave(button:GetParent())
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
        -- texcoord（图标缩放）由 ApplyButtonSkin 统一设置

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

    -- SetUpButton 里改成 macro + macrotext（WindTools 模式）
    if not InCombatLockdown() then
        button:EnableMouse(true)
        button:Show()
        button:SetAttribute("type", "macro")

        local macroText
        if button.slotID then
            macroText = "/use " .. button.slotID
        elseif button.itemName or button.itemID then
            macroText = "/use item:" .. button.itemID
            if button.itemID == 172347 then
                macroText = macroText .. "\n/use 5"
            end
        end

        if macroText then
            button:SetAttribute("macrotext", macroText)
        end
    end
end

----------------------------------------------------------------------
--  字体样式应用（快捷键 / 数量 / 冷却 三套独立配置）
----------------------------------------------------------------------
local function ResolveFontPath(cfg)
    local name = cfg and cfg.family
    if not name then
        return FONT_PATH
    end
    if name == "default" then return "Fonts\\FRIZQT__.TTF" end
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM then
        local p = LSM:Fetch("font", name, true)
        if p then return p end
    end
    return name  -- 直接当路径用
end

local function ResolveFontColor(cfg)
    local c = cfg and cfg.color or { r = 1, g = 1, b = 1, a = 1 }
    if cfg and cfg.classColor then
        local cc = RAID_CLASS_COLORS[select(2, UnitClass("player"))]
        if cc then return { r = cc.r, g = cc.g, b = cc.b, a = c.a or 1 } end
    end
    return c
end

-- 对单个 FontString 应用配置；defaultPoint 为 anchor 为空时的回退位置
local function ApplyOneFont(fs, cfg, relativeTo, defaultPoint)
    if not fs or not cfg then return end
    fs:SetFont(ResolveFontPath(cfg), cfg.size or 12, cfg.outline and "OUTLINE" or "")
    local c = ResolveFontColor(cfg)
    fs:SetTextColor(c.r, c.g, c.b, c.a or 1)
    fs:ClearAllPoints()
    local pt = cfg.anchor or defaultPoint
    fs:SetPoint(pt, relativeTo, pt, cfg.offsetX or 0, cfg.offsetY or 0)
end

-- 冷却倒计时：Cooldown 的 FontString 是惰性创建的子 Region
function ApplyCooldownFontStyle(cooldown, cfg)
    if not cooldown or not cfg then return false end
    for i = 1, cooldown:GetNumRegions() do
        local region = select(i, cooldown:GetRegions())
        if region and region.GetObjectType and region:GetObjectType() == "FontString" then
            ApplyOneFont(region, cfg, cooldown, "CENTER")
            return true
        end
    end
    return false
end

local function ApplyTextStyles(button, barDB)
    local db = barDB or {}

    -- 快捷键
    ApplyOneFont(button.bind, db.keybindFont, button, "TOPRIGHT")
    button.bind:SetShown(db.showBind ~= false)

    -- 数量
    ApplyOneFont(button.count, db.countFont, button, "BOTTOMRIGHT")
    button.count:SetShown(db.showCount ~= false)

    -- 制造品质角标：大小独立设置，字体跟随 EUI
    if button.qualityTier then
        button.qualityTier:SetFont(FONT_PATH, db.qualityTierSize or 16, "OUTLINE")
        button.qualityTier:SetShown(db.showQualityTier ~= false)
    end

    -- 冷却倒计时
    if button.cooldown then
        button.cooldown:SetHideCountdownNumbers(db.showCooldownText == false)
        if db.cooldownFont and db.showCooldownText ~= false then
            button._cooldownFontCfg = db.cooldownFont
            if not ApplyCooldownFontStyle(button.cooldown, db.cooldownFont) then
                -- FontString 可能尚未创建，下一帧重试一次
                C_Timer.After(0, function()
                    if button.cooldown then
                        ApplyCooldownFontStyle(button.cooldown, db.cooldownFont)
                    end
                end)
            end
        end
    end
end

-- 设置按钮尺寸；图标裁剪/边框等皮肤由 ApplyButtonSkin 统一处理
local function UpdateButtonSize(button, barDB)
    button:SetSize(barDB.buttonWidth, barDB.buttonHeight)
    ApplyTextStyles(button, barDB)
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
--  按物品属性扫描背包：消耗品子类（用于「药剂」分组）
--  客户端 Enum: Consumable class，Elixir subclass
----------------------------------------------------------------------
local CONSUMABLE_CLASS = (Enum and Enum.ItemClass and Enum.ItemClass.Consumable) or 0
local ELIXIR_SUBCLASS
do
    local sub = Enum and Enum.ItemConsumableSubclass
    if sub then
        ELIXIR_SUBCLASS = sub.Elixir or sub.ELIXIR
    end
    -- 经典数值：Consumable=0 → Generic=0/Potion=2/Elixir=3/Flask=4 ...
    ELIXIR_SUBCLASS = ELIXIR_SUBCLASS or 3
end

local function ScanBagConsumablesBySubclass(targetSubclass)
    local found = {}
    if not C_Container or not C_Container.GetContainerNumSlots then return found end
    for bag = 0, 5 do  -- 0..4 背包 + 5 材料包（若不存在 API 返回 nil）
        local slots = C_Container.GetContainerNumSlots(bag)
        if slots then
            for slot = 1, slots do
                local itemID = C_Container.GetContainerItemID(bag, slot)
                if itemID and not found[itemID] then
                    local classID, subclassID = select(6, GetItemInfoInstant(itemID))
                    if classID == CONSUMABLE_CLASS and subclassID == targetSubclass then
                        found[itemID] = true
                    end
                end
            end
        end
    end
    return found
end

----------------------------------------------------------------------
--  创建一条（anchor + bar + 12 按钮）
----------------------------------------------------------------------
local bars = {}

-- anchor 默认位置（无保存位置时使用，自左向右纵向排列在屏幕下方）
local function ApplyAnchorPosition(id, anchorFrame)
    local anchor = anchorFrame or (bars[id] and bars[id].anchor)
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
    ApplyAnchorPosition(id, anchor)

    -- anchor 不绘制自身背景（EUI 解锁模式会画高亮框；空条由 _bgFill 显示位置）

    local bar = CreateFrame("Frame", BUTTON_PREFIX .. id, anchor, "SecureHandlerStateTemplate")
    bar.id = id
    bar.anchor = anchor
    bar:SetPoint(barDB.anchor, anchor, barDB.anchor, 0, 0)
    bar:SetSize(200, 40)
    bar:SetFrameStrata("LOW")

    -- EUI 动作条风格背景：fill 纹理 + border frame（用 EllesmereUI.ApplyBorderStyle）
    local fill = bar:CreateTexture(nil, "BACKGROUND", nil, -1)
    local border = CreateFrame("Frame", nil, bar, "BackdropTemplate")
    border:EnableMouse(false)
    border:SetFrameLevel(math.max(0, bar:GetFrameLevel()))
    bar._bgFill = fill
    bar._bgBorder = border

    bar.buttons = {}
    for i = 1, MAX_BUTTONS do
        local btn = CreateButton(BUTTON_PREFIX .. id .. "Button" .. i, bar, barDB, i)
        btn:SetParent(bar)
        btn:Hide()
        bar.buttons[i] = btn
    end

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
-- EUI 动作条风格背景/边框渲染（复刻 EAB:ApplyBackgroundForBar 逻辑）

-- 取玩家职业颜色（RAID_CLASS_COLORS），失败时返回 nil
local function GetClassColor()
    local _, cls = UnitClass("player")
    return cls and RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls] or nil
end

local function ApplyBarBackground(bar, barDB)
    if not bar or not barDB then return end
    local fill = bar._bgFill
    local border = bar._bgBorder
    if not fill or not border then return end

    if not barDB.bgEnabled then
        fill:Hide()
        if EllesmereUI and EllesmereUI.ApplyBorderStyle then
            EllesmereUI.ApplyBorderStyle(border, 0, 0, 0, 0, barDB.bgBorderTexture or "solid")
        else
            border:Hide()
        end
        return
    end

    local c = barDB.bgColor or { r = 0, g = 0, b = 0, a = 0.5 }
    local alpha = barDB.bgOpacity ~= nil and barDB.bgOpacity / 100 or c.a
    fill:SetColorTexture(c.r, c.g, c.b, alpha)
    local padding = barDB.bgPadding or 0
    local left, right, top, bottom = -padding, padding, padding, -padding
    fill:ClearAllPoints()
    fill:SetPoint("TOPLEFT", bar, "TOPLEFT", left, top)
    fill:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", right, bottom)
    fill:Show()

    border:SetFrameLevel(barDB.bgBorderBehind and math.max(0, bar:GetFrameLevel() - 1) or bar:GetFrameLevel())
    border:ClearAllPoints()
    border:SetPoint("TOPLEFT", bar, "TOPLEFT", left, top)
    border:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", right, bottom)
    if EllesmereUI and EllesmereUI.ApplyBorderStyle then
        local bc = barDB.bgBorderColor or { r = 0, g = 0, b = 0, a = 1 }
        if barDB.bgBorderClassColor then
            local cc = GetClassColor()
            if cc then bc = { r = cc.r, g = cc.g, b = cc.b, a = bc.a or 1 } end
        end
        local thicknessKey = barDB.bgBorderThickness or "none"
        local thicknessMap = { none = 0, thin = 1, normal = 2, heavy = 3, strong = 4 }
        local borderSize = thicknessMap[thicknessKey] or 0
        EllesmereUI.ApplyBorderStyle(border, borderSize,
            bc.r, bc.g, bc.b, bc.a or 1, barDB.bgBorderTexture or "solid",
            barDB.bgBorderOffsetX, barDB.bgBorderOffsetY,
            barDB.bgBorderShiftX, barDB.bgBorderShiftY,
            "actionbars", thicknessKey)
    else
        border:Hide()
    end
end

-- 按钮边框厚度（像素），与 EUI ns.BORDER_THICKNESS.regular 一致
local BTN_THICKNESS_PX = { none = 0, thin = 1, normal = 2, heavy = 3, strong = 4 }

-- 自定义按钮形状资源（复刻 EllesmereUIActionBars SHAPE_* 常量）
local SHAPE_MEDIA = "Interface\\AddOns\\EllesmereUI\\media\\portraits\\"
local SHAPE_DATA = {
    square   = { mask = SHAPE_MEDIA .. "square_mask.tga",   border = SHAPE_MEDIA .. "square_border.tga",   inset = 17, zoomDef = 6.0, expandOff = 4, edgeScale = 0.75, circular = false },
    circle   = { mask = SHAPE_MEDIA .. "circle_mask.tga",   border = SHAPE_MEDIA .. "circle_border.tga",   inset = 17, zoomDef = 6.0, expandOff = 2, edgeScale = 0.75, circular = true  },
    csquare  = { mask = SHAPE_MEDIA .. "csquare_mask.tga",  border = SHAPE_MEDIA .. "csquare_border.tga",  inset = 17, zoomDef = 6.0, expandOff = 4, edgeScale = 0.75, circular = false },
    diamond  = { mask = SHAPE_MEDIA .. "diamond_mask.tga",  border = SHAPE_MEDIA .. "diamond_border.tga",  inset = 14, zoomDef = 6.0, expandOff = 2, edgeScale = 0.70, circular = true  },
    hexagon  = { mask = SHAPE_MEDIA .. "hexagon_mask.tga",  border = SHAPE_MEDIA .. "hexagon_border.tga",  inset = 17, zoomDef = 6.0, expandOff = 4, edgeScale = 0.65, circular = true  },
    portrait = { mask = SHAPE_MEDIA .. "portrait_mask.tga", border = SHAPE_MEDIA .. "portrait_border.tga", inset = 17, zoomDef = 6.0, expandOff = 2, edgeScale = 0.70, circular = true  },
    shield   = { mask = SHAPE_MEDIA .. "shield_mask.tga",   border = SHAPE_MEDIA .. "shield_border.tga",   inset = 13, zoomDef = 6.0, expandOff = 2, edgeScale = 0.65, circular = true  },
}
local SHAPE_ICON_EXPAND = 7

-- 恢复图标默认锚点（CreateButton 中的 1px 内缩）
local function RestoreIconAnchors(button)
    local icon = button.icon
    if not icon then return end
    icon:ClearAllPoints()
    icon:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
end

-- 应用 / 移除自定义形状的遮罩；返回是否处于自定义形状
local function ApplyButtonShape(button, barDB, zoomRatio)
    local shape = barDB.buttonShape or "none"
    local sd = SHAPE_DATA[shape]
    local icon = button.icon
    local mask = button.shapeMask
    local thicknessKey = barDB.btnBorderThickness or "thin"
    local brdOn = (BTN_THICKNESS_PX[thicknessKey] or 0) > 0
    local bc = barDB.btnBorderColor or { r = 0, g = 0, b = 0, a = 1 }
    if barDB.btnBorderClassColor then
        local cc = GetClassColor()
        if cc then bc = { r = cc.r, g = cc.g, b = cc.b, a = bc.a or 1 } end
    end

    -- ---- none / cropped：移除形状遮罩，恢复方形外观 ----
    if not sd then
        if mask then
            pcall(function()
                if icon then icon:RemoveMaskTexture(mask) end
                if button.slotBg then button.slotBg:RemoveMaskTexture(mask) end
                if button.hover then button.hover:RemoveMaskTexture(mask) end
                if button.iconBg then button.iconBg:RemoveMaskTexture(mask) end
                if button.cooldown then button.cooldown:RemoveMaskTexture(mask) end
            end)
            mask:SetTexture(nil)
            mask:ClearAllPoints()
            mask:SetSize(0.001, 0.001)
            mask:Hide()
        end
        if button.shapeBorder then
            button.shapeBorder:Hide()
            button.shapeBorder:SetTexture(nil)
        end
        RestoreIconAnchors(button)
        if icon then
            if shape == "cropped" then
                icon:SetTexCoord(zoomRatio, 1 - zoomRatio, zoomRatio + 0.10, 1 - zoomRatio - 0.10)
            else
                icon:SetTexCoord(zoomRatio, 1 - zoomRatio, zoomRatio, 1 - zoomRatio)
            end
        end
        if button.cooldown and button.cooldown.SetUseCircularEdge then
            pcall(button.cooldown.SetUseCircularEdge, button.cooldown, false)
        end
        return false
    end

    -- ---- 自定义形状 ----
    if not mask then
        mask = button:CreateMaskTexture()
        button.shapeMask = mask
    end
    mask:SetTexture(sd.mask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:ClearAllPoints()
    if brdOn then
        -- 有形状边框时遮罩内缩 1px，为环形边框贴图留出边缘
        mask:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
        mask:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    else
        mask:SetAllPoints(button)
    end
    mask:Show()

    pcall(function()
        if icon then icon:AddMaskTexture(mask) end
        if button.slotBg then button.slotBg:AddMaskTexture(mask) end
        if button.hover then button.hover:AddMaskTexture(mask) end
        if button.iconBg then button.iconBg:AddMaskTexture(mask) end
        if button.cooldown then
            button.cooldown:AddMaskTexture(mask)
            if button.cooldown.SetSwipeTexture then
                button.cooldown:SetSwipeTexture(sd.mask)
            end
        end
    end)

    -- 图标按形状外扩 + texcoord 按贴图内缘外扩
    if icon then
        local iconExp = SHAPE_ICON_EXPAND + sd.expandOff + (zoomRatio - sd.zoomDef / 100) * 200
        if iconExp < 0 then iconExp = 0 end
        local half = iconExp / 2
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", button, "TOPLEFT", -half, half)
        icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", half, -half)
        local visRatio = (128 - 2 * sd.inset) / 128
        local expand = ((1 / visRatio) - 1) * 0.5
        icon:SetTexCoord(-expand, 1 + expand, -expand, 1 + expand)
    end

    -- 形状环形边框（方形边框由调用方隐藏）
    if not button.shapeBorder then
        button.shapeBorder = button:CreateTexture(nil, "OVERLAY", nil, 6)
    end
    local ring = button.shapeBorder
    ring:ClearAllPoints()
    ring:SetAllPoints(button)
    if brdOn then
        ring:SetTexture(sd.border)
        ring:SetVertexColor(bc.r, bc.g, bc.b, bc.a or 1)
        ring:Show()
    else
        ring:Hide()
        ring:SetTexture(nil)
    end

    -- 冷却边缘跟随形状（11.x 新 API，老客户端自动跳过）
    if button.cooldown then
        if button.cooldown.SetUseCircularEdge then
            pcall(button.cooldown.SetUseCircularEdge, button.cooldown, sd.circular)
        end
        if button.cooldown.SetEdgeScale then
            pcall(button.cooldown.SetEdgeScale, button.cooldown, sd.edgeScale)
        end
    end
    return true
end

-- 暴雪风格空槽图标底纹（UI-HUD-ActionBar-IconFrame-Slot），仅空槽显示
local function ApplyBlizzIconBg(button, barDB, isEmpty)
    if not barDB.showBlizzIconBg then
        if button.iconBgClip then button.iconBgClip:Hide() end
        return
    end
    if not button.iconBgClip then
        local clip = CreateFrame("Frame", nil, button)
        clip:SetAllPoints(button)
        clip:SetClipsChildren(true)
        clip:EnableMouse(false)
        clip:SetFrameLevel(math.max(1, button:GetFrameLevel() - 1))
        local bg = clip:CreateTexture(nil, "BACKGROUND", nil, -1)
        bg:SetAtlas("UI-HUD-ActionBar-IconFrame-Slot")
        bg:SetPoint("TOPLEFT", clip, "TOPLEFT", -4, 4)
        bg:SetPoint("BOTTOMRIGHT", clip, "BOTTOMRIGHT", 4, -4)
        button.iconBgClip = clip
        button.iconBg = bg
    end
    button.iconBg:SetAlpha((barDB.blizzIconBgAlpha ~= nil and barDB.blizzIconBgAlpha / 100) or 1)
    if button.shapeMask then
        pcall(button.iconBg.AddMaskTexture, button.iconBg, button.shapeMask)
    end
    button.iconBgClip:SetShown(isEmpty and true or false)
end

-- EUI 动作条风格的单按钮皮肤：槽位底 + 图标缩放 + 形状 + 边框 + 空槽底纹
local function ApplyButtonSkin(button, barDB, isEmpty)
    if not button or not barDB then return end

    -- 槽位底颜色 / 透明度
    if button.slotBg then
        local sc = barDB.slotBgColor or { r = 0.15, g = 0.15, b = 0.15 }
        local sa = barDB.slotBgOpacity ~= nil and barDB.slotBgOpacity / 100 or 0.5
        button.slotBg:SetColorTexture(sc.r, sc.g, sc.b, sa)
    end

    local zoomRatio = (barDB.iconZoom ~= nil and barDB.iconZoom or 5.5) / 100
    local inCustomShape = ApplyButtonShape(button, barDB, zoomRatio)

    -- 非自定义形状：方形边框走 EUI ApplyBorderStyle；自定义形状：隐藏方形边框，用环形贴图
    if not inCustomShape then
        if EllesmereUI and EllesmereUI.ApplyBorderStyle then
            local key = barDB.btnBorderThickness or "thin"
            local bc = barDB.btnBorderColor or { r = 0, g = 0, b = 0, a = 1 }
    if barDB.btnBorderClassColor then
        local cc = GetClassColor()
        if cc then bc = { r = cc.r, g = cc.g, b = cc.b, a = bc.a or 1 } end
    end
            EllesmereUI.ApplyBorderStyle(button, BTN_THICKNESS_PX[key] or 1,
                bc.r, bc.g, bc.b, bc.a or 1, barDB.btnBorderTexture or "solid",
                nil, nil, nil, nil, "actionbars", key)
        end
    else
        if EllesmereUI and EllesmereUI.ApplyBorderStyle then
            EllesmereUI.ApplyBorderStyle(button, 0, 0, 0, 0,
                barDB.btnBorderTexture or "solid")
        end
        if EllesmereUI and EllesmereUI._bdBorderData then
            local bdFrame = EllesmereUI._bdBorderData[button]
            if bdFrame then bdFrame:Hide() end
        end
    end

    -- 非形状下的图标宽高比裁剪（形状分支内部已处理 texcoord）
    if not inCustomShape and barDB.buttonShape ~= "cropped" and button.icon then
        local left, right, top, bottom = zoomRatio, 1 - zoomRatio, zoomRatio, 1 - zoomRatio
        local w, h = barDB.buttonWidth or 36, barDB.buttonHeight or 36
        if w > h then
            local off = (bottom - top) * (1 - h / w) / 2
            top = top + off
            bottom = bottom - off
        elseif w < h then
            local off = (right - left) * (1 - w / h) / 2
            left = left + off
            right = right - off
        end
        button.icon:SetTexCoord(left, right, top, bottom)
    end

    ApplyBlizzIconBg(button, barDB, isEmpty)
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

    -- 旧键向后兼容：把按资料片拆分的旧键合并到新的总键（Data.lua 已去掉这些拆分）
    local LEGACY_KEY = {
        POTIONGN = "POTION", POTIONLEG = "POTION", POTIONSL = "POTION",
        POTIONDF = "POTION", POTIONTWW = "POTION", POTIONMN = "POTION",
        FLASKLEG = "FLASK", FLASKSL = "FLASK", FLASKDF = "FLASK",
        FLASKTWW = "FLASK", FLASKMN = "FLASK",
        RUNETWW = "RUNE", RUNEMN = "RUNE",
        VANTUSTWW = "VANTUS", VANTUSMN = "VANTUS",
        FOODTWW = "FOOD", FOODMN = "FOOD",
        FISHINGTWW = "FISHING", FISHINGMN = "FISHING",
        PROFTWW = "PROF", PROFMN = "PROF",
        -- 已删除的键直接跳过
        BANNER = nil, BIGDIG = nil,
    }

    for _, rawModule in ipairs({ strsplit("[, ]", barDB.include or "") }) do
        if buttonID > barDB.numButtons then break end
        -- BANNER/BIGDIG 已删除，LEGACY_KEY 里没有它们，module 保持原名后无匹配自动跳过
        local module = LEGACY_KEY[rawModule] or rawModule
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
        elseif module == "ELIXIR" then
            -- 药剂：按物品属性（消耗品子类）动态扫描背包
            for itemID in pairs(ScanBagConsumablesBySubclass(ELIXIR_SUBCLASS)) do
                addNormalButton(itemID)
            end
        elseif strmatch(module, "^SLOT:") then
            local allowedSlots = ParseSlotFilter(strmatch(module, "^SLOT:(.+)$"))
            if allowedSlots then
                for _, slotID in pairs(equipmentList) do
                    if allowedSlots[slotID] then addSlotButton(slotID) end
                end
            end
        end
    end

    -- 自定义物品 ID 列表（始终生效，OR 关系：匹配内容分组 OR 在 customList 里）
    local customList = barDB.customList
    if customList and next(customList) and buttonID <= barDB.numButtons then
        for itemID in pairs(customList) do
            if buttonID > barDB.numButtons then break end
            addNormalButton(itemID)
        end
    end

    -- 条尺寸：随实际按钮数收缩（背景留白 = EUI Background Spacing）
    local pad = barDB.bgPadding or 0
    local numRows = ceil((buttonID - 1) / barDB.buttonsPerRow)
    local numCols = buttonID > barDB.buttonsPerRow and barDB.buttonsPerRow or (buttonID - 1)
    if numCols < 1 then numCols = 1 end
    local barW = 2 * pad + numCols * barDB.buttonWidth + (numCols - 1) * barDB.spacing
    local barH = 2 * pad + numRows * barDB.buttonHeight + (numRows - 1) * barDB.spacing
    bar:SetSize(barW, barH)

    -- anchor 尺寸：满配置网格（解锁模式下 mover 目标）
    local moverRows = ceil(barDB.numButtons / barDB.buttonsPerRow)
    local moverCols = barDB.buttonsPerRow
    local anchorW = 2 * pad + moverCols * barDB.buttonWidth + (moverCols - 1) * barDB.spacing
    local anchorH = 2 * pad + moverRows * barDB.buttonHeight + (moverRows - 1) * barDB.spacing
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
        -- 空条仍显示背景（如 bgEnabled 开启），让用户能看到条的位置
        ApplyBarBackground(bar, barDB)
        bar:SetAlpha(barDB.mouseOver and (barDB.alphaMin or 0) or (barDB.alphaMax or 1))
        bar:Show()
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
        local isEmpty = not button.itemID and not button.slotID
        ApplyButtonSkin(button, barDB, isEmpty)

        if i == 1 then
            if anchorPoint == "TOPLEFT" then
                button:SetPoint(anchorPoint, bar, anchorPoint, pad, -pad)
            elseif anchorPoint == "TOPRIGHT" then
                button:SetPoint(anchorPoint, bar, anchorPoint, -pad, -pad)
            elseif anchorPoint == "BOTTOMLEFT" then
                button:SetPoint(anchorPoint, bar, anchorPoint, pad, pad)
            else
                button:SetPoint(anchorPoint, bar, anchorPoint, -pad, pad)
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

        -- 背景 / alpha
        ApplyBarBackground(bar, barDB)
        bar:SetAlpha(barDB.mouseOver and (barDB.alphaMin or 0) or (barDB.alphaMax or 1))
        bar:Show()
    else
        -- 绑定模式：强制可见，便于悬停占位按钮
        if bar.register then
            UnregisterStateDriver(bar, "visibility")
            bar.register = false
        end
        ApplyBarBackground(bar, barDB)
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
        if bar and barDB then
            for j = 1, MAX_BUTTONS do
                local button = bar.buttons[j]
                if barDB.showBind then
                    local command = format("CLICK %s%dButton%d:LeftButton", BUTTON_PREFIX, i, j)
                    local key = GetBindingKey(command)
                    button.bind:SetText(key and PrettyKey(key) or "")
                    button.bind:Show()
                else
                    button.bind:SetText("")
                    button.bind:Hide()
                end
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
    PLAYER_SPECIALIZATION_CHANGED = UpdateBars,  -- 职业色跟随专精切换
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
        local mapping = { module = "EUI_VTools_items", page = "items" }
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
                    ApplyBarBackground(bar, barDB)
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
    UpdateState(EIB.STATE.IN_DELVE)
    UpdateState(EIB.STATE.QUANTUM_ITEM_ALLOWED)
    UpdateBars()
    UpdateBinding()
    RegisterEvents()
end

----------------------------------------------------------------------
--  启动：PLAYER_LOGIN 时始终创建条 + 注册解锁元素（保证解锁模式可见），
--  仅在 enable 时才初始化内容刷新与事件监听。
----------------------------------------------------------------------
local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function()
    boot:UnregisterAllEvents()

    -- 始终创建 5 条（即使禁用），解锁模式与 getFrame 依赖 anchor 存在
    for id = 1, 5 do
        if not bars[id] then
            local ok = pcall(CreateBar, id)
            if not ok then
                -- CreateBar 失败通常是首次加载上下文问题，忽略
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
    if db and db.enable then
        Initialize()
    end

    -- 延迟 2 秒再检查并强制重设位置：EUI 解锁系统的布局可能在登录后异步覆盖位置
    C_Timer.After(2, function()
        for i = 1, 5 do ApplyAnchorPosition(i) end
    end)
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

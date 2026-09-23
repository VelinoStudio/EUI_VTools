----------------------------------------------------------------------
--  EUI_VTools — 核心入口：嵌入 EllesmereUI 设置面板
--
--  使用 EUI_Kogotool 的注入方法（侧边栏注入 + 内容区接管 + 导航 hook），
--  但置于侧边栏最后一位（而非第一位），并使用 EllesmereUI 的具名空间结构。
--
--  不修改 EllesmereUI.lua 源码，通过运行时 hook 实现。
----------------------------------------------------------------------
local _, evt = ...
local EUI = evt.EUI
local L = evt.L
local UI = evt.UI

local tinsert, tremove = table.insert, table.remove

-- 与 EUI 交互用的常量
local GROUP_KEY = UI.GROUP_KEY
local PLUS_FOLDER_PREFIX = "EUI_VTools_"

----------------------------------------------------------------------
--  页面注册表
----------------------------------------------------------------------
local pageDefs = {}

local function RegisterPage(key, nameKey, descKey, build, module)
    -- 保存英文 key，UI 渲染时才调用 L() 翻译（避免 file-scope 时 activeCatalog 未就绪）
    tinsert(pageDefs, { key = key, nameKey = nameKey, descKey = descKey, build = build, module = module })
end

-- 框架阶段只注册一个占位页，后续功能逐步添加时在此处新增 RegisterPage 调用
RegisterPage("general", "General", "General_Desc", evt.Pages.BuildGeneralPage, nil)
RegisterPage("ui", "UI", "UI_Desc", evt.Pages.BuildUIScalePage, nil)
RegisterPage("items", "Extra Items Bar", "ExtraItemsBar_Desc", evt.Pages.BuildExtraItemsPage, nil)

----------------------------------------------------------------------
--  内容区接管
----------------------------------------------------------------------
-- Plus 内容包裹帧（由 EnsurePlusWrapper 创建并赋值）
local plusContentWrapper
local activePlusPageKey
-- lastPlusPageKey：跨 close/reopen 保持最后选中的 Plus 页面
-- （与 activePlusPageKey 不同，后者是运行时状态，Hide 时会清）
local lastPlusPageKey
-- Plus 内容可见状态
local plusWrapperVisible = false

local function GetScrollChild()
    local sf = EUI and EUI._scrollFrame
    if sf and sf.GetScrollChild then
        return sf:GetScrollChild()
    end
    return nil
end

local function ClearEUIContent()
    local sc = GetScrollChild()
    if sc then
        for _, child in ipairs({sc:GetChildren()}) do
            if child ~= plusContentWrapper then
                child:Hide()
            end
        end
    end
    if EUI and EUI._pageCache then
        for _, entry in pairs(EUI._pageCache) do
            if entry and entry.wrapper then
                entry.wrapper:Hide()
            end
        end
    end
    if EUI and EUI._contentHeader then
        EUI._contentHeader:Hide()
    end
    if EUI and EUI.ClearContentHeader then
        pcall(EUI.ClearContentHeader, EUI)
    end
end

local function EnsurePlusWrapper()
    local sc = GetScrollChild()
    if not sc then return nil end

    if plusContentWrapper and plusContentWrapper.GetParent then
        if plusContentWrapper:GetParent() ~= sc then
            plusContentWrapper = nil
        end
    end

    if plusContentWrapper then return plusContentWrapper end

    local w = sc:GetWidth()
    local wrapper = CreateFrame("Frame", nil, sc)
    wrapper:SetSize(w, 1)
    wrapper:SetAllPoints(sc)
    -- 极高 frame level：保证 Plus 内容覆盖在 EUI 原生 cached wrapper 之上
    wrapper:SetFrameLevel(1000)
    wrapper:Hide()

    wrapper._pages = {}
    wrapper._pageHeights = {}

    plusContentWrapper = wrapper
    return wrapper
end

----------------------------------------------------------------------
--  页面显示
----------------------------------------------------------------------
local function ShowPlusPage(pageKey)
    if not pageDefs then return end
    local def
    for _, d in ipairs(pageDefs) do
        if d.key == pageKey then def = d; break end
    end
    if not def then return end

    local wrapper = EnsurePlusWrapper()
    if not wrapper then return end

    -- 隐藏 EUI 原生内容
    ClearEUIContent()
    if EUI and EUI._tabBar then EUI._tabBar:Hide() end

    wrapper:Show()
    plusWrapperVisible = true
    activePlusPageKey = pageKey
    lastPlusPageKey = pageKey   -- 持久化：关闭重开后仍能恢复

    -- 先隐藏所有已缓存的 Plus 页（防止内容叠加）
    for k, pg in pairs(wrapper._pages) do
        if k ~= pageKey then pg:Hide() end
    end

    -- 构建或显示目标页
    local page = wrapper._pages[pageKey]
    if not page then
        local padX = UI.PAGE_PAD_X
        local padY = UI.PAGE_PAD_Y
        page = CreateFrame("Frame", nil, wrapper)
        page:SetSize(wrapper:GetWidth(), 1)
        page:SetPoint("TOPLEFT", wrapper, "TOPLEFT", 0, 0)
        page._contentFrame = CreateFrame("Frame", nil, page)
        page._contentFrame:SetSize(wrapper:GetWidth(), 1)
        page._contentFrame:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -padY)

        if def.build then
            local contentH = def.build(page._contentFrame, 600)
            page._contentFrame:SetHeight(math.abs(contentH or 100) + padY * 2)
        end

        page:SetHeight(page._contentFrame:GetHeight() + padY * 2)
        wrapper._pages[pageKey] = page
    else
        page:Show()
    end

    -- 更新滚动区高度
    local pageH = page:GetHeight()
    wrapper._pageHeights[pageKey] = pageH
    local sc = GetScrollChild()
    if sc then sc:SetHeight(math.max(pageH, 1)) end

    -- 复位滚动
    local sf = EUI and EUI._scrollFrame
    if sf and sf.SetVerticalScroll then
        sf:SetVerticalScroll(0)
    end

    wrapper:SetFrameLevel(1000)
end

local function HidePlusContent()
    if plusContentWrapper then plusContentWrapper:Hide() end
    plusWrapperVisible = false
    activePlusPageKey = nil
end

-- 判断 EUI 原生内容是否可见（用于 Plus 层退出后判断是否需要恢复原生页）
local function NativeContentVisible()
    local sc = GetScrollChild()
    if sc then
        for _, child in ipairs({ sc:GetChildren() }) do
            if child ~= plusContentWrapper and child:IsShown() then
                return true
            end
        end
    end
    if EUI and EUI._pageCache then
        for _, entry in pairs(EUI._pageCache) do
            if entry and entry.wrapper and entry.wrapper:IsShown() then
                return true
            end
        end
    end
    return false
end

-- 深链保护标记：Plus 模块刚被 SelectModule 选中时置位，
-- 由随后（齿轮深链）紧跟的 SelectPage 调用消费并跳过，避免
-- 原版 SelectPage 用 nil 页面把刚显示的 Plus 层拆掉。
local plusJustShown = nil

----------------------------------------------------------------------
--  查找 EUI 的 headerFrame（file-local 变量，不在 EUI 全局上）
--  通过 _clickArea 子帧遍历 + 特征匹配：有 _title FontString + 位于右侧
----------------------------------------------------------------------
local function FindHeaderFrame()
    if not EUI or not EUI._clickArea then return nil end
    for _, child in ipairs({ EUI._clickArea:GetChildren() }) do
        if child._title and child._desc and child.GetChildren then
            -- 进一步确认 _title 是 FontString
            local t = child._title
            if t.GetText and t.SetText then
                return child
            end
        end
    end
    return nil
end

----------------------------------------------------------------------
--  顶部 header 更新（标题 + 描述）
--  hooksecurefunc 模式下 EUI 原版 SelectModule 已更新了 header，
--  但它用的是 EUI._modules[folderName] 的 config（我们的 Plus
--  文件夹不在 modules 里，config.title 是 nil，标题会变成文件夹名）
--  所以这里需要覆盖一下标题为正确的翻译名
----------------------------------------------------------------------
local function UpdatePlusHeader(pageDef)
    if not EUI then return end
    local hf = FindHeaderFrame()
    if hf and hf._title then
        hf._title:SetText(L(pageDef.nameKey))
    end
    if hf and hf._desc then
        hf._desc:SetText(pageDef.descKey and L(pageDef.descKey) or "")
    end
    -- 更新底部 reset 按钮（Plus 页面没有 onReset，隐藏即可）
    if EUI._UpdateResetButtonVisible then
        EUI._UpdateResetButtonVisible(false)
    end
end

----------------------------------------------------------------------
--  侧边栏高亮同步
----------------------------------------------------------------------
local function SetPlusButtonActive(pageKey)
    if not (EUI and EUI._sidebarButtons) then return end
    for folder, btn in pairs(EUI._sidebarButtons) do
        local isPlus = folder and folder:sub(1, #PLUS_FOLDER_PREFIX) == PLUS_FOLDER_PREFIX
        if isPlus then
            local isTarget = folder == PLUS_FOLDER_PREFIX .. pageKey
            -- 选中态：indicator / glow / glowTop / glowBot 全部同步
            if btn._indicator then
                if isTarget then btn._indicator:Show() else btn._indicator:Hide() end
            end
            if btn._glow then
                if isTarget then btn._glow:Show() else btn._glow:Hide() end
            end
            if btn._glowTop then
                if isTarget then btn._glowTop:Show() else btn._glowTop:Hide() end
            end
            if btn._glowBot then
                if isTarget then btn._glowBot:Show() else btn._glowBot:Hide() end
            end
            if btn._label then
                btn._label:SetAlpha(isTarget and 1 or 0.75)
            end
        else
            -- 关键：选 Plus 页面时必须熄灭所有 EUI 原生按钮的高亮
            -- 因为我们 hook SelectModule 后 return 了，EUI 自己的
            -- UpdateSidebarHighlight(folderName) 不会被调用
            if btn._indicator then btn._indicator:Hide() end
            if btn._glow then btn._glow:Hide() end
            if btn._glowTop then btn._glowTop:Hide() end
            if btn._glowBot then btn._glowBot:Hide() end
        end
    end
end

----------------------------------------------------------------------
--  侧边栏注入
----------------------------------------------------------------------
local function GetSidebarConstants()
    return
        (EUI and EUI.SIDEBAR_GROUP_ROW_H) or 28,
        (EUI and EUI.SIDEBAR_CHILD_ROW_H) or 28,
        (EUI and EUI.SIDEBAR_GROUP_GAP) or 10
end

local function CreatePlusGroupHeader(parent)
    local h = (EUI and EUI.SIDEBAR_GROUP_ROW_H) or 28
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(EUI._sidebar:GetWidth(), h)
    row:SetFrameLevel(parent:GetFrameLevel() + 1)

    local r, g, b = UI.ACCENT_R, UI.ACCENT_G, UI.ACCENT_B
    local EG = EUI and EUI.ELLESMERE_GREEN
    if EG and EG.r then r, g, b = EG.r, EG.g, EG.b end

    local label = UI.MakeFont(row, 15, r, g, b, 1)
    label:SetPoint("LEFT", row, "LEFT", (EUI.NAV_LEFT or 20), 0)
    label:SetText(L("Velino Toolbox"))

    row._isGroup = true
    row._groupKey = GROUP_KEY
    row._label = label
    return row
end

local function DecorateChildRow(btn)
    local EG = (EUI and EUI.ELLESMERE_GREEN) or { r = UI.ACCENT_R, g = UI.ACCENT_G, b = UI.ACCENT_B }

    -- 选中态左侧竖条（与 EUI 一致：BORDER 层）
    local indicator = btn:CreateTexture(nil, "BORDER")
    indicator:SetColorTexture(EG.r, EG.g, EG.b, 1)
    indicator:SetWidth(3)
    indicator:SetPoint("TOPLEFT", btn, "TOPLEFT", -1, 0)
    indicator:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", -1, 0)
    indicator:Hide()
    btn._indicator = indicator

    -- 选中态整行辉光（水平渐变，与 EUI MakeNavGradient 一致）
    local glow = btn:CreateTexture(nil, "BACKGROUND")
    glow:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
    glow:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
    glow:SetColorTexture(EG.r, EG.g, EG.b, 1)
    glow:SetGradient("HORIZONTAL", CreateColor(EG.r, EG.g, EG.b, 0.15), CreateColor(EG.r, EG.g, EG.b, 0))
    glow:Hide()
    btn._glow = glow

    -- 选中态顶/底边缘线（与 EUI MakeNavEdgeLine 一致：1px 灰白渐变）
    local function makeEdge(edge)
        local g = btn:CreateTexture(nil, "BORDER")
        g:SetHeight(1)
        g:SetPoint(edge .. "LEFT", btn, edge .. "LEFT", 0, 0)
        g:SetPoint(edge .. "RIGHT", btn, edge .. "RIGHT", 0, 0)
        g:SetColorTexture(0.7, 0.7, 0.7, 1)
        g:SetGradient("HORIZONTAL", CreateColor(0.7, 0.7, 0.7, 0.5), CreateColor(0.7, 0.7, 0.7, 0))
        g:Hide()
        return g
    end
    btn._glowTop = makeEdge("TOP")
    btn._glowBot = makeEdge("BOTTOM")

    -- hover 辉光
    local hR, hG, hB = 0.85, 0.95, 0.90
    btn._hoverGlow = btn:CreateTexture(nil, "BACKGROUND")
    btn._hoverGlow:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
    btn._hoverGlow:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
    btn._hoverGlow:SetColorTexture(hR, hG, hB, 1)
    btn._hoverGlow:SetGradient("HORIZONTAL", CreateColor(hR, hG, hB, 0.03), CreateColor(hR, hG, hB, 0))
    btn._hoverGlow:Hide()

    local hoverInd = btn:CreateTexture(nil, "BORDER")
    hoverInd:SetColorTexture(hR, hG, hB, 0.25)
    hoverInd:SetWidth(3)
    hoverInd:SetPoint("TOPLEFT", btn, "TOPLEFT", -1, 0)
    hoverInd:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", -1, 0)
    hoverInd:Hide()
    btn._hoverIndicator = hoverInd

    -- 未加载下载图标占位（EUI RefreshSidebarStates 会访问 btn._dlIcon）
    local dlIcon = btn:CreateTexture(nil, "ARTWORK")
    dlIcon:SetSize(18, 18)
    dlIcon:SetPoint("RIGHT", btn, "RIGHT", -14, 0)
    dlIcon:Hide()
    btn._dlIcon = dlIcon

    -- 整体 hover 高亮蒙版
    local hover = btn:CreateTexture(nil, "HIGHLIGHT")
    hover:SetColorTexture(1, 1, 1, 0)
    hover:SetAllPoints()

    btn:SetScript("OnEnter", function(self)
        if activePlusPageKey and self._pageKey == activePlusPageKey then return end
        self._hoverGlow:Show()
        self._hoverIndicator:Show()
        self._indicator:Show()
        self._label:SetAlpha(1)
    end)
    btn:SetScript("OnLeave", function(self)
        if activePlusPageKey and self._pageKey == activePlusPageKey then return end
        self._hoverGlow:Hide()
        self._hoverIndicator:Hide()
        self._indicator:Hide()
        self._label:SetAlpha(0.75)
    end)
end

local function CreatePlusChildRow(parent, pageDef, indentX)
    local h = (EUI and EUI.SIDEBAR_CHILD_ROW_H) or 28
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(EUI._sidebar:GetWidth(), h)
    btn:SetFrameLevel(parent:GetFrameLevel() + 1)

    DecorateChildRow(btn)

    local label = UI.MakeFont(btn, 14, 1, 1, 1, 0.75)
    label:SetPoint("LEFT", btn, "LEFT", indentX, 0)
    label:SetText(L(pageDef.nameKey))
    btn._label = label
    btn._pageKey = pageDef.key
    btn._folder = PLUS_FOLDER_PREFIX .. pageDef.key
    btn._loaded = true

    btn:SetScript("OnClick", function()
        SetPlusButtonActive(pageDef.key)
        ShowPlusPage(pageDef.key)
        UpdatePlusHeader(pageDef)
    end)

    return btn
end

local function RebuildSidebarLayout()
    if not (EUI and EUI._addonScrollChild and EUI.ADDON_GROUPS) then return end

    local scrollChild = EUI._addonScrollChild
    local sbButtons = EUI._sidebarButtons
    local groupHeaders = EUI._sidebarGroupButtons
    local groupH, childH, groupGap = GetSidebarConstants()
    local y = 0

    for i, group in ipairs(EUI.ADDON_GROUPS) do
        if i > 1 then y = y + groupGap end
        local header = groupHeaders and groupHeaders[group.key]
        if header then
            header:ClearAllPoints()
            header:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -y)
            header:Show()
            y = y + groupH
        end
        for _, folder in ipairs(group.members) do
            local btn = sbButtons and sbButtons[folder]
            if btn then
                btn:ClearAllPoints()
                btn:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -y)
                btn:Show()
                y = y + childH
            end
        end
    end

    scrollChild:SetHeight(math.max(childH or 28, y))
end

local sidebarInjected = false

local function InjectPlusSidebar()
    if sidebarInjected then return true end
    if not (EUI and EUI._sidebar and EUI._addonScrollChild and EUI.ADDON_GROUPS) then return false end

    local scrollChild = EUI._addonScrollChild
    local sbButtons = EUI._sidebarButtons
    if not sbButtons then return false end

    local groupH, childH, groupGap = GetSidebarConstants()
    local indentX = (EUI.NAV_LEFT or 18) + 16

    -- 注册 Plus 分组到 ADDON_GROUPS
    local group = { key = GROUP_KEY, label = L("Velino Toolbox"), members = {} }
    for _, def in ipairs(pageDefs) do
        local folder = PLUS_FOLDER_PREFIX .. def.key
        tinsert(group.members, folder)
        if EUI._addonInfoByFolder then
            EUI._addonInfoByFolder[folder] = {
                folder = folder,
                display = L(def.nameKey),
                alwaysLoaded = true,
            }
        end
    end

    -- 移除可能已存在的旧分组（防重复注入）
    for i = #EUI.ADDON_GROUPS, 1, -1 do
        if EUI.ADDON_GROUPS[i] and EUI.ADDON_GROUPS[i].key == GROUP_KEY then
            tremove(EUI.ADDON_GROUPS, i)
        end
    end

    -- 关键差异：置于侧边栏最后一位（append to end）
    -- EUI_Kogotool 用 tinsert(..., 1) 置于第一位，这里用 tinsert(...) 追加到末尾
    tinsert(EUI.ADDON_GROUPS, group)

    -- 创建 header 并登记到 EUI 的分组标题表
    if EUI._sidebarGroupButtons then
        EUI._sidebarGroupButtons[GROUP_KEY] = CreatePlusGroupHeader(scrollChild)
    end

    -- 创建子项
    for _, def in ipairs(pageDefs) do
        local folder = PLUS_FOLDER_PREFIX .. def.key
        local btn = CreatePlusChildRow(scrollChild, def, indentX)
        sbButtons[folder] = btn
    end

    RebuildSidebarLayout()
    sidebarInjected = true
    return true
end

----------------------------------------------------------------------
--  导航 hook
----------------------------------------------------------------------
local function HookEUINavigation()
    if not EUI then return end

    -- Hook SelectModule：用 hooksecurefunc 后处理
    -- 原版 SelectModule 在 modules[folderName] 不存在时会早 return（line 10300），
    -- 所以 Plus 文件夹不会触发任何原版逻辑（header、highlight、BuildTabs）
    -- 我们的后处理接管全部 UI 更新
    if EUI.SelectModule and not EUI._vtoolsHookedSelect then
        hooksecurefunc(EUI, "SelectModule", function(self, folderName)
            if folderName and folderName:sub(1, #PLUS_FOLDER_PREFIX) == PLUS_FOLDER_PREFIX then
                local pageKey = folderName:sub(#PLUS_FOLDER_PREFIX + 1)
                local pageDef
                for _, d in ipairs(pageDefs) do
                    if d.key == pageKey then pageDef = d; break end
                end
                -- 原版 SelectModule 早 return 了，header/highlight 都没更新
                -- 我们接管：清 EUI 原生内容 + 显示 Plus 内容 + 更新高亮 + 更新 header
                ClearEUIContent()
                ShowPlusPage(pageKey)
                SetPlusButtonActive(pageKey)
                if pageDef then UpdatePlusHeader(pageDef) end
                plusJustShown = pageKey
            else
                -- 切到原生模块：原版 SelectModule 已成功执行（更新了 header、
                -- 原生按钮高亮、BuildTabs），我们只需隐藏 Plus 层 + 熄灭 Plus 按钮高亮
                plusJustShown = nil
                if plusContentWrapper then plusContentWrapper:Hide() end
                plusWrapperVisible = false
                activePlusPageKey = nil
                for fld, b in pairs(EUI._sidebarButtons) do
                    if fld:sub(1, #PLUS_FOLDER_PREFIX) == PLUS_FOLDER_PREFIX then
                        if b._glow then b._glow:Hide() end
                        if b._glowTop then b._glowTop:Hide() end
                        if b._glowBot then b._glowBot:Hide() end
                        if b._label then b._label:SetAlpha(0.75) end
                    end
                end
                -- 原版可能因「同模块重复选中」早 return（未重建原生内容）。
                -- 若 Plus 层刚隐藏且原生内容不可见，主动恢复原生页面。
                if EUI.RefreshPage and not NativeContentVisible() then
                    EUI:RefreshPage(true)
                end
            end
        end)
        EUI._vtoolsHookedSelect = true
    end

    -- Hook SelectPage：Plus 层显示时强制熄灭，防止与原生内容重叠
    if EUI.SelectPage and not EUI._vtoolsHookedPage then
        local origPage = EUI.SelectPage
        local inPageRestore = false
        EUI.SelectPage = function(self, pageName)
            -- 齿轮深链：SelectModule(Plus) 后紧跟 SelectPage(nil) 或 SelectPage("items")。
            -- Plus 模块不在原版 modules 表里，activeModule 仍是旧原生模块，
            -- 原版会用 nil 页面拆掉刚显示的 Plus 层甚至破坏原生页状态。
            if plusJustShown then
                plusJustShown = nil
                -- 若深链指定了具体 Plus 页面（如 "items"），直接切换到该页
                if pageName then
                    ShowPlusPage(pageName)
                    SetPlusButtonActive(pageName)
                    -- 查找 pageDef 更新 header
                    for _, d in ipairs(pageDefs) do
                        if d.key == pageName then UpdatePlusHeader(d); break end
                    end
                    return
                end
                return
            end
            plusJustShown = nil
            if plusContentWrapper then plusContentWrapper:Hide() end
            plusWrapperVisible = false
            activePlusPageKey = nil
            local result = origPage(self, pageName)
            -- 原版可能因「同页面重复选中」早 return（未重建原生内容）。
            -- 若 Plus 层刚隐藏且原生内容不可见，主动恢复原生页面（防重入）。
            if not inPageRestore and EUI.RefreshPage and not NativeContentVisible() then
                inPageRestore = true
                EUI:RefreshPage(true)
                inPageRestore = false
            end
            return result
        end
        EUI._vtoolsHookedPage = true
    end

    -- 监听主窗口 Show/Toggle（EUI:Show() 和 EUI:Toggle()）
    -- 关键：不用 mainFrame:HookScript("OnShow")，因为 _mainFrame 在注入时
    -- 可能还不存在（懒创建），hook 永远不注册。EUI:Show()/Toggle() 是
    -- table 方法，注入时一定存在。
    local function _onPanelShown()
        C_Timer.After(0, function()
            if not EUI:IsShown() then return end
            -- 优先用持久化的 lastPlusPageKey（跨 close/reopen）
            -- HidePlusContent 清 activePlusPageKey 但保留 lastPlusPageKey
            local restoreKey = lastPlusPageKey
            if not restoreKey then return end
            -- 如果当前 activeModule 已经是这个 Plus 页面，不用再恢复
            local curMod = (EUI.GetActiveModule and EUI:GetActiveModule()) or nil
            if curMod == PLUS_FOLDER_PREFIX .. restoreKey then return end
            -- 用 EUI:SelectModule 触发完整流程（header/highlight/BuildTabs）
            EUI:SelectModule(PLUS_FOLDER_PREFIX .. restoreKey)
        end)
    end

    if EUI.Show and not EUI._vtoolsHookedShow then
        hooksecurefunc(EUI, "Show", _onPanelShown)
        EUI._vtoolsHookedShow = true
    end
    if EUI.Toggle and not EUI._vtoolsHookedToggle then
        hooksecurefunc(EUI, "Toggle", function()
            -- Toggle 可能 Hide 或 Show，只在 Show 时恢复
            if EUI:IsShown() then _onPanelShown() end
        end)
        EUI._vtoolsHookedToggle = true
    end

    -- Hook RefreshPage：覆盖绕过 SelectModule/SelectPage 的原生页面重建路径
    if EUI.RefreshPage and not EUI._vtoolsHookedRefresh then
        hooksecurefunc(EUI, "RefreshPage", function()
            if plusWrapperVisible and activePlusPageKey then
                ClearEUIContent()
                if plusContentWrapper then plusContentWrapper:Show() end
                SetPlusButtonActive(activePlusPageKey)
                return
            end
            if not EUI.GetActiveModule then return end
            local mod = EUI:GetActiveModule()
            if not mod then return end
            if mod:sub(1, #PLUS_FOLDER_PREFIX) == PLUS_FOLDER_PREFIX then return end
            if plusContentWrapper then plusContentWrapper:Hide() end
            activePlusPageKey = nil
        end)
        EUI._vtoolsHookedRefresh = true
    end

    -- 齿轮"元素选项"深链：解锁元素 → evt 设置页
    -- （与 ExtraItemBar.lua 的 BUTTON_PREFIX 对应）
    local mapTarget = EUI._elemMapPre or EUI._ELEMENT_SETTINGS_MAP
    if mapTarget then
        for i = 1, 5 do
            local key = "EVT_ExtraItemsBar" .. i
            if mapTarget[key] == nil then
                mapTarget[key] = { module = "EUI_VTools_items", page = "items" }
            end
        end
    end
end

----------------------------------------------------------------------
--  轮询注入
----------------------------------------------------------------------
local injectTicker
local function StartInjectLoop()
    if injectTicker then return end
    injectTicker = C_Timer.NewTicker(0.5, function()
        if InjectPlusSidebar() then
            HookEUINavigation()
            injectTicker:Cancel()
            injectTicker = nil
        end
    end)
end

----------------------------------------------------------------------
--  启动
----------------------------------------------------------------------
local boot = CreateFrame("Frame")
boot:RegisterEvent("ADDON_LOADED")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(_, event, loaded)
    if event == "ADDON_LOADED" and loaded == "EllesmereUI" then
        StartInjectLoop()
    elseif event == "PLAYER_LOGIN" then
        StartInjectLoop()
    end
end)

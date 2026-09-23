----------------------------------------------------------------------
--  EUI_VTools — 界面缩放核心
--  功能：调整游戏内各类窗体的缩放比例，支持滑块设置与右下角拖拽。
--  数据：写入 evt.db.profile.uiScale（EUI profile，随导出导入）。
--
--  设计要点：
--    1. 缩放值范围 [0.3, 2.0]，步进 0.05
--    2. 锁定=true 时隐藏拖拽手柄；锁定=false 时显示
--    3. WorldMapFrame 全屏（maximized）时隐藏手柄，不修改锁定配置
--    4. GameTooltip 无锁定开关，每次显示时重新应用 scale（防被覆盖）
--    5. LoadOnDemand 窗体（Mail/Collections/Professions）在 ADDON_LOADED 时应用
----------------------------------------------------------------------
local _, evt = ...
local db = evt.db.profile

-- 缩放范围常量
local SCALE_MIN = 0.3
local SCALE_MAX = 2.0
local SCALE_STEP = 0.05

-- 窗体注册表：key = 配置键，frameFn = 获取 frame 的函数，lazy = 是否延迟加载
local frames = {
    { key = "character",   name = "CharacterFrame",    lazy = false },  -- 顶层窗体（PaperDollFrame 是其子帧）
    { key = "friends",     name = "FriendsFrame",      lazy = false },
    { key = "mail",        name = "MailFrame",         lazy = true  },
    { key = "collections", name = "CollectionsJournal",lazy = true  },
    { key = "merchant",    name = "MerchantFrame",     lazy = false },
    { key = "professions", name = "ProfessionsFrame",  lazy = true  },
    { key = "map",         name = "WorldMapFrame",     lazy = false },
}

-- 已安装 handle 的窗体（防重复）
local handleInstalled = {}

-- 拖拽手柄的全局 frame 层级（保证在窗体之上）
local function GetHandleFrameLevel()
    return 50
end

----------------------------------------------------------------------
--  工具：clamp 缩放到合法范围
----------------------------------------------------------------------
local function ClampScale(v)
    if type(v) ~= "number" then return 1 end
    return math.max(SCALE_MIN, math.min(SCALE_MAX, v))
end

----------------------------------------------------------------------
--  工具：步进取整（0.05 对齐）
----------------------------------------------------------------------
local function SnapScale(v)
    return SCALE_MIN + math.floor((ClampScale(v) - SCALE_MIN) / SCALE_STEP + 0.5) * SCALE_STEP
end

----------------------------------------------------------------------
--  应用缩放到指定 frame
----------------------------------------------------------------------
local function ApplyScale(frame, scale)
    if not frame then return end
    frame:SetScale(ClampScale(scale))
end

----------------------------------------------------------------------
--  从配置读取并应用某个窗体的缩放
----------------------------------------------------------------------
local function ApplyFrameScale(key)
    local cfg = db.uiScale[key]
    if not cfg then return end
    local info = frames[key] and frames[key] or nil
    for _, f in ipairs(frames) do
        if f.key == key then info = f; break end
    end
    if not info then return end
    local frame = _G[info.name]
    if frame then
        ApplyScale(frame, cfg.scale)
    end
end

----------------------------------------------------------------------
--  应用所有已加载窗体的缩放
----------------------------------------------------------------------
local function ApplyAllScales()
    for _, info in ipairs(frames) do
        local frame = _G[info.name]
        if frame then
            ApplyScale(frame, db.uiScale[info.key].scale)
        end
    end
    -- Tooltip 单独处理
    if GameTooltip then
        ApplyScale(GameTooltip, db.uiScale.tooltip.scale)
    end
end

----------------------------------------------------------------------
--  右下角拖拽手柄
----------------------------------------------------------------------
local function CreateResizeHandle(frame, key)
    if handleInstalled[frame] then return handleInstalled[frame] end

    local handle = CreateFrame("Button", nil, frame)
    handle:SetSize(16, 16)
    handle:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
    handle:SetFrameLevel(frame:GetFrameLevel() + 10)
    handle:EnableMouse(true)

    -- 手柄图标（复用 EUI 的 resize 图标）
    local tex = handle:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    local icon = (evt.EUI and evt.EUI.RESIZE_ICON) or "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up"
    tex:SetTexture(icon)
    tex:SetVertexColor(1, 1, 1, 0.6)

    -- hover 高亮
    handle:SetScript("OnEnter", function() tex:SetVertexColor(1, 1, 1, 1) end)
    handle:SetScript("OnLeave", function() tex:SetVertexColor(1, 1, 1, 0.6) end)

    -- 拖拽状态
    local isDragging = false
    local startX, startY
    local startScale

    handle:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end
        isDragging = true
        startX, startY = GetCursorPosition()
        startScale = frame:GetScale()
        self:SetScript("OnUpdate", function()
            if not isDragging then return end
            local x, y = GetCursorPosition()
            -- 以窗体原始宽度为基准计算缩放增量
            local baseW = frame:GetWidth() / startScale
            if baseW <= 0 then return end
            local dx = (x - startX) / frame:GetEffectiveScale()
            local newScale = SnapScale(startScale + dx / baseW)
            if newScale ~= frame:GetScale() then
                ApplyScale(frame, newScale)
                db.uiScale[key].scale = newScale
            end
        end)
    end)

    handle:SetScript("OnMouseUp", function(self)
        isDragging = false
        self:SetScript("OnUpdate", nil)
    end)

    handle:Hide()
    handleInstalled[frame] = handle
    return handle
end

----------------------------------------------------------------------
--  更新手柄可见性（根据锁定状态 + 特殊条件）
----------------------------------------------------------------------
local function UpdateHandleVisibility(key)
    local info
    for _, f in ipairs(frames) do
        if f.key == key then info = f; break end
    end
    if not info then return end
    local frame = _G[info.name]
    if not frame then return end

    local handle = handleInstalled[frame]
    if not handle then return end

    local cfg = db.uiScale[key]
    local locked = cfg.locked

    -- WorldMapFrame 全屏时强制隐藏手柄（不修改锁定配置）
    if key == "map" and frame.IsMaximized and frame:IsMaximized() then
        handle:Hide()
        return
    end

    if locked then
        handle:Hide()
    else
        handle:Show()
    end
end

----------------------------------------------------------------------
--  安装所有已加载窗体的手柄
----------------------------------------------------------------------
local function InstallHandles()
    for _, info in ipairs(frames) do
        local frame = _G[info.name]
        if frame and not handleInstalled[frame] then
            CreateResizeHandle(frame, info.key)
            UpdateHandleVisibility(info.key)
        end
    end
end

----------------------------------------------------------------------
--  WorldMapFrame 全屏切换监听
----------------------------------------------------------------------
local function HookMapMaximized()
    local frame = _G.WorldMapFrame
    if not frame then return end
    if frame._evtHooked then return end

    -- hook SetMaximized 切换时更新手柄可见性
    if frame.SetMaximized then
        hooksecurefunc(frame, "SetMaximized", function()
            C_Timer.After(0, function() UpdateHandleVisibility("map") end)
        end)
    end

    frame._evtHooked = true
end

----------------------------------------------------------------------
--  GameTooltip 缩放 hook（每次显示时重新应用，防被覆盖）
----------------------------------------------------------------------
local function HookTooltipScale()
    if not GameTooltip then return end
    if GameTooltip._evtHooked then return end

    local function Reapply()
        ApplyScale(GameTooltip, db.uiScale.tooltip.scale)
    end

    hooksecurefunc(GameTooltip, "Show", Reapply)
    hooksecurefunc(GameTooltip, "SetUnit", Reapply)
    hooksecurefunc(GameTooltip, "SetUnitAura", Reapply)
    hooksecurefunc(GameTooltip, "SetUnitBuff", Reapply)
    hooksecurefunc(GameTooltip, "SetUnitDebuff", Reapply)
    hooksecurefunc(GameTooltip, "SetItemByID", Reapply)

    GameTooltip._evtHooked = true
    Reapply()
end

----------------------------------------------------------------------
--  OnShow hook：窗体显示时重新应用 scale（防 Blizzard 内部重置）
----------------------------------------------------------------------
local function HookOnShowScales()
    for _, info in ipairs(frames) do
        local frame = _G[info.name]
        if frame and not frame._evtScaleHooked then
            frame:HookScript("OnShow", function()
                ApplyScale(frame, db.uiScale[info.key].scale)
                UpdateHandleVisibility(info.key)
            end)
            frame._evtScaleHooked = true
        end
    end
end

----------------------------------------------------------------------
--  延迟加载窗体的 ADDON_LOADED 处理
----------------------------------------------------------------------
local lazyAddons = {
    ["Blizzard_MailUI"] = "mail",
    ["Blizzard_Collections"] = "collections",
    ["Blizzard_Professions"] = "professions",
}

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self, event, arg)
    if event == "ADDON_LOADED" then
        local key = lazyAddons[arg]
        if key then
            ApplyFrameScale(key)
            local info
            for _, fi in ipairs(frames) do
                if fi.key == key then info = fi; break end
            end
            local frame = info and _G[info.name]
            if frame then
                CreateResizeHandle(frame, key)
                UpdateHandleVisibility(key)
                if not frame._evtScaleHooked then
                    frame:HookScript("OnShow", function()
                        ApplyScale(frame, db.uiScale[key].scale)
                        UpdateHandleVisibility(key)
                    end)
                    frame._evtScaleHooked = true
                end
            end
        end
    elseif event == "PLAYER_LOGIN" then
        ApplyAllScales()
        InstallHandles()
        HookOnShowScales()
        HookMapMaximized()
        HookTooltipScale()
    end
end)

----------------------------------------------------------------------
--  暴露 API（供 Pages 设置页调用）
----------------------------------------------------------------------
evt.UIScale = {
    SCALE_MIN = SCALE_MIN,
    SCALE_MAX = SCALE_MAX,
    SCALE_STEP = SCALE_STEP,

    -- 读取某个窗体的缩放值
    GetScale = function(key)
        return db.uiScale[key] and db.uiScale[key].scale or 1
    end,

    -- 设置某个窗体的缩放值并立即应用
    SetScale = function(key, scale)
        if not db.uiScale[key] then return end
        scale = SnapScale(scale)
        db.uiScale[key].scale = scale
        ApplyFrameScale(key)
        -- Tooltip 单独处理
        if key == "tooltip" and GameTooltip then
            ApplyScale(GameTooltip, scale)
        end
    end,

    -- 读取锁定状态
    GetLocked = function(key)
        return db.uiScale[key] and db.uiScale[key].locked or false
    end,

    -- 设置锁定状态
    SetLocked = function(key, locked)
        if not db.uiScale[key] then return end
        db.uiScale[key].locked = locked
        UpdateHandleVisibility(key)
    end,

    -- 重置所有缩放到默认值 1
    ResetAll = function()
        for key, _ in pairs(db.uiScale) do
            db.uiScale[key].scale = 1
        end
        ApplyAllScales()
    end,
}

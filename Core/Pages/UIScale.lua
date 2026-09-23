----------------------------------------------------------------------
--  EUI_VTools — 界面缩放设置页
--  布局：每个窗体一个区块（SectionHeader + DualRow 左滑块右开关）
--        Tooltip 例外：滑块 + 实时预览框（无锁定开关）
----------------------------------------------------------------------
local _, evt = ...
local L = evt.L
local UI = evt.UI
local US = evt.UIScale

-- 窗体区块配置：key, 标题文本 key, tooltip 文本
local sections = {
    { key = "character",   title = "Character" },
    { key = "friends",     title = "Friends" },
    { key = "mail",        title = "Mail" },
    { key = "collections", title = "Collections" },
    { key = "merchant",    title = "Merchant" },
    { key = "tooltip",     title = "Tooltip" },
    { key = "professions", title = "Professions" },
    { key = "map",         title = "World Map" },  -- 含任务日志
}

-- 通用滑块配置生成器
local function MakeSliderCfg(key)
    return {
        type = "slider",
        text = L("Scale"),
        min = US.SCALE_MIN,
        max = US.SCALE_MAX,
        step = US.SCALE_STEP,
        getValue = function() return US.GetScale(key) end,
        setValue = function(v) US.SetScale(key, v) end,
        tooltip = L("Adjust the frame scale. 1 = original size."),
    }
end

-- 通用锁定开关配置生成器
local function MakeToggleCfg(key)
    return {
        type = "toggle",
        text = L("Locked"),
        getValue = function() return US.GetLocked(key) end,
        setValue = function(v) US.SetLocked(key, v) end,
        tooltip = L("When locked, the frame cannot be resized by dragging its bottom-right corner."),
    }
end

----------------------------------------------------------------------
--  Tooltip 预览框（模拟 GameTooltip 外观，实时反映缩放）
----------------------------------------------------------------------
local tooltipPreview

local function BuildTooltipPreview(parent, y)
    local padX = UI.PAGE_PAD_X
    local w = parent:GetWidth() - padX * 2
    local previewW = 320   -- 预览框固定宽
    local previewH = 90    -- 预览框固定高

    -- 外层 wrapper：固定占位，防止 SetScale 影响布局
    local wrapper = CreateFrame("Frame", nil, parent)
    wrapper:SetSize(w, previewH + 8)
    wrapper:SetPoint("TOPLEFT", parent, "TOPLEFT", padX, y)

    -- 内层预览框：锚定到 wrapper 中心，SetScale 从此缩放
    local frame = CreateFrame("Frame", nil, wrapper)
    frame:SetSize(previewW, previewH)
    frame:SetPoint("CENTER", wrapper, "CENTER", 0, 0)

    -- 背景（模拟 tooltip 深色底）
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.85)

    -- 边框（模拟 tooltip 金边）
    UI.ApplyBorder(frame, 1, 0.7, 0, 0.6)

    -- 模拟 tooltip 内容
    local pad = 10
    -- 第一行：物品名（稀有品质色：蓝）
    local name = UI.MakeFont(frame, 13, 0.2, 0.6, 1, 1)
    name:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, -pad)
    name:SetText("[EUI_VTools Sample Item]")

    -- 第二行：物品等级
    local ilvl = UI.MakeFont(frame, 12, 0.8, 0.8, 0.8, 0.9)
    ilvl:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -4)
    ilvl:SetText(L("Item Level") .. " 600")

    -- 第三行：描述
    local desc = UI.MakeFont(frame, 12, 0.9, 0.9, 0.9, 0.85)
    desc:SetPoint("TOPLEFT", ilvl, "BOTTOMLEFT", 0, -8)
    desc:SetText(L("Sample tooltip description line one."))

    -- 第四行：卖价
    local price = UI.MakeFont(frame, 12, 1, 0.82, 0, 1)
    price:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -8)
    price:SetText(L("Sell Price") .. ": 12g 34s 56c")

    -- 初始缩放
    frame:SetScale(US.GetScale("tooltip"))

    tooltipPreview = frame
    return wrapper, previewH + 16
end

-- 当 tooltip 缩放改变时更新预览
hooksecurefunc(US, "SetScale", function(key, scale)
    if key == "tooltip" and tooltipPreview and tooltipPreview.SetScale then
        tooltipPreview:SetScale(scale)
    end
end)

----------------------------------------------------------------------
--  页面构建器
----------------------------------------------------------------------
function evt.Pages.BuildUIScalePage(parent, contentH)
    local W = evt.EUI.Widgets
    local padX = UI.PAGE_PAD_X
    local y = -UI.PAGE_PAD_Y

    if not W then
        local err = UI.MakeFont(parent, 16, 1, 0.3, 0.3, 1)
        err:SetPoint("TOPLEFT", parent, "TOPLEFT", padX, y)
        err:SetText("EllesmereUI.Widgets not available")
        return y - 40
    end

    for _, sec in ipairs(sections) do
        local key = sec.key

        -- 区块标题
        local _, headerH = W:SectionHeader(parent, sec.title, y)
        y = y - headerH

        if key == "tooltip" then
            -- Tooltip：整行滑块 + 预览框（无锁定开关）
            local sliderRow, sliderH = W:Slider(
                parent, L("Scale"), y,
                US.SCALE_MIN, US.SCALE_MAX, US.SCALE_STEP,
                function() return US.GetScale(key) end,
                function(v) US.SetScale(key, v) end,
                L("Adjust the tooltip scale. 1 = original size.")
            )
            y = y - sliderH - 6

            -- 预览框
            local preview, previewH = BuildTooltipPreview(parent, y)
            y = y - previewH - 16
        else
            -- 普通窗体：左滑块 + 右锁定开关
            local dualRow, dualH = W:DualRow(parent, y,
                MakeSliderCfg(key),
                MakeToggleCfg(key)
            )
            y = y - dualH - 8
        end
    end

    -- 底部：重置全部按钮
    y = y - 8
    local resetBtn, resetH = W:WideButton(parent, L("Reset All Scales"), y, function()
        US.ResetAll()
    end, 200)
    y = y - resetH

    return y
end

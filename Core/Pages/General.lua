----------------------------------------------------------------------
--  EUI_VTools — 通用页构建器（占位页）
--  框架阶段仅展示欢迎信息与插件元数据，后续功能逐步添加时替换此页内容。
----------------------------------------------------------------------
local _, evt = ...
local L = evt.L
local UI = evt.UI

evt.Pages = evt.Pages or {}

function evt.Pages.BuildGeneralPage(parent, contentH)
    local padX = evt.UI.PAGE_PAD_X
    local padY = evt.UI.PAGE_PAD_Y
    local y = -padY

    -- 插件图标（media/evt_logo.tga）
    local icon = parent:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(evt.UI.ICON)
    icon:SetSize(34, 34)
    icon:SetPoint("TOPLEFT", parent, "TOPLEFT", padX, y)

    -- 标题区（图标右侧）
    local title = UI.MakeFont(parent, 22, UI.ACCENT_R, UI.ACCENT_G, UI.ACCENT_B, 1)
    title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 12, -6)
    title:SetText(L["Welcome to EUI_VTools"])
    y = y - math.max(icon:GetHeight(), title:GetStringHeight()) - 16

    -- 元数据行
    local metaFs = UI.MakeFont(parent, 14, 0.60, 0.60, 0.60, 0.85)
    metaFs:SetPoint("TOPLEFT", parent, "TOPLEFT", padX, y)
    metaFs:SetText(L["Author"] .. ": Velino    " .. L["Version"] .. ": 0.1.0")
    y = y - metaFs:GetStringHeight() - 20

    -- 说明文案
    local desc, descH = UI.SectionHeader(parent, "Framework ready", y)
    y = y - descH - 8

    local body = UI.MakeFont(parent, 14, 0.70, 0.70, 0.70, 0.80)
    body:SetPoint("TOPLEFT", parent, "TOPLEFT", padX, y)
    body:SetText(L["Framework ready"])
    body:SetWidth(parent:GetWidth() - padX * 2)
    y = y - body:GetStringHeight() - 20

    return y
end

----------------------------------------------------------------------
--  EUI_VTools — UI 原语与常量
--  复用 EllesmereUI 的视觉常量与配色，保证 Plus 页面与 EUI 原生页风格一致。
--  不自造设计语言：所有颜色 / 字体 / 边距均从 EUI 读取，EUI 无则用合理默认。
----------------------------------------------------------------------
local _, evt = ...
local EUI = evt.EUI
local L = evt.L

-- 侧边栏分组标识（与 EUI 原生分组 key 不冲突）
evt.UI.GROUP_KEY = "vtools"

-- 内容页边距：与 EUI 原生 CONTENT_PAD 对齐，保证行背景不错位
evt.UI.PAGE_PAD_X = (EUI and EUI.CONTENT_PAD) or 45
evt.UI.PAGE_PAD_Y = 14

----------------------------------------------------------------------
-- 视觉常量（沿用 EUI 青色/深色主题）
----------------------------------------------------------------------
local ACCENT_HEX = "4accff"
evt.UI.ACCENT_HEX = ACCENT_HEX
evt.UI.ACCENT_R, evt.UI.ACCENT_G, evt.UI.ACCENT_B = 0.29, 0.80, 1.00

----------------------------------------------------------------------
-- 工具：纯色纹理
----------------------------------------------------------------------
function evt.UI.SolidTex(parent, layer, r, g, b, a)
    local t = parent:CreateTexture(nil, layer)
    t:SetColorTexture(r, g, b, a)
    return t
end

----------------------------------------------------------------------
-- 工具：字体串（与 EUI MakeFont 一致：不继承 GameFontNormal 模板）
----------------------------------------------------------------------
function evt.UI.MakeFont(parent, size, r, g, b, a)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    local path = (EUI and EUI.EXPRESSWAY) or "Fonts\\FRIZQT__.TTF"
    fs:SetFont(path, size or 14, "")
    if r then fs:SetTextColor(r, g, b, a or 1) end
    return fs
end

----------------------------------------------------------------------
-- 工具：1px 边框（WoW 11.0+ 无 SetBackdrop）
----------------------------------------------------------------------
function evt.UI.ApplyBorder(frame, r, g, b, a)
    a = a or 0.8
    local function tex()
        local t = frame:CreateTexture(nil, "OVERLAY", nil, 1)
        t:SetColorTexture(r, g, b, a)
        return t
    end
    local top = tex(); top:SetPoint("TOPLEFT", frame); top:SetPoint("TOPRIGHT", frame); top:SetHeight(1)
    local bot = tex(); bot:SetPoint("BOTTOMLEFT", frame); bot:SetPoint("BOTTOMRIGHT", frame); bot:SetHeight(1)
    local lef = tex(); lef:SetPoint("TOPLEFT", frame); lef:SetPoint("BOTTOMLEFT", frame); lef:SetWidth(1)
    local rig = tex(); rig:SetPoint("TOPRIGHT", frame); rig:SetPoint("BOTTOMRIGHT", frame); rig:SetWidth(1)
end

----------------------------------------------------------------------
-- 工具：tooltip 显示（金色标题 + 白色说明 + 插件字体）
----------------------------------------------------------------------
function evt.UI.ShowTip(owner, title, text)
    if not owner then return end
    GameTooltip:SetOwner(owner, "ANCHOR_TOPLEFT", 0, 4)
    GameTooltip:ClearLines()
    if title then
        GameTooltip:AddLine(title, 0.83, 0.65, 0.35)
    end
    if text then
        GameTooltip:AddLine(text, 1, 1, 1, true)
    end
    GameTooltip:Show()
end

----------------------------------------------------------------------
-- 工具：SectionHeader（与 EUI 原生 SectionHeader 风格对齐）
----------------------------------------------------------------------
function evt.UI.SectionHeader(parent, text, y)
    local padX = evt.UI.PAGE_PAD_X
    local fs = evt.UI.MakeFont(parent, 16, 1, 1, 1, 0.41)
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", padX, y)
    fs:SetText(L[text] or text)

    local line = evt.UI.SolidTex(parent, "ARTWORK", 1, 1, 1, 0.06)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", 0, -6)
    line:SetPoint("RIGHT", parent, "RIGHT", -padX, 0)

    return fs, fs:GetStringHeight() + 20
end

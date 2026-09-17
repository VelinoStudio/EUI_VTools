----------------------------------------------------------------------
--  EUI_VTools — 本地化引导
--
--  使用与 EllesmereUI 相同的本地化结构：
--    • 英文为 key（身份键），未翻译时原样返回英文
--    • 非 English locale 通过 EllesmereUI.RegisterLocale(code) 注册翻译表
--    • 翻译在渲染边界（:SetText）应用，数据层保持英文身份
--
--  用法（各模块文件）：
--      local _, evt = ...
--      local L = evt.L          -- 即 EllesmereUI.L
--      label = L("General")    -- zhCN→通用 / enUS→General
--
--  各语言文件调用 EllesmereUI.RegisterLocale(code) 获取翻译表并填充。
--  因为 EllesmereUI 引擎在 ADDON_LOADED 时 Activate()，而本插件在
--  EllesmereUI 之后加载，填充的键会立即生效。
----------------------------------------------------------------------
local _, evt = ...

-- 确保父框架可用
local EUI = evt.EUI
if not (EUI and EUI.RegisterLocale) then return end

-- 暴露给各语言文件使用的注册入口
evt.RegisterLocale = function(code)
    return EUI.RegisterLocale(code)
end

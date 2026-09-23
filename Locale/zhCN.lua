----------------------------------------------------------------------
--  EUI_VTools — 简体中文本地化
--  英文 key → 简体中文翻译
----------------------------------------------------------------------
local _, evt = ...
if not (evt and evt.RegisterLocale) then return end

local L = evt.RegisterLocale("zhCN")
if not L then return end

-- 插件名 / 分组标题
L["Velino Toolbox"]      = "Velino工具箱"

-- 侧边栏页面名
L["General"]             = "通用"

-- 通用设置页文案
L["Welcome to EUI_VTools"]        = "欢迎使用 Velino 工具箱"
L["Framework ready"]              = "框架已就绪，功能将逐步添加。"
L["Author"]                       = "作者"
L["Version"]                      = "版本"

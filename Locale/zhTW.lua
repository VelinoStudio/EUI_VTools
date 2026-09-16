----------------------------------------------------------------------
--  EUI_VTools — 繁體中文本地化
--  英文 key → 繁體中文翻譯
----------------------------------------------------------------------
local _, evt = ...
if not (evt and evt.RegisterLocale) then return end

local L = evt.RegisterLocale("zhTW")
if not L then return end

-- 插件名 / 分組標題
L["Velino Toolbox"]      = "Velino工具箱"

-- 側邊欄頁面名
L["General"]             = "通用"

-- 通用設定頁文案
L["Welcome to EUI_VTools"]        = "歡迎使用 Velino 工具箱"
L["Framework ready"]              = "框架已就緒，功能將逐步添加。"
L["Author"]                       = "作者"
L["Version"]                      = "版本"

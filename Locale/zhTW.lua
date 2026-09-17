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
L["UI"]                  = "介面"

-- 通用設定頁文案
L["Welcome to EUI_VTools"]        = "歡迎使用 Velino 工具箱"
L["Framework ready"]              = "框架已就緒，功能將逐步添加。"
L["Author"]                       = "作者"
L["Version"]                      = "版本"

-- 介面縮放設定頁
L["Character"]                    = "角色介面"
L["Friends"]                      = "好友介面"
L["Mail"]                         = "郵箱介面"
L["Collections"]                  = "收藏品介面"
L["Merchant"]                     = "商人介面"
L["Tooltip"]                      = "滑鼠提示"
L["Professions"]                  = "專業介面"
L["World Map"]                    = "地圖"

L["Scale"]                        = "縮放"
L["Locked"]                       = "鎖定"
L["Reset All Scales"]             = "重置全部縮放"

L["Adjust the frame scale. 1 = original size."] = "調整介面縮放比例。1 為原始大小。"
L["When locked, the frame cannot be resized by dragging its bottom-right corner."] = "鎖定後，無法透過拖曳右下角調整介面大小。"
L["Adjust the tooltip scale. 1 = original size."] = "調整滑鼠提示縮放比例。1 為原始大小。"

L["Item Level"]                   = "物品等級"
L["Sell Price"]                   = "賣價"
L["Sample tooltip description line one."] = "這是一行範例提示說明文字。"

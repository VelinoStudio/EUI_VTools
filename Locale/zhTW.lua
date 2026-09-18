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

-- 頁面描述（header 下方小字）
L["General_Desc"]        = "Velino 工具箱：框架與元資訊。"
L["UI_Desc"]             = "調整遊戲內各類窗體的縮放比例。"

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

----------------------------------------------------------------------
-- 額外物品條
----------------------------------------------------------------------
L["Extra Items Bar"]              = "額外物品條"
L["ExtraItemsBar_Desc"]           = "快速使用任務物品、消耗品與裝備飾品的巨集安全按鈕條。"
L["Extra Items Bar 1"]            = "額外物品條 1"
L["Extra Items Bar 2"]            = "額外物品條 2"
L["Extra Items Bar 3"]            = "額外物品條 3"
L["Extra Items Bar 4"]            = "額外物品條 4"
L["Extra Items Bar 5"]            = "額外物品條 5"

L["Enable Extra Items Bar"]       = "啟用額外物品條"
L["Show quick-use buttons for quest items, consumables and more."] = "顯示快速使用任務物品、消耗品等的巨集安全按鈕條。"
L["Exclude Quantum Items"]        = "排除量子物品"
L["Hide quantum curio items from all bars."] = "從所有條中隱藏量子珍玩物品。"
L["Custom Items"]                 = "自訂物品"
L["Blacklist"]                    = "黑名單"
L["Custom Items Help"]            = "輸入物品 ID 並點擊加入，即可新增自訂物品（分組 CUSTOM）。"
L["Blacklist Help"]               = "加入黑名單的物品不會出現在任何條上。"
L["Add"]                          = "加入"
L["Delete"]                       = "刪除"

L["Bar"]                          = "物品條"
L["Bar 1"]                        = "條 1"
L["Bar 2"]                        = "條 2"
L["Bar 3"]                        = "條 3"
L["Bar 4"]                        = "條 4"
L["Bar 5"]                        = "條 5"
L["Enable This Bar"]              = "啟用此條"

L["Bind Keys"]                    = "綁定按鍵"
L["Enter Binding Mode"]           = "進入綁定模式"
L["Exit Binding Mode"]            = "退出綁定模式"
L["Hover a bar button and press any key to bind it. ESC while hovering clears its bindings, ESC otherwise exits."] = "停駐在條上的按鈕並按下任意按鍵即完成綁定；停駐時按 ESC 清除該按鈕的綁定，未停駐時按 ESC 退出。"
L["Move in Unlock Mode"]          = "解鎖模式移動"
L["Open EUI unlock mode to drag the bars."] = "開啟 EUI 解鎖模式，拖曳放置各條。"

L["Content"]                      = "內容"
L["Content Groups"]               = "內容分組"
L["Pick the item groups shown on this bar. Use the advanced include field for SLOT syntax."] = "勾選此條要顯示的物品分組；SLOT 語法請用下方進階 include 輸入框填寫。"
L["Advanced Include"]             = "進階 Include"
L["Comma separated groups. SLOT:n / SLOT:n-m adds usable equipment slots."] = "逗號分隔的分組清單；SLOT:n / SLOT:n-m 表示加入可用的裝備欄位。"

L["Layout"]                       = "佈局"
L["Number of Buttons"]            = "按鈕數量"
L["Buttons Per Row"]              = "每列按鈕數"
L["Button Width"]                 = "按鈕寬度"
L["Button Height"]                = "按鈕高度"
L["Spacing"]                      = "按鈕間距"
L["Backdrop Spacing"]             = "背景留白"
L["Anchor"]                       = "生長方向"
L["Backdrop"]                     = "背景"
L["Border Style"]                 = "邊框樣式"
L["Border Size"]                  = "邊框大小"
L["None"]                         = "無"
L["Solid"]                        = "實心"
L["Top Left"]                     = "左上"
L["Top Right"]                    = "右上"
L["Bottom Left"]                  = "左下"
L["Bottom Right"]                 = "右下"

L["Display"]                      = "顯示"
L["Mouse Over Fade"]              = "停駐淡入"
L["Fade the bar out when the mouse leaves and fade in on hover."] = "滑鼠移出時淡出、停駐時淡入。"
L["Min Alpha"]                    = "最小透明度"
L["Max Alpha"]                    = "最大透明度"
L["Fade Time"]                    = "淡入淡出時長"

L["Texts & Icons"]                = "文字與圖示"
L["Show Count"]                   = "顯示數量"
L["Show Key Bindings"]            = "顯示按鍵綁定"
L["Show Quality Tier"]            = "顯示製作品質標記"
L["Quality Tier Size"]            = "品質標記大小"

L["Visibility"]                   = "可見性"
L["Visibility Macro"]             = "可見性條件"
L["Always"]                       = "總是"
L["Hide"]                         = "隱藏"
L["In Combat"]                    = "戰鬥中"
L["Out of Combat"]                = "非戰鬥中"
L["Hide in Pet Battle"]           = "寵物對戰時隱藏"
L["In Stealth"]                   = "潛行中"
L["Standard macro visibility conditions, e.g. [petbattle]hide;show."] = "標準巨集可見性條件，例如 [petbattle]hide;show。"

-- 內容分組名
L["QUEST"]                        = "任務物品"
L["EQUIP"]                        = "已裝備可用物品"
L["CUSTOM"]                       = "自訂物品"
L["POTION"]                       = "藥水（全部）"
L["POTIONGN"]                     = "藥水（通用）"
L["POTIONLEG"]                    = "藥水（軍臨天下）"
L["POTIONSL"]                     = "藥水（暗影律法）"
L["POTIONDF"]                     = "藥水（巨龍崛起）"
L["POTIONTWW"]                    = "藥水（地心之戰）"
L["POTIONMN"]                     = "藥水（午夜）"
L["FLASK"]                        = "精鍊藥劑（全部）"
L["FLASKLEG"]                     = "精鍊藥劑（軍臨天下）"
L["FLASKSL"]                      = "精鍊藥劑（暗影律法）"
L["FLASKDF"]                      = "精鍊藥劑（巨龍崛起）"
L["FLASKTWW"]                     = "精鍊藥劑（地心之戰）"
L["FLASKMN"]                      = "精鍊藥劑（午夜）"
L["RUNE"]                         = "符文（全部）"
L["RUNETWW"]                      = "符文（地心之戰）"
L["RUNEMN"]                       = "符文（午夜）"
L["VANTUS"]                       = "凡圖斯（全部）"
L["VANTUSTWW"]                    = "凡圖斯（地心之戰）"
L["VANTUSMN"]                     = "凡圖斯（午夜）"
L["FOOD"]                         = "食物（製作）"
L["FOODTWW"]                      = "食物（地心之戰）"
L["FOODMN"]                       = "食物（午夜）"
L["FOODVENDOR"]                   = "食物（商人販售）"
L["MAGEFOOD"]                     = "法師餐桌"
L["FISHING"]                      = "釣魚物品（全部）"
L["FISHINGTWW"]                   = "釣魚物品（地心之戰）"
L["FISHINGMN"]                    = "釣魚物品（午夜）"
L["BANNER"]                       = "戰旗"
L["UTILITY"]                      = "功能物品"
L["OPENABLE"]                     = "可開啟物品"
L["PROF"]                         = "專業物品（全部）"
L["PROFTWW"]                      = "專業物品（地心之戰）"
L["PROFMN"]                       = "專業物品（午夜）"
L["SEEDS"]                        = "種子"
L["BIGDIG"]                       = "大挖掘"
L["DELVE"]                        = "探究物品"
L["HOLIDAY"]                      = "節慶物品"

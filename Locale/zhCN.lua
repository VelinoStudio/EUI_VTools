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
L["UI"]                  = "界面"

-- 页面描述（header 下方小字）
L["General_Desc"]        = "Velino 工具箱：框架与元信息。"
L["UI_Desc"]             = "调整游戏内各类窗体的缩放比例。"

-- 通用设置页文案
L["Welcome to EUI_VTools"]        = "欢迎使用 Velino 工具箱"
L["Framework ready"]              = "框架已就绪，功能将逐步添加。"
L["Author"]                       = "作者"
L["Version"]                      = "版本"

-- 界面缩放设置页
L["Character"]                    = "角色界面"
L["Friends"]                      = "好友界面"
L["Mail"]                         = "邮箱界面"
L["Collections"]                  = "收藏品界面"
L["Merchant"]                     = "商人界面"
L["Tooltip"]                      = "鼠标提示"
L["Professions"]                  = "专业界面"
L["World Map"]                    = "地图"

L["Scale"]                        = "缩放"
L["Locked"]                       = "锁定"
L["Reset All Scales"]             = "重置全部缩放"

L["Adjust the frame scale. 1 = original size."] = "调整界面缩放比例。1 为原始大小。"
L["When locked, the frame cannot be resized by dragging its bottom-right corner."] = "锁定后，无法通过拖动右下角调整界面大小。"
L["Adjust the tooltip scale. 1 = original size."] = "调整鼠标提示缩放比例。1 为原始大小。"

L["Item Level"]                   = "物品等级"
L["Sell Price"]                   = "卖价"
L["Sample tooltip description line one."] = "这是一行示例提示说明文字。"

----------------------------------------------------------------------
-- 额外物品条
----------------------------------------------------------------------
L["Extra Items Bar"]              = "额外物品条"
L["ExtraItemsBar_Desc"]           = "快速使用任务物品、消耗品与装备饰品的宏安全按钮条。"
L["Extra Items Bar 1"]            = "额外物品条 1"
L["Extra Items Bar 2"]            = "额外物品条 2"
L["Extra Items Bar 3"]            = "额外物品条 3"
L["Extra Items Bar 4"]            = "额外物品条 4"
L["Extra Items Bar 5"]            = "额外物品条 5"

L["Enable Extra Items Bar"]       = "启用额外物品条"
L["Show quick-use buttons for quest items, consumables and more."] = "显示快速使用任务物品、消耗品等的宏安全按钮条。"
L["Exclude Quantum Items"]        = "排除量子物品"
L["Hide quantum curio items from all bars."] = "从所有条中隐藏量子珍玩物品。"
L["Custom Items"]                 = "自定义物品"
L["Blacklist"]                    = "黑名单"
L["Custom Items Help"]            = "输入物品 ID 并点击添加，即可加入自定义物品（分组 CUSTOM）。"
L["Blacklist Help"]               = "加入黑名单的物品不会出现在任何条上。"
L["Add"]                          = "添加"
L["Delete"]                       = "删除"

L["Bar"]                          = "物品条"
L["Bar 1"]                        = "条 1"
L["Bar 2"]                        = "条 2"
L["Bar 3"]                        = "条 3"
L["Bar 4"]                        = "条 4"
L["Bar 5"]                        = "条 5"
L["Enable This Bar"]              = "启用此条"

L["Bind Keys"]                    = "绑定按键"
L["Enter Binding Mode"]           = "进入绑定模式"
L["Exit Binding Mode"]            = "退出绑定模式"
L["Hover a bar button and press any key to bind it. ESC while hovering clears its bindings, ESC otherwise exits."] = "悬停在条上的按钮并按下任意按键即完成绑定；悬停时按 ESC 清除该按钮的绑定，未悬停时按 ESC 退出。"
L["Move in Unlock Mode"]          = "解锁模式移动"
L["Open EUI unlock mode to drag the bars."] = "打开 EUI 解锁模式，拖动放置各条。"

L["Content"]                      = "内容"
L["Content Groups"]               = "内容分组"
L["Pick the item groups shown on this bar. Use the advanced include field for SLOT syntax."] = "勾选此条要显示的物品分组；SLOT 语法请用下方高级 include 输入框填写。"
L["Advanced Include"]             = "高级 Include"
L["Comma separated groups. SLOT:n / SLOT:n-m adds usable equipment slots."] = "逗号分隔的分组列表；SLOT:n / SLOT:n-m 表示加入可用的装备槽位。"

L["Layout"]                       = "布局"
L["Number of Buttons"]            = "按钮数量"
L["Buttons Per Row"]              = "每行按钮数"
L["Button Width"]                 = "按钮宽度"
L["Button Height"]                = "按钮高度"
L["Spacing"]                      = "按钮间距"
L["Backdrop Spacing"]             = "背景留白"
L["Anchor"]                       = "生长方向"
L["Backdrop"]                     = "背景"
L["Top Left"]                     = "左上"
L["Top Right"]                    = "右上"
L["Bottom Left"]                  = "左下"
L["Bottom Right"]                 = "右下"

L["Display"]                      = "显示"
L["Mouse Over Fade"]              = "悬停淡入"
L["Fade the bar out when the mouse leaves and fade in on hover."] = "鼠标移出时淡出、悬停时淡入。"
L["Min Alpha"]                    = "最小透明度"
L["Max Alpha"]                    = "最大透明度"
L["Fade Time"]                    = "淡入淡出时长"

L["Texts & Icons"]                = "文本与图标"
L["Show Count"]                   = "显示数量"
L["Show Key Bindings"]            = "显示按键绑定"
L["Show Quality Tier"]            = "显示制造品质角标"
L["Quality Tier Size"]            = "品质角标大小"

L["Visibility"]                   = "可见性"
L["Visibility Macro"]             = "可见性条件"
L["Standard macro visibility conditions, e.g. [petbattle]hide;show."] = "标准宏可见性条件，例如 [petbattle]hide;show。"

-- 内容分组名
L["QUEST"]                        = "任务物品"
L["EQUIP"]                        = "已装备可用物品"
L["CUSTOM"]                       = "自定义物品"
L["POTION"]                       = "药水（全部）"
L["POTIONGN"]                     = "药水（通用）"
L["POTIONLEG"]                    = "药水（军团）"
L["POTIONSL"]                     = "药水（暗影国度）"
L["POTIONDF"]                     = "药水（巨龙时代）"
L["POTIONTWW"]                    = "药水（地心之战）"
L["POTIONMN"]                     = "药水（午夜）"
L["FLASK"]                        = "合剂（全部）"
L["FLASKLEG"]                     = "合剂（军团）"
L["FLASKSL"]                      = "合剂（暗影国度）"
L["FLASKDF"]                      = "合剂（巨龙时代）"
L["FLASKTWW"]                     = "合剂（地心之战）"
L["FLASKMN"]                      = "合剂（午夜）"
L["RUNE"]                         = "符文（全部）"
L["RUNETWW"]                      = "符文（地心之战）"
L["RUNEMN"]                       = "符文（午夜）"
L["VANTUS"]                       = "凡图斯（全部）"
L["VANTUSTWW"]                    = "凡图斯（地心之战）"
L["VANTUSMN"]                     = "凡图斯（午夜）"
L["FOOD"]                         = "食物（制造）"
L["FOODTWW"]                      = "食物（地心之战）"
L["FOODMN"]                       = "食物（午夜）"
L["FOODVENDOR"]                   = "食物（商人出售）"
L["MAGEFOOD"]                     = "法师餐桌"
L["FISHING"]                      = "钓鱼物品（全部）"
L["FISHINGTWW"]                   = "钓鱼物品（地心之战）"
L["FISHINGMN"]                    = "钓鱼物品（午夜）"
L["BANNER"]                       = "战旗"
L["UTILITY"]                      = "功能物品"
L["OPENABLE"]                     = "可开启物品"
L["PROF"]                         = "专业物品（全部）"
L["PROFTWW"]                      = "专业物品（地心之战）"
L["PROFMN"]                       = "专业物品（午夜）"
L["SEEDS"]                        = "种子"
L["BIGDIG"]                       = "大挖掘"
L["DELVE"]                        = "地下堡物品"
L["HOLIDAY"]                      = "节日物品"

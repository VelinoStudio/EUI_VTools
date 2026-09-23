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
L["Pick the item groups shown on this bar. Items matching any selected group are included."] = "勾选此条要显示的物品分组；符合任一选中分组的物品都会显示。"
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
L["Border Style"]                 = "边框样式"
L["Border Size"]                  = "边框大小"
L["Border Color"]                 = "边框颜色"
L["Enable Bar Background"]        = "启用条背景"
L["Background Spacing"]           = "背景留白"
L["Background Color"]             = "背景颜色"
L["Background Opacity"]           = "背景不透明度"
L["Icon Zoom"]                    = "图标缩放"
L["Icon Background"]              = "图标背景"
L["Icon Background Opacity"]      = "图标背景不透明度"
L["Show Cooldown Numbers"]        = "显示冷却数字"
L["Custom Button Shape"]          = "自定义按钮形状"
L["Show Blizzard Icon Background"] = "显示暴雪图标背景"
L["Blizzard Icon Background Alpha"] = "暴雪图标背景不透明度"
L["Cropped"]                      = "裁剪"
L["Square"]                       = "方形"
L["Circle"]                       = "圆形"
L["Curved Square"]                = "圆角方形"
L["Diamond"]                      = "菱形"
L["Hexagon"]                      = "六边形"
L["Portrait"]                     = "肖像"
L["Shield"]                       = "盾形"
L["Use Class Color"]              = "使用职业颜色"
L["Sync Appearance to Other Bars"] = "将外观同步到其他条"
L["Apply Sync"]                   = "应用同步"
L["None"]                         = "无"
L["Solid"]                        = "实心"
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
L["Always"]                       = "总是"
L["Hide"]                         = "隐藏"
L["In Combat"]                    = "战斗中"
L["Out of Combat"]                = "非战斗中"
L["Hide in Pet Battle"]           = "宠物对战时隐藏"
L["In Stealth"]                   = "潜行中"
L["Standard macro visibility conditions, e.g. [petbattle]hide;show."] = "标准宏可见性条件，例如 [petbattle]hide;show。"

-- 内容分组名
L["QUEST"]                        = "任务物品"
L["EQUIP"]                        = "已装备可用物品"
L["CUSTOM"]                       = "自定义物品"
L["POTION"]                       = "药水"
L["ELIXIR"]                       = "药剂"
L["FLASK"]                        = "合剂"
L["RUNE"]                         = "符文"
L["VANTUS"]                       = "凡图斯"
L["FOOD"]                         = "专业制造的食物"
L["FOODVENDOR"]                   = "商人出售的食物"
L["MAGEFOOD"]                     = "魔法制造的食物（含术士治疗石和法师面包）"
L["FISHING"]                      = "钓鱼物品"
L["UTILITY"]                      = "功能物品"
L["OPENABLE"]                     = "可开启物品"
L["PROF"]                         = "专业物品"
L["SEEDS"]                        = "种子"
L["DELVE"]                        = "地下堡物品"
L["HOLIDAY"]                      = "节日物品"

----------------------------------------------------------------------
-- 区块标题 / 边框粗细 / 字体设置 / 同步（新增）
----------------------------------------------------------------------
L["BAR BACKGROUND"]               = "物品条背景"
L["Icons"]                        = "图标"
L["FONTS & TEXT"]                 = "字体与文字"
L["Keybind Text"]                 = "快捷键字体"
L["Count Text"]                   = "数量字体"
L["Cooldown Text"]                = "冷却时间字体"
L["Thin"]                         = "细"
L["Normal"]                       = "普通"
L["Heavy"]                        = "粗"
L["Strong"]                       = "特粗"

L["Font"]                         = "字体"
L["Font Size"]                    = "字体大小"
L["Font Color"]                   = "字体颜色"
L["Outline"]                      = "描边"
L["Text Anchor"]                  = "文字锚点"
L["Individual Default"]           = "各自默认"
L["Top"]                          = "上"
L["Bottom"]                       = "下"
L["Center"]                       = "居中"
L["Offset X"]                     = "X 偏移"
L["Offset Y"]                     = "Y 偏移"

L["Sync"]                         = "同步"
L["Syncs all visual settings except content."] = "同步除内容以外的所有外观设置。"
L["Included: colors, borders, shapes, spacing, size, fonts, visibility."] = "包含：颜色、边框、形状、间距、尺寸、字体、可见性。"
L["NOT included: enable, include (content groups), customList, blackList, pos, numButtons."] = "不包含：启用、include（内容分组）、customList、blackList、位置、按钮数量。"
L["Copy all visual settings from the current bar to the selected bars."] = "将当前条的全部外观设置复制到勾选的条。"
L["Copy visual settings from Bar %d to the selected bars below. Button contents, visibility and position are not affected."] = "将物品条 %d 的外观设置复制到下方勾选的条。按钮内容、可见性与位置不受影响。"
L["Enter item IDs you want to show on this bar. Items from this list are added in addition to content groups (OR relation)."] = "输入要在此条显示的物品 ID。此列表中的物品会在内容分组之外额外加入（OR 关系）。"

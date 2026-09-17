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

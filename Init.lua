----------------------------------------------------------------------
--  EUI_VTools — 框架引导
--  使用与 EllesmereUI 相同的结构：接入 EUILite 框架 + EllesmereUI 本地化引擎。
--  本插件命名空间缩写为 evt，供 Core/ 与 Pages/ 下所有文件通过 local _, evt = ... 共享。
--
--  与 EUI_Kogotool 的 ns 多槽约定不同，EUI_VTools 使用具名字段（evt.UI / evt.Pages / evt.L），
--  避免位置槽语义模糊；同时直接复用 EllesmereUI.Lite 与 EllesmereUI.L，结构一致。
----------------------------------------------------------------------
local addonName, evt = ...

-- 父框架引用（EllesmereUI 已在 Dependencies 中保证先加载）
local EUI = _G.EllesmereUI
evt.EUI = EUI

-- 复用父框架的 Lite（addon 对象 + 事件 + DB）
evt.Lite = (EUI and EUI.Lite) or {}

-- 复用父框架的本地化翻译函数 L（英文 key → 当前语言）
evt.L = (EUI and EUI.L) or function(s) return s end

-- 本插件自身的 addon 对象（使用 EUILite 创建，与 EllesmereUI 子插件结构一致）
if evt.Lite.NewAddon then
    evt.addon = evt.Lite.NewAddon(addonName)
end

-- 本插件自身状态 / 设置表（具名，不用数字槽）
evt.P = {}
evt.UI = {}
evt.Pages = {}

-- 插件图标（media/evt_logo.tga，供设置面板与欢迎页使用）
evt.UI.ICON = "Interface\\AddOns\\EUI_VTools\\media\\evt_logo.tga"

----------------------------------------------------------------------
--  配置数据库（接入 EUI 中央 EllesmereUIDB，随 profile 导出/导入）
--  数据存于 EllesmereUIDB.profiles[name].addons["EUI_VTools"]
----------------------------------------------------------------------
local defaults = {
    profile = {
        -- 界面缩放配置集
        uiScale = {
            character   = { scale = 1, locked = true },
            friends     = { scale = 1, locked = true },
            mail        = { scale = 1, locked = true },
            collections = { scale = 1, locked = true },
            merchant    = { scale = 1, locked = true },
            tooltip     = { scale = 1 },                  -- tooltip 无锁定开关
            professions = { scale = 1, locked = true },
            map         = { scale = 1, locked = true },   -- 地图 + 任务日志（WorldMapFrame）
        },
    },
}

-- 用 EUI 的 NewDB 创建数据库，数据天然进入 EllesmereUIDB 的 addons 子表
evt.db = (evt.Lite and evt.Lite.NewDB) and evt.Lite.NewDB("EUI_VToolsDB", defaults) or { profile = defaults.profile }

-- 账号级数据库：跨角色共享设置（独立于 EUI profile，用于非 profile 数据）
EUI_VToolsAccountDB = EUI_VToolsAccountDB or {}

-- 单次登录提示：同一条消息整个账号生命周期只显示一次
function evt.PrintOnce(msg)
    if not msg then return end
    local db = EUI_VToolsAccountDB
    if not db then print(msg); return end
    db._printOnce = db._printOnce or {}
    if db._printOnce[msg] then return end
    print(msg)
    db._printOnce[msg] = true
end

_G[addonName] = evt

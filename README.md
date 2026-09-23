# EUI_VTools · Velino 工具箱

![WoW](https://img.shields.io/badge/World%20of%20Warcraft-11.x%20%2F%2012.x-orange)
![Dependency](https://img.shields.io/badge/Dependency-EllesmereUI-blue)
![Language](https://img.shields.io/badge/语言-简体中文%20%2F%20繁體中文%20%2F%20English-green)

为 [EllesmereUI（EUI）](https://github.com/) 打造的工具箱插件，设置界面原生集成进 EUI 设置窗口的 **Plus 页**，提供界面缩放与额外物品条等实用功能。

- **插件名称**：EUI_VTools（Velino 工具箱）
- **作者**：Velino
- **版本**：0.1.0
- **配置保存**：随 EUI 配置档案（Profile）一起导入 / 导出

---

## 功能特性

### 🖥️ 界面缩放（UI Scale）

独立调整游戏内各类窗口的缩放比例，不再受全局 UI 缩放限制。

- 支持 **8 类窗口**：角色信息、好友、邮件、藏品、商人、专业、世界地图（含任务日志）、鼠标提示框
- 缩放范围 **0.3 – 2.0**，步进 0.05，滑块精确调节
- 每个窗口右下角提供 **拖拽手柄**，可直接拖动缩放；可单独锁定
- 世界地图全屏时自动隐藏手柄；邮件 / 藏品 / 专业等按需加载窗口打开时自动生效
- 「重置全部缩放」一键还原

### 🎒 额外物品条（Extra Items Bar）

自动扫描背包，把药水、食物、任务物品等可点击使用的消耗品集中显示在独立动作条上，最多支持 **5 条**、每条 **12 个按钮**，点击即可使用，支持绑定快捷键。

**物品分组**

- 任务物品（按距离排序）、药水、合剂 / 精炼、符文、凡图斯符文
- 食物：制作食物、商人食物、法师餐点（含治疗石）
- 鱼饵、实用道具、可开启物品、专业物品、种子、地下堡道具、节日道具
- 已装备的可用饰品 / 装备（自动读取装备槽）
- 支持 **自定义物品列表**（逐条添加物品 ID）与 **黑名单**

**外观与布局**

- EUI 原生动作条风格皮肤：背景 / 边框颜色、透明度、内边距、边框粗细、职业色
- 按钮形状、图标缩放、槽位底色、暴雪风格图标背景
- 按钮尺寸、间距、每行按钮数自动换行，支持横向 / 纵向排列
- 悬停淡入淡出（可调透明度与淡入时间）

**文字样式（三套独立配置）**

快捷键文字、堆叠数量、冷却倒计时各自独立设置：

- 字体（支持 LibSharedMedia 字体列表 / EUI Expressway / 游戏默认字体）
- 字号、颜色、职业颜色、描边
- 锚点位置与 X / Y 偏移

**其他**

- 冷却动画与倒计时文字、品质徽标、不可用时灰色、超出距离红色提示
- 可见性条件（如宠物对战时自动隐藏）
- 外观配置可一键 **同步到其他条**
- 地下堡 / 量子坐骑物品等特殊场景过滤
- 原生支持 EUI **解锁模式**：在解锁界面中直接拖动条的位置

---

## 安装

1. 从 [Releases](https://github.com/VelinoStudio/EUI_VTools/releases) 下载最新版本
2. 解压后将 `EUI_VTools` 文件夹放入：
   ```
   World of Warcraft\_retail_\Interface\AddOns\
   ```
3. 确认已安装并启用 **EllesmereUI**
4. 进入游戏后在角色选择界面的插件列表中勾选 `EUI_VTools`

## 使用方法

打开 EUI 设置窗口（游戏菜单或 `/eui`），进入 **Plus 页**即可看到：

- **通用**：插件信息
- **UI**：界面缩放设置
- **Extra Items Bar**：额外物品条开关与全部配置

额外物品条的位置可在 EUI 解锁模式中自由拖动；按钮支持在 EUI / Blizzard 快捷键设置界面绑定按键。

---

## 本地化

- 简体中文（zhCN）
- 繁體中文（zhTW）
- English（enUS，部分条目回退）

## 致谢

- [EllesmereUI](https://github.com/) —— 本插件依赖的 UI 框架
- [ElvUI_WindTools](https://github.com/fang2hou/ElvUI_WindTools) / EllesmereUI_WindTools —— 额外物品条模块的设计参考与灵感来源

## 许可证

本项目仅供学习交流使用。

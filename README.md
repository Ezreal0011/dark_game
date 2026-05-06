# 暗林信号

Godot 4.6 制作的回合制战术原型。项目按 M0-M9 阶段推进，当前已完成第一版玩法闭环、Web 导出准备、M8 表现层精修，以及 M9 回合逻辑和延迟移动轨迹规则。

## 当前阶段

已完成：

- M0 项目骨架
- M1 网格地图与移动
- M2 暗能、回合与基础 NPC
- M3 信号系统、NPC 默认隐藏、扫描/攻击/移动信号
- M4 资源点、技能点、静默区、回声区、黑域收缩
- M5 科技线、技能配置、三选一技能、技能槽、技能范围与冷却
- M6 NPC 类型 AI、GM 显示开关、NPC 逐个行动
- M7 交互反馈补齐
- M8 Web 导出约束、最终自检、表现层与 HUD 精修
- M9 玩家回合多操作、延迟移动轨迹、发光路径线轨迹

## 运行方式

1. 使用 Godot 4.6 打开项目目录：
   `D:\GameC\dark\dark-f`
2. 运行主场景：
   `res://scenes/Main.tscn`

## 当前核心规则

- 玩家每回合可以移动一次。
- 移动后仍可继续扫描、攻击、释放技能、升级科技、采集资源、拾取技能点。
- 玩家暗能为 0 时不能继续主动操作，只能结束回合。
- 玩家手动点击“结束”后进入 NPC 回合。
- NPC 会逐个行动，不会一次性全部移动完。
- NPC AI 不读取玩家真实位置，只读取可见信号、公开信号、地图点、黑域和自身可行动格。

## 移动轨迹规则

- 玩家和 NPC 移动都不会立刻在地图上显示轨迹。
- 静默区移动不留下移动轨迹。
- 普通移动轨迹会被记录为从起点到终点的一条路径。
- 移动轨迹不会在产生回合、下一回合、第二回合显示。
- 移动轨迹会在第三回合显示。
- 移动轨迹 5 回合后消失。
- NPC 移动轨迹在延迟结束后会作为公共轨迹显示在地图上。
- 移动轨迹表现为半透明发光路径线：
  - 普通轨迹为青蓝色。
  - 公开/回声轨迹为橙色。

## 地图与点位

- 主地图逻辑尺寸保持 24 x 16。
- 地图可通过瓦片继续编辑铺设。
- 资源点和技能点来自配置表。
- 当前点位表现为轻量地图标记，不改变采集和拾取规则。

## 配置文件

- `res://configs/game_config.json`：地图尺寸、暗能、点位、区域、缩圈和黑域参数。
- `res://configs/skill_config.json`：技能池、技能名称、类型、消耗、冷却、范围、信号强度和描述。
- `res://configs/tech_config.json`：侦察、移动、隐匿科技等级、消耗和效果。

## 测试

常用回归测试：

```powershell
& 'D:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path 'D:\GameC\dark\dark-f' --script 'res://tests/m4_rules_test.gd'
& 'D:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path 'D:\GameC\dark\dark-f' --script 'res://tests/m5_rules_test.gd'
& 'D:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path 'D:\GameC\dark\dark-f' --script 'res://tests/m6_ai_test.gd'
& 'D:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path 'D:\GameC\dark\dark-f' --script 'res://tests/m8_final_test.gd'
& 'D:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path 'D:\GameC\dark\dark-f' --script 'res://tests/m9_tilt_transform_test.gd'
```

## 开发日志

阶段日志位于：

`res://devlogs/`

当前新增日志：

- `res://devlogs/M9_回合逻辑与延迟轨迹记录.md`
- `res://devlogs/M9_移动轨迹路径线记录.md`

# Phase 3 - 血条UI + 伤害数字

## 已完成

### 1. 玩家血条 (Player HUD)
- `scenes/ui/player_hud.tscn` — CanvasLayer 覆盖层，放在屏幕左上角
- `scripts/ui/player_hud.gd` — 自动查找 player 组，监听 `health_changed` 信号
- 显示 ProgressBar + "HP: 80/100" 文本
- 低血量变色：≤60% 黄，≤30% 红

### 2. 敌人血条 (Enemy HP Bar)
- 在 `enemy.gd` 中代码创建 ProgressBar，位于敌人头顶
- 受击时显示并更新，1.5秒后自动隐藏
- `health_changed` 信号已添加

### 3. 伤害数字弹出 (Damage Numbers)
- `scenes/ui/damage_number.tscn` — Label 场景
- `scripts/ui/damage_number.gd` — 上浮 + 淡出 + 放大后自销毁
- 静态方法 `spawn(world, position, damage)` 方便调用
- 在 `enemy.take_damage()` 中自动触发

### 4. 集成
- `main.tscn` 已添加 PlayerHUD 实例
- `player_v2.gd` 已添加 `add_to_group("player")`

## 使用

用 `player_v2.gd` + `main.tscn` 运行，就可以看到：
- 左上角玩家血条
- 敌人头顶红色血条（受击时出现）
- 命中时飘出白色伤害数字

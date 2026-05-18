# Phase 1 — 韧性/霸体 + Telegraph + 敌人参数化

## 已完成

### 1. 韧性/霸体系统 (CombatEntity)
- `max_poise` / `current_poise` — 韧性值，0=无霸体（杂兵），>0=有霸体条
- `_apply_poise_damage(amount)` — 削韧，返回 true 表示打崩霸体
- `signal poise_broken` — 霸体被击破时触发
- 韧性归零自动重置，玩家可连续压制

### 2. 冲击等级 (Impact Level)
- 攻击新增 `get_impact_level()` — 返回 0-4
  - 0=无反应 1=轻击退 2=重击退 3=击飞 4=击倒
- 受击方根据冲击等级调整硬直时间和击退距离
- 玩家每种攻击独立配置冲击等级

### 3. Telegraph 攻击预警 (Enemy)
- 攻击分为 Telegraph + Active 两阶段
- Telegraph 阶段：精灵闪烁警告，攻击框未激活
- Active 阶段：播放攻击动画，攻击框激活
- `telegraph_duration` 可配置（杂兵 0.2s / Boss 0.5-1.0s）

### 4. 敌人参数化系统
- `enum Archetype { MINION, ELITE, BOSS, RANGED }`
- 所有属性通过 @export 在编辑器中调节
- Boss 血条自动变大
- 参数示例：
  - 杂兵：HP 30, 韧性 0, telegraph 0.2s
  - 精英：HP 80, 韧性 50, telegraph 0.3s
  - Boss：HP 300, 韧性 100, telegraph 0.6s

### 5. 伤害管道升级
- `take_damage(from, damage, poise_damage, impact_level)` — 统一接口
- 敌人：韧性未破=只扣血不硬直（霸体行为）
- 玩家：冲击等级影响硬直时间

## 使用方法

### 创建不同类型敌人
1. 在 Godot 中右键 `enemy_v2.tscn` → "从场景新建继承场景"
2. 修改 @export 参数：
   - `archetype` → BOSS
   - `max_health` → 300
   - `max_poise` → 100
   - `telegraph_duration` → 0.6
   - `attack_damage` → 25

### 调整玩家攻击
在编辑器中选中 Player_v2 节点，修改：
- `skill_impact_level` → 3（必杀改为击飞效果）
- `air_down_poise_damage` → 25（下落攻击高削韧）

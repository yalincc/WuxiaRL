# FSM 战斗系统 - 生成完成

## 生成内容

基于开发文档生成了完整的 2D 横版动作战斗系统 FSM 架构：

### 脚本文件 (scripts/fsm/)

| 文件 | 说明 |
|------|------|
| `state.gd` | State 基类，提供 enter/exit/update/handle_input 接口 + play_animation 辅助 |
| `state_machine.gd` | 状态机管理器，递归收集 State 子节点，物理帧委托当前状态 |
| `idle.gd` | 地面待机 → Move/Run/Attack/Dodge/Defense |
| `move.gd` | 行走（慢速），八方向移动 |
| `run.gd` | 奔跑（快速），按住 Shift |
| `jump.gd` | 跳跃抛物线，奔跑跳更远 |
| `attack_normal.gd` | 地面轻攻击，动画结束后 → Idle |
| `attack_skill.gd` | 长按技能攻击，动画结束后 → Idle |
| `defense.gd` | 防御（减伤80%），前0.15s防反窗口 |
| `defense_counter.gd` | 防反反击状态，完全无敌 |
| `dodge.gd` | 闪避翻滚，前0.12s完美闪避窗口 |
| `air_attack.gd` | 空中轻攻击，延续抛物线 |
| `air_down_attack.gd` | 下落攻击，快速向下 |
| `land.gd` | 落地硬直0.2s |
| `hit_stun.gd` | 受击硬直0.4s + 击退 |
| `input_buffer.gd` | 输入缓冲：0.25s阈值区分轻按/长按 |
| `hurt_box.gd` | 受击框，按当前状态分流伤害 |
| `hit_box.gd` | 攻击框，追踪已命中目标防重复打击 |

### 主脚本

- `scripts/player_main_fsm.gd` — PlayerFSM 角色主脚本，包含所有 @export 参数

### 场景文件

- `scenes/player_fsm.tscn` — 完整的节点树场景，可直接在编辑器中打开使用

## 适配说明

- **碰撞层已适配现有项目设置**：Player layer 2, HurtBox layer 5/mask 4, HitBox layer 3/mask 6
- **`take_damage(from_position, damage)` 签名与现有 `enemy.gd` 兼容**，可直接替换场景使用
- 动画名遵循文档规范（`attack_normal`, `attack_skill`, `defense` 等），已在 AnimationPlayer 中注册基础帧动画

## 使用步骤

1. 在 Godot 编辑器中打开 `scenes/player_fsm.tscn`
2. 打开 `scenes/main.tscn`，将 Player 实例替换为 `player_fsm.tscn`
3. 运行测试
4. 如需精细调整动画帧序列，在 AnimationPlayer 中编辑各动画轨道

# ROS 项目架构分析

> 最后更新: 2026-05-23 (同步其他作者代码后)

## 当前架构总览

```
ros_workspace/
├── src/          → 7 包
│   ├── arm_control_pkg          (机械臂控制)
│   ├── ar_tf_arm_5_pkg          (AR定位+导航+机械臂完整流程)
│   ├── auto_bkhome_pkg          (自动返航 - 空壳)
│   ├── bringup/                 (一键启动 launch 文件)
│   └── state_machine_pkg/       ★ 新增：竞赛状态机
│
└── src_task_1/   → 8 包
    ├── auto_bkhome_pkg          (自动返航 - 实现)
    ├── auto_charge_pkg          ★ 从 src/ 移入 (自动充电)
    ├── auto_nav_goal_4_pkg      (任务4：导航+AR定位)
    ├── auto_nav_goal_5_pkg      (任务5：导航+AR定位)
    ├── Grab_pkg                 (视觉引导抓取)
    └── remove_back_pkg          ★ 新增：单独的后撤节点
```

## 主要架构变化

### 正面改进

| 变化 | 说明 |
|------|------|
| 新增 `state_machine_pkg` | 完整的状态机实现，从参数服务器加载配置 |
| 删除冗余包 | `nav_goal_pkg`、`romove_pkg` 已移除 |
| `auto_charge_pkg` 归并 | 从 `src/` 移至 `src_task_1/`，统一任务包 |
| 新增 `remove_back_pkg` | 将后撤动作封装为独立可执行节点 |

### `state_machine_pkg` 架构分析

```
state_machine.launch  →  加载参数到参数服务器
       ↓
   main.cpp           →  入口，创建 StateMachine 实例
       ↓
   state_machine.cpp  →  17个状态的主循环
       ├── initialize()      → 连接服务/Action
       ├── waitForStart()    → 订阅 /competition/start
       ├── navigateTo()      → move_base Action 封装
       ├── recognizeAR()     → /track 服务封装
       ├── grasp()           → 机械臂+吸盘封装
       ├── store()           → 放置到中转箱
       ├── unloadGoods()     → 出库动作
       └── startCharging()   → 充电对接
```

### 仍存在的问题

### 1. 代码复用未解决

核心函数仍被复制粘贴：

```
arm_move()     → arm_control.cpp, ar_tf_arm_5.cpp, Grab.cpp, state_machine.cpp
set_relmove()  → auto_charge.cpp, auto_nav_goal_4.cpp, auto_nav_goal_5.cpp, state_machine.cpp
set_ARtrack()  → auto_charge.cpp, ar_tf_arm_5.cpp, auto_nav_goal_4/5.cpp, state_machine.cpp
navToGoal()    → ar_tf_arm_5.cpp, auto_charge.cpp, auto_bkhome.cpp, auto_nav_goal_4/5.cpp, state_machine.cpp
```

`state_machine.cpp` 内部重新实现了 `grasp()`、`store()` 等，但这些与其他文件的 `arm_move()` 本质相同。

### 2. 两个工作空间混杂

`auto_charge_pkg` 被移到 `src_task_1/` 后仍有部分相关包留在 `src/`。两个工作空间的 `auto_bkhome_pkg` 一个空壳一个有实现，容易混淆。

### 3. `remove_back_pkg` 设计争议

```cpp
// re_back.cpp — 整个节点只做一件事：后退 0.18m
set_relmove(-0.18, 0, 0);
```

这体现了 **单一职责** 的模块化思路，但 ROS 中更合适的做法是：
- 作为 `state_machine` 中的一个步骤（由状态机调用）
- 或作为服务/shell 命令（`rosservice call /relative_move`）

独立一个节点只执行一次后退动作就退出，意味着每次需要后撤都要启停一个节点。

### 4. 共享库仍未引入

推荐的三层架构仍未落地：

```
⛔ 当前：每个 .cpp 自己实现 navToGoal/arm_move/set_relmove
✅ 推荐：
  robot_core/               → 共享库 (librobot_core.so)
  robot_apps/               → 功能节点 (链接共享库)
  robot_params/             → YAML 配置文件
```

---

## 当前架构评分

| 维度 | 评分 | 说明 |
|------|------|------|
| 参数分离 | ★★★☆☆ | `state_machine_pkg` 做得很好，其余包仍然硬编码 |
| 代码复用 | ★☆☆☆☆ | 核心函数仍被复制粘贴 5~6 次 |
| 模块内聚 | ★★★★☆ | 每个包职责清晰，不互相依赖 |
| 包结构 | ★★☆☆☆ | 两个工作空间混杂，空包与实包并存 |
| 可扩展性 | ★★★★☆ | `state_machine_pkg` 的状态机架构易于扩展 |

---

## 优先改进建议

1. **修复 `auto_nav_goal_5` 缺失的后撤步** — 与任务4保持一致
2. **将 `state_machine_pkg` 的残余硬编码参数化** — grasp 坐标、中转箱坐标、50mm 偏移
3. **统一工作空间** — 将 `src/` 和 `src_task_1/` 合并为一个 catkin 工作空间

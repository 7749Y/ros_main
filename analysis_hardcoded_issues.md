# ROS 项目硬编码问题分析

> 最后更新: 2026-05-23 (同步其他作者代码后)

## 已解决/改善的硬编码问题

### 1. `state_machine_pkg` — 使用参数服务器

新增的状态机包**大幅改善了硬编码问题**，通过 `ros::param::param()` 从参数服务器加载配置，并给出合理默认值：

```cpp
// state_machine.cpp (构造函数中)
ros::param::param("~ar_id_1", ar_id_1_, 1);
ros::param::param("~pick_point_1_x", pick_point_1_x_, 0.5);
ros::param::param("~timeout_nav", timeout_nav_, 60.0);
// ... 所有坐标、AR ID、超时均通过参数传入
```

对应的 `launch/state_machine.launch` 将所有参数集中管理：

```xml
<param name="pick_point_1_x" value="0.5"/>
<param name="ar_id_1" value="1"/>
<param name="timeout_nav" value="60.0"/>
```

### 2. `Grab.cpp` — 运行时放置点选择

```cpp
// 从参数服务器检查放置点占用状态
nh.param("placement_point_1_occupied", point1_occupied, false);
if (!point1_occupied) {
    // 使用出刀点1 (107, 115, 42)
} else {
    // 使用出刀点2 (107, 185, 42)
}
```

### 3. 冗余包已删除

- `nav_goal_pkg` ( `src/`) — 已删除
- `romove_pkg` (`src/`) — 已删除

---

## 仍未解决的硬编码问题

### 1. `state_machine_pkg` 中的残余硬编码

尽管整体结构大大改善，但仍存在以下硬编码：

- **机械臂抓取坐标** (`state_machine.cpp:191,238`) — 硬编码在 `grasp()` 调用中：
  ```cpp
  grasp(107, 185, 42);   // Grasp1
  grasp(107, 128, 42);   // Grasp2
  ```
- **中转箱坐标** (`state_machine.cpp:622-624`) — `const float` 局部常量而非参数：
  ```cpp
  const float BOX_X = 80.0;
  const float BOX_Y = 0.0;
  const float BOX_Z = 30.0;
  ```
- **偏移量** (`state_machine.cpp:579`) — 50mm 机械臂提升偏移：
  ```cpp
  srv.request.pose.position.z = z + 50;  // 抬高50mm
  ```
- **话题/服务名** — 所有服务名仍为字符串字面量
- **frame_id** (`"map"` 在 `navigateTo` 中)

### 2. `remove_back_pkg` — 新增但带硬编码

```cpp
// re_back.cpp
set_relmove(-0.18, 0, 0);               // 位移量硬编码
client = nh.serviceClient<...>("/relative_move");  // 服务名硬编码
setlocale(LC_CTYPE, "zh_CN.utf8");       // 区域编码
```

### 3. `auto_nav_goal_5.cpp` — 后撤步被注释（新问题）

同步后 `auto_nav_goal_5` 的后撤步被注释掉了，而 `auto_nav_goal_4` 有后撤步。两者行为不一致：

| 文件 | 前移 | 后撤 |
|------|------|------|
| `auto_nav_goal_4.cpp` | 0.18 | **-0.18 (有)** |
| `auto_nav_goal_5.cpp` | 0.18 | **-0.18 (被注释)** |

### 4. `auto_charge.cpp` — 前后距离不匹配

已移至 `src_task_1/auto_charge_pkg/`，内容未变：
- 前移 0.18m → 后撤 **-0.2m** (不对称)

### 5. 其他包保持不变

`arm_control.cpp`、`ar_tf_arm_5.cpp`、`auto_bkhome.cpp`、`Grab.cpp` 中的机械臂坐标、导航点、延时等与原分析一致。

---

## 总结

| 分类 | 状态 |
|------|------|
| `state_machine_pkg` 参数化 | ✅ 大幅改善，仍有残余 |
| `Grab.cpp` 放置点选择 | ✅ 改进 |
| `nav_goal_pkg`、`romove_pkg` | ✅ 已删除 |
| `auto_nav_goal_5` 后撤步 | ❌ **新问题：被注释** |
| `auto_charge` 距离不匹配 | ❌ 未修复 |
| 机械臂坐标、偏移、延时 | ❌ 大部分未改 |

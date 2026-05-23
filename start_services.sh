#!/bin/bash
# 一键启动所有仿真服务 —— 每个服务在独立终端中运行

# ===== 清理残留进程 =====
echo "清理上一次的 ROS 进程..."
killall -9 rosmaster 2>/dev/null || true
killall -9 rosout 2>/dev/null || true
killall -9 gzserver gzclient 2>/dev/null || true
sleep 1

# ===== 初始化环境 =====
source /opt/ros/noetic/setup.bash
source $HOME/oryxbot_ws/devel/setup.bash --extend

export REI_ROBOT=oryxbotsim
export MAP_DIRECTORY=$HOME/ros_workspace/maps

# ===== 启动 roscore =====
echo "启动 roscore..."
roscore &
sleep 2

# 等待 roscore 就绪
until rostopic list > /dev/null 2>&1; do sleep 1; done
echo "roscore 就绪"

# ===== 各终端初始化命令模板 =====
INIT="source /opt/ros/noetic/setup.bash; source $HOME/oryxbot_ws/devel/setup.bash --extend; export REI_ROBOT=oryxbotsim; export MAP_DIRECTORY=$HOME/ros_workspace/maps;"

# ===== 启动 5 个服务终端 =====
# 终端 1：导航 (Gazebo + map_server + move_base + amcl + rviz)
gnome-terminal --window --title="Navigation" -- bash -c "$INIT roslaunch oryxbot_navigation demo_nav_2d.launch; exec bash"

# 终端 2：相对移动
gnome-terminal --window --title="RelativeMove" -- bash -c "$INIT roslaunch relative_move relative_move.launch; exec bash"

# 终端 3：底盘 AR 二次定位
gnome-terminal --window --title="AR_Base" -- bash -c "$INIT roslaunch ar_pose ar_base_sim.launch; exec bash"

# 终端 4：机械臂控制
gnome-terminal --window --title="ArmCtrl" -- bash -c "$INIT roslaunch oryxbot_description swiftpro_control.launch; exec bash"

# 终端 5：手部 AR 标签检测
gnome-terminal --window --title="AR_Hand" -- bash -c "$INIT roslaunch ar_pose ar_hand_sim.launch; exec bash"

#!/bin/bash
source ~/go2_ros2_sim_py/install/local_setup.bash

echo "Testing robot commands..."
echo ""

echo "1. Making robot walk..."
ros2 service call /robot1/robot_behavior_command quadropted_msgs/srv/RobotBehaviorCommand "command: walk"

echo ""
echo "2. Making robot sit..."
sleep 2
ros2 service call /robot1/robot_behavior_command quadropted_msgs/srv/RobotBehaviorCommand "command: sit"

echo ""
echo "3. Making robot stand up..."
sleep 2
ros2 service call /robot1/robot_behavior_command quadropted_msgs/srv/RobotBehaviorCommand "command: up"

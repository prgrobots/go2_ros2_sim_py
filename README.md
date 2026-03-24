# Unitree Go2 / Go1 — ROS2 Simulation and Real Robot

Simulate Unitree quadruped robots (Go2 and Go1) in Gazebo Harmonic with full ROS2 integration, then connect to the real Go2 Pro over WiFi using the same ROS2 commands. The robot walks and rotates with 12 degrees of freedom, uses inverse kinematics for motion, direct kinematics for odometry, and exposes a `quadropted_msgs` interface. All control logic is written in Python.

![Robot moving](media/robot_move.gif)

---

## Platform

| | |
|---|---|
| **OS** | Ubuntu 24.04 (Noble) — WSL2 or native |
| **ROS2** | Jazzy |
| **Simulator** | Gazebo Harmonic |
| **Real robot** | Unitree Go2 Pro (Air/Edu also supported) |
| **Tested on** | WSL2 (Windows 11) + NVIDIA GPU |

> **Note:** ROS2 Jazzy requires Ubuntu 24.04. The Docker path in this repo targets bare-metal NVIDIA and is not recommended for WSL2 — use the install script below instead.

---

## How it works

The install script sets up two independent workspaces:

```
~/go_sim/       ← simulation (this repo + Gazebo Harmonic)
~/go2_sdk/      ← real dog bridge (go2_ros2_sdk, WebRTC → ROS2)
```

The sim and real dog use the same ROS2 commands — the only difference is which launch file you run and the topic namespace:

| | Simulation | Real dog |
|---|---|---|
| Source | `source ~/go_sim/go2_sim.env` | `source ~/go2_sdk/go2_sdk.env` |
| Launch | `ros2 launch gazebo_sim launch.py` | `ros2 launch go2_robot_sdk robot.launch.py` |
| Move topic | `/robot1/cmd_vel` | `/cmd_vel` |
| Extra step | — | Connect to Go2 WiFi, set `ROBOT_IP` |

---

## Installation

### WSL2 — one-shot script (recommended)

If you don't have Ubuntu 24.04 in WSL2 yet, run this in PowerShell first:

```powershell
wsl --install -d Ubuntu-24.04
```

Then inside your WSL2 terminal:

```bash
curl -O https://raw.githubusercontent.com/prgrobots/go2_ros2_sim_py/main/install/go2_sim_setup.sh
chmod +x go2_sim_setup.sh
./go2_sim_setup.sh
```

The script runs 12 steps unattended (~15 min depending on connection):

| Step | What it does |
|---|---|
| 1 | System update, UTF-8 locale |
| 2 | ROS2 Jazzy desktop (includes Gazebo Harmonic) |
| 3 | Gazebo bridge + `ros2_control` packages |
| 4 | Nav2 stack |
| 5 | CycloneDDS + teleop tools |
| 6 | WSL2 NVIDIA GPU passthrough |
| 7 | Clone this repo + `rosdep install` |
| 8 | `colcon build` (sim workspace) |
| 9 | Write `~/go_sim/go2_sim.env` |
| 10 | Clone `go2_ros2_sdk` |
| 11 | SDK Python deps + `colcon build` |
| 12 | Write `~/go2_sdk/go2_sdk.env` |

> **Do not run as root.** The script calls sudo internally where needed.

> **NVIDIA:** Do not install NVIDIA drivers inside WSL2 — they live on the Windows host and are exposed automatically via `/usr/lib/wsl/lib`. Windows driver must be ≥ 510.

> **Display:** WSLg (Windows 11 / Win10 21H2+) works out of the box. VcXsrv/Xming users: start with *Disable access control* checked.

---

### Manual installation

<details>
<summary>Expand manual steps</summary>

**1. Install ROS2 Jazzy**

Follow the [official ROS2 Jazzy installation guide](https://docs.ros.org/en/jazzy/Installation/Ubuntu-Install-Debs.html) for Ubuntu 24.04.

**2. Install dependencies**

```bash
sudo apt install -y \
  ros-jazzy-ros-gz ros-jazzy-ros-gz-bridge ros-jazzy-ros-gz-sim \
  ros-jazzy-gz-ros2-control ros-jazzy-ros2-control ros-jazzy-ros2-controllers \
  ros-jazzy-joint-state-publisher ros-jazzy-robot-state-publisher ros-jazzy-xacro \
  ros-jazzy-navigation2 ros-jazzy-nav2-bringup \
  ros-jazzy-rmw-cyclonedds-cpp ros-jazzy-teleop-twist-keyboard \
  ros-jazzy-image-tools ros-jazzy-vision-msgs \
  python3-colcon-common-extensions python3-rosdep portaudio19-dev clang
```

**3. Clone and build the sim**

```bash
mkdir -p ~/go_sim/src
cd ~/go_sim/src
git clone https://github.com/prgrobots/go2_ros2_sim_py.git .
cd ~/go_sim
rosdep update && rosdep install --from-paths src --ignore-src -r -y
colcon build --symlink-install
```

**4. Clone and build go2_ros2_sdk**

```bash
mkdir -p ~/go2_sdk/src
git clone --recurse-submodules https://github.com/abizovnuralem/go2_ros2_sdk.git ~/go2_sdk/src
cd ~/go2_sdk/src
pip install -r requirements.txt --break-system-packages
cd ~/go2_sdk
source /opt/ros/jazzy/setup.bash
rosdep install --from-paths src --ignore-src -r -y
colcon build --symlink-install
```

**5. Configure CycloneDDS for the sim** — create `~/.ros/cyclonedds.xml`:

```xml
<CycloneDDS>
  <Domain>
    <General>
      <Interfaces>
        <NetworkInterface name="lo" multicast="true" />
      </Interfaces>
      <DontRoute>true</DontRoute>
    </General>
    <Discovery>
      <ParticipantIndex>auto</ParticipantIndex>
      <MaxAutoParticipantIndex>100</MaxAutoParticipantIndex>
    </Discovery>
  </Domain>
</CycloneDDS>
```

</details>

---

## Running the Simulation

### 1. Source the environment

Every terminal that runs ROS2 commands needs this first:

```bash
source ~/go_sim/go2_sim.env
```

> If you get `ros2: command not found` — you forgot to source.

To source automatically in every new terminal:

```bash
echo "source ~/go_sim/go2_sim.env" >> ~/.bashrc
```

### 2. Launch Gazebo

```bash
ros2 launch gazebo_sim launch.py
```

### 3. Drive the robot

In a new terminal:

```bash
source ~/go_sim/go2_sim.env
ros2 run teleop_twist_keyboard teleop_twist_keyboard \
  --ros-args -r /cmd_vel:=/robot1/cmd_vel
```

### Robot modes

| Mode | Description |
|------|-------------|
| `REST` | Default. Robot holds position, cannot walk. |
| `STAND` | Robot can rotate in place. |
| `TROT` | Walking mode. |

Switch modes:

```bash
ros2 topic pub /robot1/robot_mode quadropted_msgs/msg/RobotModeCommand \
  "{mode: 'STAND', robot_id: 1}"
```

![Mode switching](media/move1.gif)

### Sit / stand / walk behaviours

```bash
ros2 service call /robot1/robot_behavior_command \
  quadropted_msgs/srv/RobotBehaviorCommand "{command: 'walk'}"
```

| Command | Behaviour |
|---------|-----------|
| `walk` | Stands up and enables walking (TROT) |
| `up` | Stands up and locks movement |
| `sit` | Sits down |

![Sit/stand](media/sitUp.gif)

---

## Connecting to the Real Go2

The real dog bridge runs entirely on your laptop in WSL2 — nothing needs to be installed on the robot.

### Prerequisites

1. Find the robot's IP in the Unitree app: **Device → Data → Automatic Machine Inspection → STA Network: wlan0**
2. Connect your laptop WiFi to the Go2's network
3. **Close the Unitree mobile app** — it holds the WebRTC connection slot and will block the SDK

### 1. Set your robot IP

Edit the env file the install script created:

```bash
nano ~/go2_sdk/go2_sdk.env
# Change: export ROBOT_IP="192.168.8.181"  ← your Go2's actual IP
```

### 2. Source and launch

In a fresh terminal (do not mix with `go2_sim.env`):

```bash
source ~/go2_sdk/go2_sdk.env
ros2 launch go2_robot_sdk robot.launch.py
```

RViz will open. After ~4 seconds you'll see the camera feed, LiDAR point cloud, and joint states updating live.

### 3. Drive the real dog

In a new terminal:

```bash
source ~/go2_sdk/go2_sdk.env
ros2 run teleop_twist_keyboard teleop_twist_keyboard
```

No topic remap needed — the real dog uses `/cmd_vel` directly.

### What topics the real dog exposes

| Topic | Content |
|---|---|
| `/cmd_vel` | Velocity commands (Twist) |
| `/go2_camera/color/image` | Front colour camera |
| `/point_cloud2` | LiDAR point cloud |
| `/scan` | Laser scan |
| `/imu` | IMU data |
| `/joint_states` | All 12 joint positions live |
| `/map` | SLAM map (slam_toolbox) |
| `/odom` | Odometry |

> **Note:** `go2_ros2_sdk` officially targets Ubuntu 22.04 / ROS2 Humble. It builds on Jazzy but is untested upstream — if you hit issues check `~/go2_sdk/build.log`.

---

## Multi-Robot Setup

### Switching between Go2 and Go1

Edit line 102 of `gazebo_sim/launch/gazebo_multi_nav2_world.launch.py`:

```python
robot_description_package = "go2_description"  # Go2
robot_description_package = "go1_description"  # Go1
```

![Model switching](media/switch.png)

### Adding multiple robots

Edit `robot.config` to add namespaces and spawn coordinates. Each robot gets its own Nav2 stack automatically.

![Robot config](media/robot_config.png)

![Go1 multi-robot](media/go1multi.png)
![Go2 multi-robot](media/go2multi.png)

### Nav2

![Nav2](media/robot-nav2.gif)

---

## Troubleshooting

**`ros2: command not found`**
Run `source ~/go_sim/go2_sim.env` (sim) or `source ~/go2_sdk/go2_sdk.env` (real dog). Every terminal needs one of these.

**Gazebo black screen**
Add `export LIBGL_ALWAYS_SOFTWARE=1` to `~/go_sim/go2_sim.env` and re-source.

**SDK can't connect to the dog**
Check: (1) laptop is on Go2 WiFi, (2) Unitree app is closed, (3) `ROBOT_IP` in `go2_sdk.env` matches the IP shown in the app, (4) dog is fully booted.

**`/usr/lib/wsl/lib` not found**
Update your Windows NVIDIA driver to ≥ 510 from [nvidia.com](https://www.nvidia.com/Download/index.aspx).

**`colcon build` fails (sim)**
Check `~/go_sim/build.log`. Re-run `rosdep install --from-paths src --ignore-src -r -y` then retry.

**`colcon build` fails (SDK)**
Check `~/go2_sdk/build.log`. `open3d` has no Python 3.12 wheel and is skipped automatically — that's expected. Other failures are usually missing apt packages.

**CycloneDDS warnings in the terminal**
Harmless on loopback. Never source `go2_sim.env` and `go2_sdk.env` in the same terminal — they use different CycloneDDS configs and will conflict.

---

## Credits

- [mike4192 — SpotMicro](https://github.com/mike4192/spotMicro)
- [Unitree Robotics — A1 ROS](https://github.com/unitreerobotics/a1_ros)
- [QUADRUPED ROBOTICS](https://quadruped.de)
- [lnotspotl](https://github.com/lnotspotl)
- [anujjain-dev — Unitree Go2 ROS2](https://github.com/anujjain-dev/unitree-go2-ros2)
- [abizovnuralem — go2_ros2_sdk](https://github.com/abizovnuralem/go2_ros2_sdk)
- Original simulation: [abutalipovvv/go2_ros2_sim_py](https://github.com/abutalipovvv/go2_ros2_sim_py)

---

## TODO

- Add Gazebo Classic support (physics and inertial parameters for URDF)
- Odometry calibration
- Remap launch file to unify `/robot1/cmd_vel` → `/cmd_vel` across sim and real

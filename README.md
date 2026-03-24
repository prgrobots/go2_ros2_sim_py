# Unitree Go2 / Go1 Simulation in Gazebo Sim

Simulate Unitree quadruped robots (Go2 and Go1) in Gazebo Harmonic with full ROS2 integration. The robot walks and rotates with 12 degrees of freedom, uses inverse kinematics for motion, direct kinematics for odometry, and exposes a `quadropted_msgs` interface. All control logic is written in Python.

![Robot moving](media/robot_move.gif)

---

## Platform

| | |
|---|---|
| **OS** | Ubuntu 24.04 (Noble) |
| **ROS2** | Jazzy |
| **Simulator** | Gazebo Harmonic |
| **Tested on** | WSL2 (Windows 11) + NVIDIA GPU |

> **Note:** ROS2 Jazzy requires Ubuntu 24.04. The Docker path in this repo targets bare-metal NVIDIA and is not recommended for WSL2 — use the install script below instead.

---

## Installation

### WSL2 — Recommended (one-shot script)

If you don't have Ubuntu 24.04 in WSL2 yet, run this in PowerShell first:

```powershell
wsl --install -d Ubuntu-24.04
```

Then inside your WSL2 terminal:

```bash
# Download the install script
curl -O https://raw.githubusercontent.com/prgrobots/go2_ros2_sim_py/main/install/go2_sim_setup.sh

# Make it executable and run it (do NOT use sudo)
chmod +x go2_sim_setup.sh
./go2_sim_setup.sh
```

The script handles everything in order:
1. System update and UTF-8 locale
2. ROS2 Jazzy desktop (includes Gazebo Harmonic)
3. Gazebo bridge and `ros2_control` packages
4. Nav2 stack
5. CycloneDDS and teleop tools
6. WSL2 NVIDIA GPU passthrough (`/usr/lib/wsl/lib`)
7. Repo clone and `rosdep install`
8. `colcon build`
9. Environment file at `~/go_sim/go2_sim.env`

> **NVIDIA note:** Do NOT install NVIDIA drivers inside WSL2. They live on the Windows host and are exposed automatically. Your Windows driver must be ≥ 510.

> **Display note:** WSLg (built into Windows 11 and Win10 21H2+) works out of the box. If you're using VcXsrv or Xming, start it first with *Disable access control* checked.

---

### Manual installation (build from source)

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
  python3-colcon-common-extensions python3-rosdep
```

**3. Clone and build**

```bash
mkdir -p ~/go_sim/src
cd ~/go_sim/src
git clone https://github.com/prgrobots/go2_ros2_sim_py.git .
cd ~/go_sim
rosdep update
rosdep install --from-paths src --ignore-src -r -y
colcon build --symlink-install
```

**4. Configure CycloneDDS**

Create `~/.ros/cyclonedds.xml`:

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

### Step 1 — Source the environment

**Every terminal** that runs ROS2 or Gazebo commands needs this sourced first:

```bash
source ~/go_sim/go2_sim.env
```

To make this automatic in every new terminal:

```bash
echo "source ~/go_sim/go2_sim.env" >> ~/.bashrc
```

> If you get `ros2: command not found`, you forgot to source.

### Step 2 — Launch Gazebo

```bash
ros2 launch gazebo_sim launch.py
```

---

## Controlling the Robot

### Moving the Robot

The robot accepts velocity commands on `<robot_namespace>/cmd_vel`. The default namespace is `robot1`.

In a new terminal (remember to source first):

```bash
source ~/go_sim/go2_sim.env
ros2 run teleop_twist_keyboard teleop_twist_keyboard \
  --ros-args -r /cmd_vel:=/robot1/cmd_vel
```

### Robot Modes

The robot has three modes:

| Mode | Description |
|------|-------------|
| `REST` | Default. Robot holds position, cannot walk. |
| `STAND` | Robot can rotate in place. |
| `TROT` | Walking mode. |

Switch modes by publishing to the `robot_mode` topic:

```bash
ros2 topic pub /robot1/robot_mode quadropted_msgs/msg/RobotModeCommand \
  "{mode: 'STAND', robot_id: 1}"
```

![Mode switching](media/move1.gif)

### Sit / Stand / Walk Behaviours

Use the `robot_behavior_command` service:

```bash
ros2 service call /robot1/robot_behavior_command \
  quadropted_msgs/srv/RobotBehaviorCommand "{command: 'walk'}"
```

| Command | Behaviour |
|---------|-----------|
| `walk` | Stands up (REST) and enables walking (TROT) |
| `up` | Stands up (REST) and locks movement |
| `sit` | Sits down (STAND) |

![Sit/stand](media/sitUp.gif)

---

## Multi-Robot Setup

### Switching Between Go2 and Go1

Edit line 102 of `gazebo_sim/launch/gazebo_multi_nav2_world.launch.py`:

```python
# Go2:
robot_description_package = "go2_description"

# Go1:
robot_description_package = "go1_description"
```

![Model switching](media/switch.png)

### Adding Multiple Robots

Edit `robot.config` to add namespaces and spawn coordinates:

![Robot config](media/robot_config.png)

Each robot gets its own Nav2 stack automatically.

![Go1 multi-robot](media/go1multi.png)
![Go2 multi-robot](media/go2multi.png)

### Nav2 Demo

![Nav2](media/robot-nav2.gif)

---

## Troubleshooting

**`ros2: command not found`**
Run `source ~/go_sim/go2_sim.env` — every terminal needs this.

**Gazebo opens but shows a black screen**
Add this to `~/go_sim/go2_sim.env` and re-source:
```bash
export LIBGL_ALWAYS_SOFTWARE=1
```

**`/usr/lib/wsl/lib` not found during install**
Your Windows NVIDIA driver may be too old. Update to ≥ 510 from [nvidia.com](https://www.nvidia.com/Download/index.aspx).

**`colcon build` fails**
Check `~/go_sim/build.log` for the specific error. Most common cause is a missing apt package — re-run `rosdep install --from-paths src --ignore-src -r -y` and try again.

**CycloneDDS warnings in the terminal**
These are usually harmless on loopback. If topics aren't visible across terminals, confirm `RMW_IMPLEMENTATION=rmw_cyclonedds_cpp` is exported (it's set in `go2_sim.env`).

---

## Credits

- [mike4192 — SpotMicro](https://github.com/mike4192/spotMicro)
- [Unitree Robotics — A1 ROS](https://github.com/unitreerobotics/a1_ros)
- [QUADRUPED ROBOTICS](https://quadruped.de)
- [lnotspotl](https://github.com/lnotspotl)
- [anujjain-dev — Unitree Go2 ROS2](https://github.com/anujjain-dev/unitree-go2-ros2)
- Original simulation: [abutalipovvv/go2_ros2_sim_py](https://github.com/abutalipovvv/go2_ros2_sim_py)

---

## TODO

- Add Gazebo Classic support (physics and inertial parameters for URDF)
- Odometry calibration

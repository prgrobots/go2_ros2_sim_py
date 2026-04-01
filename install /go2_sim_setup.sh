#!/usr/bin/env bash
# =============================================================================
# go2_ros2_sim_py — Native Linux Setup Script
# Target : Ubuntu 24.04 (Noble) — bare metal or VM, NVIDIA GPU
# Stack  : ROS2 Jazzy + Gazebo Harmonic + Nav2 + go2_ros2_sdk
# Repo   : https://github.com/prgrobots/go2_ros2_sim_py
#
# Usage  : chmod +x go2_sim_setup_linux.sh && ./go2_sim_setup_linux.sh
#
# Notes  :
#   - Run as your normal user (NOT root). Sudo is called internally where needed.
#   - Install NVIDIA drivers normally via Ubuntu before running this script:
#       sudo ubuntu-drivers install
#   - Gazebo and RViz2 display natively — no X server config needed.
# =============================================================================

set -eo pipefail
# Note: -u (unbound variable) intentionally omitted — ROS2 setup.bash uses
# unset variables internally (AMENT_TRACE_SETUP_FILES etc) and will crash with -u.

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ── Sanity checks ─────────────────────────────────────────────────────────────
[[ "$EUID" -eq 0 ]] && error "Do not run as root. Run as your regular user."

# Verify Ubuntu 24.04
if ! grep -q 'noble' /etc/os-release 2>/dev/null; then
    error "This script requires Ubuntu 24.04 (Noble). \
You appear to be on a different distro/version."
fi

# Refuse to run inside WSL2 — use go2_sim_setup.sh instead
if grep -qi 'microsoft' /proc/version 2>/dev/null; then
    error "WSL2 detected. Use go2_sim_setup.sh (the WSL2 version) instead."
fi

info "=== Starting go2_ros2_sim_py native Linux setup ==="
info "    Ubuntu 24.04 | ROS2 Jazzy | Gazebo Harmonic | Native Linux"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# STEP 1 — System base update
# ─────────────────────────────────────────────────────────────────────────────
info "[1/11] Updating system packages..."
sudo apt update -y
sudo apt upgrade -y
sudo apt install -y \
    curl wget git gnupg2 lsb-release \
    build-essential cmake python3-pip python3-vcstools \
    software-properties-common locales

# Ensure UTF-8 locale (ROS2 requirement)
sudo locale-gen en_US en_US.UTF-8
sudo update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
export LANG=en_US.UTF-8

# ─────────────────────────────────────────────────────────────────────────────
# STEP 2 — ROS2 Jazzy repository + install
# ─────────────────────────────────────────────────────────────────────────────
info "[2/11] Installing ROS2 Jazzy (desktop-full)..."

if ! dpkg -l ros2-apt-source &>/dev/null; then
    sudo apt install -y curl
    export ROS_APT_SOURCE_VERSION
    ROS_APT_SOURCE_VERSION=$(curl -s \
        https://api.github.com/repos/ros-infrastructure/ros-apt-source/releases/latest \
        | grep -F "tag_name" | awk -F\" '{print $4}')
    curl -L -o /tmp/ros2-apt-source.deb \
        "https://github.com/ros-infrastructure/ros-apt-source/releases/download/${ROS_APT_SOURCE_VERSION}/ros2-apt-source_${ROS_APT_SOURCE_VERSION}.$(. /etc/os-release && echo "${UBUNTU_CODENAME:-${VERSION_CODENAME}}")_all.deb"
    sudo dpkg -i /tmp/ros2-apt-source.deb
fi

sudo apt update -y

sudo apt install -y \
    ros-jazzy-desktop \
    ros-dev-tools \
    python3-colcon-common-extensions \
    python3-rosdep

# ─────────────────────────────────────────────────────────────────────────────
# STEP 3 — Gazebo Harmonic extras & ros_gz bridge
# ─────────────────────────────────────────────────────────────────────────────
info "[3/11] Installing Gazebo Harmonic bridge and control packages..."

sudo apt install -y \
    ros-jazzy-ros-gz \
    ros-jazzy-ros-gz-bridge \
    ros-jazzy-ros-gz-sim \
    ros-jazzy-gz-ros2-control \
    ros-jazzy-ros2-control \
    ros-jazzy-ros2-controllers \
    ros-jazzy-joint-state-publisher \
    ros-jazzy-joint-state-publisher-gui \
    ros-jazzy-robot-state-publisher \
    ros-jazzy-xacro

# ─────────────────────────────────────────────────────────────────────────────
# STEP 4 — Nav2 stack
# ─────────────────────────────────────────────────────────────────────────────
info "[4/11] Installing Nav2..."

sudo apt install -y \
    ros-jazzy-navigation2 \
    ros-jazzy-nav2-bringup \
    ros-jazzy-nav2-map-server \
    ros-jazzy-nav2-lifecycle-manager \
    ros-jazzy-nav2-bt-navigator \
    ros-jazzy-slam-toolbox

# ─────────────────────────────────────────────────────────────────────────────
# STEP 5 — CycloneDDS + teleop
# ─────────────────────────────────────────────────────────────────────────────
info "[5/11] Installing CycloneDDS and teleop tools..."

sudo apt install -y \
    ros-jazzy-rmw-cyclonedds-cpp \
    ros-jazzy-teleop-twist-keyboard \
    ros-jazzy-teleop-twist-joy \
    ros-jazzy-twist-mux

# ─────────────────────────────────────────────────────────────────────────────
# STEP 6 — Clone the repo and rosdep
# ─────────────────────────────────────────────────────────────────────────────
info "[6/11] Cloning go2_ros2_sim_py into ~/go_sim/src ..."

WORKSPACE="$HOME/go_sim"
SRC="$WORKSPACE/src"
mkdir -p "$SRC"

if [[ -d "$SRC/.git" ]]; then
    warn "    Repo already cloned at $SRC — pulling latest..."
    git -C "$SRC" pull
else
    git clone https://github.com/prgrobots/go2_ros2_sim_py.git "$SRC"
fi

# Bootstrap rosdep
source /opt/ros/jazzy/setup.bash
if [[ ! -f /etc/ros/rosdep/sources.list.d/20-default.list ]]; then
    sudo rosdep init
fi
rosdep update

info "    Running rosdep install..."
cd "$WORKSPACE"
rosdep install --from-paths src --ignore-src -r -y

# ─────────────────────────────────────────────────────────────────────────────
# STEP 7 — colcon build (sim)
# ─────────────────────────────────────────────────────────────────────────────
info "[7/11] Building sim workspace with colcon..."
cd "$WORKSPACE"
source /opt/ros/jazzy/setup.bash

colcon build \
    --symlink-install \
    --cmake-args -DCMAKE_BUILD_TYPE=Release \
    2>&1 | tee "$WORKSPACE/build.log"

if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
    error "colcon build failed. See $WORKSPACE/build.log for details."
fi

# ─────────────────────────────────────────────────────────────────────────────
# STEP 8 — Write sim environment file
# ─────────────────────────────────────────────────────────────────────────────
info "[8/11] Writing sim environment helper..."

# On native Linux CycloneDDS works fine with defaults — no loopback pinning needed.
# We still set it explicitly for consistency with the real dog env file.
CYCLONE_XML="$HOME/.ros/cyclonedds.xml"
mkdir -p "$HOME/.ros"
cat > "$CYCLONE_XML" <<'XML'
<CycloneDDS>
  <Domain>
    <Discovery>
      <ParticipantIndex>auto</ParticipantIndex>
      <MaxAutoParticipantIndex>100</MaxAutoParticipantIndex>
    </Discovery>
  </Domain>
</CycloneDDS>
XML

ENV_FILE="$WORKSPACE/go2_sim.env"
cat > "$ENV_FILE" <<EOF
#!/usr/bin/env bash
# Source this file before launching the simulation:
#   source ~/go_sim/go2_sim.env

source /opt/ros/jazzy/setup.bash
source $WORKSPACE/install/local_setup.bash

export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
export CYCLONEDDS_URI=file://$CYCLONE_XML
export GZ_SIM_RESOURCE_PATH=$SRC/gazebo_sim/models

echo "[go2_sim] Environment ready. Run: ros2 launch gazebo_sim launch.py"
EOF
chmod +x "$ENV_FILE"

BASHRC_MARKER="# go2_sim auto-source"
if ! grep -q "$BASHRC_MARKER" "$HOME/.bashrc"; then
    cat >> "$HOME/.bashrc" <<BASHRC

$BASHRC_MARKER
# Remove the line below if you don't want go2_sim sourced in every shell:
# source $ENV_FILE
BASHRC
fi

# ─────────────────────────────────────────────────────────────────────────────
# STEP 9 — Clone go2_ros2_sdk (real dog bridge)
# ─────────────────────────────────────────────────────────────────────────────
info "[9/11] Cloning go2_ros2_sdk into ~/go2_sdk/src ..."

SDK_WORKSPACE="$HOME/go2_sdk"
SDK_SRC="$SDK_WORKSPACE/src"
mkdir -p "$SDK_SRC"

if [[ -d "$SDK_SRC/.git" ]]; then
    warn "    SDK repo already cloned at $SDK_SRC — pulling latest..."
    git -C "$SDK_SRC" pull
    git -C "$SDK_SRC" submodule update --init --recursive
else
    git clone --recurse-submodules \
        https://github.com/abizovnuralem/go2_ros2_sdk.git "$SDK_SRC"
fi

# ─────────────────────────────────────────────────────────────────────────────
# STEP 10 — SDK Python deps + rosdep + colcon build
# ─────────────────────────────────────────────────────────────────────────────
info "[10/11] Installing SDK Python deps and building..."

sudo apt install -y \
    ros-jazzy-image-tools \
    ros-jazzy-vision-msgs \
    portaudio19-dev \
    clang

cd "$SDK_SRC"
pip install -r requirements.txt --break-system-packages

# open3d has no Python 3.12 wheel — skip gracefully
pip install open3d --break-system-packages 2>/dev/null \
    || warn "    open3d skipped (no Python 3.12 wheel) — LiDAR 3D map saving won't work, everything else is fine."

cd "$SDK_WORKSPACE"
source /opt/ros/jazzy/setup.bash
rosdep install --from-paths src --ignore-src -r -y

colcon build \
    --symlink-install \
    --cmake-args -DCMAKE_BUILD_TYPE=Release \
    2>&1 | tee "$SDK_WORKSPACE/build.log"

if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
    warn "go2_ros2_sdk colcon build had errors — see $SDK_WORKSPACE/build.log"
    warn "This may be a Jazzy compatibility issue. Sim workspace is unaffected."
fi

# ─────────────────────────────────────────────────────────────────────────────
# STEP 11 — Write SDK environment file
# ─────────────────────────────────────────────────────────────────────────────
info "[11/11] Writing real-dog environment helper..."

# CycloneDDS for real dog — needs to reach the Go2 over WiFi, not loopback
CYCLONE_REAL_XML="$HOME/.ros/cyclonedds_real.xml"
cat > "$CYCLONE_REAL_XML" <<'XML'
<CycloneDDS>
  <Domain>
    <General>
      <DontRoute>false</DontRoute>
    </General>
    <Discovery>
      <ParticipantIndex>auto</ParticipantIndex>
      <MaxAutoParticipantIndex>100</MaxAutoParticipantIndex>
    </Discovery>
  </Domain>
</CycloneDDS>
XML

SDK_ENV_FILE="$SDK_WORKSPACE/go2_sdk.env"
cat > "$SDK_ENV_FILE" <<EOF
#!/usr/bin/env bash
# Source this file before connecting to the real Go2:
#   source ~/go2_sdk/go2_sdk.env
#
# Prerequisites:
#   1. Connect your laptop WiFi to the Go2's network
#   2. Find the robot IP in the Unitree app:
#      Device → Data → Automatic Machine Inspection → STA Network: wlan0
#   3. Close the Unitree mobile app — it holds the WebRTC slot
#   4. Edit ROBOT_IP below

source /opt/ros/jazzy/setup.bash
source $SDK_WORKSPACE/install/local_setup.bash

# ── Set your robot's IP here ─────────────────────────────────────────────────
export ROBOT_IP="192.168.8.181"   # <-- change this to your Go2's IP
export CONN_TYPE="webrtc"

export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
export CYCLONEDDS_URI=file://$CYCLONE_REAL_XML

echo "[go2_sdk] Environment ready."
echo "         ROBOT_IP=\$ROBOT_IP  CONN_TYPE=\$CONN_TYPE"
echo "         Run: ros2 launch go2_robot_sdk robot.launch.py"
echo ""
echo "         NOTE: Close the Unitree app before connecting."
echo "         NOTE: Do not source go2_sim.env in the same terminal."
EOF
chmod +x "$SDK_ENV_FILE"

# ─────────────────────────────────────────────────────────────────────────────
# Done
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                   Setup complete!                            ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║${NC}  ── SIMULATION (no dog needed) ───────────────────────────── "
echo -e "${GREEN}║${NC}  source ~/go_sim/go2_sim.env                                 "
echo -e "${GREEN}║${NC}  ros2 launch gazebo_sim launch.py                            "
echo -e "${GREEN}║${NC}                                                              "
echo -e "${GREEN}║${NC}  ── REAL DOG ──────────────────────────────────────────────  "
echo -e "${GREEN}║${NC}  1. Edit ROBOT_IP in ~/go2_sdk/go2_sdk.env                   "
echo -e "${GREEN}║${NC}  2. Connect laptop WiFi to Go2 network                       "
echo -e "${GREEN}║${NC}  3. Close the Unitree mobile app                             "
echo -e "${GREEN}║${NC}  source ~/go2_sdk/go2_sdk.env                                "
echo -e "${GREEN}║${NC}  ros2 launch go2_robot_sdk robot.launch.py                   "
echo -e "${GREEN}║${NC}                                                              "
echo -e "${GREEN}║${NC}  ── TELEOP ─────────────────────────────────────────────────  "
echo -e "${GREEN}║${NC}  ros2 run teleop_twist_keyboard teleop_twist_keyboard \\      "
echo -e "${GREEN}║${NC}    --ros-args -r /cmd_vel:=/robot1/cmd_vel   # sim           "
echo -e "${GREEN}║${NC}    --ros-args -r /cmd_vel:=/cmd_vel          # real dog      "
echo -e "${GREEN}║${NC}                                                              "
echo -e "${GREEN}║${NC}  Sim build log:  ~/go_sim/build.log                          "
echo -e "${GREEN}║${NC}  SDK build log:  ~/go2_sdk/build.log                         "
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"

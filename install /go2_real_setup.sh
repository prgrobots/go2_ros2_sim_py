#!/usr/bin/env bash
# =============================================================================
# go2_ros2_sim_py — Full WSL2 Setup Script
# Target : WSL2 + Ubuntu 22.04 (Jammy) + NVIDIA GPU (drivers on Windows host)
# Stack  : ROS2 Humble + Gazebo Garden + Nav2 + CycloneDDS
# Repo   : https://github.com/abutalipovvv/go2_ros2_sim_py
#
# Usage  : chmod +x install_humble.sh && ./install_humble.sh
#
# Notes  :
#   - Run as your normal user (NOT root). Sudo is called internally where needed.
#   - Your NVIDIA drivers live on the Windows host. Do NOT install NVIDIA drivers
#     inside WSL2 — they are exposed automatically via /usr/lib/wsl/lib.
#   - GUI (Gazebo/RViz) requires an X server on Windows:
#       Recommended: VcXsrv or WSLg (built-in on Windows 11 / Win10 21H2+).
#       If using WSLg you need nothing extra. If using VcXsrv, start it first
#       with "Disable access control" checked.
# =============================================================================

#set -eo pipefail
# Note: -u (unbound variable) intentionally omitted — ROS2 setup.bash uses
# unset variables internally (AMENT_TRACE_SETUP_FILES etc) and will crash with -u.

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ── Sanity checks ─────────────────────────────────────────────────────────────
[[ "$EUID" -eq 0 ]] && error "Do not run as root. Run as your regular user."

# Verify we are actually on Ubuntu 22.04
if ! grep -q 'jammy' /etc/os-release 2>/dev/null; then
    error "This script requires Ubuntu 22.04 (Jammy). \
You appear to be on a different distro/version. \
Install Ubuntu 22.04 via PowerShell: wsl --install -d Ubuntu-22.04"
fi

# Verify we are inside WSL2
if ! grep -qi 'microsoft' /proc/version 2>/dev/null; then
    warn "Could not confirm WSL2 environment — continuing anyway."
fi

info "=== Starting go2_ros2_sim_py full setup ==="
info "    Ubuntu 22.04 | ROS2 Humble | Gazebo Garden | WSL2 + NVIDIA"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# STEP 1 — System base update
# ─────────────────────────────────────────────────────────────────────────────
info "[1/9] Updating system packages..."
#locale  # check for UTF-8

sudo apt update && sudo apt install locales
sudo locale-gen en_US en_US.UTF-8
sudo update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
export LANG=en_US.UTF-8

locale  # verify settings


sudo apt install software-properties-common
sudo add-apt-repository universe

sudo apt update && sudo apt install curl -y
export ROS_APT_SOURCE_VERSION=$(curl -s https://api.github.com/repos/ros-infrastructure/ros-apt-source/releases/latest | grep -F "tag_name" | awk -F'"' '{print $4}')
curl -L -o /tmp/ros2-apt-source.deb "https://github.com/ros-infrastructure/ros-apt-source/releases/download/${ROS_APT_SOURCE_VERSION}/ros2-apt-source_${ROS_APT_SOURCE_VERSION}.$(. /etc/os-release && echo ${UBUNTU_CODENAME:-${VERSION_CODENAME}})_all.deb"
sudo dpkg -i /tmp/ros2-apt-source.deb

sudo apt update
sudo apt upgrade

sudo apt install ros-humble-desktop
sudo apt install ros-dev-tools

echo "source /opt/ros/humble/setup.bash" >> ~/.bashrc

mkdir -p ~/ros2_ws
cd ~/ros2_ws
git clone --recurse-submodules https://github.com/abizovnuralem/go2_ros2_sdk.git src
sudo apt install ros-$ROS_DISTRO-image-tools
sudo apt install ros-$ROS_DISTRO-vision-msgs

sudo apt install python3-pip clang portaudio19-dev
cd ~/ros2_ws/src
pip install -r requirements.txt
cd ~/ros2_ws

source /opt/ros/$ROS_DISTRO/setup.bash
rosdep install --from-paths src --ignore-src -r -y
colcon build


echo "source ~/ros2_ws/install/setup.bash" >> ~/.bashrc

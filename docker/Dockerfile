ARG BASE_IMG
FROM ${BASE_IMG}

# Кэширование apt-get
RUN  --mount=type=cache,target=/var/cache/apt,sharing=locked \
  --mount=type=cache,target=/var/lib/apt,sharing=locked \
  apt-get update && apt-get install -y \
  ros-humble-desktop \
  ros-dev-tools \
  ros-humble-rmw-cyclonedds-cpp \
  ros-humble-rclcpp \
  ros-humble-rclpy \
  ros-humble-urdf \
  ros-humble-xacro \
  ros-humble-std-msgs \
  ros-humble-angles \
  ros-humble-ros2-control \
  ros-humble-gz-ros2-control \
  ros-humble-controller-manager \
  ros-humble-hardware-interface \
  ros-humble-pluginlib \
  ros-humble-joint-state-publisher \
  ros-humble-robot-state-publisher \
  ros-humble-ros2launch \
  ros-humble-slam-toolbox \
  ros-humble-navigation2 \
  ros-humble-nav2-bringup \
  ros-humble-camera-info-manager \
  ros-humble-rqt-robot-steering \
  ros-humble-tf-transformations \
  ros-humble-teleop-twist-keyboard \
  ros-humble-ros2-controllers \
  ros-humble-ros-gz-image \
  ros-humble-ros-gz-bridge \
  ros-humble-opennav-docking \
  ros-humble-apriltag-ros \
  ros-humble-apriltag-msgs \
  ros-humble-image-proc \
  ros-humble-image-view \
  ros-humble-geometry-msgs \
  ros-humble-nav2-simple-commander \
  ros-humble-tf2-ros \
  ros-humble-tf2 \
  tmux \
  tmuxinator \
  python3-colcon-common-extensions \
  ccache \
  ros-humble-topic-tools \
  python3 python3-pip

# Установка colcon-cache
RUN pip3 install git+https://github.com/ruffsl/colcon-cache.git

# Копируем исходный код
COPY ../ /root/ws/src

WORKDIR /root/ws

SHELL ["/bin/bash", "-c"]

# Сборка пакетов
RUN --mount=type=cache,target=/root/.ccache \
  . /ros_entrypoint.sh && \
  colcon cache lock && \
  ccache colcon build --symlink-install \
  --mixin ccache

# Настройка entrypoint
RUN sed -i '/exec "\$@"/i umask 002' /ros_entrypoint.sh
ENV WORKSPACE_DIR=/root/ws
RUN sed -i '/exec "\$@"/i source "$WORKSPACE_DIR/install/setup.bash"' /ros_entrypoint.sh


FROM ubuntu:22.04 AS base

SHELL ["/bin/bash", "-c"]

ENV project=meeting-sdk-linux-sample
ENV cwd=/tmp/$project

WORKDIR $cwd

ARG DEBIAN_FRONTEND=noninteractive

#  Install Dependencies
# 1. Core build tools and system utilities
RUN apt-get update && apt-get install -y \
    build-essential \
    ca-certificates \
    cmake \
    curl \
    gdb \
    git \
    gfortran \
    pkgconf \
    tar \
    unzip \
    zip

# 2. Graphics and X11 libraries
RUN apt-get install -y \
    libdbus-1-3 \
    libgbm1 \
    libgl1-mesa-glx \
    libglib2.0-0 \
    libglib2.0-dev \
    libx11-dev \
    libx11-xcb1 \
    libxcb-image0 \
    libxcb-keysyms1 \
    libxcb-randr0 \
    libxcb-shape0 \
    libxcb-shm0 \
    libxcb-xfixes0 \
    libxcb-xtest0 \
    libgl1-mesa-dri \
    libxfixes3 \
    linux-libc-dev

# 3. Project-specific libraries
RUN apt-get install -y \
    libopencv-dev \
    libssl-dev

# 4. GCC-12 and alternatives
RUN apt-get install -y gcc-12 g++-12 && \
    update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-12 100 --slave /usr/bin/g++ g++ /usr/bin/g++-12
ENV CC=gcc
ENV CXX=g++

# Install ALSA
RUN apt-get install -y libasound2 libasound2-plugins alsa alsa-utils alsa-oss

# Install Pulseaudio
RUN apt-get install -y pulseaudio pulseaudio-utils

# --- Dummy audio/video support ---
# Install kernel modules and utilities for dummy audio and v4l2loopback video
RUN apt-get install -y kmod v4l2loopback-dkms v4l2loopback-utils

# Note: Loading kernel modules (snd-dummy, v4l2loopback) must be done on the HOST, not inside the container.
# See README/compose.yaml for runtime options.

FROM base AS deps

ENV TINI_VERSION v0.19.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /tini
RUN chmod +x /tini

WORKDIR /opt
RUN git clone --depth 1 https://github.com/Microsoft/vcpkg.git \
    && ./vcpkg/bootstrap-vcpkg.sh -disableMetrics \
    && ln -s /opt/vcpkg/vcpkg /usr/local/bin/vcpkg \
    && vcpkg install vcpkg-cmake

# Install dependencies for ada
RUN apt-get update && apt-get install -y git cmake

# Clone and build ada from source
RUN git clone --branch main https://github.com/ada-url/ada.git /opt/ada \
    && cd /opt/ada \
    && cmake -Bbuild -DCMAKE_BUILD_TYPE=Release \
    && cmake --build build --target install

# Clone and build CLI11 from source
RUN git clone --branch v2.4.2 https://github.com/CLIUtils/CLI11.git /opt/CLI11 \
    && cd /opt/CLI11 \
    && cmake -Bbuild -DCMAKE_BUILD_TYPE=Release \
    && cmake --build build --target install

# Install dependencies for npm
RUN apt-get update && apt-get install -y npm

# Install jwt-cpp (header-only)
RUN git clone --branch v0.6.0 https://github.com/Thalhammer/jwt-cpp.git /opt/jwt-cpp \
    && mkdir -p /usr/local/include/jwt-cpp \
    && cp -r /opt/jwt-cpp/include/jwt-cpp/* /usr/local/include/jwt-cpp/

FROM deps AS build

WORKDIR $cwd
ENTRYPOINT ["/tini", "--", "./bin/entry.sh"]



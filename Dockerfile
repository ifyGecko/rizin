# rizin docker
# ========
#
# Requires 1GB of free disk space
#
# Build docker image with:
# $ docker build -t rizin:latest .
# To enable rz-asm plugins based on binutils, pass '--build-arg with_ARCH_as=1' to the build command.
# Supported ARCHs are arm32, arm64, ppc. Each ARCH should be passed in a separate '--build-arg'.
#
# Run the docker image:
# $ docker images
# $ export DOCKER_IMAGE_ID=$(docker images --format '{{.ID}}' -f 'label=rizin')
# $ docker run -ti --cap-drop=ALL rizin:latest
#
# Once you quit the bash session get the container id with:
# $ docker ps -a | grep bash
#
# To get into that shell again just type:
# $ docker start -ai <containedid>
#
# To share those images:
# $ docker export <containerid> | xz > container.xz
# $ xz -d < container.xz | docker import -
#
#
# If you willing to debug a program within Docker, you should run it with CAP_SYS_PTRACE:
#
# $ docker run -it --cap-drop=ALL --cap-add=SYS_PTRACE rizin:latest
# $ rizin -d /bin/true
#

# Using debian 10 as base image.
FROM debian:10

# Label base
LABEL rizin latest

# Radare version
ARG RZ_VERSION=master
# rz-pipe python version
ARG RZ_PIPE_PY_VERSION=1.4.2

ARG with_arm32_as
ARG with_arm64_as
ARG with_ppc_as

ENV RZ_VERSION ${RZ_VERSION}
ENV RZ_PIPE_PY_VERSION ${RZ_PIPE_PY_VERSION}

RUN echo -e "Building versions:\n\
  RZ_VERSION=$RZ_VERSION\n\
  RZ_PIPE_PY_VERSION=${RZ_PIPE_PY_VERSION}"

# Build rizin in a volume to minimize space used by build
VOLUME ["/mnt"]

# Install all build dependencies
# Install bindings
# Build and install rizin on master branch
# Remove all build dependencies
# Cleanup
RUN DEBIAN_FRONTEND=noninteractive dpkg --add-architecture i386 && \
  apt-get update && \
  apt-get install -y \
  curl \
  wget \
  gcc \
  git \
  bison \
  pkg-config \
  make \
  glib-2.0 \
  libc6:i386 \
  libncurses5:i386 \
  libstdc++6:i386 \
  gnupg2 \
  python-pip \
  ${with_arm64_as:+binutils-aarch64-linux-gnu} \
  ${with_arm32_as:+binutils-arm-linux-gnueabi} \
  ${with_ppc_as:+binutils-powerpc64le-linux-gnu} && \
  pip install rzpipe=="$RZ_PIPE_PY_VERSION" && \
  cd /mnt && \
  git clone -b "$RZ_VERSION" -q --depth 1 https://github.com/rizinorg/rizin.git && \
  cd rizin && \
  ./configure && \
  make && \
  make install && \
  apt-get install -y xz-utils && \
  apt-get remove --purge -y \
  bison \
  python-pip \
  glib-2.0 && \
  apt-get autoremove --purge -y && \
  apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ENV RZ_ARM64_AS=${with_arm64_as:+aarch64-linux-gnu-as}
ENV RZ_ARM32_AS=${with_arm32_as:+arm-linux-gnueabi-as}
ENV RZ_PPC_AS=${with_ppc_as:+powerpc64le-linux-gnu-as}

# Create non-root user
RUN useradd -m rizin && \
  adduser rizin sudo && \
  echo "rizin:rizin" | chpasswd

# Initilise base user
USER rizin
WORKDIR /home/rizin
ENV HOME /home/rizin

# Setup rz-pm
RUN rz-pm init && \
  rz-pm update && \
  chown -R rizin:rizin /home/rizin/.config

# Base command for container
CMD ["/bin/bash"]

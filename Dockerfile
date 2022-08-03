FROM ubuntu:20.04

RUN if ! [ "$(arch)" = "aarch64" ] ; then exit 1; fi

RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

RUN apt update
RUN apt install -y \
  lsb-release \
  bc \
  build-essential \
  gfortran \
  git \
  python3 \
  python3-pip \
  openmpi-bin \
  libblas-dev

RUN pip install numpy scipy
RUN pip install mpi4py

RUN apt install -y sudo

# DOCKER_USER for the Docker user
ENV DOCKER_USER=ubuntu

# Setup default user
RUN useradd --create-home -s /bin/bash -m $DOCKER_USER && \
  echo "$DOCKER_USER:Portland" | chpasswd && adduser $DOCKER_USER sudo
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

USER ubuntu

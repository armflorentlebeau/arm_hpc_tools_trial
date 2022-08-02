FROM ubuntu:20.04

RUN if ! [ "$(arch)" = "aarch64" ] ; then exit 1; fi

RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

RUN apt update
RUN apt install -y \
  build-essential \
  gfortran \
  git \
  python3 \
  python3-pip \
  openmpi-bin \
  libblas-dev


# Install OpenMPI
#RUN wget https://download.open-mpi.org/release/open-mpi/v4.1/openmpi-4.1.4.tar.bz2
#RUN tar xf openmpi*.tar.bz2
#RUN pushd openmpi* && ./configure --prefix=/opt/openmpi/ && make -j $(nproc) && make install && popd
#RUN rm -rf openmpi*

# Install Arm PL
#RUN 

# Install Arm Forge
#RUN wget https://content.allinea.com/downloads/arm-forge-22.0.4-linux-aarch64.tar

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

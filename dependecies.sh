#!/usr/bin/env bash

COMPILE_PODMAN() {
  cd ~

  apt install build-essential curl wget cmake gcc g++ -y

  apt-get install -y \
    libapparmor-dev \
    btrfs-progs \
    git \
    iptables \
    libassuan-dev \
    libbtrfs-dev \
    libc6-dev \
    libdevmapper-dev \
    libglib2.0-dev \
    libgpgme-dev \
    libgpg-error-dev \
    libprotobuf-dev \
    libprotobuf-c-dev \
    libseccomp-dev \
    libselinux1-dev \
    libsystemd-dev \
    pkg-config \
    catatonit \
    uidmap

  apt-get install -y make git gcc build-essential pkgconf libtool \
   libsystemd-dev libprotobuf-c-dev libcap-dev libseccomp-dev libyajl-dev \
   go-md2man autoconf python3 automake

  cd ~ || exit 1
  git clone https://github.com/containers/crun.git
  cd crun || exit 1
  ./autogen.sh
  ./configure CFLAGS='-I/usr/include/libseccomp'
  make
  make install

  apt-get install netavark -y || apt-get install containernetworking-plugins -y

  cd ~ || exit 1
  #Addes go lang
  wget https://go.dev/dl/go1.26.1.linux-amd64.tar.gz
  tar -xzf go1.26.1.linux-amd64.tar.gz -C /usr/local
  rm go1.26.1.linux-amd64.tar.gz
  echo "export PATH=\$PATH:/usr/local/go/bin" >> $HOME/.profile
  export PATH=$PATH:/usr/local/go/bin

  cd ~

  git clone https://github.com/containers/conmon
  cd conmon
  export GOCACHE="$(mktemp -d)"
  make
  make podman


  mkdir -p /etc/containers

  cat <<EOF >/etc/containers/policy.json
{
  "default": [
    {
      "type": "insecureAcceptAnything"
    }
  ]
}
EOF

  cd ~

  git clone https://github.com/containers/podman/
  cd podman || exit 1
  git checkout v5.6
  make BUILDTAGS="selinux seccomp exclude_graphdriver_devicemapper systemd" PREFIX=/usr
  make install PREFIX=/usr

  cd ~

  apt install -y protobuf-compiler

  curl https://sh.rustup.rs -sSf | sh
  source $HOME/.cargo/env

  cd ~
  git clone https://github.com/containers/netavark.git
  cd netavark
  make
  cp bin/* /usr/local/libexec/podman/

  podman --version
}

COMPILE_PODMAN


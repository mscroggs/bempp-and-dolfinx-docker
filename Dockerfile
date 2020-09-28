# Dockerfile giving an environment in which Bempp-cl and dolfinx can be run
#
# Authors:
#   Matthew Scroggs <mws48@cam.ac.uk>
#   Timo Betcke <t.betcke@ucl.ac.uk>
#
# Based on the FEniCSx Docker file written by:
#   Jack S. Hale <jack.hale@uni.lu>
#   Lizao Li <lzlarryli@gmail.com>
#   Garth N. Wells <gnw20@cam.ac.uk>
#   Jan Blechta <blechta@karlin.mff.cuni.cz>
#

ARG GMSH_VERSION=4.6.0
ARG PYBIND11_VERSION=2.5.0
ARG PETSC_VERSION=3.13.2
ARG SLEPC_VERSION=3.13.2
ARG PETSC4PY_VERSION=3.13.0
ARG SLEPC4PY_VERSION=3.13.0
# Should be updated upon a new KaHIP release
ARG KAHIP_VERSION=14be06c

ARG PETSC_SLEPC_OPTFLAGS="-O2 -g"
ARG PETSC_SLEPC_DEBUGGING="yes"
ARG MAKEFLAGS

ARG BEMPP_VERSION=0.2.0
ARG EXAFMM_VERSION=0.1.0

########################################

FROM ubuntu:20.04 as dolfinx-and-bempp
LABEL maintainer="Matthew Scroggs <matt@mscroggs.co.uk>"
LABEL description="TODO"

ARG GMSH_VERSION
ARG PYBIND11_VERSION
ARG PETSC_VERSION
ARG SLEPC_VERSION
ARG PETSC4PY_VERSION
ARG SLEPC4PY_VERSION
# Should be updated upon a new KaHIP release
ARG KAHIP_VERSION

ARG PETSC_SLEPC_OPTFLAGS
ARG PETSC_SLEPC_DEBUGGING
ARG MAKEFLAGS

ARG EXAFMM_VERSION
ARG BEMPP_VERSION

WORKDIR /tmp

# Install dependencies available via apt-get.
# - First set of packages are required to build and run Bempp-cl.
# - Second set of packages are recommended and/or required to build
#   documentation or tests.
# - Third set of packages are optional, but required to run gmsh
#   pre-built binaries.
# - Fourth set of packages are optional, required for meshio.
RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get -qq update && \
    apt-get -yq --with-new-pkgs -o Dpkg::Options::="--force-confold" upgrade && \
    apt-get -y install \
    cmake \
    git \
    ipython3 \
    pkg-config \
    python-is-python3 \
    python3-dev \
    python3-matplotlib \
    python3-numpy \
    python3-pip \
    python3-pyopencl \
    python3-scipy \
    python3-setuptools \
    jupyter \
    wget && \
    apt-get -y install \
    gfortran \
    libboost-dev \
    libboost-filesystem-dev \
    libboost-iostreams-dev \
    libboost-math-dev \
    libboost-program-options-dev \
    libboost-system-dev \
    libboost-thread-dev \
    libboost-timer-dev \
    libeigen3-dev \
    libfltk-gl1.3 \
    libfltk-images1.3 \
    libfltk1.3 \
    libfreeimage3 \
    libgl2ps1.4 \
    libglu1-mesa \
    libhdf5-mpich-dev \
    libilmbase24 \
    libjxr0 \
    liblapack-dev \
    libmpich-dev \
    libocct-data-exchange-7.3 \
    libocct-foundation-7.3 \
    libocct-modeling-algorithms-7.3 \
    libocct-modeling-data-7.3 \ 
    libocct-ocaf-7.3 \
    libocct-visualization-7.3 \
    libopenblas-dev \
    libopenexr24 \
    libopenjp2-7 \
    libraw19 \
    libtbb2 \
    libxcursor1 \
    libxinerama1 \
    mpich \
    ninja-build \
    && \
    apt-get -y install \
    doxygen \
    git \
    graphviz \
    sudo \
    valgrind \
    && \
    apt-get -y install \
    libglu1 \
    libxcursor-dev \
    libxinerama1 && \
    apt-get -y install \
    python3-lxml && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install Python packages (via pip)
RUN pip3 install --no-cache-dir mpi4py numba meshio>=4.0.16 && \
    pip3 install --no-cache-dir cffi cppimport flake8 pytest pydocstyle && \
    export HDF5_MPI="ON" && \
    pip3 install --no-cache-dir --no-binary=h5py h5py meshio pygmsh

# Download Install Gmsh SDK
RUN cd /usr/local && \
    wget -nc --quiet http://gmsh.info/bin/Linux/gmsh-${GMSH_VERSION}-Linux64-sdk.tgz && \
    tar -xf gmsh-${GMSH_VERSION}-Linux64-sdk.tgz && \
    rm gmsh-${GMSH_VERSION}-Linux64-sdk.tgz

ENV PATH=/usr/local/gmsh-${GMSH_VERSION}-Linux64-sdk/bin:$PATH

# Add gmsh python API
ENV PYTHONPATH=/usr/local/gmsh-${GMSH_VERSION}-Linux64-sdk/lib:$PYTHONPATH

# Install pybind11
RUN wget -nc --quiet https://github.com/pybind/pybind11/archive/v${PYBIND11_VERSION}.tar.gz && \
    tar -xf v${PYBIND11_VERSION}.tar.gz && \
    cd pybind11-${PYBIND11_VERSION} && \
    mkdir build && \
    cd build && \
    cmake -DPYBIND11_TEST=False ../ && \
    make install && \
    rm -rf /tmp/*

# Install KaHIP
RUN cd /usr/local && \
    git clone https://github.com/schulzchristian/KaHIP.git && \
    cd KaHIP/ && \
    git checkout $KAHIP_VERSION && \
    ./compile_withcmake.sh

ENV KAHIP_ROOT=/usr/local/KaHIP

# Install PETSc with real and complex types
ENV PETSC_DIR=/usr/local/petsc SLEPC_DIR=/usr/local/slepc
WORKDIR /tmp
RUN apt-get -qq update && \
    apt-get -y install bison flex && \
    wget -nc --quiet http://ftp.mcs.anl.gov/pub/petsc/release-snapshots/petsc-lite-${PETSC_VERSION}.tar.gz -O petsc-${PETSC_VERSION}.tar.gz && \
    mkdir -p ${PETSC_DIR} && tar -xf petsc-${PETSC_VERSION}.tar.gz -C ${PETSC_DIR} --strip-components 1 && \
    cd ${PETSC_DIR} && \
    python3 ./configure \
    PETSC_ARCH=linux-gnu-real-32 \
    --COPTFLAGS=${PETSC_SLEPC_OPTFLAGS} \
    --CXXOPTFLAGS=${PETSC_SLEPC_OPTFLAGS} \
    --FOPTFLAGS=${PETSC_SLEPC_OPTFLAGS} \
    --with-debugging=${PETSC_SLEPC_DEBUGGING} \
    --with-fortran-bindings=no \
    --with-shared-libraries \
    --download-blacs \
    --download-hypre \
    --download-metis \
    --download-mumps \
    --download-ptscotch \
    --download-scalapack \
    --download-spai \
    --download-suitesparse \
    --download-superlu \
    --download-superlu_dist \
    --with-scalar-type=real && \
    make PETSC_DIR=/usr/local/petsc PETSC_ARCH=linux-gnu-real-32 ${MAKEFLAGS} all && \
    python3 ./configure \
    PETSC_ARCH=linux-gnu-complex-32 \
    --COPTFLAGS=${PETSC_SLEPC_OPTFLAGS} \
    --CXXOPTFLAGS=${PETSC_SLEPC_OPTFLAGS} \
    --FOPTFLAGS=${PETSC_SLEPC_OPTFLAGS} \
    --with-debugging=${PETSC_SLEPC_DEBUGGING} \
    --with-fortran-bindings=no \
    --with-shared-libraries \
    --download-blacs \
    --download-metis \
    --download-mumps \
    --download-ptscotch \
    --download-scalapack \
    --download-suitesparse \
    --download-superlu \
    --download-superlu_dist \
    --with-scalar-type=complex && \
    make PETSC_DIR=/usr/local/petsc PETSC_ARCH=linux-gnu-complex-32 ${MAKEFLAGS} all && \
    apt-get -y purge bison flex && \
    apt-get -y autoremove && \
    apt-get clean && \
    rm -rf \
    ${PETSC_DIR}/**/tests/ \
    ${PETSC_DIR}/**/obj/ \
    ${PETSC_DIR}/**/externalpackages/  \
    ${PETSC_DIR}/CTAGS \
    ${PETSC_DIR}/RDict.log \
    ${PETSC_DIR}/TAGS \
    ${PETSC_DIR}/docs/ \
    ${PETSC_DIR}/share/ \
    ${PETSC_DIR}/src/ \
    ${PETSC_DIR}/systems/ \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install SLEPc
WORKDIR /tmp
RUN wget -nc --quiet https://slepc.upv.es/download/distrib/slepc-${SLEPC_VERSION}.tar.gz -O slepc-${SLEPC_VERSION}.tar.gz && \
    mkdir -p ${SLEPC_DIR} && tar -xf slepc-${SLEPC_VERSION}.tar.gz -C ${SLEPC_DIR} --strip-components 1 && \
    cd ${SLEPC_DIR} && \
    export PETSC_ARCH=linux-gnu-real-32 && \
    python3 ./configure && \
    make && \
    export PETSC_ARCH=linux-gnu-complex-32 && \
    python3 ./configure && \
    make && \
    rm -rf ${SLEPC_DIR}/CTAGS ${SLEPC_DIR}/TAGS ${SLEPC_DIR}/docs ${SLEPC_DIR}/src/ ${SLEPC_DIR}/**/obj/ ${SLEPC_DIR}/**/test/ && \
    rm -rf /tmp/*

# Install petsc4py and slepc4py with real and complex types
RUN PETSC_ARCH=linux-gnu-real-32:linux-gnu-complex-32 pip3 install --no-cache-dir petsc4py==${PETSC4PY_VERSION} slepc4py==${SLEPC4PY_VERSION}

# Install FEniCSx componenets
RUN pip3 install --no-cache-dir ipython && \
    pip3 install --no-cache-dir git+https://github.com/FEniCS/fiat.git && \
    pip3 install --no-cache-dir git+https://github.com/FEniCS/ufl.git && \
    pip3 install --no-cache-dir git+https://github.com/FEniCS/ffcx.git

# Install FEniCS
RUN git clone --depth 1 https://github.com/fenics/dolfinx.git@chris/surface-facets && \
    cd dolfinx && \
    mkdir build && \
    cd build && \
    PETSC_ARCH=linux-gnu-real-32 cmake -G Ninja -DCMAKE_INSTALL_PREFIX=/usr/local/dolfinx-real ../cpp && \
    ninja ${MAKEFLAGS} install && \
    cd ../python && \
    PETSC_ARCH=linux-gnu-real-32 pip3 install --target /usr/local/dolfinx-real/lib/python3.8/dist-packages --no-dependencies --ignore-installed . && \
    cd ../ && \
    git clean -fdx && \
    mkdir build && \
    cd build && \
    PETSC_ARCH=linux-gnu-complex-32 cmake -G Ninja -DCMAKE_INSTALL_PREFIX=/usr/local/dolfinx-complex ../cpp && \
    ninja ${MAKEFLAGS} install && \
    . /usr/local/dolfinx-complex/share/dolfinx/dolfinx.conf && \
    cd ../python && \
    PETSC_ARCH=linux-gnu-complex-32 pip3 install --target /usr/local/dolfinx-complex/lib/python3.8/dist-packages --no-dependencies --ignore-installed .

# complex by default.
ENV LD_LIBRARY_PATH=/usr/local/dolfinx-complex/lib:$LD_LIBRARY_PATH \
        PATH=/usr/local/dolfinx-complex/bin:$PATH \
        PKG_CONFIG_PATH=/usr/local/dolfinx-complex/lib/pkgconfig:$PKG_CONFIG_PATH \
        PETSC_ARCH=linux-gnu-complex-32 \
        PYTHONPATH=/usr/local/dolfinx-complex/lib/python3.8/dist-packages:$PYTHONPATH

# Download and install ExaFMM
RUN apt update && apt install libfftw3-dev -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
RUN wget -nc --quiet https://github.com/exafmm/exafmm-t/archive/v${EXAFMM_VERSION}.tar.gz && \
    tar -xf v${EXAFMM_VERSION}.tar.gz && \
    cd exafmm-t-${EXAFMM_VERSION} && \
    sed -i 's/march=native/march=ivybridge/g' ./setup.py && python3 setup.py install

# Download and install Bempp
RUN wget -nc --quiet https://github.com/bempp/bempp-cl/archive/v${BEMPP_VERSION}.tar.gz && \
    tar -xf v${BEMPP_VERSION}.tar.gz && \
    cd bempp-cl-${BEMPP_VERSION} && \
    python3 setup.py install && \
    cp -r notebooks /root/example_notebooks

# Clear /tmp
RUN rm -rf /tmp/*

WORKDIR /root

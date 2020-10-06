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

ARG DOLFINX_MAKEFLAGS

ARG BEMPP_VERSION=0.2.2
ARG EXAFMM_VERSION=0.1.0

########################################

FROM dolfinx/dev-env as dolfinx-and-bempp
LABEL maintainer="Matthew Scroggs <matt@mscroggs.co.uk>"
LABEL description="TODO"

ARG DOLFINX_MAKEFLAGS
ARG BEMPP_VERSION
ARG EXAFMM_VERSION

RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get -qq update && \
    apt-get -yq --with-new-pkgs -o Dpkg::Options::="--force-confold" upgrade && \
    apt-get -y install \
    ipython3 \
    python3-pyopencl \
    pkg-config \
    python-is-python3 \
    jupyter \
#    libfltk-gl1.3 \
#    libfltk-images1.3 \
#    libfltk1.3 \
#    libfreeimage3 \
#    libgl2ps1.4 \
#    libglu1-mesa \
#    libilmbase24 \
#    libjxr0 \
#    libocct-data-exchange-7.3 \
#    libocct-foundation-7.3 \
#    libocct-modeling-algorithms-7.3 \
#    libocct-modeling-data-7.3 \ 
#    libocct-ocaf-7.3 \
#    libocct-visualization-7.3 \
#    libopenexr24 \
#    libopenjp2-7 \
#    libraw19 \
#    libtbb2 \
#    libxcursor1 \
#    libxinerama1 \
    && \
    apt-get -y install \
    python3-lxml && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install FEniCSx componenets
RUN pip3 install --no-cache-dir ipython && \
    pip3 install --no-cache-dir git+https://github.com/FEniCS/fiat.git && \
    pip3 install --no-cache-dir git+https://github.com/FEniCS/ufl.git && \
    pip3 install --no-cache-dir git+https://github.com/FEniCS/ffcx.git

# Install FEniCS
RUN git clone --depth 1 https://github.com/fenics/dolfinx.git && \
    cd dolfinx && \
    mkdir build && \
    cd build && \
    PETSC_ARCH=linux-gnu-real-32 cmake -G Ninja -DCMAKE_INSTALL_PREFIX=/usr/local/dolfinx-real ../cpp && \
    ninja ${DOLFINX_MAKEFLAGS} install && \
    cd ../python && \
    PETSC_ARCH=linux-gnu-real-32 pip3 install --target /usr/local/dolfinx-real/lib/python3.8/dist-packages --no-dependencies --ignore-installed . && \
    cd ../ && \
    git clean -fdx && \
    mkdir build && \
    cd build && \
    PETSC_ARCH=linux-gnu-complex-32 cmake -G Ninja -DCMAKE_INSTALL_PREFIX=/usr/local/dolfinx-complex ../cpp && \
    ninja ${DOLFINX_MAKEFLAGS} install && \
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

#/bin/bash

set -e

SRC_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
cd $SRC_PATH

if [ "$WORKSPACE" != "" ]; then
    INSTALL=$WORKSPACE/host-qemu-build
else
    INSTALL=$SRC_PATH/host-qemu-build
fi

# Internal variables
CLEAN=0

# Overridable number of build processors
if [ "$NUM_PROC" == "" ]; then
    NUM_PROCS=$(nproc --all)
fi

# Argument parsing
while [[ $# -gt 0 ]]; do
    arg="$1"
    case $arg in
        -c|--clean)
            CLEAN=1
            shift
        ;;
        *)
            echo "usage: $0 [-c|--clean]"
            exit 1
        ;;
    esac
done

function build_3rdparty_autogen {
    echo "Building: $1"
    cd $SRC_PATH
    cd 3rdparty/$1
    if [ -f ./autogen.sh ]; then
        ./autogen.sh
    fi
    PKG_CONF_SYSTEM=/usr/lib/$MULTIARCH/pkgconfig
    PKG_CONF_INSTALL=$INSTALL/lib/pkgconfig:$INSTALL/lib/$MULTIARCH/pkgconfig
    PKG_CONFIG_PATH=$PKG_CONFIG_PATH:$PKG_CONF_SYSTEM:$PKG_CONF_INSTALL
    env PKG_CONFIG_PATH=$PKG_CONFIG_PATH LDFLAGS="-L$INSTALL/lib" \
    ./configure --prefix=$INSTALL $2
    make -j$NUM_PROCS
    make install
}

function build_cmake {
    if [ "$CLEAN" == "1" ]; then
        if [ -d build ]; then
            rm -rf build
        fi
    fi
    if [ ! -d build ]; then
        mkdir build
    fi
    cd build
    PKG_CONF_SYSTEM=/usr/lib/$MULTIARCH/pkgconfig
    PKG_CONF_INSTALL=$INSTALL/lib/pkgconfig:$INSTALL/lib/$MULTIARCH/pkgconfig
    PKG_CONFIG_PATH=$PKG_CONFIG_PATH:$PKG_CONF_SYSTEM:$PKG_CONF_INSTALL
    env PKG_CONFIG_PATH=$PKG_CONFIG_PATH LDFLAGS="-L$INSTALL/lib" \
    cmake .. \
        -DCMAKE_INSTALL_PREFIX=$INSTALL \
        -DCMAKE_MODULE_PATH=$INSTALL \
        -DCMAKE_CXX_FLAGS="-isystem $INSTALL/include -L$INSTALL/lib -Wno-deprecated-declarations -Wl,-rpath-link,$INSTALL/lib" \
        -DCMAKE_C_FLAGS="-isystem $INSTALL/include -L$INSTALL/lib -Wno-deprecated-declarations -Wl,-rpath-link,$INSTALL/lib" \
        -DCMAKE_LD_FLAGS="-L$INSTALL/lib" \
        -DCMAKE_LIBRARY_PATH=$INSTALL/lib $@
    make VERBOSE=1 -j$NUM_PROCS
    make install
}

function build_3rdparty_cmake {
    echo "Building: $1"
    cd $SRC_PATH
    cd 3rdparty/$1
    build_cmake $2
}

# Build direct dependencies
build_3rdparty_autogen qemu "--target-list=aarch64-softmmu,x86_64-softmmu"

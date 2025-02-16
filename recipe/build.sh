#!/bin/bash
# *****************************************************************
# (C) Copyright IBM Corp. 2019, 2022. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# *****************************************************************

set +x
SHORT_OS_STR=$(uname -s)

QT="5"
V4L="1"
OPENMP="-DWITH_OPENMP=1"
# Looks like there's a bug in Opencv 3.2.0 for building with FFMPEG
# with GCC opencv/issues/8097
export CXXFLAGS="$CXXFLAGS -D__STDC_CONSTANT_MACROS"

export CPPFLAGS="${CPPFLAGS//-std=c++17/-std=c++11}"
export CXXFLAGS="${CXXFLAGS//-std=c++17/-std=c++11}"

export LDFLAGS="${LDFLAGS} -Wl,-rpath-link,${PREFIX}/lib"

if [[ $ppc_arch == "p10" ]]
then
    if [[ -z "${GCC_11_HOME}" ]];
    then
        echo "Please set GCC_11_HOME to the install path of gcc-toolset-11"
        exit 1
    else
        AR=${GCC_11_HOME}/bin/ar
        LD=${GCC_11_HOME}/bin/ld
        NM=${GCC_11_HOME}/bin/nm
        OBJCOPY=${GCC_11_HOME}/bin/objcopy
        OBJDUMP=${GCC_11_HOME}/bin/objdump
        RANLIB=${GCC_11_HOME}/bin/ranlib
        STRIP=${GCC_11_HOME}/bin/strip
    fi
fi

CMAKE_TOOLCHAIN_CMD_FLAGS=""
CMAKE_TOOLCHAIN_CMD_FLAGS="${CMAKE_TOOLCHAIN_CMD_FLAGS} -DCMAKE_AR=${AR}"
CMAKE_TOOLCHAIN_CMD_FLAGS="${CMAKE_TOOLCHAIN_CMD_FLAGS} -DCMAKE_LINKER=${LD}"
CMAKE_TOOLCHAIN_CMD_FLAGS="${CMAKE_TOOLCHAIN_CMD_FLAGS} -DCMAKE_NM=${NM}"
CMAKE_TOOLCHAIN_CMD_FLAGS="${CMAKE_TOOLCHAIN_CMD_FLAGS} -DCMAKE_OBJCOPY=${OBJCOPY}"
CMAKE_TOOLCHAIN_CMD_FLAGS="${CMAKE_TOOLCHAIN_CMD_FLAGS} -DCMAKE_OBJDUMP=${OBJDUMP}"
CMAKE_TOOLCHAIN_CMD_FLAGS="${CMAKE_TOOLCHAIN_CMD_FLAGS} -DCMAKE_RANLIB=${RANLIB}"
CMAKE_TOOLCHAIN_CMD_FLAGS="${CMAKE_TOOLCHAIN_CMD_FLAGS} -DCMAKE_STRIP=${STRIP}"

mkdir -p build
cd build

PY_MAJOR=3
PY_UNSET_MAJOR=2
# Python 3.8 now combines the "m" and the "no m" builds in 1.
if [ ${PY_VER} == "3.6" ] || [ ${PY_VER} == "3.7" ]; then
    LIB_PYTHON="${PREFIX}/lib/libpython${PY_VER}${SHLIB_EXT}m"
    INC_PYTHON="$PREFIX/include/python${PY_VER}m"
else
    LIB_PYTHON="${PREFIX}/lib/libpython${PY_VER}${SHLIB_EXT}"
    INC_PYTHON="$PREFIX/include/python${PY_VER}"
fi

PYTHON_SET_FLAG="-DBUILD_opencv_python${PY_MAJOR}=1"
PYTHON_SET_EXE="-DPYTHON${PY_MAJOR}_EXECUTABLE=${PYTHON}"
PYTHON_SET_INC="-DPYTHON${PY_MAJOR}_INCLUDE_DIR=${INC_PYTHON} "
PYTHON_SET_NUMPY="-DPYTHON${PY_MAJOR}_NUMPY_INCLUDE_DIRS=${SP_DIR}/numpy/core/include"
PYTHON_SET_LIB="-DPYTHON${PY_MAJOR}_LIBRARY=${LIB_PYTHON}"
PYTHON_SET_SP="-DPYTHON${PY_MAJOR}_PACKAGES_PATH=${SP_DIR}"
PYTHON_SET_INSTALL="-DOPENCV_PYTHON${PY_MAJOR}_INSTALL_PATH=${SP_DIR}"

PYTHON_UNSET_FLAG="-DBUILD_opencv_python${PY_UNSET_MAJOR}=0"
PYTHON_UNSET_EXE="-DPYTHON${PY_UNSET_MAJOR}_EXECUTABLE="
PYTHON_UNSET_INC="-DPYTHON${PY_UNSET_MAJOR}_INCLUDE_DIR="
PYTHON_UNSET_NUMPY="-DPYTHON${PY_UNSET_MAJOR}_NUMPY_INCLUDE_DIRS="
PYTHON_UNSET_LIB="-DPYTHON${PY_UNSET_MAJOR}_LIBRARY="
PYTHON_UNSET_SP="-DPYTHON${PY_UNSET_MAJOR}_PACKAGES_PATH="
PYTHON_UNSET_INSTALL="-DOPENCV_PYTHON${PY_UNSET_MAJOR}_INSTALL_PATH=${SP_DIR}"

# FFMPEG building requires pkgconfig
export PKG_CONFIG_PATH=$PKG_CONFIG_PATH:$PREFIX/lib/pkgconfig
export OpenBLAS_HOME=${PREFIX}

cmake -LAH -G "Ninja"                                                     \
    -DCMAKE_BUILD_TYPE="Release"                                          \
    -DCMAKE_PREFIX_PATH=${PREFIX}                                         \
    -DCMAKE_INSTALL_PREFIX=${PREFIX}                                      \
    -DCMAKE_INSTALL_LIBDIR="lib"                                          \
    -DOPENCV_DOWNLOAD_TRIES=1\;2\;3\;4\;5                                 \
    -DOPENCV_DOWNLOAD_PARAMS=INACTIVITY_TIMEOUT\;30\;TIMEOUT\;180\;SHOW_PROGRESS \
    $CMAKE_TOOLCHAIN_CMD_FLAGS                                            \
    -DOPENCV_GENERATE_PKGCONFIG=ON                                        \
    -DENABLE_CONFIG_VERIFICATION=ON                                       \
    -DENABLE_PRECOMPILED_HEADERS=OFF                                      \
    $CPU_DISPATCH_FLAGS                                                   \
    $OPENMP                                                               \
    -DWITH_LAPACK=0                                                       \
    -DHAVE_LAPACK=0                                                       \
    -DLAPACK_LAPACKE_H=lapacke.h                                          \
    -DLAPACK_CBLAS_H=cblas.h                                              \
    -DWITH_EIGEN=1                                                        \
    -DBUILD_TESTS=0                                                       \
    -DBUILD_DOCS=0                                                        \
    -DBUILD_PERF_TESTS=0                                                  \
    -DBUILD_ZLIB=0                                                        \
    -DBUILD_TIFF=0                                                        \
    -DBUILD_PNG=0                                                         \
    -DBUILD_OPENEXR=1                                                     \
    -DBUILD_JASPER=0                                                      \
    -DBUILD_JPEG=0                                                        \
    -DBUILD_LIBPROTOBUF_FROM_SOURCES=0                                    \
    -DBUILD_PROTOBUF=0                                                    \
    -DWITH_V4L=$V4L                                                       \
    -DWITH_CUDA=0                                                         \
    -DWITH_CUBLAS=0                                                       \
    -DWITH_OPENCL=0                                                       \
    -DWITH_OPENCLAMDFFT=0                                                 \
    -DWITH_OPENCLAMDBLAS=0                                                \
    -DWITH_OPENCL_D3D11_NV=0                                              \
    -DWITH_1394=0                                                         \
    -DWITH_CARBON=0                                                       \
    -DWITH_OPENNI=0                                                       \
    -DWITH_FFMPEG=1                                                       \
    -DHAVE_FFMPEG=0                                                       \
    -DWITH_JASPER=0                                                      \
    -DWITH_VA=0                                                           \
    -DWITH_VA_INTEL=0                                                     \
    -DWITH_GSTREAMER=0                                                    \
    -DWITH_MATLAB=0                                                       \
    -DWITH_TESSERACT=0                                                    \
    -DWITH_VTK=0                                                          \
    -DWITH_GTK=0                                                          \
    -DWITH_QT=0                                                         \
    -DWITH_GPHOTO2=0                                                      \
    -DINSTALL_C_EXAMPLES=0                                                \
    -DOPENCV_EXTRA_MODULES_PATH="../opencv_contrib/modules"               \
    -DCMAKE_SKIP_RPATH:bool=ON                                            \
    -DBUILD_opencv_sfm:bool=OFF                                           \
    -DPYTHON_PACKAGES_PATH=${SP_DIR}                                      \
    -DPYTHON_EXECUTABLE=${PYTHON}                                         \
    -DPYTHON_INCLUDE_DIR=${INC_PYTHON}                                    \
    -DPYTHON_LIBRARY=${LIB_PYTHON}                                        \
    -DOPENCV_SKIP_PYTHON_LOADER=1                                         \
    -DZLIB_INCLUDE_DIR=${PREFIX}/include                                  \
    -DZLIB_LIBRARY_RELEASE=${PREFIX}/lib/libz${SHLIB_EXT}                 \
    -DPNG_INCLUDE_DIR=${PREFIX}/include                                   \
    -DPROTOBUF_INCLUDE_DIR=${PREFIX}/include                              \
    -DPROTOBUF_LIBRARIES=${PREFIX}/lib                                    \
    -DPROTOBUF_UPDATE_FILES=ON                                            \
    $PYTHON_SET_FLAG                                                      \
    $PYTHON_SET_EXE                                                       \
    $PYTHON_SET_INC                                                       \
    $PYTHON_SET_NUMPY                                                     \
    $PYTHON_SET_LIB                                                       \
    $PYTHON_SET_SP                                                        \
    $PYTHON_SET_INSTALL                                                   \
    $PYTHON_UNSET_FLAG                                                    \
    $PYTHON_UNSET_EXE                                                     \
    $PYTHON_UNSET_INC                                                     \
    $PYTHON_UNSET_NUMPY                                                   \
    $PYTHON_UNSET_LIB                                                     \
    $PYTHON_UNSET_SP                                                      \
    $PYTHON_UNSET_INSTALL                                                 \
    ..

ninja install -v

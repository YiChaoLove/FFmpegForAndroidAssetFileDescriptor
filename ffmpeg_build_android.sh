#!/bin/bash

function buildFFmpeg() {
    echo "BuildFFmpeg  ==> configure, ABI:${ABI}, API:${API}"
    ./configure \
        --prefix=${PREFIX} \
        --arch=${ARCH} \
        --sysroot=${SYSROOT} \
        --cc=${CC} \
        --cxx=${CXX} \
        --cross-prefix=$CROSS_PREFIX \
        --target-os=android \
        --enable-cross-compile \
        --extra-cflags="-O3 -fPIC -mfloat-abi=softfp -mfpu=neon" \
        --enable-shared \
        --disable-static \
        --disable-runtime-cpudetect \
        --disable-programs \
        --disable-ffmpeg \
        --disable-ffplay \
        --disable-ffprobe \
        --disable-avdevice \
        --disable-postproc \
        --disable-doc \
        --disable-debug \
        --disable-network \
        --disable-bsfs \
        --disable-filters \
        --disable-encoders \
        --disable-decoders \
        --enable-decoder=h264 \
        --disable-muxers \
        --enable-muxer=mov \
        --disable-demuxers \
        --enable-demuxer=mov \
        --disable-protocols \
        --enable-protocol=file \
        --enable-protocol=pipe \
        --disable-parsers \
        --enable-parser=h264 \
        --enable-pic \
        --enable-gpl

    read -n 1 -p "BuildFFmpeg  ==> you need check configure, go on? [y|n]" input
    if [ "$input" == "y" ] ; then
        rm -rf ${PREFIX}
        make clean
        make -j12
        make install
        echo "BuildFFmpeg  ==> finish, ABI:${ABI}, API:${API}"
    else
        echo "BuildFFmpeg  ==> stoped!"
    fi
}


API=21
HOST_TAG=darwin-x86_64
NDK=/Users/yichao/Documents/lib/android-ndk-r21b
TOOLCHAIN_PATH=$NDK/toolchains/llvm/prebuilt/${HOST_TAG}
SYSROOT=${TOOLCHAIN_PATH}/sysroot

#armv7
ABI=armeabi-v7a
ARCH=arm
PREFIX=$(pwd)/android/${ABI}
CROSS_PREFIX=${TOOLCHAIN_PATH}/bin/arm-linux-androideabi-
CC=${TOOLCHAIN_PATH}/bin/armv7a-linux-androideabi${API}-clang
CXX=${CC}++
buildFFmpeg

#arm64
ABI=arm64-v8a
ARCH=arm64
PREFIX=$(pwd)/android/${ABI}
CROSS_PREFIX=${TOOLCHAIN_PATH}/bin/aarch64-linux-android-
CC=${TOOLCHAIN_PATH}/bin/aarch64-linux-android${API}-clang
CXX=${CC}++
buildFFmpeg




#!/usr/bin/env bash

while [ -h "$SOURCE"  ]; do
    DIR="$( cd -P "$( dirname "$SOURCE"  )" && pwd  )"
    SOURCE="$(readlink "$SOURCE")"
          # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
    [[ $SOURCE != /*  ]] && SOURCE="$DIR/$SOURCE"
done
DIR="$( cd -P "$( dirname "$SOURCE"  )" && pwd  )"

if [ $# -gt 1 ] ; then
    sysroot=$1
    export PATH=${sysroot}/usr/bin:$PATH
    export CFLAGS="--sysroot ${sysroot}"
fi

export CXXFLAGS="${CFLAGS}"
export LDFLAGS="${CFLAGS}"
export CC=clang

if [ ! -d xz ] ; then
    echo " -- [error] not such dir [xz]" 
    exit 1
fi

cd xz

platform=$(uname -m)
os=$(uname -s| awk '{print tolower($0)}')

./autogen.sh
./configure --disable-xz --disable-xzdec --disable-lzmadec --disable-lzma-links --disable-scripts --disable-doc --enable-static --enable-encoders=lzma1,lzma2,x86,arm,armthumb

mkdir -p ${DIR}/config/xz/${platform}/${os}

cp ./config.h ${DIR}/config/xz/${platform}/${os}/config.h

cd ${DIR}
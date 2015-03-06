#!/bin/sh

###########################################################################
#
#  Automatic build script for mimetic 
#  for iPhoneOS and iPhoneSimulator
#  Created by Ruslan Salikhov
#  Based on https://github.com/x2on/OpenSSL-for-iPhone
#
###########################################################################
#
#  Change values here
#

VERSION="0.9.8"
SDKVERSION=`xcrun -sdk iphoneos --show-sdk-version`

#
###########################################################################
#
# Don't change anything under this line!
#
###########################################################################

BASEDIR=$(dirname $0)
pushd $BASEDIR
BASEDIR=`pwd`

ARCHS="i386 x86_64 armv7 armv7s arm64"
DEVELOPER=`xcode-select -print-path`

if [ ! -d "$DEVELOPER" ]; then
  echo "xcode path is not set correctly $DEVELOPER does not exist (most likely because of xcode > 4.3)"
  echo "run"
  echo "sudo xcode-select -switch <xcode path>"
  echo "for default installation:"
  echo "sudo xcode-select -switch /Applications/Xcode.app/Contents/Developer"
  exit 1
fi

case $DEVELOPER in  
  *\ * )
    echo "Your Xcode path contains whitespaces, which is not supported."
    exit 1
    ;;
esac

case $BASEDIR in  
  *\ * )
    echo "Your path contains whitespaces, which is not supported by 'make install'."
    exit 1
    ;;
esac

set -e
if [ ! -e mimetic-${VERSION}.tar.gz ]; then
  echo "Downloading mimetic-${VERSION}.tar.gz"
  curl -O http://www.codesink.org/download/mimetic-${VERSION}.tar.gz
else
  echo "Using mimetic-${VERSION}.tar.gz"
fi

mkdir -p "${BASEDIR}/src"
mkdir -p "${BASEDIR}/bin"
mkdir -p "${BASEDIR}/lib"

tar zxf mimetic-${VERSION}.tar.gz -C "${BASEDIR}/src"
cd "${BASEDIR}/src/mimetic-${VERSION}"

for ARCH in ${ARCHS}
do
  if [[ "${ARCH}" == "i386" || "${ARCH}" == "x86_64" ]];
  then
    PLATFORM="iPhoneSimulator"
  else
    PLATFORM="iPhoneOS"
  fi
	
  export CROSS_TOP="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
  export CROSS_SDK="${PLATFORM}${SDKVERSION}.sdk"
  export BUILD_TOOLS="${DEVELOPER}"

  echo "Building mimetic-${VERSION} for ${PLATFORM} ${SDKVERSION} ${ARCH}"
  echo "Please stand by..."

  export CC="${BUILD_TOOLS}/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang"
  export CXX="${BUILD_TOOLS}/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang++"
  export CFLAGS="-arch ${ARCH} -isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} -miphoneos-version-min=7.0"
  export CXXFLAGS="-arch ${ARCH} -isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} -miphoneos-version-min=7.0"
  export AR="${BUILD_TOOLS}/Toolchains/XcodeDefault.xctoolchain/usr/bin/ar"
  export RANLIB="${BUILD_TOOLS}/Toolchains/XcodeDefault.xctoolchain/usr/bin/ranlib -s"

  mkdir -p "${BASEDIR}/bin/${PLATFORM}${SDKVERSION}-${ARCH}.sdk"
  LOG="${BASEDIR}/bin/${PLATFORM}${SDKVERSION}-${ARCH}.sdk/build-mimetic-${VERSION}.log"

  # Remove building test folder (because fails in c++11)
  sed -ie 's@^SUBDIRS = \(.*\) test \(.*\)@SUBDIRS = \1 \2@' Makefile.in

  set +e
  ./configure -host=i386 -prefix="${BASEDIR}/bin/${PLATFORM}${SDKVERSION}-${ARCH}.sdk" > "${LOG}" 2>&1
    
  if [ $? != 0 ];
  then 
    echo "Problem while configure - Please check ${LOG}"
    exit 1
  fi

  if [ "$1" == "verbose" ];
  then
    make 
  else
    make >> "${LOG}" 2>&1
  fi
	
  if [ $? != 0 ];
  then 
    echo "Problem while make - Please check ${LOG}"
    exit 1
  fi
    
  set -e
  make install >> "${LOG}" 2>&1
  make clean >> "${LOG}" 2>&1
done

echo "Build library..."
lipo -create ${BASEDIR}/bin/iPhoneSimulator${SDKVERSION}-i386.sdk/lib/libmimetic.a ${BASEDIR}/bin/iPhoneSimulator${SDKVERSION}-x86_64.sdk/lib/libmimetic.a  ${BASEDIR}/bin/iPhoneOS${SDKVERSION}-armv7.sdk/lib/libmimetic.a ${BASEDIR}/bin/iPhoneOS${SDKVERSION}-armv7s.sdk/lib/libmimetic.a ${BASEDIR}/bin/iPhoneOS${SDKVERSION}-arm64.sdk/lib/libmimetic.a -output ${BASEDIR}/lib/libmimetic.a

mkdir -p ${BASEDIR}/include
cp -R ${BASEDIR}/bin/iPhoneSimulator${SDKVERSION}-i386.sdk/include/mimetic ${BASEDIR}/include/

echo "Building done."

echo "Cleaning up..."
rm -rf ${BASEDIR}/src/mimetic-${VERSION}

echo "Done."

popd

#!/bin/bash

# ./autogen.sh

CURL_PREFIX=/usr/local
SSL_PREFIX=/usr/local/ssl

# gcc 4.4
extracflags="-Wall -Wno-pointer-to-int-cast -Wno-strict-aliasing -D_REENTRANT -DPTW32_STATIC_LIB -fmerge-all-constants"

# gcc 4.8+
extracflags="$extracflags -Ofast -fuse-linker-plugin -ftree-loop-if-convert-stores" # -flto "

# msys2
if [ ! -f "/mingw64/include/ncursesw/curses.h" ]; then
  INC_CURSES=/mingw64/include/ncursesw
  extracflags="$extracflags -I$INC_CURSES"
fi

# extracflags="-pg -static -fno-inline-small-functions"
CFLAGS="-DCURL_STATICLIB -DOPENSSL_NO_ASM -DUSE_ASM -I$CURL_PREFIX/include $extracflags"
# CPPFLAGS=""

PKG_CONFIG_PATH=$PKG_CONFIG_PATH:/usr/local/lib/pkgconfig \
./configure --build=x86_64-w64-mingw32 --enable-opencl --enable-adl --with-crypto=$SSL_PREFIX --with-libcurl=$CURL_PREFIX --enable-curses \
	--enable-static=winpthreads CFLAGS="$CFLAGS" CPPFLAGS="$CPPFLAGS" LDFLAGS="-L/usr/local/lib -lOpenCL"

if [ ! -f "submodules/jansson/src/.libs/libjansson.a" ]; then
  dir=`pwd`
  cd submodules/jansson && ./configure --enable-static && make
  cd $dir
fi

make


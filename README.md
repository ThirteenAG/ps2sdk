ps2dev
=======

A mirror of https://github.com/ps2dev/ps2dev/releases/tag/latest for buildbot use.

This is just files directly from [ps2dev-windows-latest.tar.gz](https://github.com/ps2dev/ps2dev/releases/download/latest/ps2dev-windows-latest.tar.gz).

Compiled with these changes for better plugin compatibility:

002-gcc-stage1.sh

```
  CFLAGS_FOR_TARGET="$TARGET_CFLAGS" \
  ../configure \
    --quiet \
    --prefix="$PS2DEV/$TARGET_ALIAS" \
    --target="$TARGET" \
    --enable-languages="c" \
    --with-float=hard \
    --without-headers \
    --without-newlib \
    --disable-libgcc \
    --disable-shared \
    --disable-threads \
    --disable-multilib \
    --disable-libatomic \
    --disable-nls \
    --disable-tls \
    --disable-libssp \
    --disable-libgomp \
    --disable-libmudflap \
    --disable-libquadmath \
    --enable-libstdcxx-static-eh-pool \
    $TARG_XTRA_OPTS
```

003-newlib.sh

```
  CFLAGS_FOR_TARGET="$TARGET_CFLAGS" \
  ../configure \
    --prefix="$PS2DEV/$TARGET_ALIAS" \
    --target="$TARGET" \
    --with-sysroot="$PS2DEV/$TARGET_ALIAS/$TARGET" \
    --enable-newlib-retargetable-locking \
    --disable-newlib-multithread \
    --enable-newlib-io-c99-formats \
    $TARG_XTRA_OPTS
```

004-newlib-nano.sh

```
  CFLAGS_FOR_TARGET="$TARGET_CFLAGS" \
  ../configure \
    --prefix="$PS2DEV_TMP/$TARGET_ALIAS" \
    --target="$TARGET" \
    --with-sysroot="$PS2DEV/$TARGET_ALIAS/$TARGET" \
    --disable-newlib-supplied-syscalls \
    --enable-newlib-reent-small \
    --disable-newlib-fvwrite-in-streamio \
    --disable-newlib-fseek-optimization \
    --disable-newlib-wide-orient \
    --enable-newlib-nano-malloc \
    --disable-newlib-unbuf-stream-opt \
    --enable-newlib-nano-formatted-io \
    --enable-newlib-retargetable-locking \
    --disable-newlib-multithread \
    --disable-nls \
    $TARG_XTRA_OPTS
```

005-pthread-embedded.sh

```
removed
```

006-gcc-stage2.sh

```
  CFLAGS_FOR_TARGET="$TARGET_CFLAGS" \
  CXXFLAGS_FOR_TARGET="$TARGET_CFLAGS" \
  ../configure \
    --quiet \
    --prefix="$PS2DEV/$TARGET_ALIAS" \
    --target="$TARGET" \
    --enable-languages="c,c++" \
    --with-float=hard \
    --with-sysroot="$PS2DEV/$TARGET_ALIAS/$TARGET" \
    --with-native-system-header-dir="/include" \
    --with-newlib \
    --disable-libssp \
    --disable-multilib \
    --disable-nls \
    --disable-tls \
    --enable-cxx-flags=-G0 \
    --enable-libstdcxx-static-eh-pool \
    --disable-libstdcxx-threads \
    --disable-bootstrap \
    --with-system-zlib \
    --disable-threads \
    $TARG_XTRA_OPTS
```
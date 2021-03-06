# This file is part of MXE.
# See index.html for further information.

PKG             := gcc
$(PKG)_WEBSITE  := http://gcc.gnu.org/
$(PKG)_DESCR    := GCC
$(PKG)_IGNORE   := 6%
$(PKG)_VERSION  := 5.4.0
$(PKG)_CHECKSUM := 608df76dec2d34de6558249d8af4cbee21eceddbcb580d666f7a5a583ca3303a
$(PKG)_SUBDIR   := gcc-$($(PKG)_VERSION)
$(PKG)_FILE     := gcc-$($(PKG)_VERSION).tar.bz2
$(PKG)_URL      := http://ftp.gnu.org/pub/gnu/gcc/gcc-$($(PKG)_VERSION)/$($(PKG)_FILE)
$(PKG)_URL_2    := ftp://ftp.mirrorservice.org/sites/sourceware.org/pub/gcc/releases/gcc-$($(PKG)_VERSION)/$($(PKG)_FILE)
$(PKG)_DEPS     := binutils mingw-w64

$(PKG)_FILE_$(BUILD) :=

define $(PKG)_UPDATE
    $(WGET) -q -O- 'http://ftp.gnu.org/gnu/gcc/?C=M;O=D' | \
    $(SED) -n 's,.*<a href="gcc-\([0-9][^"]*\)/".*,\1,p' | \
    $(SORT) -V | \
    tail -1
endef

define $(PKG)_CONFIGURE
    # configure gcc
    mkdir '$(1).build'
    cd    '$(1).build' && '$(1)/configure' \
        --target='$(TARGET)' \
        --build='$(BUILD)' \
        --prefix='$(PREFIX)' \
        --libdir='$(PREFIX)/lib' \
        --enable-languages='c,c++,objc,fortran' \
        --enable-version-specific-runtime-libs \
        --with-gcc \
        --with-gnu-ld \
        --with-gnu-as \
        --disable-nls \
        $(if $(BUILD_STATIC),--disable-shared) \
        --disable-multilib \
        --without-x \
        --disable-win32-registry \
        --enable-threads=$(MXE_GCC_THREADS) \
        --disable-libgomp \
        --with-gmp='$(PREFIX)/$(BUILD)' \
        --with-isl='$(PREFIX)/$(BUILD)' \
        --with-mpc='$(PREFIX)/$(BUILD)' \
        --with-mpfr='$(PREFIX)/$(BUILD)' \
        --with-cloog='$(PREFIX)/$(BUILD)' \
        --with-as='$(PREFIX)/bin/$(TARGET)-as' \
        --with-ld='$(PREFIX)/bin/$(TARGET)-ld' \
        --with-nm='$(PREFIX)/bin/$(TARGET)-nm' \
        $(shell [ `uname -s` == Darwin ] && echo "LDFLAGS='-Wl,-no_pie'")
endef

define $(PKG)_POST_BUILD
    # - no non-trivial way to configure installation of *.dlls
    #   each sudbir has it's own variations of variables like:
    #       `toolexeclibdir` `install-toolexeclibLTLIBRARIES` etc.
    #   and maintaining those would be cumbersome
    # - need to keep `--enable-version-specific-runtime-libs` otherwise
    #   libraries go directly into $(PREFIX)/$(TARGET)/lib and are
    #   harder to cleanup
    # - ignore rm failure as parallel build may have cleaned up, but
    #   don't wildcard all libs so future additions will be detected
    $(and $(BUILD_SHARED),
    mv  -v '$(PREFIX)/lib/gcc/$(TARGET)/$($(PKG)_VERSION)/'*.dll '$(PREFIX)/$(TARGET)/bin/'
    -rm -v '$(PREFIX)/lib/gcc/$(TARGET)/'libgcc_s*.dll
    -rm -v '$(PREFIX)/lib/gcc/$(TARGET)/lib/'libgcc_s*.a
    -rmdir '$(PREFIX)/lib/gcc/$(TARGET)/lib/')
endef

define $(PKG)_BUILD_mingw-w64
    # build standalone gcc
    $($(PKG)_CONFIGURE)
    $(MAKE) -C '$(1).build' -j '$(JOBS)' all-gcc
    $(MAKE) -C '$(1).build' -j 1 install-gcc

    # build mingw-w64-crt
    cd '$(1)' && $(call UNPACK_PKG_ARCHIVE,mingw-w64)
    mkdir '$(1).crt-build'
    cd '$(1).crt-build' && '$(1)/$(mingw-w64_SUBDIR)/mingw-w64-crt/configure' \
        --host='$(TARGET)' \
        --prefix='$(PREFIX)/$(TARGET)' \
        @gcc-crt-config-opts@
    $(MAKE) -C '$(1).crt-build' -j '$(JOBS)' || $(MAKE) -C '$(1).crt-build' -j '$(JOBS)'
    $(MAKE) -C '$(1).crt-build' -j 1 install

    # build rest of gcc
    cd '$(1).build'
    $(MAKE) -C '$(1).build' -j '$(JOBS)'
    $(MAKE) -C '$(1).build' -j 1 install

    # shared libgcc isn't installed to version-specific locations
    # so install correctly to simplify cleanup
    $(and $(BUILD_SHARED),
    $(MAKE) -C '$(1).build/$(TARGET)/libgcc' -j 1 \
        toolexecdir='$(PREFIX)/$(TARGET)/bin' \
        SHLIB_SLIBDIR_QUAL= \
        install-shared)

    $($(PKG)_POST_BUILD)
endef

$(PKG)_BUILD_x86_64-w64-mingw32 = $(subst @gcc-crt-config-opts@,--disable-lib32,$($(PKG)_BUILD_mingw-w64))
$(PKG)_BUILD_i686-w64-mingw32   = $(subst @gcc-crt-config-opts@,--disable-lib64,$($(PKG)_BUILD_mingw-w64))

define $(PKG)_BUILD_$(BUILD)
    for f in c++ cpp g++ gcc gcov; do \
        ln -sf "`which $$f`" '$(PREFIX)/bin/$(TARGET)'-$$f ; \
    done
endef

DEBUG ?= 0
LUAJIT_52_COMPAT ?= 1

CFLAGS += -std=c11 "-I$(CURDIR)/lib/godot-headers" "-I$(CURDIR)/lib/high-level-gdnative" "-I$(CURDIR)/lib/luajit/src"
ifeq ($(DEBUG), 1)
	CFLAGS += -g -O0 -DDEBUG
else
	CFLAGS += -O3 -DNDEBUG
endif

ifeq ($(LUAJIT_52_COMPAT), 1)
	MAKE_LUAJIT_ARGS += XCFLAGS=-DLUAJIT_ENABLE_LUA52COMPAT
endif

_CC = $(CROSS)$(CC)
LIPO ?= lipo
_LIPO = $(CROSS)$(LIPO)

SRC = hgdn.c language_gdnative.c language_in_editor_callbacks.c
OBJS = $(SRC:.c=.o) init_script.o
BUILT_OBJS = $(addprefix build/%/,$(OBJS))
MAKE_LUAJIT_OUTPUT = build/%/luajit/src/luajit build/%/luajit/src/lua51.dll build/%/luajit/src/libluajit.a

GDNLIB_ENTRY_PREFIX = addons/godot-lua-pluginscript
BUILD_FOLDERS = build build/windows_x86 build/windows_x86_64 build/linux_x86 build/linux_x86_64 build/osx_x86_64 build/osx_arm64 build/osx_universal64 build/$(GDNLIB_ENTRY_PREFIX)

DIST_SRC = LICENSE
DIST_ADDONS_SRC = LICENSE lps_coroutine.lua lua_pluginscript.gdnlib $(wildcard build/*/lua*.*) $(wildcard plugin/*)
DIST_ZIP_SRC = $(DIST_SRC) $(addprefix $(GDNLIB_ENTRY_PREFIX)/,$(DIST_ADDONS_SRC))
DIST_DEST = $(addprefix build/,$(DIST_SRC)) $(addprefix build/$(GDNLIB_ENTRY_PREFIX)/,$(DIST_ADDONS_SRC))

# Note that the order is important!
LUA_INIT_SCRIPT_SRC = \
	src/godot_ffi.lua \
	src/cache_lua_libs.lua \
	src/lua_globals.lua \
	src/lua_string_extras.lua \
	src/godot_enums.lua \
	src/godot_class.lua \
	src/godot_variant.lua \
	src/godot_string.lua \
	src/godot_string_name.lua \
	src/godot_vector2.lua \
	src/godot_vector3.lua \
	src/godot_color.lua \
	src/godot_rect2.lua \
	src/godot_plane.lua \
	src/godot_quat.lua \
	src/godot_basis.lua \
	src/godot_aabb.lua \
	src/godot_transform2d.lua \
	src/godot_transform.lua \
	src/godot_object.lua \
	src/godot_rid.lua \
	src/godot_node_path.lua \
	src/godot_dictionary.lua \
	src/godot_array.lua \
	src/godot_pool_byte_array.lua \
	src/godot_pool_int_array.lua \
	src/godot_pool_real_array.lua \
	src/godot_pool_string_array.lua \
	src/godot_pool_vector2_array.lua \
	src/godot_pool_vector3_array.lua \
	src/godot_pool_color_array.lua \
	src/pluginscript_class_metadata.lua \
	src/pluginscript_callbacks.lua \
	src/late_globals.lua \
	src/lua_package_extras.lua \
	src/lua_math_extras.lua \
	src/in_editor_callbacks.lua

ifneq (1,$(DEBUG))
	EMBED_SCRIPT_SED := src/tools/compact_lua_script.sed
endif
EMBED_SCRIPT_SED += src/tools/embed_to_c.sed
INIT_SCRIPT_SED = src/tools/add_script_c_decl.sed

# Avoid removing intermediate files created by chained implicit rules
.PRECIOUS: build/%/luajit build/%/init_script.c $(BUILT_OBJS) build/%/lua51.dll $(MAKE_LUAJIT_OUTPUT)

$(BUILD_FOLDERS):
	mkdir -p $@

build/%/hgdn.o: src/hgdn.c
	$(_CC) -o $@ $< -c $(CFLAGS)
build/%/language_gdnative.o: src/language_gdnative.c
	$(_CC) -o $@ $< -c $(CFLAGS)
build/%/language_in_editor_callbacks.o: src/language_in_editor_callbacks.c
	$(_CC) -o $@ $< -c $(CFLAGS)

build/%/luajit: | build/%
	cp -r lib/luajit $@
$(MAKE_LUAJIT_OUTPUT): | build/%/luajit
	$(MAKE) -C $| $(and $(TARGET_SYS),TARGET_SYS=$(TARGET_SYS)) $(MAKE_LUAJIT_ARGS)
build/%/lua51.dll: build/%/luajit/src/lua51.dll
	cp $< $@

build/init_script.lua: $(LUA_INIT_SCRIPT_SRC) | build
	cat $^ > $@
build/%/init_script.c: build/init_script.lua $(EMBED_SCRIPT_SED) $(INIT_SCRIPT_SED) | build/%
	sed $(addprefix -f ,$(EMBED_SCRIPT_SED)) $< | sed -f $(INIT_SCRIPT_SED) > $@

build/%/init_script.o: build/%/init_script.c
	$(_CC) -o $@ $< -c $(CFLAGS)

build/%/lua_pluginscript.so: TARGET_SYS = Linux
build/%/lua_pluginscript.so: $(BUILT_OBJS) build/%/luajit/src/libluajit.a
	$(_CC) -o $@ $^ -shared $(CFLAGS) -lm -ldl $(LDFLAGS)

build/%/lua_pluginscript.dll: TARGET_SYS = Windows
build/%/lua_pluginscript.dll: EXE = .exe
build/%/lua_pluginscript.dll: $(BUILT_OBJS) build/%/lua51.dll
	$(_CC) -o $@ $^ -shared $(CFLAGS) $(LDFLAGS)

build/%/lua_pluginscript.dylib: TARGET_SYS = Darwin
build/%/lua_pluginscript.dylib: $(BUILT_OBJS) build/%/luajit/src/libluajit.a
	$(_CC) -o $@ $^ -shared $(CFLAGS) $(LDFLAGS)
build/osx_x86_64/lua_pluginscript.dylib: CFLAGS += -arch x86_64
build/osx_x86_64/lua_pluginscript.dylib: MAKE_LUAJIT_ARGS += TARGET_FLAGS="-arch x86_64"
build/osx_arm64/lua_pluginscript.dylib: CFLAGS += -arch arm64
build/osx_arm64/lua_pluginscript.dylib: MAKE_LUAJIT_ARGS += TARGET_FLAGS="-arch arm64"
build/osx_universal64/lua_pluginscript.dylib: build/osx_x86_64/lua_pluginscript.dylib build/osx_arm64/lua_pluginscript.dylib | build/osx_universal64
	$(_LIPO) $^ -create -output $@

build/$(GDNLIB_ENTRY_PREFIX)/%:
	@mkdir -p $(dir $@)
	cp $* $@
$(addprefix build/,$(DIST_SRC)): | build
	cp $(notdir $@) $@
build/lua_pluginscript.zip: $(DIST_DEST)
	cd build && zip lua_pluginscript $(DIST_ZIP_SRC)

# Phony targets
.PHONY: clean dist docs
clean:
	$(RM) -r build/*/

dist: build/lua_pluginscript.zip

docs:
	ldoc .

# Targets by OS + arch
linux32: MAKE_LUAJIT_ARGS += CC="$(CC) -m32 -fPIC"
linux32: CFLAGS += -m32 -fPIC
linux32: build/linux_x86/lua_pluginscript.so

linux64: MAKE_LUAJIT_ARGS += CC="$(CC) -fPIC"
linux64: CFLAGS += -fPIC
linux64: build/linux_x86_64/lua_pluginscript.so

windows32: build/windows_x86/lua_pluginscript.dll
cross-windows32: CROSS = i686-w64-mingw32-
cross-windows32: MAKE_LUAJIT_ARGS += HOST_CC="$(CC) -m32" CROSS="i686-w64-mingw32-" LDFLAGS=-static-libgcc
cross-windows32: windows32

windows64: build/windows_x86_64/lua_pluginscript.dll
cross-windows64: CROSS = x86_64-w64-mingw32-
cross-windows64: MAKE_LUAJIT_ARGS += HOST_CC="$(CC)" CROSS="x86_64-w64-mingw32-" LDFLAGS=-static-libgcc
cross-windows64: windows64

osx-x86_64: build/osx_x86_64/lua_pluginscript.dylib
osx-arm64: build/osx_arm64/lua_pluginscript.dylib
osx64: build/osx_universal64/lua_pluginscript.dylib

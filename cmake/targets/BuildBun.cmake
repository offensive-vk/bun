include(Macros)

if(DEBUG)
  set(bun bun-debug)
elseif(ENABLE_SMOL)
  set(bun bun-smol-profile)
  set(bunStrip bun-smol)
elseif(ENABLE_VALGRIND)
  set(bun bun-valgrind)
elseif(ENABLE_ASSERTIONS)
  set(bun bun-assertions)
else()
  set(bun bun-profile)
  set(bunStrip bun)
endif()

set(bunExe ${bun}${CMAKE_EXECUTABLE_SUFFIX})

if(bunStrip)
  set(bunStripExe ${bunStrip}${CMAKE_EXECUTABLE_SUFFIX})
  set(buns ${bun} ${bunStrip})
else()
  set(buns ${bun})
endif()

# Some commands use this path, and some do not.
# In the future, change those commands so that generated files are written to this path.
optionx(CODEGEN_PATH FILEPATH "Path to the codegen directory" DEFAULT ${BUILD_PATH}/codegen)

if(NOT CONFIGURE_DEPENDS)
  set(CONFIGURE_DEPENDS "")
else()
  set(CONFIGURE_DEPENDS "CONFIGURE_DEPENDS")
endif()

# --- Codegen ---

set(BUN_ZIG_IDENTIFIER_SOURCE ${CWD}/src/js_lexer)
set(BUN_ZIG_IDENTIFIER_SCRIPT ${BUN_ZIG_IDENTIFIER_SOURCE}/identifier_data.zig)

file(GLOB BUN_ZIG_IDENTIFIER_SOURCES ${CONFIGURE_DEPENDS}
  ${BUN_ZIG_IDENTIFIER_SCRIPT}
  ${BUN_ZIG_IDENTIFIER_SOURCE}/*.zig
)

set(BUN_ZIG_IDENTIFIER_OUTPUTS
  ${BUN_ZIG_IDENTIFIER_SOURCE}/id_continue_bitset.blob
  ${BUN_ZIG_IDENTIFIER_SOURCE}/id_continue_bitset.meta.blob
  ${BUN_ZIG_IDENTIFIER_SOURCE}/id_start_bitset.blob
  ${BUN_ZIG_IDENTIFIER_SOURCE}/id_start_bitset.meta.blob
)

register_command(
  TARGET
    bun-identifier-data
  COMMENT
    "Generating src/js_lexer/*.blob"
  COMMAND
    ${CMAKE_ZIG_COMPILER}
      run
      ${CMAKE_ZIG_FLAGS}
      ${BUN_ZIG_IDENTIFIER_SCRIPT}
  SOURCES
    ${BUN_ZIG_IDENTIFIER_SOURCES}
  OUTPUTS
    ${BUN_ZIG_IDENTIFIER_OUTPUTS}
  TARGETS
    clone-zig
)

set(BUN_ERROR_SOURCE ${CWD}/packages/bun-error)

file(GLOB BUN_ERROR_SOURCES ${CONFIGURE_DEPENDS}
  ${BUN_ERROR_SOURCE}/*.json
  ${BUN_ERROR_SOURCE}/*.ts
  ${BUN_ERROR_SOURCE}/*.tsx
  ${BUN_ERROR_SOURCE}/*.css
  ${BUN_ERROR_SOURCE}/img/*
)

set(BUN_ERROR_OUTPUT ${BUN_ERROR_SOURCE}/dist)
set(BUN_ERROR_OUTPUTS
  ${BUN_ERROR_OUTPUT}/index.js
  ${BUN_ERROR_OUTPUT}/bun-error.css
)

register_bun_install(
  CWD
    ${BUN_ERROR_SOURCE}
  NODE_MODULES_VARIABLE
    BUN_ERROR_NODE_MODULES
)

register_command(
  TARGET
    bun-error
  COMMENT
    "Building bun-error"
  CWD
    ${BUN_ERROR_SOURCE}
  COMMAND
    ${ESBUILD_EXECUTABLE} ${ESBUILD_ARGS}
      index.tsx
      bun-error.css
      --outdir=${BUN_ERROR_OUTPUT}
      --define:process.env.NODE_ENV=\"'production'\"
      --minify
      --bundle
      --platform=browser
      --format=esm
  SOURCES
    ${BUN_ERROR_SOURCES}
    ${BUN_ERROR_NODE_MODULES}
  OUTPUTS
    ${BUN_ERROR_OUTPUTS}
)

set(BUN_FALLBACK_DECODER_SOURCE ${CWD}/src/fallback.ts)
set(BUN_FALLBACK_DECODER_OUTPUT ${CWD}/src/fallback.out.js)

register_command(
  TARGET
    bun-fallback-decoder
  COMMENT
    "Building src/fallback.out.js"
  COMMAND
    ${ESBUILD_EXECUTABLE} ${ESBUILD_ARGS}
      ${BUN_FALLBACK_DECODER_SOURCE}
      --outfile=${BUN_FALLBACK_DECODER_OUTPUT}
      --target=esnext
      --bundle
      --format=iife
      --platform=browser
      --minify
  SOURCES
    ${BUN_FALLBACK_DECODER_SOURCE}
  OUTPUTS
    ${BUN_FALLBACK_DECODER_OUTPUT}
)

set(BUN_RUNTIME_JS_SOURCE ${CWD}/src/runtime.bun.js)
set(BUN_RUNTIME_JS_OUTPUT ${CWD}/src/runtime.out.js)

register_command(
  TARGET
    bun-runtime-js
  COMMENT
    "Building src/runtime.out.js"
  COMMAND
    ${ESBUILD_EXECUTABLE} ${ESBUILD_ARGS}
      ${BUN_RUNTIME_JS_SOURCE}
      --outfile=${BUN_RUNTIME_JS_OUTPUT}
      --define:process.env.NODE_ENV=\"'production'\"
      --target=esnext
      --bundle
      --format=esm
      --platform=node
      --minify
      --external:/bun:*
  SOURCES
    ${BUN_RUNTIME_JS_SOURCE}
  OUTPUTS
    ${BUN_RUNTIME_JS_OUTPUT}
)

set(BUN_NODE_FALLBACKS_SOURCE ${CWD}/src/node-fallbacks)

file(GLOB BUN_NODE_FALLBACKS_SOURCES ${CONFIGURE_DEPENDS}
  ${BUN_NODE_FALLBACKS_SOURCE}/*.js
)

set(BUN_NODE_FALLBACKS_OUTPUT ${BUN_NODE_FALLBACKS_SOURCE}/out)
set(BUN_NODE_FALLBACKS_OUTPUTS)
foreach(source ${BUN_NODE_FALLBACKS_SOURCES})
  get_filename_component(filename ${source} NAME)
  list(APPEND BUN_NODE_FALLBACKS_OUTPUTS ${BUN_NODE_FALLBACKS_OUTPUT}/${filename})
endforeach()

register_bun_install(
  CWD
    ${BUN_NODE_FALLBACKS_SOURCE}
  NODE_MODULES_VARIABLE
    BUN_NODE_FALLBACKS_NODE_MODULES
)

# This command relies on an older version of `esbuild`, which is why
# it uses ${BUN_EXECUTABLE} x instead of ${ESBUILD_EXECUTABLE}.
register_command(
  TARGET
    bun-node-fallbacks
  COMMENT
    "Building src/node-fallbacks/*.js"
  CWD
    ${BUN_NODE_FALLBACKS_SOURCE}
  COMMAND
    ${BUN_EXECUTABLE} x
      esbuild ${ESBUILD_ARGS}
      ${BUN_NODE_FALLBACKS_SOURCES}
      --outdir=${BUN_NODE_FALLBACKS_OUTPUT}
      --format=esm
      --minify
      --bundle
      --platform=browser
  SOURCES
    ${BUN_NODE_FALLBACKS_SOURCES}
    ${BUN_NODE_FALLBACKS_NODE_MODULES}
  OUTPUTS
    ${BUN_NODE_FALLBACKS_OUTPUTS}
)

set(BUN_ERROR_CODE_SCRIPT ${CWD}/src/codegen/generate-node-errors.ts)

set(BUN_ERROR_CODE_SOURCES
  ${BUN_ERROR_CODE_SCRIPT}
  ${CWD}/src/bun.js/bindings/ErrorCode.ts
  ${CWD}/src/bun.js/bindings/ErrorCode.cpp
  ${CWD}/src/bun.js/bindings/ErrorCode.h
)

set(BUN_ERROR_CODE_OUTPUTS
  ${CODEGEN_PATH}/ErrorCode+List.h
  ${CODEGEN_PATH}/ErrorCode+Data.h
  ${CODEGEN_PATH}/ErrorCode.zig
)

register_command(
  TARGET
    bun-error-code
  COMMENT
    "Generating ErrorCode.{zig,h}"
  COMMAND
    ${BUN_EXECUTABLE}
      run
      ${BUN_ERROR_CODE_SCRIPT}
      ${CODEGEN_PATH}
  SOURCES
    ${BUN_ERROR_CODE_SOURCES}
  OUTPUTS
    ${BUN_ERROR_CODE_OUTPUTS}
)

set(BUN_ZIG_GENERATED_CLASSES_SCRIPT ${CWD}/src/codegen/generate-classes.ts)

file(GLOB BUN_ZIG_GENERATED_CLASSES_SOURCES ${CONFIGURE_DEPENDS}
  ${CWD}/src/bun.js/*.classes.ts
  ${CWD}/src/bun.js/api/*.classes.ts
  ${CWD}/src/bun.js/node/*.classes.ts
  ${CWD}/src/bun.js/test/*.classes.ts
  ${CWD}/src/bun.js/webcore/*.classes.ts
)

set(BUN_ZIG_GENERATED_CLASSES_OUTPUTS
  ${CODEGEN_PATH}/ZigGeneratedClasses.h
  ${CODEGEN_PATH}/ZigGeneratedClasses.cpp
  ${CODEGEN_PATH}/ZigGeneratedClasses+lazyStructureHeader.h
  ${CODEGEN_PATH}/ZigGeneratedClasses+DOMClientIsoSubspaces.h
  ${CODEGEN_PATH}/ZigGeneratedClasses+DOMIsoSubspaces.h
  ${CODEGEN_PATH}/ZigGeneratedClasses+lazyStructureImpl.h
  ${CODEGEN_PATH}/ZigGeneratedClasses.zig
)

register_command(
  TARGET
    bun-zig-generated-classes
  COMMENT
    "Generating ZigGeneratedClasses.{zig,cpp,h}"
  COMMAND
    ${BUN_EXECUTABLE}
      run
      ${BUN_ZIG_GENERATED_CLASSES_SCRIPT}
      ${BUN_ZIG_GENERATED_CLASSES_SOURCES}
      ${CODEGEN_PATH}
  SOURCES
    ${BUN_ZIG_GENERATED_CLASSES_SCRIPT}
    ${BUN_ZIG_GENERATED_CLASSES_SOURCES}
  OUTPUTS
    ${BUN_ZIG_GENERATED_CLASSES_OUTPUTS}
)

set(BUN_JAVASCRIPT_CODEGEN_SCRIPT ${CWD}/src/codegen/bundle-modules.ts)

file(GLOB_RECURSE BUN_JAVASCRIPT_SOURCES ${CONFIGURE_DEPENDS}
  ${CWD}/src/js/*.js
  ${CWD}/src/js/*.ts
)

file(GLOB BUN_JAVASCRIPT_CODEGEN_SOURCES ${CONFIGURE_DEPENDS}
  ${CWD}/src/codegen/*.ts
)

list(APPEND BUN_JAVASCRIPT_CODEGEN_SOURCES
  ${CWD}/src/bun.js/bindings/InternalModuleRegistry.cpp
)

set(BUN_JAVASCRIPT_OUTPUTS
  ${CODEGEN_PATH}/WebCoreJSBuiltins.cpp
  ${CODEGEN_PATH}/WebCoreJSBuiltins.h
  ${CODEGEN_PATH}/InternalModuleRegistryConstants.h
  ${CODEGEN_PATH}/InternalModuleRegistry+createInternalModuleById.h
  ${CODEGEN_PATH}/InternalModuleRegistry+enum.h
  ${CODEGEN_PATH}/InternalModuleRegistry+numberOfModules.h
  ${CODEGEN_PATH}/NativeModuleImpl.h
  ${CODEGEN_PATH}/ResolvedSourceTag.zig
  ${CODEGEN_PATH}/SyntheticModuleType.h
  ${CODEGEN_PATH}/GeneratedJS2Native.h
  # Zig will complain if files are outside of the source directory
  ${CWD}/src/bun.js/bindings/GeneratedJS2Native.zig
)

register_command(
  TARGET
    bun-js-modules
  COMMENT
    "Generating JavaScript modules"
  COMMAND
    ${BUN_EXECUTABLE}
      run
      ${BUN_JAVASCRIPT_CODEGEN_SCRIPT}
        --debug=${DEBUG}
        ${BUILD_PATH}
  SOURCES
    ${BUN_JAVASCRIPT_SOURCES}
    ${BUN_JAVASCRIPT_CODEGEN_SOURCES}
    ${BUN_JAVASCRIPT_CODEGEN_SCRIPT}
  OUTPUTS
    ${BUN_JAVASCRIPT_OUTPUTS}
)

set(BUN_JS_SINK_SCRIPT ${CWD}/src/codegen/generate-jssink.ts)

set(BUN_JS_SINK_SOURCES
  ${BUN_JS_SINK_SCRIPT}
  ${CWD}/src/codegen/create-hash-table.ts
)

set(BUN_JS_SINK_OUTPUTS
  ${CODEGEN_PATH}/JSSink.cpp
  ${CODEGEN_PATH}/JSSink.h
  ${CODEGEN_PATH}/JSSink.lut.h
)

register_command(
  TARGET
    bun-js-sink
  COMMENT
    "Generating JSSink.{cpp,h}"
  COMMAND
    ${BUN_EXECUTABLE}
      run
      ${BUN_JS_SINK_SCRIPT}
      ${CODEGEN_PATH}
  SOURCES
    ${BUN_JS_SINK_SOURCES}
  OUTPUTS
    ${BUN_JS_SINK_OUTPUTS}
)

set(BUN_OBJECT_LUT_SCRIPT ${CWD}/src/codegen/create-hash-table.ts)

set(BUN_OBJECT_LUT_SOURCES
  ${CWD}/src/bun.js/bindings/BunObject.cpp
  ${CWD}/src/bun.js/bindings/ZigGlobalObject.lut.txt
  ${CWD}/src/bun.js/bindings/JSBuffer.cpp
  ${CWD}/src/bun.js/bindings/BunProcess.cpp
  ${CWD}/src/bun.js/bindings/ProcessBindingConstants.cpp
  ${CWD}/src/bun.js/bindings/ProcessBindingNatives.cpp
)

set(BUN_OBJECT_LUT_OUTPUTS
  ${CODEGEN_PATH}/BunObject.lut.h
  ${CODEGEN_PATH}/ZigGlobalObject.lut.h
  ${CODEGEN_PATH}/JSBuffer.lut.h
  ${CODEGEN_PATH}/BunProcess.lut.h
  ${CODEGEN_PATH}/ProcessBindingConstants.lut.h
  ${CODEGEN_PATH}/ProcessBindingNatives.lut.h
)

macro(WEBKIT_ADD_SOURCE_DEPENDENCIES _source _deps)
  set(_tmp)
  get_source_file_property(_tmp ${_source} OBJECT_DEPENDS)

  if(NOT _tmp)
    set(_tmp "")
  endif()

  foreach(f ${_deps})
    list(APPEND _tmp "${f}")
  endforeach()

  set_source_files_properties(${_source} PROPERTIES OBJECT_DEPENDS "${_tmp}")
  unset(_tmp)
endmacro()

list(LENGTH BUN_OBJECT_LUT_SOURCES BUN_OBJECT_LUT_SOURCES_COUNT)
math(EXPR BUN_OBJECT_LUT_SOURCES_MAX_INDEX "${BUN_OBJECT_LUT_SOURCES_COUNT} - 1")

foreach(i RANGE 0 ${BUN_OBJECT_LUT_SOURCES_MAX_INDEX})
  list(GET BUN_OBJECT_LUT_SOURCES ${i} BUN_OBJECT_LUT_SOURCE)
  list(GET BUN_OBJECT_LUT_OUTPUTS ${i} BUN_OBJECT_LUT_OUTPUT)

  get_filename_component(filename ${BUN_OBJECT_LUT_SOURCE} NAME_WE)
  register_command(
    TARGET
      bun-codegen-lut-${filename}
    COMMENT
      "Generating ${filename}.lut.h"
    COMMAND
      ${BUN_EXECUTABLE}
        run
        ${BUN_OBJECT_LUT_SCRIPT}
        ${BUN_OBJECT_LUT_SOURCE}
        ${BUN_OBJECT_LUT_OUTPUT}
    SOURCES
      ${BUN_OBJECT_LUT_SCRIPT}
      ${BUN_OBJECT_LUT_SOURCE}
    OUTPUTS
      ${BUN_OBJECT_LUT_OUTPUT}
  )

  WEBKIT_ADD_SOURCE_DEPENDENCIES(${BUN_OBJECT_LUT_SOURCE} ${BUN_OBJECT_LUT_OUTPUT})
endforeach()

WEBKIT_ADD_SOURCE_DEPENDENCIES(
  ${CWD}/src/bun.js/bindings/ErrorCode.cpp
  ${CODEGEN_PATH}/ErrorCode+List.h
)

WEBKIT_ADD_SOURCE_DEPENDENCIES(
  ${CWD}/src/bun.js/bindings/ErrorCode.h
  ${CODEGEN_PATH}/ErrorCode+Data.h
)

WEBKIT_ADD_SOURCE_DEPENDENCIES(
  ${CWD}/src/bun.js/bindings/ZigGlobalObject.cpp
  ${CODEGEN_PATH}/ZigGlobalObject.lut.h
)

WEBKIT_ADD_SOURCE_DEPENDENCIES(
  ${CWD}/src/bun.js/bindings/InternalModuleRegistry.cpp
  ${CODEGEN_PATH}/InternalModuleRegistryConstants.h
)

# --- Zig ---

# Does not use GLOB_RECURSE because it makes configure really slow with WebKit
# We might want to consider moving our dependencies out of src/ because of this.
file(GLOB BUN_ZIG_SOURCES ${CONFIGURE_DEPENDS}
  ${CWD}/*.zig
  ${CWD}/src/*/*.zig
  ${CWD}/src/*/*/*.zig
  ${CWD}/src/*/*/*/*.zig
  ${CWD}/src/*/*/*/*/*.zig
)

list(APPEND BUN_ZIG_SOURCES
  ${BUN_ZIG_IDENTIFIER_OUTPUTS}
  ${BUN_ERROR_OUTPUTS}
  ${BUN_FALLBACK_DECODER_OUTPUT}
  ${BUN_RUNTIME_JS_OUTPUT}
  ${BUN_NODE_FALLBACKS_OUTPUTS}
  ${BUN_ERROR_CODE_OUTPUTS}
  ${BUN_ZIG_GENERATED_CLASSES_OUTPUTS}
  ${BUN_JAVASCRIPT_OUTPUTS}
)

set(BUN_ZIG_OUTPUT ${BUILD_PATH}/bun-zig.o)

register_command(
  TARGET
    bun-zig
  COMMENT
    "Building src/*.zig for ${ZIG_TARGET}"
  COMMAND
    ${CMAKE_ZIG_COMPILER}
      build obj
      ${CMAKE_ZIG_FLAGS}
      --prefix ${BUILD_PATH}
      -Dobj_format=${ZIG_OBJECT_FORMAT}
      -Dtarget=${ZIG_TARGET}
      -Doptimize=${ZIG_OPTIMIZE}
      -Dcpu=${CPU}
      -Denable_logs=$<IF:$<BOOL:${ENABLE_LOGS}>,true,false>
      -Dversion=${VERSION}
      -Dsha=${REVISION}
      -Dreported_nodejs_version=${NODEJS_VERSION}
      -Dcanary=${CANARY_REVISION}
      -Dgenerated-code=${CODEGEN_PATH}
  ARTIFACTS
    ${BUN_ZIG_OUTPUT}
  SOURCES
    ${BUN_ZIG_SOURCES}
  TARGETS
    clone-zig
)

set_property(TARGET bun-zig PROPERTY JOB_POOL compile_pool)
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "build.zig")

# --- C/C++ Sources ---

set(BUN_DEPS_SOURCE ${CWD}/src/deps)
set(BUN_USOCKETS_SOURCE ${CWD}/packages/bun-usockets)

file(GLOB BUN_CXX_SOURCES ${CONFIGURE_DEPENDS}
  ${CWD}/src/io/*.cpp
  ${CWD}/src/bun.js/modules/*.cpp
  ${CWD}/src/bun.js/bindings/*.cpp
  ${CWD}/src/bun.js/bindings/webcore/*.cpp
  ${CWD}/src/bun.js/bindings/sqlite/*.cpp
  ${CWD}/src/bun.js/bindings/webcrypto/*.cpp
  ${CWD}/src/bun.js/bindings/webcrypto/*/*.cpp
  ${CWD}/src/bun.js/bindings/v8/*.cpp
  ${BUN_USOCKETS_SOURCE}/src/crypto/*.cpp
  ${BUN_DEPS_SOURCE}/*.cpp
)

file(GLOB BUN_C_SOURCES ${CONFIGURE_DEPENDS}
  ${BUN_USOCKETS_SOURCE}/src/*.c
  ${BUN_USOCKETS_SOURCE}/src/eventing/*.c
  ${BUN_USOCKETS_SOURCE}/src/internal/*.c
  ${BUN_USOCKETS_SOURCE}/src/crypto/*.c
)

register_repository(
  NAME
    picohttpparser
  REPOSITORY
    h2o/picohttpparser
  COMMIT
    066d2b1e9ab820703db0837a7255d92d30f0c9f5
  OUTPUTS
    picohttpparser.c
)

list(APPEND BUN_C_SOURCES ${BUN_DEPS_SOURCE}/picohttpparser/picohttpparser.c)

if(WIN32)
  list(APPEND BUN_C_SOURCES ${CWD}/src/bun.js/bindings/windows/musl-memmem.c)
endif()

list(APPEND BUN_CPP_SOURCES
  ${BUN_C_SOURCES}
  ${BUN_CXX_SOURCES}
  ${BUN_ZIG_GENERATED_CLASSES_OUTPUTS}
  ${BUN_JS_SINK_OUTPUTS}
  ${BUN_JAVASCRIPT_OUTPUTS}
  ${BUN_OBJECT_LUT_OUTPUTS}
)

if(WIN32)
  if(ENABLE_CANARY)
    set(Bun_VERSION_WITH_TAG ${VERSION}-canary.${CANARY_REVISION})
  else()
    set(Bun_VERSION_WITH_TAG ${VERSION})
  endif()
  set(BUN_ICO_PATH ${CWD}/src/bun.ico)
  configure_file(
    ${CWD}/src/windows-app-info.rc
    ${CODEGEN_PATH}/windows-app-info.rc
  )
  list(APPEND BUN_CPP_SOURCES ${CODEGEN_PATH}/windows-app-info.rc)
endif()

# --- Executable ---

set(BUN_CPP_OUTPUT ${BUILD_PATH}/${CMAKE_STATIC_LIBRARY_PREFIX}${bun}${CMAKE_STATIC_LIBRARY_SUFFIX})

if(BUN_LINK_ONLY)
  add_executable(${bun} ${BUN_CPP_OUTPUT} ${BUN_ZIG_OUTPUT})
  set_target_properties(${bun} PROPERTIES LINKER_LANGUAGE CXX)
  target_link_libraries(${bun} PRIVATE ${BUN_CPP_OUTPUT})
elseif(BUN_CPP_ONLY)
  add_library(${bun} STATIC ${BUN_CPP_SOURCES})
  register_command(
    TARGET
      ${bun}
    TARGET_PHASE
      POST_BUILD
    COMMENT
      "Uploading ${bun}"
    COMMAND
      ${CMAKE_COMMAND} -E true
    ARTIFACTS
      ${BUN_CPP_OUTPUT}
  )
else()
  add_executable(${bun} ${BUN_CPP_SOURCES})
  target_link_libraries(${bun} PRIVATE ${BUN_ZIG_OUTPUT})
endif()

if(NOT bun STREQUAL "bun")
  add_custom_target(bun DEPENDS ${bun})
endif()

# --- C/C++ Properties ---

set_target_properties(${bun} PROPERTIES
  CXX_STANDARD 20
  CXX_STANDARD_REQUIRED YES
  CXX_EXTENSIONS YES
  CXX_VISIBILITY_PRESET hidden
  C_STANDARD 17
  C_STANDARD_REQUIRED YES
  VISIBILITY_INLINES_HIDDEN YES
)

# --- C/C++ Includes ---

if(WIN32)
  target_include_directories(${bun} PRIVATE ${CWD}/src/bun.js/bindings/windows)
endif()

target_include_directories(${bun} PRIVATE
  ${CWD}/packages
  ${CWD}/packages/bun-usockets
  ${CWD}/packages/bun-usockets/src
  ${CWD}/src/bun.js/bindings
  ${CWD}/src/bun.js/bindings/webcore
  ${CWD}/src/bun.js/bindings/webcrypto
  ${CWD}/src/bun.js/bindings/sqlite
  ${CWD}/src/bun.js/modules
  ${CWD}/src/js/builtins
  ${CWD}/src/napi
  ${CWD}/src/deps
  ${CWD}/src/deps/picohttpparser
  ${CODEGEN_PATH}
)

# --- C/C++ Definitions ---

if(DEBUG)
  target_compile_definitions(${bun} PRIVATE BUN_DEBUG=1)
endif()

if(APPLE)
  target_compile_definitions(${bun} PRIVATE _DARWIN_NON_CANCELABLE=1)
endif()

if(WIN32)
  target_compile_definitions(${bun} PRIVATE
    WIN32
    _WINDOWS
    WIN32_LEAN_AND_MEAN=1
    _CRT_SECURE_NO_WARNINGS
    BORINGSSL_NO_CXX=1 # lol
  )
endif()

target_compile_definitions(${bun} PRIVATE
  _HAS_EXCEPTIONS=0
  LIBUS_USE_OPENSSL=1
  LIBUS_USE_BORINGSSL=1
  WITH_BORINGSSL=1
  STATICALLY_LINKED_WITH_JavaScriptCore=1
  STATICALLY_LINKED_WITH_BMALLOC=1
  BUILDING_WITH_CMAKE=1
  JSC_OBJC_API_ENABLED=0
  BUN_SINGLE_THREADED_PER_VM_ENTRY_SCOPE=1
  NAPI_EXPERIMENTAL=ON
  NOMINMAX
  IS_BUILD
  BUILDING_JSCONLY__
  REPORTED_NODEJS_VERSION=\"${NODEJS_VERSION}\"
  REPORTED_NODEJS_ABI_VERSION=${NODEJS_ABI_VERSION}
)

if(DEBUG AND NOT CI)
  target_compile_definitions(${bun} PRIVATE
    BUN_DYNAMIC_JS_LOAD_PATH=\"${BUILD_PATH}/js\"
  )
endif()


# --- Compiler options ---

if(WIN32)
  target_compile_options(${bun} PUBLIC
    /EHsc
    -Xclang -fno-c++-static-destructors
  )
  if(RELEASE)
    target_compile_options(${bun} PUBLIC
      /Gy
      /Gw
      /GF
      /GA
    )
  endif()
else()
  target_compile_options(${bun} PUBLIC
    -fconstexpr-steps=2542484
    -fconstexpr-depth=54
    -fno-exceptions
    -fno-asynchronous-unwind-tables
    -fno-unwind-tables
    -fno-c++-static-destructors
    -fvisibility=hidden
    -fvisibility-inlines-hidden
    -fno-omit-frame-pointer
    -mno-omit-leaf-frame-pointer
    -fno-pic
    -fno-pie
    -faddrsig
  )
  if(DEBUG)
    target_compile_options(${bun} PUBLIC
      -Werror=return-type
      -Werror=return-stack-address
      -Werror=implicit-function-declaration
      -Werror=uninitialized
      -Werror=conditional-uninitialized
      -Werror=suspicious-memaccess
      -Werror=int-conversion
      -Werror=nonnull
      -Werror=move
      -Werror=sometimes-uninitialized
      -Werror=unused
      -Wno-unused-function
      -Wno-nullability-completeness
      -Werror
      -fsanitize=null
      -fsanitize-recover=all
      -fsanitize=bounds
      -fsanitize=return
      -fsanitize=nullability-arg
      -fsanitize=nullability-assign
      -fsanitize=nullability-return
      -fsanitize=returns-nonnull-attribute
      -fsanitize=unreachable
    )
    target_link_libraries(${bun} PRIVATE -fsanitize=null)
  else()
    # Leave -Werror=unused off in release builds so we avoid errors from being used in ASSERT
    target_compile_options(${bun} PUBLIC ${LTO_FLAG}
      -Werror=return-type
      -Werror=return-stack-address
      -Werror=implicit-function-declaration
      -Werror=uninitialized
      -Werror=conditional-uninitialized
      -Werror=suspicious-memaccess
      -Werror=int-conversion
      -Werror=nonnull
      -Werror=move
      -Werror=sometimes-uninitialized
      -Wno-nullability-completeness
      -Werror
    )
  endif()
endif()

# --- Linker options ---

if(WIN32)
  target_link_options(${bun} PUBLIC
    /STACK:0x1200000,0x100000
    /errorlimit:0
  )
  if(RELEASE)
    target_link_options(${bun} PUBLIC
      -flto=full
      /LTCG
      /OPT:REF
      /OPT:NOICF
      /DEBUG:FULL
      /delayload:ole32.dll
      /delayload:WINMM.dll
      /delayload:dbghelp.dll
      /delayload:VCRUNTIME140_1.dll
      # libuv loads these two immediately, but for some reason it seems to still be slightly faster to delayload them
      /delayload:WS2_32.dll
      /delayload:WSOCK32.dll
      /delayload:ADVAPI32.dll
      /delayload:IPHLPAPI.dll
    )
  endif()
elseif(APPLE)
  target_link_options(${bun} PUBLIC 
    -dead_strip
    -dead_strip_dylibs
    -Wl,-stack_size,0x1200000
    -fno-keep-static-consts
  )
else()
  target_link_options(${bun} PUBLIC
    -fuse-ld=lld-${LLVM_VERSION_MAJOR}
    -fno-pic
    -static-libstdc++
    -static-libgcc
    -Wl,-no-pie
    -Wl,-icf=safe
    -Wl,--as-needed
    -Wl,--gc-sections
    -Wl,-z,stack-size=12800000
    -Wl,--wrap=fcntl
    -Wl,--wrap=fcntl64
    -Wl,--wrap=stat64
    -Wl,--wrap=pow
    -Wl,--wrap=exp
    -Wl,--wrap=expf
    -Wl,--wrap=log
    -Wl,--wrap=log2
    -Wl,--wrap=lstat
    -Wl,--wrap=stat64
    -Wl,--wrap=stat
    -Wl,--wrap=fstat
    -Wl,--wrap=fstatat
    -Wl,--wrap=lstat64
    -Wl,--wrap=fstat64
    -Wl,--wrap=fstatat64
    -Wl,--wrap=mknod
    -Wl,--wrap=mknodat
    -Wl,--wrap=statx
    -Wl,--wrap=fmod
    -Wl,--compress-debug-sections=zlib
    -Wl,-z,lazy
    -Wl,-z,norelro
  )
endif()

# --- LTO options ---

if(ENABLE_LTO)
  if(WIN32)
    target_link_options(${bun} PUBLIC -flto)
    target_compile_options(${bun} PUBLIC -flto -Xclang -emit-llvm-bc)
  else()
    target_compile_options(${bun} PUBLIC
      -flto=full
      -emit-llvm
      -fwhole-program-vtables
      -fforce-emit-vtables
    )
  endif()
endif()

# --- Symbols list ---

if(WIN32)
  set(BUN_SYMBOLS_PATH ${CWD}/src/symbols.def)
  target_link_options(${bun} PUBLIC /DEF:${BUN_SYMBOLS_PATH})
elseif(APPLE)
  set(BUN_SYMBOLS_PATH ${CWD}/src/symbols.txt)
  target_link_options(${bun} PUBLIC -exported_symbols_list ${BUN_SYMBOLS_PATH})
else()
  set(BUN_SYMBOLS_PATH ${CWD}/src/symbols.dyn)
  set(BUN_LINKER_LDS_PATH ${CWD}/src/linker.lds)
  target_link_options(${bun} PUBLIC
    -Bsymbolics-functions
    -rdynamic
    -Wl,--dynamic-list=${BUN_SYMBOLS_PATH}
    -Wl,--version-script=${BUN_LINKER_LDS_PATH}
  )
  set_target_properties(${bun} PROPERTIES LINK_DEPENDS ${BUN_LINKER_LDS_PATH})
endif()

set_target_properties(${bun} PROPERTIES LINK_DEPENDS ${BUN_SYMBOLS_PATH})

# --- WebKit ---

include(SetupWebKit)

if(WIN32)
  target_link_libraries(${bun} PRIVATE
    ${WEBKIT_LIB_PATH}/WTF.lib
    ${WEBKIT_LIB_PATH}/JavaScriptCore.lib
    ${WEBKIT_LIB_PATH}/sicudt.lib
    ${WEBKIT_LIB_PATH}/sicuin.lib
    ${WEBKIT_LIB_PATH}/sicuuc.lib
  )
else()
  target_link_libraries(${bun} PRIVATE
    ${WEBKIT_LIB_PATH}/libWTF.a
    ${WEBKIT_LIB_PATH}/libJavaScriptCore.a
  )
  if(NOT APPLE OR EXISTS ${WEBKIT_LIB_PATH}/libbmalloc.a)
    target_link_libraries(${bun} PRIVATE ${WEBKIT_LIB_PATH}/libbmalloc.a)
  endif()
endif()

include_directories(${WEBKIT_INCLUDE_PATH})

if(WEBKIT_PREBUILT AND NOT APPLE)
  include_directories(${WEBKIT_INCLUDE_PATH}/wtf/unicode)
endif()

# --- Dependencies ---

set(BUN_DEPENDENCIES
  BoringSSL
  Brotli
  Cares
  LibDeflate
  LolHtml
  Lshpack
  Mimalloc
  TinyCC
  Zlib
  LibArchive # must be loaded after zlib
  Zstd
)

if(WIN32)
  list(APPEND BUN_DEPENDENCIES Libuv)
endif()

if(USE_STATIC_SQLITE)
  list(APPEND BUN_DEPENDENCIES SQLite)
endif()

foreach(dependency ${BUN_DEPENDENCIES})
  include(Build${dependency})
endforeach()

list(TRANSFORM BUN_DEPENDENCIES TOLOWER OUTPUT_VARIABLE BUN_TARGETS)
add_custom_target(dependencies DEPENDS ${BUN_TARGETS})

if(APPLE)
  target_link_libraries(${bun} PRIVATE icucore resolv)
endif()

if(USE_STATIC_SQLITE)
  target_compile_definitions(${bun} PRIVATE LAZY_LOAD_SQLITE=0)
else()
  target_compile_definitions(${bun} PRIVATE LAZY_LOAD_SQLITE=1)
endif()

if(LINUX)
  target_link_libraries(${bun} PRIVATE c pthread dl)

  if(USE_STATIC_LIBATOMIC)
    target_link_libraries(${bun} PRIVATE libatomic.a)
  else()
    target_link_libraries(${bun} PUBLIC libatomic.so)
  endif()

  if(USE_SYSTEM_ICU)
    target_link_libraries(${bun} PRIVATE libicudata.a)
    target_link_libraries(${bun} PRIVATE libicui18n.a)
    target_link_libraries(${bun} PRIVATE libicuuc.a)
  else()
    target_link_libraries(${bun} PRIVATE ${WEBKIT_LIB_PATH}/libicudata.a)
    target_link_libraries(${bun} PRIVATE ${WEBKIT_LIB_PATH}/libicui18n.a)
    target_link_libraries(${bun} PRIVATE ${WEBKIT_LIB_PATH}/libicuuc.a)
  endif()
endif()

if(WIN32)
  target_link_libraries(${bun} PRIVATE
    winmm
    bcrypt
    ntdll
    userenv
    dbghelp
    wsock32 # ws2_32 required by TransmitFile aka sendfile on windows
    delayimp.lib
  )
endif()

# --- Packaging ---

if(NOT BUN_CPP_ONLY)
  if(bunStrip)
    register_command(
      TARGET
        ${bun}
      TARGET_PHASE
        POST_BUILD
      COMMENT
        "Stripping ${bun}"
      COMMAND
        ${CMAKE_STRIP}
          ${bunExe}
          --strip-all
          --strip-debug
          --discard-all
          -o ${bunStripExe}
      CWD
        ${BUILD_PATH}
      OUTPUTS
        ${BUILD_PATH}/${bunStripExe}
    )
  endif()

  register_command(
    TARGET
      ${bun}
    TARGET_PHASE
      POST_BUILD
    COMMENT
      "Testing ${bun}"
    COMMAND
      ${CMAKE_COMMAND}
      -E env BUN_DEBUG_QUIET_LOGS=1
      ${BUILD_PATH}/${bunExe}
        --revision
    CWD
      ${BUILD_PATH}
  )

  if(CI)
    set(BUN_FEATURES_SCRIPT ${CWD}/scripts/features.mjs)
    register_command(
      TARGET
        ${bun}
      TARGET_PHASE
        POST_BUILD
      COMMENT
        "Generating features.json"
      COMMAND
        ${CMAKE_COMMAND}
          -E env
            BUN_GARBAGE_COLLECTOR_LEVEL=1
            BUN_DEBUG_QUIET_LOGS=1
            BUN_FEATURE_FLAG_INTERNAL_FOR_TESTING=1
          ${BUILD_PATH}/${bunExe}
          ${BUN_FEATURES_SCRIPT}
      CWD
        ${BUILD_PATH}
      ARTIFACTS
        ${BUILD_PATH}/features.json
    )
  endif()

  if(CMAKE_HOST_APPLE AND bunStrip)
    register_command(
      TARGET
        ${bun}
      TARGET_PHASE
        POST_BUILD
      COMMENT
        "Generating ${bun}.dSYM"
      COMMAND
        ${CMAKE_DSYMUTIL}
          ${bun}
          --flat
          --keep-function-for-static
          --object-prefix-map .=${CWD}
          -o ${bun}.dSYM
          -j ${CMAKE_BUILD_PARALLEL_LEVEL}
      CWD
        ${BUILD_PATH}
      OUTPUTS
        ${BUILD_PATH}/${bun}.dSYM
    )
  endif()

  if(CI)
    if(ENABLE_BASELINE)
      set(bunTriplet bun-${OS}-${ARCH}-baseline)
    else()
      set(bunTriplet bun-${OS}-${ARCH})
    endif()
    string(REPLACE bun ${bunTriplet} bunPath ${bun})
    set(bunFiles ${bunExe} features.json)
    if(WIN32)
      list(APPEND bunFiles ${bun}.pdb)
    elseif(APPLE)
      list(APPEND bunFiles ${bun}.dSYM)
    endif()
    register_command(
      TARGET
        ${bun}
      TARGET_PHASE
        POST_BUILD
      COMMENT
        "Generating ${bunPath}.zip"
      COMMAND
        ${CMAKE_COMMAND} -E rm -rf ${bunPath} ${bunPath}.zip
        && ${CMAKE_COMMAND} -E make_directory ${bunPath}
        && ${CMAKE_COMMAND} -E copy ${bunFiles} ${bunPath}
        && ${CMAKE_COMMAND} -E tar cfv ${bunPath}.zip --format=zip ${bunPath}
        && ${CMAKE_COMMAND} -E rm -rf ${bunPath}
      CWD
        ${BUILD_PATH}
      ARTIFACTS
        ${BUILD_PATH}/${bunPath}.zip
    )

    if(bunStrip)
      string(REPLACE bun ${bunTriplet} bunStripPath ${bunStrip})
      register_command(
        TARGET
          ${bun}
        TARGET_PHASE
          POST_BUILD
        COMMENT
          "Generating ${bunStripPath}.zip"
        COMMAND
          ${CMAKE_COMMAND} -E rm -rf ${bunStripPath} ${bunStripPath}.zip
          && ${CMAKE_COMMAND} -E make_directory ${bunStripPath}
          && ${CMAKE_COMMAND} -E copy ${bunStripExe} ${bunStripPath}
          && ${CMAKE_COMMAND} -E tar cfv ${bunStripPath}.zip --format=zip ${bunStripPath}
          && ${CMAKE_COMMAND} -E rm -rf ${bunStripPath}
        CWD
          ${BUILD_PATH}
        ARTIFACTS
          ${BUILD_PATH}/${bunStripPath}.zip
      )
    endif()
  endif()
endif()
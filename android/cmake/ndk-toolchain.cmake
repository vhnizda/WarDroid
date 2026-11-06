# Wraps the NDK toolchain so the engine's vendored ExternalProject builds get
# the same target. Stratagus forwards CMAKE_TOOLCHAIN_FILE to them, but not
# ANDROID_ABI or ANDROID_PLATFORM, so those come from the environment here.
if(NOT DEFINED ENV{ANDROID_NDK_ROOT})
  message(FATAL_ERROR "Set ANDROID_NDK_ROOT")
endif()
if(NOT DEFINED ENV{WARCRAFTAI_ABI})
  message(FATAL_ERROR "Set WARCRAFTAI_ABI, for example arm64-v8a")
endif()

set(ANDROID_ABI "$ENV{WARCRAFTAI_ABI}")
set(ANDROID_PLATFORM android-23)
set(ANDROID_STL c++_static)
set(CMAKE_BUILD_TYPE_INIT Release)

# SDL 2.0.22 makes this warning an error, and its Android code trips it.
set(HAVE_GCC_WERROR_DECLARATION_AFTER_STATEMENT OFF CACHE INTERNAL "")

include("$ENV{ANDROID_NDK_ROOT}/build/cmake/android.toolchain.cmake")

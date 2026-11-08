cmake_minimum_required(VERSION 3.25)
project(wargusport C CXX)

# Gradle resolves junctions, so the short engine path is passed in explicitly.
# The real project path is long enough to push SDL's header copy step past the
# Windows command line limit.
set(ENGINE_DIR "${CMAKE_CURRENT_LIST_DIR}/../../../../../engine/stratagus" CACHE PATH "Stratagus source")
cmake_path(NORMAL_PATH ENGINE_DIR)

# Stratagus forwards CMAKE_TOOLCHAIN_FILE to its vendored ExternalProject
# builds, but not ANDROID_ABI or ANDROID_PLATFORM. Give them a toolchain file
# with this build's target baked in.
file(TO_CMAKE_PATH "${CMAKE_MAKE_PROGRAM}" CHILD_MAKE_PROGRAM)
configure_file(child-toolchain.cmake.in "${CMAKE_BINARY_DIR}/child-toolchain.cmake" @ONLY)
set(CMAKE_TOOLCHAIN_FILE "${CMAKE_BINARY_DIR}/child-toolchain.cmake")

set(BUILD_VENDORED_LUA ON)
set(BUILD_VENDORED_SDL ON)
set(BUILD_VENDORED_MEDIA_LIBS ON)
set(WITH_STACKTRACE OFF)
set(WITH_OPENMP OFF)
set(BUILD_TESTING OFF)

add_subdirectory("${ENGINE_DIR}" stratagus EXCLUDE_FROM_ALL)

# The vendored ExternalProject builds don't declare the libraries they produce,
# and Ninja refuses to link against files that no rule creates. Declare them
# here as byproducts of a step that runs after those builds.
get_directory_property(ENGINE_LIBS DIRECTORY "${ENGINE_DIR}" DEFINITION stratagus_LIBS)
set(VENDORED_OUTPUTS)
foreach(lib IN LISTS ENGINE_LIBS)
    if(lib MATCHES "/src/[^/]+-build/.*\\.a$")
        list(APPEND VENDORED_OUTPUTS "${lib}")
    endif()
endforeach()
list(REMOVE_DUPLICATES VENDORED_OUTPUTS)
add_custom_target(vendored_outputs
    COMMAND "${CMAKE_COMMAND}" -E true
    BYPRODUCTS ${VENDORED_OUTPUTS}
)
add_dependencies(vendored_outputs stratagus_lib)

# SDLActivity loads libmain.so and calls SDL_main, which SDL_main.h makes of
# the engine's main().
add_library(main SHARED "${ENGINE_DIR}/src/stratagus/main.cpp")
target_link_libraries(main PRIVATE
    stratagus_lib
    # SDL is static, so keep its JNI entry points even though nothing in
    # native code references them.
    -Wl,--whole-archive
    "${CMAKE_BINARY_DIR}/stratagus/SDL2/src/SDL2-build/libSDL2.a"
    -Wl,--no-whole-archive
    android log EGL GLESv1_CM GLESv2 OpenSLES dl m
)
add_dependencies(main vendored_outputs)
# The engine sets its include paths per directory, so they don't follow
# stratagus_lib.
get_directory_property(ENGINE_INCLUDES DIRECTORY "${ENGINE_DIR}" INCLUDE_DIRECTORIES)
target_include_directories(main PRIVATE ${ENGINE_INCLUDES})

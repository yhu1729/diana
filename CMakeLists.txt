cmake_minimum_required(VERSION 3.25)

project(diana
    VERSION 0.1.0
    DESCRIPTION "Formally verified numerical methods in C"
    LANGUAGES C)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS OFF)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

option(DIANA_WERROR "Treat warnings as errors" OFF)
option(BUILD_SHARED_LIBS "Build diana as a shared library" OFF)

if(CMAKE_C_FLAGS MATCHES "-Ofast|-ffast-math")
    message(FATAL_ERROR "diana must not be built with -Ofast or -ffast-math: the verified semantics are strict IEEE binary64")
endif()

include(cmake/warning.cmake)

add_library(diana
    src/status.c)
add_library(diana::diana ALIAS diana)
target_include_directories(diana PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>)
set_target_properties(diana PROPERTIES
    C_VISIBILITY_PRESET default
    POSITION_INDEPENDENT_CODE ON
    VERSION ${PROJECT_VERSION}
    SOVERSION ${PROJECT_VERSION_MAJOR})
diana_set_strict_flag(diana)

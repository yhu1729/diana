cmake_minimum_required(VERSION 3.25)

project(diana
    VERSION 0.2.0
    DESCRIPTION "Formally verified numerical methods in C"
    LANGUAGES C)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS OFF)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

if(DEFINED SKBUILD)
    set(DIANA_BUILD_PYTHON ON CACHE BOOL "" FORCE)
endif()

option(DIANA_BUILD_TEST "Build the C test suite" OFF)
option(DIANA_SANITIZER "Enable AddressSanitizer and UndefinedBehaviorSanitizer" OFF)
option(DIANA_WERROR "Treat warnings as errors" OFF)
option(DIANA_BUILD_SHARED_LIB "Build Diana as a shared library" OFF)

string(TOUPPER "${CMAKE_BUILD_TYPE}" diana_config)
foreach(flag_var CMAKE_C_FLAGS CMAKE_C_FLAGS_DEBUG CMAKE_C_FLAGS_RELEASE
        CMAKE_C_FLAGS_RELWITHDEBINFO CMAKE_C_FLAGS_MINSIZEREL CMAKE_C_FLAGS_${diana_config})
    if("${${flag_var}}" MATCHES "-Ofast|-ffast-math|-funsafe-math-optimizations")
        message(FATAL_ERROR "Diana must not be built with -Ofast, -ffast-math or -funsafe-math-optimizations (${flag_var}): the verified semantics are strict IEEE binary64")
    endif()
endforeach()

file(STRINGS include/diana/diana.h diana_header_version REGEX "^#define DIANA_VERSION_STRING ")
string(REGEX REPLACE ".*\"([0-9.]+)\".*" "\\1" diana_header_version "${diana_header_version}")
if(NOT diana_header_version STREQUAL PROJECT_VERSION)
    message(FATAL_ERROR "include/diana/diana.h declares version ${diana_header_version}, CMakeLists.txt ${PROJECT_VERSION}")
endif()

include(cmake/warning.cmake)
include(GNUInstallDirs)

if(DIANA_SANITIZER)
    if(CMAKE_C_COMPILER_ID MATCHES "GNU|Clang|AppleClang")
        add_compile_options(-fsanitize=address,undefined -fno-omit-frame-pointer)
    else()
        message(WARNING "DIANA_SANITIZER is only supported with gcc or clang")
    endif()
endif()

if(DIANA_BUILD_SHARED_LIB)
    set(diana_library_type SHARED)
else()
    set(diana_library_type STATIC)
endif()
add_library(diana ${diana_library_type}
    src/status.c
    src/bisection.c
    src/euler.c
    src/newton.c
    src/simpson.c
    src/trapezoidal.c
    src/wrapper/bisection.c
    src/wrapper/euler.c
    src/wrapper/newton.c)
add_library(diana::diana ALIAS diana)
target_include_directories(diana PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>)
set_target_properties(diana PROPERTIES
    C_VISIBILITY_PRESET default
    POSITION_INDEPENDENT_CODE ON)
diana_set_strict_flag(diana)
if(DIANA_SANITIZER AND CMAKE_C_COMPILER_ID MATCHES "GNU|Clang|AppleClang")
    target_link_options(diana PUBLIC -fsanitize=address,undefined)
endif()

if(NOT DEFINED SKBUILD)
    set_target_properties(diana PROPERTIES
        VERSION ${PROJECT_VERSION}
        SOVERSION ${PROJECT_VERSION_MAJOR})
    install(TARGETS diana EXPORT dianaTargets
        ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
        LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR})
    install(DIRECTORY include/diana DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
    install(EXPORT dianaTargets NAMESPACE diana:: DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/diana)

    include(CMakePackageConfigHelpers)
    configure_package_config_file(cmake/dianaConfig.cmake.in
        ${CMAKE_CURRENT_BINARY_DIR}/dianaConfig.cmake
        INSTALL_DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/diana)
    write_basic_package_version_file(${CMAKE_CURRENT_BINARY_DIR}/dianaConfigVersion.cmake
        COMPATIBILITY SameMinorVersion)
    install(FILES
        ${CMAKE_CURRENT_BINARY_DIR}/dianaConfig.cmake
        ${CMAKE_CURRENT_BINARY_DIR}/dianaConfigVersion.cmake
        DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/diana)
endif()

if(DIANA_BUILD_TEST)
    enable_testing()
    add_subdirectory(test/c)
    if(NOT DEFINED SKBUILD)
        set(DIANA_INSTALL_TEST_PREFIX ${CMAKE_CURRENT_BINARY_DIR}/install-test)
        set(DIANA_INSTALL_TEST_OPTION
            -DCMAKE_PREFIX_PATH=${DIANA_INSTALL_TEST_PREFIX}
            -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
            -DCMAKE_BUILD_TYPE=$<CONFIG>
            "-DCMAKE_EXE_LINKER_FLAGS=${CMAKE_EXE_LINKER_FLAGS}")
        foreach(option CMAKE_OSX_ARCHITECTURES CMAKE_OSX_SYSROOT CMAKE_OSX_DEPLOYMENT_TARGET)
            if(DEFINED ${option})
                string(REPLACE ";" "\\;" value "${${option}}")
                list(APPEND DIANA_INSTALL_TEST_OPTION "-D${option}=${value}")
            endif()
        endforeach()
        add_test(NAME install
            COMMAND ${CMAKE_COMMAND} --install ${CMAKE_CURRENT_BINARY_DIR}
                    --prefix ${DIANA_INSTALL_TEST_PREFIX} --config $<CONFIG>)
        set_tests_properties(install PROPERTIES FIXTURES_SETUP diana_install)
        add_test(NAME find_package
            COMMAND ${CMAKE_CTEST_COMMAND}
                    --build-and-test ${CMAKE_CURRENT_SOURCE_DIR}/test/install
                                     ${CMAKE_CURRENT_BINARY_DIR}/test/install
                    --build-generator ${CMAKE_GENERATOR}
                    --build-makeprogram ${CMAKE_MAKE_PROGRAM}
                    --build-config $<CONFIG>
                    --build-options ${DIANA_INSTALL_TEST_OPTION}
                    --test-command consume)
        set_tests_properties(find_package PROPERTIES FIXTURES_REQUIRED diana_install)
    endif()
endif()

option(DIANA_BUILD_PYTHON "Build the CPython extension module" ON)
if(DIANA_BUILD_PYTHON)
    find_package(Python COMPONENTS Interpreter Development.Module REQUIRED)
    Python_add_library(_diana MODULE WITH_SOABI
        python/ext/module.c
        python/ext/convert.c
        python/ext/status.c
        python/ext/bisection.c
        python/ext/euler.c
        python/ext/newton.c
        python/ext/simpson.c
        python/ext/trapezoidal.c)
    target_link_libraries(_diana PRIVATE diana::diana)
    diana_set_strict_flag(_diana)
    if(DEFINED SKBUILD)
        install(TARGETS _diana DESTINATION diana)
        if(DIANA_BUILD_SHARED_LIB)
            install(TARGETS diana
                LIBRARY DESTINATION diana
                ARCHIVE DESTINATION diana EXCLUDE_FROM_ALL)
            if(APPLE)
                set_target_properties(diana PROPERTIES
                    MACOSX_RPATH ON
                    INSTALL_NAME_DIR "@rpath")
                set_target_properties(_diana PROPERTIES INSTALL_RPATH "@loader_path")
            else()
                set_target_properties(_diana PROPERTIES INSTALL_RPATH "$ORIGIN")
            endif()
            set_target_properties(_diana PROPERTIES INSTALL_RPATH_USE_LINK_PATH OFF)
        endif()
    endif()
endif()

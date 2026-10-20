cmake_minimum_required(VERSION 3.25)

project(diana
    VERSION 1.0.0
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
option(DIANA_BUILD_BENCHMARK "Build the benchmark suite" OFF)
option(DIANA_SANITIZER "Enable AddressSanitizer and UndefinedBehaviorSanitizer" OFF)
option(DIANA_WERROR "Treat warnings as errors" OFF)
option(DIANA_BUILD_SHARED_LIB "Build Diana as a shared library" OFF)
option(DIANA_ALLOW_UNKNOWN_COMPILER "Build with a C compiler other than gcc or clang; it gets none of the strict floating-point options, so the verified strict IEEE binary64 semantics are not established" OFF)

if(NOT CMAKE_C_COMPILER_ID MATCHES "^(GNU|Clang|AppleClang)$")
    if(DIANA_ALLOW_UNKNOWN_COMPILER)
        message(WARNING "C compiler ID '${CMAKE_C_COMPILER_ID}' gets none of Diana's strict floating-point options: the verified strict IEEE binary64 semantics are not established for this build")
    else()
        message(FATAL_ERROR "Diana must be built with gcc or clang (C compiler ID GNU, Clang or AppleClang), not '${CMAKE_C_COMPILER_ID}': only those get the strict floating-point options the proofs assume. Set DIANA_ALLOW_UNKNOWN_COMPILER=ON to build without that guarantee")
    endif()
endif()

string(TOUPPER "${CMAKE_BUILD_TYPE}" diana_config)
foreach(flag_var CMAKE_C_FLAGS CMAKE_C_FLAGS_DEBUG CMAKE_C_FLAGS_RELEASE
        CMAKE_C_FLAGS_RELWITHDEBINFO CMAKE_C_FLAGS_MINSIZEREL CMAKE_C_FLAGS_${diana_config})
    if("${${flag_var}}" MATCHES "-Ofast|-ffast-math|-funsafe-math-optimizations|-ffinite-math-only|-fno-honor-nans|-fno-honor-infinities|-fassociative-math|-freciprocal-math|-fno-signed-zeros|-fapprox-func|-ffp-contract=(fast|on)|-f?fp-model[= ](fast|aggressive)")
        message(FATAL_ERROR "Diana must not be built with ${CMAKE_MATCH_0} (${flag_var}): the verified semantics are strict IEEE binary64, every operation rounded separately in source order")
    endif()
endforeach()

file(STRINGS include/diana/diana.h diana_header_version REGEX "^#define DIANA_VERSION_STRING ")
string(REGEX REPLACE ".*\"([0-9.]+)\".*" "\\1" diana_header_version "${diana_header_version}")
if(NOT diana_header_version STREQUAL PROJECT_VERSION)
    message(FATAL_ERROR "include/diana/diana.h declares version ${diana_header_version}, CMakeLists.txt ${PROJECT_VERSION}")
endif()
foreach(part MAJOR MINOR PATCH)
    file(STRINGS include/diana/diana.h diana_header_${part} REGEX "^#define DIANA_VERSION_${part} ")
    string(REGEX REPLACE ".* ([0-9]+)$" "\\1" diana_header_${part} "${diana_header_${part}}")
    if(NOT diana_header_${part} STREQUAL PROJECT_VERSION_${part})
        message(FATAL_ERROR "include/diana/diana.h declares DIANA_VERSION_${part} ${diana_header_${part}}, CMakeLists.txt ${PROJECT_VERSION_${part}}")
    endif()
endforeach()

include(cmake/warning.cmake)
include(GNUInstallDirs)

if(DIANA_SANITIZER)
    if(CMAKE_C_COMPILER_ID MATCHES "GNU|Clang|AppleClang")
        add_compile_options(-fsanitize=address,undefined -fno-sanitize-recover=undefined
            -fno-omit-frame-pointer)
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
    src/status_str.c
    src/axpy.c
    src/bisection.c
    src/bisection_init.c
    src/bisection_mid.c
    src/bisection_result.c
    src/bisection_step.c
    src/cholesky.c
    src/euler.c
    src/euler_step.c
    src/euler_step_unchecked.c
    src/forward_substitution.c
    src/fp_sqrt.c
    src/lu.c
    src/lu_solve.c
    src/newton.c
    src/newton_init.c
    src/newton_result.c
    src/newton_step.c
    src/norm_1.c
    src/norm_2.c
    src/norm_inf.c
    src/rk4.c
    src/rk4_stage.c
    src/rk4_stage_unchecked.c
    src/rk4_step.c
    src/rk4_step_unchecked.c
    src/simpson.c
    src/transpose_substitution.c
    src/trapezoidal.c
    src/version.c)
add_library(diana::diana ALIAS diana)
target_include_directories(diana PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>)
set_target_properties(diana PROPERTIES
    C_VISIBILITY_PRESET default
    POSITION_INDEPENDENT_CODE ON)
diana_set_strict_flag(diana)
if(DIANA_BUILD_SHARED_LIB)
    file(STRINGS cmake/symbol.txt diana_symbol)
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS cmake/symbol.txt)
    if(APPLE)
        list(TRANSFORM diana_symbol PREPEND "_")
        list(JOIN diana_symbol "\n" diana_export)
        set(diana_export_file ${CMAKE_CURRENT_BINARY_DIR}/diana.exp)
        file(CONFIGURE OUTPUT ${diana_export_file} CONTENT "${diana_export}\n")
        target_link_options(diana PRIVATE "LINKER:-exported_symbols_list,${diana_export_file}")
    else()
        list(JOIN diana_symbol ";\n    " diana_export)
        set(diana_export_file ${CMAKE_CURRENT_BINARY_DIR}/diana.map)
        file(CONFIGURE OUTPUT ${diana_export_file}
            CONTENT "{\n  global:\n    ${diana_export};\n  local:\n    *;\n};\n")
        target_link_options(diana PRIVATE "LINKER:--version-script=${diana_export_file}")
    endif()
    set_property(TARGET diana APPEND PROPERTY LINK_DEPENDS ${diana_export_file})
endif()
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
        COMPATIBILITY SameMajorVersion)
    install(FILES
        ${CMAKE_CURRENT_BINARY_DIR}/dianaConfig.cmake
        ${CMAKE_CURRENT_BINARY_DIR}/dianaConfigVersion.cmake
        DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/diana)
endif()

if(DIANA_BUILD_TEST)
    enable_testing()
    add_subdirectory(test/c)
    set(diana_symbol_check -DSOURCE_DIR=${CMAKE_CURRENT_SOURCE_DIR})
    if(DIANA_BUILD_SHARED_LIB)
        list(APPEND diana_symbol_check -DNM=${CMAKE_NM} -DLIBRARY=$<TARGET_FILE:diana>
             -DAPPLE=${APPLE})
    endif()
    add_test(NAME symbol
        COMMAND ${CMAKE_COMMAND} ${diana_symbol_check}
                -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/check_symbol.cmake)
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

if(DIANA_BUILD_BENCHMARK)
    add_subdirectory(benchmark)
endif()

option(DIANA_BUILD_PYTHON "Build the CPython extension module" ON)
if(DIANA_BUILD_PYTHON)
    find_package(Python COMPONENTS Interpreter Development.Module REQUIRED)
    Python_add_library(_diana MODULE WITH_SOABI
        python/ext/module.c
        python/ext/bisection_exec.c
        python/ext/bisection_init.c
        python/ext/bisection_new.c
        python/ext/bisection_result.c
        python/ext/bisection_step.c
        python/ext/cholesky.c
        python/ext/cholesky_exec.c
        python/ext/convert_uint.c
        python/ext/euler_exec.c
        python/ext/euler_step.c
        python/ext/forward_substitution.c
        python/ext/get_array.c
        python/ext/lu.c
        python/ext/lu_exec.c
        python/ext/lu_solve.c
        python/ext/lu_solve_exec.c
        python/ext/newton_exec.c
        python/ext/newton_init.c
        python/ext/newton_new.c
        python/ext/newton_result.c
        python/ext/newton_step.c
        python/ext/norm.c
        python/ext/norm_1.c
        python/ext/norm_2.c
        python/ext/norm_exec.c
        python/ext/norm_inf.c
        python/ext/raise.c
        python/ext/rk4_exec.c
        python/ext/rk4_stage.c
        python/ext/rk4_step.c
        python/ext/simpson.c
        python/ext/simpson_exec.c
        python/ext/status_exec.c
        python/ext/status_str.c
        python/ext/substitution.c
        python/ext/substitution_exec.c
        python/ext/transpose_substitution.c
        python/ext/trapezoidal.c
        python/ext/trapezoidal_exec.c
        python/ext/version.c)
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

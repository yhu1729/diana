cmake_minimum_required(VERSION 3.25)

foreach(input DIANA_SOURCE_DIR DIANA_WORK_DIR DIANA_C_COMPILER DIANA_GENERATOR)
    if(NOT DEFINED ${input})
        message(FATAL_ERROR "${input} is not set")
    endif()
endforeach()

set(flag_var CMAKE_C_FLAGS CMAKE_C_FLAGS_DEBUG CMAKE_C_FLAGS_RELEASE CMAKE_C_FLAGS_RELWITHDEBINFO
    CMAKE_C_FLAGS_MINSIZEREL CMAKE_C_FLAGS_CHECK)
set(unsafe_flag
    -Ofast -ffast-math -funsafe-math-optimizations -ffinite-math-only -fno-honor-nans
    -fno-honor-infinities -fassociative-math -freciprocal-math -fno-signed-zeros -fapprox-func
    -ffp-contract=fast -ffp-contract=on -ffp-model=fast -ffp-model=aggressive -fp-model=fast
    "-fp-model fast")
set(safe_flag
    "-O2 -ffp-contract=off -fno-fast-math -fno-math-errno -fno-finite-math-only -fhonor-nans -fhonor-infinities -fno-associative-math -fno-reciprocal-math -fsigned-zeros -fno-approx-func -ffp-model=precise -ffp-model=strict -fp-model=precise -fp-model strict -mfma")

function(diana_configure var value)
    set(arg "")
    foreach(v IN LISTS flag_var)
        if(v STREQUAL var)
            list(APPEND arg "-D${v}=${value}")
        else()
            list(APPEND arg "-D${v}=")
        endif()
    endforeach()
    if(DEFINED DIANA_MAKE_PROGRAM AND NOT DIANA_MAKE_PROGRAM STREQUAL "")
        list(APPEND arg "-DCMAKE_MAKE_PROGRAM=${DIANA_MAKE_PROGRAM}")
    endif()
    execute_process(
        COMMAND "${CMAKE_COMMAND}" -S "${DIANA_SOURCE_DIR}" -B "${DIANA_WORK_DIR}"
                -G "${DIANA_GENERATOR}" "-DCMAKE_C_COMPILER=${DIANA_C_COMPILER}"
                -DCMAKE_BUILD_TYPE=Check -DDIANA_BUILD_PYTHON=OFF -DDIANA_BUILD_TEST=OFF
                ${arg} ${ARGN}
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE output)
    set(result "${result}" PARENT_SCOPE)
    set(output "${output}" PARENT_SCOPE)
endfunction()

function(diana_expect_accept what)
    if(NOT result EQUAL 0)
        message(SEND_ERROR "${what}: configuration failed\n${output}")
    endif()
endfunction()

function(diana_expect_reject what text)
    string(REGEX REPLACE "[ \t\r\n]+" " " flat "${output}")
    string(FIND "${flat}" "${text}" at)
    if(result EQUAL 0 OR at EQUAL -1)
        message(SEND_ERROR "${what}: configuration did not fail with \"${text}\"\n${output}")
    endif()
endfunction()

file(REMOVE_RECURSE "${DIANA_WORK_DIR}")

diana_configure(CMAKE_C_FLAGS "")
diana_expect_accept("no flag")

diana_configure(CMAKE_C_FLAGS "${safe_flag}")
diana_expect_accept("CMAKE_C_FLAGS=${safe_flag}")

foreach(flag IN LISTS unsafe_flag)
    diana_configure(CMAKE_C_FLAGS "-O2 ${flag} -g")
    diana_expect_reject("CMAKE_C_FLAGS=-O2 ${flag} -g"
        "Diana must not be built with ${flag} (CMAKE_C_FLAGS)")
endforeach()

foreach(var IN LISTS flag_var)
    diana_configure(${var} "-ffp-contract=fast")
    diana_expect_reject("${var}=-ffp-contract=fast"
        "Diana must not be built with -ffp-contract=fast (${var})")
endforeach()

file(GLOB compiler_file "${DIANA_WORK_DIR}/CMakeFiles/*/CMakeCCompiler.cmake")
list(LENGTH compiler_file compiler_file_count)
if(NOT compiler_file_count EQUAL 1)
    message(FATAL_ERROR "expected one CMakeCCompiler.cmake, found: ${compiler_file}")
endif()
file(READ "${compiler_file}" compiler_info)
string(REGEX REPLACE "set\\(CMAKE_C_COMPILER_ID \"[^\"]*\"\\)"
    "set(CMAKE_C_COMPILER_ID \"DianaUnknown\")" unknown_info "${compiler_info}")
if(unknown_info STREQUAL compiler_info)
    message(FATAL_ERROR "no CMAKE_C_COMPILER_ID line in ${compiler_file}")
endif()
file(WRITE "${compiler_file}" "${unknown_info}")

diana_configure(CMAKE_C_FLAGS "")
diana_expect_reject("compiler ID DianaUnknown"
    "Diana must be built with gcc or clang (C compiler ID GNU, Clang or AppleClang), not 'DianaUnknown': only those get the strict floating-point options the proofs assume. Set DIANA_ALLOW_UNKNOWN_COMPILER=ON")

diana_configure(CMAKE_C_FLAGS "" -DDIANA_ALLOW_UNKNOWN_COMPILER=ON)
diana_expect_accept("compiler ID DianaUnknown with DIANA_ALLOW_UNKNOWN_COMPILER=ON")
string(REGEX REPLACE "[ \t\r\n]+" " " flat "${output}")
string(FIND "${flat}" "C compiler ID 'DianaUnknown' gets none of Diana's strict" at)
if(at EQUAL -1)
    message(SEND_ERROR "DIANA_ALLOW_UNKNOWN_COMPILER=ON: no warning\n${output}")
endif()

diana_configure(CMAKE_C_FLAGS "-ffast-math" -DDIANA_ALLOW_UNKNOWN_COMPILER=ON)
diana_expect_reject("compiler ID DianaUnknown with -ffast-math"
    "Diana must not be built with -ffast-math (CMAKE_C_FLAGS)")

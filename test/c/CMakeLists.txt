function(diana_add_test name)
    add_executable(test_${name} test_${name}.c)
    target_link_libraries(test_${name} PRIVATE diana::diana m)
    diana_set_strict_flag(test_${name})
    add_test(NAME ${name} COMMAND test_${name})
endfunction()

diana_add_test(status)
diana_add_test(bisection)
diana_add_test(cholesky)
diana_add_test(compiler)
diana_add_test(euler)
diana_add_test(lu)
diana_add_test(lu_solve)
diana_add_test(newton)
diana_add_test(rk4)
diana_add_test(simpson)
diana_add_test(substitution)
diana_add_test(trapezoidal)

add_test(NAME configure
    COMMAND ${CMAKE_COMMAND}
            "-DDIANA_SOURCE_DIR=${PROJECT_SOURCE_DIR}"
            "-DDIANA_WORK_DIR=${CMAKE_CURRENT_BINARY_DIR}/configure"
            "-DDIANA_C_COMPILER=${CMAKE_C_COMPILER}"
            "-DDIANA_GENERATOR=${CMAKE_GENERATOR}"
            "-DDIANA_MAKE_PROGRAM=${CMAKE_MAKE_PROGRAM}"
            -P ${CMAKE_CURRENT_SOURCE_DIR}/test_configure.cmake)

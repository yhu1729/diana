add_executable(benchmark
    main.c
    harness.c
    bisection.c
    newton.c
    trapezoidal.c
    simpson.c
    euler.c
    rk4.c
    cholesky.c
    substitution.c
    lu.c
    lu_solve.c
    norm.c
    axpy.c)
target_link_libraries(benchmark PRIVATE diana::diana)
diana_set_strict_flag(benchmark)
target_compile_definitions(benchmark PRIVATE _POSIX_C_SOURCE=200809L)

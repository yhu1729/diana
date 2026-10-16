function(diana_set_strict_flag target)
    if(CMAKE_C_COMPILER_ID MATCHES "GNU|Clang|AppleClang")
        target_compile_options(${target} PRIVATE
            -Wall -Wextra -Wconversion -Wshadow -Wvla -Wpedantic -Wstrict-prototypes
            -Wmissing-prototypes -Wcast-qual -Wpointer-arith -Wundef -Wdouble-promotion
            -ffp-contract=off -fno-fast-math)
        if(CMAKE_C_COMPILER_ID STREQUAL "GNU")
            target_compile_options(${target} PRIVATE -fexcess-precision=standard)
        endif()
        if(DIANA_WERROR)
            target_compile_options(${target} PRIVATE -Werror)
        endif()
    endif()
endfunction()

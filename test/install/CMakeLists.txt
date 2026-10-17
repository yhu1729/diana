cmake_minimum_required(VERSION 3.25)

project(diana_install LANGUAGES C)

find_package(diana 0.3 CONFIG REQUIRED)

add_executable(consume main.c)
target_link_libraries(consume PRIVATE diana::diana)

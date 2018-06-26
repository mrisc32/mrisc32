cmake_minimum_required (VERSION 3.4.3)
project (mrisc32-sim)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

add_executable(sim
               sim.cpp
               cpu.cpp
               cpu.hpp
               cpu_simple.cpp
               cpu_simple.hpp
               ram.cpp
               ram.hpp)
target_include_directories(sim PRIVATE .)

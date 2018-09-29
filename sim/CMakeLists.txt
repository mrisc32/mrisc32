cmake_minimum_required (VERSION 3.4.3)
project (mrisc32-sim)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

find_package(Threads REQUIRED)

add_executable(mr32sim
               mr32sim.cpp
               config.cpp
               config.hpp
               cpu.cpp
               cpu.hpp
               cpu_simple.cpp
               cpu_simple.hpp
               ram.hpp)
target_include_directories(mr32sim PRIVATE .)
target_link_libraries(mr32sim ${CMAKE_THREAD_LIBS_INIT})

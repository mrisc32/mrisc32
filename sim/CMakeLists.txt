cmake_minimum_required (VERSION 3.4.3)
project (mrisc32-sim)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

set(MR32SIM_SRC mr32sim.cpp
                config.cpp
                config.hpp
                cpu.cpp
                cpu.hpp
                cpu_simple.cpp
                cpu_simple.hpp
                ram.hpp)
set(MR32SIM_DEFINES)
set(MR32SIM_LIBS)

# Optionally use GLFW + OpenGL for graphics.
find_package(glfw3 QUIET)
find_package(OpenGL QUIET)
if(glfw3_FOUND AND OpenGL_FOUND)
  add_subdirectory(glad)
  list(APPEND MR32SIM_SRC gpu.cpp
                          gpu.hpp)
  list(APPEND MR32SIM_DEFINES ENABLE_GUI)
  list(APPEND MR32SIM_LIBS glfw
                           glad
                           ${OPENGL_gl_LIBRARY}
                           ${CMAKE_DL_LIBS})
else()
  message(WARNING "Due to missing dependencies there will be no GUI support.")
endif()

# We need C++ threads.
find_package(Threads REQUIRED)
list(APPEND MR32SIM_LIBS ${CMAKE_THREAD_LIBS_INIT})

add_executable(mr32sim ${MR32SIM_SRC})
target_include_directories(mr32sim PRIVATE .)
target_compile_definitions(mr32sim PRIVATE ${MR32SIM_DEFINES})
target_link_libraries(mr32sim ${MR32SIM_LIBS})

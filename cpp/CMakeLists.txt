cmake_minimum_required(VERSION 3.10)
project(lfsr_mask_generator)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_executable(run src/lfsr_sim.cpp)


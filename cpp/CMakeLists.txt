# Minimum CMake version requirement.
cmake_minimum_required(VERSION 3.10)

# Project name and language.
project(lfsr_sim CXX)

# Set C++ Standard (C++11 is sufficient).
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
# It's recommended to disable compiler-specific extensions for better portability.
set(CMAKE_CXX_EXTENSIONS OFF)

# --- Find Dependencies ---
# Find the OpenMP library, which is required for parallelization.
# "REQUIRED" means CMake will error out if OpenMP is not found.
find_package(OpenMP REQUIRED)

# --- Define the Executable ---
# Add an executable named "lfsr_sim" from the source file src/lfsr_sim.cpp.
add_executable(lfsr_sim src/lfsr_sim.cpp)

# --- Link Libraries ---
# Link the OpenMP library to our executable.
target_link_libraries(lfsr_sim PRIVATE OpenMP::OpenMP_CXX)

# --- Set Compile Flags (Optional but Recommended) ---
# Set high-level optimization flags for the Release build type.
set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -O3 -DNDEBUG")

# Print a message to help the user confirm the CMake configuration.
message(STATUS "Project configured. To build with optimizations, use the 'Release' build type.")
message(STATUS "Example: cmake -DCMAKE_BUILD_TYPE=Release .. && cmake --build .")
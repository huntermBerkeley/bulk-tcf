cmake_minimum_required(VERSION 3.18 FATAL_ERROR)

project(bulk_tcf VERSION 1.0 LANGUAGES CXX CUDA)


set(DEFAULT_BUILD_TYPE "Release")


add_library(bulk_tcf INTERFACE)

include_directories(${PROJECT_SOURCE_DIR}/include)
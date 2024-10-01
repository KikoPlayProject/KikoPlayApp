# CMake 最低版本号要求

cmake_minimum_required(VERSION 3.16.0)

# 项目信息

project(SileroVAD)

set(ONNXRUNTIME_INCLUDE_DIR "" CACHE STRING "onnxruntime include dir")
set(ONNXRUNTIME_LIB_DIR "" CACHE STRING "onnxruntime lib dir")


add_executable(${PROJECT_NAME} silero-vad-onnx.cpp)

target_include_directories(${PROJECT_NAME} PRIVATE ${ONNXRUNTIME_INCLUDE_DIR})
target_link_libraries(${PROJECT_NAME} PRIVATE ${ONNXRUNTIME_LIB_DIR})
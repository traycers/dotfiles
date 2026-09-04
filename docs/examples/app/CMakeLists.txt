cmake_minimum_required(VERSION 3.16)
project(app VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(libB REQUIRED)

add_executable(app src/main.cpp)
target_link_libraries(app PRIVATE libB::libB)

include(GNUInstallDirs)
install(TARGETS app RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})

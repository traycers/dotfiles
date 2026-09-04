cmake_minimum_required(VERSION 3.16)
project(libB VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(libC REQUIRED)

add_library(libB src/libB.cpp)
add_library(libB::libB ALIAS libB)

target_include_directories(libB PUBLIC
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
  $<INSTALL_INTERFACE:include>
)

target_link_libraries(libB PUBLIC libC::libC)

include(GNUInstallDirs)
include(CMakePackageConfigHelpers)

install(TARGETS libB
  EXPORT libBTargets
  LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
  ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
  RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

install(DIRECTORY include/ DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})

install(EXPORT libBTargets
  FILE libBTargets.cmake
  NAMESPACE libB::
  DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/libB
)

configure_package_config_file(
  ${CMAKE_CURRENT_SOURCE_DIR}/libBConfig.cmake.in
  ${CMAKE_CURRENT_BINARY_DIR}/libBConfig.cmake
  INSTALL_DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/libB
)

write_basic_package_version_file(
  ${CMAKE_CURRENT_BINARY_DIR}/libBConfigVersion.cmake
  VERSION ${PROJECT_VERSION}
  COMPATIBILITY SameMajorVersion
)

install(FILES
  ${CMAKE_CURRENT_BINARY_DIR}/libBConfig.cmake
  ${CMAKE_CURRENT_BINARY_DIR}/libBConfigVersion.cmake
  DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/libB
)

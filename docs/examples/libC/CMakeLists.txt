cmake_minimum_required(VERSION 3.16)
project(libC VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_library(libC src/libC.cpp)
add_library(libC::libC ALIAS libC)

target_include_directories(libC PUBLIC
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
  $<INSTALL_INTERFACE:include>
)

include(GNUInstallDirs)
include(CMakePackageConfigHelpers)

install(TARGETS libC
  EXPORT libCTargets
  LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
  ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
  RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

install(DIRECTORY include/ DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})

install(EXPORT libCTargets
  FILE libCTargets.cmake
  NAMESPACE libC::
  DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/libC
)

configure_package_config_file(
  ${CMAKE_CURRENT_SOURCE_DIR}/libCConfig.cmake.in
  ${CMAKE_CURRENT_BINARY_DIR}/libCConfig.cmake
  INSTALL_DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/libC
)

write_basic_package_version_file(
  ${CMAKE_CURRENT_BINARY_DIR}/libCConfigVersion.cmake
  VERSION ${PROJECT_VERSION}
  COMPATIBILITY SameMajorVersion
)

install(FILES
  ${CMAKE_CURRENT_BINARY_DIR}/libCConfig.cmake
  ${CMAKE_CURRENT_BINARY_DIR}/libCConfigVersion.cmake
  DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/libC
)

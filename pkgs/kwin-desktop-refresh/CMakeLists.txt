cmake_minimum_required(VERSION 3.22)
project(kwin_desktop_refresh VERSION 1.0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(ECM REQUIRED NO_MODULE)
list(APPEND CMAKE_MODULE_PATH ${ECM_MODULE_PATH})
find_package(Qt6 REQUIRED COMPONENTS Core Gui Widgets Quick DBus)
include(KDEInstallDirs6)
find_package(KWin 6.6 REQUIRED)

add_library(desktoprefresh MODULE desktoprefresh.cpp)
set_target_properties(desktoprefresh PROPERTIES PREFIX "")
target_link_libraries(desktoprefresh PRIVATE KWin::kwin)
install(TARGETS desktoprefresh DESTINATION ${KDE_INSTALL_PLUGINDIR}/kwin/effects/plugins)

include(CTest)
if(BUILD_TESTING)
    add_executable(policy-test tests/policy-test.cpp)
    target_link_libraries(policy-test PRIVATE Qt6::Core)
    add_test(NAME refresh-policy COMMAND policy-test)

    add_executable(renderloop-test tests/renderloop-test.cpp)
    target_link_libraries(renderloop-test PRIVATE KWin::kwin)
    add_test(NAME renderloop-vrr-delay COMMAND renderloop-test)
endif()

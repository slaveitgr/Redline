find_package(PkgConfig REQUIRED)

find_package(Botan QUIET)
if(NOT Botan_FOUND)
  message(FATAL_ERROR "Botan library not found")
endif()

set(DBUS_DATADIR_PREFIX_DIR ${CMAKE_INSTALL_FULL_DATADIR})
option(INSTALL_DBUS_FILES_IN_PREFIX "Use installation prefix for D-Bus files" OFF)

# Find dbus
if(NOT INSTALL_DBUS_FILES_IN_PREFIX)
  pkg_check_modules(DBUS REQUIRED dbus-1)
  execute_process(
    COMMAND pkg-config --variable=datadir dbus-1
    RESULT_VARIABLE DBUS_DATADIR_PREFIX_DIR_RESULT
    OUTPUT_VARIABLE DBUS_DATADIR_PREFIX_DIR
    OUTPUT_STRIP_TRAILING_WHITESPACE
  )
  if(NOT DBUS_DATADIR_PREFIX_DIR_RESULT EQUAL "0")
    message(FATAL_ERROR "Failed to retrieve D-Bus `datadir` variable using pkg-config")
  endif()
endif()
message("D-Bus files will be installed into ${DBUS_DATADIR_PREFIX_DIR}/dbus-1")

# Find polkit
pkg_check_modules(POLKIT REQUIRED polkit-gobject-1)

option(POLKIT_POLICY_INSTALL_DIR "Polkit policy files installation directory" OFF)
if(NOT POLKIT_POLICY_INSTALL_DIR)
  execute_process(
    COMMAND pkg-config --variable=policydir polkit-gobject-1
    RESULT_VARIABLE POLKIT_POLICY_INSTALL_DIR_RESULT
    OUTPUT_VARIABLE POLKIT_POLICY_INSTALL_DIR
    OUTPUT_STRIP_TRAILING_WHITESPACE
  )
  if(NOT POLKIT_POLICY_INSTALL_DIR_RESULT EQUAL "0")
    message(FATAL_ERROR "Failed to retrieve Polkit `policydir` variable using pkg-config")
  endif()
endif()
message("Polkit policy files will be installed into ${POLKIT_POLICY_INSTALL_DIR}")

configure_file(helperids.h.in helperids.h)

list(APPEND HELPER_COMPILE_DEFINITIONS
  SPDLOG_ACTIVE_LEVEL=SPDLOG_LEVEL_TRACE
)

list(APPEND PROCESS_MONITOR_SRC
  pmon/processmonitor.cpp
  pmon/procpidsolver.cpp
  pmon/nlprocexecsocket.cpp
  pmon/nlprocexecmonitor.cpp
  pmon/processregistry.cpp
  pmon/appregistry.cpp
  pmon/msgdispatcher.cpp
  pmon/processeventconnector.c
)

list(APPEND SYSTEM_CONTROL_SRC
  sysctl/sysfswriter.cpp
  sysctl/msgreceiver.cpp
)

set(CMAKE_AUTOMOC ON)
add_executable(corectrl_helperkiller
  helperkiller.cpp
  polkit.cpp
)
set(CMAKE_AUTOMOC OFF)
set_target_properties(corectrl_helperkiller PROPERTIES OUTPUT_NAME redline_helperkiller)

target_include_directories(corectrl_helperkiller PRIVATE
  ${CMAKE_CURRENT_BINARY_DIR}
  ${POLKIT_INCLUDE_DIRS}
)
target_compile_definitions(corectrl_helperkiller PRIVATE ${HELPER_COMPILE_DEFINITIONS})
target_link_libraries(corectrl_helperkiller PRIVATE
  Qt6::Core
  Qt6::DBus
  spdlog::spdlog
  ${POLKIT_LIBRARIES}
  ${ATOMIC_LIB}
)


install(TARGETS corectrl_helperkiller DESTINATION "${CMAKE_INSTALL_FULL_LIBEXECDIR}/redline")

configure_file(helperkiller.service.in "${PROJECT_ORG}.helperkiller.service")
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_ORG}.helperkiller.service" DESTINATION "${DBUS_DATADIR_PREFIX_DIR}/dbus-1/system-services")

configure_file(helperkiller.conf.in "${PROJECT_ORG}.helperkiller.conf")
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_ORG}.helperkiller.conf" DESTINATION "${DBUS_DATADIR_PREFIX_DIR}/dbus-1/system.d")

configure_file(helperkiller.policy.in "${PROJECT_ORG}.helperkiller.policy")
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_ORG}.helperkiller.policy" DESTINATION "${POLKIT_POLICY_INSTALL_DIR}")


set(CMAKE_AUTOMOC ON)
add_executable(corectrl_helper
  helper.cpp
  polkit.cpp
  ${COMMON_SRC}
  ${CRYPTO_SRC}
  ${PROCESS_MONITOR_SRC}
  ${SYSTEM_CONTROL_SRC}
)
set(CMAKE_AUTOMOC OFF)
set_target_properties(corectrl_helper PROPERTIES OUTPUT_NAME redline_helper)

target_include_directories(corectrl_helper PRIVATE
  ${CMAKE_CURRENT_BINARY_DIR}
  ${Botan_INCLUDE_DIRS}
  ${POLKIT_INCLUDE_DIRS}
  ${PROJECT_SOURCE_DIR}/src
)
target_compile_definitions(corectrl_helper PRIVATE ${HELPER_COMPILE_DEFINITIONS})
target_link_libraries(corectrl_helper PRIVATE
  Qt6::Core
  Qt6::DBus
  stdc++fs
  pthread
  spdlog::spdlog
  ${Botan_LIBRARIES}
  ${POLKIT_LIBRARIES}
  ${ATOMIC_LIB}
)

install(TARGETS corectrl_helper DESTINATION "${CMAKE_INSTALL_FULL_LIBEXECDIR}/redline")

configure_file(helper.service.in "${PROJECT_ORG}.helper.service")
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_ORG}.helper.service" DESTINATION "${DBUS_DATADIR_PREFIX_DIR}/dbus-1/system-services")

configure_file(helper.conf.in "${PROJECT_ORG}.helper.conf")
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_ORG}.helper.conf" DESTINATION "${DBUS_DATADIR_PREFIX_DIR}/dbus-1/system.d")

configure_file(helper.policy.in "${PROJECT_ORG}.helper.policy")
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_ORG}.helper.policy" DESTINATION "${POLKIT_POLICY_INSTALL_DIR}")

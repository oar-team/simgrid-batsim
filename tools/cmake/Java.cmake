cmake_minimum_required(VERSION 2.8.6)

include(UseJava)

# Rules to build libsimgrid-java
#
add_library(simgrid-java SHARED ${JMSG_C_SRC})
set_target_properties(simgrid-java PROPERTIES VERSION ${libsimgrid-java_version})
if (CMAKE_VERSION VERSION_LESS "2.8.8")
  include_directories(${JNI_INCLUDE_DIRS})

  message("[Java] Try to workaround missing feature in older CMake. You should better update CMake to version 2.8.8 or above.")
  get_directory_property(CHECK_INCLUDES INCLUDE_DIRECTORIES)
else()
  get_target_property(COMMON_INCLUDES simgrid-java INCLUDE_DIRECTORIES)
  if (COMMON_INCLUDES)
    set_target_properties(simgrid-java PROPERTIES
      INCLUDE_DIRECTORIES "${COMMON_INCLUDES};${JNI_INCLUDE_DIRS}")
  else()
    set_target_properties(simgrid-java PROPERTIES
      INCLUDE_DIRECTORIES "${JNI_INCLUDE_DIRS}")
  endif()

  get_target_property(CHECK_INCLUDES simgrid-java INCLUDE_DIRECTORIES)
endif()
message("-- [Java] simgrid-java includes: ${CHECK_INCLUDES}")

target_link_libraries(simgrid-java simgrid)


if(WIN32)
  exec_program("java -d32 -version"
                OUTPUT_VARIABLE IS_32_BITS_JVM)
  STRING( FIND ${IS_32_BITS_JVM} "Error" POSITION )
  if(${POSITION} GREATER -1)
    message("POTENTIAL ERROR: Java JVM needs to be 32 bits to be able to run with Simgrid on Windows for now")
  endif()

  set_target_properties(simgrid-java PROPERTIES
    LINK_FLAGS "-Wl,--subsystem,windows,--kill-at")
  find_path(PEXPORTS_PATH NAMES pexports.exe PATHS NO_DEFAULT_PATHS)
  message(STATUS "pexports: ${PEXPORTS_PATH}")
  if(PEXPORTS_PATH)
    add_custom_command(TARGET simgrid-java POST_BUILD
      COMMAND ${PEXPORTS_PATH}/pexports.exe ${CMAKE_BINARY_DIR}/lib/simgrid-java.dll > ${CMAKE_BINARY_DIR}/lib/simgrid-java.def)
  endif(PEXPORTS_PATH)
endif()

# Rules to build simgrid.jar
#

## Files to include in simgrid.jar
##
set(SIMGRID_JAR "${CMAKE_BINARY_DIR}/simgrid.jar")
set(MANIFEST_IN_FILE "${CMAKE_HOME_DIRECTORY}/src/bindings/java/MANIFEST.MF.in")
set(MANIFEST_FILE "${CMAKE_BINARY_DIR}/src/bindings/java/MANIFEST.MF")

set(LIBSIMGRID_SO
  libsimgrid${CMAKE_SHARED_LIBRARY_SUFFIX})
set(LIBSIMGRID_JAVA_SO
  ${CMAKE_SHARED_LIBRARY_PREFIX}simgrid-java${CMAKE_SHARED_LIBRARY_SUFFIX})
set(LIBSURF_JAVA_SO
  ${CMAKE_SHARED_LIBRARY_PREFIX}surf-java${CMAKE_SHARED_LIBRARY_SUFFIX})

## Here is how to build simgrid.jar
##
if(CMAKE_VERSION VERSION_LESS "2.8.12")
  set(CMAKE_JAVA_TARGET_OUTPUT_NAME simgrid)
  add_jar(simgrid-java_jar ${JMSG_JAVA_SRC})
else()
  add_jar(simgrid-java_jar ${JMSG_JAVA_SRC} OUTPUT_NAME simgrid)
endif()

add_custom_command(
  TARGET simgrid-java_jar POST_BUILD
  COMMENT "Add the documentation into simgrid.jar..."
  DEPENDS ${MANIFEST_IN_FILE}
	  ${CMAKE_HOME_DIRECTORY}/COPYING
	  ${CMAKE_HOME_DIRECTORY}/ChangeLog
	  ${CMAKE_HOME_DIRECTORY}/ChangeLog.SimGrid-java
	  ${CMAKE_HOME_DIRECTORY}/LICENSE-LGPL-2.1
	    
  COMMAND ${CMAKE_COMMAND} -E copy ${MANIFEST_IN_FILE} ${MANIFEST_FILE}
  COMMAND ${CMAKE_COMMAND} -E echo "Specification-Version: \\\"${SIMGRID_VERSION_MAJOR}.${SIMGRID_VERSION_MINOR}.${SIMGRID_VERSION_PATCH}\\\"" >> ${MANIFEST_FILE}
  COMMAND ${CMAKE_COMMAND} -E echo "Implementation-Version: \\\"${GIT_VERSION}\\\"" >> ${MANIFEST_FILE}

  COMMAND ${Java_JAVADOC_EXECUTABLE} -quiet -d doc/javadoc -sourcepath ${CMAKE_HOME_DIRECTORY}/src/bindings/java/ org.simgrid.msg org.simgrid.surf org.simgrid.trace
  
  COMMAND ${JAVA_ARCHIVE} -uvmf ${MANIFEST_FILE} ${SIMGRID_JAR} doc/javadoc -C ${CMAKE_HOME_DIRECTORY} COPYING ChangeLog ChangeLog.SimGrid-java LICENSE-LGPL-2.1
  )

###
### Pack the java libraries into the jarfile if asked to do so
###

if(enable_lib_in_jar)
  find_program(STRIP_COMMAND strip)
  if(NOT STRIP_COMMAND)
    set(STRIP_COMMAND "cmake -E echo (strip not found)")
  endif()

  set(JAVA_NATIVE_PATH NATIVE/${CMAKE_SYSTEM_NAME}/${CMAKE_SYSTEM_PROCESSOR})
  if(${CMAKE_SYSTEM_PROCESSOR} MATCHES "^i[3-6]86$")
    set(JAVA_NATIVE_PATH NATIVE/${CMAKE_SYSTEM_NAME}/x86)
  endif()
  if(  (${CMAKE_SYSTEM_PROCESSOR} MATCHES "x86_64") OR
       (${CMAKE_SYSTEM_PROCESSOR} MATCHES "AMD64")     )
    set(JAVA_NATIVE_PATH NATIVE/${CMAKE_SYSTEM_NAME}/amd64)
  endif()

  add_custom_command(
    TARGET simgrid-java_jar POST_BUILD
    COMMENT "Add the native libs into simgrid.jar..."
    DEPENDS simgrid-java 
	    ${CMAKE_BINARY_DIR}/lib/${LIBSIMGRID_SO}
	    ${CMAKE_BINARY_DIR}/lib/${LIBSIMGRID_JAVA_SO}
	    ${CMAKE_BINARY_DIR}/lib/${LIBSURF_JAVA_SO}
	  
    COMMAND ${CMAKE_COMMAND} -E remove_directory NATIVE
    COMMAND ${CMAKE_COMMAND} -E make_directory                                     ${JAVA_NATIVE_PATH}
    COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_BINARY_DIR}/lib/${LIBSIMGRID_SO}      ${JAVA_NATIVE_PATH}
    COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_BINARY_DIR}/lib/${LIBSIMGRID_JAVA_SO} ${JAVA_NATIVE_PATH}
    COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_BINARY_DIR}/lib/${LIBSURF_JAVA_SO}    ${JAVA_NATIVE_PATH}
    COMMAND ${STRIP_COMMAND} ${JAVA_NATIVE_PATH}/${LIBSIMGRID_SO}
    COMMAND ${STRIP_COMMAND} ${JAVA_NATIVE_PATH}/${LIBSIMGRID_JAVA_SO}
    COMMAND ${STRIP_COMMAND} ${JAVA_NATIVE_PATH}/${LIBSURF_JAVA_SO}

    COMMAND ${JAVA_ARCHIVE} -uvf ${SIMGRID_JAR}  NATIVE
    COMMAND ${CMAKE_COMMAND} -E remove_directory NATIVE
    
    COMMAND ${CMAKE_COMMAND} -E echo "-- Cmake put the native code in ${JAVA_NATIVE_PATH}"
    COMMAND "${Java_JAVA_EXECUTABLE}" -classpath "${SIMGRID_JAR}" org.simgrid.NativeLib
    )
  if(MINGW)
    find_library(WINPTHREAD_DLL
      NAME winpthread winpthread-1
      PATHS C:\\MinGW C:\\MinGW64 C:\\MinGW\\bin C:\\MinGW64\\bin
    )
    add_custom_command(
      TARGET simgrid-java_jar POST_BUILD
      COMMENT "Add the MinGW libs into simgrid.jar..."
      DEPENDS ${CMAKE_BINARY_DIR}/lib/${LIBSIMGRID_SO}

      COMMAND ${CMAKE_COMMAND} -E remove_directory NATIVE
      COMMAND ${CMAKE_COMMAND} -E make_directory          ${JAVA_NATIVE_PATH}
      COMMAND ${CMAKE_COMMAND} -E copy ${WINPTHREAD_DLL}  ${JAVA_NATIVE_PATH}

      COMMAND ${JAVA_ARCHIVE} -uvf ${SIMGRID_JAR}  NATIVE
      COMMAND ${CMAKE_COMMAND} -E remove_directory NATIVE
    )
  endif(MINGW)
endif(enable_lib_in_jar)

include_directories(${JNI_INCLUDE_DIRS} ${JAVA_INCLUDE_PATH} ${JAVA_INCLUDE_PATH2})

if(enable_maintainer_mode)
  set(CMAKE_SWIG_FLAGS "-package" "org.simgrid.surf")
  set(CMAKE_SWIG_OUTDIR "${CMAKE_HOME_DIRECTORY}/src/bindings/java/org/simgrid/surf")

  set_source_files_properties(${JSURF_SWIG_SRC} PROPERTIES CPLUSPLUS 1)

  swig_add_module(surf-java java ${JSURF_SWIG_SRC} ${JSURF_JAVA_C_SRC})
  swig_link_libraries(surf-java simgrid)
else()
  add_library(surf-java SHARED ${JSURF_C_SRC})
  target_link_libraries(surf-java simgrid)
endif()

set_target_properties(surf-java PROPERTIES SKIP_BUILD_RPATH ON)
set_target_properties(simgrid-java PROPERTIES SKIP_BUILD_RPATH ON)

add_dependencies(simgrid-java surf-java)
add_dependencies(simgrid-java_jar surf-java)

if(WIN32)
  set_target_properties(surf-java PROPERTIES
    LINK_FLAGS "-Wl,--subsystem,windows,--kill-at")
  if(PEXPORTS_PATH)
    add_custom_command(TARGET surf-java POST_BUILD
      COMMAND ${PEXPORTS_PATH}/pexports.exe ${CMAKE_BINARY_DIR}/lib/surf-java.dll > ${CMAKE_BINARY_DIR}/lib/surf-java.def)
  endif(PEXPORTS_PATH)
endif()
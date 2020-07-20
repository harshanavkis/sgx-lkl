# musl is used as libc in userspace.

include_guard(GLOBAL)
include(ExternalProject)
include(cmake/components/common.cmake)
include(cmake/components/lkl.cmake)

# Flags for building musl itself.
set(CFLAGS 
	${CMAKE_C_FLAGS_BUILD_TYPE}
	${COMMON_ENCLAVE_CFLAGS}
	)
list(JOIN CFLAGS " " CFLAGS)

set(MUSL_LIBNAMES
	libc.a
	libcrypt.a
	libdl.a
	libm.a
	libpthread.a
	libresolv.a
	librt.a
	libutil.a
	libxnet.a
	# libld.a is manually assembled from dlstart.c/dynlink.c, see below.
	libld.a
)
list(TRANSFORM MUSL_LIBNAMES PREPEND "<INSTALL_DIR>/lib/" OUTPUT_VARIABLE MUSL_BYPRODUCTS)

ExternalProject_Add(sgxlkl-musl-ep
	# For now, this builds host-musl, while the relayering is in progress.
	# Our musl fork has dependencies to SGX-LKL headers, OE, etc.
	# TODO change to /sgx-lkl-musl
	SOURCE_DIR "${PROJECT_SOURCE_DIR}/host-musl"
	#SOURCE_DIR "${PROJECT_SOURCE_DIR}/sgx-lkl-musl"
	CONFIGURE_COMMAND "<SOURCE_DIR>/configure" 
		"CC=${CMAKE_C_COMPILER}"
		"CFLAGS=${CFLAGS}"
		"--lklheaderdir=${LKL_INCLUDE_DIR}"
		"--disable-shared"
		"--prefix=<INSTALL_DIR>"
		"--syslibdir=<INSTALL_DIR>/lib"
		# TODO remove
		"--lkllib=/dev/null"
		"--sgxlklincludes=/dev/null"
		"--sgxlkllib=/dev/null"
	BUILD_COMMAND make -j ${NUMBER_OF_CORES}
	# dlstart.c/dynlink.c are only part of libc.so but we need them as static variant.
	COMMAND make -j ${NUMBER_OF_CORES} "obj/ldso/dlstart.lo" "obj/ldso/dynlink.lo"
	COMMAND ar rc "lib/libld.a" "obj/ldso/dlstart.lo" "obj/ldso/dynlink.lo"
	INSTALL_COMMAND make install
	COMMAND ${CMAKE_COMMAND} -E copy_if_different "<BINARY_DIR>/lib/libld.a" "<INSTALL_DIR>/lib"
	# TODO Replace atomic.h includes with C11 stdatomic.h, then remove the following copy.
	COMMAND ${CMAKE_COMMAND} -E copy_if_different 
		"<SOURCE_DIR>/src/internal/atomic.h"
		"<SOURCE_DIR>/arch/x86_64/atomic_arch.h"
		"<INSTALL_DIR>/include"
	BUILD_BYPRODUCTS "${MUSL_BYPRODUCTS}"
	BUILD_ALWAYS TRUE
	DEPENDS sgx-lkl::lkl-headers
	${COMMON_EP_OPTIONS}
)
ExternalProject_Get_property(sgxlkl-musl-ep INSTALL_DIR)
list(TRANSFORM MUSL_LIBNAMES PREPEND "${INSTALL_DIR}/lib/" OUTPUT_VARIABLE MUSL_LIBRARIES)
set(MUSL_INCLUDE_DIR "${INSTALL_DIR}/include")

add_library(sgxlkl-musl INTERFACE)
target_compile_options(sgxlkl-musl INTERFACE "-nostdinc")
target_include_directories(sgxlkl-musl SYSTEM INTERFACE "${MUSL_INCLUDE_DIR}")
target_link_libraries(sgxlkl-musl INTERFACE "${MUSL_LIBRARIES}")
add_dependencies(sgxlkl-musl sgxlkl-musl-ep)
add_library(sgx-lkl::musl ALIAS sgxlkl-musl)

# For third-party Make-based projects. See libc.cmake.
set(MUSL_CFLAGS "-nostdinc -isystem ${MUSL_INCLUDE_DIR}")
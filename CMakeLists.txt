cmake_minimum_required(VERSION 3.5)

project(boost-cmake LANGUAGES CXX C)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_C_STANDARD 11)

option(ENABLE_ADDRESS_SANITIZER "enable address sanitizer" ON)

if (CMAKE_SYSTEM_PROCESSOR STREQUAL "AMD64")
    set(TARGET_PROCESSOR "x86_64")
elseif (CMAKE_SYSTEM_PROCESSOR STREQUAL "x86_64")
    set(TARGET_PROCESSOR "x86_64")
elseif (CMAKE_SYSTEM_PROCESSOR STREQUAL "aarch64")
    set(TARGET_PROCESSOR "aarch64")
else()
    message(FATAL_ERROR "Unsupported architecture ${CMAKE_HOST_SYSTEM_PROCESSOR}")
endif()

if ("${CMAKE_SYSTEM_NAME}" STREQUAL "Linux")
    set(PLATFORM_POSIX 1)
    set(PLATFORM_LINUX 1)
elseif("${CMAKE_SYSTEM_NAME}" STREQUAL "Darwin")
    set(PLATFORM_POSIX 1)
    set(PLATFORM_MACOS 1)
elseif("${CMAKE_SYSTEM_NAME}" STREQUAL "Windows")
     set(PLATFORM_WINDOWS 1)
else()
endif()

set(HAS_THIRDPARTY_BOOST ON PARENT_SCOPE)

function(boostMain)
    set(BOOST_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/boost")

    generateIcu()
    generateZlib()
    generateBzip2()
    generateZstd()
    generateLzma()

    importBoostInterfaceLibraries()

    generateBoostLocale()
    generateBoostContext()
    generateBoostCoroutine()
    generateBoostFilesystem()
    generateBoostRegex()
    generateBoostThread()
    generateBoostAtomic()
    generateBoostDateTime()
    generateBoostNumericConversion()
    generateBoostContainer()
    generateBoostMath()
    generateBoostChrono()
    generateBoostException()
    generateBoostSerialization()
    generateBoostRandom()
    generateBoostIostreams()
    generateBoostWinapi()
    generateBoostEndian()

    if(ENABLE_VALGRIND_SUPPORT)
        set(valgrind_header_possible_paths
            /usr/include/valgrind
            /usr/local/include/valgrind
            )

        find_file(VALGRIND_HEADER_PATH valgrind.h HINTS ${valgrind_header_possible_paths})

        if("${VALGRIND_HEADER_PATH}" STREQUAL "VALGRIND_HEADER_PATH-NOTFOUND")
            message(FATAL_ERROR "Could not find valgrind.h. Please install Valgrind and provide the path to its header.")
        else()
            message(STATUS "Found valgrind header: ${VALGRIND_HEADER_PATH}")
        endif()

        # We copy the header into the build folder, so that if it's installed in the system
        # we are not forced to include a folder which can contain other headers we don't want.
        set(valgrind_header_dest "${CMAKE_CURRENT_BINARY_DIR}/external_headers/valgrind/valgrind.h")

        add_custom_target(provide_valgrind_header DEPENDS "${valgrind_header_dest}")

        add_custom_command(OUTPUT "${valgrind_header_dest}"
            COMMAND "${CMAKE_COMMAND}" -E copy "${VALGRIND_HEADER_PATH}" "${valgrind_header_dest}"
            DEPENDS "${VALGRIND_HEADER_PATH}"
            )

        add_dependencies(thirdparty_boost_coroutine provide_valgrind_header)
        add_dependencies(thirdparty_boost_coroutine2 provide_valgrind_header)
        add_dependencies(thirdparty_boost_context provide_valgrind_header)

        target_compile_definitions(thirdparty_boost_coroutine PUBLIC
            BOOST_USE_VALGRIND
            )
        target_include_directories(thirdparty_boost_coroutine SYSTEM PUBLIC
            "${CMAKE_CURRENT_BINARY_DIR}/external_headers"
            )

        target_compile_definitions(thirdparty_boost_coroutine2 INTERFACE
            BOOST_USE_VALGRIND
            )
        target_include_directories(thirdparty_boost_coroutine2 SYSTEM INTERFACE
            "${CMAKE_CURRENT_BINARY_DIR}/external_headers"
            )

        target_compile_definitions(thirdparty_boost_context PUBLIC
            BOOST_USE_VALGRIND
            )
        target_include_directories(thirdparty_boost_context SYSTEM PUBLIC
            "${CMAKE_CURRENT_BINARY_DIR}/external_headers"
            )
    endif()

    if(ENABLE_ADDRESS_SANITIZER)
        # Support ASAN within coroutine, context and coroutines2.
        # Note that __ucontext__ is orders of magnitude slower than __fcontext__.
        target_compile_definitions(thirdparty_boost_coroutine PUBLIC
            BOOST_USE_UCONTEXT
            BOOST_USE_ASAN
            )
        target_compile_definitions(thirdparty_boost_coroutine2 INTERFACE
            BOOST_USE_UCONTEXT
            BOOST_USE_ASAN
            )
        target_compile_definitions(thirdparty_boost_context PUBLIC
            BOOST_USE_UCONTEXT
            BOOST_USE_ASAN
            )
    endif()

    add_library(thirdparty_boost INTERFACE)

    target_link_libraries(thirdparty_boost INTERFACE
        thirdparty_boost_coroutine
        thirdparty_boost_filesystem
        thirdparty_boost_regex
        thirdparty_boost_locale
        thirdparty_boost_format
        thirdparty_boost_variant
        thirdparty_boost_serialization
        thirdparty_boost_coroutine2
        thirdparty_boost_propertytree
        thirdparty_boost_asio
        thirdparty_boost_uuid
        thirdparty_boost_beast
        thirdparty_boost_xpressive
        thirdparty_boost_process
        thirdparty_boost_iostreams
        thirdparty_boost_winapi
        thirdparty_boost_circularbuffer
        thirdparty_boost_endian
        thirdparty_boost_thread
        thirdparty_boost_align
        )
endfunction()

function(generateIcu)
    set(library_root "${CMAKE_CURRENT_SOURCE_DIR}/icu/icu4c/source")
    add_library(thirdparty_icu INTERFACE)

    target_include_directories(thirdparty_icu SYSTEM INTERFACE
        "${library_root}/i18n"
        "${library_root}/common"
        )

endfunction()

function(generateZlib)
    set(library_root "${CMAKE_CURRENT_SOURCE_DIR}/zlib")
    add_library(thirdparty_zlib
        "${library_root}/inflate.c"
        "${library_root}/compress.c"
        "${library_root}/deflate.c"
        "${library_root}/gzread.c"
        "${library_root}/crc32.c"
        "${library_root}/infback.c"
        "${library_root}/zutil.c"
        "${library_root}/gzlib.c"
        "${library_root}/inftrees.c"
        "${library_root}/uncompr.c"
        "${library_root}/gzwrite.c"
        "${library_root}/trees.c"
        "${library_root}/gzclose.c"
        "${library_root}/inffast.c"
        "${library_root}/adler32.c"
        )
    target_compile_definitions(thirdparty_zlib PRIVATE PIC)

    if(DEFINED PLATFORM_POSIX)
        target_compile_definitions(thirdparty_zlib PRIVATE
            _LARGEFILE64_SOURCE=1
            HAVE_HIDDEN
            HAVE_UNISID_H
            HAVE_STDARG_H
            )
    endif()

    target_include_directories(thirdparty_zlib PRIVATE "${library_root}")
    target_include_directories(thirdparty_zlib SYSTEM INTERFACE "${library_root}")

endfunction()

function(generateZstd)
    set(library_root "${CMAKE_CURRENT_SOURCE_DIR}/zstd/lib")
    add_library(thirdparty_zstd
        "${library_root}/compress/zstd_compress_superblock.c"
        "${library_root}/compress/zstdmt_compress.c"
        "${library_root}/compress/zstd_double_fast.c"
        "${library_root}/compress/zstd_fast.c"
        "${library_root}/compress/zstd_compress_sequences.c"
        "${library_root}/compress/zstd_ldm.c"
        "${library_root}/compress/hist.c"
        "${library_root}/compress/zstd_compress.c"
        "${library_root}/compress/zstd_lazy.c"
        "${library_root}/compress/zstd_compress_literals.c"
        "${library_root}/compress/huf_compress.c"
        "${library_root}/compress/zstd_opt.c"
        "${library_root}/compress/fse_compress.c"
        "${library_root}/dictBuilder/cover.c"
        "${library_root}/dictBuilder/divsufsort.c"
        "${library_root}/dictBuilder/fastcover.c"
        "${library_root}/dictBuilder/zdict.c"
        "${library_root}/decompress/zstd_ddict.c"
        "${library_root}/decompress/huf_decompress.c"
        "${library_root}/decompress/zstd_decompress.c"
        "${library_root}/decompress/zstd_decompress_block.c"
        "${library_root}/common/entropy_common.c"
        "${library_root}/common/fse_decompress.c"
        "${library_root}/common/pool.c"
        "${library_root}/common/threading.c"
        "${library_root}/common/zstd_common.c"
        "${library_root}/common/error_private.c"
        "${library_root}/deprecated/zbuff_common.c"
        "${library_root}/deprecated/zbuff_decompress.c"
        "${library_root}/deprecated/zbuff_compress.c"
        )

    target_compile_definitions(thirdparty_zstd PRIVATE
        ZSTD_MULTITHREAD
        XXH_NAMESPACE=zstd
        XXH_PRIVATE_API
        )

    if(DEFINED PLATFORM_WINDOWS)
        target_compile_definitions(thirdparty_zstd PRIVATE
            ZSTD_HEAPNODE=0
            _CRT_SECURE_NO_WARNINGS
            )
    endif()

    target_include_directories(thirdparty_zstd PRIVATE
        "${library_root}"
        "${library_root}/common"
        )

    target_include_directories(thirdparty_zstd SYSTEM INTERFACE
        "${library_root}"
        "${library_root}/common"
        )
endfunction()

function(generateBzip2)

    set(library_root "${CMAKE_CURRENT_SOURCE_DIR}/bzip2")

      add_library(thirdparty_bzip2
        "${library_root}/randtable.c"
        "${library_root}/decompress.c"
        "${library_root}/bzlib.c"
        "${library_root}/blocksort.c"
        "${library_root}/compress.c"
        "${library_root}/huffman.c"
        "${library_root}/crctable.c"
      )

      target_compile_definitions(thirdparty_bzip2 PRIVATE
        _FILE_OFFSET_BITS=64
      )

      target_link_libraries(thirdparty_bzip2 PRIVATE

      )

      target_include_directories(thirdparty_bzip2 PRIVATE
        "${library_root}"
      )

      target_include_directories(thirdparty_bzip2 SYSTEM INTERFACE
        "${library_root}"
      )

endfunction()

function(generateLzma)
    set(library_root "${CMAKE_CURRENT_SOURCE_DIR}/xz")

    add_library(thirdparty_lzma
        "${library_root}/src/common/tuklib_cpucores.c"
        "${library_root}/src/common/tuklib_exit.c"
        "${library_root}/src/common/tuklib_physmem.c"
        "${library_root}/src/common/tuklib_progname.c"
        "${library_root}/src/liblzma/check/check.c"
        "${library_root}/src/liblzma/check/crc32_fast.c"
        "${library_root}/src/liblzma/check/crc32_table.c"
        "${library_root}/src/liblzma/check/crc64_fast.c"
        "${library_root}/src/liblzma/check/crc64_table.c"
        "${library_root}/src/liblzma/check/sha256.c"
        "${library_root}/src/liblzma/common/alone_decoder.c"
        "${library_root}/src/liblzma/common/alone_encoder.c"
        "${library_root}/src/liblzma/common/auto_decoder.c"
        "${library_root}/src/liblzma/common/block_buffer_decoder.c"
        "${library_root}/src/liblzma/common/block_buffer_encoder.c"
        "${library_root}/src/liblzma/common/block_decoder.c"
        "${library_root}/src/liblzma/common/block_encoder.c"
        "${library_root}/src/liblzma/common/block_header_decoder.c"
        "${library_root}/src/liblzma/common/block_header_encoder.c"
        "${library_root}/src/liblzma/common/block_util.c"
        "${library_root}/src/liblzma/common/common.c"
        "${library_root}/src/liblzma/common/easy_buffer_encoder.c"
        "${library_root}/src/liblzma/common/easy_decoder_memusage.c"
        "${library_root}/src/liblzma/common/easy_encoder.c"
        "${library_root}/src/liblzma/common/easy_encoder_memusage.c"
        "${library_root}/src/liblzma/common/easy_preset.c"
        "${library_root}/src/liblzma/common/erofs_decoder.c"
        "${library_root}/src/liblzma/common/erofs_encoder.c"
        "${library_root}/src/liblzma/common/file_info.c"
        "${library_root}/src/liblzma/common/filter_buffer_decoder.c"
        "${library_root}/src/liblzma/common/filter_buffer_encoder.c"
        "${library_root}/src/liblzma/common/filter_common.c"
        "${library_root}/src/liblzma/common/filter_decoder.c"
        "${library_root}/src/liblzma/common/filter_encoder.c"
        "${library_root}/src/liblzma/common/filter_flags_decoder.c"
        "${library_root}/src/liblzma/common/filter_flags_encoder.c"
        "${library_root}/src/liblzma/common/hardware_cputhreads.c"
        "${library_root}/src/liblzma/common/hardware_physmem.c"
        "${library_root}/src/liblzma/common/index.c"
        "${library_root}/src/liblzma/common/index_decoder.c"
        "${library_root}/src/liblzma/common/index_encoder.c"
        "${library_root}/src/liblzma/common/index_hash.c"
        "${library_root}/src/liblzma/common/outqueue.c"
        "${library_root}/src/liblzma/common/stream_buffer_decoder.c"
        "${library_root}/src/liblzma/common/stream_buffer_encoder.c"
        "${library_root}/src/liblzma/common/stream_decoder.c"
        "${library_root}/src/liblzma/common/stream_encoder.c"
        "${library_root}/src/liblzma/common/stream_encoder_mt.c"
        "${library_root}/src/liblzma/common/stream_flags_common.c"
        "${library_root}/src/liblzma/common/stream_flags_decoder.c"
        "${library_root}/src/liblzma/common/stream_flags_encoder.c"
        "${library_root}/src/liblzma/common/vli_decoder.c"
        "${library_root}/src/liblzma/common/vli_encoder.c"
        "${library_root}/src/liblzma/common/vli_size.c"
        "${library_root}/src/liblzma/delta/delta_common.c"
        "${library_root}/src/liblzma/delta/delta_decoder.c"
        "${library_root}/src/liblzma/lz/lz_decoder.c"
        "${library_root}/src/liblzma/lz/lz_encoder.c"
        "${library_root}/src/liblzma/lz/lz_encoder_mf.c"
        "${library_root}/src/liblzma/lzma/fastpos_table.c"
        "${library_root}/src/liblzma/lzma/lzma2_decoder.c"
        "${library_root}/src/liblzma/lzma/lzma2_encoder.c"
        "${library_root}/src/liblzma/lzma/lzma_decoder.c"
        "${library_root}/src/liblzma/lzma/lzma_encoder.c"
        "${library_root}/src/liblzma/lzma/lzma_encoder_optimum_fast.c"
        "${library_root}/src/liblzma/lzma/lzma_encoder_optimum_normal.c"
        "${library_root}/src/liblzma/lzma/lzma_encoder_presets.c"
        "${library_root}/src/liblzma/rangecoder/price_table.c"
        "${library_root}/src/liblzma/simple/arm.c"
        "${library_root}/src/liblzma/simple/armthumb.c"
        "${library_root}/src/liblzma/simple/ia64.c"
        "${library_root}/src/liblzma/simple/powerpc.c"
        "${library_root}/src/liblzma/simple/simple_coder.c"
        "${library_root}/src/liblzma/simple/simple_decoder.c"
        "${library_root}/src/liblzma/simple/simple_encoder.c"
        "${library_root}/src/liblzma/simple/sparc.c"
        "${library_root}/src/liblzma/simple/x86.c"
        "${library_root}/src/lzmainfo/lzmainfo.c"
        "${library_root}/src/common/tuklib_physmem.c"
        )

   target_compile_definitions(thirdparty_lzma PRIVATE
       HAVE_CONFIG_H
       TUKLIB_GETTEXT=0
       LZMADEC
       PIC
       )

   target_compile_definitions(thirdparty_lzma PUBLIC
       LZMA_API_STATIC
       )

   target_include_directories(thirdparty_lzma PRIVATE
       "${library_root}/src"
       "${library_root}/src/liblzma"
       "${library_root}/src/liblzma/delta"
       "${library_root}/src/liblzma/rangecoder"
       "${library_root}/src/liblzma/simple"
       "${library_root}/src/liblzma/common"
       "${library_root}/src/liblzma/api"
       "${library_root}/src/liblzma/lz"
       "${library_root}/src/liblzma/check"
       "${library_root}/src/liblzma/lzma"
       "${library_root}/src/common"
       "${library_root}/lib"
       )

   if (DEFINED PLATFORM_LINUX)
       target_include_directories(thirdparty_lzma PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/config/xz/${TARGET_PROCESSOR}/linux)
   elseif (DEFINED PLATFORM_MACOS)
       target_include_directories(thirdparty_lzma PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/config/xz/${TARGET_PROCESSOR}/darwin)
   elseif (DEFINED PLATFORM_WINDOWS)
       message(FATAL_ERROR "lzam unsupported windows system.")
   endif()

   target_include_directories(thirdparty_lzma SYSTEM INTERFACE "${library_root}/src/liblzma/api")
endfunction()

function(generateBoostSerialization)
    set(library_root "${BOOST_ROOT}/libs/serialization")

    add_library(thirdparty_boost_serialization STATIC
        "${library_root}/src/archive_exception.cpp"
        "${library_root}/src/basic_archive.cpp"
        "${library_root}/src/basic_iarchive.cpp"
        "${library_root}/src/basic_iserializer.cpp"
        "${library_root}/src/basic_oarchive.cpp"
        "${library_root}/src/basic_oserializer.cpp"
        "${library_root}/src/basic_pointer_iserializer.cpp"
        "${library_root}/src/basic_pointer_oserializer.cpp"
        "${library_root}/src/basic_serializer_map.cpp"
        "${library_root}/src/basic_text_iprimitive.cpp"
        "${library_root}/src/basic_text_oprimitive.cpp"
        "${library_root}/src/basic_text_wiprimitive.cpp"
        "${library_root}/src/basic_text_woprimitive.cpp"
        "${library_root}/src/basic_xml_archive.cpp"
        "${library_root}/src/basic_xml_grammar.ipp"
        "${library_root}/src/binary_iarchive.cpp"
        "${library_root}/src/binary_oarchive.cpp"
        "${library_root}/src/binary_wiarchive.cpp"
        "${library_root}/src/binary_woarchive.cpp"
        "${library_root}/src/codecvt_null.cpp"
        "${library_root}/src/extended_type_info.cpp"
        "${library_root}/src/extended_type_info_no_rtti.cpp"
        "${library_root}/src/extended_type_info_typeid.cpp"
        "${library_root}/src/polymorphic_binary_iarchive.cpp"
        "${library_root}/src/polymorphic_binary_oarchive.cpp"
        "${library_root}/src/polymorphic_iarchive.cpp"
        "${library_root}/src/polymorphic_oarchive.cpp"
        "${library_root}/src/polymorphic_text_iarchive.cpp"
        "${library_root}/src/polymorphic_text_oarchive.cpp"
        "${library_root}/src/polymorphic_text_wiarchive.cpp"
        "${library_root}/src/polymorphic_text_woarchive.cpp"
        "${library_root}/src/polymorphic_xml_iarchive.cpp"
        "${library_root}/src/polymorphic_xml_oarchive.cpp"
        "${library_root}/src/polymorphic_xml_wiarchive.cpp"
        "${library_root}/src/polymorphic_xml_woarchive.cpp"
        "${library_root}/src/stl_port.cpp"
        "${library_root}/src/text_iarchive.cpp"
        "${library_root}/src/text_oarchive.cpp"
        "${library_root}/src/text_wiarchive.cpp"
        "${library_root}/src/text_woarchive.cpp"
        "${library_root}/src/utf8_codecvt_facet.cpp"
        "${library_root}/src/void_cast.cpp"
        "${library_root}/src/xml_archive_exception.cpp"
        "${library_root}/src/xml_grammar.cpp"
        "${library_root}/src/xml_iarchive.cpp"
        "${library_root}/src/xml_oarchive.cpp"
        "${library_root}/src/xml_wgrammar.cpp"
        "${library_root}/src/xml_wiarchive.cpp"
        "${library_root}/src/xml_woarchive.cpp"
        )

    target_include_directories(thirdparty_boost_serialization SYSTEM PUBLIC
        "${library_root}/include"
        )

    target_link_libraries(thirdparty_boost_serialization PUBLIC
        thirdparty_boost_assert
        thirdparty_boost_core
        thirdparty_boost_integer
        thirdparty_boost_mpl
        thirdparty_boost_utility
        thirdparty_boost_typetraits
        thirdparty_boost_io
        thirdparty_boost_smartptr
        thirdparty_boost_iterator
        thirdparty_boost_spirit
        thirdparty_boost_array
        thirdparty_boost_function
        )

    target_link_libraries(thirdparty_boost_serialization PRIVATE

        )
endfunction()

function(generateBoostNumericConversion)
    set(library_root "${BOOST_ROOT}/libs/numeric/conversion")

    add_library(thirdparty_boost_numericconversion INTERFACE)

    target_include_directories(thirdparty_boost_numericconversion SYSTEM INTERFACE
        "${library_root}/include"
        )

    target_link_libraries(thirdparty_boost_numericconversion INTERFACE
        thirdparty_boost_config
        )
endfunction()

function(generateBoostEndian)
    set(library_root "${BOOST_ROOT}/libs/endian")

    add_library(thirdparty_boost_endian INTERFACE)

    target_include_directories(thirdparty_boost_endian SYSTEM INTERFACE
        "${library_root}/include"
        )

    target_link_libraries(thirdparty_boost_endian INTERFACE
        thirdparty_boost_config
        )
endfunction()

function(generateBoostRandom)
    set(library_root "${BOOST_ROOT}/libs/random")

    add_library(thirdparty_boost_random STATIC
        "${library_root}/src/random_device.cpp"
        )

    target_include_directories(thirdparty_boost_random SYSTEM PUBLIC
        "${library_root}/include"
        )

    target_link_libraries(thirdparty_boost_random PUBLIC
        thirdparty_boost_core
        thirdparty_boost_system
        thirdparty_boost_throwexception
        thirdparty_boost_winapi
        )

    target_link_libraries(thirdparty_boost_random PRIVATE

        )
endfunction()

function(importBoostInterfaceLibrary folder_name)

    set(library_root "${BOOST_ROOT}/libs/${folder_name}")

    string(REPLACE "_" "" target_name "${folder_name}")
    set(target_name "thirdparty_boost_${target_name}")
    message(STATUS "import boost interface library: ${target_name}")
    add_library("${target_name}" INTERFACE)

    message(STATUS "  |- ${library_root}/include")

    target_include_directories("${target_name}" SYSTEM INTERFACE
        "${library_root}/include"
        )

    if("${folder_name}" STREQUAL "uuid")
        target_compile_definitions(${target_name} INTERFACE
            BOOST_UUID_RANDOM_PROVIDER_FORCE_POSIX)
    endif()

    if(DEFINED PLATFORM_WINDOWS)
        if("${folder_name}" STREQUAL "asio")
            target_compile_definitions(${target_name} INTERFACE
                BOOST_ASIO_WINDOWS
                )
        endif()
    endif()

    foreach(additional_dependency ${ARGN})

        if(additional_dependency MATCHES "^thirdparty_")
            target_link_libraries("${target_name}" INTERFACE
                "${additional_dependency}"
                )
        else()
            string(REPLACE "_" "" additional_dependency "${additional_dependency}")

            target_link_libraries("${target_name}" INTERFACE
                "thirdparty_boost_${additional_dependency}"
                )
        endif()
    endforeach()
endfunction()

function(importBoostInterfaceLibraries)
    set(library_descriptor_list
        "fusion:config"
        "logic:config"
        "conversion:config"
        "xpressive:proto,fusion,conversion"
        "proto:config"
        "beast:mp11,logic"
        "mp11:config"
        "unordered:config"
        "function_types:config"
        "tti:function_types"
        "uuid:random,tti"
        "any:config"
        "foreach:config"
        "multi_index:foreach"
        "property_tree:any,multi_index"
        "spirit:optional"
        "algorithm:config"
        "variant:config"
        "format:config"
        "optional:config"
        "type_index:container_hash"
        "coroutine2:container_hash"
        "function:type_index,bind"
        "ratio:type_traits,core,integer"
        "multiprecision:config"
        "tokenizer:config"
        "intrusive:config"
        "array:config"
        "range:iterator,concept_check"
        "concept_check:config"
        "utility:core"
        "throw_exception:assert"
        "move:assert,static_assert"
        "container_hash:detail"
        "io:config"
        "detail:config"
        "mpl:preprocessor"
        "static_assert:config"
        "core:config"
        "type_traits:static_assert,assert"
        "preprocessor:config"
        "bind:config"
        "smart_ptr:predef,throw_exception,move"
        "assert:config"
        "iterator:mpl,assert,detail"
        "predef:config"
        "integer:config"
        "lexical_cast:range,numeric_conversion,integer,array,container,math"
        "system:config"
        "tuple:config"
        "process:config"
        "circular_buffer:config"
        "scope_exit:typeof,config"
        "typeof:config"
        "align:config"
        )

    if (HAS_THIRDPARTY_OPENSSL)
        message(STATUS "boost_asio base on openssl")
        list(APPEND library_descriptor_list "asio:config,thirdparty_openssl")
    else()
        list(APPEND library_descriptor_list "asio:config")
    endif()

    add_library(thirdparty_boost_config INTERFACE)
    target_include_directories(thirdparty_boost_config SYSTEM INTERFACE
        "${BOOST_ROOT}/libs/config/include"
        )

    foreach(library_descriptor ${library_descriptor_list})
        string(REPLACE ":" ";" temp "${library_descriptor}")
        list(GET temp 0 library_name)
        list(GET temp 1 library_dependency_list)

        string(REPLACE "," ";" library_dependency_list "${library_dependency_list}")

        importBoostInterfaceLibrary("${library_name}" ${library_dependency_list})
    endforeach()
endfunction()

function(generateBoostWinapi)
    add_library(thirdparty_boost_winapi INTERFACE)

    set(library_root "${BOOST_ROOT}/libs/winapi")

    target_include_directories(thirdparty_boost_winapi SYSTEM INTERFACE
        "${library_root}/include"
        )

    if(DEFINED PLATFORM_WINDOWS)
        target_compile_definitions(thirdparty_boost_winapi INTERFACE
            BOOST_USE_WINDOWS_H
            NOMINMAX
            )
    endif()

    target_link_libraries(thirdparty_boost_winapi INTERFACE
        thirdparty_boost_config
        thirdparty_boost_predef
        )
endfunction()

function(generateBoostLocale)
    set(library_root "${BOOST_ROOT}/libs/locale")

    add_library(thirdparty_boost_locale STATIC
        #"${library_root}/src/encoding/codepage.cpp"
        "${library_root}/src/icu/boundary.cpp"
        "${library_root}/src/icu/codecvt.cpp"
        "${library_root}/src/icu/collator.cpp"
        "${library_root}/src/icu/conversion.cpp"
        "${library_root}/src/icu/date_time.cpp"
        "${library_root}/src/icu/formatter.cpp"
        "${library_root}/src/icu/icu_backend.cpp"
        "${library_root}/src/icu/numeric.cpp"
        "${library_root}/src/icu/time_zone.cpp"
        "${library_root}/src/shared/date_time.cpp"
        "${library_root}/src/shared/format.cpp"
        "${library_root}/src/shared/formatting.cpp"
        "${library_root}/src/shared/generator.cpp"
        "${library_root}/src/shared/ids.cpp"
        "${library_root}/src/shared/localization_backend.cpp"
        "${library_root}/src/shared/message.cpp"
        "${library_root}/src/shared/mo_lambda.cpp"
        "${library_root}/src/std/codecvt.cpp"
        "${library_root}/src/std/collate.cpp"
        "${library_root}/src/std/converter.cpp"
        "${library_root}/src/std/numeric.cpp"
        "${library_root}/src/std/std_backend.cpp"
        "${library_root}/src/util/codecvt_converter.cpp"
        "${library_root}/src/util/default_locale.cpp"
        "${library_root}/src/util/gregorian.cpp"
        "${library_root}/src/util/info.cpp"
        "${library_root}/src/util/locale_data.cpp"
        )

    if(DEFINED PLATFORM_POSIX)
        target_sources(thirdparty_boost_locale PRIVATE
            "${library_root}/src/posix/codecvt.cpp"
            "${library_root}/src/posix/collate.cpp"
            "${library_root}/src/posix/converter.cpp"
            "${library_root}/src/posix/numeric.cpp"
            "${library_root}/src/posix/posix_backend.cpp"
            )

    elseif(DEFINED PLATFORM_WINDOWS)
        target_sources(thirdparty_boost_locale PRIVATE
            "${library_root}/src/win32/collate.cpp"
            "${library_root}/src/win32/converter.cpp"
            "${library_root}/src/win32/lcid.cpp"
            "${library_root}/src/win32/numeric.cpp"
            "${library_root}/src/win32/win_backend.cpp"
            )
    endif()

    target_include_directories(thirdparty_boost_locale SYSTEM PUBLIC
        "${library_root}/include"
        )

    target_include_directories(thirdparty_boost_locale PRIVATE
        "${library_root}/src"
        "${library_root}/src/encoding"
        "${library_root}/src/icu"
        "${library_root}/src/shared"
        "${library_root}/src/std"
        "${library_root}/src/util"
        )

    target_link_libraries(thirdparty_boost_locale PUBLIC
        thirdparty_boost_assert
        thirdparty_boost_iterator
        thirdparty_boost_typetraits
        thirdparty_boost_core
        thirdparty_boost_thread
        thirdparty_boost_unordered
        thirdparty_icu
        )

    target_link_libraries(thirdparty_boost_locale PRIVATE

        )
endfunction()

function(generateBoostException)
    set(library_root "${BOOST_ROOT}/libs/exception")

    add_library(thirdparty_boost_exception STATIC
        "${library_root}/src/clone_current_exception_non_intrusive.cpp"
        )

    target_include_directories(thirdparty_boost_exception SYSTEM PUBLIC
        "${library_root}/include"
        )

    target_link_libraries(thirdparty_boost_exception PUBLIC
        thirdparty_boost_config
        )

    target_link_libraries(thirdparty_boost_exception PRIVATE

        )
endfunction()

function(generateBoostChrono)
    set(library_root "${BOOST_ROOT}/libs/chrono")

    add_library(thirdparty_boost_chrono STATIC
        "${library_root}/src/chrono.cpp"
        "${library_root}/src/process_cpu_clocks.cpp"
        "${library_root}/src/thread_clock.cpp"
        )

    target_include_directories(thirdparty_boost_chrono SYSTEM PUBLIC
        "${library_root}/include"
        )

    target_link_libraries(thirdparty_boost_chrono PUBLIC
        thirdparty_boost_predef
        thirdparty_boost_mpl
        thirdparty_boost_ratio
        thirdparty_boost_system
        thirdparty_boost_throwexception
        thirdparty_boost_utility
        thirdparty_boost_winapi
        )

    target_link_libraries(thirdparty_boost_chrono PRIVATE

        )
endfunction()

function(generateBoostMath)
    set(library_root "${BOOST_ROOT}/libs/math")

    add_library(thirdparty_boost_math STATIC
        "${library_root}/src/tr1"
        "${library_root}/src/tr1/acosh.cpp"
        "${library_root}/src/tr1/acoshf.cpp"
        "${library_root}/src/tr1/acoshl.cpp"
        "${library_root}/src/tr1/asinh.cpp"
        "${library_root}/src/tr1/asinhf.cpp"
        "${library_root}/src/tr1/asinhl.cpp"
        "${library_root}/src/tr1/assoc_laguerre.cpp"
        "${library_root}/src/tr1/assoc_laguerref.cpp"
        "${library_root}/src/tr1/assoc_laguerrel.cpp"
        "${library_root}/src/tr1/assoc_legendre.cpp"
        "${library_root}/src/tr1/assoc_legendref.cpp"
        "${library_root}/src/tr1/assoc_legendrel.cpp"
        "${library_root}/src/tr1/atanh.cpp"
        "${library_root}/src/tr1/atanhf.cpp"
        "${library_root}/src/tr1/atanhl.cpp"
        "${library_root}/src/tr1/beta.cpp"
        "${library_root}/src/tr1/betaf.cpp"
        "${library_root}/src/tr1/betal.cpp"
        "${library_root}/src/tr1/c_policy.hpp"
        "${library_root}/src/tr1/cbrt.cpp"
        "${library_root}/src/tr1/cbrtf.cpp"
        "${library_root}/src/tr1/cbrtl.cpp"
        "${library_root}/src/tr1/comp_ellint_1.cpp"
        "${library_root}/src/tr1/comp_ellint_1f.cpp"
        "${library_root}/src/tr1/comp_ellint_1l.cpp"
        "${library_root}/src/tr1/comp_ellint_2.cpp"
        "${library_root}/src/tr1/comp_ellint_2f.cpp"
        "${library_root}/src/tr1/comp_ellint_2l.cpp"
        "${library_root}/src/tr1/comp_ellint_3.cpp"
        "${library_root}/src/tr1/comp_ellint_3f.cpp"
        "${library_root}/src/tr1/comp_ellint_3l.cpp"
        "${library_root}/src/tr1/copysign.cpp"
        "${library_root}/src/tr1/copysignf.cpp"
        "${library_root}/src/tr1/copysignl.cpp"
        "${library_root}/src/tr1/cyl_bessel_i.cpp"
        "${library_root}/src/tr1/cyl_bessel_if.cpp"
        "${library_root}/src/tr1/cyl_bessel_il.cpp"
        "${library_root}/src/tr1/cyl_bessel_j.cpp"
        "${library_root}/src/tr1/cyl_bessel_jf.cpp"
        "${library_root}/src/tr1/cyl_bessel_jl.cpp"
        "${library_root}/src/tr1/cyl_bessel_k.cpp"
        "${library_root}/src/tr1/cyl_bessel_kf.cpp"
        "${library_root}/src/tr1/cyl_bessel_kl.cpp"
        "${library_root}/src/tr1/cyl_neumann.cpp"
        "${library_root}/src/tr1/cyl_neumannf.cpp"
        "${library_root}/src/tr1/cyl_neumannl.cpp"
        "${library_root}/src/tr1/ellint_1.cpp"
        "${library_root}/src/tr1/ellint_1f.cpp"
        "${library_root}/src/tr1/ellint_1l.cpp"
        "${library_root}/src/tr1/ellint_2.cpp"
        "${library_root}/src/tr1/ellint_2f.cpp"
        "${library_root}/src/tr1/ellint_2l.cpp"
        "${library_root}/src/tr1/ellint_3.cpp"
        "${library_root}/src/tr1/ellint_3f.cpp"
        "${library_root}/src/tr1/ellint_3l.cpp"
        "${library_root}/src/tr1/erf.cpp"
        "${library_root}/src/tr1/erfc.cpp"
        "${library_root}/src/tr1/erfcf.cpp"
        "${library_root}/src/tr1/erfcl.cpp"
        "${library_root}/src/tr1/erff.cpp"
        "${library_root}/src/tr1/erfl.cpp"
        "${library_root}/src/tr1/expint.cpp"
        "${library_root}/src/tr1/expintf.cpp"
        "${library_root}/src/tr1/expintl.cpp"
        "${library_root}/src/tr1/expm1.cpp"
        "${library_root}/src/tr1/expm1f.cpp"
        "${library_root}/src/tr1/expm1l.cpp"
        "${library_root}/src/tr1/fmax.cpp"
        "${library_root}/src/tr1/fmaxf.cpp"
        "${library_root}/src/tr1/fmaxl.cpp"
        "${library_root}/src/tr1/fmin.cpp"
        "${library_root}/src/tr1/fminf.cpp"
        "${library_root}/src/tr1/fminl.cpp"
        "${library_root}/src/tr1/fpclassify.cpp"
        "${library_root}/src/tr1/fpclassifyf.cpp"
        "${library_root}/src/tr1/fpclassifyl.cpp"
        "${library_root}/src/tr1/hermite.cpp"
        "${library_root}/src/tr1/hermitef.cpp"
        "${library_root}/src/tr1/hermitel.cpp"
        "${library_root}/src/tr1/hypot.cpp"
        "${library_root}/src/tr1/hypotf.cpp"
        "${library_root}/src/tr1/hypotl.cpp"
        "${library_root}/src/tr1/laguerre.cpp"
        "${library_root}/src/tr1/laguerref.cpp"
        "${library_root}/src/tr1/laguerrel.cpp"
        "${library_root}/src/tr1/legendre.cpp"
        "${library_root}/src/tr1/legendref.cpp"
        "${library_root}/src/tr1/legendrel.cpp"
        "${library_root}/src/tr1/lgamma.cpp"
        "${library_root}/src/tr1/lgammaf.cpp"
        "${library_root}/src/tr1/lgammal.cpp"
        "${library_root}/src/tr1/llround.cpp"
        "${library_root}/src/tr1/llroundf.cpp"
        "${library_root}/src/tr1/llroundl.cpp"
        "${library_root}/src/tr1/log1p.cpp"
        "${library_root}/src/tr1/log1pf.cpp"
        "${library_root}/src/tr1/log1pl.cpp"
        "${library_root}/src/tr1/lround.cpp"
        "${library_root}/src/tr1/lroundf.cpp"
        "${library_root}/src/tr1/lroundl.cpp"
        "${library_root}/src/tr1/nextafter.cpp"
        "${library_root}/src/tr1/nextafterf.cpp"
        "${library_root}/src/tr1/nextafterl.cpp"
        "${library_root}/src/tr1/nexttoward.cpp"
        "${library_root}/src/tr1/nexttowardf.cpp"
        "${library_root}/src/tr1/nexttowardl.cpp"
        "${library_root}/src/tr1/pch.hpp"
        "${library_root}/src/tr1/riemann_zeta.cpp"
        "${library_root}/src/tr1/riemann_zetaf.cpp"
        "${library_root}/src/tr1/riemann_zetal.cpp"
        "${library_root}/src/tr1/round.cpp"
        "${library_root}/src/tr1/roundf.cpp"
        "${library_root}/src/tr1/roundl.cpp"
        "${library_root}/src/tr1/sph_bessel.cpp"
        "${library_root}/src/tr1/sph_besself.cpp"
        "${library_root}/src/tr1/sph_bessell.cpp"
        "${library_root}/src/tr1/sph_legendre.cpp"
        "${library_root}/src/tr1/sph_legendref.cpp"
        "${library_root}/src/tr1/sph_legendrel.cpp"
        "${library_root}/src/tr1/sph_neumann.cpp"
        "${library_root}/src/tr1/sph_neumannf.cpp"
        "${library_root}/src/tr1/sph_neumannl.cpp"
        "${library_root}/src/tr1/tgamma.cpp"
        "${library_root}/src/tr1/tgammaf.cpp"
        "${library_root}/src/tr1/tgammal.cpp"
        "${library_root}/src/tr1/trunc.cpp"
        "${library_root}/src/tr1/truncf.cpp"
        "${library_root}/src/tr1/truncl.cpp"
        )

    target_include_directories(thirdparty_boost_math SYSTEM PUBLIC
        "${library_root}/include"
        )

    target_include_directories(thirdparty_boost_math PRIVATE
        "${library_root}/src/tr1"
        )

    target_link_libraries(thirdparty_boost_math PUBLIC
        thirdparty_boost_staticassert
        thirdparty_boost_predef
        thirdparty_boost_typetraits
        thirdparty_boost_mpl
        thirdparty_boost_throwexception
        thirdparty_boost_utility
        thirdparty_boost_array
        thirdparty_boost_lexicalcast
        thirdparty_boost_smartptr
        thirdparty_boost_multiprecision
        thirdparty_boost_io
        thirdparty_boost_tokenizer
        )

    target_link_libraries(thirdparty_boost_math PRIVATE

        )
endfunction()

function(generateBoostContainer)
    set(library_root "${BOOST_ROOT}/libs/container")

    add_library(thirdparty_boost_container STATIC
        "${library_root}/src/dlmalloc.cpp"
        "${library_root}/src/global_resource.cpp"
        "${library_root}/src/monotonic_buffer_resource.cpp"
        "${library_root}/src/pool_resource.cpp"
        "${library_root}/src/synchronized_pool_resource.cpp"
        "${library_root}/src/unsynchronized_pool_resource.cpp"
        )

    target_include_directories(thirdparty_boost_container SYSTEM PUBLIC
        "${library_root}/include"
        )

    target_link_libraries(thirdparty_boost_container PUBLIC
        thirdparty_boost_move
        thirdparty_boost_core
        thirdparty_boost_intrusive
        )

    target_link_libraries(thirdparty_boost_container PRIVATE

        )
endfunction()

function(generateBoostDateTime)
    set(library_root "${BOOST_ROOT}/libs/date_time")

    add_library(thirdparty_boost_datetime STATIC
        "${library_root}/src/gregorian/greg_month.cpp"
        "${library_root}/src/gregorian/greg_names.hpp"
        "${library_root}/src/gregorian/gregorian_types.cpp"
        "${library_root}/src/posix_time/posix_time_types.cpp"
        )

    target_include_directories(thirdparty_boost_datetime SYSTEM PUBLIC
        "${library_root}/include"
        )

    target_link_libraries(thirdparty_boost_datetime PUBLIC
        thirdparty_boost_throwexception
        thirdparty_boost_utility
        thirdparty_boost_mpl
        thirdparty_boost_typetraits
        thirdparty_boost_smartptr
        thirdparty_boost_lexicalcast
        )

    target_link_libraries(thirdparty_boost_datetime PRIVATE

        )
endfunction()

function(generateBoostContext)
    set(library_root "${BOOST_ROOT}/libs/context")

    set(source_files
        "${library_root}/src/continuation.cpp"
        "${library_root}/src/fiber.cpp"
        )

    if(DEFINED PLATFORM_LINUX AND TARGET_PROCESSOR STREQUAL "x86_64")
        set(asm_source_file_list
            "${library_root}/src/asm/jump_x86_64_sysv_elf_gas.S"
            "${library_root}/src/asm/make_x86_64_sysv_elf_gas.S"
            "${library_root}/src/asm/ontop_x86_64_sysv_elf_gas.S"
            )
    elseif(DEFINED PLATFORM_LINUX AND TARGET_PROCESSOR STREQUAL "aarch64")
        set(asm_source_file_list
            "${library_root}/src/asm/jump_arm64_aapcs_elf_gas.S"
            "${library_root}/src/asm/make_arm64_aapcs_elf_gas.S"
            "${library_root}/src/asm/ontop_arm64_aapcs_elf_gas.S"
            )
    elseif(DEFINED PLATFORM_MACOS)
        set(asm_source_file_list
            "${library_root}/src/asm/jump_x86_64_sysv_macho_gas.S"
            "${library_root}/src/asm/make_x86_64_sysv_macho_gas.S"
            "${library_root}/src/asm/ontop_x86_64_sysv_macho_gas.S"
            )
    elseif(DEFINED PLATFORM_WINDOWS)
        if(CMAKE_SIZEOF_VOID_P EQUAL 4)
            set(asm_source_file_list
                "${library_root}/src/asm/jump_i386_ms_pe_masm.asm"
                "${library_root}/src/asm/make_i386_ms_pe_masm.asm"
                "${library_root}/src/asm/ontop_i386_ms_pe_masm.asm"
                )
        else()
            set(asm_source_file_list
                "${library_root}/src/asm/jump_x86_64_ms_pe_masm.asm"
                "${library_root}/src/asm/make_x86_64_ms_pe_masm.asm"
                "${library_root}/src/asm/ontop_x86_64_ms_pe_masm.asm"
                )
        endif()
    endif()

    foreach(asm_source_file ${asm_source_file_list})
        if(DEFINED PLATFORM_POSIX)
            set_property(SOURCE "${asm_source_file}" PROPERTY LANGUAGE C)
        endif()

        if(DEFINED PLATFORM_MACOS)
            set_property(SOURCE "${asm_source_file}" PROPERTY COMPILE_FLAGS "-x assembler-with-cpp")
        endif()

        if(DEFINED PLATFORM_WINDOWS)
            set_property(SOURCE "${asm_source_file}" PROPERTY COMPILE_FLAGS "/Cp /Cx /Zp4 /safeseh")
        endif()
    endforeach()

    if(OSQUERY_ENABLE_ADDRESS_SANITIZER)
        list(APPEND source_files
            "${library_root}/src/fiber.cpp"
            )
    endif()

    add_library(thirdparty_boost_context STATIC
        ${source_files}
        ${asm_source_file_list}
        )

    if(DEFINED PLATFORM_POSIX)
        target_sources(thirdparty_boost_context PRIVATE
            "${library_root}/src/posix/stack_traits.cpp"
            )

    elseif(DEFINED PLATFORM_WINDOWS)
        target_sources(thirdparty_boost_context PRIVATE
            "${library_root}/src/windows/stack_traits.cpp"
            )

        target_compile_definitions(thirdparty_boost_context PRIVATE
            BOOST_CONTEXT_EXPORT=
            )

    endif()

    target_include_directories(thirdparty_boost_context SYSTEM PUBLIC
        "${library_root}/include"
        )

    target_link_libraries(thirdparty_boost_context PUBLIC
        thirdparty_boost_config
        thirdparty_boost_assert
        thirdparty_boost_smartptr
        )

    target_link_libraries(thirdparty_boost_context PRIVATE

        )
endfunction()

function(generateBoostCoroutine)
    set(library_root "${BOOST_ROOT}/libs/coroutine")

    add_library(thirdparty_boost_coroutine STATIC
        "${library_root}/src/exceptions.cpp"
        "${library_root}/src/detail/coroutine_context.cpp"
        )

    if(DEFINED PLATFORM_POSIX)
        target_sources(thirdparty_boost_coroutine PRIVATE
            "${library_root}/src/posix/stack_traits.cpp"
            )

    elseif(DEFINED PLATFORM_WINDOWS)
        target_sources(thirdparty_boost_coroutine PRIVATE
            "${library_root}/src/windows/stack_traits.cpp"
            )
    endif()

    target_include_directories(thirdparty_boost_coroutine SYSTEM PUBLIC
        "${library_root}/include"
        )

    target_link_libraries(thirdparty_boost_coroutine PUBLIC
        thirdparty_boost_core
        thirdparty_boost_system
        thirdparty_boost_typetraits
        thirdparty_boost_context
        thirdparty_boost_thread
        )

    target_link_libraries(thirdparty_boost_coroutine PRIVATE

        )
endfunction()

function(generateBoostFilesystem)
    set(library_root "${BOOST_ROOT}/libs/filesystem")

    add_library(thirdparty_boost_filesystem STATIC
        "${library_root}/src/codecvt_error_category.cpp"
        "${library_root}/src/exception.cpp"
        "${library_root}/src/operations.cpp"
        "${library_root}/src/directory.cpp"
        "${library_root}/src/path.cpp"
        "${library_root}/src/path_traits.cpp"
        "${library_root}/src/portability.cpp"
        "${library_root}/src/unique_path.cpp"
        "${library_root}/src/utf8_codecvt_facet.cpp"
        )

    if(DEFINED PLATFORM_WINDOWS)
        target_sources(thirdparty_boost_filesystem PRIVATE
            "${library_root}/src/windows_file_codecvt.cpp"
            )
    endif()

    target_include_directories(thirdparty_boost_filesystem SYSTEM PUBLIC
        "${library_root}/include"
        )

    if(NOT BOOST_FILESYSTEM_HAS_CXX20_ATOMIC_REF)
        target_compile_definitions(thirdparty_boost_filesystem PRIVATE BOOST_FILESYSTEM_NO_CXX20_ATOMIC_REF)
        target_link_libraries(thirdparty_boost_filesystem PRIVATE thirdparty_boost_atomic)
    endif()

    target_include_directories(thirdparty_boost_filesystem PRIVATE "${library_root}")

    target_link_libraries(thirdparty_boost_filesystem PUBLIC
        thirdparty_boost_assert
        thirdparty_boost_detail
        thirdparty_boost_system
        thirdparty_boost_typetraits
        thirdparty_boost_core
        thirdparty_boost_iterator
        thirdparty_boost_io
        thirdparty_boost_containerhash
        thirdparty_boost_smartptr
        thirdparty_boost_winapi
        )

    target_link_libraries(thirdparty_boost_filesystem PRIVATE
        thirdparty_boost_predef

        )
endfunction()

function(generateBoostRegex)
    set(library_root "${BOOST_ROOT}/libs/regex")

    add_library(thirdparty_boost_regex STATIC
        "${library_root}/src/wide_posix_api.cpp"
        "${library_root}/src/posix_api.cpp"
        "${library_root}/src/regex_debug.cpp"
        "${library_root}/src/static_mutex.cpp"
        "${library_root}/src/regex.cpp"
        )

    target_include_directories(thirdparty_boost_regex SYSTEM PUBLIC
        "${library_root}/include"
        )

    target_link_libraries(thirdparty_boost_regex PUBLIC
        thirdparty_boost_predef
        thirdparty_boost_assert
        thirdparty_boost_throwexception
        thirdparty_boost_smartptr
        thirdparty_boost_core
        thirdparty_boost_mpl
        thirdparty_boost_typetraits
        thirdparty_boost_integer
        thirdparty_boost_containerhash
        )

    target_link_libraries(thirdparty_boost_regex PRIVATE

        )
endfunction()

function(generateBoostAtomic)
    set(library_root "${BOOST_ROOT}/libs/atomic")

    add_library(thirdparty_boost_atomic STATIC
        "${library_root}/src/lock_pool.cpp"
        )

    # sse2 find_address_sse2.cpp

    # sse41 find_address_sse41.cpp

    # win32 wait_ops_windows.cpp

    target_include_directories(thirdparty_boost_atomic SYSTEM PUBLIC
        "${library_root}/include"
        )

    target_include_directories(thirdparty_boost_atomic SYSTEM PRIVATE
        "${library_root}/src"
        )


    target_link_libraries(thirdparty_boost_atomic PUBLIC
        thirdparty_boost_assert
        thirdparty_boost_typetraits
        )

    target_link_libraries(thirdparty_boost_atomic PRIVATE
        thirdparty_boost_align
        thirdparty_boost_predef
        thirdparty_boost_staticassert
        thirdparty_boost_preprocessor
        thirdparty_boost_serialization
        )
endfunction()

function(generateBoostThread)
    set(library_root "${BOOST_ROOT}/libs/thread")

    add_library(thirdparty_boost_thread STATIC
        "${library_root}/src/future.cpp"
        "${library_root}/src/tss_null.cpp"
        )

    if(DEFINED PLATFORM_POSIX)
        target_sources(thirdparty_boost_thread PRIVATE
            "${library_root}/src/pthread/once.cpp"
            "${library_root}/src/pthread/once_atomic.cpp"
            "${library_root}/src/pthread/thread.cpp"
            )

    elseif(DEFINED PLATFORM_WINDOWS)
        target_sources(thirdparty_boost_thread PRIVATE
            "${library_root}/src/win32/thread.cpp"
            "${library_root}/src/win32/thread_primitives.cpp"
            "${library_root}/src/win32/tss_dll.cpp"
            "${library_root}/src/win32/tss_pe.cpp"
            )

        target_compile_definitions(thirdparty_boost_thread PRIVATE
            BOOST_THREAD_BUILD_LIB
            )
    endif()

    target_include_directories(thirdparty_boost_thread SYSTEM PUBLIC
        "${library_root}/include"
        )

    target_link_libraries(thirdparty_boost_thread PUBLIC
        thirdparty_boost_core
        thirdparty_boost_system
        thirdparty_boost_typetraits
        thirdparty_boost_move
        thirdparty_boost_mpl
        thirdparty_boost_bind
        thirdparty_boost_atomic
        thirdparty_boost_datetime
        thirdparty_boost_chrono
        thirdparty_boost_containerhash
        thirdparty_boost_tuple
        thirdparty_boost_exception
        thirdparty_boost_optional
        thirdparty_boost_function
        thirdparty_boost_typeindex
        thirdparty_boost_algorithm
        thirdparty_boost_winapi
        )

    target_link_libraries(thirdparty_boost_thread PRIVATE

        )
endfunction()

function(generateBoostIostreams)
    set(library_root "${BOOST_ROOT}/libs/iostreams")

    add_library(thirdparty_boost_iostreams STATIC
        "${library_root}/src/zlib.cpp"
        "${library_root}/src/gzip.cpp"
        "${library_root}/src/zstd.cpp"
        "${library_root}/src/bzip2.cpp"
        )

    if(DEFINED PLATFORM_POSIX)
        target_sources(thirdparty_boost_iostreams PRIVATE
            "${library_root}/src/lzma.cpp"
            )
    endif()

    target_include_directories(thirdparty_boost_iostreams SYSTEM PUBLIC
        "${library_root}/include"
        )

    target_link_libraries(thirdparty_boost_iostreams PUBLIC
        thirdparty_boost_assert
        thirdparty_boost_throwexception
        thirdparty_boost_smartptr
        thirdparty_boost_core
        thirdparty_boost_mpl
        thirdparty_boost_typetraits
        thirdparty_boost_integer
        thirdparty_boost_containerhash
        thirdparty_boost_range
        thirdparty_boost_utility
        thirdparty_zlib
        thirdparty_zstd
        thirdparty_bzip2
        )

    if(DEFINED PLATFORM_POSIX)
        target_link_libraries(thirdparty_boost_iostreams PUBLIC
            thirdparty_lzma
            )
    endif()

    target_link_libraries(thirdparty_boost_iostreams PRIVATE

        )
endfunction()

boostMain()

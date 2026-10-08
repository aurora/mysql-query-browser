# SPDX-License-Identifier: GPL-2.0-or-later
cmake_minimum_required(VERSION 3.20)
project(qbr_backend C CXX)

set(CMAKE_C_STANDARD 99)
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

find_package(PkgConfig REQUIRED)
pkg_check_modules(GLIB     REQUIRED IMPORTED_TARGET glib-2.0 gthread-2.0)
pkg_check_modules(LIBXML2  REQUIRED IMPORTED_TARGET libxml-2.0)
pkg_check_modules(PCRE     REQUIRED IMPORTED_TARGET libpcre)
pkg_check_modules(MARIADB  REQUIRED IMPORTED_TARGET libmariadb)
find_package(Iconv REQUIRED)

set(SRC ${CMAKE_CURRENT_SOURCE_DIR}/src)

# Shim headers replacing autotools config.h and MySQL server headers.
include_directories(BEFORE ${CMAKE_CURRENT_SOURCE_DIR}/compat)

# Legacy code predates -Wall hygiene; keep warnings visible but not fatal.
add_compile_options(-Wall -Wno-unknown-pragmas)

# --- utilities -------------------------------------------------------------
add_library(mysqlutil SHARED
    ${SRC}/utilities/source/myx_util.c
    ${SRC}/utilities/source/myx_util_functions.c
    ${SRC}/utilities/source/myx_xml_util_functions.c
    ${SRC}/utilities/source/myx_international_file.c
    ${SRC}/utilities/shared_source/myx_shared_util_functions.c)
target_include_directories(mysqlutil PUBLIC
    ${SRC}/utilities/include ${SRC}/utilities/shared_include)
target_link_libraries(mysqlutil PUBLIC
    PkgConfig::GLIB PkgConfig::LIBXML2 PkgConfig::PCRE PkgConfig::MARIADB
    Iconv::Iconv)

# --- sql parser ------------------------------------------------------------
add_library(mysqlsqlparser SHARED
    ${SRC}/sql-parser/source/myx_lex_helpers.cpp
    ${SRC}/sql-parser/source/myx_sql_parser.tab.cc
    ${SRC}/sql-parser/source/myx_sql_scanner.lex.c
    ${SRC}/sql-parser/source/MyxSQLTreeItem.cpp
    ${SRC}/sql-parser/source/MyxStatementParser.cpp)
target_include_directories(mysqlsqlparser PUBLIC
    ${SRC}/sql-parser/include
    ${SRC}/base-library/include
    ${SRC}/generic-runtime/include)
target_link_libraries(mysqlsqlparser PUBLIC mysqlutil)

# --- base library (connection, catalogs, recordset, options) ---------------
add_library(mysqlx SHARED
    ${SRC}/base-library/source/myx_exporter.c
    ${SRC}/base-library/source/myx_catalogs.c
    ${SRC}/base-library/source/myx_library.c
    ${SRC}/base-library/source/myx_network.c
    ${SRC}/base-library/source/myx_database_model.c
    ${SRC}/base-library/source/myx_recordset.c
    ${SRC}/base-library/source/myx_query.cpp
    ${SRC}/base-library/source/myx_shell.c
    ${SRC}/base-library/source/myx_ser_aux_functions.c
    ${SRC}/base-library/source/myx_xml_option_functions.c
    ${SRC}/base-library/source/myx_xml_user_connections.c
    ${SRC}/base-library/source/myx_sql_highlighting.c
    ${SRC}/base-library/source/myx_simple_sql_parsing.c
    ${SRC}/base-library/source/myx_xml_charset.c
    ${SRC}/base-library/source/myx_xml_datatype.c)
target_include_directories(mysqlx PUBLIC ${SRC}/base-library/include)
target_link_libraries(mysqlx PUBLIC mysqlutil mysqlsqlparser)

# --- query browser library -------------------------------------------------
add_library(mysqlqb SHARED
    ${SRC}/qb/source/myx_qb_library.c
    ${SRC}/qb/source/myx_xml_bookmark.c
    ${SRC}/qb/source/myx_xml_history.c
    ${SRC}/qb/source/myx_strip_query.cpp
    ${SRC}/qb/source/myx_xml_functionlist.c
    ${SRC}/qb/source/myx_script_editor.c
    ${SRC}/qb/source/myx_script_viewer.c
    ${SRC}/qb/source/myx_profiling.c
    ${SRC}/qb/source/myx_recordset_print.c)
# Not built yet: myx_pdf.c (needs the "panda" PDF library),
# myx_live_profiling.c (POSIX sockets, optional feature).
target_include_directories(mysqlqb PUBLIC ${SRC}/qb/include)
target_link_libraries(mysqlqb PUBLIC mysqlx)

if(WIN32)
  # Winsock, ICMP ping (myx_network.c), DPAPI password protection (myx_xml_user_connections.c)
  target_link_libraries(mysqlx PUBLIC ws2_32 iphlpapi crypt32)
endif()

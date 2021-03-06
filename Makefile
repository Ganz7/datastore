# Copyright (c) 2011 The LevelDB Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file. See the AUTHORS file for names of contributors.

# Inherit some settings from environment variables, if available

#-----------------------------------------------

ifneq ($(MAKECMDGOALS),dbg)
OPT += -O2 -fno-omit-frame-pointer -momit-leaf-frame-pointer
else
# intentionally left blank
endif

ifeq ($(MAKECMDGOALS),shared_lib)
OPT += -DNDEBUG
endif

ifeq ($(MAKECMDGOALS),static_lib)
OPT += -DNDEBUG
endif

#-----------------------------------------------

# detect what platform we're building on
$(shell (export ROCKSDB_ROOT="$(CURDIR)"; "$(CURDIR)/build_tools/build_detect_platform" "$(CURDIR)/build_config.mk"))
# this file is generated by the previous line to set build flags and sources
include build_config.mk

ifneq ($(PLATFORM), IOS)
CFLAGS += -g
CXXFLAGS += -g
else
# no debug info for IOS, that will make our library big
OPT += -DNDEBUG
endif

# ASAN doesn't work well with jemalloc. If we're compiling with ASAN, we should use regular malloc.
ifdef COMPILE_WITH_ASAN
	# ASAN compile flags
	EXEC_LDFLAGS += -fsanitize=address
	PLATFORM_CCFLAGS += -fsanitize=address
	PLATFORM_CXXFLAGS += -fsanitize=address
else
	# if we're not compiling with ASAN, use jemalloc
	EXEC_LDFLAGS := $(JEMALLOC_LIB) $(EXEC_LDFLAGS)
	PLATFORM_CXXFLAGS += $(JEMALLOC_INCLUDE) -DHAVE_JEMALLOC
	PLATFORM_CCFLAGS += $(JEMALLOC_INCLUDE) -DHAVE_JEMALLOC
endif

#-------------------------------------------------
# make install related stuff
INSTALL_PATH ?= /usr/local

uninstall:
	@rm -rf $(INSTALL_PATH)/include/rocksdb
	@rm -rf $(INSTALL_PATH)/lib/$(LIBRARY)
	@rm -rf $(INSTALL_PATH)/lib/$(SHARED)

install:
	@install -d $(INSTALL_PATH)/lib
	@for header_dir in `find "include/rocksdb" -type d`; do \
		install -d $(INSTALL_PATH)/$$header_dir; \
	done
	@for header in `find "include/rocksdb" -type f -name *.h`; do \
		install -C -m 644 $$header $(INSTALL_PATH)/$$header; \
	done
	@[ ! -e $(LIBRARY) ] || install -C -m 644 $(LIBRARY) $(INSTALL_PATH)/lib
	@[ ! -e $(SHARED) ] || install -C -m 644 $(SHARED) $(INSTALL_PATH)/lib
#-------------------------------------------------

WARNING_FLAGS = -Wall -Werror -Wsign-compare -Wshadow
CFLAGS += $(WARNING_FLAGS) -I. -I./include $(PLATFORM_CCFLAGS) $(OPT)
CXXFLAGS += $(WARNING_FLAGS) -I. -I./include $(PLATFORM_CXXFLAGS) $(OPT) -Woverloaded-virtual -Wnon-virtual-dtor

LDFLAGS += $(PLATFORM_LDFLAGS)

LIBOBJECTS = $(SOURCES:.cc=.o)
MEMENVOBJECTS = $(MEMENV_SOURCES:.cc=.o)
MOCKOBJECTS = $(MOCK_SOURCES:.cc=.o)

TESTUTIL = ./util/testutil.o
TESTHARNESS = ./util/testharness.o $(TESTUTIL) $(MOCKOBJECTS)
BENCHHARNESS = ./util/benchharness.o
VALGRIND_ERROR = 2
VALGRIND_DIR = build_tools/VALGRIND_LOGS
VALGRIND_VER := $(join $(VALGRIND_VER),valgrind)
VALGRIND_OPTS = --error-exitcode=$(VALGRIND_ERROR) --leak-check=full

TESTS = \
	db_test \
	db_iter_test \
	block_hash_index_test \
	autovector_test \
	column_family_test \
	table_properties_collector_test \
	arena_test \
	auto_roll_logger_test \
	benchharness_test \
	block_test \
	bloom_test \
	dynamic_bloom_test \
	c_test \
	cache_test \
	coding_test \
	corruption_test \
	crc32c_test \
	dbformat_test \
	env_test \
	blob_store_test \
	filelock_test \
	filename_test \
	block_based_filter_block_test \
	full_filter_block_test \
	histogram_test \
	log_test \
	manual_compaction_test \
	memenv_test \
	mock_env_test \
	merge_test \
	merger_test \
	redis_test \
	reduce_levels_test \
	plain_table_db_test \
	comparator_db_test \
	prefix_test \
	skiplist_test \
	stringappend_test \
	ttl_test \
	backupable_db_test \
	document_db_test \
	json_document_test \
	spatial_db_test \
	version_edit_test \
	version_set_test \
	compaction_picker_test \
	version_builder_test \
	file_indexer_test \
	write_batch_test \
	write_controller_test\
	deletefile_test \
	table_test \
	thread_local_test \
	geodb_test \
	rate_limiter_test \
	options_test \
	cuckoo_table_builder_test \
	cuckoo_table_reader_test \
	cuckoo_table_db_test \
	write_batch_with_index_test \
	flush_job_test \
	wal_manager_test \
	listener_test \
	write_batch_with_index_test

TOOLS = \
        sst_dump \
	db_sanity_test \
        db_stress \
        ldb \
	db_repl_stress \
  options_test \
	blob_store_bench

PROGRAMS = db_bench signal_test table_reader_bench log_and_apply_bench cache_bench perf_context_test $(TOOLS)

# The library name is configurable since we are maintaining libraries of both
# debug/release mode.
ifeq ($(LIBNAME),)
        LIBNAME=librocksdb
endif
LIBRARY = ${LIBNAME}.a
MEMENVLIBRARY = libmemenv.a

ROCKSDB_MAJOR = $(shell egrep "ROCKSDB_MAJOR.[0-9]" include/rocksdb/version.h | cut -d ' ' -f 3)
ROCKSDB_MINOR = $(shell egrep "ROCKSDB_MINOR.[0-9]" include/rocksdb/version.h | cut -d ' ' -f 3)
ROCKSDB_PATCH = $(shell egrep "ROCKSDB_PATCH.[0-9]" include/rocksdb/version.h | cut -d ' ' -f 3)

default: all

#-----------------------------------------------
# Create platform independent shared libraries.
#-----------------------------------------------
ifneq ($(PLATFORM_SHARED_EXT),)

ifneq ($(PLATFORM_SHARED_VERSIONED),true)
SHARED1 = ${LIBNAME}.$(PLATFORM_SHARED_EXT)
SHARED2 = $(SHARED1)
SHARED3 = $(SHARED1)
SHARED4 = $(SHARED1)
SHARED = $(SHARED1)
else
SHARED_MAJOR = $(ROCKSDB_MAJOR)
SHARED_MINOR = $(ROCKSDB_MINOR)
SHARED_PATCH = $(ROCKSDB_PATCH)
SHARED1 = ${LIBNAME}.$(PLATFORM_SHARED_EXT)
SHARED2 = $(SHARED1).$(SHARED_MAJOR)
SHARED3 = $(SHARED1).$(SHARED_MAJOR).$(SHARED_MINOR)
SHARED4 = $(SHARED1).$(SHARED_MAJOR).$(SHARED_MINOR).$(SHARED_PATCH)
SHARED = $(SHARED1) $(SHARED2) $(SHARED3) $(SHARED4)
$(SHARED1): $(SHARED4)
	ln -fs $(SHARED4) $(SHARED1)
$(SHARED2): $(SHARED4)
	ln -fs $(SHARED4) $(SHARED2)
$(SHARED3): $(SHARED4)
	ln -fs $(SHARED4) $(SHARED3)
endif

$(SHARED4):
	$(CXX) $(PLATFORM_SHARED_LDFLAGS)$(SHARED2) $(CXXFLAGS) $(PLATFORM_SHARED_CFLAGS) $(SOURCES) $(LDFLAGS) -o $@

endif  # PLATFORM_SHARED_EXT

.PHONY: blackbox_crash_test check clean coverage crash_test ldb_tests package \
	release tags valgrind_check whitebox_crash_test format static_lib shared_lib all \
	dbg rocksdbjavastatic rocksdbjava install uninstall

all: $(LIBRARY) $(PROGRAMS) $(TESTS)

static_lib: $(LIBRARY)

shared_lib: $(SHARED)

dbg: $(LIBRARY) $(PROGRAMS) $(TESTS)

# creates static library and programs
release:
	$(MAKE) clean
	OPT="-DNDEBUG -O2" $(MAKE) static_lib $(PROGRAMS) -j32

coverage:
	$(MAKE) clean
	COVERAGEFLAGS="-fprofile-arcs -ftest-coverage" LDFLAGS+="-lgcov" $(MAKE) all check -j32
	(cd coverage; ./coverage_test.sh)
	# Delete intermediate files
	find . -type f -regex ".*\.\(\(gcda\)\|\(gcno\)\)" -exec rm {} \;

check: $(TESTS) ldb
	for t in $(TESTS); do echo "***** Running $$t"; ./$$t || exit 1; done
	python tools/ldb_test.py

ldb_tests: ldb
	python tools/ldb_test.py

crash_test: whitebox_crash_test blackbox_crash_test

blackbox_crash_test: db_stress
	python -u tools/db_crashtest.py

whitebox_crash_test: db_stress
	python -u tools/db_crashtest2.py

asan_check:
	$(MAKE) clean
	COMPILE_WITH_ASAN=1 $(MAKE) check -j32
	$(MAKE) clean

asan_crash_test:
	$(MAKE) clean
	COMPILE_WITH_ASAN=1 $(MAKE) crash_test
	$(MAKE) clean

valgrind_check: all $(PROGRAMS) $(TESTS)
	mkdir -p $(VALGRIND_DIR)
	echo TESTS THAT HAVE VALGRIND ERRORS > $(VALGRIND_DIR)/valgrind_failed_tests; \
	echo TIMES in seconds TAKEN BY TESTS ON VALGRIND > $(VALGRIND_DIR)/valgrind_tests_times; \
	for t in $(filter-out skiplist_test,$(TESTS)); do \
		stime=`date '+%s'`; \
		$(VALGRIND_VER) $(VALGRIND_OPTS) ./$$t; \
		if [ $$? -eq $(VALGRIND_ERROR) ] ; then \
			echo $$t >> $(VALGRIND_DIR)/valgrind_failed_tests; \
		fi; \
		etime=`date '+%s'`; \
		echo $$t $$((etime - stime)) >> $(VALGRIND_DIR)/valgrind_tests_times; \
	done

unity.cc:
	$(shell (export ROCKSDB_ROOT="$(CURDIR)"; "$(CURDIR)/build_tools/unity" "$(CURDIR)/unity.cc"))

unity: unity.cc unity.o
	$(CXX) unity.o $(EXEC_LDFLAGS) -o $@ $(LDFLAGS) $(COVERAGEFLAGS)

clean:
	-rm -f $(PROGRAMS) $(TESTS) $(LIBRARY) $(SHARED) $(MEMENVLIBRARY) build_config.mk unity.cc
	-rm -rf ios-x86/* ios-arm/*
	-find . -name "*.[oda]" -exec rm {} \;
	-find . -type f -regex ".*\.\(\(gcda\)\|\(gcno\)\)" -exec rm {} \;
	-rm -rf bzip2* snappy* zlib*
tags:
	ctags * -R
	cscope -b `find . -name '*.cc'` `find . -name '*.h'`

format:
	build_tools/format-diff.sh

package:
	bash build_tools/make_package.sh $(SHARED_MAJOR).$(SHARED_MINOR)

# ---------------------------------------------------------------------------
# 	Unit tests and tools
# ---------------------------------------------------------------------------
$(LIBRARY): $(LIBOBJECTS)
	rm -f $@
	$(AR) -rs $@ $(LIBOBJECTS)

db_bench: db/db_bench.o $(LIBOBJECTS) $(TESTUTIL)
	$(CXX) db/db_bench.o $(LIBOBJECTS) $(TESTUTIL) $(EXEC_LDFLAGS) -o $@  $(LDFLAGS) $(COVERAGEFLAGS)

cache_bench: util/cache_bench.o $(LIBOBJECTS) $(TESTUTIL)
	$(CXX) util/cache_bench.o $(LIBOBJECTS) $(TESTUTIL) $(EXEC_LDFLAGS) -o $@  $(LDFLAGS) $(COVERAGEFLAGS)

block_hash_index_test: table/block_hash_index_test.o $(LIBOBJECTS) $(TESTHARNESS)
	 $(CXX) table/block_hash_index_test.o $(LIBOBJECTS) $(TESTHARNESS) $(EXEC_LDFLAGS) -o $@ $(LDFLAGS) $(COVERAGEFLAGS)

db_stress: tools/db_stress.o $(LIBOBJECTS) $(TESTUTIL)
	$(CXX) tools/db_stress.o $(LIBOBJECTS) $(TESTUTIL) $(EXEC_LDFLAGS) -o $@  $(LDFLAGS) $(COVERAGEFLAGS)

db_sanity_test: tools/db_sanity_test.o $(LIBOBJECTS) $(TESTUTIL)
	$(CXX) tools/db_sanity_test.o $(LIBOBJECTS) $(TESTUTIL) $(EXEC_LDFLAGS) -o $@  $(LDFLAGS) $(COVERAGEFLAGS)

db_repl_stress: tools/db_repl_stress.o $(LIBOBJECTS) $(TESTUTIL)
	$(CXX) tools/db_repl_stress.o $(LIBOBJECTS) $(TESTUTIL) $(EXEC_LDFLAGS) -o $@  $(LDFLAGS) $(COVERAGEFLAGS)

blob_store_bench: tools/blob_store_bench.o $(LIBOBJECTS) $(TESTUTIL)
	$(CXX) tools/blob_store_bench.o $(LIBOBJECTS) $(TESTUTIL) $(EXEC_LDFLAGS) -o $@  $(LDFLAGS) $(COVERAGEFLAGS)

signal_test: util/signal_test.o $(LIBOBJECTS)
	$(CXX) util/signal_test.o $(LIBOBJECTS) $(EXEC_LDFLAGS) -o $@ $(LDFLAGS) $(COVERAGEFLAGS)

arena_test: util/arena_test.o $(LIBOBJECTS) $(TESTHARNESS)
	$(CXX) util/arena_test.o $(LIBOBJECTS) $(TESTHARNESS) $(EXEC_LDFLAGS) -o $@ $(LDFLAGS) $(COVERAGEFLAGS)

autovector_test: util/autovector_test.o $(LIBOBJECTS) $(TESTHARNESS)
	$(CXX) util/autovector_test.o $(LIBOBJECTS) $(TESTHARNESS) $(EXEC_LDFLAGS) -o $@ $(LDFLAGS) $(COVERAGEFLAGS)

column_family_test: db/column_family_test.o $(LIBOBJECTS) $(TESTHARNESS)
	$(CXX) db/column_family_test.o $(LIBOBJECTS) $(TESTHARNESS) $(EXEC_LDFLAGS) -o $@ $(LDFLAGS) $(COVERAGEFLAGS)

table_properties_collector_test: db/table_properties_collector_test.o $(LIBOBJECTS) $(TESTHARNESS)
	$(CXX) db/table_properties_collector_test.o $(LIBOBJECTS) $(TESTHARNESS) $(EXEC_LDFLAGS) -o $@ $(LDFLAGS) $(COVERAGEFLAGS)

bloom_test: util/bloom_test.o $(LIBOBJECTS) $(TESTHARNESS)
	$(CXX) util/bloom_test.o $(LIBOBJECTS) $(TESTHARNESS) $(EXEC_LDFLAGS) -o $@ $(LDFLAGS) $(COVERAGEFLAGS)

dynamic_bloom_test: util/dynamic_bloom_test.o $(LIBOBJECTS) $(TESTHARNESS)
	$(CXX) util/dynamic_bloom_test.o $(LIBOBJECTS) $(TESTHARNESS) $(EXEC_LDFLAGS) -o $@ $(LDFLAGS) $(COVERAGEFLAGS)

c_test: db/c_test.o $(LIBOBJECTS) $(TESTHARNESS)
	$(CXX) db/c_test.o $(LIBOBJECTS) $(TESTHARNESS) $(EXEC_LDFLAGS) -o $@ $(LDFLAGS) $(COVERAGEFLAGS)

cache_test: util/cache_test.o $(LIBOBJECTS) $(TESTHARNESS)
	$(CXX) util/cache_test.o $(LIBOBJECTS) $(TESTHARNESS) $(EXEC_LDFLAGS) -o $@ $(LDFLAGS) $(COVERAGEFLAGS)

coding_test: util/coding_test.o $(LIBOBJECTS) $(TESTHARNESS)
	$(CXX) util/coding_test.o $(LIBOBJECTS) $(TESTHARNESS) $(EXEC_LDFLAGS) -o $@ $(LDFLAGS) $(COVERAGEFLAGS)

blob_store_test: util/blob_store_test.o $(LIBOBJECTS) $(TESTHARNESS) $(TESTUTIL)
	$(CXX) util/blob_store_test.o $(LIBOBJECTS) $(TESTHARNESS) $(EXEC_LDFLAGS) -o$@ $(LDFLAGS) $(COVERAGEFLAGS)

stringappend_test: utilities/merge_operators/string_append/stringappend_test.o $(LIBOBJECTS) $(TESTHARNESS)
	$(CXX) utilities/merge_operators/string_append/stringappend_test.o $(LIBOBJECTS) $(TESTHARNESS) $(EXEC_LDFLAGS) -o $@ $(LDFLAGS) $(COVERAGEFLAGS)

redis_test: utilities/redis/redis_lists_test.o $(LIBOBJECTS) $(TESTHARNESS)
	$(CXX) utilities/redis/redis_lists_test.o $(LIBOBJECTS) $(TESTHARNESS) $(EXEC_LDFLAGS) -o $@ $(LDFLAGS) $(COVERAGEFLAGS)

benchharness_test: util/benchharness_test.o $(LIBOBJECTS) $(TESTHARNESS) $(BENCHHARNESS)
	$(CXX) util/benchharness_test.o $(LIBOBJECTS) $(TESTHARNESS) $(BENCHHARNESS) $(EXEC_LDFLAGS) -o$@ $(LDFLAGS) $(COVERAGEFLAGS)

histogram_test: util/histogram_test.o $(LIBOBJECTS) $(TESTHARNESS)
	$(CXX) util/histogram_test.o $(LIBOBJECTS) $(TESTHARNESS) $(EXEC_LDFLAGS) -o$@ $(LDFLAGS) $(COVERAGEFLAGS)

thread_local_test: util/thread_local_test.o $(LIBOBJECTS) $(TESTHARNESS)
	$(CXX) util/thread_local_test.o $(LIBOBJECTS) $(TESTHARNESS) $(EXEC_LDFLAGS) -o $@ $(LDFLAGS) $(COVERAGEFLAGS)

corruption_test: db/corruption_test.o $(LIBOBJECTS) $(TESTHARNESS)
	$(CXX) db/corruption_test.o $(LIBOBJECTS) $(TESTHARNESS) $(EXEC_LDFLAGS) -o $@ $(LDFLAGS) $(COVERAGEFLAGS)

crc32c_test: util/crc32c_test.o $(LIBOBJECTS) $(TESTHARNESS)
	$(CXX) util/crc32c_test.o $(LIBOBJECTS) $(TESTHARNESS) $(EXEC_LDFLAGS) -o $@ $(LDFLAGS) $(COVERAGEFLAGS)

db_test: db/db_test.o $(LIBOBJECTS) $(TESTHARNESS)
	$(CXX) db/db_test.o $(LIBOBJECTS) $(TESTHARNESS) $(EXEC_LDFLAGS) -o $@ $(LDFLAGS) $(COVERAGEFLAGS)

db_iter_test: db/db_iter_test.o $(LIBOBJECTS) $(TESTHARNESS)
	$(CXX) db/db_iter_test.o $(LIBOBJECTS) $(TESTHARNESS) $(EXEC_LDFLAGS) -o $@ $(LDFLAGS) $(COVERAGEFLAGS)

log_write_bench: util/log_write_bench.o $(LIBOBJECTS) $(TESTHARNESS)
	$(CXX) util/log_write_bench.o $(LIBOBJECTS) $(TESTHARNESS) $(EXEC_LDFLAGS) -o $@ $(LDFLAGS) $(COVERAGEFLAGS) -pg

plain_table_db_test: db/plain_table_db_test.o $(LIBOBJECTS) $(TESTHARNESS)
	$(CXX) db/plain_table_db_test.o $(LIBOBJECTS) $(TESTHARNESS) $(EXEC_LDFLAGS) -o $@ $(LDFLAGS) $(COVERAGEFLAGS)

comparator_db_test: db/comparator_db_test.o $(LIBOBJECTS) $(TESTHARNESS)
	$(CXX) db/comparator_db_test.o $(LIBOBJECTS) $(TESTHARNESS) $(EXEC_LDFLAGS) -o $@ $(LDFLAGS) $(COVERAGEFLAGS)

table_reader_bench: table/table_reader_bench.o $(LIBOBJECTS) $(TESTHARNESS)
	$(CXX) table/table_reader_bench.o $(LIBOBJECTS) $(TESTHARNESS) $(EXEC_LDFLAGS) -o $@ $(LDFLAGS) $(COVERAGEFLAGS) -pg

log_and_apply_bench: db/log_and_apply_bench.o $(LIBOBJECTS) $(TESTHARNESS) $(BENCHHARNESS)
	$(CXX) db/log_and_apply_bench.o $(LIBOBJECTS) $(TESTHARNESS) $(BENCHHARNESS) $(EXEC_LDFLAGS) -o $@ $(LDFLAGS) $(COVERAGEFLAGS) -pg

perf_context_test: db/perf_context_test.o $(LIBOBJECTS) $(TESTHARNESS)
	$(CXX) db/perf_context_test.o $(LIBOBJECTS) $(TESTHARNESS) $(EXEC_LDFLAGS) -o $@ $(LDFLAGS)

prefix_test: db/prefix_test.o $(LIBOBJECTS) $(TESTHARNESS)
	$(CXX) db/prefix_test.o $(LIBOBJECTS) $(TESTHARNESS) $(EXEC_LDFLAGS) -o $@ $(LDFLAGS)

backupable_db_test: utilities/backupable/backupable_db_test.o $(LIBOBJECTS) $(TESTHARNESS)
	$(CXX) utilities/backupable/backupable_db_test.o $(LIBOBJECTS) $(TESTHARNESS) $(EXEC_LDFLAGS) -o $@  $(LDFLAGS) $(COVERAGEFLAGS)

document_db_test: utilities/document/document_db_test.o $(LIBOBJECTS) $(TESTHARNESS)
	$(CXX) utilities/document/document_db_test.o $(LIBOBJECTS) $(TESTHARNESS) $(EXEC_LDFLAGS) -o $@  $(LDFLAGS) $(COVERAGEFLAGS)

json_document_test: utilities/document/json_document_test.o $(LIBOBJECTS) $(TESTHARNESS)
	$(CXX) utilities/document/json_document_test.o $(LIBOBJECTS) $(TESTHARNESS) $(EXEC_LDFLAGS) -o $@  $(LDFLAGS) $(COVERAGEFLAGS)

spatial_db_test: utilities/spatialdb/spatial_db_test.o $(LIBOBJECTS) $(TESTHARNESS)
	$(CXX) utilities/spatialdb/spatial_db_test.o $(LIBOBJECTS) $(TESTHARNESS) $(EXEC_LDFLAGS) -o $@  $(LDFLAGS) $(COVERAGEFLAGS)

ttl_test: utilities/ttl/ttl_test.o $(LIBOBJECTS) $(TESTHARNESS)
	$(CXX) utilities/ttl/ttl_test.o $(LIBOBJECTS) $(TESTHARNESS) $(EXEC_LDFLAGS) -o $@  $(LDFLAGS) $(COVERAGEFLAGS)

write_batch_with_index_test: utilities/write_batch_with_index/write_batch_with_index_test.o $(LIBOBJECTS) $(TESTHARNESS)
	$(CXX) utilities/write_batch_with_index/write_batch_with_index_test.o $(LIBOBJECTS) $(TESTHARNESS) $(EXEC_LDFLAGS) -o $@  $(LDFLAGS) $(COVERAGEFLAGS)

flush_job_test: db/flush_job_test.o $(LIBOBJECTS) $(TESTHARNESS)
	$(CXX) db/flush_job_test.o $(LIBOBJECTS) $(TESTHARNESS) $(EXEC_LDFLAGS) -o $@  $(LDFLAGS) $(COVERAGEFLAGS)

wal_manager_test: db/wal_manager_test.o $(LIBOBJECTS) $(TESTHARNESS)
	$(CXX) db/wal_manager_test.o $(LIBOBJECTS) $(TESTHARNESS) $(EXEC_LDFLAGS) -o $@  $(LDFLAGS) $(COVERAGEFLAGS)

dbformat_test: db/dbformat_test.o $(LIBOBJECTS) $(TESTHARNESS)
	$(CXX) db/dbformat_test.o $(LIBOBJECTS) $(TESTHARNESS) $(EXEC_LDFLAGS) -o $@ $(LDFLAGS) $(COVERAGEFLAGS)

env_test: util/env_test.o $(LIBOBJECTS) $(TESTHARNESS)
	$(CXX) util/env_test.o $(LIBOBJECTS) $(TESTHARNESS) $(EXEC_LDFLAGS) -o $@ $(LDFLAGS) $(COVERAGEFLAGS)

rate_limiter_test: util/rate_limiter_test.o $(LIBOBJECTS) $(TESTHARNESS)
	$(CXX) util/rate_limiter_test.o $(LIBOBJECTS) $(TESTHARNESS) $(EXEC_LDFLAGS) -o $@ $(LDFLAGS) $(COVERAGEFLAGS)

filename_test: db/filename_test.o $(LIBOBJECTS) $(TESTHARNESS)
	$(CXX) db/filename_test.o $(LIBOBJECTS) $(TESTHARNESS) $(EXEC_LDFLAGS) -o $@ $(LDFLAGS) $(COVERAGEFLAGS)

block_based_filter_block_test: table/block_based_filter_block_test.o $(LIBOBJECTS) $(TESTHARNESS)
	$(CXX) table/block_based_filter_block_test.o $(LIBOBJECTS) $(TESTHARNESS) $(EXEC_LDFLAGS) -o $@ $(LDFLAGS) $(COVERAGEFLAGS)

full_filter_block_test: table/full_filter_block_test.o $(LIBOBJECTS) $(TESTHARNESS)
	$(CXX) table/full_filter_block_test.o $(LIBOBJECTS) $(TESTHARNESS) $(EXEC_LDFLAGS) -o $@ $(LDFLAGS) $(COVERAGEFLAGS)

log_test: db/log_test.o $(LIBOBJECTS) $(TESTHARNESS)
	$(CXX) db/log_test.o $(LIBOBJECTS) $(TESTHARNESS) $(EXEC_LDFLAGS) -o $@ $(LDFLAGS) $(COVERAGEFLAGS)

table_test: table/table_test.o $(LIBOBJECTS) $(TESTHARNESS)
	$(CXX) table/table_test.o $(LIBOBJECTS) $(TESTHARNESS) $(EXEC_LDFLAGS) -o $@ $(LDFLAGS) $(COVERAGEFLAGS)

block_test: table/block_test.o $(LIBOBJECTS) $(TESTHARNESS)
	$(CXX) table/block_test.o $(LIBOBJECTS) $(TESTHARNESS) $(EXEC_LDFLAGS) -o $@ $(LDFLAGS) $(COVERAGEFLAGS)

skiplist_test: db/skiplist_test.o $(LIBOBJECTS) $(TESTHARNESS)
	$(CXX) db/skiplist_test.o $(LIBOBJECTS) $(TESTHARNESS) $(EXEC_LDFLAGS) -o $@ $(LDFLAGS) $(COVERAGEFLAGS)

version_edit_test: db/version_edit_test.o $(LIBOBJECTS) $(TESTHARNESS)
	$(CXX) db/version_edit_test.o $(LIBOBJECTS) $(TESTHARNESS) $(EXEC_LDFLAGS) -o $@ $(LDFLAGS) $(COVERAGEFLAGS)

version_set_test: db/version_set_test.o $(LIBOBJECTS) $(TESTHARNESS)
	$(CXX) db/version_set_test.o $(LIBOBJECTS) $(TESTHARNESS) $(EXEC_LDFLAGS) -o $@ $(LDFLAGS) $(COVERAGEFLAGS)

compaction_picker_test: db/compaction_picker_test.o $(LIBOBJECTS) $(TESTHARNESS)
	$(CXX) db/compaction_picker_test.o $(LIBOBJECTS) $(TESTHARNESS) $(EXEC_LDFLAGS) -o $@ $(LDFLAGS) $(COVERAGEFLAGS)

version_builder_test: db/version_builder_test.o $(LIBOBJECTS) $(TESTHARNESS)
	$(CXX) db/version_builder_test.o $(LIBOBJECTS) $(TESTHARNESS) $(EXEC_LDFLAGS) -o $@ $(LDFLAGS) $(COVERAGEFLAGS)

file_indexer_test : db/file_indexer_test.o $(LIBOBJECTS) $(TESTHARNESS)
	$(CXX) db/file_indexer_test.o $(LIBOBJECTS) $(TESTHARNESS) $(EXEC_LDFLAGS) -o $@ $(LDFLAGS) $(COVERAGEFLAGS)

reduce_levels_test: tools/reduce_levels_test.o $(LIBOBJECTS) $(TESTHARNESS)
	$(CXX) tools/reduce_levels_test.o $(LIBOBJECTS) $(TESTHARNESS) $(EXEC_LDFLAGS) -o $@ $(LDFLAGS) $(COVERAGEFLAGS)

write_batch_test: db/write_batch_test.o $(LIBOBJECTS) $(TESTHARNESS)
	$(CXX) db/write_batch_test.o $(LIBOBJECTS) $(TESTHARNESS) $(EXEC_LDFLAGS) -o $@ $(LDFLAGS) $(COVERAGEFLAGS)

write_controller_test: db/write_controller_test.o $(LIBOBJECTS) $(TESTHARNESS)
	$(CXX) db/write_controller_test.o $(LIBOBJECTS) $(TESTHARNESS) $(EXEC_LDFLAGS) -o $@ $(LDFLAGS) $(COVERAGEFLAGS)

merge_test: db/merge_test.o $(LIBOBJECTS) $(TESTHARNESS)
	$(CXX) db/merge_test.o $(LIBOBJECTS) $(TESTHARNESS) $(EXEC_LDFLAGS) -o $@ $(LDFLAGS) $(COVERAGEFLAGS)

merger_test: table/merger_test.o $(LIBOBJECTS) $(TESTHARNESS)
	$(CXX) table/merger_test.o $(LIBOBJECTS) $(TESTHARNESS) $(EXEC_LDFLAGS) -o $@ $(LDFLAGS) $(COVERAGEFLAGS)

deletefile_test: db/deletefile_test.o $(LIBOBJECTS) $(TESTHARNESS)
	$(CXX) db/deletefile_test.o $(LIBOBJECTS) $(TESTHARNESS) $(EXEC_LDFLAGS) -o $@ $(LDFLAGS)

geodb_test: utilities/geodb/geodb_test.o $(LIBOBJECTS) $(TESTHARNESS)
	$(CXX) utilities/geodb/geodb_test.o $(LIBOBJECTS) $(TESTHARNESS) $(EXEC_LDFLAGS) -o $@ $(LDFLAGS) $(COVERAGEFLAGS)

cuckoo_table_builder_test: table/cuckoo_table_builder_test.o $(LIBOBJECTS) $(TESTHARNESS)
	$(CXX) table/cuckoo_table_builder_test.o  $(LIBOBJECTS) $(TESTHARNESS) $(EXEC_LDFLAGS) -o $@ $(LDFLAGS) $(COVERAGEFLAGS)

cuckoo_table_reader_test: table/cuckoo_table_reader_test.o $(LIBOBJECTS) $(TESTHARNESS) $(BENCHHARNESS)
	$(CXX) table/cuckoo_table_reader_test.o  $(LIBOBJECTS) $(TESTHARNESS) $(BENCHHARNESS) $(EXEC_LDFLAGS) -o $@ $(LDFLAGS) $(COVERAGEFLAGS)

cuckoo_table_db_test: db/cuckoo_table_db_test.o $(LIBOBJECTS) $(TESTHARNESS)
	$(CXX) db/cuckoo_table_db_test.o $(LIBOBJECTS) $(TESTHARNESS) $(EXEC_LDFLAGS) -o $@ $(LDFLAGS) $(COVERAGEFLAGS)

listener_test: db/listener_test.o $(LIBOBJECTS) $(TESTHARNESS)
	$(CXX) db/listener_test.o $(LIBOBJECTS) $(TESTHARNESS) $(EXEC_LDFLAGS) -o $@ $(LDFLAGS) $(COVERAGEFLAGS)

compactor_test: utilities/compaction/compactor_test.o $(LIBOBJECTS) $(TESTHARNESS)
	$(CXX) utilities/compaction/compactor_test.o $(LIBOBJECTS) $(TESTHARNESS) $(EXEC_LDFLAGS) -o $@ $(LDFLAGS) $(COVERAGEFLAGS)

options_test: util/options_test.o $(LIBOBJECTS) $(TESTHARNESS)
	$(CXX) util/options_test.o $(LIBOBJECTS) $(TESTHARNESS) $(EXEC_LDFLAGS) -o $@ $(LDFLAGS) $(COVERAGEFLAGS)

$(MEMENVLIBRARY) : $(MEMENVOBJECTS)
	rm -f $@
	$(AR) -rs $@ $(MEMENVOBJECTS)

memenv_test : helpers/memenv/memenv_test.o $(MEMENVOBJECTS) $(LIBOBJECTS) $(TESTHARNESS)
	$(CXX) helpers/memenv/memenv_test.o $(MEMENVOBJECTS) $(LIBOBJECTS) $(TESTHARNESS) $(EXEC_LDFLAGS) -o $@ $(LDFLAGS) $(COVERAGEFLAGS)

mock_env_test : util/mock_env_test.o $(LIBOBJECTS) $(TESTHARNESS)
	$(CXX) util/mock_env_test.o $(LIBOBJECTS) $(TESTHARNESS) $(EXEC_LDFLAGS) -o $@ $(LDFLAGS) $(COVERAGEFLAGS)

manual_compaction_test: util/manual_compaction_test.o $(LIBOBJECTS) $(TESTHARNESS)
	$(CXX) util/manual_compaction_test.o $(LIBOBJECTS) $(TESTHARNESS) $(EXEC_LDFLAGS) -o $@ $(LDFLAGS) $(COVERAGEFLAGS)

rocksdb_shell: tools/shell/ShellContext.o tools/shell/ShellState.o tools/shell/LeveldbShell.o tools/shell/DBClientProxy.o tools/shell/ShellContext.h tools/shell/ShellState.h tools/shell/DBClientProxy.h $(LIBOBJECTS)
	$(CXX) tools/shell/ShellContext.o tools/shell/ShellState.o tools/shell/LeveldbShell.o tools/shell/DBClientProxy.o $(LIBOBJECTS) $(EXEC_LDFLAGS) -o $@ $(LDFLAGS) $(COVERAGEFLAGS)

DBClientProxy_test: tools/shell/test/DBClientProxyTest.o tools/shell/DBClientProxy.o $(LIBRARY)
	$(CXX) tools/shell/test/DBClientProxyTest.o tools/shell/DBClientProxy.o $(LIBRARY) $(EXEC_LDFLAGS) $(EXEC_LDFLAGS) -o $@  $(LDFLAGS) $(COVERAGEFLAGS)

filelock_test: util/filelock_test.o $(LIBOBJECTS) $(TESTHARNESS)
	$(CXX) util/filelock_test.o $(LIBOBJECTS) $(TESTHARNESS) $(EXEC_LDFLAGS) -o $@ $(LDFLAGS) $(COVERAGEFLAGS)

auto_roll_logger_test: util/auto_roll_logger_test.o $(LIBOBJECTS) $(TESTHARNESS)
	$(CXX) util/auto_roll_logger_test.o $(LIBOBJECTS) $(TESTHARNESS) $(EXEC_LDFLAGS) -o $@ $(LDFLAGS) $(COVERAGEFLAGS)

sst_dump: tools/sst_dump.o $(LIBOBJECTS)
	$(CXX) tools/sst_dump.o $(LIBOBJECTS) $(EXEC_LDFLAGS) -o $@ $(LDFLAGS) $(COVERAGEFLAGS)

ldb: tools/ldb.o $(LIBOBJECTS)
	$(CXX) tools/ldb.o $(LIBOBJECTS) $(EXEC_LDFLAGS) -o $@ $(LDFLAGS) $(COVERAGEFLAGS)

# ---------------------------------------------------------------------------
# Jni stuff
# ---------------------------------------------------------------------------

JNI_NATIVE_SOURCES = ./java/rocksjni/*.cc
JAVA_INCLUDE = -I$(JAVA_HOME)/include/ -I$(JAVA_HOME)/include/linux
ARCH := $(shell getconf LONG_BIT)
ROCKSDBJNILIB = librocksdbjni-linux$(ARCH).so
ROCKSDB_JAR = rocksdbjni-$(ROCKSDB_MAJOR).$(ROCKSDB_MINOR).$(ROCKSDB_PATCH)-linux$(ARCH).jar
ROCKSDB_JAR_ALL = rocksdbjni-$(ROCKSDB_MAJOR).$(ROCKSDB_MINOR).$(ROCKSDB_PATCH).jar
ROCKSDB_JAVADOCS_JAR = rocksdbjni-$(ROCKSDB_MAJOR).$(ROCKSDB_MINOR).$(ROCKSDB_PATCH)-javadoc.jar
ROCKSDB_SOURCES_JAR = rocksdbjni-$(ROCKSDB_MAJOR).$(ROCKSDB_MINOR).$(ROCKSDB_PATCH)-sources.jar

ifeq ($(PLATFORM), OS_MACOSX)
ROCKSDBJNILIB = librocksdbjni-osx.jnilib
ROCKSDB_JAR = rocksdbjni-$(ROCKSDB_MAJOR).$(ROCKSDB_MINOR).$(ROCKSDB_PATCH)-osx.jar
ifneq ("$(wildcard $(JAVA_HOME)/include/darwin)","")
	JAVA_INCLUDE = -I$(JAVA_HOME)/include -I $(JAVA_HOME)/include/darwin
else
	JAVA_INCLUDE = -I/System/Library/Frameworks/JavaVM.framework/Headers/
endif
endif

libz.a:
	-rm -rf zlib-1.2.8
	curl -O http://zlib.net/zlib-1.2.8.tar.gz
	tar xvzf zlib-1.2.8.tar.gz
	cd zlib-1.2.8 && CFLAGS='-fPIC' ./configure --static && make
	cp zlib-1.2.8/libz.a .

libbz2.a:
	-rm -rf bzip2-1.0.6
	curl -O  http://www.bzip.org/1.0.6/bzip2-1.0.6.tar.gz
	tar xvzf bzip2-1.0.6.tar.gz
	cd bzip2-1.0.6 && make CFLAGS='-fPIC -Wall -Winline -O2 -g -D_FILE_OFFSET_BITS=64'
	cp bzip2-1.0.6/libbz2.a .

libsnappy.a:
	-rm -rf snappy-1.1.1
	curl -O https://snappy.googlecode.com/files/snappy-1.1.1.tar.gz
	tar xvzf snappy-1.1.1.tar.gz
	cd snappy-1.1.1 && ./configure --with-pic --enable-static
	cd snappy-1.1.1 && make
	cp snappy-1.1.1/.libs/libsnappy.a .


rocksdbjavastatic: libz.a libbz2.a libsnappy.a
	OPT="-fPIC -DNDEBUG -O2" $(MAKE) $(LIBRARY) -j
	cd java;$(MAKE) java;
	rm -f ./java/$(ROCKSDBJNILIB)
	$(CXX) $(CXXFLAGS) -I./java/. $(JAVA_INCLUDE) -shared -fPIC -o ./java/$(ROCKSDBJNILIB) $(JNI_NATIVE_SOURCES) $(LIBOBJECTS) $(COVERAGEFLAGS) libz.a libbz2.a libsnappy.a
	cd java;jar -cf $(ROCKSDB_JAR) org/rocksdb/*.class org/rocksdb/util/*.class HISTORY*.md $(ROCKSDBJNILIB)
	cd java/javadoc;jar -cf ../$(ROCKSDB_JAVADOCS_JAR) *
	cd java;jar -cf $(ROCKSDB_SOURCES_JAR) org

rocksdbjavastaticrelease: rocksdbjavastatic
	cd java/crossbuild && vagrant destroy -f && vagrant up linux32 && vagrant halt linux32 && vagrant up linux64 && vagrant halt linux64
	cd java;jar -cf $(ROCKSDB_JAR_ALL) org/rocksdb/*.class org/rocksdb/util/*.class HISTORY*.md librocksdbjni-*.so librocksdbjni-*.jnilib

rocksdbjavastaticpublish: rocksdbjavastaticrelease
	mvn gpg:sign-and-deploy-file -Durl=https://oss.sonatype.org/service/local/staging/deploy/maven2/ -DrepositoryId=sonatype-nexus-staging -DpomFile=java/rocksjni.pom -Dfile=java/rocksdbjni-$(ROCKSDB_MAJOR).$(ROCKSDB_MINOR).$(ROCKSDB_PATCH)-javadoc.jar -Dclassifier=javadoc
	mvn gpg:sign-and-deploy-file -Durl=https://oss.sonatype.org/service/local/staging/deploy/maven2/ -DrepositoryId=sonatype-nexus-staging -DpomFile=java/rocksjni.pom -Dfile=java/rocksdbjni-$(ROCKSDB_MAJOR).$(ROCKSDB_MINOR).$(ROCKSDB_PATCH)-sources.jar -Dclassifier=sources
	mvn gpg:sign-and-deploy-file -Durl=https://oss.sonatype.org/service/local/staging/deploy/maven2/ -DrepositoryId=sonatype-nexus-staging -DpomFile=java/rocksjni.pom -Dfile=java/rocksdbjni-$(ROCKSDB_MAJOR).$(ROCKSDB_MINOR).$(ROCKSDB_PATCH)-linux64.jar -Dclassifier=linux64
	mvn gpg:sign-and-deploy-file -Durl=https://oss.sonatype.org/service/local/staging/deploy/maven2/ -DrepositoryId=sonatype-nexus-staging -DpomFile=java/rocksjni.pom -Dfile=java/rocksdbjni-$(ROCKSDB_MAJOR).$(ROCKSDB_MINOR).$(ROCKSDB_PATCH)-linux32.jar -Dclassifier=linux32
	mvn gpg:sign-and-deploy-file -Durl=https://oss.sonatype.org/service/local/staging/deploy/maven2/ -DrepositoryId=sonatype-nexus-staging -DpomFile=java/rocksjni.pom -Dfile=java/rocksdbjni-$(ROCKSDB_MAJOR).$(ROCKSDB_MINOR).$(ROCKSDB_PATCH)-osx.jar -Dclassifier=osx
	mvn gpg:sign-and-deploy-file -Durl=https://oss.sonatype.org/service/local/staging/deploy/maven2/ -DrepositoryId=sonatype-nexus-staging -DpomFile=java/rocksjni.pom -Dfile=java/rocksdbjni-$(ROCKSDB_MAJOR).$(ROCKSDB_MINOR).$(ROCKSDB_PATCH).jar

rocksdbjava:
	OPT="-fPIC -DNDEBUG -O2" $(MAKE) $(LIBRARY) -j32
	cd java;$(MAKE) java;
	rm -f ./java/$(ROCKSDBJNILIB)
	$(CXX) $(CXXFLAGS) -I./java/. $(JAVA_INCLUDE) -shared -fPIC -o ./java/$(ROCKSDBJNILIB) $(JNI_NATIVE_SOURCES) $(LIBOBJECTS) $(JAVA_LDFLAGS) $(COVERAGEFLAGS)
	cd java;jar -cf $(ROCKSDB_JAR) org/rocksdb/*.class org/rocksdb/util/*.class HISTORY*.md $(ROCKSDBJNILIB)

jclean:
	cd java;$(MAKE) clean;
	rm -f $(ROCKSDBJNILIB)

jtest:
	cd java;$(MAKE) sample;$(MAKE) test;

jdb_bench:
	cd java;$(MAKE) db_bench;

# ---------------------------------------------------------------------------
#  	Platform-specific compilation
# ---------------------------------------------------------------------------

ifeq ($(PLATFORM), IOS)
# For iOS, create universal object files to be used on both the simulator and
# a device.
PLATFORMSROOT=/Applications/Xcode.app/Contents/Developer/Platforms
SIMULATORROOT=$(PLATFORMSROOT)/iPhoneSimulator.platform/Developer
DEVICEROOT=$(PLATFORMSROOT)/iPhoneOS.platform/Developer
IOSVERSION=$(shell defaults read $(PLATFORMSROOT)/iPhoneOS.platform/version CFBundleShortVersionString)

.cc.o:
	mkdir -p ios-x86/$(dir $@)
	$(CXX) $(CXXFLAGS) -isysroot $(SIMULATORROOT)/SDKs/iPhoneSimulator$(IOSVERSION).sdk -arch i686 -arch x86_64 -c $< -o ios-x86/$@
	mkdir -p ios-arm/$(dir $@)
	xcrun -sdk iphoneos $(CXX) $(CXXFLAGS) -isysroot $(DEVICEROOT)/SDKs/iPhoneOS$(IOSVERSION).sdk -arch armv6 -arch armv7 -arch armv7s -arch arm64 -c $< -o ios-arm/$@
	lipo ios-x86/$@ ios-arm/$@ -create -output $@

.c.o:
	mkdir -p ios-x86/$(dir $@)
	$(CC) $(CFLAGS) -isysroot $(SIMULATORROOT)/SDKs/iPhoneSimulator$(IOSVERSION).sdk -arch i686 -arch x86_64 -c $< -o ios-x86/$@
	mkdir -p ios-arm/$(dir $@)
	xcrun -sdk iphoneos $(CC) $(CFLAGS) -isysroot $(DEVICEROOT)/SDKs/iPhoneOS$(IOSVERSION).sdk -arch armv6 -arch armv7 -arch armv7s -arch arm64 -c $< -o ios-arm/$@
	lipo ios-x86/$@ ios-arm/$@ -create -output $@

else
.cc.o:
	$(CXX) $(CXXFLAGS) -c $< -o $@ $(COVERAGEFLAGS)

.c.o:
	$(CC) $(CFLAGS) -c $< -o $@
endif

# ---------------------------------------------------------------------------
#  	Source files dependencies detection
# ---------------------------------------------------------------------------

# Add proper dependency support so changing a .h file forces a .cc file to
# rebuild.

# The .d file indicates .cc file's dependencies on .h files. We generate such
# dependency by g++'s -MM option, whose output is a make dependency rule.
# The sed command makes sure the "target" file in the generated .d file has
# the correct path prefix.
%.d: %.cc
	$(CXX) $(CXXFLAGS) $(PLATFORM_SHARED_CFLAGS) -MM $< -o $@
ifeq ($(PLATFORM), OS_MACOSX)
	@sed -i '' -e 's,.*:,$*.o:,' $@
else
	@sed -i -e 's,.*:,$*.o:,' $@
endif

DEPFILES = $(filter-out util/build_version.d,$(SOURCES:.cc=.d))

depend: $(DEPFILES)

# if the make goal is either "clean" or "format", we shouldn't
# try to import the *.d files.
# TODO(kailiu) The unfamiliarity of Make's conditions leads to the ugly
# working solution.
ifneq ($(MAKECMDGOALS),clean)
ifneq ($(MAKECMDGOALS),format)
ifneq ($(MAKECMDGOALS),jclean)
ifneq ($(MAKECMDGOALS),jtest)
ifneq ($(MAKECMDGOALS),package)
-include $(DEPFILES)
endif
endif
endif
endif
endif

# Copyright (c) 2018-2022 Status Research & Development GmbH. Licensed under
# either of:
# - Apache License, version 2.0
# - MIT license
# at your option. This file may not be copied, modified, or distributed except
# according to those terms.

SHELL := bash # the shell used internally by "make"

# used inside the included makefiles
BUILD_SYSTEM_DIR := vendor/nimbus-build-system

LINK_PCRE := 0

EXCLUDED_NIM_PACKAGES := 	\
	vendor/nimbus-eth2/vendor/nim-bearssl 					\
	vendor/nimbus-eth2/vendor/nim-blscurve 					\
	vendor/nimbus-eth2/vendor/nim-bearssl 					\
	vendor/nimbus-eth2/vendor/nim-blscurve					\
	vendor/nimbus-eth2/vendor/nimbus-build-system		\
	vendor/nimbus-eth2/vendor/nim-chronicles				\
	vendor/nimbus-eth2/vendor/nim-chronos						\
	vendor/nimbus-eth2/vendor/nim-confutils					\
	vendor/nimbus-eth2/vendor/nimcrypto							\
	vendor/nimbus-eth2/vendor/nim-eth								\
	vendor/nimbus-eth2/vendor/nim-faststreams				\
	vendor/nimbus-eth2/vendor/nim-http-utils				\
	vendor/nimbus-eth2/vendor/nim-json-rpc					\
	vendor/nimbus-eth2/vendor/nim-json-serialization\
	vendor/nimbus-eth2/vendor/nim-libbacktrace			\
	vendor/nimbus-eth2/vendor/nim-metrics						\
	vendor/nimbus-eth2/vendor/nim-nat-traversal			\
  vendor/nimbus-eth2/vendor/nim-results     			\
	vendor/nimbus-eth2/vendor/nim-secp256k1					\
	vendor/nimbus-eth2/vendor/nim-serialization			\
	vendor/nimbus-eth2/vendor/nim-snappy						\
	vendor/nimbus-eth2/vendor/nim-sqlite3-abi				\
	vendor/nimbus-eth2/vendor/nim-ssz-serialization	\
	vendor/nimbus-eth2/vendor/nim-stew							\
	vendor/nimbus-eth2/vendor/nim-stint							\
	vendor/nimbus-eth2/vendor/nim-testutils					\
	vendor/nimbus-eth2/vendor/nim-toml-serialization\
	vendor/nimbus-eth2/vendor/nim-unittest2					\
	vendor/nimbus-eth2/vendor/nim-web3							\
	vendor/nimbus-eth2/vendor/nim-websock						\
	vendor/nimbus-eth2/vendor/nim-zlib							\
	vendor/nimbus-eth2/vendor/nim-taskpools					\
	vendor/nimbus-eth2/vendor/nim-normalize					\
	vendor/nimbus-eth2/vendor/nim-unicodedb					\
	vendor/nimbus-eth2/vendor/nim-libp2p						\
	vendor/nimbus-eth2/vendor/nim-presto						\
	vendor/nimbus-eth2/vendor/nim-zxcvbn						\
  vendor/nimbus-eth2/vendor/nim-kzg4844						\
	vendor/nimbus-eth2/vendor/nimbus-security-resources

# we don't want an error here, so we can handle things later, in the ".DEFAULT" target
-include $(BUILD_SYSTEM_DIR)/makefiles/variables.mk

# debugging tools + testing tools
TOOLS := \
	test_tools_build
TOOLS_DIRS := \
	tests
# comma-separated values for the "clean" target
TOOLS_CSV := $(subst $(SPACE),$(COMMA),$(TOOLS))

# Fluffy debugging tools + testing tools
FLUFFY_TOOLS := \
	beacon_chain_bridge \
	beacon_lc_bridge \
	eth_data_exporter \
	content_verifier \
	blockwalk \
	portalcli
FLUFFY_TOOLS_DIRS := \
	fluffy/tools/beacon_lc_bridge \
	fluffy/tools/beacon_chain_bridge \
	fluffy/tools
# comma-separated values for the "clean" target
FLUFFY_TOOLS_CSV := $(subst $(SPACE),$(COMMA),$(FLUFFY_TOOLS))

.PHONY: \
	all \
	$(TOOLS) \
	$(FLUFFY_TOOLS) \
	deps \
	update \
	nimbus \
	fluffy \
	nimbus_verified_proxy \
	test \
	test-reproducibility \
	clean \
	libnimbus.so \
	libnimbus.a \
	libbacktrace \
	dist-amd64 \
	dist-arm64 \
	dist-arm \
	dist-win64 \
	dist-macos \
	dist-macos-arm64 \
	dist

ifeq ($(NIM_PARAMS),)
# "variables.mk" was not included, so we update the submodules.
# selectively download nimbus-eth2 submodules because we don't need all of it's modules
# also holesky already exceeds github LFS quota
GIT_SUBMODULE_UPDATE := git -c submodule."vendor/nimbus-eth2".update=none submodule update --init --recursive; \
  git submodule update vendor/nimbus-eth2; \
  cd vendor/nimbus-eth2; \
  git submodule update --init vendor/eth2-networks; \
  git submodule update --init vendor/holesky; \
  git submodule update --init vendor/sepolia; \
  git submodule update --init vendor/gnosis-chain-configs; \
  git submodule update --init --recursive vendor/nim-kzg4844; \
  cd ../..

.DEFAULT:
	+@ echo -e "Git submodules not found. Running '$(GIT_SUBMODULE_UPDATE)'.\n"; \
		$(GIT_SUBMODULE_UPDATE); \
		echo
# Now that the included *.mk files appeared, and are newer than this file, Make will restart itself:
# https://www.gnu.org/software/make/manual/make.html#Remaking-Makefiles
#
# After restarting, it will execute its original goal, so we don't have to start a child Make here
# with "$(MAKE) $(MAKECMDGOALS)". Isn't hidden control flow great?

else # "variables.mk" was included. Business as usual until the end of this file.

# default target, because it's the first one that doesn't start with '.'
all: | $(TOOLS) nimbus

# must be included after the default target
-include $(BUILD_SYSTEM_DIR)/makefiles/targets.mk

# default: use blst
USE_MIRACL := 0

# default: use nim native evm
ENABLE_EVMC := 0

# "-d:release" cannot be added to config.nims

NIM_PARAMS += -d:release
ifeq ($(BOEHM_GC),1)
NIM_PARAMS += --mm:boehm
endif

T8N_PARAMS := -d:chronicles_default_output_device=stderr

ifeq ($(USE_LIBBACKTRACE), 0)
  NIM_PARAMS += -d:disable_libbacktrace
endif

# TODO: port this back to nimbus-build-system
# after we can switch to nim 1.6.16
# This rule override the one in targets.mk
libnatpmp.a: | sanity-checks
ifeq ($(OS), Windows_NT)
	+ "$(MAKE)" -C vendor/nim-nat-traversal/vendor/libnatpmp-upstream OS=mingw CC=$(CC) CFLAGS="-Wall -Wno-cpp -Os -DWIN32 -DNATPMP_STATICLIB -DENABLE_STRNATPMPERR -DNATPMP_MAX_RETRIES=4 $(CFLAGS)" $@ $(HANDLE_OUTPUT)
else
	+ "$(MAKE)" CFLAGS="-Wall -Wno-cpp -Os -DENABLE_STRNATPMPERR -DNATPMP_MAX_RETRIES=4 $(CFLAGS)" -C vendor/nim-nat-traversal/vendor/libnatpmp-upstream $@ $(HANDLE_OUTPUT)
endif

deps: | deps-common nat-libs nimbus.nims
ifneq ($(USE_LIBBACKTRACE), 0)
deps: | libbacktrace
endif

ifneq ($(USE_MIRACL), 0)
  NIM_PARAMS += -d:BLS_FORCE_BACKEND=miracl
endif

ifneq ($(ENABLE_EVMC), 0)
  NIM_PARAMS += -d:evmc_enabled
  T8N_PARAMS := -d:chronicles_enabled=off
endif

# disabled by default, enable with ENABLE_VMLOWMEM=1
ifneq ($(if $(ENABLE_VMLOWMEM),$(ENABLE_VMLOWMEM),0),0)
  NIM_PARAMS += -d:lowmem:1
endif

# chunked messages enabled by default, use ENABLE_CHUNKED_RLPX=0 to disable
ifneq ($(if $(ENABLE_CHUNKED_RLPX),$(ENABLE_CHUNKED_RLPX),1),0)
NIM_PARAMS := $(NIM_PARAMS) -d:chunked_rlpx_enabled
endif

# legacy wire protocol enabled by default, use ENABLE_LEGACY_ETH66=0 to disable
ifneq ($(if $(ENABLE_LEGACY_ETH66),$(ENABLE_LEGACY_ETH66),1),0)
NIM_PARAMS := $(NIM_PARAMS) -d:legacy_eth66_enabled
endif

#- deletes and recreates "nimbus.nims" which on Windows is a copy instead of a proper symlink
update: | update-common
	rm -rf nimbus.nims && \
		$(MAKE) nimbus.nims $(HANDLE_OUTPUT)

update-from-ci: | sanity-checks update-test
	rm -rf nimbus.nims && \
		$(MAKE) nimbus.nims $(HANDLE_OUTPUT)
	+ "$(MAKE)" --no-print-directory deps-common

# builds the tools, wherever they are
$(TOOLS): | build deps
	for D in $(TOOLS_DIRS); do [ -e "$${D}/$@.nim" ] && TOOL_DIR="$${D}" && break; done && \
		echo -e $(BUILD_MSG) "build/$@" && \
		$(ENV_SCRIPT) nim c $(NIM_PARAMS) -o:build/$@ "$${TOOL_DIR}/$@.nim"

# a phony target, because teaching `make` how to do conditional recompilation of Nim projects is too complicated
nimbus: | build deps
	echo -e $(BUILD_MSG) "build/$@" && \
		$(ENV_SCRIPT) nim c $(NIM_PARAMS) -d:chronicles_log_level=TRACE -o:build/$@ "nimbus/$@.nim"

# symlink
nimbus.nims:
	ln -s nimbus.nimble $@

# nim-libbacktrace
libbacktrace:
	+ $(MAKE) -C vendor/nim-libbacktrace --no-print-directory BUILD_CXX_LIB=0

# builds and runs the nimbus test suite
test: | build deps
	$(ENV_SCRIPT) nim test_rocksdb $(NIM_PARAMS) nimbus.nims
	$(ENV_SCRIPT) nim test $(NIM_PARAMS) nimbus.nims

# builds and runs an EVM-related subset of the nimbus test suite
test-evm: | build deps
	$(ENV_SCRIPT) nim test_evm $(NIM_PARAMS) nimbus.nims

# Primitive reproducibility test.
#
# On some platforms, with some GCC versions, it may not be possible to get a
# deterministic order for debugging info sections - even with
# "-frandom-seed=...". Striping the binaries should make them identical, though.
test-reproducibility:
	+ [ -e build/nimbus ] || $(MAKE) V=0 nimbus; \
		MD5SUM1=$$($(MD5SUM) build/nimbus | cut -d ' ' -f 1) && \
		rm -rf nimcache/*/nimbus && \
		$(MAKE) V=0 nimbus && \
		MD5SUM2=$$($(MD5SUM) build/nimbus | cut -d ' ' -f 1) && \
		[ "$$MD5SUM1" = "$$MD5SUM2" ] && echo -e "\e[92mSuccess: identical binaries.\e[39m" || \
			{ echo -e "\e[91mFailure: the binary changed between builds.\e[39m"; exit 1; }

# Fluffy related targets

# builds the fluffy client
fluffy: | build deps
	echo -e $(BUILD_MSG) "build/$@" && \
		$(ENV_SCRIPT) nim c $(NIM_PARAMS) -d:chronicles_log_level=TRACE -o:build/$@ "fluffy/$@.nim"

# primitive reproducibility test
fluffy-test-reproducibility:
	+ [ -e build/fluffy ] || $(MAKE) V=0 fluffy; \
		MD5SUM1=$$($(MD5SUM) build/fluffy | cut -d ' ' -f 1) && \
		rm -rf nimcache/*/fluffy && \
		$(MAKE) V=0 fluffy && \
		MD5SUM2=$$($(MD5SUM) build/fluffy | cut -d ' ' -f 1) && \
		[ "$$MD5SUM1" = "$$MD5SUM2" ] && echo -e "\e[92mSuccess: identical binaries.\e[39m" || \
			{ echo -e "\e[91mFailure: the binary changed between builds.\e[39m"; exit 1; }

# fluffy tests
all_fluffy_portal_spec_tests: | build deps
	echo -e $(BUILD_MSG) "build/$@" && \
	$(ENV_SCRIPT) nim c -r $(NIM_PARAMS) -d:chronicles_log_level=ERROR -d:nimbus_db_backend=sqlite -o:build/$@ "fluffy/tests/portal_spec_tests/mainnet/$@.nim"


all_fluffy_tests: | build deps
	echo -e $(BUILD_MSG) "build/$@" && \
	$(ENV_SCRIPT) nim c -r $(NIM_PARAMS) -d:chronicles_log_level=ERROR -d:nimbus_db_backend=sqlite -d:mergeBlockNumber:38130 -o:build/$@ "fluffy/tests/$@.nim"

# builds and runs the fluffy test suite
fluffy-test: | all_fluffy_portal_spec_tests all_fluffy_tests

# builds the fluffy tools, wherever they are
$(FLUFFY_TOOLS): | build deps
	for D in $(FLUFFY_TOOLS_DIRS); do [ -e "$${D}/$@.nim" ] && TOOL_DIR="$${D}" && break; done && \
		echo -e $(BUILD_MSG) "build/$@" && \
		$(ENV_SCRIPT) nim c $(NIM_PARAMS) -d:chronicles_log_level=TRACE -o:build/$@ "$${TOOL_DIR}/$@.nim"

# builds all the fluffy tools
fluffy-tools: | $(FLUFFY_TOOLS)

# Build fluffy test_portal_testnet
test_portal_testnet: | build deps
	echo -e $(BUILD_MSG) "build/$@" && \
		$(ENV_SCRIPT) nim c $(NIM_PARAMS) -o:build/$@ "fluffy/scripts/$@.nim"

# builds the uTP test app
utp-test-app: | build deps
	$(ENV_SCRIPT) nim utp_test_app $(NIM_PARAMS) nimbus.nims

# builds and runs the utp integration test suite
utp-test: | build deps
	$(ENV_SCRIPT) nim utp_test $(NIM_PARAMS) nimbus.nims

# Nimbus Verified Proxy related targets

# Builds the nimbus_verified_proxy
nimbus_verified_proxy: | build deps
	echo -e $(BUILD_MSG) "build/$@" && \
		$(ENV_SCRIPT) nim nimbus_verified_proxy $(NIM_PARAMS) nimbus.nims

# builds and runs the nimbus_verified_proxy test suite
nimbus-verified-proxy-test: | build deps
	$(ENV_SCRIPT) nim nimbus_verified_proxy_test $(NIM_PARAMS) nimbus.nims

# builds transition tool
t8n: | build deps
	$(ENV_SCRIPT) nim c $(NIM_PARAMS) $(T8N_PARAMS) "tools/t8n/$@.nim"

# builds and runs transition tool test suite
t8n_test: | build deps t8n
	$(ENV_SCRIPT) nim c -r $(NIM_PARAMS) -d:chronicles_default_output_device=stderr "tools/t8n/$@.nim"

# builds evm state test tool
evmstate: | build deps
	$(ENV_SCRIPT) nim c $(NIM_PARAMS) "tools/evmstate/$@.nim"

# builds and runs evm state tool test suite
evmstate_test: | build deps evmstate
	$(ENV_SCRIPT) nim c -r $(NIM_PARAMS) "tools/evmstate/$@.nim"

# builds txparse tool
txparse: | build deps
	$(ENV_SCRIPT) nim c $(NIM_PARAMS) "tools/txparse/$@.nim"

# usual cleaning
clean: | clean-common
	rm -rf build/{nimbus,fluffy,nimbus_verified_proxy,$(TOOLS_CSV),$(FLUFFY_TOOLS_CSV),all_tests,test_kvstore_rocksdb,test_rpc,all_fluffy_tests,all_fluffy_portal_spec_tests,test_portal_testnet,portalcli,blockwalk,eth_data_exporter,utp_test_app,utp_test,*.dSYM}
	rm -rf tools/t8n/{t8n,t8n_test}
	rm -rf tools/evmstate/{evmstate,evmstate_test}
ifneq ($(USE_LIBBACKTRACE), 0)
	+ $(MAKE) -C vendor/nim-libbacktrace clean $(HANDLE_OUTPUT)
endif

# Note about building Nimbus as a library:
#
# There were `wrappers`, `wrappers-static`, `libnimbus.so` and `libnimbus.a`
# target scripts here, and C and Go examples for calling the Nimbus library in
# directory `wrappers/`.  They have been removed because they only wrapped
# Whisper protocol support, which has been removed as it is obsolete.
#
# This note is kept so that anyone wanting to build Nimbus as a library or call
# from C or Go will know it has been done before.  The previous working version
# can be found in Git history.  Look for the `nimbus-eth1` commit that adds
# this comment and removes `wrappers/*`.

dist-amd64:
	+ MAKE="$(MAKE)" \
		scripts/make_dist.sh amd64

dist-arm64:
	+ MAKE="$(MAKE)" \
		scripts/make_dist.sh arm64

# We get an ICE on RocksDB-7.0.2 with "arm-linux-gnueabihf-g++ (Ubuntu 9.4.0-1ubuntu1~20.04.1) 9.4.0"
# and with "arm-linux-gnueabihf-g++ (Ubuntu 10.3.0-1ubuntu1) 10.3.0".
#dist-arm:
	#+ MAKE="$(MAKE)" \
		#scripts/make_dist.sh arm

dist-win64:
	+ MAKE="$(MAKE)" \
		scripts/make_dist.sh win64

dist-macos:
	+ MAKE="$(MAKE)" \
		scripts/make_dist.sh macos

dist-macos-arm64:
	+ MAKE="$(MAKE)" \
		scripts/make_dist.sh macos-arm64

dist:
	+ $(MAKE) --no-print-directory dist-amd64
	+ $(MAKE) --no-print-directory dist-arm64
	#+ $(MAKE) --no-print-directory dist-arm
	+ $(MAKE) --no-print-directory dist-win64
	+ $(MAKE) --no-print-directory dist-macos
	+ $(MAKE) --no-print-directory dist-macos-arm64

endif # "variables.mk" was not included

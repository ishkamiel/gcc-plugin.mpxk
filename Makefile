CC := gcc
CXX := g++
RM := rm

GCCPLUGINS_DIR := $(shell $(CC) -print-file-name=plugin)
PLUGIN_FLAGS := -I$(GCCPLUGINS_DIR)/include -I$(GCCPLUGINS_DIR)/include/c-family #-Wno-unused-parameter -Wno-unused-variable #-fdump-passes
DESTDIR :=
LDFLAGS :=

PLUGIN := mpxk.so
TEST_BIN := run_test
TEST_DIR := test

OBJ := mpxk.o mpxk_builtins.o
OBJ += mpxk_pass_wrappers.o
OBJ += mpxk_pass_bnd_store.o
OBJ += mpxk_pass_rm_bndstx.o
OBJ += mpxk_pass_cfun_args.o
OBJ += mpxk_pass_sweeper.o

SRC := $(OBJ:.o=.c)

TEST_SRC := $(wildcard $(TEST_DIR)/*.c)
TEST_OBJ := $(TEST_SRC:.c=.o)

TEST_DUMPS := $(TEST_OBJ:.o=.c.*);


CONFIG_SHELL := $(shell if [ -x "$$BASH" ]; then echo $$BASH; \
		else if [ -x /bin/bash ]; then echo /bin/bash; \
			else echo sh; fi ; fi)

PLUGINCC := $(shell $(CONFIG_SHELL) gcc-plugin.sh "$(CC)" "$(CXX)" "$(CC)")

ifeq ($(PLUGINCC),$(CC))
	PLUGIN_FLAGS += -std=gnu99 -O0
else
	PLUGIN_FLAGS += -std=gnu++98 -fno-rtti -Wno-narrowing -Og
endif

PLUGIN_FLAGS += -fPIC -shared -ggdb -Wall -W -fvisibility=hidden

DUMP_FLAGS := -fdump-rtl-all -fdump-tree-all -fdump-ipa-all

MPXK_CFLAGS := -fplugin=./$(PLUGIN) -mmpx -fcheck-pointer-bounds
MPXK_CFLAGS += -fno-chkp-store-bounds -fno-chkp-narrow-bounds -fno-chkp-check-read -fno-chkp-use-wrappers
MPXK_LIB_CFLAGS := $(MPXK_CFLAGS) -fno-chkp-check-write

# FIXME: This doesn't properly replicate KBuild, I think.
KERNEL_FLAGS := -O2

all: $(PLUGIN)

$(PLUGIN): $(OBJ)
	$(PLUGINCC) $(PLUGIN_FLAGS) -o $@ $^

%.o: %.c
	$(PLUGINCC) $(PLUGIN_FLAGS) -o $@ -c $<

test: $(PLUGIN) $(TEST_BIN)
	./$(TEST_BIN)

$(TEST_BIN): $(PLUGIN) $(TEST_OBJ)
	$(CC) $(KERNEL_FLAGS) $(MPXK_CFLAGS) -o $(TEST_BIN) $(TEST_OBJ)

test/%.o: $(PLUGIN) test/%.c
	$(CC) $(KERNEL_FLAGS) $(MPXK_CFLAGS) $(DUMP_FLAGS) -o $@ -c $(@:.o=.c)

test/mpxk_functions.o: $(PLUGIN) test/mpxk_functions.c
	$(CC) $(KERNEL_FLAGS) $(MPXK_LIB_CFLAGS) -o $@ -c $(@:.o=.c)

clean:
	$(RM) -f $(PLUGIN) $(TEST_BIN) $(PLUGIN) $(OBJ) $(TEST_OBJ) $(TEST_DUMPS)

print-%: ; @echo $* = $($*)

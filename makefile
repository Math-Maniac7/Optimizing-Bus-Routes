# -----------------------------
# Config
# -----------------------------
CXX       := g++
CXXFLAGS  := -std=c++20 -O2 -g -Iinclude
SRCDIR    := src
BUILDDIR  := build
ENTRY     := $(SRCDIR)/main.cpp

# Cross-platform exe extension
EXEEXT    :=
ifeq ($(OS),Windows_NT)
  EXEEXT := .exe
endif
TARGET    := route_generator$(EXEEXT)

# -----------------------------
# Source discovery (recursive)
# - POSIX: use `find`
# - Windows: use PowerShell
# -----------------------------
ifeq ($(OS),Windows_NT)
  SRCS_RAW := $(shell powershell -NoProfile -ExecutionPolicy Bypass -Command \
    "Get-ChildItem -Recurse -File '$(SRCDIR)' -Include *.cpp | ForEach-Object { (Resolve-Path -Relative $$_.FullName).Replace('\\','/') }")
else
  SRCS_RAW := $(shell find $(SRCDIR) -type f -name '*.cpp')
endif

# Normalize paths (drop leading ./)
normalize = $(patsubst ./%,%,$(1))
SRCS  := $(call normalize,$(SRCS_RAW))
ENTRY := $(call normalize,$(ENTRY))

# Exclude entry from SRCS, compile it separately
SRCS := $(filter-out $(ENTRY),$(SRCS))

# Map e.g. src/foo/bar.cpp -> build/src/foo/bar.o
OBJS      := $(patsubst %.cpp,$(BUILDDIR)/%.o,$(SRCS))
ENTRY_OBJ := $(BUILDDIR)/$(ENTRY:.cpp=.o)
DEPS      := $(OBJS:.o=.d) $(ENTRY_OBJ:.o=.d)

# -----------------------------
# Default
# -----------------------------
all: $(TARGET)

# Link
$(TARGET): $(OBJS)
	@echo "  LINK    $@"
	$(CXX) $^ -o $@

# Compile
$(BUILDDIR)/%.o: %.cpp
	@echo "  CXX     $<"
	@$(call MKDIR_P,$(dir $@))
	$(CXX) $(CXXFLAGS) -c $< -o $@

# Auto-deps
-include $(DEPS)

# -----------------------------
# Cross-platform mkdir / rm
# -----------------------------
ifeq ($(OS),Windows_NT)
  define MKDIR_P
  powershell -NoProfile -ExecutionPolicy Bypass -Command "New-Item -ItemType Directory -Force '$(1)'" > NUL
  endef
  define RM_RF
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Remove-Item -Recurse -Force '$(1)'" 2> NUL
  endef
  define RM_F
  powershell -NoProfile -ExecutionPolicy Bypass -Command "If (Test-Path '$(1)') { Remove-Item -Force '$(1)' }"
  endef
else
  define MKDIR_P
  mkdir -p $(1)
  endef
  define RM_RF
  rm -rf $(1)
  endef
  define RM_F
  rm -f $(1)
  endef
endif

# -----------------------------
# Utilities
# -----------------------------
.PHONY: clean run print
clean:
	@echo "  CLEAN"
	@$(call RM_RF,$(BUILDDIR))
	@$(call RM_F,$(TARGET))

run: $(TARGET)
	./$(TARGET)

# Debug helpers
print:
	@echo SRCS=$(SRCS)
	@echo OBJS=$(OBJS)
	@echo ENTRY=$(ENTRY)
	@echo ENTRY_OBJ=$(ENTRY_OBJ)

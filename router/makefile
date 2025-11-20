# =========================
# Native build (g++)
# =========================

CXX := g++
CXXFLAGS := -std=c++17 -Iinclude -g -O2
LDFLAGS := $(shell pkg-config --libs libcurl)

# Entry point
ENTRY := ./src/main.cpp

# Output binary name
TARGET := ./router.exe

# Find all .cpp files (recursively) under ./src
SRCS := $(filter-out $(ENTRY), $(shell find ./src -name '*.cpp'))
OBJS := $(SRCS:%.cpp=build/%.o)

# Ensure output directories exist for native build
DIRS := $(sort $(dir $(OBJS)))

# Default target builds native binary
all: $(TARGET)

# Build the final native binary
$(TARGET): $(OBJS) build/$(subst .cpp,.o,$(ENTRY))
	$(CXX) $(CXXFLAGS) $^ -o $@ $(LDFLAGS)

# Compile .cpp to .o into build/ directory (native)
build/%.o: %.cpp
	@mkdir -p $(dir $@)
	$(CXX) $(CXXFLAGS) -c $< -o $@


# =========================
# WASM build (emcc)
# =========================

EMCC := emcc
WASM_TARGET := router.html

# Reuse the same sources & entry for WASM
WASM_ENTRY := $(ENTRY)
WASM_SRCS := $(SRCS)
# Put wasm objects in a separate tree to avoid collisions
WASM_OBJS := $(WASM_SRCS:%.cpp=build_wasm/%.o)
WASM_ENTRY_OBJ := build_wasm/$(subst .cpp,.o,$(WASM_ENTRY))

EMCC_FLAGS := \
	-s EXPORTED_RUNTIME_METHODS='["UTF8ToString","stringToUTF8","allocateUTF8"]' \
	-s EXPORTED_FUNCTIONS='["_free"]' \
	-O3 \
	-std=c++17 \
	-sASYNCIFY \
	-sFETCH \
	-s ASSERTIONS=1 \
	-s ALLOW_MEMORY_GROWTH=1

# Top-level target to build WASM
wasm: $(WASM_TARGET)

# Link all wasm objects into router.html
$(WASM_TARGET): $(WASM_OBJS) $(WASM_ENTRY_OBJ)
	$(EMCC) $^ -o $@ $(EMCC_FLAGS)

# Compile .cpp to .o into build_wasm/ directory (for WASM)
build_wasm/%.o: %.cpp
	@mkdir -p $(dir $@)
	$(EMCC) -c $< -o $@ $(EMCC_FLAGS)
	
# =========================
# Utilities
# =========================

clean:
	rm -rf build build_wasm $(TARGET) $(WASM_TARGET)

.PHONY: all clean wasm

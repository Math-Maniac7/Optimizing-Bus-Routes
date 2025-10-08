# Compiler and flags
CXX := g++
CXXFLAGS := -std=c++17 -Iinclude -g -O2
LDFLAGS := $(shell pkg-config --libs libcurl)

# Entry point
ENTRY := ./src/main.cpp

# Output binary name
TARGET := ./router.exe

# Find all .cpp files (recursively)
SRCS := $(filter-out $(ENTRY), $(shell find . -wholename './src/*.cpp'))
OBJS := $(SRCS:%.cpp=build/%.o)

# Ensure output directories exist
DIRS := $(sort $(dir $(OBJS)))

# Default target
all: $(TARGET)

# Build the final binary
$(TARGET): $(OBJS) build/$(subst .cpp,.o,$(ENTRY))
	$(CXX) $(CXXFLAGS) $^ -o $@ $(LDFLAGS)

# Compile .cpp to .o into build/ directory
build/%.o: %.cpp
	@mkdir -p $(dir $@)
	$(CXX) $(CXXFLAGS) -c $< -o $@

# Clean up build artifacts
clean:
	rm -rf build $(TARGET)

.PHONY: all clean

# Optimizing-Bus-Routes

COMPILE FOR WEBASSEMBLY WITH THIS COMMAND: 
emcc -o router.js main.cpp utils.cpp graph/Graph.cpp http/http.cpp routing/BRP.cpp routing/Bus.cpp routing/BusRoute.cpp routing/BusStop.cpp routing/BusStopAssignment.cpp routing/Coordinate.cpp routing/Student.cpp -s EXPORTED_RUNTIME_METHODS='["UTF8ToString","stringToUTF8","allocateUTF8","_free"]' -O3 -std=c++17 -sASYNCIFY -sFETCH
# Optimizing-Bus-Routes

COMPILE WITH THIS COMMAND

emcc -o router.html  main.cpp utils.cpp graph/Graph.cpp http/http.cpp routing/BRP.cpp routing/Bus.cpp routing/BusRoute.cpp routing/BusStop.cpp routing/BusStopAssignment.cpp routing/Coordinate.cpp routing/Student.cpp -s EXPORTED_RUNTIME_METHODS='["UTF8ToString","stringToUTF8","allocateUTF8"]' -s EXPORTED_FUNCTIONS='["_free"]' -O3 -std=c++17 -sASYNCIFY -sFETCH -s ASSERTIONS=1 -s ALLOW_MEMORY_GROWTH=1


NEW COMMAND
emcc -o router.html  main.cpp utils.cpp graph/Graph.cpp http/http.cpp routing/BRP.cpp routing/Bus.cpp routing/BusRoute.cpp routing/BusStop.cpp routing/BusStopAssignment.cpp routing/Coordinate.cpp routing/Student.cpp algorithm/mcmf.cpp algorithm/dbscan.cpp -s EXPORTED_RUNTIME_METHODS='["UTF8ToString","stringToUTF8","allocateUTF8"]' -s EXPORTED_FUNCTIONS='["_free"]' -O3 -std=c++17 -sASYNCIFY -sFETCH -s ASSERTIONS=1 -s ALLOW_MEMORY_GROWTH=1        
can.cpp -s EXPORTED_RUNTIME_METHODS='["UTF8ToString","stringToUTF8","allocateUTF8"]' -s EXPORTED_FUNCTIONS='["_free"]' -O3 -std=c++17 -sASYNCIFY -sFETCH -s ASSERTIONS=1 -s ALLOW_MEMORY_GROWTH=1

RUN WITH THIS COMMAND

emrun router.html
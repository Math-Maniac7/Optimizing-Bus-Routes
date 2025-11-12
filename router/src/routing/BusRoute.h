#pragma once
#include <vector>

#include "BusStop.h"
#include "BusStopAssignment.h"
#include "Coordinate.h"

typedef size_t brid_t;

struct BusRoute {
    brid_t id;
    bsaid_t assignment;
    std::vector<bsid_t> stops;
    std::vector<std::vector<Coordinate*>> paths;
    ld travel_time;
    BusRoute(brid_t _id, bsaid_t _assignment, std::vector<bsid_t> _stops, std::vector<std::vector<Coordinate*>> _paths, ld travel_time);

    static BusRoute* parse(json& j);
    json to_json();
    BusRoute* make_copy();
};
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
    BusRoute(brid_t _id, bsaid_t _assignment, std::vector<bsid_t> _stops);

    static BusRoute* parse(json& j);
    BusRoute* make_copy();
};
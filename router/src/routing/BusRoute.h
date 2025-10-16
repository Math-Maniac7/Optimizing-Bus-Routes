#pragma once
#include <vector>

#include "BusStop.h"
#include "Coordinate.h"

typedef size_t brid_t;

struct BusRoute {
    brid_t id;
    std::vector<bsid_t> stops;
    BusRoute(brid_t _id, std::vector<bsid_t> _stops);

    static BusRoute* parse(json& j);
    BusRoute* make_copy();
};
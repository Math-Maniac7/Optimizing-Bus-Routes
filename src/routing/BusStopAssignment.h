#pragma once
#include <vector>

#include "BusStop.h"
#include "Bus.h"
#include "Coordinate.h"

struct BusStopAssignment {
    bid_t bus;
    std::vector<bsid_t> stops;
    BusStopAssignment(bid_t bus, std::vector<bsid_t> stops);

    static BusStopAssignment* parse(json& j);
    BusStopAssignment* make_copy();
};
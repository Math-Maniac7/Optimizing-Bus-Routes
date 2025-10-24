#pragma once
#include <vector>
#include <set>

#include "BusStop.h"
#include "Bus.h"
#include "Coordinate.h"

typedef size_t bsaid_t;

struct BusStopAssignment {
    bsaid_t id;
    bid_t bus;
    std::set<bsid_t> stops;
    BusStopAssignment(bsaid_t id, bid_t bus, std::set<bsid_t> stops);

    static BusStopAssignment* parse(json& j);
    BusStopAssignment* make_copy();
};
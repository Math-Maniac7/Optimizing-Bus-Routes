#include "BusStopAssignment.h"

BusStopAssignment::BusStopAssignment(bid_t _bus, std::vector<bsid_t> _stops) {
    bus = _bus;
    stops = _stops;
}

BusStopAssignment* BusStopAssignment::parse(json& j) {
    if(!j.contains("bus")) throw new std::runtime_error("BusStopAssignment missing bus");
    if(!j.contains("stops")) throw new std::runtime_error("BusStopAssignment missing stops");
    if(!j["stops"].is_array()) throw new std::runtime_error("BusStopAssignment malformed stops");
    bid_t bus = j["bus"];
    std::vector<bsid_t> stops = j["stops"];
    return new BusStopAssignment(bus, stops);
}

BusStopAssignment* BusStopAssignment::make_copy() {
    return new BusStopAssignment(bus, stops);
}
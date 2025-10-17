#include "BusStopAssignment.h"

BusStopAssignment::BusStopAssignment(bsaid_t _id, bid_t _bus, std::set<bsid_t> _stops) {
    id = _id;
    bus = _bus;
    stops = _stops;
}

BusStopAssignment* BusStopAssignment::parse(json& j) {
    if(!j.contains("id")) throw std::runtime_error("BusStopAssignment missing id");
    if(!j.contains("bus")) throw std::runtime_error("BusStopAssignment missing bus");
    if(!j.contains("stops")) throw std::runtime_error("BusStopAssignment missing stops");
    if(!j["stops"].is_array()) throw std::runtime_error("BusStopAssignment malformed stops");
    bsaid_t id = j["id"];
    bid_t bus = j["bus"];
    std::set<bsid_t> stops = j["stops"];
    return new BusStopAssignment(id, bus, stops);
}

BusStopAssignment* BusStopAssignment::make_copy() {
    return new BusStopAssignment(id, bus, stops);
}
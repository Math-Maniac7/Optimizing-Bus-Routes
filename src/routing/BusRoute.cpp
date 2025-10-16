#include "BusRoute.h"

BusRoute::BusRoute(brid_t _id, std::vector<bsid_t> _stops) {
    id = _id;
    stops = _stops;
}

BusRoute* BusRoute::parse(json& j) {
    if(!j.contains("id")) throw new std::runtime_error("BusRoute missing id");
    if(!j.contains("stops")) throw new std::runtime_error("BusRoute missing stops");
    if(!j["stops"].is_array()) throw new std::runtime_error("BusRoute stops malformed");
    brid_t id = j["id"];
    std::vector<bsid_t> stops = j["stops"];
    return new BusRoute(id, stops);
}

BusRoute* BusRoute::make_copy() {
    return new BusRoute(id, stops);
}
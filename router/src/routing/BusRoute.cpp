#include "BusRoute.h"

BusRoute::BusRoute(brid_t _id, bsaid_t _assignment, std::vector<bsid_t> _stops) {
    id = _id;
    assignment = _assignment;
    stops = _stops;
}

BusRoute* BusRoute::parse(json& j) {
    if(!j.contains("id")) throw std::runtime_error("BusRoute missing id");
    if(!j.contains("assignment")) throw std::runtime_error("BusRoute missing assignment");
    if(!j.contains("stops")) throw std::runtime_error("BusRoute missing stops");
    if(!j["stops"].is_array()) throw std::runtime_error("BusRoute stops malformed");
    brid_t id = j["id"];
    bsaid_t assignment = j["assignment"];
    std::vector<bsid_t> stops = j["stops"];
    return new BusRoute(id, assignment, stops);
}

BusRoute* BusRoute::make_copy() {
    return new BusRoute(id, assignment, stops);
}
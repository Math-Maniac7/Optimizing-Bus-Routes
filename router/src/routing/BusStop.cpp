#include "BusStop.h"

BusStop::BusStop(bsid_t _id, Coordinate* _pos, std::vector<sid_t> _students) {
    id = _id;
    pos = _pos;
    students = _students;
}

BusStop* BusStop::parse(json& j) {
    if(!j.contains("id")) throw std::runtime_error("BusStop missing id");
    if(!j.contains("pos")) throw std::runtime_error("BusStop missing pos");
    if(!j.contains("students")) throw std::runtime_error("BusStop missing students");
    if(!j["students"].is_array()) throw std::runtime_error("BusStop students malformed");
    bsid_t id = j["id"];
    Coordinate* pos = Coordinate::parse(j["pos"]);
    std::vector<sid_t> students = j["students"];
    return new BusStop(id, pos, students);
}

BusStop* BusStop::make_copy() {
    return new BusStop(id, pos->make_copy(), students);
}
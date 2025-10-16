#include "BusStop.h"

BusStop::BusStop(Coordinate* _pos, std::vector<sid_t> _students) {
    pos = _pos;
    students = _students;
}

BusStop* BusStop::parse(json& j) {
    if(!j.contains("pos")) throw new std::runtime_error("BusStop missing pos");
    if(!j.contains("students")) throw new std::runtime_error("BusStop missing students");
    if(!j["students"].is_array()) throw new std::runtime_error("BusStop students malformed");
    Coordinate* pos = Coordinate::parse(j["pos"]);
    std::vector<sid_t> students = j["students"];
    return new BusStop(pos, students);
}

BusStop* BusStop::make_copy() {
    return new BusStop(pos->make_copy(), students);
}
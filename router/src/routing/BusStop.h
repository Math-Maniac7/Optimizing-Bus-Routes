#pragma once
#include "Coordinate.h"
#include "Student.h"

typedef size_t bsid_t;

struct BusStop {
    bsid_t id;
    Coordinate* pos;
    std::vector<sid_t> students;
    BusStop(bsid_t _id, Coordinate* _pos, std::vector<sid_t> _students);

    static BusStop* parse(json& j);
    json to_json();
    BusStop* make_copy();
};
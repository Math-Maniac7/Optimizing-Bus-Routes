#pragma once
#include "Coordinate.h"
#include "Student.h"

typedef size_t bsid_t;

struct BusStop {
    Coordinate* pos;
    std::vector<sid_t> students;
    BusStop(Coordinate* _pos, std::vector<sid_t> _students);

    static BusStop* parse(json& j);
    BusStop* make_copy();
};
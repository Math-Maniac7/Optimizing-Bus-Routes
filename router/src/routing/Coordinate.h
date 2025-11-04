#pragma once
#include "../defs.h"

struct Coordinate {
    ld lat, lon;
    Coordinate(ld _lat, ld _lon);

    static Coordinate* parse(json& j);
    json to_json();
    Coordinate* make_copy();
};
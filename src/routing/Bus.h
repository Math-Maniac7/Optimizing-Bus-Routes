#pragma once
#include "Coordinate.h"

typedef size_t bid_t;

struct Bus {
    bid_t id;
    int capacity;
    Bus(bid_t _id, int _capacity);

    static Bus* parse(json& j);
    Bus* make_copy();
};
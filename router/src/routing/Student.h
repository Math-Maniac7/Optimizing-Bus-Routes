#pragma once
#include "Coordinate.h"
typedef size_t sid_t;

struct Student {
    sid_t id;
    Coordinate* pos;
    int walk_node = -1;
    int drive_node = -1;

    Student(sid_t _id, Coordinate* _pos);
    
    static Student* parse(json& j);
    json to_json();
    Student* make_copy();
};

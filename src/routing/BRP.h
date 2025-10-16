#pragma once
#include <vector>
#include <map>

#include "../defs.h"
#include "Coordinate.h"
#include "Student.h"
#include "Bus.h"
#include "BusStop.h"
#include "BusRoute.h"
#include "BusStopAssignment.h"

//bus routing problem
struct BRP {
    Coordinate* school;
    Coordinate* bus_yard;
    std::vector<Student*> students;
    std::vector<Bus*> buses;

    //Phase 1 output:
    std::optional<std::vector<BusStop*>> stops;

    //Phase 2 output:
    std::optional<std::vector<BusStopAssignment*>> assignments;

    //Phase 3 output:
    std::optional<std::vector<BusRoute*>> routes;

    BRP(
        Coordinate* school, 
        Coordinate* bus_yard, 
        std::vector<Student*> students, 
        std::vector<Bus*> buses, 
        std::optional<std::vector<BusStop*>> stops,
        std::optional<std::vector<BusStopAssignment*>> assignments,
        std::optional<std::vector<BusRoute*>> routes
    );

    static BRP* parse(json& j);
    BRP* make_copy();
    json to_json();

    //ensures all semantic constraints are met
    void validate();

    void do_p1();
    void do_p2();
    void do_p3();
};
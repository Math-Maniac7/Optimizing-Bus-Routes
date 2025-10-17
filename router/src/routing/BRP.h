#pragma once
#include <vector>
#include <map>

#include "../defs.h"
#include "../graph/Graph.h"
#include "../utils.h"
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

    //road graph
    Graph* graph = nullptr;

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

    // outputs a geojson representation of the current state of the problem
    // just for visualization
    json to_geojson();

    Student* get_student(sid_t id);
    Bus* get_bus(bid_t id);
    BusStop* get_stop(bsid_t id);
    BusStopAssignment* get_assignment(bsaid_t id);
    BusRoute* get_route(brid_t id);

    //ensures all semantic constraints are met
    void validate();

    //generates lat/lon bounding box from school, bus_yard, and all students
    //retrieves road graph within the bounding box. 
    Graph* create_graph();

    void do_p1();
    void do_p2();
    void do_p3();
};
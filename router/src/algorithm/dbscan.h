#pragma once
#include <vector>
#include <unordered_map>
#include "../defs.h"
#include "../graph/Graph.h"
#include "../routing/Student.h"
#include "../routing/BusStop.h"


namespace dbscan {


struct Params {
    double max_walk_dist;  // Max safe walking distance for students
    double merge_dist;     // Distance threshold to merge overlapping stops
    double seed_radius = -1.0;  // Local density radius to start cluster (optional, fallback to max_walk_dist)
    double assign_radius = -1.0; // Reassignment radius after initial stop placement
    int cap = -1;          // Max students per stop (optional; set to large number to disable)
    int min_pts = 1;       // Minimum cluster size (before growing/assignment)
};


// Main clustering + stop placement function
std::vector<BusStop*> place_stops(const std::vector<Student*>& students,
Graph* graph,
const Params& params,
std::unordered_map<sid_t, bsid_t>& sid2bsid_out);


} // namespace dbscan
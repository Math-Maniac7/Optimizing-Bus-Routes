#pragma once
#include <vector>
#include "../defs.h"
#include "../graph/Graph.h"
#include "../routing/Student.h"
#include "../routing/BusStop.h"
#include "../routing/Coordinate.h"

namespace dbscan {

    struct Params {
        double eps;
        int min_pts;
        int cap;
        double assign_radius;

        double max_walk;
        double near_ratio;
        int    near_k; 
        double solo_mult;     
    };

    std::vector<BusStop*> run(const std::vector<Student*>& students, Graph* graph, const Params& params);

}

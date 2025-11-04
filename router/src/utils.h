#pragma once
#include "defs.h"
#include <string>
#include <set>
#include<iomanip>
#include <string>
#include <fstream>
#include <sstream>
#include "http/http.h"
#include "graph/Graph.h"

namespace utils {
    std::string run_overpass_fetch(const std::string& query);
    std::string make_overpass_query(ld min_lat, ld min_lon, ld max_lat, ld max_lon);
    Graph* create_graph(ld min_lat, ld min_lon, ld max_lat, ld max_lon);

    // freeform address to coordinate
    Coordinate* geocode_freeform(const std::string& addr);

    // structured address to coordinate
    Coordinate* geocode_structured(
        const std::string& street,
        const std::string& city,
        const std::string& state,
        const std::string& country,
        const std::string& postal
    );
}

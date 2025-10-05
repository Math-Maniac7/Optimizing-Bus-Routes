#include <string>
#include <iostream>
#include <set>
#include <vector>
#include <map>
#include <fstream>
#include <cstdio>
#include "json.hpp"
using json = nlohmann::json;
#include "graph.h"
#include "defs.h"
#include <format>
#include <iomanip>

std::string run_overpass_fetch(const std::string& query) {
    //write query to temp file
    std::string query_file = "overpass_query.tmp.txt";
    {
        std::ofstream f(query_file, std::ios::binary);
        if (!f) throw std::runtime_error("failed to create temp query file");
        f << query;
    }

    //run overpass_fetch + read in output
    std::string cmd = "py -3 overpass_fetch.py \"" + query_file + "\"";
    std::string out;
    char buf[4096];

    FILE* pipe = _popen(cmd.c_str(), "rb");
    if (!pipe) throw std::runtime_error("_popen failed");
    while (true) {
        size_t n = fread(buf, 1, sizeof(buf), pipe);
        if (n == 0) break;
        out.append(buf, n);
    }
    int rc = _pclose(pipe);

    //delete temp file
    if(std::remove(query_file.c_str()) != 0) throw std::runtime_error("error deleting query file");

    if (rc != 0) throw std::runtime_error("python exited with code " + std::to_string(rc));
    return out;
}

std::string make_query(ld min_lat, ld min_lon, ld max_lat, ld max_lon) {
    std::ostringstream q;
    q.imbue(std::locale::classic());         
    q << std::fixed << std::setprecision(6);

    q << "[out:json][timeout:25];"
         "("
           // all linear transport features; classify later (car/bike/foot)
           "way[\"highway\"][\"area\"!=\"yes\"][\"highway\"!=\"construction\"][\"highway\"!=\"proposed\"]"
             "("
      << min_lat << "," << min_lon << "," << max_lat << "," << max_lon
      << ");"
         ");"
         "(._;>;);"
         "out body;";

    return q.str();
}

Graph* create_graph(ld min_lat, ld min_lon, ld max_lat, ld max_lon) {
    try {
        std::string query = make_query(min_lat, min_lon, max_lat, max_lon);
        std::string raw = run_overpass_fetch(query);

        std::cout << "QUERY : " << query << "\n";

        json j = json::parse(raw);

        {
            std::set<std::string> types;
            for(auto& [key, value] : j["elements"].items()) {
                if(value.is_object() && value.contains("type")) types.insert(value["type"]);
            }
            std::cout << "TYPES :\n";
            for(std::string s : types) std::cout << s << "\n";
        }

        Graph* g = Graph::parse(j);
        std::cout << "GRAPH : " << g->nodes.size() << "\n";

        return g;
    } 
    catch (const std::exception& e) {
        std::cout << "failed to create graph : " << e.what() << "\n";
        exit(1);
    }
}

int main(int argc, char* argv[]) {

    ld start_lat = 30.622393, start_lon = -96.353059;
    ld end_lat = 30.616143, end_lon = -96.339186;

    ld min_lat = std::min(start_lat, end_lat);
    ld min_lon = std::min(start_lon, end_lon);
    ld max_lat = std::max(start_lat, end_lat);
    ld max_lon = std::max(start_lon, end_lon);
    
    //add 5 mile buffer
    min_lat -= 0.07;
    min_lon -= 0.07;
    max_lat += 0.07;
    max_lon += 0.07;

    Graph* g = create_graph(min_lat, min_lon, max_lat, max_lon);
    std::cout << "DONE CREATE GRAPH\n";

    int start = g->get_node(Coordinate(start_lat, start_lon));
    int end = g->get_node(Coordinate(end_lat, end_lon));
    std::vector<int> path = g->get_path(start, end, true);
    
    std::cout << "PATH : \n";
    for(int x : path) {
        Node* node = g->nodes[x];
        std::cout << std::fixed << std::setprecision(10) << node->coord.lat << " " << node->coord.lon << "\n";
    }

    return 0;
}
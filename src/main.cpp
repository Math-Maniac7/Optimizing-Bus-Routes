#include <string>
#include <iostream>
#include <set>
#include <vector>
#include <map>
#include <fstream>
#include <cstdio>
#include <format>
#include <iomanip>
#include <unistd.h> 
#include <sys/wait.h>
#include <curl/curl.h>

#include "json.hpp"
using json = nlohmann::json;
#include "graph.h"
#include "defs.h"
#include "http/http.h"

std::string run_overpass_fetch(const std::string& query){
    std::string endpoint = "https://overpass-api.de/api/interpreter";
    std::vector<std::string> headers = {
        "Content-Type: text/plain",
        "Accept: application/json"
    };

    const auto resp = http_request(
        endpoint,
        "POST",
        query,
        headers,
        60,
        10,
        true,
        "overpass-client/1.0"
    );

    if (resp.status < 200 || resp.status >= 300) {
        throw std::runtime_error("Overpass HTTP " + std::to_string(resp.status) + ": " + resp.body);
    }
    return resp.body;
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

// returns a GeoJSON FeatureCollection with a single LineString feature.
json nodes_to_geojson(std::vector<Node*>& nodes) {
    assert(nodes.size() != 0);

    json coords = json::array();
    for (const Node* n : nodes) {
        assert(n != nullptr);

        // GeoJSON expects [lon, lat]
        double lon = (double) (n->coord.lon);
        double lat = (double) (n->coord.lat);
        coords.push_back({lon, lat});
    }

    json feature = {
        {"type", "Feature"},
        {"properties", {
            {"name", "route"}
        }},
        {"geometry", {
            {"type", "LineString"},
            {"coordinates", coords}
        }}
    };

    json fc = {
        {"type", "FeatureCollection"},
        {"features", json::array({feature})},
    };

    return fc;
}

// freeform address to coordinate
Coordinate geocode_freeform(const std::string& addr) {
    std::ostringstream url;
    url << "https://nominatim.openstreetmap.org/search"
        << "?format=jsonv2&limit=1&addressdetails=1&"
        << "q=" << url_encode(addr);

    std::vector<std::string> hdrs = {"Accept: application/json"};
    HttpResponse resp = http_request(url.str(), "GET", "", hdrs, 60, 10, true, "Router/1.0");

    std::cout << "RESP : " << resp.status << " " << resp.body << "\n";
    json j = json::parse(resp.body);
    assert(j.is_array() && !j.empty());
    const json& first = j[0];
    assert(first.contains("lat") && first.contains("lon"));

    ld lat = std::stold(first.at("lat").get<std::string>());
    ld lon = std::stold(first.at("lon").get<std::string>());

    return {lat, lon};
}

// structured address to coordinate
Coordinate geocode_structured(
    const std::string& street,
    const std::string& city,
    const std::string& state,
    const std::string& country,
    const std::string& postal
) {
    std::ostringstream url;
    url << "https://nominatim.openstreetmap.org/search"
        << "?format=jsonv2&limit=1&addressdetails=1"
        << "&street=" << url_encode(street)
        << "&city=" << url_encode(city)
        << "&state=" << url_encode(state)
        << "&country=" << url_encode(country)
        << "&postalcode=" << url_encode(postal);

    std::vector<std::string> hdrs = {"Accept: application/json"};
    HttpResponse resp = http_request(url.str(), "GET", "", hdrs, 60, 10, true, "Router/1.0");

    std::cout << "RESP : " << resp.status << " " << resp.body << "\n";
    json j = json::parse(resp.body);
    assert(j.is_array() && !j.empty());
    const json& first = j[0];
    assert(first.contains("lat") && first.contains("lon"));

    ld lat = std::stold(first.at("lat").get<std::string>());
    ld lon = std::stold(first.at("lon").get<std::string>());

    return {lat, lon};
}

int main(int argc, char* argv[]) {

    std::cout << "GEOCODE TEST" << std::endl;
    // driveable
    // bool walkable = false;
    // Coordinate a = geocode_freeform("11012 Deep Brook Drive, Austin TX");
    // Coordinate b = geocode_freeform("1801 Edelweiss Drive, Cedar Park TX");

    // walkable
    bool walkable = true;
    Coordinate a = geocode_freeform("11012 Deep Brook Drive, Austin TX");
    Coordinate b = geocode_freeform("10316 Prism Drive, Austin TX");

    std::cout << "PATHING TEST" << std::endl;
    ld start_lat = a.lat, start_lon = a.lon;
    ld end_lat = b.lat, end_lon = b.lon;

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

    int start = g->get_node(Coordinate(start_lat, start_lon), walkable);
    int end = g->get_node(Coordinate(end_lat, end_lon), walkable);
    std::vector<int> path = g->get_path(start, end, walkable);
    
    std::cout << "PATH : \n";
    for(int x : path) {
        Node* node = g->nodes[x];
        std::cout << std::fixed << std::setprecision(10) << node->coord.lat << " " << node->coord.lon << "\n";
    }

    std::vector<Node*> nodes(path.size());
    for(int i = 0; i < path.size(); i++) nodes[i] = g->nodes[path[i]];

    json geojson = nodes_to_geojson(nodes);
    std::cout << geojson << "\n";

    return 0;
}
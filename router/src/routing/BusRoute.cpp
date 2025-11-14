#include "BusRoute.h"

BusRoute::BusRoute(brid_t _id, bsaid_t _assignment, std::vector<bsid_t> _stops, std::vector<std::vector<Coordinate*>> _paths, ld _travel_time) {
    id = _id;
    assignment = _assignment;
    stops = _stops;
    paths = _paths;
    travel_time = _travel_time;
}

BusRoute* BusRoute::parse(json& j) {
    if(!j.contains("id")) throw std::runtime_error("BusRoute missing id");
    if(!j.contains("assignment")) throw std::runtime_error("BusRoute missing assignment");
    if(!j.contains("stops")) throw std::runtime_error("BusRoute missing stops");
    if(!j["stops"].is_array()) throw std::runtime_error("BusRoute stops malformed");
    if(!j.contains("paths")) throw std::runtime_error("BusRoute missing paths");
    if(!j.contains("travel_time")) throw std::runtime_error("BusRoute missing travel_time");
    brid_t id = j["id"];
    bsaid_t assignment = j["assignment"];
    std::vector<bsid_t> stops = j["stops"];
    if(!j["paths"].is_array()) throw std::runtime_error("BusRoute paths malformed (not an array)");
    std::vector<std::vector<Coordinate*>> paths;
    for(int i = 0; i < j["paths"].size(); i++) {
        if(!j["paths"][i].is_array()) throw std::runtime_error("BusRoute paths[" + std::to_string(i) + "] malformed (not an array)");
        std::vector<Coordinate*> path(j["paths"][i].size());
        for(int ii = 0; ii < path.size(); ii++) {
            path[ii] = Coordinate::parse(j["paths"][i][ii]);
        }
    }
    ld travel_time = j["travel_time"];
    return new BusRoute(id, assignment, stops, paths, travel_time);
}

json BusRoute::to_json() {
    json ret;
    ret["id"] = this->id;
    ret["assignment"] = this->assignment;
    ret["stops"] = this->stops;
    std::vector<json> paths_json;
    for(int i = 0; i < this->paths.size(); i++) {
        std::vector<json> path;
        for(int j = 0; j < this->paths[i].size(); j++) {
            path.push_back(this->paths[i][j]->to_json());
        }
        paths_json.push_back(path);
    }
    ret["paths"] = paths_json;
    ret["travel_time"] = travel_time;
    return ret;
}

BusRoute* BusRoute::make_copy() {
    std::vector<std::vector<Coordinate*>> _paths(this->paths.size());
    for(int i = 0; i < this->paths.size(); i++) {
        std::vector<Coordinate*> _path(this->paths[i].size());
        for(int j = 0; j < _path.size(); j++) {
            _path[j] = this->paths[i][j]->make_copy();
        }
        _paths[i] = _path;
    }
    return new BusRoute(id, assignment, stops, _paths, travel_time);
}
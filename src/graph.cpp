#include "graph.h"
#include <iostream>

OSMNode* OSMNode::parse(json& j) {
    ll id = j["id"];
    ld lat = j["lat"], lon = j["lon"];
    return new OSMNode(id, lat, lon);
}

OSMWay* OSMWay::parse(json& j) {
    return nullptr;
}

Graph* Graph::parse(json& j) {
    for(auto& [key, value] : j["elements"].items()) {
        assert(value.is_object());
        assert(value.contains("type"));
        std::string type = value["type"];
        if(type == "node") {
            OSMNode* node = OSMNode::parse(value);
        }
        else if(type == "way") {
            std::cout << value << "\n";
        }
        else assert(false);
    }
    return nullptr;
}
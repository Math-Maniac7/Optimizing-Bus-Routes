#pragma once
#include <vector>
#include <map>
#include "json.hpp"
using json = nlohmann::json;
typedef long long ll;
typedef long double ld;

//represents some location on the surface of earth
struct OSMNode {
    ll id;
    ld lat, lon;
    OSMNode(ll _id, ld _lat, ld _lon) {
        id = _id, lat = _lat, lon = _lon;
    }

    static OSMNode* parse(json& j);
};

//ordered list of OSMNodes, can either be open or closed. 
//each segment is assumed to be a geodesic on the earth's surface. 
struct OSMWay {
    ll id;
    std::vector<ll> node_ids;

    static OSMWay* parse(json& j);
};

struct Node {
    ld lat, lon;
};

//one way connection between two Nodes. 
struct Edge {
    ll u, v;
};

struct Graph {
    std::map<ll, OSMNode*> osm_nodes;
    std::map<ll, OSMWay*> osm_ways;

    std::vector<Node*> nodes;
    std::vector<Edge*> adj;

    static Graph* parse(json& j);
};
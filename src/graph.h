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
    json tags;
    OSMWay(ll _id, std::vector<ll>& _node_ids, json& _tags) {
        id = _id;
        node_ids = _node_ids;
        tags = _tags;
    }

    static OSMWay* parse(json& j);
};

struct Node {
    ld lat, lon;
    Node(ld _lat, ld _lon) {
        lat = _lat, lon = _lon;
    }
};

//one way connection between two Nodes. 
struct Edge {
    ll u, v;
    ld dist, speed_limit;
    bool is_walkable;
    Edge(ll _u, ll _v, ld _dist, ld _speed_limit, bool _is_walkable) {
        u = _u, v = _v, dist = _dist, speed_limit = _speed_limit, is_walkable = _is_walkable;
    }
};

struct Graph {
    std::map<ll, OSMNode*> osm_nodes;
    std::map<ll, OSMWay*> osm_ways;

    std::vector<Node*> nodes;
    std::vector<std::vector<Edge*>> adj;

    Graph() {}
    static Graph* parse(json& j);
};
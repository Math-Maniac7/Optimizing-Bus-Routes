#pragma once
#include <vector>
#include <map>
#include <iostream>
#include <queue>

#include "../defs.h"
#include "../routing/Coordinate.h"

//represents some location on the surface of earth
struct OSMNode {
    ll id;
    Coordinate* coord;
    OSMNode(ll _id, ld _lat, ld _lon) {
        id = _id;
        coord = new Coordinate(_lat, _lon);
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

    bool is_driveable();
    bool is_walkable();

    //0 if both way, 1 if forwards only, -1 if backwards only
    int drive_dir();
    int walk_dir();
};

struct Node {
    Coordinate* coord;

    //these are true if there is an outgoing edge from here with these properties
    bool is_walkable, is_driveable; 

    Node(ld _lat, ld _lon) {
        coord = new Coordinate(_lat, _lon);
        is_walkable = false;
        is_driveable = false;
    }
};

//one way connection between two Nodes. 
struct Edge {
    ll u, v;    //directed edge from u to v
    ld dist, speed_limit;
    bool is_walkable, is_driveable;
    Edge(ll _u, ll _v, ld _dist, ld _speed_limit, bool _is_driveable, bool _is_walkable) {
        u = _u, v = _v, dist = _dist, speed_limit = _speed_limit;
        is_walkable = _is_walkable, is_driveable = _is_driveable;
    }
};

struct Graph {
    std::map<ll, OSMNode*> osm_nodes;
    std::map<ll, OSMWay*> osm_ways;

    std::vector<Node*> nodes;
    std::vector<std::vector<Edge*>> adj;

    Graph() {}
    static Graph* parse(json& j);

    //returns nodes on path from start to end node
    std::vector<int> get_path(int start, int end, bool walkable, ld& out_dist);
    std::vector<int> get_path(int start, int end, bool walkable);

    //given some information, returns the node in graph that best matches it
    int get_node(Coordinate* coord, bool walkable);
    // TODO
    // int get_node(std::string addr);
};
#include "graph.h"
#include <iostream>

//TODO use haversine formula to compute geodesics
ld calc_dist(Node* a, Node *b) {
    return -1;
}

OSMNode* OSMNode::parse(json& j) {
    assert(j.contains("type") && j["type"] == "node");
    ll id = j["id"];
    ld lat = j["lat"], lon = j["lon"];
    return new OSMNode(id, lat, lon);
}

OSMWay* OSMWay::parse(json& j) {
    assert(j.contains("type") && j["type"] == "way");
    ll id = j["id"];
    std::vector<ll> node_ids;
    assert(j.contains("nodes"));
    assert(j["nodes"].is_array());
    for(ll x : j["nodes"]) node_ids.push_back(x);
    assert(j.contains("tags"));
    return new OSMWay(id, node_ids, j["tags"]);
}

Graph* Graph::parse(json& j) {
    std::map<ll, OSMNode*> osm_nodes;
    std::map<ll, OSMWay*> osm_ways;
    for(auto& [key, value] : j["elements"].items()) {
        assert(value.is_object());
        assert(value.contains("type"));
        std::string type = value["type"];
        if(type == "node") {
            OSMNode* node = OSMNode::parse(value);
            osm_nodes.insert({node->id, node});
        }
        else if(type == "way") {
            OSMWay* way = OSMWay::parse(value);
            osm_ways.insert({way->id, way});
        }
        else assert(false);
    }

    //turn OSMNodes into nodes
    int n = osm_nodes.size();
    std::vector<Node*> nodes;
    std::map<ll, ll> node_inds;
    {   
        ll ptr = 0;
        for(auto i = osm_nodes.begin(); i != osm_nodes.end(); i++) {
            ll id = i->first;
            OSMNode *node = i->second;
            assert(node_inds.count(id) == 0);
            node_inds.insert({id, ptr});
            nodes.push_back(new Node(node->lat, node->lon));
            ptr ++;
        }
    }

    //turn OSMWays into edges
    std::vector<std::vector<Edge*>> adj(n);
    for(auto iter = osm_ways.begin(); iter != osm_ways.end(); iter++) {
        OSMWay *way = iter->second;
        ll prev = way->node_ids[0];
        for(int i = 1; i < way->node_ids.size(); i++) {
            ll next = way->node_ids[i];
            ll u = node_inds[prev], v = node_inds[next];
            Edge *e1 = new Edge(u, v, calc_dist(nodes[u], nodes[v]), -1, false);
            adj[u].push_back(e1);
            Edge *e2 = new Edge(v, u, calc_dist(nodes[u], nodes[v]), -1, false);
            adj[v].push_back(e2);
            prev = next;
        }
    }

    Graph *g = new Graph();
    g->osm_nodes = osm_nodes;
    g->osm_ways = osm_ways;
    g->nodes = nodes;
    g->adj = adj;

    return g;
}
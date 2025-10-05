#include "graph.h"
#include <iostream>
#include <queue>
#include "defs.h"

#define EARTH_RADIUS 3959.0

typedef long double ld;

//use haversine formula to compute geodesics
ld calc_dist(Coordinate a, Coordinate b) {
    ld dlat = b.lat - a.lat;
    ld dlon = b.lon - a.lon;
    ld inner = 1.0 - cos(dlat) + cos(a.lat) * cos(b.lat) * (1.0 - cos(dlon));
    return 2.0 * EARTH_RADIUS * asin(sqrt(inner / 2.0));
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

bool OSMWay::is_driveable() {
    std::string hw = tags.contains("highway") ? tags["highway"] : "";
    std::string access = tags.contains("access") ? tags["access"] : "";
    std::string mv = tags.contains("motor_vehicle") ? tags["motor_vehicle"] : "";
    std::string mc = tags.contains("motorcar") ? tags["motorcar"] : "";
    std::string veh = tags.contains("vehicle") ? tags["vehicle"] : "";

    if (hw.empty()) return false;
    if (hw == "construction" || hw == "proposed") return false;

    // reject non-car ways unless explicitly allowed
    if (hw == "footway" || hw == "path" || hw == "pedestrian" || hw == "steps" ||
        hw == "bridleway" || hw == "cycleway" || hw == "corridor")
        return (mv == "yes" || mc == "yes" || veh == "yes");

    //TODO consider some more stuff
    // Tracks: allow but might weight heavily. 
    // Service roads: also weight heavily. 

    // access blocks
    if (access == "no" || access == "private") {
        // explicit override
        if (mv == "yes" || mc == "yes" || veh == "yes") return true;
        return false;
    }
    if (mv == "no" || mc == "no" || veh == "no") return false;

    return true;
}

bool OSMWay::is_walkable() {
    std::string hw = tags.contains("highway") ? tags["highway"] : "";
    std::string access = tags.contains("access") ? tags["access"] : "";
    std::string foot = tags.contains("foot") ? tags["foot"] : "";

    if (hw.empty()) return false;
    if (hw == "construction" || hw == "proposed") return false;

    // default: pedestrians allowed unless explicitly forbidden on motorways
    if (hw == "motorway" || hw == "motorway_link")
        return foot == "yes"; // only if explicitly allowed

    // is footpath explicitly blocked
    if (foot == "no" || access == "no" || access == "private") return false;

    return true;
}

int OSMWay::drive_dir() {
    std::string ow = tags.contains("oneway") ? tags["oneway"] : "";

    // explicit direction controls
    if (ow == "yes" || ow == "true" || ow == "1") return 1;
    if (ow == "-1") return -1;
    if (ow == "no" || ow == "false" || ow == "0") return 0;

    // roundabouts are one way forward
    std::string junc = tags.contains("junction") ? tags["junction"] : "";
    if (junc == "roundabout" || junc == "circular") return 1;

    // motorways are forwards
    std::string hw = tags.contains("highway") ? tags["highway"] : "";
    if (hw == "motorway") return 1;

    // ramp/connector to motorway should be one way
    if (hw.size() > 5 && hw.rfind("_link") == hw.size() - 5) return 1;

    // default
    return 0;
}

int OSMWay::walk_dir() {
    // footpath direction typically ignores vehicle direction
    std::string owf = tags.contains("oneway:foot") ? tags["oneway:foot"] : "";
    
    // explicit direction controls
    if (owf == "yes" || owf == "true" || owf == "1") return 1;
    if (owf == "-1") return -1;
    if (owf == "no" || owf == "false" || owf == "0") return 0;

    // escalators/travelators
    std::string conveying = tags.contains("conveying") ? tags["conveying"] : "";
    if (conveying == "forward")  return 1;
    if (conveying == "backward") return -1;

    // default
    return 0;
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
            nodes.push_back(new Node(node->coord));
            ptr ++;
        }
    }

    //turn OSMWays into edges
    std::vector<std::vector<Edge*>> adj(n);
    for(auto iter = osm_ways.begin(); iter != osm_ways.end(); iter++) {
        OSMWay *way = iter->second;
        if(way->node_ids.size() < 2) continue;  //check for degenerate ways

        bool is_driveable = way->is_driveable();
        bool is_walkable = way->is_walkable();
        int drive_dir = way->drive_dir();
        int walk_dir = way->walk_dir();

        bool is_driveable_forward = is_driveable && (drive_dir >= 0);
        bool is_driveable_backward = is_driveable && (drive_dir <= 0);
        bool is_walkable_forward = is_walkable && (walk_dir >= 0);
        bool is_walkable_backward = is_walkable && (walk_dir <= 0);

        ll prev = way->node_ids[0];
        for(int i = 1; i < way->node_ids.size(); i++) {
            ll next = way->node_ids[i];
            ll u = node_inds.at(prev), v = node_inds.at(next);
            Edge *e1 = new Edge(u, v, calc_dist(nodes[u]->coord, nodes[v]->coord), -1, is_driveable_forward, is_walkable_forward);
            adj[u].push_back(e1);
            Edge *e2 = new Edge(v, u, calc_dist(nodes[u]->coord, nodes[v]->coord), -1, is_driveable_backward, is_walkable_backward);
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

//takes in start and ending node, returns a vector of path indices. 

//TODO 
// - factor in speed limit
// - use A* instead of dijkstra
std::vector<int> Graph::get_path(int start, int end, bool walkable, ld& out_dist) {
    int n = nodes.size();

    //start, end must refer to valid nodes
    assert(0 <= start && start < n);
    assert(0 <= end && end < n);
    
    //run dijkstra
    std::vector<int> p(n, -1);
    std::vector<ld> d(n, 1e18);
    d[start] = 0;
    std::priority_queue<std::pair<ld, int>> q;    //{-dist, ind}
    q.push({0, start});
    while(q.size()) {
        ld cdist = -q.top().first;
        int cur = q.top().second;
        q.pop();
        if(d[cur] != cdist) {
            continue;
        }
        for(Edge* x : adj[cur]) {
            //make sure we can traverse this edge
            if(!walkable && !x->is_driveable) continue;
            if(walkable && !x->is_walkable) continue;

            //traverse the edge
            ld ndist = cdist + x->dist; 
            int next = x->v;
            if(ndist < d[next]) {
                d[next] = ndist;
                p[next] = cur;
                q.push({-ndist, next});
            }
        }
    }

    //a path must exist
    assert(p[end] != -1);
    assert(d[end] != 1e18);

    //generate path
    int ptr = end;
    std::vector<int> ans;
    while(ptr != -1) {
        ans.push_back(ptr);
        ptr = p[ptr];
    }
    std::reverse(ans.begin(), ans.end());
    assert(ans.size() >= 1);
    assert(ans[0] == start && ans[ans.size() - 1] == end);

    //out_dist
    out_dist = d[end];

    return ans;
}

std::vector<int> Graph::get_path(int start, int end, bool walkable) {
    ld out_dist;
    return get_path(start, end, walkable, out_dist);
}


int Graph::get_node(Coordinate coord) {
    ld mn = 1e18;
    int ans = -1;
    for(int i = 0; i < nodes.size(); i++) {
        ld dist = calc_dist(coord, nodes[i]->coord);
        if(dist < mn) {
            mn = dist;
            ans = i;
        }
    }
    assert(ans != -1);
    return ans;
}
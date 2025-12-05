#include "Graph.h"

ld deg_to_rad(ld d) {
    return d * (PI / 180.0L);
}

//use haversine formula to compute geodesics
ld calc_dist(Coordinate* a, Coordinate* b) {
    ld dlat = b->lat - a->lat;
    ld dlon = b->lon - a->lon;
    ld inner = 1.0 - cos(deg_to_rad(dlat)) + cos(deg_to_rad(a->lat)) * cos(deg_to_rad(b->lat)) * (1.0 - cos(deg_to_rad(dlon)));
    // return 2.0 * EARTH_RADIUS_MI * asin(sqrt(inner / 2.0));
    return 2.0 * (1000 * EARTH_RADIUS_KM) * asin(sqrt(inner / 2.0));
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

    // explicitly non-driveable
    if (mv == "no" || mc == "no" || veh == "no") return false;

    return true;
}

//strict definition of walkable
// bool OSMWay::is_walkable() {
//     std::string hw = tags.contains("highway") ? tags["highway"] : "";
//     std::string access = tags.contains("access") ? tags["access"] : "";
//     std::string foot = tags.contains("foot") ? tags["foot"] : "";
//     std::string footway = tags.contains("footway") ? tags["footway"] : "";

//     if (hw.empty() || hw == "construction" || hw == "proposed") return false;

//     // explicit bans
//     if (foot == "no" || access == "no" || access == "private") return false;

//     // motorways only if explicitly allowed
//     if (hw == "motorway" || hw == "motorway_link") return foot == "yes";

//     // pedestrian infrastructure
//     if (hw == "footway" || hw == "path" || hw == "pedestrian" || hw == "steps" || hw == "track" || hw == "corridor") return true;

//     return false;
// }

// lenient definition of walkable
// bool OSMWay::is_walkable() {
//     std::string hw = tags.contains("highway") ? tags["highway"] : "";
//     std::string access = tags.contains("access") ? tags["access"] : "";
//     std::string foot = tags.contains("foot") ? tags["foot"] : "";

//     if (hw.empty()) return false;
//     if (hw == "construction" || hw == "proposed") return false;

//     // default: pedestrians allowed unless explicitly forbidden on motorways
//     if (hw == "motorway" || hw == "motorway_link")
//         return foot == "yes"; // only if explicitly allowed

//     // is footpath explicitly blocked
//     if (foot == "no" || access == "no" || access == "private") return false;

//     return true;
// }

//extremely lenient definition of walkable
bool OSMWay::is_walkable() {
    std::string hw = tags.contains("highway") ? tags["highway"] : "";
    std::string access = tags.contains("access") ? tags["access"] : "";
    std::string foot = tags.contains("foot") ? tags["foot"] : "";

    if (hw.empty()) return false;
    if (hw == "construction" || hw == "proposed") return false;

    // is footpath explicitly blocked
    if (foot == "no") return false;

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

Node* Node::parse(json& j) {
    if(!j.contains("id")) throw std::runtime_error("Node missing id");
    if(!j.contains("coord")) throw std::runtime_error("Node missing coord");
    if(!j.contains("is_walkable")) throw std::runtime_error("Node missing is_walkable");
    if(!j.contains("is_driveable")) throw std::runtime_error("Node missing is_driveable");
    ll id = j["id"];
    Coordinate *coord = Coordinate::parse(j["coord"]);
    bool is_walkable = j["is_walkable"];
    bool is_driveable = j["is_driveable"];
    return new Node(id, coord, is_walkable, is_driveable);
}

json Node::to_json() {
    json ret;
    ret["id"] = id;
    ret["coord"] = coord->to_json();
    ret["is_walkable"] = is_walkable;
    ret["is_driveable"] = is_driveable;
    return ret;
}   

Node* Node::make_copy() {
    return new Node(id, coord->make_copy(), is_walkable, is_driveable);
}

Edge* Edge::parse(json& j) {
    if(!j.contains("u")) throw std::runtime_error("Edge missing u");
    if(!j.contains("v")) throw std::runtime_error("Edge missing v");
    if(!j.contains("dist")) throw std::runtime_error("Edge missing dist");
    if(!j.contains("speed_limit")) throw std::runtime_error("Edge missing speed_limit");
    if(!j.contains("is_walkable")) throw std::runtime_error("Edge mising is_walkable");
    if(!j.contains("is_driveable")) throw std::runtime_error("Edge missing is_driveable");
    ll u = j["u"], v = j["v"];
    ld dist = j["dist"], speed_limit = j["speed_limit"];
    bool is_walkable = j["is_walkable"];
    bool is_driveable = j["is_driveable"];
    return new Edge(u, v, dist, speed_limit, is_driveable, is_walkable);
}

json Edge::to_json() {
    json ret;
    ret["u"] = u;
    ret["v"] = v;
    ret["dist"] = dist;
    ret["speed_limit"] = speed_limit;
    ret["is_walkable"] = is_walkable;
    ret["is_driveable"] = is_driveable;
    return ret;
}

Edge* Edge::make_copy() {
    return new Edge(u, v, dist, speed_limit, is_driveable, is_walkable);
}

Graph* Graph::parse_osm(json& j) {
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
            nodes.push_back(new Node(nodes.size(), new Coordinate(node->coord->lat, node->coord->lon)));
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

            //add edges
            Edge *e1 = new Edge(u, v, calc_dist(nodes[u]->coord, nodes[v]->coord), -1, is_driveable_forward, is_walkable_forward);
            adj[u].push_back(e1);
            Edge *e2 = new Edge(v, u, calc_dist(nodes[u]->coord, nodes[v]->coord), -1, is_driveable_backward, is_walkable_backward);
            adj[v].push_back(e2);
            
            //upd node walkable/driveable status
            nodes[u]->is_driveable |= is_driveable_forward;
            nodes[v]->is_driveable |= is_driveable_backward;
            nodes[u]->is_walkable |= is_walkable_forward;
            nodes[v]->is_walkable |= is_walkable_backward;

            prev = next;
        }
    }

    Graph *g = new Graph();
    g->nodes = nodes;
    g->adj = adj;
    g->dist_walk = std::vector<std::vector<ld>>(nodes.size());
    g->dist_drive = std::vector<std::vector<ld>>(nodes.size());
    g->prev_walk = std::vector<std::vector<int>>(nodes.size());
    g->prev_drive = std::vector<std::vector<int>>(nodes.size());

    return g;
}

Graph* Graph::parse(json& j) {
    if(!j.contains("nodes")) throw std::runtime_error("Graph missing nodes");
    if(!j.contains("adj")) throw std::runtime_error("Graph missing edges");
    if(!j.contains("dist_walk")) throw std::runtime_error("Graph missing dist_walk");
    if(!j.contains("dist_drive")) throw std::runtime_error("Graph missing dist_drive");
    if(!j.contains("prev_walk")) throw std::runtime_error("Graph missing prev_walk");
    if(!j.contains("prev_drive")) throw std::runtime_error("Graph missing prev_drive");
    std::vector<Node*> nodes;
    for(int i = 0; i < j["nodes"].size(); i++) {
        nodes.push_back(Node::parse(j["nodes"][i]));
    }
    int n = nodes.size();
    std::vector<std::vector<Edge*>> adj(n);
    for(int i = 0; i < j["adj"].size(); i++) {
        for(int k = 0; k < j["adj"][i].size(); k++) {
            adj[i].push_back(Edge::parse(j["adj"][i][k]));
        }
    }
    std::vector<std::vector<ld>> dist_walk, dist_drive;
    std::vector<std::vector<int>> prev_walk, prev_drive;
    dist_walk = j["dist_walk"];
    dist_drive = j["dist_drive"];
    prev_walk = j["prev_walk"];
    prev_drive = j["prev_drive"];

    //some checks
    if(adj.size() != n) throw std::runtime_error("Graph adj must be of size n");
    if(dist_walk.size() != n) throw std::runtime_error("Graph dist_walk must be of size n");
    if(dist_drive.size() != n) throw std::runtime_error("Graph dist_drive must be of size n");
    if(prev_walk.size() != n) throw std::runtime_error("Graph prev_walk must be of size n");
    if(prev_drive.size() != n) throw std::runtime_error("Graph prev_drive must be of size n");
    
    for(int i = 0; i < n; i++) {
        if(nodes[i]->id != i) throw std::runtime_error("Graph node id must match ind");
    }
    for(int i = 0; i < n; i++) {
        for(int k = 0; k < adj[i].size(); k++) {
            if(adj[i][k]->u != i) throw std::runtime_error("Graph edge u must match ind");
        }
    }   
    for(int i = 0; i < n; i++) {
        if(dist_walk[i].size() != 0 && dist_walk[i].size() != n) throw std::runtime_error("Graph dist_walk must be either populated or not populated");
        if(dist_drive[i].size() != 0 && dist_drive[i].size() != n) throw std::runtime_error("Graph dist_drive must be either populated or not populated");
        if(prev_walk[i].size() != 0 && prev_walk[i].size() != n) throw std::runtime_error("Graph prev_walk must be either populated or not populated");
        if(prev_drive[i].size() != 0 && prev_drive[i].size() != n) throw std::runtime_error("Graph prev_drive must be either populated or not populated");
    }

    Graph* g = new Graph();
    g->nodes = nodes;
    g->adj = adj;
    g->dist_walk = dist_walk;
    g->dist_drive = dist_drive;
    g->prev_walk = prev_walk;
    g->prev_drive = prev_drive;

    return g;
}

json Graph::to_json() {
    int n = this->nodes.size();
    std::vector<json> nodes_json;
    for(int i = 0; i < n; i++) {
        nodes_json.push_back(this->nodes[i]->to_json());
    }
    std::vector<std::vector<json>> adj_json(n);
    for(int i = 0; i < n; i++) {
        for(int k = 0; k < this->adj[i].size(); k++) {
            adj_json[i].push_back(this->adj[i][k]->to_json());
        }
    }

    json ret;
    ret["nodes"] = nodes_json;
    ret["adj"] = adj_json;
    ret["dist_walk"] = dist_walk;
    ret["dist_drive"] = dist_drive;
    ret["prev_walk"] = prev_walk;
    ret["prev_drive"] = prev_drive;

    return ret;
}

Graph* Graph::make_copy() {
    int n = this->nodes.size();
    std::vector<Node*> _nodes(n);
    for(int i = 0; i < n; i++) {
        _nodes[i] = this->nodes[i]->make_copy();
    }
    std::vector<std::vector<Edge*>> _adj(n);
    for(int i = 0; i < n; i++) {
        for(int j = 0; j < this->adj[i].size(); j++) {
            _adj[i].push_back(this->adj[i][j]->make_copy());
        }
    }
    
    Graph *g = new Graph();
    g->nodes = _nodes;
    g->adj = _adj;
    g->dist_walk = dist_walk;
    g->dist_drive = dist_drive;
    g->prev_walk = prev_walk;
    g->prev_drive = prev_drive;
    
    return g;
}   

//single source shortest path
//TODO 
// - factor in speed limit
// - use A* instead of dijkstra
void Graph::sssp(int start, bool walkable, std::vector<ld>& d, std::vector<int>& p) {
    std::cout << "RUN SSSP : " << start << std::endl;
    int n = nodes.size();

    //start must refer to a valid node
    assert(0 <= start && start < n);
    
    //run dijkstra
    p = std::vector<int>(n, -1);
    d = std::vector<ld>(n, 1e18);
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
}

ld Graph::get_dist(int start, int end, bool walkable) {
    int n = nodes.size();
    
    //start and end must refer to valid nodes
    assert(0 <= start && start < n);
    assert(0 <= end && end < n);

    if(walkable) {
        //check if we need to run sssp on start 
        if(this->dist_walk[start].size() == 0) {
            this->sssp(start, walkable, this->dist_walk[start], this->prev_walk[start]);
        }
        return this->dist_walk[start][end];
    }
    else {
        //check if we need to run sssp on start 
        if(this->dist_drive[start].size() == 0) {
            this->sssp(start, walkable, this->dist_drive[start], this->prev_drive[start]);
        }
        return this->dist_drive[start][end];
    }
}

//takes in start and ending node, returns a vector of path indices. 
std::vector<int> Graph::get_path(int start, int end, bool walkable) {
    int n = nodes.size();

    //start and end must refer to valid nodes
    assert(0 <= start && start < n);
    assert(0 <= end && end < n);

    std::vector<int> path;
    if(walkable) {
        //check if we need to run sssp on start 
        if(this->dist_walk[start].size() == 0) {
            this->sssp(start, walkable, this->dist_walk[start], this->prev_walk[start]);
        }

        //check if a path exists
        if(this->prev_walk[start][end] == -1) {
            throw std::runtime_error("Graph::get_path() : path does not exist");
        }
        assert(this->dist_walk[start][end] != 1e18);

        //generate path
        int ptr = end;
        while(ptr != -1) {
            path.push_back(ptr);
            ptr = this->prev_walk[start][ptr];
        }
        std::reverse(path.begin(), path.end());
    }
    else {
        //check if we need to run sssp on start 
        if(this->dist_drive[start].size() == 0) {
            this->sssp(start, walkable, this->dist_drive[start], this->prev_drive[start]);
        }

        //check if a path exists
        if(this->prev_drive[start][end] == -1) {
            throw std::runtime_error("Graph::get_path() : path does not exist");
        }
        assert(this->dist_drive[start][end] != 1e18);

        //generate path
        int ptr = end;
        while(ptr != -1) {
            path.push_back(ptr);
            ptr = this->prev_drive[start][ptr];
        }
        std::reverse(path.begin(), path.end());
    }

    assert(path.size() >= 1);
    assert(path[0] == start && path[path.size() - 1] == end);
    return path;
}


int Graph::get_node(Coordinate* coord, bool walkable) {
    ld mn = 1e18;
    int ans = -1;
    for(int i = 0; i < nodes.size(); i++) {
        if(walkable && !nodes[i]->is_walkable) continue;
        if(!walkable && !nodes[i]->is_driveable) continue;

        ld dist = calc_dist(coord, nodes[i]->coord);
        if(dist < mn) {
            mn = dist;
            ans = i;
        }
    }
    // Fallback: if no node matched the requested modality, pick any closest node
    // so callers can decide how to handle failure instead of crashing.
    if(ans == -1) {
        for(int i = 0; i < nodes.size(); i++) {
            ld dist = calc_dist(coord, nodes[i]->coord);
            if(dist < mn) {
                mn = dist;
                ans = i;
            }
        }
    }
    return ans;
}

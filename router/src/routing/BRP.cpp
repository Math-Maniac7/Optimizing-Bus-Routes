#include "BRP.h"
#include <set>
#include <algorithm>
#include <random>
#include <ctime>
#include "../utils.h"

BRP::BRP(
    Coordinate* _school, 
    Coordinate* _bus_yard, 
    std::vector<Student*> _students, 
    std::vector<Bus*> _buses, 
    std::optional<std::vector<BusStop*>> _stops,
    std::optional<std::vector<BusStopAssignment*>> _assignments,
    std::optional<std::vector<BusRoute*>> _routes
) {
    school = _school;
    bus_yard = _bus_yard;
    students = _students;
    buses = _buses;
    stops = _stops;
    assignments = _assignments;
    routes = _routes;
}

BRP* BRP::parse(json& j) {
    if(!j.contains("school")) throw std::runtime_error("BRP missing school");
    if(!j.contains("bus_yard")) throw std::runtime_error("BRP missing bus_yard");
    if(!j.contains("students")) throw std::runtime_error("BRP missing students");
    if(!j.contains("buses")) throw std::runtime_error("BRP missing buses");
    Coordinate *school = Coordinate::parse(j["school"]);
    Coordinate *bus_yard = Coordinate::parse(j["bus_yard"]);
    std::vector<Student*> students;
    for(int i = 0; i < j["students"].size(); i++) {
        students.push_back(Student::parse(j["students"][i]));
    }
    std::vector<Bus*> buses;
    for(int i = 0; i < j["buses"].size(); i++) {
        buses.push_back(Bus::parse(j["buses"][i]));
    }

    std::optional<std::vector<BusStop*>> stops = std::nullopt;
    if(j.contains("stops")) {
        if(!j["stops"].is_array()) throw std::runtime_error("BRP malformed stops");
        stops = std::vector<BusStop*>();
        for(int i = 0; i < j["stops"].size(); i++) {
            stops.value().push_back(BusStop::parse(j["stops"][i]));
        }
    }

    std::optional<std::vector<BusStopAssignment*>> assignments = std::nullopt;
    if(j.contains("assignments")) {
        if(!j["assignments"].is_array()) throw std::runtime_error("BRP malformed assignments");
        assignments = std::vector<BusStopAssignment*>();
        for(int i = 0; i < j["assignments"].size(); i++) {
            assignments.value().push_back(BusStopAssignment::parse(j["assignments"][i]));
        }
    }

    std::optional<std::vector<BusRoute*>> routes;
    if(j.contains("routes")) {
        if(!j["routes"].is_array()) throw std::runtime_error("BRP malformed routes");
        routes = std::vector<BusRoute*>();
        for(int i = 0; i < j["routes"].size(); i++) {
            routes.value().push_back(BusRoute::parse(j["routes"][i]));
        }
    }
    
    return new BRP( 
        school,
        bus_yard,
        students,
        buses,
        stops,
        assignments,
        routes
    );
}

json BRP::to_json() {
    json ret;
    ret["school"] = this->school->to_json();
    ret["bus_yard"] = this->bus_yard->to_json();
    std::vector<json> students_json;
    for(int i = 0; i < this->students.size(); i++) {
        students_json.push_back(this->students[i]->to_json());
    }
    ret["students"] = students_json;
    std::vector<json> buses_json;
    for(int i = 0; i < this->buses.size(); i++) {
        buses_json.push_back(this->buses[i]->to_json());
    }
    ret["buses"] = buses_json;

    if(this->stops.has_value()) {
        std::vector<json> stops_json;
        for(int i = 0; i < this->stops.value().size(); i++) {
            stops_json.push_back(this->stops.value()[i]->to_json());
        }
        ret["stops"] = stops_json;
    }

    if(this->assignments.has_value()) {
        std::vector<json> assignments_json;
        for(int i = 0; i < this->assignments.value().size(); i++) {
            assignments_json.push_back(this->assignments.value()[i]->to_json());
        }
        ret["assignments"] = assignments_json;
    }

    if(this->routes.has_value()) {
        std::vector<json> routes_json;
        for(int i = 0; i < this->routes.value().size(); i++) {
            routes_json.push_back(this->routes.value()[i]->to_json());
        }
        ret["routes"] = routes_json;
    }

    return ret;
}

BRP* BRP::make_copy() {
    Coordinate *_school = school->make_copy();
    Coordinate *_bus_yard = bus_yard->make_copy();
    std::vector<Student*> _students;
    for(int i = 0; i < students.size(); i++) _students.push_back(students[i]->make_copy());
    std::vector<Bus*> _buses;
    for(int i = 0; i < buses.size(); i++) _buses.push_back(buses[i]->make_copy());
    std::optional<std::vector<BusStop*>> _stops = std::nullopt;
    if(stops.has_value()) {
        _stops = std::vector<BusStop*>();
        for(int i = 0; i < stops.value().size(); i++) _stops.value().push_back(stops.value()[i]->make_copy());
    }
    std::optional<std::vector<BusStopAssignment*>> _assignments = std::nullopt;
    if(assignments.has_value()) {
        _assignments = std::vector<BusStopAssignment*>();
        for(int i = 0; i < assignments.value().size(); i++) _assignments.value().push_back(assignments.value()[i]->make_copy());
    }
    std::optional<std::vector<BusRoute*>> _routes = std::nullopt;
    if(routes.has_value()) {
        _routes = std::vector<BusRoute*>();
        for(int i = 0; i < routes.value().size(); i++) _routes.value().push_back(routes.value()[i]->make_copy());
    }

    return new BRP( 
        _school,
        _bus_yard,
        _students,
        _buses,
        _stops,
        _assignments,
        _routes
    );
}

json BRP::to_geojson() {
    json features = json::array();
    Graph* graph = this->create_graph();

    //school
    {
        json feature = {
            {"type", "Feature"},
            {"properties", {
                {"name", "school"}
            }},
            {"geometry", {
                {"type", "Point"},
                {"coordinates", {this->school->lon, this->school->lat}}
            }}
        };
        features.push_back(feature);
    }
    
    //bus stops
    if(this->stops.has_value()) {
        for(int i = 0; i < this->stops.value().size(); i++) {
            BusStop *stop = this->stops.value()[i];
            Coordinate *pos = stop->pos;

            json feature = {
                {"type", "Feature"},
                {"properties", {
                    {"name", "stop " + std::to_string(stop->id)},
                    {"marker-size", "small"}
                }},
                {"geometry", {
                    {"type", "Point"},
                    {"coordinates", {pos->lon, pos->lat}}
                }}
            };
            features.push_back(feature);
        }
    }
    
    //bus routes
    if(this->routes.has_value()) {
        for(int i = 0; i < this->routes.value().size(); i++) {
            BusRoute *route = this->routes.value()[i];
            json coords = json::array();

            for(int j = 0; j < route->paths.size(); j++) {
                for(int k = 0; k < route->paths[j].size(); k++) {
                    coords.push_back({route->paths[j][k]->lon, route->paths[j][k]->lat});
                }
            }

            json feature = {
                {"type", "Feature"},
                {"properties", {
                    {"name", "route " + std::to_string(route->id)}
                }},
                {"geometry", {
                    {"type", "LineString"},
                    {"coordinates", coords}
                }}
            };
            features.push_back(feature);
        }
    }

    json fc = {
        {"type", "FeatureCollection"},
        {"features", features},
    };

    return fc;
}

Student* BRP::get_student(sid_t id) {
    for(int i = 0; i < students.size(); i++) {
        if(students[i]->id == id) return students[i];
    }
    assert(false);
}

Bus* BRP::get_bus(bid_t id) {
    for(int i = 0; i < buses.size(); i++) {
        if(buses[i]->id == id) return buses[i];
    }
    assert(false);
}

BusStop* BRP::get_stop(bsid_t id) {
    assert(stops.has_value());
    for(int i = 0; i < stops.value().size(); i++) {
        if(stops.value()[i]->id == id) return stops.value()[i];
    }
    assert(false);
}

BusStopAssignment* BRP::get_assignment(bsaid_t id) {
    assert(assignments.has_value());
    for(int i = 0; i < assignments.value().size(); i++) {
        if(assignments.value()[i]->id == id) return assignments.value()[i];
    }
    assert(false);
}

BusRoute* BRP::get_route(brid_t id) {
    assert(routes.has_value());
    for(int i = 0; i < routes.value().size(); i++) {
        if(routes.value()[i]->id == id) return routes.value()[i];
    }
    assert(false);
}

void BRP::validate() {
    // - there must be at least one student
    if(students.size() == 0) {
        throw std::runtime_error("BRP::validate() : there must be at least one student");
    }

    // - there must be at least one bus
    if(buses.size() == 0) {
        throw std::runtime_error("BRP::validate() : there must be at least one bus");
    }

    // - all student ids need to be unique
    std::set<sid_t> student_ids;
    for(int i = 0; i < students.size(); i++){
        if(student_ids.count(students[i]->id)) {
            throw std::runtime_error("BRP::validate() : duplicate student id " + std::to_string(students[i]->id));
        }
        student_ids.insert(students[i]->id);
    }

    // - all bus ids need to be unique
    std::set<bid_t> bus_ids;
    for(int i = 0; i < buses.size(); i++) {
        if(bus_ids.count(buses[i]->id)) {
            throw std::runtime_error("BRP::validate() : duplicate bus id " + std::to_string(buses[i]->id));
        }
        bus_ids.insert(buses[i]->id);
    }

    if(stops.has_value()) {
        std::map<sid_t, int> f;
        for(int i = 0; i < students.size(); i++) {
            f[students[i]->id] = 0;
        }

        // - all bus stop ids need to be unique
        std::set<bsid_t> bus_stop_ids;
        for(int i = 0; i < stops.value().size(); i++) {
            if(bus_stop_ids.count(stops.value()[i]->id)) {
                throw std::runtime_error("BRP::validate() : duplicate bus stop id " + std::to_string(stops.value()[i]->id));
            }
            bus_stop_ids.insert(stops.value()[i]->id);
        }

        // - every stop needs to refer to existing students
        for(int i = 0; i < stops.value().size(); i++) {
            BusStop *stop = stops.value()[i];
            for(sid_t x : stop->students) {
                if(!f.count(x)) {
                    throw std::runtime_error("BRP::validate() : bus stop " + std::to_string(stop->id) + " refers to non-existing student " + std::to_string(x));
                }
                f[x] ++;
            }
        }

        // - every student needs to be assigned to exactly one stop
        for(auto i = f.begin(); i != f.end(); i++) {
            sid_t id = i->first;
            int freq = i->second;
            if(freq != 1) {
                throw std::runtime_error("BRP::validate() : student " + std::to_string(id) + " assigned to " + std::to_string(freq) + " stops");
            }
        }
    }

    if(assignments.has_value()) {
        if(!stops.has_value()) throw std::runtime_error("assignments need stops");

        // - all assignment ids need to be unique
        std::set<bsaid_t> assignment_ids;
        for(int i = 0; i < assignments.value().size(); i++) {
            if(assignment_ids.count(assignments.value()[i]->id)) {
                throw std::runtime_error("BRP::validate() : duplicate assignment id " + std::to_string(assignments.value()[i]->id));
            }
            assignment_ids.insert(assignments.value()[i]->id);
        }

        {
            std::map<bsid_t, int> f;
            for(int i = 0; i < stops.value().size(); i++) {
                f[stops.value()[i]->id] = 0;
            }

            // - every assignment needs to refer to existing stops
            for(int i = 0; i < assignments.value().size(); i++) {
                BusStopAssignment *assignment = assignments.value()[i];
                for(bsid_t x : assignment->stops) {
                    if(!f.count(x)) {
                        throw std::runtime_error("BRP::validate() : assignment " + std::to_string(assignment->id) + " refers to non-existing bus stop " + std::to_string(x));
                    }
                    f[x] ++;
                }
            }
            
            // - every stop needs to be assigned to exactly one assignment
            for(auto i = f.begin(); i != f.end(); i++) {
                bsid_t id = i->first;
                int freq = i->second;
                if(freq != 1) {
                    throw std::runtime_error("BRP::validate() : bus stop " + std::to_string(id) + " assigned to " + std::to_string(freq) + " assignments");
                }
            }
        }
        
        {
            std::map<bid_t, int> f;
            for(int i = 0; i < buses.size(); i++) {
                f[buses[i]->id] = 0;
            }

            // - every assignment needs to refer to an existing bus
            for(int i = 0; i < assignments.value().size(); i++) {
                BusStopAssignment *assignment = assignments.value()[i];
                bid_t bus_id = assignment->bus;
                if(!f.count(bus_id)) {
                    throw std::runtime_error("BRP::validate() : assignment " + std::to_string(assignment->id) + " refers to non-existing bus " + std::to_string(bus_id));
                }
                f[bus_id] ++;
            }

            // - every bus needs to have exactly one bus assignment
            for(auto i = f.begin(); i != f.end(); i++) {
                bid_t id = i->first;
                int freq = i->second;
                if(freq != 1) {
                    throw std::runtime_error("BRP::validate() : bus " + std::to_string(id) + " assigned to " + std::to_string(freq) + " assignments");
                }
            }
        }
    }

    if(routes.has_value()) {
        if(!stops.has_value()) throw std::runtime_error("routes need stops");
        if(!assignments.has_value()) throw std::runtime_error("routes need assignments");

        // - all route ids need to be unique
        std::set<brid_t> route_ids;
        for(int i = 0; i < routes.value().size(); i++) {
            if(route_ids.count(routes.value()[i]->id)) {
                throw std::runtime_error("BRP::validate() : duplicate route id " + std::to_string(routes.value()[i]->id));
            }
            route_ids.insert(routes.value()[i]->id);
        }

        std::map<bsaid_t, int> f;
        for(int i = 0; i < assignments.value().size(); i++) {
            f[assignments.value()[i]->id] = 0;
        }

        // - every route needs to refer to an existing assignment
        for(int i = 0; i < routes.value().size(); i++) {
            BusRoute *route = routes.value()[i];
            if(!f.count(route->assignment)) {
                throw std::runtime_error("BRP::validate() : bus route " + std::to_string(route->id) + " refers to non-existing assignment " + std::to_string(route->assignment));
            }
            f[route->assignment] ++;

            // - the stops in the route need to be unique
            std::set<bsid_t> route_stops;
            for(bsid_t x : route->stops) {
                if(route_stops.count(x)) {
                    throw std::runtime_error("BRP::validate() : bus route " + std::to_string(route->id) + " has duplicate stop " + std::to_string(x));
                }
                route_stops.insert(x);
            }

            // - the stops in the route need to be a permutation of the stops in the assignment
            BusStopAssignment *assignment = this->get_assignment(route->id);
            if(route_stops.size() != assignment->stops.size()) {
                throw std::runtime_error("BRP::validate() : bus route " + std::to_string(route->id) + " stops not same as its assignment " + std::to_string(assignment->id));
            }
            for(bsid_t x : route->stops) {
                if(!assignment->stops.count(x)) {
                    throw std::runtime_error("BRP::validate() : bus route " + std::to_string(route->id) + " stops not same as its assignment " + std::to_string(assignment->id));
                }
            }
        }

        // - every assignment needs to be referred to by a route
        for(auto i = f.begin(); i != f.end(); i++) {
            bsaid_t id = i->first;
            int freq = i->second;
            if(freq != 1) {
                throw std::runtime_error("BRP::validate() : assignment " + std::to_string(id) + " assigned to " + std::to_string(freq) + " routes");
            }
        }

        // - there must be exactly stops.size() + 1 paths in a route
        //   except if the route has 0 stops, in which case it must have exactly 0 paths
        for(int i = 0; i < routes.value().size(); i++) {
            BusRoute *route = this->routes.value()[i];
            if(route->stops.size() == 0) {
                if(route->paths.size() != 0) {
                    throw std::runtime_error("BRP::validate() : route " + std::to_string(route->id) + " does not have the correct amount of paths");
                }
            }
            else {
                if(route->paths.size() != route->stops.size() + 1) {
                    throw std::runtime_error("BRP::validate() : route " + std::to_string(route->id) + " does not have the correct amount of paths");
                }
            }
        }
    }
}

Graph* BRP::create_graph() {
    if(this->graph != nullptr) return this->graph;

    ld min_lat = std::min(school->lat, bus_yard->lat), max_lat = std::max(school->lat, bus_yard->lat);
    ld min_lon = std::min(school->lon, bus_yard->lon), max_lon = std::max(school->lon, bus_yard->lon);
    
    for(Student* s : this->students) {
        min_lat = std::min(min_lat, s->pos->lat);
        max_lat = std::max(max_lat, s->pos->lat);
        min_lon = std::min(min_lon, s->pos->lon);
        max_lon = std::max(max_lon, s->pos->lon);
    }

    //add 5 mile buffer
    min_lat -= 0.07;
    min_lon -= 0.07;
    max_lat += 0.07;
    max_lon += 0.07;

    this->graph = utils::create_graph(min_lat, min_lon, max_lat, max_lon);
    return this->graph;
}

void BRP::do_p1() {
    //for now, just assign each student to their own bus stop
    this->stops = std::vector<BusStop*>();
    for(int i = 0; i < this->students.size(); i++) {
        Student *s = this->students[i];
        this->stops.value().push_back(new BusStop(i, s->pos->make_copy(), {s->id}));
    }
}

/*
NOTES FOR PHASE 2

overview:
 - for each bus, initialize it with a cluster 'center'. 
 - do multiple rounds:
   - let the cost of assigning a stop to a bus be equal to the distance from the stop to its center
   - run MCMF to assign the stops to the buses, with the above costs. 
   - get which stops are assigned to which buses via flow graph. Recompute center for each bus

on initializing centers:
 - we'll use demand-weighted k-means clustering to initialize the centers. 
 - all centers will be initialized on stops. Let d_i be the weight of each stop.
 - for the first center, pick stop i with weight d_i
 - for the remaining centers, pick stop i with weight d_i * min{dist(i, j)}^{\beta}
 - higher \beta spreads stops out more

on determining which stops are assigned to which buses 
 - since we're using MCMF, it's likely that a stop can be partially assigned to multiple buses. 
 - just find the bus where the majority of the flow is going to, the stop will be assigned to that bus. 

on recomputing centers
 - ideally, we compute the weighted medoid of the set of stops that are assigned to the bus. 
 - if we precompute all distances between stops, can do this pretty easily. 

on allowing for overbooking buses
 - the MCMF will look something like (source) -> (stops) -> (buses) -> (sink)
 - one set of edges from (buses) -> (sink) should reflect the base capacity of each bus, with 0 cost
 - can allow for overbooking by adding another set of edges with high capacity and high cost. 
 - if overflow is unacceptable, can have ghost bus with extremely high cost. Unmet demand will be assigned there

*/

void BRP::do_p2() {
    assert(this->stops.has_value());

    //for now, just assign all stops to one bus
    this->assignments = std::vector<BusStopAssignment*>();
    assert(this->buses.size() >= 1);
    {
        std::set<bsid_t> stops;
        for(int i = 0; i < this->stops.value().size(); i++) {
            stops.insert(this->stops.value()[i]->id);
        }
        this->assignments.value().push_back(new BusStopAssignment(0, this->buses[0]->id, stops));
    }

    for(int i = 1; i < this->buses.size(); i++) {
        this->assignments.value().push_back(new BusStopAssignment(i, this->buses[i]->id, {}));
    }
}

void BRP::do_p3() {
    assert(this->stops.has_value());
    assert(this->assignments.has_value());

    // -- TSP MUTATION STRATEGIES --
    std::mt19937 rng(std::time(0)); 

    auto rand_int = [&](int lo, int hi) {
        std::uniform_int_distribution<int> d(lo, hi);
        return d(rng);
    };
    auto rand_prob = [&](){
        std::uniform_real_distribution<double> d(0.0, 1.0);
        return d(rng);
    };

    auto rand_distinct_pair = [&](int n){
        int i = rand_int(0, n-1);
        int j = rand_int(0, n-2);
        if (j >= i) j++;
        return std::pair{i,j};
    };
    auto rand_segment = [&](int n){
        int l = rand_int(0, n-1);
        int r = rand_int(0, n-1);
        if (l > r) std::swap(l, r);
        return std::pair{l,r};
    };

    // 1) Swap two positions
    auto mutate_swap = [&](std::vector<int>& route){
        auto [i,j] = rand_distinct_pair((int)route.size());
        std::swap(route[i], route[j]);
    };

    // 2) remove at i, insert before j
    auto mutate_insertion = [&](std::vector<int>& route){
        auto [i,j] = rand_distinct_pair((int)route.size());
        int v = route[i];
        if (i < j) {
            for (int k = i; k < j; ++k) route[k] = route[k+1];
            route[j] = v;
        } else {
            for (int k = i; k > j; --k) route[k] = route[k-1];
            route[j] = v;
        }
    };

    // 3) reverse a segment [l, r]
    auto mutate_inversion = [&](std::vector<int>& route){
        auto [l,r] = rand_segment((int)route.size());
        if (l < r) std::reverse(route.begin()+l, route.begin()+r+1);
    };

    // 4) randomly permute inside [l, r]
    auto mutate_scramble = [&](std::vector<int>& route){
        auto [l,r] = rand_segment((int)route.size());
        if (l < r) std::shuffle(route.begin()+l, route.begin()+r+1, rng);
    };

    // 5) cut [l, r] and reinsert at position j
    auto mutate_displacement = [&](std::vector<int>& route){
        auto [l,r] = rand_segment((int)route.size());
        if (l == r) return;
        std::vector<int> seg(route.begin()+l, route.begin()+r+1);
        // erase segment
        route.erase(route.begin()+l, route.begin()+r+1);
        // choose new insertion point in the shorter vector
        int j = rand_int(0, (int)route.size());
        route.insert(route.begin()+j, seg.begin(), seg.end());
    };

    // 6) do k neighbor swaps
    auto mutate_adjacent_burst = [&](std::vector<int>& route){
        int k = std::min<int>(3, (int)route.size()-1); // up to 3 small tweaks
        for (int t = 0; t < k; ++t) {
            int i = rand_int(0, (int)route.size()-2);
            std::swap(route[i], route[i+1]);
        }
    };

    auto apply_mutations = [&](std::vector<int>& route){
        const double p_swap        = 0.25;
        const double p_insertion   = 0.25;
        const double p_inversion   = 0.30;
        const double p_scramble    = 0.15;
        const double p_displace    = 0.20;
        const double p_adj_burst   = 0.20;

        int ops = 1 + rand_int(0, 2);
        for (int t = 0; t < ops; ++t) {
            double r = rand_prob();
            if (r < p_swap) mutate_swap(route);
            else if ((r -= p_swap) < p_insertion) mutate_insertion(route);
            else if ((r -= p_insertion) < p_inversion) mutate_inversion(route);
            else if ((r -= p_inversion) < p_scramble) mutate_scramble(route);
            else if ((r -= p_scramble) < p_displace) mutate_displacement(route);
            else mutate_adjacent_burst(route);
        }
    };

    //create road graph
    Graph* graph = this->create_graph();

    //create mapping between stop id and index
    int n = this->stops.value().size(); 
    assert(n > 0);
    std::map<bsid_t, int> indmp;
    std::vector<bsid_t> rindmp(n);
    std::vector<Coordinate*> pos(n);
    for(int i = 0; i < this->stops.value().size(); i++) {
        BusStop *stop = this->stops.value()[i];
        bsid_t id = stop->id;
        assert(!indmp.count(id));

        indmp[id] = i;
        rindmp[i] = id;
        pos[i] = stop->pos->make_copy();
    }

    //create mapping between index and graph node index
    std::vector<int> graph_ind(n);
    for(int i = 0; i < n; i++) {
        graph_ind[i] = graph->get_node(pos[i], false);
    }

    //get pairwise distances between all stops
    std::vector<std::vector<ld>> dist(n);
    std::vector<std::vector<int>> prev(n);
    for(int i = 0; i < n; i++) {
        graph->sssp(graph_ind[i], false, dist[i], prev[i]);
    }

    //get distances from school to all stops and bus yard to all stops
    int school_graph_ind = graph->get_node(this->school, false);
    int bus_yard_graph_ind = graph->get_node(this->bus_yard, false);
    std::vector<ld> school_dist, bus_yard_dist;
    std::vector<int> school_prev, bus_yard_prev;
    graph->sssp(school_graph_ind, false, school_dist, school_prev);
    graph->sssp(bus_yard_graph_ind, false, bus_yard_dist, bus_yard_prev);

    //for each assignment, solve TSP
    std::srand(std::time(0));
    this->routes = std::vector<BusRoute*>();
    for(int i = 0; i < this->assignments.value().size(); i++) {
        BusStopAssignment *assignment = this->assignments.value()[i];
        int m = assignment->stops.size();
        if(m == 0) {
            //this bus doesn't have any stops
            this->routes.value().push_back(new BusRoute(i, assignment->id, {}, {}));
            continue;
        }

        //array of indexes
        std::vector<int> cur_stops;
        for(bsid_t stop : assignment->stops) {
            cur_stops.push_back(indmp[stop]);
        }

        std::cout << "GRAPH IND : " << std::endl;
        for(int x : cur_stops) {
            std::cout << graph_ind[x] << " ";
        }
        std::cout << std::endl;

        //currently, use genetic algorithm to solve. 
        const int EPOCH_MAX = 300;
        const int POPULATION_MAX = 500;
        const int KEEP_AMT = 50;
        assert(POPULATION_MAX >= 1);
        assert(KEEP_AMT >= 1 && KEEP_AMT < POPULATION_MAX);
        assert(EPOCH_MAX >= 1);

        //initialize with some random permutations 
        std::vector<std::vector<int>> population(POPULATION_MAX);
        for(int j = 0; j < POPULATION_MAX; j++) {
            std::vector<int> next(m);
            for(int k = 0; k < m; k++) next[k] = k;
            //std::random_shuffle(next.begin(), next.end());
            std::shuffle(next.begin(), next.end(), rng);
            population[j] = next;
        }

        //run for several epochs
        std::vector<int> best(0);
        ld best_dist = 1e18;
        for(int epoch = 0; epoch < EPOCH_MAX; epoch++) {
            // std::cout << "EPOCH : " << epoch << std::endl;
            // for(std::vector<int>& x : population){ 
            //     for(int y : x) std::cout << y << " ";
            //     std::cout << std::endl;
            // }

            //order population in ascending order of total distance
            assert(population.size() == POPULATION_MAX);
            std::vector<std::pair<ld, int>> ord(POPULATION_MAX);    //{dist, ind}
            for(int j = 0; j < POPULATION_MAX; j++) {
                std::vector<int> cur = population[j];
                assert(cur.size() >= 1);
                ld cdist = 0;
                cdist += bus_yard_dist[graph_ind[cur_stops[cur[0]]]];
                for(int k = 0; k < cur.size() - 1; k++) {
                    int u = cur_stops[cur[k]];
                    int v = graph_ind[cur_stops[cur[k + 1]]];
                    cdist += dist[u][v];
                }
                cdist += dist[cur_stops[cur[cur.size() - 1]]][school_graph_ind];
                ord[j] = {cdist, j};
            }
            sort(ord.begin(), ord.end());

            //keep track of best one
            if(ord[0].first < best_dist) {
                best_dist = ord[0].first;
                best = population[ord[0].second];
            }

            //create new population, the ones that survive reproduce until we hit POPULATION_MAX
            std::vector<std::vector<int>> npopulation(POPULATION_MAX);
            for(int j = 0; j < POPULATION_MAX; j++) {
                int ind = ord[j].second;
                if(j < KEEP_AMT) {
                    //this one survived
                    npopulation[j] = population[ind];
                }
                else {
                    //this one died, choose some out of the ones that survived to reproduce
                    std::vector<int> next = npopulation[std::rand() % KEEP_AMT];

                    //apply mutation
                    apply_mutations(next);

                    npopulation[j] = next;
                }
            }
            population = npopulation;

            if((epoch + 1) % 20 == 0) {
                std::cout << "EPOCH : " << (epoch + 1) << " " << best_dist << "\n";
                std::cout << "ORD : ";
                for(std::pair<ld, int>& x : ord) {
                    std::cout << x.first << " ";
                }
                std::cout << "\n";
            }
        }

        //take the best one
        assert(best.size() == m);
        std::cout << "BEST : " << best_dist << std::endl;
        for(int x : best) std::cout << x << " ";
        std::cout << std::endl;

        std::vector<bsid_t> route_stops(m);
        for(int j = 0; j < m; j++) {
            route_stops[j] = rindmp[cur_stops[best[j]]];
        }

        std::vector<std::vector<Coordinate*>> paths(m + 1);
        
        //bus yard to first stop
        {
            std::vector<Coordinate*> path;
            int ptr = graph_ind[indmp[route_stops[0]]];
            while(ptr != bus_yard_graph_ind) {
                assert(bus_yard_prev[ptr] != -1);
                path.push_back(graph->nodes[ptr]->coord->make_copy());
                ptr = bus_yard_prev[ptr];
            }
            path.push_back(graph->nodes[bus_yard_graph_ind]->coord->make_copy());
            reverse(path.begin(), path.end());
            paths[0] = path;
        }   

        //between stops
        for(int i = 0; i < m - 1; i++) {
            std::vector<Coordinate*> path;
            int stop_ind = indmp[route_stops[i]];
            int stop_graph_ind = graph_ind[stop_ind];
            int ptr = graph_ind[indmp[route_stops[i + 1]]];
            while(ptr != stop_graph_ind) {
                assert(prev[stop_ind][ptr] != -1);
                path.push_back(graph->nodes[ptr]->coord->make_copy());
                ptr = prev[stop_ind][ptr];
            }
            path.push_back(graph->nodes[stop_graph_ind]->coord->make_copy());
            reverse(path.begin(), path.end());
            paths[i + 1] = path;
        }

        //last stop to school
        {
            std::vector<Coordinate*> path;
            int stop_ind = indmp[route_stops[m - 1]];
            int stop_graph_ind = graph_ind[stop_ind];
            int ptr = school_graph_ind;
            while(ptr != stop_graph_ind) {
                assert(prev[stop_ind][ptr] != -1);
                path.push_back(graph->nodes[ptr]->coord->make_copy());
                ptr = prev[stop_ind][ptr];
            }
            path.push_back(graph->nodes[stop_graph_ind]->coord->make_copy());
            reverse(path.begin(), path.end());
            paths[m] = path;
        }

        this->routes.value().push_back(new BusRoute(i, assignment->id, route_stops, paths));
    }
    
    assert(this->assignments.value().size() == this->routes.value().size());
}
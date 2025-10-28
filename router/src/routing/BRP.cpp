#include "BRP.h"
#include <set>
#include <random>
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

json BRP::to_json() {
    throw std::runtime_error("BRP::to_json not implemented");
}

json BRP::to_geojson() {
    std::cout << "begin to geoson" << std::endl;
    json features = json::array();
    std::cout << "array made" << std::endl;
    Graph* graph = this->create_graph();
    std::cout << "school" << std::endl;
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
    std::cout << "bus stops" << std::endl;
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
    std::cout << "bus routes" << std::endl;
    //bus routes
    if(this->routes.has_value()) {
        for(int i = 0; i < this->routes.value().size(); i++) {
            BusRoute *route = this->routes.value()[i];
            json coords = json::array();

            std::vector<int> graph_inds(0);
            graph_inds.push_back(graph->get_node(this->school, false));
            for(int j = 0; j < route->stops.size(); j++) {
                bsid_t stop_id = route->stops[j];
                BusStop *stop = this->get_stop(stop_id);
                graph_inds.push_back(graph->get_node(stop->pos, false));
            }
            graph_inds.push_back(graph->get_node(this->bus_yard, false));

            for(int j = 0; j < graph_inds.size() - 1; j++) {
                std::vector<int> path = graph->get_path(graph_inds[j], graph_inds[j + 1], false);
                for(int x : path) {
                    Coordinate *pos = graph->nodes[x]->coord;
                    coords.push_back({pos->lon, pos->lat});
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
    std::cout << "fc" << std::endl;
    json fc = {
        {"type", "FeatureCollection"},
        {"features", features},
    };
    std::cout << "return" << std::endl;
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
    }
}

Graph* BRP::create_graph() {
    std::cout << "begin create graph" << std::endl;
    if(this->graph != nullptr) return this->graph;

    std::cout << "not null" << std::endl;

    ld min_lat = std::min(school->lat, bus_yard->lat), max_lat = std::max(school->lat, bus_yard->lat);
    ld min_lon = std::min(school->lon, bus_yard->lon), max_lon = std::max(school->lon, bus_yard->lon);

    std::cout << "min/max" << std::endl;
    
    for(Student* s : this->students) {
        min_lat = std::min(min_lat, s->pos->lat);
        max_lat = std::max(max_lat, s->pos->lat);
        min_lon = std::min(min_lon, s->pos->lon);
        max_lon = std::max(max_lon, s->pos->lon);
    }

    std::cout << "students" << std::endl;

    //add 5 mile buffer
    min_lat -= 0.07;
    min_lon -= 0.07;
    max_lat += 0.07;
    max_lon += 0.07;

    std::cout << "buffer" << std::endl;

    this->graph = utils::create_graph(min_lat, min_lon, max_lat, max_lon);
    std::cout << "created" << std::endl;

    return this->graph;
}

void BRP::do_p1() {
    throw std::runtime_error("p1 not implemented");
}

void BRP::do_p2() {
    throw std::runtime_error("p2 not implemented");
}

void BRP::do_p3() {
    assert(this->stops.has_value());
    assert(this->assignments.has_value());

    //create road graph
    Graph* graph = this->create_graph();

    //create mapping between stop id and index
    int n = this->stops.value().size(); //+2 for school and bus yard
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
            this->routes.value().push_back(new BusRoute(i, assignment->id, {}));
            continue;
        }

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
        const int EPOCH_MAX = 100;
        const int POPULATION_MAX = 1000;
        const int KEEP_AMT = 100;
        assert(POPULATION_MAX >= 1);
        assert(KEEP_AMT >= 1 && KEEP_AMT < POPULATION_MAX);
        assert(EPOCH_MAX >= 1);

        //initialize with some random permutations 
        std::vector<std::vector<int>> population(POPULATION_MAX);
        for(int j = 0; j < POPULATION_MAX; j++) {
            std::vector<int> next(m);
            for(int k = 0; k < m; k++) next[k] = k;
            std::mt19937 rng(std::time(nullptr));
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
                cdist += school_dist[graph_ind[cur_stops[cur[0]]]];
                for(int k = 0; k < cur.size() - 1; k++) {
                    int u = cur_stops[cur[k]];
                    int v = graph_ind[cur_stops[cur[k + 1]]];
                    // std::cout << "U V : " << u << " " << v << " " << dist.size() << " " << dist[u].size() << std::endl;
                    cdist += dist[u][v];
                }
                cdist += bus_yard_dist[graph_ind[cur_stops[cur[cur.size() - 1]]]];
                ord[j] = {cdist, j};
            }
            sort(ord.begin(), ord.end());

            // std::cout << "ORD : " << std::endl;
            // for(std::pair<ld, int>& x : ord) {
            //     std::cout << x.second << " " << x.first << std::endl;
            // }

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

                    //randomly swap a few nodes
                    int u = std::rand() % m;
                    int v = std::rand() % m;
                    std::swap(next[u], next[v]);

                    npopulation[j] = next;
                }
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

        this->routes.value().push_back(new BusRoute(i, assignment->id, route_stops));
    }
    
    assert(this->assignments.value().size() == this->routes.value().size());
}
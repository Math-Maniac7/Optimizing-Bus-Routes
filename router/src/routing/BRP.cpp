#include "BRP.h"
#include <set>
#include <algorithm>
#include <random>
#include <unordered_map>
#include <ctime>
#include <cmath>
#include <limits>
#include <queue>
#include "../utils.h"
#include "../algorithm/mcmf.h"
#include "../algorithm/dbscan.h"
#include "../algorithm/dsu.h"

namespace {

void destroy_bus_stop_vector(std::vector<BusStop*>& stops) {
    for(BusStop* stop : stops) {
        if(!stop) continue;
        delete stop->pos;
        delete stop;
    }
    stops.clear();
}

std::unordered_map<sid_t, size_t> build_sid_index(const std::vector<Student*>& students) {
    std::unordered_map<sid_t, size_t> index;
    for(size_t i = 0; i < students.size(); ++i) {
        index[students[i]->id] = i;
    }
    return index;
}

int ensure_drive_node(Graph* graph, Coordinate* coord) {
    if(!graph || !coord) return -1;
    int node = graph->get_node(coord, false);
    if(node >= 0) return node;
    node = graph->get_node(coord, true);
    return node;
}

int ensure_student_node(Graph* graph, Student* student, bool walkable) {
    if(!graph || !student) return -1;
    int& cache = walkable ? student->walk_node : student->drive_node;
    if(cache >= 0) return cache;
    cache = graph->get_node(student->pos, walkable);
    return cache;
}

int ensure_stop_node(Graph* graph, BusStop* stop, bool walkable) {
    if(!graph || !stop) return -1;
    int& cache = walkable ? stop->walk_node : stop->drive_node;
    if(cache >= 0) return cache;
    cache = graph->get_node(stop->pos, walkable);
    return cache;
}

struct DriveRouteData {
    std::vector<std::vector<ld>> stop_to_stop;
    std::vector<ld> school_to_stop;
    std::vector<ld> stop_to_school;
};

bool build_drive_route_data(
    Graph* graph,
    const std::vector<BusStop*>& stops,
    Coordinate* school,
    DriveRouteData& out
) {
    out.stop_to_stop.clear();
    out.school_to_stop.clear();
    out.stop_to_school.clear();
    if(!graph || !school || stops.empty()) return false;

    const double INF = std::numeric_limits<double>::infinity();
    const size_t n = stops.size();
    out.stop_to_stop.assign(n, std::vector<ld>(n, INF));
    out.school_to_stop.assign(n, INF);
    out.stop_to_school.assign(n, INF);

    std::vector<int> stop_nodes(n, -1);
    for(size_t i = 0; i < n; ++i) {
        stop_nodes[i] = ensure_stop_node(graph, stops[i], false);
    }
    int school_node = ensure_drive_node(graph, school);
    if(school_node < 0) return false;

    // Distances from school to stops
    std::vector<ld> dist;
    std::vector<int> prev;
    graph->sssp(school_node, false, dist, prev);
    for(size_t i = 0; i < n; ++i) {
        int node = stop_nodes[i];
        if(node >= 0 && node < (int)dist.size()) {
            out.school_to_stop[i] = dist[node];
        }
    }

    bool ok = false;
    for(size_t i = 0; i < n; ++i) {
        int node = stop_nodes[i];
        if(node < 0) continue;
        graph->sssp(node, false, dist, prev);
        if(school_node >= 0 && school_node < (int)dist.size()) {
            out.stop_to_school[i] = dist[school_node];
        }
        for(size_t j = 0; j < n; ++j) {
            int other = stop_nodes[j];
            if(other >= 0 && other < (int)dist.size()) {
                out.stop_to_stop[i][j] = dist[other];
                ok = true;
            }
        }
    }
    return ok;
}

double estimate_single_bus_route(const DriveRouteData& data) {
    const size_t n = data.stop_to_stop.size();
    if(n == 0) return 0.0;
    const double INF = std::numeric_limits<double>::infinity();
    std::vector<char> visited(n, 0);
    size_t visited_cnt = 0;
    int current = -1; // -1 == school
    double total = 0.0;

    while(visited_cnt < n) {
        double best = INF;
        int best_idx = -1;
        for(size_t i = 0; i < n; ++i) {
            if(visited[i]) continue;
            double d = (current == -1)
                ? data.school_to_stop[i]
                : data.stop_to_stop[current][i];
            if(d < best) {
                best = d;
                best_idx = static_cast<int>(i);
            }
        }
        if(best_idx < 0 || !std::isfinite(best)) {
            return INF;
        }
        total += best;
        visited[best_idx] = 1;
        current = best_idx;
        ++visited_cnt;
    }

    if(current >= 0) {
        double back = data.stop_to_school[current];
        if(!std::isfinite(back)) return INF;
        total += back;
    }
    return total;
}

void accumulate_stop_walk_metrics(
    Graph* graph,
    int walk_node,
    const std::vector<int>& student_nodes,
    double walk_cap,
    double& total,
    double& worst,
    double& penalty,
    size_t& served
) {
    if(!graph || walk_node < 0) {
        penalty += walk_cap;
        return;
    }
    const ld INF = static_cast<ld>(walk_cap * 4.0);
    const size_t node_count = graph->nodes.size();
    if(node_count == 0) return;
    std::unordered_map<int, int> remaining;
    remaining.reserve(student_nodes.size());
    for(int node : student_nodes) {
        if(node < 0) continue;
        remaining[node] += 1;
    }
    struct State {
        ld dist;
        int node;
    };
    auto cmp = [](const State& a, const State& b){ return a.dist > b.dist; };
    std::priority_queue<State, std::vector<State>, decltype(cmp)> pq(cmp);
    std::vector<ld> dist(node_count, INF);
    dist[walk_node] = 0;
    pq.push({0, walk_node});
    double local_max = 0.0;
    while(!pq.empty()) {
        State cur = pq.top();
        pq.pop();
        if(cur.dist > dist[cur.node]) continue;
        if(cur.dist > INF) break;
        auto it = remaining.find(cur.node);
        if(it != remaining.end()) {
            double cur_dist = static_cast<double>(cur.dist);
            for(int cnt = 0; cnt < it->second; ++cnt) {
                total += cur_dist;
                local_max = std::max(local_max, cur_dist);
                worst = std::max(worst, cur_dist);
                if(cur_dist > walk_cap) {
                    penalty += (cur_dist - walk_cap) * 3.5;
                }
                ++served;
            }
            remaining.erase(it);
            if(remaining.empty()) break;
        }
        for(Edge* edge : graph->adj[cur.node]) {
            if(!edge->is_walkable) continue;
            int next = static_cast<int>(edge->v);
            if(next < 0 || next >= static_cast<int>(node_count)) continue;
            ld ndist = cur.dist + edge->dist;
            if(ndist >= dist[next] || ndist > INF) continue;
            dist[next] = ndist;
            pq.push({ndist, next});
        }
    }
    if(!remaining.empty()) {
        double capped = static_cast<double>(INF);
        for(const auto& entry : remaining) {
            for(int cnt = 0; cnt < entry.second; ++cnt) {
                total += capped;
                local_max = std::max(local_max, capped);
                worst = std::max(worst, capped);
                if(capped > walk_cap) {
                    penalty += (capped - walk_cap) * 3.5;
                }
                ++served;
            }
        }
    }
    penalty += local_max * 0.05;
}

struct WalkStats {
    double score = std::numeric_limits<double>::infinity();
    bool valid = false;
};

WalkStats compute_walk_stats(
    Graph* graph,
    const std::vector<Student*>& students,
    std::vector<BusStop*>& stops,
    const std::unordered_map<sid_t, size_t>& sid_index,
    double walk_cap
) {
    WalkStats stats;
    if(!graph) return stats;
    double total = 0.0;
    double worst = 0.0;
    double penalty = 0.0;
    size_t served = 0;

    for(BusStop* stop : stops) {
        if(!stop) {
            penalty += walk_cap;
            continue;
        }
        int walk_node = ensure_stop_node(graph, stop, true);
        std::vector<int> student_nodes;
        student_nodes.reserve(stop->students.size());
        for(sid_t sid : stop->students) {
            auto it = sid_index.find(sid);
            if(it == sid_index.end()) continue;
            Student* stu = students[it->second];
            int stu_node = ensure_student_node(graph, stu, true);
            if(stu_node >= 0) {
                student_nodes.push_back(stu_node);
            }
        }
        accumulate_stop_walk_metrics(graph, walk_node, student_nodes, walk_cap, total, worst, penalty, served);
    }

    if(served == 0) {
        return stats;
    }
    double avg_walk = total / static_cast<double>(served);
    double stop_penalty = static_cast<double>(stops.size()) * 0.2;
    stats.score = avg_walk * 6.0 + worst * 1.0 + penalty + stop_penalty;
    stats.valid = true;
    return stats;
}

double score_phase1_solution(
    Graph* graph,
    Coordinate* school,
    const std::vector<Student*>& students,
    std::vector<BusStop*>& stops,
    const std::unordered_map<sid_t, size_t>& sid_index,
    double walk_cap,
    const WalkStats* cached_stats = nullptr
) {
    WalkStats local_stats;
    const WalkStats* stats = cached_stats;
    if(!stats) {
        local_stats = compute_walk_stats(graph, students, stops, sid_index, walk_cap);
        stats = &local_stats;
    }
    if(!stats->valid) {
        return std::numeric_limits<double>::infinity();
    }
    double walk_score = stats->score;
    if(!graph || !school) {
        return walk_score;
    }
    DriveRouteData drive_data;
    double route_score = std::numeric_limits<double>::infinity();
    if(school && build_drive_route_data(graph, stops, school, drive_data)) {
        route_score = estimate_single_bus_route(drive_data);
    }
    if(!std::isfinite(route_score)) {
        route_score = walk_cap * static_cast<double>(stops.size() + 1);
    }
    return route_score * 0.8 + walk_score;
}

}

static void merge_dense_stops(Graph* graph, std::vector<BusStop*>& stops, double merge_dist) {
    if(!graph || stops.empty() || merge_dist <= 0.0) return;
    const ld limit = merge_dist;
    bool merged = true;
    while(merged) {
        merged = false;
        for(size_t i = 0; i < stops.size() && !merged; ++i) {
            BusStop* lhs = stops[i];
            int node_i = ensure_stop_node(graph, lhs, false);
            if(node_i < 0) continue;
            for(size_t j = i + 1; j < stops.size(); ++j) {
                BusStop* rhs = stops[j];
                int node_j = ensure_stop_node(graph, rhs, false);
                if(node_j < 0) continue;
                ld d = graph->get_dist(node_i, node_j, false);
                if(!std::isfinite(d) || d > limit) continue;
                lhs->students.insert(lhs->students.end(), rhs->students.begin(), rhs->students.end());
                delete rhs->pos;
                delete rhs;
                stops.erase(stops.begin() + j);
                merged = true;
                break;
            }
        }
    }
}

BRP::BRP(
    Coordinate* _school, 
    Coordinate* _bus_yard, 
    std::vector<Student*> _students, 
    std::vector<Bus*> _buses, 
    std::optional<std::vector<BusStop*>> _stops,
    std::optional<std::vector<BusStopAssignment*>> _assignments,
    std::optional<std::vector<BusRoute*>> _routes,
    std::optional<Graph*> _graph
) {
    school = _school;
    bus_yard = _bus_yard;
    students = _students;
    buses = _buses;
    stops = _stops;
    assignments = _assignments;
    routes = _routes;
    graph = _graph;
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

    std::optional<std::vector<BusRoute*>> routes = std::nullopt;
    if(j.contains("routes")) {
        if(!j["routes"].is_array()) throw std::runtime_error("BRP malformed routes");
        routes = std::vector<BusRoute*>();
        for(int i = 0; i < j["routes"].size(); i++) {
            routes.value().push_back(BusRoute::parse(j["routes"][i]));
        }
    }

    std::optional<Graph*> graph = std::nullopt;
    if(j.contains("graph")) {
        graph = Graph::parse(j["graph"]);
    }
    
    return new BRP( 
        school,
        bus_yard,
        students,
        buses,
        stops,
        assignments,
        routes,
        graph
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

    //if(this->graph.has_value()) {
    //    ret["graph"] = graph.value()->to_json();
    //}

    ret["evals"] = this->evals;

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
    std::optional<Graph*> _graph = std::nullopt;
    if(graph.has_value()) {
        _graph = graph.value()->make_copy();
    }

    return new BRP( 
        _school,
        _bus_yard,
        _students,
        _buses,
        _stops,
        _assignments,
        _routes,
        _graph
    );
}

std::string rand_hex_color(std::mt19937 &rng) {
    std::uniform_int_distribution<int> dist(64, 224); // avoid too dark or bright
    auto comp_to_hex = [](int x) {
        std::ostringstream oss;
        oss << std::hex << std::uppercase << std::setfill('0') << std::setw(2) << x;
        return oss.str();
    };
    int r = dist(rng), g = dist(rng), b = dist(rng);
    return "#" + comp_to_hex(r) + comp_to_hex(g) + comp_to_hex(b);
}

json BRP::to_geojson() {
    json features = json::array();
    Graph* graph = this->create_graph();
    std::mt19937 rng(std::random_device{}());

    //school
    {
        json feature = {
            {"type", "Feature"},
            {"properties", {
                {"name", "school"},
                {"marker-size", "large"}
            }},
            {"geometry", {
                {"type", "Point"},
                {"coordinates", {this->school->lon, this->school->lat}}
            }}
        };
        features.push_back(feature);
    }
    
    // bus stops + students (phase 1 visualization)
    static const char* PAL[] = {
        "#e41a1c","#377eb8","#4daf4a","#984ea3",
        "#ff7f00","#ffff33","#a65628","#f781bf",
        "#999999","#1b9e77","#d95f02","#7570b3",
        "#e7298a","#66a61e","#e6ab02","#a6761d",
        "#666666"
    };
    const size_t PAL_N = sizeof(PAL)/sizeof(PAL[0]);

    if (this->stops.has_value() && !this->assignments.has_value()) {
        for (size_t i = 0; i < this->stops.value().size(); ++i) {
            BusStop *stop = this->stops.value()[i];
            Coordinate *stop_pos = stop->pos;
            const char* color = PAL[i % PAL_N];

            json stop_feature = {
                {"type", "Feature"},
                {"properties", {
                    {"name", "stop " + std::to_string(stop->id)},
                    {"marker-size", "large"},
                    {"marker-color", color}
                }},
                {"geometry", {
                    {"type", "Point"},
                    {"coordinates", {stop_pos->lon, stop_pos->lat}}
                }}
            };
            features.push_back(stop_feature);

            for (sid_t sid : stop->students) {
                Student* stu = this->get_student(sid);
                Coordinate *stu_pos = stu->pos;

                json stu_feature = {
                    {"type", "Feature"},
                    {"properties", {
                        {"name", "student " + std::to_string(sid)},
                        {"marker-size", "small"},
                        {"marker-color", color}
                    }},
                    {"geometry", {
                        {"type", "Point"},
                        {"coordinates", {stu_pos->lon, stu_pos->lat}}
                    }}
                };
                features.push_back(stu_feature);

            }
        }
    }

    //bus assignments
    if(this->assignments.has_value()) {
        assert(this->stops.has_value());
        for(int i = 0; i < this->assignments.value().size(); i++) {
            BusStopAssignment *assignment = this->assignments.value()[i];
            std::string color = rand_hex_color(rng);

            for(auto j : assignment->stops) {
                BusStop *stop = this->get_stop(j);
                Coordinate * pos = stop->pos;
                json feature = {
                    {"type", "Feature"},
                    {"properties", {
                        {"name", "stop " + std::to_string(stop->id)},
                        {"marker-size", "medium"},
                        {"marker-color", color}
                    }},
                    {"geometry", {
                        {"type", "Point"},
                        {"coordinates", {pos->lon, pos->lat}}
                    }}
                };
                features.push_back(feature);
            }
            json coords = json::array();

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
    if(this->graph.has_value()) return this->graph.value();

    ld min_lat = std::min(school->lat, bus_yard->lat), max_lat = std::max(school->lat, bus_yard->lat);
    ld min_lon = std::min(school->lon, bus_yard->lon), max_lon = std::max(school->lon, bus_yard->lon);
    
    for(Student* s : this->students) {
        min_lat = std::min(min_lat, s->pos->lat);
        max_lat = std::max(max_lat, s->pos->lat);
        min_lon = std::min(min_lon, s->pos->lon);
        max_lon = std::max(max_lon, s->pos->lon);
    }

    // //add 5 mile buffer
    // min_lat -= 0.07;
    // min_lon -= 0.07;
    // max_lat += 0.07;
    // max_lon += 0.07;

    //add 2 mile buffer
    ld buf = 2.0 / 70.0;
    min_lat -= buf;
    min_lon -= buf;
    max_lat += buf;
    max_lon += buf;

    this->graph = utils::create_graph(min_lat, min_lon, max_lat, max_lon);
    return this->graph.value();
}
/*
void BRP::do_p1() {
    //for now, just assign each student to their own bus stop
    this->stops = std::vector<BusStop*>();
    for(int i = 0; i < this->students.size(); i++) {
        Student *s = this->students[i];
        this->stops.value().push_back(new BusStop(i, s->pos->make_copy(), {s->id}));
    }
}
*/
void BRP::do_p1() {
    Graph* graph = this->create_graph();
    const size_t student_cnt = this->students.size();
    if(student_cnt == 0) {
        this->stops = std::vector<BusStop*>();
        return;
    }

    dbscan::Params base_params;
    const double mile = 1609.34;
    const double base_walk = 225.0;
    const double base_seed = 95.0;
    const int base_cap = 12;

    const size_t raw_bus_cnt = this->buses.size();
    const double bus_cnt = raw_bus_cnt > 0 ? static_cast<double>(raw_bus_cnt) : 1.0;

    double total_capacity = 0.0;
    int min_capacity = std::numeric_limits<int>::max();
    int max_capacity = 0;
    for(Bus* bus : this->buses) {
        total_capacity += std::max(0, bus->capacity);
        min_capacity = std::min(min_capacity, bus->capacity);
        max_capacity = std::max(max_capacity, bus->capacity);
    }
    if(min_capacity == std::numeric_limits<int>::max()) {
        min_capacity = base_cap * 2;
    }
    if(max_capacity <= 0) {
        max_capacity = std::max(min_capacity, base_cap * 2);
    }
    double avg_capacity = (raw_bus_cnt > 0 && total_capacity > 0.0) ? (total_capacity / bus_cnt) : max_capacity;
    double students_per_bus = bus_cnt > 0.0 ? (static_cast<double>(student_cnt) / bus_cnt) : static_cast<double>(student_cnt);

    double demand_scale = base_cap > 0 ? std::max(1.0, students_per_bus / (base_cap * 0.85)) : 1.0;
    double fleet_scale = 1.0 + 0.5 / bus_cnt;
    double capacity_scale = avg_capacity > 0.0 ? std::clamp(avg_capacity / 55.0, 0.7, 1.4) : 1.0;
    double cap_scale = std::min(3.5, demand_scale * fleet_scale * capacity_scale);
    int scaled_cap = std::max(base_cap, static_cast<int>(std::round(base_cap * cap_scale)));
    int cap_ceiling = std::max(max_capacity, min_capacity);
    if(cap_ceiling <= 0) cap_ceiling = scaled_cap;

    double capacity_pressure = (scaled_cap > 0)
        ? std::max(0.0, (students_per_bus / static_cast<double>(scaled_cap)) - 1.0)
        : 1.0;
    capacity_pressure = std::min(1.0, capacity_pressure);
    double effective_walk = base_walk + capacity_pressure * (mile - base_walk);
    base_params.max_walk_dist = effective_walk;
    base_params.assign_radius = effective_walk;
    base_params.seed_radius = std::min(base_params.max_walk_dist, base_seed * (1.0 + 0.5 * capacity_pressure));
    base_params.merge_dist = base_params.seed_radius;
    // Phase 1 stop capacity should mirror the actual bus capacity ceiling.
    base_params.cap = cap_ceiling;
    base_params.min_pts = 2;

    base_params.target_stop_count = 0;

    auto sid_index = build_sid_index(this->students);
    std::vector<BusStop*> best_solution;
    double best_score = std::numeric_limits<double>::infinity();

    struct CandidateSol {
        std::vector<BusStop*> stops;
        WalkStats walk_stats;
        double walk_cap = 0.0;
        double final_score = std::numeric_limits<double>::infinity();
    };

    auto destroy_candidate = [&](CandidateSol& c) {
        destroy_bus_stop_vector(c.stops);
    };

    std::vector<CandidateSol> candidate_pool;
    const size_t max_pool = 2;
    double best_walk = std::numeric_limits<double>::infinity();

    auto consider_solution = [&](const dbscan::Params& params) -> bool {
        std::unordered_map<sid_t, bsid_t> sid2bsid;
        auto raw = dbscan::place_stops(this->students, graph, params, sid2bsid);
        WalkStats walk_stats = compute_walk_stats(graph, this->students, raw, sid_index, params.max_walk_dist);
        if(!walk_stats.valid) {
            destroy_bus_stop_vector(raw);
            return false;
        }
        if(std::isfinite(best_walk) && walk_stats.score >= best_walk * 1.02) {
            destroy_bus_stop_vector(raw);
            return false;
        }
        CandidateSol entry;
        entry.stops.swap(raw);
        entry.walk_stats = walk_stats;
        entry.walk_cap = params.max_walk_dist;
        candidate_pool.push_back(std::move(entry));
        std::sort(candidate_pool.begin(), candidate_pool.end(), [](const CandidateSol& a, const CandidateSol& b){
            return a.walk_stats.score < b.walk_stats.score;
        });
        while(candidate_pool.size() > max_pool) {
            destroy_candidate(candidate_pool.back());
            candidate_pool.pop_back();
        }
        best_walk = std::min(best_walk, candidate_pool.front().walk_stats.score);
        return true;
    };

    consider_solution(base_params);

    const double bus_cnt_d = std::max(1.0, static_cast<double>(raw_bus_cnt));
    const double student_factor = static_cast<double>(student_cnt) / 80.0;
    const double bus_factor = bus_cnt_d / 8.0;
    int iteration_budget = static_cast<int>(std::round(1.0 + student_factor + bus_factor));
    iteration_budget = std::clamp(iteration_budget, 1, 20);
    std::mt19937 rng(std::random_device{}());
    std::uniform_real_distribution<double> walk_jitter(0.9, 1.15);
    std::uniform_real_distribution<double> seed_jitter(0.8, 1.2);
    // stop_jitter removed – no explicit stop goal anymore

    int stale_iters = 0;
    const int stale_limit = std::max(1, iteration_budget / 5);
    for(int iter = 0; iter < iteration_budget; ++iter) {
        dbscan::Params iter_params = base_params;
        iter_params.max_walk_dist = std::clamp(base_params.max_walk_dist * walk_jitter(rng), 160.0, mile);
        iter_params.assign_radius = iter_params.max_walk_dist;
        iter_params.seed_radius = std::clamp(base_params.seed_radius * seed_jitter(rng), 60.0, iter_params.max_walk_dist);
        if(!consider_solution(iter_params)) {
            if(++stale_iters >= stale_limit) break;
        } else {
            stale_iters = 0;
        }
    }

    if(candidate_pool.empty()) {
        std::unordered_map<sid_t, bsid_t> sid2bsid;
        auto fallback = dbscan::place_stops(this->students, graph, base_params, sid2bsid);
        WalkStats ws = compute_walk_stats(graph, this->students, fallback, sid_index, base_params.max_walk_dist);
        CandidateSol entry;
        entry.stops.swap(fallback);
        entry.walk_stats = ws;
        entry.walk_cap = base_params.max_walk_dist;
        candidate_pool.push_back(std::move(entry));
    }

    size_t best_idx = 0;
    double final_best = std::numeric_limits<double>::infinity();
    for(size_t i = 0; i < candidate_pool.size(); ++i) {
        auto& cand = candidate_pool[i];
        double score = score_phase1_solution(
            graph,
            this->school,
            this->students,
            cand.stops,
            sid_index,
            cand.walk_cap,
            &cand.walk_stats
        );
        cand.final_score = score;
        if(score < final_best) {
            final_best = score;
            best_idx = i;
        }
    }

    if(this->stops.has_value()) {
        destroy_bus_stop_vector(this->stops.value());
    }
    this->stops = std::vector<BusStop*>();
    this->stops.value().swap(candidate_pool[best_idx].stops);

    for(size_t i = 0; i < candidate_pool.size(); ++i) {
        if(i == best_idx) continue;
        destroy_candidate(candidate_pool[i]);
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
    int N = this->stops.value().size();
    int M = this->buses.size();

    std::cout << "GETTING GRAPH" << std::endl;
    Graph* graph = this->create_graph();
    std::cout << "DONE GETTING GRAPH" << std::endl;

    //initialize bus cluster centers
    //a bus cluster center should always fall on a graph node
    std::vector<int> cluster_centers(M, -1);
    for(int i = 0; i < M; i++) {
        //for now, just assign bus to random stop
        int stop_ind = random() % N;
        cluster_centers[i] = ensure_stop_node(graph, this->stops.value()[stop_ind], false);
    }

    //iterate
    std::vector<ld> stop_weights(N), bus_capacities(M);
    for(int i = 0; i < N; i++) {
        stop_weights[i] = this->stops.value()[i]->students.size();
    }
    for(int i = 0; i < M; i++) {
        bus_capacities[i] = this->buses[i]->capacity;
    }
    std::vector<int> stop_graph_nodes(N);
    for(int i = 0; i < N; i++) {
        stop_graph_nodes[i] = ensure_stop_node(graph, this->stops.value()[i], false);
    }
    std::vector<int> assignment;
    const int ITERCNT = 5;
    for(int _ = 0; _ < ITERCNT; _++) {
        std::cout << "ITERATION : " << _ << std::endl;

        //compute assignment costs
        std::vector<std::vector<ld>> cost(N, std::vector<ld>(M));
        for(int i = 0; i < N; i++) {
            for(int j = 0; j < M; j++) {
                cost[i][j] = graph->get_dist(stop_graph_nodes[i], cluster_centers[j], false);
            }
        }
        std::cout << "COMPUTED COSTS : " << N << " " << M << " " << N * M << std::endl;

        //get mcmf assignment
        assignment = mcmf::calc_assignment(stop_weights, cost, bus_capacities);
        std::cout << "DONE MCMF" << std::endl;
        for(int i = 0; i < assignment.size(); i++) {
            std::cout << assignment[i] << " ";
        }
        std::cout << "\n";
        
        //recompute centers as euclidean average of stop centers
        std::vector<std::pair<ld, ld>> sum(M, {0, 0});
        std::vector<ld> amt(M, 0);
        for(int i = 0; i < N; i++) {
            Coordinate* pos = this->stops.value()[i]->pos;
            sum[assignment[i]].first += pos->lat;
            sum[assignment[i]].second += pos->lon;
            amt[assignment[i]] ++;
        }
        for(int i = 0; i < M; i++) {
            if(amt[i] == 0) {
                std::cout << "NOTHING ASSIGNED TO BUS : " << i << std::endl;
                //randomly reassign to another stop
                int stop_ind = random() % N;
                cluster_centers[i] = ensure_stop_node(graph, this->stops.value()[stop_ind], false);
            }
            else {
                sum[i].first /= amt[i];
                sum[i].second /= amt[i];
                Coordinate* npos = new Coordinate(sum[i].first, sum[i].second);
                int graph_ind = graph->get_node(npos, false);
                cluster_centers[i] = graph_ind;
            }
        }
    }

    //construct assignments
    std::vector<BusStopAssignment*> assignments(M);
    for(int i = 0; i < M; i++) {
        assignments[i] = new BusStopAssignment(i, this->buses[i]->id, {});
    }
    for(int i = 0; i < N; i++) {
        assert(assignment[i] != -1);
        assignments[assignment[i]]->stops.insert(this->stops.value()[i]->id);
    }

    this->assignments = assignments;
}

// void BRP::do_p2() {
//     assert(this->stops.has_value());

//     //for now, just assign all stops to one bus
//     this->assignments = std::vector<BusStopAssignment*>();
//     assert(this->buses.size() >= 1);
//     {
//         std::set<bsid_t> stops;
//         for(int i = 0; i < this->stops.value().size(); i++) {
//             stops.insert(this->stops.value()[i]->id);
//         }
//         this->assignments.value().push_back(new BusStopAssignment(0, this->buses[0]->id, stops));
//     }

//     for(int i = 1; i < this->buses.size(); i++) {
//         this->assignments.value().push_back(new BusStopAssignment(i, this->buses[i]->id, {}));
//     }
// }

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
        graph_ind[i] = ensure_stop_node(graph, this->stops.value()[i], false);
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
            this->routes.value().push_back(new BusRoute(i, assignment->id, {}, {}, 0));
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

        this->routes.value().push_back(new BusRoute(i, assignment->id, route_stops, paths, best_dist));
    }
    
    assert(this->assignments.value().size() == this->routes.value().size());
}

void BRP::do_eval() {
    Graph *graph = this->create_graph();
    std::map<std::string, ld> eval;
    
    if(this->stops.has_value()) {
        std::map<bsid_t, int> stop_graphindmp;
        for(int i = 0; i < this->stops.value().size(); i++) {
            BusStop *stop = this->stops.value()[i];
            stop_graphindmp[stop->id] = ensure_stop_node(graph, this->stops.value()[i], true);
        }

        std::map<sid_t, int> student_graphindmp;
        for(int i = 0; i < this->students.size(); i++) {
            Student *s = this->students[i];
            student_graphindmp[s->id] = ensure_student_node(graph, s, true);
        }

        std::map<sid_t, bsid_t> student_stopmp;
        std::map<sid_t, ld> student_distmp;
        for(int i = 0; i < this->stops.value().size(); i++) {
            BusStop *stop = this->stops.value()[i];
            for(sid_t id : stop->students) {
                assert(!student_stopmp.count(id));
                student_stopmp[id] = stop->id;
                student_distmp[id] = graph->get_dist(student_graphindmp[id], stop_graphindmp[stop->id], true);
            }
        }

        //average student walk time
        ld avg_student_walk_time = 0;
        for(int i = 0; i < this->students.size(); i++) {
            Student *s = this->students[i];
            avg_student_walk_time += student_distmp[s->id];
        }
        avg_student_walk_time /= this->students.size();
        eval["avg_student_walk_time"] = avg_student_walk_time;

        //average per-stop maximum student walk time
        ld avg_per_stop_max_walk_time = 0;
        for(int i = 0; i < this->stops.value().size(); i++) {
            ld max_walk = 0;
            BusStop *stop = this->stops.value()[i];
            for(sid_t id : stop->students) {
                max_walk = std::max(max_walk, student_distmp[id]);
            }
            avg_per_stop_max_walk_time += max_walk;
        }
        avg_per_stop_max_walk_time /= this->stops.value().size();
        eval["avg_per_stop_max_walk_time"] = avg_per_stop_max_walk_time;

        //number of stops
        eval["nr_stops"] = this->stops.value().size();
    }

    if(this->assignments.has_value()) {
        assert(this->stops.has_value());

        std::map<bsaid_t, bid_t> assignment_busmp;
        std::map<bid_t, ld> bus_loadmp;
        for(int i = 0; i < this->assignments.value().size(); i++) {
            BusStopAssignment *assignment = this->assignments.value()[i];
            assignment_busmp[assignment->id] = assignment->bus;
            for(bsid_t stop_id : assignment->stops) {
                BusStop *stop = this->get_stop(stop_id);
                bus_loadmp[assignment->bus] += stop->students.size();
            }
        }

        std::map<bsid_t, int> stop_graphindmp;
        for(int i = 0; i < this->stops.value().size(); i++) {
            BusStop *stop = this->stops.value()[i];
            stop_graphindmp[stop->id] = ensure_stop_node(graph, this->stops.value()[i], true);
        }

        //average assignment compactness
        ld avg_assignment_compactness = 0;
        for(int i = 0; i < this->assignments.value().size(); i++) {
            //compute MST for compactness score
            BusStopAssignment *assignment = this->assignments.value()[i];
            int n = assignment->stops.size();
            std::vector<bsid_t> stops;
            for(bsid_t id : assignment->stops) stops.push_back(id);

            // - compute all pairwise distances
            std::vector<std::pair<ld, std::pair<int, int>>> e;
            for(int j = 0; j < n; j++) {
                for(int k = j + 1; k < n; k++) {
                    int u = stops[j];
                    int v = stops[k];
                    ld dist = graph->get_dist(stop_graphindmp[u], stop_graphindmp[v], false);
                    e.push_back({dist, {j, k}});
                }
            }
            sort(e.begin(), e.end());

            // - do MST algorithm
            DSU dsu(n);
            ld esum = 0;
            for(int j = 0; j < e.size(); j++) {
                int u = e[i].second.first;
                int v = e[i].second.second;
                ld dist = e[i].first;
                if(dsu.unify(u, v)) {
                    esum += dist;
                }
            }

            avg_assignment_compactness += esum;
        }
        avg_assignment_compactness /= this->assignments.value().size();
        eval["avg_assignment_compactness"] = avg_assignment_compactness;

        //total bus overbooking
        ld total_bus_overbooking = 0;
        for(int i = 0; i < this->buses.size(); i++) {
            Bus *bus = this->buses[i];
            total_bus_overbooking += std::max((ld) 0, bus_loadmp[bus->id] - bus->capacity);
        }
        eval["total_bus_overbooking"] = total_bus_overbooking;

        //sum of squared deviation from mean bus load
        ld mean_bus_load = 0;
        for(int i = 0; i < this->buses.size(); i++) {
            Bus *bus = this->buses[i];
            mean_bus_load += bus_loadmp[bus->id];
        }
        mean_bus_load /= this->buses.size();
        ld bus_load_deviation = 0;
        for(int i = 0; i < this->buses.size(); i++) {
            Bus *bus = this->buses[i];
            ld deviation = mean_bus_load - bus_loadmp[bus->id];
            bus_load_deviation += deviation * deviation;
        }
        eval["bus_load_deviation"] = bus_load_deviation;
    }   

    if(this->routes.has_value()) {
        assert(this->stops.has_value());
        assert(this->assignments.has_value());

        //average per-bus travel time
        ld average_bus_travel_time = 0;
        for(int i = 0; i < this->routes.value().size(); i++) {
            BusRoute *route = this->routes.value()[i];
            average_bus_travel_time += route->travel_time;
        }
        average_bus_travel_time /= this->buses.size();
        eval["average_bus_travel_time"] = average_bus_travel_time;

        //maximum bus travel time
        ld maximum_bus_travel_time = 0;
        for(int i = 0; i < this->routes.value().size(); i++) {
            BusRoute *route = this->routes.value()[i];
            maximum_bus_travel_time = std::max(maximum_bus_travel_time, route->travel_time);
        }
        eval["maximum_bus_travel_time"] = maximum_bus_travel_time;
    }

    this->evals = eval;
}

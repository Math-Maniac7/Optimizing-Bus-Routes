#include "dbscan.h"
#include <queue>
#include <algorithm>
#include <limits>
#include <cassert>

namespace dbscan {
using std::vector;
static constexpr ld INF = std::numeric_limits<ld>::infinity();
static constexpr ld METERS_TO_GRAPH = 1.0L / 1609.34L;

// Find all student indices within eps (WALK graph) of student i
static vector<int> region_query(int i,
                                const vector<int>& stu_walk_node,
                                Graph* graph,
                                ld eps) {
    vector<ld> dist;
    vector<int> prev;
    graph->sssp(stu_walk_node[i], true, dist, prev);

    vector<int> nbrs;
    nbrs.reserve(stu_walk_node.size());
    for (int j = 0; j < (int)stu_walk_node.size(); ++j) {
        ld d = dist[stu_walk_node[j]];
        if (d < INF / 2 && d <= eps) nbrs.push_back(j);
    }
    return nbrs;
}

static int drive_degree(Graph* graph, int node) {
    if (node < 0 || node >= (int)graph->adj.size()) return 0;
    int deg = 0;
    for (auto e : graph->adj[node]) {
        if (e->is_driveable) deg++;
    }
    return deg;
}

static std::pair<int,int> choose_medoid_walk_node(const vector<int>& members,
                                                  const vector<int>& stu_walk_node,
                                                  Graph* graph) {
    int best_node = stu_walk_node[members.front()];
    int best_idx = members.front();
    ld best_sum = INF;
    vector<ld> dist;
    vector<int> prev;
    for (int idx : members) {
        int node = stu_walk_node[idx];
        graph->sssp(node, true, dist, prev);
        ld total = 0;
        bool bad = false;
        for (int other : members) {
            ld d = dist[stu_walk_node[other]];
            if (d >= INF / 2) { bad = true; break; }
            total += d;
        }
        if (!bad && total < best_sum) {
            best_sum = total;
            best_node = node;
            best_idx = idx;
        }
    }
    return {best_node, best_idx};
}

static int find_intersection_near(Graph* graph,
                                  int start,
                                  ld max_meters) {
    if (start < 0 || start >= (int)graph->nodes.size()) return -1;
    const ld limit = max_meters * METERS_TO_GRAPH;
    std::queue<std::pair<int, ld>> q;
    std::vector<bool> seen(graph->nodes.size(), false);
    q.push({start, 0.0L});
    seen[start] = true;

    while (!q.empty()) {
        auto [node, dist] = q.front();
        q.pop();
        if (node != start &&
            graph->nodes[node]->is_driveable &&
            drive_degree(graph, node) >= 3) {
            return node;
        }
        if ((size_t)node >= graph->adj.size()) continue;
        for (auto e : graph->adj[node]) {
            if (!e->is_driveable) continue;
            int nxt = (int)e->v;
            ld nd = dist + e->dist;
            if (nd > limit + 1e-9L) continue;
            if (!seen[nxt]) {
                seen[nxt] = true;
                q.push({nxt, nd});
            }
        }
    }
    return -1;
}

std::vector<BusStop*> run(const std::vector<Student*>& students,
                          Graph* graph,
                          const Params& P) {
    const int N = (int)students.size();
    if (N == 0) return {};

    // Map each student to nearest WALK node once
    vector<int> stu_walk_node(N);
    vector<int> stu_drive_node(N);
    for (int i = 0; i < N; ++i) {
        stu_walk_node[i] = graph->get_node(students[i]->pos, true);
        stu_drive_node[i] = graph->get_node(students[i]->pos, false);
    }

    // Standard DBSCAN labeling
    vector<int> label(N, -1); // -1=unvisited, -2=noise, >=0 cluster id
    int cur_cluster = 0;

    const ld eps_graph = ((P.seed_radius > 0 ? P.seed_radius : P.max_walk_dist) * METERS_TO_GRAPH);
    for (int i = 0; i < N; ++i) {
        if (label[i] != -1) continue;

        auto nbrs = region_query(i, stu_walk_node, graph, eps_graph);
        if ((int)nbrs.size() + 1 < P.min_pts) {
            label[i] = -2; // noise
            continue;
        }

        label[i] = cur_cluster;
        std::queue<int> q;
        for (int v : nbrs) q.push(v);

        while (!q.empty()) {
            int j = q.front(); q.pop();
            if (label[j] == -2) label[j] = cur_cluster;   // border → cluster
            if (label[j] != -1) continue;                 // already processed
            label[j] = cur_cluster;

            auto nbrs2 = region_query(j, stu_walk_node, graph, eps_graph);
            if ((int)nbrs2.size() + 1 >= P.min_pts) {
                for (int u : nbrs2) if (label[u] == -1) q.push(u);
            }
        }
        ++cur_cluster;
    }

    // Group indices by cluster; collect noise
    vector<vector<int>> clusters(cur_cluster);
    vector<int> noise;
    for (int i = 0; i < N; ++i) {
        if (label[i] >= 0) clusters[label[i]].push_back(i);
        else               noise.push_back(i);
    }

    // Build stops: one per cluster (center snapped to WALK graph)
    vector<BusStop*> stops;
    stops.reserve(clusters.size() + noise.size());

    for (auto& members : clusters) {
        if (members.empty()) continue;

        auto [center_walk_node, medoid_idx] =
            choose_medoid_walk_node(members, stu_walk_node, graph);
        int drive_center = stu_drive_node[medoid_idx];
        if (drive_center < 0 || drive_center >= (int)graph->nodes.size() ||
            !graph->nodes[drive_center]->is_driveable) {
            drive_center = graph->get_node(graph->nodes[center_walk_node]->coord, false);
        }
        int intersection = find_intersection_near(graph, drive_center, 20.0L);
        if (intersection != -1) drive_center = intersection;

        // Ensure each member is actually reachable from the chosen center on WALK graph
        vector<ld> dist; vector<int> prev;
        graph->sssp(center_walk_node, true, dist, prev);

        vector<sid_t> sids;
        sids.reserve(members.size());
        for (int idx : members) {
            if (dist[stu_walk_node[idx]] < INF / 2) {
                sids.push_back(students[idx]->id);
            }
        }
        if (!sids.empty()) {
            Coordinate* pos = graph->nodes[drive_center]->coord->make_copy();
            stops.push_back(new BusStop((bsid_t)stops.size(), pos, sids));
        }
    }

    // Noise → singleton stops at student positions
    for (int idx : noise) {
        Coordinate* p = students[idx]->pos->make_copy();
        std::vector<sid_t> one = { students[idx]->id };
        stops.push_back(new BusStop((bsid_t)stops.size(), p, one));
    }

    return stops;
}

std::vector<BusStop*> place_stops(const std::vector<Student*>& students,
                                  Graph* graph,
                                  const Params& params,
                                  std::unordered_map<sid_t, bsid_t>& sid2bsid_out) {
    auto stops = run(students, graph, params);
    sid2bsid_out.clear();
    for (size_t i = 0; i < stops.size(); ++i) {
        for (sid_t sid : stops[i]->students) {
            sid2bsid_out[sid] = stops[i]->id;
        }
    }
    return stops;
}
}

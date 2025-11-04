#include "dbscan.h"
#include <queue>
#include <algorithm>
#include <limits>
#include <cassert>

namespace dbscan {
using std::vector;
static constexpr ld INF = std::numeric_limits<ld>::infinity();

// Find all student indices within eps (WALK graph) of student i
static vector<int> region_query(int i,
                                const vector<int>& stu_node,
                                Graph* graph,
                                ld eps) {
    vector<ld> dist;
    vector<int> prev;
    graph->sssp(stu_node[i], true, dist, prev);

    vector<int> nbrs;
    nbrs.reserve(stu_node.size());
    for (int j = 0; j < (int)stu_node.size(); ++j) {
        ld d = dist[stu_node[j]];
        if (d < INF / 2 && d <= eps) nbrs.push_back(j);
    }
    return nbrs;
}

// Average lat/lon of members and snap to nearest WALK node
static int choose_center_on_graph(const vector<int>& members,
                                  const vector<Student*>& students,
                                  Graph* graph) {
    ld sum_lat = 0, sum_lon = 0;
    for (int idx : members) {
        sum_lat += students[idx]->pos->lat;
        sum_lon += students[idx]->pos->lon;
    }
    const ld c = (ld)members.size();
    Coordinate guess(sum_lat / c, sum_lon / c);
    return graph->get_node(&guess, true);
}

std::vector<BusStop*> run(const std::vector<Student*>& students,
                          Graph* graph,
                          const Params& P) {
    const int N = (int)students.size();
    if (N == 0) return {};

    // Map each student to nearest WALK node once
    vector<int> stu_node(N);
    for (int i = 0; i < N; ++i) {
        stu_node[i] = graph->get_node(students[i]->pos, true);
    }

    // Standard DBSCAN labeling
    vector<int> label(N, -1); // -1=unvisited, -2=noise, >=0 cluster id
    int cur_cluster = 0;

    for (int i = 0; i < N; ++i) {
        if (label[i] != -1) continue;

        auto nbrs = region_query(i, stu_node, graph, P.eps);
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

            auto nbrs2 = region_query(j, stu_node, graph, P.eps);
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

        const int center_node = choose_center_on_graph(members, students, graph);

        // Ensure each member is actually reachable from the chosen center on WALK graph
        vector<ld> dist; vector<int> prev;
        graph->sssp(center_node, true, dist, prev);

        vector<sid_t> sids;
        sids.reserve(members.size());
        for (int idx : members) {
            if (dist[stu_node[idx]] < INF / 2) {
                sids.push_back(students[idx]->id);
            }
        }
        if (!sids.empty()) {
            Coordinate* pos = graph->nodes[center_node]->coord->make_copy();
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
}
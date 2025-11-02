#include "mcmf.h"
#include "../defs.h"
#include <queue>
#include <vector>
#include <algorithm>

namespace mcmf {
    using namespace std;

    const ld INF = 1e18;
    struct MCMF {
        struct Edge {
            int v, isback;
            ld cap, flow, cost;
        };

        int n;
        vector<Edge> edges;
        vector<vector<int>> adj;
        vector<pair<int, int>> par;
        vector<int> in_q;
        vector<ld> dist, pi;

        MCMF(int n) : n(n), adj(n), dist(n), pi(n), par(n), in_q(n) {}

        void addEdge(int u, int v, ld cap, ld cost) {
            int idx = edges.size();
            edges.push_back({v, 0, cap, 0, cost});
            edges.push_back({u, 1, cap, cap, -cost});
            adj[u].push_back(idx);
            adj[v].push_back(idx ^ 1);
        }

        bool find_path(int s, int t) {
            fill(dist.begin(), dist.end(), INF);
            fill(in_q.begin(), in_q.end(), 0);
            queue<int> q;
            q.push(s);
            dist[s] = 0;
            in_q[s] = 1;

            while (!q.empty()) {
                int cur = q.front();
                q.pop();
                in_q[cur] = 0;

                for (int idx : adj[cur]) {
                    Edge& e = edges[idx];
                    int nxt = e.v;
                    ld cap = e.cap, fl = e.flow, wt = e.cost;
                    ld nxtD = dist[cur] + wt;

                    if (fl >= cap || nxtD >= dist[nxt]) continue;

                    dist[nxt] = nxtD;
                    par[nxt] = {cur, idx};

                    if (!in_q[nxt]) {
                        q.push(nxt);
                        in_q[nxt] = 1;
                    }
                }
            }
            return dist[t] < INF;
        }

        pair<ld, ld> calc(int s, int t) {
            ld flow = 0, cost = 0;

            while (find_path(s, t)) {
                for (int i = 0; i < n; i++) {
                    pi[i] = min(pi[i] + dist[i], INF);
                }

                ld f = INF;
                for (int v = t, u, i; v != s; v = u) {
                    tie(u, i) = par[v];
                    f = min(f, edges[i].cap - edges[i].flow);
                }

                flow += f;
                for (int v = t, u, i; v != s; v = u) {
                    tie(u, i) = par[v];
                    edges[i].flow += f;
                    edges[i ^ 1].flow -= f;
                }
            }

            for (size_t i = 0; i < edges.size() / 2; i++) {
                cost += edges[i * 2].cost * edges[i * 2].flow;
            }

            return {flow, cost};
        }
    };

    //weights is size N, costs is size NxM, capcities is size M
    vector<int> calc_assignment(vector<ld> weights, vector<vector<ld>> costs, vector<ld> capacities) {
        int N = weights.size();
        assert(costs.size() == N);
        int M = capacities.size();
        for(int i = 0; i < N; i++) {
            assert(costs[i].size() == M);
        }

        //setup graph
        int indptr = 0;
        int source = indptr ++, sink = indptr ++;
        vector<int> stops(N), buses(M);
        map<int, int> bus_idmp;
        for(int i = 0; i < N; i++) {
            stops[i] = indptr ++;
        }
        for(int i = 0; i < M; i++) {
            buses[i] = indptr ++;
            bus_idmp[buses[i]] = i;
        }

        MCMF mcmf(indptr);
        for(int i = 0; i < N; i++) {
            mcmf.addEdge(source, stops[i], weights[i], 0);
        }
        for(int i = 0; i < N; i++) {
            for(int j = 0; j < M; j++) {
                mcmf.addEdge(stops[i], buses[j], INF, costs[i][j]);
            }
        }
        for(int i = 0; i < M; i++) {
            mcmf.addEdge(buses[i], sink, capacities[i], 0);
        }

        //do mcmf
        pair<ld, ld> res = mcmf.calc(source, sink);

        //extract results
        vector<int> ans(N, -1);
        for(int i = 0; i < N; i++) {
            //find bus that the stop directs most of its flow towards
            int bus = -1;
            ld most = -INF;
            for(int j = 0; j < mcmf.adj[stops[i]].size(); j++) {
                int e = mcmf.adj[stops[i]][j];
                MCMF::Edge edge = mcmf.edges[e];
                if(edge.isback) continue;
                assert(bus_idmp.count(edge.v));
                if(edge.flow > most) {
                    most = edge.flow;
                    bus = bus_idmp[edge.v];
                }
            }
            assert(bus != -1);
            ans[i] = bus;
        }
        for(int i = 0; i < N; i++) assert(ans[i] != -1);
        return ans;
    }
}
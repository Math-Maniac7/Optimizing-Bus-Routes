#include "dbscan.h"
#include <algorithm>
#include <cmath>
#include <climits>
#include <queue>
#include <unordered_map>
#include <unordered_set>
#include <limits>
#include <numeric>
#include <random>

namespace dbscan {

using std::vector;
using node_t = int;
using DistMap = std::unordered_map<node_t, ld>;

struct WalkParams {
    ld max;
    ld assign;
    ld move;
};

static void dijkstra_cut(Graph* g, node_t start, ld cut, bool walk, DistMap& out) {
    out.clear(); if (start < 0 || start >= (node_t)g->nodes.size()) return;
    struct Q { ld d; node_t u; }; auto cmp = [](auto a, auto b){return a.d>b.d;};
    std::priority_queue<Q, vector<Q>, decltype(cmp)> pq(cmp);
    out[start]=0; pq.push({0,start});
    while(!pq.empty()){
        auto [d,u]=pq.top(); pq.pop();
        if(d>cut||out[u]<d-1e-9) continue;
        for(auto e:g->adj[u]) {
            if((walk&&!e->is_walkable)||(!walk&&!e->is_driveable)) continue;
            node_t v=e->v; ld nd=d+e->dist; if(nd>cut) continue;
            if(!out.count(v)||nd<out[v]) {out[v]=nd; pq.push({nd,v});}
        }
    }
}
static node_t valid_node(Graph* g, node_t n, bool walk) {
    if (n>=0 && n<(node_t)g->nodes.size() &&
        (walk?g->nodes[n]->is_walkable:g->nodes[n]->is_driveable)) return n;
    if (n<0||n>=(node_t)g->nodes.size()) n=0;
    return g->get_node(g->nodes[n]->coord, walk);
}
static int drive_deg(Graph* g,node_t n){int d=0;for(auto e:g->adj[n])if(e->is_driveable)d++;return d;}

static node_t walk_node_safe(Graph* g,const vector<node_t>&w,int i,const vector<Student*>&S){
    node_t n=w[i]; return (n>=0&&(size_t)n<g->nodes.size())?n:g->get_node(S[i]->pos,true);
}
static const ld INFVAL = std::numeric_limits<ld>::infinity();
static vector<int> region_query(
    int i,
    const vector<node_t>& w,
    Graph* g,
    ld r,
    const vector<Student*>& S,
    std::vector<std::vector<int>>* cache = nullptr,
    std::vector<char>* ready = nullptr
) {
    if(cache && ready && i >= 0 && i < (int)ready->size() && (*ready)[i]) {
        return (*cache)[i];
    }
    DistMap dist; dijkstra_cut(g,walk_node_safe(g,w,i,S),r,true,dist);
    vector<int>N; for(int j=0;j<(int)w.size();++j){ if(j==i)continue;
        node_t v=walk_node_safe(g,w,j,S);auto it=dist.find(v);
        if(it!=dist.end()&&it->second<=r+1e-6)N.push_back(j);
    }
    if(cache && ready && i >= 0 && i < (int)ready->size()) {
        (*cache)[i] = N;
        (*ready)[i] = true;
    }
    return N;
}
static int medoid(const vector<int>&M,const vector<node_t>&W,Graph*g,
    const vector<Student*>&S,ld max_walk){
    ld best=std::numeric_limits<ld>::max();int bi=M.front();
    for(int i:M){ node_t ni=walk_node_safe(g,W,i,S);
        vector<ld>d;vector<int>p; g->sssp(ni,true,d,p);
        ld tot=0;bool bad=false;
        for(int j:M){node_t nj=walk_node_safe(g,W,j,S);
            if(d[nj]>max_walk+1e-6){bad=true;break;} tot+=d[nj];
        } if(!bad&&tot<best){best=tot;bi=i;}
    } return bi;
}
static vector<vector<int>> make_clusters(const vector<Student*>&S,Graph*g,
    const Params&P,vector<node_t>&W,vector<node_t>&D,std::unordered_map<sid_t,int>&idmap){
    int N=S.size(); W.resize(N); D.resize(N); idmap.clear();
    for(int i=0;i<N;++i){W[i]=g->get_node(S[i]->pos,true);
        D[i]=g->get_node(S[i]->pos,false); idmap[S[i]->id]=i;}
    ld r=(P.seed_radius>0?P.seed_radius:P.max_walk_dist);
    vector<int>lab(N,-1); int cid=0;
    std::vector<std::vector<int>> neigh_cache(N);
    std::vector<char> neigh_ready(N, false);
    for(int i=0;i<N;++i){ if(lab[i]!=-1)continue;
        auto n=region_query(i,W,g,r,S,&neigh_cache,&neigh_ready);
        if((int)n.size()+1<P.min_pts){lab[i]=-2;continue;}
        lab[i]=cid; std::queue<int>q; for(int v:n)q.push(v);
        while(!q.empty()){int j=q.front();q.pop();
            if(lab[j]==-2)lab[j]=cid; if(lab[j]!=-1)continue;
            lab[j]=cid; auto n2=region_query(j,W,g,r,S,&neigh_cache,&neigh_ready);
            if((int)n2.size()+1>=P.min_pts)for(int v:n2)if(lab[v]==-1)q.push(v);
        }++cid;
    }
    vector<vector<int>>C(cid); for(int i=0;i<N;++i)if(lab[i]>=0)C[lab[i]].push_back(i);
    return C;
}

static bool compute_distance_matrix(const vector<int>& cluster,
    const vector<node_t>&W,Graph*g,const vector<Student*>&S,
    const WalkParams&wp, vector<vector<ld>>& dist_out) {
    int n = cluster.size();
    dist_out.assign(n, vector<ld>(n, INFVAL));
    bool ok = false;
    for(int ii = 0; ii < n; ++ii) {
        node_t start = walk_node_safe(g, W, cluster[ii], S);
        DistMap dists;
        dijkstra_cut(g, start, wp.max * 3.0, true, dists);
        for(int jj = 0; jj < n; ++jj) {
            node_t target = walk_node_safe(g, W, cluster[jj], S);
            auto it = dists.find(target);
            if(it != dists.end()) {
                dist_out[ii][jj] = it->second;
                ok = true;
            }
        }
    }
    return ok;
}

static vector<int> init_medoids(const vector<vector<ld>>& dist, int k) {
    int n = dist.size();
    vector<int> medoids;
    vector<ld> total(n, 0);
    for(int i = 0; i < n; ++i) {
        ld sum = 0;
        for(int j = 0; j < n; ++j) {
            ld d = dist[i][j];
            if(std::isinf(d)) d = 1e9;
            sum += d;
        }
        total[i] = sum;
    }
    int first = std::min_element(total.begin(), total.end()) - total.begin();
    medoids.push_back(first);
    vector<ld> minDist(n, INFVAL);
    for(int t = 1; t < k; ++t) {
        int next_idx = -1;
        ld best = -1;
        for(int i = 0; i < n; ++i) {
            ld d = INFVAL;
            for(int m : medoids) {
                d = std::min(d, dist[i][m]);
            }
            if(d > best) {
                best = d;
                next_idx = i;
            }
        }
        if(next_idx == -1) break;
        medoids.push_back(next_idx);
    }
    while((int)medoids.size() < k) {
        medoids.push_back(medoids.back());
    }
    return medoids;
}

static vector<vector<int>> split_cluster_kmedoids(
    const vector<int>& cluster,
    const vector<node_t>& W,
    Graph* g,
    const vector<Student*>& S,
    const WalkParams& wp,
    const Params& P
) {
    vector<vector<int>> groups;
    if(cluster.empty()) return groups;
    int max_group = (P.cap > 0) ? P.cap : (int)cluster.size();
    if((int)cluster.size() <= max_group) {
        groups.push_back(cluster);
        return groups;
    }
    int k = (max_group <= 0) ? 1 : ((cluster.size() + max_group - 1) / max_group);
    if(P.target_stop_count > 0) {
        k = std::min(k, P.target_stop_count);
    }
    vector<vector<ld>> dist;
    if(!compute_distance_matrix(cluster, W, g, S, wp, dist)) {
        // fallback to simple slicing
        for(size_t i = 0; i < cluster.size(); i += max_group) {
            vector<int> chunk;
            for(size_t j = i; j < cluster.size() && (int)(j - i) < max_group; ++j) {
                chunk.push_back(cluster[j]);
            }
            groups.push_back(std::move(chunk));
        }
        return groups;
    }
    vector<int> medoids = init_medoids(dist, std::max(1, k));
    vector<int> assignment(cluster.size(), -1);
    for(int iter = 0; iter < 6; ++iter) {
        bool changed = false;
        // assign
        for(size_t i = 0; i < cluster.size(); ++i) {
            ld best = INFVAL;
            int best_m = -1;
            for(int m_idx = 0; m_idx < (int)medoids.size(); ++m_idx) {
                ld d = dist[i][medoids[m_idx]];
                if(d < best) {
                    best = d;
                    best_m = m_idx;
                }
            }
            if(assignment[i] != best_m) {
                assignment[i] = best_m;
                changed = true;
            }
        }
        // update medoids
        for(int m_idx = 0; m_idx < (int)medoids.size(); ++m_idx) {
            ld best_cost = INFVAL;
            int best_idx = medoids[m_idx];
            for(size_t i = 0; i < cluster.size(); ++i) {
                if(assignment[i] != m_idx) continue;
                ld cost = 0;
                for(size_t j = 0; j < cluster.size(); ++j) {
                    if(assignment[j] != m_idx) continue;
                    ld d = dist[i][j];
                    if(std::isinf(d)) d = 1e9;
                    cost += d;
                }
                if(cost < best_cost) {
                    best_cost = cost;
                    best_idx = i;
                }
            }
            if(best_idx != medoids[m_idx]) {
                medoids[m_idx] = best_idx;
                changed = true;
            }
        }
        if(!changed) break;
    }
    groups.resize(medoids.size());
    for(size_t i = 0; i < cluster.size(); ++i) {
        int a = assignment[i];
        if(a < 0) a = 0;
        if(a >= (int)groups.size()) groups.resize(a + 1);
        groups[a].push_back(cluster[i]);
    }
    // remove empty groups
    vector<vector<int>> filtered;
    for(auto& gset : groups) {
        if(!gset.empty()) filtered.push_back(std::move(gset));
    }
    return filtered;
}

struct StopCandidate{Coordinate*coord;vector<int>cover;node_t walk,drive;};
static vector<node_t> gather_drive(Graph*g,node_t s,ld lim,size_t cap){
    DistMap best;struct Q{ld d;node_t u;};auto cmp=[](auto a,auto b){return a.d>b.d;};
    std::priority_queue<Q,vector<Q>,decltype(cmp)>pq(cmp);
    s=valid_node(g,s,false);best[s]=0;pq.push({0,s});vector<node_t>out;
    while(!pq.empty()){auto[d,u]=pq.top();pq.pop();
        if(d>lim||best[u]<d-1e-9)continue;
        if(g->nodes[u]->is_driveable)out.push_back(u);
        if(out.size()>=cap)break;
        for(auto e:g->adj[u])if(e->is_driveable){
            node_t v=e->v;ld nd=d+e->dist;
            if(nd<=lim&&(!best.count(v)||nd<best[v])){best[v]=nd;pq.push({nd,v});}
        }}
    if(out.empty())out.push_back(s);return out;
}
struct SABest {
    bool valid=false;
    node_t drive=-1;
    node_t walk=-1;
    std::vector<int> cover;
    ld score=0;
};

struct CandidateCache {
    node_t drive=-1;
    node_t walk=-1;
    std::vector<ld> dists;
};

static CandidateCache build_candidate_cache(
    node_t drive,
    const vector<int>& members,
    const vector<node_t>& W,
    Graph* g,
    const vector<Student*>& S,
    const WalkParams& wp
) {
    CandidateCache cache;
    cache.drive = drive;
    cache.walk = valid_node(g, drive, true);
    cache.dists.assign(members.size(), INFVAL);
    if(cache.walk < 0) return cache;
    DistMap dist;
    dijkstra_cut(g, cache.walk, wp.max, true, dist);
    for(size_t idx = 0; idx < members.size(); ++idx) {
        node_t sn = walk_node_safe(g, W, members[idx], S);
        auto it = dist.find(sn);
        if(it != dist.end()) {
            cache.dists[idx] = it->second;
        }
    }
    return cache;
}

static SABest evaluate_state_cached(
    const CandidateCache& cache,
    const vector<int>& members,
    Graph* g,
    const WalkParams& wp
) {
    SABest res;
    if(cache.walk < 0 || cache.dists.size() != members.size()) return res;
    std::vector<int> cover;
    cover.reserve(members.size());
    ld total = 0;
    ld worst = 0;
    for(size_t i = 0; i < members.size(); ++i) {
        ld d = cache.dists[i];
        if(!std::isfinite(d) || d > wp.max + 1e-6) return res;
        total += d;
        worst = std::max(worst, d);
        cover.push_back(members[i]);
    }
    ld pen = (drive_deg(g, cache.drive) <= 2 ? (4 - drive_deg(g, cache.drive)) * 0.4L : 0);
    res.valid = true;
    res.drive = cache.drive;
    res.walk = cache.walk;
    res.cover = std::move(cover);
    res.score = total + 0.35L * worst + pen;
    return res;
}

static SABest evaluate_state(
    node_t drive,
    const vector<int>& members,
    const vector<node_t>& W,
    Graph* g,
    const vector<Student*>& S,
    const WalkParams& wp
) {
    CandidateCache cache = build_candidate_cache(drive, members, W, g, S, wp);
    return evaluate_state_cached(cache, members, g, wp);
}

static StopCandidate run_simulated_annealing(
    const vector<int>& members,
    const vector<CandidateCache>& caches,
    Graph* g,
    const WalkParams& wp
) {
    StopCandidate c{};
    if(caches.empty() || members.empty()) return c;
    std::mt19937 rng(std::random_device{}());
    auto eval_idx = [&](int idx) { return evaluate_state_cached(caches[idx], members, g, wp); };

    SABest current;
    int current_idx = -1;
    for(size_t i = 0; i < caches.size(); ++i) {
        current = eval_idx(static_cast<int>(i));
        if(current.valid) {
            current_idx = static_cast<int>(i);
            break;
        }
    }
    if(!current.valid) return c;
    SABest best = current;
    int best_idx = current_idx;
    std::uniform_real_distribution<double> prob(0.0, 1.0);
    const double maxTemp = std::max<double>(15.0, wp.max * 0.15);
    double temp = maxTemp;
    const double finalTemp = 1.0;
    const double cooling = 0.94;
    const int maxIter = 160;
    std::uniform_int_distribution<int> pick(0, static_cast<int>(caches.size() - 1));

    for(int iter = 0; iter < maxIter && temp > finalTemp; ++iter) {
        int next_idx = pick(rng);
        SABest candidate = eval_idx(next_idx);
        if(!candidate.valid) {
            temp *= cooling;
            continue;
        }
        ld delta = candidate.score - current.score;
        if(delta < 0 || std::exp(-delta / temp) > prob(rng)) {
            current = candidate;
            current_idx = next_idx;
        }
        if(current.score < best.score) {
            best = current;
            best_idx = current_idx;
        }
        temp *= cooling;
    }

    c.coord = g->nodes[best.drive]->coord->make_copy();
    c.walk = best.walk;
    c.drive = best.drive;
    c.cover = best.cover;
    return c;
}

static node_t escape_culdesac(Graph* g, node_t start, ld max_step){
    int start_deg = drive_deg(g,start);
    if(start_deg >= 3) return start;
    std::queue<std::pair<node_t, ld>> q;
    std::vector<char> vis(g->nodes.size(), 0);
    q.push({start, 0});
    vis[start] = 1;
    node_t best = start;
    int best_deg = start_deg;
    while(!q.empty()){
        auto [u, dist] = q.front(); q.pop();
        int deg = drive_deg(g,u);
        if(u != start && deg >= 3){
            return u;
        }
        if(deg > best_deg){
            best = u;
            best_deg = deg;
        }
        for(auto e : g->adj[u]){
            if(!e->is_driveable) continue;
            ld nd = dist + e->dist;
            if(nd > max_step) continue;
            if(vis[e->v]) continue;
            vis[e->v] = 1;
            q.push({e->v, nd});
        }
    }
    return best;
}

static StopCandidate build_cand(const vector<int>&M,const vector<node_t>&W,const vector<node_t>&D,
    const vector<Student*>&S,Graph*g,const WalkParams&wp){
    StopCandidate c{}; if(M.empty())return c;
    int med=medoid(M,W,g,S,wp.max);
    std::unordered_set<node_t>seen;vector<node_t>C;
    const size_t global_cap = 48;
    auto add=[&](int i,size_t k){
        if(i<0) return;
        for(node_t n:gather_drive(g,D[i],wp.move,k)){
            if(seen.insert(n).second){
                C.push_back(n);
                if(C.size()>=global_cap)break;
            }
        }
    };
    add(med,6);
    for(int i:M){
        if(C.size()>=global_cap) break;
        if(i!=med) add(i,3);
    }
    if(C.empty())C.push_back(D[med]);
    std::vector<CandidateCache> caches;
    caches.reserve(C.size());
    for(node_t drive_node : C){
        caches.push_back(build_candidate_cache(drive_node, M, W, g, S, wp));
    }
    c=run_simulated_annealing(M,caches,g,wp);
    if(!c.coord){
        node_t fallback=D[med];
        SABest eval=evaluate_state(fallback,M,W,g,S,wp);
        if(!eval.valid){
            eval.drive=fallback;
            eval.walk=valid_node(g,fallback,true);
            eval.cover={med};
        }
        c.coord=g->nodes[eval.drive]->coord->make_copy();
        c.walk=eval.walk;
        c.drive=eval.drive;
        c.cover=eval.cover;
    }
    node_t adjusted = escape_culdesac(g, c.drive, std::min<ld>(80.0, wp.max * 0.5));
    if(adjusted != c.drive){
        SABest eval = evaluate_state(adjusted, M, W, g, S, wp);
        if(eval.valid){
            delete c.coord;
            c.coord = g->nodes[adjusted]->coord->make_copy();
            c.drive = adjusted;
            c.walk = eval.walk;
            c.cover = eval.cover;
        }
    }
    return c;
}

static const std::vector<std::pair<int, ld>>& cluster_neighbors(
    int sid,
    const std::vector<int>& cluster,
    const vector<node_t>&W,
    Graph*g,
    const WalkParams&wp,
    const std::vector<Student*>&S,
    std::unordered_map<int,std::vector<std::pair<int,ld>>>&cache
) {
    auto it = cache.find(sid);
    if(it != cache.end()) return it->second;

    DistMap dist;
    node_t start = walk_node_safe(g, W, sid, S);
    dijkstra_cut(g, start, wp.max, true, dist);

    std::vector<std::pair<int, ld>> res;
    for(int other : cluster) {
        if(other == sid) continue;
        node_t target = walk_node_safe(g, W, other, S);
        auto jt = dist.find(target);
        if(jt != dist.end() && jt->second <= wp.max + 1e-6) {
            res.push_back({other, jt->second});
        }
    }
    std::sort(res.begin(), res.end(), [](const auto& a, const auto& b){return a.second < b.second;});
    auto inserted = cache.emplace(sid, std::move(res));
    return inserted.first->second;
}

static std::vector<std::vector<int>> partition_cluster(
    const std::vector<int>& cluster,
    const vector<node_t>&W,
    Graph*g,
    const WalkParams&wp,
    const Params&P,
    const std::vector<Student*>&S
) {
    std::vector<std::vector<int>> groups;
    if(cluster.empty()) return groups;

    std::unordered_map<int,int> pos;
    for(int i=0;i<(int)cluster.size();++i) pos[cluster[i]] = i;
    std::vector<bool> used(cluster.size(), false);
    std::unordered_map<int,std::vector<std::pair<int,ld>>> neighbor_cache;
    int max_group = (P.cap>0)?P.cap:INT_MAX;
    int remaining = cluster.size();

    while(remaining > 0) {
        int best_idx = -1;
        std::vector<std::pair<int,ld>> best_neighbors;
        int best_gain = -1;

        for(int i=0;i<(int)cluster.size();++i) {
            if(used[i]) continue;
            int sid = cluster[i];
            const auto& neigh = cluster_neighbors(sid, cluster, W, g, wp, S, neighbor_cache);
            std::vector<std::pair<int,ld>> filtered;
            filtered.reserve(neigh.size());
            for(const auto& pr : neigh) {
                auto it = pos.find(pr.first);
                if(it == pos.end()) continue;
                if(used[it->second]) continue;
                filtered.push_back(pr);
            }
            int gain = 1;
            if(max_group > 1) gain += std::min<int>(max_group-1, filtered.size());
            if(gain > best_gain) {
                best_gain = gain;
                best_idx = i;
                best_neighbors = filtered;
            }
        }

        if(best_idx == -1) break;
        std::sort(best_neighbors.begin(), best_neighbors.end(), [](const auto& a,const auto& b){return a.second < b.second;});

        std::vector<int> group;
        group.push_back(cluster[best_idx]);
        if(!used[best_idx]) {
            used[best_idx] = true;
            remaining--;
        }

        for(const auto& pr : best_neighbors) {
            if((int)group.size() >= max_group) break;
            auto it = pos.find(pr.first);
            if(it == pos.end()) continue;
            int idx = it->second;
            if(used[idx]) continue;
            used[idx] = true;
            remaining--;
            group.push_back(cluster[idx]);
        }
        groups.push_back(group);
    }

    for(int i=0;i<(int)cluster.size();++i) {
        if(!used[i]) {
            groups.push_back({cluster[i]});
            used[i] = true;
        }
    }

    return groups;
}

static void dedup(vector<BusStop*>&st,vector<node_t>&sw,vector<node_t>&sd){
    std::unordered_map<node_t,size_t>k;vector<bool>rem(st.size(),false);
    for(size_t i=0;i<st.size();++i){node_t key=sd[i];
        if(!k.count(key))k[key]=i;else{size_t j=k[key];
            st[j]->students.insert(st[j]->students.end(),
                st[i]->students.begin(),st[i]->students.end());
            rem[i]=true;}}
    vector<BusStop*>S;vector<node_t>W,D;
    for(size_t i=0;i<st.size();++i)if(!rem[i]){
        st[i]->id=S.size();S.push_back(st[i]);
        W.push_back(sw[i]);D.push_back(sd[i]);}
    st.swap(S);sw.swap(W);sd.swap(D);
}

// merge+reassign+enforce 
static void refine(vector<BusStop*>&st,vector<node_t>&sw,vector<node_t>&sd,
    const vector<Student*>&S,const std::unordered_map<sid_t,int>&map,
    const vector<node_t>&W,const vector<node_t>&D,Graph*g,const WalkParams&wp,const Params&P){
    dedup(st,sw,sd);
    vector<DistMap>cov(st.size());
    for(size_t i=0;i<st.size();++i)dijkstra_cut(g,sw[i],wp.max,true,cov[i]);
    vector<vector<sid_t>>ns(st.size());
    std::vector<bool>assigned(S.size(),false);

    auto add_stop_for_student=[&](int idx)->size_t{
        StopCandidate cand=build_cand({idx},W,D,S,g,wp);
        if(!cand.coord){
            cand.coord=S[idx]->pos->make_copy();
            cand.walk=walk_node_safe(g,W,idx,S);
            cand.drive=D[idx];
        }
        auto*stop=new BusStop((bsid_t)st.size(),cand.coord,{});
        st.push_back(stop);
        sw.push_back(cand.walk);
        sd.push_back(cand.drive);
        ns.emplace_back();
        cov.emplace_back();
        dijkstra_cut(g,cand.walk,wp.max,true,cov.back());
        return st.size()-1;
    };

    for(const auto&entry:map){
        sid_t sid=entry.first;
        int idx=entry.second;
        node_t sn=W[idx];
        ld best=std::numeric_limits<ld>::max();
        int bi=-1;
        for(size_t s=0;s<st.size();++s){
            auto it=cov[s].find(sn);
            if(it==cov[s].end())continue;
            if(it->second>wp.max+1e-6)continue;
            if(it->second<best){best=it->second;bi=s;}
        }
        if(bi==-1){
            bi=static_cast<int>(add_stop_for_student(idx));
        }
        ns[bi].push_back(sid);
        assigned[idx]=true;
    }

    for(size_t i=0;i<assigned.size();++i){
        if(assigned[i])continue;
        size_t bi=add_stop_for_student(static_cast<int>(i));
        ns[bi].push_back(S[i]->id);
        assigned[i]=true;
    }

    vector<BusStop*>S2;vector<node_t>W2,D2;
    for(size_t i=0;i<st.size();++i)if(!ns[i].empty()){
        st[i]->students=ns[i];st[i]->id=S2.size();
        S2.push_back(st[i]);W2.push_back(sw[i]);D2.push_back(sd[i]);}
    st.swap(S2);sw.swap(W2);sd.swap(D2);
    dedup(st,sw,sd);
}

static void merge_close_stops(
    Graph* g,
    vector<BusStop*>& st,
    vector<node_t>& sw,
    vector<node_t>& sd,
    ld limit
) {
    if(!g || st.empty() || limit <= 0) return;
    bool merged = true;
    while(merged) {
        merged = false;
        for(size_t i = 0; i < st.size() && !merged; ++i) {
            node_t ni = sd[i];
            if(ni < 0) continue;
            for(size_t j = i + 1; j < st.size(); ++j) {
                node_t nj = sd[j];
                if(nj < 0) continue;
                ld d = g->get_dist(ni, nj, false);
                if(!std::isfinite(d) || d > limit) continue;
                st[i]->students.insert(
                    st[i]->students.end(),
                    st[j]->students.begin(),
                    st[j]->students.end()
                );
                delete st[j]->pos;
                delete st[j];
                st.erase(st.begin() + j);
                sw.erase(sw.begin() + j);
                sd.erase(sd.begin() + j);
                merged = true;
                break;
            }
        }
    }
}

static std::vector<std::vector<int>> plan_global_groups(
    const vector<node_t>&W,
    Graph*g,
    const WalkParams&wp,
    const Params&P,
    const std::vector<Student*>&S,
    size_t target
) {
    std::vector<std::vector<int>> groups;
    size_t N = S.size();
    if(N == 0) return groups;
    std::vector<int> universe(N);
    std::iota(universe.begin(), universe.end(), 0);
    std::vector<bool> used(N,false);
    int remaining = (int)N;
    target = std::max<size_t>(1, std::min(target, N));
    std::unordered_map<int,std::vector<std::pair<int,ld>>> neighbor_cache;

    auto build_from_seed = [&](int seed, int desired){
        std::vector<int> subset;
        subset.push_back(seed);
        const auto& neigh = cluster_neighbors(seed, universe, W, g, wp, S, neighbor_cache);
        for(const auto& pr : neigh) {
            if(used[pr.first]) continue;
            subset.push_back(pr.first);
            if(P.cap > 0 && (int)subset.size() >= P.cap) break;
            if((int)subset.size() >= desired) break;
        }
        return subset;
    };

    while(remaining > 0) {
        size_t remaining_slots = (groups.size() < target) ? (target - groups.size()) : 1;
        int desired = (remaining + (int)remaining_slots - 1) / (int)remaining_slots;
        if(P.cap > 0) desired = std::min(desired, P.cap);
        int best_seed = -1;
        std::vector<int> best_group;
        for(int i = 0; i < (int)N; ++i) {
            if(used[i]) continue;
            auto candidate = build_from_seed(i, desired);
            if(candidate.size() > best_group.size()) {
                best_seed = i;
                best_group = std::move(candidate);
                if((int)best_group.size() >= desired) break;
            }
        }
        if(best_seed == -1) break;
        for(int idx : best_group) {
            if(!used[idx]) {
                used[idx] = true;
                --remaining;
            }
        }
        groups.push_back(std::move(best_group));
    }
    if(remaining > 0) {
        for(int i = 0; i < (int)N; ++i) {
            if(used[i]) continue;
            groups.push_back({i});
            used[i] = true;
        }
    }
    return groups;
}

static void consolidate_global(vector<BusStop*>&st,vector<node_t>&sw,vector<node_t>&sd,
    const vector<Student*>&S,const vector<node_t>&W,const vector<node_t>&D,
    Graph*g,const WalkParams&wp,const Params&P){
    if(P.target_stop_count <= 0) return;
    size_t target = std::max<size_t>(1, P.target_stop_count);
    if(st.size() <= target) return;
    auto groups = plan_global_groups(W, g, wp, P, S, target);
    if(groups.empty()) return;

    std::vector<BusStop*> rebuilt;
    std::vector<node_t> new_sw, new_sd;
    rebuilt.reserve(groups.size());
    std::vector<bool> covered(S.size(), false);
    for(auto& group : groups) {
        if(group.empty()) continue;
        auto cand = build_cand(group, W, D, S, g, wp);
        if(!cand.coord) {
            cand.coord = S[group.front()]->pos->make_copy();
            cand.walk = walk_node_safe(g, W, group.front(), S);
            cand.drive = D[group.front()];
        }
        BusStop* stop = new BusStop((bsid_t)rebuilt.size(), cand.coord, {});
        std::unordered_set<int> included(cand.cover.begin(), cand.cover.end());
        for(int idx : cand.cover) {
            stop->students.push_back(S[idx]->id);
            covered[idx] = true;
        }
        for(int idx : group) {
            if(included.count(idx)) continue;
            stop->students.push_back(S[idx]->id);
            covered[idx] = true;
        }
        rebuilt.push_back(stop);
        new_sw.push_back(cand.walk);
        new_sd.push_back(cand.drive);
    }
    for(int i = 0; i < (int)S.size(); ++i) {
        if(covered[i]) continue;
        StopCandidate cand = build_cand({i}, W, D, S, g, wp);
        if(!cand.coord) {
            cand.coord = S[i]->pos->make_copy();
            cand.walk = walk_node_safe(g, W, i, S);
            cand.drive = D[i];
        }
        BusStop* stop = new BusStop((bsid_t)rebuilt.size(), cand.coord, {S[i]->id});
        rebuilt.push_back(stop);
        new_sw.push_back(cand.walk);
        new_sd.push_back(cand.drive);
        covered[i] = true;
    }
    st.swap(rebuilt);
    sw.swap(new_sw);
    sd.swap(new_sd);
    dedup(st,sw,sd);
}

static void reassign_students(
    vector<BusStop*>& st,
    vector<node_t>& sw,
    vector<node_t>& sd,
    const vector<Student*>& S,
    const vector<node_t>& W,
    const vector<node_t>& D,
    Graph* g,
    const WalkParams& wp,
    const Params& P
) {
    if(st.empty() || S.empty()) return;
    const ld INF = std::numeric_limits<ld>::infinity();
    size_t stop_cnt = st.size();
    size_t stu_cnt = S.size();

    std::vector<std::vector<std::pair<int, ld>>> options(stu_cnt);
    DistMap walk_dists;
    const ld search_limit = std::max<ld>(wp.max * 1.5L, wp.max + 25.0L);
    for(size_t i = 0; i < stop_cnt; ++i) {
        node_t source = valid_node(g, sw[i], true);
        if(source < 0) continue;
        dijkstra_cut(g, source, search_limit, true, walk_dists);
        for(size_t j = 0; j < stu_cnt; ++j) {
            node_t node = walk_node_safe(g, W, static_cast<int>(j), S);
            auto it = walk_dists.find(node);
            if(it == walk_dists.end()) continue;
            ld d = it->second;
            if(std::isnan(d) || d >= INF || d > search_limit) continue;
            options[j].push_back({static_cast<int>(i), d});
        }
        walk_dists.clear();
    }

    std::vector<int> cap(stop_cnt, (P.cap > 0) ? P.cap : INT_MAX);
    std::vector<std::vector<int>> membership(stop_cnt);

    for(size_t j = 0; j < stu_cnt; ++j) {
        auto& opts = options[j];
        if(opts.empty()) {
            for(size_t i = 0; i < stop_cnt; ++i) {
                opts.push_back({static_cast<int>(i), INF});
            }
        }
        std::sort(opts.begin(), opts.end(), [](const auto& a, const auto& b){
            return a.second < b.second;
        });
        bool placed = false;
        for(const auto& pr : opts) {
            int si = pr.first;
            if(si < 0 || si >= static_cast<int>(stop_cnt)) continue;
            if(membership[si].size() >= static_cast<size_t>(cap[si])) continue;
            membership[si].push_back(static_cast<int>(j));
            placed = true;
            break;
        }
        if(!placed) {
            int fallback = opts.front().first;
            fallback = std::max(0, std::min(static_cast<int>(stop_cnt) - 1, fallback));
            membership[fallback].push_back(static_cast<int>(j));
        }
    }

    for(size_t i = 0; i < stop_cnt; ++i) {
        auto& members = membership[i];
        if(members.empty()) {
            st[i]->students.clear();
            continue;
        }
        StopCandidate cand = build_cand(members, W, D, S, g, wp);
        if(cand.coord) {
            delete st[i]->pos;
            st[i]->pos = cand.coord;
            sw[i] = cand.walk;
            sd[i] = cand.drive;
        }
        st[i]->students.clear();
        st[i]->students.reserve(members.size());
        for(int idx : members) {
            st[i]->students.push_back(S[idx]->id);
        }
    }
}

static void merge_culdesac_stops(
    Graph* g,
    vector<BusStop*>& st,
    vector<node_t>& sw,
    vector<node_t>& sd,
    ld max_walk
) {
    if(!g || st.size() < 2) return;
    const ld base_limit = std::min<ld>(std::max<ld>(max_walk * 0.5L, 90.0L), max_walk * 0.9L);
    bool changed = true;
    while(changed) {
        changed = false;
        for(size_t i = 0; i < st.size() && !changed; ++i) {
            node_t walk_i = valid_node(g, sw[i], true);
            node_t drive_i = valid_node(g, sd[i], false);
            if(walk_i < 0 || drive_i < 0) continue;
            int deg_i = drive_deg(g, drive_i);
            if(deg_i > 2) continue;
            DistMap dist;
            dijkstra_cut(g, walk_i, base_limit, true, dist);
            size_t best_j = std::numeric_limits<size_t>::max();
            ld best_d = std::numeric_limits<ld>::max();
            for(size_t j = 0; j < st.size(); ++j) {
                if(i == j) continue;
                node_t walk_j = valid_node(g, sw[j], true);
                auto it = dist.find(walk_j);
                if(it == dist.end()) continue;
                ld d = it->second;
                if(d > base_limit) continue;
                int deg_j = drive_deg(g, valid_node(g, sd[j], false));
                if(deg_j <= 1 && deg_i <= 1) continue;
                if(deg_j < deg_i && d > base_limit * 0.6L) continue;
                if(d < best_d) {
                    best_d = d;
                    best_j = j;
                }
            }
            if(best_j != std::numeric_limits<size_t>::max()) {
                st[best_j]->students.insert(
                    st[best_j]->students.end(),
                    st[i]->students.begin(),
                    st[i]->students.end()
                );
                delete st[i]->pos;
                delete st[i];
                st.erase(st.begin() + i);
                sw.erase(sw.begin() + i);
                sd.erase(sd.begin() + i);
                changed = true;
            }
        }
    }
}

vector<BusStop*> run(const vector<Student*>&S,Graph*g,const Params&Pin){
    Params P=Pin;
    if(P.seed_radius<=0)P.seed_radius=P.max_walk_dist;
    if(P.assign_radius<=0)P.assign_radius=P.max_walk_dist;
    if(P.cap<=0)P.cap=INT_MAX;if(P.min_pts<=0)P.min_pts=1;
    WalkParams wp{P.max_walk_dist,P.assign_radius,std::max(P.max_walk_dist,60.0)};
    vector<node_t>W,D;std::unordered_map<sid_t,int>map;
    auto clusters=make_clusters(S,g,P,W,D,map);
    vector<BusStop*>st;vector<node_t>sw,sd;vector<bool>as(S.size(),false);

    auto emit=[&](const StopCandidate&c){
        if(!c.coord||c.cover.empty())return;
        vector<sid_t>ids;for(int i:c.cover){ids.push_back(S[i]->id);as[i]=true;}
        st.push_back(new BusStop((bsid_t)st.size(),c.coord,ids));
        sw.push_back(c.walk);sd.push_back(c.drive);
    };
    for(auto&M:clusters){
        auto groups = split_cluster_kmedoids(M, W, g, S, wp, P);
        if(groups.empty()) groups.push_back(M);
        for(auto& subset : groups) emit(build_cand(subset, W, D, S, g, wp));
    }
    for(int i=0;i<(int)S.size();++i)
        if(!as[i])emit(build_cand({i},W,D,S,g,wp));
    refine(st,sw,sd,S,map,W,D,g,wp,P);
    consolidate_global(st,sw,sd,S,W,D,g,wp,P);
    merge_close_stops(g, st, sw, sd, std::min<ld>(wp.max * 0.35L, 75.0L));
    merge_culdesac_stops(g, st, sw, sd, wp.max);
    reassign_students(st,sw,sd,S,W,D,g,wp,P);
    return st;
}
vector<BusStop*> place_stops(const vector<Student*>&S,Graph*g,const Params&P,
    std::unordered_map<sid_t,bsid_t>&sid2bs){
    auto st=run(S,g,P);sid2bs.clear();
    for(size_t i=0;i<st.size();++i)
        for(auto sid:st[i]->students)sid2bs[sid]=st[i]->id;
    return st;
}

}

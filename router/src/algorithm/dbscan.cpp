#include "dbscan.h"
#include <algorithm>
#include <cmath>
#include <climits>
#include <queue>
#include <unordered_map>
#include <unordered_set>
#include <limits>

namespace dbscan {

using std::vector;
using node_t = int;
using DistMap = std::unordered_map<node_t, ld>;
static constexpr ld METERS_TO_MILES = 1.0L / 1609.34L;
static inline ld m2g(ld m) { return m * METERS_TO_MILES; }

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
static vector<int> region_query(int i,const vector<node_t>&w,Graph*g,ld r,const vector<Student*>&S){
    DistMap dist; dijkstra_cut(g,walk_node_safe(g,w,i,S),r,true,dist);
    vector<int>N; for(int j=0;j<(int)w.size();++j){ if(j==i)continue;
        node_t v=walk_node_safe(g,w,j,S);auto it=dist.find(v);
        if(it!=dist.end()&&it->second<=r+1e-6)N.push_back(j);
    }return N;
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
    ld r=m2g(P.seed_radius>0?P.seed_radius:P.max_walk_dist);
    vector<int>lab(N,-1); int cid=0;
    for(int i=0;i<N;++i){ if(lab[i]!=-1)continue;
        auto n=region_query(i,W,g,r,S);
        if((int)n.size()+1<P.min_pts){lab[i]=-2;continue;}
        lab[i]=cid; std::queue<int>q; for(int v:n)q.push(v);
        while(!q.empty()){int j=q.front();q.pop();
            if(lab[j]==-2)lab[j]=cid; if(lab[j]!=-1)continue;
            lab[j]=cid; auto n2=region_query(j,W,g,r,S);
            if((int)n2.size()+1>=P.min_pts)for(int v:n2)if(lab[v]==-1)q.push(v);
        }++cid;
    }
    vector<vector<int>>C(cid); for(int i=0;i<N;++i)if(lab[i]>=0)C[lab[i]].push_back(i);
    return C;
}

struct WalkParams{ld max,assign,move;};
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
static StopCandidate build_cand(const vector<int>&M,const vector<node_t>&W,const vector<node_t>&D,
    const vector<Student*>&S,Graph*g,const WalkParams&wp){
    StopCandidate c{}; if(M.empty())return c;
    int med=medoid(M,W,g,S,wp.max);
    std::unordered_set<node_t>seen;vector<node_t>C;
    auto add=[&](int i,size_t k){for(node_t n:gather_drive(g,D[i],wp.move,k))
        if(seen.insert(n).second){C.push_back(n);if(C.size()>=64)break;}};
    add(med,8);for(int i:M)if(C.size()<64&&i!=med)add(i,4);
    if(C.empty())C.push_back(D[med]);
    ld best=std::numeric_limits<ld>::max();node_t bd=-1,bw=-1;
    for(node_t d:C){node_t mw=walk_node_safe(g,W,med,S);
        node_t w=valid_node(g,d,true);
        DistMap dist; dijkstra_cut(g,w,wp.max,true,dist);
        bool ok=true;ld tot=0,worst=0;
        for(int i:M){node_t si=walk_node_safe(g,W,i,S);
            auto it=dist.find(si);
            if(it==dist.end()||it->second>wp.max+1e-6){ok=false;break;}
            tot+=it->second;worst=std::max(worst,it->second);}
        if(!ok)continue;
        ld pen=(drive_deg(g,d)<=2?(4-drive_deg(g,d))*0.5L*wp.max:0);
        ld score=tot+0.25L*worst+pen;
        if(score<best){best=score;bd=d;bw=w;}
    }
    if(bd==-1){bd=D[med];bw=valid_node(g,bd,true);}
    c.coord=g->nodes[bd]->coord->make_copy();c.walk=bw;c.drive=bd;
    DistMap dist; dijkstra_cut(g,c.walk,wp.max,true,dist);
    for(int i:M){node_t si=walk_node_safe(g,W,i,S);
        auto it=dist.find(si);
        if(it!=dist.end()&&it->second<=wp.max+1e-6)c.cover.push_back(i);}
    if(c.cover.empty())c.cover.push_back(med);
    return c;
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
    // reassign every student to closest reachable stop
    vector<DistMap>cov(st.size());
    for(size_t i=0;i<st.size();++i)dijkstra_cut(g,sw[i],wp.max,true,cov[i]);
    vector<vector<sid_t>>ns(st.size());
    for(auto&[sid,idx]:map){
        node_t sn=W[idx];ld bd=std::numeric_limits<ld>::max();int bi=-1;
        for(size_t s=0;s<st.size();++s){
            auto it=cov[s].find(sn);
            if(it!=cov[s].end()&&it->second<=wp.max+1e-6&&it->second<bd){bd=it->second;bi=s;}
        }
        if(bi==-1)bi=0;ns[bi].push_back(sid);
    }
    vector<BusStop*>S2;vector<node_t>W2,D2;
    for(size_t i=0;i<st.size();++i)if(!ns[i].empty()){
        st[i]->students=ns[i];st[i]->id=S2.size();
        S2.push_back(st[i]);W2.push_back(sw[i]);D2.push_back(sd[i]);}
    st.swap(S2);sw.swap(W2);sd.swap(D2);
    dedup(st,sw,sd);
}

vector<BusStop*> run(const vector<Student*>&S,Graph*g,const Params&Pin){
    Params P=Pin;
    if(P.seed_radius<=0)P.seed_radius=P.max_walk_dist;
    if(P.assign_radius<=0)P.assign_radius=P.max_walk_dist;
    if(P.cap<=0)P.cap=INT_MAX;if(P.min_pts<=0)P.min_pts=1;
    WalkParams wp{m2g(P.max_walk_dist),m2g(P.assign_radius),m2g(std::max(P.max_walk_dist,60.0))};
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
        for(auto&chunk:{M})emit(build_cand(M,W,D,S,g,wp)); 
    }
    for(int i=0;i<(int)S.size();++i)
        if(!as[i])emit(build_cand({i},W,D,S,g,wp));
    refine(st,sw,sd,S,map,W,D,g,wp,P);
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

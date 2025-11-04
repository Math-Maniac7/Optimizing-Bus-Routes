#pragma once
#include <vector>
#include "../defs.h"

namespace mcmf {
    using namespace std;
    vector<int> calc_assignment(vector<ld> weights, vector<vector<ld>> costs, vector<ld> capacities);
}

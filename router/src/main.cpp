#include <string>
#include <iostream>
#include <set>
#include <vector>
#include <map>
#include <fstream>
#include <cstdio>
//#include <format>
#include <iomanip>
#include <unistd.h> 
//#include <sys/wait.h>
//#include <curl/curl.h>

#include "defs.h"
#include "graph/Graph.h"
//#include "http/http.h"
#include "routing/BRP.h"
#include "utils.h"

// returns a GeoJSON FeatureCollection with a single LineString feature.
json nodes_to_geojson(std::vector<Node*>& nodes) {
    assert(nodes.size() != 0);

    json coords = json::array();
    for (const Node* n : nodes) {
        assert(n != nullptr);

        // GeoJSON expects [lon, lat]
        double lon = (double) (n->coord->lon);
        double lat = (double) (n->coord->lat);
        coords.push_back({lon, lat});
    }

    json feature = {
        {"type", "Feature"},
        {"properties", {
            {"name", "route"}
        }},
        {"geometry", {
            {"type", "LineString"},
            {"coordinates", coords}
        }}
    };

    json fc = {
        {"type", "FeatureCollection"},
        {"features", json::array({feature})},
    };

    return fc;
}

void do_test() {
    std::cout << "GEOCODE TEST" << std::endl;
    // driveable
    // bool walkable = false;
    // Coordinate a = geocode_freeform("11012 Deep Brook Drive, Austin TX");
    // Coordinate b = geocode_freeform("1801 Edelweiss Drive, Cedar Park TX");

    // walkable
    bool walkable = true;
    Coordinate *a = utils::geocode_freeform("11012 Deep Brook Drive, Austin TX");
    Coordinate *b = utils::geocode_freeform("10316 Prism Drive, Austin TX");

    std::cout << "PATHING TEST" << std::endl;
    ld start_lat = a->lat, start_lon = a->lon;
    ld end_lat = b->lat, end_lon = b->lon;

    ld min_lat = std::min(start_lat, end_lat);
    ld min_lon = std::min(start_lon, end_lon);
    ld max_lat = std::max(start_lat, end_lat);
    ld max_lon = std::max(start_lon, end_lon);
    
    //add 5 mile buffer
    min_lat -= 0.07;
    min_lon -= 0.07;
    max_lat += 0.07;
    max_lon += 0.07;

    Graph* g = utils::create_graph(min_lat, min_lon, max_lat, max_lon);
    std::cout << "DONE CREATE GRAPH\n";

    int start = g->get_node(new Coordinate(start_lat, start_lon), walkable);
    int end = g->get_node(new Coordinate(end_lat, end_lon), walkable);
    std::vector<int> path = g->get_path(start, end, walkable);
    
    std::cout << "PATH : \n";
    for(int x : path) {
        Node* node = g->nodes[x];
        std::cout << std::fixed << std::setprecision(10) << node->coord->lat << " " << node->coord->lon << "\n";
    }

    std::vector<Node*> nodes(path.size());
    for(int i = 0; i < path.size(); i++) nodes[i] = g->nodes[path[i]];

    json geojson = nodes_to_geojson(nodes);
    std::cout << geojson << "\n";
}

BRP* parse_brp(char* json_str) {
    std::string str(json_str);
    json input = json::parse(str);

    //try to parse json into BRP and validate
    BRP* brp;
    try {
        brp = BRP::parse(input);
    }
    catch(const std::runtime_error e) {
        std::cout << "BRP parse error : " << e.what() << "\n";
        return nullptr;
    }
    std::cout << "DONE PARSING BRP" << std::endl;

    //validate BRP
    try {
        brp->validate();
    }
    catch(const std::runtime_error e) {
        std::cout << "BRP validation error : " << e.what() << "\n";
        return nullptr;
    }
    std::cout << "DONE VALIDATING INPUT" << std::endl;

    return brp;
}

#if _ISWASM

extern EMSCRIPTEN_KEEPALIVE char* json_out_to_C_string(char** json_out){
    return *json_out;
}

extern EMSCRIPTEN_KEEPALIVE char* do_p1(char* json_str, char** json_out) {
    *json_out = 0;
    BRP* brp = parse_brp(json_str);
    if(brp == nullptr) {
        return "error parsing/validating brp";
    }
    brp->do_p1();

    //validate before we output
    try {
        brp->validate();
    }
    catch(const std::runtime_error e) {
        std::cout << "BRP validation error : " << e.what() << "\n";
        return "error validating output";
    }
    std::cout << "DONE VALIDATING OUTPUT" << std::endl;

    json output = brp->to_json();
    std::string output_str = to_string(output);

    //char* cstr = (char*) malloc(output_str.size());
    //memcpy(cstr, output_str.c_str(), output_str.size());
    char* cstr = (char*) malloc(output_str.size() + 1); // +1 for '\0'
    memcpy(cstr, output_str.c_str(), output_str.size());
    cstr[output_str.size()] = '\0';
    *json_out = cstr;
    return cstr;
}

extern EMSCRIPTEN_KEEPALIVE char* do_p2(char* json_str) {
    BRP* brp = parse_brp(json_str);
    if(brp == nullptr) {
        return "error parsing/validating brp";
    }
    brp->do_p2();

    //validate before we output
    try {
        brp->validate();
    }
    catch(const std::runtime_error e) {
        std::cout << "BRP validation error : " << e.what() << "\n";
        return "error validating output";
    }
    std::cout << "DONE VALIDATING OUTPUT" << std::endl;

    json output = brp->to_geojson();
    std::string output_str = to_string(output);

    char* cstr = (char*) malloc(output_str.size());
    memcpy(cstr, output_str.c_str(), output_str.size());
    return cstr;
}

extern EMSCRIPTEN_KEEPALIVE char* do_p3(char* json_str) {
    BRP* brp = parse_brp(json_str);
    if(brp == nullptr) {
        return "error parsing/validating brp";
    }
    brp->do_p3();

    //validate before we output
    try {
        brp->validate();
    }
    catch(const std::runtime_error e) {
        std::cout << "BRP validation error : " << e.what() << "\n";
        return "error validating output";
    }
    std::cout << "DONE VALIDATING OUTPUT" << std::endl;

    json output = brp->to_geojson();
    std::string output_str = to_string(output);

    char* cstr = (char*) malloc(output_str.size());
    memcpy(cstr, output_str.c_str(), output_str.size());
    return cstr;
}

/*
int main(){
    std::cout  << "Prove something works";

    const char* input = "{\"school\":{\"lat\":30.455773,\"lon\":-97.798242},\"bus_yard\":{\"lat\":30.455773,\"lon\":-97.798242},\"students\":[{\"id\":0,\"pos\":{\"lat\":30.4524471,\"lon\":-97.8115005}},{\"id\":1,\"pos\":{\"lat\":30.4427579,\"lon\":-97.8028133}},{\"id\":2,\"pos\":{\"lat\":30.4423536,\"lon\":-97.808608}},{\"id\":3,\"pos\":{\"lat\":30.4475907,\"lon\":-97.8188957}},{\"id\":4,\"pos\":{\"lat\":30.4543126,\"lon\":-97.8183026}}],\"buses\":[{\"id\":0,\"capacity\":100}],\"stops\":[{\"id\":0,\"pos\":{\"lat\":30.4524471,\"lon\":-97.8115005},\"students\":[0]},{\"id\":1,\"pos\":{\"lat\":30.4427579,\"lon\":-97.8028133},\"students\":[1]},{\"id\":2,\"pos\":{\"lat\":30.4423536,\"lon\":-97.808608},\"students\":[2]},{\"id\":3,\"pos\":{\"lat\":30.4475907,\"lon\":-97.8188957},\"students\":[3]},{\"id\":4,\"pos\":{\"lat\":30.4543126,\"lon\":-97.8183026},\"students\":[4]}],\"assignments\":[{\"id\":0,\"bus\":0,\"stops\":[0,1,2,3,4]}]}";
    
    char* err = (char*) malloc(strlen(input) + 1);
    strcpy(err, input);

    char* out = do_p1(err);
    std::cout << out;
    std::cout << "done" << std::endl;
}*/

#else

int main(int argc, char* argv[]) {
    if(argc < 3) {
        std::cout << "Usage : \n";
        std::cout << "<p1 | p2 | p3> <in_file>\n";
        std::cout << "-o <out_file>\n";
        std::cout << "-geojson : returns a geojson representation of the resulting BRP\n";
        return 1;
    }

    std::string type = argv[1];
    if(!(type == "p1" || type == "p2" || type == "p3")) {
        std::cout << "Unknown type : " << type << "\n";
        return 1;
    }

    //read file, parse as json
    std::string filepath = argv[2];
    json input;
    {
        std::ifstream in(filepath);
        if(!in) {
            std::cout << "Error: cannot open file: " << filepath << "\n";
            return 1;
        }
        try {
            in >> input;
        } 
        catch(const json::parse_error& e) {
            std::cout << "JSON parse error at byte " << e.byte << ": " << e.what() << "\n";
            return 1;
        }
    }
    std::cout << "DONE PARSING JSON" << std::endl;

    //parse other flags
    bool to_geojson = false;
    int argptr = 3;
    std::string outfile = "";
    while(argptr != argc) {
        std::string next(argv[argptr ++]);
        if(next == "-geojson") {
            to_geojson = true;
        }
        else if(next == "-o") {
            if(argptr == argc) {
                std::cout << "Missing outfile\n";
                return 1;
            }
            outfile = std::string(argv[argptr ++]);
        }
        else {
            std::cout << "Unknown flag : " + next << "\n";
            return 1;
        }
    }

    //try to parse json into BRP and validate
    BRP* brp;
    try {
        brp = BRP::parse(input);
    }
    catch(const std::runtime_error e) {
        std::cout << "BRP parse error : " << e.what() << "\n";
        return 1;
    }
    std::cout << "DONE PARSING BRP" << std::endl;

    //validate BRP
    try {
        brp->validate();
    }
    catch(const std::runtime_error e) {
        std::cout << "BRP validation error : " << e.what() << "\n";
        return 1;
    }
    std::cout << "DONE VALIDATING INPUT" << std::endl;

    //solve BRP
    try {
        std::cout << "SOLVING BRP : " << type << std::endl;
        if(type == "p1") {
            brp->do_p1();
        } 
        else if(type == "p2") {
            brp->do_p2();
        } 
        else if(type == "p3") {
            brp->do_p3();
        } 
        else {
            assert(false);
        }
    } 
    catch (const std::exception& e) {
        std::cout << "Error while processing (" << type << "): " << e.what() << "\n";
        return 1;
    }
    std::cout << "DONE SOLVING" << std::endl;

    //validate before we output
    try {
        brp->validate();
    }
    catch(const std::runtime_error e) {
        std::cout << "BRP validation error : " << e.what() << "\n";
        return 1;
    }
    std::cout << "DONE VALIDATING OUTPUT" << std::endl;

    //convert BRP to json and output
    json output;
    if(to_geojson) {
        output = brp->to_geojson();
    }
    else {
        output = brp->to_json();
    }

    if(outfile != "") {
        std::ofstream fout(outfile);
        fout << output << "\n";
        fout.close();
    }   
    else {
        std::cout << output << "\n";
    }

    return 0;
}

#endif
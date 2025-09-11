#include <bits/stdc++.h>
#include <cstdio>
#include "json.hpp"
using json = nlohmann::json;

std::string run_overpass_fetch(const std::string& query) {
    //write query to temp file
    std::string query_file = "overpass_query.tmp.txt";
    {
        std::ofstream f(query_file, std::ios::binary);
        if (!f) throw std::runtime_error("failed to create temp query file");
        f << query;
    }

    //run overpass_fetch + read in output
    std::string cmd = "py -3 overpass_fetch.py \"" + query_file + "\"";
    std::string out;
    char buf[4096];

    FILE* pipe = _popen(cmd.c_str(), "rb");
    if (!pipe) throw std::runtime_error("_popen failed");
    while (true) {
        size_t n = fread(buf, 1, sizeof(buf), pipe);
        if (n == 0) break;
        out.append(buf, n);
    }
    int rc = _pclose(pipe);

    //delete temp file
    if(std::remove(query_file.c_str()) != 0) throw std::runtime_error("error deleting query file");

    if (rc != 0) throw std::runtime_error("python exited with code " + std::to_string(rc));
    return out;
}

int main(int argc, char* argv[]) {

    try {
        //bbox near cstat
        std::string query =
            "[out:json][timeout:25];"
            "("
              "way[\"highway\"](30.52,-96.39,30.67,-96.24);"
            ");"
            "(._;>;);"
            "out body;";
        std::string raw = run_overpass_fetch(query);

        // std::cout << "RAW : " << raw << "\n";

        json j = json::parse(raw);
        std::cout << "ELEMENTS : " << j["elements"].size() << "\n";

    } 
    catch (const std::exception& e) {
        std::cerr << "Error: " << e.what() << "\n";
        return 1;
    }

    return 0;
}
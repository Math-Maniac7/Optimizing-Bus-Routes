#include "utils.h"

namespace utils {
    std::string run_overpass_fetch(const std::string& query){
        std::string endpoint = "https://overpass-api.de/api/interpreter";
        std::vector<std::string> headers = {
            "Content-Type: text/plain",
            "Accept: application/json"
        };

        const auto resp = http_request(
            endpoint,
            "POST",
            query,
            headers,
            60,
            10,
            true,
            "overpass-client/1.0"
        );

        if (resp.status < 200 || resp.status >= 300) {
            throw std::runtime_error("Overpass HTTP " + std::to_string(resp.status) + ": " + resp.body);
        }
        return resp.body;
    }

    std::string make_overpass_query(ld min_lat, ld min_lon, ld max_lat, ld max_lon) {
        std::ostringstream q;
        q.imbue(std::locale::classic());         
        q << std::fixed << std::setprecision(6);

        q << "[out:json][timeout:25];"
            "("
            // all linear transport features; classify later (car/bike/foot)
            "way[\"highway\"][\"area\"!=\"yes\"][\"highway\"!=\"construction\"][\"highway\"!=\"proposed\"]"
                "("
        << min_lat << "," << min_lon << "," << max_lat << "," << max_lon
        << ");"
            ");"
            "(._;>;);"
            "out body;";

        return q.str();
    }

    Graph* create_graph(ld min_lat, ld min_lon, ld max_lat, ld max_lon) {
        try {
            std::string query = make_overpass_query(min_lat, min_lon, max_lat, max_lon);
            std::string raw = run_overpass_fetch(query);

            std::cout << "QUERY : " << query << "\n";

            json j = json::parse(raw);

            {
                std::set<std::string> types;
                for(auto& [key, value] : j["elements"].items()) {
                    if(value.is_object() && value.contains("type")) types.insert(value["type"]);
                }
                std::cout << "TYPES :\n";
                for(std::string s : types) std::cout << s << "\n";
            }

            Graph* g = Graph::parse(j);
            std::cout << "GRAPH : " << g->nodes.size() << "\n";

            return g;
        } 
        catch (const std::exception& e) {
            std::cout << "failed to create graph : " << e.what() << "\n";
            exit(1);
        }
    }

    // freeform address to coordinate
    Coordinate* geocode_freeform(const std::string& addr) {
        std::ostringstream url;
        url << "https://nominatim.openstreetmap.org/search"
            << "?format=jsonv2&limit=1&addressdetails=1&"
            << "q=" << url_encode(addr);

        std::vector<std::string> hdrs = {"Accept: application/json"};
        HttpResponse resp = http_request(url.str(), "GET", "", hdrs, 60, 10, true, "Router/1.0");

        std::cout << "RESP : " << resp.status << " " << resp.body << "\n";
        json j = json::parse(resp.body);
        assert(j.is_array() && !j.empty());
        const json& first = j[0];
        assert(first.contains("lat") && first.contains("lon"));

        ld lat = std::stold(first.at("lat").get<std::string>());
        ld lon = std::stold(first.at("lon").get<std::string>());

        return new Coordinate(lat, lon);
    }

    // structured address to coordinate
    Coordinate* geocode_structured(
        const std::string& street,
        const std::string& city,
        const std::string& state,
        const std::string& country,
        const std::string& postal
    ) {
        std::ostringstream url;
        url << "https://nominatim.openstreetmap.org/search"
            << "?format=jsonv2&limit=1&addressdetails=1"
            << "&street=" << url_encode(street)
            << "&city=" << url_encode(city)
            << "&state=" << url_encode(state)
            << "&country=" << url_encode(country)
            << "&postalcode=" << url_encode(postal);

        std::vector<std::string> hdrs = {"Accept: application/json"};
        HttpResponse resp = http_request(url.str(), "GET", "", hdrs, 60, 10, true, "Router/1.0");

        std::cout << "RESP : " << resp.status << " " << resp.body << "\n";
        json j = json::parse(resp.body);
        assert(j.is_array() && !j.empty());
        const json& first = j[0];
        assert(first.contains("lat") && first.contains("lon"));

        ld lat = std::stold(first.at("lat").get<std::string>());
        ld lon = std::stold(first.at("lon").get<std::string>());

        return new Coordinate(lat, lon);
    }
}


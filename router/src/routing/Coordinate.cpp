#include "Coordinate.h"

Coordinate::Coordinate(ld _lat, ld _lon) {
    lat = _lat;
    lon = _lon;
}

Coordinate* Coordinate::parse(json& j) {
    if(!j.contains("lat") || !j.contains("lon")) {
        throw std::runtime_error("Coordinate malformed");
    }
    ld lat = j["lat"];
    ld lon = j["lon"];
    return new Coordinate(lat, lon);
}

Coordinate* Coordinate::make_copy() {
    return new Coordinate(lat, lon);
}
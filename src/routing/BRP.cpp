#include "BRP.h"

BRP::BRP(
    Coordinate* _school, 
    Coordinate* _bus_yard, 
    std::vector<Student*> _students, 
    std::vector<Bus*> _buses, 
    std::optional<std::vector<BusStop*>> _stops,
    std::optional<std::vector<BusStopAssignment*>> _assignments,
    std::optional<std::vector<BusRoute*>> _routes
) {
    school = _school;
    bus_yard = _bus_yard;
    students = _students;
    buses = _buses;
    stops = _stops;
    assignments = _assignments;
    routes = _routes;
}

BRP* BRP::parse(json& j) {
    if(!j.contains("school")) throw new std::runtime_error("BRP missing school");
    if(!j.contains("bus_yard")) throw new std::runtime_error("BRP missing bus_yard");
    if(!j.contains("students")) throw new std::runtime_error("BRP missing students");
    if(!j.contains("buses")) throw new std::runtime_error("BRP missing buses");
    Coordinate *school = Coordinate::parse(j["school"]);
    Coordinate *bus_yard = Coordinate::parse(j["bus_yard"]);
    std::vector<Student*> students;
    for(int i = 0; i < j["students"].size(); i++) {
        students.push_back(Student::parse(j["students"][i]));
    }
    std::vector<Bus*> buses;
    for(int i = 0; i < j["buses"].size(); i++) {
        buses.push_back(Bus::parse(j["buses"][i]));
    }

    std::optional<std::vector<BusStop*>> stops = std::nullopt;
    if(j.contains("stops")) {
        if(!j["stops"].is_array()) throw new std::runtime_error("BRP malformed stops");
        stops = std::vector<BusStop*>();
        for(int i = 0; i < j["stops"].size(); i++) {
            stops.value().push_back(BusStop::parse(j["stops"][i]));
        }
    }

    std::optional<std::vector<BusStopAssignment*>> assignments = std::nullopt;
    if(j.contains("assignments")) {
        if(!j["assignments"].is_array()) throw new std::runtime_error("BRP malformed assignments");
        assignments = std::vector<BusStopAssignment*>();
        for(int i = 0; i < j["assignments"].size(); i++) {
            assignments.value().push_back(BusStopAssignment::parse(j["assignments"][i]));
        }
    }

    std::optional<std::vector<BusRoute*>> routes;
    if(j.contains("routes")) {
        if(!j["routes"].is_array()) throw new std::runtime_error("BRP malformed routes");
        routes = std::vector<BusRoute*>();
        for(int i = 0; i < j["routes"].size(); i++) {
            routes.value().push_back(BusRoute::parse(j["routes"][i]));
        }
    }
    
    return new BRP( 
        school,
        bus_yard,
        students,
        buses,
        stops,
        assignments,
        routes
    );
}

BRP* BRP::make_copy() {
    Coordinate *_school = school->make_copy();
    Coordinate *_bus_yard = bus_yard->make_copy();
    std::vector<Student*> _students;
    for(int i = 0; i < students.size(); i++) _students.push_back(students[i]->make_copy());
    std::vector<Bus*> _buses;
    for(int i = 0; i < buses.size(); i++) _buses.push_back(buses[i]->make_copy());
    std::optional<std::vector<BusStop*>> _stops = std::nullopt;
    if(stops.has_value()) {
        _stops = std::vector<BusStop*>();
        for(int i = 0; i < stops.value().size(); i++) _stops.value().push_back(stops.value()[i]->make_copy());
    }
    std::optional<std::vector<BusStopAssignment*>> _assignments = std::nullopt;
    if(assignments.has_value()) {
        _assignments = std::vector<BusStopAssignment*>();
        for(int i = 0; i < assignments.value().size(); i++) _assignments.value().push_back(assignments.value()[i]->make_copy());
    }
    std::optional<std::vector<BusRoute*>> _routes = std::nullopt;
    if(routes.has_value()) {
        _routes = std::vector<BusRoute*>();
        for(int i = 0; i < routes.value().size(); i++) _routes.value().push_back(routes.value()[i]->make_copy());
    }

    return new BRP( 
        _school,
        _bus_yard,
        _students,
        _buses,
        _stops,
        _assignments,
        _routes
    );
}

json BRP::to_json() {
    throw new std::runtime_error("BRP::to_json not implemented");
}

void BRP::validate() {
    throw new std::runtime_error("BRP::validate not implemented");
}

void BRP::do_p1() {
    throw new std::runtime_error("p1 not implemented");
}

void BRP::do_p2() {
    throw new std::runtime_error("p2 not implemented");
}

void BRP::do_p3() {
    throw new std::runtime_error("p3 not implemented");
}
#include "Bus.h"

Bus::Bus(bid_t _id, int _capacity) {
    id = _id;
    capacity = _capacity;
}

Bus* Bus::parse(json& j) {
    if(!j.contains("id") || !j.contains("capacity")) {
        throw std::runtime_error("Bus malformed");
    }
    bid_t id = j["id"];
    int capacity = j["capacity"];
    return new Bus(id, capacity);
}

json Bus::to_json() {
    json ret;
    ret["id"] = this->id;
    ret["capacity"] = this->capacity;
    return ret;
}

Bus* Bus::make_copy() {
    return new Bus(id, capacity);
}
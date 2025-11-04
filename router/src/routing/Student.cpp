#include "Student.h"

Student::Student(sid_t _id, Coordinate* _pos) {
    id = _id;
    pos = _pos;
}

Student* Student::parse(json& j) {
    if(!j.contains("id") || !j.contains("pos")) {
        throw std::runtime_error("Student malformed");
    }
    sid_t id = j["id"];
    Coordinate *pos = Coordinate::parse(j["pos"]);
    return new Student(id, pos);
}

json Student::to_json() {
    json ret;
    ret["id"] = this->id;
    ret["pos"] = this->pos->to_json();
    return ret;
}

Student* Student::make_copy() {
    return new Student(id, pos->make_copy());
}
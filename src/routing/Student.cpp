#include "Student.h"

Student::Student(sid_t _id, Coordinate* _pos) {
    id = _id;
    pos = _pos;
}

Student* Student::parse(json& j) {
    if(!j.contains("id") || !j.contains("pos")) {
        throw new std::runtime_error("Student malformed");
    }
    sid_t id = j["id"];
    Coordinate *pos = Coordinate::parse(j["pos"]);
    return new Student(id, pos);
}

Student* Student::make_copy() {
    return new Student(id, pos->make_copy());
}
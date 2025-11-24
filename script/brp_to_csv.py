#!/usr/bin/env python3
import argparse
import csv
import json
import time
from typing import Dict, Tuple

import requests

NOMINATIM_URL = "https://nominatim.openstreetmap.org/reverse"

def reverse_geocode(lat: float, lon: float, session: requests.Session, cache: Dict[Tuple[float, float], str],
                    sleep_seconds: float = 1.0) -> str:
    """
    Reverse geocode a (lat, lon) pair into an address string using Nominatim.
    Uses a simple in-memory cache and optional sleep to respect rate limits.
    """
    key = (round(lat, 7), round(lon, 7))  # round to avoid tiny float differences

    if key in cache:
        return cache[key]

    params = {
        "format": "jsonv2",
        "lat": lat,
        "lon": lon,
        "addressdetails": 1,
    }
    headers = {
        # Nominatim requires a descriptive User-Agent
        "User-Agent": "bus-routing-reverse-geocoder/1.0"
    }

    try:
        resp = session.get(NOMINATIM_URL, params=params, headers=headers, timeout=10)
        resp.raise_for_status()
        data = resp.json()
        address = data.get("display_name")
        if not address:
            # Fallback: just stringify lat/lon if display_name is missing
            address = f"{lat:.7f}, {lon:.7f}"
    except Exception as e:
        # On any error, log and fall back to lat/lon
        print(f"Warning: reverse geocoding failed for ({lat}, {lon}): {e}")
        address = f"{lat:.7f}, {lon:.7f}"

    cache[key] = address

    # Be kind to the free Nominatim service
    time.sleep(sleep_seconds)

    print("Got :", lat, lon, address)

    return address


def process_file(input_path: str, output_path: str, sleep_seconds: float = 1.0) -> None:
    # Read the JSON (your example file is JSON even though it has .txt extension)
    with open(input_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    session = requests.Session()
    cache: Dict[Tuple[float, float], str] = {}

    rows = []

    # School
    school = data.get("school")
    if school and "lat" in school and "lon" in school:
        s_lat = school["lat"]
        s_lon = school["lon"]
        s_addr = reverse_geocode(s_lat, s_lon, session, cache, sleep_seconds)
        rows.append({
            "type": "school",
            "address": s_addr,
            "id": ""
        })

    # Bus yard
    bus_yard = data.get("bus_yard")
    if bus_yard and "lat" in bus_yard and "lon" in bus_yard:
        b_lat = bus_yard["lat"]
        b_lon = bus_yard["lon"]
        b_addr = reverse_geocode(b_lat, b_lon, session, cache, sleep_seconds)
        rows.append({
            "type": "bus_yard",
            "address": b_addr,
            "id": ""
        })

    # Students
    students = data.get("students", [])
    for stu in students:
        sid = stu.get("id")
        pos = stu.get("pos", {})
        lat = pos.get("lat")
        lon = pos.get("lon")
        if lat is None or lon is None:
            print(f"Warning: student {sid} missing lat/lon; skipping")
            continue

        addr = reverse_geocode(lat, lon, session, cache, sleep_seconds)
        rows.append({
            "type": "student",
            "address": addr,
            "id": sid if sid is not None else ""
        })

    # Write CSV
    fieldnames = ["type", "address", "id"]
    with open(output_path, "w", newline="", encoding="utf-8") as csvfile:
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow(row)

    print(f"Wrote {len(rows)} rows to {output_path}")


def main():
    parser = argparse.ArgumentParser(
        description="Convert bus-routing JSON (school, bus_yard, students) to CSV with reverse-geocoded addresses."
    )
    parser.add_argument("input", help="Input JSON file (e.g., average_missouri.txt)")
    parser.add_argument("output", help="Output CSV file path")
    parser.add_argument(
        "--sleep",
        type=float,
        default=1.0,
        help="Seconds to sleep between reverse geocoding requests (default: 1.0, increase if you hit rate limits).",
    )

    args = parser.parse_args()
    process_file(args.input, args.output, sleep_seconds=args.sleep)


if __name__ == "__main__":
    main()

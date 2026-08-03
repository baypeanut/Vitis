#!/usr/bin/env python3
"""
import_xwines.py
================
Transforms the X-Wines dataset CSV into a Supabase-ready wines import CSV.

Usage:
    python import_xwines.py XWines_Wines.csv

Output:
    wines_import.csv  — upload this in Supabase Dashboard:
                        Table Editor → wines → Import data from CSV

X-Wines dataset: https://github.com/rogerioxavier/X-Wines
License: CC0 1.0 (Public Domain)
"""

import ast
import csv
import sys
from pathlib import Path

# Map X-Wines "Type" values to Pari category CHECK constraint values.
# Pari schema: category IN ('Red', 'White', 'Sparkling', 'Rose') OR NULL
# Empty string in CSV must be imported as NULL in Supabase (Table Editor usually does this).
CATEGORY_MAP = {
    "Red":          "Red",
    "White":        "White",
    "Rosé":         "Rose",
    "Rose":         "Rose",
    "Sparkling":    "Sparkling",
    "Dessert/Port": "",   # → import as NULL
    "Fortified":    "",   # → import as NULL
}


def parse_python_list(raw: str) -> list[str]:
    """Parse a Python list literal string like "['Merlot', 'Cab']" → ['Merlot', 'Cab']."""
    if not raw or raw.strip() in ("nan", "[]", ""):
        return []
    try:
        result = ast.literal_eval(raw.strip())
        return [str(x).strip() for x in result] if isinstance(result, list) else []
    except (ValueError, SyntaxError):
        return []


def join_grapes(lst: list[str]) -> str:
    """Join the full grape list, preserving order and dropping duplicates.

    Keeping only the first grape collapsed every blend to its lead varietal, so a
    Bordeaux blend imported as plain "Cabernet Sauvignon". That loses real information
    twice over: the catalog reads wrong, and compute_wine_embedding derives the wine
    vector from (category, variety, region), so the blend never reaches the taste model.
    """
    seen: set[str] = set()
    ordered: list[str] = []
    for grape in lst:
        key = grape.casefold()
        if grape and key not in seen:
            seen.add(key)
            ordered.append(grape)
    return ", ".join(ordered)


def build_region(region_name: str, country: str) -> str:
    region_name = region_name.strip()
    country = country.strip()
    if region_name and country and country not in region_name:
        return f"{region_name}, {country}"
    return region_name or country


def transform(input_path: str, output_path: str) -> None:
    seen: set[tuple[str, str]] = set()
    rows: list[dict] = []
    skipped = 0

    with open(input_path, encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            name     = row.get("WineName", "").strip()
            producer = row.get("WineryName", "").strip()

            if not name or not producer:
                skipped += 1
                continue

            # Deduplicate: one catalog entry per (name, producer) pair.
            key = (name.casefold(), producer.casefold())
            if key in seen:
                continue
            seen.add(key)

            category = CATEGORY_MAP.get(row.get("Type", "").strip(), "")
            grapes   = parse_python_list(row.get("Grapes", ""))
            variety  = join_grapes(grapes)
            region   = build_region(row.get("RegionName", ""), row.get("Country", ""))

            rows.append({
                "name":     name,
                "producer": producer,
                "region":   region,
                "variety":  variety,
                "category": category,
                # vintage left NULL — users specify the vintage they actually drank.
                # label_image_url left NULL — X-Wines has no label images.
            })

    with open(output_path, "w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=["name", "producer", "region", "variety", "category"],
        )
        writer.writeheader()
        writer.writerows(rows)

    print(f"✓ {len(rows):,} unique wines written to: {output_path}")
    if skipped:
        print(f"  (skipped {skipped} rows with missing name/producer)")
    print()
    print("Next step: upload wines_import.csv in Supabase →")
    print("  Table Editor → wines table → Import data from CSV")
    print("  ✓ 'name', 'producer', 'region', 'variety', 'category' columns map directly.")
    print("  ✓ Empty 'category' cells must import as NULL (Dessert/Port, Fortified).")
    print("  ✓ 'id' and 'created_at' will be auto-filled by Supabase.")
    print("  ✓ Duplicate detection: Supabase will error on exact duplicate UUIDs,")
    print("    but since IDs are auto-generated, each row gets a fresh UUID.")
    print("    Run the de-dup query below after import if needed.")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    input_file  = sys.argv[1]
    output_file = str(Path(input_file).with_name("wines_import.csv"))
    transform(input_file, output_file)

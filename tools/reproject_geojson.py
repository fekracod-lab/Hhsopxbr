#!/usr/bin/env python3
"""
Reproject a GeoJSON file to EPSG:4326 (WGS84).

Usage:
  python tools\reproject_geojson.py --in assets/al_qaim_roads.geojson --out assets/al_qaim_roads_wgs84.geojson

If --overwrite is passed, the input file will be overwritten.

This script will try to auto-detect the source CRS by sampling coordinates:
- If coordinates look like lon/lat already (lon between -180..180 and lat between -90..90) it will skip.
- If coordinates look like Web Mercator (large meter values) it assumes EPSG:3857.
- If coordinates look like UTM (easting ~100000..900000, northing up to ~10000000), it assumes EPSG:32638 (UTM zone 38N) which is common for Iraq.

If pyproj is available it uses it for accurate transforms. Otherwise it will ask you to install pyproj.

Note: For best results use QGIS or ogr2ogr if you know the exact source CRS.
"""

import argparse
import json
import math
import sys
from pathlib import Path

try:
    from pyproj import Transformer
except Exception:
    Transformer = None


def sample_first_coords(obj):
    """Recursively find the first numeric coordinate pair in the GeoJSON structure."""
    if isinstance(obj, list):
        if len(obj) >= 2 and isinstance(obj[0], (int, float)) and isinstance(obj[1], (int, float)):
            return obj[0], obj[1]
        for item in obj:
            res = sample_first_coords(item)
            if res:
                return res
    elif isinstance(obj, dict):
        for k in ('coordinates', 'geometry', 'features', 'features'):
            if k in obj:
                res = sample_first_coords(obj[k])
                if res:
                    return res
        for v in obj.values():
            res = sample_first_coords(v)
            if res:
                return res
    return None


def detect_epsg_from_coords(x, y):
    # 1) lon/lat check
    if abs(x) <= 180 and abs(y) <= 90:
        return 4326
    # 2) web mercator meters (approx bounds)
    if abs(x) > 1000 and abs(x) <= 20037508 and abs(y) > 1000 and abs(y) <= 20037508:
        return 3857
    # 3) UTM heuristics (easting ~100000..1000000, northing 0..10000000)
    if 100000 <= abs(x) <= 1000000 and 0 <= abs(y) <= 10000000:
        # assume UTM zone 38N (EPSG:32638)
        return 32638
    # fallback
    return None


def transform_coords_array(coords, transformer):
    # coords can be nested arrays (Point: [x,y], LineString: [[x,y], ...], Polygon: [[[x,y], ...], ...])
    if isinstance(coords, list) and len(coords) >= 2 and isinstance(coords[0], (int, float)) and isinstance(coords[1], (int, float)):
        x, y = float(coords[0]), float(coords[1])
        try:
            lon, lat = transformer.transform(x, y)
        except Exception:
            # pyproj newer interface sometimes expects (x,y) -> (lon,lat)
            lon, lat = transformer.transform(x, y)
        return [lon, lat]
    elif isinstance(coords, list):
        return [transform_coords_array(c, transformer) for c in coords]
    else:
        return coords


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--in', dest='infile', required=True, help='Input GeoJSON path')
    p.add_argument('--out', dest='outfile', required=False, help='Output GeoJSON path (defaults to input + _wgs84.geojson)')
    p.add_argument('--overwrite', action='store_true', help='Overwrite input file')
    args = p.parse_args()

    infile = Path(args.infile)
    if not infile.exists():
        print('Input file not found:', infile)
        sys.exit(2)

    if args.outfile:
        outfile = Path(args.outfile)
    else:
        outfile = infile.with_name(infile.stem + '_wgs84.geojson')

    with infile.open('r', encoding='utf-8') as fh:
        data = json.load(fh)

    sample = sample_first_coords(data)
    if not sample:
        print('Could not find coordinates sample in the file. Exiting.')
        sys.exit(3)

    x, y = sample
    detected = detect_epsg_from_coords(x, y)

    if detected == 4326:
        print('File appears to already be EPSG:4326 (WGS84). Writing a copy to', outfile)
        with outfile.open('w', encoding='utf-8') as fh:
            json.dump(data, fh, ensure_ascii=False)
        if args.overwrite:
            infile.unlink()
            outfile.replace(infile)
        print('Done.')
        return

    if detected is None:
        print('Could not auto-detect CRS from sample coordinates:', x, y)
        print('Please reproject using QGIS or pass a known EPSG by editing this script. Defaulting to EPSG:3857 assumption.')
        detected = 3857

    print(f'Detected source EPSG:{detected} from sample {x},{y}')

    if Transformer is None:
        print('\npyproj is required for transformation. Install with:')
        print('  pip install pyproj')
        sys.exit(4)

    try:
        transformer = Transformer.from_crs(f'EPSG:{detected}', 'EPSG:4326', always_xy=True)
    except Exception as e:
        print('Failed to create transformer:', e)
        sys.exit(5)

    def transform_feature(obj):
        if isinstance(obj, dict) and 'type' in obj:
            t = obj['type']
            if t == 'FeatureCollection' and 'features' in obj:
                obj['features'] = [transform_feature(f) for f in obj['features']]
                return obj
            if t == 'Feature' and 'geometry' in obj:
                obj['geometry'] = transform_feature(obj['geometry'])
                return obj
            if t in ('Point', 'MultiPoint', 'LineString', 'MultiLineString', 'Polygon', 'MultiPolygon') and 'coordinates' in obj:
                obj['coordinates'] = transform_coords_array(obj['coordinates'], transformer)
                return obj
        elif isinstance(obj, dict):
            return {k: transform_feature(v) for k, v in obj.items()}
        elif isinstance(obj, list):
            return [transform_feature(v) for v in obj]
        return obj

    newdata = transform_feature(data)

    with outfile.open('w', encoding='utf-8') as fh:
        json.dump(newdata, fh, ensure_ascii=False)

    if args.overwrite:
        infile.unlink()
        outfile.replace(infile)
        print('Overwrote original file with reprojected GeoJSON:', infile)
    else:
        print('Wrote reprojected GeoJSON to', outfile)


if __name__ == '__main__':
    main()

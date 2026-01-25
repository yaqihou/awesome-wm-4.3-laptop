#!/usr/bin/env python3

"""
Ultra-fast conversion of Lua table cache to CSV using Polars
Usage: python3 convert_to_csv_fast.py
"""

import os
import re
import time
from pathlib import Path

try:
    import polars as pl
except ImportError:
    print("Error: Polars is not installed. Install it with: pip install polars")
    exit(1)

# Configuration
CONFIG = {
    'text_cache_path': os.path.expanduser('~/.config/awesome/wallpaper-ratio-cache.json'),
    'csv_output_path': os.path.expanduser('~/.config/awesome/wallpaper-cache.csv')
}

def parse_lua_table_fast(content):
    """
    Ultra-fast parsing of Lua table format using regex and list comprehension
    """
    print("Parsing Lua table...")

    # Find the cache table content - handle nested braces properly
    cache_start = content.find('["cache"] = {')
    if cache_start == -1:
        print("Error: Could not find cache table in content")
        return None

    # Find the matching closing brace by counting braces
    brace_count = 0
    cache_end = -1
    for i in range(cache_start + len('["cache"] = {'), len(content)):
        if content[i] == '{':
            brace_count += 1
        elif content[i] == '}':
            brace_count -= 1
            if brace_count == -1:  # Found the closing brace for cache table
                cache_end = i
                break

    if cache_end == -1:
        print("Error: Could not find end of cache table")
        return None

    cache_content = content[cache_start + len('["cache"] = {'):cache_end]

    # Pattern to match each cache entry with multiline content
    entry_pattern = r'\["([^"]+)"\]\s*=\s*\{([^}]+)\},'
    entries = re.findall(entry_pattern, cache_content, re.MULTILINE | re.DOTALL)

    print(f"Found {len(entries)} cache entries to parse...")

    if len(entries) == 0:
        print("No entries found!")
        return None

    # Pre-compile regex patterns for better performance
    height_pattern = re.compile(r'\["height"\]\s*=\s*(\d+)')
    ratio_pattern = re.compile(r'\["ratio"\]\s*=\s*"([^"]+)"')
    width_pattern = re.compile(r'\["width"\]\s*=\s*(\d+)')

    # Parse all entries using list comprehension for speed
    data = []
    skipped = 0

    print("Parsing entries...")
    for i, (filepath, entry_content) in enumerate(entries):
        height_match = height_pattern.search(entry_content)
        ratio_match = ratio_pattern.search(entry_content)
        width_match = width_pattern.search(entry_content)

        if height_match and ratio_match and width_match:
            data.append({
                'path': filepath,
                'ratio': ratio_match.group(1),
                'width': int(width_match.group(1)),
                'height': int(height_match.group(1))
            })
        else:
            skipped += 1

        # Progress reporting
        if (i + 1) % 10000 == 0:
            print(f"Processed {i + 1}/{len(entries)} entries...")

    print(f"Successfully parsed {len(data)} entries, skipped {skipped}")
    return data

def convert_with_polars(data, output_path):
    """Convert data to CSV using Polars (ultra-fast)"""
    print(f"Converting {len(data)} entries to CSV using Polars...")

    start_time = time.time()

    # Create Polars DataFrame
    df = pl.DataFrame(data)

    # Write to CSV (Polars is optimized for this)
    df.write_csv(output_path)

    conversion_time = time.time() - start_time

    print(f"Polars CSV conversion completed in {conversion_time:.2f} seconds")
    print(f"Processing rate: {len(data) / conversion_time:.0f} entries/second")
    print(f"Output file: {output_path}")

    return True

def load_text_cache(cache_path):
    """Load and validate the text cache file"""
    if not os.path.exists(cache_path):
        print(f"Error: Cache file not found: {cache_path}")
        return None

    print(f"Loading cache file: {cache_path}")
    file_size = os.path.getsize(cache_path)
    print(f"File size: {file_size / (1024*1024):.2f} MB")

    try:
        with open(cache_path, 'r', encoding='utf-8') as f:
            content = f.read()

        if not content.strip():
            print("Error: Cache file is empty")
            return None

        print("Cache file loaded successfully")
        return content

    except Exception as e:
        print(f"Error reading cache file: {e}")
        return None

def main():
    """Main conversion function"""
    print("Ultra-Fast Wallpaper Cache to CSV Converter (Python + Polars)")
    print("=" * 65)
    print(f"Input:  {CONFIG['text_cache_path']}")
    print(f"Output: {CONFIG['csv_output_path']}")
    print()

    total_start_time = time.time()

    # Load text cache
    print("Step 1: Loading text cache...")
    load_start = time.time()
    content = load_text_cache(CONFIG['text_cache_path'])
    if content is None:
        return 1
    load_time = time.time() - load_start
    print(f"Load completed in {load_time:.2f} seconds")

    # Parse cache data
    print("\nStep 2: Parsing cache data...")
    parse_start = time.time()
    data = parse_lua_table_fast(content)
    parse_time = time.time() - parse_start
    print(f"Parsing completed in {parse_time:.2f} seconds")

    if data is None or len(data) == 0:
        print("Failed to parse cache data")
        return 1

    # Convert to CSV using Polars
    print("\nStep 3: Converting to CSV with Polars...")
    success = convert_with_polars(data, CONFIG['csv_output_path'])

    total_time = time.time() - total_start_time

    if success:
        print(f"\nConversion successful!")
        print(f"Total time: {total_time:.2f} seconds")
        print(f"Overall processing rate: {len(data) / total_time:.0f} entries/second")
        print(f"Entries processed: {len(data):,}")
        return 0
    else:
        print(f"\nConversion failed!")
        return 1

if __name__ == '__main__':
    exit(main())
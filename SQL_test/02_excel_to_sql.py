#!/usr/bin/env python3
"""
Excel to PostgreSQL Converter for JLPT N1 Vocabulary
=====================================================
This script reads the Excel file and generates SQL INSERT statements.
It AUTO-GENERATES example_before and example_after from full_sentence.

Supports:
- Direct kanji matches
- Verb conjugations (ichidan, godan)
- い-adjective conjugations
- な-adjective variations
- Compound words with particles

Usage:
    python 02_excel_to_sql.py <path_to_excel_file>
    
Output:
    Creates 03_insert_data.sql file with all INSERT statements
"""

import pandas as pd
import re
import sys
from pathlib import Path


# =============================================================================
# Japanese Word Pattern Matching
# =============================================================================

def get_stem_patterns(kanji):
    """
    Generate possible stems and conjugation patterns for a Japanese word.
    Returns a list of possible patterns to search for in sentences.
    """
    patterns = [kanji]  # Always try exact match first
    
    # Clean the kanji (remove markers like ＊, +, etc.)
    clean_kanji = re.sub(r'[＊\*\+（）\(\)①②③④⑤]', '', kanji).strip()
    if clean_kanji != kanji:
        patterns.append(clean_kanji)
    
    # Verb endings (godan and ichidan)
    verb_endings = {
        # Ichidan verbs (る verbs) - remove る, add conjugations
        'る': ['', 'て', 'た', 'ない', 'ます', 'れば', 'よう', 'られる', 'させる', 
               'ている', 'ていた', 'てる', 'てた', 'ず', 'ずに', 'たい', 'たら', 
               'たり', 'ろ', 'れ', 'させ', 'られ', 'なかった'],
        # Godan verbs ending in う
        'う': ['わ', 'い', 'って', 'った', 'わない', 'います', 'えば', 'おう',
               'わず', 'いたい', 'ったら', 'ったり', 'え', 'わなかった'],
        # Godan verbs ending in く
        'く': ['か', 'き', 'いて', 'いた', 'かない', 'きます', 'けば', 'こう',
               'かず', 'きたい', 'いたら', 'いたり', 'け', 'かなかった'],
        # Godan verbs ending in ぐ
        'ぐ': ['が', 'ぎ', 'いで', 'いだ', 'がない', 'ぎます', 'げば', 'ごう',
               'がず', 'ぎたい', 'いだら', 'いだり', 'げ', 'がなかった'],
        # Godan verbs ending in す
        'す': ['さ', 'し', 'して', 'した', 'さない', 'します', 'せば', 'そう',
               'さず', 'したい', 'したら', 'したり', 'せ', 'さなかった'],
        # Godan verbs ending in つ
        'つ': ['た', 'ち', 'って', 'った', 'たない', 'ちます', 'てば', 'とう',
               'たず', 'ちたい', 'ったら', 'ったり', 'て', 'たなかった'],
        # Godan verbs ending in ぬ
        'ぬ': ['な', 'に', 'んで', 'んだ', 'なない', 'にます', 'ねば', 'のう',
               'なず', 'にたい', 'んだら', 'んだり', 'ね', 'ななかった'],
        # Godan verbs ending in ぶ
        'ぶ': ['ば', 'び', 'んで', 'んだ', 'ばない', 'びます', 'べば', 'ぼう',
               'ばず', 'びたい', 'んだら', 'んだり', 'べ', 'ばなかった'],
        # Godan verbs ending in む
        'む': ['ま', 'み', 'んで', 'んだ', 'まない', 'みます', 'めば', 'もう',
               'まず', 'みたい', 'んだら', 'んだり', 'め', 'まなかった'],
    }
    
    # い-adjective endings
    i_adj_endings = ['い', 'く', 'くて', 'かった', 'くない', 'くなかった', 
                     'ければ', 'さ', 'そう', 'すぎる', 'すぎ', 'み']
    
    # Check for verb patterns
    for ending, conjugations in verb_endings.items():
        if clean_kanji.endswith(ending):
            stem = clean_kanji[:-len(ending)]
            if stem:  # Make sure we have a stem
                for conj in conjugations:
                    patterns.append(stem + conj)
                # Also add just the stem for partial matches
                patterns.append(stem)
    
    # Check for い-adjective patterns
    if clean_kanji.endswith('い') and len(clean_kanji) > 1:
        stem = clean_kanji[:-1]
        for ending in i_adj_endings:
            patterns.append(stem + ending)
        patterns.append(stem)
    
    # Check for な-adjective (with or without な)
    if clean_kanji.endswith('な'):
        stem = clean_kanji[:-1]
        patterns.extend([stem, stem + 'な', stem + 'に', stem + 'だ', stem + 'で', 
                        stem + 'だった', stem + 'ではない', stem + 'じゃない'])
    # Also check if it might be a な-adj without the な marker
    if clean_kanji.endswith('(な)') or clean_kanji.endswith('（な）'):
        stem = re.sub(r'[\(（]な[\)）]$', '', clean_kanji)
        patterns.extend([stem, stem + 'な', stem + 'に', stem + 'だ', stem + 'で'])
    
    # For compound words with particles, try variations
    for particle in ['が', 'を', 'に', 'で', 'と', 'の']:
        if particle in clean_kanji:
            parts = clean_kanji.split(particle)
            patterns.extend(parts)
            # Also try without the particle
            patterns.append(clean_kanji.replace(particle, ''))
    
    # Remove duplicates while preserving order (longer patterns first for accuracy)
    seen = set()
    unique_patterns = []
    for p in patterns:
        if p and p not in seen:
            seen.add(p)
            unique_patterns.append(p)
    
    return unique_patterns


def find_word_in_sentence(kanji, sentence):
    """
    Find the kanji word (or its conjugated form) in the sentence.
    Returns (before, matched_form, after) or (None, None, None) if not found.
    """
    if not sentence or not kanji:
        return None, None, None
    
    if pd.isna(sentence) or pd.isna(kanji):
        return None, None, None
    
    sentence = str(sentence)
    kanji = str(kanji)
    
    # Get all possible patterns
    patterns = get_stem_patterns(kanji)
    
    # Try each pattern, longest match first for accuracy
    patterns_sorted = sorted(patterns, key=len, reverse=True)
    
    for pattern in patterns_sorted:
        if pattern and pattern in sentence:
            idx = sentence.index(pattern)
            before = sentence[:idx]
            after = sentence[idx + len(pattern):]
            return before, pattern, after
    
    return None, None, None


# =============================================================================
# SQL Generation Functions
# =============================================================================

def escape_sql_string(value):
    """Escape single quotes for SQL and handle None/NaN values."""
    if pd.isna(value) or value is None:
        return "NULL"
    # Convert to string and escape single quotes
    s = str(value).replace("'", "''")
    return f"'{s}'"


def parse_week_day(lecture_str):
    """Parse lecture string like '1週1日' to (week, day)."""
    if pd.isna(lecture_str):
        return None, None
    match = re.match(r'(\d+)週(\d+)日', str(lecture_str))
    if match:
        return int(match.group(1)), int(match.group(2))
    return None, None


def determine_difficulty(raw_word):
    """Determine difficulty level based on ＊ markers."""
    if pd.isna(raw_word):
        return 1
    raw_str = str(raw_word)
    if '＊＊' in raw_str or '**' in raw_str:
        return 3  # Most difficult
    elif '＊' in raw_str or '*' in raw_str:
        return 2  # Medium difficulty
    elif '+' in raw_str:
        return 2  # Also marked
    return 1  # Normal


def determine_word_type(raw_word, meaning):
    """Try to determine word type from the word itself."""
    if pd.isna(raw_word):
        return None
    raw_str = str(raw_word)
    
    # Check for な-adjective marker
    if '(な)' in raw_str or '（な）' in raw_str:
        return 'な-adjective'
    
    # Check meaning for clues
    if not pd.isna(meaning):
        meaning_str = str(meaning).lower()
        if meaning_str.startswith('to '):  # Starts with "to " - likely a verb
            return 'verb'
    
    # Check ending patterns
    clean_word = re.sub(r'[＊\*\+（）\(\)]', '', raw_str)
    if clean_word.endswith('い') and not clean_word.endswith('しい'):
        # Most い endings are い-adjectives, but しい can be tricky
        if len(clean_word) > 1:
            return 'い-adjective'
    elif clean_word.endswith('る') or clean_word.endswith('す') or \
         clean_word.endswith('く') or clean_word.endswith('ぐ') or \
         clean_word.endswith('む') or clean_word.endswith('ぶ') or \
         clean_word.endswith('つ') or clean_word.endswith('う'):
        return 'verb'
    
    return None


# =============================================================================
# Main Function
# =============================================================================

def main(excel_path):
    """Main function to convert Excel to SQL."""
    
    print(f"Reading Excel file: {excel_path}")
    xlsx = pd.ExcelFile(excel_path)
    
    # Read the raw data sheet (most complete data)
    df = pd.read_excel(xlsx, sheet_name='1_raw_data', header=1)
    
    # Filter out rows without valid data
    df = df[df['Sr no'].notna() & df['Kanji'].notna()]
    
    print(f"Found {len(df)} vocabulary entries")
    
    # Statistics
    total_with_sentence = 0
    auto_generated = 0
    
    # Prepare SQL output
    sql_lines = []
    sql_lines.append("-- =====================================================")
    sql_lines.append("-- JLPT N1 Vocabulary Data Import")
    sql_lines.append("-- Generated from Excel file")
    sql_lines.append("-- example_before and example_after are AUTO-GENERATED")
    sql_lines.append("-- from full_sentence using Japanese conjugation rules")
    sql_lines.append("-- =====================================================")
    sql_lines.append("")
    sql_lines.append("-- Make sure to run 01_create_schema.sql first!")
    sql_lines.append("")
    sql_lines.append("BEGIN;")
    sql_lines.append("")
    sql_lines.append("-- Insert vocabulary data")
    sql_lines.append("INSERT INTO vocabulary (")
    sql_lines.append("    ref_no, kanji, hiragana, meaning_en,")
    sql_lines.append("    example_before, example_after, hint, full_sentence,")
    sql_lines.append("    page_no, schedule_id, word_type, difficulty_level")
    sql_lines.append(") VALUES")
    
    values_list = []
    
    for idx, row in df.iterrows():
        # Extract data from row
        ref_no = int(row['Sr no']) if pd.notna(row['Sr no']) else 'NULL'
        kanji = row['Kanji']
        kanji_sql = escape_sql_string(kanji)
        hiragana = escape_sql_string(row['Hiragana'])
        meaning = escape_sql_string(row['Meaning'])
        hint = escape_sql_string(row['Hint'])
        sentence = row['Sentence']
        sentence_sql = escape_sql_string(sentence)
        
        # AUTO-GENERATE example_before and example_after from sentence
        if pd.notna(sentence) and str(sentence).strip():
            total_with_sentence += 1
            before, matched, after = find_word_in_sentence(kanji, sentence)
            if before is not None:
                auto_generated += 1
                example_before = escape_sql_string(before) if before else "NULL"
                example_after = escape_sql_string(after) if after else "NULL"
            else:
                # Fallback: use original Excel values if pattern matching fails
                example_before = escape_sql_string(row['Supporting word 1'])
                example_after = escape_sql_string(row['Supporting word 2'])
        else:
            # No sentence available, use NULL
            example_before = "NULL"
            example_after = "NULL"
        
        # Page number
        page_no = 'NULL'
        if pd.notna(row['Page no.']):
            try:
                page_no = int(float(row['Page no.']))
            except:
                page_no = 'NULL'
        
        # Schedule (week/day)
        week, day = parse_week_day(row['Lecture'])
        if week and day:
            schedule_id = f"(SELECT id FROM schedule WHERE week = {week} AND day = {day})"
        else:
            schedule_id = "NULL"
        
        # Word type and difficulty
        word_type = escape_sql_string(determine_word_type(row['Raw'], row['Meaning']))
        difficulty = determine_difficulty(row['Raw'])
        
        # Build value tuple
        value = f"""    ({ref_no}, {kanji_sql}, {hiragana}, {meaning},
     {example_before}, {example_after}, {hint}, {sentence_sql},
     {page_no}, {schedule_id}, {word_type}, {difficulty})"""
        
        values_list.append(value)
    
    # Join all values with commas
    sql_lines.append(',\n'.join(values_list))
    sql_lines.append(";")
    sql_lines.append("")
    sql_lines.append("COMMIT;")
    sql_lines.append("")
    sql_lines.append("-- Verify the import")
    sql_lines.append("SELECT 'Total vocabulary entries:' as info, COUNT(*) as count FROM vocabulary;")
    sql_lines.append("SELECT 'Words with auto-generated examples:' as info, COUNT(*) as count FROM vocabulary WHERE example_before IS NOT NULL;")
    sql_lines.append("SELECT 'Words per week:' as info, s.week, COUNT(v.id) as count")
    sql_lines.append("FROM schedule s LEFT JOIN vocabulary v ON v.schedule_id = s.id")
    sql_lines.append("GROUP BY s.week ORDER BY s.week;")
    
    # Write to file
    output_path = Path(__file__).parent / '03_insert_data.sql'
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(sql_lines))
    
    print(f"\nSQL file generated: {output_path}")
    print(f"Total entries: {len(values_list)}")
    print(f"Words with sentences: {total_with_sentence}")
    print(f"Auto-generated examples: {auto_generated} ({100*auto_generated/total_with_sentence:.1f}% success rate)")
    
    # Print summary by week
    print("\n--- Summary by Week ---")
    df['Week'], df['Day'] = zip(*df['Lecture'].apply(parse_week_day))
    week_summary = df.groupby('Week').size()
    for week, count in week_summary.items():
        if week:
            print(f"  Week {int(week)}: {count} words")


if __name__ == "__main__":
    if len(sys.argv) > 1:
        excel_file = sys.argv[1]
    else:
        # Default path for testing
        excel_file = '/mnt/user-data/uploads/N1_goi_word_list_R000.xlsm'
    
    main(excel_file)

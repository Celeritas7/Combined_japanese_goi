#!/usr/bin/env python3
"""
Excel to SQL Converter for JLPT Vocabulary (N1 + N2 + N3)
=========================================================
This script reads Excel files and generates SQL INSERT statements.
It uses FUGASHI (MeCab wrapper) for intelligent sentence splitting.

Features:
- Processes all three levels (N1, N2, N3)
- Auto-generates example_before and example_after from full_sentence
- Handles verb/adjective conjugations using fugashi
- Outputs Supabase-compatible SQL

Usage:
    python 02_excel_to_sql.py
    
    Or with custom paths:
    python 02_excel_to_sql.py --n1 path/to/n1.xlsm --n2 path/to/n2.xlsm --n3 path/to/n3.xlsm

Output:
    Creates 03_insert_data.sql file with all INSERT statements

Requirements:
    pip install pandas openpyxl fugashi unidic-lite
"""

import pandas as pd
import re
import sys
import argparse
from pathlib import Path

# Try to import fugashi for advanced Japanese processing
try:
    import fugashi
    FUGASHI_AVAILABLE = True
    tagger = fugashi.Tagger()
    print("✓ Fugashi loaded successfully")
except ImportError:
    FUGASHI_AVAILABLE = False
    print("⚠ Fugashi not available, using fallback pattern matching")


# =============================================================================
# Japanese Word Pattern Matching
# =============================================================================

def get_dictionary_form(word):
    """
    Use fugashi to get the dictionary form of a conjugated word.
    Returns a list of possible forms (dictionary form + surface forms).
    """
    if not FUGASHI_AVAILABLE:
        return [word]
    
    forms = [word]
    try:
        tokens = tagger(word)
        for token in tokens:
            # Get dictionary form if available
            if hasattr(token, 'feature') and token.feature.lemma:
                forms.append(token.feature.lemma)
            # Also add the surface form
            forms.append(str(token))
    except:
        pass
    
    return list(set(forms))


def get_stem_patterns(kanji):
    """
    Generate possible stems and conjugation patterns for a Japanese word.
    Returns a list of possible patterns to search for in sentences.
    """
    patterns = [kanji]
    
    # Clean the kanji (remove markers like ＊, +, etc.)
    clean_kanji = re.sub(r'[＊\*\+（）\(\)①②③④⑤]', '', kanji).strip()
    if clean_kanji != kanji:
        patterns.append(clean_kanji)
    
    # Use fugashi to get dictionary forms
    if FUGASHI_AVAILABLE:
        patterns.extend(get_dictionary_form(clean_kanji))
    
    # Verb endings (godan and ichidan)
    verb_endings = {
        'る': ['', 'て', 'た', 'ない', 'ます', 'れば', 'よう', 'られる', 'させる', 
               'ている', 'ていた', 'てる', 'てた', 'ず', 'ずに', 'たい', 'たら', 
               'たり', 'ろ', 'れ', 'させ', 'られ', 'なかった', 'ません'],
        'う': ['わ', 'い', 'って', 'った', 'わない', 'います', 'えば', 'おう',
               'わず', 'いたい', 'ったら', 'ったり', 'え', 'わなかった'],
        'く': ['か', 'き', 'いて', 'いた', 'かない', 'きます', 'けば', 'こう',
               'かず', 'きたい', 'いたら', 'いたり', 'け', 'かなかった'],
        'ぐ': ['が', 'ぎ', 'いで', 'いだ', 'がない', 'ぎます', 'げば', 'ごう',
               'がず', 'ぎたい', 'いだら', 'いだり', 'げ', 'がなかった'],
        'す': ['さ', 'し', 'して', 'した', 'さない', 'します', 'せば', 'そう',
               'さず', 'したい', 'したら', 'したり', 'せ', 'さなかった'],
        'つ': ['た', 'ち', 'って', 'った', 'たない', 'ちます', 'てば', 'とう',
               'たず', 'ちたい', 'ったら', 'ったり', 'て', 'たなかった'],
        'ぬ': ['な', 'に', 'んで', 'んだ', 'なない', 'にます', 'ねば', 'のう',
               'なず', 'にたい', 'んだら', 'んだり', 'ね', 'ななかった'],
        'ぶ': ['ば', 'び', 'んで', 'んだ', 'ばない', 'びます', 'べば', 'ぼう',
               'ばず', 'びたい', 'んだら', 'んだり', 'べ', 'ばなかった'],
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
            if stem:
                for conj in conjugations:
                    patterns.append(stem + conj)
                patterns.append(stem)
    
    # Check for い-adjective patterns
    if clean_kanji.endswith('い') and len(clean_kanji) > 1:
        stem = clean_kanji[:-1]
        for ending in i_adj_endings:
            patterns.append(stem + ending)
        patterns.append(stem)
    
    # Check for な-adjective
    if clean_kanji.endswith('な'):
        stem = clean_kanji[:-1]
        patterns.extend([stem, stem + 'な', stem + 'に', stem + 'だ', stem + 'で', 
                        stem + 'だった', stem + 'ではない', stem + 'じゃない'])
    
    if clean_kanji.endswith('(な)') or clean_kanji.endswith('（な）'):
        stem = re.sub(r'[\(（]な[\)）]$', '', clean_kanji)
        patterns.extend([stem, stem + 'な', stem + 'に', stem + 'だ', stem + 'で'])
    
    # For compound words with particles
    for particle in ['が', 'を', 'に', 'で', 'と', 'の']:
        if particle in clean_kanji:
            parts = clean_kanji.split(particle)
            patterns.extend(parts)
            patterns.append(clean_kanji.replace(particle, ''))
    
    # Remove duplicates, prioritize longer patterns
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
    
    sentence = str(sentence).strip()
    kanji = str(kanji).strip()
    
    # Get all possible patterns
    patterns = get_stem_patterns(kanji)
    
    # Sort by length (longest first for accuracy)
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
        return 3
    elif '＊' in raw_str or '*' in raw_str:
        return 2
    elif '+' in raw_str:
        return 2
    return 1


def determine_word_type(raw_word, meaning):
    """Try to determine word type from the word itself."""
    if pd.isna(raw_word):
        return None
    raw_str = str(raw_word)
    
    if '(な)' in raw_str or '（な）' in raw_str:
        return 'な-adjective'
    
    if not pd.isna(meaning):
        meaning_str = str(meaning).lower()
        if meaning_str.startswith('to '):
            return 'verb'
    
    clean_word = re.sub(r'[＊\*\+（）\(\)]', '', raw_str)
    if clean_word.endswith('い') and len(clean_word) > 1:
        return 'い-adjective'
    elif clean_word.endswith('る') or clean_word.endswith('す') or \
         clean_word.endswith('く') or clean_word.endswith('ぐ') or \
         clean_word.endswith('む') or clean_word.endswith('ぶ') or \
         clean_word.endswith('つ') or clean_word.endswith('う'):
        return 'verb'
    
    return None


# =============================================================================
# Excel Processing
# =============================================================================

def process_excel_file(excel_path, level):
    """Process a single Excel file and return vocabulary data."""
    print(f"\nProcessing {level}: {excel_path}")
    
    try:
        xlsx = pd.ExcelFile(excel_path)
        df = pd.read_excel(xlsx, sheet_name='1_raw_data', header=1)
    except Exception as e:
        print(f"  Error reading file: {e}")
        return []
    
    # Filter valid rows
    df = df[df['Sr no'].notna()]
    if 'Kanji' in df.columns:
        df = df[df['Kanji'].notna()]
    
    print(f"  Found {len(df)} entries")
    
    # Statistics
    total_with_sentence = 0
    auto_generated = 0
    
    vocabulary_data = []
    
    for idx, row in df.iterrows():
        # Extract data
        ref_no = int(row['Sr no']) if pd.notna(row['Sr no']) else None
        kanji = str(row['Kanji']) if pd.notna(row.get('Kanji')) else str(row.get('Raw', ''))
        hiragana = row.get('Hiragana', '')
        meaning = row.get('Meaning', '')
        hint = row.get('Hint', '')
        sentence = row.get('Sentence', '')
        
        # Auto-generate example_before and example_after
        example_before = None
        example_after = None
        
        if pd.notna(sentence) and str(sentence).strip():
            total_with_sentence += 1
            before, matched, after = find_word_in_sentence(kanji, sentence)
            if before is not None:
                auto_generated += 1
                example_before = before if before else None
                example_after = after if after else None
            else:
                # Fallback to Excel columns
                example_before = row.get('Supporting word 1', None)
                example_after = row.get('Supporting word 2', None)
        
        # Page number
        page_no = None
        if pd.notna(row.get('Page no.')):
            try:
                page_no = int(float(row['Page no.']))
            except:
                pass
        
        # Schedule (week/day)
        lecture_col = 'Lecture' if 'Lecture' in row else None
        week, day = parse_week_day(row.get(lecture_col, None)) if lecture_col else (None, None)
        
        # Word type and difficulty
        word_type = determine_word_type(row.get('Raw', kanji), meaning)
        difficulty = determine_difficulty(row.get('Raw', kanji))
        
        vocabulary_data.append({
            'level': level,
            'ref_no': ref_no,
            'kanji': kanji,
            'hiragana': hiragana if pd.notna(hiragana) else None,
            'meaning_en': meaning if pd.notna(meaning) else None,
            'example_before': example_before if pd.notna(example_before) else None,
            'example_after': example_after if pd.notna(example_after) else None,
            'hint': hint if pd.notna(hint) else None,
            'full_sentence': sentence if pd.notna(sentence) else None,
            'page_no': page_no,
            'week': week,
            'day': day,
            'word_type': word_type,
            'difficulty_level': difficulty,
        })
    
    if total_with_sentence > 0:
        print(f"  Auto-generated examples: {auto_generated}/{total_with_sentence} ({100*auto_generated/total_with_sentence:.1f}% success)")
    
    return vocabulary_data


def generate_sql(all_vocabulary):
    """Generate SQL INSERT statements for all vocabulary."""
    
    sql_lines = []
    sql_lines.append("-- =====================================================")
    sql_lines.append("-- JLPT Vocabulary Data Import (N1 + N2 + N3)")
    sql_lines.append("-- Generated by 02_excel_to_sql.py")
    sql_lines.append("-- example_before and example_after are AUTO-GENERATED")
    sql_lines.append("-- =====================================================")
    sql_lines.append("")
    sql_lines.append("-- Make sure to run 01_create_schema.sql first!")
    sql_lines.append("")
    sql_lines.append("BEGIN;")
    sql_lines.append("")
    sql_lines.append("-- Insert vocabulary data")
    sql_lines.append("INSERT INTO vocabulary (")
    sql_lines.append("    level, ref_no, kanji, hiragana, meaning_en,")
    sql_lines.append("    example_before, example_after, hint, full_sentence,")
    sql_lines.append("    page_no, schedule_id, word_type, difficulty_level")
    sql_lines.append(") VALUES")
    
    values_list = []
    
    for v in all_vocabulary:
        # Schedule ID lookup
        if v['week'] and v['day']:
            schedule_id = f"(SELECT id FROM schedule WHERE week = {v['week']} AND day = {v['day']})"
        else:
            schedule_id = "NULL"
        
        value = f"""    ({escape_sql_string(v['level'])}, {v['ref_no'] or 'NULL'}, {escape_sql_string(v['kanji'])}, {escape_sql_string(v['hiragana'])}, {escape_sql_string(v['meaning_en'])},
     {escape_sql_string(v['example_before'])}, {escape_sql_string(v['example_after'])}, {escape_sql_string(v['hint'])}, {escape_sql_string(v['full_sentence'])},
     {v['page_no'] or 'NULL'}, {schedule_id}, {escape_sql_string(v['word_type'])}, {v['difficulty_level']})"""
        
        values_list.append(value)
    
    sql_lines.append(',\n'.join(values_list))
    sql_lines.append(";")
    sql_lines.append("")
    sql_lines.append("COMMIT;")
    sql_lines.append("")
    sql_lines.append("-- Verify the import")
    sql_lines.append("SELECT level, COUNT(*) as count FROM vocabulary GROUP BY level ORDER BY level;")
    sql_lines.append("SELECT 'Total:' as level, COUNT(*) as count FROM vocabulary;")
    
    return '\n'.join(sql_lines)


# =============================================================================
# Main Function
# =============================================================================

def main():
    parser = argparse.ArgumentParser(description='Convert JLPT Excel files to SQL')
    parser.add_argument('--n1', default='N1_goi_word_list_R000.xlsm', help='Path to N1 Excel file')
    parser.add_argument('--n2', default='N2_goi_word_list_R005.xlsm', help='Path to N2 Excel file')
    parser.add_argument('--n3', default='N3_goi_word_list_R001.xlsm', help='Path to N3 Excel file')
    parser.add_argument('--output', default='03_insert_data.sql', help='Output SQL file')
    args = parser.parse_args()
    
    print("=" * 60)
    print("JLPT Vocabulary Excel to SQL Converter")
    print("=" * 60)
    
    all_vocabulary = []
    
    # Process each level
    files = [
        (args.n1, 'N1'),
        (args.n2, 'N2'),
        (args.n3, 'N3'),
    ]
    
    for file_path, level in files:
        if Path(file_path).exists():
            data = process_excel_file(file_path, level)
            all_vocabulary.extend(data)
        else:
            print(f"\n⚠ File not found: {file_path}")
    
    if not all_vocabulary:
        print("\n❌ No vocabulary data found!")
        return
    
    print("\n" + "=" * 60)
    print(f"Total vocabulary entries: {len(all_vocabulary)}")
    print("=" * 60)
    
    # Generate SQL
    sql_content = generate_sql(all_vocabulary)
    
    # Write to file
    output_path = Path(args.output)
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(sql_content)
    
    print(f"\n✓ SQL file generated: {output_path}")
    print(f"  Total entries: {len(all_vocabulary)}")
    
    # Summary by level
    print("\n--- Summary by Level ---")
    level_counts = {}
    for v in all_vocabulary:
        level_counts[v['level']] = level_counts.get(v['level'], 0) + 1
    
    for level in sorted(level_counts.keys()):
        print(f"  {level}: {level_counts[level]} words")


if __name__ == "__main__":
    main()

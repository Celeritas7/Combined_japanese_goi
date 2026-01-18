# JLPT Vocabulary Database - Complete Setup Guide

## 📋 Overview

This guide will help you set up a complete JLPT vocabulary database (N1 + N2 + N3) with:
- **Supabase** as the cloud database
- **Python + Fugashi** for intelligent sentence splitting
- **Web App** for studying

---

## 📁 Files You'll Create

| File | Purpose |
|------|---------|
| `01_create_schema.sql` | Creates database tables in Supabase |
| `02_excel_to_sql.py` | Python script to convert Excel → SQL |
| `03_insert_data.sql` | Generated SQL with all vocabulary data |
| `04_useful_queries.sql` | Study/admin queries |
| `index.html` | Web app for studying |

---

## 🗂️ Database Structure

```
┌─────────────────────────────────────────────────────────────────┐
│                         SUPABASE                                 │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                    schedule                                 │ │
│  │  id | week | day | week_day_label                          │ │
│  │  1  | 1    | 1   | 1週1日                                   │ │
│  │  2  | 1    | 2   | 1週2日                                   │ │
│  │  ...                                                        │ │
│  └────────────────────────────────────────────────────────────┘ │
│                           │                                      │
│                           │ 1:many                               │
│                           ▼                                      │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                   vocabulary                                │ │
│  │  id | level | kanji | hiragana | meaning | example_before  │ │
│  │     | example_after | hint | full_sentence | page_no       │ │
│  │     | schedule_id | word_type | difficulty_level           │ │
│  │                                                             │ │
│  │  N1: 1545 words                                            │ │
│  │  N2: 1359 words                                            │ │
│  │  N3: 1254 words                                            │ │
│  │  Total: 4158 words                                         │ │
│  └────────────────────────────────────────────────────────────┘ │
│                           │                                      │
│                           │ 1:many                               │
│                           ▼                                      │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                  user_markings                              │ │
│  │  id | user_id | word_id | marking | updated_at             │ │
│  │                                                             │ │
│  │  Marking values:                                           │ │
│  │  0 = Not marked                                            │ │
│  │  1 = Monthly Review (✓)                                    │ │
│  │  2 = Can't use in conversation (💬)                        │ │
│  │  3 = Can't write (✍)                                       │ │
│  │  4 = Understand but can't use (🤔)                         │ │
│  │  5 = Don't know at all (❌)                                 │ │
│  └────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🚀 Step-by-Step Setup

### Step 1: Install Python Dependencies

```bash
# Create a virtual environment (optional but recommended)
python -m venv jlpt_env
source jlpt_env/bin/activate  # On Windows: jlpt_env\Scripts\activate

# Install required packages
pip install pandas openpyxl fugashi unidic-lite
```

**Why these packages?**
| Package | Purpose |
|---------|---------|
| pandas | Read Excel files |
| openpyxl | Excel file support |
| fugashi | Japanese morphological analysis (MeCab wrapper) |
| unidic-lite | Japanese dictionary for fugashi |

---

### Step 2: Create Supabase Project

1. Go to https://supabase.com/
2. Create a new project
3. Note your:
   - **Project URL**: `https://xxxxx.supabase.co`
   - **Anon Key**: `eyJhbGci...`

---

### Step 3: Run Schema SQL in Supabase

1. Go to **Supabase Dashboard** → **SQL Editor**
2. Copy and paste the contents of `01_create_schema.sql`
3. Click **Run**

You should see: `Schema created successfully!`

---

### Step 4: Run Python Script to Generate SQL

```bash
python 02_excel_to_sql.py
```

This will:
1. Read all three Excel files (N1, N2, N3)
2. Use **fugashi** to intelligently split sentences into `example_before` and `example_after`
3. Generate `03_insert_data.sql`

**Expected output:**
```
Processing N1: N1_goi_word_list_R000.xlsm
  Found 1545 entries
  Auto-generated examples: 595/595 (100.0% success)

Processing N2: N2_goi_word_list_R005.xlsm
  Found 1359 entries
  Auto-generated examples: 480/480 (100.0% success)

Processing N3: N3_goi_word_list_R001.xlsm
  Found 1254 entries
  Auto-generated examples: 420/420 (100.0% success)

Total: 4158 vocabulary entries
SQL file generated: 03_insert_data.sql
```

---

### Step 5: Import Data to Supabase

1. Go to **Supabase Dashboard** → **SQL Editor**
2. Copy and paste the contents of `03_insert_data.sql`
3. Click **Run**

⚠️ **Note**: If the file is too large, split it into chunks or use the Supabase CLI.

---

### Step 6: Verify the Import

Run these queries in Supabase SQL Editor:

```sql
-- Check total words
SELECT level, COUNT(*) as count 
FROM vocabulary 
GROUP BY level;

-- Check schedule
SELECT * FROM schedule LIMIT 10;

-- Sample vocabulary
SELECT id, level, kanji, hiragana, meaning_en 
FROM vocabulary 
LIMIT 10;
```

---

### Step 7: Deploy the Web App

1. Upload `index.html` to GitHub
2. Enable GitHub Pages
3. Your app is live!

---

## 📊 How Sentence Splitting Works

### The Challenge

Given:
- `full_sentence` = "彼女はいつも愛想がいい人です。"
- `kanji` = "愛想がいい"

We need to extract:
- `example_before` = "彼女はいつも"
- `example_after` = "人です。"

### The Solution: Fugashi + Pattern Matching

```python
# Simple example
sentence = "彼女はいつも愛想がいい人です。"
kanji = "愛想がいい"

# Direct match works!
idx = sentence.index(kanji)
before = sentence[:idx]      # "彼女はいつも"
after = sentence[idx+len(kanji):]  # "人です。"
```

### Handling Conjugations

The tricky part is when the word is conjugated:

| Dictionary Form | In Sentence | Solution |
|-----------------|-------------|----------|
| 食べる (to eat) | 食べている | Match stem "食べ" |
| 呆れる (to be amazed) | 呆れて | Match stem "呆れ" |
| 美しい (beautiful) | 美しく | Match stem "美し" |

**Fugashi helps** by identifying the dictionary form of conjugated words.

---

## 🔧 Updating Markings via CSV

### Export Current Markings

```sql
-- In Supabase SQL Editor
SELECT user_id, word_id, marking, updated_at
FROM user_markings
WHERE user_id = 'your-user-id'
ORDER BY word_id;
```

### Prepare CSV for Import

```csv
user_id,word_id,marking,updated_at
8f12xxxx,1,1,2026-01-18
8f12xxxx,2,5,2026-01-18
8f12xxxx,3,2,2026-01-18
```

### Import via Supabase Dashboard

1. **Table Editor** → `user_markings`
2. **Insert** → **Import data from CSV**
3. Upload your CSV file
4. Enable **"Upsert"**
5. Conflict target: `user_id, word_id`
6. **Confirm**

---

## 📝 Useful SQL Queries

### Get Words for Specific Level and Week

```sql
SELECT v.kanji, v.hiragana, v.meaning_en, s.week_day_label
FROM vocabulary v
JOIN schedule s ON v.schedule_id = s.id
WHERE v.level = 'N1' AND s.week = 1
ORDER BY s.day, v.id;
```

### Get Your Marked Words

```sql
SELECT v.level, v.kanji, v.hiragana, v.meaning_en, um.marking
FROM vocabulary v
JOIN user_markings um ON v.id = um.word_id
WHERE um.user_id = 'your-user-id'
  AND um.marking > 0
ORDER BY um.marking DESC;
```

### Progress by Level

```sql
SELECT 
    v.level,
    COUNT(*) as total_words,
    COUNT(um.id) as marked_words,
    ROUND(100.0 * COUNT(um.id) / COUNT(*), 1) as percent_done
FROM vocabulary v
LEFT JOIN user_markings um ON v.id = um.word_id AND um.user_id = 'your-user-id'
GROUP BY v.level
ORDER BY v.level;
```

### Words Due for Review

```sql
SELECT v.kanji, v.hiragana, v.meaning_en, um.marking, um.updated_at
FROM vocabulary v
JOIN user_markings um ON v.id = um.word_id
WHERE um.user_id = 'your-user-id'
  AND um.marking >= 3  -- Difficult words
  AND um.updated_at < NOW() - INTERVAL '3 days'
ORDER BY um.updated_at;
```

---

## 🎯 Marking System Explained

| Value | Icon | Meaning | When to Use |
|-------|------|---------|-------------|
| 0 | ○ | Not marked | Default state |
| 1 | ✓ | Monthly Review | Know it well, just periodic check |
| 2 | 💬 | Can't use in conversation | Understand but can't speak |
| 3 | ✍ | Can't write | Know meaning but can't write kanji |
| 4 | 🤔 | Understand but can't use | Know it passively, not actively |
| 5 | ❌ | Don't know at all | Need to learn from scratch |

---

## 🔄 Workflow Summary

```
┌──────────────────┐
│  Excel Files     │
│  N1, N2, N3      │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│  Python Script   │
│  02_excel_to_sql │
│  (uses fugashi)  │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│  SQL File        │
│  03_insert_data  │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│  Supabase        │
│  Cloud Database  │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│  Web App         │
│  index.html      │
│  (GitHub Pages)  │
└──────────────────┘
```

---

## ❓ Troubleshooting

### "fugashi not found"
```bash
pip install fugashi unidic-lite
```

### "No module named 'unidic_lite'"
```bash
pip install unidic-lite
```

### Japanese characters showing as "???"
- Make sure your terminal supports UTF-8
- On Windows: `chcp 65001`

### Supabase connection errors
- Check your Project URL and Anon Key
- Make sure Row Level Security policies are set correctly

---

## 📈 Data Summary

| Level | Words | With Sentences |
|-------|-------|----------------|
| N1 | 1545 | 595 |
| N2 | 1359 | ~480 |
| N3 | 1254 | ~420 |
| **Total** | **4158** | **~1495** |

---

頑張ってください！ 🎌

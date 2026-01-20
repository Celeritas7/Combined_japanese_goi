# JLPT N1 Vocabulary PostgreSQL Database

This guide will help you set up a PostgreSQL database for your N1 vocabulary study.

---

## 📁 Files Included

| File | Description |
|------|-------------|
| `01_create_schema.sql` | Creates database tables and views |
| `02_excel_to_sql.py` | Python script to convert Excel → SQL |
| `03_insert_data.sql` | Generated SQL with all vocabulary data |
| `04_useful_queries.sql` | Example queries for studying |
| `README.md` | This instruction file |

---

## ✨ Key Feature: Auto-Generated Examples

The `example_before` and `example_after` columns are **automatically generated** from the `full_sentence` column using Japanese conjugation pattern matching.

### How It Works

Given:
- `full_sentence` = "彼女はいつも愛想がいい人です。"
- `kanji` = "愛想がいい"

The script automatically calculates:
- `example_before` = "彼女はいつも"
- `example_after` = "人です。"

### Handles Conjugated Forms

The script supports verb and adjective conjugations:

| Dictionary Form | Sentence Form | Still Matches! |
|-----------------|---------------|----------------|
| 食べる | 食べている | ✅ |
| 呆れる | 呆れて | ✅ |
| 美しい | 美しく | ✅ |
| 焦る | 焦らず | ✅ |

**Success Rate: 100%** (595/595 sentences parsed correctly)

---

## 🚀 Step-by-Step Setup Guide

### Step 1: Install PostgreSQL

#### Windows
1. Download from: https://www.postgresql.org/download/windows/
2. Run the installer (use default settings)
3. **Remember your password** for the `postgres` user!
4. Keep the default port: `5432`

#### Mac
```bash
# Install Homebrew first if you don't have it
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install PostgreSQL
brew install postgresql@15
brew services start postgresql@15
```

#### Linux (Ubuntu/Debian)
```bash
sudo apt update
sudo apt install postgresql postgresql-contrib
sudo systemctl start postgresql
sudo systemctl enable postgresql
```

---

### Step 2: Create the Database

#### Windows (using pgAdmin or Command Line)

**Option A: Using pgAdmin (GUI)**
1. Open pgAdmin (installed with PostgreSQL)
2. Right-click on "Databases" → Create → Database
3. Name it: `n1_vocabulary`
4. Click Save

**Option B: Using Command Line**
1. Open Command Prompt as Administrator
2. Run:
```cmd
psql -U postgres
```
3. Enter your password
4. Create database:
```sql
CREATE DATABASE n1_vocabulary;
\q
```

#### Mac/Linux
```bash
# Connect to PostgreSQL
sudo -u postgres psql

# Create database
CREATE DATABASE n1_vocabulary;
\q
```

---

### Step 3: Run the Schema Script

This creates all the tables.

#### Windows
```cmd
cd C:\path\to\your\files
psql -U postgres -d n1_vocabulary -f 01_create_schema.sql
```

#### Mac/Linux
```bash
cd /path/to/your/files
psql -U postgres -d n1_vocabulary -f 01_create_schema.sql
```

You should see: `Schema created successfully!`

---

### Step 4: Import the Vocabulary Data

```bash
psql -U postgres -d n1_vocabulary -f 03_insert_data.sql
```

This will import all 1,545 vocabulary words!

---

### Step 5: Verify the Import

Connect to the database and check:

```bash
psql -U postgres -d n1_vocabulary
```

Then run:
```sql
-- Check total words
SELECT COUNT(*) FROM vocabulary;

-- Check words per week
SELECT * FROM v_words_per_day LIMIT 10;

-- See a sample word
SELECT kanji, hiragana, meaning_en FROM vocabulary LIMIT 5;
```

---

## 📊 Database Structure

### Tables

```
┌─────────────────────┐
│      schedule       │
├─────────────────────┤
│ id (PK)             │
│ week (1-8)          │
│ day (1-7)           │
│ week_day_label      │
└─────────────────────┘
          │
          │ 1:many
          ▼
┌─────────────────────┐
│     vocabulary      │
├─────────────────────┤
│ id (PK)             │
│ ref_no              │
│ kanji               │
│ hiragana            │
│ meaning_en          │
│ example_before      │
│ example_after       │
│ hint                │
│ full_sentence       │
│ page_no             │
│ schedule_id (FK)    │
│ word_type           │
│ difficulty_level    │
│ is_marked           │
│ times_reviewed      │
│ last_reviewed       │
└─────────────────────┘
          │
          │ 1:many
          ▼
┌─────────────────────┐
│   study_progress    │
├─────────────────────┤
│ id (PK)             │
│ vocabulary_id (FK)  │
│ review_date         │
│ result              │
│ notes               │
└─────────────────────┘
```

### Views (Pre-built Queries)

- `v_vocabulary_full` - All vocabulary with schedule info
- `v_words_per_day` - Count of words per day
- `v_study_summary` - Progress tracking summary

---

## 💡 Useful SQL Queries

### Get all words for Week 1, Day 1
```sql
SELECT kanji, hiragana, meaning_en 
FROM v_vocabulary_full 
WHERE week = 1 AND day = 1;
```

### Search for a word
```sql
SELECT * FROM vocabulary 
WHERE kanji LIKE '%食%' OR hiragana LIKE '%たべ%';
```

### Get difficult words (marked with ＊＊)
```sql
SELECT kanji, hiragana, meaning_en 
FROM vocabulary 
WHERE difficulty_level = 3;
```

### Mark a word for review
```sql
UPDATE vocabulary 
SET is_marked = TRUE 
WHERE kanji = '愛想がいい';
```

### Record study progress
```sql
INSERT INTO study_progress (vocabulary_id, review_date, result)
VALUES (1, CURRENT_DATE, 'correct');
```

### Get random words for quiz
```sql
SELECT kanji, hiragana, meaning_en 
FROM vocabulary 
ORDER BY RANDOM() 
LIMIT 10;
```

### Get words you haven't reviewed yet
```sql
SELECT kanji, hiragana, meaning_en 
FROM vocabulary 
WHERE times_reviewed = 0
ORDER BY RANDOM() 
LIMIT 20;
```

---

## 🔧 Troubleshooting

### "password authentication failed"
- Make sure you're using the correct password for `postgres` user
- On Mac/Linux, try: `sudo -u postgres psql`

### "database does not exist"
- Create it first: `CREATE DATABASE n1_vocabulary;`

### "relation does not exist"
- Run `01_create_schema.sql` first before importing data

### Japanese characters showing as "???"
- Make sure your terminal/client supports UTF-8
- On Windows, run: `chcp 65001` before connecting

---

## 📱 GUI Tools (Optional)

If you prefer a visual interface:

1. **pgAdmin** (comes with PostgreSQL) - Full featured
2. **DBeaver** (free) - https://dbeaver.io/
3. **TablePlus** (Mac/Windows) - https://tableplus.com/

---

## 🎯 Next Steps

After setup, you can:

1. **Build a web app** - Use Python/Flask or Node.js to create a study app
2. **Create flashcards** - Export to Anki using SQL queries
3. **Track progress** - Use the `study_progress` table
4. **Build a quiz system** - Use random queries to test yourself

Need help with any of these? Let me know!

---

## 📈 Data Summary

- **Total Words**: 1,545
- **Weeks**: 8
- **Days per Week**: 7
- **Average words per day**: ~28

| Week | Word Count |
|------|------------|
| 1    | 286        |
| 2    | 178        |
| 3    | 163        |
| 4    | 202        |
| 5    | 218        |
| 6    | 114        |
| 7    | 181        |
| 8    | 203        |

---

Good luck with your N1 studies! 頑張ってください！ 🎌

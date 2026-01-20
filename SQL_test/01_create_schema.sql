-- =====================================================
-- JLPT N1 Vocabulary Database Schema
-- =====================================================
-- Run this file first to create the database structure
-- Command: psql -U postgres -f 01_create_schema.sql
-- =====================================================

-- Create the database (run this separately if needed)
-- CREATE DATABASE n1_vocabulary;

-- Connect to the database
-- \c n1_vocabulary

-- =====================================================
-- Table 1: schedule (週/日 - Week/Day schedule)
-- =====================================================
DROP TABLE IF EXISTS vocabulary CASCADE;
DROP TABLE IF EXISTS schedule CASCADE;

CREATE TABLE schedule (
    id SERIAL PRIMARY KEY,
    week INTEGER NOT NULL,           -- Week number (1-8)
    day INTEGER NOT NULL,            -- Day number (1-7)
    week_day_label VARCHAR(20),      -- Label like "1週1日"
    UNIQUE(week, day)
);

-- Insert schedule data (8 weeks × 7 days = 56 entries)
INSERT INTO schedule (week, day, week_day_label) VALUES
(1, 1, '1週1日'), (1, 2, '1週2日'), (1, 3, '1週3日'), (1, 4, '1週4日'),
(1, 5, '1週5日'), (1, 6, '1週6日'), (1, 7, '1週7日'),
(2, 1, '2週1日'), (2, 2, '2週2日'), (2, 3, '2週3日'), (2, 4, '2週4日'),
(2, 5, '2週5日'), (2, 6, '2週6日'), (2, 7, '2週7日'),
(3, 1, '3週1日'), (3, 2, '3週2日'), (3, 3, '3週3日'), (3, 4, '3週4日'),
(3, 5, '3週5日'), (3, 6, '3週6日'), (3, 7, '3週7日'),
(4, 1, '4週1日'), (4, 2, '4週2日'), (4, 3, '4週3日'), (4, 4, '4週4日'),
(4, 5, '4週5日'), (4, 6, '4週6日'), (4, 7, '4週7日'),
(5, 1, '5週1日'), (5, 2, '5週2日'), (5, 3, '5週3日'), (5, 4, '5週4日'),
(5, 5, '5週5日'), (5, 6, '5週6日'), (5, 7, '5週7日'),
(6, 1, '6週1日'), (6, 2, '6週2日'), (6, 3, '6週3日'), (6, 4, '6週4日'),
(6, 5, '6週5日'), (6, 6, '6週6日'), (6, 7, '6週7日'),
(7, 1, '7週1日'), (7, 2, '7週2日'), (7, 3, '7週3日'), (7, 4, '7週4日'),
(7, 5, '7週5日'), (7, 6, '7週6日'), (7, 7, '7週7日'),
(8, 1, '8週1日'), (8, 2, '8週2日'), (8, 3, '8週3日'), (8, 4, '8週4日'),
(8, 5, '8週5日'), (8, 6, '8週6日'), (8, 7, '8週7日');

-- =====================================================
-- Table 2: vocabulary (Main vocabulary table)
-- =====================================================
CREATE TABLE vocabulary (
    id SERIAL PRIMARY KEY,
    ref_no INTEGER,                          -- Original reference number from Excel
    kanji VARCHAR(100) NOT NULL,             -- The vocabulary word in kanji
    hiragana VARCHAR(100),                   -- Reading in hiragana
    meaning_en TEXT,                         -- English meaning
    example_before TEXT,                     -- Supporting word 1 (context before)
    example_after TEXT,                      -- Supporting word 2 (context after)
    hint TEXT,                               -- Hint/explanation
    full_sentence TEXT,                      -- Complete example sentence
    page_no INTEGER,                         -- Page number in textbook
    schedule_id INTEGER REFERENCES schedule(id),  -- Foreign key to schedule
    word_type VARCHAR(20),                   -- Type: い-adj, な-adj, verb, noun, etc.
    difficulty_level INTEGER DEFAULT 1,      -- 1=normal, 2=marked with ＊, 3=marked with ＊＊
    is_marked BOOLEAN DEFAULT FALSE,         -- For user's study tracking
    times_reviewed INTEGER DEFAULT 0,        -- How many times reviewed
    last_reviewed TIMESTAMP,                 -- When last reviewed
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- Table 3: study_progress (Track user's learning)
-- =====================================================
CREATE TABLE study_progress (
    id SERIAL PRIMARY KEY,
    vocabulary_id INTEGER REFERENCES vocabulary(id),
    review_date DATE NOT NULL,
    result VARCHAR(20),                      -- 'correct', 'incorrect', 'partial'
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- Indexes for better query performance
-- =====================================================
CREATE INDEX idx_vocabulary_kanji ON vocabulary(kanji);
CREATE INDEX idx_vocabulary_hiragana ON vocabulary(hiragana);
CREATE INDEX idx_vocabulary_schedule ON vocabulary(schedule_id);
CREATE INDEX idx_vocabulary_page ON vocabulary(page_no);
CREATE INDEX idx_vocabulary_marked ON vocabulary(is_marked);
CREATE INDEX idx_progress_vocab ON study_progress(vocabulary_id);
CREATE INDEX idx_progress_date ON study_progress(review_date);

-- =====================================================
-- Useful Views
-- =====================================================

-- View: vocabulary with schedule info
CREATE VIEW v_vocabulary_full AS
SELECT 
    v.id,
    v.ref_no,
    v.kanji,
    v.hiragana,
    v.meaning_en,
    v.example_before,
    v.example_after,
    v.full_sentence,
    v.hint,
    v.page_no,
    v.word_type,
    v.difficulty_level,
    v.is_marked,
    v.times_reviewed,
    v.last_reviewed,
    s.week,
    s.day,
    s.week_day_label
FROM vocabulary v
LEFT JOIN schedule s ON v.schedule_id = s.id;

-- View: words per day count
CREATE VIEW v_words_per_day AS
SELECT 
    s.week_day_label,
    s.week,
    s.day,
    COUNT(v.id) as word_count
FROM schedule s
LEFT JOIN vocabulary v ON v.schedule_id = s.id
GROUP BY s.id, s.week_day_label, s.week, s.day
ORDER BY s.week, s.day;

-- View: study progress summary
CREATE VIEW v_study_summary AS
SELECT 
    s.week_day_label,
    COUNT(v.id) as total_words,
    SUM(CASE WHEN v.is_marked THEN 1 ELSE 0 END) as marked_words,
    SUM(CASE WHEN v.times_reviewed > 0 THEN 1 ELSE 0 END) as reviewed_words
FROM schedule s
LEFT JOIN vocabulary v ON v.schedule_id = s.id
GROUP BY s.id, s.week_day_label, s.week, s.day
ORDER BY s.week, s.day;

COMMENT ON TABLE vocabulary IS 'JLPT N1 vocabulary words with example sentences and meanings';
COMMENT ON TABLE schedule IS 'Study schedule organized by week and day';
COMMENT ON TABLE study_progress IS 'Track review history for spaced repetition';

SELECT 'Schema created successfully!' as status;

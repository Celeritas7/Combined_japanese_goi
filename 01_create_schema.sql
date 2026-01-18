-- =====================================================
-- JLPT Vocabulary Database Schema (N1 + N2 + N3)
-- =====================================================
-- For Supabase
-- Run this first to create the database structure
-- =====================================================

-- =====================================================
-- Table 1: schedule (週/日 - Week/Day schedule)
-- =====================================================
DROP TABLE IF EXISTS user_markings CASCADE;
DROP TABLE IF EXISTS vocabulary CASCADE;
DROP TABLE IF EXISTS schedule CASCADE;

CREATE TABLE schedule (
    id SERIAL PRIMARY KEY,
    week INTEGER NOT NULL,
    day INTEGER NOT NULL,
    week_day_label VARCHAR(20),
    UNIQUE(week, day)
);

-- Insert schedule data (11 weeks × 7 days = 77 entries to cover all levels)
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
(8, 5, '8週5日'), (8, 6, '8週6日'), (8, 7, '8週7日'),
(9, 1, '9週1日'), (9, 2, '9週2日'), (9, 3, '9週3日'), (9, 4, '9週4日'),
(9, 5, '9週5日'), (9, 6, '9週6日'), (9, 7, '9週7日'),
(10, 1, '10週1日'), (10, 2, '10週2日'), (10, 3, '10週3日'), (10, 4, '10週4日'),
(10, 5, '10週5日'), (10, 6, '10週6日'), (10, 7, '10週7日'),
(11, 1, '11週1日'), (11, 2, '11週2日'), (11, 3, '11週3日'), (11, 4, '11週4日'),
(11, 5, '11週5日'), (11, 6, '11週6日'), (11, 7, '11週7日');

-- =====================================================
-- Table 2: vocabulary (Main vocabulary table)
-- =====================================================
CREATE TABLE vocabulary (
    id SERIAL PRIMARY KEY,
    level VARCHAR(5) NOT NULL,               -- 'N1', 'N2', 'N3'
    ref_no INTEGER,                          -- Original reference number from Excel
    kanji VARCHAR(100) NOT NULL,             -- The vocabulary word in kanji
    hiragana VARCHAR(100),                   -- Reading in hiragana
    meaning_en TEXT,                         -- English meaning
    example_before TEXT,                     -- Supporting word 1 (context before)
    example_after TEXT,                      -- Supporting word 2 (context after)
    hint TEXT,                               -- Hint/explanation
    full_sentence TEXT,                      -- Complete example sentence
    page_no INTEGER,                         -- Page number in textbook
    schedule_id INTEGER REFERENCES schedule(id),
    word_type VARCHAR(20),                   -- Type: い-adj, な-adj, verb, noun
    difficulty_level INTEGER DEFAULT 1,      -- 1=normal, 2=＊, 3=＊＊
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- Table 3: user_markings (Track user's learning progress)
-- =====================================================
CREATE TABLE user_markings (
    id SERIAL PRIMARY KEY,
    user_id TEXT NOT NULL,                   -- Google Auth user ID
    word_id INTEGER NOT NULL REFERENCES vocabulary(id),
    marking INTEGER DEFAULT 0,               -- 0-5 marking scale
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, word_id)
);

-- =====================================================
-- Indexes for better query performance
-- =====================================================
CREATE INDEX idx_vocabulary_level ON vocabulary(level);
CREATE INDEX idx_vocabulary_kanji ON vocabulary(kanji);
CREATE INDEX idx_vocabulary_hiragana ON vocabulary(hiragana);
CREATE INDEX idx_vocabulary_schedule ON vocabulary(schedule_id);
CREATE INDEX idx_vocabulary_page ON vocabulary(page_no);
CREATE INDEX idx_markings_user ON user_markings(user_id);
CREATE INDEX idx_markings_word ON user_markings(word_id);

-- =====================================================
-- Row Level Security (RLS) for Supabase
-- =====================================================
ALTER TABLE schedule ENABLE ROW LEVEL SECURITY;
ALTER TABLE vocabulary ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_markings ENABLE ROW LEVEL SECURITY;

-- Allow anyone to read schedule and vocabulary
CREATE POLICY "Allow public read schedule" ON schedule 
    FOR SELECT USING (true);

CREATE POLICY "Allow public read vocabulary" ON vocabulary 
    FOR SELECT USING (true);

-- Allow authenticated users to manage their own markings
CREATE POLICY "Allow users to read own markings" ON user_markings 
    FOR SELECT USING (auth.uid()::text = user_id);

CREATE POLICY "Allow users to insert own markings" ON user_markings 
    FOR INSERT WITH CHECK (auth.uid()::text = user_id);

CREATE POLICY "Allow users to update own markings" ON user_markings 
    FOR UPDATE USING (auth.uid()::text = user_id);

CREATE POLICY "Allow users to delete own markings" ON user_markings 
    FOR DELETE USING (auth.uid()::text = user_id);

-- =====================================================
-- Useful Views
-- =====================================================

-- View: vocabulary with schedule info
CREATE OR REPLACE VIEW v_vocabulary_full AS
SELECT 
    v.id,
    v.level,
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
    s.week,
    s.day,
    s.week_day_label
FROM vocabulary v
LEFT JOIN schedule s ON v.schedule_id = s.id;

-- View: words count per level
CREATE OR REPLACE VIEW v_level_summary AS
SELECT 
    level,
    COUNT(*) as total_words,
    COUNT(CASE WHEN full_sentence IS NOT NULL THEN 1 END) as words_with_sentences
FROM vocabulary
GROUP BY level
ORDER BY level;

-- View: words per day per level
CREATE OR REPLACE VIEW v_words_per_day AS
SELECT 
    v.level,
    s.week_day_label,
    s.week,
    s.day,
    COUNT(v.id) as word_count
FROM schedule s
LEFT JOIN vocabulary v ON v.schedule_id = s.id
WHERE v.id IS NOT NULL
GROUP BY v.level, s.id, s.week_day_label, s.week, s.day
ORDER BY v.level, s.week, s.day;

-- =====================================================
-- Comments
-- =====================================================
COMMENT ON TABLE vocabulary IS 'JLPT N1/N2/N3 vocabulary words with example sentences';
COMMENT ON TABLE schedule IS 'Study schedule organized by week and day';
COMMENT ON TABLE user_markings IS 'User progress tracking with 0-5 marking scale';
COMMENT ON COLUMN user_markings.marking IS '0=Not marked, 1=Monthly Review, 2=Cant use in conversation, 3=Cant write, 4=Understand but cant use, 5=Dont know';

SELECT 'Schema created successfully!' as status;
SELECT 'Schedule entries:' as info, COUNT(*) as count FROM schedule;

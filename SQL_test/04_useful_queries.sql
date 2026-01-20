-- =====================================================
-- JLPT N1 Vocabulary - Useful Study Queries
-- =====================================================
-- Save this file and run queries as needed
-- Connect: psql -U postgres -d n1_vocabulary
-- =====================================================

-- =====================================================
-- BASIC QUERIES
-- =====================================================

-- 1. Count total vocabulary
SELECT COUNT(*) as total_words FROM vocabulary;

-- 2. Get all words for a specific day
SELECT 
    kanji,
    hiragana,
    meaning_en,
    example_before || kanji || example_after as example
FROM v_vocabulary_full
WHERE week = 1 AND day = 1
ORDER BY ref_no;

-- 3. Search by kanji
SELECT kanji, hiragana, meaning_en, full_sentence
FROM vocabulary
WHERE kanji LIKE '%食%';

-- 4. Search by hiragana/reading
SELECT kanji, hiragana, meaning_en
FROM vocabulary
WHERE hiragana LIKE '%たべ%';

-- 5. Search by English meaning
SELECT kanji, hiragana, meaning_en
FROM vocabulary
WHERE meaning_en ILIKE '%eat%' OR meaning_en ILIKE '%food%';

-- =====================================================
-- STUDY MODE QUERIES
-- =====================================================

-- 6. Get random 10 words for quick quiz
SELECT kanji, hiragana, meaning_en
FROM vocabulary
ORDER BY RANDOM()
LIMIT 10;

-- 7. Get random words from specific week
SELECT kanji, hiragana, meaning_en
FROM v_vocabulary_full
WHERE week = 1
ORDER BY RANDOM()
LIMIT 10;

-- 8. Get difficult words only (＊＊ marked)
SELECT kanji, hiragana, meaning_en, hint
FROM vocabulary
WHERE difficulty_level = 3
ORDER BY RANDOM()
LIMIT 10;

-- 9. Get words you haven't reviewed yet
SELECT kanji, hiragana, meaning_en
FROM vocabulary
WHERE times_reviewed = 0
ORDER BY RANDOM()
LIMIT 20;

-- 10. Get words you marked for review
SELECT kanji, hiragana, meaning_en, hint
FROM vocabulary
WHERE is_marked = TRUE;

-- =====================================================
-- PROGRESS TRACKING
-- =====================================================

-- 11. Mark a word for special attention
UPDATE vocabulary
SET is_marked = TRUE
WHERE kanji = '愛想がいい';

-- 12. Unmark a word
UPDATE vocabulary
SET is_marked = FALSE
WHERE kanji = '愛想がいい';

-- 13. Record that you reviewed a word
UPDATE vocabulary
SET 
    times_reviewed = times_reviewed + 1,
    last_reviewed = NOW()
WHERE id = 1;

-- 14. Record detailed study progress
INSERT INTO study_progress (vocabulary_id, review_date, result, notes)
VALUES (1, CURRENT_DATE, 'correct', 'Got it on first try');

-- 15. Get your study history for a word
SELECT 
    v.kanji,
    sp.review_date,
    sp.result,
    sp.notes
FROM study_progress sp
JOIN vocabulary v ON v.id = sp.vocabulary_id
WHERE v.kanji = '愛想がいい'
ORDER BY sp.review_date DESC;

-- =====================================================
-- STATISTICS & SUMMARIES
-- =====================================================

-- 16. Words per week summary
SELECT 
    s.week,
    COUNT(v.id) as total_words,
    SUM(CASE WHEN v.times_reviewed > 0 THEN 1 ELSE 0 END) as reviewed,
    ROUND(100.0 * SUM(CASE WHEN v.times_reviewed > 0 THEN 1 ELSE 0 END) / COUNT(v.id), 1) as percent_done
FROM schedule s
LEFT JOIN vocabulary v ON v.schedule_id = s.id
GROUP BY s.week
ORDER BY s.week;

-- 17. Words per day for a specific week
SELECT * FROM v_words_per_day WHERE week = 1;

-- 18. Difficulty distribution
SELECT 
    CASE difficulty_level
        WHEN 1 THEN 'Normal'
        WHEN 2 THEN 'Medium (＊)'
        WHEN 3 THEN 'Hard (＊＊)'
    END as difficulty,
    COUNT(*) as count
FROM vocabulary
GROUP BY difficulty_level
ORDER BY difficulty_level;

-- 19. Word type distribution
SELECT 
    COALESCE(word_type, 'Unknown') as type,
    COUNT(*) as count
FROM vocabulary
GROUP BY word_type
ORDER BY count DESC;

-- 20. Your overall progress
SELECT 
    COUNT(*) as total_words,
    SUM(CASE WHEN times_reviewed > 0 THEN 1 ELSE 0 END) as reviewed_words,
    SUM(CASE WHEN is_marked THEN 1 ELSE 0 END) as marked_words,
    ROUND(100.0 * SUM(CASE WHEN times_reviewed > 0 THEN 1 ELSE 0 END) / COUNT(*), 1) as percent_complete
FROM vocabulary;

-- =====================================================
-- FLASHCARD EXPORT QUERIES
-- =====================================================

-- 21. Export format for Anki (Tab-separated)
-- Front: Kanji, Back: Hiragana + Meaning
SELECT 
    kanji || E'\t' || hiragana || ' - ' || meaning_en as anki_format
FROM vocabulary
ORDER BY ref_no;

-- 22. Export with example sentences
SELECT 
    kanji,
    hiragana,
    meaning_en,
    COALESCE(full_sentence, example_before || kanji || example_after) as example
FROM vocabulary
WHERE full_sentence IS NOT NULL OR example_before IS NOT NULL
ORDER BY ref_no;

-- =====================================================
-- QUIZ QUERIES
-- =====================================================

-- 23. Kanji → Reading quiz (show answer separately)
-- Run first query, try to answer, then run second
-- Question:
SELECT kanji, meaning_en FROM vocabulary WHERE id = 1;
-- Answer:
SELECT hiragana FROM vocabulary WHERE id = 1;

-- 24. Reading → Kanji quiz
SELECT hiragana, meaning_en FROM vocabulary WHERE id = 1;
-- Answer:
SELECT kanji FROM vocabulary WHERE id = 1;

-- 25. Meaning → Word quiz
SELECT meaning_en FROM vocabulary WHERE id = 1;
-- Answer:
SELECT kanji, hiragana FROM vocabulary WHERE id = 1;

-- =====================================================
-- SPACED REPETITION HELPERS
-- =====================================================

-- 26. Words due for review (not reviewed in 3+ days)
SELECT kanji, hiragana, meaning_en, last_reviewed
FROM vocabulary
WHERE last_reviewed < NOW() - INTERVAL '3 days'
   OR last_reviewed IS NULL
ORDER BY last_reviewed NULLS FIRST
LIMIT 20;

-- 27. Frequently wrong words (needs study_progress data)
SELECT 
    v.kanji,
    v.hiragana,
    COUNT(sp.id) as review_count,
    SUM(CASE WHEN sp.result = 'incorrect' THEN 1 ELSE 0 END) as wrong_count
FROM vocabulary v
JOIN study_progress sp ON sp.vocabulary_id = v.id
GROUP BY v.id, v.kanji, v.hiragana
HAVING SUM(CASE WHEN sp.result = 'incorrect' THEN 1 ELSE 0 END) > 0
ORDER BY wrong_count DESC;

-- =====================================================
-- EXAMPLE: Complete Study Session
-- =====================================================

-- Start of study session:
-- 1. Pick 10 random words from Week 1
SELECT id, kanji, hiragana, meaning_en 
FROM v_vocabulary_full 
WHERE week = 1 
ORDER BY RANDOM() 
LIMIT 10;

-- 2. After studying each word, mark it reviewed:
-- UPDATE vocabulary SET times_reviewed = times_reviewed + 1, last_reviewed = NOW() WHERE id = <word_id>;

-- 3. If you got it wrong, mark it:
-- INSERT INTO study_progress (vocabulary_id, review_date, result) VALUES (<word_id>, CURRENT_DATE, 'incorrect');

-- 4. Check your progress:
SELECT * FROM v_study_summary WHERE week = 1;

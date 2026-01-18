-- =====================================================
-- JLPT Vocabulary - Useful Queries for Supabase
-- =====================================================
-- Copy and paste these queries into Supabase SQL Editor
-- =====================================================


-- =====================================================
-- BASIC QUERIES
-- =====================================================

-- 1. Count total vocabulary by level
SELECT level, COUNT(*) as count 
FROM vocabulary 
GROUP BY level 
ORDER BY level;

-- 2. Get all words for a specific level and week
SELECT 
    v.kanji,
    v.hiragana,
    v.meaning_en,
    v.example_before || v.kanji || v.example_after as example,
    s.week_day_label
FROM vocabulary v
JOIN schedule s ON v.schedule_id = s.id
WHERE v.level = 'N1' AND s.week = 1
ORDER BY s.day, v.ref_no;

-- 3. Search by kanji (partial match)
SELECT level, kanji, hiragana, meaning_en
FROM vocabulary
WHERE kanji LIKE '%食%'
ORDER BY level;

-- 4. Search by hiragana/reading
SELECT level, kanji, hiragana, meaning_en
FROM vocabulary
WHERE hiragana LIKE '%たべ%';

-- 5. Search by English meaning
SELECT level, kanji, hiragana, meaning_en
FROM vocabulary
WHERE meaning_en ILIKE '%eat%' OR meaning_en ILIKE '%food%';


-- =====================================================
-- STUDY MODE QUERIES
-- =====================================================

-- 6. Get random 10 words for quick quiz (specific level)
SELECT kanji, hiragana, meaning_en
FROM vocabulary
WHERE level = 'N1'
ORDER BY RANDOM()
LIMIT 10;

-- 7. Get random words from specific week (any level)
SELECT level, kanji, hiragana, meaning_en
FROM v_vocabulary_full
WHERE week = 1
ORDER BY RANDOM()
LIMIT 10;

-- 8. Get difficult words only (＊＊ marked)
SELECT level, kanji, hiragana, meaning_en, hint
FROM vocabulary
WHERE difficulty_level = 3
ORDER BY level, RANDOM()
LIMIT 10;

-- 9. Get words with example sentences
SELECT 
    kanji,
    hiragana,
    meaning_en,
    example_before || '【' || kanji || '】' || example_after as context
FROM vocabulary
WHERE example_before IS NOT NULL
  AND level = 'N1'
ORDER BY RANDOM()
LIMIT 10;


-- =====================================================
-- USER MARKINGS QUERIES
-- =====================================================

-- 10. Get your marked words (replace 'YOUR-USER-ID')
SELECT 
    v.level,
    v.kanji,
    v.hiragana,
    v.meaning_en,
    um.marking,
    CASE um.marking
        WHEN 1 THEN '✓ Monthly Review'
        WHEN 2 THEN '💬 Cant use in conversation'
        WHEN 3 THEN '✍ Cant write'
        WHEN 4 THEN '🤔 Understand but cant use'
        WHEN 5 THEN '❌ Dont know at all'
    END as marking_label
FROM vocabulary v
JOIN user_markings um ON v.id = um.word_id
WHERE um.user_id = 'YOUR-USER-ID'
ORDER BY um.marking DESC, v.level;

-- 11. Progress by level (replace 'YOUR-USER-ID')
SELECT 
    v.level,
    COUNT(*) as total_words,
    COUNT(um.id) as marked_words,
    SUM(CASE WHEN um.marking = 1 THEN 1 ELSE 0 END) as monthly_review,
    SUM(CASE WHEN um.marking = 2 THEN 1 ELSE 0 END) as cant_use_convo,
    SUM(CASE WHEN um.marking = 3 THEN 1 ELSE 0 END) as cant_write,
    SUM(CASE WHEN um.marking = 4 THEN 1 ELSE 0 END) as understand_cant_use,
    SUM(CASE WHEN um.marking = 5 THEN 1 ELSE 0 END) as dont_know,
    ROUND(100.0 * COUNT(um.id) / COUNT(*), 1) as percent_marked
FROM vocabulary v
LEFT JOIN user_markings um ON v.id = um.word_id AND um.user_id = 'YOUR-USER-ID'
GROUP BY v.level
ORDER BY v.level;

-- 12. Words you marked as "Don't know" (need to study)
SELECT 
    v.level,
    v.kanji,
    v.hiragana,
    v.meaning_en,
    v.hint,
    um.updated_at
FROM vocabulary v
JOIN user_markings um ON v.id = um.word_id
WHERE um.user_id = 'YOUR-USER-ID'
  AND um.marking = 5
ORDER BY um.updated_at DESC;

-- 13. Words due for review (marked > 3 days ago)
SELECT 
    v.level,
    v.kanji,
    v.hiragana,
    v.meaning_en,
    um.marking,
    um.updated_at
FROM vocabulary v
JOIN user_markings um ON v.id = um.word_id
WHERE um.user_id = 'YOUR-USER-ID'
  AND um.marking >= 3  -- Difficult words
  AND um.updated_at < NOW() - INTERVAL '3 days'
ORDER BY um.updated_at;


-- =====================================================
-- BULK UPDATE MARKINGS
-- =====================================================

-- 14. Mark all words in Week 1 as "Monthly Review" (marking=1)
-- WARNING: This affects all words! Be careful.
-- INSERT INTO user_markings (user_id, word_id, marking, updated_at)
-- SELECT 'YOUR-USER-ID', v.id, 1, NOW()
-- FROM vocabulary v
-- JOIN schedule s ON v.schedule_id = s.id
-- WHERE v.level = 'N1' AND s.week = 1
-- ON CONFLICT (user_id, word_id) DO UPDATE SET marking = 1, updated_at = NOW();

-- 15. Reset all markings for a specific level
-- WARNING: This deletes your progress!
-- DELETE FROM user_markings
-- WHERE user_id = 'YOUR-USER-ID'
--   AND word_id IN (SELECT id FROM vocabulary WHERE level = 'N1');


-- =====================================================
-- EXPORT QUERIES
-- =====================================================

-- 16. Export for CSV (markings)
SELECT 
    um.user_id,
    um.word_id,
    um.marking,
    um.updated_at
FROM user_markings um
WHERE um.user_id = 'YOUR-USER-ID'
ORDER BY um.word_id;

-- 17. Export vocabulary with markings
SELECT 
    v.id as word_id,
    v.level,
    v.kanji,
    v.hiragana,
    v.meaning_en,
    COALESCE(um.marking, 0) as marking
FROM vocabulary v
LEFT JOIN user_markings um ON v.id = um.word_id AND um.user_id = 'YOUR-USER-ID'
WHERE v.level = 'N1'
ORDER BY v.id;


-- =====================================================
-- STATISTICS
-- =====================================================

-- 18. Overall database summary
SELECT 
    'Vocabulary' as table_name,
    (SELECT COUNT(*) FROM vocabulary) as total_rows,
    (SELECT COUNT(*) FROM vocabulary WHERE level = 'N1') as n1_count,
    (SELECT COUNT(*) FROM vocabulary WHERE level = 'N2') as n2_count,
    (SELECT COUNT(*) FROM vocabulary WHERE level = 'N3') as n3_count;

-- 19. Words with/without sentences
SELECT 
    level,
    COUNT(*) as total,
    COUNT(full_sentence) as with_sentence,
    COUNT(*) - COUNT(full_sentence) as without_sentence
FROM vocabulary
GROUP BY level
ORDER BY level;

-- 20. Word type distribution
SELECT 
    level,
    COALESCE(word_type, 'Unknown') as type,
    COUNT(*) as count
FROM vocabulary
GROUP BY level, word_type
ORDER BY level, count DESC;


-- =====================================================
-- ADMIN QUERIES
-- =====================================================

-- 21. Find duplicate kanji entries
SELECT kanji, level, COUNT(*) as count
FROM vocabulary
GROUP BY kanji, level
HAVING COUNT(*) > 1
ORDER BY count DESC;

-- 22. Check for orphaned markings
SELECT um.*
FROM user_markings um
LEFT JOIN vocabulary v ON um.word_id = v.id
WHERE v.id IS NULL;

-- 23. Users with most markings
SELECT 
    user_id,
    COUNT(*) as total_markings,
    SUM(CASE WHEN marking = 5 THEN 1 ELSE 0 END) as dont_know_count
FROM user_markings
GROUP BY user_id
ORDER BY total_markings DESC
LIMIT 10;

-- Supabase pgvector functions for RAG
-- Run this migration to create the vector similarity search function

-- Enable pgvector extension (if not already enabled)
CREATE EXTENSION IF NOT EXISTS vector;

-- Function: match_knowledge
-- Efficient vector similarity search using cosine distance
-- Usage: SELECT * FROM match_knowledge(query_embedding, match_threshold, match_count)

CREATE OR REPLACE FUNCTION match_knowledge(
    query_embedding vector(768),
    match_threshold float DEFAULT 0.7,
    match_count int DEFAULT 5
)
RETURNS TABLE (
    id uuid,
    content text,
    metadata jsonb,
    similarity float
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        kb.id,
        kb.content,
        kb.metadata,
        1 - (kb.embedding <=> query_embedding) AS similarity
    FROM knowledge_base kb
    WHERE 1 - (kb.embedding <=> query_embedding) > match_threshold
    ORDER BY kb.embedding <=> query_embedding
    LIMIT match_count;
END;
$$;

-- Alternative function: match_knowledge_by_category
-- Filter by category in metadata

CREATE OR REPLACE FUNCTION match_knowledge_by_category(
    query_embedding vector(768),
    category_filter text,
    match_threshold float DEFAULT 0.7,
    match_count int DEFAULT 5
)
RETURNS TABLE (
    id uuid,
    content text,
    metadata jsonb,
    similarity float
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        kb.id,
        kb.content,
        kb.metadata,
        1 - (kb.embedding <=> query_embedding) AS similarity
    FROM knowledge_base kb
    WHERE 
        kb.metadata->>'category' = category_filter
        AND 1 - (kb.embedding <=> query_embedding) > match_threshold
    ORDER BY kb.embedding <=> query_embedding
    LIMIT match_count;
END;
$$;

-- Create index for faster similarity search
-- This significantly improves query performance

CREATE INDEX IF NOT EXISTS knowledge_base_embedding_idx 
ON knowledge_base 
USING ivfflat (embedding vector_cosine_ops)
WITH (lists = 100);

-- Create index for metadata category filtering
CREATE INDEX IF NOT EXISTS knowledge_base_category_idx 
ON knowledge_base 
USING gin ((metadata->'category'));

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION match_knowledge TO authenticated;
GRANT EXECUTE ON FUNCTION match_knowledge TO anon;
GRANT EXECUTE ON FUNCTION match_knowledge_by_category TO authenticated;
GRANT EXECUTE ON FUNCTION match_knowledge_by_category TO anon;

-- Verify setup
DO $$
BEGIN
    RAISE NOTICE '✅ Vector search functions created successfully';
    RAISE NOTICE '✅ Indexes created for optimal performance';
    RAISE NOTICE '✅ Permissions granted';
END $$;

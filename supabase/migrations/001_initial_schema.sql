-- ============================================
-- Legal RAG Mexico - Initial Database Schema
-- ============================================
-- Run this migration in your Supabase SQL Editor
-- Make sure to run in order: 001, 002, 003...

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "vector";
CREATE EXTENSION IF NOT EXISTS "pg_trgm"; -- For text search

-- Create custom types
DO $$ BEGIN
    CREATE TYPE user_role AS ENUM ('user', 'admin', 'premium', 'moderator');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE subscription_tier AS ENUM ('free', 'basic', 'professional', 'enterprise');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE document_status AS ENUM ('draft', 'published', 'archived', 'deleted');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- ============================================
-- USERS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT UNIQUE NOT NULL,
  full_name TEXT,
  organization TEXT,
  phone TEXT,
  role user_role DEFAULT 'user',
  subscription_tier subscription_tier DEFAULT 'free',
  subscription_expires_at TIMESTAMP WITH TIME ZONE,
  profile_image_url TEXT,
  bio TEXT,
  preferences JSONB DEFAULT '{}',
  metadata JSONB DEFAULT '{}',
  is_active BOOLEAN DEFAULT true,
  last_login_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_users_email ON public.users(email);
CREATE INDEX IF NOT EXISTS idx_users_role ON public.users(role);
CREATE INDEX IF NOT EXISTS idx_users_subscription ON public.users(subscription_tier);
CREATE INDEX IF NOT EXISTS idx_users_organization ON public.users(organization);

-- ============================================
-- SEARCH HISTORY TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.search_history (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  query TEXT NOT NULL,
  query_embedding vector(1536),
  results JSONB DEFAULT '[]',
  filters JSONB DEFAULT '{}',
  result_count INTEGER DEFAULT 0,
  execution_time_ms INTEGER,
  metadata JSONB DEFAULT '{}',
  ip_address INET,
  user_agent TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_search_history_user_id ON public.search_history(user_id);
CREATE INDEX IF NOT EXISTS idx_search_history_created_at ON public.search_history(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_search_history_query_trgm ON public.search_history USING gin(query gin_trgm_ops);

-- ============================================
-- DOCUMENTS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.documents (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title TEXT NOT NULL,
  content TEXT,
  summary TEXT,
  document_type TEXT,
  jurisdiction TEXT,
  source_url TEXT,
  source_name TEXT,
  author TEXT,
  publication_date DATE,
  effective_date DATE,
  expiration_date DATE,
  version TEXT,
  language TEXT DEFAULT 'es',
  tags TEXT[],
  metadata JSONB DEFAULT '{}',
  embedding vector(1536),
  search_vector tsvector,
  view_count INTEGER DEFAULT 0,
  citation_count INTEGER DEFAULT 0,
  status document_status DEFAULT 'published',
  created_by UUID REFERENCES public.users(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_documents_type ON public.documents(document_type);
CREATE INDEX IF NOT EXISTS idx_documents_jurisdiction ON public.documents(jurisdiction);
CREATE INDEX IF NOT EXISTS idx_documents_status ON public.documents(status);
CREATE INDEX IF NOT EXISTS idx_documents_publication_date ON public.documents(publication_date DESC);
CREATE INDEX IF NOT EXISTS idx_documents_tags ON public.documents USING gin(tags);
CREATE INDEX IF NOT EXISTS idx_documents_search_vector ON public.documents USING gin(search_vector);
CREATE INDEX IF NOT EXISTS idx_documents_title_trgm ON public.documents USING gin(title gin_trgm_ops);

-- Create vector similarity search index
CREATE INDEX IF NOT EXISTS documents_embedding_idx ON public.documents 
USING ivfflat (embedding vector_cosine_ops)
WITH (lists = 100);

-- ============================================
-- SAVED QUERIES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.saved_queries (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  query TEXT NOT NULL,
  filters JSONB DEFAULT '{}',
  is_favorite BOOLEAN DEFAULT false,
  is_public BOOLEAN DEFAULT false,
  execution_count INTEGER DEFAULT 0,
  last_executed_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_saved_queries_user_id ON public.saved_queries(user_id);
CREATE INDEX IF NOT EXISTS idx_saved_queries_is_favorite ON public.saved_queries(is_favorite);
CREATE INDEX IF NOT EXISTS idx_saved_queries_is_public ON public.saved_queries(is_public);

-- ============================================
-- CHAT SESSIONS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.chat_sessions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  title TEXT,
  description TEXT,
  messages JSONB[] DEFAULT ARRAY[]::JSONB[],
  context JSONB DEFAULT '{}',
  metadata JSONB DEFAULT '{}',
  token_count INTEGER DEFAULT 0,
  is_archived BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_chat_sessions_user_id ON public.chat_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_chat_sessions_created_at ON public.chat_sessions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_chat_sessions_is_archived ON public.chat_sessions(is_archived);

-- ============================================
-- CITATIONS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.citations (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  document_id UUID REFERENCES public.documents(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
  citation_text TEXT NOT NULL,
  citation_format TEXT NOT NULL,
  page_number INTEGER,
  paragraph_number INTEGER,
  section TEXT,
  notes TEXT,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_citations_document_id ON public.citations(document_id);
CREATE INDEX IF NOT EXISTS idx_citations_user_id ON public.citations(user_id);
CREATE INDEX IF NOT EXISTS idx_citations_format ON public.citations(citation_format);

-- ============================================
-- DOCUMENT CHUNKS TABLE (for RAG)
-- ============================================
CREATE TABLE IF NOT EXISTS public.document_chunks (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  document_id UUID REFERENCES public.documents(id) ON DELETE CASCADE,
  chunk_index INTEGER NOT NULL,
  content TEXT NOT NULL,
  embedding vector(1536),
  metadata JSONB DEFAULT '{}',
  token_count INTEGER,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_document_chunks_document_id ON public.document_chunks(document_id);
CREATE INDEX IF NOT EXISTS idx_document_chunks_index ON public.document_chunks(chunk_index);

-- Create vector similarity search index
CREATE INDEX IF NOT EXISTS document_chunks_embedding_idx ON public.document_chunks 
USING ivfflat (embedding vector_cosine_ops)
WITH (lists = 100);

-- ============================================
-- USER FAVORITES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.user_favorites (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  document_id UUID REFERENCES public.documents(id) ON DELETE CASCADE,
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, document_id)
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_user_favorites_user_id ON public.user_favorites(user_id);
CREATE INDEX IF NOT EXISTS idx_user_favorites_document_id ON public.user_favorites(document_id);

-- ============================================
-- API USAGE TRACKING TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.api_usage (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  endpoint TEXT NOT NULL,
  method TEXT NOT NULL,
  status_code INTEGER,
  response_time_ms INTEGER,
  tokens_used INTEGER,
  cost_estimate DECIMAL(10, 6),
  error_message TEXT,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_api_usage_user_id ON public.api_usage(user_id);
CREATE INDEX IF NOT EXISTS idx_api_usage_created_at ON public.api_usage(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_api_usage_endpoint ON public.api_usage(endpoint);

-- ============================================
-- FUNCTIONS
-- ============================================

-- Function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to update document search vector
CREATE OR REPLACE FUNCTION update_document_search_vector()
RETURNS TRIGGER AS $$
BEGIN
  NEW.search_vector := 
    setweight(to_tsvector('spanish', COALESCE(NEW.title, '')), 'A') ||
    setweight(to_tsvector('spanish', COALESCE(NEW.summary, '')), 'B') ||
    setweight(to_tsvector('spanish', COALESCE(NEW.content, '')), 'C') ||
    setweight(to_tsvector('spanish', COALESCE(array_to_string(NEW.tags, ' '), '')), 'D');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to handle new user registration
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (id, email, full_name, metadata)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    COALESCE(NEW.raw_user_meta_data, '{}'::jsonb)
  )
  ON CONFLICT (id) DO UPDATE
  SET 
    email = EXCLUDED.email,
    full_name = COALESCE(EXCLUDED.full_name, public.users.full_name),
    metadata = EXCLUDED.metadata;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get similar documents
CREATE OR REPLACE FUNCTION get_similar_documents(
  query_embedding vector(1536),
  match_threshold float DEFAULT 0.7,
  match_count int DEFAULT 10
)
RETURNS TABLE (
  id UUID,
  title TEXT,
  content TEXT,
  document_type TEXT,
  jurisdiction TEXT,
  similarity float
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    d.id,
    d.title,
    d.content,
    d.document_type,
    d.jurisdiction,
    1 - (d.embedding <=> query_embedding) AS similarity
  FROM public.documents d
  WHERE d.status = 'published'
    AND d.embedding IS NOT NULL
    AND 1 - (d.embedding <=> query_embedding) > match_threshold
  ORDER BY d.embedding <=> query_embedding
  LIMIT match_count;
END;
$$;

-- ============================================
-- TRIGGERS
-- ============================================

-- Update triggers for updated_at
CREATE TRIGGER update_users_updated_at 
  BEFORE UPDATE ON public.users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_documents_updated_at 
  BEFORE UPDATE ON public.documents
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_saved_queries_updated_at 
  BEFORE UPDATE ON public.saved_queries
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_chat_sessions_updated_at 
  BEFORE UPDATE ON public.chat_sessions
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Update search vector on document changes
CREATE TRIGGER update_document_search_vector_trigger
  BEFORE INSERT OR UPDATE ON public.documents
  FOR EACH ROW EXECUTE FUNCTION update_document_search_vector();

-- Handle new user registration
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================

-- Enable RLS on all tables
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.search_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.saved_queries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.citations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.document_chunks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_favorites ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.api_usage ENABLE ROW LEVEL SECURITY;

-- Users policies
CREATE POLICY "Users can view own profile" ON public.users
  FOR SELECT USING (auth.uid() = id OR role = 'admin');

CREATE POLICY "Users can update own profile" ON public.users
  FOR UPDATE USING (auth.uid() = id);

-- Search history policies
CREATE POLICY "Users can view own search history" ON public.search_history
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own search history" ON public.search_history
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own search history" ON public.search_history
  FOR DELETE USING (auth.uid() = user_id);

-- Documents policies (public read, admin write)
CREATE POLICY "Documents are viewable by all authenticated users" ON public.documents
  FOR SELECT USING (auth.uid() IS NOT NULL AND status = 'published');

CREATE POLICY "Admins can manage documents" ON public.documents
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.users 
      WHERE id = auth.uid() AND role IN ('admin', 'moderator')
    )
  );

-- Saved queries policies
CREATE POLICY "Users can manage own saved queries" ON public.saved_queries
  FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Users can view public saved queries" ON public.saved_queries
  FOR SELECT USING (is_public = true);

-- Chat sessions policies
CREATE POLICY "Users can manage own chat sessions" ON public.chat_sessions
  FOR ALL USING (auth.uid() = user_id);

-- Citations policies
CREATE POLICY "Users can view all citations" ON public.citations
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Users can manage own citations" ON public.citations
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own citations" ON public.citations
  FOR DELETE USING (auth.uid() = user_id);

-- Document chunks policies
CREATE POLICY "Document chunks viewable by authenticated users" ON public.document_chunks
  FOR SELECT USING (auth.uid() IS NOT NULL);

-- User favorites policies
CREATE POLICY "Users can manage own favorites" ON public.user_favorites
  FOR ALL USING (auth.uid() = user_id);

-- API usage policies
CREATE POLICY "Users can view own API usage" ON public.api_usage
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "System can insert API usage" ON public.api_usage
  FOR INSERT WITH CHECK (true);

-- ============================================
-- INITIAL DATA (Optional)
-- ============================================

-- Insert default document types
INSERT INTO public.documents (title, document_type, jurisdiction, content, status)
VALUES 
  ('Constitución Política de los Estados Unidos Mexicanos', 'constitucion', 'federal', 'Placeholder content...', 'published'),
  ('Código Civil Federal', 'codigo_civil', 'federal', 'Placeholder content...', 'published'),
  ('Código Penal Federal', 'codigo_penal', 'federal', 'Placeholder content...', 'published')
ON CONFLICT DO NOTHING;

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated;
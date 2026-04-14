-- 收藏表
CREATE TABLE favorites (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  book_name TEXT NOT NULL,
  book_source TEXT NOT NULL CHECK (book_source IN ('pccr', 'threads')),
  book_data JSONB NOT NULL,
  status TEXT NOT NULL DEFAULT 'want' CHECK (status IN ('want', 'owned', 'done')),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (user_id, book_name, book_source)
);

-- Row Level Security
ALTER TABLE favorites ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users read own favorites"
  ON favorites FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users insert own favorites"
  ON favorites FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users update own favorites"
  ON favorites FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users delete own favorites"
  ON favorites FOR DELETE
  USING (auth.uid() = user_id);

-- 索引
CREATE INDEX idx_favorites_user_id ON favorites(user_id);
CREATE INDEX idx_favorites_user_status ON favorites(user_id, status);

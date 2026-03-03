-- ================================
-- Koro SNS setup.sql  (再実行可能・冪等)
-- ================================
-- 既存ポリシーを先に削除してから再作成するため何度実行してもOK

-- ── posts 拡張 ───────────────────────────────────────
-- リプころ (reply) / リコロ (repost) 用カラム追加
-- 既に存在する場合は IF NOT EXISTS で無視させる
ALTER TABLE posts ADD COLUMN IF NOT EXISTS reply_to  TEXT;   -- 直接の親post id
ALTER TABLE posts ADD COLUMN IF NOT EXISTS root_id   TEXT;   -- スレッド根post id
ALTER TABLE posts ADD COLUMN IF NOT EXISTS repost_of  TEXT;  -- リコロ元post id
ALTER TABLE posts ADD COLUMN IF NOT EXISTS repost_author  TEXT; -- リコロ元の表示名
ALTER TABLE posts ADD COLUMN IF NOT EXISTS repost_handle  TEXT; -- リコロ元のハンドル
ALTER TABLE posts ADD COLUMN IF NOT EXISTS repost_content TEXT; -- リコロ元の本文

-- ── likes ──────────────────────────────────────────
-- post_id は posts テーブルの id 型に合わせて TEXT
DROP TABLE IF EXISTS likes;
CREATE TABLE likes (
  id          UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id     UUID        NOT NULL,
  post_id     TEXT        NOT NULL,
  created_at  TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, post_id)
);
ALTER TABLE likes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "likes_select" ON likes;
DROP POLICY IF EXISTS "likes_insert" ON likes;
DROP POLICY IF EXISTS "likes_delete" ON likes;
CREATE POLICY "likes_select" ON likes FOR SELECT USING (true);
CREATE POLICY "likes_insert" ON likes FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "likes_delete" ON likes FOR DELETE USING (auth.uid() = user_id);

-- ── follows ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS follows (
  id           UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  follower_id  UUID        NOT NULL,
  following_id UUID        NOT NULL,
  created_at   TIMESTAMPTZ DEFAULT now(),
  UNIQUE(follower_id, following_id),
  CHECK(follower_id != following_id)
);
ALTER TABLE follows ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "follows_select" ON follows;
DROP POLICY IF EXISTS "follows_insert" ON follows;
DROP POLICY IF EXISTS "follows_delete" ON follows;
CREATE POLICY "follows_select" ON follows FOR SELECT USING (true);
CREATE POLICY "follows_insert" ON follows FOR INSERT WITH CHECK (auth.uid() = follower_id);
CREATE POLICY "follows_delete" ON follows FOR DELETE USING (auth.uid() = follower_id);

-- ── posts 削除ポリシー（有効にする場合はコメント解除） ──
-- DROP POLICY IF EXISTS "posts_delete_own" ON posts;
-- CREATE POLICY "posts_delete_own" ON posts FOR DELETE
--   USING (author_handle IN (SELECT user_handle FROM profiles WHERE id = auth.uid()));
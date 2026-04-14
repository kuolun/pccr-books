# 收藏功能 + Google 登入 + 蝦皮連結 — 設計規格

## 背景

pccr-books 是一個嬰幼兒好書查詢靜態網站（單一 HTML、GitHub Pages），目前有兩個資料來源 Tab（教育部好書 848 本、Threads 社群推薦 84 本）。本次要加入使用者系統和收藏功能，同時新增蝦皮購物連結。

## 目標

1. 新增蝦皮搜尋連結
2. Google 帳號登入（Supabase Auth）
3. 書籍卡片收藏星號
4. 「我的收藏」Tab + 三階段閱讀狀態追蹤

## 技術架構

- **前端**：維持單一 `index.html`，透過 CDN 載入 Supabase JS SDK
- **後端**：Supabase 免費方案（50K MAU、500MB DB、Google OAuth 內建）
- **部署**：GitHub Pages 不變
- **資料庫**：Supabase 託管的 PostgreSQL

不需要額外的伺服器、build 工具或框架。

## 功能規格

### 1. 蝦皮連結

每張書籍卡片的 actions 區新增「蝦皮」按鈕。

- PCCR 卡片和 Threads 卡片都加
- URL 格式：`https://shopee.tw/search?keyword={encodeURIComponent(書名)}`
- 按鈕樣式：新增 `.act-shopee`，配色使用蝦皮橘 `#ee4d2d`

### 2. Google 登入

#### Supabase 設定

- 建立 Supabase 專案
- 啟用 Google OAuth provider
- 設定 Google Cloud Console OAuth 2.0 credentials
- Redirect URL 設為 GitHub Pages 網址

#### 前端 UI

- Header 右側新增登入區域
  - **未登入**：顯示「登入」文字按鈕
  - **已登入**：顯示 Google 頭像（圓形，24px）+ 名字，hover 顯示「登出」
- 手機版：頭像縮小或只顯示圖示

#### 登入流程

1. 使用者點「登入」→ 呼叫 `supabase.auth.signInWithOAuth({ provider: 'google' })`
2. 跳轉 Google 授權頁 → 回到網站
3. `supabase.auth.onAuthStateChange` 偵測登入狀態，更新 UI

### 3. 收藏星號

#### 卡片 UI

- 每張書籍卡片右上角新增星號圖示
- **未收藏**：空心星 `☆`（灰色）
- **已收藏**：實心星 `★`（金色 `#d4a853`）
- 星號使用 CSS `position: absolute; top: 0.5rem; right: 0.5rem`，卡片需 `position: relative`

#### 互動邏輯

- **已登入 + 點星號**：
  - 未收藏 → 新增收藏（狀態預設 `want`），星號變實心
  - 已收藏 → 移除收藏，星號變空心
- **未登入 + 點星號**：
  - 顯示提示面板（overlay），內容：
    - 標題：「登入即可收藏」
    - 說明：「登入後可以：收藏喜愛的書籍 / 追蹤閱讀進度（想看→已入手→讀完）/ 跨裝置同步收藏清單」
    - Google 登入按鈕
    - 「稍後再說」關閉按鈕

### 4. 我的收藏 Tab

#### Tab 位置

- 登入後在現有 Tab 列最右邊新增「我的收藏 N」
- 未登入時不顯示此 Tab
- N 為即時收藏數量

#### 收藏清單 UI

- 進入收藏 Tab 時，從 Supabase 讀取使用者的收藏資料
- 顯示搜尋框（搜尋收藏內的書名）
- 狀態篩選 pills：「全部」「想看」「已入手」「讀完」
- 書籍卡片樣式與原本一致，但額外顯示：
  - 狀態標籤（tag 樣式）
  - 狀態切換按鈕組（三個按鈕：想看 / 已入手 / 讀完，當前狀態高亮）

#### 閱讀狀態

三種狀態與對應顏色：
- `want`（想看）：藍色 `#1565c0`
- `owned`（已入手）：橘色 `#e65100`
- `done`（讀完）：綠色 `#2e7d32`

狀態切換是直接跳轉，不需要按順序（可以從「想看」直接跳到「讀完」）。

## 資料庫設計

### 表：`favorites`

```sql
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
```

### Row Level Security

```sql
ALTER TABLE favorites ENABLE ROW LEVEL SECURITY;

-- 使用者只能讀取自己的收藏
CREATE POLICY "Users read own favorites"
  ON favorites FOR SELECT
  USING (auth.uid() = user_id);

-- 使用者只能新增自己的收藏
CREATE POLICY "Users insert own favorites"
  ON favorites FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- 使用者只能更新自己的收藏
CREATE POLICY "Users update own favorites"
  ON favorites FOR UPDATE
  USING (auth.uid() = user_id);

-- 使用者只能刪除自己的收藏
CREATE POLICY "Users delete own favorites"
  ON favorites FOR DELETE
  USING (auth.uid() = user_id);
```

### 索引

```sql
CREATE INDEX idx_favorites_user_id ON favorites(user_id);
CREATE INDEX idx_favorites_user_status ON favorites(user_id, status);
```

## 前端實作要點

### Supabase SDK 載入

```html
<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>
<script>
const supabase = supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
</script>
```

### 收藏資料快取

- 登入時一次讀取所有收藏，存在 `Map<string, favorite>` 中（key 為 `book_name:book_source`）
- 星號渲染時從快取判斷是否已收藏
- 收藏/取消收藏時同時更新快取和 DB
- 避免每次 render 都查 DB

### 書籍識別方式

- PCCR 書籍用 `book_name` + `book_source='pccr'` 識別
- Threads 書籍用 `book_name` + `book_source='threads'` 識別
- 同名書在不同來源可以各自收藏

### render 流程調整

```
render() {
  const books = currentSource === 'favorites'
    ? getFavoritesAsBooks()
    : getActiveBooks().filter(matchBook);
  // ... 渲染
}
```

收藏 Tab 的資料來自 `favorites` 表的 `book_data` 欄位，還原成書籍物件後用現有的 renderCard 渲染。

## 新增 CSS

```css
/* 蝦皮按鈕 */
.act-shopee { background:#fff3e0; color:#ee4d2d; border-color:#ffcc80; }
.act-shopee:hover { background:#ee4d2d; color:#fff; }

/* 收藏星號 */
.fav-star { position:absolute; top:0.5rem; right:0.5rem; font-size:1.3rem; cursor:pointer; color:#ccc; transition:color 0.15s; background:none; border:none; padding:0.2rem; }
.fav-star:hover { color:#d4a853; }
.fav-star.active { color:#d4a853; }

/* 登入區域 */
.auth-area { position:absolute; right:1rem; top:50%; transform:translateY(-50%); }

/* 登入提示面板 */
.login-prompt-overlay { position:fixed; inset:0; background:rgba(0,0,0,0.4); display:flex; align-items:center; justify-content:center; z-index:100; }
.login-prompt { background:#fff; border-radius:12px; padding:2rem; max-width:360px; text-align:center; }

/* 狀態標籤 */
.tag-want { background:#e3f2fd; color:#1565c0; }
.tag-owned { background:#fff3e0; color:#e65100; }
.tag-done { background:#e8f5e9; color:#2e7d32; }

/* 狀態切換按鈕 */
.status-btns { display:flex; gap:0.3rem; margin-top:0.4rem; }
.status-btn { padding:0.2rem 0.5rem; border-radius:4px; font-size:0.72rem; cursor:pointer; border:1px solid #ddd; background:#fff; }
.status-btn.current { font-weight:700; }
```

## 實作順序

1. **蝦皮連結** — 最簡單，不涉及後端
2. **Supabase 專案建立** — 建 DB、設 Auth、設 RLS
3. **Google 登入 UI** — Header 登入按鈕、auth state 管理
4. **收藏星號** — 卡片改造、未登入提示面板、收藏 CRUD
5. **我的收藏 Tab** — Tab 新增、收藏清單 render、狀態篩選與切換
6. **測試** — 登入/登出、收藏/取消、狀態切換、跨 Tab 星號同步
7. **部署** — 更新 GitHub Pages、設定 Supabase redirect URL

## 需使用者手動操作的步驟

以下步驟無法由程式自動完成：

1. 註冊 Supabase 帳號並建立專案 → 取得 `SUPABASE_URL` 和 `SUPABASE_ANON_KEY`
2. 在 Google Cloud Console 建立 OAuth 2.0 credentials → 取得 Client ID 和 Secret
3. 在 Supabase Dashboard 啟用 Google Auth provider 並填入 credentials
4. 設定 OAuth redirect URL 為 `https://kuolun.github.io/pccr-books/`

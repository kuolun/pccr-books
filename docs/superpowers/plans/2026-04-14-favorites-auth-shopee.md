# 收藏功能 + Google 登入 + 蝦皮連結 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 為嬰幼兒好書查詢網站加入蝦皮連結、Google 登入、書籍收藏與三階段閱讀狀態追蹤。

**Architecture:** 前端維持單一 `index.html`，透過 CDN 載入 Supabase JS SDK 直連 Supabase PostgreSQL。使用 Supabase Auth 的 Google OAuth 做登入，收藏資料存在 `favorites` 表並以 Row Level Security 隔離使用者資料。

**Tech Stack:** Vanilla JS, Supabase JS SDK v2 (CDN), Supabase PostgreSQL, Google OAuth 2.0, GitHub Pages

---

## File Structure

| 檔案 | 職責 |
|------|------|
| `index.html` | 唯一前端檔案 — CSS、HTML、JS 全部在此 |
| `supabase-setup.sql` | 新增 — Supabase 資料庫 schema（供使用者在 SQL Editor 執行） |

所有修改都在 `index.html`，按區域分：
- **CSS 區**（`<style>` 內）：新增 `.act-shopee`, `.fav-star`, `.auth-area`, `.login-prompt-overlay`, `.tag-want/owned/done`, `.status-btns` 等
- **HTML 區**（`<body>` 內）：header 登入區域、收藏 Tab、登入提示 overlay、收藏篩選器
- **JS 區**（`<script>` 內）：Supabase 初始化、auth 管理、收藏 CRUD、render 邏輯調整

---

## Task 1: 蝦皮連結

**Files:**
- Modify: `index.html` — CSS 區（加 `.act-shopee`）、JS 區（`links()` 和 `renderThreadsCard()` 函式）

- [ ] **Step 1: 新增蝦皮 CSS**

在 `index.html` 的 `<style>` 區，找到 `.act-yt:hover{background:#d32f2f;color:#fff}` 後面加入：

```css
.act-shopee{background:#fff3e0;color:#ee4d2d;border-color:#ffcc80}
.act-shopee:hover{background:#ee4d2d;color:#fff}
```

- [ ] **Step 2: PCCR 卡片加入蝦皮連結**

在 JS 區的 `links(b)` 函式中，在 YouTube 連結後面（`act-yt` 那行之後、`return html` 之前）加入：

```javascript
html+=`<a class="act act-shopee" href="https://shopee.tw/search?keyword=${enc(name)}" target="_blank" rel="noopener">蝦皮</a>`;
```

- [ ] **Step 3: Threads 卡片加入蝦皮連結**

在 JS 區的 `renderThreadsCard(b)` 函式中，在 YouTube 連結後面加入：

```javascript
actions+=`<a class="act act-shopee" href="https://shopee.tw/search?keyword=${enc(b.n)}" target="_blank" rel="noopener">蝦皮</a>`;
```

- [ ] **Step 4: 瀏覽器驗證**

開啟 `index.html`，確認：
- PCCR 卡片有蝦皮按鈕且點擊能開啟蝦皮搜尋結果
- Threads 卡片有蝦皮按鈕且點擊能開啟蝦皮搜尋結果
- 蝦皮按鈕配色為橘色

- [ ] **Step 5: Commit**

```bash
git add index.html
git commit -m "feat: add Shopee search link to all book cards"
```

---

## Task 2: Supabase 資料庫 Schema

**Files:**
- Create: `supabase-setup.sql`

- [ ] **Step 1: 建立 SQL setup 檔案**

建立 `supabase-setup.sql`：

```sql
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
```

- [ ] **Step 2: Commit**

```bash
git add supabase-setup.sql
git commit -m "feat: add Supabase database schema for favorites"
```

- [ ] **Step 3: 使用者手動操作（暫停點）**

需要使用者完成以下操作後才能繼續：

1. 註冊 [Supabase](https://supabase.com) 並建立新專案
2. 進入專案 → SQL Editor → 貼上 `supabase-setup.sql` 的內容 → 執行
3. 進入 Settings → API → 複製 `Project URL` 和 `anon public` key
4. 進入 [Google Cloud Console](https://console.cloud.google.com) → APIs & Services → Credentials → 建立 OAuth 2.0 Client ID
   - Application type: Web application
   - Authorized redirect URIs: 加入 `https://<你的supabase-ref>.supabase.co/auth/v1/callback`
5. 回到 Supabase → Authentication → Providers → 啟用 Google → 填入 Client ID 和 Client Secret
6. 在 Supabase → Authentication → URL Configuration → 設定 Site URL 為 `https://kuolun.github.io/pccr-books/`，Redirect URLs 加入 `https://kuolun.github.io/pccr-books/`

使用者需提供：
- `SUPABASE_URL`（例如 `https://xxxxx.supabase.co`）
- `SUPABASE_ANON_KEY`（一長串 JWT）

---

## Task 3: Supabase SDK + Google 登入 UI

**Files:**
- Modify: `index.html` — CSS 區、HTML 區（header）、JS 區（Supabase 初始化 + auth）

- [ ] **Step 1: 新增登入相關 CSS**

在 `<style>` 區，`source-tab` 相關 CSS 後面加入：

```css
.header{position:relative}
.auth-area{position:absolute;right:1rem;top:50%;transform:translateY(-50%);font-size:0.85rem}
.auth-area a{color:#7a6548;text-decoration:none;cursor:pointer;font-weight:600}
.auth-area a:hover{color:#5a4228}
.auth-user{display:flex;align-items:center;gap:0.4rem;color:#5a4228;font-size:0.82rem}
.auth-user img{width:24px;height:24px;border-radius:50%}
.auth-user .logout-btn{color:#999;font-size:0.75rem;cursor:pointer;margin-left:0.3rem}
.auth-user .logout-btn:hover{color:#c0392b}
.login-prompt-overlay{position:fixed;inset:0;background:rgba(0,0,0,0.4);display:flex;align-items:center;justify-content:center;z-index:100}
.login-prompt{background:#fff;border-radius:12px;padding:2rem;max-width:360px;text-align:center;box-shadow:0 8px 32px rgba(0,0,0,0.15)}
.login-prompt h3{color:#5a4228;margin-bottom:0.8rem}
.login-prompt ul{text-align:left;margin:1rem 0;padding-left:1.2rem;color:#666;font-size:0.9rem;line-height:2}
.login-prompt .google-btn{display:inline-flex;align-items:center;gap:0.5rem;background:#fff;border:2px solid #ddd;border-radius:8px;padding:0.6rem 1.2rem;font-size:0.95rem;cursor:pointer;font-weight:600;color:#333;transition:border-color 0.15s}
.login-prompt .google-btn:hover{border-color:#4285f4}
.login-prompt .dismiss-btn{display:block;margin-top:0.8rem;color:#999;font-size:0.8rem;cursor:pointer;background:none;border:none}
```

手機版追加（在 `@media(max-width:600px)` 區塊內）：

```css
.auth-area{position:static;text-align:center;margin-top:0.5rem}
```

- [ ] **Step 2: 新增 Header 登入區域 HTML**

在 `<div class="header">` 內，`</div>` 結束前，加入：

```html
<div class="auth-area" id="authArea">
  <a onclick="loginWithGoogle()">登入</a>
</div>
```

- [ ] **Step 3: 新增登入提示 overlay HTML**

在 `</body>` 前加入：

```html
<div class="login-prompt-overlay" id="loginPrompt" style="display:none">
  <div class="login-prompt">
    <h3>登入即可收藏</h3>
    <ul>
      <li>收藏喜愛的書籍</li>
      <li>追蹤閱讀進度（想看→已入手→讀完）</li>
      <li>跨裝置同步收藏清單</li>
    </ul>
    <button class="google-btn" onclick="loginWithGoogle()">
      <svg width="18" height="18" viewBox="0 0 48 48"><path fill="#4285F4" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"/><path fill="#34A853" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"/><path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"/><path fill="#EA4335" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"/></svg>
      使用 Google 帳號登入
    </button>
    <button class="dismiss-btn" onclick="document.getElementById('loginPrompt').style.display='none'">稍後再說</button>
  </div>
</div>
```

- [ ] **Step 4: 載入 Supabase SDK 並初始化**

在 `<script>` 標籤前（即 `</div>` footer 之後），加入：

```html
<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>
```

在現有 `<script>` 區最頂部（`const BOOKS=` 之前），加入：

```javascript
const SUPABASE_URL='__SUPABASE_URL__';
const SUPABASE_ANON_KEY='__SUPABASE_ANON_KEY__';
const sb=window.supabase.createClient(SUPABASE_URL,SUPABASE_ANON_KEY);
let currentUser=null;
let favCache=new Map();
```

注意：`__SUPABASE_URL__` 和 `__SUPABASE_ANON_KEY__` 為 placeholder，使用者取得 Supabase credentials 後替換。

- [ ] **Step 5: 新增 auth 管理函式**

在 JS 區，`render();` 之前，加入：

```javascript
// Auth
async function loginWithGoogle(){
  await sb.auth.signInWithOAuth({provider:'google',options:{redirectTo:location.origin+location.pathname}});
}

async function logout(){
  await sb.auth.signOut();
  currentUser=null;
  favCache.clear();
  if(currentSource==='favorites'){
    document.querySelector('.source-tab[data-source="pccr"]').click();
  }
  updateAuthUI();
  updateFavTab();
  render();
}

function updateAuthUI(){
  const area=document.getElementById('authArea');
  if(currentUser){
    const meta=currentUser.user_metadata;
    const name=meta.full_name||meta.name||'User';
    const avatar=meta.avatar_url||meta.picture||'';
    area.innerHTML=`<div class="auth-user">${avatar?`<img src="${avatar}" alt="">`:''}<span>${name}</span><span class="logout-btn" onclick="logout()">登出</span></div>`;
  }else{
    area.innerHTML='<a onclick="loginWithGoogle()">登入</a>';
  }
}

async function loadFavorites(){
  if(!currentUser)return;
  const{data}=await sb.from('favorites').select('*').eq('user_id',currentUser.id);
  favCache.clear();
  if(data)data.forEach(f=>favCache.set(f.book_name+':'+f.book_source,f));
}

function updateFavTab(){
  const tab=document.getElementById('favTab');
  if(!tab)return;
  if(currentUser){
    tab.style.display='';
    tab.querySelector('.tab-count').textContent=favCache.size;
  }else{
    tab.style.display='none';
  }
}

sb.auth.onAuthStateChange(async(event,session)=>{
  currentUser=session?.user||null;
  updateAuthUI();
  if(currentUser){
    await loadFavorites();
  }
  updateFavTab();
  render();
});
```

- [ ] **Step 6: 瀏覽器驗證**

開啟 `index.html`，確認：
- Header 右側顯示「登入」文字
- 點「登入」會跳轉 Google（如果 Supabase 已設定好；如果尚未設定，確認 JS 不報錯）
- 未登入時不顯示收藏 Tab

- [ ] **Step 7: Commit**

```bash
git add index.html
git commit -m "feat: add Supabase SDK and Google login UI"
```

---

## Task 4: 收藏星號

**Files:**
- Modify: `index.html` — CSS 區、JS 區（`renderPccrCard`, `renderThreadsCard`, 收藏 CRUD）

- [ ] **Step 1: 新增星號 CSS**

在 `<style>` 區加入：

```css
.book-card{position:relative}
.fav-star{position:absolute;top:0.5rem;right:0.5rem;font-size:1.3rem;cursor:pointer;color:#ccc;transition:color 0.15s;background:none;border:none;padding:0.2rem;line-height:1}
.fav-star:hover{color:#d4a853}
.fav-star.active{color:#d4a853}
```

- [ ] **Step 2: 新增收藏 CRUD 函式**

在 JS 區，`updateFavTab` 函式後面加入：

```javascript
function isFav(bookName,source){
  return favCache.has(bookName+':'+source);
}

async function toggleFav(bookName,source,bookData){
  if(!currentUser){
    document.getElementById('loginPrompt').style.display='';
    return;
  }
  const key=bookName+':'+source;
  if(favCache.has(key)){
    const fav=favCache.get(key);
    await sb.from('favorites').delete().eq('id',fav.id);
    favCache.delete(key);
  }else{
    const row={user_id:currentUser.id,book_name:bookName,book_source:source,book_data:bookData,status:'want'};
    const{data}=await sb.from('favorites').insert(row).select().single();
    if(data)favCache.set(key,data);
  }
  updateFavTab();
  render();
}

function starHtml(bookName,source,bookData){
  const active=isFav(bookName,source)?'active':'';
  const icon=isFav(bookName,source)?'★':'☆';
  const dataAttr=`data-bn="${bookName.replace(/"/g,'&quot;')}" data-bs="${source}"`;
  return `<button class="fav-star ${active}" ${dataAttr} onclick="toggleFav(this.dataset.bn,this.dataset.bs,findBookData(this.dataset.bn,this.dataset.bs))">${icon}</button>`;
}

function findBookData(bookName,source){
  const books=source==='threads'?THREADS_BOOKS:BOOKS;
  return books.find(b=>b.n===bookName)||{n:bookName};
}
```

- [ ] **Step 3: 在 PCCR 卡片加入星號**

修改 `renderPccrCard(b)` 函式，在 `return` 的 template literal 中，`<div class="book-card` 開頭的下一行加入星號：

將：
```javascript
return `<div class="book-card${b.cl?' classic':''}">
    <div class="title">${titleHtml}</div>
```

改為：
```javascript
return `<div class="book-card${b.cl?' classic':''}">
    ${starHtml(b.n,'pccr',b)}
    <div class="title">${titleHtml}</div>
```

- [ ] **Step 4: 在 Threads 卡片加入星號**

修改 `renderThreadsCard(b)` 函式，同樣在 card div 開頭後加入星號：

將：
```javascript
return `<div class="book-card threads-src">
    <div class="title">${b.n}</div>
```

改為：
```javascript
return `<div class="book-card threads-src">
    ${starHtml(b.n,'threads',b)}
    <div class="title">${b.n}</div>
```

- [ ] **Step 5: 瀏覽器驗證**

開啟 `index.html`，確認：
- 每張卡片右上角有灰色空心星 ☆
- 未登入時點星號 → 顯示登入提示面板
- 面板有 Google 登入按鈕和「稍後再說」
- 「稍後再說」能關閉面板

- [ ] **Step 6: Commit**

```bash
git add index.html
git commit -m "feat: add favorite star button to book cards with login prompt"
```

---

## Task 5: 我的收藏 Tab + 狀態追蹤

**Files:**
- Modify: `index.html` — CSS 區、HTML 區（Tab、篩選器）、JS 區（render 邏輯）

- [ ] **Step 1: 新增狀態相關 CSS**

在 `<style>` 區加入：

```css
.tag-want{background:#e3f2fd;color:#1565c0}
.tag-owned{background:#fff3e0;color:#e65100}
.tag-done{background:#e8f5e9;color:#2e7d32}
.status-btns{display:flex;gap:0.3rem;margin-top:0.4rem}
.status-btn{padding:0.2rem 0.5rem;border-radius:4px;font-size:0.72rem;cursor:pointer;border:1px solid #ddd;background:#fff;transition:all 0.15s}
.status-btn:hover{border-color:#d4a853}
.status-btn.current{font-weight:700;border-color:currentColor}
```

- [ ] **Step 2: 新增收藏 Tab HTML**

在 source-tabs 區的 threads Tab 後面，加入收藏 Tab：

```html
<button class="source-tab" data-source="favorites" id="favTab" style="display:none">我的收藏 <span class="tab-count">0</span></button>
```

- [ ] **Step 3: 新增收藏篩選器 HTML**

在 `threadsFilters` 的 `</div>` 後面，加入：

```html
<div class="filters" id="favFilters" style="display:none">
  <div class="filter-group">
    <label>閱讀狀態</label>
    <div class="filter-pills" id="favStatusFilter">
      <span class="pill active" data-val="">全部</span>
      <span class="pill" data-val="want">想看</span>
      <span class="pill" data-val="owned">已入手</span>
      <span class="pill" data-val="done">讀完</span>
    </div>
  </div>
</div>
```

- [ ] **Step 4: 修改 Tab 切換邏輯**

修改 source tab click handler，將現有的 `pccrFiltersEl` / `threadsFiltersEl` 切換邏輯改為支援三個 Tab：

將現有的 tab click handler 替換為：

```javascript
document.querySelectorAll('.source-tab').forEach(tab=>{
  tab.addEventListener('click',()=>{
    document.querySelectorAll('.source-tab').forEach(t=>t.classList.remove('active'));
    tab.classList.add('active');
    currentSource=tab.dataset.source;
    resetFilters();
    pccrFiltersEl.style.display=currentSource==='pccr'?'':'none';
    threadsFiltersEl.style.display=currentSource==='threads'?'':'none';
    document.getElementById('favFilters').style.display=currentSource==='favorites'?'':'none';
    if(currentSource==='pccr'){
      subtitle.textContent='教育部 / 國立臺灣圖書館 嬰幼兒閱讀推廣計畫 — 歷年入選好書 '+BOOKS.length+' 本';
    }else if(currentSource==='threads'){
      subtitle.textContent='Threads 社群推薦書單 — '+THREADS_BOOKS.length+' 本';
    }else{
      subtitle.textContent='我的收藏書單 — '+favCache.size+' 本';
    }
    render();
  });
});
```

- [ ] **Step 5: 新增收藏篩選 pill 設定**

在 `setupPills('threadsAgeFilter','age');` 後面加入：

```javascript
setupPills('favStatusFilter','favStatus');
```

同時在 `filters` 物件中加入 `favStatus` 欄位。將：

```javascript
let filters={search:'',age:'',year:'',cat:'',origin:'',classic:false};
```

改為：

```javascript
let filters={search:'',age:'',year:'',cat:'',origin:'',classic:false,favStatus:''};
```

`resetFilters` 函式也加入 `favStatus:''`。

- [ ] **Step 6: 新增收藏狀態更新函式**

在 JS 區加入：

```javascript
async function updateFavStatus(bookName,source,newStatus){
  const key=bookName+':'+source;
  const fav=favCache.get(key);
  if(!fav)return;
  await sb.from('favorites').update({status:newStatus,updated_at:new Date().toISOString()}).eq('id',fav.id);
  fav.status=newStatus;
  render();
}
```

- [ ] **Step 7: 修改 render 函式支援收藏 Tab**

將 `render()` 函式改為：

```javascript
function render(){
  let matched;
  if(currentSource==='favorites'){
    matched=Array.from(favCache.values());
    if(filters.search){
      const s=filters.search;
      matched=matched.filter(f=>f.book_name.toLowerCase().includes(s));
    }
    if(filters.favStatus){
      matched=matched.filter(f=>f.status===filters.favStatus);
    }
    resultCount.textContent=matched.length;
    if(matched.length===0){
      bookList.innerHTML='<div class="no-result">沒有收藏的書籍</div>';
      return;
    }
    bookList.innerHTML=matched.map(renderFavCard).join('');
  }else{
    matched=getActiveBooks().filter(matchBook);
    resultCount.textContent=matched.length;
    if(matched.length===0){
      bookList.innerHTML='<div class="no-result">沒有找到符合條件的書籍</div>';
      return;
    }
    bookList.innerHTML=matched.map(renderCard).join('');
  }
}
```

- [ ] **Step 8: 新增收藏卡片 render 函式**

在 JS 區加入：

```javascript
function renderFavCard(fav){
  const b=fav.book_data;
  const statusLabels={want:'想看',owned:'已入手',done:'讀完'};
  const statusClass={want:'tag-want',owned:'tag-owned',done:'tag-done'};

  const tags=[];
  if(b.ag)tags.push(`<span class="tag tag-age">${b.ag}歲</span>`);
  tags.push(`<span class="tag ${statusClass[fav.status]}">${statusLabels[fav.status]}</span>`);
  if(fav.book_source==='threads'&&b.cat)tags.push(`<span class="tag tag-cat">${b.cat}</span>`);

  let meta='';
  if(b.a)meta+=`<span><span class="label">作者</span>${b.a}</span>`;
  if(b.p)meta+=` <span><span class="label">出版</span>${b.p}</span>`;

  const bn=fav.book_name.replace(/"/g,'&quot;');
  const bs=fav.book_source;
  const statusBtns=`<div class="status-btns">
    <button class="status-btn${fav.status==='want'?' current tag-want':''}" onclick="updateFavStatus('${bn}','${bs}','want')">想看</button>
    <button class="status-btn${fav.status==='owned'?' current tag-owned':''}" onclick="updateFavStatus('${bn}','${bs}','owned')">已入手</button>
    <button class="status-btn${fav.status==='done'?' current tag-done':''}" onclick="updateFavStatus('${bn}','${bs}','done')">讀完</button>
  </div>`;

  let actions='';
  actions+=`<a class="act act-momo" href="https://www.momoshop.com.tw/search/searchShop.jsp?keyword=${enc(b.n||fav.book_name)}" target="_blank" rel="noopener">momo</a>`;
  actions+=`<a class="act act-eslite" href="https://www.eslite.com/Search?keyword=${enc(b.n||fav.book_name)}" target="_blank" rel="noopener">誠品</a>`;
  actions+=`<a class="act act-books" href="https://search.books.com.tw/search/query/key/${enc(b.n||fav.book_name)}" target="_blank" rel="noopener">博客來</a>`;
  actions+=`<a class="act act-shopee" href="https://shopee.tw/search?keyword=${enc(b.n||fav.book_name)}" target="_blank" rel="noopener">蝦皮</a>`;

  const cardClass=fav.book_source==='threads'?'book-card threads-src':'book-card';

  return `<div class="${cardClass}">
    ${starHtml(fav.book_name,fav.book_source,b)}
    <div class="title">${b.n||fav.book_name}</div>
    <div class="tags">${tags.join('')}</div>
    ${meta?`<div class="meta">${meta}</div>`:''}
    ${statusBtns}
    <div class="actions">${actions}</div>
  </div>`;
}
```

- [ ] **Step 9: 瀏覽器驗證**

確認（需 Supabase 已設定好）：
- 登入後出現「我的收藏」Tab
- 點星號收藏書籍 → 星號變金色實心
- 進入收藏 Tab → 顯示收藏的書
- 狀態篩選 pills（全部/想看/已入手/讀完）正常運作
- 點狀態按鈕可切換（想看→已入手→讀完）
- 取消收藏後卡片消失
- 登出後收藏 Tab 消失

- [ ] **Step 10: Commit**

```bash
git add index.html
git commit -m "feat: add favorites tab with reading status tracking"
```

---

## Task 6: 整合測試 + 部署

**Files:**
- Modify: `index.html`（如有修正）

- [ ] **Step 1: 端到端測試清單**

手動測試以下場景：

1. 未登入 → 點星號 → 出現登入提示面板 → 「稍後再說」關閉面板
2. 未登入 → 面板中點 Google 登入 → 跳轉 Google → 登入成功回到網站
3. 已登入 → Header 顯示名字和頭像
4. 已登入 → 點星號收藏 → 星號變實心 → 收藏 Tab 計數 +1
5. 已登入 → 再點星號 → 取消收藏 → 星號變空心 → 收藏 Tab 計數 -1
6. 已登入 → 切到 Threads Tab → 收藏 → 切到收藏 Tab → 書在那裡
7. 收藏 Tab → 點「已入手」按鈕 → 狀態標籤變橘色
8. 收藏 Tab → 篩選「讀完」→ 只顯示讀完的書
9. 收藏 Tab → 搜尋書名 → 正確過濾
10. 登出 → 收藏 Tab 消失 → 星號全部變空心
11. 蝦皮按鈕 → 開啟蝦皮搜尋頁面
12. 手機版 → 確認 Tab、星號、登入提示面板的 RWD 佈局

- [ ] **Step 2: 替換 Supabase credentials**

確認 `__SUPABASE_URL__` 和 `__SUPABASE_ANON_KEY__` 已替換為真實值。

- [ ] **Step 3: 最終 Commit**

```bash
git add index.html
git commit -m "chore: finalize Supabase credentials for production"
```

- [ ] **Step 4: 部署到 GitHub Pages**

```bash
git push origin main
```

確認 `https://kuolun.github.io/pccr-books/` 正常載入。

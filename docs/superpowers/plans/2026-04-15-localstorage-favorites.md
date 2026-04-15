# localStorage Favorites Migration — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Supabase auth + database favorites with pure localStorage — zero login, zero network, instant response.

**Architecture:** Single-file change to `index.html`. Remove Supabase SDK + all auth code (~120 lines). Replace with ~20 lines of localStorage read/write. The `favCache` Map stays as the in-memory store, backed by localStorage instead of Supabase.

**Tech Stack:** Vanilla JS, localStorage API, no external dependencies.

**Note on innerHTML usage:** This codebase uses innerHTML for rendering book cards with trusted data (hardcoded book arrays). All user-facing text is escaped via the existing `esc()` function. This is an accepted pattern for this static site.

---

## File Structure

Only one file changes:

- **Modify:** `index.html` — remove Supabase/auth code, add localStorage functions, update HTML/CSS

---

### Task 1: Remove Supabase SDK, auth HTML, and auth CSS

**Files:**
- Modify: `index.html:79-92` (CSS), `index.html:112` (responsive CSS), `index.html:118-123` (header auth area HTML), `index.html:251-265` (login prompt HTML), `index.html:267` (Supabase CDN script tag)

- [ ] **Step 1: Remove auth CSS rules (lines 79-92, 112)**

Delete these CSS rules:
```css
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

And in the `@media(max-width:600px)` block, delete:
```css
  .auth-area{position:static;text-align:center;margin-top:0.5rem}
```

- [ ] **Step 2: Remove auth area from header HTML (lines 118-123)**

Change the header to remove the auth area div:
```html
<div class="header">
  <h1>嬰幼兒好書快速查詢</h1>
  <p id="subtitle">教育部 / 國立臺灣圖書館 嬰幼兒閱讀推廣計畫 — 歷年入選好書 848 本</p>
</div>
```

- [ ] **Step 3: Remove login prompt overlay HTML (lines 251-265)**

Delete the entire login prompt overlay div (id="loginPrompt") and all its children.

- [ ] **Step 4: Remove Supabase CDN script tag (line 267)**

Delete the supabase-js script tag.

- [ ] **Step 5: Make favorites tab always visible (line 129)**

Remove `style="display:none"` from the favorites tab button:
```html
<button class="source-tab" data-source="favorites" id="favTab">我的收藏 <span class="tab-count">0</span></button>
```

- [ ] **Step 6: Commit**

```
git add index.html
git commit -m "refactor: remove Supabase SDK, auth HTML, and auth CSS"
```

---

### Task 2: Remove all Supabase/auth JavaScript, add localStorage functions

**Files:**
- Modify: `index.html` (script section)

- [ ] **Step 1: Remove Supabase init and auth variables (lines 269-275)**

Delete SUPABASE_URL, SUPABASE_ANON_KEY, sb client creation, currentUser, and favCache.

Replace with:
```js
const FAV_KEY='pccr-favs';
function loadFavs(){
  try{return new Map(Object.entries(JSON.parse(localStorage.getItem(FAV_KEY)||'{}')))}
  catch{return new Map()}
}
function saveFavs(){
  try{localStorage.setItem(FAV_KEY,JSON.stringify(Object.fromEntries(favCache)))}
  catch(e){console.error('saveFavs failed:',e)}
}
let favCache=loadFavs();
```

- [ ] **Step 2: Remove auth functions (lines 527-556)**

Delete `loginWithGoogle()`, `logout()`, and `updateAuthUI()` functions entirely.

- [ ] **Step 3: Remove Supabase loadFavorites (lines 557-570)**

Delete `_loadingFavs` flag and `loadFavorites()` function entirely.

- [ ] **Step 4: Simplify updateFavTab (lines 572-581)**

Replace with:
```js
function updateFavTab(){
  const tab=document.getElementById('favTab');
  if(tab)tab.querySelector('.tab-count').textContent=favCache.size;
}
```

- [ ] **Step 5: Remove session/timeout helpers (lines 587-607)**

Delete `_toggling`, `withTimeout()`, `sessionExpired()`, and `ensureSession()` entirely.

- [ ] **Step 6: Rewrite toggleFav as sync function (lines 608-637)**

Replace entire async toggleFav with:
```js
function toggleFav(bookName,source){
  const key=bookName+':'+source;
  if(favCache.has(key))favCache.delete(key);
  else favCache.set(key,'want');
  saveFavs();
  updateFavTab();
  render();
}
```

- [ ] **Step 7: Rewrite updateFavStatus as sync function (lines 650-660)**

Replace entire async updateFavStatus with:
```js
function updateFavStatus(bookName,source,newStatus){
  favCache.set(bookName+':'+source,newStatus);
  saveFavs();
  updateFavTab();
  render();
}
```

- [ ] **Step 8: Remove onAuthStateChange listener (lines 664-674)**

Delete the entire `sb.auth.onAuthStateChange(...)` block.

- [ ] **Step 9: Remove login prompt and loginBtn event listeners (lines 695-699)**

Delete the three event listener lines for promptLoginBtn, promptDismissBtn, and loginBtn.

- [ ] **Step 10: Remove dbg function (line 702)**

Delete `function dbg(msg){console.log('[pccr]',msg);}`.

- [ ] **Step 11: Commit**

```
git add index.html
git commit -m "refactor: replace Supabase auth/favorites with localStorage"
```

---

### Task 3: Update event handlers and renderFavCard

**Files:**
- Modify: `index.html` (script section)

- [ ] **Step 1: Simplify star click handler in event delegation**

Change the bookList click handler to remove async/await and simplify:
```js
bookList.addEventListener('click',(e)=>{
  const star=e.target.closest('.fav-star');
  if(star){
    toggleFav(star.dataset.favName,star.dataset.favSource);
    return;
  }
  const statusBtn=e.target.closest('.status-btn');
  if(statusBtn){
    const{bn,bs,st}=statusBtn.dataset;
    if(bn&&bs&&st)updateFavStatus(bn,bs,st);
  }
});
```

- [ ] **Step 2: Rewrite renderFavCard to use localStorage data**

Replace the current `renderFavCard(fav)` function with new signature `renderFavCard(bookName, source, status)`:
```js
function renderFavCard(bookName,source,status){
  const b=findBookData(bookName,source);
  const statusLabels={want:'想看',owned:'已入手',done:'讀完'};
  const statusClass={want:'tag-want',owned:'tag-owned',done:'tag-done'};

  const tags=[];
  if(b.ag)tags.push('<span class="tag tag-age">'+b.ag+'歲</span>');
  tags.push('<span class="tag '+statusClass[status]+'">'+statusLabels[status]+'</span>');
  if(source==='threads'&&b.cat)tags.push('<span class="tag tag-cat">'+b.cat+'</span>');

  let meta='';
  if(b.a)meta+='<span><span class="label">作者</span>'+b.a+'</span>';
  if(b.p)meta+=' <span><span class="label">出版</span>'+b.p+'</span>';

  const bn=esc(bookName);
  const statusBtns='<div class="status-btns">'
    +'<button class="status-btn'+(status==='want'?' current tag-want':'')+'" data-bn="'+bn+'" data-bs="'+source+'" data-st="want">想看</button>'
    +'<button class="status-btn'+(status==='owned'?' current tag-owned':'')+'" data-bn="'+bn+'" data-bs="'+source+'" data-st="owned">已入手</button>'
    +'<button class="status-btn'+(status==='done'?' current tag-done':'')+'" data-bn="'+bn+'" data-bs="'+source+'" data-st="done">讀完</button>'
    +'</div>';

  let actions='';
  actions+='<a class="act act-momo" href="https://www.momoshop.com.tw/search/searchShop.jsp?keyword='+enc(bookName)+'" target="_blank" rel="noopener">momo</a>';
  actions+='<a class="act act-eslite" href="https://www.eslite.com/Search?keyword='+enc(bookName)+'" target="_blank" rel="noopener">誠品</a>';
  actions+='<a class="act act-books" href="https://search.books.com.tw/search/query/key/'+enc(bookName)+'" target="_blank" rel="noopener">博客來</a>';
  actions+='<a class="act act-shopee" href="https://shopee.tw/search?keyword='+enc(bookName)+'" target="_blank" rel="noopener">蝦皮</a>';

  const cardClass=source==='threads'?'book-card threads-src':'book-card';

  return '<div class="'+cardClass+'">'
    +starHtml(bookName,source)
    +'<div class="title">'+(b.n||bookName)+'</div>'
    +'<div class="tags">'+tags.join('')+'</div>'
    +(meta?'<div class="meta">'+meta+'</div>':'')
    +statusBtns
    +'<div class="actions">'+actions+'</div>'
    +'</div>';
}
```

Note: `findBookData` fallback returns `{n: bookName}` when book not found — this renders just the name with purchase links.

- [ ] **Step 3: Update render() favorites branch to use new renderFavCard signature**

Replace the favorites branch in render() with:
```js
if(currentSource==='favorites'){
    let entries=Array.from(favCache.entries()).map(([k,status])=>{
      const i=k.lastIndexOf(':');
      return{bookName:k.slice(0,i),source:k.slice(i+1),status};
    });
    if(filters.search){
      const s=filters.search;
      entries=entries.filter(e=>e.bookName.toLowerCase().includes(s));
    }
    if(filters.favStatus){
      entries=entries.filter(e=>e.status===filters.favStatus);
    }
    resultCount.textContent=entries.length;
    if(entries.length===0){
      bookList.innerHTML='<div class="no-result">沒有收藏的書籍</div>';
      return;
    }
    bookList.innerHTML=entries.map(e=>renderFavCard(e.bookName,e.source,e.status)).join('');
```

- [ ] **Step 4: Add updateFavTab() before render() at end of script**

Change the end of script from:
```js
render();
```

To:
```js
updateFavTab();
render();
```

- [ ] **Step 5: Verify favorites tab subtitle in tab click handler**

In the tab click handler, verify the favorites subtitle reads:
```js
subtitle.textContent='我的收藏書單 — '+favCache.size+' 本';
```

No change needed if already correct.

- [ ] **Step 6: Commit**

```
git add index.html
git commit -m "feat: wire up localStorage favorites with updated render and event handlers"
```

---

### Task 4: Verify and clean up

**Files:**
- Modify: `index.html`

- [ ] **Step 1: Run syntax validation**

```bash
node -e "
var html=require('fs').readFileSync('index.html','utf8');
var m=html.match(/<script>([\s\S]*?)<\/script>/);
try{Function(m[1]);console.log('OK: JS syntax valid')}catch(e){console.log('FAIL:',e.message);process.exit(1)}
console.log(!html.includes('supabase')?'OK: No supabase refs':'FAIL: supabase refs remain');
console.log(!html.includes('currentUser')?'OK: No currentUser':'FAIL: currentUser remains');
console.log(!html.includes('loginPrompt')?'OK: No loginPrompt':'FAIL: loginPrompt remains');
console.log(!html.includes('authArea')?'OK: No authArea':'FAIL: authArea remains');
console.log(html.includes('pccr-favs')?'OK: Has FAV_KEY':'FAIL: Missing FAV_KEY');
console.log(html.includes('loadFavs')?'OK: Has loadFavs':'FAIL: Missing loadFavs');
console.log(html.includes('saveFavs')?'OK: Has saveFavs':'FAIL: Missing saveFavs');
"
```

Expected: all OK

- [ ] **Step 2: Verify no orphaned references**

Search for any remaining references to removed code:
```bash
grep -n "currentUser\|loginWith\|signOut\|signIn\|ensureSession\|withTimeout\|_toggling\|_loadingFavs\|sb\.\|SUPABASE\|authArea\|loginPrompt\|promptLoginBtn\|promptDismissBtn\|loginBtn\|logoutBtn\|dbg(" index.html
```

Expected: no output (zero matches)

- [ ] **Step 3: Test in local server**

```bash
python3 -m http.server 8080 &
curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/
```

Expected: `200`

- [ ] **Step 4: Commit and push**

```
git add index.html
git commit -m "chore: verify clean removal of Supabase dependencies"
git push origin main
```

---

### Task 5: Manual E2E browser test

Open https://kuolun.github.io/pccr-books/ after GitHub Pages deploys (~2 min) and verify:

- [ ] **Step 1: Page loads instantly** — 848 books visible, no loading delay, no console errors (F12)
- [ ] **Step 2: Favorites tab visible** — 「我的收藏 0」tab always shown (no login needed)
- [ ] **Step 3: Click star to favorite** — star turns solid, favorites count increments
- [ ] **Step 4: Switch to favorites tab** — favorited book appears with status buttons
- [ ] **Step 5: Change reading status** — click 已入手 / 讀完, tag color changes
- [ ] **Step 6: Unfavorite** — click star again, star becomes empty, count decrements
- [ ] **Step 7: Refresh page** — favorites persist after reload (localStorage)
- [ ] **Step 8: No auth UI** — no login button, no logout button, no login prompt overlay
- [ ] **Step 9: Console clean** — no errors, no Supabase references in Network tab

# 收藏功能改用 localStorage 設計規格

## 背景

目前收藏功能依賴 Supabase（PostgreSQL + Google OAuth），但遇到多個穩定性問題：
- Session 過期後 API call timeout，星星點了沒反應
- signOut promise 掛住，登出無效
- loadFavorites 無 timeout 保護，收藏載入失敗
- 瀏覽器擴充套件擋 `*.supabase.co` 請求
- 部分家長沒有 Google 帳號，無法使用收藏功能

**決策：** 移除 Supabase，改用純 localStorage。不需要跨裝置同步。

## 資料結構

```js
// localStorage key: 'pccr-favs'
// value: JSON string of object
// key = "bookName:source", value = reading status string
{
  "好餓的毛毛蟲:pccr": "want",
  "Dear Zoo:threads": "owned",
  "小波在哪裡:threads": "done"
}
```

- 閱讀狀態：`"want"`（想看）、`"owned"`（已入手）、`"done"`（讀完）
- 不儲存完整 book_data — 需要時從 `BOOKS` / `THREADS_BOOKS` 陣列查找
- 預估容量：1000 本書 × ~50 bytes/entry ≈ 50KB，遠低於 localStorage 5MB 上限

## 要移除的項目

### JavaScript
- `SUPABASE_URL`、`SUPABASE_ANON_KEY` 常數
- `sb` Supabase client 建立
- `currentUser` 變數
- `loginWithGoogle()` 函數
- `logout()` 函數
- `updateAuthUI()` 函數
- `ensureSession()` 函數
- `sessionExpired()` 函數
- `withTimeout()` 函數
- `_loadingFavs`、`_toggling` guard flags
- `sb.auth.onAuthStateChange()` listener
- `dbg()` 函數
- Login prompt button event listeners（promptLoginBtn、promptDismissBtn）
- Initial loginBtn event listener
- URL hash 清除邏輯（access_token）

### HTML
- `<script src="...supabase-js...">` CDN 載入
- Auth area（`#authArea`，包含登入/登出 UI）
- Login prompt overlay（`#loginPrompt`）

### CSS
- `.auth-area`、`.auth-user`、`.logout-btn` 樣式
- `.login-prompt-overlay`、`.login-prompt`、`.google-btn`、`.dismiss-btn` 樣式

## 要保留並改寫的項目

### `favCache` (Map)
- 保留為 `Map<string, string>`（key → status）
- 頁面載入時從 localStorage 初始化
- 每次修改後同步寫回 localStorage

### `toggleFav(bookName, source)`
- 改為同步函數（非 async）
- 移除 ensureSession / withTimeout / Supabase API call
- 直接操作 favCache + saveFavs()

### `updateFavStatus(bookName, source, newStatus)`
- 改為同步函數
- 直接操作 favCache + saveFavs()

### `loadFavorites()`
- 改為同步函數 `loadFavs()`
- 從 localStorage 讀取 JSON，轉為 Map
- 加 try/catch 處理 JSON parse 失敗（資料損壞時回傳空 Map）

### 「我的收藏」tab
- **永遠顯示**（不再受登入狀態控制）
- `updateFavTab()` 簡化為只更新數量

### 星星按鈕、閱讀狀態按鈕
- UI 不變
- Event delegation 不變（bookList click handler）
- 移除 toggleFav 中的 `if(!currentUser)` 登入檢查

### `renderFavCard(fav)`
- 參數從 `fav` object (Supabase row) 改為 `{bookName, source, status}`
- 從 BOOKS/THREADS_BOOKS 查找書籍資料來渲染

## 新增的核心程式碼

```js
const FAV_KEY = 'pccr-favs';

function loadFavs() {
  try {
    return new Map(Object.entries(JSON.parse(localStorage.getItem(FAV_KEY) || '{}')));
  } catch { return new Map(); }
}

function saveFavs() {
  try { localStorage.setItem(FAV_KEY, JSON.stringify(Object.fromEntries(favCache))); }
  catch(e) { console.error('saveFavs failed:', e); }
}

let favCache = loadFavs();

function toggleFav(bookName, source) {
  const key = bookName + ':' + source;
  if (favCache.has(key)) favCache.delete(key);
  else favCache.set(key, 'want');
  saveFavs();
  updateFavTab();
  render();
}

function updateFavStatus(bookName, source, status) {
  favCache.set(bookName + ':' + source, status);
  saveFavs();
  updateFavTab();
  render();
}

function isFav(bookName, source) {
  return favCache.has(bookName + ':' + source);
}
```

## UI 變更

- Header 右上角移除登入/登出區域
- 「我的收藏」tab 永遠顯示（帶數字 badge）
- 未登入點星星不再彈出登入提示 — 直接收藏
- Login prompt overlay 整個移除

## 不變的部分

- 書籍卡片樣式和結構
- 搜尋和篩選功能
- Tab 切換（PCCR / Threads / 我的收藏）
- 閱讀狀態按鈕和對應 CSS class
- 星星圖示和 hover 效果
- Event delegation 架構

## Supabase 資料遷移

現有 Supabase 用戶的收藏資料將無法自動遷移至 localStorage。

- 目前使用量極低（測試階段），影響範圍可忽略
- Supabase 資料庫不刪除，資料仍保留在 server 上
- 不做自動遷移機制（投入產出比不划算）

## 已知限制

- 資料只存在該瀏覽器的 localStorage，清除瀏覽器資料會丟失
- 無痕模式下收藏不會保留
- 不支援跨裝置同步
- localStorage 寫入可能在空間不足或隱私模式下失敗（saveFavs 有 try/catch）
- 這些限制已被接受，未來如有需求可加匯出功能

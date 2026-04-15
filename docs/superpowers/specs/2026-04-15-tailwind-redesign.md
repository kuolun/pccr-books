# Tailwind CSS 日系風格重新設計

## 風格：奶油抹茶

溫暖圓潤的日系親切風格。大圓角卡片、pill 標籤、柔和漸層。

## 配色

| 用途 | 色碼 | Tailwind |
|------|------|----------|
| 頁面底色 | `#f6f1eb` | `bg-cream` |
| 主色 | `#5b8c5a` | `bg-matcha` |
| 主色淺 | `#7ab87a` | `bg-matcha-light` |
| 文字深 | `#3d3d3d` | `text-stone-800` |
| 文字淺 | `#9a9a9a` | `text-stone-400` |
| 邊框 | `#e8e0d4` | `border-sand` |
| 星星 | `#d4a853` | `text-amber-500` |

## 元件設計

- **Header**：抹茶綠漸層（`#5b8c5a` → `#7ab87a`），白字，`rounded-2xl`
- **Tabs**：active = 抹茶綠 pill 白字，inactive = 白底綠框，`rounded-full`
- **卡片**：白底，`rounded-2xl`，`shadow-sm`，hover `shadow-md`，移除左邊框
- **Tag**：pill `rounded-full`，各分類不同淡色背景
- **搜尋框**：`rounded-xl`，大圓角
- **篩選**：pill 按鈕組
- **購書連結**：小 pill 按鈕，各平台不同顏色

## RWD

- 電腦：`lg:grid-cols-3`
- 平板：`md:grid-cols-2`
- 手機：`grid-cols-1`，篩選垂直排列

## 實作

- CDN：`<script src="https://cdn.tailwindcss.com">`
- 自訂色票用 `tailwind.config`
- 移除現有 `<style>` 全部 CSS
- JS 邏輯不動，只改 HTML class
- render 函數中的 HTML template 改用 Tailwind class

# 10 — Nội dung App Store (日本語 · English · Tiếng Việt)

> Bản nháp để dán vào App Store Connect, mỗi ngôn ngữ một bản địa hoá (Japanese, English (U.S.), Vietnamese).
> Giới hạn dùng ở đây: tên 30 ký tự, phụ đề 30, văn bản quảng cáo 170, mô tả 4000; **từ khoá 100 byte** (UTF-8 — chữ Nhật
> 3 byte, chữ Việt có dấu 2–3 byte mỗi chữ). Dãy từ khoá dưới đây đều ≤ 100 byte. **Cần kiểm tra** giới hạn và quy định
> metadata mới nhất của Apple trước khi nộp. Câu tiếng Nhật nên nhờ người bản ngữ đọc lại.
> Cập nhật 2026-10-02.

## Nguyên tắc

- Chỉ nói những gì app **đã làm được** (README, `docs/06`). Chưa có thì không nhắc: đọc ảnh hoá đơn, đồng bộ iCloud,
  biểu đồ tháng, danh mục tuỳ chỉnh…
- Không hứa "2 giây" hay con số tốc độ nào cho tới khi có trung vị thật từ TestFlight (`EntryTimingLog`, `docs/01`).
  Khi có số đo thì mới cân nhắc tên kiểu "Xu – Ghi chi tiêu 2 giây" (`docs/07`).
- Không ghi giá Xu Pro: App Store tự hiện giá theo từng nước (`docs/07`).
- Không nêu tên app khác, không so sánh.
- Apple Pay: nói rõ là tự động hoá người dùng tự cài trong app Phím tắt, không phải Xu đọc thẻ.
- Câu ví dụ lấy từ những câu parser đã có test (`JapanMarketTests`, `QuickEntryParserTests`).
- Xu Pro: mở cả **5 thói quen có sẵn** (`HabitTemplate`) cùng lúc, không phải "không giới hạn" — chưa có thói quen tự tạo.
  Sửa danh mục là **chạm để chọn lại** (2 chạm), không nói "một chạm".

## 日本語

**App名**(30字以内): `Xu – ひと言で家計簿`

**サブタイトル**(30字以内): `銀行連携なし・データは端末内だけ`

**キーワード**(100バイト以内、カンマ区切り、App名の語は入れない。86バイト):
`支出,記録,節約,予算,小遣い帳,習慣,ウィジェット,円,オフライン`

**プロモーションテキスト**(170字以内):
「コーヒー 350円」と打つだけで記録完了。ホーム画面のウィジェットからワンタップでも記録できます。アカウント不要、データはiPhoneの中だけ。

**説明**:

```
「コーヒー 350円」「昨日 電車 220」——ひと言打つだけで、Xuが金額・日付・カテゴリを読み取って記録します。

■ すばやく記録
・文章で入力:「家賃 6万5千円」「千五百円 ランチ」「9月20日 スーパー 2480」のような漢数字や日付もそのまま
・カテゴリが違ったらタップして選び直すだけ。次からは覚えます
・ホーム画面のウィジェット:いつもの支出をワンタップで記録(アプリを開かずに)
・ショートカット/アクションボタン:「支出を記録」をすぐ呼び出せます
・Apple Pay:ショートカットAppのオートメーションを設定すると、カード払いを自動で記録(設定ガイドつき)

■ 続けられる仕組み
・月の予算から「今日あといくら使えるか」を表示
・夜の締めリマインダー、習慣の強さ、週のふりかえり
・責めない言葉づかい。使いすぎても赤字で叱りません

■ プライバシー
・銀行連携なし、アカウント登録なし。データはこのiPhoneの中だけ
・広告・トラッキング・アクセス解析なし
・CSVでいつでも無料で書き出し

■ 円とドンに対応
日本で使うなら円、ベトナムで使うならドン。表示言語は日本語・英語・ベトナム語から選べます。

■ Xu Pro(買い切り・サブスクなし)
用意された5つの習慣をすべて同時に続けられ、ウィジェットに「いつもの」を最大4件表示。記録・アプリ内の「いつもの」・ショートカット・CSV書き出しはずっと無料です。
```

## English

**Name** (≤30): `Xu – Expense Log in One Line`

**Subtitle** (≤30): `No bank link. Stays on device`

**Keywords** (≤100 bytes, comma-separated, no words from the name; 92 bytes):
`spending,tracker,budget,money,habit,widget,shortcut,quick,offline,yen,dong,japan,vietnam,csv`

**Promotional text** (≤170):
Type "coffee 350" and you're done. Log from a Home Screen widget with one tap. No account, no bank link — your data stays on your iPhone.

**Description**:

```
Type "coffee 350" or "train 220 yesterday" — Xu reads the amount, date and category and logs it.

QUICK LOGGING
• Plain sentences: amounts, dates like "yesterday", and Japanese formats such as 6万5千円
• Wrong category? Tap to pick another — Xu remembers next time
• Home Screen widget: log your usual expenses with one tap, without opening the app
• Shortcuts and the Action Button: "Log expense" is ready to go
• Apple Pay: set up an automation in the Shortcuts app to log card payments automatically (step-by-step guide included)

HABITS THAT STICK
• See how much you can still spend today, based on your monthly budget
• Evening day-close reminder, habit strength, weekly look-back
• No guilt: no red warnings when you overspend

PRIVATE BY DESIGN
• No bank link, no account. Your data stays on this iPhone
• No ads, no tracking, no analytics
• Export CSV any time, for free

YEN AND DONG
Use yen in Japan or dong in Vietnam. Choose Vietnamese, English or Japanese for the app.

XU PRO — PAY ONCE, NO SUBSCRIPTION
Track all 5 built-in habits at once and show up to 4 quick picks on the widget. Logging, quick picks in the app, Shortcuts and CSV export are always free.
```

## Tiếng Việt

**Tên** (≤30): `Xu – Ghi chi tiêu một câu`

**Phụ đề** (≤30): `Không liên kết ngân hàng`

**Từ khoá** (≤100 byte, không lặp từ đã có trong tên như "ghi", "chi", "tiêu"; 88 byte):
`quản lý,sổ thu,tiết kiệm,ngân sách,thói quen,tài chính,widget,yên,offline`

**Văn bản quảng cáo** (≤170):
Gõ "cà phê 35k" là xong. Chạm một lần trên widget màn hình chính cũng ghi được. Không tài khoản, không liên kết ngân hàng, dữ liệu nằm trên iPhone của bạn.

**Mô tả**:

```
Gõ "cà phê 35k" hay "grab 52k hôm qua", Xu tự hiểu số tiền, ngày và danh mục rồi ghi lại.

GHI NHANH
• Gõ như nói: "35k", "1tr2", "lương +15tr", "hôm qua", "thứ 2"…
• Đoán sai danh mục thì chạm để chọn lại, lần sau Xu nhớ
• Widget màn hình chính: chạm một lần để ghi khoản quen, không cần mở app
• Phím tắt và Action Button: "Ghi chi tiêu" có sẵn
• Apple Pay: cài tự động hoá trong app Phím tắt để tự ghi khi quẹt thẻ (có hướng dẫn từng bước)

THÓI QUEN, KHÔNG TỘI LỖI
• Biết hôm nay còn được tiêu bao nhiêu theo ngân sách tháng
• Nhắc chốt ngày buổi tối, sức mạnh thói quen, nhìn lại tuần
• Không trách móc, không màu đỏ khi tiêu quá

RIÊNG TƯ
• Không liên kết ngân hàng, không tài khoản. Dữ liệu nằm trên iPhone này
• Không quảng cáo, không theo dõi, không công cụ phân tích
• Xuất CSV bất cứ lúc nào, miễn phí

ĐỒNG VÀ YÊN
Ở Việt Nam ghi bằng đồng, ở Nhật ghi bằng yên. Giao diện tiếng Việt, tiếng Anh hoặc tiếng Nhật.

XU PRO — MUA MỘT LẦN, KHÔNG THUÊ BAO
Theo dõi cả 5 thói quen có sẵn cùng lúc, widget hiện tới 4 khoản quen. Ghi chép, khoản quen trong app, Phím tắt và xuất CSV luôn miễn phí.
```

## Ảnh chụp màn hình

Theo 5 thông điệp trong `docs/07`, chụp với giao diện và nơi chi tiêu đúng từng thị trường (Nhật: yên, câu tiếng Nhật).

| # | 日本語 | English | Tiếng Việt |
|---|---|---|---|
| 1 | 「コーヒー 350円」で記録完了 | Type "coffee 350". Done. | Gõ "cà phê 35k". Xong. |
| 2 | ホーム画面からワンタップ | One tap from your Home Screen | Chạm 1 lần trên màn hình chính |
| 3 | 今日あといくら使える? | How much is left for today? | Biết hôm nay còn được tiêu bao nhiêu |
| 4 | 責めない習慣づくり | Build habits, without guilt | Xây thói quen, không cảm giác tội lỗi |
| 5 | 銀行連携なし。データはあなたのもの | No bank link. Your data is yours. | Không liên kết ngân hàng. Dữ liệu là của bạn. |

## Cần kiểm tra trước khi nộp

- [ ] Giới hạn ký tự và quy định metadata của App Store Connect — bản mới nhất.
- [ ] Tên "Xu" (và tên đầy đủ ở trên) còn dùng được ở từng nước.
- [ ] Kích thước, số lượng ảnh chụp màn hình Apple yêu cầu — bản mới nhất.
- [ ] Người bản ngữ Nhật đọc lại phần 日本語.
- [ ] Mọi câu ví dụ trong mô tả chạy đúng trên bản build nộp (ghi thử từng câu).
- [ ] Câu lệnh Siri/Phím tắt và tự động hoá Apple Pay đã thử trên máy thật trước khi nhắc trong mô tả.

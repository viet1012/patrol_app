# S-Patrol (`chuphinh`)

S-Patrol là ứng dụng Flutter, chạy chủ yếu trên **web**. Ứng dụng dùng cho:

- Tuần tra an toàn (HSE Patrol)
- Audit an toàn (SRG)
- Tuần tra chất lượng (QA)
- Tuần tra máy (MA)
- Kiểm kê tài sản cố định

Các chức năng chính là chụp ảnh, quét QR, nhập bằng giọng nói và dùng AI tóm tắt rủi ro theo máy.

- **Ngôn ngữ:** vi (mặc định), en, ja (`lib/l10n`). Nút đổi trên Home chỉ chuyển qua lại VI ↔ JP. Chuỗi được dịch bằng `'key'.tr(context)` (`lib/core/i18n/translator.dart`).
- **Thư viện chính:** go_router, dio, stomp/web_socket, syncfusion charts, excel, pdf/printing, qr_flutter, ZXing/jsQR (JS).
- Code dùng `dart:html` trực tiếp (camera, export, storage), nên hiện chỉ đảm bảo chạy trên web.

---

## Mục lục

1. [Kiến trúc & điều hướng](#1-kiến-trúc--điều-hướng)
2. [Phân quyền](#2-phân-quyền)
3. [Đăng nhập & phiên làm việc](#3-đăng-nhập--phiên-làm-việc)
4. [Home](#4-home)
5. [Patrol (Before → After → Recheck → Redo)](#5-patrol-before--after--recheck--redo)
6. [Data Table & báo cáo](#6-data-table--báo-cáo)
7. [Fixed Asset (Kiểm kê tài sản cố định)](#7-fixed-asset-kiểm-kê-tài-sản-cố-định)
8. [Thành phần dùng chung](#8-thành-phần-dùng-chung)
9. [Danh sách API](#9-danh-sách-api)
10. [Build & deploy](#10-build--deploy)
11. [Điểm cần lưu ý / chưa chắc chắn](#11-điểm-cần-lưu-ý--chưa-chắc-chắn)

---

## 1. Kiến trúc & điều hướng

```
lib/
├── app/            # router, splash, idle detector
├── core/           # api, models, network, session, permission, i18n, socket
├── features/
│   ├── auth/       # login, register, đổi/quên mật khẩu
│   ├── home/       # PatrolHomeScreen
│   ├── patrol/     # before, after, recheck, redo, summary (data table + báo cáo)
│   ├── fixed_asset/# kiểm kê, map, no_qr, replace, reprint, summary
│   └── machine_ai/ # panel AI tóm tắt rủi ro theo máy
├── shared/         # camera, qr, speech, widgets, utils
└── l10n/           # vi / en / ja
```

**Các route có URL** (`lib/app/routes/router.dart`):

| Route | Màn hình | Ghi chú |
|---|---|---|
| `/` (`?from=`) | `LoginPage` | |
| `/splash?from=` | `SplashPage` | Hiện trong lúc khôi phục phiên. |
| `/home` | `PatrolHomeScreen` | |
| `/home/summary?group=&plant=&...` | `PatrolReportTablePage` | Cần quyền `summary` của `group`. Bộ lọc nằm trong URL. |
| `/after/:qr?group=` | `AfterReportScreen` | Cần quyền `after`. Thiếu `group` thì mặc định `Patrol`. Thiếu `qr` thì hiện `_InvalidLinkPage`. |

Các màn còn lại (Before, After list, Recheck, Fixed Asset…) mở bằng `Navigator.push`, không có URL riêng.

**Guard:**

- Chưa đăng nhập thì chuyển về `/?from=<url>`.
- Đang khôi phục phiên thì chuyển về `/splash?from=<url>`.
- Không đủ quyền thì chuyển về `/home`.
- `RouteTarget.safe` chỉ nhận đường dẫn nội bộ: chặn `//` và `://`, không cho quay về login/splash.

---

## 2. Phân quyền

**`PatrolGroup`** (`lib/core/models/patrol_group.dart`). Cấu hình giao diện nằm trong `lib/core/permission/patrol_group_ui.dart`.

| PatrolGroup | Tiêu đề card | Nút trên Home |
|---|---|---|
| `Patrol` | Weekly Safety Patrol | Before, After, Recheck ("HSE ReCheck"), Data Table |
| `Audit` | SRG Safety Audit | Before, After, Recheck ("SRG Recheck"), Data Table |
| `QualityPatrol` | QA Quality Patrol | Before, After, Recheck ("QA Recheck"), Data Table |
| `AssetUpdate` | MA Machine Patrol | Before, Data Table |
| `FixedAsset` | Fixed Asset Audit | Kiểm kê (before), In lại QR (recheck), Thay QR (after), Tổng hợp (summary) |

**`PatrolAction`**:

- `before`: tạo báo cáo phát hiện lỗi
- `after`: khắc phục
- `recheck`: kiểm tra lại
- `summary`: xem bảng dữ liệu

**Cơ chế:**

- Quyền lấy từ `GET /api/hr/me?code=` và trả về `{empId, role, plant, permissions: {Group: {before, after, recheck, summary}}}`.
- Kiểm tra quyền bằng `AuthMe.can(group, action)`.
- Kết quả được cache trong bộ nhớ (`SessionStore.authMe`). Cache mất khi F5 hoặc logout.

**Cách Home áp dụng quyền:**

- Group không có quyền nào thì ẩn cả card.
- Nút không có quyền thì mờ đi và có ổ khóa.
- Tải quyền lỗi thì hiện banner kèm nút "Thử lại".
- Plant `SPC` (`kAllPlantCode`, xem tất cả nhà máy) chỉ hiện card Patrol với một nút "Data Table".

---

## 3. Đăng nhập & phiên làm việc

| Màn hình | File | Chức năng |
|---|---|---|
| `LoginPage` | `lib/features/auth/login/login_page.dart` | Xem chi tiết ngay dưới bảng. API: `/api/auth/login`, `/api/auth/check-account-exists`. |
| `RegisterBottomSheet` | `lib/features/auth/register/register_page.dart` | Nhập Employee ID, mật khẩu, xác nhận mật khẩu → `POST /api/auth/register`. Thành công thì tự điền mã NV vào form đăng nhập. |
| `ChangePasswordBottomSheet` | `lib/features/auth/login/change_password_screen.dart` | Kiểm tra tài khoản tồn tại, sau đó nhập mật khẩu cũ / mới / xác nhận → `/api/auth/change_password`. |
| `ForgotPasswordBottomSheet` | `lib/features/auth/login/forgot_password_bottom_sheet.dart` | Nhập Employee ID + Email → `/api/auth/export-password`. Mật khẩu được gửi qua Microsoft Teams. |
| `SplashPage` | `lib/app/splash/splash_page.dart` | Logo và vòng loading trong lúc `AuthSession.restore()` chạy. |

**Chi tiết `LoginPage`:**

- Đăng nhập bằng mã NV + mật khẩu, có tùy chọn "Remember me".
- Tự đăng nhập nếu đã lưu thông tin.
- Lỗi server thì tự thử lại 1 lần.
- Mất mạng thì hiện dialog "Connection Lost" và reload 1 lần.
- Để yên 30 phút thì hiện dialog "Session Idle".
- Đăng nhập xong chuyển tới `?from=`, mặc định `/home`.

**Phiên làm việc:**

- **Khôi phục phiên:** `main()` gọi `AuthSession.instance.restore()`. Hàm này đọc thông tin đã lưu (web: `localStorage`; mobile: secure storage) và đăng nhập lại. Router dùng `refreshListenable` nên F5 vẫn giữ đúng URL đích.
- **Idle:** `AppIdleDetector` (`lib/app/app_idle_detector.dart`) theo dõi thao tác. Sau 30 phút không thao tác, hiện dialog "App has been idle" với nút Reload. App kiểm tra mỗi 1 phút.
- **Phát hiện bản mới:** `main.dart` so `meta[name="app-version"]` với version lưu trong `localStorage`. Nếu khác thì tự reload.
- **Lưu theo tài khoản:** plant đã chọn (`selected_plant_<account>`) và tùy chọn giao diện (`ui_pref_*`).

---

## 4. Home

**`PatrolHomeScreen`** — `lib/features/home/patrol_home_screen.dart`

**Dữ liệu tải khi mở (song song):**

- `/api/hr/me`
- Plant đã lưu
- Master máy (`/api/hse_master`)
- Đội tuần tra (`/api/patrol_teams`)
- Tên nhân viên (`/api/hr/name`)

**Thanh trên:**

- Lời chào kèm tên nhân viên.
- `LanguageToggleSwitch` (VI ↔ JP).
- Dropdown Plant: ưu tiên plant từ HR, `SPC` luôn đứng đầu. Chọn xong thì lưu lại.

**Card Patrol / Audit / QualityPatrol / AssetUpdate:**

| Nút | Mở tới |
|---|---|
| `<prefix> Before` | `PatrolBeforeScreen` |
| Action After | `AfterOverviewScreen` |
| Recheck | `RecheckDetailScreen` |
| Data Table | `/home/summary?group=&plant=` → `PatrolReportTablePage` |

Card Patrol tự mở nếu user thuộc một đội tuần tra (`findTeamByEmp`).

**Card FixedAsset:**

| Nút | Mở tới |
|---|---|
| Kiểm kê | `FixedAssetScreen` |
| In lại QR (badge) | `FixedAssetReprintScreen` |
| Thay QR (badge) | `FixedAssetReplaceScreen` |
| Tổng hợp | `FixedAssetSummaryScreen` |

- Badge là số máy có cờ `needsQrReprint`, lấy từ `GET /api/fixed-assets/qr-mismatch`.
- Badge tải lại khi quay về Home.

**Phía dưới:**

- **Logout:** hỏi xác nhận, gọi `SessionStore.clear()`, rồi chuyển về `/`.
- **Nút quét QR:** cần quyền after của Patrol. Mở `QrScannerDialog`, quét xong chuyển tới `/after/<qr>?group=Patrol`.

---

## 5. Patrol (Before → After → Recheck → Redo)

### Luồng & trạng thái (`atStatus`)

```
Before (POST /api/report) ──► Doing
   │
After (PUT {id}/update_at) ──► Pro_Done
   │
Recheck (PUT {id}/hse_recheck) ──► OK: Closed
                               └─► NG: Redo ──► Redo (PUT {id}/update_at) ──► Recheck lại
```

- **Quá hạn (Late):** report đang `Doing`/`Redo` và `(dueDateUpdatedAt ?? dueDate) < hôm nay`.
- `Wait` và `Done` là giá trị cũ, còn xuất hiện trong mapping filter/icon.

### Chấm điểm rủi ro (`lib/core/models/risk_score_calculator.dart`)

**Patrol / Audit:** tổng điểm = Frequency + Probability + Severity.

- **Frequency (F):** often 4, sometimes 2, rare 1
- **Probability (P):** certain 6, high 4, possible 2, rare 1
- **Severity (S):** critical 10, severe 7, moderate 5, minor 3, negligible 1

Quy ra mức:

| Tổng điểm | Mức |
|---|---|
| ≥16 | V |
| ≥12 | IV |
| ≥9 | III |
| ≥6 | II |
| ≥3 | I |

Nhóm Patrol bắt buộc chọn đủ F/P/S.

**QualityPatrol** dùng bộ khác, không tính tổng:

- Frequency: often / rare
- 5M: Material / Machine / Man / Method / Measuring / 5S
- Quality Impact

Các giá trị risk được gửi lên dạng song ngữ Việt–Nhật.

### 5.1 Before — phát hiện lỗi

**`PatrolBeforeScreen`**

- **File:** `lib/features/patrol/before/patrol_before_screen.dart`, các part trong `patrol_before_screen/`: `_ai`, `_camera`, `_qr`, `_report`, `_view`, `_form_widgets`, `_models`.
- **Mở từ:** nút Before ở Home.

**Chọn vị trí:**

- Plant/Fac/Group tự điền theo đội tuần tra.
- Group / Fac / Area / Machine là dropdown có tìm kiếm, cho phép thêm giá trị mới.

**Camera** (`CameraPreviewBox`):

- Chụp ảnh: tối đa 3 ảnh (AssetUpdate tối đa 10).
- Có zoom và đèn.
- Đồng thời quét QR:
  - *QR số (Patrol):* nhận 1–5 chữ số, kiểm tra trùng qua `GET /api/report/check-qr`.
  - *QR máy:* tra `GET /api/hse_master/by-macid` để tự điền plant/fac/area/machine.
  - *AssetUpdate:* QR bất kỳ được dùng làm `qr_key`.

**AI** (`MachineAiRiskHistoryPanel`):

- Bật/tắt được.
- Khi chọn máy, hiện tóm tắt lịch sử rủi ro qua `GET /api/patrol_report/analyze-machine`.
- Có thể dịch sang JP qua `POST /api/patrol_report/translate-ai-summary`.

**Nhập nội dung:**

- **Comment / Countermeasure:** autocomplete (`/api/suggest/*`), nhập giọng nói (`VoiceInputButton`), chữ tự thu nhỏ khi dài.
- **Rủi ro:** Patrol chọn F/P/S, QualityPatrol chọn Frequency/5M/Impact. AssetUpdate ẩn phần group/area/risk.
- **"Need recheck":** checkbox.

**Validation khi gửi:**

- Bắt buộc có ít nhất 1 ảnh.
- Bắt buộc có comment.
- Patrol bắt buộc QR + Plant/Fac/Area/Machine + F/P/S.
- AssetUpdate bắt buộc QR.
- Ô thiếu thì nhấp nháy và tự cuộn tới.

**Gửi:** `POST /api/report` (multipart: `report` là JSON, `images` là các ảnh).

- Lỗi 409 / `DUPLICATE_QR` → báo QR trùng.
- Lỗi 400 `INVALID_QR` → báo QR sai.
- Thành công thì reset form.

**`EditBeforeScreen`** (`before/edit/edit_before_screen.dart`)

- Danh sách report do chính user tạo, đang `Doing`/`Redo`.
- Lọc theo Area/Risk.
- Bấm vào một dòng mở `EditDetailPage`.

**`EditDetailPage`** (`before/edit/edit_detail_page.dart`)

- Sửa group/division/area/machine, F/P/S, comment, countermeasure, need recheck → `POST {id}/edit`.
- Quản lý ảnh (tối đa 3):
  - Thêm: `POST {id}/add_image`
  - Xóa: `DELETE {id}/delete_image`
  - Chụp hoặc chọn ảnh qua `CameraEditBox`.

### 5.2 After — khắc phục

**`AfterOverviewScreen`** (`after/after_overview_screen.dart`)

- Pivot PIC × mức rủi ro (I–V, Total), cột IV và V tô đỏ.
- Lọc trạng thái Doing / Redo.
- API: `GET /api/patrol_report/pivot`.
- Bấm vào một PIC mở `AfterReportListScreen`.

**`AfterReportListScreen`** (`after/after_report_list_screen.dart`)

- Danh sách report của PIC: trạng thái, QR, Area, Machine, Risk, Deadline ("Late Nd" / "Today" / "Nd left").
- Lọc theo Area/Risk. Sắp xếp risk cao trước, rồi tới deadline.
- Report `Redo` mở `RedoDetailPage`, còn lại mở `AfterReportScreen`.

**`AfterReportScreen`** (`after/after_report_screen.dart`)

- **Mở từ:** danh sách, hoặc route `/after/:qr` (quét QR / link trực tiếp).
- **Tự chuyển màn:** report `Pro_Done` → `RecheckDetailPage`; report `Redo` → `RedoDetailPage`.
- Hiển thị ảnh và comment của Before. Ảnh thay được qua `PUT {id}/replace_image`.
- **Thao tác** (qua `POST {id}/edit`):
  - Đổi PIC
  - Assign PIC (chỉ PIC hiện tại được giao)
  - Đổi deadline (mỗi lần đổi tăng `dueDateUpdateCount`)
  - Lưu comment tạm
- **Chụp ảnh After** (`AfterCameraBox`, tối đa 2 ảnh) và nhập comment:
  - Bắt buộc có comment, ít nhất 1 ảnh, MSNV hợp lệ.
  - Gửi `PUT {id}/update_at`. Lỗi 409 thì báo xung đột.

### 5.3 Recheck — HSE kiểm tra lại

- **`RecheckDetailScreen`** (`recheck/recheck_detail_screen.dart`): pivot PIC × mức rủi ro, cố định trạng thái `Pro_Done`.
- **`RecheckPicDetailScreen`** (`recheck/recheck_pic_detail_screen.dart`): danh sách report của PIC, lọc theo Area/Risk.
- **`RecheckDetailPage`** (`recheck/recheck_detail_page.dart`):
  - So sánh BEFORE và AFTER (ảnh + comment). Đổi được PIC.
  - HSE nhập MSNV (tự tra tên), comment, chụp ảnh, rồi bấm **OK** / **NG** → `PUT {id}/hse_recheck`.
  - OK → `Closed`, NG → `Redo`.
  - Chỉ đánh giá được khi report đang `Pro_Done`.

### 5.4 Redo — làm lại

**`RedoDetailPage`** (`redo/redo_detail_page.dart`)

- Hiển thị 3 khối: BEFORE, AFTER, HSE Check (lý do NG).
- Đổi được PIC và deadline.
- Chụp lại ảnh + comment → `PUT {id}/update_at`.

### Widget dùng chung của Patrol (`features/patrol/common/`)

- **`AfterCameraBox`:** camera tối đa 2 ảnh, ảnh ra tối đa 2048px.
- **`ReplaceableImageItem` / `ReplaceImageSheet`:** xem, zoom và thay ảnh.

---

## 6. Data Table & báo cáo

### `PatrolReportTablePage` / `PatrolReportTable`

- **Files:** `lib/features/patrol/summary/patrol_report_table_page.dart` và `patrol_report_table.dart`. Logic nằm trong `summary/core/patrol_report_table_controller.dart`.
- **Route:** `/home/summary`. Trang tự tải quyền nên F5 không mất trang.
- **Dữ liệu:** tải toàn bộ report qua `GET /api/patrol_report/filter`. Lọc và phân trang làm ở client.

**Tham số URL** (`summary/core/patrol_report_table_url.dart`):

| Tham số | Ý nghĩa |
|---|---|
| `from`, `to` | Khoảng ngày (yyyy-MM-dd). Mặc định từ ngày 1 tháng trước đến hôm nay. Có chọn nhanh theo FY (1/4–31/3). |
| `q` | Tìm toàn văn |
| `page`, `rows` | Phân trang (15/30/50/100, mặc định 30) |
| `fac`, `grp` | Lọc nhanh theo Plant / Group |
| `f.<cột>` | Lọc nhiều giá trị theo cột |

Ví dụ: `/home/summary?group=Patrol&plant=SPC&fac=Fac_2&from=2026-09-01&to=2026-10-08&q=pump&f.division=CORE%20PIN&page=2&rows=50`

**Cột** (`summary/core/patrol_report_table_columns.dart`):

- **Thông tin chung:** STT, QR, Group, Plant, Division, Area, Machine, Patrol User, Img(B)
- **Rủi ro & nội dung:** Risk T, Comment, Countermeasure
- **Hạn:** Created, Deadline, Revise Deadline, Due Rev, Due By, Due Status (Late / Still Time)
- **Phụ trách:** PIC, Assign, Check Info, Risk F/P/S
- **After:** AT Stt, AT PIC, AT Date, AT Cmt, Img(A)
- **HSE:** HSE User, HSE Judge, HSE Updated, HSE Comment, Img(H)
- **Khác:** Load

Header cột có popup lọc nhiều giá trị và kéo được để đổi độ rộng. `PatrolReportColumnsDialog` cho ẩn/hiện và sắp xếp lại cột; layout lưu theo tài khoản.

**Group bar:**

- Chip Fac và Group, có đếm số lượng.
- Chọn ngày và FY.
- Nút Show/Hide Summary và nút Report.

**Toolbar:**

- Back, Reload
- Download Excel (`GET /api/patrol-reports/export-excel`, có thanh tiến trình)
- Search (Ctrl/Cmd+F), Clear filters, Columns

**Dòng:**

- Dòng quá hạn có vạch đỏ bên trái.
- Bấm ảnh B/A/H mở `PatrolImagesDialog`: lưới ảnh, thông tin, xem ảnh toàn màn hình.
- Double-tap dòng mở `EditReportDialog`.
- Trên mobile dùng layout riêng.

**`EditReportDialog`** (`summary/dialogs/edit_report_dialog.dart`)

- **Quyền:** người tạo, người được assign, hoặc role HSE.
- **Sửa được:** Group, Division, Area, Machine, F/P/S, Comment, Countermeasure, AT Comment, PIC, At_Status (`Doing`/`Pro_Done`/`Closed`), ảnh.
- Chỉ gửi các trường đã thay đổi, qua `POST {id}/edit`.

### Báo cáo

- **`PatrolRiskSummaryPage`** (`summary/reports/pages/patrol_risk_summary_page.dart`):
  - Khối "Summary" phía trên bảng: biểu đồ cột chồng theo Group · Division, chia mức I–V.
  - API: `GET /api/patrol_report/risk_summary`.
  - Bấm vào một cột để lọc bảng; ngày đồng bộ với bảng.
- **`BeforeAfterSummaryDialog`** (`summary/reports/pages/before_after_summary_dialog.dart`), mở từ nút "Report":
  - **`DivisionSummaryTable`** (`GET /api/patrol_report/summary/division`): mỗi dòng là Plant/Division. Các cột:
    - Before: TTL, I–V
    - After: Finished / Remain / Deadline (Still / 3 Days / Late)
    - HSE Finished
  - **`PicSummaryView`** (`GET /api/patrol_report/summary`): mỗi Fac có 3 bảng theo PIC: BEFORE, AFTER, HSE RECHECK (OK/NG kèm tỉ lệ). Trên mobile dùng bảng riêng.

---

## 7. Fixed Asset (Kiểm kê tài sản cố định)

Mục đích là kiểm kê máy theo quý (kỳ `YYYY-Qn`):

1. Quét tem QR trên máy.
2. So sánh vị trí thực tế với MASTER/MAP rồi lưu.
3. Máy cần làm lại tem được đưa vào luồng **In lại QR** → **Thay QR**.

Mọi API có tiền tố `/api/fixed-assets` (`lib/core/api/fixed_asset_api.dart`). `FixedAssetBackend` bọc các hàm này để có thể thay bằng bản giả khi test.

### 7.1 Kiểm kê — `FixedAssetScreen`

- **File:** `lib/features/fixed_asset/fixed_asset_screen.dart`.
- Nghiệp vụ nằm trong `fixed_asset_controller.dart`; các quy tắc thuần trong `fixed_asset_audit_flow.dart`.

**Luồng** (chỉ còn chế độ `MANUAL`):

1. **Chọn PIC (bắt buộc)** từ `GET /pics`. PIC được dùng chung cho cả phiên ở 3 màn Kiểm kê / In lại / Thay QR.
2. **Chọn vị trí** Fac → Floor → PositionA → PositionAA (`/facs`, `/floors`, `/position-a`, `/position-aa`).
   - Cấp nào chỉ có 1 lựa chọn thì tự chọn.
   - Chọn đủ 4 cấp thì camera mới bật và danh sách máy được tải (`GET /machines`).
3. **Quét QR.** Hỗ trợ các dạng:
   - `KVH_{mã}_{floor}_{AA}[_{tên}]`
   - `KVH_{floor}_{A}_{AA}_{mã}_{tên}`
   - Mã máy trần

   Nhiều mã trong khung thì ưu tiên mã gần tâm nhất và có trong danh sách máy.
4. **Chụp frame** ngay khi đọc được QR (JPEG, cạnh dài 1280).
5. **Kiểm tra** qua `POST /audit-check`, trả về trạng thái trong kỳ, PIC và cờ `needsQrReprint`.
   - **Máy đang chờ in lại tem:**
     - Quét bằng tem cũ: báo "QR chưa được thay", không lưu.
     - Tem mới đúng vị trí: lưu.
     - Vị trí lệch: mở dialog "Máy đã dời?".
   - **Vị trí trên QR khác vị trí đang chọn:** mở `FixedAssetQrMismatchDialog`. Chọn "Vẫn lưu" thì đánh dấu cần in lại QR.
   - **Máy không có trong danh sách của vị trí** (so với MASTER qua `GET /scan-info`): mở `FixedAssetMismatchDialog`. Dialog này đang **tắt** mặc định (`FA_MASTER_MISMATCH_DIALOG=false`), nên app tự lưu với `confirmLocationMismatch=true`.
6. **Lưu** qua `POST /audit`. Kết quả: `saved`, `alreadyAudited`, `unknownMachine`, `requiresConfirmation`, `pendingQrReplace`, `needsQrReprint`.
7. **Upload ảnh** (chỉ khi lưu mới): `POST /audits/{auditId}/photo?type=audit&qr=<QR thô>`.
   - Chạy ngầm, lỗi thì thử lại 1 lần.
   - Vẫn lỗi thì báo, nhưng kết quả kiểm kê vẫn giữ.
8. **Tiến độ:** `GET /audit-summary?pic=` cho thẻ tiến độ, `GET /zone-progress` cho bản đồ. Cả hai tải lại khi app quay về foreground.

**Bố cục màn:**

- Camera (zoom, bật/tắt, chip QR theo trạng thái)
- `FixedAssetStatusCard` (kết quả lần quét gần nhất)
- Tile "Máy không có QR"
- Bản đồ tầng
- `FixedAssetAuditProgressCard`
- `FixedAssetLocationSection` (chọn PIC + 4 dropdown)
- `FixedAssetMachineSection`: danh sách máy có tìm kiếm, nhãn đã kiểm / cần in QR / thiếu QR, nút "Ghi máy thiếu QR"

**Dialog:**

| Dialog | File | Chức năng |
|---|---|---|
| `FixedAssetMismatchDialog` | `widgets/fixed_asset_mismatch_dialog.dart` | "Sai vị trí máy" / "Vị trí không có trong MAP": so MASTER với vị trí đang quét; nút Vẫn lưu / Bỏ qua. |
| `FixedAssetQrMismatchDialog` | `widgets/fixed_asset_qr_mismatch_dialog.dart` | So ĐANG CHỌN với TRÊN QR, mục lệch tô đỏ; nút Không lưu / Vẫn lưu (đánh dấu in lại). |
| `FixedAssetReprintMoveDialog` | `widgets/fixed_asset_reprint_move_dialog.dart` | "Máy đã dời?": xác nhận để cập nhật vị trí thực tế; máy vẫn cần in lại tem. |

**Máy không có QR — `NoQrReportSheet`** (`no_qr/no_qr_report_sheet.dart`)

- **Mở từ:** tile "Máy không có QR" hoặc nút trên từng dòng máy (mã máy điền sẵn). Quét QR tạm dừng khi form mở.
- **Trường:** vị trí (breadcrumb / 4 dropdown), PIC, mã máy (chọn hoặc nhập tay), ghi chú (có nhập giọng nói).
- **Gửi:** `POST /audit` với `mode: "NO_QR"`, `needsQrReprint: true`.

### 7.2 Bản đồ tầng (`fixed_asset/map/`)

- **`FixedAssetDetectedMap`:** thẻ bản đồ, thu gọn được.
  - Khu nhỏ thì tự zoom vào.
  - Bấm vào thì mở toàn màn hình, có nút "Show all".
- **Ảnh bản đồ** khai báo trong `floor_map_data.dart`, ảnh nằm ở `assets/maps/`:
  - Floor 1: Press, Guide, Warehouse, Mold
  - Floor 2: All
- **Hiển thị:**
  - Đa giác khu cha (PositionA) và khu con (PositionAA).
  - Khu đang chọn có viền sáng; phần ngoài khu được làm mờ (spotlight).
  - Mỗi khu có badge đã kiểm/tổng.
- **Thao tác:** Ctrl + lăn chuột hoặc 2 ngón để zoom. Hiệu ứng tự giảm khi máy chạy chậm.

### 7.3 In lại QR — `FixedAssetReprintScreen` (`reprint/`)

**Danh sách:**

- Lấy từ `GET /qr-mismatch`, nhóm theo xưởng.
- Lý do: "Mất QR" hoặc "Sai vị trí".
- Mỗi thẻ hiện "QR đang dán" và "In cho vị trí".
- Nội dung QR mới là `KVH_{mã}_{floor}_{AA}_{tên}`, phải parse ngược lại khớp thì mới cho in.

**Lọc:** theo PIC, xưởng, khu vực, tìm mã/tên. Có chọn tất cả và kéo xuống để tải lại.

**Export** (`reprint/fixed_asset_reprint_export.dart`):

- **In QR (PDF):** A4, 2×5 tem 82×35 mm, mở hộp thoại in.
- **Tải PNG:** 600 dpi, mỗi máy 1 file `QR_{mã}.png`.
- **Xem trước:** `fixed_asset_reprint_preview.dart`.

**Sau khi in:** sheet nhắc dán tem và quét ở "Thay QR", kèm nút "Mở Thay QR".

### 7.4 Thay QR (`replace/`)

**Dữ liệu:**

- Lấy từ `GET /qr-mismatch`, chỉ giữ dòng có `needsQrReprint`. Lọc theo PIC và xưởng.
- Hai loại việc:
  - **Mất QR:** chỉ quét QR mới.
  - **Sai QR:** quét QR cũ rồi đến QR mới.

**Các màn:**

| Màn hình | File | Chức năng |
|---|---|---|
| `FixedAssetReplaceScreen` | `replace/fixed_asset_replace_screen.dart` | Cây vị trí thực tế Floor → A → AA kèm số máy chờ, có nhóm "Chưa rõ vị trí". Hết việc thì tự đóng. Mở từ Home, từ In lại QR, hoặc từ Tổng hợp. |
| `FixedAssetReplaceZoneScreen` | `replace/fixed_asset_replace_zone_screen.dart` | Danh sách máy chờ trong một khu. Máy xong thì biến mất; khu rỗng thì tự đóng. |
| `FixedAssetReplaceTaskScreen` | `replace/fixed_asset_replace_task_screen.dart` | "Việc cần làm": thông tin máy và checklist các bước. Camera tự mở; xong thì chuyển sang máy tiếp theo. |
| `FixedAssetReplaceScanScreen` | `replace/fixed_asset_replace_scan_screen.dart` | Camera toàn màn hình, badge QR CŨ / QR MỚI, thanh bước ①→②, đèn flash. |

**Xử lý** (`FixedAssetReplaceController`):

- **QR cũ:** chỉ kiểm tra tại máy, không gọi API lưu.
  - Ảnh upload ngầm qua `POST /audits/{auditId}/photo?type=before`.
  - Chưa có `auditId` thì giữ ảnh ở trạng thái **pending**, upload khi có id. Ảnh chờ mất khi đóng màn.
- **QR mới:** kiểm tra tại máy, rồi gửi `POST /audit` dạng multipart:
  - part `data`: JSON với `qrReplace: true`, `qr` (QR thô)
  - part `photo`: ảnh JPEG
  - Chỉ tính xong khi backend đã gỡ cờ in lại.
  - Không lưu được ảnh thì vẫn tính là đã thay.

### 7.5 Tổng hợp (`summary/`)

**`FixedAssetSummaryScreen`**

- **API:** `GET /summary?period=` và `GET /summary/pics?period=`, gọi song song.
- **Chọn quý:** lấy danh sách từ backend; không có thì dùng quý hiện tại và 3 quý trước.
- **Bốn thẻ chỉ số:**
  - **Tiến độ quý:** donut, so với kế hoạch 1/3 mỗi tháng.
  - **Mục tiêu tháng.**
  - **Còn lại cả quý:** khoảng bao nhiêu máy/ngày.
  - **Chờ thay QR:** bấm vào mở màn Thay QR.
- **Tiến độ theo PIC:** thanh 3 tháng có vạch "hôm nay", sắp xếp được. Bấm một PIC để xem chi tiết.

**`FixedAssetSummaryPicScreen`**

- **API:** `GET /summary/pic-detail` và `GET /summary/pic-machines`.
- **Tab "Theo khu":**
  - Bảng nhóm theo Fac · Tầng: Tiến độ / % / Còn lại / Lệch vị trí.
  - Lọc "Chỉ khu chưa xong", tìm khu.
  - Bấm một khu: màn rộng (≥900px) mở panel bên phải, màn hẹp mở màn riêng.
- **Tab "Danh sách máy":**
  - Cột: Mã / Tên / Trạng thái / Người kiểm / Thời gian / Vị trí QR-Master / Ghi chú.
  - Lọc Tất cả / Chưa kiểm / Đã kiểm / Bất thường.

---

## 8. Thành phần dùng chung

| Thành phần | File | Chức năng |
|---|---|---|
| `CameraPreviewBox` | `lib/shared/camera/camera_preview_box.dart` (+ `camera_preview_box/*`) | Camera web (getUserMedia): quét QR bằng ZXing, chụp hoặc upload nhiều ảnh, zoom phần cứng, bật/tắt, hiển thị STT. Tự tạm dừng khi bị route khác che. |
| `QrScannerDialog` | `lib/shared/qr/qr_scanner_dialog.dart` | Dialog quét QR, dùng ở Home. |
| `VoiceInputButton` | `lib/shared/speech/voice_input_button.dart` | Nút mic chèn chữ vào ô nhập: dùng Web Speech API, hoặc ghi âm rồi gửi `POST /api/speech/transcribe`. |
| `MachineAiRiskHistoryPanel` | `lib/features/machine_ai/machine_ai_alert_card.dart` | AI tóm tắt lịch sử rủi ro theo máy, có nút dịch sang JP. |
| `CommonUI`, `CommonSearchableDropdown`, `CommonRiskDropdown`, `RequiredFieldFlash`, các nút Glass… | `lib/shared/widgets/` | Snackbar, hộp xác nhận, dropdown, hiệu ứng ô bắt buộc, nút kính. |
| `DueDateUtils`, `natural_sort`, `plant_constants` | `lib/shared/utils/` | Tiện ích tính hạn, sắp xếp, hằng số plant. |

---

## 9. Danh sách API

Địa chỉ backend cấu hình trong `lib/core/api/api_config.dart`.

| Nhóm | Endpoint |
|---|---|
| Auth | `/api/auth/login`, `/register`, `/change_password`, `/export-password`, `/check-account-exists` |
| HR | `GET /api/hr/me`, `GET /api/hr/name` |
| Master | `GET /api/hse_master`, `GET /api/hse_master/by-macid`, `GET /api/patrol_teams` |
| Report (Before) | `POST /api/report`, `GET /api/report/check-qr` |
| Patrol report | `GET /api/patrol_report/filter`, `/pivot`, `/risk_summary`, `/summary`, `/summary/division` |
| Patrol report (thao tác) | `POST {id}/edit`, `PUT {id}/update_at`, `PUT {id}/hse_recheck`, `PUT {id}/replace_image`, `POST {id}/add_image`, `DELETE {id}/delete_image` |
| AI | `GET /api/patrol_report/analyze-machine`, `POST /api/patrol_report/translate-ai-summary` |
| Excel | `GET /api/patrol-reports/export-excel` |
| Gợi ý | `GET /api/suggest/comment`, `/counter` |
| Giọng nói / STT | `POST /api/speech/transcribe` (FE đang tắt, xem mục 11), `GET /api/stt/crt`, WebSocket `/ws-stt/websocket` → `/topic/stt/{fac}/{type}` |
| Fixed Asset | `/api/fixed-assets/`: `pics`, `facs`, `floors`, `position-a`, `position-aa`, `machines`, `scan-info`, `audit-check`, `audit`, `audits/{id}/photo`, `audit-summary`, `zone-progress`, `qr-mismatch`, `summary`, `summary/pics`, `summary/pic-detail`, `summary/pic-machines` |

---

## 10. Build & deploy

- **CI** (`.github/workflows/deploy.yaml`): chạy khi push lên `main`. Dùng Flutter 3.35.7, chạy `flutter build web --release`, rồi deploy `build/web` lên GitHub Pages.
- **Build tay** (`build_web_release.ps1`), lần lượt:
  - Tăng version x.y.z trong `pubspec.yaml`.
  - Chạy `flutter clean`, `pub get`, `build web --release --pwa-strategy=none`.
  - Thay `__APP_VERSION__` trong `index.html` và ghi `version.json`.
  - Kiểm tra các file bắt buộc (`main.dart.js`, `js/zxing.min.js`, `js/jsQR.js`, font).
  - Script chỉ build, không deploy.

```powershell
flutter pub get
flutter run -d chrome          # chạy dev
./build_web_release.ps1        # build release
```

---

## 11. Điểm cần lưu ý / chưa chắc chắn

Mục này đối chiếu code FE với tài liệu BE (`patrol_be/README.md`, audit ngày 2026-11-21, commit `e022fea`). Mã `S*`/`H*`/`M*` là mã lỗi trong mục 4 của README BE. Phần đối chiếu chỉ dựa trên đọc code, chưa chạy thử với server.

### 11.1 Gọi API sai / lệch hợp đồng

| # | API | Vấn đề | Ảnh hưởng | Cách sửa đề xuất |
|---|---|---|---|---|
| A1 | `POST /api/fixed-assets/audit` (Thay QR, bước QR mới) | FE gửi QR thô bằng field **`qrRaw`** (`fixed_asset_api.dart`, `saveAudit`), nhưng `FixedAssetAuditSaveRequest` của BE nhận field **`qr`**. Jackson bỏ qua field lạ nên không báo lỗi. | BE không nhận được QR thô. Ảnh `after/` bị đặt tên theo kiểu dự phòng `{Div}_{MachineCode}_{Floor}_{AA}_{Group}_3.jpg` thay vì `{qr}_3.jpg`. Upload ảnh `/audits/{id}/photo?qr=` vẫn đúng. | ✅ **Đã sửa:** FE gửi key `qr`. Ảnh `after/` từ giờ đặt tên `{qr}_3.jpg` (khi QR chứa MachineCode); ảnh đã lưu trước đó giữ tên cũ. |
| A2 | `GET /api/patrol_report/summary/pic` | BE không có endpoint này (FE gọi qua `PatrolPicSummaryApi`). | Không có, vì không màn nào gọi. | ✅ Đã xóa (11.4). |
| A3 | `GET /api/patrol_report/pic-summary` | BE không có endpoint này (FE gọi qua `SummaryApi.fetchPicSummary`). | Không có, vì không màn nào gọi. | ✅ Đã xóa (11.4). |
| A4 | `POST /api/patrol_report/translate-ai-summary` | Khi LLM lỗi hoặc bận, BE trả **nguyên văn tiếng Việt**. FE không phân biệt được nên hiển thị luôn như bản tiếng Nhật. (BE M7) | User JP thấy nội dung tiếng Việt trong ô "JP". | BE trả thêm cờ `translated: false`, FE hiện thông báo "chưa dịch được". |
| A5 | Upload multipart qua `DioClient.postUpload` / `putUpload`: `POST /api/report`, `add_image`, `edit`, `update_at`, `hse_recheck`, `replace_image` | `_retry` tự gửi lại khi timeout, nhưng dùng lại **cùng một `FormData`**. Dio không gửi lại được `FormData` đã finalize, và các API này đều không idempotent. `SpeechApi` và `FixedAssetApi.saveAudit` đã tránh `_retry` vì đúng lý do này. | Nếu lần 1 server đã xử lý nhưng client timeout: lần retry lỗi, user thấy báo lỗi rồi gửi lại thủ công, có thể tạo report hoặc ảnh trùng (nhóm không có QR thì không bị chặn 409). | Không retry cho upload (gọi thẳng `DioClient.dio`), giống `saveAudit`. **Chưa sửa** vì đổi hành vi. |
| A6 | `POST /api/patrol_report/{id}/edit` | `EditReportDialog` cho sửa `atStatus` tự do (`Doing`/`Pro_Done`/`Closed`), và BE không validate. (BE H1) | Có thể đóng hoặc mở lại report mà bỏ qua bước Recheck. | BE validate chuyển trạng thái; FE giới hạn lựa chọn theo role HSE. |

**Các phần đã khớp** (tên param, part, body):

- **Auth, HR:** `/api/auth/*` (`{account, password}`, `{account, oldPassword, newPassword}`, `account`+`email`; `AuthResponse.code` `AUTH_001..004`), `/api/hr/me` và `/api/hr/name` (`code`).
- **Tạo report:** `/api/report/check-qr` (`qrKey`); `/api/hse_master/by-macid` (`macId`); `POST /api/report` (part `report` + `images`).
- **Tra cứu và thống kê Patrol:**
  - `/filter`: `pic=''` nghĩa là chưa gán.
  - `/pivot`: `at_status` gửi nhiều giá trị.
  - `/risk_summary`, `/summary/division`: `fromD`, `toD`, `fac`, `type`.
  - `/summary`: `from`, `to`, `plant`, `type`.
  - `/export-excel`: `from`, `to`.
  - Giá trị `SPC` được BE xử lý là "mọi nhà máy".
- **Cập nhật report:**
  - `add_image` (`image`), `replace_image` (`oldImage`, `newImage`), `delete_image` (`image`).
  - `update_at`: `data{atComment, atPic}`.
  - `hse_recheck`: `data{hseUser, hseJudge, hseComment, atStatus}`.
  - `edit`: `PatrolEditDTO`; FE map `needRecheck` → `checkInfo`.
- **Gợi ý, STT, WebSocket:** `/api/suggest/comment|counter` (`l`); `/api/stt/crt` (`fac`, `type`); WebSocket SockJS `/ws-stt/websocket`.
- **Fixed Asset:**
  - Toàn bộ param dropdown, summary và `scan-info`.
  - `audit-check` (`{machineCode, floor, positionAA}`).
  - `POST /audit` bản JSON, và bản multipart (`data` có `Content-Type: application/json` + `photo`).
  - `/audits/{id}/photo` (`userId`, `type`, `qr`, part `file`).

### 11.2 API BE có nhưng FE không dùng

| API | Ghi chú |
|---|---|
| `GET /api/hr/recheck` | FE kiểm tra quyền bằng `/api/hr/me`. |
| `GET /api/patrol_report/machine-history` | Chức năng AI dùng `/analyze-machine`. |
| `GET /api/fixed-assets/pic-zones` | Chưa có màn nào dùng. |
| `GET /api/fixed-assets/zone-lock` | FE còn hàm `FixedAssetApi.fetchZoneLock` và model nhưng không UI nào gọi. BE trả `locked` luôn `false`. |
| `GET /api/fixed-assets/audited-machine-codes`, `/machine-location` | Hàm FE đã xóa (11.4). |
| `GET /api/suggest/search`, `/searchCounter`, `/all` | FE tải toàn bộ bằng `/comment`, `/counter` rồi lọc ở client. Hàm `search`/`searchCounter` đã xóa (11.4). |
| `POST /api/speech/transcribe` | FE dùng Web Speech API (`kUseWebSpeech = true` trong `voice_input_button.dart`). BE cũng đang tắt (`speech.transcribe.enabled=false`). Nếu đổi `kUseWebSpeech = false` thì phải bật BE trước, nếu không sẽ bị 404. |
| `GET /api/debug/headers` | Endpoint debug, nên gỡ khỏi production (BE S7). |

### 11.3 Mật khẩu: hiện trạng và hướng xử lý

| # | Hiện trạng | Phía | Hướng xử lý |
|---|---|---|---|
| P1 | Mật khẩu lưu **dạng thô** trong `localStorage` (`account_password`, `session_store.dart`). "Remember me" **mặc định bật**. F5 thì đăng nhập lại bằng mật khẩu này (`AuthSession.restore`). | FE | **Ngắn hạn:** mặc định tắt Remember me; dùng `sessionStorage` thay cho `localStorage`. **Dài hạn:** khi BE phát token (P3), chỉ lưu token có hạn, bỏ hẳn việc lưu mật khẩu. |
| P2 | Gửi mật khẩu qua **HTTP không mã hóa** (`ApiConfig.baseUrl = http://...`, `ws://`). | FE + hạ tầng | Chuyển sang HTTPS/WSS. Trong `api_config.dart` đã có sẵn cấu hình `https`/`wss` qua App Proxy (đang comment). |
| P3 | **Không có token:** login chỉ trả success. FE coi là "đã đăng nhập" khi có account trong `SessionStore`. Mọi API tin `userId`/`code` do client gửi lên. (BE S1) | BE + FE | BE thêm Spring Security, login phát token. FE gắn `Authorization` trong interceptor của `DioClient`, xử lý 401 bằng cách về `/`. |
| P4 | BE **lưu và so sánh mật khẩu dạng thô**, cho phép mật khẩu rỗng. (BE S2) | BE | Dùng BCrypt. Migrate dần: lần login đầu so khớp bản thô thì hash lại và lưu. Thêm độ dài tối thiểu ở cả FE (register/change) lẫn BE. |
| P5 | **Quên mật khẩu** (`GET /api/auth/export-password`) ghi file Excel chứa mật khẩu thô vào thư mục dùng chung; không đối chiếu email; ai cũng gọi được. (BE S3, S4) | BE | Thay bằng luồng reset: BE sinh mật khẩu tạm hoặc link một lần, gửi qua Teams/email đã đăng ký, buộc đổi khi đăng nhập. FE giữ nguyên form (account + email), chỉ đổi thông báo. |
| P6 | **Dò tài khoản:** login trả 404 (`AUTH_001`) khác 401 (`AUTH_002`), FE hiện 2 thông báo khác nhau. Màn đổi mật khẩu gọi `check-account-exists` trước. (BE H6) | BE + FE | Gộp thành một thông báo "Sai tài khoản hoặc mật khẩu"; thêm rate-limit login ở BE. |
| P7 | FE `trim()` mật khẩu ở cả login, register và change password (nhất quán). BE không trim. | FE | Giữ nguyên. Lưu ý: nếu sau này có client khác không trim, mật khẩu có khoảng trắng đầu/cuối sẽ lệch. |

**Thứ tự đề xuất:**

1. P2 (HTTPS) và P5 (gỡ export-password).
2. P1 ngắn hạn.
3. P4 cùng lúc với P6.
4. P3, sau đó bỏ hẳn việc lưu mật khẩu ở FE.

### 11.4 Code chết

**Đã xóa** (không còn tham chiếu nào, không đổi logic; `flutter analyze lib` không phát sinh lỗi mới):

| Đã xóa | Lý do |
|---|---|
| `core/api/patrol_pic_summary_api.dart`, `core/models/patrol_pic_summary.dart`, `summary/reports/pages/patrol_pic_summary_page.dart`, `summary/reports/charts/patrol_pic_summary_chart.dart` | Trang không được mở từ đâu; gọi endpoint BE không tồn tại (A2). |
| `SummaryApi.fetchPicSummary`, `core/models/pic_summary.dart` | Không ai gọi; endpoint BE không tồn tại (A3). |
| `FixedAssetApi.fetchAuditedMachineCodes`, `fetchMachineLocation`, `core/models/fixed_asset_machine_location.dart` | Không ai gọi (đã thay bằng `scan-info`). |
| `AutoCmpApi.search`, `searchCounter` | Không ai gọi. |
| `MachineAiAlertCard`, `_AiHeader` (`machine_ai_alert_card.dart`) | Không dùng; `MachineAiRiskHistoryPanel` vẫn giữ. |
| `features/machine_ai/ai_analysis_toggle.dart` | File đã bị comment toàn bộ. |
| Khối `DioClient` cũ bị comment ở đầu `dio_client.dart` | Code đã comment. |
| Import, field, hằng và method private không dùng: `_needManualSelect`, `_oldPIC`, `_isLoadingName`, `_loadingMacId`, `_lastGood*`, `showGlassDialog` (bản riêng của màn Before), `getPlants`, `normalizeGroup`, `_revertToLastGood`, … | Cảnh báo `unused_*` của analyzer. |
| Phần dựng `Uri` chỉ để log trong `PatrolPivotApi` / `PatrolReportApi` | Interceptor của `DioClient` đã log URL đầy đủ. |
| `test/fixed_asset_zone_lock_test.dart` | Gọi API controller không còn tồn tại, không compile được. |
| `shared/qr/qr_code_camera.dart` (`QrCodeCamera`), `shared/animations/christmas_title.dart` (`ChristmasTitle`), `shared/utils/report_validator.dart` (`ReportValidator`), `core/models/patrol_edit_model.dart` (`PatrolEditDTO` phía FE) | Không file nào import. Camera QR đã được thay bằng `CameraPreviewBox`; `updateReportApi` dựng map trực tiếp. |

**Dọn lint** (không đổi logic):

- `Color.withOpacity(x)` → `withValues(alpha: x)`: 475 chỗ. `withValues` giữ alpha dạng số thực thay vì làm tròn 8 bit, nên khác biệt màu không nhìn thấy được.
- Bỏ so sánh null luôn sai và 3 import không dùng trong `translator.dart`. File này được sinh tự động nên đã sửa cả template trong `tool/generate_translator.dart`.

**Giữ lại, cần quyết định thêm:**

- **Zone lock:** `FixedAssetApi.fetchZoneLock`, `FixedAssetBackend.fetchZoneLock`, `fixed_asset_zone_lock.dart`. Không UI nào gọi. Đề xuất xóa khi chốt bỏ chế độ AUTO.
- **`FixedAssetSummaryNav.openAudit`:** chưa ai gọi, nhưng `FixedAssetScreen` đã có sẵn `initialPic`/`initialLocation` cho nó. Có vẻ là chức năng đang làm dở.
- **Field không dùng nhưng xóa sẽ đổi luồng code:**
  - `_comment` / `_counterMeasure` (`PatrolBeforeScreen`): được gán trong timer debounce.
  - `_enableCamera` (`RedoDetailPage`): đi kèm đoạn chờ 200ms trước snackbar.
- **`RedoDetailPage` tự viết lại request `update_at`**, trùng với `updateAfterReportApi`. Request gửi đi giống nhau, nhưng khi gặp lỗi mạng/5xx thì nội dung snackbar `'Server error: $e'` sẽ khác, nên chưa gộp.
- **`capture.dart`: `if (blob == null)`**. Analyzer báo luôn sai, nhưng `toBlob` của trình duyệt vẫn có thể trả null, nên giữ làm chốt chặn lúc chạy.
- **Test hỏng từ trước:** `fixed_asset_manual_confirm_test.dart`, `fixed_asset_manual_location_test.dart`, `fixed_asset_machine_section_test.dart`. Các file này dùng chữ ký cũ của `FixedAssetBackend` và `setLocationMode` / `zoneLockEnabled` không còn tồn tại, nên `flutter test` chưa chạy sạch. Cần cập nhật, hoặc xóa nếu chỉ còn test chế độ AUTO.

### 11.5 Khác

- **CI không thay `__APP_VERSION__`**, nên cơ chế tự reload khi có bản mới có thể không chạy với bản deploy từ CI (chưa chắc).
- **Version lệch nhau:** `ApiConfig.version` là `V1.9.4`, còn `pubspec.yaml` là `1.0.2`.
- **`dart:js_util`:** `flutter analyze` báo không tìm thấy (`camera_preview_box.dart`); lỗi này có từ trước.
- **Đã xác nhận với tài liệu BE:** `update_at` → `Pro_Done` do server đặt; điều này khớp với việc FE không gửi `atStatus`.

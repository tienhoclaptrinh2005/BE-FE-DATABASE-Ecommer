# Báo cáo UAT và sẵn sàng triển khai — 15/09/2026

## 1. Kết luận phát hành

- **Nghiệp vụ và mã nguồn:** ĐẠT UAT trên môi trường local.
- **Sẵn sàng triển khai staging:** CÓ ĐIỀU KIỆN. Cần cấp database/Redis/host staging và secret staging trước khi chạy release.
- **Sẵn sàng triển khai production:** **CHƯA ĐẠT (NO-GO)** tại thời điểm kiểm tra.

Các chặn production hiện tại:

1. `tienhoclaptrinh.site`, `www.tienhoclaptrinh.site` và `api.tienhoclaptrinh.site` chưa phân giải DNS; chỉ `images.tienhoclaptrinh.site` đang hoạt động.
2. Chưa có môi trường production thật: không có `.env.production`, database/Redis production hoặc secret trên nền tảng deploy. Các file `.env.production.example` chỉ là template và vẫn chứa placeholder.
3. Hai repository mới có CI kiểm thử, chưa có Dockerfile, manifest triển khai hoặc workflow CD/rollback.
4. Migration đang là SQL chạy thủ công, chưa được quản lý bởi Flyway/Liquibase và chưa có down migration.
5. R2 credential local đã xuất hiện trong log chẩn đoán của phiên UAT. Phải thu hồi cặp key hiện tại và tạo key mới trước staging/production.

## 2. Phiên bản được kiểm thử

- Backend commit: `cf56e9cfd141f5baa704447a15edb95d80e55491`
- Frontend commit: `b6e4361fa6a114c7e914454a4e7c202cd6ccbf86`
- Java: 21
- PostgreSQL đích kiểm thử: local, cổng `5678`
- Backend local: `http://localhost:8080`
- Frontend local: `http://localhost:3000`

## 3. Kiểm thử tự động

| Hạng mục | Kết quả | Bằng chứng |
|---|---:|---|
| Backend Maven verify | PASS | 130 test, 0 failure, 0 error, đóng gói JAR thành công |
| Frontend ESLint | PASS | `npm run lint` không có lỗi |
| Frontend production build | PASS | Next.js build thành công, TypeScript đạt, tạo đủ 42 route |
| Build với URL production dự kiến | PASS | Dùng `https://api.tienhoclaptrinh.site` và `https://images.tienhoclaptrinh.site` |
| Hibernate schema validation | PASS | JAR khởi động trên database restore + migration với `ddl-auto=validate` |

Lưu ý: GitHub repository không công khai cho API không xác thực nên không đọc được trạng thái Actions từ ngoài. Kết quả trên là chạy trực tiếp từ đúng working tree hiện tại.

## 4. UAT Buyer → Seller → Admin

### 4.1 Đăng ký và duyệt Seller

- Tạo Buyer UAT mới.
- Gửi yêu cầu mở shop.
- Admin duyệt shop.
- Đăng nhập lại nhận role `SELLER`, shop chuyển `ACTIVE`.
- Tên hồ sơ được đồng bộ sang tên shop sau khi duyệt.

Kết quả: **PASS**.

### 4.2 Nạp tiền qua SePay

- Tạo deposit `PENDING` và mã QR có `transactionCode` riêng.
- Webhook sai chữ ký trả `401`.
- Webhook HMAC hợp lệ chuyển deposit sang `SUCCESS`.
- Gửi lại cùng webhook vẫn trả thành công nhưng không cộng tiền lần hai.
- Deposit UAT: `CH_88320318`, số tiền `10.000 đ`, ví chỉ tăng đúng một lần.

Kết quả: **PASS** cho chữ ký, idempotency và chống cộng trùng.

### 4.3 Checkout đơn Giao ngay

- Checkout biến thể còn kho và giao đúng một digital asset.
- Gửi lại cùng idempotency key trả về cùng đơn, không trừ ví và kho lần hai.
- Đơn UAT: `ORD-S2-20260915020838347-2959`.
- Trạng thái sau giao: `DELIVERED/PAID`.
- Buyer bị trừ đúng `399.000 đ`; Seller nhận đúng khoản hold tương ứng.

Kết quả: **PASS**.

### 4.4 Khiếu nại và Admin phán quyết

Luồng đã chạy:

`OPEN → WARRANTY_IN_PROGRESS → WAITING_BUYER_CONFIRMATION → ADMIN_REVIEW → RESOLVED/BUYER_WIN`

- Seller bắt đầu và báo hoàn tất bảo hành.
- Buyer từ chối kết quả, nhập lý do và chuyển Admin.
- Hồ sơ xuất hiện trong hàng đợi `ADMIN_REVIEW`.
- Admin xử Buyer thắng.
- Buyer được hoàn đúng `399.000 đ`; khoản hold Seller được giải phóng tương ứng.

Kết quả: **PASS**.

### 4.5 Đơn Đặt hàng

- Đơn hoàn thành `ORD-S2-20260915021030786-6010`:
  `WAITING_SELLER_ACCEPTANCE → PROCESSING → DELIVERED/PAID`.
- Hold release được tạo ở trạng thái `HOLDING`, thời gian còn lại khi kiểm tra là khoảng `167,99 giờ`, đúng T+7.
- Đơn Buyer chủ động hủy `ORD-S2-20260915021030977-5272` chuyển `CANCELLED/REFUNDED`, số dư được phục hồi đúng.
- Đơn quá hạn nhận `ORD-S2-20260915021214202-6981` được scheduler thật quét trong chu kỳ một phút, chuyển `CANCELLED/REFUNDED` với mã `SELLER_ACCEPTANCE_TIMEOUT`, hoàn đúng `200.000 đ`.

Kết quả: **PASS** cho nhận đơn, hoàn thành, hold T+7, hủy và tự hủy sau deadline.

### 4.6 Rút tiền

- `WD-000007`: idempotency trả cùng yêu cầu và chỉ trừ số dư một lần.
- Không cho chuyển thẳng `PENDING → DONE` (`409`).
- Không cho hoàn tất thiếu mã tham chiếu (`400`).
- `PENDING → APPROVED → DONE` với mã giao dịch ngân hàng hợp lệ; không trừ thêm tiền khi hoàn tất.
- `WD-000008`: từ chối thiếu lý do bị chặn (`400`); từ chối hợp lệ chuyển `REJECTED` và hoàn lại đúng `500.000 đ`.

Kết quả: **PASS**.

## 5. Phân quyền và ownership

| Trường hợp | Mã HTTP mong đợi | Kết quả |
|---|---:|---:|
| Chưa đăng nhập gọi ví | 401 | PASS |
| Buyer gọi API Seller | 403 | PASS |
| Seller gọi dashboard Admin | 403 | PASS |
| Admin gọi danh sách sản phẩm Seller | 403 | PASS |
| User khác xem đơn Buyer | 404 | PASS |
| User khác xem tài sản số của Buyer | 404 | PASS |
| Shop khác xem chi tiết đơn Seller | 404 | PASS |

API dùng `404` ở các kiểm tra ownership để không làm lộ sự tồn tại tài nguyên của user/shop khác.

## 6. Database migration và validate

Đã thực hiện trên một database tạm được restore từ backup:

1. Chạy `migration-2026-09-14-admin-dispute-escalation.sql`.
2. Chạy `migration-2026-09-14-withdrawal-workflow.sql`.
3. Chạy lại cả hai file lần thứ hai để kiểm tra tính idempotent.
4. Khởi động JAR với database này và `ddl-auto=validate`.
5. Gọi API public và OpenAPI, đều trả `200`.

Kết quả: **PASS**. Các database tạm đã được xóa sau kiểm thử.

Rủi ro còn lại: migration chưa có version manager. Với database mới dùng `schema-v8.sql`; với database đang có dữ liệu phải backup rồi chạy hai migration theo đúng thứ tự trên. Không chạy `seed-test-data.sql` trên production.

## 7. CORS, cookie, domain và HTTPS

### Backend local

- Preflight từ `http://localhost:3000`: `200`.
- Có `Access-Control-Allow-Origin` đúng origin và `Allow-Credentials: true`.
- Origin không được phép bị từ chối `403`, không trả header allow-origin.
- Refresh token nằm trong cookie `HttpOnly`, `SameSite=Strict`, path `/api/v1/auth` và không xuất hiện trong JSON.
- Cookie local không có `Secure`, đúng vì local chạy HTTP.
- Template production đặt `AUTH_COOKIE_SECURE=true`, đúng yêu cầu khi chạy HTTPS.

### Domain bên ngoài

| Domain | Trạng thái ngày 15/09/2026 |
|---|---|
| `tienhoclaptrinh.site` | Chưa có bản ghi phân giải dùng được |
| `www.tienhoclaptrinh.site` | Không phân giải |
| `api.tienhoclaptrinh.site` | Không phân giải |
| `images.tienhoclaptrinh.site` | DNS và HTTPS hoạt động qua Cloudflare |

Do API domain chưa tồn tại, chưa thể kiểm thử cookie/CORS/webhook từ Internet đến backend production.

## 8. Cloudflare R2

- Bucket dev cho phép CORS từ `http://localhost:3000` với `GET`, `HEAD`, `PUT`.
- Bucket production cho phép `https://tienhoclaptrinh.site` và `https://www.tienhoclaptrinh.site`.
- Bucket production từ chối origin local bằng `403`.
- Đã chạy thật chuỗi `presign → PUT → complete → public HEAD` trên bucket dev bằng WebP 1200×900.
- Backend xác minh ảnh thành công; URL công khai trả `200`, `Content-Type: image/webp` và `Cache-Control: public, max-age=31536000, immutable`.
- Object UAT đã được xóa; URL kiểm tra lại trả `404`.
- Dữ liệu mới lưu object key thay vì đóng cứng media domain, nên đổi `MEDIA_PUBLIC_BASE_URL` không buộc sửa toàn bộ bản ghi mới.

Kết quả: **PASS trên dev**; CORS production **PASS**. Chưa test PUT production vì chưa có production secret trong môi trường deploy.

## 9. Backup, restore và rollback

- Backup custom format: `C:\Users\acer\AppData\Local\Temp\commercehub-uat-20260915-015914.backup`.
- Kích thước: `432.030 bytes`.
- SHA-256: `0eb74ccc62b86c5f0616f4c341ee773f25a8b69deecf03111d96bd883faed932`.
- Restore vào database tạm thành công.
- Đối chiếu nguồn/restore khớp: 86 bảng, 9 user, 10 ví, 122 wallet transaction, 24 order, 24 order item, 72 digital asset, 18 hold release, 3 dispute và 6 withdrawal tại thời điểm backup.
- Database restore tạm đã được xóa.

Kết quả: **PASS cho backup/restore database**.

Chưa thể kiểm thử rollback bản phát hành ứng dụng vì chưa có image được đánh version, môi trường staging/production hoặc pipeline CD. Hai migration dùng transaction nên lỗi giữa migration sẽ rollback transaction, nhưng chưa có down migration. Rollback production an toàn hiện phải là: dừng ghi → restore backup vào database mới → trỏ app về database đã restore → triển khai lại artifact/tag trước đó.

## 10. Dữ liệu UAT còn trong local

UAT chủ động tạo dữ liệu để có thể truy vết sau kiểm thử:

- 1 user/shop có email bắt đầu bằng `uat.` và kết thúc bằng `@commercehub.test`.
- 4 đơn UAT nêu trong báo cáo.
- Deposit `CH_88320318`.
- Dispute `#4`, đã `RESOLVED/BUYER_WIN`.
- Withdrawal `#7` đã `DONE`, withdrawal `#8` đã `REJECTED`.

Đây chỉ là dữ liệu local. Không sao chép các bản ghi này hoặc chạy seed lên production.

## 11. Checklist bắt buộc trước khi mở production

1. Thu hồi R2 key hiện tại; tạo key riêng cho staging và production với quyền tối thiểu trên từng bucket.
2. Chọn và cấu hình host cho frontend, backend, PostgreSQL và Redis.
3. Tạo DNS `@`, `www`, `api`; bật HTTPS và kiểm tra redirect HTTP → HTTPS.
4. Đặt secret bằng dashboard/secret manager, không tạo hoặc commit `.env.production` chứa khóa thật.
5. Với backend production: `AUTH_COOKIE_SECURE=true`, `SPRINGDOC_ENABLED=false`, `SEPAY_ENVIRONMENT=production`, `R2_RATE_LIMIT_STORE=redis`, `ddl-auto=validate`.
6. Cấu hình URL webhook SePay công khai là `https://api.<domain>/api/v1/payments/sepay/webhook`; test chữ ký, retry và duplicate trên staging trước.
7. Backup database đích, chạy migration, khởi động đúng artifact đã gắn tag, rồi chạy smoke test.
8. Bổ sung endpoint health/readiness không yêu cầu đăng nhập để nền tảng deploy kiểm tra an toàn.
9. Bổ sung Dockerfile hoặc manifest đúng nền tảng deploy; build image/tag bất biến và quy trình rollback về tag trước.
10. Tạo lịch backup tự động, mã hóa backup, lưu ngoài máy chủ database và diễn tập restore định kỳ.

## 12. Smoke test cần chạy sau mỗi lần deploy

- Trang chủ frontend tải qua HTTPS, không mixed content.
- Đăng nhập và refresh token hoạt động sau reload trang.
- Origin không được phép không gọi được API.
- Buyer tạo QR; webhook SePay staging cộng tiền đúng một lần.
- Checkout một đơn Giao ngay và một đơn Đặt hàng bằng dữ liệu UAT riêng.
- Seller chỉ thấy đơn của shop mình; Admin chỉ thấy hàng đợi cần xử lý.
- Hủy đơn hoàn ví đúng; đơn hoàn thành tạo hold T+7.
- Upload ảnh WebP qua R2 và đọc lại từ media domain.
- Tạo rút tiền nhỏ, duyệt, từ chối và đối chiếu wallet transaction.
- Kiểm tra log không chứa JWT, refresh token, webhook secret, R2 secret hoặc dữ liệu tài khoản số đã giao.

# CommerceHub — Baseline kiểm thử 05/09/2026

> Ngày chốt: **05/09/2026 (GMT+7)**  
> Backend commit nền: `c2361a8` (`main`)  
> Frontend commit nền: `708205f` (`main`)  
> Trạng thái: các thay đổi mô tả dưới đây đang ở working tree, chưa được commit.

## 1. Phạm vi baseline

Baseline này chốt contract API sau khi chuẩn hóa route, response dispute, pagination, error response; bổ sung OpenAPI/Swagger và GitHub Actions CI cho cả backend lẫn frontend.

Không có thay đổi schema/database trong đợt này.

## 2. Route đã chuẩn hóa

| Nhóm | Route cũ | Route chuẩn |
|---|---|---|
| Checkout | `POST /api/v1/checkout/checkout` | `POST /api/v1/checkout` |
| Kho tài sản seller | `POST /api/v1/seller/products/products/assets/inventory` | `POST /api/v1/seller/products/assets/inventory` |
| Cấu hình phí admin | `/api/admin/fee-configs` | `/api/v1/admin/fee-configs` |
| Phí seller | `/api/seller/fees` | `/api/v1/seller/fees` |

Frontend checkout service đã chuyển sang route mới. Kết quả quét `src/main` backend và `src` frontend không còn route lặp `/products/products`, `/checkout/checkout` hoặc hai route phí không có `/api/v1`.

## 3. Contract response

### Dispute

Buyer, seller và admin dispute controller đều trả cùng envelope:

```json
{
  "success": true,
  "code": 200,
  "message": "...",
  "data": {}
}
```

API tạo dispute trả HTTP `201` và trường `code: 201`. Các API tạo category, shop, product và review cũng được đồng bộ `code: 201` với HTTP status thực tế.

### Pagination

Danh sách dispute dùng một kiểu `PageResponse<T>` duy nhất:

```json
{
  "currentPage": 0,
  "pageSize": 20,
  "totalPages": 1,
  "totalElements": 1,
  "data": []
}
```

Frontend dispute service và màn hình danh sách đã dùng đúng `currentPage`, `pageSize` và `data`; không còn phụ thuộc trực tiếp vào cấu trúc `Page` nội bộ của Spring.

### Error handler

Các lỗi thông dụng đều trả envelope `ApiResponse` với `success: false`, HTTP status và `code` đồng nhất:

- `400`: validation, JSON sai, thiếu request parameter, path/query sai kiểu.
- `401`: sai thông tin đăng nhập.
- `403`: không đủ quyền.
- `404`: endpoint hoặc resource không tồn tại.
- `405`: sai HTTP method.
- `409`: vi phạm unique/constraint hoặc optimistic locking.
- `500`: lỗi ngoài dự kiến; không trả stack trace cho client.

## 4. OpenAPI/Swagger

- Dependency: `org.springdoc:springdoc-openapi-starter-webmvc-ui:2.8.17`.
- OpenAPI JSON: `http://localhost:8080/v3/api-docs`.
- Swagger UI: `http://localhost:8080/swagger-ui/index.html`.
- Đã khai báo Bearer JWT và phân biệt operation public/protected trong tài liệu.
- Có thể bật/tắt bằng `SPRINGDOC_ENABLED`; mặc định đang bật cho môi trường local.
- Contract test xác nhận bốn route chuẩn tồn tại và bốn route cũ không còn trong OpenAPI.

## 5. CI đã thêm

### Backend

File: `commercehub-backend/.github/workflows/ci.yml`

- Trigger khi push, pull request hoặc chạy thủ công.
- Java 21 Temurin, Maven cache.
- PostgreSQL 16 riêng cho job test.
- Schema test tạo/xóa độc lập bằng `ddl-auto=create-drop`.
- Chạy `./mvnw -B --no-transfer-progress verify`.

### Frontend

File: `commercehub-frontend/.github/workflows/ci.yml`

- Trigger khi push, pull request hoặc chạy thủ công.
- Node.js 22, npm cache.
- Chạy `npm ci`, `npm run lint`, `npm run build`.

Workflow đã được thêm và kiểm tra cấu trúc tại local. Trạng thái GitHub Actions thực tế chỉ có sau khi commit/push lên GitHub; baseline không ghi nhận nhầm workflow chưa chạy là đã pass.

## 6. Môi trường kiểm thử local

| Thành phần | Phiên bản |
|---|---|
| OS | Windows 11 x64 |
| Java | Oracle JDK 21.0.8 |
| Maven Wrapper | Apache Maven 3.9.14 |
| Spring Boot | 3.5.13 |
| Springdoc | 2.8.17 |
| Node.js | 24.18.0 |
| npm | 11.16.0 |
| Next.js | 16.3.0 |
| React | 19.2.8 |

## 7. Kết quả kiểm thử

| Hạng mục | Lệnh | Kết quả |
|---|---|---|
| Backend full suite | `.\\mvnw.cmd test` | **PASS — 50/50**, 0 failure, 0 error, 0 skipped |
| Test nền trước thay đổi | thuộc full suite | **PASS — 47/47** |
| Contract test mới | `OpenApiContractTest` | **PASS — 3/3** |
| Frontend lint | `npm run lint` | **PASS** |
| Frontend production build | `npm run build` | **PASS** |
| Kiểm tra whitespace diff backend | `git diff --check` | **PASS** |
| Kiểm tra whitespace diff frontend | `git diff --check` | **PASS** |
| Quét route cũ trong source chạy thật | `rg` | **PASS — không còn kết quả** |

Phân bổ 50 backend test theo Surefire: 16 test suite, tổng 50 test, không có failure/error/skipped.

## 8. Lưu ý vận hành

- Lần test local này dùng PostgreSQL local hiện có và `ddl-auto=validate`; CI dùng PostgreSQL độc lập với `create-drop` để không phụ thuộc dữ liệu máy phát triển.
- Maven trên máy hiện tại có thể nhận sai `user.home` thành `C:\\`. Nếu Maven không tìm thấy cache dependency, chạy PowerShell:

```powershell
$env:MAVEN_OPTS='-Dmaven.repo.local=C:\Users\acer\.m2\repository'
.\mvnw.cmd test
Remove-Item Env:MAVEN_OPTS
```

- Cảnh báo Mockito tự attach agent và thông báo encoding console không làm test thất bại, nhưng nên xử lý trước khi nâng JDK lớn hơn.

## 9. Tiêu chí hoàn thành mốc 05/09

- [x] Chuẩn hóa ba nhóm route và frontend service liên quan.
- [x] Chuẩn hóa dispute response và pagination.
- [x] Mở rộng global error handler.
- [x] Thêm OpenAPI/Swagger và contract test.
- [x] Thêm CI backend/frontend.
- [x] 47 backend test nền tiếp tục xanh.
- [x] 3 contract test mới xanh; tổng mới 50 test.
- [x] Frontend lint/build xanh.
- [x] Không còn route lặp `/products/products` hoặc `/checkout/checkout` trong source chạy thật.


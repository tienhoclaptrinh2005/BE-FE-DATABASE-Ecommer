-- ============================================================
-- COMMERCEHUB — SCHEMA v8 (FILE DUY NHẤT)
-- ============================================================
-- Nguồn: schema DB live + tài liệu v8 + quyết định nghiệp vụ đã chốt.
--
-- QUYẾT ĐỊNH:
--   [DEL] favorite_shops — không còn shop/sản phẩm yêu thích
--   [ADD] carts + cart_items — giỏ hàng (1 user = 1 cart)
--   [DEL] Waive phí sàn — KHÔNG có status WAIVED / total_waived / waived_at
--   [FEE] Mặc định 4% (0.0400), làm tròn CEILING đồng nguyên
--   [PAY] Mua hàng luôn trừ WALLET (nạp trước — mua sau)
--   [PRE] PRE_ORDER trừ ví NGAY lúc checkout (không chờ shop accept)
--   [HOLD] 1 OrderItem = 1 HoldRelease = 1 FeeLedger
--   [SHOP] 1 User = 1 Shop; level giới hạn số sản phẩm (allowed_product_count)
--   [IDEM] UNIQUE (user_id, idempotency_key) trên orders — chặn double-submit ngay tại DB
--   [DLV] Nội dung giao khách thống nhất tên delivery_content:
--         INSTANT   : import TXT, 1 dòng = 1 asset → digital_assets.delivery_content;
--                     khi giao SNAPSHOT nguyên văn vào asset_delivery_logs.delivery_content_snapshot
--                     → buyer xem lại TỪ SNAPSHOT, không đọc lại kho
--         PRE_ORDER : shop nhập account/key/tin nhắn → pre_order_items.delivery_content
--                     (+ delivery_content_type ACCOUNT|KEY|MESSAGE|OTHER)
--         seller_notes = ghi chú NỘI BỘ của shop, KHÔNG dùng để giao hàng
--
-- Cách dùng:
--   psql -h localhost -p 5678 -U postgres -d commercehub_db -f schema-v8.sql
--   File idempotent — chạy lại an toàn, KHÔNG mất dữ liệu wallet_transactions
--   (bảng cũ chưa partition được ĐỔI TÊN thành wallet_transactions_legacy đúng 1 lần,
--    dữ liệu giữ nguyên — không DROP; đối soát xong tự DROP bảng legacy thủ công).
-- ============================================================

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================
-- MODULE 1: AUTH & USER
-- ============================================================

CREATE TABLE IF NOT EXISTS roles (
    id          BIGSERIAL    PRIMARY KEY,
    name        VARCHAR(50)  NOT NULL UNIQUE,
    description VARCHAR(255),
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS level_configs (
    level                 INT           PRIMARY KEY,
    label                 VARCHAR(50)   NOT NULL,
    min_spent             NUMERIC(18,2) NOT NULL DEFAULT 0,
    allowed_product_count INT           NOT NULL DEFAULT 0,
    description           VARCHAR(255)
);

CREATE TABLE IF NOT EXISTS users (
    id                 BIGSERIAL     PRIMARY KEY,
    email              VARCHAR(255)  NOT NULL UNIQUE,
    phone              VARCHAR(20)   UNIQUE,
    username           VARCHAR(100)  UNIQUE,
    username_changed_at TIMESTAMPTZ,
    password_hash      VARCHAR(255)  NOT NULL,
    full_name          VARCHAR(255)  NOT NULL,
    avatar_url         VARCHAR(500),
    status             VARCHAR(30)   NOT NULL DEFAULT 'ACTIVE'
                           CHECK (status IN ('ACTIVE','BANNED','SUSPENDED')),
    ban_reason         TEXT,
    last_active_at     TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    user_level         INT           NOT NULL DEFAULT 1 REFERENCES level_configs(level),
    accumulated_spent  NUMERIC(18,2) NOT NULL DEFAULT 0,
    accumulated_earned NUMERIC(18,2) NOT NULL DEFAULT 0,
    is_email_verified  BOOLEAN       NOT NULL DEFAULT FALSE,
    is_phone_verified  BOOLEAN       NOT NULL DEFAULT FALSE,
    provider           VARCHAR(30),
    created_at         TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at         TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS user_roles (
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role_id BIGINT NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    PRIMARY KEY (user_id, role_id)
);

CREATE TABLE IF NOT EXISTS refresh_tokens (
    id         BIGSERIAL   PRIMARY KEY,
    user_id    BIGINT      NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token      TEXT        NOT NULL UNIQUE,
    device_id  VARCHAR(255),
    ip_address VARCHAR(45),
    expires_at TIMESTAMPTZ NOT NULL,
    revoked    BOOLEAN     NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user ON refresh_tokens(user_id) WHERE revoked = FALSE;

CREATE TABLE IF NOT EXISTS email_verification_tokens (
    id         BIGSERIAL   PRIMARY KEY,
    user_id    BIGINT      NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token      TEXT        NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ NOT NULL,
    used       BOOLEAN     NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS password_reset_tokens (
    id         BIGSERIAL   PRIMARY KEY,
    user_id    BIGINT      NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token      TEXT        NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ NOT NULL,
    used       BOOLEAN     NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- MODULE 2: WALLET & MONEY FLOW
-- ============================================================

CREATE TABLE IF NOT EXISTS wallets (
    id                BIGSERIAL     PRIMARY KEY,
    user_id           BIGINT        UNIQUE REFERENCES users(id),
    available_balance NUMERIC(18,2) NOT NULL DEFAULT 0 CHECK (available_balance >= 0),
    hold_balance      NUMERIC(18,2) NOT NULL DEFAULT 0 CHECK (hold_balance >= 0),
    status            VARCHAR(30)   NOT NULL DEFAULT 'ACTIVE'
                          CHECK (status IN ('ACTIVE','LOCKED','FROZEN')),
    is_platform       BOOLEAN       NOT NULL DEFAULT FALSE,
    version           BIGINT        NOT NULL DEFAULT 0,
    created_at        TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_one_platform_wallet ON wallets(is_platform) WHERE is_platform = TRUE;

CREATE TABLE IF NOT EXISTS deposits (
    id               BIGSERIAL     PRIMARY KEY,
    user_id          BIGINT        NOT NULL REFERENCES users(id),
    wallet_id        BIGINT        NOT NULL REFERENCES wallets(id),
    amount           NUMERIC(18,2) NOT NULL CHECK (amount > 0),
    provider         VARCHAR(30)   NOT NULL CHECK (provider IN ('VNPAY','MOMO','ZALOPAY')),
    transaction_code VARCHAR(100)  UNIQUE,
    idempotency_key  VARCHAR(100)  UNIQUE,
    status           VARCHAR(30)   NOT NULL DEFAULT 'PENDING'
                         CHECK (status IN ('PENDING','SUCCESS','FAILED')),
    processed_at     TIMESTAMPTZ,
    created_at       TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_deposits_user ON deposits(user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS withdrawals (
    id              BIGSERIAL     PRIMARY KEY,
    wallet_id       BIGINT        NOT NULL REFERENCES wallets(id),
    amount          NUMERIC(18,2) NOT NULL CHECK (amount > 0),
    fee             NUMERIC(18,2) NOT NULL DEFAULT 0,
    bank_name       VARCHAR(100)  NOT NULL,
    account_number  VARCHAR(50)   NOT NULL,
    account_name    VARCHAR(100)  NOT NULL,
    idempotency_key VARCHAR(100)  UNIQUE,
    status          VARCHAR(30)   NOT NULL DEFAULT 'PENDING'
                        CHECK (status IN ('PENDING','APPROVED','REJECTED','DONE')),
    admin_note      TEXT,
    processor_id    BIGINT        REFERENCES users(id),
    created_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    processed_at    TIMESTAMPTZ,
    updated_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_withdrawals_status ON withdrawals(status, created_at DESC);

-- wallet_transactions (partitioned)
-- Migrate legacy đúng 1 lần: nếu bảng cũ tồn tại mà CHƯA partition thì ĐỔI TÊN thành
-- wallet_transactions_legacy (GIỮ NGUYÊN dữ liệu — KHÔNG drop lịch sử giao dịch),
-- kèm đổi tên index cũ để không đụng tên index của bảng partition mới.
-- Dữ liệu cũ KHÔNG tự copy sang bảng mới (khác cấu trúc/UUID) — đối soát xong,
-- tự chuyển những gì cần rồi DROP wallet_transactions_legacy thủ công.
-- Chạy lại file này sau đó sẽ KHÔNG đụng gì nữa (bảng chính đã là partition).
DO $$
DECLARE
    idx RECORD;
BEGIN
    IF EXISTS (
        SELECT 1
        FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = current_schema()
          AND c.relname = 'wallet_transactions'
          AND c.relkind = 'r'   -- bảng thường (chưa partition)
    ) THEN
        IF EXISTS (
            SELECT 1
            FROM pg_class c
            JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE n.nspname = current_schema()
              AND c.relname = 'wallet_transactions_legacy'
        ) THEN
            RAISE EXCEPTION 'wallet_transactions_legacy đã tồn tại — đối soát và DROP bảng backup này trước khi migrate lại';
        END IF;

        ALTER TABLE wallet_transactions RENAME TO wallet_transactions_legacy;

        FOR idx IN
            SELECT indexname
            FROM pg_indexes
            WHERE schemaname = current_schema()
              AND tablename = 'wallet_transactions_legacy'
        LOOP
            EXECUTE format('ALTER INDEX %I RENAME TO %I',
                           idx.indexname, left(idx.indexname || '_legacy', 63));
        END LOOP;

        RAISE NOTICE 'wallet_transactions cũ đã đổi tên thành wallet_transactions_legacy (dữ liệu giữ nguyên)';
    END IF;
END$$;

CREATE TABLE IF NOT EXISTS wallet_transactions (
    id               UUID          NOT NULL DEFAULT gen_random_uuid(),
    wallet_id        BIGINT        NOT NULL,
    transaction_type VARCHAR(30)   NOT NULL
                         CHECK (transaction_type IN (
                             'DEPOSIT','ORDER_PAYMENT','SALE_HOLD',
                             'HOLD_RELEASE','HOLD_RELEASE_NET','PLATFORM_FEE',
                             'ORDER_REFUND','DISPUTE_REFUND','REFUND',
                             'WITHDRAW_PENDING','WITHDRAW_DONE','WITHDRAW_CANCEL',
                             'CANCEL_HOLD','ADMIN_ADJUST'
                         )),
    balance_type     VARCHAR(20)   NOT NULL DEFAULT 'AVAILABLE'
                         CHECK (balance_type IN ('AVAILABLE','HOLD')),
    amount           NUMERIC(18,2) NOT NULL,
    balance_before   NUMERIC(18,2) NOT NULL,
    balance_after    NUMERIC(18,2) NOT NULL,
    reference_id     BIGINT,
    reference_type   VARCHAR(30),
    description      TEXT,
    created_at       TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

CREATE TABLE IF NOT EXISTS wt_2025_01 PARTITION OF wallet_transactions FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');
CREATE TABLE IF NOT EXISTS wt_2025_02 PARTITION OF wallet_transactions FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');
CREATE TABLE IF NOT EXISTS wt_2025_03 PARTITION OF wallet_transactions FOR VALUES FROM ('2025-03-01') TO ('2025-04-01');
CREATE TABLE IF NOT EXISTS wt_2025_04 PARTITION OF wallet_transactions FOR VALUES FROM ('2025-04-01') TO ('2025-05-01');
CREATE TABLE IF NOT EXISTS wt_2025_05 PARTITION OF wallet_transactions FOR VALUES FROM ('2025-05-01') TO ('2025-06-01');
CREATE TABLE IF NOT EXISTS wt_2025_06 PARTITION OF wallet_transactions FOR VALUES FROM ('2025-06-01') TO ('2025-07-01');
CREATE TABLE IF NOT EXISTS wt_2025_07 PARTITION OF wallet_transactions FOR VALUES FROM ('2025-07-01') TO ('2025-08-01');
CREATE TABLE IF NOT EXISTS wt_2025_08 PARTITION OF wallet_transactions FOR VALUES FROM ('2025-08-01') TO ('2025-09-01');
CREATE TABLE IF NOT EXISTS wt_2025_09 PARTITION OF wallet_transactions FOR VALUES FROM ('2025-09-01') TO ('2025-10-01');
CREATE TABLE IF NOT EXISTS wt_2025_10 PARTITION OF wallet_transactions FOR VALUES FROM ('2025-10-01') TO ('2025-11-01');
CREATE TABLE IF NOT EXISTS wt_2025_11 PARTITION OF wallet_transactions FOR VALUES FROM ('2025-11-01') TO ('2025-12-01');
CREATE TABLE IF NOT EXISTS wt_2025_12 PARTITION OF wallet_transactions FOR VALUES FROM ('2025-12-01') TO ('2026-01-01');
CREATE TABLE IF NOT EXISTS wt_2026_01 PARTITION OF wallet_transactions FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');
CREATE TABLE IF NOT EXISTS wt_2026_02 PARTITION OF wallet_transactions FOR VALUES FROM ('2026-02-01') TO ('2026-03-01');
CREATE TABLE IF NOT EXISTS wt_2026_03 PARTITION OF wallet_transactions FOR VALUES FROM ('2026-03-01') TO ('2026-04-01');
CREATE TABLE IF NOT EXISTS wt_2026_04 PARTITION OF wallet_transactions FOR VALUES FROM ('2026-04-01') TO ('2026-05-01');
CREATE TABLE IF NOT EXISTS wt_2026_05 PARTITION OF wallet_transactions FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');
CREATE TABLE IF NOT EXISTS wt_2026_06 PARTITION OF wallet_transactions FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');
CREATE TABLE IF NOT EXISTS wt_2026_07 PARTITION OF wallet_transactions FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
CREATE TABLE IF NOT EXISTS wt_2026_08 PARTITION OF wallet_transactions FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');
CREATE TABLE IF NOT EXISTS wt_2026_09 PARTITION OF wallet_transactions FOR VALUES FROM ('2026-09-01') TO ('2026-10-01');
CREATE TABLE IF NOT EXISTS wt_2026_10 PARTITION OF wallet_transactions FOR VALUES FROM ('2026-10-01') TO ('2026-11-01');
CREATE TABLE IF NOT EXISTS wt_2026_11 PARTITION OF wallet_transactions FOR VALUES FROM ('2026-11-01') TO ('2026-12-01');
CREATE TABLE IF NOT EXISTS wt_2026_12 PARTITION OF wallet_transactions FOR VALUES FROM ('2026-12-01') TO ('2027-01-01');
CREATE TABLE IF NOT EXISTS wt_2027_01 PARTITION OF wallet_transactions FOR VALUES FROM ('2027-01-01') TO ('2027-02-01');
CREATE TABLE IF NOT EXISTS wt_2027_02 PARTITION OF wallet_transactions FOR VALUES FROM ('2027-02-01') TO ('2027-03-01');
CREATE TABLE IF NOT EXISTS wt_2027_03 PARTITION OF wallet_transactions FOR VALUES FROM ('2027-03-01') TO ('2027-04-01');
CREATE TABLE IF NOT EXISTS wt_2027_04 PARTITION OF wallet_transactions FOR VALUES FROM ('2027-04-01') TO ('2027-05-01');
CREATE TABLE IF NOT EXISTS wt_2027_05 PARTITION OF wallet_transactions FOR VALUES FROM ('2027-05-01') TO ('2027-06-01');
CREATE TABLE IF NOT EXISTS wt_2027_06 PARTITION OF wallet_transactions FOR VALUES FROM ('2027-06-01') TO ('2027-07-01');
CREATE TABLE IF NOT EXISTS wt_2027_07 PARTITION OF wallet_transactions FOR VALUES FROM ('2027-07-01') TO ('2027-08-01');
CREATE TABLE IF NOT EXISTS wt_2027_08 PARTITION OF wallet_transactions FOR VALUES FROM ('2027-08-01') TO ('2027-09-01');
CREATE TABLE IF NOT EXISTS wt_2027_09 PARTITION OF wallet_transactions FOR VALUES FROM ('2027-09-01') TO ('2027-10-01');
CREATE TABLE IF NOT EXISTS wt_2027_10 PARTITION OF wallet_transactions FOR VALUES FROM ('2027-10-01') TO ('2027-11-01');
CREATE TABLE IF NOT EXISTS wt_2027_11 PARTITION OF wallet_transactions FOR VALUES FROM ('2027-11-01') TO ('2027-12-01');
CREATE TABLE IF NOT EXISTS wt_2027_12 PARTITION OF wallet_transactions FOR VALUES FROM ('2027-12-01') TO ('2028-01-01');
CREATE TABLE IF NOT EXISTS wt_default  PARTITION OF wallet_transactions DEFAULT;
-- LƯU Ý VẬN HÀNH: partition tháng chỉ tạo sẵn đến hết 2027-12. PartitionCreateScheduler (backend)
-- phải tạo wt_YYYY_MM TRƯỚC khi sang tháng mới. Nếu để giao dịch rơi vào wt_default, lệnh tạo
-- partition cho khoảng đó sẽ LỖI cho đến khi chuyển các dòng đó ra khỏi wt_default
-- (trong 1 transaction: DELETE ... RETURNING ra bảng tạm → tạo partition → INSERT lại).

CREATE INDEX IF NOT EXISTS idx_wt_wallet_created ON wallet_transactions(wallet_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_wt_type ON wallet_transactions(transaction_type, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_wt_reference ON wallet_transactions(reference_type, reference_id, created_at DESC)
    WHERE reference_id IS NOT NULL;

-- ============================================================
-- MODULE 3: SHOP (KHÔNG có favorite_shops)
-- ============================================================

CREATE TABLE IF NOT EXISTS shops (
    id               BIGSERIAL     PRIMARY KEY,
    owner_id         BIGINT        NOT NULL UNIQUE REFERENCES users(id),
    name             VARCHAR(255)  NOT NULL,
    slug             VARCHAR(255)  NOT NULL UNIQUE,
    shop_avatar_url  VARCHAR(500),
    shop_cover_url   VARCHAR(500),
    description      TEXT,
    total_orders     INT           NOT NULL DEFAULT 0,
    total_disputes   INT           NOT NULL DEFAULT 0,
    dispute_rate     NUMERIC(5,2)  NOT NULL DEFAULT 0,
    status           VARCHAR(30)   NOT NULL DEFAULT 'ACTIVE'
                         CHECK (status IN ('ACTIVE','SUSPENDED','CLOSED','INACTIVE','BANNED')),
    rating_avg       NUMERIC(3,2)  NOT NULL DEFAULT 0,
    created_at       TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS shop_images (
    id         BIGSERIAL    PRIMARY KEY,
    shop_id    BIGINT       NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
    image_url  VARCHAR(500) NOT NULL,
    image_type VARCHAR(30)  NOT NULL DEFAULT 'GALLERY'
                   CHECK (image_type IN ('GALLERY','LICENSE','VERIFY','OTHER')),
    sort_order INT          NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS shop_reports (
    id           BIGSERIAL    PRIMARY KEY,
    reporter_id  BIGINT       NOT NULL REFERENCES users(id),
    shop_id      BIGINT       NOT NULL REFERENCES shops(id),
    reason       TEXT         NOT NULL,
    evidence_url VARCHAR(500),
    status       VARCHAR(30)  NOT NULL DEFAULT 'PENDING'
                     CHECK (status IN ('PENDING','RESOLVED','DISMISSED')),
    admin_notes  TEXT,
    processor_id BIGINT       REFERENCES users(id),
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    resolved_at  TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_shop_reports_shop_status ON shop_reports(shop_id, status);

-- ============================================================
-- MODULE 4: CATEGORY / PRODUCT / ASSET
-- ============================================================

CREATE TABLE IF NOT EXISTS categories (
    id         BIGSERIAL    PRIMARY KEY,
    name       VARCHAR(255) NOT NULL,
    slug       VARCHAR(255) NOT NULL UNIQUE,
    icon_url   VARCHAR(500),
    is_active  BOOLEAN      NOT NULL DEFAULT TRUE,
    sort_order INT          NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS products (
    id                   BIGSERIAL     PRIMARY KEY,
    shop_id              BIGINT        NOT NULL REFERENCES shops(id),
    category_id          BIGINT        NOT NULL REFERENCES categories(id),
    name                 VARCHAR(255)  NOT NULL,
    slug                 VARCHAR(255)  NOT NULL UNIQUE,
    thumbnail_url        VARCHAR(500),
    short_description    VARCHAR(200),
    description          TEXT,
    product_type         VARCHAR(30)   NOT NULL DEFAULT 'ACCOUNT'
                             CHECK (product_type IN ('ACCOUNT','LICENSE','GIFTCARD','COOKIE','OTHER')),
    delivery_type        VARCHAR(20)   NOT NULL DEFAULT 'INSTANT'
                             CHECK (delivery_type IN ('INSTANT','PRE_ORDER')),
    status               VARCHAR(30)   NOT NULL DEFAULT 'ACTIVE'
                             CHECK (status IN ('ACTIVE','INACTIVE','DELETED')),
    sold_count           BIGINT        NOT NULL DEFAULT 0,
    failed_dispute_count BIGINT        NOT NULL DEFAULT 0,
    stock_count          INT,
    created_at           TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at           TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_products_shop ON products(shop_id, status);
CREATE INDEX IF NOT EXISTS idx_products_category ON products(category_id, status);
CREATE INDEX IF NOT EXISTS idx_products_delivery ON products(delivery_type, status);

CREATE TABLE IF NOT EXISTS pre_order_configs (
    id                         BIGSERIAL   PRIMARY KEY,
    product_id                 BIGINT      NOT NULL UNIQUE REFERENCES products(id) ON DELETE CASCADE,
    max_processing_hours       INT         NOT NULL DEFAULT 24,
    order_instructions         TEXT,
    buyer_input_fields         JSONB,
    auto_reject_if_unavailable BOOLEAN     NOT NULL DEFAULT FALSE,
    created_at                 TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at                 TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS product_variants (
    id            BIGSERIAL     PRIMARY KEY,
    product_id    BIGINT        NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    name          VARCHAR(100)  NOT NULL,
    duration_days INT,
    price         NUMERIC(18,2) NOT NULL CHECK (price >= 0),
    sort_order    INT           NOT NULL DEFAULT 0,
    status        VARCHAR(30)   NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','INACTIVE')),
    stock_count   INT           NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS digital_assets (
    id                  BIGSERIAL    PRIMARY KEY,
    product_variant_id  BIGINT       NOT NULL REFERENCES product_variants(id),
    asset_type          VARCHAR(50)  NOT NULL
                            CHECK (asset_type IN ('ACCOUNT','LICENSE','GIFTCARD','COOKIE','OTHER')),
    -- v8-DLV: NGUYÊN VĂN 1 dòng TXT giao cho khách (1 dòng TXT = 1 asset khi import).
    delivery_content    TEXT,
    -- asset_data: dữ liệu cũ/metadata — TEXT khớp entity DigitalAsset (Hibernate validate)
    asset_data          TEXT         NOT NULL,
    asset_identifier    VARCHAR(500),
    status              VARCHAR(30)  NOT NULL DEFAULT 'AVAILABLE'
                            CHECK (status IN ('AVAILABLE','RESERVED','SOLD','DISPUTED','REVOKED')),
    reserved_at         TIMESTAMPTZ,
    reserved_expires_at TIMESTAMPTZ,
    order_item_id       BIGINT,
    is_delivered        BOOLEAN      NOT NULL DEFAULT FALSE,
    delivered_at        TIMESTAMPTZ,
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_digital_assets_available
    ON digital_assets(product_variant_id, status) WHERE status = 'AVAILABLE';
CREATE INDEX IF NOT EXISTS idx_digital_assets_order_item
    ON digital_assets(order_item_id) WHERE order_item_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS product_images (
    id         BIGSERIAL    PRIMARY KEY,
    product_id BIGINT       NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    image_url  VARCHAR(500) NOT NULL,
    sort_order INT          NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS asset_delivery_logs (
    id                        BIGSERIAL   PRIMARY KEY,
    asset_id                  BIGINT      NOT NULL REFERENCES digital_assets(id),
    order_item_id             BIGINT      NOT NULL,
    buyer_id                  BIGINT      NOT NULL REFERENCES users(id),
    -- v8-DLV: bản chụp CỐ ĐỊNH nội dung đã giao — buyer mở lại đơn đọc từ đây,
    -- KHÔNG đọc lại digital_assets (kho có thể bị sửa/thu hồi sau khi bán)
    delivery_content_snapshot TEXT,
    asset_data_snapshot       JSONB       NOT NULL,
    delivery_method           VARCHAR(30) NOT NULL DEFAULT 'AUTO'
                                  CHECK (delivery_method IN ('AUTO','MANUAL','RESEND')),
    status                    VARCHAR(30) NOT NULL DEFAULT 'SUCCESS'
                                  CHECK (status IN ('SUCCESS','FAILED','RESENT')),
    error_message             TEXT,
    delivered_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_adl_order_item ON asset_delivery_logs(order_item_id);
CREATE INDEX IF NOT EXISTS idx_adl_buyer ON asset_delivery_logs(buyer_id, delivered_at DESC);

CREATE TABLE IF NOT EXISTS asset_access_logs (
    id          BIGSERIAL   PRIMARY KEY,
    asset_id    BIGINT      NOT NULL REFERENCES digital_assets(id),
    user_id     BIGINT      NOT NULL REFERENCES users(id),
    ip_address  VARCHAR(45),
    user_agent  TEXT,
    accessed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- MODULE 5: VOUCHER
-- ============================================================

CREATE TABLE IF NOT EXISTS vouchers (
    id                  BIGSERIAL     PRIMARY KEY,
    shop_id             BIGINT        NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
    code                VARCHAR(50)   NOT NULL,
    description         VARCHAR(255),
    discount_type       VARCHAR(20)   NOT NULL CHECK (discount_type IN ('PERCENT','FIXED')),
    discount_value      NUMERIC(18,2) NOT NULL CHECK (discount_value > 0),
    max_discount_amount NUMERIC(18,2),
    min_order_amount    NUMERIC(18,2) NOT NULL DEFAULT 0,
    apply_all_products  BOOLEAN       NOT NULL DEFAULT TRUE,
    starts_at           TIMESTAMPTZ   NOT NULL,
    expires_at          TIMESTAMPTZ   NOT NULL,
    usage_limit         INT           NOT NULL DEFAULT 1,
    used_count          INT           NOT NULL DEFAULT 0,
    is_active           BOOLEAN       NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_voucher_shop_code UNIQUE (shop_id, code),
    CONSTRAINT chk_voucher_dates CHECK (expires_at > starts_at)
);

CREATE TABLE IF NOT EXISTS voucher_products (
    voucher_id BIGINT NOT NULL REFERENCES vouchers(id) ON DELETE CASCADE,
    product_id BIGINT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    PRIMARY KEY (voucher_id, product_id)
);

CREATE TABLE IF NOT EXISTS voucher_usages (
    id              BIGSERIAL     PRIMARY KEY,
    voucher_id      BIGINT        NOT NULL REFERENCES vouchers(id),
    user_id         BIGINT        NOT NULL REFERENCES users(id),
    order_id        BIGINT        NOT NULL,
    discount_amount NUMERIC(18,2) NOT NULL,
    used_at         TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_voucher_user UNIQUE (voucher_id, user_id)
);

-- ============================================================
-- MODULE 6: CART (THAY THẾ FAVORITE)
-- ============================================================

CREATE TABLE IF NOT EXISTS carts (
    id         BIGSERIAL   PRIMARY KEY,
    user_id    BIGINT      NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS cart_items (
    id                 BIGSERIAL   PRIMARY KEY,
    cart_id            BIGINT      NOT NULL REFERENCES carts(id) ON DELETE CASCADE,
    product_variant_id BIGINT      NOT NULL REFERENCES product_variants(id),
    quantity           INT         NOT NULL CHECK (quantity > 0 AND quantity <= 1000),
    created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_cart_item_variant UNIQUE (cart_id, product_variant_id)
);
CREATE INDEX IF NOT EXISTS idx_cart_items_cart ON cart_items(cart_id);

-- ============================================================
-- MODULE 7: ORDER
-- ============================================================

CREATE TABLE IF NOT EXISTS orders (
    id                     BIGSERIAL     PRIMARY KEY,
    order_code             VARCHAR(50)   NOT NULL UNIQUE,
    user_id                BIGINT        NOT NULL REFERENCES users(id),
    shop_id                BIGINT        NOT NULL REFERENCES shops(id),
    cart_session_id        VARCHAR(100),
    voucher_id             BIGINT        REFERENCES vouchers(id),
    voucher_discount       NUMERIC(18,2) NOT NULL DEFAULT 0,
    delivery_type          VARCHAR(20)   NOT NULL DEFAULT 'INSTANT'
                               CHECK (delivery_type IN ('INSTANT','PRE_ORDER')),
    status                 VARCHAR(30)   NOT NULL DEFAULT 'PENDING',
    payment_status         VARCHAR(30)   NOT NULL DEFAULT 'UNPAID'
                               CHECK (payment_status IN ('UNPAID','PAID','REFUNDED','PARTIAL_REFUND')),
    -- v8: mua hàng CHỈ WALLET (VNPAY/MOMO/ZALOPAY chỉ dùng để NẠP ví — xem deposits.provider)
    payment_method         VARCHAR(30)   NOT NULL DEFAULT 'WALLET'
                               CHECK (payment_method = 'WALLET'),
    subtotal_amount        NUMERIC(18,2) NOT NULL,
    total_amount           NUMERIC(18,2) NOT NULL,
    placed_at              TIMESTAMPTZ,
    approved_at            TIMESTAMPTZ,
    rejected_at            TIMESTAMPTZ,
    delivered_at           TIMESTAMPTZ,
    approval_deadline_at   TIMESTAMPTZ,
    processing_deadline_at TIMESTAMPTZ,
    rejection_reason       TEXT,
    idempotency_key        VARCHAR(100),
    version                BIGINT        NOT NULL DEFAULT 0,
    created_at             TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at             TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_orders_user ON orders(user_id, status);
CREATE INDEX IF NOT EXISTS idx_orders_shop ON orders(shop_id, status);
-- Bản cũ là index thường → KHÔNG enforce idempotency; phải là UNIQUE
DROP INDEX IF EXISTS idx_orders_user_idem_key;
CREATE UNIQUE INDEX IF NOT EXISTS uq_orders_user_idem_key ON orders(user_id, idempotency_key)
    WHERE idempotency_key IS NOT NULL;

CREATE TABLE IF NOT EXISTS order_items (
    id                 BIGSERIAL     PRIMARY KEY,
    order_id           BIGINT        NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_variant_id BIGINT        NOT NULL REFERENCES product_variants(id),
    product_name       VARCHAR(255)  NOT NULL,
    variant_name       VARCHAR(100)  NOT NULL,
    product_type       VARCHAR(30)   NOT NULL,
    delivery_type      VARCHAR(20)   NOT NULL CHECK (delivery_type IN ('INSTANT','PRE_ORDER')),
    unit_price         NUMERIC(18,2) NOT NULL,
    quantity           INT           NOT NULL DEFAULT 1 CHECK (quantity > 0),
    line_total         NUMERIC(18,2) NOT NULL,
    -- Snapshot phí sàn chốt lúc buyer thanh toán
    fee_config_id      BIGINT,
    fee_rate_snapshot  NUMERIC(5,4),
    fee_amount         NUMERIC(18,2),
    seller_net_amount  NUMERIC(18,2),
    created_at         TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_order_items_order ON order_items(order_id);

-- v8-DLV: delivery_content = nội dung shop giao khách (account/key/tin nhắn), buyer xem lại
-- vĩnh viễn từ cột này. seller_notes = ghi chú NỘI BỘ, không bao giờ trả cho buyer.
-- Đã bỏ delivered_asset_data + shop_note (thay bằng delivery_content + seller_notes).
CREATE TABLE IF NOT EXISTS pre_order_items (
    id                    BIGSERIAL    PRIMARY KEY,
    order_item_id         BIGINT       NOT NULL UNIQUE REFERENCES order_items(id) ON DELETE CASCADE,
    buyer_inputs          TEXT,        -- JSON string — TEXT khớp entity PreOrderItem (Hibernate validate)
    buyer_note            TEXT,
    status                VARCHAR(30)  NOT NULL DEFAULT 'PENDING'
                              CHECK (status IN ('PENDING','ACCEPTED','PROCESSING','DELIVERED','REJECTED','CANCELLED')),
    delivery_content      TEXT,
    delivery_content_type VARCHAR(20),
    seller_notes          TEXT,
    accepted_at           TIMESTAMPTZ,
    delivered_at          TIMESTAMPTZ,
    completed_at          TIMESTAMPTZ,
    created_at            TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at            TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS order_status_logs (
    id          BIGSERIAL   PRIMARY KEY,
    order_id    BIGINT      NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    from_status VARCHAR(30),
    to_status   VARCHAR(30) NOT NULL,
    changed_by  BIGINT      REFERENCES users(id),
    note        TEXT,
    meta        JSONB,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- FK ngược
ALTER TABLE digital_assets DROP CONSTRAINT IF EXISTS fk_da_order_item;
ALTER TABLE digital_assets ADD CONSTRAINT fk_da_order_item
    FOREIGN KEY (order_item_id) REFERENCES order_items(id);
ALTER TABLE voucher_usages DROP CONSTRAINT IF EXISTS fk_vu_order;
ALTER TABLE voucher_usages ADD CONSTRAINT fk_vu_order
    FOREIGN KEY (order_id) REFERENCES orders(id);
ALTER TABLE asset_delivery_logs DROP CONSTRAINT IF EXISTS fk_adl_order_item;
ALTER TABLE asset_delivery_logs ADD CONSTRAINT fk_adl_order_item
    FOREIGN KEY (order_item_id) REFERENCES order_items(id);

-- ============================================================
-- MODULE 8: PLATFORM FEE (KHÔNG WAIVE)
-- Status ledger: PENDING | COLLECTED | CANCELLED | ADJUSTED
-- ============================================================

CREATE TABLE IF NOT EXISTS platform_fee_configs (
    id              BIGSERIAL     PRIMARY KEY,
    fee_rate        NUMERIC(5,4)  NOT NULL CHECK (fee_rate >= 0 AND fee_rate <= 1),
    min_fee_amount  NUMERIC(18,2) NOT NULL DEFAULT 0 CHECK (min_fee_amount >= 0),
    max_fee_amount  NUMERIC(18,2),
    description     VARCHAR(255),
    is_active       BOOLEAN       NOT NULL DEFAULT TRUE,
    effective_from  TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    effective_until TIMESTAMPTZ,
    created_by      BIGINT        NOT NULL REFERENCES users(id),
    created_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_fee_dates CHECK (effective_until IS NULL OR effective_until > effective_from),
    CONSTRAINT chk_fee_min_max CHECK (max_fee_amount IS NULL OR max_fee_amount >= min_fee_amount)
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_active_fee_config ON platform_fee_configs(is_active) WHERE is_active = TRUE;

CREATE TABLE IF NOT EXISTS hold_releases (
    id                     BIGSERIAL     PRIMARY KEY,
    wallet_id              BIGINT        NOT NULL REFERENCES wallets(id),
    order_id               BIGINT        NOT NULL REFERENCES orders(id),
    order_item_id          BIGINT        NOT NULL UNIQUE REFERENCES order_items(id),  -- v8: 1 OrderItem = 1 HoldRelease
    hold_amount            NUMERIC(18,2) NOT NULL CHECK (hold_amount > 0),
    fee_amount             NUMERIC(18,2) NOT NULL DEFAULT 0 CHECK (fee_amount >= 0),
    seller_net_amount      NUMERIC(18,2) NOT NULL CHECK (seller_net_amount >= 0),
    fee_ledger_id          BIGINT,
    status                 VARCHAR(30)   NOT NULL DEFAULT 'HOLDING'
                               CHECK (status IN (
                                   'HOLDING','COMPLAINED','WARRANTY_IN_PROGRESS',
                                   'DISPUTED','RELEASED','REFUNDED'
                               )),
    scheduled_release_at   TIMESTAMPTZ   NOT NULL,
    released_at            TIMESTAMPTZ,
    complaint_reason       TEXT,
    complained_at          TIMESTAMPTZ,
    remaining_hold_seconds BIGINT,
    warranty_started_at    TIMESTAMPTZ,
    created_at             TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_hold_fee_net CHECK (hold_amount = fee_amount + seller_net_amount)
);
CREATE INDEX IF NOT EXISTS idx_hold_releases_job ON hold_releases(scheduled_release_at)
    WHERE status = 'HOLDING';

CREATE TABLE IF NOT EXISTS platform_fee_ledgers (
    id                   BIGSERIAL     PRIMARY KEY,
    order_item_id        BIGINT        NOT NULL UNIQUE REFERENCES order_items(id),
    order_id             BIGINT        NOT NULL REFERENCES orders(id),
    shop_id              BIGINT        NOT NULL REFERENCES shops(id),
    seller_wallet_id     BIGINT        NOT NULL REFERENCES wallets(id),
    fee_config_id        BIGINT        NOT NULL REFERENCES platform_fee_configs(id),
    fee_rate_snapshot    NUMERIC(5,4)  NOT NULL,
    sale_amount          NUMERIC(18,2) NOT NULL CHECK (sale_amount > 0),
    fee_amount           NUMERIC(18,2) NOT NULL CHECK (fee_amount >= 0),
    seller_net_amount    NUMERIC(18,2) NOT NULL CHECK (seller_net_amount >= 0),
    adjusted_sale_amount NUMERIC(18,2),
    adjusted_fee_amount  NUMERIC(18,2),
    adjusted_seller_net  NUMERIC(18,2),
    adjustment_reason    TEXT,
    status               VARCHAR(20)   NOT NULL DEFAULT 'PENDING'
                             CHECK (status IN ('PENDING','COLLECTED','CANCELLED','ADJUSTED')),
    fee_incurred_at      TIMESTAMPTZ   NOT NULL,
    collected_at         TIMESTAMPTZ,
    cancelled_at         TIMESTAMPTZ,
    hold_release_id      BIGINT,
    dispute_id           BIGINT,
    created_at           TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at           TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_fee_sale_net CHECK (sale_amount = fee_amount + seller_net_amount)
);
CREATE INDEX IF NOT EXISTS idx_fee_ledger_shop ON platform_fee_ledgers(shop_id, status, fee_incurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_fee_ledger_pending ON platform_fee_ledgers(fee_incurred_at) WHERE status = 'PENDING';

CREATE TABLE IF NOT EXISTS platform_fee_logs (
    id            BIGSERIAL     PRIMARY KEY,
    fee_ledger_id BIGINT        NOT NULL REFERENCES platform_fee_ledgers(id),
    from_status   VARCHAR(20),
    to_status     VARCHAR(20)   NOT NULL,
    fee_amount    NUMERIC(18,2) NOT NULL CHECK (fee_amount >= 0),
    changed_by    BIGINT        REFERENCES users(id),
    reason        TEXT,
    meta          JSONB,
    created_at    TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS shop_fee_summaries (
    id             BIGSERIAL     PRIMARY KEY,
    shop_id        BIGINT        NOT NULL REFERENCES shops(id),
    period_year    INT           NOT NULL,
    period_month   INT           NOT NULL CHECK (period_month BETWEEN 1 AND 12),
    total_sales    NUMERIC(18,2) NOT NULL DEFAULT 0,
    total_fee      NUMERIC(18,2) NOT NULL DEFAULT 0,
    total_net      NUMERIC(18,2) NOT NULL DEFAULT 0,
    total_refunded NUMERIC(18,2) NOT NULL DEFAULT 0,
    order_count    INT           NOT NULL DEFAULT 0,
    dispute_count  INT           NOT NULL DEFAULT 0,
    updated_at     TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_shop_fee_period UNIQUE (shop_id, period_year, period_month)
);

-- Circular FK fee ↔ hold
ALTER TABLE platform_fee_ledgers DROP CONSTRAINT IF EXISTS fk_fee_hold_release;
ALTER TABLE platform_fee_ledgers ADD CONSTRAINT fk_fee_hold_release
    FOREIGN KEY (hold_release_id) REFERENCES hold_releases(id);
ALTER TABLE hold_releases DROP CONSTRAINT IF EXISTS fk_hold_fee_ledger;
ALTER TABLE hold_releases ADD CONSTRAINT fk_hold_fee_ledger
    FOREIGN KEY (fee_ledger_id) REFERENCES platform_fee_ledgers(id);

-- ============================================================
-- MODULE 9: DISPUTE & REVIEW
-- ============================================================

CREATE TABLE IF NOT EXISTS order_disputes (
    id                 BIGSERIAL     PRIMARY KEY,
    order_id           BIGINT        NOT NULL REFERENCES orders(id),
    order_item_id      BIGINT        NOT NULL UNIQUE REFERENCES order_items(id),
    user_id            BIGINT        NOT NULL REFERENCES users(id),
    shop_id            BIGINT        NOT NULL REFERENCES shops(id),
    reason             TEXT          NOT NULL,
    evidence_urls      TEXT[],
    shop_response      TEXT,
    shop_evidence_urls TEXT[],
    status             VARCHAR(30)   NOT NULL DEFAULT 'OPEN'
                           CHECK (status IN ('OPEN','PROCESSING','BUYER_WIN','SELLER_WIN','PARTIAL_REFUND','CLOSED')),
    refund_amount      NUMERIC(18,2),
    admin_note         TEXT,
    resolver_id        BIGINT        REFERENCES users(id),
    created_at         TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    deadline_at        TIMESTAMPTZ   NOT NULL,
    resolved_at        TIMESTAMPTZ,
    updated_at         TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

ALTER TABLE platform_fee_ledgers DROP CONSTRAINT IF EXISTS fk_fee_dispute;
ALTER TABLE platform_fee_ledgers ADD CONSTRAINT fk_fee_dispute
    FOREIGN KEY (dispute_id) REFERENCES order_disputes(id);

CREATE TABLE IF NOT EXISTS product_reviews (
    id            BIGSERIAL   PRIMARY KEY,
    product_id    BIGINT      NOT NULL REFERENCES products(id),
    order_item_id BIGINT      NOT NULL UNIQUE REFERENCES order_items(id),
    user_id       BIGINT      NOT NULL REFERENCES users(id),
    rating        INT         NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment       TEXT,
    is_visible    BOOLEAN     NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ
);

-- ============================================================
-- MODULE 10: CHAT / NOTIFICATION / AUDIT / FRAUD / OPS
-- ============================================================

CREATE TABLE IF NOT EXISTS chat_rooms (
    id               BIGSERIAL   PRIMARY KEY,
    participant_a    BIGINT      NOT NULL REFERENCES users(id),
    participant_b    BIGINT      NOT NULL REFERENCES users(id),
    shop_id          BIGINT      REFERENCES shops(id),
    related_order_id BIGINT      REFERENCES orders(id),
    last_message_at  TIMESTAMPTZ,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_participants CHECK (participant_a < participant_b)
);
-- UNIQUE (a,b,shop_id) KHÔNG chặn trùng khi shop_id IS NULL (NULL != NULL trong UNIQUE)
-- → thay bằng 2 partial unique index để chặn trùng cả 2 trường hợp
ALTER TABLE chat_rooms DROP CONSTRAINT IF EXISTS uq_chat_room;
CREATE UNIQUE INDEX IF NOT EXISTS uq_chat_room_shop
    ON chat_rooms(participant_a, participant_b, shop_id) WHERE shop_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uq_chat_room_direct
    ON chat_rooms(participant_a, participant_b) WHERE shop_id IS NULL;

CREATE TABLE IF NOT EXISTS chat_messages (
    id              BIGSERIAL   PRIMARY KEY,
    room_id         BIGINT      NOT NULL REFERENCES chat_rooms(id) ON DELETE CASCADE,
    sender_id       BIGINT      NOT NULL REFERENCES users(id),
    content         TEXT        NOT NULL,
    attachment_url  VARCHAR(500),
    attachment_type VARCHAR(30),
    is_read         BOOLEAN     NOT NULL DEFAULT FALSE,
    sent_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_chat_messages_room ON chat_messages(room_id, sent_at DESC);

CREATE TABLE IF NOT EXISTS notifications (
    id          BIGSERIAL    PRIMARY KEY,
    user_id     BIGINT       NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type        VARCHAR(50)  NOT NULL,
    title       VARCHAR(255) NOT NULL,
    content     TEXT         NOT NULL,
    ref_id      BIGINT,
    ref_type    VARCHAR(30),
    is_read     BOOLEAN      NOT NULL DEFAULT FALSE,
    expires_at  TIMESTAMPTZ,
    archived_at TIMESTAMPTZ,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id, is_read, created_at DESC)
    WHERE archived_at IS NULL;

CREATE TABLE IF NOT EXISTS audit_logs (
    id          BIGSERIAL    PRIMARY KEY,
    actor_id    BIGINT       NOT NULL REFERENCES users(id),
    actor_role  VARCHAR(50)  NOT NULL,
    action      VARCHAR(100) NOT NULL,
    target_type VARCHAR(50)  NOT NULL,
    target_id   BIGINT       NOT NULL,
    old_value   JSONB,
    new_value   JSONB,
    reason      TEXT,
    ip_address  VARCHAR(45),
    user_agent  TEXT,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_audit_logs_target ON audit_logs(target_type, target_id, created_at DESC);

CREATE TABLE IF NOT EXISTS user_login_logs (
    id             BIGSERIAL    PRIMARY KEY,
    user_id        BIGINT       NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    ip_address     VARCHAR(45)  NOT NULL,
    user_agent     TEXT,
    device_id      VARCHAR(255),
    country_code   VARCHAR(10),
    status         VARCHAR(30)  NOT NULL CHECK (status IN ('SUCCESS','FAILED','BLOCKED')),
    failure_reason VARCHAR(100),
    created_at     TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_user_login_logs_user ON user_login_logs(user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS risk_flags (
    id           BIGSERIAL    PRIMARY KEY,
    entity_type  VARCHAR(30)  NOT NULL CHECK (entity_type IN ('USER','SHOP','WALLET')),
    entity_id    BIGINT       NOT NULL,
    flag_type    VARCHAR(100) NOT NULL,
    severity     VARCHAR(20)  NOT NULL DEFAULT 'MEDIUM'
                     CHECK (severity IN ('LOW','MEDIUM','HIGH','CRITICAL')),
    description  TEXT,
    is_resolved  BOOLEAN      NOT NULL DEFAULT FALSE,
    resolved_by  BIGINT       REFERENCES users(id),
    resolved_at  TIMESTAMPTZ,
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_risk_flags_open ON risk_flags(entity_type, entity_id) WHERE is_resolved = FALSE;

CREATE TABLE IF NOT EXISTS outbox_events (
    id             UUID         NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    aggregate_type VARCHAR(50)  NOT NULL,
    aggregate_id   BIGINT       NOT NULL,
    event_type     VARCHAR(100) NOT NULL,
    payload        JSONB        NOT NULL,
    status         VARCHAR(20)  NOT NULL DEFAULT 'PENDING'
                       CHECK (status IN ('PENDING','PUBLISHED','FAILED')),
    retry_count    INT          NOT NULL DEFAULT 0,
    last_error     TEXT,
    created_at     TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    published_at   TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_outbox_pending ON outbox_events(created_at) WHERE status = 'PENDING';

CREATE TABLE IF NOT EXISTS idempotency_keys (
    id             BIGSERIAL    PRIMARY KEY,
    key_value      VARCHAR(100) NOT NULL UNIQUE,
    operation_type VARCHAR(100) NOT NULL,
    user_id        BIGINT       NOT NULL REFERENCES users(id),
    response_body  JSONB,
    status         VARCHAR(20)  NOT NULL DEFAULT 'PROCESSING'
                       CHECK (status IN ('PROCESSING','DONE','FAILED')),
    expires_at     TIMESTAMPTZ  NOT NULL DEFAULT NOW() + INTERVAL '24 hours',
    created_at     TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS job_logs (
    id              BIGSERIAL    PRIMARY KEY,
    job_type        VARCHAR(100) NOT NULL,
    status          VARCHAR(20)  NOT NULL DEFAULT 'RUNNING'
                        CHECK (status IN ('RUNNING','SUCCESS','FAILED','PARTIAL')),
    started_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    finished_at     TIMESTAMPTZ,
    processed_count INT          NOT NULL DEFAULT 0,
    error_message   TEXT,
    meta            JSONB
);

CREATE TABLE IF NOT EXISTS shedlock (
    name       VARCHAR(64)  NOT NULL PRIMARY KEY,
    lock_until TIMESTAMP    NOT NULL,
    locked_at  TIMESTAMP    NOT NULL,
    locked_by  VARCHAR(255) NOT NULL
);

-- ============================================================
-- UPGRADE (DB đã tạo bằng bản cũ của file này) + CLEANUP LEGACY
-- ============================================================
-- Idempotent: DB mới thì các cột đã có sẵn trong CREATE TABLE, ALTER bên dưới bị bỏ qua.
ALTER TABLE digital_assets      ADD COLUMN IF NOT EXISTS delivery_content TEXT;
-- DB cũ tạo cột dạng JSONB → đổi sang TEXT khớp entity (Hibernate validate)
ALTER TABLE digital_assets      ALTER COLUMN asset_data   TYPE TEXT USING asset_data::text;
ALTER TABLE pre_order_items     ALTER COLUMN buyer_inputs TYPE TEXT USING buyer_inputs::text;
ALTER TABLE asset_delivery_logs ADD COLUMN IF NOT EXISTS delivery_content_snapshot TEXT;
ALTER TABLE pre_order_items     ADD COLUMN IF NOT EXISTS delivery_content TEXT;
ALTER TABLE pre_order_items     ADD COLUMN IF NOT EXISTS delivery_content_type VARCHAR(20);
ALTER TABLE pre_order_items     ADD COLUMN IF NOT EXISTS accepted_at TIMESTAMPTZ;
ALTER TABLE pre_order_items     ADD COLUMN IF NOT EXISTS delivered_at TIMESTAMPTZ;

ALTER TABLE pre_order_items DROP CONSTRAINT IF EXISTS chk_pre_order_delivery_content_type;
ALTER TABLE pre_order_items ADD CONSTRAINT chk_pre_order_delivery_content_type
    CHECK (delivery_content_type IS NULL
           OR delivery_content_type IN ('ACCOUNT','KEY','MESSAGE','OTHER'));

-- DB cũ có thể còn cột delivered_asset_data / shop_note trên pre_order_items:
-- giữ nguyên để đối soát, chuyển dữ liệu sang delivery_content xong thì DROP thủ công.

DROP TABLE IF EXISTS favorite_shops CASCADE;

-- ============================================================
-- SEED DATA
-- ============================================================

INSERT INTO roles (name, description) VALUES
    ('SUPER_ADMIN', 'Quyền cao nhất'),
    ('ADMIN',       'Quản trị viên'),
    ('SELLER',      'Người bán hàng'),
    ('BUYER',       'Người mua hàng')
ON CONFLICT (name) DO NOTHING;

INSERT INTO level_configs (level, label, min_spent, allowed_product_count, description) VALUES
    (1, 'Đồng',      0,           5,   'Shop đăng tối đa 5 sản phẩm'),
    (2, 'Bạc',       5000000,     20,  'Shop đăng tối đa 20 sản phẩm'),
    (3, 'Vàng',      20000000,    100, 'Shop đăng tối đa 100 sản phẩm'),
    (4, 'Kim Cương', 100000000,   500, 'Shop đăng tối đa 500 sản phẩm')
ON CONFLICT (level) DO UPDATE SET
    allowed_product_count = EXCLUDED.allowed_product_count,
    label = EXCLUDED.label,
    min_spent = EXCLUDED.min_spent,
    description = EXCLUDED.description;

INSERT INTO categories (name, slug, sort_order, is_active) VALUES
    ('Netflix',         'netflix',          1,  true),
    ('Spotify',         'spotify',          2,  true),
    ('YouTube Premium', 'youtube-premium',  3,  true),
    ('ChatGPT Plus',    'chatgpt-plus',     4,  true),
    ('Steam',           'steam',            5,  true),
    ('Canva Pro',       'canva-pro',        6,  true),
    ('Adobe Creative',  'adobe-creative',   7,  true),
    ('Microsoft 365',   'microsoft-365',    8,  true),
    ('Game Account',    'game-account',     9,  true),
    ('Khác',            'other',            99, true)
ON CONFLICT (slug) DO NOTHING;

INSERT INTO wallets (user_id, available_balance, hold_balance, status, is_platform, version, updated_at)
SELECT NULL, 0, 0, 'ACTIVE', true, 0, NOW()
WHERE NOT EXISTS (SELECT 1 FROM wallets WHERE is_platform = true)
ON CONFLICT (is_platform) WHERE is_platform = TRUE DO NOTHING;  -- chống race khi 2 tiến trình cùng seed

-- Fee 4% — cần ít nhất 1 user (FK created_by). Chạy lại sau khi có admin.
INSERT INTO platform_fee_configs
    (fee_rate, min_fee_amount, max_fee_amount, description, is_active, effective_from, created_by, created_at)
SELECT 0.0400, 0, NULL, 'Phí sàn mặc định 4% (v8)', true, NOW(), seed_user.id, NOW()
FROM (
    SELECT u.id FROM users u
    ORDER BY (EXISTS (
        SELECT 1 FROM user_roles ur JOIN roles r ON r.id = ur.role_id
        WHERE ur.user_id = u.id AND r.name IN ('ADMIN','SUPER_ADMIN')
    )) DESC, u.id ASC
    LIMIT 1
) seed_user
WHERE NOT EXISTS (SELECT 1 FROM platform_fee_configs WHERE is_active = true)
ON CONFLICT (is_active) WHERE is_active = TRUE DO NOTHING;  -- chống race khi 2 tiến trình cùng seed

COMMIT;

-- ============================================================
-- TỔNG KẾT LUỒNG TIỀN v8
-- ============================================================
-- A. NẠP TIỀN: VNPay IPN → đối chiếu amount → DEPOSIT vào ví buyer
-- B. CHECKOUT (cart hoặc buy-now): luôn WALLET
--      buyer.available -= total
--      seller.hold     += total
--      mỗi item: snapshot fee (4%, CEILING) → HoldRelease + FeeLedger PENDING
-- C. PRE_ORDER: trừ ví NGAY lúc checkout; reject/cancel → hoàn tiền
-- D. T+7: seller.available += net; platform += fee; ledger COLLECTED
-- E. DISPUTE buyer win: refund buyer, cancel hold, ledger CANCELLED (không waive)
-- F. ĐỐI SOÁT (fee 4%, CEILING):
--      sale 19500 → fee 780, net 18720   (780 + 18720 = 19500)
--      sale 100   → fee 4,   net 96      (4 + 96 = 100)
--      subtotal 20000, voucher 400 → sale 19600 → fee 784, net 18816
--      (voucher 400 + net 18816 + fee 784 = 20000)
-- G. GIAO HÀNG (delivery_content):
--      INSTANT   : import TXT (1 dòng = 1 asset AVAILABLE) → mua: lock + RESERVED
--                  → thanh toán OK: snapshot nguyên văn vào asset_delivery_logs
--                  → asset SOLD; buyer xem lại TỪ delivery_content_snapshot (không đọc kho)
--      PRE_ORDER : PENDING → ACCEPTED (accepted_at) → PROCESSING
--                  → shop nhập delivery_content (+type) → DELIVERED (delivered_at)
--                  hoặc PENDING → REJECTED / CANCELLED (hoàn tiền)
--      BẢO MẬT   : không log nội dung; chỉ trả trong API chi tiết đơn (buyer sở hữu,
--                  shop bán — phục vụ bảo hành, admin); Cache-Control: no-store;
--                  không đưa nội dung vào URL; cân nhắc mã hóa at-rest (AES-GCM/pgcrypto)
-- ============================================================

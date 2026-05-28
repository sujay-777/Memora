-- ============================================================
-- V2 : Add highlights, resurfacing_events, compiled_documents
-- ============================================================

CREATE TABLE highlights (
    id                  UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    content_item_id     UUID        NOT NULL REFERENCES content_items(id) ON DELETE CASCADE,
    user_id             UUID        NOT NULL REFERENCES users(id)          ON DELETE CASCADE,
    selected_text       TEXT        NOT NULL,
    surrounding_context TEXT,
    page_url            TEXT,
    page_title          TEXT,
    highlight_color     VARCHAR(20) DEFAULT 'yellow',
    position_data       JSONB,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE resurfacing_events (
    id               UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id          UUID         NOT NULL REFERENCES users(id)          ON DELETE CASCADE,
    content_item_id  UUID         NOT NULL REFERENCES content_items(id)  ON DELETE CASCADE,
    trigger_context  TEXT,
    similarity_score DECIMAL(5,4),
    was_accepted     BOOLEAN,
    was_dismissed    BOOLEAN,
    created_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE compiled_documents (
    id                  UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id             UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title               TEXT,
    compiled_text       TEXT,
    source_content_ids  JSONB,
    pdf_minio_key       TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_highlights_user_id
    ON highlights(user_id);

CREATE INDEX idx_highlights_content_item_id
    ON highlights(content_item_id);

CREATE INDEX idx_resurfacing_user_id
    ON resurfacing_events(user_id);

CREATE INDEX idx_resurfacing_content_item_id
    ON resurfacing_events(content_item_id);

CREATE INDEX idx_compiled_documents_user_id
    ON compiled_documents(user_id);

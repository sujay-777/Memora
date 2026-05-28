-- ============================================================
-- V1 : Initial schema for Memora
-- ============================================================

-- Enable UUID generation extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- users
-- Note: email is stored encrypted (Jasypt) at the application
--       layer, so the column type is TEXT to hold ciphertext.
-- ============================================================
CREATE TABLE users (
    id              UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    email           TEXT        NOT NULL UNIQUE,
    display_name    VARCHAR(255),
    password_hash   TEXT        NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- topics
-- ============================================================
CREATE TABLE topics (
    id              UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name            VARCHAR(255) NOT NULL,
    description     TEXT,
    auto_detected   BOOLEAN     NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- topic_clusters
-- ============================================================
CREATE TABLE topic_clusters (
    id              UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name            VARCHAR(255) NOT NULL,
    description     TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Junction: a cluster groups many topics
CREATE TABLE topic_cluster_topics (
    cluster_id      UUID NOT NULL REFERENCES topic_clusters(id) ON DELETE CASCADE,
    topic_id        UUID NOT NULL REFERENCES topics(id)         ON DELETE CASCADE,
    PRIMARY KEY (cluster_id, topic_id)
);

-- ============================================================
-- content_items
-- Note: raw_content and source_url are encrypted (Jasypt).
-- ============================================================
CREATE TABLE content_items (
    id                    UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id               UUID         NOT NULL REFERENCES users(id)  ON DELETE CASCADE,
    content_type          VARCHAR(50)  NOT NULL,
    raw_content           TEXT,
    source_url            TEXT,
    source_title          TEXT,
    minio_object_key      TEXT,
    topic_id              UUID         REFERENCES topics(id) ON DELETE SET NULL,
    embedding_id          VARCHAR(255),
    auto_detected_topic   VARCHAR(255),
    created_at            TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at            TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_content_type CHECK (
        content_type IN ('TEXT', 'IMAGE', 'PDF', 'NOTE', 'SCREENSHOT', 'DIAGRAM')
    )
);

-- ============================================================
-- study_sessions
-- ============================================================
CREATE TABLE study_sessions (
    id               UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id          UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    topic_id         UUID        REFERENCES topics(id) ON DELETE SET NULL,
    started_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ended_at         TIMESTAMPTZ,
    active_url       TEXT,
    session_metadata JSONB
);

-- Junction: a session surfaces many content items
CREATE TABLE study_session_content_items (
    session_id      UUID NOT NULL REFERENCES study_sessions(id)  ON DELETE CASCADE,
    content_item_id UUID NOT NULL REFERENCES content_items(id)   ON DELETE CASCADE,
    PRIMARY KEY (session_id, content_item_id)
);

-- ============================================================
-- exam_profiles
-- ============================================================
CREATE TABLE exam_profiles (
    id            UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id       UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    exam_name     VARCHAR(255) NOT NULL,
    syllabus_text TEXT,
    exam_date     DATE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- exam_topic_coverage
-- ============================================================
CREATE TABLE exam_topic_coverage (
    id               UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    exam_profile_id  UUID        NOT NULL REFERENCES exam_profiles(id) ON DELETE CASCADE,
    user_id          UUID        NOT NULL REFERENCES users(id)          ON DELETE CASCADE,
    topic_name       VARCHAR(255) NOT NULL,
    coverage_status  VARCHAR(50)  NOT NULL DEFAULT 'NOT_STARTED',
    content_count    INTEGER      NOT NULL DEFAULT 0,
    created_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_coverage_status CHECK (
        coverage_status IN ('NOT_STARTED', 'IN_PROGRESS', 'COVERED')
    )
);

-- ============================================================
-- Indexes
-- ============================================================
CREATE INDEX idx_users_email
    ON users(email);

CREATE INDEX idx_topics_user_id
    ON topics(user_id);

CREATE INDEX idx_topic_clusters_user_id
    ON topic_clusters(user_id);

CREATE INDEX idx_content_items_user_id
    ON content_items(user_id);

CREATE INDEX idx_content_items_topic_id
    ON content_items(topic_id);

CREATE INDEX idx_content_items_content_type
    ON content_items(content_type);

CREATE INDEX idx_study_sessions_user_id
    ON study_sessions(user_id);

CREATE INDEX idx_study_sessions_topic_id
    ON study_sessions(topic_id);

CREATE INDEX idx_exam_profiles_user_id
    ON exam_profiles(user_id);

CREATE INDEX idx_exam_topic_coverage_exam_profile_id
    ON exam_topic_coverage(exam_profile_id);

CREATE INDEX idx_exam_topic_coverage_user_id
    ON exam_topic_coverage(user_id);

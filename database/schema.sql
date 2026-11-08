-- ====================================================================
-- CONNEKT Platform Database Schema
-- PostgreSQL 15+ / 18+ Relational Schema
-- Architecture: UUID PKs, Normalized Relational Entities, Strict Constraints
-- ====================================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Enum Types (if not exist)
DO $$ BEGIN
    CREATE TYPE user_mode_type AS ENUM ('common', 'professional', 'both');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE user_role_type AS ENUM ('user', 'moderator', 'admin');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE user_status_type AS ENUM ('active', 'suspended', 'pending_otp', 'deactivated');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE otp_purpose_type AS ENUM ('registration', 'login', 'forgot_password', 'phone_change');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- --------------------------------------------------------------------
-- 1. USERS TABLE (Core Identity)
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phone VARCHAR(25) UNIQUE NOT NULL,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(120) UNIQUE NOT NULL, -- Connekt Mail ID (e.g. username@connekt.me)
    recovery_email VARCHAR(150),
    password_hash VARCHAR(255) NOT NULL,
    current_mode VARCHAR(20) NOT NULL DEFAULT 'common' CHECK (current_mode IN ('common', 'professional', 'both')),
    allowed_modes TEXT[] NOT NULL DEFAULT ARRAY['common', 'professional', 'both'],
    role VARCHAR(20) NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'moderator', 'admin')),
    status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'pending_otp', 'deactivated')),
    is_verified BOOLEAN NOT NULL DEFAULT true,
    last_login_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_phone ON users(phone);
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

-- --------------------------------------------------------------------
-- 2. USER PROFILES (Personal / Common Mode Profile)
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS user_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    full_name VARCHAR(120) NOT NULL,
    display_name VARCHAR(120),
    avatar_url TEXT DEFAULT '/assets/images/default-avatar.png',
    banner_url TEXT DEFAULT '/assets/images/default-banner.png',
    bio TEXT DEFAULT '',
    location VARCHAR(120) DEFAULT '',
    website VARCHAR(255) DEFAULT '',
    birthdate DATE,
    gender VARCHAR(30) DEFAULT '',
    interests TEXT[] DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_user_profiles_user_id ON user_profiles(user_id);

-- --------------------------------------------------------------------
-- 3. PROFESSIONAL PROFILES (Professional Mode Profile)
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS professional_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    headline VARCHAR(180) DEFAULT '',
    current_company VARCHAR(150) DEFAULT '',
    industry VARCHAR(120) DEFAULT '',
    summary TEXT DEFAULT '',
    years_of_experience INT DEFAULT 0,
    portfolio_url VARCHAR(255) DEFAULT '',
    github_url VARCHAR(255) DEFAULT '',
    linkedin_url VARCHAR(255) DEFAULT '',
    resume_url TEXT DEFAULT '',
    is_open_to_work BOOLEAN DEFAULT false,
    is_hiring BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_prof_profiles_user_id ON professional_profiles(user_id);

-- --------------------------------------------------------------------
-- 4. USER SKILLS
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS user_skills (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    skill_name VARCHAR(80) NOT NULL,
    proficiency VARCHAR(30) DEFAULT 'Intermediate',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, skill_name)
);

CREATE INDEX IF NOT EXISTS idx_user_skills_user_id ON user_skills(user_id);

-- --------------------------------------------------------------------
-- 5. USER EDUCATION
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS user_education (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    institution VARCHAR(180) NOT NULL,
    degree VARCHAR(120) NOT NULL,
    field_of_study VARCHAR(120),
    start_year INT,
    end_year INT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_user_education_user_id ON user_education(user_id);

-- --------------------------------------------------------------------
-- 6. USER EXPERIENCE
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS user_experience (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    company_name VARCHAR(180) NOT NULL,
    title VARCHAR(140) NOT NULL,
    location VARCHAR(120),
    start_date DATE,
    end_date DATE,
    is_current BOOLEAN DEFAULT false,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_user_experience_user_id ON user_experience(user_id);

-- --------------------------------------------------------------------
-- 7. OTP VERIFICATIONS
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS otp_verifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    identifier VARCHAR(100) NOT NULL, -- phone or email
    otp_code VARCHAR(10) NOT NULL,
    purpose VARCHAR(30) NOT NULL CHECK (purpose IN ('registration', 'login', 'forgot_password', 'phone_change')),
    expires_at TIMESTAMPTZ NOT NULL,
    attempts INT NOT NULL DEFAULT 0,
    is_used BOOLEAN NOT NULL DEFAULT false,
    ip_address VARCHAR(50),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_otp_identifier_purpose ON otp_verifications(identifier, purpose);
CREATE INDEX IF NOT EXISTS idx_otp_expires_at ON otp_verifications(expires_at);

-- --------------------------------------------------------------------
-- 8. SESSIONS & DEVICES
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash VARCHAR(255) NOT NULL,
    device_info VARCHAR(255) DEFAULT 'Web Browser',
    ip_address VARCHAR(60),
    user_agent TEXT,
    is_revoked BOOLEAN NOT NULL DEFAULT false,
    last_active_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_token_hash ON sessions(token_hash);

-- --------------------------------------------------------------------
-- 9. PRIVACY SETTINGS
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS privacy_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    profile_visibility VARCHAR(30) DEFAULT 'public' CHECK (profile_visibility IN ('public', 'friends_only', 'contacts_only', 'private')),
    read_receipts BOOLEAN DEFAULT true,
    online_status BOOLEAN DEFAULT true,
    last_seen_visibility VARCHAR(30) DEFAULT 'everyone' CHECK (last_seen_visibility IN ('everyone', 'contacts', 'nobody')),
    group_invitation_approval BOOLEAN DEFAULT true,
    message_requests VARCHAR(30) DEFAULT 'everyone' CHECK (message_requests IN ('everyone', 'contacts_only', 'nobody')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_privacy_settings_user_id ON privacy_settings(user_id);

-- --------------------------------------------------------------------
-- 10. BLOCKED USERS
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS blocked_users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blocker_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    blocked_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(blocker_id, blocked_id)
);

CREATE INDEX IF NOT EXISTS idx_blocked_users_blocker ON blocked_users(blocker_id);

-- --------------------------------------------------------------------
-- 11. AUDIT REPORTS & SECURITY
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    target_type VARCHAR(40) NOT NULL CHECK (target_type IN ('user', 'post', 'comment', 'message', 'community')),
    target_id UUID NOT NULL,
    reason VARCHAR(100) NOT NULL,
    details TEXT,
    status VARCHAR(30) DEFAULT 'pending' CHECK (status IN ('pending', 'investigating', 'resolved', 'dismissed')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- --------------------------------------------------------------------
-- 12. NOTIFICATIONS (Foundation for Phase 2+)
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type VARCHAR(60) NOT NULL,
    title VARCHAR(150) NOT NULL,
    body TEXT NOT NULL,
    data JSONB DEFAULT '{}',
    is_read BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON notifications(is_read);

-- --------------------------------------------------------------------
-- HELPER TRIGGER: update_timestamp
-- --------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trigger_set_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_users_updated_at ON users;
CREATE TRIGGER set_users_updated_at
BEFORE UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION trigger_set_timestamp();

DROP TRIGGER IF EXISTS set_user_profiles_updated_at ON user_profiles;
CREATE TRIGGER set_user_profiles_updated_at
BEFORE UPDATE ON user_profiles
FOR EACH ROW
EXECUTE FUNCTION trigger_set_timestamp();

DROP TRIGGER IF EXISTS set_prof_profiles_updated_at ON professional_profiles;
CREATE TRIGGER set_prof_profiles_updated_at
BEFORE UPDATE ON professional_profiles
FOR EACH ROW
EXECUTE FUNCTION trigger_set_timestamp();

DROP TRIGGER IF EXISTS set_privacy_updated_at ON privacy_settings;
CREATE TRIGGER set_privacy_updated_at
BEFORE UPDATE ON privacy_settings
FOR EACH ROW
EXECUTE FUNCTION trigger_set_timestamp();

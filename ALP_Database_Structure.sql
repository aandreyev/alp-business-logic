-- =============================================
-- ALP Legal Practice Management System
-- Database Structure for Analytics and AI Understanding
-- =============================================

-- This script contains the complete database schema for the ALP system,
-- a comprehensive legal practice management platform built with .NET and PostgreSQL.

-- =============================================
-- CORE AUDIT TABLES
-- =============================================
-- All tables inherit from BaseEntity with these standard fields:
-- - id (primary key)
-- - inserted_at (timestamp)
-- - updated_at (timestamp)
-- - inserted_by_id (foreign key to users)
-- - last_updated_by_id (foreign key to users)
-- - is_deleted (soft delete flag)

-- =============================================
-- USER MANAGEMENT & SECURITY
-- =============================================

CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    contact_number VARCHAR(50),
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    password_hash VARCHAR(255),
    microsoft_refresh_token TEXT,
    profile_image_identifier VARCHAR(255),
    active BOOLEAN DEFAULT TRUE,
    is_legal BOOLEAN,
    is_staff BOOLEAN,
    last_login TIMESTAMP,
    address_id INTEGER,
    postal_address_id INTEGER,
    date_of_birth DATE,
    photo TEXT,
    proposal_photo TEXT,
    initials VARCHAR(10),
    salutation INTEGER,
    second_email VARCHAR(255),
    office_id INTEGER,
    admission_date DATE,
    user_type INTEGER,
    email_delta_tokens JSONB,
    email_folder_delta_tokens TEXT,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE roles (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    is_system_admin BOOLEAN DEFAULT FALSE,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE user_roles (
    user_id INTEGER NOT NULL,
    role_id INTEGER NOT NULL,
    PRIMARY KEY (user_id, role_id)
);

CREATE TABLE role_permissions (
    id SERIAL PRIMARY KEY,
    role_id INTEGER NOT NULL,
    permission VARCHAR(100) NOT NULL,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE user_refresh_tokens (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    token VARCHAR(255) NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE user_one_time_passwords (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    code VARCHAR(10) NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    used BOOLEAN DEFAULT FALSE,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE user_preferences (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    preference_key VARCHAR(100) NOT NULL,
    preference_value TEXT,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

-- =============================================
-- ORGANIZATION STRUCTURE
-- =============================================

CREATE TABLE offices (
    id SERIAL PRIMARY KEY,
    legal_entity VARCHAR(255) NOT NULL,
    abn VARCHAR(50),
    phone VARCHAR(50),
    website VARCHAR(255),
    bank_account_name VARCHAR(255),
    bank_account_bsb VARCHAR(10),
    bank_account_number VARCHAR(20),
    bpay_biller_code VARCHAR(20),
    address_id INTEGER NOT NULL,
    trust_account_id INTEGER,
    active BOOLEAN DEFAULT TRUE,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE addresses (
    id SERIAL PRIMARY KEY,
    address_line_1 VARCHAR(255),
    address_line_2 VARCHAR(255),
    city VARCHAR(100),
    state VARCHAR(50),
    postcode VARCHAR(20),
    country VARCHAR(100),
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE business_entities (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    abn VARCHAR(50),
    office_id INTEGER,
    xero_tenant_id VARCHAR(255),
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

-- =============================================
-- CONTACT RELATIONSHIP MANAGEMENT (CRM)
-- =============================================

CREATE TABLE contacts (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255),
    secondary_email VARCHAR(255),
    invoice_email VARCHAR(255),
    salutation INTEGER NOT NULL, -- 1=Mr, 2=Mrs, 3=Ms, 4=Miss, 5=Dr, 6=Rev, 7=Mx
    gender INTEGER, -- 1=Male, 2=Female, 3=Neutral
    status INTEGER DEFAULT 1, -- 1=Active, 2=Dormant, 3=Inactive, 4=Blacklisted, 5=Deceased
    first_name VARCHAR(100) NOT NULL,
    middle_name VARCHAR(100),
    last_name VARCHAR(100) NOT NULL,
    preferred_first_name VARCHAR(100),
    previous_name VARCHAR(100),
    profile_image_identifier VARCHAR(255),
    contact_number VARCHAR(50),
    estimated_net_worth INTEGER, -- 1=Urban, 2=Affluent, 3=High, 4=Ultra
    date_of_birth DATE,
    date_of_death DATE,
    place_of_birth VARCHAR(255),
    estimated_assets INTEGER,
    estimated_liabilities INTEGER,
    estimated_wealth_date DATE,
    skype VARCHAR(100),
    linked_in_link VARCHAR(255),
    facebook_link VARCHAR(255),
    twitter_link VARCHAR(255),
    structure_diagram_link VARCHAR(255),
    occupation_id INTEGER,
    show_emails BOOLEAN DEFAULT TRUE,
    hide_email_reason VARCHAR(255),
    active_campaign_id INTEGER,
    address_id INTEGER NOT NULL,
    postal_same_as_address BOOLEAN DEFAULT FALSE,
    postal_address_id INTEGER NOT NULL,
    -- Relationship fields
    father_id INTEGER,
    mother_id INTEGER,
    spouse_id INTEGER,
    referrer_id INTEGER,
    sibling_count INTEGER DEFAULT 0,
    accountant_id INTEGER,
    financial_id INTEGER,
    lawyer_id INTEGER,
    director_id VARCHAR(255),
    direct_line VARCHAR(50),
    voi BOOLEAN DEFAULT FALSE,
    beverage VARCHAR(100),
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE contact_aliases (
    id SERIAL PRIMARY KEY,
    contact_id INTEGER NOT NULL,
    alias_name VARCHAR(255) NOT NULL,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE organisations (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    website VARCHAR(255),
    domain VARCHAR(255),
    mainline VARCHAR(50),
    group_status INTEGER,
    group_parent_id INTEGER,
    business_search_words TEXT,
    estimated_revenue INTEGER,
    number_of_employees INTEGER,
    business_lifecycle INTEGER,
    number_of_locations INTEGER,
    establishment_date DATE,
    status INTEGER,
    abn VARCHAR(50),
    acn VARCHAR(50),
    organisation_type_id INTEGER,
    industry_category_id INTEGER,
    industry_sub_category_id INTEGER,
    established_by_us BOOLEAN DEFAULT FALSE,
    show_emails BOOLEAN DEFAULT TRUE,
    address_id INTEGER NOT NULL,
    postal_same_as_address BOOLEAN DEFAULT FALSE,
    postal_address_id INTEGER,
    xero_contact_id VARCHAR(255),
    supplier BOOLEAN DEFAULT FALSE,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE clients (
    id SERIAL PRIMARY KEY,
    primary_contact_id INTEGER NOT NULL,
    secondary_contact_id INTEGER,
    organisation_id INTEGER,
    xero_contact_id VARCHAR(255),
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

-- =============================================
-- MATTER MANAGEMENT
-- =============================================

CREATE TABLE matters (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    client_id INTEGER NOT NULL,
    reviewer_id INTEGER NOT NULL,
    coordinator_id INTEGER,
    estimated_budget DECIMAL(10,2),
    first_contact_date DATE,
    status INTEGER NOT NULL, -- 1=ToBeQuoted, 2=QuotedAwaitingAcceptance, 3=Lost, 4=Open, 5=Closed, 6=Finalised, 7=Deleted
    office_id INTEGER NOT NULL,
    -- Status flags
    waiting_for_external BOOLEAN DEFAULT FALSE,
    waiting_for_internal BOOLEAN DEFAULT FALSE,
    to_be_followed_up BOOLEAN DEFAULT FALSE,
    -- Additional fields
    segment_id INTEGER,
    sub_segment_id INTEGER,
    offering_category_id INTEGER,
    conflict_parties TEXT,
    conflict_status INTEGER, -- 1=Outstanding, 2=NoOtherParties, 3=ConflictCheckSent
    matter_date DATE,
    closed_date DATE,
    lead_date DATE,
    billing_method INTEGER, -- InvoiceType enum
    billable_status INTEGER, -- 1=Open, 2=Suspended, 3=Closed
    is_matter_paid BOOLEAN,
    matter_status_tag_id INTEGER,
    funds_in_trust BOOLEAN DEFAULT FALSE,
    conflict_check_sent BOOLEAN DEFAULT FALSE,
    conflict_check_sent_at TIMESTAMP,
    standard_terms_sent BOOLEAN DEFAULT FALSE,
    standard_terms_sent_at TIMESTAMP,
    referrer_thanked BOOLEAN DEFAULT FALSE,
    referrer_thanked_at TIMESTAMP,
    apply_rate_adjustment BOOLEAN DEFAULT FALSE,
    rate_adjustment_percentage DECIMAL(5,2),
    deferred_fee BOOLEAN DEFAULT FALSE,
    sharepoint_folder VARCHAR(255),
    precedent_value INTEGER, -- 1-5 score
    estimated_closing_date DATE,
    matter_lost_reason TEXT,
    matter_closed_check TEXT,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE matter_outcomes (
    id SERIAL PRIMARY KEY,
    matter_id INTEGER NOT NULL,
    offering_outcome_id INTEGER NOT NULL,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE matter_components (
    id SERIAL PRIMARY KEY,
    matter_id INTEGER NOT NULL,
    offering_component_id INTEGER NOT NULL,
    user_id INTEGER,
    status INTEGER,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

-- =============================================
-- OFFERING MANAGEMENT
-- =============================================

CREATE TABLE offering_categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE offerings (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    category_id INTEGER,
    law_area_id INTEGER,
    law_sub_area_id INTEGER,
    segment_id INTEGER,
    sub_segment_id INTEGER,
    scope_of_work TEXT,
    what_we_do TEXT,
    what_we_dont_do TEXT,
    assumptions TEXT,
    exclusions TEXT,
    success_factors TEXT,
    risks TEXT,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE offering_outcomes (
    id SERIAL PRIMARY KEY,
    offering_id INTEGER NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE offering_components (
    id SERIAL PRIMARY KEY,
    offering_id INTEGER NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    duration_days INTEGER,
    buffer_days INTEGER,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

-- =============================================
-- PROJECT MANAGEMENT
-- =============================================

CREATE TABLE projects (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    due_date DATE,
    complete BOOLEAN DEFAULT FALSE,
    owner_id INTEGER NOT NULL,
    template_id INTEGER,
    business_area_id INTEGER,
    capability_id INTEGER,
    sub_capability_id INTEGER,
    sharepoint_folder VARCHAR(255),
    is_created_by_scheduler BOOLEAN DEFAULT FALSE,
    is_bau BOOLEAN DEFAULT FALSE, -- Business as usual
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE project_tasks (
    id SERIAL PRIMARY KEY,
    project_id INTEGER NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    assigned_user_id INTEGER,
    due_date DATE,
    complete BOOLEAN DEFAULT FALSE,
    order_index INTEGER,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE project_task_steps (
    id SERIAL PRIMARY KEY,
    project_task_id INTEGER NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    complete BOOLEAN DEFAULT FALSE,
    order_index INTEGER,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE project_templates (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    business_area_id INTEGER,
    capability_id INTEGER,
    sub_capability_id INTEGER,
    is_active BOOLEAN DEFAULT TRUE,
    trigger_days INTEGER,
    last_triggered_date DATE,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE project_template_tasks (
    id SERIAL PRIMARY KEY,
    project_template_id INTEGER NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    assigned_user_id INTEGER,
    days_to_complete INTEGER,
    order_index INTEGER,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE project_template_task_steps (
    id SERIAL PRIMARY KEY,
    project_template_task_id INTEGER NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    order_index INTEGER,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

-- =============================================
-- DOCUMENT MANAGEMENT
-- =============================================

CREATE TABLE documents (
    id SERIAL PRIMARY KEY,
    file_name VARCHAR(255) NOT NULL,
    file_extension VARCHAR(10) NOT NULL,
    editing_identifier VARCHAR(255),
    locked_by_user_id INTEGER,
    extracted_text TEXT,
    extracted_text_search_vector tsvector,
    contract_id INTEGER,
    discriminator VARCHAR(50) NOT NULL, -- For inheritance (MatterDocument, ProjectDocument, etc.)
    matter_id INTEGER,
    project_id INTEGER,
    contact_id INTEGER,
    organisation_id INTEGER,
    client_id INTEGER,
    offering_id INTEGER,
    resource_id INTEGER,
    note_id INTEGER,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE document_versions (
    id SERIAL PRIMARY KEY,
    document_id INTEGER NOT NULL,
    version_number INTEGER NOT NULL,
    file_storage_identifier VARCHAR(255),
    file_size BIGINT,
    created_by_user_id INTEGER,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE voice_document_recognitions (
    id SERIAL PRIMARY KEY,
    document_id INTEGER NOT NULL,
    recognized_text TEXT,
    confidence_score DECIMAL(5,2),
    language VARCHAR(10),
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

-- =============================================
-- TIME TRACKING & BILLING
-- =============================================

CREATE TABLE time_entries (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    description TEXT,
    start_time TIMESTAMP,
    end_time TIMESTAMP,
    duration_minutes INTEGER,
    billable BOOLEAN DEFAULT TRUE,
    rate DECIMAL(10,2),
    billed BOOLEAN DEFAULT FALSE,
    discriminator VARCHAR(50) NOT NULL, -- For inheritance
    matter_component_id INTEGER,
    project_task_id INTEGER,
    sales_activity_id INTEGER,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE timers (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    description TEXT,
    start_time TIMESTAMP NOT NULL,
    is_running BOOLEAN DEFAULT TRUE,
    discriminator VARCHAR(50) NOT NULL,
    matter_component_id INTEGER,
    project_task_id INTEGER,
    sales_activity_id INTEGER,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE invoices (
    id SERIAL PRIMARY KEY,
    matter_id INTEGER NOT NULL,
    xero_id VARCHAR(255),
    xero_invoice_id VARCHAR(255),
    invoice_number INTEGER NOT NULL,
    type INTEGER NOT NULL, -- InvoiceType enum
    status INTEGER NOT NULL, -- 1=Draft, 2=AwaitingApproval, 3=Approved, 4=Sent, 5=All
    synced_to_xero BOOLEAN DEFAULT FALSE,
    due_date DATE,
    invoice_date DATE,
    last_sync_at TIMESTAMP,
    total_invoice_amount DECIMAL(10,2),
    total_invoice_amount_incl_gst DECIMAL(10,2),
    received_payments DECIMAL(10,2),
    outstanding_amount DECIMAL(10,2),
    drafted_by_id INTEGER NOT NULL,
    approved_by_id INTEGER,
    sent_by_id INTEGER,
    file_storage_identifier VARCHAR(255),
    file_requested_at TIMESTAMP,
    file_up_to_date BOOLEAN DEFAULT FALSE,
    queried_status BOOLEAN,
    queried_text TEXT,
    do_not_collect BOOLEAN,
    invoice_sent BOOLEAN,
    is_invoice_paid BOOLEAN,
    payment_expectations TEXT,
    reject_reason TEXT,
    statement_sent_time TIMESTAMP,
    friendly_reminder_sent_time TIMESTAMP,
    first_reminder_sent_time TIMESTAMP,
    second_reminder_sent_time TIMESTAMP,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE disbursements (
    id SERIAL PRIMARY KEY,
    matter_id INTEGER NOT NULL,
    invoice_id INTEGER,
    description TEXT,
    amount DECIMAL(10,2),
    gst_amount DECIMAL(10,2),
    disbursement_date DATE,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE fixed_price_items (
    id SERIAL PRIMARY KEY,
    invoice_id INTEGER NOT NULL,
    description TEXT,
    amount DECIMAL(10,2),
    gst_amount DECIMAL(10,2),
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE discount_items (
    id SERIAL PRIMARY KEY,
    invoice_id INTEGER NOT NULL,
    description TEXT,
    amount DECIMAL(10,2),
    percentage DECIMAL(5,2),
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE payments (
    id SERIAL PRIMARY KEY,
    invoice_id INTEGER NOT NULL,
    amount DECIMAL(10,2),
    payment_date DATE,
    payment_method VARCHAR(50),
    reference VARCHAR(255),
    xero_payment_id VARCHAR(255),
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

-- =============================================
-- TRUST ACCOUNTING
-- =============================================

CREATE TABLE trust_accounts (
    id SERIAL PRIMARY KEY,
    account_name VARCHAR(255) NOT NULL,
    account_number VARCHAR(50),
    bsb VARCHAR(10),
    bank_name VARCHAR(255),
    opening_balance DECIMAL(15,2),
    current_balance DECIMAL(15,2),
    office_id INTEGER,
    is_controlled_money BOOLEAN DEFAULT FALSE,
    enable_partial_payment BOOLEAN DEFAULT FALSE,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE trust_transaction_requests (
    id SERIAL PRIMARY KEY,
    matter_id INTEGER NOT NULL,
    request_type INTEGER NOT NULL,
    amount DECIMAL(10,2),
    description TEXT,
    status INTEGER DEFAULT 1, -- 1=Pending, 2=Approved, 3=Rejected
    requested_by_id INTEGER,
    approved_by_id INTEGER,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE trust_transactions (
    id SERIAL PRIMARY KEY,
    trust_account_id INTEGER NOT NULL,
    matter_id INTEGER,
    transfer_matter_id INTEGER,
    transaction_type INTEGER NOT NULL,
    amount DECIMAL(10,2),
    description TEXT,
    transaction_date DATE,
    reference VARCHAR(255),
    bank_transaction_date DATE,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE trust_ledgers (
    id SERIAL PRIMARY KEY,
    matter_id INTEGER NOT NULL,
    trust_account_id INTEGER NOT NULL,
    transaction_type INTEGER NOT NULL,
    amount DECIMAL(10,2),
    balance DECIMAL(10,2),
    description TEXT,
    transaction_date DATE,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE bank_transactions (
    id SERIAL PRIMARY KEY,
    trust_account_id INTEGER NOT NULL,
    transaction_date DATE,
    description TEXT,
    amount DECIMAL(10,2),
    balance DECIMAL(10,2),
    reference VARCHAR(255),
    bank_reference VARCHAR(255),
    reconciled BOOLEAN DEFAULT FALSE,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

-- =============================================
-- EMAIL MANAGEMENT
-- =============================================

CREATE TABLE emails (
    id SERIAL PRIMARY KEY,
    subject VARCHAR(500),
    body TEXT,
    from_address VARCHAR(255),
    to_addresses TEXT,
    cc_addresses TEXT,
    bcc_addresses TEXT,
    sent_date TIMESTAMP,
    received_date TIMESTAMP,
    message_id VARCHAR(255),
    conversation_id VARCHAR(255),
    outlook_id VARCHAR(255),
    is_read BOOLEAN DEFAULT FALSE,
    is_flagged BOOLEAN DEFAULT FALSE,
    direction INTEGER, -- 1=Incoming, 2=Outgoing
    discriminator VARCHAR(50) NOT NULL,
    matter_id INTEGER,
    project_id INTEGER,
    contact_id INTEGER,
    organisation_id INTEGER,
    user_id INTEGER,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE email_recipients (
    id SERIAL PRIMARY KEY,
    email_id INTEGER NOT NULL,
    recipient_address VARCHAR(255),
    recipient_name VARCHAR(255),
    recipient_type INTEGER, -- 1=To, 2=CC, 3=BCC
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE email_attachments (
    id SERIAL PRIMARY KEY,
    email_id INTEGER NOT NULL,
    file_name VARCHAR(255),
    file_size BIGINT,
    content_type VARCHAR(255),
    outlook_attachment_id VARCHAR(255),
    file_storage_identifier VARCHAR(255),
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE email_templates (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    subject VARCHAR(500),
    body TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE user_email_folders (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    folder_name VARCHAR(255),
    outlook_folder_id VARCHAR(255),
    parent_folder_id INTEGER,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

-- =============================================
-- NOTES & COMMUNICATION
-- =============================================

CREATE TABLE notes (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255),
    content TEXT,
    is_pinned BOOLEAN DEFAULT FALSE,
    discriminator VARCHAR(50) NOT NULL,
    matter_id INTEGER,
    project_id INTEGER,
    contact_id INTEGER,
    organisation_id INTEGER,
    invoice_id INTEGER,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE note_attachments (
    id SERIAL PRIMARY KEY,
    note_id INTEGER NOT NULL,
    file_name VARCHAR(255),
    file_extension VARCHAR(10),
    file_storage_identifier VARCHAR(255),
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

-- =============================================
-- REMINDERS & NOTIFICATIONS
-- =============================================

CREATE TABLE reminders (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255),
    description TEXT,
    due_date TIMESTAMP,
    completed BOOLEAN DEFAULT FALSE,
    user_id INTEGER NOT NULL,
    discriminator VARCHAR(50) NOT NULL,
    document_id INTEGER,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE notifications (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    title VARCHAR(255),
    message TEXT,
    read BOOLEAN DEFAULT FALSE,
    notification_type INTEGER,
    entity_type VARCHAR(50),
    entity_id INTEGER,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

-- =============================================
-- DYNAMIC METADATA SYSTEM
-- =============================================

CREATE TABLE dynamic_parameters (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    data_type INTEGER, -- 1=String, 2=Integer, 3=Decimal, 4=Boolean, 5=Date, 6=DateTime
    is_required BOOLEAN DEFAULT FALSE,
    default_value TEXT,
    validation_rules TEXT,
    display_order INTEGER,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE dynamic_parameter_values (
    id SERIAL PRIMARY KEY,
    parameter_name VARCHAR(255),
    display_value VARCHAR(255),
    sort_order INTEGER,
    is_active BOOLEAN DEFAULT TRUE,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

-- Entity-specific dynamic parameter associations
CREATE TABLE contact_dynamic_parameters (
    id SERIAL PRIMARY KEY,
    contact_id INTEGER NOT NULL,
    dynamic_parameter_id INTEGER NOT NULL,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE contact_dynamic_parameter_values (
    id SERIAL PRIMARY KEY,
    contact_id INTEGER NOT NULL,
    dynamic_parameter_id INTEGER NOT NULL,
    value TEXT,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

-- Similar tables exist for other entities:
-- matter_dynamic_parameters, matter_dynamic_parameter_values
-- project_dynamic_parameters, project_dynamic_parameter_values
-- document_dynamic_parameters, document_dynamic_parameter_values
-- etc.

-- =============================================
-- TAXONOMY & CLASSIFICATION
-- =============================================

CREATE TABLE business_areas (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE capabilities (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    business_area_id INTEGER,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE sub_capabilities (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    capability_id INTEGER,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE law_areas (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE law_sub_areas (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    law_area_id INTEGER,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE segments (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE sub_segments (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    segment_id INTEGER,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE organisation_types (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE industry_categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE industry_sub_categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    industry_category_id INTEGER,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE occupations (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE contact_roles (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

-- =============================================
-- RELATIONSHIP MANAGEMENT
-- =============================================

CREATE TABLE contact_relationships (
    id SERIAL PRIMARY KEY,
    contact_id INTEGER NOT NULL,
    related_contact_id INTEGER NOT NULL,
    relationship_type INTEGER,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE child_relationships (
    id SERIAL PRIMARY KEY,
    parent_id INTEGER NOT NULL,
    child_id INTEGER NOT NULL,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE referred_relationships (
    id SERIAL PRIMARY KEY,
    referrer_id INTEGER NOT NULL,
    referred_id INTEGER NOT NULL,
    referral_date DATE,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE organisation_relationships (
    id SERIAL PRIMARY KEY,
    organisation_id INTEGER NOT NULL,
    related_organisation_id INTEGER NOT NULL,
    relationship_type INTEGER,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

-- =============================================
-- EXTERNAL INTEGRATIONS
-- =============================================

CREATE TABLE integrations (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    integration_type VARCHAR(100),
    api_key VARCHAR(255),
    api_secret VARCHAR(255),
    endpoint_url VARCHAR(255),
    is_active BOOLEAN DEFAULT TRUE,
    last_sync_at TIMESTAMP,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE integration_logs (
    id SERIAL PRIMARY KEY,
    integration_id INTEGER NOT NULL,
    operation VARCHAR(100),
    status INTEGER, -- 1=Success, 2=Failed, 3=Warning
    message TEXT,
    request_data TEXT,
    response_data TEXT,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

-- =============================================
-- SYSTEM LOGGING & AUDIT
-- =============================================

CREATE TABLE alp_logs (
    id SERIAL PRIMARY KEY,
    log_level VARCHAR(20),
    message TEXT,
    exception TEXT,
    user_id INTEGER,
    request_path VARCHAR(255),
    request_method VARCHAR(10),
    ip_address VARCHAR(45),
    user_agent TEXT,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE automation_logs (
    id SERIAL PRIMARY KEY,
    automation_type VARCHAR(100),
    entity_type VARCHAR(100),
    entity_id INTEGER,
    action VARCHAR(100),
    status INTEGER,
    message TEXT,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

-- =============================================
-- ASSET & RISK MANAGEMENT
-- =============================================

CREATE TABLE asset_types (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE assets (
    id SERIAL PRIMARY KEY,
    asset_type_id INTEGER NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    serial_number VARCHAR(255),
    purchase_date DATE,
    purchase_price DECIMAL(10,2),
    current_value DECIMAL(10,2),
    location VARCHAR(255),
    assigned_user_id INTEGER,
    status INTEGER, -- 1=Active, 2=Inactive, 3=Disposed
    warranty_expiry DATE,
    depreciation_date DATE,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE asset_management_logs (
    id SERIAL PRIMARY KEY,
    asset_id INTEGER NOT NULL,
    action VARCHAR(100),
    description TEXT,
    performed_by_id INTEGER,
    performed_at TIMESTAMP,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE risks (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    risk_category INTEGER,
    probability INTEGER, -- 1-5 scale
    impact INTEGER, -- 1-5 scale
    risk_score INTEGER, -- Calculated field
    mitigation_strategy TEXT,
    owner_id INTEGER,
    status INTEGER, -- 1=Open, 2=Mitigated, 3=Closed
    due_date DATE,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE incident_logs (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    incident_type INTEGER,
    severity INTEGER, -- 1=Low, 2=Medium, 3=High, 4=Critical
    status INTEGER, -- 1=Open, 2=InProgress, 3=Resolved, 4=Closed
    reported_by_id INTEGER,
    assigned_to_id INTEGER,
    occurred_at TIMESTAMP,
    resolved_at TIMESTAMP,
    resolution_notes TEXT,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

-- =============================================
-- SPECIALIZED MODULES
-- =============================================

CREATE TABLE contracts (
    id SERIAL PRIMARY KEY,
    contract_uuid VARCHAR(255),
    contract_name VARCHAR(255),
    contract_description TEXT,
    start_date DATE,
    end_date DATE,
    amount DECIMAL(10,2),
    currency VARCHAR(10),
    contract_type VARCHAR(100),
    status INTEGER,
    digital_contract_id VARCHAR(255),
    digital_contract_submission_id VARCHAR(255),
    is_signed BOOLEAN,
    comments TEXT,
    discriminator VARCHAR(50) NOT NULL, -- For inheritance
    client_id INTEGER,
    matter_id INTEGER,
    project_id INTEGER,
    user_id INTEGER,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE contract_submitters (
    id SERIAL PRIMARY KEY,
    contract_id INTEGER NOT NULL,
    submission_id VARCHAR(255),
    submitter_uuid VARCHAR(255),
    submitter_slug VARCHAR(255),
    "order" INTEGER,
    name VARCHAR(255),
    email VARCHAR(255),
    contact_number VARCHAR(50),
    initials VARCHAR(10),
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE ppsr_registers (
    id SERIAL PRIMARY KEY,
    registration_number VARCHAR(255),
    collateral_description TEXT,
    grantor_name VARCHAR(255),
    secured_party_name VARCHAR(255),
    registration_date DATE,
    expiry_date DATE,
    status INTEGER,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE wiki_pages (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    content TEXT,
    category VARCHAR(100),
    tags TEXT,
    is_published BOOLEAN DEFAULT FALSE,
    author_id INTEGER,
    last_editor_id INTEGER,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE safe_storage_document_types (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE safe_storage_sections (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    location VARCHAR(255),
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE safe_storage_documents (
    id SERIAL PRIMARY KEY,
    document_type_id INTEGER NOT NULL,
    section_id INTEGER NOT NULL,
    matter_id INTEGER,
    client_id INTEGER,
    description TEXT,
    location_details VARCHAR(255),
    stored_date DATE,
    retrieved_date DATE,
    status INTEGER, -- 1=Stored, 2=Retrieved, 3=Destroyed
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

-- =============================================
-- MAIL REGISTER
-- =============================================

CREATE TABLE incoming_mail (
    id SERIAL PRIMARY KEY,
    entry_type INTEGER NOT NULL,
    sender_type INTEGER NOT NULL,
    matter_id INTEGER,
    received_date DATE NOT NULL,
    office_id INTEGER NOT NULL,
    sender_staff_id INTEGER,
    sender_contact_id INTEGER,
    sender_others VARCHAR(255),
    description TEXT,
    delivery_method INTEGER,
    delivery_notes TEXT,
    address_id INTEGER,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE outgoing_mail (
    id SERIAL PRIMARY KEY,
    entry_type INTEGER NOT NULL,
    recipient_type INTEGER NOT NULL,
    other_recipient_type VARCHAR(255),
    matter_id INTEGER,
    sent_date DATE NOT NULL,
    office_id INTEGER NOT NULL,
    sender_staff_id INTEGER,
    recipient_staff_id INTEGER,
    recipient_contact_id INTEGER,
    recipient_others VARCHAR(255),
    for_attention_of VARCHAR(255),
    description TEXT,
    delivery_method INTEGER,
    delivery_notes TEXT,
    address_id INTEGER,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

-- =============================================
-- METABASE REPORTING
-- =============================================

CREATE TABLE metabase_report_groups (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE metabase_reports (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    metabase_id INTEGER,
    report_group_id INTEGER,
    is_active BOOLEAN DEFAULT TRUE,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE metabase_report_parameters (
    id SERIAL PRIMARY KEY,
    metabase_report_id INTEGER NOT NULL,
    parameter_name VARCHAR(255) NOT NULL,
    parameter_type VARCHAR(50),
    default_value TEXT,
    is_required BOOLEAN DEFAULT FALSE,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

-- =============================================
-- ADDITIONAL SPECIALIZED TABLES
-- =============================================

CREATE TABLE syntaq_forms (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    form_structure JSONB,
    is_active BOOLEAN DEFAULT TRUE,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE syntaq_form_records (
    id SERIAL PRIMARY KEY,
    syntaq_form_id INTEGER NOT NULL,
    matter_id INTEGER,
    form_data JSONB,
    submitted_at TIMESTAMP,
    submitted_by_id INTEGER,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE bug_reports (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    priority INTEGER, -- 1=Low, 2=Medium, 3=High, 4=Critical
    status INTEGER, -- 1=Open, 2=InProgress, 3=Resolved, 4=Closed
    reported_by_id INTEGER,
    assigned_to_id INTEGER,
    browser_info TEXT,
    steps_to_reproduce TEXT,
    expected_behavior TEXT,
    actual_behavior TEXT,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE contact_special_interests (
    id SERIAL PRIMARY KEY,
    contact_id INTEGER NOT NULL,
    interest VARCHAR(255),
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE remunerations (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    base_salary DECIMAL(10,2),
    hourly_rate DECIMAL(10,2),
    billing_rate DECIMAL(10,2),
    effective_date DATE,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE pqe_adjustments (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    years_experience INTEGER,
    adjustment_percentage DECIMAL(5,2),
    effective_date DATE,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE sprints (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    start_date DATE,
    end_date DATE,
    goals TEXT,
    status INTEGER, -- 1=Planning, 2=Active, 3=Completed
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE call_datas (
    id SERIAL PRIMARY KEY,
    contact_id INTEGER,
    phone_number VARCHAR(50),
    call_date TIMESTAMP,
    duration_seconds INTEGER,
    call_type INTEGER, -- 1=Incoming, 2=Outgoing, 3=Missed
    notes TEXT,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    inserted_by_id INTEGER,
    last_updated_by_id INTEGER,
    is_deleted BOOLEAN DEFAULT FALSE
);

-- =============================================
-- IMPORTANT NOTES FOR AI ANALYTICS
-- =============================================

/*
KEY RELATIONSHIPS AND PATTERNS:

1. USER HIERARCHY:
   - users table contains all system users (lawyers, staff, administrators)
   - user_roles provides many-to-many relationship with roles
   - offices represent physical locations/legal entities

2. CLIENT STRUCTURE:
   - contacts: Individual people
   - organisations: Companies/entities
   - clients: Links contacts/organisations as billable clients

3. MATTER LIFECYCLE:
   - matters: Central legal cases/work
   - matter_components: Break down work into components
   - matter_outcomes: Link to offering outcomes
   - Status flow: ToBeQuoted → QuotedAwaitingAcceptance → Open → Closed → Finalised

4. PROJECT MANAGEMENT:
   - projects: Internal work/tasks
   - project_tasks: Breakdown of project work
   - project_templates: Reusable project structures

5. TIME & BILLING:
   - time_entries: Billable/non-billable time tracking
   - timers: Active time tracking
   - invoices: Generated bills with complex status workflow
   - trust_transactions: Client money management (critical for legal compliance)

6. DOCUMENT MANAGEMENT:
   - documents table uses discriminator pattern for different document types
   - document_versions: Version control
   - Full-text search via extracted_text_search_vector

7. DYNAMIC METADATA:
   - Flexible system for custom fields on any entity
   - *_dynamic_parameters and *_dynamic_parameter_values tables

8. AUDIT TRAIL:
   - All tables have inserted_at, updated_at, inserted_by_id, last_updated_by_id
   - Soft deletes via is_deleted flag
   - Comprehensive logging in alp_logs and automation_logs

9. INTEGRATION POINTS:
   - Xero integration for accounting
   - Microsoft 365 integration for emails
   - Active Campaign for marketing
   - Syntaq for forms

10. COMPLIANCE FEATURES:
    - Trust accounting (highly regulated in legal industry)
    - Conflict checking
    - Document retention
    - Audit trails

ANALYTICS OPPORTUNITIES:
- Matter profitability analysis
- Time tracking and utilization
- Client relationship analysis
- Performance metrics by user/office
- Pipeline analysis (matter status progression)
- Resource allocation optimization
- Risk assessment
- Compliance reporting
*/ 
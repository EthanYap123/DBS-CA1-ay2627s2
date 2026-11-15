-- ============================================
-- REVIEW AND COMMENT TABLES
-- Run after CreateDbTable.sql and SeedData.sql.
-- Safe to run again: drops and recreates only these two tables.
-- ============================================

DROP TABLE IF EXISTS public.comment CASCADE;
DROP TABLE IF EXISTS public.review CASCADE;

-- ============================================
-- REVIEW
-- One review per member per product.
-- "Must have a COMPLETED order for the product" is checked in create_review.
-- ============================================

CREATE TABLE public.review (
    id SERIAL PRIMARY KEY,
    member_id INTEGER NOT NULL,
    product_id INTEGER NOT NULL,
    rating SMALLINT NOT NULL,
    review_text CHARACTER VARYING(1000) NOT NULL,
    created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_review_member FOREIGN KEY (member_id) REFERENCES public.member(id),
    CONSTRAINT fk_review_product FOREIGN KEY (product_id) REFERENCES public.product(id),
    CONSTRAINT uq_review_member_product UNIQUE (member_id, product_id),
    CONSTRAINT chk_review_rating CHECK (rating BETWEEN 1 AND 5),
    CONSTRAINT chk_review_text_not_blank CHECK (TRIM(review_text) <> ''),
    CONSTRAINT chk_review_updated_after_created CHECK (updated_at >= created_at)
);

-- Product page lists all reviews of one product.
-- (Lookups by member use the index from uq_review_member_product, since member_id is its first column.)
CREATE INDEX idx_review_product_id ON public.review (product_id);

-- ============================================
-- COMMENT
-- parent_comment_id NULL = top-level comment, otherwise a reply to that comment.
-- Deleting a review deletes all its comments (ON DELETE CASCADE on review_id).
-- A comment with replies is marked is_deleted instead of being removed.
-- ============================================

CREATE TABLE public.comment (
    id SERIAL PRIMARY KEY,
    review_id INTEGER NOT NULL,
    member_id INTEGER NOT NULL,
    parent_comment_id INTEGER,
    comment_text CHARACTER VARYING(500) NOT NULL,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_comment_review FOREIGN KEY (review_id) REFERENCES public.review(id) ON DELETE CASCADE,
    CONSTRAINT fk_comment_member FOREIGN KEY (member_id) REFERENCES public.member(id),
    -- Needed so the composite foreign key below has something unique to point to
    CONSTRAINT uq_comment_id_review UNIQUE (id, review_id),
    -- A reply must point to a comment on the SAME review.
    -- No ON DELETE rule, so a comment that still has replies cannot be removed.
    CONSTRAINT fk_comment_parent_same_review FOREIGN KEY (parent_comment_id, review_id)
        REFERENCES public.comment(id, review_id),
    CONSTRAINT chk_comment_text_not_blank CHECK (TRIM(comment_text) <> ''),
    CONSTRAINT chk_comment_not_own_parent CHECK (parent_comment_id <> id)
);

-- get_comments loads all comments of a review
CREATE INDEX idx_comment_review_id ON public.comment (review_id);
-- Finding the replies of a comment (delete_comment checks this, and the recursive query in get_comments joins on it)
CREATE INDEX idx_comment_parent_comment_id ON public.comment (parent_comment_id);

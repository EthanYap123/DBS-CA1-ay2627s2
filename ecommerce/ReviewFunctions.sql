-- ============================================
-- REVIEW PROCEDURES AND FUNCTION
-- Run after CreateReviewCommentTables.sql. Safe to run again (CREATE OR REPLACE).
--
-- create_review, update_review, delete_review are procedures (CALL ...) because they
-- change data and return nothing. get_reviews is a function because it returns rows.
--
-- Every check raises an exception with a message the app shows to the user as is.
-- The member id is always passed in, so they work from the app (member id from the
-- login token) and from pgAdmin (type any member id).
-- ============================================

-- The rating is passed as NUMERIC so that a value like 3.5 reaches the check below instead of
-- being rejected before the procedure runs. A different parameter type makes a separate
-- procedure, so the earlier INTEGER versions are dropped first.
DROP PROCEDURE IF EXISTS public.create_review(INTEGER, INTEGER, INTEGER, TEXT);
DROP PROCEDURE IF EXISTS public.update_review(INTEGER, INTEGER, INTEGER, TEXT);


-- --------------------------------------------
-- create_review
-- --------------------------------------------
CREATE OR REPLACE PROCEDURE public.create_review(
    p_member_id INTEGER,
    p_product_id INTEGER,
    p_rating NUMERIC,
    p_review_text TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Member and product must exist
    IF NOT EXISTS (SELECT 1 FROM public.member WHERE id = p_member_id) THEN
        RAISE EXCEPTION 'Member not found.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.product WHERE id = p_product_id) THEN
        RAISE EXCEPTION 'Product not found.';
    END IF;

    -- Rating and text
    IF p_rating IS NULL OR p_rating NOT BETWEEN 1 AND 5 OR p_rating <> TRUNC(p_rating) THEN
        RAISE EXCEPTION 'Rating must be a whole number from 1 to 5.';
    END IF;

    IF p_review_text IS NULL OR TRIM(p_review_text) = '' THEN
        RAISE EXCEPTION 'Review text cannot be empty.';
    END IF;

    IF LENGTH(TRIM(p_review_text)) > 1000 THEN
        RAISE EXCEPTION 'Review text cannot be more than 1000 characters.';
    END IF;

    -- Business rule: only products from the member's COMPLETED orders can be reviewed
    IF NOT EXISTS (
        SELECT 1
        FROM public.sale_order so
        JOIN public.sale_order_item soi ON soi.sale_order_id = so.id
        WHERE so.member_id = p_member_id
          AND soi.product_id = p_product_id
          AND so.status = 'COMPLETED'
    ) THEN
        RAISE EXCEPTION 'You can only review products from your completed orders.';
    END IF;

    -- One review per member per product
    IF EXISTS (
        SELECT 1 FROM public.review
        WHERE member_id = p_member_id AND product_id = p_product_id
    ) THEN
        RAISE EXCEPTION 'You have already reviewed this product. Update your existing review instead.';
    END IF;

    INSERT INTO public.review (member_id, product_id, rating, review_text)
    VALUES (p_member_id, p_product_id, p_rating::SMALLINT, TRIM(p_review_text));

EXCEPTION
    -- Backup for two requests arriving at the same time: the UNIQUE constraint catches it
    WHEN unique_violation THEN
        RAISE EXCEPTION 'You have already reviewed this product. Update your existing review instead.';
END;
$$;


-- --------------------------------------------
-- update_review
-- --------------------------------------------
CREATE OR REPLACE PROCEDURE public.update_review(
    p_member_id INTEGER,
    p_review_id INTEGER,
    p_rating NUMERIC,
    p_review_text TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_owner_id INTEGER;
BEGIN
    SELECT member_id INTO v_owner_id FROM public.review WHERE id = p_review_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Review not found.';
    END IF;

    -- Members can only change their own reviews
    IF v_owner_id IS DISTINCT FROM p_member_id THEN
        RAISE EXCEPTION 'You can only update your own reviews.';
    END IF;

    IF p_rating IS NULL OR p_rating NOT BETWEEN 1 AND 5 OR p_rating <> TRUNC(p_rating) THEN
        RAISE EXCEPTION 'Rating must be a whole number from 1 to 5.';
    END IF;

    IF p_review_text IS NULL OR TRIM(p_review_text) = '' THEN
        RAISE EXCEPTION 'Review text cannot be empty.';
    END IF;

    IF LENGTH(TRIM(p_review_text)) > 1000 THEN
        RAISE EXCEPTION 'Review text cannot be more than 1000 characters.';
    END IF;

    UPDATE public.review
    SET rating = p_rating::SMALLINT,
        review_text = TRIM(p_review_text),
        updated_at = NOW()
    WHERE id = p_review_id;
END;
$$;


-- --------------------------------------------
-- delete_review
-- The review's comments are deleted with it by ON DELETE CASCADE on comment.review_id.
-- --------------------------------------------
CREATE OR REPLACE PROCEDURE public.delete_review(
    p_member_id INTEGER,
    p_review_id INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_owner_id INTEGER;
BEGIN
    SELECT member_id INTO v_owner_id FROM public.review WHERE id = p_review_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Review not found.';
    END IF;

    -- Members can only delete their own reviews
    IF v_owner_id IS DISTINCT FROM p_member_id THEN
        RAISE EXCEPTION 'You can only delete your own reviews.';
    END IF;

    DELETE FROM public.review WHERE id = p_review_id;
END;
$$;


-- --------------------------------------------
-- get_reviews
-- All reviews of one member, newest first, with what the "My Reviews" page shows.
-- --------------------------------------------
CREATE OR REPLACE FUNCTION public.get_reviews(p_member_id INTEGER)
RETURNS TABLE (
    review_id INTEGER,
    product_id INTEGER,
    product_name CHARACTER VARYING,
    rating SMALLINT,
    review_text CHARACTER VARYING,
    updated_at TIMESTAMP WITHOUT TIME ZONE
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.member m WHERE m.id = p_member_id) THEN
        RAISE EXCEPTION 'Member not found.';
    END IF;

    RETURN QUERY
    SELECT r.id, p.id, p.name, r.rating, r.review_text, r.updated_at
    FROM public.review r
    JOIN public.product p ON p.id = r.product_id
    WHERE r.member_id = p_member_id
    ORDER BY r.updated_at DESC, r.id DESC;
END;
$$;

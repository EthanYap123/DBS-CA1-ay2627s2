-- ============================================
-- COMMENT PROCEDURES AND FUNCTION
-- Run after CreateReviewCommentTables.sql. Safe to run again (CREATE OR REPLACE).
--
-- Like the review procedures, every check raises an exception with a message the app
-- shows to the user as is, and the member id is always passed in.
-- ============================================


-- --------------------------------------------
-- create_comment
-- p_parent_comment_id is NULL for a top-level comment on the review,
-- or the id of the comment being replied to.
-- --------------------------------------------
CREATE OR REPLACE PROCEDURE public.create_comment(
    p_member_id INTEGER,
    p_review_id INTEGER,
    p_parent_comment_id INTEGER,
    p_comment_text TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_review_author INTEGER;
    v_parent_review INTEGER;
    v_parent_author INTEGER;
    v_parent_deleted BOOLEAN;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.member WHERE id = p_member_id) THEN
        RAISE EXCEPTION 'Member not found.';
    END IF;

    SELECT member_id INTO v_review_author FROM public.review WHERE id = p_review_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Review not found.';
    END IF;

    IF p_comment_text IS NULL OR TRIM(p_comment_text) = '' THEN
        RAISE EXCEPTION 'Comment text cannot be empty.';
    END IF;

    IF LENGTH(TRIM(p_comment_text)) > 500 THEN
        RAISE EXCEPTION 'Comment text cannot be more than 500 characters.';
    END IF;

    IF p_parent_comment_id IS NULL THEN
        -- Top-level comment: anyone except the review's author
        IF p_member_id = v_review_author THEN
            RAISE EXCEPTION 'You cannot start a comment on your own review. You can reply to comments from other members.';
        END IF;
    ELSE
        -- Reply: the parent must exist, be on the same review and not be deleted
        SELECT review_id, member_id, is_deleted
        INTO v_parent_review, v_parent_author, v_parent_deleted
        FROM public.comment
        WHERE id = p_parent_comment_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'The comment you are replying to was not found.';
        END IF;

        IF v_parent_review <> p_review_id THEN
            RAISE EXCEPTION 'You can only reply to a comment on the same review.';
        END IF;

        IF v_parent_deleted THEN
            RAISE EXCEPTION 'You cannot reply to a deleted comment.';
        END IF;

        -- The review's author may only reply to comments made by other members
        IF p_member_id = v_review_author AND v_parent_author = p_member_id THEN
            RAISE EXCEPTION 'On your own review you can only reply to comments from other members.';
        END IF;
    END IF;

    INSERT INTO public.comment (review_id, member_id, parent_comment_id, comment_text)
    VALUES (p_review_id, p_member_id, p_parent_comment_id, TRIM(p_comment_text));

EXCEPTION
    -- Backup if the parent comment is removed at the same moment: the composite FK catches it
    WHEN foreign_key_violation THEN
        RAISE EXCEPTION 'The comment you are replying to was not found.';
END;
$$;

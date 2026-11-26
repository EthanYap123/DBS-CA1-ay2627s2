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


-- --------------------------------------------
-- get_comments
-- All comments of one review in thread order: each comment is followed by its replies,
-- oldest first. depth is 0 for a top-level comment, 1 for a reply, 2 for a reply to a
-- reply, and so on, so the page can indent it. A deleted comment that still has replies
-- shows as [deleted] without its writer.
-- --------------------------------------------
CREATE OR REPLACE FUNCTION public.get_comments(p_review_id INTEGER)
RETURNS TABLE (
    comment_id INTEGER,
    parent_comment_id INTEGER,
    member_id INTEGER,
    username CHARACTER VARYING,
    comment_text CHARACTER VARYING,
    is_deleted BOOLEAN,
    created_at TIMESTAMP WITHOUT TIME ZONE,
    depth INTEGER
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.review r WHERE r.id = p_review_id) THEN
        RAISE EXCEPTION 'Review not found.';
    END IF;

    RETURN QUERY
    WITH RECURSIVE thread AS (
        -- Start with the top-level comments of the review
        SELECT c.id, c.parent_comment_id, c.member_id, c.comment_text, c.is_deleted, c.created_at,
               0 AS depth,
               ARRAY[c.id] AS path
        FROM public.comment c
        WHERE c.review_id = p_review_id AND c.parent_comment_id IS NULL

        UNION ALL

        -- Then repeatedly add the replies to the comments found so far
        SELECT c.id, c.parent_comment_id, c.member_id, c.comment_text, c.is_deleted, c.created_at,
               t.depth + 1,
               t.path || c.id
        FROM public.comment c
        JOIN thread t ON c.parent_comment_id = t.id
    )
    SELECT t.id,
           t.parent_comment_id,
           CASE WHEN t.is_deleted THEN NULL ELSE t.member_id END,
           CASE WHEN t.is_deleted THEN NULL ELSE m.username END,
           CASE WHEN t.is_deleted THEN '[deleted]'::CHARACTER VARYING ELSE t.comment_text END,
           t.is_deleted,
           t.created_at,
           t.depth
    FROM thread t
    JOIN public.member m ON m.id = t.member_id
    -- path is the list of ids from the top-level comment down to this one. Ids only go up,
    -- so sorting by path puts every reply under its parent, oldest first.
    ORDER BY t.path;
END;
$$;


-- --------------------------------------------
-- delete_comment
-- A member can only delete their own comment. A comment with replies is marked deleted
-- so the other members' replies stay. A comment without replies is removed, and any
-- deleted parents left with no replies are removed with it.
-- --------------------------------------------
CREATE OR REPLACE PROCEDURE public.delete_comment(
    p_member_id INTEGER,
    p_comment_id INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_owner_id INTEGER;
    v_is_deleted BOOLEAN;
    v_parent_id INTEGER;
BEGIN
    SELECT member_id, is_deleted, parent_comment_id
    INTO v_owner_id, v_is_deleted, v_parent_id
    FROM public.comment
    WHERE id = p_comment_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Comment not found.';
    END IF;

    IF v_is_deleted THEN
        RAISE EXCEPTION 'This comment has already been deleted.';
    END IF;

    IF v_owner_id IS DISTINCT FROM p_member_id THEN
        RAISE EXCEPTION 'You can only delete your own comments.';
    END IF;

    IF EXISTS (SELECT 1 FROM public.comment WHERE parent_comment_id = p_comment_id) THEN
        UPDATE public.comment SET is_deleted = TRUE WHERE id = p_comment_id;
    ELSE
        DELETE FROM public.comment WHERE id = p_comment_id;

        -- Remove deleted parents that no longer have any replies
        WHILE v_parent_id IS NOT NULL
              AND EXISTS (SELECT 1 FROM public.comment WHERE id = v_parent_id AND is_deleted)
              AND NOT EXISTS (SELECT 1 FROM public.comment WHERE parent_comment_id = v_parent_id)
        LOOP
            DELETE FROM public.comment WHERE id = v_parent_id
            RETURNING parent_comment_id INTO v_parent_id;
        END LOOP;
    END IF;
END;
$$;

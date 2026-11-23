const { query } = require("../config/database");

// Empty form fields are sent to the database as NULL, so the procedures give their own
// "cannot be empty" / "rating must be..." messages instead of a type error.
const toNull = (value) => (value === undefined || value === "" ? null : value);

const createReview = async (memberId, productId, rating, reviewText) => {
  await query("CALL public.create_review($1, $2, $3, $4)", [
    memberId,
    toNull(productId),
    toNull(rating),
    toNull(reviewText),
  ]);
};

const getReviews = async (memberId) => {
  const result = await query("SELECT * FROM public.get_reviews($1)", [memberId]);
  return result.rows;
};

const updateReview = async (memberId, reviewId, rating, reviewText) => {
  await query("CALL public.update_review($1, $2, $3, $4)", [
    memberId,
    toNull(reviewId),
    toNull(rating),
    toNull(reviewText),
  ]);
};

const deleteReview = async (memberId, reviewId) => {
  await query("CALL public.delete_review($1, $2)", [memberId, toNull(reviewId)]);
};

module.exports = { createReview, getReviews, updateReview, deleteReview };

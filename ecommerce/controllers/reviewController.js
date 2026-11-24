const reviewModel = require("../models/reviewModel");

// All validation happens in the database procedures. This turns their errors into a response:
// - P0001: a RAISE EXCEPTION from a procedure, so its message is shown to the user as is
// - 22P02 / 22003: the value cannot be read as a number at all (eg "abc"), or an id is not a
//   whole number or is too large, so PostgreSQL rejects it before the procedure can check it
const sendError = (res, err) => {
  if (err.code === "P0001") {
    return res.status(400).json({ success: false, message: err.message });
  }
  if (err.code === "22P02" || err.code === "22003") {
    return res.status(400).json({ success: false, message: "The id and rating must be whole numbers." });
  }
  console.error(err);
  return res.status(500).json({ success: false, message: "Server error." });
};

// The member id always comes from the login token (req.user), never from the request body,
// so a member can only act as themselves.

const createReview = async (req, res) => {
  try {
    const { productId, rating, reviewText } = req.body;
    await reviewModel.createReview(req.user.id, productId, rating, reviewText);
    res.status(201).json({ success: true, message: "Review created." });
  } catch (err) {
    sendError(res, err);
  }
};

const getReviews = async (req, res) => {
  try {
    const reviews = await reviewModel.getReviews(req.user.id);
    res.json({ success: true, reviews });
  } catch (err) {
    sendError(res, err);
  }
};

const updateReview = async (req, res) => {
  try {
    const { reviewId, rating, reviewText } = req.body;
    await reviewModel.updateReview(req.user.id, reviewId, rating, reviewText);
    res.json({ success: true, message: "Review updated." });
  } catch (err) {
    sendError(res, err);
  }
};

const deleteReview = async (req, res) => {
  try {
    const { reviewId } = req.body;
    await reviewModel.deleteReview(req.user.id, reviewId);
    res.json({ success: true, message: "Review deleted." });
  } catch (err) {
    sendError(res, err);
  }
};

module.exports = { createReview, getReviews, updateReview, deleteReview };

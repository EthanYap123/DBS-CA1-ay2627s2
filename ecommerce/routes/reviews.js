const express = require("express");
const router = express.Router();
const reviewController = require("../controllers/reviewController");
const { verifyToken } = require("../middleware/auth");

router.post("/create", verifyToken, reviewController.createReview);
router.get("/retrieve/all", verifyToken, reviewController.getReviews);
router.put("/update", verifyToken, reviewController.updateReview);
router.delete("/delete", verifyToken, reviewController.deleteReview);

module.exports = router;

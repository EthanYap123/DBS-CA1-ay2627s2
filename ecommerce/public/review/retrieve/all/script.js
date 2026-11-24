document.addEventListener("DOMContentLoaded", () => {
  const token = localStorage.getItem("token");
  if (!token) {
    window.location.href = "/auth/login";
    return;
  }
  const username = localStorage.getItem("username") || "User";
  document.getElementById("navUsername").textContent = username;
  loadReviews();
});

async function loadReviews() {
  try {
    const res = await fetch("/api/review/retrieve/all", {
      headers: { Authorization: `Bearer ${localStorage.getItem("token")}` },
    });
    const data = await res.json();
    if (data.success) {
      renderReviews(data.reviews);
    } else {
      showError(data.message);
    }
  } catch (err) {
    showError("Failed to load reviews. Please try again.");
  }
}

function renderReviews(reviews) {
  const list = document.getElementById("reviewList");
  if (reviews.length === 0) {
    list.textContent = "You have not written any reviews yet.";
    return;
  }
  // get_reviews already returns them newest first
  reviews.forEach((review) => {
    const item = document.createElement("div");
    addLine(item, "h3", `Review ID: ${review.reviewId}`);
    addLine(item, "p", `Product Name: ${review.productName}`);
    addLine(item, "p", `Rating: ${"⭐".repeat(review.rating)}`);
    addLine(item, "p", `Review Text: ${review.reviewText}`);
    addLine(item, "p", `Last Updated: ${new Date(review.updatedAt).toLocaleString()}`);
    addButton(item, "Update", `/review/update/?id=${review.reviewId}`);
    addButton(item, "Delete", `/review/delete/?id=${review.reviewId}`);
    addLine(item, "hr", "");
    list.appendChild(item);
  });
}

// textContent, not innerHTML, so text typed in a review is never run as HTML
function addLine(parent, tag, text) {
  const el = document.createElement(tag);
  el.textContent = text;
  parent.appendChild(el);
}

function addButton(parent, text, url) {
  const button = document.createElement("button");
  button.textContent = text;
  button.addEventListener("click", () => {
    window.location.href = url;
  });
  parent.appendChild(button);
}

function showError(text) {
  const el = document.getElementById("message");
  el.textContent = text;
  el.className = "message error";
}

function logout() {
  localStorage.clear();
  window.location.href = "/auth/login";
}

document.addEventListener("DOMContentLoaded", () => {
  const token = localStorage.getItem("token");
  if (!token) {
    window.location.href = "/auth/login";
    return;
  }
  const username = localStorage.getItem("username") || "User";
  document.getElementById("navUsername").textContent = username;

  // Saved by the "Write a Review" button on the products page
  const savedId = localStorage.getItem("selectedProductId") || "";
  const savedName = localStorage.getItem("selectedProductName") || "";
  const productIdInput = document.getElementById("productId");
  productIdInput.value = savedId;

  // Only show the product name while the id in the box is the one it belongs to
  const showTitle = () => {
    const matches = savedName && productIdInput.value.trim() === savedId;
    document.getElementById("pageTitle").textContent = matches
      ? `Create Review for ${savedName}`
      : "Create Review";
  };
  showTitle();
  productIdInput.addEventListener("input", showTitle);

  document.getElementById("createForm").addEventListener("submit", createReview);
});

// The values are not checked here. The database checks them and its message is shown.
async function createReview(event) {
  event.preventDefault();
  try {
    const res = await fetch("/api/review/create", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${localStorage.getItem("token")}`,
      },
      body: JSON.stringify({
        productId: document.getElementById("productId").value.trim(),
        rating: document.getElementById("rating").value.trim(),
        reviewText: document.getElementById("reviewText").value,
      }),
    });
    const data = await res.json();
    showMessage(data.message, data.success);
    if (data.success) {
      document.getElementById("rating").value = "";
      document.getElementById("reviewText").value = "";
    }
  } catch (err) {
    showMessage("Cannot connect to server.", false);
  }
}

function showMessage(text, success) {
  const el = document.getElementById("message");
  el.textContent = text;
  el.className = success ? "message" : "message error";
}

function logout() {
  localStorage.clear();
  window.location.href = "/auth/login";
}

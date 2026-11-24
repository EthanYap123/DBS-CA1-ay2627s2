document.addEventListener("DOMContentLoaded", () => {
  const token = localStorage.getItem("token");
  if (!token) {
    window.location.href = "/auth/login";
    return;
  }
  const username = localStorage.getItem("username") || "User";
  document.getElementById("navUsername").textContent = username;

  // The Update button on My Reviews passes the review id in the URL (?id=6)
  const id = new URLSearchParams(window.location.search).get("id") || "";
  document.getElementById("reviewId").value = id;

  document.getElementById("updateForm").addEventListener("submit", updateReview);
});

// The values are not checked here. The database checks them and its message is shown.
async function updateReview(event) {
  event.preventDefault();
  try {
    const res = await fetch("/api/review/update", {
      method: "PUT",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${localStorage.getItem("token")}`,
      },
      body: JSON.stringify({
        reviewId: document.getElementById("reviewId").value.trim(),
        rating: document.getElementById("rating").value,
        reviewText: document.getElementById("reviewText").value,
      }),
    });
    const data = await res.json();
    showMessage(data.message, data.success);
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

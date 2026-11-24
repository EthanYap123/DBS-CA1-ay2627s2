document.addEventListener("DOMContentLoaded", () => {
  const token = localStorage.getItem("token");
  if (!token) {
    window.location.href = "/auth/login";
    return;
  }
  const username = localStorage.getItem("username") || "User";
  document.getElementById("navUsername").textContent = username;

  // The Delete button on My Reviews passes the review id in the URL (?id=6)
  const id = new URLSearchParams(window.location.search).get("id") || "";
  document.getElementById("reviewId").value = id;

  document.getElementById("deleteForm").addEventListener("submit", deleteReview);
});

// The database checks that the review exists and is the member's own. Its comments are deleted with it.
async function deleteReview(event) {
  event.preventDefault();
  try {
    const res = await fetch("/api/review/delete", {
      method: "DELETE",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${localStorage.getItem("token")}`,
      },
      body: JSON.stringify({
        reviewId: document.getElementById("reviewId").value.trim(),
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

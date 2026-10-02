"use strict";

const menuButton = document.querySelector(".menu-toggle");
const navigation = document.querySelector("#site-nav");

function fitMenuToViewport() {
  const headerBottom = document.querySelector(".site-header")?.getBoundingClientRect().bottom ?? 0;
  navigation?.style.setProperty("--menu-top", `${Math.max(0, headerBottom)}px`);
}

function closeMenu() {
  navigation?.classList.remove("is-open");
  document.body.classList.remove("menu-open");
  menuButton?.setAttribute("aria-expanded", "false");
  menuButton?.setAttribute("aria-label", "Open navigation");
}

menuButton?.addEventListener("click", () => {
  const opening = menuButton.getAttribute("aria-expanded") !== "true";
  menuButton.setAttribute("aria-expanded", String(opening));
  menuButton.setAttribute(
    "aria-label",
    opening ? "Close navigation" : "Open navigation",
  );
  if (opening) fitMenuToViewport();
  navigation.classList.toggle("is-open", opening);
  document.body.classList.toggle("menu-open", opening);
});

navigation?.addEventListener("click", (event) => {
  if (event.target.closest("a")) closeMenu();
});

document.addEventListener("keydown", (event) => {
  if (
    event.key === "Escape" &&
    menuButton?.getAttribute("aria-expanded") === "true"
  ) {
    closeMenu();
    menuButton.focus();
  }
});

// Keep keyboard navigation inside the mobile menu while it is open.
document.addEventListener("keydown", (event) => {
  if (
    event.key !== "Tab" ||
    menuButton?.getAttribute("aria-expanded") !== "true"
  )
    return;
  const links = [...navigation.querySelectorAll("a")];
  const last = links.at(-1);
  if (event.shiftKey && document.activeElement === menuButton) {
    event.preventDefault();
    last?.focus();
  } else if (!event.shiftKey && document.activeElement === last) {
    event.preventDefault();
    menuButton.focus();
  }
});

window.matchMedia("(max-width: 900px)").addEventListener("change", closeMenu);
window.addEventListener("resize", () => {
  if (menuButton?.getAttribute("aria-expanded") === "true") fitMenuToViewport();
});

// On compact screens, keep regional phone choices within reach without crowding the header.
const mobileCall = document.createElement("div");
mobileCall.className = "mobile-call";
mobileCall.innerHTML = `
  <div class="mobile-call__panel" id="mobile-call-panel" hidden>
    <p>Call Tri State</p>
    <a href="tel:+19287687814"><span>Arizona & Nevada</span><strong>928.768.7814</strong></a>
    <a href="tel:+17142698800"><span>California & Hawaii</span><strong>714.269.8800</strong></a>
  </div>
  <button class="mobile-call__button" type="button" aria-expanded="false" aria-controls="mobile-call-panel">
    <svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M7.5 3.5h2.2l1.1 4-1.7 1.7a15.4 15.4 0 0 0 5.7 5.7l1.7-1.7 4 1.1v2.2a2 2 0 0 1-2.2 2A16.8 16.8 0 0 1 5.5 5.7 2 2 0 0 1 7.5 3.5Z" stroke="currentColor" stroke-width="1.5" stroke-linejoin="round"/></svg>
    <span>Call</span>
  </button>`;
document.body.appendChild(mobileCall);

const mobileCallButton = mobileCall.querySelector(".mobile-call__button");
const mobileCallPanel = mobileCall.querySelector(".mobile-call__panel");

function closeMobileCall({ returnFocus = false } = {}) {
  if (mobileCallButton?.getAttribute("aria-expanded") !== "true") return;
  mobileCallButton.setAttribute("aria-expanded", "false");
  mobileCallPanel.hidden = true;
  if (returnFocus) mobileCallButton.focus();
}

mobileCallButton.addEventListener("click", () => {
  const opening = mobileCallButton.getAttribute("aria-expanded") !== "true";
  mobileCallButton.setAttribute("aria-expanded", String(opening));
  mobileCallPanel.hidden = !opening;
});

document.addEventListener("click", (event) => {
  if (!mobileCall.contains(event.target)) closeMobileCall();
});
document.addEventListener("keydown", (event) => {
  if (event.key === "Escape") closeMobileCall({ returnFocus: true });
});
window.matchMedia("(min-width: 701px)").addEventListener("change", closeMobileCall);
document.querySelectorAll("[data-year]").forEach((node) => {
  node.textContent = new Date().getFullYear();
});

// Keep project photos in a dismissible, accessible viewer.
const imageLinks = document.querySelectorAll(
  ".projects-section a[data-project-preview]",
);

if (imageLinks.length && typeof HTMLDialogElement !== "undefined") {
  const viewer = document.createElement("dialog");
  viewer.className = "image-viewer";
  viewer.setAttribute("aria-labelledby", "image-viewer-caption");
  viewer.innerHTML = `
    <div class="image-viewer__panel">
      <div class="image-viewer__toolbar">
        <p id="image-viewer-caption"></p>
        <button class="image-viewer__close" type="button" aria-label="Close image">
          <span>Close</span><span aria-hidden="true">×</span>
        </button>
      </div>
      <div class="image-viewer__content">
        <img class="image-viewer__image" alt="" />
        <p class="image-viewer__status" role="status" aria-live="polite"></p>
      </div>
    </div>`;
  document.body.appendChild(viewer);

  const viewerImage = viewer.querySelector(".image-viewer__image");
  const caption = viewer.querySelector("#image-viewer-caption");
  const status = viewer.querySelector(".image-viewer__status");
  const closeButton = viewer.querySelector(".image-viewer__close");
  let originLink;

  viewerImage.addEventListener("load", () => {
    if (viewer.open) status.textContent = "";
  });
  viewerImage.addEventListener("error", () => {
    if (viewer.open)
      status.textContent =
        "The image could not load. Close the viewer and try again.";
  });

  imageLinks.forEach((link) => {
    link.addEventListener("click", (event) => {
      if (
        event.button !== 0 ||
        event.metaKey ||
        event.ctrlKey ||
        event.shiftKey ||
        event.altKey
      )
        return;
      event.preventDefault();
      originLink = link;
      const description = link.closest(".project-card")?.querySelector("img")?.alt || "Project image";
      caption.textContent = description;
      viewerImage.alt = description;
      status.textContent = "Loading image…";
      viewerImage.src = link.href;
      document.body.classList.add("viewer-open");
      viewer.showModal();
      closeButton.focus();
    });
  });

  closeButton.addEventListener("click", () => viewer.close());
  viewer.addEventListener("click", (event) => {
    if (event.target !== viewer) return;
    const box = viewer.getBoundingClientRect();
    if (
      event.clientX < box.left ||
      event.clientX > box.right ||
      event.clientY < box.top ||
      event.clientY > box.bottom
    )
      viewer.close();
  });
  // Native dialog dismissal also handles Escape and keeps focus inside the modal.
  viewer.addEventListener("close", () => {
    document.body.classList.remove("viewer-open");
    viewerImage.removeAttribute("src");
    status.textContent = "";
    originLink?.focus({ preventScroll: true });
  });
}

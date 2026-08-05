/* FourFold System — shared interactivity */
(function () {
  "use strict";

  /* ---------- Navbar scroll state ---------- */
  var navbar = document.querySelector(".navbar");
  function onScroll() {
    if (!navbar) return;
    if (window.scrollY > 20) navbar.classList.add("scrolled");
    else navbar.classList.remove("scrolled");

    var toTop = document.querySelector(".to-top");
    if (toTop) {
      if (window.scrollY > 700) toTop.classList.add("show");
      else toTop.classList.remove("show");
    }
  }
  document.addEventListener("scroll", onScroll, { passive: true });
  onScroll();

  /* ---------- Mobile menu ---------- */
  var hamburger = document.querySelector(".hamburger");
  var mobileMenu = document.querySelector(".mobile-menu");
  var scrim = document.querySelector(".menu-scrim");
  function closeMenu() {
    hamburger && hamburger.classList.remove("open");
    mobileMenu && mobileMenu.classList.remove("open");
    scrim && scrim.classList.remove("open");
    document.body.style.overflow = "";
  }
  if (hamburger) {
    hamburger.addEventListener("click", function () {
      var opening = !mobileMenu.classList.contains("open");
      hamburger.classList.toggle("open", opening);
      mobileMenu.classList.toggle("open", opening);
      scrim.classList.toggle("open", opening);
      document.body.style.overflow = opening ? "hidden" : "";
    });
  }
  scrim && scrim.addEventListener("click", closeMenu);
  document.querySelectorAll(".mobile-menu a").forEach(function (a) {
    a.addEventListener("click", closeMenu);
  });

  /* ---------- Back to top ---------- */
  var toTopBtn = document.querySelector(".to-top");
  toTopBtn &&
    toTopBtn.addEventListener("click", function () {
      window.scrollTo({ top: 0, behavior: "smooth" });
    });

  /* ---------- Scroll reveal ---------- */
  var revealEls = document.querySelectorAll(".reveal, .reveal-stagger");
  if ("IntersectionObserver" in window) {
    var io = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          if (entry.isIntersecting) {
            entry.target.classList.add("in-view");
            io.unobserve(entry.target);
          }
        });
      },
      { threshold: 0.15, rootMargin: "0px 0px -60px 0px" }
    );
    revealEls.forEach(function (el) {
      io.observe(el);
    });
  } else {
    revealEls.forEach(function (el) {
      el.classList.add("in-view");
    });
  }

  /* ---------- Card cursor glow ---------- */
  document.querySelectorAll(".card").forEach(function (card) {
    card.addEventListener("mousemove", function (e) {
      var r = card.getBoundingClientRect();
      card.style.setProperty("--mx", (e.clientX - r.left) + "px");
      card.style.setProperty("--my", (e.clientY - r.top) + "px");
    });
  });

  /* ---------- Counter animation for stat numbers ---------- */
  document.querySelectorAll("[data-count]").forEach(function (el) {
    var target = parseFloat(el.getAttribute("data-count"));
    var suffix = el.getAttribute("data-suffix") || "";
    var decimals = el.getAttribute("data-decimals") ? parseInt(el.getAttribute("data-decimals"), 10) : 0;
    var started = false;
    var obs = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          if (entry.isIntersecting && !started) {
            started = true;
            var start = performance.now();
            var dur = 1400;
            function tick(now) {
              var p = Math.min(1, (now - start) / dur);
              var eased = 1 - Math.pow(1 - p, 3);
              var val = target * eased;
              el.textContent = val.toFixed(decimals) + suffix;
              if (p < 1) requestAnimationFrame(tick);
              else el.textContent = target.toFixed(decimals) + suffix;
            }
            requestAnimationFrame(tick);
            obs.unobserve(el);
          }
        });
      },
      { threshold: 0.4 }
    );
    obs.observe(el);
  });

  /* ---------- Bubbles generator for tanks ---------- */
  document.querySelectorAll(".bubbles").forEach(function (container) {
    for (var i = 0; i < 6; i++) {
      var b = document.createElement("span");
      b.className = "bubble";
      b.style.left = 8 + Math.random() * 80 + "%";
      b.style.animationDuration = 2.5 + Math.random() * 2.5 + "s";
      b.style.animationDelay = Math.random() * 3 + "s";
      container.appendChild(b);
    }
  });

  /* ---------- Live device panel demo (hero) ---------- */
  var panel = document.querySelector("[data-panel-demo]");
  if (panel) {
    var seg = panel.querySelector(".seven-seg");
    var ledOL = panel.querySelector(".led.led-ol");
    var ledDR = panel.querySelector(".led.led-dr");
    var ledSC = panel.querySelector(".led.led-sc");
    var caption = panel.querySelector(".panel-caption");
    var btnOn = panel.querySelector(".panel-btn.on");
    var btnOff = panel.querySelector(".panel-btn.off");
    var overheadWater = document.querySelector("[data-tank='overhead'] .water");
    var overheadPct = document.querySelector("[data-tank='overhead'] .pct");
    var undergroundWater = document.querySelector("[data-tank='underground'] .water");
    var undergroundPct = document.querySelector("[data-tank='underground'] .pct");

    var oh = 32, ug = 78;

    function setTanks() {
      if (overheadWater) overheadWater.style.height = oh + "%";
      if (overheadPct) overheadPct.textContent = Math.round(oh) + "%";
      if (undergroundWater) undergroundWater.style.height = ug + "%";
      if (undergroundPct) undergroundPct.textContent = Math.round(ug) + "%";
    }
    setTanks();

    function clearLeds() {
      [ledOL, ledDR, ledSC].forEach(function (l) {
        l && l.classList.remove("on");
      });
    }

    var states = [
      {
        text: "OFF",
        cls: "state-off",
        caption: "Standby — press ON to start the motor",
        btn: "off",
        pumping: false,
      },
      {
        text: "0.4A",
        cls: "",
        caption: "Motor starting… monitoring current",
        btn: "on",
        pumping: true,
      },
      {
        text: "10.1A",
        cls: "",
        caption: "Running normally — transferring water",
        btn: "on",
        pumping: true,
      },
      {
        text: "12.8A",
        cls: "",
        led: "ol",
        caption: "Overload detected — motor auto-stopped to protect it",
        btn: "off",
        pumping: false,
      },
      {
        text: "0.2A",
        cls: "",
        led: "dr",
        caption: "Dry run detected — underground tank empty, motor stopped",
        btn: "off",
        pumping: false,
      },
    ];

    var idx = 0;
    var pumpTimer = null;

    function applyState(s) {
      clearLeds();
      if (seg) {
        seg.textContent = s.text;
        seg.className = "seven-seg " + s.cls;
      }
      if (s.led === "ol" && ledOL) ledOL.classList.add("on");
      if (s.led === "dr" && ledDR) ledDR.classList.add("on");
      if (s.led === "sc" && ledSC) ledSC.classList.add("on");
      if (caption) caption.textContent = s.caption;
      if (btnOn) btnOn.classList.toggle("active", s.btn === "on");
      if (btnOff) btnOff.classList.toggle("active", s.btn === "off");

      clearInterval(pumpTimer);
      if (s.pumping) {
        pumpTimer = setInterval(function () {
          ug = Math.max(8, ug - 2.2);
          oh = Math.min(94, oh + 1.6);
          setTanks();
        }, 220);
      }
    }

    applyState(states[0]);
    setInterval(function () {
      idx = (idx + 1) % states.length;
      applyState(states[idx]);
    }, 2600);
  }

  /* ---------- Contact form -> mailto ---------- */
  var contactForm = document.querySelector("#inquiry-form");
  if (contactForm) {
    contactForm.addEventListener("submit", function (e) {
      e.preventDefault();
      var name = contactForm.querySelector("[name='name']").value.trim();
      var phone = contactForm.querySelector("[name='phone']").value.trim();
      var email = contactForm.querySelector("[name='email']").value.trim();
      var topic = contactForm.querySelector("[name='topic']").value;
      var message = contactForm.querySelector("[name='message']").value.trim();

      var subject = "Inquiry from " + name + " — " + topic;
      var body =
        "Name: " + name + "\n" +
        "Phone: " + phone + "\n" +
        "Email: " + email + "\n" +
        "Topic: " + topic + "\n\n" +
        message;

      var mailto =
        "mailto:fourfoldsystem@gmail.com?subject=" +
        encodeURIComponent(subject) +
        "&body=" +
        encodeURIComponent(body);

      window.location.href = mailto;

      var status = contactForm.querySelector(".form-status");
      if (status) {
        status.textContent = "Opening your email app to send this inquiry to fourfoldsystem@gmail.com…";
        status.classList.add("show", "ok");
      }
    });
  }

  /* ---------- Notify me (coming soon) ---------- */
  var notifyForm = document.querySelector("#notify-form");
  if (notifyForm) {
    notifyForm.addEventListener("submit", function (e) {
      e.preventDefault();
      var email = notifyForm.querySelector("input").value.trim();
      var status = notifyForm.querySelector(".form-status");
      var mailto =
        "mailto:fourfoldsystem@gmail.com?subject=" +
        encodeURIComponent("Notify me — Raise a Ticket feature") +
        "&body=" +
        encodeURIComponent("Please notify me at " + email + " when the Raise a Ticket feature launches.");
      window.location.href = mailto;
      if (status) {
        status.textContent = "Thanks! We'll reach out at " + email + " when this feature is live.";
        status.classList.add("show", "ok");
      }
      notifyForm.reset();
    });
  }

  /* ---------- Active nav link ---------- */
  var current = (window.location.pathname.split("/").pop() || "index.html");
  document.querySelectorAll(".nav-links a, .mobile-menu a").forEach(function (a) {
    var href = a.getAttribute("href");
    if (href === current || (current === "" && href === "index.html")) {
      a.classList.add("active");
    }
  });
})();

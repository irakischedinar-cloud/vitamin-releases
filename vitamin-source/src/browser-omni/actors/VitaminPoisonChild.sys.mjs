/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * VitaminPoisonChild - Content process actor for human-like behavior simulation
 * Implements realistic mouse movements, scrolling, and link clicking
 */

export class VitaminPoisonChild extends JSWindowActorChild {
  constructor() {
    super();
    this.currentX = 0;
    this.currentY = 0;
    // Fitts's Law constants (empirically derived)
    this.FITTS_A = 50;  // Base time (ms)
    this.FITTS_B = 150; // Movement factor
    // Human micro-tremor frequency (~10Hz)
    this.TREMOR_FREQ = 10;
    this.TREMOR_AMP = 1.5;
  }

  receiveMessage(message) {
    switch (message.name) {
      case "VitaminPoison:Scroll":
        this.doScroll(message.data);
        break;
      case "VitaminPoison:ScrollSequence":
        this.doScrollSequence(message.data);
        break;
      case "VitaminPoison:SimulateBehavior":
        this.simulateBehavior(message.data);
        break;
    }
    return null;
  }

  doScroll(data) {
    const { amount } = data;
    try {
      this.contentWindow.scrollBy({ top: amount, behavior: "smooth" });
    } catch (e) {
      // Window may have been closed
    }
  }

  doScrollSequence(data) {
    const { scrolls } = data;
    let index = 0;

    const doNext = () => {
      if (index >= scrolls.length) return;

      const { amount, delay } = scrolls[index];
      try {
        this.contentWindow.scrollBy({ top: amount, behavior: "smooth" });
      } catch (e) {
        return;
      }

      index++;
      if (index < scrolls.length) {
        this.contentWindow.setTimeout(doNext, delay);
      }
    };

    doNext();
  }

  // Main behavior simulation entry point
  simulateBehavior(data) {
    const { sequence, isSearchPage, fingerprint } = data;

    // Spoof fingerprint properties first (before any trackers can read them)
    if (fingerprint) {
      this.spoofFingerprint(fingerprint);
    }

    // Initialize mouse position
    this.currentX = this.contentWindow.innerWidth / 2;
    this.currentY = this.contentWindow.innerHeight / 2;

    // First check for CAPTCHA
    this.contentWindow.setTimeout(async () => {
      const captchaResult = this.detectAndHandleRecaptcha();

      if (captchaResult.detected) {
        if (captchaResult.solvable && captchaResult.element) {
          // Try to solve checkbox CAPTCHA
          const solved = await this.attemptRecaptchaCheckbox(captchaResult.element);
          if (!solved) {
            // Failed to solve - notify parent to close tab
            this.sendAsyncMessage("VitaminPoison:CaptchaDetected", {
              type: captchaResult.type,
              solved: false
            });
            return;
          }
          // Solved! Continue with behavior
        } else {
          // Unsolvable CAPTCHA - notify parent to close tab
          this.sendAsyncMessage("VitaminPoison:CaptchaDetected", {
            type: captchaResult.type,
            solved: false
          });
          return;
        }
      }

      // Handle cookie banners
      this.handleCookieBanner();

      // Start behavior sequence after brief delay
      this.contentWindow.setTimeout(() => {
        this.executeSequence(sequence, 0);
      }, 500);
    }, 1000);
  }

  // Spoof navigator and screen properties to match the fingerprint
  // Note: JS property spoofing is limited due to CSP - HTTP headers do the heavy lifting
  spoofFingerprint(fp) {
    // Fingerprint spoofing via JS is unreliable due to CSP restrictions
    // The HTTP User-Agent header spoofing in the parent process handles the main fingerprint
    // This is intentionally minimal to avoid browser freezes
    return;
  }

  executeSequence(sequence, index) {
    if (index >= sequence.length) return;

    const action = sequence[index];

    try {
      switch (action.type) {
        case "pause":
          this.contentWindow.setTimeout(() => {
            this.executeSequence(sequence, index + 1);
          }, action.duration);
          break;

        case "mouseMove":
          this.simulateMouseMove(action.x, action.y, action.duration, () => {
            this.executeSequence(sequence, index + 1);
          });
          break;

        case "scroll":
          this.simulateSmoothScroll(action.amount, action.duration, () => {
            this.executeSequence(sequence, index + 1);
          });
          break;

        case "clickSearchResult":
          this.clickSearchResult(action.resultIndex, () => {
            this.executeSequence(sequence, index + 1);
          });
          break;

        default:
          this.executeSequence(sequence, index + 1);
      }
    } catch (e) {
      // Continue with next action even if one fails
      this.contentWindow.setTimeout(() => {
        this.executeSequence(sequence, index + 1);
      }, 100);
    }
  }

  // Fitts's Law: Calculate realistic movement time based on distance and target size
  fittsMovementTime(distance, targetWidth = 50) {
    // MT = a + b * log2(D/W + 1)
    const id = Math.log2(distance / targetWidth + 1); // Index of difficulty
    return this.FITTS_A + this.FITTS_B * id;
  }

  // Human-like velocity profile (slow-fast-slow with asymmetry)
  velocityProfile(t) {
    // Minimum jerk trajectory (realistic human movement)
    // Slightly asymmetric - faster acceleration, slower deceleration
    const t2 = t * t;
    const t3 = t2 * t;
    const t4 = t3 * t;
    const t5 = t4 * t;
    return 10 * t3 - 15 * t4 + 6 * t5;
  }

  // Generate micro-tremor (human hand shake ~8-12Hz)
  microTremor(time) {
    const freq = this.TREMOR_FREQ + (Math.random() - 0.5) * 4;
    const amp = this.TREMOR_AMP * (0.5 + Math.random() * 0.5);
    return Math.sin(time * freq * 2 * Math.PI / 1000) * amp;
  }

  // Bezier curve for natural mouse movement
  bezierPoint(t, p0, p1, p2, p3) {
    const u = 1 - t;
    return u * u * u * p0 + 3 * u * u * t * p1 + 3 * u * t * t * p2 + t * t * t * p3;
  }

  // Generate control points with human-like curvature
  generateControlPoints(startX, startY, endX, endY) {
    const dx = endX - startX;
    const dy = endY - startY;
    const dist = Math.sqrt(dx * dx + dy * dy);

    // Curvature varies with distance (longer = more curve)
    const curveFactor = Math.min(0.4, dist / 1000);

    // Perpendicular offset for arc
    const perpX = -dy / dist * curveFactor * dist * (Math.random() - 0.3);
    const perpY = dx / dist * curveFactor * dist * (Math.random() - 0.3);

    const cp1x = startX + dx * 0.25 + perpX * 0.5;
    const cp1y = startY + dy * 0.25 + perpY * 0.5;
    const cp2x = startX + dx * 0.75 + perpX * 0.5;
    const cp2y = startY + dy * 0.75 + perpY * 0.5;

    return { cp1x, cp1y, cp2x, cp2y };
  }

  // Fitts's Law mouse movement with overshoot and correction
  simulateMouseMove(targetX, targetY, requestedDuration, callback) {
    const startX = this.currentX;
    const startY = this.currentY;
    const dx = targetX - startX;
    const dy = targetY - startY;
    const distance = Math.sqrt(dx * dx + dy * dy);

    if (distance < 5) {
      callback();
      return;
    }

    // Use Fitts's Law for duration (ignore requested, calculate realistic)
    const duration = Math.max(150, this.fittsMovementTime(distance));

    // 30% chance of overshoot on longer movements
    const willOvershoot = distance > 100 && Math.random() < 0.3;
    const overshootAmount = willOvershoot ? (0.05 + Math.random() * 0.1) : 0;

    // Overshoot target
    const overshootX = targetX + dx * overshootAmount;
    const overshootY = targetY + dy * overshootAmount;

    const { cp1x, cp1y, cp2x, cp2y } = this.generateControlPoints(startX, startY, overshootX, overshootY);

    const steps = Math.max(15, Math.floor(duration / 12)); // ~83fps for smoothness
    let currentStep = 0;
    const startTime = Date.now();
    const self = this;

    const moveStep = () => {
      const elapsed = Date.now() - startTime;
      const t = Math.min(1, elapsed / duration);

      if (t >= 1) {
        if (willOvershoot) {
          // Correction movement back to actual target
          self.currentX = overshootX;
          self.currentY = overshootY;
          self.contentWindow.setTimeout(() => {
            self.simulateCorrection(targetX, targetY, callback);
          }, 30 + Math.random() * 50);
        } else {
          self.currentX = targetX;
          self.currentY = targetY;
          self.dispatchMouseEvent("mousemove", targetX, targetY);
          callback();
        }
        return;
      }

      // Apply velocity profile
      const vt = self.velocityProfile(t);

      const x = self.bezierPoint(vt, startX, cp1x, cp2x, overshootX);
      const y = self.bezierPoint(vt, startY, cp1y, cp2y, overshootY);

      // Add micro-tremor
      const tremor = self.microTremor(elapsed);
      const tremorAngle = Math.random() * Math.PI * 2;

      self.currentX = x + Math.cos(tremorAngle) * tremor;
      self.currentY = y + Math.sin(tremorAngle) * tremor;

      self.dispatchMouseEvent("mousemove", self.currentX, self.currentY);

      self.contentWindow.setTimeout(moveStep, 12);
    };

    moveStep();
  }

  // Correction movement after overshoot (quick, small adjustment)
  simulateCorrection(targetX, targetY, callback) {
    const startX = this.currentX;
    const startY = this.currentY;
    const distance = Math.sqrt((targetX - startX) ** 2 + (targetY - startY) ** 2);
    const duration = 50 + distance * 2;
    const steps = Math.max(5, Math.floor(duration / 16));
    let currentStep = 0;
    const self = this;

    const correctStep = () => {
      currentStep++;
      const t = currentStep / steps;

      // Quick ease-out
      const et = 1 - Math.pow(1 - t, 2);

      self.currentX = startX + (targetX - startX) * et;
      self.currentY = startY + (targetY - startY) * et;
      self.dispatchMouseEvent("mousemove", self.currentX, self.currentY);

      if (currentStep >= steps) {
        self.currentX = targetX;
        self.currentY = targetY;
        callback();
      } else {
        self.contentWindow.setTimeout(correctStep, 16);
      }
    };

    correctStep();
  }

  // Dispatch mouse event at given coordinates
  dispatchMouseEvent(type, x, y) {
    try {
      const event = new this.contentWindow.MouseEvent(type, {
        bubbles: true,
        cancelable: true,
        clientX: x,
        clientY: y,
        screenX: x,
        screenY: y,
        view: this.contentWindow
      });

      // Find element at position and dispatch event
      const element = this.document.elementFromPoint(x, y);
      if (element) {
        element.dispatchEvent(event);
      }
    } catch (e) {
      // Ignore errors from event dispatch
    }
  }

  // Smooth scroll with variable speed (faster in middle, slower at edges)
  simulateSmoothScroll(amount, duration, callback) {
    const steps = Math.max(5, Math.floor(duration / 50));
    let currentStep = 0;
    let scrolled = 0;

    const scrollStep = () => {
      if (currentStep >= steps) {
        callback();
        return;
      }

      // Ease-in-out for natural scroll feel
      let t = (currentStep + 1) / steps;
      t = t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2;

      const targetScrolled = amount * t;
      const stepAmount = targetScrolled - scrolled;

      this.contentWindow.scrollBy({ top: stepAmount, behavior: "auto" });
      scrolled = targetScrolled;

      currentStep++;
      this.contentWindow.setTimeout(scrollStep, duration / steps);
    };

    scrollStep();
  }

  // Check if URL is safe to click
  isUrlSafe(href) {
    // BLOCK: Only allow http/https protocols
    try {
      const url = new URL(href);
      if (url.protocol !== "http:" && url.protocol !== "https:") return false;
      // BLOCK: Local/private network addresses
      const hostname = url.hostname;
      if (hostname === "localhost" ||
          hostname === "127.0.0.1" ||
          hostname === "::1" ||
          hostname.startsWith("192.168.") ||
          hostname.startsWith("10.") ||
          hostname.startsWith("172.") ||
          hostname.endsWith(".local")) {
        return false;
      }
    } catch (e) {
      return false; // Invalid URL
    }

    const lowerHref = href.toLowerCase();

    // BLOCK: Download file extensions
    const dangerousExtensions = [
      '.exe', '.msi', '.dmg', '.pkg', '.deb', '.rpm', '.appimage',
      '.zip', '.rar', '.7z', '.tar', '.gz', '.bz2',
      '.iso', '.img', '.bin',
      '.bat', '.cmd', '.sh', '.ps1', '.vbs', '.js',
      '.apk', '.ipa',
      '.torrent', '.magnet'
    ];
    for (const ext of dangerousExtensions) {
      if (lowerHref.includes(ext)) return false;
    }

    // BLOCK: Shopping/checkout/payment
    const shoppingPatterns = [
      'checkout', 'check-out', 'cart', 'basket', 'buy-now', 'buynow',
      'purchase', 'payment', 'pay-now', 'paynow', 'order-now', 'ordernow',
      'add-to-cart', 'addtocart', 'add-to-basket', 'billing',
      'subscribe', 'subscription', 'upgrade', 'pricing',
      '/pay/', '/buy/', '/order/', '/shop/cart', '/checkout/',
      'paypal', 'stripe.com', 'square.com'
    ];
    for (const pattern of shoppingPatterns) {
      if (lowerHref.includes(pattern)) return false;
    }

    // BLOCK: Login/signup/auth pages
    const authPatterns = [
      'login', 'log-in', 'signin', 'sign-in', 'signup', 'sign-up',
      'register', 'auth/', 'oauth', 'sso/', 'account/create',
      'forgot-password', 'reset-password', 'verify-email'
    ];
    for (const pattern of authPatterns) {
      if (lowerHref.includes(pattern)) return false;
    }

    // BLOCK: URL shorteners (hide destination)
    const shorteners = [
      'bit.ly', 'tinyurl', 't.co', 'goo.gl', 'ow.ly', 'is.gd',
      'buff.ly', 'adf.ly', 'bit.do', 'mcaf.ee', 'su.pr'
    ];
    for (const shortener of shorteners) {
      if (lowerHref.includes(shortener)) return false;
    }

    // BLOCK: Potentially dangerous sites
    const dangerousSites = [
      'malware', 'virus', 'crack', 'keygen', 'warez', 'torrent',
      'phishing', 'scam'
    ];
    for (const site of dangerousSites) {
      if (lowerHref.includes(site)) return false;
    }

    return true;
  }

  // Detect and handle reCAPTCHA challenges
  detectAndHandleRecaptcha() {
    try {
      const doc = this.document;
      const url = this.contentWindow.location.href;

      // Check for Google "unusual traffic" page
      if (url.includes("google.com") && url.includes("sorry")) {
        return { detected: true, type: "blocked", solvable: false };
      }

      // Check for reCAPTCHA iframe
      const recaptchaFrame = doc.querySelector('iframe[src*="recaptcha"]');
      if (recaptchaFrame) {
        return { detected: true, type: "recaptcha_frame", solvable: false };
      }

      // Check for reCAPTCHA v2 checkbox
      const recaptchaCheckbox = doc.querySelector('.g-recaptcha, .recaptcha-checkbox, [data-sitekey]');
      if (recaptchaCheckbox) {
        return { detected: true, type: "checkbox", solvable: true, element: recaptchaCheckbox };
      }

      // Check for image challenge (if already triggered)
      const imageChallenge = doc.querySelector('.rc-imageselect, .rc-image-tile-wrapper, [class*="rc-image"]');
      if (imageChallenge) {
        return { detected: true, type: "image_challenge", solvable: false };
      }

      // Check for hCaptcha
      const hcaptcha = doc.querySelector('.h-captcha, iframe[src*="hcaptcha"]');
      if (hcaptcha) {
        return { detected: true, type: "hcaptcha", solvable: false };
      }

      // Check for generic CAPTCHA indicators in page text
      const bodyText = doc.body?.innerText?.toLowerCase() || "";
      if (bodyText.includes("unusual traffic") ||
          bodyText.includes("not a robot") ||
          bodyText.includes("verify you're human") ||
          bodyText.includes("captcha")) {
        return { detected: true, type: "generic", solvable: false };
      }

      return { detected: false };
    } catch (e) {
      return { detected: false };
    }
  }

  // Attempt to solve reCAPTCHA checkbox (just click it with human-like behavior)
  async attemptRecaptchaCheckbox(element) {
    try {
      // Find the actual clickable checkbox
      let checkbox = element.querySelector('.recaptcha-checkbox') ||
                     element.querySelector('[role="checkbox"]') ||
                     element;

      // Try to find it in iframe if not directly accessible
      if (!checkbox || !checkbox.getBoundingClientRect) {
        const iframe = this.document.querySelector('iframe[src*="recaptcha"]');
        if (iframe) {
          try {
            const iframeDoc = iframe.contentDocument || iframe.contentWindow?.document;
            if (iframeDoc) {
              checkbox = iframeDoc.querySelector('.recaptcha-checkbox, [role="checkbox"]');
            }
          } catch (e) {
            // Cross-origin iframe, can't access
            return false;
          }
        }
      }

      if (!checkbox) return false;

      const rect = checkbox.getBoundingClientRect();
      if (rect.width === 0 || rect.height === 0) return false;

      // Calculate click position with slight randomness (humans don't click center exactly)
      const clickX = rect.left + rect.width * (0.3 + Math.random() * 0.4);
      const clickY = rect.top + rect.height * (0.3 + Math.random() * 0.4);

      // Move mouse to checkbox with Fitts's Law timing
      return new Promise(resolve => {
        // Pre-click pause (human hesitation)
        this.contentWindow.setTimeout(() => {
          this.simulateMouseMove(clickX, clickY, 0, () => {
            // Pause before clicking (reading/confirming)
            this.contentWindow.setTimeout(() => {
              // Click sequence
              this.dispatchMouseEvent("mousedown", clickX, clickY);
              this.contentWindow.setTimeout(() => {
                this.dispatchMouseEvent("mouseup", clickX, clickY);
                this.dispatchMouseEvent("click", clickX, clickY);

                // Try actual click too
                try { checkbox.click(); } catch (e) {}

                // Wait to see if image challenge appears
                this.contentWindow.setTimeout(() => {
                  const result = this.detectAndHandleRecaptcha();
                  if (result.type === "image_challenge") {
                    resolve(false); // Failed, image challenge appeared
                  } else if (!result.detected) {
                    resolve(true); // Success, CAPTCHA gone
                  } else {
                    resolve(false); // Still there, failed
                  }
                }, 2000);
              }, 50 + Math.random() * 80);
            }, 200 + Math.random() * 400);
          });
        }, 500 + Math.random() * 500);
      });
    } catch (e) {
      return false;
    }
  }

  // Try to handle cookie consent banners (accept to maximize tracking/poisoning)
  handleCookieBanner() {
    // Words that indicate we should NOT click (settings/manage buttons)
    const rejectWords = [
      'manage', 'settings', 'preferences', 'customize', 'customise',
      'options', 'reject', 'decline', 'deny', 'refuse', 'necessary only',
      'essential only', 'required only', 'learn more', 'more info',
      'privacy policy', 'cookie policy', 'details'
    ];

    // Priority 1: "Accept All" / "Allow All" buttons (best match)
    const priorityTexts = [
      'accept all', 'allow all', 'accept all cookies', 'allow all cookies',
      'i accept all', 'agree to all', 'enable all', 'yes, i accept',
      'accept and continue', 'agree and continue', 'accept & continue'
    ];

    // Priority 2: Generic accept buttons
    const acceptTexts = [
      'accept', 'agree', 'allow', 'i agree', 'i accept', 'got it',
      'ok', 'okay', 'yes', 'confirm', 'understood', 'i understand'
    ];

    // Specific framework selectors (known to be accept-all buttons)
    const frameworkSelectors = [
      '#onetrust-accept-btn-handler',
      '#CybotCookiebotDialogBodyLevelButtonLevelOptinAllowAll',
      '.CybotCookiebotDialogBodyButtonAccept',
      '[data-cookiebanner="accept_button"]',
      '.cc-accept', '.cc-allow',
      '.cmplz-accept', '#cmplz-accept',
      '.qc-cmp2-summary-buttons button:first-child',
      '#sp-cc-accept',
      '.fc-cta-consent',
      '.cky-btn-accept'
    ];

    const isButtonSafe = (text, ariaLabel) => {
      const combined = (text + ' ' + ariaLabel).toLowerCase();
      for (const word of rejectWords) {
        if (combined.includes(word)) return false;
      }
      return true;
    };

    const isVisible = (el) => {
      const rect = el.getBoundingClientRect();
      return rect.width > 0 && rect.height > 0 && rect.top < this.contentWindow.innerHeight;
    };

    try {
      // First try: Known framework selectors
      for (const selector of frameworkSelectors) {
        try {
          const btn = this.document.querySelector(selector);
          if (btn && isVisible(btn)) {
            btn.click();
            return true;
          }
        } catch (e) {}
      }

      // Gather all clickable elements
      const allButtons = this.document.querySelectorAll('button, a[role="button"], [role="button"], input[type="button"], input[type="submit"]');
      let bestMatch = null;
      let bestPriority = 99;

      for (const btn of allButtons) {
        if (!isVisible(btn)) continue;

        const text = (btn.textContent || btn.innerText || '').toLowerCase().trim();
        const ariaLabel = (btn.getAttribute('aria-label') || '').toLowerCase();

        if (!isButtonSafe(text, ariaLabel)) continue;

        // Check priority 1 matches
        for (const pattern of priorityTexts) {
          if (text.includes(pattern) || ariaLabel.includes(pattern)) {
            if (bestPriority > 1) {
              bestMatch = btn;
              bestPriority = 1;
            }
            break;
          }
        }

        // Check priority 2 matches (only if no priority 1 found)
        if (bestPriority > 2) {
          for (const pattern of acceptTexts) {
            if (text === pattern || ariaLabel === pattern ||
                text.startsWith(pattern + ' ') || text.endsWith(' ' + pattern)) {
              bestMatch = btn;
              bestPriority = 2;
              break;
            }
          }
        }
      }

      if (bestMatch) {
        const text = (bestMatch.textContent || '').toLowerCase().trim().substring(0, 30);
        bestMatch.click();
        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  // Find and click a search result
  clickSearchResult(resultIndex, callback) {
    try {
      // Common selectors for search results across different engines
      const selectors = [
        // Google
        'div.g a[href]:not([href*="google"])',
        'div[data-hveid] a[href^="http"]:not([href*="google"])',
        // DuckDuckGo
        'article[data-testid="result"] a[href]',
        'a.result__a',
        // Bing
        'li.b_algo h2 a',
        'li.b_algo a[href^="http"]',
        // Brave
        'div.snippet a[href^="http"]',
        // Yahoo
        'div.dd.algo a[href^="http"]',
        // Ecosia
        'a.result__link',
        // Generic fallbacks
        'main a[href^="http"]:not([href*="search"])',
        'article a[href^="http"]',
        '#search a[href^="http"]',
        '.results a[href^="http"]'
      ];

      let links = [];

      // Try each selector until we find links
      for (const selector of selectors) {
        try {
          const found = this.document.querySelectorAll(selector);
          if (found.length > 0) {
            // Filter out unsafe and non-result links
            links = Array.from(found).filter(link => {
              const href = link.href || "";
              const text = link.textContent || "";

              // Basic checks
              if (!href.startsWith("http")) return false;
              if (href.includes("google.com/search")) return false;
              if (href.includes("bing.com/search")) return false;
              if (href.includes("duckduckgo.com")) return false;
              if (href.includes("javascript:")) return false;
              if (text.length < 5) return false;

              // Safety check
              if (!this.isUrlSafe(href)) return false;

              return true;
            });

            if (links.length > 0) break;
          }
        } catch (e) {}
      }

      if (links.length === 0) {
        callback();
        return;
      }

      // Pick target link (bounded by available links)
      const targetIndex = Math.min(resultIndex, links.length - 1);
      const targetLink = links[targetIndex];

      // Get link position
      const rect = targetLink.getBoundingClientRect();
      const linkX = rect.left + rect.width / 2 + (Math.random() - 0.5) * rect.width * 0.5;
      const linkY = rect.top + rect.height / 2 + (Math.random() - 0.5) * rect.height * 0.3;

      // Move mouse to link first
      this.simulateMouseMove(linkX, linkY, 300 + Math.random() * 200, () => {
        // Small pause before clicking (human hesitation)
        this.contentWindow.setTimeout(() => {
          // Dispatch click events
          this.dispatchMouseEvent("mousedown", linkX, linkY);
          this.contentWindow.setTimeout(() => {
            this.dispatchMouseEvent("mouseup", linkX, linkY);
            this.dispatchMouseEvent("click", linkX, linkY);

            // Actually navigate if event didn't trigger it
            this.contentWindow.setTimeout(() => {
              try {
                targetLink.click();
              } catch (e) {}
              callback();
            }, 100);
          }, 50 + Math.random() * 100);
        }, 100 + Math.random() * 200);
      });

    } catch (e) {
      callback();
    }
  }
}

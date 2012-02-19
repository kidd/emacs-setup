;; Encoding
(set-default-coding-systems 'utf-8)
(prefer-coding-system 'utf-8)

(defun fg-revert-buffer-to-enc (enc)
	(let
		((coding-system-for-read enc)
			(coding-system-for-write enc))
		(revert-buffer t t)))

(defadvice select-safe-coding-system-interactively
	(around fg-select-safe-coding-system-interactively activate) 'raw-text)

;; Font
;; Note: I always use variable-pitch font for code buffers
(when window-system
	(set-frame-font "Luxi Sans-8")
	(set-face-font 'variable-pitch "Luxi Sans-8")
	(set-face-font 'fixed-pitch "Luxi Mono-7"))

;; Time is critical
(setq-default display-time-day-and-date t
	display-time-24hr-format t
	calendar-date-style 'european
	calendar-latitude [56 50 north]
	calendar-longitude [60 35 east]
	calendar-time-display-form ; "13:05 (YEKST)"
		'(24-hours ":" minutes
			(if time-zone " (") time-zone (if time-zone ")")))
(display-time)

;; Smooth scrolling
(setq-default
	scroll-preserve-screen-position t ; keep vertical pos
	line-move-visual t ; keep horizontal pos
	scroll-conservatively 5
	isearch-allow-scroll t) ; alas, it doesn't work for custom PgUp/PgDn, TODO: extend

;; Assorted minor tweaks
(setq-default
	inhibit-startup-screen t
	frame-title-format "emacs - %b" ; format the title-bar to include buffer name
	show-paren-style 'mixed ; mark the area in the direction of far parenthesis
	visible-bell t) ; flash on weird stuff

;; Cosmetic minor modes
(global-font-lock-mode t) ; syntax highlighting (funny name for it)
(show-paren-mode t) ; show matching parenthesis
(column-number-mode t) ; column numbers at the bottom
(display-battery-mode t) ; show the death clock
(which-function-mode t) ; show which function pointer is in

;; Rodent banishment (if any)
(when (and (display-mouse-p) (require 'avoid))
	(mouse-avoidance-mode 'exile))

;; Character display tweaks
(or standard-display-table (setq standard-display-table (make-display-table)))
;; Display page delimiter ^L as a horizontal line (plus "^L")
(aset standard-display-table ?\f (vconcat (make-vector 64 ?-) "^L"))
;; Tab indentation guides
(aset standard-display-table ?\t (vconcat "˙ "))


;; Local modes
(load-library-safe "develock-py")
(autoload 'rainbow-mode
	"rainbow-mode" "Color code highlighting mode" t)
(autoload 'yaml-mode
	"yaml-mode" "Mode for editing YAML files" t)
(autoload 'go-mode
	"go-mode" "Mode for editing Go sources" t)

;; Nice, but crashes current emacs (24.0.50.1)
;; (autoload 'lambda-mode
;; 	"lambda-mode" "Minor mode to display 'lambda' as a greek letter" t)
;; (add-hook 'python-mode-hook #'(lambda () (lambda-mode t)))


;; Crosshair highlighting modes
;; (load-library-safe "column-marker")
(when
	(and
		(load-library-safe "vline")
		(load-library-safe "col-highlight"))

	(setq-default
		vline-use-timer t
		vline-idle-time 0.1
		col-highlight-vline-face-flag nil
		col-highlight-period 2)

	(defun vline-post-command-hook ()
		(when (and vline-mode (not (minibufferp))) (flash-column-highlight)))
	(defalias 'vline-timer-callback 'vline-post-command-hook)

	(defvar col-highlight-flash-timer (timer-create)
		"Timer for an active column highlihting in `vline-mode'.")
	(defadvice col-highlight-flash
		(around fg-col-highlight-flash-cleanup activate)
		"Flash current column, cancelling previous flash-timer,
	stored in `col-highlight-flash-timer'.
	See `col-highlight-flash-set' for details."
		(cancel-timer col-highlight-flash-timer)
		(setq col-highlight-flash-timer ad-do-it)))


;; Ibuffer tweaks
(setq-default
	ibuffer-formats
		'((mark modified read-only
			" " (name 30 30 :left :elide)
			" " (size 9 -1 :right)
			" " (mode 16 16 :left :elide)
			" " filename-and-process)
		(mark
			" " (name 16 -1)
			" " filename)))




;; Mask for X (inits are bg-agnostic colors)
(defvar fg-color-fg-core)
(defvar fg-color-bg-core)
(defvar fg-color-bg-hl)
(defvar fg-color-fg-modeline "firebrick")
(defvar fg-color-spell-dupe "Gold3")
(defvar fg-color-spell-err "OrangeRed")
(defvar fg-color-irrelevant "medium sea green")
(defvar fg-color-irrelevant-xtra "sea green")
(defvar fg-color-comment "DeepSkyBlue4")
(defvar fg-color-kw "dark green")
(defvar fg-color-func "gold")
(defvar fg-color-func-modeline fg-color-func)
(defvar fg-color-type "dark slate gray")
(defvar fg-color-key "MistyRose4")
(defvar fg-color-var "Coral")
(defvar fg-color-static "olive drab")

(defun fg-masq-x ()
	"CSS-like binding."
	(custom-set-faces
		`(default
			((,(and
					(boundp 'fg-color-fg-core)
					(boundp 'fg-color-bg-core))
				(:foreground ,fg-color-fg-core
					:background ,fg-color-bg-core))))
		;; Py
		`(py-builtins-face ((t (:foreground ,fg-color-kw))))
		`(py-decorators-face ((t (:foreground ,fg-color-kw))))
		`(py-pseudo-keyword-face ((t (:foreground ,fg-color-kw))))
		;; FlySpell
		`(flyspell-duplicate ((t (:foreground ,fg-color-spell-dupe :underline t :weight normal))))
		`(flyspell-incorrect ((t (:foreground ,fg-color-spell-err :underline t :weight normal))))
		;; Vline
		`(vline ((t (:background ,fg-color-bg-hl))))
		`(vline-visual ((t (:background ,fg-color-bg-hl))))
		;; Jabber
		`(jabber-title-large ((t (:weight bold :height 1.5))))
		`(jabber-title-medium ((t (:weight bold :height 1.2))))
		`(jabber-roster-user-online ((t (:foreground ,fg-color-fg-core :slant normal :weight bold))))
		`(jabber-roster-user-away ((t (:foreground ,fg-color-irrelevant :slant italic :weight normal))))
		`(jabber-roster-user-xa ((t (:foreground ,fg-color-irrelevant-xtra :slant italic :weight normal))))
		;; ERC
		`(erc-timestamp-face ((t (:foreground ,fg-color-comment :weight normal))))
		`(erc-keyword-face ((t (:foreground ,fg-color-kw :weight bold))))
		`(erc-current-nick-face ((t (:foreground ,fg-color-kw :weight bold))))
		`(erc-notice-face ((t (:foreground ,fg-color-fg-modeline))))
		`(erc-prompt-face ((t (:foreground ,fg-color-fg-core :background nil))))
		;; Newsticker
		`(newsticker-treeview-face ((t (:foreground ,fg-color-fg-core))))
		`(newsticker-treeview-immortal-face
			((t (:inherit newsticker-treeview-face :slant italic :weight bold))))
		`(newsticker-treeview-selection-face ((t (:background ,fg-color-bg-hl))))
		;; Misc
		`(yaml-tab-face ((t (:inherit default :background ,fg-color-bg-hl))))
		`(w3m-current-anchor ((t (:inherit w3m-anchor :underline t))))
		`(which-func ((t
			(:inherit font-lock-function-name-face
				:foreground ,fg-color-func-modeline t))))
		;; Defaults
		`(font-lock-comment-face ((t (:foreground ,fg-color-comment))))
		`(font-lock-function-name-face ((t (:foreground ,fg-color-func))))
		`(font-lock-keyword-face ((t (:foreground ,fg-color-kw))))
		`(font-lock-type-face ((t (:foreground ,fg-color-type))))
		`(font-lock-variable-name-face ((t (:foreground ,fg-color-var))))
		`(font-lock-builtin-face ((t (:foreground ,fg-color-key))))
		`(font-lock-string-face ((t (:foreground ,fg-color-static))))
		`(menu
			((,(and window-system (boundp 'fg-color-fg-core))
				(:background "light slate gray"
					:foreground ,fg-color-fg-core
					:box (:line-width 2 :color "grey75" :style released-button)))))
		`(mode-line ((t (:foreground "black" :background "light slate gray")))))
	(tool-bar-mode -1)
	(scroll-bar-mode -1)
	(when (boundp 'fg-color-fg-core)
		(set-cursor-color fg-color-fg-core)
		(set-foreground-color fg-color-fg-core)
		(setq-default term-default-fg-color fg-color-fg-core))
	(when (boundp 'fg-color-bg-core)
		(set-background-color fg-color-bg-core)
		(setq-default term-default-bg-color fg-color-bg-core)))

;;;; Rainbow mode seem to need a kick here, not sure why
;; (progn (rainbow-mode t) (rainbow-turn-on))

(defun fg-masq-x-dark ()
	"Translucent text on dark background."
	(interactive)
	(let*
		((fg-color-fg-core "#6ad468")
			(fg-color-bg-core "#101c10")
			(fg-color-bg-hl "DarkGreen")
			(fg-color-key "MistyRose2")
			(fg-color-kw "springgreen")
			(fg-color-type "SlateGrey")
			(fg-color-func-modeline "yellow")
			(fg-color-fg-modeline "tomato")
			(fg-color-comment "SteelBlue1"))
		(customize-set-variable
			'frame-background-mode 'dark)
		(fg-masq-x)))

(defun fg-masq-x-light ()
	"Black text on white background."
	(interactive)
	(let*
		((fg-color-fg-core "black")
			(fg-color-bg-core "white")
			(fg-color-bg-hl "lavender blush")
			(fg-color-func "saddle brown")
			(fg-color-func-modeline "red4")
			(fg-color-var "IndianRed4"))
		(customize-set-variable
			'frame-background-mode 'light)
		(fg-masq-x)))

(defun fg-masq-x-pitch ()
	"Toggle fixed/variable pitch in current buffer."
	(interactive)
	(if
		(and (boundp 'buffer-face-mode-face) buffer-face-mode-face)
		(setq buffer-face-mode-face (buffer-face-set nil))
		(buffer-face-set 'fixed-pitch)))


;; Mask 4 no-X, uniform static dark-only
(defun fg-masq-nox ()
	(interactive)
	(custom-set-faces
		'(default ((t (:foreground "wheat" :background "black"))))
		'(font-lock-comment-face ((t (:foreground "magenta"))))
		'(font-lock-function-name-face ((t (:foreground "red"))))
		'(font-lock-keyword-face ((t (:foreground "green"))))
		'(font-lock-type-face ((t (:foreground "blue"))))
		'(font-lock-string-face ((t (:foreground "cyan"))))
		'(font-lock-variable-name-face ((t (:foreground "blue"))))
		'(menu
			((((type x-toolkit))
				(:background "white"
					:foreground "black"
					:box (:line-width 2 :color "grey75" :style released-button)))))
		'(modeline ((t (:foreground "blue" :background "white")))))
	(set-cursor-color "blue")
	(set-foreground-color "white")
	(set-background-color "black")
	(set-face-foreground 'default "white")
	(set-face-background 'default "black"))


;; Lisp highlights
(when
	(require 'highlight-parentheses nil t)
	(setq-default hl-paren-colors
		'("red1" "OrangeRed1" "orange1" "DarkOrange1")))


;; Set masq depending on time-of-the-day
(require 'solar)
(defvar fg-sunset-timer)
(defvar fg-sunrise-timer)

(defun fg-smart-lookz (&optional frame)
	"Automatically switch to dark background after sunset
and to light background after sunrise.
Note that `calendar-latitude' and `calendar-longitude'
should be set before calling the `solar-sunrise-sunset'."
	(interactive)
	(if (and calendar-latitude calendar-longitude calendar-time-zone)
		(let*
			((l (solar-sunrise-sunset (calendar-current-date)))
				(sunrise-string (apply 'solar-time-string (car l)))
				(sunset-string (apply 'solar-time-string (car (cdr l))))
				(current-time-string (format-time-string "%H:%M")))
			(if
				(or (string-lessp current-time-string sunrise-string)
					(string-lessp sunset-string current-time-string))
				(fg-masq-x-dark)
				(fg-masq-x-light))
			(when (and (boundp 'fg-sunset-timer) (timerp fg-sunset-timer))
				(cancel-timer fg-sunset-timer))
			(when (and (boundp 'fg-sunrise-timer) (timerp fg-sunrise-timer))
				(cancel-timer fg-sunrise-timer))
			(setq fg-sunset-timer (run-at-time sunset-string (* 60 60 24) 'fg-masq-x-dark))
			(setq fg-sunrise-timer (run-at-time sunrise-string (* 60 60 24) 'fg-masq-x-light)))))

;; Masquerade!
(if window-system
	(progn
		(fg-smart-lookz)
		(add-to-list 'after-make-frame-functions 'fg-smart-lookz))
	(fg-masq-nox)) ; time-of-the-day independent, since terms should be plain black



;; Auto lookz switching
(defun fg-hook-set-lookz ()
	"Enable stuff like trailing spacez or fixed-width face."
	(if buffer-file-name ; nil for system buffers and terminals
		(setq show-trailing-whitespace t)
		(when
			(memq major-mode
				'(term-mode jabber-roster-mode ibuffer-mode
					gnus-group-mode gnus-summary-mode))
			(buffer-face-set 'fixed-pitch))))

(add-hook 'find-file-hook 'fg-hook-set-lookz)
(add-hook 'ibuffer-hook 'fg-hook-set-lookz)
(add-hook 'after-change-major-mode-hook 'fg-hook-set-lookz)

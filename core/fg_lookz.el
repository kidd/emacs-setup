;; Encoding
(set-default-coding-systems 'utf-8)

;; Font
(set-frame-font "Luxi Sans-8")
(set-face-font 'variable-pitch "Luxi Sans-8")
(set-face-font 'fixed-pitch "Luxi Mono-7")

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
(show-paren-mode) ; show matching parenthesis
(column-number-mode) ; column numbers at the bottom
(display-battery-mode) ; show the death clock

;; Rodent banishment (if any)
(when (and (display-mouse-p) (require 'avoid))
  (mouse-avoidance-mode 'animate))

;; Display page delimiter ^L as a horizontal line (plus "^L")
(or standard-display-table (setq standard-display-table (make-display-table)))
(aset standard-display-table ?\f (vconcat (make-vector 64 ?-) "^L"))


;; TODO: M4 keyz for per-buffer mono/sans font switching (see buffer-face-set)
;; TODO: Pull colors from this stuff:
; (color-theme-initialize)
; (color-theme-mods)


;; Mask for X (inits are bg-agnostic colors)
(defvar fg-color-fg-core)
(defvar fg-color-bg-core)
(defvar fg-color-spell-dupe "Gold3")
(defvar fg-color-spell-err "OrangeRed")
(defvar fg-color-comment "DeepSkyBlue4")
(defvar fg-color-kw "springgreen")
(defvar fg-color-func "gold")
(defvar fg-color-type "dark slate gray")
(defvar fg-color-key "MistyRose4")
(defvar fg-color-var "Coral")
(defvar fg-color-static "olive drab")

(defun fg-masq-x ()
	"Css-like binding."
	(custom-set-faces
		`(default
			((,(and
					(boundp 'fg-color-fg-core)
					(boundp 'fg-color-bg-core))
				(:foreground ,fg-color-fg-core
					:background ,fg-color-bg-core))))
		`(flyspell-duplicate ((t (:foreground ,fg-color-spell-dupe :underline t :weight normal))))
		`(flyspell-incorrect ((t (:foreground ,fg-color-spell-err :underline t :weight normal))))
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

(defun fg-masq-x-dark ()
	"Translucent text on dark background."
	(interactive)
	(let*
		((fg-color-fg-core "#6ad468")
		 (fg-color-bg-core "#101c10")
		 (fg-color-key "MistyRose2")
		 (fg-color-comment "SteelBlue1"))
		(fg-masq-x)))

(defun fg-masq-x-light ()
	"Black text on white background."
	(interactive)
	(let*
		((fg-color-fg-core "black")
		 (fg-color-bg-core "white")
		 (fg-color-kw "dark green")
		 (fg-color-func "saddle brown")
		 (fg-color-var "IndianRed4"))
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

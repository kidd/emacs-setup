(defvar fg-path
	(expand-file-name "~/.emacs.d")
	"root for all emacs-related crap")


;; Extend include path
(add-to-list 'load-path fg-path)
(add-to-list 'load-path (concat fg-path "/extz"))
(add-to-list 'load-path (concat fg-path "/core"))


;; Basic loading macros
(defmacro load-library-safe (name &optional msg)
	"Condition-wrapped inclusion of unsafe el code"
	`(condition-case err
		(load-library ,name)
		(error (progn (message ,(or msg "Failed to load %s: %s") ,name err) nil))))


;; Auth data
(save-excursion
	(find-file (concat fg-path "/auth.el.gpg"))
	(eval-buffer)
	(kill-buffer))


;; Temp/spool path init
(setq-default
	temporary-file-directory
		(concat fg-path "/tmp/"))
(make-directory temporary-file-directory t)
(set-file-modes temporary-file-directory #o700)


;; Basic / custom includes
(load-library "fg_lisp") ; core language tweaks, should be first
(load-library "fg_macroz")
(load-library "fg_lookz")
(load-library "fg_sec")

; External and non-critical
;; (load-library "fg_shell")
(autoload 'multi-term "fg_shell" nil t)
(dolist
	(sym '(fg-jabber-activity-reset jabber-activity-switch-to
		jabber-connect jabber-connect-all))
	(autoload sym "fg_jabbra" nil t))
(dolist
	(sym
		'(emms emms-stop emms-pause emms-shuffle
			emms-next emms-previous emms-add-directory-tree
			emms-playlist emms-add-playlist emms-playlist-save
			emms-playlist-mode-clear fg-emms-notify))
	(autoload sym "fg_emms" nil t))
(dolist
	(sym
		'(erc-bol fg-erc fg-erc-track-reset erc-track-switch-buffer))
	(autoload sym "fg_erc" nil t))
(autoload 'gnus "fg_gnus" nil t)
(autoload 'w3m-region "fg_w3m" nil t)
(dolist
	(sym '(newsticker-start newsticker-show-news))
	(autoload sym "fg_newsticker" nil t))

;; Compositing stuff
(load-library "fg_style")
(load-library "fg_keyz") ; must be the last one


;; Release auth data sources
;; (require 'obarray-fns)
;; (mapc 'makunbound
;; 	(find-symbols (lambda (sym) (string-prefix-p "fg-auth-" (symbol-name sym)))))


;; Adjust tmp path and use it for all backup and autosave files
(require 'saveplace)
(desktop-save-mode)
(setq-default
	; autosave
	auto-save-list-file-prefix
		(concat temporary-file-directory "bakz-")
	auto-save-file-name-transforms
		(list (cons ".*" (list temporary-file-directory t)))
	; backups
	backup-directory-alist
		(list (cons "." temporary-file-directory))
	backup-by-copying t
	delete-old-versions t
	version-control t
	kept-new-versions 6
	kept-old-versions 2
	; save-place-in-file
	save-place t
	save-place-file
		(concat temporary-file-directory "placez")
	; recentf mode
	recentf-max-saved-items 256
	recentf-max-menu-items 10
	recentf-menu-filter 'recentf-arrange-by-rule
	recentf-save-file
		(concat temporary-file-directory "recentf")
	recentf-arrange-rules
		`(("py (%d)" ".\\.py\\'")
			("php (%d)" ".\\.php[0-9]?\\'")
			("sh (%d)" ".\\.sh\\'")
			("conf (%d)"
				,(concat ".\\.\\(c\\(onf\\|fg\\|f\\)\\|\\(ya?ml\\)\\)"
					"\\(\\.\\(sample\\|example\\|dist\\|documented\\)\\)?\\'"))
			("perl (%d)" ".\\.pl[0-9]?\\'")
			("web/tpl (%d)" ".\\.\\(html\\|css\\|htm\\|js\\|tpl\\)\\'")
			("sql (%d)" ".\\.sql\\'")
			("C (%d)" ".\\.\\(c\\|h\\)\\'")
			("(e)lisp (%d)" ".\\.\\(el\\|cl\\|lisp\\)\\'")
			("ebuild (%d)" ".\\.\\(eclass\\|ebuild\\|exlib\\|exheres-0\\)\\'"))
	; buffer list storage
	desktop-dirname temporary-file-directory
	desktop-path (list temporary-file-directory)
	desktop-base-file-name "bufferz"
	desktop-load-locked-desktop t ; bogus check
	desktop-save t)

;; Obligatory timer to save desktop every now and then - crashes do happen
(defvar fg-desktop-autosave-timer
	(run-at-time t 600 'desktop-save-in-desktop-dir) ;; 10 min
	"Repetitive timer calling `desktop-save-in-desktop-dir'.")

;; Default behavior tweaks / modes
(fset 'yes-or-no-p 'y-or-n-p) ; use y or n instead of yes or no

(delete-selection-mode t) ; delete active selection w/ transient-mode
(mouse-wheel-mode t) ; ...in case I plug the rodent in
(auto-image-file-mode t)
(recentf-mode t) ; TODO: bind keys to use it

(setq-default
	next-line-add-newlines nil ; don't move past eof
	x-select-enable-clipboard t ; shared clipboard should always be enabled
	compare-windows-sync t ; advance point in both buffers on comparison
	; find-file tweaks
	find-file-run-dired nil
	find-file-visit-truename t
	find-file-existing-other-name t)

;; TLS, used for jabber and erc
(setq-default
	starttls-use-gnutls t
	starttls-extra-arguments '("--insecure") ; for gnutls-cli: skip certificate validation, for gtalk w/ CN:gmail.com
	password-cache-expiry nil)
;; doc-view setup
(setq-default doc-view-continuous t)
;; Notifications
;; TODO: check for notification-daemon type here
(setq-default fg-notify-never-escape t)


;; Auto-mode tweaks
(delq (assoc-string "\\.inc\\'" auto-mode-alist) auto-mode-alist)
(nconc auto-mode-alist
	'((".\\.\\(eclass\\|ebuild\\|exlib\\|exheres-0\\)\\'" . sh-mode)
		("\\.jl\\'" . lisp-mode) ("\\.rkt\\'" . scheme-mode) ("\\.vol\\'" . conf-mode)))

;; Vars not declared "safe" by modes, invoking hack-local-variables-confirm
;;  retarded  way to expand this list is "!" on confirm and fishing them from custom
(setq-default
	safe-local-variable-values
		'((test-case-name . twisted\.test\.test_factories\,twisted\.internet\.test\.test_protocol)))


;; Misc hooks
(defadvice kill-buffer (around fg-kill-buffer-persistent-scratch activate)
	"Bury *scratch* buffer instead of killing it."
	(if
		(equal (or (ad-get-arg 0) (buffer-name)) "*scratch*")
		(bury-buffer)
		ad-do-it))

(defadvice save-buffers-kill-emacs (around no-query-kill-emacs activate)
	"Prevent annoying \"Active processes exist\" query when killing Emacs."
	(flet ((process-list ())) ad-do-it))


;; Emacs server (client is bound to zsh ec/ee aliases)
(server-start)

;; Starting layout setup
(split-window-horizontally)

(unless
	(or
		(not (eq window-system 'x))
		(eq (frame-parameter nil 'fullscreen) 'maximized))
	(set-frame-parameter nil 'fullscreen 'maximized))

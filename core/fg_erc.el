(require 'erc)
(require 'tls)


(defun fg-erc ()
	"Connect to IRC."
	(interactive)
	(erc-tls :server "irc.fraggod.net" :port 6667 :nick "freenode"
		:password fg-auth-erc-password-freenode :full-name "Mike Kazantsev")
	(erc-tls :server "irc.fraggod.net" :port 6667 :nick "quakenet"
		:password fg-auth-erc-password-quakenet :full-name "Mike Kazantsev")
	(erc-tls :server "irc.fraggod.net" :port 6667 :nick "bitlbee"
		:password fg-auth-erc-password-bitlbee :full-name "Mike Kazantsev"))


;; Modules
(setq
	;; Fill-mode doesn't play nice with variable pitch
	;; Note that it can't seem to be disabled globally via erc-fill-mode var
	erc-modules (delq 'fill erc-modules)
	;; These are useless and only hinder ops like copy-paste
	erc-modules (delq 'button erc-modules)
	;; Disabled by default, but I'd hate to bump into these
	erc-modules (delq 'smiley erc-modules)
	erc-modules (delq 'sound erc-modules))

(add-to-list 'erc-modules 'log)
(add-to-list 'erc-modules 'truncate)
(add-to-list 'erc-modules 'autoaway)
(add-to-list 'erc-modules 'dcc)


;; TODO: should be configured first
;; (add-to-list 'erc-modules 'notify)
;; TODO: check these out
;; (add-to-list 'erc-modules 'keep-place)


(setq-default
	erc-server "irc.fraggod.net"

	;; erc-port 6667
	;; erc-nick '("freenode")

	erc-user-full-name "Mike Kazantsev"
	erc-email-userid "mike_dropthis_kazantsev@andthis.fraggod.net"

	erc-prompt
		(lambda () (erc-propertize (concat "~erc/"
			(if (and (boundp 'erc-default-recipients) (erc-default-target))
				(erc-default-target) "limbo") "%")
			'read-only t 'rear-nonsticky t 'front-nonsticky t 'intangible t))
	erc-minibuffer-notice t

	erc-quit-reason 'erc-quit-reason-various
	erc-quit-reason-various-alist
		'(("home" "Heading home...")
			("" "o//"))
	erc-part-reason 'erc-part-reason-various
	erc-part-reason-various-alist erc-quit-reason-various-alist

	erc-anonymous-login nil

	erc-encoding-coding-alist
		'(("#debian-ru" . cyrillic-koi8))

	;; Custom log-friendly datestamping, includes erc-insert-timestamp-left
	;; Note that default erc-insert-timestamp-function is "...-right"
	erc-insert-timestamp-function 'fg-erc-timestamp-with-datestamps
	erc-datestamp-format " === [%Y-%m-%d %a] ===\n"

	erc-timestamp-only-if-changed-flag nil
	erc-timestamp-format "[%H:%M:%S]"
	erc-timestamp-format-left (concat erc-timestamp-format " ")
	erc-timestamp-format-right erc-timestamp-format

	erc-pcomplete-nick-postfix ","
	erc-pcomplete-order-nickname-completions t

	erc-log-insert-log-on-open nil ;; very messy
	erc-log-channels-directory (concat fg-path "/tmp/erc")
	erc-max-buffer-size 30000
	erc-max-buffer-size-to-act 50000 ;; for custom truncation, not used by default ERC

	erc-track-showcount t
	erc-track-exclude-types ;; join/part/nickserv + all the crap on connect
		'("JOIN" "NICK" "PART" "QUIT" "MODE" "324" "329" "332" "333" "353" "477")
	erc-track-enable-keybindings nil

	erc-hide-list '("JOIN" "PART" "QUIT") ;; careful, these are completely ignored
	erc-ignore-list
		'("^zebrapig!~eir@.*" "^CIA-[[:digit:]]+!~?[cC][iI][aA]@.*" "^PLT_Notify!.*")

	erc-server-auto-reconnect t
	erc-server-reconnect-attempts t
	erc-server-reconnect-timeout 10

	erc-pals nil
	erc-fools nil
	erc-notify-list nil

	erc-notify-signon-hook nil
	erc-notify-signoff-hook nil)

;; Extra: block msgs by content
(defcustom fg-erc-msg-block ()
	"Regexps to match to-be-ignored msgs."
	:group 'erc :type '(repeat regexp))

;; Autoaway is only useful when based on X idle time, not emacs/irc
(when (eq window-system 'x)
	(setq-default
		erc-auto-set-away nil
		erc-autoaway-message "AFK (%is), later..."
		erc-autoaway-idle-method 'x
		erc-autoaway-idle-seconds (* 30 60)))



;; Custom timestamping
(make-variable-buffer-local
	(defvar erc-last-datestamp nil))

(defun fg-erc-timestamp-with-datestamps (string)
	"Insert date as well as timestamp if it changes between events.
Makes ERC buffers a bit more log-friendly."
	(erc-insert-timestamp-left string)
	(let ((datestamp (erc-format-timestamp (current-time) erc-datestamp-format)))
		(unless (string= datestamp erc-last-datestamp)
			(erc-insert-timestamp-left datestamp)
			(setq erc-last-datestamp datestamp))))


;; Custom buffer truncation
(defun erc-truncate-buffer ()
	"Truncates the current buffer to `erc-max-buffer-size'.
Not on every new line (as in vanilla version), but only if
buffer is larger than `erc-max-buffer-size-to-act'.
Appending to logs is handled in `erc-truncate-buffer-to-size'.
Meant to be used in hooks, like `erc-insert-post-hook'."
	(interactive)
	(let ((buffer (current-buffer)))
		(when (> (buffer-size buffer) erc-max-buffer-size-to-act)
			(erc-truncate-buffer-to-size erc-max-buffer-size buffer))))

(defun erc-cmd-REIGNORE ()
	"Drop local changes to ignore-list (or apply global changes)."
	(erc-display-line
		(erc-make-notice "Reset ignore-list to a default (global) state")
		'active)
	(erc-with-server-buffer (kill-local-variable 'erc-ignore-list))
	(erc-cmd-IGNORE))

;; Clears out annoying erc-track-mode stuff when I don't care
(defun fg-erc-track-reset ()
	(interactive)
	(setq erc-modified-channels-alist nil)
	(erc-modified-channels-display)
	(force-mode-line-update t))


;; New message notification hook
(defun fg-erc-notify (text)
	(let*
		((buffer (current-buffer))
			(channel
				(or (erc-default-target) (buffer-name buffer))))
		(when
			(and (buffer-live-p buffer)
				(or
					(not (erc-buffer-visible buffer))
					(not (fg-xactive-check))))
			(fg-notify (format "erc: %s" channel) text :pixmap "erc" :strip t))))
(add-hook 'erc-insert-pre-hook 'fg-erc-notify)


;; Message content filter
(defun fg-erc-msg-content-filter (msg)
	(when (erc-list-match fg-erc-msg-block msg)
		(set 'erc-insert-this nil)))
(add-hook 'erc-insert-pre-hook 'fg-erc-msg-content-filter)


;; Some quick fail right after connection (like "password incorrect")
;;  will trigger infinite zero-delay reconnection loop by default.
;; This code fixes the problem, raising error for too fast erc-server-reconnect calls
(defvar fg-erc-reconnect-time 0
	"Timestamp of the last `erc-server-reconnect' run.
Prevents idiotic zero-delay reconnect loops from hanging emacs.")

(defadvice erc-server-reconnect (around fg-erc-server-reconnect-delay activate)
	(let*
		((time (float-time))
			(delay (- erc-server-reconnect-timeout (- time fg-erc-reconnect-time))))
		(if (> delay 0)
			(progn
				(message "Skipping erc-server-reconnect (for %d more secs)" delay)
				(error "erc-server-reconnect loop detected"))
			(setq fg-erc-reconnect-time time)
			ad-do-it)))


;; Away timer, based on X idle time, not emacs or irc
;; TODO: finish and test this

(defvar fg-erc-autoaway-idletimer-x nil
	"X idletimer. Used when `erc-autoaway-idle-method' is set to 'x.")
;; TODO: there must be some event for "user activity" in emacs to replace this timer
(defvar fg-erc-autoaway-check-interval 120
	"Interval to check whether user has become active.")

(defun fg-erc-autoaway-check-away ()
	"Check if away mode need to be set or reset and
establish a timer for a next check, if there's any need for it."
	;; Whole (when ...) wrap is based on the assumption that
	;; erc-server-buffer's won't spawn w/o resetting (run-with-idle-timer ...) call
	(when (erc-autoaway-some-server-buffer)
		(let ((idle-time (/ (fg-idle-time) 1000.0)))
			(if (and erc-away erc-autoaway-caused-away) ;; check whether away should be set or reset
				(if (< idle-time erc-autoaway-idle-seconds)
					(erc-cmd-GAWAY "") ;; erc-autoaway-reset-indicators should be called via erc-server-305-functions
					(fg-erc-autoaway-x-idletimer :delay fg-erc-autoaway-check-interval))
				(when erc-autoaway-caused-away
					(if (>= idle-time erc-autoaway-idle-seconds)
						(progn
							(erc-display-message nil 'notice nil
								(format "Setting automatically away (threshold: %i)" erc-autoaway-idle-seconds))
							(erc-autoaway-set-away idle-time t) ;; erc-server-buffer presence already checked
							(fg-erc-autoaway-x-idletimer :delay fg-erc-autoaway-check-interval))
						(fg-erc-autoaway-x-idletimer :idle-time idle-time)))))))

(defun* fg-erc-autoaway-x-idletimer (&key delay idle-time)
	"Reestablish the X idletimer."
	(interactive)
	(when fg-erc-autoaway-idletimer-x
		(erc-cancel-timer fg-erc-autoaway-idletimer-x))
	(unless delay
		(unless idle-time
			(setq idle-time (/ (fg-idle-time) 1000.0)))
		(setq delay (max 1 (+ (- erc-autoaway-idle-seconds idle-time) 10))))
	(setq fg-erc-autoaway-idletimer-x
		(run-at-time (format "%i sec" delay) nil 'fg-erc-autoaway-check-away)))

(defun erc-autoaway-reestablish-idletimer ()
	"Reestablish the Emacs idletimer (which also triggers X idletimer).
If `erc-autoaway-idle-method' is 'emacs, you must call this
function each time you change `erc-autoaway-idle-seconds'."
	;; Used on assumption that emacs-idle-time is greater or equal to x-idle-time.
	(interactive)
	(when erc-autoaway-idletimer
		(erc-cancel-timer erc-autoaway-idletimer))
	(setq erc-autoaway-idletimer
		(if (eq window-system 'x)
			(run-with-idle-timer erc-autoaway-idle-seconds t
				'fg-erc-autoaway-x-idletimer :idle-time erc-autoaway-idle-seconds)
			(run-with-idle-timer erc-autoaway-idle-seconds t
				'erc-autoaway-set-away erc-autoaway-idle-seconds))))

(when (and erc-auto-set-away (eq erc-autoaway-idle-method 'x))
	(erc-autoaway-reestablish-idletimer) ;; definition should've been updated
	(remove-hook 'erc-timer-hook 'erc-autoaway-possibly-set-away)) ;; based on emacs-idle-time, bogus


;; DCC - ultimate one-liner fix for 'DCC SEND "file name with spaces" ...' issue
;; Comes in handy in #bookz@undernet.
;; Sent cleaner [PATCH] upstream (see erc-discuss 2011-10-29).
(defconst erc-dcc-ctcp-query-send-regexp
	"^DCC SEND \"?\\(.*+?\\)\"? \\([0-9]+\\) \\([0-9]+\\) *\\([0-9]*\\) *$")


;; Create paths
(make-directory erc-log-channels-directory t)

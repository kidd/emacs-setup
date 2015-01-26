(require 'erc)
(require 'tls)


(defvar fg-erc-connect-last 0
	"Timestamp when last irc net was connected,
to make sure there are delays between these.
Used from `fg-erc'.")

(defvar fg-erc-connect-lag 10
	"Timeout for irc connection to complete.
Used for misc sloppy time matching purposes as well.")

(defun fg-erc ()
	"Connect to IRC servers.
Uses up all the connection commands destructively,
so can only be called once.
Enables notifications only after connecting to the last server,
to avoid spamming them with MOTD entries and notices."
	(interactive)
	(when fg-erc-links

		(run-with-timer (* fg-erc-connect-lag 2) nil
			(lambda ()
				"Post-connected-to-all hook."
				(add-hook 'erc-insert-pre-hook 'fg-erc-notify)
				(setq fg-erc-track-save-timer
					(run-with-timer fg-erc-track-save-interval
						fg-erc-track-save-interval 'fg-erc-track-save))))

		(fg-erc-connect-loop)))

(defun fg-erc-connect-loop (&rest ignored)
	(if (not fg-erc-links)
		(remove-hook 'erc-after-connect 'fg-erc-connect-loop)
		(add-hook 'erc-after-connect 'fg-erc-connect-loop)
		(run-with-timer (* 1.5 fg-erc-connect-lag) nil 'fg-erc-connect-next t)
		(run-with-timer 1 nil 'fg-erc-connect-next)))

(defun fg-erc-connect-next (&optional timeout-hook)
	(let
		((link (car fg-erc-links))
			(skip
				(when timeout-hook
					(< (- (float-time) fg-erc-connect-last) fg-erc-connect-lag))))
		(when (and link (not skip))
			(setq
				fg-erc-links (cdr fg-erc-links)
				fg-erc-connect-last (float-time))
			(apply (car link) (cdr link)))))


;; erc-track state preservation feature
;; Idea is to have list of unread stuff dumped to some file on timer,
;;  so that sudden system crash or emacs kill won't loose any important msgs
;; TODO: auto-restore this into erc-modified-channels-alist maybe?

(defcustom fg-erc-track-save-path (concat fg-path "/tmp/erc-track-state")
	"Path to save `erc-modified-channels-alist' state to."
	:group 'erc-track :type 'string)

(defcustom fg-erc-track-save-interval 400
	"Interval between saving `erc-modified-channels-alist' state,
so that it can be preserved in an event of emacs getting killed."
	:group 'erc-track :type 'number)

(defcustom fg-erc-track-save-copies 4
	"Copies of old `erc-modified-channels-alist' states to keep."
	:group 'erc-track :type 'number)

(defvar fg-erc-track-save-timer nil
	"Repeating timer for `fg-erc-track-save'.")

(defvar fg-erc-track-save-seed (format "%d" (random))
	"Seed for identifying emacs instance for `fg-erc-track-save'.")

(defun fg-erc-track-save-dump ()
	(apply 'fg-string-join "\n"
		(append
			(list
				fg-erc-track-save-seed
				""
				(format "%s (%.0f)" (fg-time-string) (float-time))
				"")
			(let (res)
				(nreverse
					(dolist (el erc-modified-channels-alist res)
						(push (format "%s %d"
							(buffer-name (car el)) (cadr el)) res))))
			(list ""))))

(defun fg-erc-track-save-bak-name (n)
	(format "%s.%d" fg-erc-track-save-path n))

(defun fg-erc-track-save ()
	"Save `erc-modified-channels-alist' to a file,
making sure to preserve a copies from a few last runs."
	(let
		((curr-lines
			(with-temp-buffer
				;; Check if current seed matches the one in the file
				(condition-case ex
					(progn
						(insert-file-contents fg-erc-track-save-path)
						(split-string (buffer-string) "\n" t))
					('error nil)))))
		;; Rotate backup copies, if any
		(when
			(not (string= (first curr-lines) fg-erc-track-save-seed))
			(let (fns)
				(dotimes (n (- fg-erc-track-save-copies 1) fns)
					(multiple-value-bind (src dst)
						(mapcar 'fg-erc-track-save-bak-name
							(list
								(- fg-erc-track-save-copies n 1)
								(- fg-erc-track-save-copies n)))
						(when (file-exists-p src) (rename-file src dst t)))))
			(when (file-exists-p fg-erc-track-save-path)
				(rename-file fg-erc-track-save-path
					(fg-erc-track-save-bak-name 1) t)))
		;; Save
		(with-temp-buffer
			(insert (fg-erc-track-save-dump))
			(write-region (point-min) (point-max) fg-erc-track-save-path))))


;; Local feature: blocking msgs by a bunch of props

(defcustom fg-erc-msg-block ()
	"Regexps to match to-be-ignored msgs."
	:group 'erc :type '(repeat regexp))

(defcustom fg-erc-msg-block-plists ()
	"Block messages by matching any of
channel, network, nick or message vs regexp plists.

List of plists with any number of following keys (in each):
	:net - regexp to match network.
	:chan - regexp to match erc-target (e.g. channel or nick).
	:nick - nickname regexp for `fg-erc-msg-block-pattern'.
	:msg - message regexp for `fg-erc-msg-block-pattern'."
	:group 'erc :type '(repeat sexp))

(defun fg-erc-msg-block-pattern (nick msg)
	"Build proper pattern for regular channel messages
 (including ZNC-buffered messages) from specified NICK
and MSG regexp patterns. MSG can have $ at the end."
	(concat
		"^\\(\\s-*\\[[0-9:]+\\]\\)?\\s-*<" nick
		">\\(\\s-+\\[[0-9:]+\\]\\)?\\s-+" msg))

(defun fg-erc-re (string) (concat "^" (regexp-quote string) "$"))


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

(erc-update-modules)


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

	erc-interpret-controls-p t ;; for otr
	erc-interpret-mirc-color nil
	erc-beep-p nil
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

	erc-ignore-list ;; global ignore-everywhere list
		'("^CIA-[[:digit:]]+!~?[cC][iI][aA]@"
			"^fdo-vcs!~?kgb@\\sw+\\.freedesktop\\.org$"
			"^KGB[^!]+!~?Debian-kgb@.*\\.kitenet\\.net$"
			"^travis-ci!~?travis-ci@.*\\.amazonaws\\.com$"
			"^irker[[:digit:]]+!~?irker@"
			"^GitHub[[:digit:]]+!~?GitHub[[:digit:]]+@.*\\.github\\.com$")

	fg-erc-msg-block ;; ignore-patterns with nick and message regexps
		(mapcar
			(apply-partially 'apply 'fg-erc-msg-block-pattern)
				'(("fc[a-f0-9]+" "\\S-+ is over two months out of date. ya feeling ok\\?")))

	fg-erc-msg-block-plists ;; net+chan+nick+msg ignore-patterns
		`((:chan "^#exherbo$"
				:net "^FreeNode$" :nick "zebrapig"
				:msg "[0-9]+ patch\\(es\\)? in queue \\.\\.\\. slackers!")
			(:chan "^#exherbo$" :net "^FreeNode$"
				:nick "\\(u-u-commits\\|gerritwk23\\|jenkins-exherbo\\)")
			(:chan "^#tahoe-lafs$" :net "^FreeNode$" :nick "tahoe-bot")
			(:chan "^#crytocc$" :net "^Cryto\\(-IRC\\|CC\\)$" :nick "botpie91")
			(:chan "^#esp$" :net "^FreeNode$" :nick "plexdev")
			(:chan "^#\\(cjdns\\|projectmeshnet\\|hyperboria\\)$"
				:net "^EFNet$" :nick "i2p"
				:msg "\\(<--\\|-->\\)\\s-+\\S-+ has \\(joined\\|quit\\|left\\) ")
			(:chan "^#cjdns$" :net "^HypeIRC$" :nick "finnbot")
			(:chan "^#bitlbee$" :net "^OFTC$" :nick "Not-dee8" :msg "\\[bitlbee\\]")
			(:chan "^#\\(unhosted\\|remotestorage\\)$"
				:net "^FreeNode$" :nick "unposted"
				:msg ,(concat "\\[\\(" "website\\(/master\\)?"
						"\\|remoteStorage\\.js\\(/[[:word:]\-_]+\\)?" "\\)\\]\\s-+"))
			(:chan "^#\\(unhosted\\|remotestorage\\)$"
				:net "^FreeNode$" :nick "DeBot"
				:msg "\\[\\(URL\\|feed\\)\\]\\s-+"))

	erc-server-auto-reconnect t
	erc-server-reconnect-attempts t
	erc-server-reconnect-timeout 10

	erc-pals nil
	erc-fools nil
	erc-notify-list nil

	erc-notify-signon-hook nil
	erc-notify-signoff-hook nil)

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


;; Message content filter
(defun fg-erc-msg-content-filter (msg)
	"erc-insert-pre-hook function to match message against
fg-erc-msg-block and fg-erc-msg-block-channel rulesets
and block the message if any rule in either matches it."
	(condition-case-unless-debug ex
		(let ((msg (erc-controls-strip msg)))
			(when
				(or
					;; check fg-erc-msg-block
					(erc-list-match fg-erc-msg-block msg)
					;; check fg-erc-msg-block-channel
					(dolist (rule fg-erc-msg-block-plists)
						(when (fg-erc-msg-match-rule rule msg) (return-from nil t))))
				(set 'erc-insert-this nil)))
		(t (warn "Error in ERC filter: %s" ex))))

(defun fg-erc-msg-match-rule (rule msg)
	"Match RULE against MSG.
Must be called from an ERC channel buffer, as it also matches
channel/netwrok parameters."
	(let*
		((net (plist-get rule :net))
			(chan (plist-get rule :chan))
			(nick (plist-get rule :nick))
			(line (plist-get rule :msg))
			(msg-pat (when (or nick line)
				(fg-erc-msg-block-pattern (or nick "[^>]+") (or line "")))))
		(and
			(or (not net)
				(string-match net (or (symbol-name (erc-network)) "")))
			(or (not chan)
				(string-match chan (or (erc-default-target) "")))
			(or (not msg-pat)
				(string-match msg-pat (fg-string-strip-whitespace msg))))))

;; (with-current-buffer (erc-get-buffer "#ccnx")
;; 	(let
;; 		((msg "[11:49:11]<someuser> some test msg")
;; 			(fg-erc-msg-block-plists
;; 				'((:nick "someuser" :net "Hype" :chan "cc"))))
;; 		(dolist (rule fg-erc-msg-block-plists)
;; 			(when (fg-erc-msg-match-rule rule msg) (return-from nil t)))))

(add-hook 'erc-insert-pre-hook 'fg-erc-msg-content-filter)


;; Useful to test new ignore-list masks
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


;; Used to get short definition of
;;  a selected word or phrase and a link to a longer version
(defun fg-erc-ddg-define (start end)
	"Send 'define <selection>' to DuckDuckGo bot via jabber."
	(interactive "r")
	(let
		((erc-buff-ddg (erc-get-buffer "ddg_bot"))
			(query (filter-buffer-substring start end)))
		(unless erc-buff-ddg
			(let*
				((erc-buff-bitlbee
						(or (erc-get-buffer "&jabber") (erc-get-buffer "&bitlbee")))
					(erc-buff-bitlbee
						(and erc-buff-bitlbee
							(with-current-buffer erc-buff-bitlbee
								(car
									(erc-buffer-list-with-nick "ddg_bot" erc-server-process))))))
				(when erc-buff-bitlbee
					(with-current-buffer erc-buff-bitlbee
						(setq erc-buff-ddg (erc-cmd-QUERY "ddg_bot"))))))
		(when erc-buff-ddg
			(switch-to-buffer erc-buff-ddg)
			(erc-send-message (format "define %s" query)))))


;; New message notification hook
(defun fg-erc-notify (text)
	(let*
		((buffer (current-buffer))
			(channel
				(or (erc-default-target) (buffer-name buffer)))
			(text (erc-controls-strip text)))
		(when
			(and (buffer-live-p buffer)
				(or
					(not (erc-buffer-visible buffer))
					(not (fg-xactive-check))))
			(condition-case-unless-debug ex
				(fg-notify (format "erc: %s" channel) text :pixmap "erc" :strip t)
				(error
					(message "ERC notification error: %s" ex)
					(ding t))))))


;; erc-highlight-nicknames mods
;; idea: from #erc
;; source: http://www.emacswiki.org/emacs/ErcNickColors
;; TODO: also check color-diff vs opposite bg, make sure color is visible on both kinds
(require 'color)

(defun* fg-erc-get-color-for-nick (nick &optional (min-delta 40))
	(fg-color-tweak
		(plist-get (custom-face-attributes-get 'default (selected-frame)) :background)
		(downcase nick) min-delta))

(defun fg-erc-highlight-nicknames ()
	(condition-case-unless-debug ex
		(save-excursion
			(goto-char (point-min))
			(while (re-search-forward "[-[:alnum:]_`^|]+" nil t)
				(let*
					((bounds (cons (match-beginning 0) (point)))
						(nick (buffer-substring-no-properties (car bounds) (cdr bounds)))
						(nick-self (erc-current-nick)))
					(when (string-match "^<\\(.*\\)>$" nick)
						(setq
							nick (match-string 1 nick)
							bounds (cons (1+ (car bounds)) (1- (cdr bounds)))))
					(when
						(and
							(or
								(and (erc-server-buffer-p) (erc-get-server-user nick))
								(and erc-channel-users (erc-get-channel-user nick)))
							(not (string-equal nick nick-self)))
						(put-text-property
							(car bounds) (cdr bounds) 'face
							(cons 'foreground-color
								(fg-erc-get-color-for-nick nick)))))))
		(error
			(message "ERC highlight error: %s" ex)
			(ding t))))

(add-hook 'erc-insert-modify-hook 'fg-erc-highlight-nicknames)


;; Putting a mark-lines into the buffers

(defun fg-erc-mark-put (buffer)
	(erc-display-line " *** -------------------- ***" buffer))

(defun erc-cmd-MARK ()
	"Put a horizontal marker-line into a buffer. Purely aesthetic."
	(fg-erc-mark-put 'active))

(defun fg-erc-mark ()
	"Put a horizontal marker-line into a current buffer."
	(interactive)
	(when (eq major-mode 'erc-mode) (fg-erc-mark-put (current-buffer))))

;; Auto mark-lines.
;; source: http://www.emacswiki.org/emacs/ErcBar

(defvar fg-erc-bar-threshold 1
	"Display bar when there are more than erc-bar-threshold unread messages.")

(defvar fg-erc-bar-overlay-color "dark red"
	"Color of the overlay line.")

(defvar fg-erc-bar-overlay nil
	"Overlay used to set bar.")

(defun fg-erc-bar-move-back (n)
	"Moves back n message lines. Ignores wrapping, and server messages."
	(interactive "nHow many lines ? ")
	(re-search-backward "^.*<.*>" nil t n))

(defun fg-erc-bar-update-overlay ()
	"Update the overlay for current buffer,
based on the content of erc-modified-channels-alist.
Should be executed on window change."
	(interactive)
	(let*
		((info (assq (current-buffer) erc-modified-channels-alist))
			(count (cadr info)))
		(if (and info (> count fg-erc-bar-threshold))
			(save-excursion
				(end-of-buffer)
				(when (fg-erc-bar-move-back count)
					(let ((inhibit-field-text-motion t))
						(move-overlay fg-erc-bar-overlay
							(line-beginning-position)
							(line-end-position)
							(current-buffer)))))
			(delete-overlay fg-erc-bar-overlay))))

;; TODO: make face change for light/dark masq's
(setq fg-erc-bar-overlay (make-overlay 0 0))
(overlay-put fg-erc-bar-overlay 'face `(:underline ,fg-erc-bar-overlay-color))

;; Put the hook *before* erc-modified-channels-update by remove/add dance
(defadvice erc-track-mode
	(after fg-erc-bar-setup-hook (&rest args) activate)
	(remove-hook 'window-configuration-change-hook 'fg-erc-bar-update-overlay)
	(add-hook 'window-configuration-change-hook 'fg-erc-bar-update-overlay))

(add-hook 'erc-send-completed-hook (lambda (str) (fg-erc-bar-update-overlay)))


;; Iterate over all erc channel buffers

(defvar fg-erc-cycle-channels-return-buffer nil
	"Non-erc buffer to return to after going full-cycle over buffers.")
(defvar fg-erc-cycle-channels-pos-start nil)

(defun fg-erc-cycle-channels ()
	"Iterate (switch-to) over all erc channel buffers,
returning to the original one in the end."
	(interactive)
	(let*
		;; List of all channel buffers
		((buffer (current-buffer))
			(channel-buffers
				(sort*
					;; Don't cycle over already-visible buffers
					(remove-if
						(lambda (buff)
							(and
								(not (eq buffer buff))
								(erc-buffer-visible buff)))
						(erc-channel-list nil))
					;; Sort by buffer (=channel) name,
					;;  so they'll always be iterated over in roughly the same order
					'string-lessp :key 'buffer-name))
			(pos (position buffer channel-buffers)))
		(when (numberp pos) (setq pos (+ pos 1)))
		(when (or (not pos) (>= pos (length channel-buffers)))
			(unless pos
				;; Set return-buffer and reset pos-start
				(setq
					fg-erc-cycle-channels-pos-start nil
					fg-erc-cycle-channels-return-buffer buffer))
			(setq pos 0))
		(if
			(and
				fg-erc-cycle-channels-pos-start
				fg-erc-cycle-channels-return-buffer
				(buffer-live-p fg-erc-cycle-channels-return-buffer)
				(= fg-erc-cycle-channels-pos-start pos))
			;; Full cycle over buffers is complete, switch back to return-buffer
			(progn
				(setq
					buffer fg-erc-cycle-channels-return-buffer
					fg-erc-cycle-channels-pos-start nil
					fg-erc-cycle-channels-return-buffer nil)
				(switch-to-buffer buffer))
			;; Switch to some channel buffer
			(unless
				(and
					fg-erc-cycle-channels-pos-start
					fg-erc-cycle-channels-return-buffer)
				;; Starting a new cycle
				(setq fg-erc-cycle-channels-pos-start pos))
			(switch-to-buffer (nth pos channel-buffers)))))


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


;; Since DCC SEND handling in ERC was a bit broken before
;;  my time, and I managed to "fix" it introducing a new regression
;;  (which I've submitted a patch for, again)...
;; It'd only make sense to leave this debug code here, for now.
;; (setq debug-on-error t)
;; (erc-dcc-handle-ctcp-send <process erc-Manchester.UK.EU.UnderNet.Org-6667>
;; 	"DCC SEND SearchBot_results_for_quicksilver.txt.zip 1816743045 58560 2779"
;; 	"seekbot" "seekbot" "108.73.76.133" "MK_FG")
;; (let ((query "DCC SEND \"SearchBot results for quicksilver.txt.zip\" 1816743045 58560 2779"))
;; 	(string-match erc-dcc-ctcp-query-send-regexp query)
;; 	(or (match-string 5 query)
;; 		(erc-dcc-unquote-filename (match-string 2 query))))
;; (let ((query "DCC SEND SearchBot_results_for_quicksilver.txt.zip 1816743045 58560 2779"))
;; 	(string-match erc-dcc-ctcp-query-send-regexp query)
;; 	(or (match-string 5 query)
;; 		(erc-dcc-unquote-filename (match-string 2 query))))

(require 'multi-term)
(setq multi-term-program "/bin/zsh")
(setq multi-term-scroll-show-maximum-output t)

; (add-hook 'term-mode-hook (lambda () (buffer-face-set "shadow")))

(add-hook 'term-mode-hook (lambda ()
	; (buffer-face-set 'fixed-pitch)
	(local-set-key (key "<tab>") 'key)))


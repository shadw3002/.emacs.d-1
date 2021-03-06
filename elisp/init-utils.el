;;; init-utils

;; count words
(defvar wc-regexp-chinese-char-and-punc
  (rx (category chinese)))
(defvar wc-regexp-chinese-punc
  "[。，！？；：「」『』（）、【】《》〈〉※—]")
(defvar wc-regexp-english-word
  "[a-zA-Z0-9-]+")

(defun my/word-count ()
  "「較精確地」統計中/日/英文字數。
- 文章中的註解不算在字數內。
- 平假名與片假名亦包含在「中日文字數」內，每個平/片假名都算單獨一個字（但片假
  名不含連音「ー」）。
- 英文只計算「單字數」，不含標點。
- 韓文不包含在內。

※計算標準太多種了，例如英文標點是否算入、以及可能有不太常用的標點符號沒算入等
。且中日文標點的計算標準要看 Emacs 如何定義特殊標點符號如ヴァランタン・アルカン
中間的點也被 Emacs 算為一個字而不是標點符號。"
  (interactive)
  (let* ((v-buffer-string
          (progn
            (if (eq major-mode 'org-mode) ; 去掉 org 文件的 OPTIONS（以#+開頭）
                (setq v-buffer-string (replace-regexp-in-string "^#\\+.+" ""
								(buffer-substring-no-properties (point-min) (point-max))))
              (setq v-buffer-string (buffer-substring-no-properties (point-min) (point-max))))
            (replace-regexp-in-string (format "^ *%s *.+" comment-start) "" v-buffer-string)))
                                        ; 把註解行刪掉（不把註解算進字數）。
         (chinese-char-and-punc 0)
         (chinese-punc 0)
         (english-word 0)
         (chinese-char 0))
    (with-temp-buffer
      (insert v-buffer-string)
      (goto-char (point-min))
      ;; 中文（含標點、片假名）
      (while (re-search-forward wc-regexp-chinese-char-and-punc nil :no-error)
        (setq chinese-char-and-punc (1+ chinese-char-and-punc)))
      ;; 中文標點符號
      (goto-char (point-min))
      (while (re-search-forward wc-regexp-chinese-punc nil :no-error)
        (setq chinese-punc (1+ chinese-punc)))
      ;; 英文字數（不含標點）
      (goto-char (point-min))
      (while (re-search-forward wc-regexp-english-word nil :no-error)
        (setq english-word (1+ english-word))))
    (setq chinese-char (- chinese-char-and-punc chinese-punc))
    ;;  (message
    ;;      (format "中日文字數（不含標點）：%s
    ;; 中日文字數（包含標點）：%s
    ;; 英文字數（不含標點）：%s
    ;; =======================
    ;; 中英文合計（不含標點）：%s"
    ;;              chinese-char chinese-char-and-punc english-word
    ;;              (+ chinese-char english-word)))
    (+ chinese-char english-word)))

;;----------------------------------------------------------------------
(defun my/insert-current-time ()
  "Insert the current time"
  (interactive "*")
  (insert (format-time-string "%Y-%m-%d %H:%M:%S" (current-time))))

(defun my/insert-current-date ()
  "Insert the current time"
  (interactive "*")
  (insert (format-time-string "%b %d, %Y" (current-time))))

(global-set-key (kbd "C-c t t") 'my/insert-current-time)
(global-set-key (kbd "C-c t d") 'my/insert-current-date)
;;--------------------------------------------------------------------
(defun my/mood-diary-quick-capture ()
  (interactive)
  (let ((mood-diary-file "~/iCloud/blog_site/org/my-mood-diary-2020.org"))
    (find-file mood-diary-file)
    (with-current-buffer "my-mood-diary-2020.org"
      (goto-char (point-min))
      (re-search-forward "-----")
      (previous-line)
      (insert "\n-----\n**")
      (backward-char)
      (my/insert-current-time)
      (forward-char)
      (insert "\n\n"))
    ))
(global-set-key (kbd "C-c m d") 'my/mood-diary-quick-capture)

;;-------------------------------------------------------------------
;; generate qrcode
(setq lexical-binding t)
(defun my/qr-encode (str &optional buf)
  "Encode STR as a QR code.
Return a new buffer or BUF with the code in it."
  (interactive "MString to encode: ")
  (let ((buffer (get-buffer-create (or buf "*QR Code*")))
        (format (if (display-graphic-p) "PNG" "UTF8"))
        (inhibit-read-only t))
    (with-current-buffer buffer
      (delete-region (point-min) (point-max)))
    (make-process
     :name "qrencode" :buffer buffer
     :command `("qrencode" ,str "-t" ,format "-o" "-")
     :coding 'no-conversion
     ;; seems only the filter function is able to move point to top
     :filter (lambda (process string)
               (with-current-buffer (process-buffer process)
                 (insert string)
                 (goto-char (point-min))
                 (set-marker (process-mark process) (point))))
     :sentinel (lambda (process change)
                 (when (string= change "finished\n")
                   (with-current-buffer (process-buffer process)
                     (cond ((string= format "PNG")
                            (image-mode)
                            (image-transform-fit-to-height))
                           (t ;(string= format "UTF8")
                            (text-mode)
                            (decode-coding-region (point-min) (point-max) 'utf-8)))))))
    (when (called-interactively-p 'interactive)
      (display-buffer buffer))
    buffer))
;; =========================
(use-package general
  :ensure t)

(use-package auto-save
  :load-path "~/.emacs.d/site-lisp/auto-save"
  :config
  (auto-save-enable)  ;; 开启自动保存功能。
  (setq auto-save-slient t) ;; 自动保存的时候静悄悄的， 不要打扰我
  (setq auto-save-delete-trailing-whitespace nil))


(use-package paredit
  ;; check if the parens is matched
  :ensure t
  :defer t)

(use-package which-key
  :ensure t
  :config
  (which-key-mode))

(use-package all-the-icons
  :load-path "~/.emacs.d/site-lisp/all-the-icons")

;;google translate
(use-package google-translate
  :ensure t
  :init
  (setq google-translate-base-url
	"http://translate.google.cn/translate_a/single")
  (setq google-translate-listen-url
	"http://translate.google.cn/translate_tts")
  (setq google-translate-backend-method 'curl)
  (setq google-translate-default-source-language "en")
  (setq google-translate-default-target-language "zh-CN")  
  :config
  (when (and (string-match "0.11.18"
			   (google-translate-version))
             (>= (time-to-seconds)
		 (time-to-seconds
                  (encode-time 0 0 0 23 9 2018))))
    (defun google-translate--get-b-d1 ()
      ;; TKK='427110.1469889687'
      (list 427110 1469889687))))

(use-package youdao-dictionary
  :ensure t
  :defer 5
  :bind (("C-c y y" . youdao-dictionary-search-at-point+)
  	 ("C-c y i" . youdao-dictionary-search-from-input))
  :init
  (setq url-automatic-caching t))

(use-package osx-dictionary
  :ensure t
  ;; :bind (("C-c y y" . osx-dictionary-search-word-at-point)
  ;; 	 ("C-c y i" . osx-dictionary-search-input))
  )

(use-package search-web
  :defer 5
  :ensure t
  :init
  (setq search-web-engines
	'(("腾讯视频" "https://v.qq.com/x/search/?q=%s" nil)
	  ("Google" "http://www.google.com/search?q=%s" nil)
	  ("Youtube" "http://www.youtube.com/results?search_query=%s" nil)
	  ("Bilibili" "https://search.bilibili.com/all?keyword=%s" nil)
	  ("Stackoveflow" "http://stackoverflow.com/search?q=%s" nil)
	  ("Sogou" "https://www.sogou.com/web?query=%s" nil)
	  ("Github" "https://github.com/search?q=%s" nil)
	  ("Melpa" "https://melpa.org/#/?q=%s" nil)
	  ("Emacs-China" "https://emacs-china.org/search?q=%s" nil)
	  ("EmacsWiki" "https://www.emacswiki.org/emacs/%s" nil)
	  ("Wiki-zh" "https://zh.wikipedia.org/wiki/%s" nil)
	  ("Wiki-en" "https://en.wikipedia.org/wiki/%s" nil)
	  ))
  :bind (("C-C w u" . browse-url)
	 ("C-c w w" . search-web)
	 ("C-c w p" . search-web-at-point)
	 ("C-c w r" . search-web-region)))

;; use xwidget-webkit
;; (setq browse-url-browser-function 'xwidget-webkit-browse-url)
;; (defun browse-url-default-browser (url &rest args)
;;   "Override `browse-url-default-browser' to use `xwidget-webkit' URL ARGS."
;;   (xwidget-webkit-browse-url url args))
;; (local-set-key (kbd "C-c w c") 'xwidget-webkit-copy-selection-as-kill)
;; (local-set-key (kbd "C-c w k") 'xwidget-webkit-current-url-message-kill)

(use-package browse-at-remote
  :ensure t
  :bind ("C-c w g" . browse-at-remote))

(use-package proxy-mode
  :ensure t
  :defer 5
  :init
  (setq proxy-mode-socks-proxy '("geekinney.com" "124.156.188.197" 10808 5))
  (setq url-gateway-local-host-regexp
	(concat "\\`" (regexp-opt '("localhost" "127.0.0.1")) "\\'")))

(use-package darkroom
  :ensure t
  :defer t
  :bind (("C-c d" . darkroom-tentative-mode)))

(use-package password-generator
  :ensure t)

(defun file-contents (filename)
  (interactive "fFind file: ")
  (with-temp-buffer
    (insert-file-contents filename) ;; 先将文件内容插入临时buffer，再读取内容
    (buffer-substring-no-properties (point-min) (point-max))))

(defun chunyang-scratch-save ()
  (ignore-errors
    (with-current-buffer "*scratch*"
      (write-region nil nil (concat config-dir "scratch")))))

(defun chunyang-scratch-restore ()
  (let ((f (concat config-dir "scratch")))
    (when (file-exists-p f)
      (with-current-buffer "*scratch*"
	(erase-buffer)
	(insert-file-contents f)))))

(add-hook 'kill-emacs-hook #'chunyang-scratch-save)
(add-hook 'after-init-hook #'chunyang-scratch-restore)

;; 统一局域网下上传文件
;; (require 'web-server)
;; (ws-start
;;  '(((:GET . ".*") .
;;     (lambda (request)
;;       (with-slots (process headers) request
;;         (ws-response-header proc 200 '("Content-type" . "text/html"))
;;         (process-send-string
;;          process
;;          "\
;; <meta name='viewport' content='width=device-width, initial-scale=1'>
;; <h1>Upload File</h1>
;; <form method='post' enctype='multipart/form-data'>
;;   <input type='file' name='file'>
;;   <input type='submit'>
;; </form>
;; "))))
;;    ((:POST . ".*") .
;;     (lambda (request)
;;       (with-slots (process headers) request
;;         (let-alist (assoc-default "file" headers)
;;           (let ((out (make-temp-file "x-" nil .filename)))
;;             (let ((coding-system-for-write 'binary))
;;               (write-region .content nil out))
;;             (message "[%s] saved %d bytes to %s"
;;                      (current-time-string)
;;                      (string-bytes .content)
;;                      out)
;;             (ws-response-header process 200 '("Content-type" . "text/plain"))
;;             (process-send-string process (format "saved to %s\n" out))))))))
;;  9008 nil :host "0.0.0.0")

;;-----------------------------
(add-hook 'focus-in-hook 'my/mac-switch-input-source)
(defun my/mac-switch-input-source ()
  (interactive)
  (shell-command
   "osascript -e 'tell application \"System Events\" to tell process \"SystemUIServer\"
      set currentLayout to get the value of the first menu bar item of menu bar 1 whose description is \"text input\"
      if currentLayout is not \"ABC\" then
        tell (1st menu bar item of menu bar 1 whose description is \"text input\") to {click, click (menu 1'\"'\"'s menu item \"ABC\")}
      end if
    end tell' &>/dev/null")
  (message "Input source has changed to ABC!"))

(provide 'init-utils)

;;; init-utils.el ends here

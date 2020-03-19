;;; 解析elisp为html
(defvar print-html--single-tag-list
  '("img" "br" "hr" "input" "meta" "link" "param"))

(defun print-html--get-plist (list)
  "get attributes of a tag"
  (let* ((i 0)
	 (plist nil))
    (while (and (nth i list) (symbolp (nth i list)))
      (setq key (nth i list))
      (setq value (nth (1+ i) list))
      (setq plist (append plist (list key value)))
      (incf i 2))
    plist))

(defun print-html--get-inner (list)
  "get inner html of a tag"
  (let* ((i 0)
	 (inner nil)
	 (plist (print-html--get-plist list)))
    (if (null plist)
	(setq inner list)
      (dolist (p plist)
	(setq inner (remove p list))
	(setq list inner)))
    inner))

(defun print-html--plist->alist (plist)
  "convert plist to alist"
  (if (null plist)
      '()
    (cons
     (list (car plist) (cadr plist))
     (print-html--plist->alist (cddr plist)))))

(defun print-html--insert-html-tag (tag &optional attrs)
  "insert html tag and attributes"
  (let ((tag (symbol-name tag))
	(attrs (print-html--plist->alist attrs)))
    (if (member tag print-html--single-tag-list)
	(progn
	  (insert (concat "<" tag "/>"))
	  (backward-char 2)
	  (dolist (attr attrs)
	    (insert (concat " " (substring (symbol-name (car attr)) 1) "=" "\"" (cadr attr) "\"")))
	  (forward-char 2))
      (progn
	(insert (concat "<" tag ">" "</" tag ">"))
	(backward-char (+ 4 (length tag)))
	(dolist (attr attrs)
	  (insert (concat " " (substring (symbol-name (car attr)) 1) "=" "\"" (cadr attr) "\"")))
	(forward-char 1)))
    ))

(defun print-html--jump-outside (tag)
  "jump outside of html tag"
  (let ((tag (symbol-name tag)))
    (if (member tag print-html--single-tag-list)
	(forward-char 0)
      (forward-char (+ 3 (length tag))))))
;;----------------------------------------
;;; hacking logic tag!
(defun print-html--process-logic-include (left)
  (dolist (item (car left))
    (print-html-unformated item)))

(defun print-html--process-logic-if (left)
  (if (car left)
      (print-html-unformated (cadr left))
    (print-html-unformated (cadr (cdr left)))))

(defun print-html--process-logic-each (left)
  (dolist (item (car left))
    (setq each-list
	  (read
	   (replace-regexp-in-string
	    "item" (concat "\"" item "\"") (prin1-to-string (cadr left)))))
    (print-html-unformated each-list)))

(defun print-html--process-logic-block (left)
  (print-html-unformated (cadr left)))

(defun print-html--process-logic-extend (left)
  (let ((base-str (prin1-to-string (car left)))
	(entend-str
	 (with-temp-buffer
	   (insert base-str)
	   (setq point (goto-char (point-min)))
	   (while point
	     (dolist (item (cdr left))
	       (setq name (symbol-name (cadr item)))
	       (setq block (prin1-to-string (cadr (cdr item))))
	       (setq point (re-search-forward ":block" nil t))
	       (skip-chars-forward "[\" \"\n\t\r]")
	       (if (string= name (thing-at-point 'word))
		   (progn
		     (skip-chars-forward "[a-zA-Z]")
		     (skip-chars-forward "[\" \"\n\t\r]")
		     (setq sexp-beg (point))
		     (ignore-errors (forward-sexp))
		     (setq sexp-end (point))
		     (kill-region sexp-beg sexp-end)
		     (insert block)))))
	   (buffer-substring-no-properties (point-min) (point-max)))))
    (print-html-unformated (read entend-str))))

(defun print-html--process-logic (list)
  "process template logic"
  (let ((logic (car list))
	(left (cdr list)))
    (cond
     ((eq logic :include)
      (print-html--process-logic-include left))
     ((eq logic :if)
      (print-html--process-logic-if left))
     ((eq logic :each)
      (print-html--process-logic-each left))
     ((eq logic :block)
      (print-html--process-logic-block left))
     ((eq logic :extend)
      (print-html--process-logic-extend left)))
    ))

;;---------------------------------------------------------------------
(defun print-html--process-tag (list)

  "process html tag"
  (let ((tag (car list))
	(plist (print-html--get-plist (cdr list)))
	(inner (print-html--get-inner (cdr list))))
    (with-current-buffer (get-buffer-create "*print html*")
      (when tag
	(progn
	  (print-html--insert-html-tag tag plist)
	  (dolist (item inner)
	    (if (listp item)
		(print-html-unformated item)
	      (insert item)))
	  (print-html--jump-outside tag)
	  (buffer-substring-no-properties (point-min) (point-max)))))
    ))

(defun print-html-unformated (list)
  "parse elisp to unformated html"
  (let ((car-str (symbol-name (car list))))
    (if (string= (substring car-str 0 1) ":")
	(print-html--process-logic list)
      (print-html--process-tag list))
    ))
;;----------------------------------------
(defun print-html--has-child-p ()
  "judge if a tag has child element"
  (let ((open-tag-pos (save-excursion
			(web-mode-element-beginning)
			(point)))
	(close-tag-pos (save-excursion
			 (web-mode-tag-match)
			 (point))))
    (save-excursion
      (goto-char close-tag-pos)
      (or (search-backward-regexp "</.+>" open-tag-pos t)
	  (search-backward-regexp "/>" open-tag-pos t)))
    ))

(defun print-html--has-context-p ()
  "judge if a tag has inner context"
  (save-excursion
    (not (eq (skip-chars-forward "^<") 0))))

(defun print-html--has-context-newline ()
  "make a newline at the end context"
  (if (print-html--has-context-p)
      (progn
	(skip-chars-forward "^<")
	(newline))))

(defun print-html-format-html ()
  "well format html string"
  (let ((pos (goto-char (point-min))))
    (with-current-buffer "*print html*"
      (web-mode)
      (while (< pos (point-max))
	(if (print-html--has-child-p)
	    (progn
	      (skip-chars-forward "^>")
	      (forward-char)
	      (newline)
	      (setq pos (point))
	      (print-html--has-context-newline)
	      (setq pos (point)))
	  (progn
	    (sgml-skip-tag-forward 1)
	    (newline)
	    (setq pos (point))
	    (print-html--has-context-newline)
	    (setq pos (point))))))))
;;----------------------------------------
(defun print-html-test (LIST)
  (with-current-buffer (get-buffer-create "*print-html-test*")
    (web-mode)
    (insert (print-html LIST))
    (indent-region-or-buffer))
  (view-buffer "*print-html-test*"))

(defun print-html (LIST)
  (let ((html (print-html-unformated LIST)))
    (with-current-buffer "*print html*"
      (print-html-format-html)
      (setq html (buffer-substring-no-properties (point-min) (point-max))))
    (kill-buffer "*print html*")
    html))
;;----------------------------------------
;;; example!
(print-html-test
 `(div :class "post-info"
       (p "「"
	  (:include ,test)
	  (:if ,comment
	       (a "show comment") ;; (:include ,comment-div1)
	       (a "hide comment") ;; (:include ,comment-div2)
	       )
	  (ul
	   (:each
	    ("apple" "peach" "orange" "grape")
	    (li :class "fruit" item)))
	  (span "分类")
	  (span "字数")
	  (span :id "id"
		(span :class "post-meta-item-text" "阅读 ")
		(span :class "leancloud-visitors-count" "...")
		" 次")
	  "」")))<div class="post-info">
<p>
「
  <span class="test">test-content</span>
  <a>hide comment</a>
  <ul>
  <li class="fruit">apple</li>
  <li class="fruit">peach</li>
  <li class="fruit">orange</li>
  <li class="fruit">grape</li>
  </ul>
  <span>分类</span>
  <span>字数</span>
  <span id="id">
  <span class="post-meta-item-text">阅读 </span>
  <span class="leancloud-visitors-count">...</span>
  次
  </span>
  」
</p>
</div>

;;----------------------------------------------------------------
;;; extend 和 include的区别和联系??
(setq base-html
      '(body
	(h1 :id "logo" "戈楷旎")
	(p :id "description" "happy hacking emacs")
	(div :id "content"
	     (:block main))
	(div :id "postamble"
	     (:block post))
	))


(setq extend-html
      `(:extend ,base-html
		(:block main (p "this is the extend main content"))
		(:block post (p "this is the extend postamble content"))
		))

(print-html extend-html)
;;----------------------------------------------------------------------
;;; test var!
(setq comment nil)
(setq comment-div1 '((a :class "if-test" "if-test-content")))
(setq comment-div2 '((a :class "else-test" "else-test-content")))
(setq list '((span :class "span" item)))
(setq test `((span :class "test" "test-content")))
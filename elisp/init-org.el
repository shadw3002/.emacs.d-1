;;; Org clock
(use-package org
  :bind (("C-c c" . org-capture)
	 ("<f9>" . plain-org-wiki)
	 ("<f12>" . org-agenda)
	 ("C-c a" . org-agenda)
	 ("C-c o l" . org-store-link)
	 ("C-c t v" . org-tags-view))
  :init
  (setq org-src-fontify-natively t)
  (setq org-agenda-files '("~/org"))

  (setq org-agenda-window-setup 'current-window)

  ;; Set to the location of your Org files on your local system
  (setq org-directory "~/org")
  (setq org-default-notes-file "~/org/inbox.org")

  ;; Capture templates for: TODO tasks, Notes, diary, habit and org-protocol
  (setq org-capture-templates
	(quote (("t" "todo" entry (file "~/org/inbox.org")
		 "* TODO %?\n%U\n" :clock-resume t
		 :empty-lines 1)
		("n" "note" entry (file "~/org/inbox.org")
		 "* %? :NOTE:\n%U\n" :clock-resume t
		 :empty-lines 1)
		("j" "Journal" entry (file+datetree "~/org/diary.org")
		 "* %?\n Entered on %U\n" :clock-in t :clock-resume t)
		("w" "org-protocol" entry (file "~/org/inbox.org")
		 "* TODO Review %c\n%U\n" :immediate-finish t
		 :empty-lines 1)
		("h" "Habit" entry (file "~/org/inbox.org")
		 "* NEXT %?\n%U\n%a\nSCHEDULED: %(format-time-string \"%<<%Y-%m-%d %a .+1d/3d>>\")\n:PROPERTIES:\n:STYLE: habit\n:REPEAT_TO_STATE: NEXT\n:END:\n"
		 :empty-lines 1))))
  :config
  ;; org code block
  (defun org-insert-src-block (src-code-type)
    "Insert a `SRC-CODE-TYPE' type source code block in org-mode."
    (interactive
     (let ((src-code-types
	    '("emacs-lisp" "python" "C" "sh" "java" "js" "clojure" "C++" "css"
	      "calc" "asymptote" "dot" "gnuplot" "ledger" "lilypond" "mscgen"
	      "octave" "oz" "plantuml" "R" "sass" "screen" "sql" "awk" "ditaa"
	      "haskell" "latex" "lisp" "matlab" "ocaml" "org" "perl" "ruby"
	      "scheme" "sqlite")))
       (list (ido-completing-read "Source code type: " src-code-types))))
    (progn
      (newline-and-indent)
      (insert (format "#+BEGIN_SRC %s\n" src-code-type))
      (newline-and-indent)
      (insert "#+END_SRC\n")
      (previous-line 2)
      (org-edit-src-code)))

  (add-hook 'org-mode-hook '(lambda ()
			      ;; turn on flyspell-mode by default
					; (flyspell-mode 1)

			      ;; C-TAB for expanding
			      (local-set-key (kbd "C-<tab>")
					     'yas/expand-from-trigger-key)
			      ;; keybinding for editing source code blocks
			      (local-set-key (kbd "C-c o e")
					     'org-edit-src-code)
			      ;; keybinding for inserting code blocks
			      (local-set-key (kbd "C-c o i")
					     'org-insert-src-block)
			      ))

  (defun bh/remove-empty-drawer-on-clock-out ()
    "Remove empty LOGBOOK drawers on clock out"
    (interactive)
    (save-excursion
      (beginning-of-line 0)
      (org-remove-empty-drawer-at (point))))

  (add-hook 'org-clock-out-hook 'bh/remove-empty-drawer-on-clock-out 'append)

  ;; org refile config
  ;;==================================================
					; Targets include this file and any file contributing to the agenda - up to 9 levels deep
  (setq org-refile-targets (quote ((nil :maxlevel . 9)
				   (org-agenda-files :maxlevel . 9))))

					; Use full outline paths for refile targets - we file directly with IDO
  (setq org-refile-use-outline-path t)

					; Targets complete directly with IDO
  (setq org-outline-path-complete-in-steps nil)

					; Allow refile to create parent tasks with confirmation
  (setq org-refile-allow-creating-parent-nodes (quote confirm))

					; Use IDO for both buffer and file completion and ido-everywhere to t
  (setq org-completion-use-ido t)
  (setq ido-everywhere t)
  (setq ido-max-directory-size 100000)
  (ido-mode (quote both))
					; Use the current window when visiting files and buffers with ido
  (setq ido-default-file-method 'selected-window)
  (setq ido-default-buffer-method 'selected-window)
					; Use the current window for indirect buffer display
  (setq org-indirect-buffer-display 'current-window)

	    ;;;; Refile settings
					; Exclude DONE state tasks from refile targets
  (defun bh/verify-refile-target ()
    "Exclude todo keywords with a done state from refile targets"
    (not (member (nth 2 (org-heading-components)) org-done-keywords)))

  (setq org-refile-target-verify-function 'bh/verify-refile-target)

    ;;; ==================================================
    ;;; ==================================================

  (setq org-agenda-span 'day)

  (setq org-stuck-projects (quote ("" nil nil "")))

  (defun bh/is-project-p ()
    "Any task with a todo keyword subtask"
    (save-restriction
      (widen)
      (let ((has-subtask)
	    (subtree-end (save-excursion (org-end-of-subtree t)))
	    (is-a-task (member (nth 2 (org-heading-components)) org-todo-keywords-1)))
	(save-excursion
	  (forward-line 1)
	  (while (and (not has-subtask)
		      (< (point) subtree-end)
		      (re-search-forward "^\*+ " subtree-end t))
	    (when (member (org-get-todo-state) org-todo-keywords-1)
	      (setq has-subtask t))))
	(and is-a-task has-subtask))))

  (defun bh/is-project-subtree-p ()
    "Any task with a todo keyword that is in a project subtree.
    Callers of this function already widen the buffer view."
    (let ((task (save-excursion (org-back-to-heading 'invisible-ok)
				(point))))
      (save-excursion
	(bh/find-project-task)
	(if (equal (point) task)
	    nil
	  t))))

  (defun bh/is-task-p ()
    "Any task with a todo keyword and no subtask"
    (save-restriction
      (widen)
      (let ((has-subtask)
	    (subtree-end (save-excursion (org-end-of-subtree t)))
	    (is-a-task (member (nth 2 (org-heading-components)) org-todo-keywords-1)))
	(save-excursion
	  (forward-line 1)
	  (while (and (not has-subtask)
		      (< (point) subtree-end)
		      (re-search-forward "^\*+ " subtree-end t))
	    (when (member (org-get-todo-state) org-todo-keywords-1)
	      (setq has-subtask t))))
	(and is-a-task (not has-subtask)))))

  (defun bh/is-subproject-p ()
    "Any task which is a subtask of another project"
    (let ((is-subproject)
	  (is-a-task (member (nth 2 (org-heading-components)) org-todo-keywords-1)))
      (save-excursion
	(while (and (not is-subproject) (org-up-heading-safe))
	  (when (member (nth 2 (org-heading-components)) org-todo-keywords-1)
	    (setq is-subproject t))))
      (and is-a-task is-subproject)))

  (defun bh/list-sublevels-for-projects-indented ()
    "Set org-tags-match-list-sublevels so when restricted to a subtree we list all subtasks.
      This is normally used by skipping functions where this variable is already local to the agenda."
    (if (marker-buffer org-agenda-restrict-begin)
	(setq org-tags-match-list-sublevels 'indented)
      (setq org-tags-match-list-sublevels nil))
    nil)

  (defun bh/list-sublevels-for-projects ()
    "Set org-tags-match-list-sublevels so when restricted to a subtree we list all subtasks.
      This is normally used by skipping functions where this variable is already local to the agenda."
    (if (marker-buffer org-agenda-restrict-begin)
	(setq org-tags-match-list-sublevels t)
      (setq org-tags-match-list-sublevels nil))
    nil)

  (defvar bh/hide-scheduled-and-waiting-next-tasks t)

  (defun bh/toggle-next-task-display ()
    (interactive)
    (setq bh/hide-scheduled-and-waiting-next-tasks (not bh/hide-scheduled-and-waiting-next-tasks))
    (when  (equal major-mode 'org-agenda-mode)
      (org-agenda-redo))
    (message "%s WAITING and SCHEDULED NEXT Tasks" (if bh/hide-scheduled-and-waiting-next-tasks "Hide" "Show")))

  (defun bh/skip-stuck-projects ()
    "Skip trees that are not stuck projects"
    (save-restriction
      (widen)
      (let ((next-headline (save-excursion (or (outline-next-heading) (point-max)))))
	(if (bh/is-project-p)
	    (let* ((subtree-end (save-excursion (org-end-of-subtree t)))
		   (has-next ))
	      (save-excursion
		(forward-line 1)
		(while (and (not has-next) (< (point) subtree-end) (re-search-forward "^\\*+ NEXT " subtree-end t))
		  (unless (member "WAITING" (org-get-tags-at))
		    (setq has-next t))))
	      (if has-next
		  nil
		next-headline)) ; a stuck project, has subtasks but no next task
	  nil))))

  (defun bh/skip-non-stuck-projects ()
    "Skip trees that are not stuck projects"
    ;; (bh/list-sublevels-for-projects-indented)
    (save-restriction
      (widen)
      (let ((next-headline (save-excursion (or (outline-next-heading) (point-max)))))
	(if (bh/is-project-p)
	    (let* ((subtree-end (save-excursion (org-end-of-subtree t)))
		   (has-next ))
	      (save-excursion
		(forward-line 1)
		(while (and (not has-next) (< (point) subtree-end) (re-search-forward "^\\*+ NEXT " subtree-end t))
		  (unless (member "WAITING" (org-get-tags-at))
		    (setq has-next t))))
	      (if has-next
		  next-headline
		nil)) ; a stuck project, has subtasks but no next task
	  next-headline))))

  (defun bh/skip-non-projects ()
    "Skip trees that are not projects"
    ;; (bh/list-sublevels-for-projects-indented)
    (if (save-excursion (bh/skip-non-stuck-projects))
	(save-restriction
	  (widen)
	  (let ((subtree-end (save-excursion (org-end-of-subtree t))))
	    (cond
	     ((bh/is-project-p)
	      nil)
	     ((and (bh/is-project-subtree-p) (not (bh/is-task-p)))
	      nil)
	     (t
	      subtree-end))))
      (save-excursion (org-end-of-subtree t))))

  (defun bh/skip-non-tasks ()
    "Show non-project tasks.
    Skip project and sub-project tasks, habits, and project related tasks."
    (save-restriction
      (widen)
      (let ((next-headline (save-excursion (or (outline-next-heading) (point-max)))))
	(cond
	 ((bh/is-task-p)
	  nil)
	 (t
	  next-headline)))))

  (defun bh/skip-project-trees-and-habits ()
    "Skip trees that are projects"
    (save-restriction
      (widen)
      (let ((subtree-end (save-excursion (org-end-of-subtree t))))
	(cond
	 ((bh/is-project-p)
	  subtree-end)
	 ((org-is-habit-p)
	  subtree-end)
	 (t
	  nil)))))

  (defun bh/skip-projects-and-habits-and-single-tasks ()
    "Skip trees that are projects, tasks that are habits, single non-project tasks"
    (save-restriction
      (widen)
      (let ((next-headline (save-excursion (or (outline-next-heading) (point-max)))))
	(cond
	 ((org-is-habit-p)
	  next-headline)
	 ((and bh/hide-scheduled-and-waiting-next-tasks
	       (member "WAITING" (org-get-tags-at)))
	  next-headline)
	 ((bh/is-project-p)
	  next-headline)
	 ((and (bh/is-task-p) (not (bh/is-project-subtree-p)))
	  next-headline)
	 (t
	  nil)))))

  (defun bh/skip-project-tasks-maybe ()
    "Show tasks related to the current restriction.
    When restricted to a project, skip project and sub project tasks, habits, NEXT tasks, and loose tasks.
    When not restricted, skip project and sub-project tasks, habits, and project related tasks."
    (save-restriction
      (widen)
      (let* ((subtree-end (save-excursion (org-end-of-subtree t)))
	     (next-headline (save-excursion (or (outline-next-heading) (point-max))))
	     (limit-to-project (marker-buffer org-agenda-restrict-begin)))
	(cond
	 ((bh/is-project-p)
	  next-headline)
	 ((org-is-habit-p)
	  subtree-end)
	 ((and (not limit-to-project)
	       (bh/is-project-subtree-p))
	  subtree-end)
	 ((and limit-to-project
	       (bh/is-project-subtree-p)
	       (member (org-get-todo-state) (list "NEXT")))
	  subtree-end)
	 (t
	  nil)))))

  (defun bh/skip-project-tasks ()
    "Show non-project tasks.
    Skip project and sub-project tasks, habits, and project related tasks."
    (save-restriction
      (widen)
      (let* ((subtree-end (save-excursion (org-end-of-subtree t))))
	(cond
	 ((bh/is-project-p)
	  subtree-end)
	 ((org-is-habit-p)
	  subtree-end)
	 ((bh/is-project-subtree-p)
	  subtree-end)
	 (t
	  nil)))))

  (defun bh/skip-non-project-tasks ()
    "Show project tasks.
    Skip project and sub-project tasks, habits, and loose non-project tasks."
    (save-restriction
      (widen)
      (let* ((subtree-end (save-excursion (org-end-of-subtree t)))
	     (next-headline (save-excursion (or (outline-next-heading) (point-max)))))
	(cond
	 ((bh/is-project-p)
	  next-headline)
	 ((org-is-habit-p)
	  subtree-end)
	 ((and (bh/is-project-subtree-p)
	       (member (org-get-todo-state) (list "NEXT")))
	  subtree-end)
	 ((not (bh/is-project-subtree-p))
	  subtree-end)
	 (t
	  nil)))))

  (defun bh/skip-projects-and-habits ()
    "Skip trees that are projects and tasks that are habits"
    (save-restriction
      (widen)
      (let ((subtree-end (save-excursion (org-end-of-subtree t))))
	(cond
	 ((bh/is-project-p)
	  subtree-end)
	 ((org-is-habit-p)
	  subtree-end)
	 (t
	  nil)))))

  (defun bh/skip-non-subprojects ()
    "Skip trees that are not projects"
    (let ((next-headline (save-excursion (outline-next-heading))))
      (if (bh/is-subproject-p)
	  nil
	next-headline)))

  (defun org-is-habit-p ())

    ;;; ==================================================

  ;; Do not dim blocked tasks
  (setq org-agenda-dim-blocked-tasks nil)

  ;; Compact the block agenda view
  (setq org-agenda-compact-blocks t)

  ;; Custom agenda command definitions
  (setq org-agenda-custom-commands
	(quote (("o" "Omni Agenda"
		 ((agenda "" nil)
		  (tags "REFILE"
			((org-agenda-overriding-header "Inbox, task to refile!")
			 (org-tags-match-list-sublevels nil)))))
		("N" "Notes" tags "NOTE"
		 ((org-agenda-overriding-header "Notes")
		  (org-tags-match-list-sublevels t)))
		("h" "Habits" tags-todo "STYLE=\"habit\""
		 ((org-agenda-overriding-header "Habits")
		  (org-agenda-sorting-strategy
		   '(todo-state-down effort-up category-keep))))
		(" " "Agenda"
		 ((agenda "" nil)
		  (tags "REFILE"
			((org-agenda-overriding-header "Tasks to Refile")
			 (org-tags-match-list-sublevels nil)))
		  (tags-todo "-CANCELLED/!"
			     ((org-agenda-overriding-header "Stuck Projects")
			      (org-agenda-skip-function 'bh/skip-non-stuck-projects)
			      (org-agenda-sorting-strategy
			       '(category-keep))))
		  (tags-todo "-HOLD-CANCELLED/!"
			     ((org-agenda-overriding-header "Projects")
			      (org-agenda-skip-function 'bh/skip-non-projects)
			      (org-tags-match-list-sublevels 'indented)
			      (org-agenda-sorting-strategy
			       '(category-keep))))
		  (tags-todo "-CANCELLED/!NEXT"
			     ((org-agenda-overriding-header (concat "Project Next Tasks"
								    (if bh/hide-scheduled-and-waiting-next-tasks
									""
								      " (including WAITING and SCHEDULED tasks)")))
			      (org-agenda-skip-function 'bh/skip-projects-and-habits-and-single-tasks)
			      (org-tags-match-list-sublevels t)
			      (org-agenda-todo-ignore-scheduled bh/hide-scheduled-and-waiting-next-tasks)
			      (org-agenda-todo-ignore-deadlines bh/hide-scheduled-and-waiting-next-tasks)
			      (org-agenda-todo-ignore-with-date bh/hide-scheduled-and-waiting-next-tasks)
			      (org-agenda-sorting-strategy
			       '(todo-state-down effort-up category-keep))))
		  (tags-todo "-REFILE-CANCELLED-WAITING-HOLD/!"
			     ((org-agenda-overriding-header (concat "Project Subtasks"
								    (if bh/hide-scheduled-and-waiting-next-tasks
									""
								      " (including WAITING and SCHEDULED tasks)")))
			      (org-agenda-skip-function 'bh/skip-non-project-tasks)
			      (org-agenda-todo-ignore-scheduled bh/hide-scheduled-and-waiting-next-tasks)
			      (org-agenda-todo-ignore-deadlines bh/hide-scheduled-and-waiting-next-tasks)
			      (org-agenda-todo-ignore-with-date bh/hide-scheduled-and-waiting-next-tasks)
			      (org-agenda-sorting-strategy
			       '(category-keep))))
		  (tags-todo "-REFILE-CANCELLED-WAITING-HOLD/!"
			     ((org-agenda-overriding-header (concat "Standalone Tasks"
								    (if bh/hide-scheduled-and-waiting-next-tasks
									""
								      " (including WAITING and SCHEDULED tasks)")))
			      (org-agenda-skip-function 'bh/skip-project-tasks)
			      (org-agenda-todo-ignore-scheduled bh/hide-scheduled-and-waiting-next-tasks)
			      (org-agenda-todo-ignore-deadlines bh/hide-scheduled-and-waiting-next-tasks)
			      (org-agenda-todo-ignore-with-date bh/hide-scheduled-and-waiting-next-tasks)
			      (org-agenda-sorting-strategy
			       '(category-keep))))
		  (tags-todo "-CANCELLED+WAITING|HOLD/!"
			     ((org-agenda-overriding-header (concat "Waiting and Postponed Tasks"
								    (if bh/hide-scheduled-and-waiting-next-tasks
									""
								      " (including WAITING and SCHEDULED tasks)")))
			      (org-agenda-skip-function 'bh/skip-non-tasks)
			      (org-tags-match-list-sublevels nil)
			      (org-agenda-todo-ignore-scheduled bh/hide-scheduled-and-waiting-next-tasks)
			      (org-agenda-todo-ignore-deadlines bh/hide-scheduled-and-waiting-next-tasks)))
		  (tags "-REFILE/"
			((org-agenda-overriding-header "Tasks to Archive")
			 (org-agenda-skip-function 'bh/skip-non-archivable-tasks)
			 (org-tags-match-list-sublevels nil))))
		 nil))))

  ;; ==================================================


  (setq org-todo-keywords
	(quote ((sequence "TODO(t)" "NEXT(n)" "|" "DONE(d)")
		(sequence "WAITING(w@/!)" "HOLD(h@/!)" "|" "CANCELLED(c@/!)" "PHONE" "MEETING"))))


  (setq org-todo-keyword-faces
	(quote (("TODO" :foreground "red" :weight bold)
		("NEXT" :foreground "blue" :weight bold)
		("DONE" :foreground "forest green" :weight bold)
		("WAITING" :foreground "orange" :weight bold)
		("HOLD" :foreground "magenta" :weight bold)
		("CANCELLED" :foreground "forest green" :weight bold)
		("MEETING" :foreground "forest green" :weight bold)
		("PHONE" :foreground "forest green" :weight bold))))

  ;; to state tiggers
  (setq org-todo-state-tags-triggers
	(quote (("CANCELLED" ("CANCELLED" . t))
		("WAITING" ("WAITING" . t))
		("HOLD" ("WAITING") ("HOLD" . t))
		(done ("WAITING") ("HOLD"))
		("TODO" ("WAITING") ("CANCELLED") ("HOLD"))
		("NEXT" ("WAITING") ("CANCELLED") ("HOLD"))
		("DONE" ("WAITING") ("CANCELLED") ("HOLD")))))

  ;; filtering
  ;; (defun bh/org-auto-exclude-function (tag)
  ;;   "Automatic task exclusion in the agenda with / RET"
  ;;   (and (cond
  ;; 	((string= tag "hold")
  ;; 	 t)
  ;; 	((string= tag "farm")
  ;; 	 t))
  ;;        (concat "-" tag)))

  ;; (setq org-agenda-auto-exclude-function 'bh/org-auto-exclude-function)


  ;; Tags with fast selection keys
  (setq org-tag-alist (quote ((:startgroup)
			      ("@office" . ?o)
			      ("@home" . ?H)
			      (:endgroup)
			      ("WAITING" . ?w)
			      ("HOLD" . ?h)
			      ("PERSONAL" . ?P)
			      ("WORK" . ?W)
			      ("NOTE" . ?n)
			      ("CANCELLED" . ?c)
			      ("FLAGGED" . ??)
			      ("emacs" . ?e)
			      ("blog" . ?b)
			      )))

					; Allow setting single tags without the menu
  (setq org-fast-tag-selection-single-key (quote expert))

					; For tag searches ignore tasks with scheduled and deadline dates
  (setq org-agenda-tags-todo-honor-ignore-options t)

  ;; cycle through the todo states but skip setting timestamps.
  (setq org-treat-S-cursor-todo-selection-as-state-change nil)


  ;; 优先级范围和默认任务的优先级
  (setq org-highest-priority ?A)
  (setq org-lowest-priority  ?E)
  (setq org-default-priority ?C)
  ;; 优先级醒目外观
  (setq org-priority-faces
	'((?A . (:background "red" :foreground "white" :weight bold))
	  (?B . (:background "DarkOrange" :foreground "white" :weight bold))
	  (?C . (:background "yellow" :foreground "DarkGreen" :weight bold))
	  (?D . (:background "DodgerBlue" :foreground "black" :weight bold))
	  (?E . (:background "SkyBlue" :foreground "black" :weight bold))
	  ))


  ;; =====================clock setup=============================

  ;; Resume clocking task when emacs is restarted
  (org-clock-persistence-insinuate)
  ;;
  ;; Show lot of clocking history so it's easy to pick items off the C-F11 list
  (setq org-clock-history-length 23)
  ;; Resume clocking task on clock-in if the clock is open
  (setq org-clock-in-resume t)
  ;; Change tasks to NEXT when clocking in
  (setq org-clock-in-switch-to-state 'bh/clock-in-to-next)
  ;; Separate drawers for clocking and logs
  (setq org-drawers (quote ("PROPERTIES" "LOGBOOK")))
  ;; Save clock data and state changes and notes in the LOGBOOK drawer
  (setq org-clock-into-drawer t)
  ;; Sometimes I change tasks I'm clocking quickly - this removes clocked tasks with 0:00 duration
  (setq org-clock-out-remove-zero-time-clocks t)
  ;; Clock out when moving task to a done state
  (setq org-clock-out-when-done t)
  ;; Save the running clock and all clock history when exiting Emacs, load it on startup
  (setq org-clock-persist t)
  ;; Do not prompt to resume an active clock
  (setq org-clock-persist-query-resume nil)
  ;; Enable auto clock resolution for finding open clocks
  (setq org-clock-auto-clock-resolution (quote when-no-clock-is-running))
  ;; Include current clocking task in clock reports
  (setq org-clock-report-include-clocking-task t)

  (setq bh/keep-clock-running nil)

  (defun bh/clock-in-to-next (kw)
    "Switch a task from TODO to NEXT when clocking in.
	Skips capture tasks, projects, and subprojects.
	Switch projects and subprojects from NEXT back to TODO"
    (when (not (and (boundp 'org-capture-mode) org-capture-mode))
      (cond
       ((and (member (org-get-todo-state) (list "TODO"))
	     (bh/is-task-p))
	"NEXT")
       ((and (member (org-get-todo-state) (list "NEXT"))
	     (bh/is-project-p))
	"TODO"))))

  (defun bh/find-project-task ()
    "Move point to the parent (project) task if any"
    (save-restriction
      (widen)
      (let ((parent-task (save-excursion (org-back-to-heading 'invisible-ok) (point))))
	(while (org-up-heading-safe)
	  (when (member (nth 2 (org-heading-components)) org-todo-keywords-1)
	    (setq parent-task (point))))
	(goto-char parent-task)
	parent-task)))

  (defun bh/punch-in (arg)
    "Start continuous clocking and set the default task to the
	selected task.  If no task is selected set the Organization task
	as the default task."
    (interactive "p")
    (setq bh/keep-clock-running t)
    (if (equal major-mode 'org-agenda-mode)
	;;
	;; We're in the agenda
	;;
	(let* ((marker (org-get-at-bol 'org-hd-marker))
	       (tags (org-with-point-at marker (org-get-tags-at))))
	  (if (and (eq arg 4) tags)
	      (org-agenda-clock-in '(16))
	    (bh/clock-in-organization-task-as-default)))
      ;;
      ;; We are not in the agenda
      ;;
      (save-restriction
	(widen)
					; Find the tags on the current task
	(if (and (equal major-mode 'org-mode) (not (org-before-first-heading-p)) (eq arg 4))
	    (org-clock-in '(16))
	  (bh/clock-in-organization-task-as-default)))))

  (defun bh/punch-out ()
    (interactive)
    (setq bh/keep-clock-running nil)
    (when (org-clock-is-active)
      (org-clock-out))
    (org-agenda-remove-restriction-lock))

  (defun bh/clock-in-default-task ()
    (save-excursion
      (org-with-point-at org-clock-default-task
	(org-clock-in))))

  (defun bh/clock-in-parent-task ()
    "Move point to the parent (project) task if any and clock in"
    (let ((parent-task))
      (save-excursion
	(save-restriction
	  (widen)
	  (while (and (not parent-task) (org-up-heading-safe))
	    (when (member (nth 2 (org-heading-components)) org-todo-keywords-1)
	      (setq parent-task (point))))
	  (if parent-task
	      (org-with-point-at parent-task
		(org-clock-in))
	    (when bh/keep-clock-running
	      (bh/clock-in-default-task)))))))

  (defvar bh/organization-task-id "eb155a82-92b2-4f25-a3c6-0304591af2f9")

  (defun bh/clock-in-organization-task-as-default ()
    (interactive)
    (org-with-point-at (org-id-find bh/organization-task-id 'marker)
      (org-clock-in '(16))))

  (defun bh/clock-out-maybe ()
    (when (and bh/keep-clock-running
	       (not org-clock-clocking-in)
	       (marker-buffer org-clock-default-task)
	       (not org-clock-resolving-clocks-due-to-idleness))
      (bh/clock-in-parent-task)))

  (add-hook 'org-clock-out-hook 'bh/clock-out-maybe 'append)

  (setq org-time-stamp-rounding-minutes (quote (1 1)))

  (setq org-agenda-clock-consistency-checks
	(quote (:max-duration "4:00"
			      :min-duration 0
			      :max-gap 0
			      :gap-ok-around ("4:00"))))

  ;;; Show the clocked-in task - if any - in the header line
  (defun sanityinc/show-org-clock-in-header-line ()
    (setq-default header-line-format '((" " org-mode-line-string " "))))

  (defun sanityinc/hide-org-clock-from-header-line ()
    (setq-default header-line-format nil))

  (add-hook 'org-clock-in-hook 'sanityinc/show-org-clock-in-header-line)
  (add-hook 'org-clock-out-hook 'sanityinc/hide-org-clock-from-header-line)
  (add-hook 'org-clock-cancel-hook 'sanityinc/hide-org-clock-from-header-line)

    ;;; =================Time Reporting and Tracking=================================
  (setq org-clock-out-remove-zero-time-clocks t)

  ;; Agenda clock report parameters
  (setq org-agenda-clockreport-parameter-plist
	(quote (:link t :maxlevel 5 :fileskip0 t :compact t :narrow 80)))

  ;; Set default column view headings: Task Effort Clock_Summary
  (setq org-columns-default-format "%80ITEM(Task) %10Effort(Effort){:} %10CLOCKSUM")

  ;; global Effort estimate values
  ;; global STYLE property values for completion
  (setq org-global-properties (quote (("Effort_ALL" . "0:15 0:30 0:45 1:00 2:00 3:00 4:00 5:00 6:00 0:00")
				      ("STYLE_ALL" . "habit"))))

  ;; Agenda log mode items to display (closed and state changes by default)
  (setq org-agenda-log-mode-items (quote (closed state)))

  ;; ==================================================
  ;; 中文换行问题
  (add-hook 'org-mode-hook 
	    (lambda () (setq truncate-lines nil)))

  )


(use-package org-bullets
  :ensure t
  :config
  (add-hook 'org-mode-hook (lambda () (org-bullets-mode 1))))

(use-package org-agenda-property
  :ensure t
  :bind (("C-c o p" . org-property-action)))

(use-package calfw-org
  :ensure t
  :defer t
  :bind (("C-x c c" . my-open-calendar))
  :config
  (defun my-open-calendar ()
    (interactive)
    (cfw:open-calendar-buffer
     :contents-sources
     (list
      (cfw:org-create-source "#FFFFFF")))))

(use-package calfw
  :ensure t
  :defer t)

(use-package move-text
  :ensure t
  :defer 5
  :config (move-text-default-bindings))

(use-package htmlize
  :ensure t
  :defer 5)

(use-package idle-org-agenda
  :after org-agenda
  :ensure t
  :init (setq idle-org-agenda-interval 600
	      idle-org-agenda-key "o")
  :config (idle-org-agenda-mode))


(provide 'init-org)

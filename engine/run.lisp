;;;; engine/run.lisp -- uruchamianie SGP/Graphplan w SBCL (Windows, macOS, Linux)
;;;;
;;;;   sbcl --script engine/run.lisp <plik.pddl> [problem] [opcje]
;;;;
;;;;   problem          nazwa z (define (problem X) ...); pusta -> pierwszy w pliku
;;;;   --name NAZWA     nazwa wyniku: results/NAZWA.json (domyślnie problem-data-czas)
;;;;   --graph          dodatkowo results/NAZWA.html z rysunkiem grafu planowania
;;;;   --no-open        nie otwieraj rysunku w przeglądarce
;;;;   --list           tylko wypisz problemy zdefiniowane w pliku
;;;;   --gp | --sgp     wymuś planner (domyślnie: SGP przy niepewności/obserwacjach)
;;;;   --levels N       maksymalna liczba kroków algorytmu = długość planu (domyślnie 20)
;;;;   --trace FLAGA    śledzenie SGP: contexts, top-level, actions, mutex, bc, csp
;;;;
;;;; Pliki plannera (loader, domains, logic, gp, sgp) to SGP 1.0h -- patrz SGP-README.txt.

(setf sb-impl::*default-external-format* :utf-8)

(defpackage :runner (:use :common-lisp))
(in-package :runner)

(defvar *engine-dir* (make-pathname :name nil :type nil :version nil :defaults *load-truename*))
(defvar *root*
  (let ((dir (butlast (pathname-directory *engine-dir*))))
    (make-pathname :directory dir :name nil :type nil :version nil :defaults *engine-dir*)))

;;; ------------------------------------------------------------------
;;; Ładowanie plannera (ze źródeł, forma po formie -- jak w Allegro CL)

(handler-bind ((warning #'muffle-warning))
  (let ((*load-verbose* nil) (*compile-verbose* nil) (*compile-print* nil))
    (dolist (f '("loader" "domains" "logic" "gp" "sgp"))
      (load (make-pathname :name f :type "lisp" :defaults *engine-dir*)))))

(defun dom (name) (find-symbol name :domains))
(defun dcall (name &rest args) (apply (dom name) args))
(defun pcall (pkg name &rest args) (apply (find-symbol name pkg) args))

;;; ------------------------------------------------------------------
;;; Pomiar: opakowujemy funkcje plannera, nie zmieniając ich kodu

(defvar *last-pg* nil)
(defvar *level-times* nil)   ; lista plist (:expansion s :mutex s :search s), od poziomu 1
(defvar *current* nil)

(defun now () (get-internal-real-time))
(defun secs (start) (/ (- (get-internal-real-time) start) (float internal-time-units-per-second)))

(defun wrap (pkg name fn)
  (let* ((sym (find-symbol name pkg))
         (orig (fdefinition sym)))
    (setf (fdefinition sym) (funcall fn orig))))

(dolist (pkg '(:gp :sgp))
  (wrap pkg "EXTEND-PLAN-GRAPH"
        (lambda (orig)
          (lambda (pg)
            (finish-output)              ; postęp ("Levels 1 2 3...") widoczny na bieżąco
            (setf *last-pg* pg
                  *current* (list :expansion 0.0 :mutex 0.0 :search 0.0))
            (let* ((t0 (now)) (r (funcall orig pg)))
              (setf (getf *current* :expansion) (secs t0))
              (setf *level-times* (append *level-times* (list *current*)))
              r))))
  (wrap pkg "DERIVE-MUTEX"
        (lambda (orig)
          (lambda (&rest args)
            (let* ((t0 (now)) (r (apply orig args)))
              (when *current* (incf (getf *current* :mutex) (secs t0)))
              r))))
  (wrap pkg "FIND-PLANS-IN-PG"
        (lambda (orig)
          (lambda (&rest args)
            (let* ((t0 (now)) (r (apply orig args)))
              (when *current* (setf (getf (car (last *level-times*)) :search) (secs t0)))
              (finish-output)
              r)))))

;;; Jednostki czasu: JSON w milisekundach, terminal w czytelnej postaci
(defun ms (seconds) (/ (round (* seconds 1000000)) 1000.0))   ; ms z dokładnością do 0,001

(defun human-time (seconds)
  (cond ((< seconds 0.001) (format nil "~,3F ms" (* seconds 1000)))
        ((< seconds 1) (format nil "~,1F ms" (* seconds 1000)))
        ((< seconds 60) (format nil "~,2F s" seconds))
        (t (multiple-value-bind (m s) (floor seconds 60)
             (format nil "~D min ~D s" m (round s))))))

;;; ------------------------------------------------------------------
;;; Problemy w pliku, wybór plannera

(defun problems-in-file (file)
  (let ((*package* (find-package :domains)) (result '()))
    (with-open-file (in file)
      (loop for form = (read in nil in)
            until (eq form in)
            when (and (consp form) (symbolp (car form))
                      (string= (symbol-name (car form)) "DEFINE")
                      (consp (second form))
                      (string= (symbol-name (car (second form))) "PROBLEM"))
              do (push (second (second form)) result)))
    (nreverse result)))

(defun load-domain-file (file)
  (let ((*package* (find-package :domains)))
    (handler-bind ((warning #'muffle-warning))
      (load file))))

(defun mentions-p (tree names)
  (cond ((symbolp tree) (and tree (member (symbol-name tree) names :test #'string=)))
        ((consp tree) (or (mentions-p (car tree) names) (mentions-p (cdr tree) names)))))

(defun planner-for (problem)
  (let* ((p (dcall "GET-PROBLEM" problem))
         (d (dcall "GET-DOMAIN" (dcall "PROBLEM-DOMAIN" p))))
    (if (or (intersection (append (dcall "DOMAIN-REQUIREMENTS" d)
                                  (dcall "PROBLEM-REQUIREMENTS" p))
                          '(:uncertainty :sensing))
            (mentions-p (dcall "PROBLEM-INIT" p) '("ONEOF" "OR" "UNCERTAIN" "IFF" "UNKNOWN"))
            (mentions-p (mapcar (dom "OP-EFFECT") (dcall "DOMAIN-OPERATORS" d)) '("OBSERVES")))
        :sgp :gp)))

;;; ------------------------------------------------------------------
;;; Opis węzłów grafu

(defun str (x)
  (let ((*package* (find-package :domains)) (*print-pretty* nil))
    (string-downcase (princ-to-string x))))

(defun atom-label (x)
  "Zapis jak w PDDL.pdf: (at ball1 rooma) -> at (ball1, rooma); (not P) -> ¬ P."
  (cond ((atom x) (str x))
        ((and (symbolp (car x)) (string= (symbol-name (car x)) "NOT"))
         (format nil "¬ ~A" (atom-label (second x))))
        ((null (cdr x)) (str (car x)))
        (t (format nil "~A (~{~A~^, ~})" (str (car x)) (mapcar #'str (cdr x))))))

(defun noop-p (node planner)
  (if (eq planner :gp)
      (eq (pcall :gp "INST-COMP-COMPONENT" node) (find-symbol "PERSIST" :gp))
      (eq (pcall :sgp "ACT-OPERATOR" node) (find-symbol "PERSIST" :sgp))))

(defun action-label (node planner)
  (if (eq planner :gp)
      (let ((c (pcall :gp "INST-COMP-COMPONENT" node)))
        (if (symbolp c)
            (format nil "no-op: ~A" (atom-label (pcall :gp "PROP-DESCRIPTION"
                                              (first (pcall :gp "INST-COMP-PRECONDITIONS" node)))))
            (let ((op (dcall "COMP-OPERATOR" c)))
              (atom-label (cons (dcall "OP-NAME" op)
                         (funcall (find-symbol "PLUG" :logic)
                                  (dcall "OP-VARIABLES" op)
                                  (if (symbol-value (find-symbol "*GROUND*" :gp))
                                      (pcall :gp "COMP-BINDINGS" c)
                                      (pcall :gp "INST-COMP-BINDINGS" node))))))))
      (let ((d (pcall :sgp "ACT-DESCRIPTION" node)))
        (if (noop-p node planner)
            (format nil "no-op: ~A" (atom-label (second d)))
            (atom-label d)))))

(defun action-pre (node planner)
  (pcall planner (if (eq planner :gp) "INST-COMP-PRECONDITIONS" "ACT-PRECONDITIONS") node))
(defun action-eff (node planner)
  (pcall planner (if (eq planner :gp) "INST-COMP-EFFECTS" "ACT-EFFECTS") node))
(defun node-mutex (node planner) (pcall planner "NODE-MUTEX" node))
(defun node-context (node planner)
  (if (eq planner :sgp) (pcall :sgp "NODE-CONTEXT" node) nil))

(defun level-props (level planner)
  "Lista węzłów-faktów poziomu. W SGP poziom to lista klastrów (fakt we wszystkich światach)."
  (if (eq planner :gp)
      level
      (loop for cluster in level append (pcall :sgp "CLUSTER-PROPS" cluster))))

(defun prop-label (node planner)
  (if (eq planner :gp)
      (atom-label (pcall :gp "PROP-DESCRIPTION" node))
      (atom-label (pcall :sgp "PROP-DESCRIPTION" node))))

(defun count-mutex-pairs (nodes planner)
  (/ (loop for n in nodes sum (length (node-mutex n planner))) 2))

;;; ------------------------------------------------------------------
;;; Statystyki kroków algorytmu -- nazwy jak w SGP (stat-gp) i w PDDL.pdf, tab. 2:
;;;   time-expansion  czas rozwinięcia grafu w danym kroku (zawiera time-mutex)
;;;   time-bc         czas sprawdzania osiągnięcia celu (backtracking)
;;;   time-mutex      czas wyznaczania wzajemnie wykluczających się relacji
;;;   graph-size      liczba akcji (z no-op) i propozycji
;;;   mutex-count     liczba mutexów akcji i propozycji (jak w SGP: każda para liczona 2 razy)
;;; Krok k tworzy poziom akcji 2k-1 i poziom propozycji 2k grafu planowania.

(defun mutex-count (nodes planner)
  (loop for n in nodes sum (length (node-mutex n planner))))

(defun step-stats (pg planner)
  (let* ((plevels (reverse (pcall planner "PG-PROPOSITION-LEVELS" pg)))
         (alevels (reverse (pcall planner "PG-ACTION-LEVELS" pg))))
    (loop for k from 1 below (length plevels)
          for props = (nth k plevels)
          for acts = (nth (1- k) alevels)
          for times = (nth (1- k) *level-times*)
          collect
          (list :step k
                :time-expansion (if times (getf times :expansion) 0.0)
                :time-bc (if times (getf times :search) 0.0)
                :time-mutex (if times (getf times :mutex) 0.0)
                :actions (length acts)
                :noops (count-if (lambda (a) (noop-p a planner)) acts)
                ;; jak stat-gp graph-size: w SGP liczone są propozycje bez podziału na światy
                :propositions (length props)
                :mutex-actions (mutex-count acts planner)
                :mutex-propositions (mutex-count (level-props props planner) planner)))))

(defun step-json (st)
  `(:obj ("step" . ,(getf st :step))
         ("time_expansion_ms" . ,(ms (getf st :time-expansion)))
         ("time_bc_ms" . ,(ms (getf st :time-bc)))
         ("time_mutex_ms" . ,(ms (getf st :time-mutex)))
         ("graph_size" . (:obj ("actions" . ,(getf st :actions))
                               ("propositions" . ,(getf st :propositions))))
         ("noops" . ,(getf st :noops))
         ("mutex_count" . (:obj ("actions" . ,(getf st :mutex-actions))
                                ("propositions" . ,(getf st :mutex-propositions))))))

(defun print-stats (stats)
  "Tabela w układzie tab. 5 i 6 z PDDL.pdf (czasy w ms)."
  (when stats
    (format t "~&~%~4A  ~14@A  ~9@A  ~10@A  ~18A  ~A~%"
            "Krok" "time-expansion" "time-bc" "time-mutex" "graph-size" "mutex-count")
    (format t "~4A  ~14@A  ~9@A  ~10@A  ~18A  ~A~%"
            "" "[ms]" "[ms]" "[ms]" "(akcje,propozycje)" "(akcje,propozycje)")
    (dolist (st stats)
      (format t "~4D  ~14,3F  ~9,3F  ~10,3F  ~18A  ~A~%"
              (getf st :step) (* 1000 (getf st :time-expansion)) (* 1000 (getf st :time-bc))
              (* 1000 (getf st :time-mutex))
              (format nil "(~D,~D)" (getf st :actions) (getf st :propositions))
              (format nil "(~D,~D)" (getf st :mutex-actions) (getf st :mutex-propositions))))
    (flet ((sum (k) (* 1000 (loop for st in stats sum (getf st k)))))
      (format t "~4@A  ~14,3F  ~9,3F  ~10,3F~%" "Σ" (sum :time-expansion) (sum :time-bc) (sum :time-mutex))
      (format t "~4@A  time-expansion + time-bc = ~,3F ms~%" "Σ" (+ (sum :time-expansion) (sum :time-bc))))))

;;; ------------------------------------------------------------------
;;; Plan

(defun plan-steps (plan planner)
  "Plan jako lista kroków; każdy krok to lista (etykieta . światy-do-pominięcia)."
  (loop for step in plan
        collect (loop for a in step
                      collect (if (and (eq planner :sgp) (consp a) (consp (car a)))
                                  (cons (atom-label (car a)) (cdr a))
                                  (cons (atom-label a) nil)))))

(defun plan-json (steps)
  (loop for step in steps
        for i from 1
        collect `(:obj ("step" . ,i)
                       ("actions" . ,(loop for (label . skip) in step
                                           collect `(:obj ("action" . ,label)
                                                          ,@(when skip
                                                              `(("skip_in_worlds" . ,skip)))))))))

;;; ------------------------------------------------------------------
;;; Graf (dane do rysunku)

(defun graph-json (pg planner steps)
  (let* ((plevels (reverse (pcall planner "PG-PROPOSITION-LEVELS" pg)))
         (alevels (reverse (pcall planner "PG-ACTION-LEVELS" pg)))
         (n (length alevels))
         (offset (- n (length steps)))
         (ids (make-hash-table :test #'eq))
         (counter 0))
    (flet ((id (node) (or (gethash node ids) (setf (gethash node ids) (incf counter)))))
      ;; nadaj identyfikatory w kolejności poziomów
      (loop for lvl in plevels do (dolist (p (level-props lvl planner)) (id p)))
      (dolist (lvl alevels) (dolist (a lvl) (id a)))
      (cons :arr
            (loop for i from 0 to n
                  for props = (level-props (nth i plevels) planner)
                  for acts = (and (> i 0) (nth (1- i) alevels))
                  for plan-labels = (let ((k (- i 1 offset)))
                                      (and (> i 0) (>= k 0) (< k (length steps))
                                           (mapcar #'car (nth k steps))))
                  collect
                  `(:obj
                    ("level" . ,i)
                    ("props" . (:arr ,@(loop for p in props
                                             collect `(:obj ("id" . ,(id p))
                                                            ("label" . ,(prop-label p planner))
                                                            ,@(let ((c (node-context p planner)))
                                                                (when c `(("ctx" . ,(str c)))))
                                                            ("mutex" . (:arr ,@(mapcar #'id (node-mutex p planner))))))))
                    ("actions" . (:arr ,@(loop for a in acts
                                               for label = (action-label a planner)
                                               collect `(:obj ("id" . ,(id a))
                                                              ("label" . ,label)
                                                              ("noop" . ,(if (noop-p a planner) :true :false))
                                                              ("plan" . ,(if (member label plan-labels :test #'string=) :true :false))
                                                              ,@(let ((c (node-context a planner)))
                                                                  (when c `(("ctx" . ,(str c)))))
                                                              ("pre" . (:arr ,@(mapcar #'id (action-pre a planner))))
                                                              ("eff" . (:arr ,@(mapcar #'id (action-eff a planner))))
                                                              ("mutex" . (:arr ,@(mapcar #'id (node-mutex a planner))))))))))))))

;;; ------------------------------------------------------------------
;;; JSON

(defun json-string (s stream)
  (write-char #\" stream)
  (loop for c across s do
    (case c
      (#\" (write-string "\\\"" stream))
      (#\\ (write-string "\\\\" stream))
      (#\Newline (write-string "\\n" stream))
      (#\Return (write-string "\\r" stream))
      (#\Tab (write-string "\\t" stream))
      (t (if (< (char-code c) 32)
             (format stream "\\u~4,'0X" (char-code c))
             (write-char c stream)))))
  (write-char #\" stream))

(defun json (x stream &optional (indent 0) (pretty t))
  (labels ((nl (ind) (when pretty (terpri stream) (dotimes (i ind) (write-char #\Space stream)))))
    (cond ((eq x :true) (write-string "true" stream))
          ((or (eq x :false) (null x)) (write-string (if (null x) "[]" "false") stream))
          ((eq x :null) (write-string "null" stream))
          ((stringp x) (json-string x stream))
          ((integerp x) (format stream "~D" x))
          ((rationalp x) (format stream "~,3F" (float x)))
          ((floatp x) (format stream "~,3F" x))
          ((symbolp x) (json-string (str x) stream))
          ((and (consp x) (eq (car x) :obj))
           (write-char #\{ stream)
           (loop for (pair . rest) on (cdr x) do
             (nl (+ indent 2))
             (json-string (car pair) stream)
             (write-string (if pretty ": " ":") stream)
             (json (cdr pair) stream (+ indent 2) pretty)
             (when rest (write-char #\, stream)))
           (nl indent)
           (write-char #\} stream))
          (t
           (let ((items (if (eq (car x) :arr) (cdr x) x))
                 (flat (every #'atom (if (eq (car x) :arr) (cdr x) x))))
             (write-char #\[ stream)
             (loop for (item . rest) on items do
               (unless flat (nl (+ indent 2)))
               (json item stream (+ indent 2) pretty)
               (when rest (write-string (if flat ", " ",") stream)))
             (unless (or flat (null items)) (nl indent))
             (write-char #\] stream))))))

;;; ------------------------------------------------------------------
;;; Rysunek: samodzielny plik HTML (SVG + JS), bez zewnętrznych bibliotek

(defun read-template ()
  (with-open-file (in (make-pathname :name "graph" :type "html" :defaults *engine-dir*))
    (let ((s (make-string (file-length in))))
      (subseq s 0 (read-sequence s in)))))

(defun replace-all (string old new)
  (with-output-to-string (out)
    (loop with start = 0
          for pos = (search old string :start2 start)
          do (write-string string out :start start :end (or pos (length string)))
          while pos
          do (write-string new out) (setf start (+ pos (length old))))))

(defun write-graph-html (path result-json graph)
  (let ((data (with-output-to-string (s)
                (json `(:obj ("result" . ,result-json) ("graph" . ,graph)) s 0 nil))))
    ;; "</" nie może wystąpić wewnątrz <script>
    (setf data (replace-all data "</" "<\\/"))
    (with-open-file (out path :direction :output :if-exists :supersede)
      (write-string (replace-all (read-template) "/*__DATA__*/null" data) out))))

(defun open-in-browser (path)
  (let ((p (sb-ext:native-namestring path)))
    (ignore-errors
     #+win32 (sb-ext:run-program "cmd" (list "/c" "start" "" p) :search t :wait nil)
     #+darwin (sb-ext:run-program "open" (list p) :search t :wait nil)
     #-(or win32 darwin) (sb-ext:run-program "xdg-open" (list p) :search t :wait nil))))

;;; ------------------------------------------------------------------
;;; Główna procedura

(defun timestamp ()
  (multiple-value-bind (s mi h d mo y) (get-decoded-time)
    (format nil "~4,'0D-~2,'0D-~2,'0DT~2,'0D:~2,'0D:~2,'0D" y mo d h mi s)))

(defun safe-name (s)
  (map 'string (lambda (c) (if (or (alphanumericp c) (find c "-_.")) c #\_)) s))

(defun print-plan (steps planner)
  (format t "~&~%ROZWIĄZANIE (~A), liczba kroków planu: ~D~%"
          (if (eq planner :sgp) "SGP, plan warunkowy" "GP") (length steps))
  (loop for step in steps for i from 1 do
    (format t "~3D°~%" i)
    (loop for (label . skip) in step do
      (format t "     ~A~@[   ; pomiń w światach ~{~A~^ ~}~]~%" label skip))))

(defun usage ()
  (format t "~&Użycie: sbcl --script engine/run.lisp <plik.pddl> [problem] [--name NAZWA] ~
             [--graph] [--no-open] [--list] [--gp|--sgp] [--levels N] [--trace FLAGA]~%"))

(defun main (args)
  (let (file problem name graph (open t) list-only planner (levels 20) trace)
    (loop while args do
      (let ((a (string-trim " " (pop args))))
        (cond ((string= a "") nil)
              ((string= a "--name") (let ((v (string-trim " " (or (pop args) ""))))
                                      (unless (string= v "") (setf name v))))
              ((string= a "--graph") (setf graph t))
              ((string= a "--no-open") (setf open nil))
              ((string= a "--list") (setf list-only t))
              ((string= a "--gp") (setf planner :gp))
              ((string= a "--sgp") (setf planner :sgp))
              ((string= a "--levels") (let ((v (string-trim " " (or (pop args) ""))))
                                        (unless (string= v "")
                                          (setf levels (or (parse-integer v :junk-allowed t)
                                                           (progn (format t "Zła liczba kroków: ~A~%" v)
                                                                  (return-from main 2)))))))
              ((string= a "--trace") (push (pop args) trace))
              ((member a '("-h" "--help") :test #'string=) (usage) (return-from main 0))
              ((null file) (setf file a))
              ((null problem) (setf problem a))
              (t (format t "Nieznany argument: ~A~%" a) (usage) (return-from main 2)))))
    (unless file (usage) (return-from main 2))
    (unless (probe-file file) (format t "Brak pliku: ~A~%" file) (return-from main 2))
    (let ((problems (problems-in-file file)))
      (format t "Plik: ~A~%Problemy: ~{~(~A~)~^, ~}~%" (file-namestring file) problems)
      (when list-only (return-from main 0))
      (when (null problems) (format t "W pliku nie ma (define (problem ...)).~%") (return-from main 1))
      (load-domain-file file)
      (let* ((psym (if problem
                       (or (find-symbol (string-upcase problem) :domains)
                           (progn (format t "Nie ma problemu ~A w pliku.~%" problem)
                                  (return-from main 2)))
                       (first problems)))
             (planner (or planner (planner-for psym)))
             (pkg (if (eq planner :sgp) :sgp :gp))
             (name (safe-name (or name (format nil "~(~A~)-~A" psym
                                               (remove #\: (substitute #\- #\T (timestamp)))))))
             (json-path (merge-pathnames (format nil "results/~A.json" name) *root*))
             (html-path (merge-pathnames (format nil "results/~A.html" name) *root*))
             (log (make-string-output-stream)))
        (dolist (f trace)
          (setf (symbol-value (find-symbol (format nil "*TRACE-GP-~A*" (string-upcase f)) pkg)) t))
        (format t "~&~%========== ~(~A~) [~(~A~)] ==========~%" psym planner)
        (setf *last-pg* nil *level-times* nil *current* nil)
        (let* ((warnings '())
               (t0 (now))
               (plan (let ((*standard-output* (make-broadcast-stream *standard-output* log))
                           (*package* (find-package pkg)))
                       (handler-bind ((warning
                                        (lambda (w)
                                          (let ((msg (substitute #\Space #\Newline (princ-to-string w))))
                                            (push msg warnings)
                                            (format t "~&UWAGA: ~A~%" msg))
                                          (muffle-warning w))))
                         (pcall pkg "PLAN" psym :levels levels))))
               (total (secs t0))
               (steps (plan-steps plan planner))
               (stats (if *last-pg* (step-stats *last-pg* planner) nil))
               (graph-levels (length stats))
               (stop (cond (plan "plan_found")
                           ((>= graph-levels levels) "level_limit")
                           ((null warnings) "leveled_off")
                           (t "unsupported")))
               (result
                 `(:obj
                   ("name" . ,name)
                   ("created" . ,(timestamp))
                   ("file" . ,(file-namestring file))
                   ("problem" . ,(str psym))
                   ("domain" . ,(str (dcall "PROBLEM-DOMAIN" (dcall "GET-PROBLEM" psym))))
                   ("planner" . ,(str planner))
                   ("max_steps" . ,levels)
                   ("solved" . ,(if plan :true :false))
                   ("stop_reason" . ,stop)
                   ("warnings" . (:arr ,@(reverse warnings)))
                   ("plan_steps" . ,(length steps))
                   ("plan_actions" . ,(loop for s in steps sum (length s)))
                   ,@(when (and (eq planner :sgp) *last-pg*)
                       `(("worlds" . ,(pcall :sgp "PG-CONTEXTS" *last-pg*))))
                   ("algorithm_steps" . ,graph-levels)
                   ("initial_propositions" . ,(if *last-pg*
                                                  (length (car (last (pcall planner "PG-PROPOSITION-LEVELS" *last-pg*))))
                                                  0))
                   ("time_ms" . (:obj
                                 ("expansion" . ,(ms (loop for x in stats sum (getf x :time-expansion))))
                                 ("bc" . ,(ms (loop for x in stats sum (getf x :time-bc))))
                                 ("mutex" . ,(ms (loop for x in stats sum (getf x :time-mutex))))
                                 ("total" . ,(ms total))))
                   ("steps" . (:arr ,@(mapcar #'step-json stats)))
                   ("plan" . (:arr ,@(plan-json steps)))
                   ("planner_output" . ,(get-output-stream-string log))
                   ("sbcl" . ,(lisp-implementation-version)))))
          (cond (plan (print-plan steps planner))
                ((string= stop "unsupported")
                 (format t "~&~%BRAK PLANU: domena używa konstrukcji nieobsługiwanych przez SGP (patrz UWAGA).~%"))
                ((string= stop "level_limit")
                 (format t "~&~%BRAK PLANU: osiągnięto limit ~D kroków algorytmu. Plan może istnieć ~
                            przy większym limicie.~%" levels))
                (t (format t "~&~%BRAK PLANU: graf się wyrównał po ~D krokach algorytmu, ~
                              plan nie istnieje.~%" graph-levels)))
          (print-stats stats)
          (format t "~&Czas: ~A, kroki algorytmu: ~D~%" (human-time total) graph-levels)
          (ensure-directories-exist json-path)
          (with-open-file (out json-path :direction :output :if-exists :supersede)
            (json result out) (terpri out))
          (format t "Wynik: ~A~%" (sb-ext:native-namestring json-path))
          (when (and graph *last-pg*)
            (write-graph-html html-path result (graph-json *last-pg* planner steps))
            (format t "Graf:  ~A~%" (sb-ext:native-namestring html-path))
            (when open (open-in-browser html-path)))
          (if plan 0 1))))))

(sb-ext:exit :code (handler-case (main (rest sb-ext:*posix-argv*))
                     (sb-sys:interactive-interrupt () 130)
                     (error (e) (format t "~&~%BŁĄD: ~A~%" e) 3))
             :abort nil)

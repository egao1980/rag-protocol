(in-package #:rag-protocol)

;;; Analyzer role: tokenize → optional stopword drop → optional stem.
;;; In-tree SIMPLE-ANALYZER. Product tokenizers can subclass RAG-ANALYZER.

(defclass rag-analyzer () ())

(defgeneric analyze (analyzer text)
  (:documentation "TEXT → list of tokens (lowercase strings). NIL/empty → ()."))

(defun tokenize (text)
  "Lowercase alphanumeric tokens (CL characters). Empty / NIL → ()."
  (let ((s (string-downcase (or text "")))
        (out '())
        (start nil))
    (loop for i from 0 below (length s)
          for c = (char s i)
          for alnum = (alphanumericp c)
          do (cond
               ((and alnum (null start))
                (setf start i))
               ((and (not alnum) start)
                (push (subseq s start i) out)
                (setf start nil)))
          finally (when start
                    (push (subseq s start) out)))
    (nreverse out)))

(defparameter *english-stopwords*
  '("a" "about" "above" "after" "again" "against" "all" "am" "an" "and" "any" "are"
    "as" "at" "be" "because" "been" "before" "being" "below" "between" "both" "but"
    "by" "can" "did" "do" "does" "doing" "down" "during" "each" "few" "for" "from"
    "further" "had" "has" "have" "having" "he" "her" "here" "hers" "herself" "him"
    "himself" "his" "how" "i" "if" "in" "into" "is" "it" "its" "itself" "just" "me"
    "more" "most" "my" "myself" "no" "nor" "not" "now" "of" "off" "on" "once" "only"
    "or" "other" "our" "ours" "ourselves" "out" "over" "own" "same" "she" "should"
    "so" "some" "such" "than" "that" "the" "their" "theirs" "them" "themselves"
    "then" "there" "these" "they" "this" "those" "through" "to" "too" "under"
    "until" "up" "very" "was" "we" "were" "what" "when" "where" "which" "while"
    "who" "whom" "why" "will" "with" "you" "your" "yours" "yourself" "yourselves"))

(defun make-stopword-table (words)
  (let ((table (make-hash-table :test 'equal)))
    (dolist (w words table)
      (setf (gethash (string-downcase w) table) t))))

(defparameter *english-stopword-table*
  (make-stopword-table *english-stopwords*))

(defun english-stopword-p (token)
  (and token (gethash token *english-stopword-table*)))

;;; Porter stemmer (Porter 1980). Token is already lowercase.

(defun %porter-vowel-p (s i)
  (let ((c (char s i)))
    (case c
      ((#\a #\e #\i #\o #\u) t)
      (#\y (and (plusp i) (not (%porter-vowel-p s (1- i)))))
      (t nil))))

(defun %porter-m (s end)
  "Measure of S[0..END) ."
  (let ((n 0)
        (i 0))
    (loop
      (when (>= i end) (return-from %porter-m n))
      (when (%porter-vowel-p s i) (return))
      (incf i))
    (incf i)
    (loop
      (loop
        (when (>= i end) (return-from %porter-m n))
        (when (not (%porter-vowel-p s i)) (return))
        (incf i))
      (incf i)
      (incf n)
      (loop
        (when (>= i end) (return-from %porter-m n))
        (when (%porter-vowel-p s i) (return))
        (incf i))
      (incf i))))

(defun %porter-has-vowel (s end)
  (loop for i from 0 below end
        thereis (%porter-vowel-p s i)))

(defun %porter-double-c (s end)
  (and (>= end 2)
       (char= (char s (1- end)) (char s (- end 2)))
       (not (%porter-vowel-p s (1- end)))))

(defun %porter-cvc (s end)
  (and (>= end 3)
       (not (%porter-vowel-p s (1- end)))
       (%porter-vowel-p s (- end 2))
       (not (%porter-vowel-p s (- end 3)))
       (not (member (char s (1- end)) '(#\w #\x #\y) :test #'char=))))

(defun %porter-ends (s end suffix)
  (let ((n (length suffix)))
    (and (>= end n)
         (string= s suffix :start1 (- end n) :end1 end))))

(defun porter-stem (word)
  "Porter (1980) stem of a lowercase token. Words shorter than 3 are unchanged."
  (let ((w (or word "")))
    (when (< (length w) 3)
      (return-from porter-stem w))
    (let ((s (make-array (length w) :element-type 'character
                         :adjustable t :fill-pointer (length w)
                         :initial-contents w)))
      (labels ((end () (fill-pointer s))
               (set-end (n) (setf (fill-pointer s) n))
               (ends (suffix) (%porter-ends s (end) suffix))
               (chop (n) (set-end (- (end) n)))
               (replace-suffix (old new)
                 (chop (length old))
                 (loop for c across new do (vector-push-extend c s)))
               (m () (%porter-m s (end)))
               (r (old new)
                 (when (plusp (%porter-m s (- (end) (length old))))
                   (replace-suffix old new))))
        ;; 1a
        (cond
          ((ends "sses") (chop 2))
          ((ends "ies") (chop 2))
          ((ends "ss"))
          ((ends "s") (chop 1)))
        ;; 1b
        (cond
          ((ends "eed")
           (when (plusp (%porter-m s (- (end) 3)))
             (chop 1)))
          ((and (ends "ed") (%porter-has-vowel s (- (end) 2)))
           (chop 2)
           (cond
             ((or (ends "at") (ends "bl") (ends "iz"))
              (vector-push-extend #\e s))
             ((and (%porter-double-c s (end))
                   (not (member (char s (1- (end))) '(#\l #\s #\z) :test #'char=)))
              (chop 1))
             ((= (m) 1)
              (when (%porter-cvc s (end))
                (vector-push-extend #\e s)))))
          ((and (ends "ing") (%porter-has-vowel s (- (end) 3)))
           (chop 3)
           (cond
             ((or (ends "at") (ends "bl") (ends "iz"))
              (vector-push-extend #\e s))
             ((and (%porter-double-c s (end))
                   (not (member (char s (1- (end))) '(#\l #\s #\z) :test #'char=)))
              (chop 1))
             ((= (m) 1)
              (when (%porter-cvc s (end))
                (vector-push-extend #\e s))))))
        ;; 1c
        (when (and (ends "y") (%porter-has-vowel s (1- (end))))
          (setf (char s (1- (end))) #\i))
        ;; 2
        (when (>= (end) 3)
          (case (char s (- (end) 2))
            (#\a (cond ((ends "ational") (r "ational" "ate"))
                       ((ends "tional") (r "tional" "tion"))))
            (#\c (cond ((ends "enci") (r "enci" "ence"))
                       ((ends "anci") (r "anci" "ance"))))
            (#\e (when (ends "izer") (r "izer" "ize")))
            (#\l (cond ((ends "abli") (r "abli" "able"))
                       ((ends "alli") (r "alli" "al"))
                       ((ends "entli") (r "entli" "ent"))
                       ((ends "eli") (r "eli" "e"))
                       ((ends "ousli") (r "ousli" "ous"))))
            (#\o (cond ((ends "ization") (r "ization" "ize"))
                       ((ends "ation") (r "ation" "ate"))
                       ((ends "ator") (r "ator" "ate"))))
            (#\s (cond ((ends "alism") (r "alism" "al"))
                       ((ends "iveness") (r "iveness" "ive"))
                       ((ends "fulness") (r "fulness" "ful"))
                       ((ends "ousness") (r "ousness" "ous"))))
            (#\t (cond ((ends "aliti") (r "aliti" "al"))
                       ((ends "iviti") (r "iviti" "ive"))
                       ((ends "biliti") (r "biliti" "ble"))))))
        ;; 3
        (cond
          ((ends "icate") (r "icate" "ic"))
          ((ends "ative") (r "ative" ""))
          ((ends "alize") (r "alize" "al"))
          ((ends "iciti") (r "iciti" "ic"))
          ((ends "ical") (r "ical" "ic"))
          ((ends "ful") (r "ful" ""))
          ((ends "ness") (r "ness" "")))
        ;; 4 — switch is on the second-last letter (Porter 1980).
        (when (>= (end) 2)
          (let ((matched
                 (case (char s (- (end) 2))
                   (#\a (when (ends "al") 2))
                   (#\c (cond ((ends "ance") 4)
                              ((ends "ence") 4)))
                   (#\e (when (ends "er") 2))
                   (#\i (when (ends "ic") 2))
                   (#\l (cond ((ends "able") 4)
                              ((ends "ible") 4)))
                   (#\n (cond ((ends "ant") 3)
                              ((ends "ement") 5)
                              ((ends "ment") 4)
                              ((ends "ent") 3)))
                   (#\o (cond ((and (ends "ion")
                                    (>= (end) 4)
                                    (member (char s (- (end) 4)) '(#\s #\t)
                                            :test #'char=))
                               3)
                              ((ends "ou") 2)))
                   (#\s (when (ends "ism") 3))
                   (#\t (cond ((ends "ate") 3)
                              ((ends "iti") 3)))
                   (#\u (when (ends "ous") 3))
                   (#\v (when (ends "ive") 3))
                   (#\z (when (ends "ize") 3)))))
            (when (and matched (> (%porter-m s (- (end) matched)) 1))
              (chop matched))))
        ;; 5a
        (when (ends "e")
          (let ((mm (%porter-m s (1- (end)))))
            (when (or (> mm 1)
                      (and (= mm 1) (not (%porter-cvc s (1- (end))))))
              (chop 1))))
        ;; 5b
        (when (and (> (m) 1)
                   (%porter-double-c s (end))
                   (char= (char s (1- (end))) #\l))
          (chop 1))
        (coerce s 'string)))))

(defun %coerce-stopwords (stopwords)
  (etypecase stopwords
    (null nil)
    ((eql :english) *english-stopword-table*)
    (hash-table stopwords)
    (list (make-stopword-table stopwords))))

(defun %apply-stemmer (stemmer token)
  (etypecase stemmer
    (null token)
    ((eql :porter) (porter-stem token))
    (function (funcall stemmer token))))

(defclass simple-analyzer (rag-analyzer)
  ((stemmer :initarg :stemmer :accessor simple-analyzer-stemmer :initform nil)
   (stopwords :initarg :stopwords :accessor simple-analyzer-stopwords :initform nil)
   (stop-table :accessor simple-analyzer-stop-table :initform nil)))

(defun make-simple-analyzer (&key stemmer stopwords)
  (let ((a (make-instance 'simple-analyzer :stemmer stemmer :stopwords stopwords)))
    (setf (simple-analyzer-stop-table a) (%coerce-stopwords stopwords))
    a))

(defmethod analyze ((analyzer rag-analyzer) text)
  (declare (ignore text))
  (error 'rag-missing-backend
         :role :analyzer
         :message (format nil "~a does not implement analyze" (class-of analyzer))))

(defmethod analyze ((analyzer null) text)
  (analyze (make-simple-analyzer) text))

(defmethod analyze ((analyzer simple-analyzer) text)
  (let ((table (simple-analyzer-stop-table analyzer))
        (stem (simple-analyzer-stemmer analyzer))
        (out '()))
    (dolist (tok (tokenize text))
      (unless (and table (gethash tok table))
        (push (%apply-stemmer stem tok) out)))
    (nreverse (delete "" out :test #'equal))))

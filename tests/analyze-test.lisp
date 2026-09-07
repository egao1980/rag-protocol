(in-package #:rag-protocol/tests)

(deftest tokenize-basic
  (ok (equal '("hello" "world") (rag-protocol:tokenize "Hello, world!")))
  (ok (null (rag-protocol:tokenize "")))
  (ok (null (rag-protocol:tokenize nil))))

(deftest porter-classic
  (ok (equal "caress" (rag-protocol:porter-stem "caresses")))
  (ok (equal "poni" (rag-protocol:porter-stem "ponies")))
  (ok (equal "ti" (rag-protocol:porter-stem "ties")))
  (ok (equal "caress" (rag-protocol:porter-stem "caress")))
  (ok (equal "cat" (rag-protocol:porter-stem "cats")))
  (ok (equal "feed" (rag-protocol:porter-stem "feed")))
  (ok (equal "agre" (rag-protocol:porter-stem "agreed")))
  (ok (equal "plaster" (rag-protocol:porter-stem "plastered")))
  (ok (equal "bled" (rag-protocol:porter-stem "bled")))
  (ok (equal "motor" (rag-protocol:porter-stem "motoring")))
  (ok (equal "sing" (rag-protocol:porter-stem "sing")))
  (ok (equal "hop" (rag-protocol:porter-stem "hopping")))
  (ok (equal "file" (rag-protocol:porter-stem "filing")))
  (ok (equal "relat" (rag-protocol:porter-stem "relational")))
  (ok (equal "condit" (rag-protocol:porter-stem "conditional")))
  (ok (equal "ration" (rag-protocol:porter-stem "rational")))
  (ok (equal "hi" (rag-protocol:porter-stem "hi"))))

(deftest english-stopwords
  (ok (rag-protocol:english-stopword-p "the"))
  (ok (rag-protocol:english-stopword-p "and"))
  (ng (rag-protocol:english-stopword-p "apple")))

(deftest simple-analyzer-stem-stop
  (let ((a (rag-protocol:make-simple-analyzer :stemmer :porter :stopwords :english)))
    (ok (equal '("run" "cat")
               (rag-protocol:analyze a "the running cats")))
    (ok (null (rag-protocol:analyze a "the and or")))))

(deftest analyze-null-defaults
  (ok (equal '("hello" "world") (rag-protocol:analyze nil "Hello, world!"))))

(deftest rrf-and-linear-fuse
  (let* ((a (rag-protocol:make-rag-hit
             :chunk (rag-protocol:make-rag-chunk :id "a" :text "a") :score 1f0))
         (b (rag-protocol:make-rag-hit
             :chunk (rag-protocol:make-rag-chunk :id "b" :text "b") :score 1f0))
         (rrf (rag-protocol:fuse (rag-protocol:make-rrf-fusion)
                                 (list (list a) (list b a)) :top-k 2))
         (lin (rag-protocol:linear-fuse
               (list (list a (rag-protocol:make-rag-hit
                              :chunk (rag-protocol:make-rag-chunk :id "b" :text "b")
                              :score 0f0))
                     (list b))
               :weights '(1 0) :top-k 2)))
    (ok (equal "a" (rag-protocol:rag-chunk-id
                    (rag-protocol:rag-hit-chunk (first rrf)))))
    (ok (equal "a" (rag-protocol:rag-chunk-id
                    (rag-protocol:rag-hit-chunk (first lin)))))
    (ok (> (rag-protocol:rag-hit-score (first lin))
           (rag-protocol:rag-hit-score (second lin))))))

(deftest sparse-dot-and-encode
  (ok (= 0f0 (rag-protocol:sparse-dot '(("x" . 1f0)) '(("y" . 1f0)))))
  (ok (< (abs (- 2f0 (rag-protocol:sparse-dot '(("a" . 2f0)) '(("a" . 1f0)))))
         1e-6))
  (let ((enc (rag-protocol:make-simple-sparse-encoder)))
    (let ((vec (rag-protocol:encode-sparse enc "cat cat dog")))
      (ok (assoc "cat" vec :test #'equal))
      (ok (> (cdr (assoc "cat" vec :test #'equal))
             (cdr (assoc "dog" vec :test #'equal))))))
  (ok (equal '(("z" . 1f0))
             (rag-protocol:query-sparse
              (rag-protocol:make-rag-query :sparse '(("z" . 1f0))))))
  (ok (null (rag-protocol:query-sparse "nope"))))

(deftest pipeline-fills-sparse
  (let* ((store (rag-protocol:make-mock-vector-store))
         (pipe (rag-protocol:make-rag-pipeline
                :store store
                :embedder (llm-protocol:make-mock-llm-backend)
                :chunker (rag-protocol:make-passthrough-chunker)
                :sparse-encoder (rag-protocol:make-simple-sparse-encoder)))
         (chunks (rag-protocol:ingest
                  pipe (list (rag-protocol:make-rag-document :id "a" :text "alpha")))))
    (ok (rag-protocol:rag-chunk-sparse (first chunks)))))

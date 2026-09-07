(in-package #:rag-protocol/tests)

(defun %vec (&rest xs)
  (map 'vector (lambda (x) (float x 1f0)) xs))

(defun %chunk (id text emb)
  (rag-protocol:make-rag-chunk :id id :document-id "d" :text text :embedding emb))

(deftest no-store-signals
  (let ((rag-protocol:*rag-store* nil))
    (ok (signals (rag-protocol:query-store nil (%vec 1 0))
                 'rag-protocol:rag-missing-backend))))

(deftest passthrough-chunk
  (let ((chunks (rag-protocol:chunk (rag-protocol:make-passthrough-chunker)
                                    (rag-protocol:make-rag-document
                                     :id "doc" :text "hello"))))
    (ok (= 1 (length chunks)))
    (ok (equal "doc:0" (rag-protocol:rag-chunk-id (first chunks))))
    (ok (equal "hello" (rag-protocol:rag-chunk-text (first chunks))))))

(deftest coerce-string-document
  (let ((d (rag-protocol:coerce-document "hi")))
    (ok (rag-protocol:rag-document-p d))
    (ok (equal "hi" (rag-protocol:rag-document-text d)))))

(deftest cosine-identical
  (ok (< (abs (- 1f0 (rag-protocol:cosine-similarity (%vec 1 0 0) (%vec 1 0 0))))
         1e-6)))

(deftest cosine-orthogonal
  (ok (< (abs (rag-protocol:cosine-similarity (%vec 1 0) (%vec 0 1)))
         1e-6)))

(deftest cosine-zero
  (ok (= 0f0 (rag-protocol:cosine-similarity (%vec 0 0) (%vec 1 0)))))

(deftest cosine-dim-mismatch
  (ok (signals (rag-protocol:cosine-similarity (%vec 1) (%vec 1 0))
               'rag-protocol:rag-dimension-mismatch)))

(deftest mock-upsert-query
  (let ((store (rag-protocol:make-mock-vector-store)))
    (rag-protocol:upsert store
                         (list (%chunk "a" "alpha" (%vec 1 0))
                               (%chunk "b" "beta" (%vec 0 1))))
    (let ((hits (rag-protocol:query-store store (%vec 1 0) :top-k 2)))
      (ok (= 2 (length hits)))
      (ok (equal "a" (rag-protocol:rag-chunk-id
                      (rag-protocol:rag-hit-chunk (first hits)))))
      (ok (= 1 (rag-protocol:rag-hit-rank (first hits))))
      (ok (> (rag-protocol:rag-hit-score (first hits))
             (rag-protocol:rag-hit-score (second hits)))))))

(deftest mock-query-filter
  (let ((store (rag-protocol:make-mock-vector-store)))
    (rag-protocol:upsert store
                         (list (%chunk "a" "keep" (%vec 1 0))
                               (%chunk "b" "drop" (%vec 1 0))))
    (let ((hits (rag-protocol:query-store
                 store (%vec 1 0) :top-k 5
                 :filter (lambda (ch)
                           (equal "keep" (rag-protocol:rag-chunk-text ch))))))
      (ok (= 1 (length hits)))
      (ok (equal "a" (rag-protocol:rag-chunk-id
                      (rag-protocol:rag-hit-chunk (first hits))))))))

(deftest mock-delete
  (let ((store (rag-protocol:make-mock-vector-store)))
    (rag-protocol:upsert store (%chunk "a" "x" (%vec 1 0)))
    (ok (equal '("a") (rag-protocol:delete-ids store "a")))
    (ok (null (rag-protocol:query-store store (%vec 1 0) :top-k 5)))))

(deftest mock-dimension-mismatch
  (let ((store (rag-protocol:make-mock-vector-store)))
    (rag-protocol:upsert store (%chunk "a" "x" (%vec 1 0)))
    (ok (signals (rag-protocol:upsert store (%chunk "b" "y" (%vec 1 0 0)))
                 'rag-protocol:rag-dimension-mismatch))))

(deftest identity-rerank-truncates
  (let* ((hits (list (rag-protocol:make-rag-hit
                      :chunk (%chunk "a" "a" (%vec 1)) :score 0.1)
                     (rag-protocol:make-rag-hit
                      :chunk (%chunk "b" "b" (%vec 1)) :score 0.9)))
         (out (rag-protocol:rerank (rag-protocol:make-identity-reranker)
                                   "q" hits :top-k 1)))
    (ok (= 1 (length out)))
    (ok (equal "b" (rag-protocol:rag-chunk-id
                    (rag-protocol:rag-hit-chunk (first out)))))))

(deftest pipeline-ingest-retrieve
  (let* ((store (rag-protocol:make-mock-vector-store))
         (embedder (llm-protocol:make-mock-llm-backend))
         (pipe (rag-protocol:make-rag-pipeline
                :store store :embedder embedder
                :chunker (rag-protocol:make-passthrough-chunker))))
    (let ((chunks (rag-protocol:ingest
                   pipe (list (rag-protocol:make-rag-document :id "a" :text "alpha")
                              (rag-protocol:make-rag-document :id "b" :text "zzzzzz")))))
      (ok (= 2 (length chunks)))
      (ok (rag-protocol:rag-chunk-embedding (first chunks))))
    (let ((hits (rag-protocol:retrieve pipe "alpha" :top-k 2)))
      (ok (= 2 (length hits)))
      (ok (equal "alpha" (rag-protocol:rag-chunk-text
                          (rag-protocol:rag-hit-chunk (first hits))))))))

(deftest pipeline-retrieve-precomputed
  (let* ((store (rag-protocol:make-mock-vector-store))
         (pipe (rag-protocol:make-rag-pipeline :store store)))
    (rag-protocol:upsert store (%chunk "a" "x" (%vec 1 0)))
    (let ((hits (rag-protocol:retrieve pipe (%vec 1 0) :top-k 1)))
      (ok (equal "a" (rag-protocol:rag-chunk-id
                      (rag-protocol:rag-hit-chunk (first hits))))))))

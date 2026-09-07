(in-package #:rag-protocol/tests)

(deftest missing-store-use-value
  (let* ((store (rag-protocol:make-mock-vector-store))
         (ch (%chunk "a" "x" (%vec 1 0)))
         (rag-protocol:*rag-store* nil))
    (handler-bind ((rag-protocol:rag-missing-backend
                    (lambda (c)
                      (use-value store c))))
      (rag-protocol:upsert nil ch))
    (ok (equal "a" (rag-protocol:rag-chunk-id
                    (rag-protocol:rag-hit-chunk
                     (first (rag-protocol:query-store store (%vec 1 0) :top-k 1))))))))

(deftest delete-missing-continue
  (let ((store (rag-protocol:make-mock-vector-store)))
    (rag-protocol:upsert store (%chunk "a" "x" (%vec 1 0)))
    (let ((deleted
            (handler-bind ((rag-protocol:rag-not-found
                            (lambda (c)
                              (declare (ignore c))
                              (invoke-restart 'continue))))
              (rag-protocol:delete-ids store '("a" "missing")))))
      (ok (equal '("a") deleted))
      (ok (null (rag-protocol:query-store store (%vec 1 0) :top-k 5))))))

(deftest delete-missing-signals
  (let ((store (rag-protocol:make-mock-vector-store)))
    (ok (signals (rag-protocol:delete-ids store "nope")
                 'rag-protocol:rag-not-found))))

(deftest dimension-mismatch-continue
  (let ((store (rag-protocol:make-mock-vector-store)))
    (rag-protocol:upsert store (%chunk "a" "x" (%vec 1 0)))
    (handler-bind ((rag-protocol:rag-dimension-mismatch
                    (lambda (c)
                      (declare (ignore c))
                      (invoke-restart 'continue))))
      (rag-protocol:upsert store (%chunk "b" "y" (%vec 1 0 0))))
    (ok (= 1 (length (rag-protocol:query-store store (%vec 1 0) :top-k 5))))))

(deftest dimension-mismatch-use-value
  (let ((store (rag-protocol:make-mock-vector-store)))
    (rag-protocol:upsert store (%chunk "a" "x" (%vec 1 0)))
    (handler-bind ((rag-protocol:rag-dimension-mismatch
                    (lambda (c)
                      (use-value (%vec 0 1) c))))
      (rag-protocol:upsert store (%chunk "b" "y" (%vec 1 0 0))))
    (let ((hits (rag-protocol:query-store store (%vec 0 1) :top-k 1)))
      (ok (equal "b" (rag-protocol:rag-chunk-id
                      (rag-protocol:rag-hit-chunk (first hits))))))))

(defsystem "rag-protocol"
  :version "0.1.2"
  :description "CLOS RAG protocol (chunk / store / rerank / retrieve) for cl-stack"
  :author "egao1980"
  :license "MIT"
  :depends-on ("llm-protocol")
  :serial t
  :pathname "src"
  :components ((:file "package")
               (:file "conditions")
               (:file "types")
               (:file "analyze")
               (:file "sparse")
               (:file "protocol")
               (:file "fuse")
               (:file "mock"))
  :in-order-to ((test-op (test-op "rag-protocol/tests"))))

(defsystem "rag-protocol/tests"
  :depends-on ("rag-protocol" "rove")
  :pathname "tests"
  :serial t
  :components ((:file "package")
               (:file "protocol-test")
               (:file "analyze-test")
               (:file "restarts-test"))
  :perform (test-op (o c)
             (unless (symbol-call :rove :run c)
               (error "tests failed for ~A" (component-name c)))))

(defpackage #:rag-protocol
  (:use #:cl)
  (:nicknames #:stack-rag)
  (:export #:rag-error
           #:rag-error-message
           #:rag-missing-backend
           #:rag-missing-backend-role
           #:rag-dimension-mismatch
           #:rag-dimension-mismatch-expected
           #:rag-dimension-mismatch-actual
           #:rag-dimension-mismatch-id
           #:rag-not-found
           #:rag-not-found-ids

           #:rag-document
           #:make-rag-document
           #:rag-document-p
           #:rag-document-id
           #:rag-document-text
           #:rag-document-metadata
           #:coerce-document

           #:rag-chunk
           #:make-rag-chunk
           #:rag-chunk-p
           #:rag-chunk-id
           #:rag-chunk-document-id
           #:rag-chunk-text
           #:rag-chunk-embedding
           #:rag-chunk-sparse
           #:rag-chunk-metadata

           #:rag-hit
           #:make-rag-hit
           #:rag-hit-p
           #:rag-hit-chunk
           #:rag-hit-score
           #:rag-hit-rank

           #:rag-query
           #:make-rag-query
           #:rag-query-p
           #:rag-query-text
           #:rag-query-embedding
           #:rag-query-sparse
           #:rag-query-top-k
           #:rag-query-filter

           #:rag-vector-store
           #:rag-chunker
           #:rag-reranker
           #:rag-pipeline
           #:make-rag-pipeline
           #:rag-pipeline-store
           #:rag-pipeline-embedder
           #:rag-pipeline-chunker
           #:rag-pipeline-reranker
           #:rag-pipeline-sparse-encoder

           #:*rag-store*
           #:*rag-chunker*
           #:*rag-reranker*
           #:*rag-pipeline*

           #:chunk
           #:upsert
           #:delete-ids
           #:query-store
           #:rerank
           #:ingest
           #:retrieve

           #:cosine-similarity
           #:query-vector
           #:query-text
           #:query-sparse

           #:rag-analyzer
           #:analyze
           #:tokenize
           #:porter-stem
           #:english-stopword-p
           #:*english-stopwords*
           #:simple-analyzer
           #:make-simple-analyzer
           #:simple-analyzer-stemmer
           #:simple-analyzer-stopwords

           #:rag-fusion
           #:fuse
           #:rrf-fuse
           #:linear-fuse
           #:rrf-fusion
           #:make-rrf-fusion
           #:rrf-fusion-k
           #:linear-fusion
           #:make-linear-fusion
           #:linear-fusion-weights
           #:*rag-fusion*

           #:rag-sparse-encoder
           #:encode-sparse
           #:sparse-dot
           #:simple-sparse-encoder
           #:make-simple-sparse-encoder

           #:passthrough-chunker
           #:make-passthrough-chunker
           #:identity-reranker
           #:make-identity-reranker

           #:mock-vector-store
           #:make-mock-vector-store
           #:mock-store-dimension
           #:use-mock-vector-store))

(in-package #:rag-protocol)

# rag-protocol

Lispy **CLOS** RAG API for [cl-stack](https://github.com/egao1980/cl-stack) — documents, chunks, hits, vector store / chunker / reranker roles, `ingest` / `retrieve`.

Embeddings stay in [`llm-protocol`](https://github.com/egao1980/llm-protocol) (`embed` / `embed-query`). This package takes float vectors or an `llm-backend`.

| System | Role | Repo |
|--------|------|------|
| `rag-protocol` (`stack-rag`) | Protocol + mock store + passthrough chunker | this repo |
| `rag-backend-memory` | In-process cosine store | [`egao1980/rag-backend-memory`](https://github.com/egao1980/rag-backend-memory) |
| `rag-backend-sql` | Persist via `sql-protocol` (Lisp cosine) | [`egao1980/rag-backend-sql`](https://github.com/egao1980/rag-backend-sql) |
| `rag-backend-pgvector` | Postgres ANN (`<=>` cosine, text wire) | [`egao1980/rag-backend-pgvector`](https://github.com/egao1980/rag-backend-pgvector) |
| `rag-backend-hybrid` | In-process Okapi BM25 + RRF over a vector store | [`egao1980/rag-backend-hybrid`](https://github.com/egao1980/rag-backend-hybrid) |
| `rag-backend-text` | Recursive character splitter | [`egao1980/rag-backend-text`](https://github.com/egao1980/rag-backend-text) |

```lisp
(asdf:load-system "rag-protocol")

(let* ((store (stack-rag:make-mock-vector-store))
       (embedder (stack-llm:make-mock-llm-backend))
       (pipe (stack-rag:make-rag-pipeline
              :store store :embedder embedder
              :chunker (stack-rag:make-passthrough-chunker))))
  (stack-rag:ingest pipe (list (stack-rag:make-rag-document :id "a" :text "alpha")
                               (stack-rag:make-rag-document :id "b" :text "beta")))
  (stack-rag:retrieve pipe "alpha" :top-k 2))
```

`retrieve` passes a `rag-query` (text + embedding) into `query-store` so lexical/hybrid stores can see the query string. `query-text` / `query-vector` unwrap it. Default `rerank` is identity (score desc). Default ingest chunker is passthrough (one chunk per document) unless you bind a `rag-chunker`.

## License

MIT

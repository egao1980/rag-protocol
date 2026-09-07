# rag-protocol

Lispy **CLOS** RAG API for [cl-stack](https://github.com/egao1980/cl-stack) — documents, chunks, hits, vector store / chunker / reranker roles, `ingest` / `retrieve`.

Embeddings stay in [`llm-protocol`](https://github.com/egao1980/llm-protocol) (`embed` / `embed-query`). This package takes float vectors or an `llm-backend`.

| System | Role | Repo |
|--------|------|------|
| `rag-protocol` (`stack-rag`) | Protocol + mock store + passthrough chunker | this repo |
| `rag-backend-memory` | In-process cosine store | [`egao1980/rag-backend-memory`](https://github.com/egao1980/rag-backend-memory) |
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

Default `rerank` is identity (score desc). Default ingest chunker is passthrough (one chunk per document) unless you bind a `rag-chunker`.

## License

MIT

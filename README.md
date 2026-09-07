# rag-protocol

Lispy **CLOS** RAG API for [cl-stack](https://github.com/egao1980/cl-stack) — documents, chunks, hits, vector store / chunker / reranker roles, `ingest` / `retrieve`.

Embeddings stay in [`llm-protocol`](https://github.com/egao1980/llm-protocol) (`embed` / `embed-query`). This package takes float vectors or an `llm-backend`.

| System | Role | Repo |
|--------|------|------|
| `rag-protocol` (`stack-rag`) | Protocol + mock store + passthrough chunker | this repo |
| `rag-backend-memory` | In-process cosine store | [`egao1980/rag-backend-memory`](https://github.com/egao1980/rag-backend-memory) |
| `rag-backend-sql` | Persist via `sql-protocol` (Lisp cosine) | [`egao1980/rag-backend-sql`](https://github.com/egao1980/rag-backend-sql) |
| `rag-backend-pgvector` | Postgres ANN (`<=>` cosine, text wire) | [`egao1980/rag-backend-pgvector`](https://github.com/egao1980/rag-backend-pgvector) |
| `rag-backend-hybrid` | In-process Okapi BM25 + RRF / linear fusion over a vector store | [`egao1980/rag-backend-hybrid`](https://github.com/egao1980/rag-backend-hybrid) |
| `rag-backend-tsvector` | Postgres `tsvector` / `ts_rank` | [`egao1980/rag-backend-tsvector`](https://github.com/egao1980/rag-backend-tsvector) |
| `rag-backend-splade` | Sparse term-weight store + encoder (`encode-fn` for neural SPLADE) | [`egao1980/rag-backend-splade`](https://github.com/egao1980/rag-backend-splade) |
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

`retrieve` passes a `rag-query` (text + embedding + optional sparse) into `query-store`. `query-text` / `query-vector` / `query-sparse` unwrap it.

GFs on this protocol — not a second package:

| Role | GF | In-tree |
|------|----|---------|
| `rag-analyzer` | `analyze` | `simple-analyzer` — tokenize, optional Porter, optional English stopwords |
| `rag-fusion` | `fuse` | `rrf-fusion` (k=60), `linear-fusion` (min-max + weights) |
| `rag-sparse-encoder` | `encode-sparse` | `simple-sparse-encoder` — `log(1+tf)` or `:encode-fn` |

`tsvector` is a store backend (Postgres FTS). Neural SPLADE is `:encode-fn` on the sparse encoder; we do not ship BERT weights.

Default `rerank` is identity (score desc). Default ingest chunker is passthrough unless you bind a `rag-chunker`. Optional `:sparse-encoder` on the pipeline fills `rag-chunk-sparse` / `rag-query-sparse`.

## License

MIT

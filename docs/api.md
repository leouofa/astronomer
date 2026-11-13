# Astronomer REST API (`/api/v1`) Specification & Developer Reference

This document provides a comprehensive technical reference for the programmatic REST API exposed by **Astronomer** under `/api/v1`. The API is designed for external applications, researchers, and companion client environments (such as an MCP server or Python/Julia astrophysics scripts) to query, manipulate, and orchestrate the entire astrophysics catalog, vector embedding manifold, archetype clustering engine, and multi-stage LLM synthesis pipelines.

---

## 1. Architectural Overview & Conventions

### Base URL
```
http://localhost:3000/api/v1
```

### OpenAPI 3.1 Specification
Astronomer serves an introspectable OpenAPI 3.1 JSON document directly at:
```http
GET /api/v1/openapi.json
```

### Response Envelopes
All responses are formatted as JSON using a consistent envelope structure:

#### Single Resource or Action Response
```json
{
  "data": { ... },
  "meta": { ... }
}
```

#### Collection Response (with Pagination)
```json
{
  "data": [ ... ],
  "meta": {
    "total": 42,
    "limit": 50,
    "offset": 0
  }
}
```

#### Error Response
Standard HTTP status codes (`400 Bad Request`, `404 Not Found`, `422 Unprocessable Entity`, etc.) return an error object:
```json
{
  "error": {
    "code": "not_found",
    "message": "Couldn't find StarSystem with 'id'=9999",
    "details": ["Optional validation errors or context"]
  }
}
```

### Pagination
Collection endpoints support `limit` (default: `50`, maximum: `500`) and `offset` (default: `0`) query parameters.

### Embedding Vectors (`pgvector` 1024-float arrays)
To keep network payloads lean, endpoints returning `StarSystem` or `CelestialBody` records include vector metadata (`embedded: boolean`, `embedding_model: string`, `embedded_at: timestamp`, `embedding_dimensions: 1024`), while the raw 1024-float array is omitted by default.
Pass `?include_embedding=true` on any individual or collection query to include the raw vector:
```json
{
  "data": {
    "id": 1,
    "name": "TRAPPIST-1",
    "embedded": true,
    "embedding_model": "bge-large",
    "embedding": [0.0123, -0.0456, 0.0891, ...]
  }
}
```

### Synchronous vs. Asynchronous Job Execution (`?sync=true`)
Long-running LLM and embedding operations (discovery, population, vector calculation) default to asynchronous execution via ActiveJob/Sidekiq (`202 Accepted` with `{ "data": { "job_id": "...", "status": "queued" } }`).
Clients can:
1. Poll the job status at `GET /api/v1/jobs/:id`.
2. Or pass `?sync=true` on single-entity actions (`POST /api/v1/star_systems/:id/generate_embedding?sync=true`, `POST /api/v1/cosmic_structures/:id/populate_star_systems?sync=true`, `POST /api/v1/star_systems/:id/populate_celestial_bodies?sync=true`) to block until execution completes and receive the immediate result (`200 OK`).

---

## 2. Resource Endpoints

### 2.1 Galaxies / Clusters (`/api/v1/cosmic_structures`)

- `GET /api/v1/cosmic_structures`: List galaxies and galaxy clusters (supports `q`, `limit`, `offset`, `include_star_systems`)
- `POST /api/v1/cosmic_structures`: Create a new cosmic structure
- `GET /api/v1/cosmic_structures/:id`: Retrieve cosmic structure by ID
- `PATCH /api/v1/cosmic_structures/:id`: Update cosmic structure
- `DELETE /api/v1/cosmic_structures/:id`: Delete cosmic structure
- `POST /api/v1/cosmic_structures/populate`: Trigger automated discovery of major galaxies and galaxy clusters
- `POST /api/v1/cosmic_structures/:id/populate_star_systems`: Discover star systems for a specific cosmic structure
- `POST /api/v1/cosmic_structures/upsert_batch`: Bulk upsert cosmic structure records

### 2.2 Star Systems (`/api/v1/star_systems`)

- `GET /api/v1/star_systems`: List star systems (supports `cosmic_structure_id`, `theme`, `q`, `embedded`, `include_embedding`, `include_celestial_bodies`)
- `POST /api/v1/star_systems`: Create a star system record
- `GET /api/v1/star_systems/:id`: Retrieve star system details
- `PATCH /api/v1/star_systems/:id`: Update star system details
- `DELETE /api/v1/star_systems/:id`: Delete a star system
- `GET /api/v1/star_systems/:id/neighbors`: Find nearest cosine-distance star system neighbors
- `POST /api/v1/star_systems/:id/generate_embedding`: Generate or refresh 1024-d embedding vector
- `POST /api/v1/star_systems/:id/populate_celestial_bodies`: Discover planets and celestial bodies for this star system
- `POST /api/v1/star_systems/populate`: Discover star systems across all cosmic structures
- `POST /api/v1/star_systems/upsert_batch`: Bulk upsert star systems for a given `cosmic_structure_id`
- `GET /api/v1/star_systems/search`: Semantic vector and keyword search across star systems

### 2.3 Planets & Celestial Bodies (`/api/v1/celestial_bodies`)

- `GET /api/v1/celestial_bodies`: List celestial bodies (supports `star_system_id`, `cosmic_structure_id`, `theme`, `q`, `embedded`, `include_embedding`)
- `POST /api/v1/celestial_bodies`: Create a celestial body record
- `GET /api/v1/celestial_bodies/:id`: Retrieve celestial body details
- `PATCH /api/v1/celestial_bodies/:id`: Update celestial body details
- `DELETE /api/v1/celestial_bodies/:id`: Delete a celestial body
- `GET /api/v1/celestial_bodies/:id/neighbors`: Find nearest celestial body counterparts
- `POST /api/v1/celestial_bodies/:id/generate_embedding`: Generate 1024-d embedding vector
- `POST /api/v1/celestial_bodies/populate`: Discover celestial bodies across all star systems
- `POST /api/v1/celestial_bodies/upsert_batch`: Bulk upsert celestial bodies for a given `star_system_id`
- `GET /api/v1/celestial_bodies/search`: Semantic vector and keyword search across celestial bodies

### 2.4 Clustering & Snapshots (`/api/v1/clusters`, `/api/v1/cluster_snapshots`)

- `GET /api/v1/clusters`: Dynamically compute agglomerative clusters for `StarSystem` or `CelestialBody` across levels 1 to 15 (params: `target`, `level`, `full_coverage`, `force`)
- `GET /api/v1/cluster_snapshots`: List frozen cluster snapshots
- `POST /api/v1/cluster_snapshots`: Compute and persist a frozen cluster snapshot
- `GET /api/v1/cluster_snapshots/:id`: Retrieve snapshot details, clusters, and member records
- `DELETE /api/v1/cluster_snapshots/:id`: Delete snapshot

### 2.5 Multi-Stage AI Synthesis Reports (`/api/v1/cluster_reports`)

- `GET /api/v1/cluster_reports`: List synthesis reports
- `POST /api/v1/cluster_reports`: Run 2-phase Map-Reduce report on a saved snapshot
- `POST /api/v1/cluster_reports/deep_synthesis`: Run 3-phase Hierarchical Deep Synthesis report
- `GET /api/v1/cluster_reports/:id`: Retrieve completed or running report details and synthesis monograph
- `DELETE /api/v1/cluster_reports/:id`: Delete report

### 2.6 Semantic Counterparts & Discovery (`/api/v1/find_counterparts`, `/api/v1/search`)

- `POST /api/v1/find_counterparts`: Find closest functional and physical counterparts for a given star system or celestial body across other galaxies or star systems
- `GET /api/v1/search`: Unified cross-entity search endpoint

### 2.7 Platform Status & Settings (`/api/v1/status`, `/api/v1/settings`)

- `GET /api/v1/status`: Health check, database connectivity, `pgvector` version, Ollama reachability, counts of cosmic structures, star systems, celestial bodies, and embeddings
- `GET /api/v1/settings`: Current LLM and embedding model configuration, context window sizes, temperature settings
- `PATCH /api/v1/settings`: Update runtime settings (e.g., context window size, model overrides)
- `POST /api/v1/settings/bulk_embeddings`: Trigger background embedding generation for all un-embedded records

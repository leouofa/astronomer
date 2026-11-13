<p align="center">
  <img src="docs/images/logo.jpg" alt="Astronomer Logo" width="400" />
</p>

# Astronomer: A Computational Laboratory for Comparative Astrophysics, Stellar Systems, and Celestial Body Manifolds

[![Ruby](https://img.shields.io/badge/Ruby-3.4%2B-CC342D?logo=ruby&logoColor=white)](https://www.ruby-lang.org/)
[![Rails 8.1+](https://img.shields.io/badge/Rails-8.1%2B-red.svg?logo=rubyonrails&logoColor=white)](https://rubyonrails.org)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16%2B-4169E1?logo=postgresql&logoColor=white)](https://www.postgresql.org/)
[![pgvector](https://img.shields.io/badge/pgvector-1024--dim_HNSW-0284C7.svg)](https://github.com/pgvector/pgvector)
[![Ollama](https://img.shields.io/badge/Ollama-Local_Inference-black?logo=ollama&logoColor=white)](https://ollama.com)
[![RubyLLM](https://img.shields.io/badge/RubyLLM-Agent_Orchestration-9333EA.svg)](https://github.com/flavorjones/ruby-llm)
[![Sidekiq](https://img.shields.io/badge/Sidekiq-Background_Jobs-B91C1C.svg?logo=sidekiq&logoColor=white)](https://sidekiq.org)
[![Tailwind CSS](https://img.shields.io/badge/Tailwind_CSS-38B2AC?logo=tailwind-css&logoColor=white)](https://tailwindcss.com)
[![Hotwire](https://img.shields.io/badge/Hotwire-Turbo%20%26%20Stimulus-F3B01C.svg)](https://hotwired.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**Astronomer** is an open-source computational research platform and quantitative analytical laboratory designed for **astrophysicists**, **planetary scientists**, **extragalactic astronomers**, and **stellar cartographers**. It enables researchers to systematically map, cluster, and synthesize astrophysical archetypes, evolutionary trajectories, orbital dynamics, and planetary manifolds across galaxies, star systems, and celestial bodies using **1024-dimensional semantic vector embeddings (`pgvector`)**, **graph-theoretic connected components**, and **multi-stage AI synthesis pipelines**.

---

## Abstract & Scholarly Vision

Modern observational and theoretical astrophysics faces a deluge of empirical discoveries: thousands of exoplanets cataloged by Kepler, TESS, and JWST, complex stellar remnants and binary pulsars discovered across galactic discs, and morphologically distinct star clusters spanning the Local Group and beyond. How can researchers discover systemic archetypes across disparate cosmic structures without flattening unique physical parameters or relying on isolated, uncontextualized surveys?

Astronomer operationalizes comparative astrophysics within a transparent, reproducible, locally hosted computational laboratory:

1. **Multi-Tier Cosmic Architecture**:
   - **Galaxies / Clusters (`CosmicStructure`)**: Major galactic structures, dwarf galaxies, and galaxy clusters (e.g., Milky Way, Andromeda Galaxy M31, Large Magellanic Cloud, Small Magellanic Cloud, Triangulum Galaxy M33, Centaurus A, Virgo Cluster).
   - **Star Systems (`StarSystem`)**: Stellar hosts, binary/multiple star systems, neutron stars, X-ray pulsars, and compact remnants belonging to cosmic structures (`belongs_to :cosmic_structure`).
   - **Planets / Celestial Bodies (`CelestialBody`)**: Terrestrial exoplanets, gas/ice giants, ocean worlds, dwarf planets, major moons, and circumstellar features (`belongs_to :star_system`).
2. **High-Dimensional Semantic Manifold**: Every star system and celestial body profile is projected into a **1024-dimensional vector space** indexed via PostgreSQL `pgvector` HNSW (`vector_cosine_ops`), enabling empirical measurement of physical and evolutionary proximity.
3. **Multi-Granularity Empirical Clustering & Snapshotting**: Researchers interactively tune cosine distance thresholds across **15 granularity levels** (from tight structural twins at *Level 1, $\le 0.16$* to zero-singleton **100% Full Catalog Coverage** at *Level 15* via nearest-cluster singleton absorption) and freeze states into immutable **Cluster Snapshots**.
4. **Map-Reduce & Hierarchical Deep Synthesis Reports**: Rather than shallow single-prompt summaries, Astronomer executes a **2-Phase Map-Reduce** or **3-Phase Hierarchical Deep Synthesis** workflow over saved snapshots, inspecting every cluster through the researcher's specific inquiry and grounding every finding in cited cluster numbers, star systems, and celestial bodies.

---

## 3-Tier Domain Mapping

| Tier | Domain Entity | Database Model | Table Name | Key Associations |
|------|---------------|----------------|------------|------------------|
| **Tier 1** | Galaxies / Clusters | `CosmicStructure` | `cosmic_structures` | `has_many :star_systems`, `has_many :celestial_bodies, through: :star_systems` |
| **Tier 2** | Star Systems | `StarSystem` | `star_systems` | `belongs_to :cosmic_structure`, `has_many :celestial_bodies`, `embeddable` |
| **Tier 3** | Planets / Celestial Bodies | `CelestialBody` | `celestial_bodies` | `belongs_to :star_system`, `has_one :cosmic_structure, through: :star_system`, `embeddable` |

---

## End-to-End Empirical Research Pipeline

```mermaid
flowchart TD
    subgraph S1["Stage I: Corpus Discovery"]
        P["CosmicStructureDiscoveryAgent\n(Galaxies & Clusters)"] --> G["StarSystemDiscoveryAgent\n(Star Systems & Astrophysical Themes)"]
        G --> M["CelestialBodyDiscoveryAgent\n(Exoplanets, Moons, Remnants)"]
    end

    subgraph S2["Stage II: High-Dimensional Embeddings"]
        M --> V1["1024-d Vector Generation\n(bge-large / nomic-embed-text)"]
        V1 --> V2["pgvector HNSW Index\n(vector_cosine_ops)"]
    end

    subgraph S3["Stage III: Agglomerative Clustering & Snapshots"]
        V2 --> C1["15-Level Cosine Distance Clustering\n(Graph Connected Components)"]
        C1 --> C2["Zero-Singleton Absorption\n(100% Full Catalog Coverage)"]
        C2 --> C3["ClusterSnapshot\n(Frozen JSON State)"]
    end

    subgraph S4["Stage IV: Scholarly Synthesis"]
        C3 --> R1["Phase 1: Cluster Group Summaries"]
        R1 --> R2["Phase 2: Batch Cross-Cluster Aggregation"]
        R2 --> R3["Phase 3: Executive Monograph Synthesis\n(Cited Clusters & Objects)"]
    end
```

---

## Installation & Local Laboratory Setup

### Prerequisites

- **Ruby 3.4+**
- **PostgreSQL 16+** with `pgvector` extension installed (`CREATE EXTENSION IF NOT EXISTS vector;`)
- **Ollama** running locally on `http://localhost:11434` with an LLM and embedding model (e.g. `qwen2.5:32b`, `bge-large`)
- **Redis** running locally (for background job processing via Sidekiq)

### Setup

```bash
# Clone the repository
git clone https://github.com/leouofa/astronomer.git
cd astronomer

# Install dependencies
bundle install

# Prepare database
bin/rails db:prepare

# Run tests
bundle exec rails test

# Start the local development server (web + worker)
bin/dev
```

Visit `http://localhost:3000` to access the interactive web interface.

---

## Programmatic REST API (`/api/v1`) & OpenAPI 3.1 Spec

Astronomer provides a full-featured REST API under `/api/v1` returning JSON responses adhering to the `{ "data": ... }` envelope standard.

- Interactive OpenAPI 3.1 schema: `GET /api/v1/openapi.json`
- Full API documentation: see [docs/api.md](file:///Users/leonid/src/astronomer/docs/api.md)

### Key Endpoints

- `GET /api/v1/cosmic_structures`: List galaxies and galaxy clusters
- `GET /api/v1/star_systems`: List star systems with optional filtering by `cosmic_structure_id`, `theme`, or `q`
- `GET /api/v1/star_systems/:id/neighbors`: Find nearest cosine-distance star system neighbors
- `GET /api/v1/celestial_bodies`: List celestial bodies with pagination
- `GET /api/v1/celestial_bodies/:id/neighbors`: Find nearest celestial body counterparts
- `GET /api/v1/clusters?target=StarSystem&level=5`: Interactive agglomerative clustering
- `POST /api/v1/cluster_snapshots`: Freeze an empirical cluster snapshot
- `POST /api/v1/cluster_reports`: Synthesize an AI-grounded Map-Reduce or Deep Synthesis report

---

## Open Science, Reproducibility, & Testing

Astronomer is designed for open, reproducible science:

- **100% Local Inference**: Zero proprietary API lock-in.
- **Deterministic Clustering**: Snapshot algorithms freeze graph-theoretic components alongside exact centroid distances.
- **Comprehensive Test Suite**: Model tests, agent tests, job tests, service tests, and API controller tests with 100% passing coverage:

```bash
bundle exec rails test
```

---

## License

This project is open-source software licensed under the [MIT License](LICENSE).

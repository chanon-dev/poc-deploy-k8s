# Kubernetes Platform Architecture Diagrams

This folder contains comprehensive DrawIO diagrams for the Kubernetes on-premise platform.

## How to View the Diagrams

These are `.drawio` files that can be opened with:

1. **Online (Recommended)**:
   - Visit [https://app.diagrams.net](https://app.diagrams.net) (formerly draw.io)
   - Click "Open Existing Diagram"
   - Select the `.drawio` file from this folder

2. **Desktop App**:
   - Download draw.io desktop app from [https://github.com/jgraph/drawio-desktop/releases](https://github.com/jgraph/drawio-desktop/releases)
   - Open the `.drawio` file directly

3. **VS Code Extension**:
   - Install "Draw.io Integration" extension
   - Open `.drawio` files directly in VS Code

## Available Diagrams

### 1. Architecture Overview
**File**: `1-architecture-overview.drawio`

**Purpose**: Shows the complete Kubernetes platform architecture including all components and layers.

**Contains**:
- Infrastructure layer (Ingress Controller, Storage, RBAC, Network Policies)
- Application namespaces (Jenkins, Argo CD, Vault, environments)
- Future observability layer (Prometheus, Grafana, ELK, Jaeger)
- External access points
- Component relationships

**Use this when**:
- Understanding the overall system structure
- Planning new features or components
- Explaining the platform to new team members
- Documentation and presentations

---

### 2. Ingress Network Flow
**File**: `2-ingress-network-flow.drawio`

**Purpose**: Detailed traffic flow diagram showing how requests are routed through NGINX Ingress Controller.

**Contains**:
- User browser → /etc/hosts → LoadBalancer flow
- NGINX Ingress Controller routing logic
- Host-based routing to services
- Service to Pod connections
- Step-by-step flow explanation
- Benefits and requirements

**Use this when**:
- Setting up Ingress for the first time
- Troubleshooting Ingress routing issues
- Understanding how hostname-based access works
- Learning production-like Kubernetes networking

---

### 3. Port-Forward Network Flow
**File**: `3-port-forward-network-flow.drawio`

**Purpose**: Shows how kubectl port-forward creates tunnels from localhost to services.

**Contains**:
- Terminal → kubectl → Kubernetes API flow
- localhost port mapping
- Direct service connections
- Pros and cons comparison
- Step-by-step flow explanation

**Use this when**:
- Understanding port-forward mechanism
- Quick local development setup
- Comparing with Ingress approach
- Troubleshooting port-forward connections

---

### 4. Deployment Workflow
**File**: `4-deployment-workflow.drawio`

**Purpose**: Complete deployment process from start to finish, including decision points.

**Contains**:
- Prerequisites check
- Optional Ingress installation decision
- All 5 deployment phases (Namespaces, RBAC, Jenkins, Argo CD, Vault)
- Verification steps
- Side notes with commands and configurations
- Estimated time for each phase
- Access methods for both approaches

**Use this when**:
- Deploying the platform for the first time
- Understanding the deployment sequence
- Creating deployment automation
- Troubleshooting deployment issues

---

### 5. Components Relationship
**File**: `5-components-relationship.drawio`

**Purpose**: Shows how all components interact with each other in the CI/CD pipeline.

**Contains**:
- Jenkins, Argo CD, Vault, Harbor (future), Git, Kubernetes relationships
- Data flow between components
- Complete CI/CD flow (12 steps)
- Each component's role, responsibilities, needs, and provides
- Developer interactions

**Use this when**:
- Understanding the CI/CD pipeline
- Designing new workflows
- Troubleshooting integration issues
- Explaining the system to developers

---

### 6. Ingress vs Port-Forward Comparison
**File**: `6-ingress-vs-portforward-comparison.drawio`

**Purpose**: Comprehensive comparison to help choose the right access method.

**Contains**:
- Side-by-side feature comparison
- Setup complexity comparison
- Access methods and URLs
- Detailed pros and cons for each approach
- Quick comparison table
- Recommendations for different use cases

**Use this when**:
- Deciding which access method to use
- Explaining options to team members
- Understanding trade-offs
- Setting up new environments

---

## Diagram Color Coding

Throughout all diagrams, we use consistent color coding:

| Color | Component Type | Example |
|-------|---------------|---------|
| **Blue** (`#b1ddf0`) | Jenkins components | Jenkins pods, services |
| **Pink** (`#fad9d5`) | Argo CD components | Argo CD server, repo server |
| **Light Red** (`#f8cecc`) | Vault components | Vault pods, secrets |
| **Purple** (`#e1d5e7`) | Infrastructure | Ingress Controller, RBAC |
| **Green** (`#d5e8d4`) | General services/benefits | Services, positive aspects |
| **Yellow** (`#fff2cc`) | Configuration/warnings | Setup steps, requirements |
| **Light Blue** (`#dae8fc`) | Kubernetes resources | Cluster, deployments |
| **Orange** (`#ffe6cc`) | Future/optional | Harbor, observability |
| **Light Green** (`#cdeb8b`) | External/user | User, developer |

## Line Styles

- **Solid lines**: Active connections, data flow
- **Dashed lines**: Return paths, responses, optional components
- **Thick lines**: Primary/important flows
- **Arrows**: Direction of data/request flow

## Editing the Diagrams

To modify these diagrams:

1. Open the `.drawio` file in diagrams.net or draw.io app
2. Make your changes
3. Save the file (it will remain as `.drawio` format)
4. Commit the changes to Git

**Tips**:
- Maintain consistent color coding
- Keep text readable (minimum font size: 10pt)
- Use the same shapes for similar components
- Update the README if you add new diagrams

## Exporting to Other Formats

From draw.io/diagrams.net, you can export to:

- **PNG**: File → Export as → PNG (for documentation)
- **PDF**: File → Export as → PDF (for presentations)
- **SVG**: File → Export as → SVG (for scalable graphics)

Recommended export settings:
- **PNG**: 200% zoom, transparent background OFF
- **PDF**: Fit to page, include diagram title
- **SVG**: Embed fonts

## Related Documentation

These diagrams complement the following documentation:

- [Ingress Setup Guide](../ingress-setup-guide.md) - Pairs with diagrams #2, #3, #6
- [Quick Command Reference](../quick-command-reference.md) - Pairs with diagram #4
- [Manual Installation Steps](../manual-installation-steps.md) - Pairs with diagram #4
- [Local Development Guide](../local-development-guide.md) - Pairs with all diagrams

## Questions or Updates?

If you need to:
- Add new diagrams
- Update existing diagrams
- Request different views or perspectives

Please update this README with any new diagrams you create and maintain the numbering system.

---

**Last Updated**: 2024-01-01
**Diagram Count**: 6
**Format**: DrawIO (.drawio)

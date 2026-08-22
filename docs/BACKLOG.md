# Backlog and Scope Guardrails

This file records ideas outside EasyFlow v1. Inclusion here is not approval or a commitment to implement.

## Explicitly out of scope for v1

- Notion synchronization;
- a custom EasyFlow cloud backend, always-on server, webhook infrastructure, or WebSocket service;
- user accounts or login;
- collaboration and team features;
- iPhone or iPad EasyFlow applications;
- tags, categories, projects, hierarchies, or complex grouping;
- due dates, calendar integration, recurring tasks, or dependencies;
- nested Steps or percentage completion;
- EasyFlow-generated notifications;
- global keyboard shortcuts;
- an embedded AI assistant;
- telemetry, analytics, advertising, or social features;
- complex reporting or Kanban.

## Deferred ideas mentioned

- Notion integration if a future architecture accepts the required reachable service;
- occasional notifications about the current working set;
- global shortcuts;
- broader appearance/customization controls;
- activation on every display;
- additional synchronization mechanisms;
- more advanced task behaviors.

Notion was considered technically feasible but deferred because reliable webhook-driven bidirectional synchronization would require an always-reachable endpoint. Apple Reminders/iCloud remains the only approved external integration for v1.

Any promotion from this backlog requires an explicit scope decision, updates to `PRODUCT_SPEC.md`, and an ADR when architecture changes.

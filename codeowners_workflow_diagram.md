# CODEOWNERS Workflow Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    CODEOWNERS APPROVAL WORKFLOW                         │
└─────────────────────────────────────────────────────────────────────────┘

                        ┌─────────────────────┐
                        │  Create Merge       │
                        │  Request            │
                        └──────────┬──────────┘
                                   │
                                   ▼
                        ┌──────────────────────┐
                        │  What files changed? │
                        └──────────┬───────────┘
                                   │
                ┌──────────────────┼──────────────────┐
                │                  │                  │
                ▼                  ▼                  ▼
    ┌───────────────────┐  ┌──────────────┐  ┌──────────────────┐
    │  INFRASTRUCTURE   │  │  LAB/STAGE   │  │   PRODUCTION     │
    │   (Protected)     │  │  (Team Apps) │  │  (Apps/Base)     │
    └─────────┬─────────┘  └──────┬───────┘  └────────┬─────────┘
              │                   │                    │
    • /clusters/               • /apps/lab/           • /apps/prod/
    • /terraform/              • /apps/stage/         • /apps/base/
    • /infrastructure/                                 • /.gitlab-ci.yml
    • /policy/                                         • /.sops.yaml
    • /secrets/                                        • /secrets/
              │                   │                    │
              ▼                   ▼                    ▼
    ┌─────────────────┐  ┌────────────────┐  ┌──────────────────┐
    │   REQUIRES      │  │   REQUIRES     │  │    REQUIRES      │
    │                 │  │                │  │                  │
    │  @ai-devops     │  │  @ai-devops    │  │   @ai-devops     │
    │   approval      │  │      OR        │  │    approval      │
    │                 │  │  @ai-dev-XXX   │  │                  │
    └────────┬────────┘  └───────┬────────┘  └────────┬─────────┘
             │                   │                     │
             │                   │                     │
             └───────────────────┼─────────────────────┘
                                 │
                                 ▼
                    ┌────────────────────────┐
                    │  ✓ Approval Received   │
                    │  (Self-approval OK!)   │
                    └────────────┬───────────┘
                                 │
                                 ▼
                         ┌───────────────┐
                         │  MERGE! 🚀    │
                         └───────────────┘


┌─────────────────────────────────────────────────────────────────────────┐
│                         TEAM-SPECIFIC PATHS                             │
└─────────────────────────────────────────────────────────────────────────┘

    /apps/lab/**/cai/         →  @ai-devops  OR  @ai-dev-cai
    /apps/lab/**/ringsense/   →  @ai-devops  OR  @ai-dev-ringsense
    /apps/lab/**/cprc/        →  @ai-devops  OR  @ai-dev-coremedia

    /apps/stage/**/cai/       →  @ai-devops  OR  @ai-dev-cai
    /apps/stage/**/ringsense/ →  @ai-devops  OR  @ai-dev-ringsense
    /apps/stage/**/cprc/      →  @ai-devops  OR  @ai-dev-coremedia


┌─────────────────────────────────────────────────────────────────────────┐
│                            KEY POINTS                                   │
└─────────────────────────────────────────────────────────────────────────┘

    ✓  Self-approval is ALLOWED for code owners
    ✓  Only ONE approval needed from code owner groups
    ✓  DevOps can approve everything
    ✓  App teams can approve their own lab/stage changes
    ✓  Prod changes = DevOps only
```

---

## Quick Reference Card

| **You are...**        | **Changing...**           | **Who can approve?**                    |
|-----------------------|---------------------------|-----------------------------------------|
| DevOps Team           | Infrastructure files      | @ai-devops (you!)                       |
| DevOps Team           | Any team's apps           | @ai-devops (you!)                       |
| CAI Team              | /apps/lab/**/cai/         | @ai-devops OR @ai-dev-cai (you!)        |
| CAI Team              | /apps/stage/**/cai/       | @ai-devops OR @ai-dev-cai (you!)        |
| RingSense Team        | /apps/lab/**/ringsense/   | @ai-devops OR @ai-dev-ringsense (you!)  |
| RingSense Team        | /apps/stage/**/ringsense/ | @ai-devops OR @ai-dev-ringsense (you!)  |
| CoreMedia Team        | /apps/lab/**/cprc/        | @ai-devops OR @ai-dev-coremedia (you!)  |
| CoreMedia Team        | /apps/stage/**/cprc/      | @ai-devops OR @ai-dev-coremedia (you!)  |
| Any Team              | /apps/prod/               | @ai-devops ONLY                         |
| Any Team              | /clusters/, /terraform/   | @ai-devops ONLY                         |


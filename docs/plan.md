# CI Demo Project Plan (Jenkins + Docker + AWS ECR)

## Goal

Build a small CI-focused demo project to demonstrate:

- Jenkins pipeline design
- Docker image build (multi-stage)
- AWS ECR integration
- Basic CI best practices (test, validation, tagging, cleanup)

> Scope: CI only (no deployment). CD will be covered in a separate project.

---

## High-Level Flow

```
Git push → Jenkins pipeline triggered
    → checkout code
    → run unit tests
    → build JAR
    → build Docker image
    → run smoke test (container)
    → push image to ECR (master branch only)
    → archive test results
    → cleanup
```

---

## Project Structure

```
ci-demo-project/
├── app/                     # Spring Boot app
│   ├── hello-world-api/
│   └── Dockerfile          # multi-stage build
│
├── cicd/
│   ├── Jenkinsfile         # pipeline definition
│   └── smoke-test.sh
│
├── .gitignore
└── README.md               # later
```

---

## Step 1 — App (Spring Boot)

Goal: minimal app for pipeline validation

- create REST API:
  - `GET /hello` → returns simple message

- enable health endpoint (Spring Actuator or simple endpoint)
- add 1–2 unit tests

Done when:

- `mvn test` passes locally
- app runs locally

---

## Step 2 — Docker

Goal: build small, production-style image

- multi-stage Dockerfile:
  - stage 1: build JAR (Maven)
  - stage 2: runtime (small base image)

- expose app port (e.g., 8080)

Tagging strategy:

- `app:<build_number>`
- `app:<commit_sha>`
- `latest` (master branch only)

Done when:

- image builds locally
- container runs and `/hello` works

---

## Step 3 — Smoke Test

Goal: verify container actually works

- start container locally (inside Jenkins later)
- call:
  - `/hello` OR `/health`

- fail if response not OK

Optional:

- use curl script (`scripts/smoke-test.sh`)

Done when:

- test fails if app is broken
- test passes if app is healthy

---

## Step 4 — AWS (ECR Setup)

Goal: prepare image registry

- create ECR repository
- create IAM policy (least privilege):
  - push/pull images only

- generate credentials for Jenkins

Done when:

- can login to ECR manually
- can push image locally

---

## Step 5 — Jenkins Pipeline

Goal: implement CI pipeline

Stages:

1. **Checkout**
2. **Test**
   - run `mvn test`

3. **Build**
   - package JAR

4. **Docker Build**
5. **Smoke Test**
   - run container
   - test endpoint

6. **Push to ECR**
   - only on `master` branch

7. **Post**
   - archive test results
   - cleanup containers/images

Key features:

- branch condition (master vs others)
- credentials from Jenkins (no hardcoding)
- post block (cleanup + archive)

Done when:

- pipeline runs successfully end-to-end
- image appears in ECR

---

## Step 6 — Security Basics

Goal: avoid bad practices

- store AWS credentials in Jenkins credentials store
- inject into pipeline securely
- no secrets in repo or Jenkinsfile
- IAM policy limited to ECR push actions

---

## Step 7 — Validation Checklist

Before calling it done:

- [ ] unit tests run in Jenkins
- [ ] Docker image builds successfully
- [ ] smoke test validates container
- [ ] image pushed to ECR (master branch only)
- [ ] test results archived
- [ ] pipeline cleans up resources
- [ ] no hardcoded credentials

---

## Optional Improvements (if time permits)

Keep small, but useful:

- add commit SHA tagging
- add build number tagging
- add retry/timeout for flaky steps
- add simple logging output in pipeline

---

## Notes

- keep everything simple → focus is CI pipeline clarity
- avoid over-engineering (no deployment, no Terraform here)
- pipeline readability > complexity
- this project should be easy to explain in an interview

---

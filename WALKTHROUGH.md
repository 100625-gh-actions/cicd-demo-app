# Full CI/CD Lifecycle -- Instructor Walkthrough

**Duration:** 30-45 minutes (single-flow live demo)
**Format:** Instructor codes live while students observe
**Repo:** `100625-gh-actions/cicd-demo-app`
**Registry:** `ghcr.io/100625-gh-actions/cicd-demo-app`

---

## Story Arc

| Act | Theme | What Happens |
|-----|-------|--------------|
| **Act 1** | Feature Addition | Add a "Personal Greeting" feature, push it through CI, deploy to staging, then promote to production via a release. |
| **Act 2** | Bug Fix + Rollback | Introduce a price calculation bug, watch it break staging, perform an emergency rollback, then fix the bug properly. |

---

## Pre-Demo Setup Checklist

Complete **all** of the following before students arrive. Each item should be verified, not assumed.

| # | Item | How to Verify |
|---|------|---------------|
| 1 | GitHub repo `100625-gh-actions/cicd-demo-app` exists with code on `main` | Visit **https://github.com/100625-gh-actions/cicd-demo-app** |
| 2 | Branch protection on `main` -- require the CI Pipeline check to pass | Repo **Settings > Branches > Branch protection rules** |
| 3 | GitHub Environment `staging` configured (no required reviewers) | Repo **Settings > Environments > staging** |
| 4 | GitHub Environment `production` configured **with required reviewer** (yourself) | Repo **Settings > Environments > production** -- confirm "Required reviewers" is enabled |
| 5 | Repository secrets set for **both** environments | Repo **Settings > Secrets and variables > Actions** |
| 6 | EC2 instances running (Terraform applied) | `terraform output` shows both IPs |
| 7 | App accessible at staging URL | `curl http://<STAGING_IP>:5000/api/health` returns `{"status":"healthy",...}` |
| 8 | App accessible at production URL | `curl http://<PRODUCTION_IP>:5000/api/health` returns `{"status":"healthy",...}` |
| 9 | Local clone is up-to-date and on `main` | `git status` shows clean working tree |
| 10 | `gh` CLI authenticated | `gh auth status` shows logged in |

### Required Repository Secrets

| Secret Name | Scope | Description |
|-------------|-------|-------------|
| `STAGING_HOST` | Environment: `staging` | Public IP of the staging EC2 instance |
| `PRODUCTION_HOST` | Environment: `production` | Public IP of the production EC2 instance |
| `SSH_PRIVATE_KEY` | Repository-level (or both environments) | Private SSH key that matches the EC2 key pair |

> NOTE: The workflows also use `GITHUB_TOKEN`, which is provided automatically by GitHub Actions. No manual configuration needed for it.

---

## Introduction (5 min)

### What to do

1. Open a blank slide or whiteboard and draw this diagram:

```
Developer  -->  GitHub Repo  -->  CI Pipeline (PR checks)
                    |
                    v
               Merge to main  -->  CD Staging (auto-deploy)
                    |
                    v
               Create Release -->  CD Production (manual approval)
                    |
                    v
               Rollback (emergency, manual trigger)
```

2. Open **two browser tabs** side by side:
   - **Tab 1:** `http://<STAGING_IP>:5000` (staging app)
   - **Tab 2:** `http://<PRODUCTION_IP>:5000` (production app)

3. Open a **third tab** to the GitHub repo: **https://github.com/100625-gh-actions/cicd-demo-app**

### What to observe

- Both apps look identical right now -- same version, same features.
- The staging app shows a **blue "staging" badge** in the header.
- The production app shows a **green "production" badge** in the header.
- Both display the current version and build SHA.

### Key teaching points

> *"We are building a complete CI/CD pipeline for a Python web application. By the end of this demo, you will have seen every stage of the software delivery lifecycle: branching, pull requests, automated testing, staging deployment, production release with manual approval, and emergency rollback."*

> *"Notice that staging and production are running the same code right now. That is the starting point. Our goal is to ship a new feature through the entire pipeline and then handle a production incident."*

---

## Step 1: Explore the Application (3 min)

### What to do

1. **In the browser**, show the HTML UI at `http://<STAGING_IP>:5000`:
   - Point out the **version badge** (e.g., `v1.0.0`) and the **environment badge** (`staging`).
   - Scroll down to show the **four feature cards**: Health Monitoring, Version Tracking, REST API, Automated Testing.
   - Scroll to the footer -- show the **Build SHA**.

2. **In the terminal**, hit the API endpoints:

```bash
# Health check -- the heartbeat of the application
curl -s http://<STAGING_IP>:5000/api/health | python3 -m json.tool
```

**Expected output:**
```json
{
    "status": "healthy",
    "version": "v1.0.0",
    "environment": "staging"
}
```

```bash
# Version info -- includes the build SHA for traceability
curl -s http://<STAGING_IP>:5000/api/version | python3 -m json.tool
```

```bash
# Items list -- the demo data
curl -s http://<STAGING_IP>:5000/api/items | python3 -m json.tool
```

**Expected output (items):**
```json
[
    {"id": 1, "name": "Widget A", "price": 9.99},
    {"id": 2, "name": "Widget B", "price": 14.99},
    {"id": 3, "name": "Gadget C", "price": 24.50},
    {"id": 4, "name": "Gizmo D", "price": 7.25},
    {"id": 5, "name": "Doohickey E", "price": 19.99}
]
```

3. **In the editor**, briefly open `app/app.py`:
   - Show lines 17-19 -- the app reads `APP_VERSION`, `ENVIRONMENT`, and `BUILD_SHA` from **environment variables**.
   - Show lines 24-30 -- the `ITEMS` list (this is the data the bug will affect later).
   - Show lines 32-53 -- the `FEATURES` list (we will add a new feature here).

4. **In the editor**, briefly open the `Dockerfile`:
   - Point out the **two-stage build**: `builder` stage (line 30) and `production` stage (line 59).
   - Point out the **build arguments** on lines 77-78: `APP_VERSION` and `BUILD_SHA`.
   - Point out the **non-root user** on lines 100-101.
   - Point out the **HEALTHCHECK** instruction on line 152.

### Key teaching points

> *"The app gets its version and environment from environment variables. This is important -- the same Docker image can run as staging or production just by changing the environment variables. The code does not change between environments."*

> *"The Dockerfile uses a multi-stage build. Stage 1 installs dependencies. Stage 2 copies only what is needed for runtime. This keeps the production image small and secure."*

---

## Step 2: Create a Feature Branch (2 min)

### What to do

```bash
# Make sure we are on main and up to date
git checkout main
git pull origin main

# Create a feature branch
git checkout -b feature/add-greeting
```

### What to observe

- Terminal confirms: `Switched to a new branch 'feature/add-greeting'`

### Key teaching points

> *"In a professional workflow, developers never commit directly to main. They create feature branches. This keeps main stable and lets CI validate changes before they reach the production codebase."*

> *"Branch naming conventions matter. Prefixes like `feature/`, `fix/`, `hotfix/`, and `docs/` help the team understand what a branch contains at a glance."*

---

## Step 3: Add the Greeting Feature (5 min)

We will make **three changes** -- add a feature card, add an API endpoint, and add tests.

### Change 1: Add a feature to the FEATURES list

**File:** `app/app.py`

Open the file and find the `FEATURES` list (around line 32). Add a new entry **after** the last item (the "Automated Testing" entry):

```python
    {
        "name": "Personal Greeting",
        "description": "Greet users by name with a personalized message.",
        "icon": "&#128075;",  # waving hand
    },
```

> NOTE: Add this right before the closing `]` of the `FEATURES` list, after line 53. The list will now have 5 items.

### Change 2: Add a new API endpoint

**File:** `app/app.py`

Add the following endpoint **after** the `api_item` function (after line 113):

```python
@app.route("/api/greet/<name>")
def api_greet(name):
    """Return a personalized greeting."""
    return jsonify(
        {"message": f"Hello, {name}! Welcome to CI/CD Demo App v{APP_VERSION}."}
    )
```

### Change 3: Add tests for the new endpoint

**File:** `tests/test_app.py`

Add the following test class **at the end** of the file:

```python
class TestGreetEndpoint:
    """Tests for GET /api/greet/<name>."""

    def test_greet_returns_200(self, client):
        """Greeting endpoint should return HTTP 200."""
        response = client.get("/api/greet/World")
        assert response.status_code == 200

    def test_greet_contains_name(self, client):
        """Greeting should contain the provided name."""
        response = client.get("/api/greet/Alice")
        data = response.get_json()
        assert "Alice" in data["message"]

    def test_greet_contains_version(self, client):
        """Greeting should contain the app version."""
        response = client.get("/api/greet/Test")
        data = response.get_json()
        assert "0.1.0" in data["message"]

    def test_greet_response_is_json(self, client):
        """Greeting endpoint should return JSON content type."""
        response = client.get("/api/greet/World")
        assert "application/json" in response.content_type
```

### Commit the changes

```bash
git add app/app.py tests/test_app.py
git commit -m "feat: add personal greeting endpoint"
```

### What to observe

- The commit succeeds locally with no errors.

### Key teaching points

> *"Notice we are committing exactly two files -- the source code change and the corresponding tests. Good practice is to always ship code with tests."*

> *"The commit message follows the Conventional Commits format: `feat:` for a new feature, `fix:` for a bug fix, `docs:` for documentation changes. Many teams use this to auto-generate changelogs."*

---

## Step 4: Open a Pull Request -- Watch CI Trigger (5 min)

### What to do

**Push the branch to GitHub:**

```bash
git push origin feature/add-greeting
```

**Create the Pull Request** using the `gh` CLI:

```bash
gh pr create \
  --title "feat: add personal greeting endpoint" \
  --body "Adds a new /api/greet/<name> endpoint that returns a personalized greeting. Includes unit tests."
```

> NOTE: Alternatively, you can create the PR via the GitHub web UI. The `gh` CLI is faster for a live demo.

### What to observe

1. **Go to the PR page** in the browser:
   - The CI Pipeline workflow starts automatically.
   - You will see status checks appearing at the bottom of the PR.
   - Initially they show a yellow "pending" indicator.

2. **Open the Actions tab** (`https://github.com/100625-gh-actions/cicd-demo-app/actions`):
   - Show the **CI Pipeline** workflow run in progress.
   - Click into it to show the **four jobs**:

| Job | Purpose | Runs in Parallel? |
|-----|---------|-------------------|
| **Lint Code** | flake8 checks for style issues | Yes (with Test) |
| **Run Tests** | pytest with coverage | Yes (with Lint) |
| **Build Docker Image** | Verify Dockerfile builds | No -- waits for Lint + Test (`needs: [lint, test]`) |
| **CI Summary** | Posts results comment to PR | No -- waits for all jobs (`needs: [lint, test, build]`) |

3. **Wait ~2 minutes** for the pipeline to complete.

4. **Go back to the PR page:**
   - See the **CI Summary comment** posted automatically on the PR.
   - The comment contains a results table showing each job's pass/fail status.
   - The merge button transitions from "Merge is blocked" to **"Squash and merge"** (green).

### Expected CI Summary comment on the PR

```
## CI Pipeline Passed

| Job | Status |
|-----|--------|
| Lint Code | success |
| Run Tests | success |
| Build Docker Image | success |

*Commit: `abc1234` | Run: #42*
```

### Key teaching points

> *"Notice that the CI pipeline started automatically the moment we created the PR. Nobody had to click a button. The `on: pull_request` trigger in `ci.yml` makes this happen."*

> *"Lint and Test run in parallel -- look at the workflow graph. They do not depend on each other. But Build depends on both (`needs: [lint, test]`). This means if linting or tests fail, we do not waste time building a Docker image."*

> *"The branch protection rule on main requires the CI Pipeline to pass before merging. Even if I wanted to click merge right now with failing checks, GitHub would not let me. This is your safety net."*

> *"The CI Summary comment is posted by the `ci-summary` job using `actions/github-script`. Notice the `if: always()` condition -- this job runs even when previous jobs fail so it can report the failure."*

---

## Step 5: Review the PR -- Watch PR Review Workflow (3 min)

### What to do

1. On the PR page, click **"Files changed"** to see the diff.
2. Click the green **"Review changes"** button in the top right.
3. Select **"Approve"** and click **"Submit review"**.

> NOTE: If you have a student or co-instructor available, have them submit the approval instead. This makes it more realistic.

### What to observe

1. **Go to the Actions tab:**
   - A new workflow run appears: **PR Review Automation**.
   - This was triggered by the `pull_request_review` event (defined in `pr-review.yml`).

2. **Go back to the PR page:**
   - An **"approved"** label has been automatically added to the PR.
   - If a "changes-requested" label was present, it would have been removed.

3. **Check the PR timeline:**
   - You can see the label addition event in the conversation timeline.

### Key teaching points

> *"This is an example of workflow automation around the review process. The `pr-review.yml` workflow listens for the `pull_request_review` event and automatically adds or removes labels based on the review decision."*

> *"Labels are visual indicators. When you look at the PR list page, you can immediately see which PRs are approved and which ones need changes. Without automation, people forget to add labels. With automation, it is always up to date."*

> *"This follows the DevOps principle: 'If you do it more than twice, automate it.'"*

---

## Step 6: Merge the PR -- Watch CD to Staging (5 min)

### What to do

1. On the PR page, click **"Squash and merge"** (or "Merge pull request").
2. Confirm the merge.

### What to observe

1. **Immediately go to the Actions tab:**
   - A new workflow run starts: **CD -- Deploy to Staging**.
   - This was triggered by the `push` event on `main` (merging a PR creates a push to `main`).

2. **Click into the workflow run** and show the **four jobs**:

| Job | Purpose | Depends On |
|-----|---------|------------|
| **Run Tests** | Post-merge safety check on main | -- |
| **Build & Push Docker Image** | Build image, push to GHCR with `latest` + `sha-XXXXXXX` tags | Test |
| **Deploy to Staging** | SSH into staging EC2, pull new image, restart container | Build & Push |
| **Smoke Test Staging** | curl the health endpoint to verify deployment | Deploy |

3. **While the pipeline runs**, explain each stage:
   - *"Tests run again after merge as a safety net -- the PR branch might have been out of date with main."*
   - *"The Docker image is pushed to GHCR with two tags: `latest` and a SHA-based tag like `sha-abc1234` for traceability."*
   - *"Deployment uses SSH to connect to the EC2 instance, pull the new image, stop the old container, and start a new one."*
   - *"The smoke test hits `/api/health` to verify the app is running after deployment."*

4. **After ~3 minutes**, the pipeline completes.

5. **Refresh the staging browser tab** (`http://<STAGING_IP>:5000`):
   - **The "money shot":** A **fifth feature card** appears -- "Personal Greeting" with a waving hand icon.
   - The version badge updates to show the new SHA-based version.

6. **Test the new endpoint in the terminal:**

```bash
curl -s http://<STAGING_IP>:5000/api/greet/Student | python3 -m json.tool
```

**Expected output:**
```json
{
    "message": "Hello, Student! Welcome to CI/CD Demo App vsha-abc1234."
}
```

### Key teaching points

> *"This is Continuous Deployment to staging. Every merge to main automatically deploys. No human intervention needed. The code went from a PR approval to running on a server in about 3 minutes."*

> *"Notice the concurrency group in the workflow: `concurrency: group: deploy-staging, cancel-in-progress: true`. If two PRs are merged quickly, the second deployment cancels the first. Only the latest code gets deployed."*

> *"The staging environment exists so we can verify changes in a production-like setting before releasing to real users. It is the dress rehearsal."*

---

## Step 7: Create a Release -- Watch CD to Production (5 min)

### What to do

1. **In the browser**, go to the GitHub repo.
2. Click **"Releases"** in the right sidebar (or navigate to `https://github.com/100625-gh-actions/cicd-demo-app/releases`).
3. Click **"Draft a new release"**.
4. Fill in:
   - **Tag:** `v1.1.0` (click "Create new tag: v1.1.0 on publish")
   - **Release title:** `v1.1.0 -- Personal Greeting Feature`
   - **Description:** Click **"Generate release notes"** or type: `Adds the /api/greet endpoint for personalized greetings.`
5. Make sure **"Set as the latest release"** is checked.
6. Click **"Publish release"**.

> NOTE: You can also create the release via the CLI:
> ```bash
> gh release create v1.1.0 --title "v1.1.0 -- Personal Greeting Feature" --notes "Adds the /api/greet endpoint for personalized greetings."
> ```

### What to observe

1. **Go to the Actions tab:**
   - A new workflow run starts: **CD -- Deploy to Production**.
   - This was triggered by the `release: published` event.

2. **Click into the workflow run.** Show the jobs:

| Job | Purpose | Depends On |
|-----|---------|------------|
| **Build Release Image** | Build image, push to GHCR with `v1.1.0` + `latest` + SHA tags | -- |
| **Deploy to Production** | SSH into production EC2, deploy the release image | Build Release |
| **Generate Release Notes** | Auto-update release description with changelog | Deploy to Production |

3. **PAUSE at the approval gate!**
   - The **Deploy to Production** job shows a yellow banner: **"Waiting for review"**.
   - This is the **environment protection rule** on the `production` environment.
   - Show the students the approval dialog.

4. **Explain the approval gate** before clicking Approve:

> *"This is the human checkpoint. The image is built and ready. But it will NOT reach production until someone with the right permissions clicks Approve. This is how companies balance automation with human oversight."*

5. **Click "Review deployments"**, check the `production` environment, and click **"Approve and deploy"**.

6. **Wait for deployment** (~2 minutes).

7. **Refresh the production browser tab** (`http://<PRODUCTION_IP>:5000`):
   - The production app now shows the **"Personal Greeting"** feature card.
   - The version badge shows **`v1.1.0`**.
   - The environment badge shows **"production"** in green.

8. **Test the endpoint against production:**

```bash
curl -s http://<PRODUCTION_IP>:5000/api/greet/World | python3 -m json.tool
```

**Expected output:**
```json
{
    "message": "Hello, World! Welcome to CI/CD Demo App vv1.1.0."
}
```

9. **Check the release page** -- the release notes have been auto-updated with a changelog section listing the merged PR.

### Key teaching points

> *"Production deployments use semantic versioning. The tag `v1.1.0` tells everyone: minor version bump (new feature, backward compatible). This is different from staging, which uses SHA-based tags."*

> *"The Docker image tagged `v1.1.0` is immutable. Once built, it never changes. This is what makes rollbacks possible -- we can always go back to a known-good version."*

> *"Compare the concurrency settings: staging uses `cancel-in-progress: true` (always deploy the latest), while production uses `cancel-in-progress: false` (never cancel an in-progress production deployment). These are deliberate design choices."*

---

## Step 8: Introduce a Bug -- Act 2 Begins (3 min)

> NOTE: Tell the students: "That was the happy path. Now let us see what happens when things go wrong."

### What to do

1. **Create a new branch:**

```bash
git checkout main
git pull origin main
git checkout -b fix/price-display
```

2. **Introduce the bug** in `app/app.py`. Find the `api_items` function (around line 101) and **replace it** with:

```python
@app.route("/api/items")
def api_items():
    """Return the list of all demo items."""
    # BUG: accidentally multiplying prices by 100!
    buggy_items = [
        {**item, "price": item["price"] * 100} for item in ITEMS
    ]
    return jsonify(buggy_items)
```

3. **Commit and push:**

```bash
git add app/app.py
git commit -m "fix: update price display formatting"
git push origin fix/price-display
```

4. **Create a PR and merge quickly** (skip the review for the sake of time):

```bash
gh pr create --title "fix: update price display formatting" --body "Updates price display logic."
```

> NOTE: For speed, you can merge via CLI if branch protection allows, or temporarily adjust protection rules. Alternatively, approve the PR quickly yourself and merge.

```bash
# After CI passes:
gh pr merge --squash
```

5. **Watch the CD Staging workflow trigger** in the Actions tab.

6. **After deployment completes**, check the staging app:

```bash
curl -s http://<STAGING_IP>:5000/api/items | python3 -m json.tool
```

**Expected output (broken prices!):**
```json
[
    {"id": 1, "name": "Widget A", "price": 999.0},
    {"id": 2, "name": "Widget B", "price": 1499.0},
    {"id": 3, "name": "Gadget C", "price": 2450.0},
    {"id": 4, "name": "Gizmo D", "price": 725.0},
    {"id": 5, "name": "Doohickey E", "price": 1999.0}
]
```

### What to observe

- Widget A now shows **$999.00** instead of **$9.99**.
- All prices are 100x what they should be.
- The bug passed CI because the existing tests do not check the items endpoint response data in a way that catches the multiplication.

### Key teaching points

> *"Oh no. The prices are broken. Widget A costs $999 instead of $9.99. This is the kind of bug that could cost a company real money if it reached production."*

> *"Notice that CI passed -- all tests were green. This is a good reminder that CI is only as strong as your test suite. The tests check that the endpoint returns 200 and that items have the right keys, but they did not assert the exact price values from the endpoint itself. Lesson: write tests that validate business logic, not just status codes."*

> *"But here is the good news: the bug is only on staging. It has NOT reached production yet. And even if it had, we have a rollback mechanism."*

---

## Step 9: Rollback! (3 min)

### What to do

1. **Go to the Actions tab** in the browser.
2. In the left sidebar, click **"Rollback"** workflow.
3. Click the **"Run workflow"** button (top right).
4. Fill in the form:

| Field | Value |
|-------|-------|
| **Version to rollback to** | `v1.1.0` |
| **Target environment** | `staging` |
| **Reason for rollback** | `Price calculation bug -- items showing 100x prices` |

5. Click **"Run workflow"**.

### What to observe

1. **Watch the Rollback workflow run:**
   - **Job 1: Validate Rollback Version** -- uses `docker manifest inspect` to verify the `v1.1.0` image exists in GHCR before attempting anything. This is the "fail fast" pattern.
   - **Job 2: Rollback staging** -- SSHes into the staging EC2, pulls the `v1.1.0` image, stops the current container, starts a new one with the old image.

2. **After ~2 minutes**, the rollback completes.

3. **Refresh the staging browser tab** or hit the API:

```bash
curl -s http://<STAGING_IP>:5000/api/items | python3 -m json.tool
```

**Expected output (prices are correct again!):**
```json
[
    {"id": 1, "name": "Widget A", "price": 9.99},
    {"id": 2, "name": "Widget B", "price": 14.99},
    {"id": 3, "name": "Gadget C", "price": 24.50},
    {"id": 4, "name": "Gizmo D", "price": 7.25},
    {"id": 5, "name": "Doohickey E", "price": 19.99}
]
```

```bash
# Verify the version rolled back
curl -s http://<STAGING_IP>:5000/api/version | python3 -m json.tool
```

**Expected output:**
```json
{
    "version": "v1.1.0",
    "environment": "staging"
}
```

### Key teaching points

> *"Rollback is not magic. It is just 'deploy a known-good version.' We pull the v1.1.0 Docker image that we know works and run it. That is why immutable, versioned Docker images matter. The image tagged v1.1.0 today is exactly the same image that was tagged v1.1.0 yesterday."*

> *"Look at the rollback workflow inputs: version, environment, and reason. The reason field creates an audit trail. Six months from now, someone can look at the workflow run and understand why this rollback happened."*

> *"The concurrency group for the rollback is `deploy-staging` -- the same group used by the CD Staging workflow. This means a rollback and a deployment cannot run at the same time. They queue up and run one at a time."*

> *"Rollback is a band-aid, not the cure. It buys you time. The bug is still in the code on main. We need to fix it properly."*

---

## Step 10: Fix the Bug Properly (3 min)

### What to do

1. **Fix the code.** Go back to `app/app.py` and restore the original `api_items` function:

```python
@app.route("/api/items")
def api_items():
    """Return the list of all demo items."""
    return jsonify(ITEMS)
```

2. **Commit, push, and create a PR:**

```bash
git checkout main
git pull origin main
git checkout -b fix/revert-price-bug
```

Make the fix in `app/app.py`, then:

```bash
git add app/app.py
git commit -m "fix: revert accidental price multiplication"
git push origin fix/revert-price-bug
gh pr create --title "fix: revert accidental price multiplication" --body "Reverts the price bug introduced in the previous PR. Items were showing 100x their actual price."
```

3. **Wait for CI to pass**, then merge the PR.

4. **Watch CD Staging deploy the fix** in the Actions tab.

5. **Verify staging** after deployment:

```bash
curl -s http://<STAGING_IP>:5000/api/items | python3 -m json.tool
```

Prices should be correct: Widget A = 9.99, Widget B = 14.99, etc.

6. **(Optional, if time permits)** Create release `v1.1.1` to deploy the fix to production:

```bash
gh release create v1.1.1 --title "v1.1.1 -- Fix price calculation bug" --notes "Reverts accidental price multiplication that caused all item prices to display 100x their actual value."
```

Then approve the production deployment when prompted.

### Key teaching points

> *"The proper flow after an incident is: Rollback first (stop the bleeding), then fix the code, then deploy the fix through the normal pipeline. Rollback gives you time. The proper fix goes through CI, review, and staging before reaching production."*

> *"Notice the version bump: v1.1.0 to v1.1.1. The third number is the patch version -- it means 'bug fix, no new features, no breaking changes.' This follows semantic versioning."*

> *"If this were a real incident, you would also write a post-mortem: What happened? Why did it happen? How did we respond? What will we do to prevent it from happening again? (In this case: add tests that check actual price values.)"*

---

## Wrap-Up (3 min)

### What to do

1. **Draw the complete flow** on the whiteboard (or show a prepared slide):

```
Branch --> PR --> CI Checks --> Review --> Merge --> Staging Deploy --> Release --> Prod Deploy
                                                                         |
                                                                         +-> Rollback (emergency)
```

2. **Show all 6 workflows** in the `.github/workflows/` directory:

| # | Workflow File | Workflow Name | Trigger | Purpose |
|---|--------------|---------------|---------|---------|
| 1 | `ci.yml` | CI Pipeline | `pull_request` (opened, synchronize, reopened) | Lint, Test, Build, post summary comment |
| 2 | `pr-review.yml` | PR Review Automation | `pull_request_review` (submitted) | Auto-add/remove labels based on review state |
| 3 | `cd-staging.yml` | CD -- Deploy to Staging | `push` to `main` | Test, build, push to GHCR, deploy to staging EC2, smoke test |
| 4 | `cd-production.yml` | CD -- Deploy to Production | `release` (published) | Build release image, deploy with manual approval, auto-generate release notes |
| 5 | `rollback.yml` | Rollback | `workflow_dispatch` (manual) | Validate version exists, deploy specified version to chosen environment |
| 6 | `scheduled-health.yml` | Scheduled Health Checks | `schedule` (cron: every 6 hours) + `workflow_dispatch` | Check staging + production health endpoints, create GitHub Issue on failure |

3. **Mention the scheduled health check:**

> *"There is one workflow we did not trigger today: the scheduled health check. It runs automatically every 6 hours via a cron schedule. It hits the /api/health endpoint on both staging and production. If either one is down, it automatically creates a GitHub Issue to alert the team. This is a basic form of synthetic monitoring."*

4. **Recap the key concepts learned:**

| Concept | Where We Saw It |
|---------|-----------------|
| Feature branches | Step 2 -- `git checkout -b feature/add-greeting` |
| Pull requests as quality gates | Step 4 -- CI must pass before merge |
| Parallel CI jobs | Step 4 -- Lint and Test run simultaneously |
| Job dependencies (`needs:`) | Step 4 -- Build waits for Lint + Test |
| Automated PR labeling | Step 5 -- "approved" label added automatically |
| Continuous Deployment (staging) | Step 6 -- Merge to main auto-deploys |
| Docker image tagging (SHA + version) | Steps 6 and 7 |
| Manual approval gates | Step 7 -- Production requires human approval |
| Semantic versioning | Step 7 -- v1.1.0 |
| Emergency rollback | Step 9 -- Deploy a known-good version |
| Immutable artifacts | Step 9 -- Docker image tags never change |
| Concurrency control | Steps 6 and 9 -- Prevent parallel deployments |
| `workflow_dispatch` (manual triggers) | Step 9 -- Rollback form with inputs |
| Post-incident process | Step 10 -- Rollback, fix, test, deploy |

5. **Open the floor for Q&A.**

---

## Appendix A: Quick Reference -- All Workflows

| Workflow | File | Trigger | Jobs | Key Features |
|----------|------|---------|------|-------------|
| CI Pipeline | `ci.yml` | `pull_request` | Lint, Test, Build, CI Summary | Parallel lint/test, Docker build verification, PR comment with results |
| PR Review Automation | `pr-review.yml` | `pull_request_review` | Auto-Label PR | Adds "approved" or "changes-requested" labels |
| CD Staging | `cd-staging.yml` | `push` to `main` | Test, Build & Push, Deploy Staging, Smoke Test | GHCR push, SSH deploy, health check verification |
| CD Production | `cd-production.yml` | `release` published | Build Release, Deploy Production, Generate Release Notes | Manual approval gate, version-tagged images, auto-changelog |
| Rollback | `rollback.yml` | `workflow_dispatch` | Validate, Rollback | Image existence check, environment selection dropdown, audit logging |
| Health Checks | `scheduled-health.yml` | `schedule` (cron) + `workflow_dispatch` | Check Staging, Check Production, Report | Auto-creates GitHub Issues, dedup with existing open issues |

---

## Appendix B: Repository Secrets

| Secret | Scope | Value | Used By |
|--------|-------|-------|---------|
| `STAGING_HOST` | Environment: `staging` | Public IP of staging EC2 (e.g., `3.95.xxx.xxx`) | `cd-staging.yml`, `rollback.yml`, `scheduled-health.yml` |
| `PRODUCTION_HOST` | Environment: `production` | Public IP of production EC2 (e.g., `54.210.xxx.xxx`) | `cd-production.yml`, `rollback.yml`, `scheduled-health.yml` |
| `SSH_PRIVATE_KEY` | Repository-level | PEM private key content | `cd-staging.yml`, `cd-production.yml`, `rollback.yml` |
| `GITHUB_TOKEN` | Auto-provided | Automatic | All workflows (GHCR login, PR comments, issue creation) |

---

## Appendix C: Useful Commands

### Git Commands

| Command | Purpose |
|---------|---------|
| `git checkout -b feature/my-feature` | Create a new feature branch |
| `git add app/app.py tests/test_app.py` | Stage specific files |
| `git commit -m "feat: description"` | Commit with conventional message |
| `git push origin feature/my-feature` | Push branch to remote |
| `git checkout main && git pull` | Switch to main and update |

### GitHub CLI (`gh`) Commands

| Command | Purpose |
|---------|---------|
| `gh pr create --title "..." --body "..."` | Create a pull request |
| `gh pr merge --squash` | Squash-merge the current PR |
| `gh pr list` | List open pull requests |
| `gh pr view` | View current PR details |
| `gh release create v1.1.0 --title "..." --notes "..."` | Create and publish a release |
| `gh release list` | List all releases |
| `gh run list` | List recent workflow runs |
| `gh run view` | View a specific workflow run |
| `gh run watch` | Watch a running workflow in real time |

### curl Commands for the App

| Command | Purpose |
|---------|---------|
| `curl -s http://<IP>:5000/api/health \| python3 -m json.tool` | Check application health |
| `curl -s http://<IP>:5000/api/version \| python3 -m json.tool` | Get version and build info |
| `curl -s http://<IP>:5000/api/items \| python3 -m json.tool` | List all items |
| `curl -s http://<IP>:5000/api/items/1 \| python3 -m json.tool` | Get a single item by ID |
| `curl -s http://<IP>:5000/api/greet/Alice \| python3 -m json.tool` | Test the greeting endpoint |

### Docker Commands (on EC2 via SSH)

| Command | Purpose |
|---------|---------|
| `docker ps` | List running containers |
| `docker logs cicd-demo-app` | View application logs |
| `docker inspect cicd-demo-app` | Inspect container configuration |
| `docker images` | List downloaded images |
| `docker stats` | Live resource usage |

### Make Commands (local development)

| Command | Purpose |
|---------|---------|
| `make install` | Install all dependencies (production + dev) |
| `make test` | Run pytest with verbose output |
| `make test-cov` | Run tests with coverage report |
| `make lint` | Run flake8 linter |
| `make run` | Start Flask dev server on port 5000 |
| `make docker-build` | Build the Docker image locally |
| `make docker-run` | Run the app in a local Docker container |
| `make clean` | Remove generated files and caches |

---

## Appendix D: Project File Structure

```
cicd-demo-app/
|
|-- .github/
|   +-- workflows/
|       |-- ci.yml                  # CI pipeline (PR checks)
|       |-- pr-review.yml           # Auto-label on review
|       |-- cd-staging.yml          # Deploy to staging on merge
|       |-- cd-production.yml       # Deploy to production on release
|       |-- rollback.yml            # Manual rollback
|       +-- scheduled-health.yml    # Scheduled health checks
|
|-- app/
|   |-- app.py                      # Flask application (routes, API endpoints)
|   |-- templates/
|   |   +-- index.html              # HTML UI template (Jinja2)
|   |-- requirements.txt            # Production dependencies (Flask, gunicorn)
|   +-- requirements-dev.txt        # Dev/test dependencies (pytest, flake8)
|
|-- tests/
|   |-- conftest.py                 # Pytest fixtures (app, client)
|   |-- test_app.py                 # Tests for all endpoints
|   +-- test_items.py               # Additional tests for items API
|
|-- terraform/
|   |-- main.tf                     # EC2 instances, security group
|   |-- variables.tf                # Input variables
|   |-- outputs.tf                  # Output values (IPs, URLs)
|   |-- user_data_staging.sh        # EC2 boot script for staging
|   |-- user_data_production.sh     # EC2 boot script for production
|   +-- terraform.tfvars.example    # Example variable values
|
|-- Dockerfile                      # Multi-stage Docker build
|-- .dockerignore                   # Files excluded from Docker build
|-- .flake8                         # Flake8 linter configuration
|-- .gitignore                      # Git ignore rules
+-- Makefile                        # Development shortcuts
```

---

## Appendix E: Troubleshooting

### CI Pipeline fails on the PR

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| Lint job fails | Code style violation (flake8) | Run `make lint` locally, fix the reported issues |
| Test job fails | Test assertion error | Run `make test` locally, check the failing test output |
| Build job fails | Dockerfile issue | Run `make docker-build` locally to reproduce |
| Build job skipped | Lint or Test failed | Fix the upstream failure first -- Build depends on both |

### CD Staging does not trigger after merge

| Check | How |
|-------|-----|
| Was the merge to `main`? | Confirm in the PR page -- it should show "merged into main" |
| Is the workflow file on `main`? | Check `.github/workflows/cd-staging.yml` exists on main |
| Is there a concurrency conflict? | Check Actions tab for queued or in-progress staging deployments |

### Production deployment stuck at approval

| Check | How |
|-------|-----|
| Is the `production` environment configured? | Repo Settings > Environments > production |
| Are required reviewers set? | The environment must have at least one required reviewer |
| Is the current user a required reviewer? | Only designated reviewers can approve |

### Rollback fails at validation

| Symptom | Cause | Fix |
|---------|-------|-----|
| "Image NOT found in GHCR" | The version tag does not exist | Check available tags at the repo's Packages tab |
| Wrong tag format | User typed `1.0.0` instead of `v1.0.0` | Include the `v` prefix for release versions |

### App is not accessible after deployment

| Check | Command |
|-------|---------|
| Is the container running? | SSH in and run `docker ps` |
| Container logs | `docker logs cicd-demo-app` |
| Is port 5000 open in the security group? | Check AWS Console or `terraform show` |
| Is the EC2 instance running? | Check AWS Console |

---

## Appendix F: Timing Guide

Use this to pace yourself during the demo. The total should be 30-45 minutes depending on Q&A.

| Section | Allocated Time | Running Total |
|---------|---------------|---------------|
| Introduction | 5 min | 5 min |
| Step 1: Explore the Application | 3 min | 8 min |
| Step 2: Create a Feature Branch | 2 min | 10 min |
| Step 3: Add the Greeting Feature | 5 min | 15 min |
| Step 4: Open PR / Watch CI | 5 min | 20 min |
| Step 5: Review PR / Watch Labels | 3 min | 23 min |
| Step 6: Merge / Watch CD Staging | 5 min | 28 min |
| Step 7: Release / Watch CD Production | 5 min | 33 min |
| Step 8: Introduce a Bug | 3 min | 36 min |
| Step 9: Rollback | 3 min | 39 min |
| Step 10: Fix the Bug Properly | 3 min | 42 min |
| Wrap-Up + Q&A | 3 min | 45 min |

> NOTE: Steps 4 and 6 include ~2-3 minutes of waiting for pipelines. Use this time to explain what is happening at each stage. Do not just stand there in silence -- narrate the workflow graph, explain the job dependencies, and call out interesting lines in the workflow YAML. The wait time is teaching time.

---

## Appendix G: What If Something Goes Wrong During the Demo

| Problem | Recovery |
|---------|----------|
| CI takes too long | Have a pre-recorded screenshot or GIF of a successful CI run ready |
| EC2 instance is unreachable | Check AWS Console; restart the instance; re-run Terraform if needed |
| GHCR login fails | Verify `GITHUB_TOKEN` has `packages:write` scope; check if the org allows GHCR |
| Merge button is blocked | Check branch protection rules; ensure CI passed; ensure PR is approved |
| Rollback image not found | Use `latest` as the version instead of a specific tag |
| Student asks a question you cannot answer | Write it down, promise to follow up, and move on. Do not derail the demo. |

> NOTE: Always do a full dry run of the demo at least once before presenting to students. Every deployment to a live server is an opportunity for something unexpected to happen. The dry run lets you discover and fix issues in advance.

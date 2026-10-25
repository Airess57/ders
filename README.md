# Temperature Analyzer — SDO Deployment Lab

## What will you learn?

Work through the levels in order. You will use the same C application to build a Docker image, run Kubernetes Jobs, and deploy a web service.

| Level | Topic                 | Result                                                   |
| ----- | --------------------- | -------------------------------------------------------- |
| 0     | Git & GitHub          | Your source files are in a repository                    |
| 1     | C & Docker            | Your C program runs locally and in an image              |
| 2     | Kubernetes Job        | A single batch analysis completes                        |
| 3     | Kubernetes CronJob    | Kubernetes creates Jobs on a schedule                    |
| 4     | Kubernetes Deployment | A long-running web service stays available and can scale |
| Recap | GitHub Actions        | Prebuilt workflows compile and test the same project     |

## Project files

```text
sdo-deployment-tutorial/
├── monitor.c                    # C temperature analyzer
├── Dockerfile                   # Multi-stage build: GCC builder + Python runtime
├── server.py                    # Minimal HTTP server; executes compiled C binary
├── index.html                   # Browser form to submit temperature readings
├── Job.yaml                     # Run the C program once
├── CronJob.yaml                 # Schedule repeated one-time analyses
├── Deployment.yaml              # Keep the HTTP server running
├── test.sh                      # Local C test cases
├── test-web.sh                  # HTTP tests
├── .github/workflows/ci.yml     # C, manifest and Docker checks
├── .github/workflows/ci-website.yml # Web tests
└── .gitignore
```

The C program accepts a list of temperature readings (integers from **-50 through 100**) and calculates minimum, maximum, average, count of readings **>= 30 °C**, and an overall status. For example:

```text
$ ./monitor 22 25 31 28 35
Readings: 5
Minimum: 22 C
Maximum: 35 C
Average: 28.2 C
Warnings (>= 30 C): 2
Status: WARNING
```

An input such as `abc` is invalid: the program prints an error and exits with a **non-zero exit code**. This makes successful versus failed execution easy to observe.

**Starter code:** <https://github.com/HABITS-Lab-MMacedo/sdo-deployment-tutorial>

---

## Level 0 — Git & GitHub: Work in your own repository

**Starter repository:** <https://github.com/HABITS-Lab-MMacedo/sdo-deployment-tutorial>

**Goal:** Download the starter code from the course repository, connect your local copy to a new repository under **your own GitHub account**, and push your work **at the end of the tutorial**. Do not push to the HABITS-Lab-MMacedo repository.

1. Clone the course repository and enter its folder:

   ```bash
   git clone https://github.com/HABITS-Lab-MMacedo/sdo-deployment-tutorial.git
   cd sdo-deployment-tutorial
   git status
   ```

2. Inspect where the clone would normally push:
   ```bash
   git remote -v
   ```

**Question:** Why does `origin` currently point to `HABITS-Lab-MMacedo`? A clone automatically remembers the URL it came from.

3. On GitHub, create a **new, empty repository in your own account** (suggested name: `sdo-deployment-tutorial`). Do **not** initialize it with a README, `.gitignore`, or license. Copy its HTTPS URL, such as `https://github.com/YOUR-USERNAME/sdo-deployment-tutorial.git`.

4. Remove the course remote and add your own repository as `origin`:

   ```bash
   git remote remove origin
   git remote add origin https://github.com/YOUR-USERNAME/sdo-deployment-tutorial.git
   git remote -v
   ```

   Replace `YOUR-USERNAME` with **your own GitHub username**. Make sure both fetch and push now show **your** URL, not the course URL. Do not run `git init`; cloning already created the local Git repository. You can check your branch with `git branch --show-current` (expected: `main`).

5. **Do not push yet.** Continue with Levels 1–4 and make your changes locally. At the **end of the tutorial**, follow the \_\_Final submission — Push your own repository\_\_ section to commit and push everything together.

**Check your result:** The starter code is on your computer, and `origin` points to your own empty repository. You are ready to work without pushing to the course repository.

---

## Level 1 — C & Docker (multi-stage build)

**Files:** `monitor.c`, `Dockerfile`, `test.sh`; Docker running.

**Why are we doing this?** Docker packages a program with the environment required to run it. A **multi-stage Dockerfile** compiles C with GCC in one stage but keeps GCC out of the final runtime image.

1. Compile and run the C program with GCC:
   ```bash
   gcc -std=c11 -Wall -Wextra -Werror -O2 monitor.c -o monitor
   ./monitor 22 25 31 28 35
   bash test.sh
   ```

**GCC command explained:**

| Parameter    | Meaning                                        |
| ------------ | ---------------------------------------------- |
| `gcc`        | Compiles the C source code into an executable. |
| `-std=c11`   | Uses the C11 language standard.                |
| `-Wall`      | Enables common compiler warnings.              |
| `-Wextra`    | Enables additional warnings.                   |
| `-Werror`    | Treats enabled warnings as errors.             |
| `-O2`        | Enables compiler optimizations.                |
| `monitor.c`  | Source file to compile.                        |
| `-o monitor` | Names the output executable `monitor`.         |

On Windows, run this inside WSL or a GCC/Bash-capable environment. `bash test.sh` requires Bash and GCC.

2. Read `Dockerfile`. Locate `FROM gcc:14.2 AS builder` and `FROM python:3.15-slim`. Which stage builds the executable? Which stage runs the application?

3. Build the Docker image:

   ```bash
   docker build -t temperature-monitor:1.0 .
   ```

4. Run the C executable in Docker (the explicit `/app/monitor` overrides the default Python server command):

   ```bash
   docker run --rm temperature-monitor:1.0 /app/monitor 22 25 31 28 35
   ```

5. Try an invalid input:
   ```bash
   docker run --rm temperature-monitor:1.0 /app/monitor abc
   ```

**Question:** Why does the program exit unsuccessfully? Does a high but valid temperature (e.g. 35) count as a program error?

6. Inspect the image:
   ```bash
   docker images temperature-monitor:1.0
   ```

**Question:** Why is the runtime image not required to contain GCC?

7. Run the web interface locally:

   ```bash
   docker run --rm -p 8000:8000 temperature-monitor:1.0
   ```

   Open <http://localhost:8000> in your browser. Stop with `Ctrl+C` before proceeding if you need the terminal. This is a local Docker demonstration, **not a Kubernetes Deployment**.

**Check your result:** the analysis prints `Average: 28.2 C` and `Warnings (>= 30 C): 2`. The invalid input prints an error. The final image runs both batch commands and (by default) the web server.

---

## Level 2 — Kubernetes Job (run once)

**Files:** `Job.yaml` plus `temperature-monitor:1.0`; working Kubernetes cluster.

**Why are we doing this?** A Job executes a task expected to finish. Unlike a Deployment, it does not keep a service running forever.

1. Confirm the cluster is ready:

   ```bash
   kubectl get nodes
   ```

2. If using **Minikube**, load the already-built image:

   ```bash
   minikube image load temperature-monitor:1.0
   ```

   If using **kind**, use `kind load docker-image temperature-monitor:1.0` instead. Use the image-loading method suitable for the cluster chosen in Setup.

3. Open `Job.yaml`. Notice `apiVersion: batch/v1`, `kind: Job`, `backoffLimit: 0`, `restartPolicy: Never`, `command: ["/app/monitor"]`, and the temperature `args`.

4. Create the Job and view its result:

   ```bash
   kubectl apply -f Job.yaml
   kubectl get jobs
   kubectl logs job/temperature-job
   ```

   The Job should eventually display `Complete` / `1/1` and the log should show computed statistics. If the Pod is still starting, wait briefly and retry.

5. Change the `args` temperatures inside `Job.yaml`. Because the Job Pod template cannot simply be changed in place, delete the old Job and create a new one:

   ```bash
   kubectl delete -f Job.yaml
   kubectl apply -f Job.yaml
   kubectl logs job/temperature-job
   ```

   Do not edit the Job name or labels unless you also adapt the commands.

**Questions:** What is the difference between `command` and `args`? What does `backoffLimit: 0` mean? What do CPU `requests` and `limits` mean?

**Check your result:** one batch analysis completes and its output is visible in the Job logs.

---

## Level 3 — Kubernetes CronJob (scheduled Job)

**Files:** `CronJob.yaml`; cluster and image from Level 2.

**Why are we doing this?** A CronJob creates Jobs at scheduled times. It is useful for repeated one-time tasks, not for keeping a web server running.

1. Open `CronJob.yaml`. Find `schedule: "*/5 * * * *"` (every five minutes), `concurrencyPolicy: Forbid`, `jobTemplate` and its nested Pod configuration.

2. Create the CronJob:

   ```bash
   kubectl apply -f CronJob.yaml
   kubectl get cronjobs
   ```

3. Instead of waiting for the next scheduled run, start a Job manually:

   ```bash
   kubectl create job temperature-manual --from=cronjob/temperature-cron
   kubectl get jobs
   kubectl logs job/temperature-manual
   ```

4. **Question:** How is a CronJob different from a Job? What does the `schedule` value mean? Why does a manual trigger not change the CronJob's schedule?

5. Run `kubectl get jobs` again after a scheduled execution and compare the names of automatically created Jobs. You may not see one immediately.

**Check your result:** the manual Job completes and prints temperature statistics. A scheduled CronJob will also create Jobs at the specified times while it exists.

---

## Level 4 — Kubernetes Deployment

**Files:** `Deployment.yaml`, `server.py`, `index.html`, `monitor.c`, and the same Docker image.

**Why are we doing this?** A Deployment manages **long-running Pods** and keeps the desired number of replicas available. Our Docker image defaults to `python3 server.py`; the web server starts the compiled C executable whenever someone submits readings.

1. Open `Deployment.yaml`. Find `apiVersion: apps/v1`, `kind: Deployment`, `replicas: 1`, `selector.matchLabels`, the matching Pod labels, `containerPort: 8000`, and the `/health` readiness probe.

2. Create the Deployment:

   ```bash
   kubectl apply -f Deployment.yaml
   kubectl get deployments
   kubectl get pods
   ```

   The Deployment should eventually show `1/1` ready. If not, inspect `kubectl describe pods` for errors.

3. Expose it to **your own laptop** with port forwarding (keep this terminal open):

   ```bash
   kubectl port-forward deployment/temperature-monitor 8080:8000
   ```

4. Open <http://localhost:8080>. Enter `22, 25, 31, 28, 35`, click **Analyze temperatures**, and compare the output to Level 1. This web page is provided ready-made; you are **not** expected to write HTML or Python.

5. In a \_\_second terminal\_\_, change the desired number of replicas:

   ```bash
   kubectl scale deployment temperature-monitor --replicas=2
   kubectl get deployments
   kubectl get pods
   ```

6. **Questions:** Why do two Pods appear? Which Deployment field decides how many Pods Kubernetes should keep? How is this different from a Job completing and stopping?

7. Try self-healing: identify a Deployment Pod using `kubectl get pods`, then delete it with `kubectl delete pod <POD-NAME>`. Run `kubectl get pods` again. Does Kubernetes create a replacement?

**Check your result:** a browser can submit readings to a running Deployment; Kubernetes maintains two Pods after scaling. Note: `kubectl port-forward deployment/...` forwards to one selected Pod and is a **local development tool**, not a production public endpoint or load-balancing demonstration. When scaling, you may need to restart port-forward if its selected Pod disappears.

---

## GitHub Actions recap

After pushing your changes, check the two GitHub Actions workflows. They automatically test the C application and web server; they do not deploy to Minikube.
| Workflow | File | What you should see |
| --------------------- | ---------------------------------- | --------------------------------------------------------------------- |
| **CI - C and Docker** | `.github/workflows/ci.yml` | `lint`, `build-and-test`, `kubernetes-manifests`, `docker-build` jobs |
| **CI - Website** | `.github/workflows/ci-website.yml` | `website-test` job |

1. After completing the **Final submission** section below, open the **Actions** tab in **your own GitHub repository**. If prompted, enable Actions for the repository. This is a recap of previously learned CI, not deployment automation.

2. Select **CI - C and Docker**, open the latest run and inspect the four jobs. Download its `build-output` artifact to view `test-results.txt`.

3. Select **CI - Website** and see whether the HTTP endpoint tests pass.

4. In a later commit, add another valid example to `test.sh` and push it to your own repository. Which workflow runs, and which job tests the C program?

**Important:** These are continuous **integration** workflows. They compile, test and build; they do **not** deploy to your own laptop's Minikube. The manifest job performs only basic YAML/kind checks, not a complete Kubernetes execution test.

---

## Finish — Push your work to GitHub

Push your own repository at the end of the lab. You configured your `origin` in Level 0, but have not pushed yet.

1. Check which files changed and where you will push:
   ```bash
   git status
   git remote -v
   ```

**Before pushing:** `origin` must point to `https://github.com/YOUR-USERNAME/sdo-deployment-tutorial.git` (or the actual name of your own repository). **Never push to the course repository.**

2. Make a small change so you have your own work to commit. For example, modify the temperature sample values in `Job.yaml`, or add a short note to your copy of the README. If you changed a Job's Pod template, remember that the existing Kubernetes Job must be deleted and recreated to pick up that change.

3. Stage and commit your work:

   ```bash
   git add .
   git commit -m "Complete SDO deployment tutorial"
   ```

   If Git reports `nothing to commit`, make a small meaningful file change and retry. Do not commit generated binaries or temporary files; `.gitignore` excludes the compiled output.

4. Push your `main` branch to your own remote:

   ```bash
   git push -u origin main
   ```

5. Open `https://github.com/YOUR-USERNAME/sdo-deployment-tutorial` in a browser and **verify** that your files and commit appear. Check the **Actions** tab for CI results. A successful push does not by itself mean the CI jobs passed; inspect the run.

**Check your result:** Your individual GitHub repository contains your tutorial work, and the course starter repository remains unchanged.

---

## Cleanup after the lab

Close any `kubectl port-forward` terminal with `Ctrl+C`, then delete only the resources created for this project:

```bash
kubectl delete -f Deployment.yaml -f CronJob.yaml -f Job.yaml --ignore-not-found
kubectl delete job temperature-manual --ignore-not-found
kubectl get jobs,cronjobs,deployments
```

The CronJob is removed so it will not keep creating new Jobs. To stop (without deleting) Minikube after class: `minikube stop`.

---

## Troubleshooting / common problems

| Problem                                      | Why it happens                                             | What to try                                                                                                               |
| -------------------------------------------- | ---------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| `git: command not found`                     | Git missing / terminal not restarted                       | Install Git, restart terminal and check `git --version`                                                                   |
| Git asks for identity on commit              | Name and email not configured                              | `git config --global user.name "Your Name"` and `git config --global user.email "you@example.com"` (use your own details) |
| `remote origin already exists`               | A clone already has an origin remote                       | Follow Level 0: `git remote remove origin`, then `git remote add origin` with **your own repository URL**                 |
| GitHub rejects `git push`                    | Wrong remote URL, authentication, or repository permission | Check `git remote -v`: it must point to **your own** repository. Sign in with GitHub using an available supported method  |
| `Cannot connect to the Docker daemon`        | Docker is not running                                      | Start Docker Desktop / Docker Engine; check `docker ps`                                                                   |
| Docker image not found in Kubernetes         | Local Docker and cluster use different image stores        | `minikube image load temperature-monitor:1.0` (or the matching cluster load command)                                      |
| `ErrImagePull` / `ImagePullBackOff`          | Image missing or tag mismatched                            | Recheck image tag, chosen cluster/context, and the image-load command                                                     |
| `CrashLoopBackOff`                           | Long-running container is exiting repeatedly               | Run `kubectl logs deployment/temperature-monitor` and `kubectl describe pods`                                             |
| `ContainerCreating` or `Pending`             | Cluster is still starting / cannot schedule                | Wait briefly; inspect `kubectl describe pod <POD-NAME>`                                                                   |
| Job already exists but output did not change | Jobs do not rerun after editing args                       | Delete the old Job, then reapply the file                                                                                 |
| `kubectl` connected to wrong cluster         | Incorrect current context                                  | `kubectl config current-context`, then select the intended cluster                                                        |
| `address already in use` on port 8080        | Local port is occupied                                     | Use `kubectl port-forward deployment/temperature-monitor 8081:8000` and open localhost:8081                               |
| Browser cannot connect                       | port-forward not running / selected Pod exited             | Re-run port-forward; check Deployment readiness                                                                           |
| GCC or Bash missing                          | Local C compilation and `bash test.sh` are used            | Follow the installation reference below; on Windows use WSL or a suitable GCC/Bash environment                            |
| Actions workflow fails                       | Compilation, tests or image build failed                   | Open GitHub Actions and expand the red step to read the log                                                               |

If your setup fails, read the matching troubleshooting entry or follow the live demonstration and retry the commands later.

## Check your understanding

1. Why do we use a multi-stage Dockerfile?

2. What happens after a **Job** successfully finishes?

3. How does a **CronJob** create Jobs automatically?

4. Why does a **Deployment** use a long-running process?

5. What happens when we scale a Deployment from one replica to two?

6. What does GitHub Actions verify, and why does it not automatically deploy to local Minikube?

**Remember:** The \_\_same C application\_\_ can be packaged in Docker and used by different Kubernetes controllers. A Job runs a finite task, a CronJob schedules Jobs, and a Deployment maintains a long-running service.

---

## Appendix — Tool installation and environment setup (reference)

Most students should already have these tools installed. **This appendix is for anyone missing a tool or needing to troubleshoot setup; use this section only if you need help with setup.** You need **Git, GCC, Bash, Docker, a GitHub account, kubectl, and one local Kubernetes cluster**. Python 3 is only needed to run the web server directly without Docker. Verify your setup before class; GCC compilation and Docker image building are used in Level 1.
| Tool | Why we need it | Where |
| ----------------------------------------------------- | --------------------------------------------------------- | -------------------------- |
| Git | Clone, commit and push source files | Level 0 |
| Docker Desktop / Docker Engine | Build and run our image | Level 1+ |
| kubectl | Send commands to Kubernetes | Level 2+ |
| Minikube **or** Docker Desktop Kubernetes **or** kind | Local Kubernetes cluster | Level 2+ |
| GitHub account | Store project and view CI workflows | Level 0 and Actions recap |
| GCC and Bash | Compile C locally and run `test.sh` | Level 1 |
| Python 3 | Only for running web server natively (Docker includes it) | Web testing |

### A. Install Git

- **macOS:** run `git --version`. If not installed, install the Xcode Command Line Tools with `xcode-select --install`, or use `brew install git` if Homebrew is available.

- **Windows:** install **Git for Windows** from <https://git-scm.com/download/win> and use Git Bash or PowerShell.

- **Linux:** on Ubuntu/Debian, `sudo apt update && sudo apt install -y git`. For other distributions use their package manager.

**Verify:** `git --version`

### B. Install and start Docker

- **macOS:** download Docker Desktop from <https://www.docker.com/products/docker-desktop/>, or use `brew install --cask docker` if Homebrew is available.

- **Windows:** download Docker Desktop from the same site. WSL 2 / virtualization may be required; follow the installation prompts, then restart if requested.

- **Linux:** follow the official Docker Engine instructions for your distribution: <https://docs.docker.com/engine/install/>.

**Important:** Launch Docker Desktop and wait until its engine is running before using the terminal. On Linux, ensure the Docker daemon is running.

```bash
docker --version
docker run --rm hello-world
```

Expected: Docker prints a version, and the second command prints a **Hello from Docker!** message.

### C. Install kubectl

- **macOS:** `brew install kubectl`, or follow <https://kubernetes.io/docs/tasks/tools/>.

- **Windows:** `winget install Kubernetes.kubectl` (or the official instructions).

- **Linux:** follow <https://kubernetes.io/docs/tasks/tools/>.

**Verify:** `kubectl version --client`

### D. Install Minikube (recommended classroom option)

- **macOS:** `brew install minikube`

- **Windows:** `winget install Kubernetes.minikube`

- **Linux:** follow <https://minikube.sigs.k8s.io/docs/start/>

Restart your terminal if newly installed commands are not found. With Docker running:

```bash
minikube start --driver=docker
kubectl get nodes
```

Expected: a node is shown with status **Ready**. The first start can be slow because it downloads Kubernetes components. Before class, you can check `minikube status`.

### E. Alternative local Kubernetes clusters (choose ONE, not all)

If Minikube does not work, choose another option instead of installing all of them:
| Cluster | Start / select it | Local image availability |
| ----------------------------- | ----------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| **Minikube (recommended)** | `minikube start --driver=docker` | `minikube image load temperature-monitor:1.0` |
| **Docker Desktop Kubernetes** | Enable Kubernetes in Docker Desktop settings; `kubectl config use-context docker-desktop` | Depends on image store/runtime configuration; if image is missing, use the cluster's supported image-loading method or Minikube |
| **kind** | Install from <https://kind.sigs.k8s.io/docs/user/quick-start/> then `kind create cluster` | `kind load docker-image temperature-monitor:1.0` |
Always verify `kubectl get nodes` and `kubectl config current-context` before applying manifests. The current context must point at the cluster you intend to use.

**Why load the image?** The image built on your computer is not automatically available inside every Kubernetes node. Loading it prevents `ErrImagePull` or `ImagePullBackOff` when the manifest references `temperature-monitor:1.0`.

### F. GCC and Bash; Python 3 (only for native web server)

- **macOS:** `xcode-select --install` provides Apple Clang through the `gcc` command; Homebrew GCC is another option (`brew install gcc`, then use its versioned command). The `bash` command is included with macOS. For native web testing, install Python 3 if missing (`brew install python`).

- **Windows:** use WSL (Ubuntu is suitable): `sudo apt update && sudo apt install -y build-essential bash`. Run the GCC/Bash commands inside WSL. Python 3 is needed only for a native web server.

- **Ubuntu/Debian:** `sudo apt update && sudo apt install -y build-essential bash`. Install `python3` as well only if testing the web server natively.

**Quick setup checklist:** `git --version`, `gcc --version`, `bash --version`, `docker --version`, `docker ps`, `kubectl version --client`, and `kubectl get nodes` should succeed. If a step fails, use the troubleshooting section at the end; ask for help if a command still fails.

---

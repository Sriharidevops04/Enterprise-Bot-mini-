# Findings — Part 4 debug lab

Fill in one entry per defect you find. Paste the *actual* output you saw —
we cross-check it against your session recording and your git diff, and the
diagnostic path matters more to us than the fix itself.

Before you start investigating, begin recording:
`script -q part4-session.log` (or `asciinema rec part4-session.cast`), and
commit that file alongside this one.

---

## Defect 1

**Symptom** (what you observed — paste the real command output):

Error: 1 error occurred:
    * Job.batch "migrate" is invalid: spec.template.spec.restartPolicy: Required value: valid values: "OnFailure", "Never"

**Cause** (the actual root cause, not the symptom restated):

restartpolicy should be Never for all other manifests otherwise it will go into crashloopbackoff 
only pods which are managed by deployment should have restartpolicy as Always

**Fix** (what you changed, and why this over alternatives):
nano broken-chart/templates/migrate-job.yaml here i changed the restartpolicy
and deleted the migrate pod so that it will start freshly

**How I found it** (the sequence of commands/reasoning that led you here):

while running the ./scenario.sh up i have found the issue

---

## Defect 2

**Symptom:**

Readiness probe failed: Get "http://10.244.0.22:8080/healthz":
dial tcp 10.244.0.22:8080: connect: connection refused

**Cause:**

The application listens on port 8081, while the chart configures the container/readiness port as 8080.
**Fix:**
Changed common.port from 8080 to 8081.
**How I found it:**
kubectl describe pod ... showed the readiness probe failing on 8080, and kubectl logs ... showed the application listening on 8081.

---

## Defect 3

**Symptom:**

The worker deployment was not ready and the worker pod repeatedly entered `CrashLoopBackOff`.

Observed pod state:

worker-5c857fddc-l5qf8   0/1   CrashLoopBackOff
worker-7685bd656f-pm7kq  0/1   CrashLoopBackOff

FATAL: worker could not initialise its cache: mkdir /var/cache/app:
read-only file system -- the process needs a writable directory at
/var/cache/app (mount a volume there, or set CACHE_DIR)

**Cause:**

The worker container uses readOnlyRootFilesystem: true, but the application needs to create and write to /var/cache/app. Because that directory was part of the read-only root filesystem and no writable volume was mounted there, the worker process exited.

**Fix:**

Added an emptyDir volume and mounted it at /var/cache/app.

The existing readOnlyRootFilesystem: true security setting was retained, while the specific cache directory was given a writable filesystem.

**How I found it:**
Ran kubectl get pods -n debug-lab and observed the worker repeatedly entering CrashLoopBackOff.
Ran kubectl -n debug-lab logs <worker-pod> --previous to inspect the previous crashed container.
The application reported that it could not create /var/cache/app because of the read-only filesystem.
Inspected the worker Deployment template and found readOnlyRootFilesystem: true with no writable volume mounted at /var/cache/app.
Added an emptyDir volume mounted at /var/cache/app.
Re-applied the chart and verified that the worker became 1/1 Ready and that no pods remained in CrashLoopBackOff.

---

## Defect 4

**Symptom:**

The reporter pod was Running but not Ready, and the reporter application returned HTTP 403 when attempting to list pods.

Observed verification output:

FAIL  deployment reporter: 0/1 ready
FAIL  ServiceAccount debug-lab/reporter cannot list pods
FAIL  reporter /report does not return a pod count

pod list failed: ... HTTP 403 ... user "system:serviceaccount:debug-lab:reporter"
cannot list resource "pods" in the namespace "debug-lab"

**Cause:**

The reporter-read Role already allowed get and list on pods, but its RoleBinding was bound to the default ServiceAccount instead of the reporter ServiceAccount used by the reporter Deployment. The reporter Deployment explicitly uses the reporter ServiceAccount


**Fix:**

name: default to name: reporter
**How I found it:**

./scenario.sh verify showed the reporter deployment was not ready and the reporter pod-count check was failing.
Reporter logs showed HTTP 403 while trying to list pods.
kubectl auth can-i list pods -n debug-lab --as="system:serviceaccount:debug-lab:reporter" returned no.
The same check using the default ServiceAccount returned yes.
Inspected the Role and confirmed it already allowed get and list on pods.
Inspected the RoleBinding and found it referenced default instead of reporter.
Changed the RoleBinding subject to reporter.
Re-applied the Helm release and confirmed the reporter ServiceAccount could list pods.
---

## Defect 5

**Symptom:**

The metrics deployment was not becoming ready.

Observed verification output:


FAIL  deployment metrics: 0/1 ready

**Cause:**

The metrics workload requested 2 CPUs and had a 4 CPU limit, while the cluster's LimitRange imposes a maximum of 1 CPU per container. The chart therefore requested resources outside the cluster's allowed limits.

**Fix:**

requests:
  cpu: "50m"
  memory: "64Mi"
limits:
  cpu: "200m"
  memory: "128Mi"
**How I found it:**

./scenario.sh verify showed deployment metrics: 0/1 ready.
Inspected the metrics workload and its resource configuration.
Found that the chart requested 2 CPUs and allowed a limit of 4 CPUs.
Inspected the immutable cluster-state LimitRange and found a hard maximum of 1 CPU per container.
Adjusted the metrics resources to remain below that maximum.
Re-applied the Helm release.
Confirmed the metrics pod became 1/1 Running
---

## Defect 6

**Symptom:**
The gateway deployment was not ready and the gateway did not report the backend as healthy.

Observed verification output:

FAIL  deployment gateway: 0/1 ready
FAIL  gateway /status does not report backend=ok
**Cause:**

http://backend.default.svc:8080

**Fix:**

Changed the backend URL to reference the backend Service in the correct namespace:
BACKEND_URL: "http://backend.debug-lab.svc:8081"

**How I found it:**
./scenario.sh verify showed the gateway deployment was not ready and /status did not report backend=ok.
Inspected the gateway Deployment environment and found the configured BACKEND_URL.
Compared the URL with the namespace in which the backend Service was running.
Found that the URL referenced backend.default.svc instead of the debug-lab namespace.
Corrected the backend Service DNS name.
Re-applied the Helm release.
Confirmed the new gateway pod became 1/1 Running

---

If you ran out of time on any defect, say so here and describe what you would
have tried next — that section is read carefully and counts in your favour.

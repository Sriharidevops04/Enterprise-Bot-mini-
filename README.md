# Enterprise-Bot-mini-

This repository contains my solution for the Enterprise Bot GmbH DevOps / Platform Engineer take-home assignment.

The solution covers:

- A containerized Python HTTP service
- A Helm chart for Kubernetes deployment
- An idempotent local setup script using kind
- A Kubernetes debugging lab
- Written responses for the Gateway API migration question

---

## Repository Structure

```text
.
├── setup.sh
├── README.md
├── ANSWERS.md
├── service/
│   ├── app.py
│   ├── Dockerfile
│   ├── requirements.txt
│   └── .dockerignore
├── chart/
└── lab/
    ├── scenario.sh
    ├── cluster-state/
    ├── broken-chart/
    ├── FINDINGS.md
    └── part4-session.log

Resource Requests and Limits

For the application workloads, I selected small CPU and memory requests and limits (50m and 200m)because this assignment runs on a local kind cluster and the service is lightweight.

Requests represent the baseline resources Kubernetes should reserve for the workload.

Limits prevent an individual container from consuming an uncontrolled amount of CPU or memory.

The selected values should be considered starting points for this assignment rather than production sizing. In a production environment I would use observed CPU and memory utilisation, workload characteristics, traffic levels, and historical metrics to tune them.


The final remaining reporter issue in Part 4 was not fully resolved within the available debugging time.

After correcting the reporter RBAC configuration, the reporter ServiceAccount was able to list pods through Kubernetes RBAC checks. However, the reporter application continued to report:

pod list failed: parse pod list: unexpected end of JSON input

I did not claim a fix without sufficient evidence.

Risk

The remaining issue means the Part 4 debug lab is not completely healthy and the reporter workload would require additional investigation before being considered production-ready.

The next investigation would trace the reporter's in-cluster API request, authentication/token configuration, endpoint handling, and the exact response being parsed by the application.


How I Used AI

I used ChatGPT as an assistant during the assignment for Kubernetes troubleshooting, debugging guidance, and documentation support.

For Part 4, I used the suggested diagnostic commands against my own Kubernetes cluster and used the actual command output as evidence.

I validated the suggested fixes myself and re-ran the Kubernetes verification commands after changes.

One important correction during the debugging process was distinguishing the reporter's RBAC failure from the separate JSON parsing issue that remained after RBAC was fixed. I left the remaining issue documented rather than claiming it was solved without evidence.

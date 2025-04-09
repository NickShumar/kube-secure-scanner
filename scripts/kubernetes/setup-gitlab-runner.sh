#!/bin/bash

# Install GitLab Runner in Minikube
kubectl create namespace gitlab-runner

# Create service account for GitLab runner
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: gitlab-runner
  namespace: gitlab-runner
EOF

# Create RBAC permissions
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: gitlab-runner-role
  namespace: inspec-test
rules:
- apiGroups: [""]
  resources: ["pods", "pods/exec", "pods/log"]
  verbs: ["get", "list", "create", "delete"]
EOF

# Create role binding
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: gitlab-runner-binding
  namespace: inspec-test
subjects:
- kind: ServiceAccount
  name: gitlab-runner
  namespace: gitlab-runner
roleRef:
  kind: Role
  name: gitlab-runner-role
  apiGroup: rbac.authorization.k8s.io
EOF

# Deploy GitLab runner using Helm
helm repo add gitlab https://charts.gitlab.io
helm repo update

helm install gitlab-runner gitlab/gitlab-runner \
  --namespace gitlab-runner \
  --set rbac.create=true \
  --set runners.privileged=true \
  --set gitlabUrl=http://your.gitlab.instance.url \
  --set runnerRegistrationToken=your-registration-token

image: docker:latest

services:
  - docker:dind

variables:
  KUBERNETES_MEMORY_REQUEST: 256Mi
  KUBERNETES_MEMORY_LIMIT: 512Mi
  KUBERNETES_CPU_REQUEST: 250m
  KUBERNETES_CPU_LIMIT: 500m

stages:
  - test
  - scan

container-test:
  stage: test
  script:
    - export KUBECONFIG=/path/to/kubeconfig.yaml
    - kubectl get pods -n inspec-test
    - kubectl describe pod inspec-target -n inspec-test

container-scan:
  stage: scan
  script:
    - export KUBECONFIG=/path/to/kubeconfig.yaml
    - ./scripts/scan-container.sh inspec-test inspec-target busybox ./examples/cinc-profiles/container-baseline


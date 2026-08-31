# aws-jenkins-docker-cicd

A CI/CD pipeline example that builds, tests, and deploys a Dockerized application using Jenkins running on AWS. This repository contains the pipeline definition (Jenkinsfile), Dockerfile, and supporting scripts to demonstrate a full build → image push → deploy workflow using AWS services (ECR/ECS or EC2).

---

## Table of contents
- Overview
- Architecture
- Prerequisites
- Repository layout
- Quick start (local build)
- Jenkins setup (high level)
- Typical Jenkins pipeline (Jenkinsfile)
- AWS ECR / ECS deployment steps (example)
- Environment variables & credentials
- Troubleshooting
- Security notes
- Contact

---

## Overview
This project demonstrates a CI/CD pipeline that:
- Builds a Docker image for the application.
- Runs tests inside the build stage.
- Pushes the image to AWS ECR (or any Docker registry).
- Deploys the image to AWS (ECS service or EC2 hosts running Docker).
- Uses Jenkins to orchestrate the flow with declarative pipeline stages.

Adjust the CI/CD steps to match your production infrastructure (ECS, EKS, EC2, or other).

---

## Architecture (high level)
- Jenkins controller (hosted on an AWS EC2 instance or managed Jenkins) with Docker installed.
- Jenkins agents that can run Docker builds (either docker-in-docker or with local Docker).
- AWS ECR for storing built images.
- AWS ECS (Fargate or EC2) or fleet of EC2 instances running Docker to deploy images.
- Optional: Route53 / Load Balancer to expose the service.

Example flow:
1. Developer pushes code to GitHub.
2. Jenkins picks up change (webhook) and checks out code.
3. Jenkins builds Docker image and runs tests.
4. Jenkins tags and pushes image to ECR.
5. Jenkins triggers deployment to ECS/EC2 (update service or ssh+docker pull).

---

## Prerequisites
- AWS account with permissions to create/use ECR, ECS, IAM roles, and optionally EC2/ELB.
- Jenkins server with:
  - Docker or ability to run Docker builds.
  - AWS CLI (or AWS plugin) and Docker credentials configured.
  - Recommended plugins: Pipeline, Amazon ECR, Credentials Binding, SSH Agent (if deploying via SSH), Blue Ocean (optional).
- Docker (for local testing).
- Git access to this repository.
- IAM user or role with ECR/ECS permissions and access keys (or use instance role).

---

## Repository layout
- Jenkinsfile                 — Declarative pipeline used by Jenkins
- Dockerfile                  — Builds the application image
- scripts/                    — Helper scripts (login, deploy, etc.)
- app/                        — Example application (if included)
- README.md                   — This document

(Adjust to the actual repo structure in this project.)

---

## Quick start — build & run locally
Clone the repo:
```bash
git clone https://github.com/SouravPaul82/aws-jenkins-docker-cicd.git
cd aws-jenkins-docker-cicd
```

Build the Docker image locally:
```bash
docker build -t my-app:local .
```

Run the container:
```bash
docker run -p 8000:8000 my-app:local
# then open http://localhost:8000 (adjust port per app)
```

---

## Jenkins setup (high level)
1. Install Jenkins on an EC2 instance (or use a hosted Jenkins).
2. Install Docker on the Jenkins host or ensure agents can run Docker.
3. In Jenkins > Manage Credentials, add:
   - AWS credentials (access key ID & secret) — id: aws-creds
   - Docker registry credentials (if separate) — id: docker-registry
   - SSH key for deployment (if deploying to EC2 via SSH) — id: deploy-ssh
4. Create a multibranch pipeline or a pipeline job pointing at this repository and the Jenkinsfile.

Recommended Jenkins plugins: Pipeline, Credentials, Amazon ECR, Docker Pipeline, SSH Agent.

---

## Typical Jenkins pipeline (summary)
A typical declarative Jenkinsfile will include stages:

- Checkout
- Build
  - docker build
  - run unit tests inside container or as part of build
- Push
  - Authenticate to ECR (aws ecr get-login-password | docker login)
  - Tag and push image to ECR
- Deploy
  - Update an ECS service with new image (aws ecs update-service) OR
  - SSH into EC2 and pull & restart container (docker pull & docker-compose up -d)
- Notify (Slack, email)

Example-stage snippet (conceptual):
```groovy
pipeline {
  agent any
  environment {
    ECR_REGISTRY = "123456789012.dkr.ecr.us-east-1.amazonaws.com"
    IMAGE_NAME = "${ECR_REGISTRY}/my-app"
    AWS_CREDENTIALS = credentials('aws-creds')
  }
  stages {
    stage('Build') {
      steps {
        sh 'docker build -t ${IMAGE_NAME}:${GIT_COMMIT} .'
      }
    }
    stage('Push') {
      steps {
        sh '''
          aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ${ECR_REGISTRY}
          docker push ${IMAGE_NAME}:${GIT_COMMIT}
        '''
      }
    }
    stage('Deploy') {
      steps {
        // either update ECS or SSH to host and restart container
      }
    }
  }
}
```
Adjust the steps to your environment and credentials plugin usage.

---

## Example: push to ECR & deploy to ECS (commands)
Authenticate to ECR:
```bash
aws ecr get-login-password --region <region> | docker login --username AWS --password-stdin <account>.dkr.ecr.<region>.amazonaws.com
```

Tag & push:
```bash
docker tag my-app:latest <account>.dkr.ecr.<region>.amazonaws.com/my-app:latest
docker push <account>.dkr.ecr.<region>.amazonaws.com/my-app:latest
```

Update ECS service (example):
```bash
aws ecs update-service --cluster my-cluster --service my-service --force-new-deployment --region <region>
```

Alternative: for EC2 hosts with docker-compose, you can SSH and run:
```bash
ssh -i /path/to/key ec2-user@ec2-host 'docker pull <registry>/my-app:latest && docker-compose up -d'
```

---

## Environment variables & Jenkins credentials (example)
- Jenkins credentials IDs (examples):
  - aws-creds — AWS access key + secret
  - docker-registry — DockerHub or ECR login if used
  - deploy-ssh — private key for deployment host SSH

- Pipeline environment variables:
  - AWS_REGION (e.g., us-east-1)
  - ECR_REGISTRY (account.dkr.ecr.region.amazonaws.com)
  - IMAGE_NAME (ECR_REGISTRY/repo)

Store secrets in Jenkins credentials store and reference them in the Jenkinsfile.

---

## Troubleshooting
- Build fails locally: run docker build locally and inspect error logs.
- Jenkins can't authenticate to ECR: verify IAM credentials and region; ensure the ECR repository exists.
- Deployment failure: check ECS deployment events or SSH logs on EC2.
- Permissions errors: confirm IAM policies attached to user/role include ecr:*, ecs:*, iam:PassRole (if needed).

Add verbose logging in pipeline steps (echo, set -x) when debugging.

---

## Security notes
- Do not commit AWS secrets or private keys to the repo.
- Use Jenkins credentials store or AWS IAM roles for EC2 instance profiles.
- Limit IAM permissions to least privilege required (ECR push/pull, ECS update).
- Use secure channels for SSH and rotate credentials regularly.

---

## Next steps / Customization
- Replace generic deploy stage with your chosen target (ECS task definition update, EKS rollout, or rolling update on EC2 instances).
- Add test stages (unit, integration, linting).
- Add image scanning step (Trivy/Clair) before pushing images.

---

## Contact
If you want, I can:
- Update this README in the repository (develop branch),
- Add a concrete Jenkinsfile example tuned to your exact deployment (ECS or EC2),
- Or create example AWS IAM policies and scripted deploy helpers.

Please tell me how you'd like me to proceed.

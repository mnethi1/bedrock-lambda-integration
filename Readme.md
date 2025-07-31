
# AWS Lambda + Bedrock Claude Haiku Integration

This project provides a complete solution for integrating AWS Lambda with AWS Bedrock's Claude Haiku model using Python, Terraform for infrastructure, and GitHub Actions for CI/CD.

## Prerequisites

- AWS Account with Bedrock access
- GitHub account
- Terraform installed locally
- Python 3.11+
- AWS CLI configured

## Setup Instructions

### 1. Clone and Setup


AWS CLI:

aws lambda invoke --function-name bedrock-claude-integration-bedrock-lambda --payload file://lambda/test_payload.json --cli-binary-format raw-in-base64-out response.json


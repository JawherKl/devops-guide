# GitLab CI/CD Pipeline Example

This example demonstrates a basic GitLab CI/CD pipeline for a Node.js application.

## .gitlab-ci.yml

Create a `.gitlab-ci.yml` file with the following content:

```yaml
stages:
  - build
  - test
  - deploy

build:
  stage: build
  script:
    - npm install

test:
  stage: test
  script:
    - npm test

deploy:
  stage: deploy
  script:
    - npm run deploy
```

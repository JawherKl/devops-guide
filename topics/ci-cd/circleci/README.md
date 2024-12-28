# CircleCI CI/CD Pipeline Example

This example demonstrates a basic CircleCI pipeline for a Node.js application.

## .circleci/config.yml

Create a `.circleci/config.yml` file with the following content:

```yaml
version: 2.1

jobs:
  build:
    docker:
      - image: circleci/node:14
    steps:
      - checkout
      - run:
          name: Install dependencies
          command: npm install
      - run:
          name: Run tests
          command: npm test
      - run:
          name: Deploy application
          command: npm run deploy

workflows:
  version: 2
  build_and_deploy:
    jobs:
      - build
```
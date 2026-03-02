# OWASP ZAP Example

## Introduction
OWASP ZAP (Zed Attack Proxy) is an open-source security tool used for finding vulnerabilities in web applications. It is designed to be used by both security professionals and developers.

## Setting up OWASP ZAP
1. **Install OWASP ZAP**:
   ```sh
   sudo apt install zaproxy
   ```

2. **Start OWASP ZAP**:
   ```sh
   zap.sh
   ```

## Running a Security Scan
1. **Start ZAP in daemon mode**:
   ```sh
   zap.sh -daemon -config api.key=<your_api_key>
   ```

2. **Run a quick scan**:
   ```sh
   zap-cli quick-scan --self-contained http://example.com
   ```

## Example Configuration
Create a `zap-config.yaml` file with the following content:

```yaml
zap:
  target: "http://example.com"
  context: "Default Context"
  apiKey: "<your_api_key>"
  session: "zap_session.session"
  scanPolicyName: "Default Policy"
  spider:
    maxDepth: 5
    threadCount: 10
  ajaxSpider:
    maxCrawlDepth: 3
    maxCrawlStates: 20
  activeScan:
    policy: "Default Policy"
    threadCount: 5
```

## Automating with CI/CD
Integrate OWASP ZAP into your CI/CD pipeline to automatically scan your web applications for vulnerabilities.

### Example GitHub Actions Workflow
Create a `.github/workflows/owasp-zap.yml` file with the following content:

```yaml
name: OWASP ZAP Security Scan

on: [push, pull_request]

jobs:
  zap:
    runs-on: ubuntu-latest
    steps:
    - name: Checkout code
      uses: actions/checkout@v2

    - name: Set up Java
      uses: actions/setup-java@v2
      with:
        java-version: '11'

    - name: Install OWASP ZAP
      run: sudo apt install zaproxy

    - name: Start OWASP ZAP in daemon mode
      run: zap.sh -daemon -config api.key=${{ secrets.ZAP_API_KEY }}

    - name: Run OWASP ZAP scan
      run: |
        zap-cli quick-scan --self-contained http://example.com
        zap-cli report -o zap_report.html -f html

    - name: Upload ZAP report
      uses: actions/upload-artifact@v2
      with:
        name: zap-report
        path: zap_report.html
```

## Conclusion
By integrating OWASP ZAP into your development workflow, you can continuously monitor and fix vulnerabilities, ensuring your web applications remain secure.

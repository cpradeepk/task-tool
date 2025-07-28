#!/usr/bin/env node

/**
 * SwargFood Task Management - Test Report Generator
 * Generates comprehensive test reports with screenshots and metrics
 */

const fs = require('fs');
const path = require('path');

class TestReportGenerator {
  constructor() {
    this.resultsDir = 'test-results';
    this.reportDir = 'test-reports';
    this.screenshotsDir = path.join(this.resultsDir, 'screenshots');
  }

  async generateReport() {
    console.log('🔄 Generating comprehensive test report...');

    // Create report directory
    if (!fs.existsSync(this.reportDir)) {
      fs.mkdirSync(this.reportDir, { recursive: true });
    }

    // Read test results
    const results = await this.readTestResults();
    
    // Generate HTML report
    const htmlReport = this.generateHTMLReport(results);
    
    // Write report
    const reportPath = path.join(this.reportDir, 'comprehensive-report.html');
    fs.writeFileSync(reportPath, htmlReport);
    
    // Generate JSON summary
    const jsonSummary = this.generateJSONSummary(results);
    const summaryPath = path.join(this.reportDir, 'test-summary.json');
    fs.writeFileSync(summaryPath, JSON.stringify(jsonSummary, null, 2));
    
    console.log('✅ Report generated successfully!');
    console.log(`📄 HTML Report: ${reportPath}`);
    console.log(`📊 JSON Summary: ${summaryPath}`);
    
    return { htmlReport: reportPath, jsonSummary: summaryPath };
  }

  async readTestResults() {
    const results = {
      summary: { total: 0, passed: 0, failed: 0, skipped: 0 },
      tests: [],
      screenshots: [],
      duration: 0,
      timestamp: new Date().toISOString()
    };

    try {
      // Read Playwright JSON results if available
      const jsonResultsPath = path.join(this.resultsDir, 'results.json');
      if (fs.existsSync(jsonResultsPath)) {
        const jsonResults = JSON.parse(fs.readFileSync(jsonResultsPath, 'utf8'));
        results.summary = this.extractSummary(jsonResults);
        results.tests = this.extractTests(jsonResults);
        results.duration = jsonResults.stats?.duration || 0;
      }

      // Read screenshots
      if (fs.existsSync(this.screenshotsDir)) {
        results.screenshots = fs.readdirSync(this.screenshotsDir)
          .filter(file => file.endsWith('.png'))
          .map(file => ({
            name: file,
            path: path.join(this.screenshotsDir, file),
            timestamp: fs.statSync(path.join(this.screenshotsDir, file)).mtime
          }));
      }

    } catch (error) {
      console.warn('⚠️ Could not read test results:', error.message);
    }

    return results;
  }

  extractSummary(jsonResults) {
    const summary = { total: 0, passed: 0, failed: 0, skipped: 0 };
    
    if (jsonResults.stats) {
      summary.total = jsonResults.stats.total || 0;
      summary.passed = jsonResults.stats.passed || 0;
      summary.failed = jsonResults.stats.failed || 0;
      summary.skipped = jsonResults.stats.skipped || 0;
    }

    return summary;
  }

  extractTests(jsonResults) {
    const tests = [];

    if (jsonResults.suites) {
      jsonResults.suites.forEach(suite => {
        if (suite.specs) {
          suite.specs.forEach(spec => {
            tests.push({
              title: spec.title,
              file: spec.file,
              status: spec.ok ? 'passed' : 'failed',
              duration: spec.duration || 0,
              error: spec.error || null
            });
          });
        }
      });
    }

    return tests;
  }

  generateHTMLReport(results) {
    const passRate = results.summary.total > 0 
      ? ((results.summary.passed / results.summary.total) * 100).toFixed(1)
      : 0;

    return `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>SwargFood Task Management - Test Report</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            margin: 0;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            overflow: hidden;
        }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            text-align: center;
        }
        .header h1 {
            margin: 0;
            font-size: 2.5em;
        }
        .header p {
            margin: 10px 0 0 0;
            opacity: 0.9;
        }
        .summary {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            padding: 30px;
            background: #f8f9fa;
        }
        .metric {
            text-align: center;
            padding: 20px;
            background: white;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .metric-value {
            font-size: 2.5em;
            font-weight: bold;
            margin-bottom: 5px;
        }
        .metric-label {
            color: #666;
            font-size: 0.9em;
        }
        .passed { color: #28a745; }
        .failed { color: #dc3545; }
        .skipped { color: #ffc107; }
        .total { color: #007bff; }
        .content {
            padding: 30px;
        }
        .section {
            margin-bottom: 40px;
        }
        .section h2 {
            color: #333;
            border-bottom: 2px solid #eee;
            padding-bottom: 10px;
        }
        .test-list {
            list-style: none;
            padding: 0;
        }
        .test-item {
            display: flex;
            align-items: center;
            padding: 15px;
            margin-bottom: 10px;
            background: #f8f9fa;
            border-radius: 6px;
            border-left: 4px solid #ddd;
        }
        .test-item.passed {
            border-left-color: #28a745;
        }
        .test-item.failed {
            border-left-color: #dc3545;
        }
        .test-status {
            width: 20px;
            height: 20px;
            border-radius: 50%;
            margin-right: 15px;
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
            font-weight: bold;
            font-size: 12px;
        }
        .test-status.passed {
            background: #28a745;
        }
        .test-status.failed {
            background: #dc3545;
        }
        .test-details {
            flex: 1;
        }
        .test-title {
            font-weight: 600;
            margin-bottom: 5px;
        }
        .test-file {
            font-size: 0.85em;
            color: #666;
        }
        .test-duration {
            color: #666;
            font-size: 0.85em;
        }
        .screenshots {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
            gap: 20px;
        }
        .screenshot {
            border: 1px solid #ddd;
            border-radius: 6px;
            overflow: hidden;
        }
        .screenshot img {
            width: 100%;
            height: 200px;
            object-fit: cover;
        }
        .screenshot-info {
            padding: 10px;
            background: #f8f9fa;
        }
        .footer {
            text-align: center;
            padding: 20px;
            color: #666;
            border-top: 1px solid #eee;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 SwargFood Task Management</h1>
            <p>Automated Test Report - ${new Date(results.timestamp).toLocaleString()}</p>
        </div>

        <div class="summary">
            <div class="metric">
                <div class="metric-value total">${results.summary.total}</div>
                <div class="metric-label">Total Tests</div>
            </div>
            <div class="metric">
                <div class="metric-value passed">${results.summary.passed}</div>
                <div class="metric-label">Passed</div>
            </div>
            <div class="metric">
                <div class="metric-value failed">${results.summary.failed}</div>
                <div class="metric-label">Failed</div>
            </div>
            <div class="metric">
                <div class="metric-value">${passRate}%</div>
                <div class="metric-label">Pass Rate</div>
            </div>
        </div>

        <div class="content">
            <div class="section">
                <h2>📋 Test Results</h2>
                <ul class="test-list">
                    ${results.tests.map(test => `
                        <li class="test-item ${test.status}">
                            <div class="test-status ${test.status}">
                                ${test.status === 'passed' ? '✓' : '✗'}
                            </div>
                            <div class="test-details">
                                <div class="test-title">${test.title}</div>
                                <div class="test-file">${test.file}</div>
                            </div>
                            <div class="test-duration">${test.duration}ms</div>
                        </li>
                    `).join('')}
                </ul>
            </div>

            ${results.screenshots.length > 0 ? `
            <div class="section">
                <h2>📸 Screenshots</h2>
                <div class="screenshots">
                    ${results.screenshots.map(screenshot => `
                        <div class="screenshot">
                            <img src="${screenshot.path}" alt="${screenshot.name}" />
                            <div class="screenshot-info">
                                <strong>${screenshot.name}</strong><br>
                                <small>${new Date(screenshot.timestamp).toLocaleString()}</small>
                            </div>
                        </div>
                    `).join('')}
                </div>
            </div>
            ` : ''}
        </div>

        <div class="footer">
            <p>Generated by SwargFood Test Suite • ${new Date().toLocaleString()}</p>
        </div>
    </div>
</body>
</html>`;
  }

  generateJSONSummary(results) {
    return {
      timestamp: results.timestamp,
      summary: results.summary,
      passRate: results.summary.total > 0 
        ? ((results.summary.passed / results.summary.total) * 100).toFixed(1)
        : 0,
      duration: results.duration,
      testCount: results.tests.length,
      screenshotCount: results.screenshots.length,
      status: results.summary.failed > 0 ? 'FAILED' : 'PASSED'
    };
  }
}

// Run if called directly
if (require.main === module) {
  const generator = new TestReportGenerator();
  generator.generateReport().catch(console.error);
}

module.exports = TestReportGenerator;

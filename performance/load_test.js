import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('errors');
const responseTime = new Trend('response_time');

// Test configuration
export const options = {
  stages: [
    { duration: '1m', target: 10 },   // Ramp up to 10 users
    { duration: '3m', target: 10 },   // Stay at 10 users
    { duration: '1m', target: 20 },   // Ramp up to 20 users
    { duration: '3m', target: 20 },   // Stay at 20 users
    { duration: '1m', target: 0 },    // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<2000'], // 95% of requests must complete within 2s
    errors: ['rate<0.1'],               // Error rate must be below 10%
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:3000';

export default function () {
  // Test 1: Homepage load
  let res = http.get(`${BASE_URL}/`);
  check(res, {
    'homepage status is 200': (r) => r.status === 200,
    'homepage response time < 2s': (r) => r.timings.duration < 2000,
  });
  errorRate.add(res.status !== 200);
  responseTime.add(res.timings.duration);
  sleep(1);

  // Test 2: Login page
  res = http.get(`${BASE_URL}/session/new`);
  check(res, {
    'login page status is 200': (r) => r.status === 200,
  });
  errorRate.add(res.status !== 200);
  sleep(1);

  // Test 3: Registration page
  res = http.get(`${BASE_URL}/users/new`);
  check(res, {
    'registration page status is 200': (r) => r.status === 200,
  });
  errorRate.add(res.status !== 200);
  sleep(1);

  // Test 4: Health check endpoint
  res = http.get(`${BASE_URL}/up`);
  check(res, {
    'health check status is 200': (r) => r.status === 200,
    'health check response time < 500ms': (r) => r.timings.duration < 500,
  });
  errorRate.add(res.status !== 200);
  responseTime.add(res.timings.duration);
  sleep(1);

  // Test 5: Static assets (CSS)
  res = http.get(`${BASE_URL}/assets/application.css`);
  check(res, {
    'CSS asset status is 200 or 404': (r) => r.status === 200 || r.status === 404,
  });
  sleep(1);

  // Test 6: API without auth (should return 401)
  res = http.get(`${BASE_URL}/api/v1/accounts`);
  check(res, {
    'API without auth returns 401': (r) => r.status === 401,
  });
  errorRate.add(res.status !== 401);
  sleep(1);
}
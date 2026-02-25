import http from 'k6/http';
import { check, sleep, group } from 'k6';

// Smoke test - minimal load to verify system works
export const options = {
  vus: 1,              // 1 virtual user
  duration: '1m',      // Run for 1 minute
  thresholds: {
    http_req_duration: ['p(95)<3000'], // 95% under 3s
    http_req_failed: ['rate<0.1'],      // Less than 10% errors
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:3000';

export default function () {
  group('Smoke Test - Critical Paths', () => {
    // Test homepage
    let res = http.get(`${BASE_URL}/`);
    check(res, {
      'homepage loads': (r) => r.status === 200,
      'homepage < 3s': (r) => r.timings.duration < 3000,
    });
    sleep(2);

    // Test login page
    res = http.get(`${BASE_URL}/session/new`);
    check(res, {
      'login page loads': (r) => r.status === 200,
    });
    sleep(2);

    // Test health endpoint
    res = http.get(`${BASE_URL}/up`);
    check(res, {
      'health check passes': (r) => r.status === 200,
      'health check < 1s': (r) => r.timings.duration < 1000,
    });
  });
}
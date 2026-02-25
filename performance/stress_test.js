import http from 'k6/http';
import { check, sleep, group } from 'k6';

// Stress test - push system to its limits
export const options = {
  stages: [
    { duration: '2m', target: 50 },   // Ramp up to 50 users
    { duration: '5m', target: 50 },   // Stay at 50 users
    { duration: '2m', target: 100 },  // Spike to 100 users
    { duration: '5m', target: 100 },  // Stay at 100 users
    { duration: '2m', target: 150 },  // Spike to 150 users
    { duration: '5m', target: 150 },  // Stay at 150 users
    { duration: '2m', target: 0 },    // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<5000'], // 95% under 5s even under stress
    http_req_failed: ['rate<0.2'],      // Less than 20% errors acceptable under stress
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:3000';

export default function () {
  group('Stress Test - High Load', () => {
    const endpoints = [
      '/',
      '/session/new',
      '/users/new',
      '/up',
    ];

    endpoints.forEach((endpoint) => {
      const res = http.get(`${BASE_URL}${endpoint}`);
      check(res, {
        [`${endpoint} responds`]: (r) => r.status < 500, // Accept any non-server error
      });
    });

    sleep(1);
  });
}
import http from 'k6/http';
import { check } from 'k6';

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';
const MODE = __ENV.MODE || 'sem-cache';
const VUS = parseInt(__ENV.VUS || '10', 10);
const DURATION = __ENV.DURATION || '15s';

export const options = {
  vus: VUS,
  duration: DURATION,
  summaryTrendStats: ['avg', 'min', 'med', 'max', 'p(90)', 'p(95)', 'p(99)'],
};

export function setup() {
  if (MODE === 'com-cache-quente') {
    http.del(`${BASE_URL}/api/cache`);
    const res = http.get(`${BASE_URL}/api/music/top50/com-cache`);
    check(res, { 'aquecimento status 200': (r) => r.status === 200 });
  } else if (MODE === 'com-cache-frio') {
    http.del(`${BASE_URL}/api/cache`);
  }
}

export default function () {
  const endpoint =
    MODE === 'sem-cache'
      ? `${BASE_URL}/api/music/top50/sem-cache`
      : `${BASE_URL}/api/music/top50/com-cache`;

  const res = http.get(endpoint, { timeout: '30s' });
  check(res, {
    'status 200': (r) => r.status === 200,
  });
}

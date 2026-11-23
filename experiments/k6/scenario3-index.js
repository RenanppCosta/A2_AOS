import http from 'k6/http';
import { check } from 'k6';

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';
const VUS = parseInt(__ENV.VUS || '10', 10);
const DURATION = __ENV.DURATION || '15s';

export const options = {
  vus: VUS,
  duration: DURATION,
  summaryTrendStats: ['avg', 'min', 'med', 'max', 'p(90)', 'p(95)', 'p(99)'],
};

export default function () {
  const albumId = ((__VU * 97 + __ITER) % 10000) + 1;
  const res = http.get(`${BASE_URL}/api/music/album/${albumId}`, {
    timeout: '30s',
  });
  check(res, {
    'status 200': (r) => r.status === 200,
  });
}

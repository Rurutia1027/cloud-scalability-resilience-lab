// Drive productservice hard enough for the HPA to add pods.
//
// Coupons SAVE10 and SAVE20 must already be in the database. product looks
// them up before it stores a row. On EKS the public address is the ALB DNS name:
//
//   bin/k6-load.sh http://<alb-dns-name>
//
// The previous path, a node public IP, is still open for the comparison:
//
//   bin/k6-load.sh http://<node-public-ip>:30090
//
// Locally, with both services on the Compose ports:
//
//   bin/k6-load.sh http://localhost:9090

import http from 'k6/http';
import { check, sleep } from 'k6';

const baseUrl = __ENV.BASE_URL;

export const options = {
  scenarios: {
    products: {
      executor: 'ramping-vus',
      startVUs: 1,
      stages: [
        { duration: '20s', target: 5 },
        { duration: '60s', target: 20 },
        { duration: '20s', target: 0 },
      ],
      gracefulRampDown: '10s',
    },
  },
  thresholds: {
    http_req_failed: ['rate<0.05'],
  },
};

const items = [
  { name: 'notebook', price: 100, couponCode: 'SAVE10' },
  { name: 'mouse', price: 50, couponCode: 'SAVE20' },
];

export function setup() {
  if (!baseUrl) {
    throw new Error('Set BASE_URL, for example http://<node-public-ip>:30090');
  }
}

export default function () {
  const item = items[Math.floor(Math.random() * items.length)];
  const response = http.post(
    `${baseUrl}/productapi/products`,
    JSON.stringify({
      name: item.name,
      description: 'k6 load',
      price: item.price,
      couponCode: item.couponCode,
    }),
    { headers: { 'Content-Type': 'application/json' } },
  );

  check(response, {
    'product stored': (r) => r.status === 200,
  });
  sleep(0.2);
}

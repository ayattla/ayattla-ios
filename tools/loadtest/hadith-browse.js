// Load test for ayattla.com's read APIs (k6). Run only with the owner's approval, off-peak.
//
//   k6 run -e STAGE=50 tools/loadtest/hadith-browse.js     (then 100, then 200)
//
// Pass: p95 under 800 ms and under 1% errors. Run it before and after the Cloudflare cache
// rules to compare. It only reads public pages; it never calls /api/hadith/check.
import http from "k6/http";
import { check, sleep } from "k6";

const users = Number(__ENV.STAGE || 50);
const base = __ENV.BASE || "https://ayattla.com";

export const options = {
  stages: [
    { duration: "1m", target: users },
    { duration: "3m", target: users },
    { duration: "1m", target: 0 },
  ],
  thresholds: {
    http_req_duration: ["p(95)<800"],
    http_req_failed: ["rate<0.01"],
  },
  userAgent: "AyatTutla-LoadTest/1.0",
};

export default function () {
  // The same requests the app makes: first hadith pages, then the radio list.
  const page = 1 + Math.floor(Math.random() * 5);
  const r1 = http.get(`${base}/api/hadith/browse?cat=&page=${page}&q=`);
  check(r1, { "browse 200": (r) => r.status === 200 });
  sleep(1 + Math.random() * 2);
  const r2 = http.get(`${base}/api/radios`);
  check(r2, { "radios 200": (r) => r.status === 200 });
  sleep(1 + Math.random() * 2);
}

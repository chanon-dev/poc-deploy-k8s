'use client';

import { useEffect, useState } from 'react';
import styles from './page.module.css';

interface ApiResponse {
  message: string;
  timestamp: string;
  environment: string;
}

export default function Home() {
  const [data, setData] = useState<ApiResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const apiUrl = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:5000';

  useEffect(() => {
    fetchData();
  }, []);

  const fetchData = async () => {
    try {
      setLoading(true);
      setError(null);

      const response = await fetch(`${apiUrl}/api/health`);

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }

      const result = await response.json();
      setData(result);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'An error occurred');
    } finally {
      setLoading(false);
    }
  };

  return (
    <main className={styles.main}>
      <div className={styles.container}>
        <h1 className={styles.title}>Sample Application</h1>
        <p className={styles.subtitle}>Next.js + C# Web API</p>

        <div className={styles.card}>
          <h2>Frontend Info</h2>
          <p><strong>Framework:</strong> Next.js 14</p>
          <p><strong>Language:</strong> TypeScript + React</p>
          <p><strong>API URL:</strong> {apiUrl}</p>
        </div>

        <div className={styles.card}>
          <h2>Backend API Status</h2>
          {loading && <p className={styles.loading}>Loading...</p>}
          {error && <p className={styles.error}>Error: {error}</p>}
          {data && (
            <>
              <p className={styles.success}>{data.message}</p>
              <p><strong>Environment:</strong> {data.environment}</p>
              <p><strong>Timestamp:</strong> {new Date(data.timestamp).toLocaleString()}</p>
            </>
          )}
          <button onClick={fetchData} className={styles.button}>
            Refresh
          </button>
        </div>

        <div className={styles.footer}>
          <p>Deployed via Jenkins → Harbor → Argo CD → Kubernetes</p>
        </div>
      </div>
    </main>
  );
}

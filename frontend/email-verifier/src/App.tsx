import React, { useState } from 'react';
import axios from 'axios';

const App: React.FC = () => {
  const [file, setFile] = useState<File | null>(null);
  const [smtpCheck, setSmtpCheck] = useState(true);
  const [gravatarCheck, setGravatarCheck] = useState(false);
  const [catchAllCheck, setCatchAllCheck] = useState(true);
  const [jobId, setJobId] = useState<string | null>(null);
  const [progress, setProgress] = useState<number>(0);
  const [total, setTotal] = useState<number>(0);
  const [status, setStatus] = useState<string>('');
  const [results, setResults] = useState<any[]>([]);
  const [polling, setPolling] = useState(false);

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files && e.target.files.length > 0) {
      setFile(e.target.files[0]);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!file) return;
    const formData = new FormData();
    formData.append('file', file);
    formData.append('smtp_check', smtpCheck ? 'true' : 'false');
    formData.append('gravatar_check', gravatarCheck ? 'true' : 'false');
    formData.append('catch_all_check', catchAllCheck ? 'true' : 'false');
    const res = await axios.post('/api/upload', formData, { headers: { 'Content-Type': 'multipart/form-data' } });
    setJobId(res.data.job_id);
    setResults([]);
    setProgress(0);
    setStatus('pending');
    setPolling(true);
  };

  React.useEffect(() => {
    if (jobId && polling) {
      const interval = setInterval(async () => {
        const progRes = await axios.get(`/api/progress/${jobId}`);
        setProgress(progRes.data.progress);
        setTotal(progRes.data.total);
        setStatus(progRes.data.status);
        if (progRes.data.status === 'done') {
          setPolling(false);
          const resultsRes = await axios.get(`/api/results/${jobId}`);
          setResults(resultsRes.data.results);
        }
      }, 1000);
      return () => clearInterval(interval);
    }
  }, [jobId, polling]);

  const handleDownload = () => {
    const csv = [
      ['Email', 'Reachable', 'Error'],
      ...results.map(r => [r.email, r.reachable, r.error || ''])
    ].map(e => e.join(",")).join("\n");
    const blob = new Blob([csv], { type: 'text/csv' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'results.csv';
    a.click();
    URL.revokeObjectURL(url);
  };

  return (
    <div style={{ maxWidth: 600, margin: 'auto', padding: 24 }}>
      <h2>Email Verifier Dashboard</h2>
      <form onSubmit={handleSubmit}>
        <input type="file" accept=".csv" onChange={handleFileChange} required />
        <div style={{ margin: '12px 0' }}>
          <label><input type="checkbox" checked={smtpCheck} onChange={e => setSmtpCheck(e.target.checked)} /> SMTP Check</label>
          <label style={{ marginLeft: 12 }}><input type="checkbox" checked={gravatarCheck} onChange={e => setGravatarCheck(e.target.checked)} /> Gravatar Check</label>
          <label style={{ marginLeft: 12 }}><input type="checkbox" checked={catchAllCheck} onChange={e => setCatchAllCheck(e.target.checked)} /> Catch-All Check</label>
        </div>
        <button type="submit" disabled={!file || polling}>Start Validation</button>
      </form>
      {status && (
        <div style={{ margin: '16px 0' }}>
          <b>Status:</b> {status} {total > 0 && `( ${progress} / ${total} )`}
          {polling && <div style={{ width: '100%', background: '#eee', marginTop: 8 }}>
            <div style={{ width: `${(progress / (total || 1)) * 100}%`, background: '#4caf50', height: 8 }} />
          </div>}
        </div>
      )}
      {results.length > 0 && (
        <div>
          <h4>Results</h4>
          <button onClick={handleDownload}>Download CSV</button>
          <table border={1} cellPadding={6} style={{ marginTop: 12, width: '100%' }}>
            <thead>
              <tr>
                <th>Email</th>
                <th>Reachable</th>
                <th>Error</th>
              </tr>
            </thead>
            <tbody>
              {results.map((r, i) => (
                <tr key={i}>
                  <td>{r.email}</td>
                  <td>{r.reachable}</td>
                  <td>{r.error}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
};

export default App;

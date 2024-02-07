import React, { useState, useEffect } from 'react';

function DebugNumberPage() {
  const [debugNumber, setDebugNumber] = useState(null);

  useEffect(() => {
    fetch('http://85.215.65.78:8000/debug-number', { credentials: 'include' })
      .then((response) => response.json())
      .then((data) => setDebugNumber(data.debugNumber))
      .catch((error) => console.error(error));
  }, []);

  return (
    <div>
      <h1>Debug Number</h1>
      <p>{debugNumber ? `Debug Number: ${debugNumber}` : 'Loading...'}</p>
    </div>
  );
}

export default DebugNumberPage;

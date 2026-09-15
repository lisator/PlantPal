import React from 'react';
import ReactDOM from 'react-dom/client';

function App() {
  return <h1>React is running!</h1>;
}

const container = document.getElementById('react-root');
const root = ReactDOM.createRoot(container);
root.render(<App />);
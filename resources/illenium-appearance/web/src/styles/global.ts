import { createGlobalStyle } from 'styled-components';

// Crimson Edge palette
export const T = {
  bg: '#0c0c0e',
  panel: '#17161a',
  edge: '#232025',
  field: '#0f0e10',
  text: '#e6e4e3',
  dim: '#86828a',
  faint: '#4c4850',
  red: '#ff2438',
  redHover: '#e01d30',
  redDim: 'rgba(255,36,56,0.10)',
  redSoft: 'rgba(255,36,56,0.06)',
};

export default createGlobalStyle`
  * {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
    outline: 0;
    font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
  }

  body {
    background: transparent;
    -webkit-font-smoothing: antialiased;
    overflow: hidden;
  }

  button {
    cursor: pointer;
    outline: 0;
    font-family: inherit;
  }

  ::-webkit-scrollbar { width: 6px; }
  ::-webkit-scrollbar-track { background: transparent; }
  ::-webkit-scrollbar-thumb { background: ${T.edge}; border-radius: 3px; }
  ::-webkit-scrollbar-thumb:hover { background: ${T.faint}; }
`;

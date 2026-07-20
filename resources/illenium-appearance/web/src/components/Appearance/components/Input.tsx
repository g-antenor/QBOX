import { useCallback } from 'react';
import styled from 'styled-components';
import { T } from '../../../styles/global';

interface InputProps {
  title?: string;
  min?: number;
  max?: number;
  defaultValue: number;
  clientValue: number;
  onChange: (value: number) => void;
}

// REDESIGN: numeric selector is now a SLIDER (was left/right arrows).
const Container = styled.div`
  min-width: 0;
  width: 100%;
  display: flex;
  flex-direction: column;
  flex-grow: 1;

  > span {
    width: 100%;
    display: flex;
    justify-content: space-between;
    align-items: center;
    font-size: 11px;
    color: ${T.dim};

    b {
      font-weight: 600;
      color: ${T.text};
      font-variant-numeric: tabular-nums;
    }
  }

  .track-row {
    display: flex;
    align-items: center;
    gap: 8px;
    margin-top: 8px;

    small {
      font-size: 9px;
      color: ${T.faint};
      min-width: 12px;
      text-align: center;
    }
  }

  input[type='range'] {
    -webkit-appearance: none;
    appearance: none;
    flex: 1;
    height: 3px;
    background: ${T.edge};
    border-radius: 2px;
    outline: none;
  }

  input[type='range']::-webkit-slider-thumb {
    -webkit-appearance: none;
    appearance: none;
    width: 12px;
    height: 12px;
    border-radius: 50%;
    background: ${T.red};
    cursor: pointer;
    transition: transform 0.1s;
  }
  input[type='range']::-webkit-slider-thumb:hover { transform: scale(1.2); }
`;

const Input: React.FC<InputProps> = ({ title, min = 0, max = 255, defaultValue, clientValue, onChange }) => {
  const handleChange = useCallback(
    (e: { target: { value: string } }) => {
      const parsed = parseInt(e.target.value, 10);
      if (Number.isNaN(parsed)) return;
      onChange(parsed);
    },
    [onChange],
  );

  return (
    <Container>
      <span>
        <small>
          {title}
          {clientValue !== undefined && <em style={{ color: T.faint, fontStyle: 'normal' }}> · {clientValue}</em>}
        </small>
        <b>
          {defaultValue} <span style={{ color: T.faint, fontWeight: 400 }}>/ {max}</span>
        </b>
      </span>
      <div className="track-row">
        <small>{min}</small>
        <input type="range" min={min} max={max} step={1} value={defaultValue} onChange={handleChange} />
        <small>{max}</small>
      </div>
    </Container>
  );
};

export default Input;

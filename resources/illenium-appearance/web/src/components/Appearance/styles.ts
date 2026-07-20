import styled from 'styled-components';
import { T } from '../../styles/global';

export const Wrapper = styled.div`
  height: 100vh;
  width: 100vw;

  display: flex;
  align-items: stretch;
  justify-content: space-between;
  overflow: hidden;
  color: ${T.text};
`;

/* ---------------- left panel (sections) ---------------- */
export const LeftPanel = styled.div`
  height: 100vh;
  width: 360px;
  flex: none;

  display: flex;
  flex-direction: column;

  padding: 24px 16px;
  gap: 12px;

  background: ${T.panel};
  border-right: 1px solid ${T.edge};
`;

export const Brand = styled.div`
  display: flex;
  flex-direction: column;
  gap: 2px;

  .title {
    font-size: 15px;
    font-weight: 800;
    letter-spacing: 0.06em;
    text-transform: uppercase;
    color: ${T.text};
    display: flex;
    align-items: center;
    gap: 7px;
  }
  .title::before {
    content: '';
    width: 6px;
    height: 6px;
    border-radius: 50%;
    background: ${T.red};
    box-shadow: 0 0 6px ${T.red};
  }
  .sub {
    font-size: 10px;
    color: ${T.faint};
    letter-spacing: 0.04em;
    text-transform: uppercase;
    padding-left: 13px;
  }
`;

export const TabBar = styled.div`
  display: flex;
  gap: 4px;
  padding: 4px;
  border-radius: 4px;
  border: 1px solid ${T.edge};
  background: ${T.field};
`;

export const Tab = styled.button<{ active: boolean }>`
  flex: 1;
  padding: 8px 4px;
  border: 0;
  border-radius: 3px;
  background: ${({ active }) => (active ? T.red : 'transparent')};
  color: ${({ active }) => (active ? '#fff' : T.dim)};
  font-size: 10px;
  font-weight: 700;
  letter-spacing: 0.03em;
  text-transform: uppercase;
  transition: background 0.12s, color 0.12s;

  &:hover {
    color: ${({ active }) => (active ? '#fff' : T.text)};
    background: ${({ active }) => (active ? T.redHover : T.redSoft)};
  }
`;

export const Container = styled.div`
  flex: 1;
  min-height: 0;

  display: flex;
  flex-direction: column;
  align-items: flex-start;
  justify-content: flex-start;

  padding-right: 4px;
  overflow-y: auto;
`;

export const FlexWrapper = styled.div`
  width: 100%;
  display: flex;

  > div {
    & + div {
      margin-left: 12px;
    }
  }
`;
